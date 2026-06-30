# mirshi — AGNOS↔Linux mirror-shim

> **Status**: Scaffolded v0.1.0 (2026-06-29) — activated from the idea-log ([[project_tools_stable_ideas]]) per "earns its own memory file + planning doc when it activates." | **Repo**: [MacCracken/mirshi](https://github.com/MacCracken/mirshi) | **Roadmap**: [mirshi/docs/development/roadmap.md](https://github.com/MacCracken/mirshi/blob/main/docs/development/roadmap.md) | **Roadmap phase**: 20 (compat) / swallow.

## What it is

**mir**ror + **shim** — a **userland syscall-translation supervisor** (the WSL1 / Wine / gVisor "pico-process" model — **NOT** kernel emulation, **NOT** a VM). One translation core, run from either side of the AGNOS↔Linux ABI boundary.

agnos redefines the `Sys` enum to its own numbers (`exit`=0 vs Linux 60; the net band `#45-#57` is a sovereign `sock_*`/`udp_*`/`icmp` ABI; `mmap#27` 2 MB-granular; `sock_recv` inverted-EOF; `execwait#37` run-to-completion). An agnos static ELF doing `syscall(0,…)` hits Linux `read` without translation — so each agnos syscall needs a **per-number handler** that maps-with-arg-translation, **emulates** in userspace, or returns `ENOSYS`. agnos bins are **static, no libc** → no `LD_PRELOAD`; interception is supervisor-side.

## Three weights, two lifespans (the strategic case)

| # | Weight | Lifespan |
|---|---|---|
| **1** | **Test surface (build-first)** — run agnos userland as native Linux processes in a plain Docker container (no QEMU, shared host kernel) → **multi-container fan-out** for userland concurrency/threading tests at scale across heterogeneous Linux hosts. The near-term win: *"boot a few containers to throw meatier tests at it."* | Durable (Docker + sandboxes forever) |
| **2** | **Linux→AGNOS swallow** — run Linux binaries **on the agnos kernel**. This **IS** the maturity-arc *swallow* stage + the permanent compat layer of [[project_agnos_empire_defense_layers]] / Phase 20. User: *"swallow of linux was always the first target."* mirshi is the **named instantiation** of that long-promised compat layer. | **Permanent** |
| **3** | **Cloud-deployability bridge** — cloud/orchestration only speaks Linux containers and **cannot host a foreign kernel**; mirshi lets agnos run *anywhere compute is sold* by presenting as an ordinary Linux-ABI container. The difference between "agnos runs on hardware we control" and "agnos runs anywhere." | May recede over a **multi-year** arc *if* providers adopt native agnos containers — but baseline is forever |

**Build the pieces as durable, portable projects either way** — weight (1) is real today regardless of whether (3) ever recedes. Weight (3) is why mirshi is strategically heavier than any CLI-tool idea-log entry.

## v1 scope (user, 2026-06-29)

**v1 = "AGNOS + mirshi runs in a plain Docker container, no QEMU."** That's **direction 1 (AGNOS→Linux)**, headless CLI: agnos-compiled userland runs as native Linux processes under mirshi's translation. The full first-few-cycles plan is in the repo roadmap; the spine:

- **M0** (0.1.0 ✅ scaffold) → real M0 = a `ptrace(PTRACE_SYSEMU)` trap loop that runs an agnos static ELF and logs its syscall stream.
- **M1** (0.2.0) core translation (process + console → hello-world runs).
- **M2** (0.3.0) filesystem syscalls (real agnos CLI tools run; honor `AO_*`→`O_*`, the `a4=r10` ABI, agnos dirents; the symlink gap mirrors the ark-v2 finding).
- **M3** (0.4.0) **the Docker image + multi-container fan-out** — the v1 vehicle.
- **M4** (0.5.0) seccomp-user-notify migration (the low-overhead path the fan-out-at-scale goal wants).
- **Feature freeze at 0.5.0**, then the canonical pre-1.0 quality close (cf. tarka/prajna): **0.6.0** hardening (misbehaving/hostile child, host-resource bounds) → **0.7.0** security CVE/0-day sweep (sandbox-escape classes; the seccomp-notify `FLAG_CONTINUE` TOCTOU is the headline 0-day) → **0.8.0** optimizations (per-syscall hot path, pass-through fast-path) → **0.9.0** freeze + docs (translation-table contract frozen, ADRs) → **v1.0.0 clean cut.**

**Post-v1 / v2+**: the sovereign net band over Linux sockets (first expansion — unblocks net tools / agora / descent in containers), multi-process agnos (agnsh-with-exec), graphics, signals/epoll, and **direction 2 (Linux→AGNOS swallow)**.

## Discipline (the boundary that must not blur)

mirshi-in-Docker runs agnos userland on the **host** Linux kernel → it validates **userland concurrency on real cores + Linux-app compat**, but does **NOT** exercise the **agnos kernel's own SMP scheduler or net stack** (that's QEMU `-smp` + iron). The full matrix: **mirshi/Docker** = userland concurrency at scale & Linux-compat; **QEMU+KVM** = real-kernel + kernel-SMP/net validation (the only thing that caught the real `sys_open`-ABI bug "correct-by-construction" missed, [[feedback_qemu_test_agnos_userland]]); **iron** = hardware truth. mirshi **complements, never replaces** them — each owns a distinct bug class. Don't let mirshi's convenience erode the iron/QEMU discipline.

## Open design decisions

- **Intercept mechanism**: `ptrace(PTRACE_SYSEMU)` for M0 bring-up (simplest — full register read/rewrite, the fastest path to a working translation loop) → migrate to `SECCOMP_RET_USER_NOTIF` + `process_vm_readv` at M4 for the low per-syscall overhead the fan-out-at-scale goal needs (gVisor-class). Both raw-syscall-able from Cyrius.
- **Emulation depth per syscall**: the sovereign-semantics syscalls (net band, `execwait` run-to-completion, 2 MB mmap granularity, inverted `recv` EOF) need real userspace emulation, not a number map — expand the handler table incrementally per consumer.
- **mirshi vs the QEMU service-sweep harness**: both are "AGNOS in a container," but the [`docker-service-sweep-harness.md`](docker-service-sweep-harness.md) runs AGNOS-**under-QEMU**-in-Docker (validates the real kernel); mirshi runs agnos **userland-on-host-Linux** (validates userland at scale). Complementary, not competing — keep both.

## References

- Repo + roadmap (above); memory [[project_mirshi_abi_shim]] (full design), [[project_tools_stable_ideas]] (origin idea-log entry).
- Maturity arc / swallow: [[project_agnos_maturity_arc]]; compat layer: [[project_agnos_empire_defense_layers]], [`cross-platform-compat-subsystem.md`](cross-platform-compat-subsystem.md) (Phase 20).
- Discipline: [[feedback_qemu_test_agnos_userland]].
