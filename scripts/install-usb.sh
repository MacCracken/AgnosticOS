#!/bin/bash
# install-usb.sh — Provision or refresh a USB drive as an AGNOS boot device
#
# gnoboot at EFI/BOOT/BOOTX64.EFI + agnos kernel at /boot/agnos.
# UEFI firmware loads gnoboot from the removable-boot path; gnoboot loads
# the kernel via SimpleFileSystemProtocol and hands off via the sovereign
# boot-info struct (RDI = &boot_info, magic 0x41474E4F='AGNO'). No GRUB.
#
# GPT layout (provision mode):
#   p1  256 MiB  FAT32 ESP        (label AGNOSBOOT)  — gnoboot + kernel + initramfs
#   p2   25 GiB  ext4 agnos-fs    (GPT name agnos-fs, fs label agnos-fs)
#                                  — pre-seeded with /hello.txt, /welcome.txt,
#                                    /agnos/, /agnos/notes.txt; ready surface
#                                    for 1.33.x ext4 WRITE bring-up.
#   rest        unallocated       (reserved for future expansion)
#
# Two modes:
#
#   sudo ./scripts/install-usb.sh /dev/sdX
#     Full provision: wipes, GPT + 256MB FAT32 ESP + 25GiB ext4 agnos-fs
#     partition (pre-seeded), copies gnoboot.efi + kernel + initramfs.
#     No grub-install.
#
#   sudo ./scripts/install-usb.sh --update /dev/sdX
#     Iteration refresh: mounts the existing ESP, overwrites gnoboot +
#     kernel + initramfs, unmounts. No wipe. Does NOT touch the agnos-fs
#     data partition — writes that 1.33.x lands there will survive
#     kernel-refresh iterations.
#
# After either: reboot, F-key boot menu, select the USB.
#
# Note: this is a host-side bash script (orchestration of destructive
# disk operations needs root). The Cyrius-native install.cyr does the
# initramfs build that this script consumes.

set -euo pipefail

# --- args ---

MODE="provision"
if [[ "${1:-}" == "--update" || "${1:-}" == "-u" ]]; then
    MODE="update"
    shift
fi

DEV="${1:-}"
if [[ -z "$DEV" ]]; then
    echo "Usage:"
    echo "  sudo $0 /dev/sdX             # full provision (wipes the device)"
    echo "  sudo $0 --update /dev/sdX    # refresh gnoboot + kernel + initramfs only"
    echo ""
    echo "Detect candidates:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS,LABEL,MODEL | head -20
    exit 1
fi

if [[ ! -b "$DEV" ]]; then
    echo "ERROR: $DEV is not a block device"
    exit 1
fi

# NVMe partitions use 'p1' suffix; SATA/USB use plain '1'
case "$DEV" in
    *nvme*) PART="${DEV}p1"; PART2="${DEV}p2" ;;
    *)      PART="${DEV}1";  PART2="${DEV}2"  ;;
esac

# --- paths ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KERNEL_SRC="${REPO_ROOT}/../agnos/build/agnos"
GNOBOOT_SRC="${GNOBOOT_SRC:-${REPO_ROOT}/../gnoboot/build/BOOTX64.EFI}"
INITRAMFS_SRC="${SCRIPT_DIR}/build/initramfs.cpio.gz"
MOUNT_POINT="/mnt/agnos-usb"
MOUNT_POINT_DATA="/mnt/agnos-usb-data"

# --- preflight ---

if [[ ! -f "$KERNEL_SRC" ]]; then
    echo "ERROR: AGNOS kernel not found at $KERNEL_SRC"
    echo "  Build it first in the agnos repo: (cd ../agnos && sh scripts/build.sh)"
    exit 1
fi

if [[ ! -f "$GNOBOOT_SRC" ]]; then
    echo "ERROR: gnoboot binary not found at $GNOBOOT_SRC"
    echo "  Build it first in the gnoboot repo:"
    echo "    (cd ../gnoboot && CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI)"
    echo "  Or fetch the latest release:"
    echo "    curl -fsSL https://github.com/MacCracken/gnoboot/releases/latest/download/BOOTX64.EFI \\"
    echo "      -o ../gnoboot/build/BOOTX64.EFI"
    echo "  Or override GNOBOOT_SRC=/path/to/BOOTX64.EFI on the command line."
    exit 1
fi

