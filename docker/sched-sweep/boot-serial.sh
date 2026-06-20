#!/bin/sh
# AGNOS sched-sweep — generic boot-and-capture entrypoint.
#
# Boots a MOUNTED agnos kernel under qemu+OVMF+gnoboot and dumps the serial
# console to stdout, then exits at TIMEOUT. No networking / port-forward — the
# scheduler selftests (RING3 / THREAD / SMP) print their PASS markers to serial
# during boot, which the host runner greps. The kernel is mounted (not baked
# into the image) so ONE image serves every selftest build.
#
# Inputs (mounted read-only at /input):
#   /input/agnos        — the kernel to boot (built with the desired *_SELFTEST flag)
#   /input/BOOTX64.EFI  — gnoboot UEFI app
# Env:
#   SMP      — vCPU count (default 1; the SMP selftest wants 4)
#   TIMEOUT  — seconds before teardown (default 30)
#   MEM      — guest RAM (default 512M)
set -eu
KERNEL=/input/agnos
GNOBOOT=/input/BOOTX64.EFI
SMP="${SMP:-1}"
TIMEOUT="${TIMEOUT:-30}"
MEM="${MEM:-512M}"
WORK=/tmp/agnos-boot

[ -f "$KERNEL" ]  || { echo "FATAL: kernel missing at $KERNEL"   >&2; exit 1; }
[ -f "$GNOBOOT" ] || { echo "FATAL: gnoboot missing at $GNOBOOT" >&2; exit 1; }

# --- OVMF firmware discovery (Debian ovmf package layout) -------------------
OVMF_CODE=""
for c in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd \
         /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/qemu/OVMF_CODE.fd; do
    [ -f "$c" ] && { OVMF_CODE="$c"; break; }
done
OVMF_VARS_SRC=""
for c in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd \
         /usr/share/edk2/x64/OVMF_VARS.4m.fd /usr/share/qemu/OVMF_VARS.fd; do
    [ -f "$c" ] && { OVMF_VARS_SRC="$c"; break; }
done
[ -n "$OVMF_CODE" ] && [ -n "$OVMF_VARS_SRC" ] || { echo "FATAL: OVMF not found" >&2; exit 1; }

# --- KVM if shared (real timing variation — the point of the sweep), else TCG -
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    ACCEL="-enable-kvm -cpu host"
else
    ACCEL="-cpu max"
fi

# --- assemble a minimal ESP-only boot image --------------------------------
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

# -smp drives the scheduler under the requested core count; the selftests print
# their markers to -serial stdio, captured as this container's stdout.
#
# DONE_MARKERS (pipe-delimited) — early-exit once ALL have appeared on serial, so
# a run finishes when the selftest is done instead of waiting out the full
# TIMEOUT (agnos continues to a shell and never exits on its own). The awk echoes
# every line immediately (fflush) and exits when the marker set is exhausted;
# qemu then dies on SIGPIPE, with `timeout` as the backstop. Without DONE_MARKERS
# it just streams until TIMEOUT.
set +e
if [ -n "${DONE_MARKERS:-}" ]; then
    timeout "$TIMEOUT" qemu-system-x86_64 \
        -machine q35 -m "$MEM" $ACCEL -smp "$SMP" \
        -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
        -drive "if=pflash,format=raw,file=$WORK/vars.fd" \
        -drive "file=$ESP,format=raw,if=none,id=esp0" \
        -device "virtio-blk-pci,drive=esp0" \
        -serial stdio -display none -no-reboot 2>/dev/null \
    | awk -v M="$DONE_MARKERS" '
        BEGIN { n=split(M, a, "|"); for (i=1;i<=n;i++) need[a[i]]=1; left=n }
        { print; fflush() }
        { for (m in need) if (index($0, m)) { delete need[m]; left-- } }
        left==0 { exit }
      '
else
    timeout "$TIMEOUT" qemu-system-x86_64 \
        -machine q35 -m "$MEM" $ACCEL -smp "$SMP" \
        -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
        -drive "if=pflash,format=raw,file=$WORK/vars.fd" \
        -drive "file=$ESP,format=raw,if=none,id=esp0" \
        -device "virtio-blk-pci,drive=esp0" \
        -serial stdio -display none -no-reboot
fi
exit 0
