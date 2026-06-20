# AGNOS sched-sweep — Track-A scheduler selftest harness

The **scheduling** half of the founder net+sched sweep (the networking half is
[`../net-sweep/`](../net-sweep/)). It boots each AGNOS **scheduler selftest**
kernel inside a container (QEMU+OVMF+gnoboot) and tallies the pass-rate across
repeated runs — a containerised, reproducible regression gate for the 1.44.x
preemptive-scheduler / SMP surface, burn-free.

```
host runner ──▶ docker run -v kernel:/input ──▶ qemu (TCG) ──▶ agnos boots
                                                              ──▶ selftest prints markers to serial
            ◀── serial (stdout) ◀──────────────────────────────┘
```

## Selftests covered

| name | build flag | `-smp` | markers (all must appear) |
|---|---|---|---|
| `ring3` | `RING3_SELFTEST=1` | 1 | `ring3: preempt OK` · `ring3: child exited` · `ring3: gate held` |
| `thread` | `THREAD_SELFTEST=1` | 1 | `thr: preempt OK` · `thr: gate held` |
| `smp` | *(production)* | 4 | `smp: cpus online: 4` · `Activating scheduler` · `kybernet:` |

## ⚠ Key finding — the selftests are **TCG-only**

These selftests **do not complete under KVM**. Under KVM the boot timing differs
and `kybernet` launches while the ring-3 selftest procs are still alive, so the
markers never print and the boot stalls at `Activating scheduler...` (observed
2026-06-19: a KVM run produced 0/3, the serial tail ending exactly there). This
is a **harness/timing artifact, not a scheduler bug** — it matches the attn11
session note ("agnos smokes are TCG-only by design") and the KVM boot-timing
caveat in `state.md`.

So **TCG is the default** here. `KVM_OPT=1` opts into KVM (fast boot) but expect
the selftests not to complete — useful only for boot-path smoke, not the markers.
TCG boot is slower, so per-selftest timeouts auto-scale ×3.

**Consequence for "testing at scale":** because TCG is deterministic, repeating a
selftest mostly re-confirms stability (a clean-room regression gate) rather than
surfacing new timing races. **Real scheduler-race-finding needs a dedicated
concurrent-proc *stress* selftest** (many ring-3 procs contending, randomised
yield/exit ordering) — a kernel bite, not a harness one. That stress selftest is
the natural next step for this harness to drive.

## Run

```sh
./sched-sweep.sh                  # build kernels + image, RUNS x each (TCG), report
RUNS=5 PAR=3 ./sched-sweep.sh
ONLY=ring3 ./sched-sweep.sh        # one selftest
KVM_OPT=1 ./sched-sweep.sh         # KVM (boot smoke only — selftests won't complete)
```

`RUNS` boots per selftest, `PAR` in parallel (host-scheduler jitter). Each run's
serial is greppped for all markers; a `<100%` pass-rate prints the first failing
run's serial tail (to tell a real race from a boot-timeout under load) and is
logged to `sched-findings.jsonl` (gitignored).

## Notes
- The kernel + gnoboot are **mounted** at runtime (`-v …:/input:ro`), so one
  image serves every selftest build — the runner rebuilds `build/agnos` per flag
  and leaves it as the **last** build (smp=production); rebuild your flavour after.
- Reuses the QEMU boot recipe from `agnos/scripts/{ring3,thread,smp}-smoke.sh`,
  wrapped for a container — the same iron→QEMU→**containers** realism ladder as
  net-sweep.
