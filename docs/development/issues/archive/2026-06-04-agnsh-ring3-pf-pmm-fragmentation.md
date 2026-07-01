# agnsh ring-3 #PF after banner — RESOLVED: kernel PMM cross-class fragmentation (NOT cyrius, NOT agnsh)

> **Naming note:** this file was originally named `…-frame-smash.md` after an early hypothesis. That
> hypothesis was **wrong** (it rested on a stale disassembly — see Symptom). The actual dominant fault is a
> kernel page-*mapping* failure, not a stack frame-smash. The file was renamed to
> `…-pf-pmm-fragmentation.md`; a genuine (but separate and rare) frame-smash survives as **residual bug #2**.

> **2026-06-05 UPDATE — RESOLVED.** A validated kernel fix now drops the ring-3 #PF to
> **0 across 52 boots** (was ~50%). Root cause is the **PMM allocation-class fragmentation**
> below (not the CR3-walk theory of Experiment 4 — see the RESOLUTION section at the bottom,
> which supersedes the "candidate fixes all fell short" conclusion). Fix:
> `pmm_alloc()` allocates **top-down**. One rarer, SEPARATE residual bug (SYSCALL-path RBP
> smash, `CR2=0x37fed8`) remains. Read the RESOLUTION section first; the body below is the
> prior session's (correct, convergent) diagnosis trail.

**Date:** 2026-06-04 / 2026-06-05
**Symptom:** kybernet (PID1) execs `/bin/agnsh`; agnsh prints its banner, then a
ring-3 `#PF` (`v=0e cpl=3`) freezes it before the prompt, on ~50% of boots. Two
fault faces, both DOWNSTREAM of one root cause (a mis-mapped heap page — see RESOLUTION):

