#!/bin/bash
# install-usb.sh — Provision or refresh a USB drive as an AGNOS boot device
#
# Path C: gnoboot at EFI/BOOT/BOOTX64.EFI + agnos kernel at /boot/agnos.
# UEFI firmware loads gnoboot from the removable-boot path; gnoboot loads
# the kernel via SimpleFileSystemProtocol and hands off via the sovereign
# boot-info struct (RDI = &boot_info, magic 0x41474E4F='AGNO'). No GRUB.
# Pre-1.30.0 multiboot2-via-GRUB shape lives in git history; see Path A
# notes in docs/development/path-a-elf64-multiboot2.md (closed).
#
# Two modes:
#
#   sudo ./scripts/install-usb.sh /dev/sdX
#     Full provision: wipes, GPT + 256MB FAT32 ESP, copies gnoboot.efi
#     + kernel + initramfs. No grub-install.
#
#   sudo ./scripts/install-usb.sh --update /dev/sdX
#     Iteration refresh: mounts the existing ESP, overwrites gnoboot +
#     kernel + initramfs, unmounts. No wipe. Use this after rebuilding
#     gnoboot and/or agnos kernel locally.
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
    *nvme*) PART="${DEV}p1" ;;
    *)      PART="${DEV}1" ;;
esac

# --- paths ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KERNEL_SRC="${REPO_ROOT}/../agnos/build/agnos"
GNOBOOT_SRC="${GNOBOOT_SRC:-${REPO_ROOT}/../gnoboot/build/BOOTX64.EFI}"
INITRAMFS_SRC="${SCRIPT_DIR}/build/initramfs.cpio.gz"
MOUNT_POINT="/mnt/agnos-usb"

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
    exit 0
fi

# --- provision-mode preflight (tools only needed for full wipe path) ---

for tool in parted mkfs.fat wipefs partprobe; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: required tool '$tool' not found"
        exit 1
    fi
done

# --- confirmation ---

echo "=== AGNOS USB Provisioning (Path C — gnoboot, no GRUB) ==="
echo ""
echo "Target device: $DEV"
echo ""
echo "Device info (verify this is your USB, NOT your daily-driver disk):"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS,LABEL,MODEL "$DEV" 2>/dev/null || true
echo ""
udevadm info --query=property --name="$DEV" 2>/dev/null | grep -E "ID_BUS|ID_MODEL|ID_VENDOR" || true
echo ""
echo "Files to install:"
echo "  gnoboot:   $GNOBOOT_SRC ($(stat -c%s "$GNOBOOT_SRC") bytes)"
echo "  Kernel:    $KERNEL_SRC ($(stat -c%s "$KERNEL_SRC") bytes)"
echo "  Initramfs: $INITRAMFS_SRC ($(stat -c%s "$INITRAMFS_SRC") bytes)"
echo ""
echo "*** THIS WILL WIPE ALL DATA ON $DEV ***"
echo "  (For just refreshing gnoboot/kernel/initramfs on a USB you've already"
echo "   provisioned once, re-run with --update — no wipe.)"
echo ""
read -r -p "Type 'YES' to proceed: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

# --- 1. wipe ---

echo ""
echo "[1/6] Wiping existing partition table on $DEV..."
wipefs -a "$DEV"

# --- 2. partition ---

echo "[2/6] Creating GPT layout (256MB FAT32 ESP at 1MiB + rest unallocated)..."
parted -s "$DEV" mklabel gpt
parted -s "$DEV" mkpart AGNOS-BOOT fat32 1MiB 256MiB
parted -s "$DEV" set 1 esp on
partprobe "$DEV"
sleep 1

# --- 3. format ---

echo "[3/6] Formatting $PART as FAT32 (label AGNOSBOOT)..."
mkfs.fat -F32 -n AGNOSBOOT "$PART"

# --- 4. mount ---

echo "[4/6] Mounting $PART at $MOUNT_POINT..."
mkdir -p "$MOUNT_POINT"
mount "$PART" "$MOUNT_POINT"

# --- 5. copy gnoboot (UEFI removable-boot path) ---

echo "[5/6] Copying gnoboot to EFI/BOOT/BOOTX64.EFI..."
mkdir -p "${MOUNT_POINT}/EFI/BOOT"
cp "$GNOBOOT_SRC" "${MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI"

# --- 6. copy AGNOS kernel + initramfs ---

echo "[6/6] Copying AGNOS kernel + initramfs..."
mkdir -p "${MOUNT_POINT}/boot"
cp "$KERNEL_SRC" "${MOUNT_POINT}/boot/agnos"
cp "$INITRAMFS_SRC" "${MOUNT_POINT}/boot/initramfs.cpio.gz"

# --- unmount + sync ---

echo ""
echo "Unmounting and syncing..."
umount "$MOUNT_POINT"
sync

# --- done ---

echo ""
echo "============================================================"
echo "✓ AGNOS USB ready at $DEV"
echo "============================================================"
echo ""
echo "Layout:"
echo "  $PART   256MB  FAT32 ESP  (label AGNOSBOOT)"
echo "    EFI/BOOT/BOOTX64.EFI    — gnoboot (UEFI removable-boot path)"
echo "    boot/agnos              — AGNOS kernel (ELF64)"
echo "    boot/initramfs.cpio.gz  — initramfs (consumed by kernel; not gnoboot v0.1.0)"
echo "  unallocated  rest of device  (reserved for future AGNOS data partition)"
echo ""
echo "Boot path:"
echo "  UEFI firmware → EFI/BOOT/BOOTX64.EFI (gnoboot) → /boot/agnos (kernel)"
echo "  Handoff: RDI = &boot_info (magic 0x41474E4F='AGNO'), see path-c-sovereign-uefi.md"
echo ""
echo "Next steps:"
echo "  1. Reboot"
echo "  2. Hit your motherboard's boot-menu key (F8/F10/F12/Esc)"
echo "  3. Select the USB drive"
echo "  4. gnoboot loads the kernel automatically (no menu in v0.1.0)"
echo ""
echo "Iteration loop (refresh without re-provisioning):"
echo "  (cd ../gnoboot && CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI)"
echo "  (cd ../agnos && sh scripts/build.sh)"
echo "  sudo $0 --update $DEV"
echo ""
