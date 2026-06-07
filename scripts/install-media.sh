#!/bin/bash
# install-media.sh — provision or refresh an AGNOS boot+root medium (USB or internal disk).
#
# Evolution of install-usb.sh. Adds two things the iron loop needed:
#   - --update-fs : refresh /bin/agnsh (+ any staged rootfs files) on the agnos-fs WITHOUT a
#                   wipe. (install-usb.sh's full provision never seeded /bin/agnsh and --update
#                   was ESP-only, so this used to be a manual mount-and-copy every agnsh change.)
#   - LABEL targeting for the update modes, so they hit whatever disk holds AGNOSBOOT / agnos-fs
#     — e.g. the internal NVMe (nvme0n1: p1 AGNOSBOOT ESP, p2 agnos-fs root, p3 fstest).
#
# gnoboot at EFI/BOOT/BOOTX64.EFI + agnos kernel at /boot/agnos. UEFI loads gnoboot; gnoboot
# loads the kernel and hands off via the sovereign boot-info struct (RDI=&boot_info, magic
# 0x41474E4F='AGNO'). No GRUB.
#
# Modes:
#   sudo ./scripts/install-media.sh /dev/sdX            FULL PROVISION (WIPES the whole disk). Guarded:
#                                                        refuses the disk holding / or /boot, refuses a
#                                                        mounted disk, refuses a partition target; fails
#                                                        CLOSED if it can't identify the system disk.
#   sudo ./scripts/install-media.sh --update [DEV]       ESP refresh (gnoboot+kernel+initramfs), no wipe.
#                                                        Targets AGNOSBOOT by label unless DEV given.
#   sudo ./scripts/install-media.sh --update-fs [PART]   agnos-fs refresh (build/rootfs/* incl /bin/agnsh),
#                                                        no wipe. Targets agnos-fs by label unless PART given.
#   sudo ./scripts/install-media.sh --update-all         ESP + agnos-fs, both by label, no wipe.
#
# Stage first:  (cd ../agnos && ./scripts/stage-agnsh.sh --build && ./scripts/stage-tools.sh --build)
#
# Host-side bash; destructive disk ops need root. No Linux initramfs is built — gnoboot loads an
# OPTIONAL sovereign INDR \boot\initramfs if one is staged at build/initramfs; otherwise the kernel
# mounts agnos-fs straight off NVMe (see install_initramfs below).

set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

# --- paths ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KERNEL_SRC="${KERNEL_SRC:-${REPO_ROOT}/../agnos/build/agnos}"
GNOBOOT_SRC="${GNOBOOT_SRC:-${REPO_ROOT}/../gnoboot/build/BOOTX64.EFI}"
# Sovereign initramfs ONLY (gnoboot loads \boot\initramfs, INDR format, OPTIONAL). NEVER a Linux
# cpio.gz. Default points at a non-.gz sovereign artifact; if it doesn't exist the boot proceeds
# without an initramfs (gnoboot: absent → phys/size 0; the kernel mounts the agnos-fs from NVMe).
INITRAMFS_SRC="${INITRAMFS_SRC:-${SCRIPT_DIR}/build/initramfs}"
ROOTFS_STAGE="${ROOTFS_STAGE:-${REPO_ROOT}/../agnos/build/rootfs}"   # stage-agnsh.sh → build/rootfs/bin/agnsh
MOUNT_POINT="/mnt/agnos-esp"
MOUNT_POINT_DATA="/mnt/agnos-fs"

# Self-clean: an aborted run must not leave a partition mounted (a stale mount can otherwise be
# silently reused and redirect writes to the wrong device on the next run).
cleanup() {
    umount "${MOUNT_POINT:-}"      2>/dev/null || true
    umount "${MOUNT_POINT_DATA:-}" 2>/dev/null || true
}
trap cleanup EXIT

# --- helpers ---

require_file() { [[ -f "$1" ]] || die "$2 not found at $1"; }

