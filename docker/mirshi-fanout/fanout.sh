#!/usr/bin/env bash
# fanout.sh — fan out N concurrent agnos-mirshi-fanout containers, each running
# an ecosystem tool under mirshi, and collect pass/fail + wall time. The test-
# fleet model: concurrent agnos-userland workloads, no QEMU — each container is a
# plain native process tree sharing the host kernel (direction 1). This is the
# userland-concurrency-at-scale surface that COMPLEMENTS (never replaces) the
# QEMU net-sweep / sched-sweep (real agnos kernel) and iron (hardware truth).
#
# Usage: fanout.sh [N] [/bin/tool] [tool-args...]     (defaults: 12 /bin/iam)
#   fanout.sh 24 /bin/iam
#   fanout.sh 12 /bin/kii /data/ramgon.png
set -euo pipefail

img="${IMG:-agnos-mirshi-fanout}"
n="${1:-12}"; shift || true
tool="${1:-/bin/iam}"; shift || true
args=("$@")
# Stock-Docker-safe ptrace recipe (the default seccomp profile blocks ptrace).
caps=(--cap-add=SYS_PTRACE --security-opt seccomp=unconfined)

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo "==> fanning out $n concurrent containers: $tool ${args[*]}"

start=$(date +%s%N)
for i in $(seq 1 "$n"); do
    # set +e in the subshell: a failing `docker run` must NOT abort before we
    # record its real exit code (the inherited set -e would skip the echo).
    ( set +e
      docker run --rm "${caps[@]}" "$img" "$tool" "${args[@]}" >"$tmp/out.$i" 2>"$tmp/err.$i"
      echo $? >"$tmp/rc.$i" ) &
done
wait
end=$(date +%s%N)

ok=0; fail=0
for i in $(seq 1 "$n"); do
    rc="$(cat "$tmp/rc.$i" 2>/dev/null || echo 1)"
    if [ "$rc" = "0" ]; then
        ok=$((ok + 1))
    else
        fail=$((fail + 1))
        echo "  container $i FAILED (rc=$rc): $(grep -v WARNING "$tmp/err.$i" 2>/dev/null | head -1)" >&2
    fi
done

msg=""
if [ "$fail" -ne 0 ]; then msg=", $fail failed"; fi
echo "==> $ok/$n containers OK$msg — wall $(( (end - start) / 1000000 )) ms"
echo "    sample output: $(head -1 "$tmp/out.1" 2>/dev/null)"
[ "$fail" -eq 0 ]
