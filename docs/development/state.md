---
name: AGNOS Ecosystem State
description: Live cross-repo state — Cyrius cycle, pin-lag spectrum, active sweeps, carry-forward debt
type: state
---

# AGNOS Ecosystem — Current State

> **⚠ NOT A LOG.** This file is **live state with pointers** — current truth only, plus links to where the history lives. Iron attempt history → [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md). Per-repo release history → each repo's `CHANGELOG.md`. Crate versions → the two registry pointers below. If you find yourself writing prose narrative here, it belongs in one of those other files.

> **Cyrius toolchain**: agnos pins **6.0.56** (`cyrius.cyml`); build agnos-target binaries with the **pinned** version, NOT the default `cyrius` wrapper (latest ~6.0.88, warns on drift). agnosticos boot-pipeline (`scripts/cyrius.cyml`) pins **6.0.14**. Cyrius cycle **v6.0.0** open since 2026-05-19 (v5.11.x closed at 5.11.69). Per-repo pins → Pin-lag spectrum below.
>
> **Last refresh**: 2026-06-12. **Current versions: agnos 1.44.23 · agnoshi 1.7.0 · kriya 1.1.2 · owl 1.3.8 · anuenue 1.1.1 · cyrius-doom 0.29.0 · gnoboot 0.5.0.**
>
> **Open cycle — 1.44.x multi-threading / preemptive scheduling.** The deep cooperative→preemptive scheduler transition ([[project_multithreading_future_arc]]). **Preemptive-ring-3 milestone landed (1.44.0–10):** `kthread_create` + a `preempt_count` gate (the "reentrant-or-gated" foundation), reentrant-or-gated syscalls + the FS write-fd-allocator gate, per-process CS/SS, preemptive ring-3 time-slicing (1→2 procs, distinct CR3, while syscalling — the "per-proc-kstack wall" dissolved: syscalls run IF=0), concurrent exec + clean `exit`, real ELF spawn, non-blocking `waitpid` (1.44.9), and **— 1.44.10 — a ring-3 PARENT `spawn`(#3)s a child ELF + poll-`waitpid`(#4)s it to exit ENTIRELY FROM RING 3.** The 1.44.9 blocker is cleared: `spawn`#3 now copies the user ELF to a kernel staging buffer + runs `elf_load` under the **kernel CR3** `0x1000` (the parent CR3's 256 MB–1 GB mirror gap left the child's page-table pages unreachable → #UD-at-child; the boot CR3 maps all phys, the proven 1.44.8 condition). `ring3-smoke` **4/4** (new `ring3: parent spawn+wait OK`), `thread-smoke` 2/2, `agnsh-smoke`/`doom-smoke` PASS, `sweep` 7/7, `check.sh` 11/11, production byte-stable. Absorbs the 1.43.x carry-forward (per-process env · FB scaling · zero-copy FB-mmap; first-`mmap` RIP=0 already repaired at 1.43.8). **1.44.11 (cut 2026-06-10):** the **page-table VA-collision fix** — the foundational unlock for *many concurrent ring-3 procs*. The in-memory loaders' per-pid user VAs (`spawn_user_proc`/`elf_load`) put 2 MB USER pages at ≥16 MB (PD[8..63]), overwriting the identity-supervisor map of the pmm pool → kernel `load64(PML4)` SMAP-faulted on context switch once ≥~6 ring-3 procs coexisted. De-striped to fixed VAs (code `0x400000`/stack `0x3FC00000`, mirroring `elf_load_from_file`) + the coupled `pmm_alloc`→`pmm_alloc_2mb`; **`ring3-smoke` now 5/5** with a `≥8`-proc `stress OK` assert (before/after: striped triple-faults at scheduler activation). Unblocks **`spawn_path`#43** (non-blocking from-disk spawn, staged dead-code). **1.44.12 (cut 2026-06-10):** the **non-LIFO proc-table-slot reclaim** — an out-of-order background-job exit reaped a NON-TOP slot but append-only allocation never reused it (the 16-slot table leaked even though memory was freed). New `proc_alloc_slot()` reuses dead `state==0` slots + clears the recycled slot's `proc_signals`/`proc_sigmask` (a regression reuse exposed); the LIFO collapse stays as an optimization so the foreground iron path is byte-identical (`reap: slot reclaim OK` green). `ring3-smoke` **7/7** (new `nonlifo reuse OK`/`signal clear OK`, before/after proven). **1.44.13 (cut 2026-06-10): BOTH KERNEL halves of schedulable agnsh** — (1) **`spawn_path`#43 validated end-to-end** (a `RING3_SELFTEST` ring-3 parent #43s `/bin/prog2` from disk, poll-`waitpid`#4s it, exits 42 — `ring3: spawnpath OK`; fixed prog2 to be scheduled-safe with a post-exit `jmp $`); (2) the **non-blocking cooked-line read** (`read(0)` with `a4=r10≠0` drains `kb_buf` into a kernel partial-line accumulator + returns -2/WOULD_BLOCK until Enter; `nbread-smoke` 4/4; `a4==0` keeps the blocking default). exec-smoke **16/16** · ring3-smoke **7/7** · nbread-smoke **4/4** · agnsh-smoke PASS · check 11/11, production 1,147,200 B. **Prompt-preempt decided: Option B** — agnsh polls the non-blocking read + `waitpid`#4, yielding **in ring 3** so bg jobs time-slice; Option A (a blocking read that yields mid-wait) is rejected — it needs **per-process kernel stacks** (a bg proc's syscall resets `rsp` to the shared `syscall_kstack_top` and clobbers agnsh's suspended read frame; same deferred arc as the *blocking* `waitpid`). **1.44.14 (cut 2026-06-10) — schedulable agnsh WORKS** (the user-visible "shell stays live while a bg job runs"): `agnsh-bg-test.py` **PASS** — `sleeper &` launches non-blocking via #43, the prompt returns + stays live (`version` responds mid-run), the job runs to completion (`SLEEPER-DONE`), agnsh reaps it (`[1] Done`). Three kernel fixes (the scoping workflow's in-handler-yield recommendation was REJECTED as kstack-unsafe; the kstack-SAFE design preempts agnsh in ring 3, never mid-handler): (1) **agnsh runs preemptively** — kybernet sets a consumed `exec_preempt` gate so `enter_ring3` starts agnsh IF=1 (timer preempts it between prompt polls → the bg proc gets a slice); foreground `execwait`#37 stays IF=0 byte-for-byte. (2) **`exec_resume_pid` gate** — exit#0 only `kernel_resume`s the foreground proc, so a bg proc's `exit` no longer hijacks agnsh's resume (it goes state 0 for `waitpid`#4). (3) **-3 partial-line signal** — a mid-line job-drain no longer orphans the half-typed command. exec-smoke 16/16 · ring3-smoke 7/7 · nbread 4/4 · agnsh-smoke PASS · sweep 7/7 · check 11/11, production 1,147,584 B. **agnoshi 1.6.0** = the `&` userland (job table + parse + poll loop + -3). **1.44.15 (cut 2026-06-10): multiple concurrent `&` jobs validated** — `agnsh-multijob-test` PASS (2 jobs, the short one reaps OUT OF ORDER while the long one runs, prompt stays live). Works as-is; kernel **byte-identical to 1.44.14** (the 1.44.12 non-LIFO alloc + 1.44.14 `exec_resume_pid` gate + agnsh's 8-slot job-table compaction handle it). A "collapse all trailing dead slots" reap opt was tried + reverted as UNSAFE (would reclaim an exited-but-unreaped proc's slot, breaking the parent's pending waitpid + leaking its AS). The `>1`-job caution is cleared. **1.44.16 (cut 2026-06-10) — `sched_yield`#44**: abandon-frame voluntary end-of-slice from ring 3 (stub-time capture of rcx/r11/callee-saved → slot write AS-IF-SYSRET'd → synthesized-frame iretq switch; the serial-kstack invariant holds because the frame is ABANDONED, never suspended). agnsh's poll loop yields after unproductive polls (**agnoshi 1.6.1**, also fixing the 1.6.0 SYS_SPAWN_PATH-in-gitignored-lib durability bug). **Benchmark: bg sleeper 22.8s → 12.8s (×1.78, N=2e9 TCG)**. ring3-smoke **8/8** (new `yield OK`) · exec 16/16 · bg/multijob tests PASS. **1.44.17 (cut 2026-06-10) — idle-deprioritization landed**: `sched_next` two-pass (a registered `sched_idle_pid` skipped while any other proc is ready; pass 2 = the original scan + proc-0 fallback — boot-era/single-worker rotations byte-identical). **Benchmark: bg sleeper 12.3s → 9.8s (×1.26, stable ×2); cumulative vs busy-poll baseline 22.8s → 9.8s = ×2.3** (bg share ~75%). ring3-smoke 8/8 · thread 2/2 · exec 16/16 · bg/multijob PASS · sweep 7/7 · check 11/11. **1.44.18 (cut 2026-06-11) — SMP-AP wake + park landed** (the arc's last parked item): BSP wakes APs 1-3 (SDM INIT-SIPI-SIPI, real tick-timed delays); APs come up the 16→32→64 trampoline, count in via spinlock, and **PARK (IF=0 hlt — no AP ever runs the scheduler; single-core invariant untouched)**. Fixed two latent never-executed trampoline bugs (32-bit stage borrowed the kernel GDT whose CS 0x08 is L=1/D=0 → decoded 16-bit, AP crashed; stale GDT limit 55 would #GP ltr) + invariant-safe `ap_entry` (was arming the AP timer + sti) + call-site move post-pt_init/post-sti. **smp-smoke 3/3** (`-smp 4` → `smp: cpus online: 4` + full boot); whole battery green at `-smp 1`; bg-test unchanged ~9.8s. Iron: the wake is the riskiest item on the next burn (real-Zen INIT-SIPI timing). **Arc tail: EMPTY**. **1.44.19 (cut 2026-06-11) — per-process env landed** (carry-forward 1 of 3): caller envp through #37/#43 (a3=blob, a4=len; fallback-only — legacy callers' garbage a3/a4 degrade to the default, never -1; fault-proof page-walking copy); kybernet seeds agnsh's env; `/bin/envprop` proves propagation (exit 81 vs the 72 fallback gate; exec-smoke 17/17 ×3). EN ROUTE: an intermediate 6-arg loader call shape showed layout-sensitive instability under the pinned toolchain — finalized on the consume-at-entry-globals shape (NOT attributed upstream: never reproduced on current cyrius, no issue filed). **agnoshi 1.7.0 consumer DONE** (env inheritance). **1.44.20 (cut 2026-06-11) — kernel-scaled blit** (carry-forward 2 of 3): #39 a4[39:32] integer scale; cyrius-doom 0.29.0 (cut 2026-06-11) drops its userland scaler (cap 3 → panel-natural 7 @ 1440p; 64K vs scale²·64K ring-3 px/frame). The adversarial review caught a ring-3-reachable BSS smash in the draft design (the w*scale rowbuf gate). fbscale + doom smokes PASS, all green. **Carry-forward 3 (zero-copy FB-mmap) CLOSED — superseded** (motivation gone post-scaling; hardened-kernel posture held: blit#39 stays THE ring-3 FB path). **1.43.x carry-forward ledger EMPTY.** **1.44.21-22 (cut 2026-06-11) — arc-closing security/hardening + clarity sweep** (multi-dimension audit of `1.43.8..HEAD`; arc found solid). **1.44.21:** fixed a ring-3-reachable OOB write in `kbd_read_nonblock` (the line-flush copied the persistent `nbline_pos`-byte accumulator into the current call's user buffer bounded only by a PRIOR call's `count`; both flush paths now clamp to the current validated `count`, byte-identical for agnsh's fixed prompt count) + bounded the now-live APIC INIT/SIPI delivery-status polls (the 1.44.18 wake un-gated them; a stuck IPI would hang boot on real Zen — the burn's riskiest item). nbread 4/4 · ring3 8/8 · agnsh-bg · smp 3/3 · sweep 7/7 · check 11/11. **1.44.22:** comment-only (binary byte-identical to .21 modulo banner — `cmp`-verified) — corrected the `main.cyr` `var X[N]` sizing footgun, the stale `#43 spawn_path` "dead code" note, and the `sysinfo` cpu_count enumerated-vs-schedulable note. Deferred (documented): waitpid#4 ownership gate (proc_get_ppid stub → would break agnsh `&` reaping), MADT AP-enum, loader DRY, sched_next single-pass. **One iron-burn covers both cuts → [`#tracker-144x-cycle`](iron-nuc-zen-log.md#tracker-144x-cycle).** Next: the cyrius-audit crossover at 1.45.x. **attn11 TRAINS ON AGNOS (2026-06-11, parallel attn11 session):** the GPT-style transformer trained 50 steps in ring 3 on agnos 1.44.15 + agnsh 1.6.x — argv through execwait, checkpoint saved via the full ext2 bridged path (open/write/global-sync/rename, crash-atomic), post-boot `e2fsck` clean even after a hard quit, loss/lr/grad-norm matching native Linux to every displayed digit and the checkpoint **bit-for-bit identical** (948,008 B) under the qemu-x86_64 reference. Both real failures were toolchain-side (the cycc argv-capture emission order — the known bare-call class) or harness-side (KVM boot-timing: kybernet launched while selftest procs were alive — agnos smokes are TCG-only by design); **zero kernel faults in 7 boots**. ~1.15 s/step TCG vs 58 ms native (~20×). The strongest whole-stack validation to date — a real ML workload beyond DOOM. **Userland testing surface (done):** the **kriya/owl coreutils delegation** — agnoshi **1.5.0** dropped its in-process verbs → kriya `/bin` dispatcher (11 `/bin/<verb>` symlinks) + owl `cat`; END-TO-END QEMU-green (`agnos/scripts/agnsh-delegation-test.py`), with two consumer fixes **kriya 1.1.2** + **owl 1.3.8** (the stale-`fnptr.cyr` allocator gap from a pre-6.1.14 cyrius pin; owl also `var r = main()` → bare-call). **1.44.19 → 1.44.20 cut** (user-approved 2026-06-11): banner `v1.44.20`, production **1,193,072 B**, `check.sh` 11/11; cyrius-doom 0.28.4 → **0.29.0** (kernel-scaled blit consumer). **FIRST IRON BURN 2026-06-12 — reached agnsh (so SMP-AP wake, the flagged riskiest item, PASSED on real Zen) but LOCKED UP at the `agnoshi 1.7.0` banner (freeze, no header/prompt).** Root-caused (6-reader + adversarial-3-lens workflow, independently ELF-verified): the BSP `TSS.RSP0=0x200000` sits in live kernel `.bss` (image+BSS = `[0x100000..0x2334E8)`), so the first ring-3 IF=1 timer tick (agnsh, the first preemptible ring-3 proc, 1.44.14) grows the cross-privilege ISR + `do_context_switch` call tree DOWN into live kernel globals → triple-fault. **FIXED at 1.44.23 (cut 2026-06-12) in `agnos/gdt.cyr`: BSP RSP0 `0x200000`→`0x3C0000`** (above the image, below the syscall kstacks, in PD[1]/region-1 — finishing the relocation the boot stack + syscall kstack already did). QEMU no-regression gate green (`ring3` 8/8 · `smp` 3/3 · `agnsh-smoke` · `check` 11/11 · `sweep` 7/7); production `build/agnos` 1,193,424 B; **iron re-burn pending** → [`#tracker-144x-cycle`](iron-nuc-zen-log.md#tracker-144x-cycle).
>
> **Closed arcs (history → each repo's CHANGELOG + iron-log, NOT here):** 1.31.x storage (iron) · 1.32.x networking (iron) · 1.33.x ext2/4 write (iron) · 1.34.x FAT/exFAT write · 1.35.x comms · 1.36.x refactor (byte-identical) · 1.37.x ext4 extent-alloc (iron) · 1.38.x jbd2 (iron) · 1.39.x VFS write-lift · 1.40.x exec-from-disk (iron) · 1.41.x shell→agnoshi (iron) · 1.42.x perf + hardening + sysinfo(#34/#35)/klug(#36) · 1.43.x graphics/DOOM (iron — burn `1439` plays DOOM in-game on real Zen). MVP gate (boot-to-shell on iron) green since 1.30.9.
>
> **Iron-log roads** (split by maturity era; active keeps the bare name): **base** (active — [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md)) → **server** (self-hosting / public-beta gate) → **platforms** (1.5x+ hardware). Chain: [`-mvp`](iron-nuc-zen-log-mvp.md) → [`-mvp2`](iron-nuc-zen-log-mvp2.md) → active.
>
> **Crate registries**: [`planning/shared-crates.md`](planning/shared-crates.md) (full, incl. pre-1.0); [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ subset).

**Out of cycle scope (parked):**
- AMD Zen scanout residue (Quiet Boot legibility) — separate cycle per [`project_amd_zen_scanout_residue`](../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_amd_zen_scanout_residue.md); HUBP `clear_tiling` port or shadow-buffer eval.
- Kernel-side FB **double-buffer** (tear-free flips inside blit#39) — backlogged 2026-06-11 when zero-copy FB-mmap was closed as superseded. Trigger: observed tearing on iron, or future shell-launched games beyond cyrius-doom needing it. Always kernel-mediated (`fb_phys` stays unexposed — the hardened posture is the decision).
- SMP-AP wakeup — QEMU-landed at 1.44.18 (wake + park); IRON validation rides the next archaemenid burn (real-Zen INIT-SIPI timing is the burn's riskiest item).
- i225-V NIC driver — queued for Intel iron post-migration (the r8169 RTL8125 path is DONE + iron-verified, 1.32.x; i225-V is a separate hardware line, not an AMD blocker).

This doc holds **volatile state** — what's currently true across the AGNOS dev surface. CLAUDE.md is preferences/process/procedures; this is the live picture. Per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md): rewrite in place when state changes; don't preserve historical snapshots — git history is authoritative.

**Drift caveat**: always verify against actual `VERSION` + `cyrius.cyml` files before acting on any single item in this doc.

---

## Cyrius cycle — v6.0.0 (open 2026-05-19)

**v6.x = "what the language GAINS."** v5.x was "what the language IS"; the v5.x→v6.x boundary marks the pivot from stabilization to expansion (RISC-V rv64, PIE, closures, Class-B FFI, bare-metal — slip path: v5.8.x → v5.10.x → v5.11.x → **v6.x**, per the boundary memory). First slot cut today, 2026-05-19.

### v6.0.0 cycle-open — two-binary rename ceremony

- `cyrc` → **`cybs`** (Cyrius Bootstrap) — the seed/bootstrap compiler in the chain
- `cc5`  → **`cycc`** (Cyrius Computer Compiler) — the self-hosted production compiler

Bootstrap chain is now `seed (asm) → cybs → cycc`. The "Version lives in `VERSION` + `--version`, never in binary names" Key Principle stays — but the names are *forever*. No `cycc6` at v7.0.0, no `cybs7` at v8.0.0; the cc3 → cc5 (v5.0.0) → cycc (v6.0.0) and cyrc → cybs (v6.0.0) sequence was the LAST name-change penalty paid.

**Rename surface**: ~2,100 occurrences across ~157 files. Categorized sed preserved historical anchor text (v5.x CHANGELOG entries, completed-phases.md, archives, audit date-stamps, vidya retros — those names were what the binaries were called at the time). Current-state code + canonical-current docs renamed. File renames via `git mv` (`bootstrap/cyrc.cyr` → `bootstrap/cybs.cyr`, `build/cc5*` → `build/cycc*`, scripts renamed in parallel).

**Back-compat (v6.0.x window)**: `scripts/install.sh` ships symlinks `cc5 → cycc`, `cyrc → cybs`, `cc5_aarch64 → cycc_aarch64`, `cc5_win → cycc_win` in `~/.cyrius/versions/<v>/bin/`. `cbt/core.cyr` compiler-lookup tries new name first then falls back to old. Both drop at **v6.1.0**.

**Mechanical gates at v6.0.0 cut**: cycc self-host byte-identical at **874,240 B** (+8 B vs cc5 at v5.11.69's 874,232 B, from the longer "cycc" binary-name strings). `check.sh` **76/76**. `cyrius test` **152/152**. 3-step bootstrap (old cc5 v5.11.69 → cycc_a → cycc_b byte-identical). Cross-arch: cycc_aarch64 564,456 B, cycc_win 686,632 B.

### v6.0.x carry-forward (from v5.x closeout)

Five accompanying-refactor items pulled forward — surface on next cyrius-side touch. Detail in `cyrius/docs/development/roadmap.md`. Beyond this: RISC-V rv64 backend, PIE, closures, Class-B FFI, bare-metal Cyrius — all v6.x slots, no firm sequencing yet.

### v5.11.x retrospective (closed 2026-05-19 at 5.11.69)

**70 patches across 11 days** (2026-05-09 → 2026-05-19) — the longest minor in Cyrius history. Three same-day bursts of 24/18/17 on 2026-05-11/12/13 carried the bulk; the .56–.69 tail spread across one patch/day cadence with the heavy engineering at .68 (heap-map reorg) and closeout housekeeping at .69.

- **Stdlib annotation arc** — 1,010 unannotated public fns annotated across the 7-phase breakout (foundational / I/O / strings / collections / big consumers / closeout / compiler internals); Phase 1 landed at v5.11.1, all phases closed in the .1–.55 burst.
- **Consumer-issue closeout** — kavach P1 sandbox wrappers (v5.11.0), daimon/bote P2 wave, low-priority cleanups.
- **ELF section-header fix arc** (.29/.30/.31) — GRUB `grub_elf32_get_shnum` rejection traced to `e_shoff=0` from x86 kernel / aarch64 kernel / cyrld emitters; mirrored 5-section table across all three.
- **gvar-init-order zero-reads fix** (v5.11.64) — module-top `var X = INT_LITERAL` read as 0 before init block ran (kmode==1 init-order: top-level asm → PARSE_PROG → EMIT_GVAR_INITS, with kernel's main body in PARSE_PROG never returning). Root cause of the 10-letter Phase-3 cmd-path silent-absorb arc on iron (FF→QQ+QQ2, falsified across Attempts 57-63 chasing what looked like silicon). Fixed via Option 1 — image-static init for literal-RHS gvars at file scope, every backend covered. Issue: [`2026-05-18-gvar-init-order-zero-reads.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-18-gvar-init-order-zero-reads.md).
- **Path A→Path C transition** (.43–.55) — diagnostic + sovereign UEFI-application emit support for the gnoboot lane after GRUB MB2-EFI W^X blocker (per `project_grub_mb2_efi_wx_blocker` memory).
- **Heap-map full reorganization** (v5.11.68) — the true v5.x closeout engineering work; ~9.06 MB reclaimed, 84 → 99 regions, brk-final 0x4E8C000 → 0x4D9D000. v5.11.69 was doc/scripts/vidya closeout sweep (the originally-conditional fold-applied slot — mabda 3.0 fold was dropped per user direction post-.67, so .69 absorbed pre-6.0 cleanup instead).

**v6.0.0 enabling consumers** (cut during v5.11.x):
- **argonaut 1.7.0 + kybernet 1.2.1** (2026-05-11 eve) — BOOT_MINIMAL agnoshi-as-console; unblocked the closed-beta MVP path without aethersafha.
- **kriya 1.0.0** (2026-05-18) — coreutils-equivalent dispatcher graduated to v1.0+.
- **commandress 1.0.0** (2026-05-18) — segment renderer + config layer stabilized; adapter-based for agnoshi/bash/zsh prompt-hook.

V1.0+ binaries cohort now **13**: agnos, agnoshi, argonaut, bannermanor, commandress, cyim, cyim-lsp, iam, kriya, kybernet, mihi, nous, owl. (iam + mihi added 2026-05-20 morning as the first v6.0.x graduations; bannermanor 0.5.0 → **1.0.0** later same day with CLI surface + CYML font format + default font set frozen as the v1.0 contract.)

### v5.10.x retrospective (closed 2026-05-11 at 5.10.50)

**50 patches in 5 days** (2026-05-06 → 2026-05-11). THREE completed arcs plus a compile-perf miniarc:

- **Typed-simd ABI arc — 11 phases** (closeout v5.10.39). `lib/simd.cyr` rewrite: every math op exists in value-form + pointer-form siblings with parser-side `&IDENT → _ptr` overload routing; f64v2 args in XMM0/XMM1 (SysV) / V0/V1 (aarch64), f64v4 in register pairs; PE-gated via `CYRIUS_HAS_VAL_SIMD_PARAMS`. **This is the substrate for Cyrius-native codec work long-term** — typed SIMD primitives + cross-platform ABI-aware register routing is the floor of any handwritten-SIMD codec port (tarang's current dav1d/openh264/libvpx C-FFI layer is the placeholder until that future arc opens).
- **REAL TYPE SYSTEM arc — 5 phases** (Phase 2 v5.10.24, Phase 3 v5.10.25 overload generalize). Per-fn param-type bitmasks, call-site type checking, cstring / Result / Option / Tagged vocabulary on stdlib.
- **Struct-byval ABI arc — 3 phases** (.45 + .46 + .47). Cross-backend struct-byval return surface.
- **Compile-time-perf miniarc** (.40 + .41) — **2.7× total compile speedup**.

Plus one TLS contract pin (.42), one PE premise debunk (.49 — 15-slot phantom pin closed by empirical re-test), 4 open issues closed (str_split, exec_*, parser cosmetics, kernel-reserved-word), and 9+ in-cycle pin re-scopings driven by premise-check discipline.

api-surface 2,769 → 2,876 (+107 public fns). cc5 (x86) 741,048 B → **804,472 B**. check.sh 66 gates stable. cyrius test count 132 → ~146.

### cycc cut state

cycc self-host **874,240 B** at v6.0.0 (was cc5 874,232 B at v5.11.69 close; +8 B for the longer "cycc" binary-name string in `version_str.cyr`). Self-host fixpoint clean. cc5 grew from **804,472 B at v5.11.0** baseline to **874,232 B at v5.11.69** across the 70-patch cycle (+69,760 B over 9 days). check.sh 66 → 76 gates; cyrius test 132 → 152 across the 5.10.x + 5.11.x cycles.

### Genuinely dangling — carry-forward into v6.x triage

| # | Item | Domain | Notes |
|---|------|--------|-------|
| 1 | `cyrlint` multi-line assert | Tooling | Investigated v5.8.41; couldn't reproduce on 4 synthetic tests. Decide: close as moot, or pin a real reproduction case |
| 2 | `ESTORESTACKPARM` stub | Language | Explicitly **held** — needs unhold-or-resolve decision |
| 3 | Optimization arc O3–O6 audit | Compiler | Partial follow-on shipped (O3a IR / O4a–c regalloc / O5 / O6 codebuf) — needs status sweep against v5.6.x deferral list |
| 4 | Consumer rollup — pre-CYML format tail | Ecosystem | `hoosh` and `shravan` only (down from 11 at v5.10) — format migration + pin bump |
| 5 | Consumer rollup — deep-lag tail | Ecosystem | ark (5.1.10), yantra (5.6.17); hisab/agnova/abaco/nous/bazaar/shakti in v5.7.x; libro/majra exited at v5.10.44 |
| 6 | Consumer rollup — v5.7.48 held cluster (3 repos remaining) | Ecosystem | mabda, cyrius-doom, samvada — phylax + agnosys both exited during v5.10.x/v5.11.x |
| 7 | RISC-V rv64 backend | Compiler/backend | Slipped 7+ times; first-class v6.x candidate. Substrate prereqs (typed-simd ABI / REAL TYPE SYSTEM / struct-byval) all landed v5.10.x |
| 8 | Bare-metal Cyrius target | Compiler/runtime | v6.x slot; substrate prereqs landed v5.10.x + v5.11.x stdlib annotation |
| 9 | PIE / closures / Class-B FFI | Language | Three v6.x feature slots per the v5.x→v6.x boundary; no firm sequencing |

---

## Pin-lag spectrum

Each repo's `cyrius = "X.Y.Z"` pin (verified **2026-06-01** from local clones). **The deep-lag tail has nearly fully collapsed onto 6.0.x** — the old v5.7.x cluster (hisab, abaco, nous, bazaar, shakti) and most of the v5.7.48 held-cluster (mabda, cyrius-doom) have all graduated. What remains is a thin set of old-pin holdouts plus a 5.10.x bedrock that graduates on natural-next-touch. Two repos (`hoosh`, `shravan`) are still pre-CYML (`cyrius.toml`).

```
Current pins (local clones, 2026-06-01). Format = cyrius.cyml unless noted; entries show (version / pin).

PRE-CYML (cyrius.toml — migrate to cyrius.cyml + 6.0.x):
  hoosh (2.0.0 / 4.5.0), shravan (2.3.2 / 4.10.3)

CYML — DEEP LAG (re-port to 6.0.x before any re-measurement):
  v5.1.x:   ark (0.8.0 / 5.1.10)        ← extreme; port pre-dates the pin convention
  v5.6.x:   yantra (0.1.0 / 5.6.17)
  v5.7.x:   agnova (0.1.0 / 5.7.12)
  v5.7.48:  samvada (0.2.2 / 5.7.48)    ← last of the old 5.7.48 held-cluster

CYML — 5.10.x BEDROCK (~10 repos; runtime/boot path, graduate on natural-next-touch):
  v5.10.10: owl (1.3.6)
  v5.10.20: cyim-lsp (1.5.0)
  v5.10.34: aegis (1.0.0)
  v5.10.44: kavach (3.2.1), daimon (1.2.3), bote (2.7.2), t-ron (2.1.4),
            nein (1.5.1), phylax (1.1.1), majra (2.4.4)

CYML — 5.11.55 (trailing pair):
  sit (0.8.5), vidya (2.7.1)

CYML — 6.0.x LEADING EDGE (the bulk of the ecosystem, ~32 repos):
  v6.0.0:   ai-hwaccel (2.2.6)
  v6.0.1:   abaco (2.2.4), cyim (1.7.1), sandhi (1.4.0), niyama (1.0.3),
            sankoch (2.3.0), sakshi (2.2.5), yukti (2.2.4), vani (0.9.4),
            cyrius-doom (0.28.2), darshana (0.5.3), chakshu (0.6.1),
            mihi (1.0.0), iam (1.0.0), kii (1.0.0), hapi (1.0.1),
            bannermanor (1.0.1)
  v6.0.3:   nous (1.2.5), bazaar (1.0.2), shakti (0.4.0), patra (1.10.3),
            vyakarana (2.2.2)
  v6.0.14:  hisab (2.6.5)
  v6.0.26:  agnostik (1.3.0)
  v6.0.43:  mabda (3.0.1)
  v6.0.53:  libro (2.7.1)
  v6.0.56:  agnos (1.43.7), agnosys (1.4.0),
            kybernet (1.3.3), argonaut (1.8.2),
            bannermanor (1.1.0), commandress (1.1.0), kriya (1.1.0),
            klug (0.1.0)
  v6.0.61:  sigil (3.7.1)
  v6.0.87:  agnoshi (1.4.8)    ← advanced 6.0.56→6.0.87 (2026-06-08) for the
            agnos getenv()/envp walk; consumer-only feature bump, NOT drift.
            (1.4.8 then STOPPED calling getenv on agnos — see the regression note
            in the header — but kept the pin; getenv is still used host-side.)
            The kernel + the other agnos-target binaries hold 6.0.56.
  v6.1.5:   agora (1.2.0)        ← telnet BBS (door games + Persistent Universe);
            pin lifted 6.0.52→6.1.5 — the ≥6.0.53 sigil/sha256 SIGILL blocker
            cleared on 6.1.x (was the gate on the 1.2.0 crypto path).
  v6.2.2:   attn11 (1.4.3)       ← leading edge — the from-scratch *trained*
            GPT-style transformer (the ecosystem's ML/training reference);
            tracks current cyrius, well ahead of the agnos boot-path band.
            1.x sequence-mixer arc (MoE, gated-linear, selective SSM, hybrid);
            now TRAINS in ring 3 on agnos (checkpoint bit-identical to native).

CYRIUS TOOLCHAIN: 6.0.61. The agnos boot-path core moved into the 6.0.5x band
  during the 1.41.x shell-separation arc (CYRIUS_TARGET_AGNOS landed at
  6.0.55/56); agnos pins 6.0.56 deliberately (held-known-working; do not chase
  the toolchain number). hisab alone still trails at 6.0.14. agnoshi advanced
  to 6.0.87 on 2026-06-08 to consume the agnos getenv()/envp walk (cyrius latest
  released: 6.2.2 — confirmed by attn11's pin) — a targeted consumer feature bump,
  not a cohort move.

ABSENT from this devbox clone (not surveyable here): avatara, hadara, itihas,
  takumi, aethersafha, mela, seema, samay, + the scaffolded cyrius-* game repos.
```

**Bands of attention (2026-06-01):**
- **6.0.x leading edge is the bulk of the ecosystem.** The agnos boot-path core moved forward with the **1.41.x shell-separation arc** — `CYRIUS_TARGET_AGNOS` (the agnos-target stdlib peer that lets `/bin/agnsh` run) landed at cyrius 6.0.55/56, so **agnos/agnoshi/kybernet/argonaut pin 6.0.56**, agnosys/libro at 6.0.52/53, agnostik 6.0.26, mabda 6.0.43, sigil already on 6.0.61; only **hisab** still holds 6.0.14. Toolchain ships **6.0.61** (don't chase it — agnos's 6.0.56 is held-known-working). *(Boot-path-core pins re-surveyed 2026-06-04; the rest of the spectrum is the 2026-06-01 survey.)*
- **5.10.x bedrock** down to ~10 — kavach, daimon, bote, t-ron, nein, phylax, majra (.44) + aegis (.34), cyim-lsp (.20), owl (.10). Graduate on natural-next-touch; none are blockers.
- **5.11.55 pair**: sit, vidya.
- **Deep-lag tail nearly gone** — only ark (5.1.10, extreme), yantra (5.6.17), agnova (5.7.12), samvada (5.7.48) remain on old CYML pins; hoosh (4.5.0) + shravan (4.10.3) are the last pre-CYML holdouts. The old v5.7.x cluster (hisab/abaco/nous/bazaar/shakti) and the v5.7.48 held-cluster (mabda/cyrius-doom) have otherwise fully graduated to 6.0.x — only samvada stayed behind.
- **Port-ledger / Volume 3 relevance**: of the ten Vol 1 ports, **eight are on 6.0.x** — abaco done (in the V3 seed); nous + agnosys have fresh CSVs (write-up only); kybernet, agnostik, ai-hwaccel, kavach need a bench run (± a small pin bump for kavach). **hoosh** (4.5.0, pre-CYML) and **ark** (5.1.10) are the two needing a real re-port before re-measurement; **avatara** is absent from this clone. See the Volume 3 *Receipts Pending — The Wave* list.

### New repos / milestone bumps since last refresh

| Repo | Version | Pin | Notes |
|------|---------|-----|-------|
| **aegis** | **1.0.0** | 5.10.34 | **Hit v1.0** (was 0.8.2 in last refresh). Real system-security daemon now shipping. Skipped 0.9.x — straight implementation closeout to 1.0.0. |
| **agnos** | **1.44.20** | **6.0.56** | Kernel. **1.41.x shell-separation arc IRON-COMPLETE** (burn `14115`, 2026-06-06 — agnsh types/echoes/dispatches on archaemenid). **1.42.x landed on top:** perf (heap-zeroing −50%, 1.42.5; memory-core 1.42.7; fs-read multi-LBA 1.42.8; fb-blit 1.42.9) + 3 carry-forward hardening fixes (page-map 1.42.2 / RBP-smash 1.42.3 / reap 1.42.4) + Track-B userland FS verbs (agnoshi 1.4.2) + **sovereign sysinfo syscalls** (1.42.10 — `uname`#34 / `sysinfo`#35) + **klug kernel-log layer** (1.42.11–12 — ring buffer + `klog`#36) + **klug userland reader banked** (1.42.13 — `klug` 0.1.0, sovereign dmesg) + **hardening/audit/security sweep** (1.42.14 — 6-dim multi-agent audit; CRITICAL ring-3 arbitrary-write via signalfd/timerfd reads FIXED + MEDIUM SMAP-on-exit + LOW SFMASK; HIGH `cyml.cyr` overflow surfaced to cyrius). The agnos-fs `/bin` now carries the first **AGNOS-tic tools** (`bnrmr`/`cmdrs`/`klug`, `stage-tools.sh`). pin moved 6.0.14 → 6.0.56 at 1.41.4 (`CYRIUS_TARGET_AGNOS`). build 1,096,464 B. **1.43.x graphics/userland arc landed on top:** execwait #37 (→ userland `run`), FB-console ANSI/SGR color, `fbinfo`#38/`blit`#39 framebuffer, `uptime_ms`#40/`sleep_ms`#41 ring-3 timing — culminating in **DOOM rendering** (1.43.6 / cyrius-doom 0.28.2 — first real userland app, title screen blits in ring 3; QEMU `doom-smoke.sh` PASS, NOT yet iron-burned). **1.44.x preemptive-scheduling arc landed on top:** `kthread_create` + `preempt_count` gate, per-process CS/SS, preemptive ring-3 time-slicing (1→2 procs, distinct CR3, while syscalling), concurrent exec + clean `exit`, real ELF spawn, non-blocking `waitpid` (1.44.9), and **— 1.44.10 — a ring-3 PARENT `spawn`(#3)s a child ELF + poll-`waitpid`(#4)s it to exit entirely from ring 3** (the spawn#3 kernel-CR3 fix: `elf_load` under boot CR3 `0x1000` since the parent CR3's 256 MB–1 GB mirror gap left the child's tables unreachable → #UD-at-child). `ring3-smoke` **7/7** (incl. 1.44.11 page-table-fix `stress OK` + 1.44.12 `nonlifo reuse OK`/`signal clear OK`) / `thread-smoke` 2/2 / `agnsh`+`doom`-smoke / `sweep` 7/7 / `check.sh` 11/11. **1.44.11** de-striped the in-mem loaders' user VAs (page-table SMAP-fault fix → ≥8 concurrent procs); **1.44.12** added non-LIFO proc-slot reuse (`proc_alloc_slot`); **1.44.13** validated `spawn_path`#43 + the non-blocking cooked-line read (both kernel halves); **1.44.14** schedulable agnsh WORKS — agnsh `&` background jobs get CPU while the prompt stays live (preemptive agnsh + `exec_resume_pid` gate + -3 partial-line signal; agnoshi 1.6.0 userland); **1.44.15** validated MULTIPLE concurrent `&` jobs (out-of-order reap, byte-identical kernel); **1.44.16** `sched_yield`#44 (abandon-frame end-of-slice; agnsh poll loop yields); **1.44.17** idle-deprioritization in sched_next — bg jobs cumulative ×2.3 (22.8s→9.8s; agnoshi 1.6.1); **1.44.18** SMP-AP wake+park — all 4 CPUs online (smp-smoke 3/3), single-core invariant untouched, 2 latent trampoline bugs fixed; **1.44.19** per-process env (#37/#43 a3/a4 blob, fallback-only + fault-proof copy; kybernet seeds; envprop exit-81 proof; agnoshi 1.7.0 inherits); **1.44.20** kernel-scaled blit (#39 a4[39:32]; cyrius-doom 0.29.0 drops its userland scaler — panel-natural scale, 64K vs scale²·64K ring-3 px/frame; CF-3 zero-copy closed superseded). build → 1,193,072 B → [`#tracker-144x-cycle`](iron-nuc-zen-log.md#tracker-144x-cycle). |
| **agnoshi** | **1.4.6** | **6.0.56** | AI shell — the userland interactive shell exec'd from disk in ring 3. **1.4.2: core FS verbs** (`ls`/`cat`/`cp`/`mv`/`rm`/`mkdir`/`rmdir`/`touch`/`echo`/`wc`/`find`/`grep`) as in-process builtins over the existing syscalls; destructive verbs mode-gated (auto/assist execute, human/strict `[y/N]`). Host verbs-smoke 84/0; verb→ext2 roundtrip iron-path-validated. 1.4.1 paired `read_line` with agnos's line-disciplined `read(fd 0)`. `version-bump.sh` now auto-syncs the `VERSION_STR` banner. |
| **chakshu** | **0.6.0** | **6.0.1** | AI-augmented system monitor (`shu` binary). Was 0.3.0 / pin 5.10.20 in last refresh — jumped three patch versions (0.3.0 → 0.6.0) AND graduated pin straight to 6.0.1 (one of the first three v6.0.x graduations). Started consuming mihi for its sys-info probe surface, which let the maturity arc compress. |
| **cyim-lsp** | 1.5.0 | 5.10.20 | LSP server companion to cyim. Pin moved 5.10.10 → 5.10.20. |
| **bannermanor** | **1.0.0** | **6.0.1** | **NEW + graduated to v1.0** (binary `bnrmr`). figlet-equivalent ASCII-art banner generator for login MOTDs / script intros / splash text. English wordplay (commandress/bannermanor naming lane); `bnrmr` vowel-dropped per the `commandress`→`cmdrs` compression pattern. Cut at 0.5.0 straight on v6.0.1 morning; jumped to **1.0.0** later 2026-05-20 — CLI flag surface, CYML font format (schema=1), and default in-tree font set (block / slim / big) all frozen as the v1.0 contract. Drove the darshana 0.3.0 → 0.3.5 color-primitives bump (banner colors). |
| **darshana** | **0.3.5** | **6.0.1** | TTY/raw-mode primitives library (दर्शन — viewing/showing). Extracted from cyim's `src/tty.cyr` once chakshu became a second consumer. Not a TUI framework — just termios + ANSI + cursor positioning. Was 0.3.0 / pin 5.10.20 in last refresh; 0.3.5 added ANSI color escape sequences so bannermanor's banners can render colored, AND graduated the pin straight from 5.10.20 → 6.0.1 in the same touch. |
| **hapi** | **0.5.0** | **6.0.1** | **NEW.** GNU `stow`-equivalent — dotfile / symlink farm manager. Hawaiian हपी (*happy*) + backronym **H**ome **A**sset **P**rovisioning **I**nterface — first Pacific Islands word in the AGNOS naming surface. CYML manifest per package, capability-bounded execution (touches `$HOME` only by default), lightweight audit trail. Cut at 0.5.0 straight on v6.0.1. |
| **kii** | **0.1.0** | **6.0.1** | **NEW 2026-05-22** — `chafa` / `jp2a` / `viu`-equivalent: image → ANSI/ASCII-art converter for terminal display. **Four-layered name** across three language families: (1) Hawaiian *image / picture / likeness* (what it produces); (2) East Asian *ki* (気) / *chi* (氣) — *life-force / vital energy* (kii is the *ki of the terminal*, the animating force that brings the screen to life via images); (3) English-phonetic back-half of **a-scii** (what it emits); (4) functional convergence — produces images via ASCII to animate the terminal, all three language angles describing the same operation. Triple-lane crossover (Polynesian + East Asian + English) is rare in the AGNOS naming surface — typical names sit in one lane. Polynesian Hawaiian micro-cluster with `hapi`, `anuenue`. Cut straight at 0.1.0 on cyrius 6.0.1; reads raster input (PNG, JPEG, GIF, BMP planned), quantizes to terminal-renderable color palette + glyph set, emits ANSI escape sequences sized to terminal cols × rows. |
| **iam** | **1.0.0** | **6.0.1** | **NEW.** fastfetch/neofetch-equivalent system-info display for login MOTD + screenshot flex. Pure inverse of `whoami` — whoami says who the user is, iam says what the system is. Thin presentation layer over the mihi probe library. Cut straight to 1.0.0 on cyrius 6.0.1 — second v6.0.x graduation. Lives in the English-wordplay/trickster naming lane per `feedback_naming_lanes`. |
| **mihi** | **1.0.0** | **6.0.1** | **NEW.** मिही / mihi — system-info probe library (CPU / RAM / GPU / kernel / uptime / distro / hostname). Substrate for iam, chakshu, and any tool that needs "tell me about this box." Maori: the formal self-introduction ceremony — Sanskrit-Hindi/Polynesian semantic naming lane per `feedback_naming_lanes`. First of the three v6.0.x graduations to be cut. |

---

## Active sweeps

### Niyama fold-in (v5.9.0 downstream sweep)

Fresh sibling-fold per niyama ADR 0011. Pattern parallels sandhi-fold (v5.7.0) and vani-fold (v5.8.0).

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (cyim is #1 multi-consumer gate; bare-metal kernel queued #2) | ✅ Done at v5.9.0 |
| 2 | In-tree fixture migration if needed | ✅ N/A — no fixtures touched |
| 3 | cyim → niyama integration verification (regex sweep) | ✅ Done — `cyim/src/main.cyr:51` includes `lib/niyama.cyr` directly |
| 4 | Document the niyama-fold pattern alongside sandhi/vani-fold in `design-patterns.md` | [ ] Pending |
| 5 | Niyama-fold-in article slot | [ ] Subsumed by [*What Justifies a Stdlib Foldin*](../articles/what-justifies-a-stdlib-foldin.md) — per-fold piece optional |

### gnoboot 0.2 merge + version bump (closed 2026-05-15)

Branch `0.2` merged to `main` (`529dfc1`) and tagged `v0.2.0`. Was one commit ahead at `d981fae` ("cleanup of canary and clear framebuffer for initial display"); structurally clean for merge after iron-boot ground truth landed.

| Action | Status |
|---|---|
| CMOS port-I/O blocks stripped (5 inline sites: entry / HandleProtocol / ELF-load / pre-EBS / post-EBS) | ✅ on branch — 0 CMOS refs in 0.2 vs 6 in main |
| UEFI-output collapse (`msg_li_f` … `msg_ebs_f` → shared `msg_fail` + `code_*` table + `efi_fail(st, code)` helper) | ✅ on branch |
| Banner tightened to `gnoboot v<VERSION>: handing off to kernel` (`tests/ovmf_smoke.sh` `EXPECT` synced) | ✅ on branch |
| `efi_clear(st)` called pre-banner so handoff line is the only thing on the framebuffer | ✅ on branch |
| Boot-info struct ABI preserved (magic `0x41474E4F`, RDI handoff, `fb_phys` at +0x48, GOP capture retained) | ✅ verified |
| CHANGELOG `[Unreleased]` section drafted | ✅ on branch |
| Bump `VERSION` 0.1.0 → 0.2.0 | ✅ shipped in 0.2.0 |
| Bump `cyrius.cyml` `version` field 0.1.0 → 0.2.0 | ✅ shipped in 0.2.0 |
| Sync `src/main.cyr` `msg_pre` banner UTF-16LE byte (`0x31` → `0x32`, `v0.1` → `v0.2`) | ✅ shipped in 0.2.0 |
| Sync `tests/ovmf_smoke.sh` default `EXPECT` (`gnoboot v0.1.0` → `gnoboot v0.2.0`, both literal + usage-example) | ✅ shipped in 0.2.0 |
| Rename `[Unreleased]` → `[0.2.0] — 2026-05-15` in `CHANGELOG.md` (Unreleased section preserved as empty placeholder for next cycle) | ✅ shipped in 0.2.0 |
| Rebuild verifies `OK` (`CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI`) | ✅ verified 2026-05-15 |
| Merge `0.2 → main` | ✅ landed (`529dfc1` on main) |
| Tag `v0.2.0` on `main` | ✅ tagged |
| Push branches + tag | ✅ pushed |

Sweep closed 2026-05-15. Per `feedback_bootloader_kernel_ownership` Claude owns gnoboot end-to-end during iron-boot bring-up; merge + tag were user-driven git ops per CLAUDE.md (user handles all git operations).

### Vani audio distlib fold-in (v5.8.0 downstream sweep)

Per [`vani/docs/development/cyrius-stdlib-fold-in.md`](https://github.com/MacCracken/vani/blob/main/docs/development/cyrius-stdlib-fold-in.md). Pattern parallels v5.7.0 sandhi fold.

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (`grep -rn "include.*lib/audio.cyr"` across ecosystem) | ✅ Done at v5.8.0 — zero hits |
| 2 | In-tree fixture migration (3 preprocessor-cap regression tests) | ✅ Done in cyrius repo at v5.8.0 |
| 3 | Document the fold-in pattern alongside sandhi-fold in `design-patterns.md` | ❌ Still pending (now subsumed by fold-in article) |
| 4 | Vani-fold-in article (parallels sandhi-fold article slot) | ❌ Still pending (now subsumed) |

### v5.7.x → v5.8.x → v5.9.x → v5.10.x → v5.11.x debt carry-forward

Status verified 2026-05-11 eve.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | yantra orphan `lib/http_server.cyr` delete | ❌ Pending | File still present at `yantra/lib/http_server.cyr`; cleanup-only, no callers. yantra still at 5.6.17 (deep-lag). |
| 2 | sit orphan `lib/http_server.cyr` delete | ✅ Done | Removed during v5.8.x; sit now at 5.9.37 |
| 3 | vyakarana grammar refresh — index 469 sandhi fns | ❓ Re-verify | vyakarana at 2.2.1 / 5.10.5 — version stable through v5.10–v5.11 burst, content reflection still unverified |
| 4 | vidya per-minor refresh (`language.toml` / `dependencies.toml` / `ecosystem.toml`) | ✅ Likely done | vidya at 2.7.0 / pin 5.9.43 — stable across two minors with active content tree |
| 5 | hoosh / ifran / daimon / mela / ark sandhi-fold audit-confirm | ✅ Confirmed clean | Zero `[deps.sandhi]` and zero include-sandhi refs in any (hoosh still on `cyrius.toml`; daimon now on .cyml 5.10.44; ark on .cyml 5.1.10 deep-lag) |
| 6 | **Boot-to-shell MVP enablement** | ✅ MVP GATE HIT 2026-05-18 (Iron Attempt 68) | argonaut 1.7.0 + kybernet 1.2.1 added agnoshi to BOOT_MINIMAL defaults 2026-05-11 eve. Closed-beta MVP definition (kernel + kybernet + agnoshi typeable on iron archaemenid) clears at agnos 1.30.9, cyrius pin 5.11.64. Active 1.30.x branch is now framebuffer refresh quality (1.30.10). |

### CVE-2026-31431 (Copy Fail) cleanup + audit

Linux kernel LPE in `algif_aead` (AF_ALG in-place AEAD + `splice()` → 4-byte page-cache write → root). Disclosed 2026-04-29; affects mainline kernels from 2017 onward. Roadmap item **S1**.

**AGNOS-native kernel** (`agnos` v1.30.9): structurally immune — verified at `kernel/core/syscall.cyr:32-36`, sovereign syscall table contains no `socket`, no `splice`, no AF_ALG family. Bug class is unreachable. (Kernel has moved 1.26.1 → 1.30.9 since the original CVE audit across multiple bring-up cuts; syscall-surface unchanged. Syscall table verification is anchored on the syscall-table invariant, not the kernel patch level — re-verify only if the syscall surface grows.)

| # | Action | Status |
|---|--------|--------|
| 1 | Host defconfigs — pin `# CONFIG_CRYPTO_USER_API{,_HASH,_SKCIPHER,_AEAD,_RNG} is not set` in `agnosticos/kernel/{6.6-lts,6.x-stable,7.0-devel}/configs/*defconfig` and `kernel/configs/edge-{deeplens,nuc,rpi4,rpi5}.config` | ❌ Pending — re-verified 2026-05-09: zero `CRYPTO_USER_API` refs in any host defconfig |
| 2 | Audit local crypto-adjacent repos for `AF_ALG` / `algif_aead` refs: sigil, agnosys, phylax | ✅ Done 2026-05-03 — zero hits |
| 3 | Audit when next cloned: kybernet, libro, kavach, shakti, aegis, t-ron, argonaut, ark, agnostik, bote, daimon, hoosh | ❓ Deferred — repos not all local |
| 4 | Once defconfigs pinned, document the absence-by-design pattern alongside other AGNOS-vs-Linux structural-immunity examples in `design-patterns.md` | [ ] |

### Pending Cyrius ports

| Repo | Current state | Action |
|------|---------------|--------|
| **bhava** | 2.0.0 Rust (no `cyrius.cyml` on remote) | Port can start — v5.10.x stdlib + math additions are the gating concern |
| **goonj** | 1.4.3 Rust (Cargo.toml present locally) | Acoustics — port pending |
| **naad** | 1.2.5 Rust (Cargo.toml present locally) | Audio synthesis — port pending |
| **aethersafha** | 0.1.0 scaffold | Real implementation (Wayland compositor) |
| **aethersafta** | 0.50.0 (media compositing scene graph) | Distinct from aethersafha — not a Cyrius port target, near-stable lib |

### Per-repo housekeeping (P1/P2)

Carry-forward from v5.6.x → v5.7.x → v5.8.x → v5.9.x → v5.10.x. None blocking; bundle with each repo's next natural patch.

- **`docs/development/state.md` migration** (this pattern). **Done**: cyrius, owl (2026-04-23), agnosticos (this file), sandhi, sit, vidya. **Pending**: every other repo that still carries volatile state in CLAUDE.md (verified 2026-05-06: kybernet, daimon, agnos, abaco, hoosh, kavach, mabda, sigil all missing; presume similar for the unverified tail).
- **`cyrius.toml` → `cyrius.cyml` format migration**: tail collapsed v5.10–v5.11. **Migrated** (local-verified 5.10.44+): agnoshi, bote, t-ron, kavach, itihas (remote), nein. **Remaining** (local-verified pre-CYML / no pin): hoosh, shravan. **Remote-only — unverified**: avatara, ai-hwaccel, hadara — these likely migrated alongside the wave but need cloning to confirm.
- **`[build].modules` → `[lib] modules` migration**: sigil, agnosys, shakti pending. sakshi has `dist/sakshi.cyr` but no `modules` block — investigate generation mechanism.
- **`docs/adr/` scaffold** (12 repos still missing): agnosys, sigil, takumi, phylax, ark, nous, sakshi, yukti, bsp, owl, cyrius-doom, majra. Copy `README.md` + `template.md` from sit; don't back-fill historical decisions.
- **`docs/adrs/` → `docs/adr/` rename**: argonaut last offender.
- **kiran pin-field population** — kiran shipped 1.0.0 but `cyrius.cyml` still lacks `cyrius = "X.Y.Z"`. Worth populating now that it's stable.
- **Crate registry refresh** — ✅ swept 2026-05-20 PM (post-Attempt-82 drift sweep).
  - [`planning/shared-crates.md`](planning/shared-crates.md) (full registry, pre-1.0 + v1.0+): footer date now 2026-05-20 PM. All flagged bumps confirmed in-tree (agnostik 1.2.2, agnosys 1.2.6, sigil 3.1.1, sankoch 2.2.5, libro 2.6.3, sandhi 1.3.4, niyama 1.0.2, aegis 1.0.0, cyim 1.7.0, chakshu 0.6.0, darshana 0.3.5). v1.0+ graduations folded: **mihi 1.0.0** (OS & Infrastructure, +1 row), **iam 1.0.0** + **bannermanor 1.0.0** (Binaries & Tools, +2 rows). agnos 1.30.7 → 1.31.2 (pin 5.11.59 → 6.0.1) and agnoshi 1.3.2 → 1.3.3 (pin 5.10.44 → 6.0.1) rows refreshed to reflect storage-arc + iron-validation + mid-cycle pin graduations. gnoboot 0.4.1 → 0.4.2. Bannermanor moved from pre-1.0 to v1.0+ section; pre-1.0 binaries count 13 → 11. v1.0+ Stable Index header count 86 → 89.
  - [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ stable subset): header date 2026-05-18 → 2026-05-20 PM, lib count 78 → 79 (mihi added to OS & Infrastructure), Binaries & Tools at v1.0+ list expanded to 12 (added bannermanor, commandress, iam alongside existing entries; pointer-link updated to `#binaries--tools-13-crates`).

### CLAUDE.md table refresh

Root [`CLAUDE.md`](../../CLAUDE.md) "Standalone Repos" table also drifted (same pattern as shared-crates.md). When refreshing, prefer pointing to this file or to shared-crates.md rather than re-duplicating versions in CLAUDE.md.

---

## Doc / article update queue

| File | Action |
|------|--------|
| [`roadmap.md`](roadmap.md) | v5.7.x / v5.8.x / v5.9.x / v5.10.x / v5.11.x phase definitions are now historical; v6.x = "what the language gains" (RISC-V rv64, PIE, closures, Class-B FFI, bare-metal). v5.12.x reservation rolled into v6.x. Re-touch on each v6.0.x ship. |
| [`summer-2026-arc.md`](summer-2026-arc.md) | Cycle-theme references need re-anchoring against v5.10.x three-arc retro + v5.11.x stdlib-annotation closeout + v6.0.0 rename-ceremony framing + closed-beta MVP gate hit on iron. |
| [`articles/cyrius-vs-rust-benchmarks.md`](../articles/cyrius-vs-rust-benchmarks.md) | Add v5.9.x / v5.10.x / v5.11.x / v6.0.0 rows; sweep "Pure compute gap" language for closed items |
| [`articles/port-ledger-volume-1.md`](../articles/port-ledger-volume-1.md) | 🔒 **FROZEN 2026-06-01** — locked to v5.5.4 baseline. Freeze pass added a `STATUS — FROZEN` banner + fixed the 3-vol→5-vol structural drift (every "re-measurement is Volume 2" pointer corrected to **Volume 3**; never-cut `v5.12.x` → v6.x arc). Receipt tables untouched. Immutable. |
| [`articles/port-ledger-volume-2.md`](../articles/port-ledger-volume-2.md) | 🔒 **FROZEN 2026-06-01** — mid-arc snapshot captured 2026-05-15 (kernel iron-validation receipt, pin-cluster review, four new native subsystems). Freeze pass added a `STATUS — FROZEN` banner; "in-flight" statements stay true-as-of-capture, body otherwise untouched. Immutable. |
| **NEW** [`articles/port-ledger-volume-3.md`](../articles/port-ledger-volume-3.md) | 🌱 **OPEN / accreting — seeded 2026-06-01.** The post-arc re-measurement. Fills in per-port as 6.0.x re-benchmarks come online. Seeded with `abaco` (3-point trend: primality −94/−96/−92% landed at 4.8.5, HELD across 5.7.23→6.0.1, +~2× at 6.0.1, no regression) + `hisab` (v2.2.0 Rust-vs-Cyrius head-to-head + re-bench-pending flag on grown x64-batch surface). Ten-port wave + opt-arc closure + held-cluster + cross-arch listed pending. |
| [`articles/doom-in-cyrius.md`](../articles/doom-in-cyrius.md) | v5.11.x rebuild numbers when cyrius-doom ships an unblock release (still on pin 5.7.48) |
| [`articles/sovereign-compiler-vs-brute-force.md`](../articles/sovereign-compiler-vs-brute-force.md) | cycc self-host **874,240 B** at v6.0.0 (was cc5 741,048 B at v5.9.0; +133 KB across the v5.10.x three-arc cycle + v5.11.x 70-patch closeout; +8 B name-string delta at the rename ceremony). Pull current size from `cyrius/build/cycc` before publishing. |
| [`planning/shared-crates.md`](planning/shared-crates.md) | 🔄 Stale as of 2026-05-20 PM. Refresh queue: agnostik 1.2.2, agnosys 1.2.6, sigil 3.1.1, sankoch 2.2.5, libro 2.6.3, sandhi 1.3.4, niyama 1.0.2, aegis **1.0.0**, cyim 1.7.0, chakshu **0.6.0**, darshana **0.3.5**. New (graduated from planned → shipped): argonaut 1.7.0, kybernet 1.2.1, bannermanor 0.5.0, hapi 0.5.0, iam 1.0.0, mihi 1.0.0. |
| [`docs/applications/libs/README.md`](../applications/libs/README.md) | Bump versions for v1.0+ subset; "Last Updated 2026-04-15" predates three minors |
| [`first-party/first-party-documentation.md`](first-party/first-party-documentation.md) | Re-read at each v6.0.x patch — meta-irony from *Docs Go Stale Before the Commit* |
| [`first-party/first-party-standards.md`](first-party/first-party-standards.md) | ✅ Refreshed 2026-05-09 — full Cyrius-first rewrite; Rust-era archive at `docs/archive/first-party-standards-rust-era.md` |
| **NEW** ✅ [*What Justifies a Stdlib Foldin*](../articles/what-justifies-a-stdlib-foldin.md) | Shipped 2026-05-06 — meta-process article covering the gate framework, anti-criteria, mechanism, and three-instance pattern across sandhi/vani/niyama. Subsumes per-instance article slots. |
| **NEW** ✅ Phase-3-stdlib-foldin retrospective | Landed 2026-05-06 in vidya at `content/cyrius/field_notes/compiler/retros/foldin_arc_v57_v59.cyml`. Companion to *what-justifies-a-stdlib-foldin* (process) — the retro is the experiential ledger. |
| **NEW** [*v5.10.x: three arcs in five days*] (working title) | v5.10.x retro candidate — reframe past *REAL TYPE SYSTEM in 24 patches* working title. Cycle closed 2026-05-11 at .50 with three completed arcs (typed-simd ABI 11 phases, REAL TYPE SYSTEM 5 phases, struct-byval ABI 3 phases) + 2.7× compile-perf miniarc + PE premise debunk. Draftable now. |
| **NEW** [*Typed SIMD: the substrate for native codec ports*] (working title) | Companion to *port-ledger* — the typed-simd ABI arc (v5.10.28 → v5.10.39) is the foundation that turns tarang's "framework-only, codecs via C FFI" placeholder into an eventual handwritten-SIMD-codec lane (dav1d/FFmpeg territory). Frame as the *prerequisite landed; codec arc is future-arc work post-bare-metal*. Tarang competition framing piece. |
| **NEW** ✅ darshana extraction note | When darshana ships 1.0.0, document the cyim-private → shared-library extraction pattern (single-consumer-private → second-consumer-triggers-extraction) alongside other extraction examples. |
| **NEW** [*Why AGNOS-native agents can't be drained by a tweet*] (working title) | Black Hat / summer-2026-arc Beat 2 article — AGNOS agent-injection defense as second instance of the absence-by-design structural-immunity pattern (kernel CVE-2026-31431 was the first). Spec: [`planning/agent-injection-defense.md`](planning/agent-injection-defense.md). Roadmap: Phase 15A. Draft after Phase 1 ships (post-closed-beta). |

---

## Refresh procedure

When a v6.0.x patch closes:

1. Pull current `VERSION` + `cyrius.cyml`/`cyrius.toml` for affected repos
2. Update the pin-lag spectrum if any repo crossed a band (and exited the v5.11.x leading-edge bedrock by re-pinning to v6.0.x)
3. Tick off swept items
4. Re-anchor "Last refresh" date in the header
5. Re-anchor "Cyrius toolchain" if a new minor cut

When v6.0.x cycle closes:

1. Move v6.0.x slot list closeout summary into a brief retrospective (one paragraph)
2. Repoint all `6.0.x` references to whichever cycle is next (v6.1.x — back-compat symlinks drop here, plus whichever v6.x feature slot lands first)
3. Don't archive — rewrite in place. Git history is the snapshot.

---

## Related

- [`CLAUDE.md`](../../CLAUDE.md) — preferences/process/procedures (this doc holds the volatile state CLAUDE.md should NOT carry)
- [`applications/shared-crates.md`](applications/shared-crates.md) — authoritative crate registry (versions + roles)
- [`roadmap.md`](roadmap.md) — Cyrius milestone definitions and timeline
- [Cyrius CHANGELOG](https://github.com/MacCracken/cyrius/blob/main/CHANGELOG.md) — authoritative source for cycle status
- [Articles: *Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md) — the rationale for state.md as a pattern
- [Articles: *Your Docs Are About to Rot*](../articles/your-docs-are-about-to-rot.md) — the broader drift argument
- Per-repo `docs/development/state.md` (where it exists) — source of truth for that repo's local state; verify before acting

---

*Refresh in place per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md). Per-day refresh narratives previously accreted here have been pruned — git history is authoritative for prior-state recovery; CHANGELOGs + iron-nuc-zen-log are the canonical event ledgers.*
