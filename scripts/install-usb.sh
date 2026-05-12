#!/bin/bash
# install-usb.sh — Provision a USB drive as an AGNOS boot device
#
# Wipes the target device, creates a GPT layout with a 256MB FAT32 ESP,
# installs GRUB in EFI removable mode, copies AGNOS kernel + initramfs,
# and writes a 3-entry boot menu.
#
# Usage:
#   sudo ./scripts/install-usb.sh /dev/sdX
#
# After running: reboot, F-key boot menu, select the USB.
#
# Note: this is a host-side bash script (orchestration of destructive
# disk operations + grub-install — both need root). The Cyrius-native
# install.cyr does the initramfs build that this script consumes.
# Eventually this script's logic could fold into install.cyr behind a
# --target-device flag, but for first-hardware-boot work the bash form
# is direct and inspectable.

set -euo pipefail

# --- args ---

DEV="${1:-}"
if [[ -z "$DEV" ]]; then
    echo "Usage: sudo $0 /dev/sdX"
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
INITRAMFS_SRC="${SCRIPT_DIR}/build/initramfs.cpio.gz"
MOUNT_POINT="/mnt/agnos-usb"

# --- preflight ---

if [[ ! -f "$KERNEL_SRC" ]]; then
    echo "ERROR: AGNOS kernel not found at $KERNEL_SRC"
    echo "  Build it first in the agnos repo: cyrius build src/main.cyr build/agnos"
    exit 1
fi

if [[ ! -f "$INITRAMFS_SRC" ]]; then
    echo "ERROR: initramfs not found at $INITRAMFS_SRC"
    echo "  Build it first: cd $SCRIPT_DIR && ./build/install"
    exit 1
fi

for tool in parted mkfs.fat wipefs partprobe grub-install; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: required tool '$tool' not found"
        exit 1
    fi
done

# --- confirmation ---

echo "=== AGNOS USB Provisioning ==="
echo ""
echo "Target device: $DEV"
echo ""
echo "Device info (verify this is your USB, NOT your daily-driver disk):"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS,LABEL,MODEL "$DEV" 2>/dev/null || true
echo ""
udevadm info --query=property --name="$DEV" 2>/dev/null | grep -E "ID_BUS|ID_MODEL|ID_VENDOR" || true
echo ""
echo "Files to install:"
echo "  Kernel:    $KERNEL_SRC ($(stat -c%s "$KERNEL_SRC") bytes)"
echo "  Initramfs: $INITRAMFS_SRC ($(stat -c%s "$INITRAMFS_SRC") bytes)"
echo ""
echo "*** THIS WILL WIPE ALL DATA ON $DEV ***"
echo ""
read -r -p "Type 'YES' to proceed: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

# --- 1. wipe ---

echo ""
echo "[1/7] Wiping existing partition table on $DEV..."
wipefs -a "$DEV"

# --- 2. partition ---

echo "[2/7] Creating GPT layout (256MB FAT32 ESP + 999G unallocated)..."
parted -s "$DEV" mklabel gpt
parted -s "$DEV" mkpart AGNOS-BOOT fat32 1MiB 256MiB
parted -s "$DEV" set 1 esp on
partprobe "$DEV"
sleep 1

# --- 3. format ---

echo "[3/7] Formatting $PART as FAT32 (label AGNOSBOOT)..."
mkfs.fat -F32 -n AGNOSBOOT "$PART"

# --- 4. mount ---

echo "[4/7] Mounting $PART at $MOUNT_POINT..."
mkdir -p "$MOUNT_POINT"
mount "$PART" "$MOUNT_POINT"

# --- 5. grub install ---

echo "[5/7] Installing GRUB (EFI removable mode, no NVRAM entry)..."
grub-install \
    --target=x86_64-efi \
    --efi-directory="$MOUNT_POINT" \
    --boot-directory="${MOUNT_POINT}/boot" \
    --removable \
    --no-nvram

# --- 6. copy AGNOS files ---

echo "[6/7] Copying AGNOS kernel + initramfs..."
cp "$KERNEL_SRC" "${MOUNT_POINT}/boot/agnos"
cp "$INITRAMFS_SRC" "${MOUNT_POINT}/boot/initramfs.cpio.gz"

# --- 7. grub.cfg ---

echo "[7/7] Writing GRUB config..."
cat > "${MOUNT_POINT}/boot/grub/grub.cfg" <<'EOF'
set timeout=3
set default=0

menuentry 'AGNOS — Closed Beta MVP (boot to shell)' {
    insmod multiboot
    insmod gzio
    multiboot /boot/agnos
    module    /boot/initramfs.cpio.gz
    boot
}

menuentry 'AGNOS — verbose serial (ttyS0,115200)' {
    insmod multiboot
    insmod gzio
    multiboot /boot/agnos console=ttyS0,115200
    module    /boot/initramfs.cpio.gz
    boot
}

menuentry 'AGNOS — kybernet harness mode (boot-test exit on phase 8)' {
    insmod multiboot
    insmod gzio
    multiboot /boot/agnos kybernet.harness=1
    module    /boot/initramfs.cpio.gz
    boot
}
EOF

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
echo "  $PART   256MB  FAT32 ESP  (GRUB + kernel + initramfs)"
echo "  unallocated  ~931GB  (reserved for future AGNOS data partition)"
echo ""
echo "Next steps:"
echo "  1. Reboot"
echo "  2. Hit your motherboard's boot-menu key (F8/F10/F12/Esc)"
echo "  3. Select the USB drive"
echo "  4. At GRUB, default boots straight to AGNOS in 3 seconds"
echo ""
echo "Iteration loop (update kernel/initramfs without re-installing GRUB):"
echo "  sudo mount $PART $MOUNT_POINT"
echo "  sudo cp <new-kernel> $MOUNT_POINT/boot/agnos"
echo "  sudo cp <new-initramfs> $MOUNT_POINT/boot/initramfs.cpio.gz"
echo "  sudo umount $MOUNT_POINT && sudo sync"
echo ""