# Whole-disk kernel name (e.g. sda) backing a node, normalized through symlinks. A partition →
# its parent disk; a whole disk → its own basename (PKNAME of a disk is empty).
disk_base_of() {
    local n d
    n="$(readlink -f "$1" 2>/dev/null || echo "$1")"
    d="$(lsblk -no PKNAME "$n" 2>/dev/null | head -1)"
    [[ -z "$d" ]] && d="$(basename "$n")"
    echo "$d"
}

# Refuse a WHOLE-DISK target for the update modes — they expect a PARTITION (the
# ESP / agnos-fs), and mounting a disk fails with a cryptic "bad superblock". A
# whole disk's disk_base_of equals its own basename (no parent). Die with the fix:
# omit the arg (label auto-resolve) or pass the partition. Belt for the common
# `--update /dev/nvme0n1` (disk) vs the needed /dev/nvme0n1p1 (ESP) slip.
refuse_whole_disk() {
    local node="$1" label="$2"
    if [[ "$(basename "$(readlink -f "$node")")" == "$(disk_base_of "$node")" ]]; then
        die "$node is a whole disk, not a partition. Omit the argument to auto-resolve the $label label, or pass the partition (e.g. ${node}p1)."
    fi
}

# Abort if $1 resolves to the disk holding the running / or /boot. FAILS CLOSED: if the system
# disk can't be determined, refuse rather than allow. Gates every mount-and-write path, not just
# the wipe — a cp onto the dev root/boot is destructive too.
refuse_system_disk() {
    local target_disk root_src boot_src root_disk boot_disk
    target_disk="$(disk_base_of "$1")"
    [[ -n "$target_disk" ]] || die "cannot resolve a backing disk for $1 — refusing (fail-closed)."
    root_src="$(findmnt -no SOURCE / 2>/dev/null || true)"
    [[ -n "$root_src" ]] || die "cannot determine the running root device — refusing (fail-closed)."
    root_disk="$(disk_base_of "$root_src")"
    [[ -n "$root_disk" ]] || die "cannot resolve the disk backing / ($root_src) — refusing (fail-closed)."
    [[ "$target_disk" == "$root_disk" ]] \
        && die "refusing: $1 is on /dev/$root_disk, which holds the running root filesystem (/ = $root_src)."
    boot_src="$(findmnt -no SOURCE /boot 2>/dev/null || true)"   # /boot may not be a separate mount
    if [[ -n "$boot_src" ]]; then
        boot_disk="$(disk_base_of "$boot_src")"
        [[ -n "$boot_disk" ]] || die "cannot resolve the disk backing /boot ($boot_src) — refusing (fail-closed)."
        [[ "$target_disk" == "$boot_disk" ]] \
            && die "refusing: $1 is on /dev/$boot_disk, which holds the running /boot ($boot_src)."
    fi
    return 0   # MUST be explicit: a trailing short-circuited `&& die` would otherwise leave the
               # function's status non-zero on the SAFE path and set -e would kill the script silently.
}

# Abort if the whole disk backing $1 has ANY mounted partition. Fails closed on enumeration error.
refuse_if_mounted() {
    local disk m rc
    disk="$(disk_base_of "$1")"
    m="$(lsblk -nro MOUNTPOINTS "/dev/$disk" 2>/dev/null)"; rc=$?
    [[ $rc -ne 0 ]] && die "cannot enumerate mounts on /dev/$disk — refusing (fail-closed)."
    m="$(printf '%s\n' "$m" | grep -v '^$' | head -8 || true)"
    if [[ -n "$m" ]]; then
        echo "Mounted partitions on /dev/$disk:" >&2; echo "$m" >&2
        die "refusing — /dev/$disk has mounted partitions (unmount them first if you really mean it)."
    fi
    return 0
}

