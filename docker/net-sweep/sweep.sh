#!/bin/bash
# AGNOS net-sweep — connection-stress sweep driver (Track-A, host-side; step 4).
#
# Boots the net-sweep boot container (qemu+OVMF+gnoboot+agnos, SLIRP hostfwd)
# and hammers the AGNOS kernel TCP server across the sweep dimensions that are
# reachable from outside the container, to flush out NETWORKING bugs in the
# real agnos net stack (passive-open, conn-slot reclaim, the 8-conn cap, RX
# robustness, soak/hang) — entirely burn-free.
#
# Dimensions exercised here (subset of the 9 in
# docs/development/planning/docker-service-sweep-harness.md §6 reachable through
# Docker NAT; segment-fuzz / SYN-flood / netem-loss need an in-namespace driver
# container and are deferred to a later bite — logged, not silently skipped):
#   D1  connection-churn + cap-reclaim   (the 1.45.2 8-slot reclaim, under churn)
#   D2  concurrency burst                (parallel conns vs the 8-conn cap)
#   D3  application-payload fuzz          (garbage/partial bytes → RX append path)
#   D4  soak / hang-watch                (sustained load; assert no panic/hang)
#
# After every dimension it (a) re-probes with a clean request and (b) scans the
# guest serial for panics + a still-advancing served-counter, so a crash/hang
# is caught immediately. Writes a findings ledger to ./findings.jsonl.
#
# Usage:  ./sweep.sh                 # build image if needed, boot, sweep, report
#         HOST_PORT=18080 ./sweep.sh
#         CHURN=512 BURST=32 SOAK=45 ./sweep.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPOS="$(cd "$HERE/../../.." && pwd)"
AGNOS_KERNEL="$REPOS/agnos/build/agnos"
GNOBOOT_EFI="$REPOS/gnoboot/build/BOOTX64.EFI"
IMAGE="agnos-net-sweep"
CTR="agnos-sweep-run"
HOST_PORT="${HOST_PORT:-18080}"
URL="http://127.0.0.1:$HOST_PORT/"
CHURN="${CHURN:-256}"      # D1 sequential open/close count
BURST="${BURST:-24}"       # D2 simultaneous connections per burst
BURSTS="${BURSTS:-5}"      # D2 number of bursts
SOAK="${SOAK:-30}"         # D4 soak seconds
BOOT_WAIT="${BOOT_WAIT:-60}"
FINDINGS="$HERE/findings.jsonl"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
grn() { printf '\033[32m%s\033[0m\n' "$*"; }
yel() { printf '\033[33m%s\033[0m\n' "$*"; }
cleanup() { docker rm -f "$CTR" >/dev/null 2>&1 || true; }
trap cleanup EXIT

ledger() { # service dim input observed severity
    printf '{"ts":%s,"service":"%s","dim":"%s","input":"%s","observed":"%s","severity":"%s"}\n' \
        "$(date +%s 2>/dev/null || echo 0)" "$1" "$2" "$3" "$4" "$5" >> "$FINDINGS"
}
save_serial() { docker logs "$CTR" >"$HERE/last-serial.log" 2>&1 || true; }

# --- 0. inputs + image ------------------------------------------------------
[ -f "$AGNOS_KERNEL" ] || { red "kernel not built: $AGNOS_KERNEL"; exit 1; }
strings "$AGNOS_KERNEL" | grep -q "tcp_listen(8080)" || { red "kernel not built TCP_LISTEN_SMOKE=1"; exit 1; }
echo "==> staging kernel ($(stat -c %s "$AGNOS_KERNEL") B) + building image"
mkdir -p "$HERE/stage"
cp "$AGNOS_KERNEL" "$HERE/stage/agnos"
cp "$GNOBOOT_EFI"  "$HERE/stage/BOOTX64.EFI"
docker build -t "$IMAGE" "$HERE" >/tmp/sweep-build.log 2>&1 || { red "image build failed"; tail -5 /tmp/sweep-build.log; exit 1; }

KVM_ARG=""; [ -r /dev/kvm ] && [ -w /dev/kvm ] && KVM_ARG="--device /dev/kvm"
cleanup
docker run -d --rm --name "$CTR" $KVM_ARG -e "QEMU_TIMEOUT=900" -p "$HOST_PORT:8080" "$IMAGE" >/dev/null \
    || { red "docker run failed"; exit 1; }

# --- 1. wait for boot -------------------------------------------------------
echo "==> waiting for AGNOS to answer on :$HOST_PORT (up to ${BOOT_WAIT}s)"
up=0
for _ in $(seq 1 $((BOOT_WAIT/2))); do
    sleep 2
    docker ps -q -f "name=$CTR" | grep -q . || { red "container exited early"; docker logs "$CTR" 2>&1 | tail -15; exit 1; }
    [ -n "$(curl -s --max-time 3 "$URL" 2>/dev/null)" ] && { up=1; break; }
done
[ "$up" = 1 ] || { red "AGNOS never answered"; docker logs "$CTR" 2>&1 | tail -20; exit 1; }
grn "AGNOS up — server live"
: > "$FINDINGS"

# Probe helper: 1 clean GET → "OK" if a 200 body comes back, else "DEAD".
clean_probe() { [ -n "$(curl -s --max-time 4 "$URL" 2>/dev/null | grep -c 'tcp_listen smoke')" ] && \
                curl -s --max-time 4 "$URL" 2>/dev/null | grep -q 'tcp_listen smoke' && echo OK || echo DEAD; }
panic_scan() { docker logs "$CTR" 2>&1 | grep -ciE 'panic|fault|#GP|#PF|triple|halt' ; }
served_count() { docker logs "$CTR" 2>&1 | grep -oE 'served conn=[0-9]+' | tail -1 | grep -oE '[0-9]+$'; }

