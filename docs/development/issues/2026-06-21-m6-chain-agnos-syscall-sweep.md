# M6 persistence chain → agnos: complete syscall-gap sweep (ONE ticket)

> **Status**: Open — request to the cyrius/language agent | **Created**: 2026-06-21 | **Owner**: agnosticos (testing surface) → cyrius (agnos peer) + patra + libro
> **Why this exists**: descent's `--agnos` build surfaces the M6-chain gaps **one rebuild at a time** (lseek → futex → access → …). This ticket enumerates the **entire** gap set in one pass — re-derived from the **live 6.2.34 vendored chain**, not the stale step-2 list in [`planning/server-app-ports.md`](../planning/server-app-ports.md) — so the language agent can group + fix them in a **single sweep per repo** instead of ticket-after-ticket.

## Context

- agnos kernel now ships `lseek`#58 + `flock`#59 (`[Unreleased]`, FLOCK_SELFTEST green).
- cyrius **6.2.34** agnos peer (`lib/syscalls_x86_64_agnos.cyr`) defines `SYS_LSEEK` / `SYS_FLOCK` / `SYS_SYNC` / `SYS_GETRANDOM` / `SYS_TIME_UNIX` / `SYS_STAT` / `sock_*` / `epoll_*` / `timerfd_*` / `signalfd` etc.
- descent re-vendored its `./lib` to the 6.2.34 snapshot (pin `6.2.30 → 6.2.34`). Linux build stays green (**1,517,184 B**).
- The M6 chain (`patra` → `sigil` → `sakshi` → `libro`, opt-in crash-safe player-save) still has the gaps below. **sakshi is fully agnos-adapted** (zero Linux-only / raw-number refs — verified). The remaining work is in the agnos **peer** (cyrius), **patra**, and **libro**.

Two categories: **(1) compile gaps** (the `--agnos` build *fails* without them) and **(2) runtime number-overlap hazards** (compile fine, **silently mis-dispatch** on agnos because agnos reuses ABI numbers).

---

## Category 1 — COMPILE GAPS  ·  owner: cyrius agnos peer (`lib/syscalls_x86_64_agnos.cyr`)