# Resolve a filesystem label to exactly one partition, or die. Refuses ambiguity (the USB+NVMe
# dual-medium case where two filesystems carry the same label).
resolve_label() {
    local label="$1" hits n
    hits="$(lsblk -nro NAME,LABEL 2>/dev/null | awk -v l="$label" '$2==l{print "/dev/"$1}')"
    n="$(printf '%s\n' "$hits" | grep -c . || true)"
    [[ "$n" -eq 0 ]] && die "no filesystem labeled '$label' — provision first, or pass the partition explicitly."
    if [[ "$n" -gt 1 ]]; then
        echo "Multiple filesystems carry label '$label':" >&2; printf '%s\n' "$hits" >&2
        die "ambiguous label '$label' — pass the partition explicitly (e.g. /dev/nvme0n1p2)."
    fi
    printf '%s\n' "$hits" | head -1
}

# Verify a partition isn't already mounted somewhere other than our mountpoint.
refuse_mounted_elsewhere() {
    local part="$1" mp="$2" tgt
    tgt="$(findmnt -rn -S "$part" -o TARGET 2>/dev/null | head -1 || true)"
    [[ -n "$tgt" && "$tgt" != "$mp" ]] && die "$part is already mounted at $tgt — unmount it first."
    return 0
}

# Mount $1 at $2. If something is already mounted there it MUST be $1 — never silently reuse a
# stale mount of a different device (that is the one path that writes bytes to the wrong disk).
mount_at() {
    mkdir -p "$2"
    if mountpoint -q "$2"; then
        local cur
        cur="$(findmnt -no SOURCE "$2" 2>/dev/null || true)"
        [[ "$(readlink -f "$cur" 2>/dev/null)" == "$(readlink -f "$1" 2>/dev/null)" ]] \
            || die "$2 already holds '$cur', not '$1' — refusing to reuse a stale mount."
        echo "  (already mounted at $2 — verified same device)"
    else
        mount "$1" "$2"
    fi
}

umount_safe() { umount "$1" 2>/dev/null || { sync; sleep 1; umount -l "$1" 2>/dev/null || true; }; }

# Install the SOVEREIGN initramfs onto an ESP mount and PURGE any stale Linux cpio.gz a prior
# install left behind. gnoboot loads \boot\initramfs (INDR format) and treats it as OPTIONAL —
# AGNOS is not Linux, so this never ships a cpio.gz.
install_initramfs() {
    local mp="$1"
    rm -f "${mp}/boot/initramfs.cpio.gz"        # purge Linux garbage from older installs
    if [[ -f "$INITRAMFS_SRC" ]]; then
        cp "$INITRAMFS_SRC" "${mp}/boot/initramfs"
        echo "  + sovereign \\boot\\initramfs ($(stat -c%s "$INITRAMFS_SRC") bytes)"
    else
        rm -f "${mp}/boot/initramfs"
        echo "  (no sovereign initramfs — boot proceeds without one; gnoboot \\boot\\initramfs is optional)"
    fi
    return 0
}

# --- ESP refresh (kernel + gnoboot + initramfs), no wipe ---

esp_update() {
    local esp="$1"
    [[ -b "$esp" ]] || die "ESP partition not found: $esp (provision first, or pass the right partition)."
    refuse_whole_disk "$esp" AGNOSBOOT
    refuse_system_disk "$esp"
    refuse_mounted_elsewhere "$esp" "$MOUNT_POINT"
    require_file "$KERNEL_SRC"  "AGNOS kernel"
    require_file "$GNOBOOT_SRC" "gnoboot binary"

    echo "=== ESP refresh ==="
    echo "Target ESP: $esp  (disk /dev/$(disk_base_of "$esp"))"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$esp" 2>/dev/null || true
    echo "  gnoboot:   $GNOBOOT_SRC ($(stat -c%s "$GNOBOOT_SRC") bytes)"
    echo "  kernel:    $KERNEL_SRC ($(stat -c%s "$KERNEL_SRC") bytes)"

    mount_at "$esp" "$MOUNT_POINT"
    [[ -d "${MOUNT_POINT}/EFI/BOOT" ]] || die "$esp has no /EFI/BOOT — not a provisioned AGNOS ESP. Full-provision first."
    cp "$GNOBOOT_SRC" "${MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI"
    mkdir -p "${MOUNT_POINT}/boot"
    cp "$KERNEL_SRC"  "${MOUNT_POINT}/boot/agnos"
    install_initramfs "$MOUNT_POINT"
    sync
    echo "✓ ESP refreshed on $esp (gnoboot + kernel)."
    umount_safe "$MOUNT_POINT"
}

