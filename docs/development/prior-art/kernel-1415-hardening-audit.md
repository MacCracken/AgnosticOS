# Kernel hardening / security / refactor audit — agnos 1.41.5

> **Date**: 2026-06-03 · **Scope**: agnos kernel, x86_64 only · **Target version**: agnos 1.41.5
> **Method**: 6-dimension multi-agent audit (syscall ingress · FS backends · exec/proc ·
> memory-safety sweep · refactor · net-ingress recheck), each finding **adversarially
> verified** for ring-3 reachability + a behavior-preserving fix. 26 findings survived
> verification (0 refuted); the HIGH cluster cross-converged from two independent dimensions.
> Each HIGH was then re-derived against source by hand before any code changed.

The 1.41.x shell-separation arc put a real userland shell (`agnsh`) on the other side of the
syscall boundary for the first time, and 1.41.3 added nine FS syscalls that take user pointers.
That makes the syscall ingress an actual attack surface (ring-3 → ring-0), so 1.41.5 is a
dedicated hardening pass over it before the arc closes.

## Invariants the audit reasoned under

- **Single-threaded, single-core, no preemption during a syscall** (SYSCALL masks IF via SFMASK).
  No locking; shared kernel scratch is relied upon. A "race" is not a valid finding.
- **Per-process CR3** mirrors a *superset* of the kernel map (0-4 GB + MMIO/BARs), so a kernel
  deref of a bad user pointer reads real kernel/MMIO memory or faults ring-0 → panic.
- **User VA window**: every legitimate user address is **below 1 GB** — ELF segments
  (`p_vaddr >= 2 MB`, `p_memsz <= 32 MB`), the per-pid stack (`0x800000 + pid*0x400000`, < 72 MB
  for the 16-proc cap), and the mmap arena `[0x10000000, 0x40000000)`. MMIO/BARs (NVMe
  ~0xC0000000) and the 1-4 GB PDPT range sit **above** it. `pmm_alloc_2mb` hands out 2-14 MB.
- **Trust boundary** (`kernel/core/syscall.cyr`): `is_user_ptr` / `is_user_range`. The
  `getdents(29)` `VFS_EXT2_DIR` tag check is the precedent the epoll/timerfd fixes follow.

## Findings + disposition

