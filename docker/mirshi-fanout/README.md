# mirshi-fanout — ecosystem userland in Docker, no QEMU

The **userland** track of the container test surface: run AGNOS's real
agnos-target userland tools (`iam`, `kii`, …) as native Linux processes under
[**mirshi**](https://github.com/MacCracken/mirshi) (the AGNOS↔Linux syscall
shim), fanned out across concurrent `FROM scratch` containers — **no QEMU**,
sharing the host kernel (mirshi direction 1).

```
docker run agnos-mirshi-fanout /bin/iam        ─┐
docker run agnos-mirshi-fanout /bin/iam         ├─  N containers, each: mirshi
docker run agnos-mirshi-fanout /bin/kii …       │   translates the tool's agnos
      …                                        ─┘   syscalls → host Linux. No VM.
```

## Where it sits in the realism ladder

**iron → QEMU → containers.** This is a *third* container track next to the
QEMU sweeps, and the boundary is load-bearing (mirshi
[ADR 0011](https://github.com/MacCracken/mirshi/blob/main/docs/adr/0011-mirshi-qemu-iron-boundary-discipline.md)):

| Track | Runs | Validates | mirshi-fanout? |
|---|---|---|---|
| [`../net-sweep/`](../net-sweep/) | agnos **kernel** under QEMU | kernel TCP accept / net stack | ❌ stays QEMU |
| [`../sched-sweep/`](../sched-sweep/) | agnos **kernel** under QEMU (TCG) | SMP scheduler / preemption | ❌ stays QEMU |
| **mirshi-fanout** (here) | agnos **userland** on the host kernel via mirshi | the tool binary + its agnos-ABI syscall use, at fan-out scale | ✅ |

mirshi runs the **exact agnos-target ELF** the project ships (unlike a Linux
recompile) but supervisor-*emulates* the net band and shares the host kernel — so
it **complements, never replaces** the QEMU sweeps (real kernel) and iron
(hardware truth). It owns userland-concurrency + Linux-compat-at-scale; it does
**not** exercise the agnos kernel's scheduler or net stack. A green fan-out here
is *not* "the agnos kernel works" — that's net-sweep/sched-sweep/iron.

## What runs (and what doesn't)

| Tool | Invocation | Exercises under mirshi |
|---|---|---|
| **iam** | `/bin/iam` | info-getter band (`uname#34`/`sysinfo#35`/`getuid#15`) + native CPUID. The **GPU line is absent by design** — the accelerator manifest (agnos#89, a hardware-manifest read) has no answer under mirshi (no agnos hardware model). |
| **kii** | `/bin/kii /data/ramgon.png [--width N]` | fs read (`open`/`read`), `winsize#60`, ANSI render. Renders an ~8 KB halfblock frame. |

Deferred:
- **descent** (MUD, `serve <port>`) — a server: mirshi net band + epoll. Needs
  the `--net`/`--net-listen-any` run mode + a telnet-client assert (a different
  invocation class than the run-once tools) — the next tool to land here.
- **agora** (BBS) — **fork-per-accept**; no `agora_agnos` build yet (blocked on
  the agnos `spawn#3`/`waitpid#4` adaptation of its accept loop). Out until it
  builds `--agnos`.

## Prerequisites

- `docker` on the host.
- The sibling repos under `~/Repos/`, with each tool's agnos ELF built:
  - `~/Repos/mirshi` — built here by `build.sh` (always current).
  - `~/Repos/iam/build/iam_agnos` — `cd ~/Repos/iam && cyrius build --agnos src/main.cyr build/iam_agnos`
  - `~/Repos/kii/build/kii_agnos` — `cd ~/Repos/kii && cyrius build --agnos src/main.cyr build/kii_agnos`

  `build.sh` fails loud with the exact command if a tool ELF is missing (it
  **stages** release artifacts — it does not resolve each tool's cross-repo deps).

## Run

```sh
./smoke.sh                          # build image + run each tool once + an 8x fan-out (the gate)
./build.sh                          # just (re)build the agnos-mirshi-fanout image
./fanout.sh 24 /bin/iam             # 24 concurrent iam containers
./fanout.sh 12 /bin/kii /data/ramgon.png
```

Stock Docker blocks ptrace in its default seccomp profile; the scripts pass
`--cap-add=SYS_PTRACE --security-opt seccomp=unconfined` (mirshi is a ptrace
supervisor). The `FROM scratch` container itself is the filesystem confinement
(mirshi's `--root` is orthogonal and unused here).

## Adding a tool

Append one row to the `TOOLS` table in [`build.sh`](build.sh) —
`"name:repo-subdir:agnos-ELF:build-hint"` — drop any sample data into `data/`,
and add an assertion to [`smoke.sh`](smoke.sh). Run-once tools work today; server
tools (descent) need the `--net` run mode + a client assert.
