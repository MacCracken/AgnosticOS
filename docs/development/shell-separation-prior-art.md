# Shell Separation — Prior Art + Boundary Audit (1.41.x arc)

> **Status**: 1.41.0 (arc-open + boundary audit). This is the planning/audit doc for moving the
> interactive shell out of the kernel and into the userland `agnsh` (agnoshi) binary, exec'd from
> disk via the 1.40.x exec path. Engineering bites 1.41.1+ implement against this map.
>
> **Companion**: [`exec-from-disk-prior-art.md`](exec-from-disk-prior-art.md) (the exec path this rides on);
> agnos roadmap § *1.41.x — Shell Separation Arc* (the bite ladder + commitments).

## 1. Goal

Today PID 1 (`kybernet`) calls the **in-kernel `shell()`** (`agnos/kernel/user/shell.cyr`, ~1150 LOC) — a
ring-0 REPL that:
- reads the keyboard **directly** (`kb_has_key` / `kb_read_scancode` / `scancode_to_ascii`, with `arch_wait()` between keys),
- prints via `kprint`/`kputc` (FB console), and
- calls `ext2_*` / `vfs_*` / `fatfs_*` / `dns_*` / `icmp_*` / `pmm_*` / PCI / block kernel functions **in-process**.

The arc makes the **userland `agnsh` binary** (the [agnoshi](https://github.com/MacCracken/agnoshi) repo —
AI-native NL shell, ~5 K LOC, 295 KB static, v1.3.x) the interactive shell, **exec'd from disk in ring 3**
via the 1.40.x exec path. A ring-3 process reaches the kernel **only through syscalls**, so the audit below
maps every in-kernel verb to the syscall surface `agnsh` will need. The in-kernel shell shrinks to a minimal
**emergency/recovery shell** — the permanent boot fallback when no userland shell is reachable.

This is the **first userland binary promoted to a system component**. It defines the permanent
kernel↔userland shell boundary, and is the kernel-slimming counterpart to the 1.40.x exec arc (the
console-font slimming already shipped as `kashi` at 1.37.5).

**Why now**: 1.40.x exec-from-disk is iron-validated (a static ELF64 runs in ring 3 off the agnos-fs),
and 1.40.14 process teardown means a long-lived userland process won't leak its slot/pages.

## 1a. Gating prerequisite — the userland↔kernel syscall ABI (cyrius-side)

**`agnsh` is an OS-agnostic shell** (zsh/bash-class portability): the same source builds for whatever
target the Cyrius toolchain provides. The Cyrius stdlib syscall layer (`lib/syscalls.cyr` — *"Linux syscall
wrappers, arch-dispatched"*) currently offers **`CYRIUS_TARGET_LINUX`** (x86-64 + aarch64 peers) and
**`CYRIUS_TARGET_WIN`** — Linux was simply the host target available to build against. So the existing
`build/agnsh` emits **Linux syscall numbers**, Linux `stat` struct layouts, and the `openat`-family wrappers —
it runs on Linux today, and **will not execute on AGNOS's sovereign 28-syscall ABI** as built.

This is **not an oversight — it's the portability working as designed**, and it makes the agnos port "add a
Cyrius target," not "rewrite the shell" (the same multi-target story Cyrius itself has: Linux / Windows / macOS
→ **+ agnos**). The **gating prerequisite** for the arc is therefore a **`CYRIUS_TARGET_AGNOS`** stdlib profile
— a new `lib/syscalls_*_agnos.cyr` peer emitting agnos syscall numbers + agnos struct layouts, selected by a
compiler `PP_PREDEFINE` target macro — so the same `agnsh` source rebuilds for the agnos ABI.

- **This is cyrius-side work**, driven with the cyrius agent (hands-off here, per [[feedback_cyrius_hands_off]]) —
  the same class of cyrius-gated dependency as PIE (→ full-binary KASLR) and stdlib TLS (→ HTTP).
- **AGNOS does NOT adopt the Linux syscall ABI** to make Linux binaries run — that would erase the
  sovereign-surface / structural-immunity invariant ([[project_agnos_kernel_growth_rules]],
  [[project_monolithic_by_design]]). The reconciliation is "Cyrius learns to emit agnos syscalls," not
  "agnos learns to answer Linux syscalls."
- **Shared-ABI contract**: the agnos-side syscalls this arc adds (§4) and the `CYRIUS_TARGET_AGNOS` stdlib peer
  must agree on the **same numbers + struct layouts**. The agnos syscall table (`syscall.cyr`) is the canonical
  source; the cyrius peer mirrors it. Keep them in lockstep (one drifts → silent wrong-syscall, the exact class
  the cyrius `syscalls.cyr` split was created to prevent).

**Bottom line**: the agnos-side bites below (stdin + FS syscalls) are necessary but **not sufficient** —
`agnsh` can't run on agnos until the `CYRIUS_TARGET_AGNOS` build profile exists. Sequence the cyrius-side
target alongside 1.41.1/1.41.2 so both halves of the ABI land together.

## 2. Launch path (current)

```
boot_finish.cyr  →  kybernet()            (kernel/user/init.cyr)
                      └─ shell()           (kernel/user/shell.cyr:1093)  ← ring-0 REPL
```

`shell()` loop: print `agnos> ` → poll `kb_has_key()`/`kb_read_scancode()` → echo + buffer until newline →
`sh_exec(buf, len)` → dispatch by verb. Input is **ring-0 keyboard polling**; output is **ring-0 `kprint`**.

Target:

```
boot_finish.cyr  →  kybernet()
                      ├─ run("/bin/agnsh")  ← exec from disk, ring 3 (1.41.3)
                      └─ shell()            ← emergency fallback if /bin/agnsh missing/exec-fails (1.41.4)
```

## 3. Verb inventory + boundary classification

The 35 verbs `sh_exec` dispatches, classified by where they land after separation:

| Verb | Does | Lands in |
|------|------|----------|
| `help` `ps` `free` `uptime` | static / `proc_table` / `pmm_free_count` / `timer_ticks` | **agnsh** (via getpid/sysinfo-style syscalls or local) |
| `cat` `ls` `cd` `pwd` `echo`/`echo >` `touch` `rm` `mkdir` `rmdir` `mv` `ln` `sync` | filesystem ops | **agnsh** (needs the FS syscall surface — §4) |
| `run` | exec a program from disk | **agnsh** (needs exec-by-path syscall — §5, deferred) |
| `dns` `ping` `ntp` `date` `send` `recv` `tcp` `net` | network / clock | **agnsh** (needs a net/clock syscall surface — §5, deferred) |
| `halt` | shutdown | **agnsh** (`reboot`/halt syscall — 13 exists) |
| `lspci` `cpus` `pipe` `blkread` `disk` `parts` `jbd2` `bench` `test` | deep kernel diagnostics (PCI table, block dev, rdtsc bench, journal state) | **kernel emergency shell** (read kernel internals directly; a `/proc`-style syscall surface is a later option, not MVP) |

**Boundary decision**: agnsh owns the **user-facing** verbs (filesystem, run, network, clock, halt, info).
The emergency shell keeps the **recovery + deep-diagnostic** set (`ls`/`cat`/`run`/`reboot` for recovery +
the `lspci`/`blkread`/`disk`/`parts`/`bench` diagnostics that read kernel internals with no clean syscall
yet). The split is by *who needs the data*: user-facing → userland via syscalls; kernel-internal debug →
stays in the kernel where the data lives.

## 4. Syscall gap analysis (the FS surface — the 1.41.x core)

Current syscall table (`syscall.cyr`, 29 entries 0–28): `0 exit · 1 write · 2 getpid · 3 spawn · 4 waitpid ·
5 read · 6 close · 7 open · 8 dup(stub) · 9 mkdir(stub→0) · 10 rmdir(stub→0) · 11 mount(noop) · 12 sync(stub→0) ·
13 reboot · 14 pause · 15 getuid(0) · 16 kill · 17 sigprocmask · 18 signalfd · 19–21 epoll · 22–23 timerfd ·
24 umount(0) · 25 pipe · 26 write_boot_checkpoint · 27 mmap · 28 munmap`.

What `agnsh`'s filesystem builtins need:

| agnsh op | in-kernel shell calls today | syscall status | bite |
|----------|------------------------------|----------------|------|
| open a file | `ext2_open` / `vfs_open_on` (mount-routed) | **`open`(7) routes to `initrd_open` ONLY** — can't reach the agnos-fs. **Must re-route through `vfs_resolve_mount`.** | 1.41.2 |
| read / write / close | `vfs_read`/`vfs_write`/`vfs_close` | ✅ exist (5/1/6) | — |
| **stdin (interactive)** | `kb_*` ring-0 polling | **`read(fd=0)` → serial today; needs keyboard-backed BLOCKING stdin** | **1.41.1** |
| `ls` (readdir) | `ext2_print_dir` / `vfs_print_dir_on` | **MISSING — no `getdents`/readdir syscall** | 1.41.2 |
| `mkdir` | `vfs_mkdir_on` | **stub → 0** (must wire to backend) | 1.41.2 |
| `rmdir` | `vfs_rmdir_on` | **stub → 0** | 1.41.2 |
| `rm` (unlink) | `vfs_delete_on` | **MISSING** | 1.41.2 |
| `mv` (rename) | `vfs_rename_on` | **MISSING** | 1.41.2 |
| `ln` (link) | `ext2_link` | **MISSING** | 1.41.2 |
| `sync` | `ext2_sync` / `vfs_sync` | **stub → 0** | 1.41.2 |
| `stat` (type/size) | inline inode reads | **MISSING** (needed for `ls -l`, type detection) | 1.41.2 |
| `touch` | `ext2_create` / `vfs_create_on` | **no `create` syscall** (open-with-O_CREAT, or a dedicated create) | 1.41.2 |

**Two central new capabilities** fall out of this:
1. **Blocking keyboard stdin (1.41.1)** — `read(fd=0)` serviced from the keyboard driver. The syscall handler
   enables interrupts in ring 0 while it waits (the in-kernel loop's `kb_has_key`/`arch_wait` logic, moved
   behind the syscall), returns bytes/a line to the ring-3 caller. **The dispositive new capability** — a
   userland process reads the keyboard for the first time, and it's the first *interactive* (blocking-on-input,
   not run-to-completion) ring-3 process.
