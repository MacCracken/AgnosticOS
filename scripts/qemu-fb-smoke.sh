#!/bin/sh
# qemu-fb-smoke.sh — headless Path-C boot smoke for AGNOS.
#
# Sibling to qemu-fb-visual.sh. Same disk-image build (gnoboot EFI +
# agnos kernel in an ESP on a 64MB GPT disk), but runs QEMU without a
# graphical display, captures serial to a log, and polls the log for an
# EXPECT string. Returns 0 on match, 1 on miss / timeout.
#
# Intended use: pre-burn validation in a cycle's build gates. Verifies
# the kernel boots through gnoboot's Path-C handoff, reaches the shell
# prompt, and the new fb/serial diagnostic lines we expect for this
# cycle land in the serial transcript. NOT a substitute for iron — the
# canonical smoke targets are `AGNOS shell` (kernel up) plus whatever
# cycle-specific diagnostic line proves the bundle compiled correctly.
#
# Usage:
#   scripts/qemu-fb-smoke.sh                                # default EXPECT=AGNOS shell
#   EXPECT="fb: WC verified" scripts/qemu-fb-smoke.sh       # 1.30.11: verify PAT readback fires
#   EXPECT="fb: pf="          scripts/qemu-fb-smoke.sh      # 1.30.11: verify pf diagnostic prints
#   QEMU_TIMEOUT=120          scripts/qemu-fb-smoke.sh      # extend deadline (default 90s)
#   AGNOS_KERNEL=/path/to/agnos scripts/qemu-fb-smoke.sh    # smoke a different build
#
# Requires: qemu-system-x86_64, parted, mtools, edk2-ovmf.
#
# Exit codes:
#   0 — EXPECT matched in serial transcript before timeout
#   1 — EXPECT not matched within QEMU_TIMEOUT seconds
#   2 — toolchain / asset prerequisites missing

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGNOS_REPO="${AGNOS_REPO:-$ROOT/../agnos}"
GNOBOOT_REPO="${GNOBOOT_REPO:-$ROOT/../gnoboot}"
AGNOS_KERNEL="${AGNOS_KERNEL:-$AGNOS_REPO/build/agnos}"
GNOBOOT_EFI="${GNOBOOT_EFI:-$GNOBOOT_REPO/build/BOOTX64.EFI}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-90}"
EXPECT="${EXPECT:-AGNOS shell}"
SERIAL_LOG="${SERIAL_LOG:-/tmp/agnos-qemu-smoke-serial.log}"
QEMU_RES="${QEMU_RES:-1920x1080}"
QEMU_VGA="${QEMU_VGA:-std}"
POLL_INTERVAL="${POLL_INTERVAL:-2}"

# OVMF firmware probes (Arch + Ubuntu paths).
OVMF_CODE=""
OVMF_VARS_SRC=""
for c in \
    /usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/qemu/OVMF.fd \
    ; do
    if [ -f "$c" ]; then OVMF_CODE="$c"; break; fi
done
for v in \
    /usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd \
    /usr/share/OVMF/OVMF_VARS.fd \
    ; do
    if [ -f "$v" ]; then OVMF_VARS_SRC="$v"; break; fi
done

# Prerequisites.
for tool in qemu-system-x86_64 parted mformat mmd mcopy; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool not in PATH" >&2; exit 2; }
done
[ -n "$OVMF_CODE" ]     || { echo "ERROR: OVMF_CODE.fd not found" >&2; exit 2; }
[ -n "$OVMF_VARS_SRC" ] || { echo "ERROR: OVMF_VARS.fd not found" >&2; exit 2; }
[ -f "$AGNOS_KERNEL" ]  || { echo "ERROR: $AGNOS_KERNEL not found — build agnos first" >&2; exit 2; }
[ -f "$GNOBOOT_EFI" ]   || { echo "ERROR: $GNOBOOT_EFI not found — build gnoboot first" >&2; exit 2; }

# Pre-flight the serial log path (same root-owned-file footgun as qemu-fb-visual.sh).
if [ -e "$SERIAL_LOG" ] && [ ! -w "$SERIAL_LOG" ]; then
    echo "ERROR: serial log path '$SERIAL_LOG' is not writable by $(whoami)." >&2
    echo "  Fix: sudo rm '$SERIAL_LOG'  (then re-run)" >&2
    exit 2
fi
# Truncate any prior transcript so the grep below sees only this run.
: > "$SERIAL_LOG"

D=$(mktemp -d -t agnos-fb-smoke.XXXXXX)
trap 'rm -rf "$D"' EXIT
cd "$D"

