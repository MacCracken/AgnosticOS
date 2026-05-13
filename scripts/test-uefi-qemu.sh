#!/bin/sh
# test-uefi-qemu.sh — boot the AGNOS kernel under QEMU + OVMF (emulated UEFI).
#
# Exercises the SAME grub_relocator64_efi_boot path the NUC AMD iron uses
# (lib/i386/relocator64.S:95-164 — no long-mode-exit, 64-bit indirect jmp).
# Step 5b of docs/development/path-a-elf64-multiboot2.md. If this boots
# cleanly into the scheduler + tier3 test, the multiboot2 + EFI64-entry
# kernel + the long-mode shim are validated together before Attempt 5
# on iron.
#
# Layout produced (raw FAT32 image, no partition table — OVMF treats
# unpartitioned FAT32 as a "removable" ESP):
#   /EFI/BOOT/BOOTX64.EFI        standalone GRUB-EFI with embedded config
#                                 that search.fs_label's AGNOSTEST and
#                                 loads /boot/grub/grub.cfg
#   /boot/grub/grub.cfg          multiboot2 menu entries (see install-usb.sh
#                                 for the iron equivalent — same shape but
#                                 `multiboot2` / `module2` instead of
#                                 `multiboot` / `module`)
#   /boot/agnos                  ELF64 multiboot2 kernel
#   /boot/initramfs.cpio.gz      initramfs
#
# Requires: edk2-ovmf, qemu-system-x86_64, mtools, grub (x86_64-efi modules).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGNOS_REPO="${AGNOS_REPO:-$ROOT/../agnos}"
BUILD="$ROOT/scripts/build"
IMG="$BUILD/test-uefi.img"
KERNEL="$AGNOS_REPO/build/agnos"
INITRAMFS="$BUILD/initramfs.cpio.gz"
OVMF_CODE="/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd"
OVMF_VARS_SRC="/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd"
OVMF="/usr/share/edk2-ovmf/x64/OVMF.4m.fd"   # fallback combined

# --- sanity ---
for tool in qemu-system-x86_64 mkfs.fat mcopy mmd grub-mkstandalone; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool not in PATH" >&2; exit 1; }
done
[ -f "$KERNEL" ] || { echo "ERROR: $KERNEL not found — build it first ($AGNOS_REPO/scripts/build.sh)" >&2; exit 1; }
[ -f "$INITRAMFS" ] || { echo "ERROR: $INITRAMFS not found" >&2; exit 1; }
[ -f "$OVMF_CODE" ] || { echo "ERROR: $OVMF_CODE not found — install edk2-ovmf" >&2; exit 1; }
[ -f "$OVMF_VARS_SRC" ] || { echo "ERROR: $OVMF_VARS_SRC not found" >&2; exit 1; }

# Confirm kernel is ELF64 multiboot2 (not legacy ELF32 multiboot1)
if ! grub-file --is-x86-multiboot2 "$KERNEL" 2>/dev/null; then
    echo "ERROR: $KERNEL is NOT a multiboot2 kernel." >&2
    echo "  Build it with CYRIUS_ELF64_KERNEL=1 (which scripts/build.sh sets)." >&2
    exit 1
fi

mkdir -p "$BUILD"

# --- 1. create + format image ---
echo "[1/5] Creating 64M FAT32 image at $IMG..."
rm -f "$IMG"
truncate -s 64M "$IMG"
mkfs.fat -F 32 -n AGNOSTEST "$IMG" >/dev/null

# --- 2. Build a small EFI loader + copy modules from system grub ---
# Mirrors what `grub-install --target=x86_64-efi --removable` does internally:
# a thin BOOTX64.EFI that knows where to find modules (via embedded `prefix`),
# plus the modules themselves at /boot/grub/x86_64-efi/*.mod on the ESP.
# Avoids grub-install's disk-detection (which fails against a staging dir).
echo "[2/5] Building thin BOOTX64.EFI + copying modules..."
STAGE="$BUILD/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/EFI/BOOT" "$STAGE/boot/grub/x86_64-efi"

