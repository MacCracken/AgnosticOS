# Anonymous `mmap` — Design + Prior-Art Note

> **Status**: `mmap` SHIPPED at agnos **1.35.3**; `munmap` SHIPPED at **1.35.4** (§ 7). Unlike the protocol bites (DNS/NTP), `mmap`/`munmap` are internal VMM facilities, not wire-format ports — so this is a focused design note (the POSIX/Linux contract is the reference) rather than a multi-OS comparison.
>
> **Scope**: **anonymous** `mmap`/`munmap` only — hand a process a fresh, zero-filled region of its own address space and release it again. No file-backing, no `MAP_FIXED` placement games, no `mremap`. Per the roadmap "mmap (anonymous-only) — adds VMM surface, no filesystem work."
>
> **Created**: 2026-05-27. **Updated**: 2026-05-27 (munmap, § 7).

---

## 1. The contract (POSIX / Linux reference)

`mmap(addr, length, prot, flags, fd, offset)` → a virtual address. For the anonymous case (`MAP_ANONYMOUS`, `fd` ignored): allocate `length` (page-rounded) bytes of zero-filled memory, map it into the caller's address space, return its base. v1 honors `length`; `addr`/`prot`/`flags`/`fd`/`offset` are accepted-and-ignored (always anonymous, R/W/U). Linux/FreeBSD agree on this core; the differences (placement hints, huge-page flags, NUMA) are all deferred.

---

## 2. The AGNOS constraint that shapes everything: 2 MB huge pages

AGNOS user memory is **2 MB huge pages only** — there is no 4 KB PT level for user mappings (`vmm.cyr`: "2 MB huge pages only (PD entries)"; `proc_map_page` writes a PD entry `phys | 0x87` = present/RW/user/PS). The PMM is a 4 KB-page bitmap, and the **existing** ELF-loader / stack idiom is: `pmm_alloc()` one 4 KB page, then `proc_map_page(cr3, vaddr, phys)` maps the **enclosing 2 MB region** as one huge page.

Two consequences this forces on `mmap`:

1. **Granularity is 2 MB.** The smallest mapping is one 2 MB huge page — `mmap(4096)` returns a 2 MB region. This is inherent to the VMM, not a v1 shortcut; fine-grained 4 KB `mmap` requires a 4 KB user-paging level (a separate, large VMM arc — deferred).
2. **The ELF/stack idiom has a latent aliasing hazard** the `mmap` bite must *not* inherit: it maps a full 2 MB huge page but `pmm_alloc` only reserved the single 4 KB page inside it — the other 511 pages stay "free" in the PMM and could be handed out again, aliasing the same physical 2 MB. ELF/stack get away with it (sequential boot-time allocation); a dynamic, repeatedly-called `mmap` would not. So `mmap` needs a **real 2 MB-contiguous allocator**.

---

## 3. Design