# --- agnos-fs refresh (stage /bin/agnsh + rootfs files), no wipe ---

fs_update() {
    local part="$1"
    [[ -b "$part" ]] || die "agnos-fs partition not found: $part (provision first, or pass the right partition)."
    refuse_whole_disk "$part" agnos-fs
    refuse_system_disk "$part"
    refuse_mounted_elsewhere "$part" "$MOUNT_POINT_DATA"
    [[ -d "$ROOTFS_STAGE" ]] || die "staged rootfs not found at $ROOTFS_STAGE — run: (cd ../agnos && ./scripts/stage-agnsh.sh --build)"
    [[ -f "${ROOTFS_STAGE}/bin/agnsh" ]] || die "${ROOTFS_STAGE}/bin/agnsh missing — run: (cd ../agnos && ./scripts/stage-agnsh.sh --build)"

    echo "=== agnos-fs refresh (no wipe) ==="
    echo "Target agnos-fs: $part  (disk /dev/$(disk_base_of "$part"))"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$part" 2>/dev/null || true
    echo "  staged /bin ← ${ROOTFS_STAGE}/bin/ :"
    for f in "${ROOTFS_STAGE}/bin/"*; do
        [[ -f "$f" ]] && echo "    $(basename "$f") ($(stat -c%s "$f") bytes)"
    done

    mount_at "$part" "$MOUNT_POINT_DATA"
    # Merge the staged tree in (cp -a is overwrite-matching-paths, never a mirror/delete — existing
    # write-test artifacts + seed files survive). cp -a preserves the +x bits stage-*.sh set; the
    # explicit chmod is belt-and-suspenders across the whole /bin — agnsh (PID 1) + the AGNOS-tic
    # tools (bnrmr/cmdrs/…) must all stay executable on the ext4 agnos-fs for exec-from-disk.
    cp -a "${ROOTFS_STAGE}/." "${MOUNT_POINT_DATA}/"
    chmod +x "${MOUNT_POINT_DATA}/bin/"*
    sync
    echo "  on-disk /bin now: $(ls "${MOUNT_POINT_DATA}/bin/" 2>/dev/null | tr '\n' ' ')"
    echo "✓ agnos-fs refreshed on $part — /bin (agnsh + staged tools) updated, data partition NOT wiped."
    umount_safe "$MOUNT_POINT_DATA"
}

# --- arg parse ---

MODE="provision"
case "${1:-}" in
    --update|-u)  MODE="update";     shift ;;
    --update-fs)  MODE="update-fs";  shift ;;
    --update-all) MODE="update-all"; shift ;;
    -h|--help|"")
        [[ "${1:-}" == "" ]] && echo "No mode/device given."
        cat <<EOF
Usage:
  sudo $0 /dev/sdX            full provision (WIPES the whole disk) — guarded
  sudo $0 --update [DEV]      ESP refresh (gnoboot + kernel; optional sovereign initramfs), no wipe   [default: label AGNOSBOOT]
  sudo $0 --update-fs [PART]  agnos-fs refresh (/bin/agnsh + staged rootfs), no wipe   [default: label agnos-fs]
  sudo $0 --update-all        ESP + agnos-fs, both by label, no wipe

Stage first:  (cd ../agnos && ./scripts/stage-agnsh.sh --build && ./scripts/stage-tools.sh --build)

Block devices:
EOF
        lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS 2>/dev/null | head -25
        exit 0 ;;
esac

ARG="${1:-}"