### C1 — patra futex-mutex constants
- **Missing in agnos peer** (present in `syscalls_x86_64_linux.cyr`): `SYS_FUTEX`, `FUTEX_WAIT`, `FUTEX_WAKE`, `FUTEX_PRIVATE_FLAG`.
- **Referenced**: `lib/patra.cyr:3360, 3370` in `_patra_lock` / `_patra_unlock`.
- **Reachability**: **never reached at runtime on single-core agnos** — `_patra_mtx == 0` is the default and guards both functions (`patra.cyr:3358, 3367`); the futex syscall only runs if a caller opts into the concurrency contract via `patra_init`, which descent does not. Pure **compile-time** symbol resolution.
- **Fix**: add the four constants to the agnos peer (mirror the Linux peer's block; values are irrelevant since the path is dead on single-core). A `sys_futex` no-op wrapper is optional, not required.

### C2 — sigil `sys_access` wrapper + `SYS_ACCESS`
- **Missing in agnos peer**: `SYS_ACCESS` constant **and** the `sys_access(path, mode)` wrapper fn (Linux-peer-only).
- **Referenced**: `lib/sigil.cyr` ×13 — TPM/IMA/cert-file existence probes (`:961, :962, :1153, :1246, :1681, :1718, :1924, :1955, :2369, :2413, …`), e.g. `sys_access("/dev/tpmrm0", 0)`.
- **Fix**: add `sys_access` to the agnos peer. **Recommended impl**: existence test via agnos `SYS_STAT`#33 (return 0 if the path stats OK, else −1). A plain `return -1` stub is also correct — none of sigil's probed paths (`/dev/tpmrm0`, `/dev/tpm0`, IMA dirs, secureboot DER) exist on agnos, so "not present / fail-closed" is the right degraded behavior.

---

## Category 2 — RUNTIME NUMBER-OVERLAP HAZARDS  ·  owner: patra + libro

These are **raw Linux syscall numbers used UNGATED** in agnos-reachable code. agnos reuses ABI numbers (e.g. `#8 = dup`, not `lseek`; `#60` is a no-op), so each silently mis-dispatches. Each must be routed through the agnos number under `#ifdef CYRIUS_TARGET_AGNOS`.

| # | Site | Raw call | Linux meaning | On agnos | Fix → agnos |
|---|------|----------|---------------|----------|-------------|
| **H1** | `patra.cyr:107` `enum Sync { SYS_FDATASYNC = 75 }` + its syscall | `syscall(75,…)` | fdatasync | #75 ≠ fdatasync | `sync`#12 (or no-op) under agnos branch |
| **H2** | `patra.cyr:311` | `syscall(201, 0)` | time() | #201 mis-dispatch | `time_unix`#46 |
| **H3** | `libro.cyr:216–223` | `syscall(1,…)` (write) + `syscall(60, 74)` (exit) | write / exit | **#60 is a NO-OP on agnos; #1 ≠ write** | agnos write + `SYS_EXIT`#0 — **better**: source libro entropy via `getrandom` (agnos peer HAS it) so the `/dev/urandom` fail-closed path is never entered on agnos |
| **H4** | `libro.cyr:292` `get_epoch_secs()` | `syscall(228, 0, buf)` | clock_gettime | #228 mis-dispatch | `time_unix`#46 |
| **H5** ⚠ | `libro.cyr:3746, 3764, 4255` `_fs_file_size()` | `syscall(8, fd, 0, 2)` | lseek(SEEK_END) | **`#8 = dup` on agnos** → returns a dup'd fd, not a size → **silent FileStore corruption** | `SYS_LSEEK`#58 (now exists) |

**H5 is the dangerous one**: every FileStore size read on agnos would `dup()` the fd and treat the result as a byte count. Now fixable since `lseek`#58 landed.

---

## NOT gaps (verified — leave alone)
- `sigil.cyr:441 syscall(34)` / `:444 syscall(63)` — uname, **already correctly platform-gated** (`#ifdef CYRIUS_TARGET_AGNOS` → agnos `uname`#34 ; `#ifndef` → Linux #63).
- **sakshi** — fully agnos-adapted; the stale plan claimed it needed `clock_gettime`/`nanosleep`/`openat`/`sendto`/`socket` — **none are referenced** in the 6.2.34 chain.
- `lseek` / `flock` / `getrandom` / `sync` / `sock_*` / `epoll_*` / `timerfd_*` / `signalfd` / `stat` / `rename` — already agnos-resolved.

## Sweep checklist
- [ ] **cyrius peer**: C1 (4 futex consts) + C2 (`sys_access` via stat#33)
- [ ] **patra**: H1 (fdatasync→sync#12) + H2 (time→time_unix#46), `#ifdef CYRIUS_TARGET_AGNOS`
- [ ] **libro**: H3 (write/exit + getrandom entropy) + H4 (clock→time_unix#46) + H5 (lseek#58), `#ifdef CYRIUS_TARGET_AGNOS`
- [ ] descent re-`cyrius lib sync`, `cyrius build --agnos` green, Linux build stays green
- [ ] then the descent agnos port continues (platform breakout / epoll→poll-loop / timerfd / signals — see server-app-ports.md steps 3–8) with **full** crash-safe persistence (v1b), no gate-out needed

> **Peer half filed for the cyrius language agent:** `cyrius/docs/development/issues/2026-06-21-agnos-peer-m6-chain-syscalls.md` (C1 futex consts + C2 `sys_access`, with inline code). This agnosticos doc is the local reference / full derivation. The in-lib half (H1–H5) shipped as **patra 1.12.3** + **libro 2.7.6** (2026-06-21).

## Status (2026-06-21)
- **C1 + C2 prototyped in descent's `lib/syscalls_x86_64_agnos.cyr`** (the base stdlib **peer** — survives `cyrius build`; only the dep-bundle libs get re-vendored by `cyrius-lsp`). With them, **the entire M6 chain now compiles for `--agnos`** — the build passes patra/sigil/sakshi/libro and stops in descent's *own* source (`server.cyr` epoll/fcntl port, expected). These peer additions are the reference for the cyrius fold-in.
- **H1–H5 are inside the dep-bundle libs** (`patra.cyr`/`libro.cyr`), which `cyrius-lsp` re-vendors to pristine on edit — so they can't be prototyped in descent and **are genuinely the language agent's source-repo fold** (patra + libro source). They do **not** block the build (symbols resolve, just to Linux values); they're runtime-correctness for the persistence path. Each is specced above with exact file:line + agnos target.

## Derivation method (so this can be re-run / trusted)
Re-derived from `cyrius-yeomans-descent/lib/{patra,sigil,sakshi,libro}.cyr` @ 6.2.34, not from comments:
1. `SYS_*`/`FUTEX_*`/`sys_*` symbols defined in the Linux peer **minus** those in the agnos peer, **intersect** chain references → C1, C2.
2. All literal `syscall(<NUMBER>)` in the chain, filtered to those **not** inside a `CYRIUS_TARGET_AGNOS` cpp branch → H1–H5.
