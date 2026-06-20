#!/bin/sh
# AGNOS net-sweep boot container — entrypoint.
#
# Boots the bundled agnos kernel under qemu-system-x86_64 + OVMF + gnoboot,
# with SLIRP user-mode networking forwarding the container's $LISTEN_PORT to
# the guest's :8080 (where a TCP_LISTEN_SMOKE kernel binds tcp_listen(8080)).
#
# This is Track-A step 3 of the Docker service-sweep harness
# (agnosticos/docs/development/planning/docker-service-sweep-harness.md):
# the "AGNOS-in-QEMU-in-Docker boot container". It reuses the boot recipe
# from agnos/scripts/tcp-listen-smoke.sh, wrapped for a container.
#
# Inputs (baked in at image build, under /opt/agnos):
#   agnos          — kernel (built TCP_LISTEN_SMOKE=1)
#   BOOTX64.EFI    — gnoboot UEFI app
#
# Env:
#   LISTEN_PORT    — container-side port forwarded to guest :8080 (default 8080)
#   QEMU_TIMEOUT   — seconds before the boot is torn down (default 90; TCG is slow)
#   MEM            — guest RAM (default 512M)
set -eu

KERNEL=/opt/agnos/agnos
GNOBOOT=/opt/agnos/BOOTX64.EFI
LISTEN_PORT="${LISTEN_PORT:-8080}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-90}"
MEM="${MEM:-512M}"
WORK=/tmp/agnos-boot

[ -f "$KERNEL" ]  || { echo "FATAL: kernel missing at $KERNEL"   >&2; exit 1; }
[ -f "$GNOBOOT" ] || { echo "FATAL: gnoboot missing at $GNOBOOT" >&2; exit 1; }

# --- OVMF firmware discovery (Debian ovmf package layout) -------------------
OVMF_CODE=""
for c in \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    /usr/share/qemu/OVMF_CODE.fd ; do
    [ -f "$c" ] && { OVMF_CODE="$c"; break; }
done
OVMF_VARS_SRC=""
for c in \
    /usr/share/OVMF/OVMF_VARS_4M.fd \
    /usr/share/OVMF/OVMF_VARS.fd \
    /usr/share/edk2/x64/OVMF_VARS.4m.fd \
    /usr/share/qemu/OVMF_VARS.fd ; do
    [ -f "$c" ] && { OVMF_VARS_SRC="$c"; break; }
done
[ -n "$OVMF_CODE" ] && [ -n "$OVMF_VARS_SRC" ] || {
    echo "FATAL: OVMF firmware not found in image" >&2; exit 1; }

# --- KVM if the host shared /dev/kvm, else TCG (slower but always works) ----
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    ACCEL="-enable-kvm -cpu host"
    echo "net-sweep: /dev/kvm present — hardware acceleration"
else
    ACCEL="-cpu max"
    echo "net-sweep: no /dev/kvm — TCG (software) emulation; boot is slower"
fi

# --- Assemble a minimal ESP-only boot image --------------------------------
rm -rf "$WORK"; mkdir -p "$WORK"
ESP="$WORK/esp.img"
dd if=/dev/zero of="$ESP" bs=1M count=64 status=none
parted -s "$ESP" mklabel gpt mkpart ESP fat32 1MiB 100% set 1 esp on
mformat -i "$ESP"@@1048576 -F
mmd    -i "$ESP"@@1048576 ::EFI
mmd    -i "$ESP"@@1048576 ::EFI/BOOT
mcopy  -i "$ESP"@@1048576 "$GNOBOOT" ::EFI/BOOT/BOOTX64.EFI
mmd    -i "$ESP"@@1048576 ::boot
mcopy  -i "$ESP"@@1048576 "$KERNEL"  ::boot/agnos
cp "$OVMF_VARS_SRC" "$WORK/vars.fd"; chmod +w "$WORK/vars.fd"

echo "net-sweep: booting agnos ($(stat -c %s "$KERNEL") B) — guest :8080 -> container :$LISTEN_PORT"
echo "net-sweep: connect from the host to the docker-published port to exercise tcp_accept"
echo "---------------------------------------------------------------------------"

# hostfwd binds the QEMU host (= this container) port $LISTEN_PORT to guest :8080.
# Docker's -p then publishes $LISTEN_PORT out of the container to the real host.
exec timeout "$QEMU_TIMEOUT" qemu-system-x86_64 \
    -machine q35 -m "$MEM" $ACCEL \
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
    -drive "if=pflash,format=raw,file=$WORK/vars.fd" \
    -drive "file=$ESP,format=raw,if=none,id=esp0" \
    -device "virtio-blk-pci,drive=esp0" \
    -netdev "user,id=u1,hostfwd=tcp::${LISTEN_PORT}-:8080" \
    -device "virtio-net-pci,netdev=u1" \
    -serial stdio -display none -no-reboot
