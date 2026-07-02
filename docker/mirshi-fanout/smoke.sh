#!/usr/bin/env bash
# smoke.sh — the vehicle gate: build the agnos-mirshi-fanout image, then run each
# staged tool once under mirshi (no QEMU) and assert it produces output + exits 0,
# plus a small concurrent fan-out. Mirrors mirshi/docker/smoke.sh for the
# ecosystem tool set. CI-runnable (needs docker + the sibling tool ELFs built).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
img="${IMG:-agnos-mirshi-fanout}"
caps=(--cap-add=SYS_PTRACE --security-opt seccomp=unconfined)

"$here/build.sh"

run() { docker run --rm "${caps[@]}" "$img" "$@" 2>/dev/null; }
fail=0

echo "== iam (info-getter band: uname/sysinfo/getuid + native CPUID) =="
if run /bin/iam | grep -q "AGNOS"; then
    echo "OK: iam renders the AGNOS system card"
else
    echo "FAIL: iam did not render"; fail=1
fi

echo "== kii (fs read + winsize + ANSI render, positional arg) =="
bytes="$(run /bin/kii /data/ramgon.png | wc -c)"
if [ "$bytes" -gt 1000 ]; then
    echo "OK: kii renders ($bytes bytes of ANSI art)"
else
    echo "FAIL: kii produced $bytes bytes"; fail=1
fi

echo "== fanout (8x iam, concurrent, no QEMU) =="
if "$here/fanout.sh" 8 /bin/iam >/dev/null; then
    echo "OK: 8-container iam fan-out"
else
    echo "FAIL: fan-out"; fail=1
fi

if [ "$fail" -eq 0 ]; then
    echo "== mirshi-fanout smoke PASSED =="
else
    echo "== mirshi-fanout smoke FAILED =="; exit 1
fi