if [[ ! -f "$INITRAMFS_SRC" ]]; then
    echo "ERROR: initramfs not found at $INITRAMFS_SRC"
    echo "  Build it first: cd $SCRIPT_DIR && ./build/install"
    exit 1
fi

# --- update mode (refresh gnoboot + kernel + initramfs, no wipe) ---

if [[ "$MODE" == "update" ]]; then
    if [[ ! -b "$PART" ]]; then
        echo "ERROR: expected partition $PART does not exist"
        echo "  $DEV may not be provisioned yet — run without --update first."
        exit 1
    fi
    echo "=== AGNOS USB Refresh ==="
    echo ""
    echo "Target partition: $PART (on $DEV)"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS,LABEL,MODEL "$DEV" 2>/dev/null || true
    echo ""
    echo "Files to install:"
    echo "  gnoboot:   $GNOBOOT_SRC ($(stat -c%s "$GNOBOOT_SRC") bytes)"
    echo "  Kernel:    $KERNEL_SRC ($(stat -c%s "$KERNEL_SRC") bytes)"
    echo "  Initramfs: $INITRAMFS_SRC ($(stat -c%s "$INITRAMFS_SRC") bytes)"
    echo ""

    mkdir -p "$MOUNT_POINT"
    # Tolerate a previous failed run that left the partition mounted.
    if mountpoint -q "$MOUNT_POINT"; then
        echo "  (already mounted at $MOUNT_POINT — reusing)"
    else
        mount "$PART" "$MOUNT_POINT"
    fi

    if [[ ! -d "${MOUNT_POINT}/EFI/BOOT" ]]; then
        echo "ERROR: $PART is mounted but has no /EFI/BOOT — not a provisioned AGNOS USB"
        echo "       (or it's a pre-1.30.0 GRUB-shape USB — re-provision without --update)."
        umount "$MOUNT_POINT" 2>/dev/null || true
        exit 1
    fi

    OLD_GNOBOOT_BYTES=0
    [[ -f "${MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI" ]] && OLD_GNOBOOT_BYTES=$(stat -c%s "${MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI")
    OLD_KERN_BYTES=0
    [[ -f "${MOUNT_POINT}/boot/agnos" ]] && OLD_KERN_BYTES=$(stat -c%s "${MOUNT_POINT}/boot/agnos")
    OLD_INIT_BYTES=0
    [[ -f "${MOUNT_POINT}/boot/initramfs.cpio.gz" ]] && OLD_INIT_BYTES=$(stat -c%s "${MOUNT_POINT}/boot/initramfs.cpio.gz")

    echo "Refreshing /EFI/BOOT/BOOTX64.EFI         ${OLD_GNOBOOT_BYTES} → $(stat -c%s "$GNOBOOT_SRC") bytes"
    cp "$GNOBOOT_SRC" "${MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI"
    echo "Refreshing /boot/agnos                    ${OLD_KERN_BYTES} → $(stat -c%s "$KERNEL_SRC") bytes"
    cp "$KERNEL_SRC" "${MOUNT_POINT}/boot/agnos"
    echo "Refreshing /boot/initramfs.cpio.gz       ${OLD_INIT_BYTES} → $(stat -c%s "$INITRAMFS_SRC") bytes"
    cp "$INITRAMFS_SRC" "${MOUNT_POINT}/boot/initramfs.cpio.gz"

    echo "Unmounting and syncing..."
    umount "$MOUNT_POINT"
    sync

    echo ""
    echo "============================================================"
    echo "✓ AGNOS USB refreshed on $PART"
    echo "============================================================"
    echo ""
    echo "No GRUB config to maintain — gnoboot reads /boot/agnos directly."
    echo "Reboot and select the USB to test."
    echo ""
    echo "What you'll see on the screen:"
    echo "  Boot renders a live text log: AGNOS kernel version -> arch init (GDT/TSS/IDT) ->"
    echo "  subsystems (PMM, heap, PCI, xhci, VFS) -> 'AGNOS shell v... (type help)' -> 'agnos>' prompt."
    echo "  If boot stalls partway, the last visible line names the init step that failed."
    echo ""
    echo "If boot stalls (no shell prompt):"
    echo "  Reboot into Linux on the same machine, then:"
    echo "    sudo ${SCRIPT_DIR}/build/read-boot-log"
    echo "  Reads CMOS slots 0x50-0x6F + 0x60 (battery-backed, survives reset): kernel + gnoboot"
    echo "  checkpoints, magic bytes, CR4 stamps, PMM allocator scan, and xhci post-mortem. Pairs"
    echo "  with the framebuffer text to name the exact sub-case. See docs/development/iron-nuc-zen-log.md (active log) or docs/development/iron-nuc-zen-log-mvp.md (Attempts 1–68, MVP era)."
    exit 0
