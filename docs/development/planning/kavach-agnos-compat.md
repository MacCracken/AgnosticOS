# kavach ↔ agnos-kernel compatibility & base-stage kernel needs

> **Status**: Audit complete 2026-06-29 (multi-agent, source-grounded, adversarially verified). **Scope**: where kavach stands on the bare agnos kernel today, what the kernel needs for *base*, and the sovereign (capability-first) shape of future sandbox-confinement primitives. **Companion**: the `bhumi`/`mehman` compositor-backend split ([[shared-crates.md]]) — same "AGNOS is not Linux, build sovereign-native, not ported-isms" through-line.

## Bottom line

On the bare agnos kernel **today**, kavach is a fully-working **scanner + HMAC-audit + policy frontend with zero kernel-backed confinement — and that is correct by design**, not a defect. Confinement is the **capability layer's** job, and that layer is not yet in the kernel. **None of kavach's kernel needs are *base* needs**: sandboxing is a **swallow-stage** concern (empire-defense Phase 20 — a kavach-sandboxed personality container kept permanently separate from the kernel). The kernel-internals for *base* are essentially **done**; what remains for base is **ecosystem** (ISO Stage-4 cut, sovereign ark/nous, soak), not kernel work.

## kavach on bare agnos — three buckets

**1. Works unchanged (the bulk of kavach's value).** Pure-userspace, no kernel-isolation primitive: the HMAC-SHA256 tamper-evident audit chain (`audit.cyr`), the entire scanner family (`scanning_{code,data,secrets,threat,runtime}` + `scoring` + `aho_corasick`), the PASS/WARN/QUARANTINE/BLOCK gate (`scanning_gate.cyr`), the policy DTO. Only OS touch is ordinary VFS file append + chmod — agnos covers it (`open#7`/`write#1`/`close#6`/`flock#59`). `credential.cyr`/`quarantine.cyr` port modulo verifying agnos VFS honors `O_EXCL`/`O_NOFOLLOW`/`fchmod`.

**2. Compiles but honestly no-ops.** `security.cyr` already does the right thing — under `#ifdef CYRIUS_TARGET_AGNOS`, `apply_landlock`/`load_seccomp`/`create_namespace` return `err_not_supported(...)` rather than faking success, explicitly deferring to "the capability layer." `mac.cyr` (SELinux/AppArmor) and `cgroup.cyr` (cgroup-v2) degrade to silent inert no-ops (sysfs reads fail → `MAC_NONE` / `cgroup_supported()==0`).

**3. The one real defect — fixed in kavach 3.5.3 (2026-06-29).** `sys_security_syscalls.cyr` + `kernel_audit.cyr` hardcoded **Linux x86_64 syscall numbers** (`unshare=272`, `socket=41`, `bind=49`, `sendto=44`, `recvfrom=45`, phantom `agnos_audit_log=520`) that **alias catastrophically** on agnos's 0-62 table (`#41=sleep_ms`, `#44=unassigned`, `#45=getrandom`, `#49=sock_recv`). A raw `syscall(49, fd, sockaddr, 12)` on an agnos build would invoke **`sock_recv` with a sockaddr pointer as a destination buffer** — silently memory-unsafe, not merely unsupported. Fix: the four `kernel_audit.cyr` entry points (`audit_open`/`audit_send_raw`/`audit_recv_raw`/`audit_agnos_log`) are now `#ifndef CYRIUS_TARGET_AGNOS`-gated (return `err_not_supported`), and the misleading "agnos-only" comment on the Linux numbers is corrected with the per-number aliasing documented + the reference-only-inside-`#ifndef` invariant recorded. Host build + 413/413 tests green.

**Pre-existing, separate blocker (cyrius-side, hands-off):** the `--agnos` build still fails to link on `file_append_locked` / `sys_access` — those resolve in vendored `lib/io.cyr` only on Linux/macOS/aarch64 syscall layers, not the agnos target (a cyrius-stdlib surface gap under installed 6.3.5 vs pin 6.2.36). Unrelated to the syscall-aliasing fix.

### The "SyAgnos backend" is inverted from its name

`backend_sy_agnos.cyr` does **not** run on agnos — it shells out to `docker`/`podman` to run AGNOS **as a hardened container on a Linux host** (`ghcr.io/maccracken/agnos`), and the *Linux host's* seccomp/cgroups/nftables do the confining. Useful, but it is not kavach enforcing anything on the sovereign kernel.

## What the kernel needs for *base*

**For base: nothing sandbox-related.** Base fired 2026-05-25 (1.33.x WRITE); its kernel close-marker (FS-deep + crash-safe extent→jbd2→VFS, general exec-from-disk, lean kernel) is met and iron-validated, head at 1.50.x. Base's remaining work is the **ecosystem half** — ISO Stage-4 cut, sovereign ark/nous maturation (a deliberately-trailing v2 goal), soak. Foreign-app sandboxing belongs to **swallow** (terminal stage), so kavach's confinement gaps don't gate base.

## Two genuinely-confirmed near-term kernel items — ✅ BOTH DONE (agnos 1.50.7, 2026-06-29)

Both surfaced by the audit, both sovereign (no Linux projection), both small. Landed as **agnos 1.50.7**:

| Item | Stage | Detail |
|---|---|---|
| **bg-job fault teardown** ✅ | server | `fault_kill_current` resumed the shell for the *foreground* exec child (1.47.x), but a background (`&`) proc fault fell through to the stub → **halted the box**. **FIXED 1.50.7**: the bg path (already `proc_set_state(pid,0)`+SIGCHLD) now `sti;hlt`-yields so the next timer tick's `do_context_switch` switches to the next ready proc — the proven preemption path, no new mechanism. Foreground path unchanged (`fault-kill-smoke: PASS`); **on-iron bg-fault survival rides the next burn** (deterministic bg-fault integration test deferred — heavier than a hermetic selftest). |
| **real `proc_get_ppid`** ✅ | base/server hardening | `proc_get_ppid` was a stub returning `0` always, so `kill#16`'s "may only signal children" gate was **inert**. **FIXED 1.50.7**: flat `proc_ppid[16]` (parallel to `proc_cs[16]`/`proc_ss[16]`) filled at `proc_create_user` from the creator pid, reset in `proc_alloc_slot`, read by `proc_get_ppid`; the gate is extracted into a testable `proc_may_signal(caller,target)`. `PPID_SELFTEST` → `ppid: child-gate PASS`. **Guardrail held**: signal-ownership only, NOT pgid/sid. Un-blocks the deferred waitpid#4 ownership-gate cleanup. |

## The swallow-stage capability primitives (the real future sandbox work)

When native confinement is built, it must be **capability-first, never Linux-ABI emulation** — the adversarial verify pass reframed every "X-equivalent" that smuggled a Linux mechanism:

| Confinement need | ✗ Not | ✓ Sovereign form | Where it lives |
|---|---|---|---|
| **FS reach** | a Landlock clone | per-spawn, monotonically-narrowable grant over the *existing* kernel-curated mount table + path-prefixes, consulted by `vfs_resolve_mount`/`open#7`; confinement by **nameability**, not a private chrooted view | kernel (needs a per-proc FS-reach field) |
| **syscall reach** | a seccomp-style allow-list indexed by syscall number ("seccomp without bytecode") | **capability tokens over resource classes** (net authority, spawn authority, kill authority), checked at the `ksyscall` dispatch point | kernel |
| **resource budget** | a cgroup tree / `cpu.weight` / `pids.max` | a **page-budget the PMM/`sys_mmap` debits** (deny past grant, before machine-RAM is exhausted) + a capability-carried scheduling-eligibility grant. *Today one proc can mmap all machine RAM — the absence most fairly called a genuine gap.* | kernel (PMM + scheduler) |
| **net reach** | an LSM hook on `socket()` (there is no `socket()`) | a per-proc capability gate over `conn_id` allocation (`sock_connect#47`/`sock_listen#56`/`udp_bind#51`) | **kernel** dispatcher; kavach authors policy |
| **FS view** | a ring-3 `mount()` building an arbitrary tree | capability-composed FS-region grants (read-only / copy-on-grant) over kernel-curated regions | kernel |

**Key reframe**: most of these are **kernel-resident**, with kavach as policy *author* — not "kavach-specific." The agnos roadmap already carries this as a deferred, scope-gated item ("Native sandbox-confinement primitives… explicitly NOT Landlock/seccomp/unshare ABI emulation"), and kavach's `err_not_supported` returns are the wired consumer-demand signal. The architecture is already pointing the right way.

## Why the absences are principled (not gaps to backfill)

agnos's missing-vs-Linux surface is mostly **absence-by-design**, anchored in two project axioms:
- **CVE-2026-31431 structural immunity**: no `socket()`/`splice`/`AF_ALG` → no generic socket-family multiplexer or pipe-buffer/crypto-socket plumbing to weaponize or seccomp-deny. The net band `#45-#57` is a curated `conn_id` ABI.
- **Capability-first auth posture**: no `setuid`/POSIX-caps (`getuid#15` always returns root — there is no uid ladder to descend), no namespaces/`unshare` (explicitly rejected for capability gating), no `ptrace` (a whole trace-escape class gone), `mount#11`/`umount#24` are no-op stubs (FS routing is kernel-curated). "Isolate a process" → a capability gate on what it can name/reach, **not** a private-namespace view.

Three absences are honestly **partial/genuine gaps** rather than fully-principled: seccomp-class per-process syscall reach, cgroups-class resource quotas, and a composable per-guest rootfs — each the kind of thing a sandbox genuinely needs, each deferred to **swallow** and to be built capability-first.

## References

- agnos source: `kernel/core/syscall.cyr` (dispatch, `getuid#15:832`, `kill#16:843`, `fault_kill_current:362`, `is_user_range:216`), `kernel/core/proc.cyr` (`proc_create_address_space:400`, `sys_mmap:995`, `proc_get_ppid` stub`:722`, 16-proc cap`:176`), `kernel/core/vfs.cyr` (per-proc fd tables `:134-203`), `kernel/arch/x86_64/{ring3,boot_shim}.cyr` (ring-3 + SMEP/SMAP).
- cyrius: `lib/syscalls_x86_64_agnos.cyr` (the `SYS_*` enum, the authoritative agnos number map).
- kavach: `src/security.cyr` (the `#ifdef CYRIUS_TARGET_AGNOS` precedent), `src/kernel_audit.cyr` + `src/sys_security_syscalls.cyr` (the 3.5.3 fix), `src/backend_sy_agnos.cyr` (the docker/podman shell-out).
- Memory: [[project_agnos_maturity_arc]], [[project_agnos_empire_defense_layers]], [[project_agnos_auth_posture]], [[project_ecosystem_agnos_destined_linux_slant]], [[project_monolithic_by_design]].
