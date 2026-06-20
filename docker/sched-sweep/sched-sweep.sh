#!/bin/bash
# AGNOS scheduling sweep (Track-A, the scheduler half of the founder net+sched sweep).
#
# Boots each scheduler SELFTEST kernel N times under KVM inside Docker — in
# parallel batches, so host-scheduler jitter perturbs guest timing — and tallies
# the pass-rate. A selftest that passes on the host but is FLAKY here (pass-rate
# < 100%) is a timing-dependent scheduler RACE a single deterministic run misses.
# This is the scheduling analogue of net-sweep/sweep.sh; both are burn-free.
#
# Selftests (each its own kernel build; markers must ALL appear in serial):
#   ring3  RING3_SELFTEST=1   smp 1  -> "ring3: preempt OK" / "child exited" / "gate held"
#   thread THREAD_SELFTEST=1  smp 1  -> "thr: preempt OK"   / "gate held"
#   smp    (production)       smp 4  -> "smp: cpus online: 4" / "Activating scheduler" / "kybernet:"
#
# Usage:  ./sched-sweep.sh                 # build kernels + image, RUNS x each, report
#         RUNS=20 PAR=6 ./sched-sweep.sh
#         ONLY=ring3 ./sched-sweep.sh      # one selftest
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPOS="$(cd "$HERE/../../.." && pwd)"
AGNOS="$REPOS/agnos"
GNOBOOT_EFI="$REPOS/gnoboot/build/BOOTX64.EFI"
IMAGE="agnos-sched-sweep"
RUNS="${RUNS:-12}"
PAR="${PAR:-4}"
ONLY="${ONLY:-}"
FINDINGS="$HERE/sched-findings.jsonl"

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
yel(){ printf '\033[33m%s\033[0m\n' "$*"; }

[ -f "$GNOBOOT_EFI" ] || { red "gnoboot not built: $GNOBOOT_EFI"; exit 1; }

echo "==> building sched-sweep image"
docker build -t "$IMAGE" "$HERE" >/tmp/sched-image.log 2>&1 || { red "image build failed"; tail -6 /tmp/sched-image.log; exit 1; }

# IMPORTANT: agnos's scheduler selftests are TCG-only. Under KVM the boot timing
# differs and kybernet launches while the selftest procs are still alive, so the
# RING3/THREAD/SMP markers never print (a harness artifact, not a scheduler bug —
# documented in the attn11 session note + state.md). So TCG is the DEFAULT here;
# KVM=1 opts in (fast boot, but expect the selftests not to complete). TCG boot is
# slower → timeouts are scaled ×TMULT.
KVM=""
if [ -n "${KVM_OPT:-}" ] && { [ -r /dev/kvm ] && [ -w /dev/kvm ]; }; then
    KVM="--device /dev/kvm"; TMULT=1
    yel "==> KVM_OPT set — fast boot, but agnos scheduler selftests are TCG-only and may NOT complete under KVM"
else
    TMULT=3
    echo "==> TCG (default — scheduler selftests are TCG-only; KVM boot-timing races kybernet vs selftest procs)"
fi
: > "$FINDINGS"

# Build a kernel with the given flag assignment ("" = production) into build/agnos.
build_kernel() {
    ( cd "$AGNOS" && eval "${1:-} sh scripts/build.sh" ) >/tmp/sched-kbuild.log 2>&1 \
        || { red "    kernel build FAILED (${1:-production})"; tail -8 /tmp/sched-kbuild.log; return 1; }
}