fi

# --- provision-mode preflight (tools only needed for full wipe path) ---

for tool in parted mkfs.fat mkfs.ext4 wipefs partprobe; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: required tool '$tool' not found"
        exit 1
    fi
done

# --- confirmation ---

echo "=== AGNOS USB Provisioning (gnoboot, no GRUB) ==="
echo ""
echo "Target device: $DEV"
echo ""
echo "Device info (verify this is your USB, NOT your daily-driver disk):"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS,LABEL,MODEL "$DEV" 2>/dev/null || true
echo ""
udevadm info --query=property --name="$DEV" 2>/dev/null | grep -E "ID_BUS|ID_MODEL|ID_VENDOR" || true
echo ""
echo "Files to install (ESP, partition 1):"
echo "  gnoboot:   $GNOBOOT_SRC ($(stat -c%s "$GNOBOOT_SRC") bytes)"
echo "  Kernel:    $KERNEL_SRC ($(stat -c%s "$KERNEL_SRC") bytes)"
echo "  Initramfs: $INITRAMFS_SRC ($(stat -c%s "$INITRAMFS_SRC") bytes)"
echo ""
echo "Data partition (ext4 agnos-fs, partition 2, 25 GiB):"
echo "  Pre-seeded with /hello.txt, /welcome.txt, /agnos/notes.txt"
echo "  Ready surface for 1.33.x ext4 WRITE bring-up. Persists across"
echo "  --update refresh cycles (only the ESP is touched on --update)."
echo ""
echo "*** THIS WILL WIPE ALL DATA ON $DEV ***"
echo "  (For just refreshing gnoboot/kernel/initramfs on a USB you've already"
echo "   provisioned once, re-run with --update — no wipe, data partition untouched.)"
echo ""
read -r -p "Type 'YES' to proceed: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

# --- 1. wipe ---

echo ""
echo "[1/8] Wiping existing partition table on $DEV..."
wipefs -a "$DEV"

# --- 2. partition ---

echo "[2/8] Creating GPT layout (256MiB FAT32 ESP at 1MiB + 25GiB ext4 agnos-fs at 256MiB + rest unallocated)..."
parted -s "$DEV" mklabel gpt
parted -s "$DEV" mkpart AGNOS-BOOT fat32 1MiB 256MiB
parted -s "$DEV" set 1 esp on
# Second partition: GPT name "agnos-fs" so the kernel's GPT-aware ext2
# probe (ext2.cyr:160-185, gates on Linux-FS type GUID + matches name)
# can recognize it. End offset: 256MiB + 25 GiB (25600 MiB) = 25856 MiB.
parted -s "$DEV" mkpart agnos-fs ext4 256MiB 25856MiB
partprobe "$DEV"
sleep 1

# --- 3. format ESP ---

echo "[3/8] Formatting $PART as FAT32 (label AGNOSBOOT)..."
mkfs.fat -F32 -n AGNOSBOOT "$PART"

# --- 4. format data partition (ext4, default 64BIT-enabled per Attempt 91) ---

echo "[4/8] Formatting $PART2 as ext4 (label agnos-fs, default mkfs.ext4 → 64BIT)..."
mkfs.ext4 -F -L agnos-fs "$PART2"

# --- 5. mount ESP ---

echo "[5/8] Mounting $PART at $MOUNT_POINT..."
mkdir -p "$MOUNT_POINT"
mount "$PART" "$MOUNT_POINT"

# --- 6. copy gnoboot + kernel + initramfs (ESP contents) ---

echo "[6/8] Copying gnoboot + kernel + initramfs to ESP..."
mkdir -p "${MOUNT_POINT}/EFI/BOOT"
cp "$GNOBOOT_SRC" "${MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI"
mkdir -p "${MOUNT_POINT}/boot"
cp "$KERNEL_SRC" "${MOUNT_POINT}/boot/agnos"
cp "$INITRAMFS_SRC" "${MOUNT_POINT}/boot/initramfs.cpio.gz"

umount "$MOUNT_POINT"

# --- 7. mount data partition + seed ---