- `e=0007 CR2=0x10000000 IP=0x42c0b8` — the first ring-3 write to the freshly-mmap'd
  heap page faults (present-supervisor PDE). **An early read of this as a "frame-smash /
  rbp corrupted to `0x10000020` in an orphan epilogue" was WRONG** — it came from a stale
  (Jun-3) disassembly; in the live binary that address is a plain heap store and `rbp`/`rsp`
  are healthy. (The genuine RBP smash is the rare, separate residual bug #2.)
- `e=0005 CR2=0x8 IP=0x40469f` — NULL+8 deref: `alloc` returned 0 (heap unmappable), agnsh
  chained the NULL. Same root cause.

## Layer attribution: KERNEL (agnos). Definitively NOT cyrius, NOT agnsh.

### Experiment 1 — agnsh logic is exonerated
`heapstress.cyr` (agnoshi/heapstress.cyr) contains ZERO agnsh source — only the
cyrius stdlib (`lib/alloc.cyr` + `lib/vec.cyr` + `lib/str.cyr`) doing a malloc /
store-7-fields / chain loop. Built `cyrius build --agnos`, seeded as `/bin/agnsh`,
booted 15x via `/tmp/repro-loop-bin.sh`:

```
TALLY [heapstress] N=15 : #PF=12  #UD=0  clean=3  other=0
```

Same two faults (`CR2=0x10000000` and `CR2=0x8`), same ~12/15 rate. => the defect
is reproduced by the cyrius stdlib heap path on the agnos kernel with NO agnsh
code present. agnsh's own logic is not implicated.

### Experiment 2 — elf.cyr init-stack offset is exonerated
The uncommitted `kernel/core/elf.cyr` change relocates the init stack 0x3000 ->
0x1FF000. Built + booted 15x each:

```
TALLY [baseline_1FF000] N=15 : #PF=13  clean=2
TALLY [committed_3000]  N=15 : #PF=11  clean=3  other=1
```

Identical fault set at both offsets. The stack relocation neither causes nor fixes
the bug. (It is a legitimate "more downward stack room" improvement, orthogonal.)

### Experiment 3 — the fault is on the FIRST ring-3 write to the mmap'd heap page
heapstress disasm: IP `0x40379f` = `mov %rax,(%rcx)` with `rcx = 0x10000000` (the
value mmap just returned). The store to the freshly-mmap'd page faults
`e=0007` (P=1, W=1, U=1 = **US protection violation on a PRESENT page**). The
`CR2=0x8` variant (`mov (%rax),%rax`, rsi=NULL) is the secondary "alloc returned 0,
chained NULL" effect of the same root cause.

### Experiment 4 — root mechanism (page-table dumps from QEMU `-d int` + kprint)
Instrumented `sys_mmap` / `elf_load_from_file` (QEMU-only kprints, since reverted):

- At **exec time, under the boot CR3 (identity)**: the per-process PD entry for the
  mmap arena base is `PD[128] = 0x10000083` — i.e. the COPIED kernel identity
  mapping: phys 0x10000000 | flags **0x83 (Present, RW, SUPERVISOR — NO US bit)**.
  Source: `proc_create_address_space` copies kernel PD `[0..510]` from `0x3000`
  (proc.cyr:210-213), and `pt_init` (paging.cyr:11-18) identity-maps ALL 512 PD
  entries `[0,1GB)` as present **supervisor** 2 MB pages. So VA 0x10000000 is a
  present supervisor page in every process from birth.

- `sys_mmap` is supposed to overwrite `PD[128]` to user (`0x87`) via
  `proc_map_page` (proc.cyr:382-401). It writes `pde = 0xa00087` and that value
  reads back **at the broken walk location** — but the write does NOT reach the PD
  the running ring-3 process actually walks. Confirmed: inside `sys_mmap`,
  `load64(cr3)` (the per-process PML4[0]) reads **0**, while `pde` reads `a00087`.
  Both are read by the SAME `proc_map_page`-style walk, so `proc_map_page` is
  computing `pd_addr` from a bogus `pml4e=0` and storing the user PDE to the wrong
  physical location. The REAL `PD[128]` stays `0x10000083` (supervisor) -> ring-3
  write faults `e=0007`.

  Dump (3 boots):
  ```
  MMAP va=10000000 pc=2 cr3var=57d000 exec_cr3_g=57d000 pml4e=0 pde=a00087
  ```
  `proc_current=2` (correct), `cr3 == exec_cr3_g` (correct CR3 value), but
  `load64(cr3) == 0`.

### Why load64(cr3)==0 inside the syscall
The SYSCALL handler runs under the **per-process CR3**, not the boot CR3:
`exec_and_wait` sets `kpti_kernel_cr3 = kpti_user_cr3 = exec_cr3_g` (ring3.cyr:
61-62), and the syscall stub switches to `kpti_kernel_cr3` on entry
(syscall_hw.cyr:161-171). `proc_map_page` / `sys_mmap` then do
`load64(cr3)`/`store64(...)` treating physical page-table addresses as virtual
addresses — only valid under a faithful phys==VA identity map. Under the
per-process CR3 (whose page-table pages have themselves been allocated and, on the
flaky boots, partially clobbered), that walk reads 0 and the user PDE is written to
the wrong place. **Flaky + allocation-layout-dependent** because it depends on
where the page-table pages landed and what aliases them that boot (the kernel
boot "Heap:" base and `pmm_next_free` KASLR seed both vary run-to-run).

## Candidate fixes TESTED and their results (all FELL SHORT of the >=15-clean bar)

1. **`invlpg`/CR3-reload in `proc_map_page`** (TLB flush after the PDE rewrite).
   Result: `TALLY heapstress_flush N=15 : #PF=11`. No effect — the syscall-return
   CR3 reload already flushes; the PDE itself is written to the wrong table.
   REVERTED.

2. **PMM allocation-class partition** (a parallel agent's `pmm.cyr` patch: region 2
   = exclusive 4 KB page-table pool, `pmm_alloc_2mb` carves only regions 3-7, so a
   2 MB `memset` can never zero a live page-table page). Compelling diagnosis with
   GDB ground truth (a faulting boot had CR3 region-2 with `*(CR3)=0`). Result:
   `TALLY fix_agnsh N=15 : #PF=13` and `fix_heapstress N=15 : #PF=13`. **Did NOT
   eliminate the fault** — so memset-zeroing-a-page-table is at most a contributing
   alias, not the whole mechanism. REVERTED (note: this patch was applied then
   reverted out-of-band during the session; tree is back at HEAD).

3. **Run the `sys_mmap` map loop under the boot CR3 (0x1000, full identity), then
   restore the per-process CR3.** This directly targets the "page-table walk under
   the wrong CR3" mechanism. Result: the `CR2=0x10000000` fault DISAPPEARED but was
   replaced by a **uniform** `CR2=0x8` (`TALLY bootcr3_agnsh N=15 : #PF=15`). So the
   boot-CR3 switch fixed the supervisor-PDE problem but broke something else
   deterministically (likely the `cr3_load(cr3)` restore vs SYSRET's own CR3 reload,
   or it surfaced the NULL-chain path uniformly). REVERTED.

## Where the real fix likely lives (KERNEL — agnos)
The architectural defect is that **page-table-editing syscalls (`sys_mmap`,
`sys_munmap`, and `proc_map_page`) run under the per-process CR3 and edit the page
tables via `load64`/`store64` on physical addresses as if identity-mapped, which
is only reliable under the boot CR3.** Two converging directions a fix should
weigh (needs an owner with more iron-time):

- **A. Edit page tables under a guaranteed identity map.** Switch to boot CR3
  (0x1000) around the page-table edits in `sys_mmap`/`sys_munmap`/`proc_map_page`,
  then restore — but do it correctly w.r.t. the SYSRET CR3 reload (experiment 3
  got halfway: the supervisor PDE was fixed, a separate `CR2=0x8` appeared). The
  restore/return interaction with `syscall_hw.cyr:264-272` (SYSRET reloads
  `kpti_user_cr3`) must be made consistent.

- **B. Don't seed the mmap arena as present-supervisor in the first place.**
  `proc_create_address_space` copies pt_init's present-supervisor identity entries
  for the whole 0-1 GB PD, including the mmap arena `[0x10000000, 0x40000000)`
  (pd_idx 128..511). If those arena entries were left NOT-PRESENT (0) in the
  per-process PD, an un-mapped arena access would fault cleanly `e=0006`
  (not-present) instead of `e=0007` (supervisor present), AND there would be no
  stale supervisor PDE to "win" when `proc_map_page`'s write goes astray. This does
  not by itself fix the wrong-CR3 walk, but it removes the present-supervisor trap
  and is a correctness improvement regardless. Pairs naturally with A.

### Precise source pointers (agnos kernel)
- The present-supervisor seed of the arena: `kernel/arch/x86_64/paging.cyr:11-18`
  (`pt_init` maps all 512 PD entries `0x83`) + `kernel/core/proc.cyr:210-213`
  (`proc_create_address_space` copies `[0..510]` into the per-process PD).
- The mis-targeted PDE write: `kernel/core/proc.cyr:382-401` (`proc_map_page`)
  called from `kernel/core/proc.cyr:436-458` (`sys_mmap`) — the
  `load64(cr3)`-based walk under the per-process CR3 reads `pml4e=0`.
- The CR3 context the syscall runs under: `kernel/arch/x86_64/ring3.cyr:61-62`
  (`kpti_kernel_cr3 = kpti_user_cr3 = exec_cr3_g`) +
  `kernel/arch/x86_64/syscall_hw.cyr:161-171` (stub switches to `kpti_kernel_cr3`).

### The "corrupting write" (planting 0x10000020 into the saved-rbp slot)
There is **no single kernel store that writes 0x10000020 into the user stack.** The
heap pointer reaches the user stack via the GUEST program itself: agnsh/heapstress
`mov %rsp,%rbp`-frames a function, the FIRST write to the mmap'd page (the
function storing into the malloc'd record at `[0x10000000]`, e.g. heapstress
`make_record` `store64(rec+0, ...)`) faults `e=0007` because `PD[128]` is a stale
present-supervisor entry the kernel failed to flip to user. The "rbp=0x10000020 in
an orphan epilogue" is a DOWNSTREAM artifact: after the faulting page-write the
program's frame/return slots already hold heap pointers (the record being built),
and the redirected RIP lands in the DCE-orphan epilogue that reloads rbp from a
heap-pointer slot. So: not a stray kernel write into the stack — a kernel
**failure to map a page user-writable**, surfacing as the program faulting on its
own heap store.