- **`pmm_alloc_2mb()` / `pmm_free_2mb(addr)`** (new, `pmm.cyr`): scan the page bitmap for **512 contiguous free 4 KB pages** aligned to a 2 MB boundary, mark them all used, return the 2 MB-aligned base (0 on failure). `pmm_free_2mb` clears all 512. This is the correctness fix — the whole 2 MB the huge page exposes is now genuinely reserved, no aliasing.
- **`sys_mmap(length)`** (new): round `length` up to a 2 MB multiple; for each 2 MB chunk — `pmm_alloc_2mb()`, identity-map it for kernel access (`vmm_map(phys, phys, 0x83)` if not already, mirroring the ELF loader), `memset` it to zero, `proc_map_page(proc_get_cr3(proc_current), vaddr, phys)` into the caller's address space (US=1). Return the first `vaddr` (or 0 on failure). Multi-chunk mappings are vaddr-contiguous; their physical 2 MB regions need not be.
- **mmap vaddr arena** — a global cursor (`mmap_next_vaddr`) starting at **0x10000000 (256 MB)**, growing +2 MB per huge page, ceiling **0x40000000 (1 GB)** (the per-process PD covers 0–1 GB; code sits at ~2–34 MB, per-pid stacks at `0x800000 + pid*0x400000`, so 256 MB–1 GB is clear). Each address space is independent (its own CR3), so a global monotonic cursor never collides across processes; it doesn't reclaim on the v1 (no-`munmap`) path — acceptable for a low-process-count kernel (512 huge pages of arena).
- **Syscall number**: `mmap` = **27** (the first new *functional* syscall since v1.21.0; surface goes 27 → 28). 26 was already taken — `write_boot_checkpoint(byte)`, a diagnostic added during iron-boot bring-up — so mmap takes the next free slot. The CVE-2026-31431 structural-immunity argument is **unaffected** — it is anchored on the *absence of the AF_ALG / socket / `splice` syscalls*, which `mmap` (a pure memory syscall) does not add; the count reference is reframed to "absence of the vulnerable socket/crypto surface," which is the actual load-bearing property — not a raw table-size invariant.

---

## 4. Diff against AGNOS

| Need | Today | Gap |
|---|---|---|
| Map a 2 MB user page into a process | `proc_map_page(cr3, vaddr, phys)` ✓ | reuse |
| Caller's address space in a syscall | `proc_get_cr3(proc_current)` ✓ | reuse |
| Identity-map + zero a phys 2 MB region | `vmm_map(phys,phys,0x83)` + `memset` ✓ (ELF idiom) | reuse |
| **2 MB-contiguous physical allocation** | **none** — `pmm_alloc` is single-4 KB; ELF/stack alias | **`pmm_alloc_2mb` / `pmm_free_2mb`** |
| mmap arena + cursor | none | a global monotonic vaddr cursor |
| the `mmap` syscall | none | `sys_mmap` + dispatch entry 27 |

---

## 5. Bite plan

- **Bite 1 — `pmm_alloc_2mb` / `pmm_free_2mb`** (`pmm.cyr`): the 512-contiguous-page allocator. The riskiest new code; gets the hermetic test.
- **Bite 2 — `sys_mmap` + arena + syscall 27** (`proc.cyr` + `syscall.cyr`): anonymous map into `proc_current`'s CR3. Update the syscall-count doc refs (26→27) + reframe the immunity anchor line.
- **Validation** — `MMAP_SELFTEST` (hermetic): `pmm_alloc_2mb` returns a 2 MB-aligned base with all 512 pages marked used; a second call yields a distinct, non-overlapping region; `pmm_free_2mb` releases them (bitmap shows free); the length-rounding is exact (4 KB→2 MB, 2 MB+1→4 MB). The full map-into-process path reuses the iron-proven `proc_map_page` idiom (so it rides existing proof rather than needing a live user-proc test at boot). `mmap-smoke.sh` gates `mmap: pmm2mb PASS`.

---

## 6. Out of scope (deferred)

- **4 KB-granular `mmap`** — requires a 4 KB user-paging level (a PT layer under the PDs); a large VMM arc that also unblocks finer KPTI. Until then `mmap` is 2 MB-granular.
- **File-backed `mmap`** (`MAP_SHARED`/`MAP_PRIVATE` over an fd) — needs the VFS page-cache; far future.
- **`MAP_FIXED` / placement hints / `mremap`** — anonymous-bump-allocator only for v1.
- **Retrofitting ELF/stack onto `pmm_alloc_2mb`** — would fix the pre-existing aliasing hazard project-wide; noted as a separate cleanup, not bundled here.

---

## 7. `munmap` (1.35.4)

`mmap`'s natural pair: release a region a process got from `mmap` and return its physical 2 MB pages to the PMM. Without it, the global bump arena (256 MB→1 GB = 384 huge pages) and the 16 MB physical pool only recover at process teardown — fine for a one-shot allocation, a leak for any consumer that churns mappings (arena allocators, a heap that grows *and shrinks*). Syscall **28**.