2. **Mount-routed FS syscall surface (1.41.2)** — wire `open`/`getdents`/`mkdir`/`rmdir`/`unlink`/`rename`/
   `link`/`stat`/`sync`/`create` to the **1.40.13 mount router** (`vfs_resolve_mount` → ext2 inode-wise or
   `vfs_*_on` for FAT/exFAT). The routing layer already exists; these syscalls are thin dispatchers over it.

## 5. CWD + deferred surfaces

- **CWD is userland-owned (design decision).** The in-kernel shell holds CWD as kernel state (`sh_cwd_*`).
  `agnsh` instead tracks its **own** CWD and passes **absolute paths** to every syscall — so **no kernel
  `chdir`/`getcwd` is needed**. Simpler, and it keeps per-process CWD out of the kernel until a real
  multi-process consumer demands it.
- **`run` / exec-by-path (DEFERRED follow-on).** `agnsh` launching an external binary needs a ring-3-initiated
  exec (syscall 3 `spawn` takes an in-memory ELF, not a path; the 1.40.x `run` is kernel-driven via
  `sh_cmd_run`). This also collides with the run-to-completion model (a parent shell persisting while a child
  runs) — i.e. it wants **preemptive ring 3 (interrupt-KPTI)** or a careful nested-exec design. **Out of the
  separation MVP.** Until it lands, `agnsh` does its builtins via syscalls; "launch arbitrary `/bin/foo`" is
  the follow-on.