echo "[7/8] Mounting $PART2 at $MOUNT_POINT_DATA + seeding hello + welcome + /agnos/ subfolder..."
mkdir -p "$MOUNT_POINT_DATA"
mount "$PART2" "$MOUNT_POINT_DATA"
PROV_DATE="$(date -u +%Y-%m-%d)"
printf 'hello from agnos USB ext4 seed   provisioned %s\n' "$PROV_DATE" > "${MOUNT_POINT_DATA}/hello.txt"
printf 'welcome — secondary hello on agnos-fs root   provisioned %s\n' "$PROV_DATE" > "${MOUNT_POINT_DATA}/welcome.txt"
mkdir -p "${MOUNT_POINT_DATA}/agnos"
printf 'notes from the /agnos/ subfolder — cd+cat+ls validation surface   provisioned %s\n' "$PROV_DATE" > "${MOUNT_POINT_DATA}/agnos/notes.txt"

# --- 8. unmount + sync ---

echo "[8/8] Unmounting and syncing..."
umount "$MOUNT_POINT_DATA"
sync

# --- done ---

echo ""
echo "============================================================"
echo "✓ AGNOS USB ready at $DEV"
echo "============================================================"
echo ""
echo "Layout:"
echo "  $PART   256MiB  FAT32 ESP        (label AGNOSBOOT)"
echo "    EFI/BOOT/BOOTX64.EFI    — gnoboot (UEFI removable-boot path)"
echo "    boot/agnos              — AGNOS kernel (ELF64)"
echo "    boot/initramfs.cpio.gz  — initramfs (consumed by kernel; not gnoboot v0.1.0)"
echo "  $PART2   25GiB   ext4 agnos-fs   (GPT name & fs label 'agnos-fs', 64BIT-enabled)"
echo "    /hello.txt              — primary hello seed"
echo "    /welcome.txt            — secondary hello seed (root)"
echo "    /agnos/notes.txt        — content inside /agnos/ subfolder"
echo "  unallocated  rest of device  (reserved for future expansion)"
echo ""
echo "Note on mount priority (per agnos/kernel/core/ext2.cyr probe order"
echo "NVMe → AHCI → USB-MS → VirtIO → RAMDISK, first match wins): if a"
echo "machine also has an internal NVMe 'agnos-fs' partition (e.g. archaemenid),"
echo "NVMe wins and the USB seed sits dormant. That's intentional — the USB"
echo "agnos-fs is the sacrificial write-test surface for 1.33.x WRITE bring-up,"
echo "kept ready without competing with the NVMe primary."
echo ""
echo "Boot path:"
echo "  UEFI firmware → EFI/BOOT/BOOTX64.EFI (gnoboot) → /boot/agnos (kernel)"
echo "  Handoff: RDI = &boot_info (magic 0x41474E4F='AGNO'), see docs/development/ for sovereign UEFI design notes"
echo ""
echo "Next steps:"
echo "  1. Reboot"
echo "  2. Hit your motherboard's boot-menu key (F8/F10/F12/Esc)"
echo "  3. Select the USB drive"
echo "  4. gnoboot loads the kernel automatically (no menu in v0.1.0)"
echo ""
echo "What you'll see on the screen:"
echo "  Boot renders a live text log: AGNOS kernel version -> arch init (GDT/TSS/IDT) ->"
echo "  subsystems (PMM, heap, PCI, xhci, VFS) -> 'AGNOS shell v... (type help)' -> 'agnos>' prompt."
echo "  If boot stalls partway, the last visible line names the init step that failed."
echo ""
echo "If boot stalls (no shell prompt):"
echo "  Reboot into Linux on the same machine, then:"
echo "    sudo ${SCRIPT_DIR}/build/read-boot-log"
echo "  Reads CMOS slots 0x50-0x6F + 0x60 (battery-backed, survives reset): kernel + gnoboot"
echo "  checkpoints, magic bytes, CR4 stamps, PMM allocator scan, and xhci post-mortem. Pairs"
echo "  with the framebuffer text to name the exact sub-case. See docs/development/iron-nuc-zen-log.md (active log) or docs/development/iron-nuc-zen-log-mvp.md (Attempts 1–68, MVP era)."
echo ""
echo "Iteration loop (refresh without re-provisioning):"
echo "  (cd ../gnoboot && CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI)"
echo "  (cd ../agnos && sh scripts/build.sh)"
echo "  sudo $0 --update $DEV"
echo ""