echo "[1/3] Building 64MB GPT disk image with Path-C ESP layout..."
dd if=/dev/zero of=disk.img bs=1M count=64 status=none
parted -s disk.img mklabel gpt mkpart ESP fat32 1MiB 100% set 1 esp on >/dev/null 2>&1
mformat -i disk.img@@1048576 -F
mmd -i disk.img@@1048576 ::EFI
mmd -i disk.img@@1048576 ::EFI/BOOT
mmd -i disk.img@@1048576 ::boot
mcopy -i disk.img@@1048576 "$GNOBOOT_EFI" ::EFI/BOOT/BOOTX64.EFI
mcopy -i disk.img@@1048576 "$AGNOS_KERNEL" ::boot/agnos
echo "      gnoboot: $(stat -c%s "$GNOBOOT_EFI") bytes"
echo "      kernel : $(stat -c%s "$AGNOS_KERNEL") bytes"
echo "      EXPECT : '$EXPECT'"
echo "      log    : $SERIAL_LOG"

cp "$OVMF_VARS_SRC" vars.fd
chmod +w vars.fd

# VGA device args (same shape as qemu-fb-visual.sh — keeps the smoke
# path running at iron-realistic 1920x1080 unless overridden).
VGA_ARGS=""
if [ "$QEMU_RES" = "default" ] || [ "$QEMU_VGA" = "default" ]; then
    : # let qemu pick
else
    XRES="${QEMU_RES%x*}"
    YRES="${QEMU_RES#*x}"
    case "$QEMU_VGA" in
        std)    VGA_ARGS="-vga std -global VGA.xres=$XRES -global VGA.yres=$YRES" ;;
        virtio) VGA_ARGS="-vga none -device virtio-vga,xres=$XRES,yres=$YRES" ;;
        *)      echo "ERROR: QEMU_VGA='$QEMU_VGA' must be: std | virtio | default" >&2; exit 2 ;;
    esac
fi

echo "[2/3] Launching QEMU (headless, -display none) — deadline ${QEMU_TIMEOUT}s..."

# Background QEMU. `-display none -monitor none -serial file:` is the
# canonical headless triple — no graphical attach, no monitor I/O on
# host stdio, kernel serial flows into the log file. -no-reboot makes
# a triple-fault halt visible instead of looping.
qemu-system-x86_64 \
    -machine q35 -m 256M -cpu max \
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
    -drive "if=pflash,format=raw,file=vars.fd" \
    -drive "file=disk.img,format=raw" \
    -device qemu-xhci,id=xhci \
    -device usb-kbd,bus=xhci.0 \
    $VGA_ARGS \
    -serial file:"$SERIAL_LOG" \
    -display none \
    -monitor none \
    -no-reboot \
    >/dev/null 2>&1 &
QEMU_PID=$!

# Poll for EXPECT until match or deadline. Kills QEMU on either.
DEADLINE=$(( $(date +%s) + QEMU_TIMEOUT ))
MATCHED=0
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        # QEMU exited on its own (kernel halt / triple-fault). Final grep.
        break
    fi
    if grep -qF "$EXPECT" "$SERIAL_LOG" 2>/dev/null; then
        MATCHED=1
        break
    fi
    sleep "$POLL_INTERVAL"
done

# Final grep covers the post-exit case too.
if [ "$MATCHED" = 0 ] && grep -qF "$EXPECT" "$SERIAL_LOG" 2>/dev/null; then
    MATCHED=1
fi

# Tear down QEMU if still alive.
if kill -0 "$QEMU_PID" 2>/dev/null; then
    kill "$QEMU_PID" 2>/dev/null || true
    # Give it a moment to terminate cleanly, then SIGKILL if still around.
    sleep 1
    kill -9 "$QEMU_PID" 2>/dev/null || true
fi
wait "$QEMU_PID" 2>/dev/null || true

echo "[3/3] QEMU exited."

if [ "$MATCHED" = 1 ]; then
    echo "PASS: EXPECT='$EXPECT' matched in serial transcript"
    echo "      ($SERIAL_LOG)"
    exit 0
else
    echo "FAIL: EXPECT='$EXPECT' not matched within ${QEMU_TIMEOUT}s"
    echo ""
    echo "Last 30 lines of serial transcript:"
    echo "--- $SERIAL_LOG ---"
    tail -30 "$SERIAL_LOG" 2>/dev/null || echo "(serial log empty)"
    echo "--- end ---"
    exit 1
fi