- **Network + clock syscalls (DEFERRED).** `dns`/`ping`/`ntp`/`send`/`recv`/`tcp`/`net`/`date` call
  `dns_resolve`/`icmp_ping`/`udp_*`/`tcp_*`/`ntp_now` directly today. A userland socket/clock syscall surface
  is its own design (BSD-sockets-shaped vs message-shaped). Keep these kernel-side (emergency shell or a thin
  syscall later); not part of the FS-and-stdin MVP.
- **AI / intent / `hoosh` gateway (DEFERRED).** `agnsh`'s natural-language + approval + audit features are out
  of scope for the separation. The bar is "agnsh is the interactive shell, from disk, talking to the kernel
  only via syscalls." LLM wiring (`hoosh`) is its own later arc.

## 6. Prior art

How other systems draw the kernel↔shell boundary — the converged shape we port from (per
[[feedback_redesign_dont_reinvent]], triangulate, don't clone one source):

- **Unix / POSIX** — the canonical split: shell is userland (`/bin/sh`), kernel exposes `open`/`read`/`write`/
  `close`/`getdents(64)`/`mkdir`/`rmdir`/`unlink`/`rename`/`link`/`stat`/`chdir`/`fork`/`execve`/`wait`. Our
  MVP is a **subset** (no fork — single static binary; CWD userland-owned). `getdents64`'s record layout
  (`d_ino`/`d_off`/`d_reclen`/`d_type`/`d_name`) is the reference for our `getdents` shape.
- **xv6** (MIT teaching kernel) — the cleanest minimal reference: `sh.c` is a ~400-line userland program over
  ~20 syscalls (`open`/`read`/`write`/`close`/`dup`/`exec`/`fork`/`wait`/`mkdir`/`chdir`/`fstat`). Shows the
  *floor* of what an interactive shell needs from a kernel — close to our target surface.
- **Plan 9** — shell (`rc`) is userland; the kernel surface is file-oriented (everything via `open`/`read`/
  `write` on synthetic files). Relevant for the **deferred `/proc`-style diagnostic surface** (lspci/disk/parts
  as readable kernel files instead of in-kernel verbs).
- **BusyBox / toybox** — one static multi-call binary providing dozens of "commands" as internal dispatch over
  the same small syscall set — the architecture `agnsh` already mirrors (one `agnsh` binary, many builtins).
  Validates "don't ship 30 separate `/bin` programs; one binary dispatches."
- **AGNOS internal precedents** — `kashi` (1.37.5, console-font slimming: kernel consumes a separately-built
  data core) and the 1.40.x exec path (kernel runs a userland ELF in ring 3) are the two moves this arc
  composes: *slim the kernel by moving a role to a separately-built artifact* + *run that artifact from disk*.

## 7. Bite ladder (mirrors the agnos roadmap)

- **1.41.0** — this doc + boundary audit; **staging mechanism** (`agnos/scripts/stage-agnsh.sh` → `build/rootfs/bin/agnsh`, consumed by fs-population). *(no kernel code → no VERSION bump yet.)* Surfaced the §1a ABI prerequisite.
- **(cyrius-side, parallel — gating)** — `CYRIUS_TARGET_AGNOS` stdlib syscall profile so `agnsh` rebuilds for the agnos ABI. Driven with the cyrius agent; not an agnos-version bite. Must land before `agnsh` can run on agnos.
- **1.41.1** — blocking keyboard `read(fd=0)` from ring 3 (the dispositive agnos-side new capability).
- **1.41.2** — mount-routed FS syscalls: re-route `open`, add `getdents`/`unlink`/`rename`/`link`/`stat`/`create`, make `mkdir`/`rmdir`/`sync` real. (Shared-ABI contract with the cyrius peer — §1a.)
- **1.41.3** — `kybernet` execs `/bin/agnsh` (the agnos-ABI build); falls back to the in-kernel emergency shell on **any** boot-to-shell failure.
- **1.41.4** — shrink the in-kernel shell to the emergency/recovery set; lock the boundary.
- **1.41.5** — arc-close hardening + the combined iron burn (`agnsh` interactive on real Zen).

## 8. Open questions (resolve before the bite that hits them)

1. **`getdents` record shape** — POSIX `getdents64`-style packed records vs a simpler AGNOS-native one. (1.41.2)
2. **`open` flags** — do we need `O_CREAT`/`O_TRUNC`/`O_APPEND` as flag bits, or separate `create`/`truncate`
   syscalls? The in-kernel shell uses separate `ext2_create` + `ext2_truncate_zero` calls today. (1.41.2)
3. **stdin line discipline** — does `read(fd=0)` return raw bytes (agnsh does its own line-edit) or
   cooked lines (kernel does backspace/echo)? Raw is more Unix-honest and pushes editing into agnsh; cooked
   reuses the existing in-kernel echo loop. (1.41.1)
4. ~~**Emergency-shell trigger**~~ — **RESOLVED (user, 2026-05-31)**: the emergency shell fires on **any
   boot-to-shell failure** (exec-fail of `/bin/agnsh` being the immediate case — missing / corrupt / wrong-ABI
   / non-zero exit before prompt), **plus a future user key-chord** to summon it on demand (a held-key check
   during boot / a runtime hotkey). Not exec-fail-only — any path that fails to reach an interactive prompt
   falls back to the in-kernel recovery shell. (1.41.3 / 1.41.4)