# Copy ALL GRUB x86_64-efi modules + helper files (matches grub-install layout)
cp /usr/lib/grub/x86_64-efi/*.mod "$STAGE/boot/grub/x86_64-efi/"
cp /usr/lib/grub/x86_64-efi/*.lst "$STAGE/boot/grub/x86_64-efi/"
cp -r /usr/share/grub/themes 2>/dev/null "$STAGE/boot/grub/" || true

# Embedded config: tell GRUB where to find its real config + modules.
# `prefix` is the path GRUB uses to load additional modules at runtime.
EMBED_CFG="$(mktemp)"
cat > "$EMBED_CFG" <<'EOF'
search --label AGNOSTEST --set=root
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
EOF
grub-mkimage \
    --format=x86_64-efi \
    --output="$STAGE/EFI/BOOT/BOOTX64.EFI" \
    --prefix='/boot/grub' \
    --config="$EMBED_CFG" \
    part_gpt part_msdos fat normal configfile search search_label echo
rm -f "$EMBED_CFG"

# --- 3. real grub.cfg (multiboot2 menu) ---
GRUB_CFG="$(mktemp)"
cat > "$GRUB_CFG" <<'EOF'
# UEFI test grub.cfg — multiboot2 variant of install-usb.sh's iron config.
insmod all_video
insmod efi_gop
insmod efi_uga
set gfxpayload=text
set timeout=2
set default=2   # kernel-only — bisect away from module2

menuentry 'AGNOS — ELF64 multiboot2 (default)' {
    insmod multiboot2
    insmod gzio
    set gfxpayload=text
    multiboot2 /boot/agnos
    module2    /boot/initramfs.cpio.gz
    boot
}

menuentry 'AGNOS — verbose serial (ttyS0,115200)' {
    insmod multiboot2
    insmod gzio
    set gfxpayload=text
    multiboot2 /boot/agnos console=ttyS0,115200
    module2    /boot/initramfs.cpio.gz
    boot
}

# Kernel-only entry — no module2. Bisects whether the initramfs module
# handling is what's faulting in GRUB-EFI's multiboot2 prep.
menuentry 'AGNOS — kernel only (no initramfs)' {
    insmod multiboot2
    set gfxpayload=text
    multiboot2 /boot/agnos console=ttyS0,115200
    boot
}
EOF

# --- 4. assemble files in staging, then mcopy the tree into image ---
echo "[3/5] Assembling staging dir, then mcopy into image..."
cp "$GRUB_CFG" "$STAGE/boot/grub/grub.cfg"
cp "$KERNEL" "$STAGE/boot/agnos"
cp "$INITRAMFS" "$STAGE/boot/initramfs.cpio.gz"
rm -f "$GRUB_CFG"

# mcopy -s recurses; the staging dir layout matches the ESP exactly
mcopy -i "$IMG" -s "$STAGE"/* ::/

# --- 5. boot ---
echo "[4/5] Booting QEMU OVMF (serial → stdout)..."
echo "      Quit: Ctrl-A x  |  Timeout: ${QEMU_TIMEOUT:-45}s wall clock"
echo ""

# `-cpu max` advertises SMEP/SMAP; without KVM, host emulation is slow
# but doesn't require /dev/kvm permissions. Set QEMU_KVM=1 to opt in.
KVM_ARGS=""
if [ "${QEMU_KVM:-0}" = "1" ] && [ -r /dev/kvm ]; then
    KVM_ARGS="-enable-kvm -cpu host"
else
    KVM_ARGS="-cpu max"
fi

# Canonical OVMF pflash setup: code (RO) + a writable copy of vars.
# Some QEMU versions handle EFI image memory-protection policy
# differently when OVMF is loaded as pflash vs `-bios`.
OVMF_VARS="$BUILD/test-uefi-vars.4m.fd"
cp -f "$OVMF_VARS_SRC" "$OVMF_VARS"

timeout "${QEMU_TIMEOUT:-45}" \
    qemu-system-x86_64 \
        -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
        -drive "if=pflash,format=raw,file=$OVMF_VARS" \
        -drive "file=$IMG,format=raw" \
        -serial stdio \
        -display none \
        -m 256M \
        -no-reboot \
        $KVM_ARGS \
    || rc=$?
echo ""
echo "[5/5] QEMU exited (rc=${rc:-0})."
