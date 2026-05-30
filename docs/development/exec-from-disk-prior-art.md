---
name: Exec-from-disk — prior art + arc plan
description: Multi-source survey of ELF loading + execve, AGNOS current exec state (buffer-based elf_load), and the 1.40.x bite ladder for loading + running a program from the filesystem (the second base-maturity exit leg)
type: prior-art
---

# Exec-from-disk — Prior Art + Arc Plan (1.40.x)

> Companion to [`vfs-generic-write-prior-art.md`](vfs-generic-write-prior-art.md), [`ext4-jbd2-prior-art.md`](ext4-jbd2-prior-art.md). Same discipline: derive the converged shape from multiple sources, port to AGNOS conventions, ladder into small QEMU-validated bites, then a user-driven iron burn. Per [[feedback_redesign_dont_reinvent]] Linux is **one source of many**, never the singular reference.

## 0. Why this arc (the base-maturity *second* leg)

The "base" maturity exit is **FS-crash-safe + exec-from-disk** ([[project_agnos_maturity_arc]]). The crash-safe leg is complete and (mostly) iron-validated:

- **1.37.x** ext4 extent allocation (iron Attempt 1373).
- **1.38.x** jbd2 journaling (iron `13810_*` re-burn).
- **1.39.x** VFS generic-write lift (verb surface + subdirs; iron burn pending — to ride with this arc's burn).

That makes the filesystem **durable and writable from the shell**. The remaining base-exit leg is **running a program loaded from that filesystem** — today programs only come from the in-memory initrd. 1.40.x closes it: read an ELF from a VFS path, load it, run it, collect its exit code.

This was an explicit **non-goal** of the VFS lift (`vfs-generic-write-prior-art.md` §5) — deferred to its own arc, which is this one.

## 1. AGNOS current state (the gap to close)

Mapped from the kernel 2026-05-28 (agnos 1.40.0). Files: `kernel/core/elf.cyr` (~120 LOC), `kernel/core/proc.cyr`, `kernel/core/sched.cyr`, `kernel/core/initrd.cyr`, `kernel/core/syscall.cyr`, `kernel/core/vfs.cyr`, `kernel/user/shell.cyr`.

**Exec already exists — but only from memory.** `elf_load(elf_addr, elf_size)` (`elf.cyr:5`) is a complete, security-hardened **static ELF64 loader from a memory buffer**:

- validates ELF magic + class=2 (64-bit); entry must be ≥ `0x200000` (userspace);
- bounds-checks the program-header table within `elf_size`; `phnum ≤ 64`, `phentsize ≥ 56`;
- per `PT_LOAD`: validates `p_offset`/`p_filesz`/`p_memsz` within the file, `p_memsz ≥ p_filesz`, no overflow, `p_vaddr ≥ 0x200000`, segment ≤ `0x2000000` (32 MB);
- creates a per-process address space (`proc_create_address_space`), maps 2 MB pages (`proc_map_page`), `memcpy`s each segment, zeros BSS, allocates a user stack with a guard gap;
- returns a pid. Exposed as **syscall #3 `spawn(elf_addr, elf_size)`** (`syscall.cyr:108`).

The process/scheduler plumbing is all present: `proc.cyr` (address spaces, page mapping), `sched.cyr`, `spawn_user_proc`, **`waitpid`** (syscall #4), per-process exit codes.

**The single missing capability: disk → contiguous buffer.** `elf_load` consumes a buffer that *already holds the whole ELF*. Today that buffer is the **initrd** region (`initrd.cyr` — a memory image set up at boot). Nothing reads an ELF off a real filesystem. Two concrete blockers:

1. **The 4 KB memfile cap.** `fatfs_open`/`exfat_open`/`initrd_open` wrap files as a `VFS_MEMFILE` capped at **4096 bytes** (`vfs.cyr`, `fatfs.cyr:fatfs_open`). A real static binary is hundreds of KB to a few MB — it cannot be read through the current open path.
2. **No path → ELF-buffer route.** There is no "read this whole file from the FS into a buffer" primitive; reads are streamed in ≤ 4 KB chunks via `vfs_read` against a memfile, or block-level via `ext2_read_at`.

**What 1.39.x already gave us (the enabler).** The VFS generic-write lift made **ext2 + FAT + exFAT all reachable by path, including subdirectories** (`fatfs_resolve_parent`/`exfat_resolve_parent`, the `*_in_dir` finders). So exec-from-disk can resolve a program path on whichever FS backs it — the read side is the only new plumbing.

**The shell invocation seam.** `sh_exec` (`shell.cyr:780`) dispatches verbs; an unrecognized command falls through to `kprint("unknown: ", 9)` (`shell.cyr:1080`). That fallthrough — or an explicit `run`/`exec` verb — is where a typed program name becomes a load+spawn.

### Current vs. needed

| Step | Today | Exec-from-disk needs |
|------|-------|----------------------|
| locate program | initrd name match (memory) | VFS path resolve (ext2/FAT/exFAT, incl. subdirs) — **have it (1.39.x)** |
| get ELF bytes | already in memory (initrd) / ≤ 4 KB memfile | **read the *whole* file into a bounded buffer** — NEW |
| load + map | `elf_load(addr, size)` — **have it, hardened** | reuse unchanged |
| run | `spawn` (#3) + scheduler + `waitpid` (#4) — **have it** | reuse |
| invoke | initrd-driven at boot / selftest | **shell `run <path>` verb** (then bare-name) — NEW |

## 2. Prior art (multi-source)

**xv6 `exec.c`** — the canonical teaching shape. `namei(path)` → `ilock(ip)` → `readi(ip, &elf, 0, sizeof elf)` (read the ELF header from the inode) → validate `ELF_MAGIC` → for each `PT_LOAD`: `uvmalloc` the new pagetable to `ph.vaddr+ph.memsz`, then **`loadseg(pagetable, ph.vaddr, ip, ph.off, ph.filesz)`** reads the segment *directly from the inode* into the freshly-mapped pages. Builds the user stack with `argv`. **Commits the new pagetable only on success** — the old image is untouched until the very end, so a mid-load failure leaves the caller intact. **Lesson**: you don't need a whole-file buffer — stream each segment from disk into its mapped pages; and switch address spaces only after a fully-successful load.

**Linux `fs/binfmt_elf.c` `load_elf_binary`** — the production heavyweight. Reads the ELF + program headers, handles a `PT_INTERP` (dynamic linker `ld.so`), `mmap`s `PT_LOAD` segments from the file through the page cache (demand-paged), sets up the ELF auxiliary vector (`auxv`), `argv`/`envp`, brk. **Lesson**: the static subset is small; the bulk is dynamic linking + demand paging + auxv, all of which AGNOS does **not** need now. AGNOS is sovereign and statically linked.

**4.4BSD / FreeBSD `imgact_elf.c`** — "image activators" pick a loader by magic; `exec_new_vmspace` builds the address space; segments mapped from the vnode. Same static-load core as xv6, wrapped in the activator abstraction. **Lesson**: keep the loader pluggable by magic (ELF now; `#!`-script or other formats later) — but that's a later abstraction, not a 1.40.x need.

**Plan 9** — `exec` is a syscall that reads the program from the file server over 9P; the kernel validates the `a.out`/ELF header and faults pages in. **Lesson (aspirational)**: exec is just "read a validated image from a file-like source" — the source being a local FS or a network FS is immaterial to the loader.

### Converged shape

`resolve path → read + validate ELF header → for each PT_LOAD bring bytes into the new address space → set entry + user stack (+ argv/env) → commit (switch) only on success → schedule`. The two design axes that differ across sources:

- **slurp-whole-file vs. stream-per-segment.** Linux mmaps (demand); xv6 streams per-segment from the inode; the simplest is to slurp the whole file into one buffer then load.
- **commit timing.** Always build the new image fully before abandoning the old (xv6's "commit on success"). AGNOS's `elf_load` already builds a *separate* `new_cr3` and only the new process runs it — the caller's address space is never mutated, so this property holds for free.

## 3. AGNOS design decisions (proposed)

1. **Slurp-then-load, not stream-per-segment (for now).** `elf_load` already takes a full `(addr, size)` buffer and is hardened + iron-adjacent. Reusing it **unchanged** is the lowest-risk path. So: read the whole ELF from the VFS path into one bounded kernel buffer, then `elf_load(buf, size)`. The xv6 `loadseg`-style per-segment streaming (no whole-file buffer) is a **later optimization** if/when binaries get large — noted, not done.
2. **Load buffer — REOPENED at 1.40.1 (the `kmalloc` plan is dead).** `kmalloc` *and* `pmm_alloc` both cap at a single **4 KB page** (`heap.cyr` slab classes top out at 4096; `pmm_alloc` returns one `i*0x1000` page) — AGNOS has **no large-contiguous allocator**. So a whole-ELF buffer can't be `kmalloc`'d. The 1.40.2 load path picks from:
   - **(a) Streaming loader** (xv6 `loadseg` style) — read the ELF header into a 4 KB scratch, then read each `PT_LOAD` segment *directly into its mapped process pages* via an offset-read. Never needs a big buffer. Clean for **ext2** (`ext2_read_at` takes an offset); FAT/exFAT have no offset-read (`fatfs_read`/`exfat_read` read from chain start), so FAT/exFAT-exec would need cluster-skipping added — defer it (exec-from-ext2 first, since the agnos-fs root is ext2).
   - **(b) Reserved load window** — a fixed module-global buffer sized to a max-binary cap; slurp the whole ELF (via `vfs_read_file`), reuse `elf_load` unchanged. Works for all 3 FSes immediately; costs that much always-resident kernel memory.
   - **(c) `pmm_alloc_contiguous(n)`** — add a contiguous-multi-page allocator, then slurp. Most general; new allocator code.
   Note: a **true module-global** `var X[N]` is `N×8` bytes, but `var X[N]` **in the kernel main body is function-local** (`N` bytes — the main body runs as a PARSE_PROG function), so a large fixed buffer must live at file top-level (like `vfs_table`). [[cyrius-var-array-u64-units]].
3. **A `vfs_read_file(path, namelen, dst, cap)` primitive** that resolves the FS (ext2 path-aware via the shell's CWD scoping; FAT/exFAT via the 1.39.x resolver) and reads the **whole** file — NOT the 4 KB-capped memfile. ext2: `ext2_open` + an `ext2_read_at` loop. FAT/exFAT: read the full cluster chain (the exec path lifts the 4 KB cap that `fatfs_open`/`exfat_open` impose for `cat`). This is the one genuinely new piece of plumbing.
4. **Shell invocation = explicit `run <path>` verb first.** Unambiguous, no collision with builtins; resolves the path (CWD-relative via `sh_abspath` + the 1.39.9 resolver), reads → `elf_load` → marks ready → `waitpid` → prints the exit code. **Bare-name fallthrough** (type the program name, like a normal shell) is a clean follow-on once `run` is proven — it hangs off the existing `unknown:` seam (`shell.cyr:1080`).
5. **Static ELF only; argv/env deferred.** No dynamic linker (`PT_INTERP` rejected — sovereign + static), no `auxv`, no `$PATH` search, no `#!` scripts, no `fork`/COW, no demand paging. argv/env passing is a follow-on bite (the user stack is already built; argv just adds to it).

## 4. Bite ladder (Claude-determined per the standing delegation; user tags each cut)

| Bite | Cut | Scope | Smoke gate | Status |
|------|-----|-------|------------|--------|
| **0** | 1.40.0 | **Arc open** — this prior-art doc + lean version bump + tracking surface. No kernel code. | — | ✅ this cut |
| **1** | 1.40.1 | **`vfs_read_file` — arbitrary-size whole-file read.** Resolve FS (ext2 / FAT / exFAT via the 1.39.x resolver), read the full file past the 4 KB memfile cap into a caller buffer. The real new primitive. *(Surfaced the no-large-allocator finding → design #2 reopened.)* | smoke: read a >4 KB (6000 B) seeded file back, verify bytes past offset 4096, each FS | ✅ **DONE** — `vfsrf` gates green on FAT + exFAT; build 1,014,528 → 1,024,256 B |
| **2** | 1.40.2 | **Streaming ELF loader (the LOAD half).** `elf_load_from_file` reads the header into a scratch, then streams each `PT_LOAD` segment's bytes **directly into its physical pages via the kernel identity map** (no CR3 switch — the switch-into-half-built-AS approach hung). `vfs_read_file_at`/`vfs_file_size` (ext2 offset read/size). `run <path>` loads + reports. | exec-smoke: write ELF→ext2, stream-load, parse (`entry=0x400078`), map, `fsck` clean | ✅ **DONE** — build 1,024,256 → 1,033,296 B |
| **3** | 1.40.3 | **Ring-3 execution bring-up (the RUN half) — DONE.** Brought up the entire never-run ring-3 + SYSCALL path. **Ten first-run bugs** fixed: the core blocker was the SYSCALL stub's `mov cr3, r10` mis-encoded with REX.R (`44`→cr11→#UD) instead of REX.B (`41`); plus LSTAR programmed via NX-stack bytecode, EFER.SCE not in effect, KPTI dual-CR3 mismatch (collapsed to one full per-process CR3), syscall kernel stack VA colliding with the user stack, SMAP blocking the user-buffer copy (STAC/CLAC), APIC-read-before-CR3-switch, timer-in-ring-3 (IF masked), 2 MB-vs-4 KB page alloc, and fd 1/2 not wired to the console. | `exec-smoke` PASS (6/6): `EXEC-DISK-OK` + `run: exit 42`, `fsck` clean | ✅ **DONE** — build 1,033,304 B |
| **4** | 1.40.4 | **CWD-relative + subdir program paths + ENOEXEC/E2BIG bounds.** `run` resolves a subdir/CWD path (`sh_abspath` + `ext2_path_lookup`) and refuses non-ELF (ENOEXEC) / >16 MB (E2BIG) cleanly. | exec-smoke: `/notelf` refused → `/bin/prog2` loaded from a subdir, run in ring 3 (`EXEC-DISK-OK` + exit 42), `fsck` clean | ✅ **DONE** — build 1,033,448 B. Follow-on: multi-run/shell-loop continuation + ~17% exec flake (hardening) |
| **5** | 1.40.5 | **Arc-close hardening + automated sweep + manual iron plan.** Fixed clean `exec_and_wait` return (full setjmp/longjmp of callee-saved + caller frame → caller continues, shell-loop shape) + the kstack-VA-collision flake (reserve the SYSCALL stack right after `heap_init` → phys 0x200000, below user VAs). Added `scripts/sweep.sh` (one-command QEMU sweep of both arcs, 7/7) + [`exec-iron-manual-tests.md`](exec-iron-manual-tests.md) (on-iron checklist). | `sweep.sh` 7/7; exec-smoke + `exec: selftest done` green | ✅ **DONE** — build 1,033,512 B. **Arc functionally complete; combined VFS+exec iron burn is user-driven.** |
| **6** | 1.40.6 | **Multi-`run` in one boot** (post-arc follow-on). `kernel_resume` restores the boot CR3 on program exit (the per-process CR3 didn't map the NVMe BAR → the next run's ext2 read faulted); `sh_cmd_run` sets `proc_current = pid` (per-run exit code). Programs run back-to-back. | exec-smoke runs `/bin/prog2` ×2 (EXEC-DISK-OK ×2, exit 42 ×2); sweep 7/7 | ✅ **DONE** — build 1,033,528 B |
| **7** | 1.40.7 | **argv passing.** `elf_load_from_file` builds the SysV init stack (`rsp→argc/argv[]/NULL/envp NULL/auxv AT_NULL`, strings higher, 16-aligned); `sh_cmd_run` splits the path token from args. `/bin/argc` exits with argc. | exec-smoke `run /bin/argc one two` → `run: exit 3`; sweep 7/7 | ✅ **DONE** — build 1,034,704 B (envp/auxv contents deferred) |
| **8** | 1.40.8 | **Final hardening + burn prep** (updated scripts; pre-burn sweep). | sweep green | |
| **iron** | — | **Combined VFS (1.39.x) + exec (1.40.x) iron burn** on archaemenid — [`exec-iron-manual-tests.md`](exec-iron-manual-tests.md) A1–A6 (ring-3 `run` on real Zen) + B1–B4 (FAT/exFAT verbs), extends [`#tracker-139-cycle`](iron-nuc-zen-log.md#tracker-139-cycle). Closes both arcs on hardware. | the manual checklist's dispositive bars | pending user burn |

Test ELF: the selftest seeds a minimal known-good static ELF64 (the existing in-kernel `user_test_proc` image, or a tiny hand-built one that writes a marker via `write(1,…)` and `exit(code)`) onto the FS, then `run`s it and gates on the marker + exit code reaching the log — mirrors the 1.37.x self-seed pattern (FB/serial-readable, deterministic, no host-side seeding needed for the QEMU smoke).

## 5. Non-goals (this arc)

- **Dynamic linking** (`PT_INTERP` / `ld.so`) — sovereign + static only.
- ~~**argv** passing~~ — **done 1.40.7 (count) + 1.40.8 (string bytes, hardened + bounded)**. **envp / auxv** *contents* still deferred (the slots are zeroed/`AT_NULL`; programs that need real env/auxv come later).
- **`$PATH` search**, **`#!` shebang scripts**, **fork/COW**, **demand paging / `mmap` from file** — all later.
- **Stream-per-segment loading** (xv6 `loadseg` style) — optimization deferred; slurp-then-load first.

---

*Drafted 2026-05-28 at the 1.40.x kickoff. Bite structure is Claude-determined per the standing delegation; releases are user-tagged. Update in place as bites land.*