# --- non-destructive update modes (every write path runs refuse_system_disk; label-targeted by default) ---

if [[ "$MODE" == "update-all" ]]; then
    [[ -z "$ARG" ]] || die "--update-all is label-only (it drives both AGNOSBOOT and agnos-fs by label). Use --update DEV / --update-fs PART for an explicit target."
    esp_update "$(readlink -f "$(resolve_label AGNOSBOOT)")"
    fs_update  "$(readlink -f "$(resolve_label agnos-fs)")"
    echo ""; echo "Done. Reboot to run the refreshed kernel + /bin/agnsh."
    exit 0
fi

if [[ "$MODE" == "update" ]]; then
    if [[ -n "$ARG" ]]; then ESP="$(readlink -f "$ARG")"; else ESP="$(readlink -f "$(resolve_label AGNOSBOOT)")"; fi
    esp_update "$ESP"
    echo ""; echo "Done. Reboot to run the refreshed kernel."
    exit 0
fi

if [[ "$MODE" == "update-fs" ]]; then
    if [[ -n "$ARG" ]]; then FSP="$(readlink -f "$ARG")"; else FSP="$(readlink -f "$(resolve_label agnos-fs)")"; fi
    fs_update "$FSP"
    echo ""; echo "Done. Reboot to run the refreshed /bin/agnsh."
    exit 0
fi

# ============================================================================
# FULL PROVISION (destructive). Everything below WIPES the target whole disk.
# ============================================================================

DEV="$ARG"
[[ -n "$DEV" ]] || die "no device given for full provision."
[[ -b "$DEV" ]] || die "$DEV is not a block device."
DEV="$(readlink -f "$DEV")"                                   # resolve symlinks BEFORE the guards
[[ "$(lsblk -no TYPE "$DEV" 2>/dev/null | head -1)" == disk ]] \
    || die "provision target must be a whole disk, got: $DEV (a partition?). Pass /dev/sdX or /dev/nvme0n1."

# Hard safety guards BEFORE anything destructive.
refuse_system_disk "$DEV"
refuse_if_mounted "$DEV"

for tool in parted mkfs.fat mkfs.ext4 wipefs partprobe; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool '$tool' not found"
done
require_file "$KERNEL_SRC"  "AGNOS kernel"
require_file "$GNOBOOT_SRC" "gnoboot binary"

case "$DEV" in
    *nvme*|*mmcblk*|*loop*) P1="${DEV}p1"; P2="${DEV}p2"; P3="${DEV}p3" ;;
    *)                      P1="${DEV}1";  P2="${DEV}2";  P3="${DEV}3"  ;;
esac

IS_REMOVABLE="$(cat "/sys/block/$(basename "$DEV")/removable" 2>/dev/null || echo 0)"

echo "=== AGNOS full provision (gnoboot, no GRUB) ==="
echo "Target whole disk: $DEV   (removable=$IS_REMOVABLE)"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL "$DEV" 2>/dev/null || true
udevadm info --query=property --name="$DEV" 2>/dev/null | grep -E "ID_BUS|ID_MODEL|ID_VENDOR" || true
echo ""
echo "Will create: p1 256MiB FAT32 AGNOSBOOT (ESP) | p2 25GiB ext4 agnos-fs | p3 512MiB FAT32 fstest"
echo "ESP gets: gnoboot + kernel ($(stat -c%s "$KERNEL_SRC") B)  [+ sovereign \\boot\\initramfs if present]."
if [[ -f "${ROOTFS_STAGE}/bin/agnsh" ]]; then
    echo "agnos-fs gets: /bin/agnsh ($(stat -c%s "${ROOTFS_STAGE}/bin/agnsh") B) + seed files."
else
    echo "agnos-fs gets: seed files only (run stage-agnsh.sh --build first to include /bin/agnsh)."