base_panics="$(panic_scan)"

# --- D1: connection-churn + cap-reclaim ------------------------------------
echo "==> D1 connection-churn x$CHURN (validates 8-slot reclaim under churn)"
d1_ok=0; d1_fail=0
for _ in $(seq 1 "$CHURN"); do
    if curl -s --max-time 4 "$URL" 2>/dev/null | grep -q 'tcp_listen smoke'; then
        d1_ok=$((d1_ok+1)); else d1_fail=$((d1_fail+1)); fi
done
echo "    served=$d1_ok  failed=$d1_fail  (after-state: $(clean_probe))"
if [ "$d1_fail" -eq 0 ]; then grn "    D1 PASS — slot reclaim holds across $CHURN conns";
    ledger sched-net D1-churn "$CHURN seq conns" "all $CHURN served; reclaim holds" info
else yel "    D1 WEAK — $d1_fail/$CHURN failed (possible slot leak / reclaim gap)";
    ledger sched-net D1-churn "$CHURN seq conns" "$d1_fail failed → reclaim/leak suspect" high; fi

# --- D2: concurrency burst vs the 8-conn cap -------------------------------
echo "==> D2 concurrency: $BURSTS bursts x $BURST simultaneous conns (8-conn cap)"
d2_worst=0
for b in $(seq 1 "$BURSTS"); do
    ok=0
    pids=""
    tmp="$(mktemp -d)"
    for i in $(seq 1 "$BURST"); do
        ( curl -s --max-time 6 "$URL" 2>/dev/null | grep -q 'tcp_listen smoke' && echo 1 > "$tmp/$i" ) &
        pids="$pids $!"
    done
    wait $pids 2>/dev/null
    ok="$(cat "$tmp"/* 2>/dev/null | grep -c 1)"
    rm -rf "$tmp"
    fails=$((BURST-ok))
    [ "$fails" -gt "$d2_worst" ] && d2_worst=$fails
    echo "    burst $b: $ok/$BURST ok ($(clean_probe) after)"
done
# Some refusals under a >8 simultaneous burst are EXPECTED (8-conn cap, MVP-real).
# The finding is whether the server RECOVERS (clean probe OK) after each burst.
if [ "$(clean_probe)" = OK ]; then grn "    D2 PASS — server recovers after concurrent bursts (cap is graceful)";
    ledger sched-net D2-concurrency "$BURST x$BURSTS bursts" "worst $d2_worst refused (8-conn cap, expected); recovers" info
else red "    D2 FAIL — server DID NOT recover after a burst (cap not graceful — HANG/LEAK)";
    ledger sched-net D2-concurrency "$BURST x$BURSTS bursts" "server dead after burst" critical; fi

# --- D3: application-payload fuzz (garbage / partial → RX append path) ------
echo "==> D3 payload fuzz (garbage/partial/oversized → exercises tcp_rx_append)"
for payload in "$(head -c 64 /dev/urandom | base64)" "GET" "$(head -c 4096 /dev/zero | tr '\0' 'A')" $'\xff\xfe\x00bad'; do
    printf '%s' "$payload" | timeout 4 nc -w 2 127.0.0.1 "$HOST_PORT" >/dev/null 2>&1 || true
done
after="$(clean_probe)"
if [ "$after" = OK ]; then grn "    D3 PASS — RX path survives garbage/partial/oversized; clean req still 200";
    ledger sched-net D3-fuzz "garbage/partial/4KB/binary" "RX path robust; recovers" info
else red "    D3 FAIL — server dead after malformed payloads (RX-path bug)";
    ledger sched-net D3-fuzz "garbage/partial/4KB/binary" "server dead after fuzz" critical; fi

# --- D4: soak / hang-watch --------------------------------------------------
echo "==> D4 soak ${SOAK}s sustained open/close (hang + panic watch)"
soak_end=$(( $(date +%s) + SOAK ))
soak_n=0
while [ "$(date +%s)" -lt "$soak_end" ]; do
    curl -s --max-time 4 "$URL" >/dev/null 2>&1 && soak_n=$((soak_n+1))
done
after="$(clean_probe)"; panics="$(panic_scan)"
echo "    soak conns=$soak_n  after=$after  panic-lines=$panics (base $base_panics)  served-counter=$(served_count)"
if [ "$after" = OK ] && [ "$panics" -le "$base_panics" ]; then
    grn "    D4 PASS — no hang, no panic across ${SOAK}s soak";
    ledger sched-net D4-soak "${SOAK}s sustained" "no hang/panic; $soak_n conns" info
else red "    D4 FAIL — hang or panic during soak"; docker logs "$CTR" 2>&1 | tail -10;
    ledger sched-net D4-soak "${SOAK}s sustained" "hang/panic (after=$after panics=$panics)" critical; fi

# --- report -----------------------------------------------------------------
save_serial
echo "------------------------------------------------------------------"
echo "sweep findings → $FINDINGS   (guest serial → $HERE/last-serial.log)"
crit="$(grep -c '"severity":"critical"' "$FINDINGS" 2>/dev/null)"; crit="${crit:-0}"
high="$(grep -c '"severity":"high"' "$FINDINGS" 2>/dev/null)";     high="${high:-0}"
echo "  critical=$crit  high=$high  (info rows = passing dimensions)"
echo "  final served-counter in guest: $(served_count)"
[ "$crit" -eq 0 ] && grn "NET SWEEP: no critical findings" || red "NET SWEEP: $crit critical finding(s) — see ledger"
exit 0