# run_selftest  name  build-assign  smp  timeout  "marker1|marker2|..."
run_selftest() {
    local name="$1" build="$2" smp="$3" markers="$5"
    local to=$(( $4 * TMULT ))      # TCG boot is slower → scale the base timeout
    [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && return 0
    echo "==> [$name] building kernel (${build:-production}) ..."
    build_kernel "$build" || { printf '{"selftest":"%s","verdict":"BUILD-FAIL"}\n' "$name" >> "$FINDINGS"; return 1; }
    local stage logdir; stage="$(mktemp -d)"; logdir="$(mktemp -d)"
    cp "$AGNOS/build/agnos" "$stage/agnos"
    cp "$GNOBOOT_EFI" "$stage/BOOTX64.EFI"
    echo "    kernel $(stat -c %s "$stage/agnos") B — booting x$RUNS  (smp=$smp, par=$PAR, timeout=${to}s)"

    local i=0
    while [ "$i" -lt "$RUNS" ]; do
        local b=0
        while [ "$b" -lt "$PAR" ] && [ "$i" -lt "$RUNS" ]; do
            i=$((i+1))
            (
                out="$(docker run --rm $KVM -e SMP="$smp" -e TIMEOUT="$to" -e DONE_MARKERS="$markers" -v "$stage:/input:ro" "$IMAGE" 2>/dev/null)"
                ok=1; sIFS=$IFS; IFS='|'
                for m in $markers; do printf '%s' "$out" | grep -qF "$m" || ok=0; done
                IFS=$sIFS
                echo "$ok" > "$logdir/$i.ok"
                [ "$ok" = 1 ] || printf '%s' "$out" | tail -18 > "$logdir/$i.serial"
            ) &
            b=$((b+1))
        done
        wait
    done

    local pass=0 fail=0 j
    for j in $(seq 1 "$RUNS"); do
        [ "$(cat "$logdir/$j.ok" 2>/dev/null)" = 1 ] && pass=$((pass+1)) || fail=$((fail+1))
    done
    if [ "$fail" -eq 0 ]; then
        grn "    [$name] $pass/$RUNS PASS — stable across $RUNS runs (no race surfaced)"
        printf '{"selftest":"%s","runs":%s,"pass":%s,"verdict":"stable"}\n' "$name" "$RUNS" "$pass" >> "$FINDINGS"
    else
        red "    [$name] $pass/$RUNS pass, $fail FAIL — FLAKY (timing-dependent scheduler race, or boot-timeout under load)"
        for j in $(seq 1 "$RUNS"); do
            [ -f "$logdir/$j.serial" ] && { echo "      --- first failing run ($j) serial tail (race vs. didn't-reach-selftest) ---"; sed 's/^/      /' "$logdir/$j.serial"; break; }
        done
        printf '{"selftest":"%s","runs":%s,"pass":%s,"verdict":"FLAKY"}\n' "$name" "$RUNS" "$pass" >> "$FINDINGS"
    fi
    rm -rf "$stage" "$logdir"
}

run_selftest ring3  "RING3_SELFTEST=1"  1 30 "ring3: preempt OK|ring3: child exited|ring3: gate held"
run_selftest thread "THREAD_SELFTEST=1" 1 30 "thr: preempt OK|thr: gate held"
# The concurrent-proc STRESS selftest (the real race-finder): a 12-proc storm near
# the 16-slot proc-table cap, 3 rounds of spawn/work/yield/exit churning slot-reclaim,
# asserting count/leak/starve/canary/cap invariants. A non-PASS = a real scheduler
# race (torn counter, slot leak, starved proc, clobbered canary, cap overrun).
run_selftest sched-stress "SCHED_STRESS_SELFTEST=1" 1 40 "sched-stress: ALL PASS"
# SMP-AP wake is GATED OFF in the MVP (smp_wake_enabled=0, agnos main.cyr:2131 —
# parked for iron validation per state.md), so production single-core-boots even
# at -smp 4. This dim therefore validates the GATED production boot is stable +
# reaches kybernet under -smp 4 (a boot-path regression — confirms the gate holds
# and 3 parked-AP cores don't disturb the BSP). Un-gated AP-wake validation (flip
# smp_wake_enabled=1) is a separate iron-bound concern, not the MVP config.
run_selftest boot-smp4 ""               4 35 "smp: AP wake gated (MVP single-core)|Activating scheduler|kybernet:"

echo "------------------------------------------------------------------"
echo "sched-sweep findings → $FINDINGS"
flaky="$(grep -c '"verdict":"FLAKY"' "$FINDINGS" 2>/dev/null)"; flaky="${flaky:-0}"
bfail="$(grep -c '"verdict":"BUILD-FAIL"' "$FINDINGS" 2>/dev/null)"; bfail="${bfail:-0}"
if [ "$flaky" -eq 0 ] && [ "$bfail" -eq 0 ]; then
    grn "SCHED SWEEP: all selftests stable across $RUNS runs each — no scheduler races surfaced"
else
    red "SCHED SWEEP: $flaky flaky + $bfail build-fail — see ledger above"
fi
echo "NOTE: build/agnos is left as the LAST build (smp=production); rebuild your flavour as needed."
exit 0