fi
echo ""
echo "*** THIS WILL WIPE ALL DATA ON $DEV ***"
[[ "$IS_REMOVABLE" != "1" ]] && echo "*** $DEV is a NON-REMOVABLE (internal) disk — confirm this is the AGNOS disk. ***"
echo "  (To only refresh an already-provisioned medium, use --update / --update-fs / --update-all — no wipe.)"
echo ""
read -r -p "Type 'WIPE $DEV' exactly to proceed: " confirm
[[ "$confirm" == "WIPE $DEV" ]] || die "aborted (confirmation did not match)."

echo ""
echo "[1/8] Wiping partition table on $DEV..."
wipefs -a "$DEV"

echo "[2/8] Creating GPT layout..."
parted -s "$DEV" mklabel gpt
parted -s "$DEV" mkpart AGNOS-BOOT fat32 1MiB 256MiB
parted -s "$DEV" set 1 esp on
parted -s "$DEV" mkpart agnos-fs ext4 256MiB 25856MiB
parted -s "$DEV" mkpart fstest fat32 25856MiB 26368MiB
partprobe "$DEV"
sleep 1

echo "[3/8] Formatting $P1 FAT32 (label AGNOSBOOT)..."
mkfs.fat -F32 -n AGNOSBOOT "$P1"
echo "[4/8] Formatting $P2 ext4 (label agnos-fs)..."
mkfs.ext4 -F -L agnos-fs "$P2"
echo "      Formatting $P3 FAT32 (label fstest)..."
mkfs.fat -F32 -n fstest "$P3"

echo "[5/8] Mounting ESP + copying gnoboot + kernel..."
mount_at "$P1" "$MOUNT_POINT"
mkdir -p "${MOUNT_POINT}/EFI/BOOT" "${MOUNT_POINT}/boot"
cp "$GNOBOOT_SRC" "${MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI"
cp "$KERNEL_SRC"  "${MOUNT_POINT}/boot/agnos"
install_initramfs "$MOUNT_POINT"
sync; umount_safe "$MOUNT_POINT"

echo "[6/8] Mounting agnos-fs + seeding /bin/agnsh + sample files..."
mount_at "$P2" "$MOUNT_POINT_DATA"
PROV_DATE="$(date -u +%Y-%m-%d 2>/dev/null || echo provisioned)"
if [[ -f "${ROOTFS_STAGE}/bin/agnsh" ]]; then
    mkdir -p "${MOUNT_POINT_DATA}/bin"
    cp "${ROOTFS_STAGE}/bin/agnsh" "${MOUNT_POINT_DATA}/bin/agnsh"
    chmod +x "${MOUNT_POINT_DATA}/bin/agnsh"
    echo "      seeded /bin/agnsh ($(stat -c%s "${MOUNT_POINT_DATA}/bin/agnsh") bytes)"
fi
printf 'hello from agnos ext4 seed   provisioned %s\n' "$PROV_DATE" > "${MOUNT_POINT_DATA}/hello.txt"
printf 'welcome — secondary hello on agnos-fs root   provisioned %s\n' "$PROV_DATE" > "${MOUNT_POINT_DATA}/welcome.txt"
mkdir -p "${MOUNT_POINT_DATA}/agnos"
printf 'notes from the /agnos/ subfolder   provisioned %s\n' "$PROV_DATE" > "${MOUNT_POINT_DATA}/agnos/notes.txt"
sync; umount_safe "$MOUNT_POINT_DATA"

echo "[7/8] Sync..."; sync
echo "[8/8] Done."
echo ""
echo "============================================================"
echo "✓ AGNOS medium ready at $DEV"
echo "  p1 AGNOSBOOT (ESP)  p2 agnos-fs (root, /bin/agnsh)  p3 fstest (FAT)"
echo "============================================================"
echo ""
echo "Iteration loop (no re-provision):"
echo "  (cd ../agnos && sh scripts/build.sh && ./scripts/stage-agnsh.sh --build)"
echo "  sudo $0 --update-all      # ESP kernel + agnos-fs /bin/agnsh, by label, no wipe"