## Repro harnesses (kept)
- `/tmp/repro-loop.sh <label> <N>` — boots the real `agnsh_agnos`, tallies faults.
- `/tmp/repro-loop-bin.sh <label> <N> <binary>` — same, but seeds `/bin/agnsh`
  with an arbitrary ring-3 ELF (used for `heapstress_agnos`).
- `agnoshi/heapstress.cyr` — agnsh-free stdlib heap-stress repro.

## NOT a cyrius bug
The cyrius stdlib heap path (`alloc`/`vec`) merely calls `mmap` (syscall 27) and
writes the returned page. The host (Linux) build of the same source passes smoke
59/59. The defect is entirely in agnos's mmap / page-table / syscall-CR3 path.
No cyrius edit is warranted.

---

## RESOLUTION (2026-06-05) — top-down `pmm_alloc`, validated 0 #PF / 52 boots

The prior conclusion ("all candidate fixes fell short; the real fix is in the wrong-CR3
page-table walk") is **superseded**. A different PMM change — **not** the region partition
that failed at #PF=13 — eliminates the fault.

### Decisive distinguishing experiment

Pinning `pmm_next_free` to a fixed page (KASLR off) made the fault **vanish 14/14**; KASLR
on, ~50%. A *kernel-only* change flips the outcome ⇒ kernel layer, and specifically the
**KASLR-seeded PMM layout** is the non-determinism source. (This also explains the prior
report's "flaky, allocation-layout-dependent, boot Heap base varies" observations.)

### Why the region PARTITION failed but TOP-DOWN works

- **Partition** (region 2 = 4 KB-only, `pmm_alloc_2mb` carves 3–7): relocates the heap's
  *physical* region. With QEMU `info mem` ground truth, the relocated heap (`0x10000000`)
  came back **absent** from the active CR3 deterministically — i.e. the relocation exposed
  the latent `vmm_map(phys,phys)`/per-process-PD breakage the prior report's Experiment 4
  describes. So the partition traded a flaky fault for a deterministic one. (#PF=13/15.)
- **Top-down** `pmm_alloc` (allocate 4 KB pages from page 4095 → 1024): 4 KB page-table /
  DMA pages cluster in HIGH 2 MB regions; `pmm_alloc_2mb` keeps scanning LOW→high and gets
  the **same low regions agnsh always used** (code/stack/heap), so the heap's physical
  region is unchanged from the working baseline — only the cross-class fragmentation is
  removed. The KASLR-scattered 4 KB pages can no longer pick a *random* 2 MB region to
  poison. (#PF=0.)

So the operative root cause is: **`pmm_alloc` (4 KB) and `pmm_alloc_2mb` (2 MB) share one
6-region pool, and the KASLR-randomized bottom-up 4 KB first-fit scatters a page-table page
into a random 2 MB region every boot; one set page makes `pmm_alloc_2mb` skip that whole
region, so on ~half of boots agnsh cannot assemble its 3 contiguous regions.** The
"present-supervisor PDE / wrong-CR3 walk" mechanism of Experiment 4 is a real adjacent
fragility (and a good follow-up hardening per directions A/B), but it is **not** what
gates agnsh boot-to-shell — the fragmentation is.

### Validation (`/tmp/repro-loop.sh`, qemu `-d int`)

| batch | runs | ring-3 #PF | note |
|-------|------|-----------|------|
| fixed-hint probe (KASLR off) | 14 | 0 | proves layout-dependence |
| topdown | 18 | 0 | — |
| topdown (2nd) | 16 | 1 | the 1 is the SEPARATE syscall-RBP bug |
| topdown + proc-experiment | 18 | 0 | deep `v=0e.*cpl=3` scan: none |

**Net: 0 PMM-fragmentation faults across 52 runs** (the lone outlier is bug #2 below).

### The fix
`kernel/core/pmm.cyr` — `pmm_alloc()` now scans `for (i = 4095; i >= 1024; i = i - 1)`
(top-down) instead of bottom-up from the KASLR `pmm_next_free`. ~14 lines. Final `build/agnos`
(clean-isolation rebuild, `pmm.cyr` the only change vs HEAD): **1,070,480 B**, multiboot2 OK.

### Residual bug #2 (separate, much rarer — NOT fixed)
1 of 52 boots hit `#PF IP=0x40986b CR2=0x37fed8` in agnsh's mmap-wrapper epilogue
(`mov -0x28(%rbp),%r15`) with **RBP smashed to 0x37ff00** (RSP healthy 0x1002ee0). 0x37ff00
sits just under the SYSCALL kernel stack top (0x3F0000); the mmap syscall had just
*succeeded* (RAX=0x10000000). This is a genuine frame-smash in the **SYSCALL entry/return
path** (`kernel/arch/x86_64/syscall_hw.cyr`) — the user RBP is not preserved across the
kstack switch — and is the likely original "rbp→kernel-ish pointer" in the task brief.
Independent of the PMM fix; needs its own bite.

### Methodology caveat for future PT debugging
Reading `*(CR3 & ~0xfff)` in gdb is a TRAP on this kernel: the per-process PML4 physical
page lives in `[0x400000,0x600000)`, which *aliases the user CODE virtual range*, so gdb
resolves the CR3 value as a VA through the very tables under inspection and returns code
bytes / zeros — not the PML4. (This is also why `load64(cr3)==0` appeared in Experiment 4.)
Use QEMU monitor `info mem` / `xp` (physical) for authoritative page-table state.

---

### Independent re-validation in clean isolation (2026-06-05, decider session)

The fix was re-validated from a **verified-clean HEAD baseline**, because the working tree
was found NOT clean as a prior lane had claimed: `pmm.cyr` carried the top-down fix
(unstaged) AND `proc.cyr` carried a Lane-C `cr3_load(0x1000)` experiment (staged) that had
FAILED its own validation. Both were stashed; the two candidates were then tested one at a
time against a freshly-built clean-HEAD kernel.

| kernel build | change in tree | repro | ring-3 #PF |
|---|---|---|---|
| clean HEAD (1,070,704 B) | none | `baseline` N=20 | **16/20** (CR2=0x8 dominant, 0x10000000 rare) |
| top-down only (1,070,480 B) | `pmm.cyr` only; `proc.cyr` at HEAD | `topdown` N=20 | **0/20** |
| top-down only | same | `topdown2` N=20 | **0/20** |

**Net with the isolated fix: 0 ring-3 #PF across 40 fresh-KASLR boots; baseline 16/20.**
The top-down `pmm_alloc` change ALONE is sufficient — the Lane-C `proc.cyr` CR3-walk
experiment is NOT part of the fix and was discarded (it never passed the bar). Final tree:
`kernel/core/pmm.cyr` is the only modified file vs HEAD; `proc.cyr` restored to HEAD;
nothing under `cyrius/` touched. Build/agnos at 1,070,480 B reflects the fix.

Residual bug #2 (SYSCALL-path RBP smash, ~1/52) did not appear in these 40 runs but is
unaddressed and remains a separate follow-up bite.