### The Linux model we deliberately do NOT copy

Linux `do_munmap` is heavyweight because it carries **VMA metadata**: a red-black tree of `vm_area_struct`s per address space. `munmap(addr, len)` can split a VMA (unmap the middle of a mapping), merge neighbours, and unmap across several VMAs in one call — all bookkeeping over that tree. AGNOS has **no VMA layer**: a mapping's only record is the PD entry itself. So our `munmap` is correspondingly simpler *and* more restrictive — it is the literal inverse of our bump `mmap`, not a general range operation.

### Design

`sys_munmap(addr, length)`:

1. **Validate** — `addr` must be 2 MB-aligned and within the arena `[0x10000000, 0x40000000)`; `length` rounds up to 2 MB exactly as `mmap` does. Anything else → `-1` (never touch non-arena memory — code, stacks, the kernel).
2. **Walk to the PD once** (`PML4→PDPT→PD`; the whole arena lives under one PD since the per-process PD covers 0–1 GB).
3. **Per 2 MB region** — read the PD entry; if **present**, recover `phys = entry & ~0x1FFFFF`, call `proc_unmap_page` (clears the entry in **both** the kernel and the KPTI user PD), `invlpg` the vaddr (the `vmm.cyr` idiom — the live process could otherwise keep a stale TLB entry into now-freed physical, a use-after-free), then `pmm_free_2mb(phys)`. If **not present**, skip it (idempotent — no double-free).
4. **LIFO vaddr reclaim** — if the freed range sits exactly at the top of the bump arena (`addr + len == mmap_next_vaddr`), rewind the cursor so alloc-then-free round-trips don't bleed vaddr space. Non-top frees release physical but leave a vaddr hole (the bump allocator doesn't track holes — acceptable for a low-process-count kernel; a free-list is a later refinement if churn demands it).

`pmm_free_2mb` already validates alignment + range and refuses the kernel region, so a malformed `phys` is a safe no-op. The TLB story: `invlpg` flushes the kernel-CR3 entry; the KPTI CR3 switch on syscall-return flushes the user side (same path that makes a fresh `mmap` mapping visible).

### Diff against AGNOS

| Need | Today | Gap |
|---|---|---|
| Clear a 2 MB user PD entry (kernel + KPTI user) | `proc_unmap_page(cr3, vaddr)` ✓ (guard-page use) | reuse |
| Invalidate a stale huge-page TLB entry | `var f = v; asm { invlpg [rax]; }` ✓ (`vmm.cyr`) | reuse |
| Free a contiguous 2 MB physical region | `pmm_free_2mb(phys)` ✓ (shipped with mmap) | reuse |
| Read the phys backing a vaddr | PD-entry read (`load64(pd + idx*8) & ~0x1FFFFF`) | trivial new |
| the `munmap` syscall | none | `sys_munmap` + dispatch entry 28 |

### Validation

The hermetic gate folds into `MMAP_SELFTEST` / `mmap-smoke.sh` (the pair shares one test surface): `pmm_free_2mb` **rejects** misaligned / kernel-region / out-of-range addresses (the guards `munmap` leans on), and an **alloc → free → alloc** round-trip proves freed physical is genuinely reusable — the core `munmap` value — with the free-count restored each cycle (`munmap: pmm-reuse PASS`). The full `sys_munmap` PD-walk + `proc_unmap_page` + `invlpg` path rides those iron-proven primitives (no live user-proc at boot to drive a real unmap), exactly as `sys_mmap` rides `proc_map_page`.

### Still deferred after munmap

- **4 KB-granular unmap / partial-region munmap** — needs the 4 KB paging level (and then VMA-ish tracking to split). Out with 4 KB `mmap`.
- **vaddr free-list** — reclaim non-top holes in the bump arena. Only worth it if a consumer shows real fragmentation.