| # | Sev | Category | File | Issue | Disposition (1.41.5) |
|---|-----|----------|------|-------|----------------------|
| 1/8 | HIGH | security | syscall.cyr | epoll_ctl(20) never checks `ktag==VFS_EPOLL` → arbitrary kernel write (foreign fd's payload[2] = heap ptr / inode#) | **FIXED** — tag check |
| 2 | HIGH | security | syscall.cyr | epoll_wait(21) never checks `ktag==VFS_EPOLL` → arbitrary kernel read + attacker-driven loop count | **FIXED** — tag check |
| 3/10 | HIGH | security | syscall.cyr | watched fd (`arg3`) stored unbounded, used as `&vfs_table + wfd*32` → OOB kernel read | **FIXED** — bound at insert (epoll_ctl) + at deref (epoll_wait) |
| 4 | HIGH | security | syscall.cyr | `is_user_ptr`/`is_user_range` had no upper bound → ring-3 can aim kernel load/store at MMIO/high mem | **FIXED** — 1 GB ceiling |
| 5 | HIGH | hardening | syscall.cyr | sigprocmask(17)/signalfd(18) validate a bare ptr then load/store 8 bytes | **FIXED** — `is_user_range(p,8)` |
| 6 | HIGH | memory-safety | vfs.cyr/ext2.cyr | unbounded basename → `ext2_dir_buf[512]` (4 KB) overflow in fresh-block dir append (mkdir/create/rename-dst/link-dst) | **FIXED** — 255-byte cap in `vfs_ext2_parent` |
| 7 | HIGH | hardening | vfs.cyr | `vfs_ext2_parent` didn't cap basename at ext2's 255 max | **FIXED** — same cap (one ingress for all FS-mutation syscalls) |
| 9 | HIGH | security | syscall.cyr/elf.cyr | spawn(3) passes user `elf_addr/elf_size` to `elf_load`'s load8/load64 with no `is_user_range` → kernel-mem disclosure | **FIXED** — range check before `elf_load` |
| 12 | MED | hardening | proc.cyr | `sys_mmap` `length + 0x1FFFFF` wraps on near-u64 length, defeating the arena-ceiling guard | **FIXED** — length cap before rounding |
| 13 | MED | hardening | elf.cyr | ELF `p_vaddr` had no upper bound → segment can land in mmap arena + alias future mmap | **FIXED** — cap `p_vaddr+p_memsz <= 0x10000000` (both load paths) |
| 15 | LOW | hardening | syscall.cyr | epoll_create(19) stored `kmalloc(128)` without a null check | **FIXED** — alloc before claiming slot; -1 on OOM |
| 17 | LOW | hardening | syscall.cyr | epoll_wait validated events buf with bare ptr before writing up to ~192 B | **FIXED** — `is_user_range(arg2, arg3*12)` |
| 18 | LOW | hardening | syscall.cyr | timerfd_settime(23) operated on an fd slot without a tag check | **FIXED** — `ktag==VFS_TIMERFD` check |
| 19 | LOW | hardening | net_dns.cyr | `dns_qname_encode` had no overall length cap before the 320 B `qbuf` | **FIXED** — 255-byte hostname cap |
| 20 | LOW | hardening | fatfs.cyr | `fatfs_read` lacked the FAT-chain cycle guard `exfat_read` has | **FIXED** — iteration counter (cycle re-reads to maxlen otherwise) |
| 26 | LOW | dead-code | syscall.cyr | epoll_ctl op==2 clears ALL watches (not just `arg3`) — misleading | **FIXED** — comment clarified |
| 11 | MED | memory-safety | elf.cyr | malformed on-disk ELF leaks per-process page tables + mapped 2 MB pages (no teardown on failure paths) | **DEFERRED** — needs teardown/pre-pass in the iron-validated exec path; own focused bite (1.41.x exec-hardening) |
| 16 | LOW | hardening | proc.cyr | `proc_reap` reclaims the proc-table slot only when it's the top slot; a non-top reap leaks toward the 16-cap | **DEFERRED** — non-triggering under the current run-to-completion single-foreground model |
| 14 | LOW | hardening | syscall.cyr | `stack_canary_check` coverage inconsistent across return paths | **DEFERRED** — not a vuln; folds into the canary refactor (#23) |
| 21 | LOW | refactor | syscall.cyr | ksyscall if-ladder dispatches syscall numbers out of numeric order | **DEFERRED** — byte-identical but a large diff in a security-critical file; own pure-refactor cut |
| 22 | LOW | refactor | syscall.cyr | FS syscalls duplicate validate + resolve_mount + per-backend shape | **DEFERRED** — not provably behavior-equivalent (fix_sound=false); own cut |
| 23 | LOW | refactor | syscall.cyr | `stack_canary_check` scattered; could collapse to one tail check | **DEFERRED** — not provably behavior-equivalent; own cut |
| 24 | LOW | dead-code | syscall.cyr | dead `return 0` after `arch_halt()` in reboot | **DEFERRED** — cosmetic; left as a defensive no-op |
| 25 | LOW | dead-code | syscall.cyr | Tier-1/2/3/4 section comments no longer describe contiguous ranges | **DEFERRED** — folds into the #21 reorder |

**Fixed: 15** (all 10 HIGH + 2 MEDIUM + 3 LOW). **Deferred: 8**, each with a reason (invasive
in the iron-validated exec path, non-triggering under the current model, or a behavior-equivalent
refactor that doesn't belong bundled with security fixes).

## Why the refactors are deferred, not done

A hardening cut should not carry behavior-equivalent rewrites of the file it is hardening. #22
(FS-syscall dedup) and #23 (canary single-tail) both came back `fix_sound=false` — their
equivalence isn't provable by inspection — and #21 (numeric reorder) is a large diff in the exact
security-critical dispatcher 1.41.5 is changing. They are real cleanups, but they belong in a
**separate pure-refactor cut** validated independently against the sweep, so a refactor typo can't
hide behind a security diff.

## Validation (QEMU, x86_64)

- `scripts/sweep.sh` — **7/7** (FAT/exFAT read+write, ext2 W1-W5, exec-from-disk) — no behavior
  regression from any of the 15 fixes.
- `FS_SYSCALL_SELFTEST` — **`fssys: ALL PASS`**: mkdir / open-O_CREAT / stat / rename / getdents /
  unlink / rmdir all pass through `ksyscall` with the new `is_user_range` ceiling + the basename
  cap (scratch via `pmm_alloc_2mb` at 2-14 MB, below the ceiling).
- `scripts/agnsh-smoke.sh` — **PASS** ×N: real ring-3 `agnsh` boots to its prompt — read(fd=0) /
  write / mmap user pointers all live in the validated `[0x200000, 0x40000000)` window.
- `scripts/check.sh` — **11/11**.
- Production build clean: 1,062,872 → 1,063,016 B.
