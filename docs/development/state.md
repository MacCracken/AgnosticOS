---
name: AGNOS Ecosystem State
description: Live cross-repo state — Cyrius cycle, pin-lag spectrum, active sweeps, carry-forward debt
type: state
---

# AGNOS Ecosystem — Current State

> **⚠ NOT A LOG.** This file is **live state with pointers** — current truth only, plus links to where the history lives. Iron attempt history → [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md). Per-repo release history → each repo's `CHANGELOG.md`. Crate versions → the two registry pointers below. If you find yourself writing prose narrative here, it belongs in one of those other files.

> **Cyrius toolchain**: agnos pins **6.0.14** (`cyrius.cyml`; 6.0.1 → 6.0.3 at the 1.35.5 cycle-open, held through the 1.37/1.38 big-write arcs, → **6.0.14 at the 1.39.0 cycle-open 2026-05-28** — user-requested re-pin to current; A/B byte-identical, all gates green, drift warning cleared). The agnosticos `scripts/cyrius.cyml` boot-pipeline pin **graduated 5.11.59 → 6.0.14 on 2026-05-30** (the long-deferred boot-side sweep landed: rebuilding `read-boot-log` for the 1.40.9 exec-iron CMOS read was its next boot-side touch; compiled clean on 6.0.14, one harmless `vec_get` 6.0.x stdlib-drift warning in a DCE'd path, left unchased per user). v6.0.0 cycle opened 2026-05-19; v5.11.x closed at **5.11.69**.
> **Last refresh**: 2026-05-31. **agnos kernel: 1.40.9 (exec iron-validated; tagging) → 1.40.10 OPEN** · gnoboot 0.4.2. **The 1.40.x exec-from-disk arc is IRON-COMPLETE** — the 1409 final burn (`1409_final_pass`, 2026-05-31) runs `/bin/prog2` + `/bin/argv` in ring 3 on real Zen (`run: exit 42` / `run: exit 90` / `exec: selftest done`, rubric A1–A7 all green); the base-maturity exec leg is proven on iron. **1.40.10 OPEN fixes the scheduler reset that surfaced immediately after, at the DHCP hlt-wait** (NEXT clause below + [`#tracker-14010-cycle`](iron-nuc-zen-log.md#tracker-14010-cycle)). The 1408→1409 triage narrative that follows is **historical** (root cause: `fb_fb_phys` read gnoboot's `boot_info` at its ≥4 GB UEFI load address under the per-process CR3; fixed by `boot_info_copy`): the combined VFS+exec burn went **3/4 first try** — A1 boot/mount + full ext2-write suite + jbd2-clean + A2 ENOEXEC all PASS — but **A3 (the `/bin/prog2` ring-3 run) spontaneously RESET the box** on real Zen. CMOS bisection (`CMOS[0x50]=0x20`, the pre-iretq stamp) proved the **load path fully succeeded**; the fault is the **ring-3 transition itself** on Zen (QEMU `-cpu max` passes the same binary 7/7). **1.40.9 OPEN — the silent reset is its own bug:** the IDT bare-iretq'd every vector → any transition fault triple-faulted → reset. 1.40.9 installs real #UD/#DF/#TS/#NP/#SS/#GP/#PF handlers that stamp the fault vector to `CMOS[0x54]`+magic`0x55`=0xE5 then halt (QEMU 7/7 / sweep 6/6 / check 11/11). **1.40.9 RE-BURN DONE 2026-05-31 (boot `1409_boot_lock`): THE HANDLER WORKED** — box HALTED at `exec: running /bin/prog2` (no reset); `CMOS[0x55]=0xE5` + `CMOS[0x54]=0x0E` → **vector 14 = #PF** (rubric row 159). **CR2 RE-BURN DONE 2026-05-31 (boots `1409_second_attempt_*`): the captured fault REWRITES the diagnosis.** `CMOS[0x5C-0x5F]` = CR2 low-24 `0x006190` + #PF error code `0x00` = **not-present · read · SUPERVISOR (CPL0) · data** — a **kernel-mode (ring 0) read of an unmapped LOW page ~0x6190**, NOT a user fault. This **DISPROVES the earlier "first user VA after the iretq" theory** (that would be `U/S=1`, CR2 ≥ 0x400000). prog2 is exonerated: its code (`0x400078`), write buffer (`0x4000A9`), and stack (`≥0x803000`) are all mapped and nowhere near `0x6190`; the FS is clean (`e2fsck` 38 files, `/bin/prog2` inode 33 intact). `0x6190` sits in the 0-2 MB region holding the boot page tables (`0x1000/2000/3000`), the `boot_shim` GDT (`0x4000`), and the iretq frame (`0x7000`); the fault fires right after `CMOS[0x50]=0x20` (just before the `iretq`) and before any `EXEC-DISK-OK`. **Static audit (2026-05-31) traced the whole exec→`iretq`→SYSCALL→`vfs_write`→exit path against the real hardware and FALSIFIED the GDT/low-mapping hypothesis:** kernel loads @ 1 MB, all RAM ≤16 MB pool, every BAR <4 GB (GPU `0xd0000000`, NVMe `0xfcd00000`), boot_info <4 GB, and the `0x7000` iretq-frame write that precedes the `CMOS[0x50]=0x20` stamp proves PD[0] is present — so literal low `0x6190` cannot be not-present. CR2's byte-2 `0x00` ⇒ the real address is `(k<<24)|0x6190`; the only unmapped such values are **≥4 GB**, and nothing in the path legitimately computes one ⇒ a **wild/garbage ≥4 GB pointer**, unlocalizable from the 3-byte capture. **LATENT FIX LANDED (`proc.cyr`, folded into 1.40.9, QEMU-validated no-regression — sweep all-green except the pre-existing exFAT-write `mkfs 1.3.2` drift):** `proc_create_address_space` now mirrors ALL present kernel `PDPT[1..511]` + `PML4[1..511]` entries (was only PML4[0]→PDPT[0..3] = 0–4 GB), making the per-process CR3 a faithful superset of the kernel map and retiring the 1.40.6 NVMe-BAR-class gap. It's the leading behavioral fix for the ring-3 #PF if a ≥4 GB access is hiding in the path. **FULL-CR2 CAPTURE ALSO LANDED (`idt.cyr`, folded into 1.40.9):** the #PF stub now stamps `CMOS[0x60-0x62]` = CR2 bits 47:24 (full 48-bit address; `read-boot-log` prints `CR2 = 0x…` and flags ≥4 GB explicitly). exec-smoke 7/7, no regression; EXEC-selftest build **1,043,440 B**, flash-ready. **NEXT (dispositive re-burn, user's call on timing): both fixes are in one binary** — a re-burn either boots past `exec: running /bin/prog2` (the CR3 superset fix was it) or halts with the real ≥4 GB `CR2` now readable instead of the truncated `0x6190`. **Both fixes shipped 2026-05-31 (QEMU-green, folded into open 1.40.9):** (1) **CR2+errcode capture** in the #PF handler (`CMOS[0x5C-0x5F]` = CR2 bytes + #PF error code, via the proven 0x70/0x71 bank); (2) **ext2 duplicate-dirent guard** — the 1409 `e2fsck` came back **DIRTY** (dup 'prog2'/'w3a.txt' ×5, "Filesystem still has errors"); `ext2_create`/`ext2_mkdir` lacked the existence guard `ext2_link`/`ext2_rename` already have, so each boot appended a same-name dirent (a contributor to the ext2w MISMATCHes — my earlier "not corruption" read was wrong). exec-smoke 7/7 · ext2-write 19/19 · check 11/11; flash-ready `build/agnos` = 1,042,176 B. **ext2w MISMATCHes FULLY CLEARED 2026-05-31 — the actual fixes:** the dup-guard made `ext2_create` idempotent, but the create-side asserts still no-op'd on fixtures a prior boot left on the persistent NVMe FS — a new `ext2_wst_clean` **PRE-CLEAN** (wipes prior-boot fixtures before the suite runs) is what clears them, making the write suite idempotent on an `--update` flash (no hard reflash needed; this is exactly the user's "first --update boot shows MISMATCH, hard flash doesn't" observation). The cleanup also **EXPOSED + fixed a real `ext2_truncate_zero` bug**: a *fast* symlink stores its target inline in `i_block[]`, and the unlink path walked those ASCII words as block pointers — `rm` of `sl_f → "/hl_b.txt"` freed block 116 (an inode-table block) → e2fsck "multiply-claimed block / off-by-one free count". Bites any `rm` of a fast symlink, not just the test; now guarded (`i_blocks==0` ⇒ no data blocks). Validated with a **two-boot persistent test** (boot the same image twice = the `--update` path the fresh-image smoke never exercises) → boot-2 `e2fsck -fn` clean exit 0; full `sweep.sh` **7/7** (the guard sits on the shared unlink path → all FAT/exFAT/ext2/exec arcs re-swept, no regression). EXEC-selftest build **1,040,688 B**. **FOURTH BURN DONE 2026-05-31 (`1409_fourthboot_idempotent.jpeg`) — DISPOSITIVE: the CR3-superset fix was NOT it, AND the full CR2 is now readable.** Box HALTED again at `exec: running /bin/prog2` (ext2-write suite all-idempotent ✓, shtest ✓, `/notelf` ENOEXEC ✓). **Full 48-bit `CR2 = 0x000140006190`** (≈5.07 GB), err `0x00` = not-present · read · SUPERVISOR(CPL0) · data. **This is a genuine WILD POINTER, not a mapping gap:** PMM pool is capped 0–16 MB (4096×4 KB) so it's not an allocation; GPU/NVMe BARs are all <4 GB (`lspci`: GPU `0xd0000000`, no 64-bit ≥4 GB BAR), so it's not MMIO; vmm boot CR3 maps only **0–1 GB (single PD@0x3000) + on-demand APIC(PDPT[3])/shattered BARs**, so 5 GB is unmapped in EVERY CR3 → the proc.cyr mirror can't help (nothing to mirror). **Path localized:** prog2's `write(1,…)` routes fd1→`dev_write(0)`→`serial_dev_write`→**serial (invisible on iron)**, so the write succeeds silently and the fault is in the **exit→`kernel_resume` window** of prog2's first run (QEMU passes because serial is captured AND zeroed RAM makes the uninitialized value read 0/low). Leading hypothesis: a `pop`/`ret` on a corrupted restored kernel `rsp` (`exec_ctx[6]`) post-`kernel_resume`, or an uninitialized pointer (0 on QEMU→garbage on iron). **A `read-boot-log` DECODER BUG was found + fixed (agnosticos `scripts/src/read-boot-log.cyr`): the #PF/CR2 decode was gated behind a stale gnoboot-magic heuristic (`0x53!=0xCD`) that bailed with "gnoboot never ran" even with `0x55=0xE5`/`0x54=0x0E` stamped — hoisted the exception decode ahead of the reach heuristics.** **RIP-CAPTURE BURN DONE 2026-05-31 — ROOT CAUSE FOUND + FIXED (folded into open/untagged 1.40.9, QEMU-validated; dispositive re-burn pending).** RIP stamp read **`RIP(low32)=0x22220202`** (CR2 `0x010140006190`; low 32 `0x40006190` identical to the prior burn, only the bits-40-47 byte randomized = uninitialized high garbage). `0x22220202` (~572 MB) is OUTSIDE the kernel image and the err code has no I/D bit ⇒ that page is mapped+executing ⇒ **the kernel transferred control to garbage RAM via a corrupted `ret`**, not a bad data deref. **A static-disassembly audit of `build/agnos` EXONERATES the exec/resume logic** (the prior "corrupted exec_ctx restore / pop-ret on bad rsp" hypothesis is FALSIFIED): `exec_and_wait`'s save (`[rbp+0/8/16]`→exec_ctx[5/6/7]), `kernel_resume`'s restore (`movabs &exec_ctx`→`jmp rdx` to the real `0x11ae17` return site), and the `sh_cmd_run` continuation (`pid` in callee-saved r14) are all provably correct + deterministic — they cannot produce a garbage RIP. **Root cause (confirmed in source): the kernel image crossed 2 MB** (LOAD MemSiz `0x20F4E0`) but `pmm_init` reserved only the first 2 MB (pages 0-511) — so pages 512-527 are live `.bss` the PMM thinks free, and the syscall kstack (`syscall_kstack_reserve`→`pmm_alloc_2mb`) only landed at the safe `0x200000` when region 1 was pristine at that boot point. The **KASLR-seeded `pmm_next_free` (RDRAND) + the boot allocs before it** (`main.cyr:150-163`) differ QEMU-vs-Zen, so on iron the kstack relocated to `0x400000` — the user-code VA the per-process CR3 overrides — and the first syscall ran on a stack absent under the user CR3 → corrupted `ret` → the wild #PF. (Same mechanism as the earlier "~17% exec flake.") **Fix (folded into 1.40.9): (1)** `pmm_init` reserves the **first 4 MB** (pages 0-1023 = regions 0+1) — covers the >2 MB kernel + region 1; **(2)** `syscall_kstack_reserve` pins the kstack to a **FIXED `0x3F0000`** (boot identity-mapped, mirrored into every per-process CR3, below the `0x400000` user-VA base — never overridden), no alloc, no KASLR/boot-order dependency. **QEMU: exec-smoke 7/7 · check 11/11 · sweep 6/7** (the one red row is the **pre-existing** FAT-write `mkfs`/LFN drift — verified red on a stashed clean tree too; ext2-write + exFAT-write + exec all green). EXEC-selftest flash artifact **1,046,080 B** (MemSiz `0x20F4E0`), flash-ready. **THAT DISPOSITIVE RE-BURN DONE 2026-05-31 — ROOT CAUSE LOCALIZED + REAL FIX SHIPPED (folded into open/untagged 1.40.9, QEMU-validated).** The box halted again at `exec: running /bin/prog2` (the kstack/pmm fix HELD — RIP no longer garbage) and `read-boot-log` printed `CR2 = 0x000140006190`, err `0x00` = not-present·read·SUPERVISOR·data, **`RIP(low32)=0x00104fc8`** — and the RIP is **inside the kernel image** (1 MB base), the unlock. `objdump build/agnos` maps `0x104fc8` to **`fb_fb_phys()`** (`fb_console.cyr`: `bi=load64(&boot_info_ptr); if(bi==0)return 0; return load64(bi+0x48)`), so the fault is `load64(bi+0x48)` and `boot_info_ptr=0x140006148` (~5 GB) survived the `==0` guard. **Root cause: gnoboot is a UEFI PE app firmware loads at an arbitrary base — on archaemenid (RAM-rich Zen) ≥4 GB** (low 32 `0x40006148` = constant in-image offset of `boot_info`; high bits = load base). The kernel reads `boot_info` **in place**; works all boot because **Path C runs on UEFI's all-RAM identity map** (`pt_init` = `mov cr3,cr3` TLB flush, NOT a switch to its own 0x1000 tables), but `exec_and_wait` switches to the **per-process CR3 (0–4 GB only**; the kernel's own tables never mapped ≥4 GB so the superset-mirror had nothing to mirror), so prog2's first `write`→console→`fb_putc`→`fb_fb_phys` reads `boot_info` ≥4 GB → unmapped → #PF. QEMU/OVMF loads gnoboot <4 GB → never reproduces (the QEMU-vs-Zen divergence; same class as 1.40.6 NVMe-BAR). **FIX (`mbi.cyr` `boot_info_capture_rdi` + new `boot_info_copy[16]` in `boot_data.cyr`):** at capture (top-level, first thing after the boot shim, UEFI map still live) `memcpy` the 120 B struct into a low (<4 GB) kernel buffer + repoint `boot_info_ptr` → all `fb_fb_phys`/pitch/width/height reads now CR3-independent. FB BAR `0xd0000000` (3.49 GB, `lspci`-confirmed) is <4 GB + already mirrored → pixel writes were never the fault. **QEMU: exec-smoke 7/7 · sweep 6/7** (red row = pre-existing FAT-write `mkfs`/LFN drift; ext2-write + exFAT-write + exec green); no-op on QEMU ⇒ zero regression by construction. EXEC-selftest flash artifact **1,046,320 B**, burn-ready. **DISPOSITIVE RE-BURN DONE 2026-05-31 (`1409_final_pass`): EXEC-FROM-DISK PASSES ON IRON 🎯** — `run: exit 42` + `run: exit 90` + `exec: selftest done`; rubric A1–A7 all green; base-maturity exec leg iron-validated, user tags **1.40.9**. **But the boot then RESET right after `Activating scheduler...` → `dhcp: DISCOVER`** — a latent scheduler bug the *working* exec selftest exposed (DHCP innocent, user's read confirmed). **→ 1.40.10 OPEN:** the now-working exec selftest leaves `proc_count≥2` + `proc_current` on a dead exec proc, so the first post-`sched_active=1` timer tick (the DHCP hlt-wait) clears `do_context_switch`'s `proc_count<2` early-return, falls back to a dead exec proc, `cr3_load`s its stale per-process CR3 + iretqs into a ring-3 RIP in ring 0 → triple-fault reset (QEMU can't repro — SLIRP answers DISCOVER before a tick lands). **Fix (user chose "real kernel idle proc 0"): register proc 0 = kernel main thread + proc 1 = hlt idle thread, both on boot CR3 `0x1000`, before `sched_active=1`** (equal-CR3 ⇒ `cr3_load` never fires ⇒ pure register-switch, single-address-space kernel-threads model). QEMU exec-smoke **7/7**, sweep **6/7** (red = pre-existing exFAT-*read*; FAT-write now passes), boot advances `Activating scheduler...`→`Launching kybernet...`. Burn artifact **1,050,592 B** (`burn-prep.sh` exit 0), burn-ready; re-burn pending → [`#tracker-14010-cycle`](iron-nuc-zen-log.md#tracker-14010-cycle). Bite 2 LANDED (rides the same burn): `kernel_resume` resets `proc_current=0` so interactive `run` can't leave a dead proc for the scheduler to resurrect (exec-smoke 7/7, sweep 6/7). Per [[feedback_no_unprompted_version_bumps]] no VERSION bump until the user tags. `read-boot-log.cyr` was slimmed 986→210 lines (dead xhci/r8169/dhcp/MTRR chapters dropped; decodes live slots + #PF CR2/errcode/RIP bit-decode). Detail → [`iron-nuc-zen-log.md` § 1409 burn entry](iron-nuc-zen-log.md) + [`#tracker-140-cycle`](iron-nuc-zen-log.md#tracker-140-cycle). **base-maturity close ACHIEVED on iron 2026-05-31** (FS-crash-safe ✓ + exec-from-disk ✓ both iron-validated); the only open item is 1.40.10's scheduler-reset fix re-burn (boot-to-shell past scheduler activation). The 1.39.x VFS generic-write lift is functionally COMPLETE (verb surface + subdirs; Track B was not exercised — the A3 reset ended the boot first; rides the 1.40.9 re-burn). 1.37–1.38 big-write arcs closed + iron-validated. Arc ladder since the last refresh:
> - **1.35.x comms arc — CLOSED at 1.35.7.** DNS stub resolver + 8-entry TTL cache, ICMP echo/`ping`, TCP hardening (retransmit + RX window + MSS), NTP/SNTP + CMOS RTC boot clock, anonymous `mmap`/`munmap` (first new functional syscall since v1.21), arc-close hardening (forged-IP-length clamp + TCP seq-wrap/RTC bounds).
> - **1.36.x refactor cycle.** `net.cyr` 3-way split (L2/L3 core + protocols + ingress) + `main.cyr` selftest extraction — **all byte-for-byte identical builds** (sha256-verified), behavior provably unchanged.
> - **1.37.x ext4 extent-ALLOCATION arc — iron-validated.** On-demand tree growth depth 0→1→2; **archaemenid Attempt 1373 PASS** (depth-2 written + survived power-cycle, host `e2fsck -fn` clean). Closed at **1.37.5** by vendoring **kashi 0.6.0** font-data core into `fb_console.cyr` (retiring the planned 1.40.x console-font separation cycle in the same motion).
> - **1.38.x jbd2 journaling arc.** 1.38.0 probe+dirty-refusal → .1 SB read + V2/V3 SB-csum validate + `jbd2` verb → .2 log reader → .3 replay-on-mount → .4 tx lifecycle → .5 write path → .6 `put_inode` integration → .7 crash smoke → .8 arc-close hardening → .9 iron-burn automation (CMOS-stamped telemetry slots 0xA0-0xA4 + host wrappers) → **.10 CSUM_V2/V3 write+replay support** (the 2026-05-28 iron-burn unlock).
>
> **JBD2 iron burn done 2026-05-28** (boots `1389_*`): **read-side PASSED** (probe + SB-csum-validate on the real journal); **write-side was blocked** because archaemenid's agnos-fs journal is **CSUM_V3 + 64BIT** (`incompat=0x12`) — the Linux kernel stamps CSUM_V3 onto a `metadata_csum` journal on first RW mount, `mke2fs` doesn't, so the QEMU smokes never hit it and the 1.38.7 refusal aborted every `commit_tx` on iron. **1.38.10 implements the V3 tag/descriptor/commit checksums** (write + replay), formats re-derived from `include/linux/jbd2.h` + `fs/jbd2/commit.c` and **Linux-`e2fsck`-oracle-validated**; `commit_tx` now COMMITs to the real journal. All 5 jbd2 smokes green on a CSUM_V3 journal (`mk-dirty-journal-img.py --csum-v3` mirrors the kernel stamp); also fixed a latent legacy-tag field swap that made AGNOS journals non-Linux-replayable. `test.sh` 4/4 · `check.sh` 11/11 · build **992,832 B**. Per-cut detail → CHANGELOG `[1.35.0]`–`[1.38.11]`; iron evidence → [`#tracker-138-cycle`](iron-nuc-zen-log.md#tracker-138-cycle) + the 1.37.x Attempt 1373 entry.
> **JBD2 write-side re-burn DONE 2026-05-28** (boots `13810_*`): five-boot sequence on the unmodified CSUM_V3 agnos-fs journal cleared every tracker row — boot-1 clean baseline (seq 4), boot-2 integration **`commit_tx: COMMITTED`** (the line that refused at the 1389 burn) + `integration selftest PASS`, boot-3 crash **`stress loop PASS (clean shutdown)`** (100/100), boot-4 deliberate mid-cycle power cut, boot-5 recovery clean (`jbd2: clean journal … seq=142`). Host `e2fsck -fn` clean + journal SB CLEAN at every checkpoint. **Crash-safe journaling iron-validated — the 1.38.x arc is COMPLETE.** Photos catalogued → [`iron-nuc-zen-photos/`](iron-nuc-zen-photos/README.md).
>
> **1.39.x VFS generic-write lift OPEN** (arc plan: [`vfs-generic-write-prior-art.md`](vfs-generic-write-prior-art.md); read-first, single-primary-FS). **1.39.1 DONE — bite 1: `cat` reaches FAT/exFAT** (`vfs_open_secondary`). **1.39.2 DONE — bite 2: `ls` lists FAT/exFAT** (`vfs_print_dir_secondary`; `fatfs_ls` serial→FB + new `exfat_print_dir`). **1.39.3 DONE — bite 3: `touch`+`echo >` write to FAT/exFAT** (`vfs_create_secondary`/`vfs_write_secondary`; non-ESP-preferring). **1.39.4 DONE — bite 4: `rm`** (`vfs_delete_secondary`). **1.39.5 DONE — bite 5: FAT `mkdir`/`rmdir`** (`fatfs_mkdir`/`fatfs_rmdir`/`fatfs_dir_is_empty`; first bite that *adds* backend capability). **1.39.6 DONE — bite 6: exFAT `mkdir`/`rmdir`**. **1.39.7 DONE — bite 7: `mv` (rename) + `sync`** (`fatfs_rename` in-place dirent rewrite, `exfat_rename` re-emit-at-same-clusters, `vfs_rename_secondary`/`vfs_sync_secondary`); fat-write + exfat-write rename gates + `fsck` clean. **Full shell verb set now works on FAT + exFAT** (`cat`/`ls`/`touch`/`echo >`/`rm`/`mkdir`/`rmdir`/`mv`/`sync`). **1.39.8 DONE — bite 8 (arc close): mount-registry consolidation + ingress hardening.** Folded the seven duplicated non-ESP-preference chains behind one `vfs_secondary_select()` (byte-identical behavior, −1,760 B); bounds/ingress review re-derived every backend buffer clean + added `vfs_sec_name_ok` (1..255) at the generic seam (bounds `fatfs_build_83`'s unbounded dot-scan + backstops the exFAT create/mkdir entries). check 11/11 · test 4/4 · all four FAT/exFAT smokes + ext2-write regression PASS · `fsck` clean · build 1,008,816 → **1,007,696 B**. Iron pre-audit rubric written → [`#tracker-139-cycle`](iron-nuc-zen-log.md#tracker-139-cycle) (folds in the long-pending 1.34.x FAT/exFAT iron burn; test-surface fork is the user's call). **1.39.9 DONE — bite 9: FAT/exFAT subdir paths.** Pure backend work (the shell already passed full slashed paths): `fatfs_resolve_parent`/`exfat_resolve_parent` path-walk + per-directory finder generalization (sentinel `dir_clus==0`=root → byte-identical bare-name behavior); wired open/create/write/delete/mkdir/rmdir/rename on both backends. `cat`/`touch`/`echo >`/`rm`/`mkdir`/`rmdir`/`mv` now operate inside subdirectories. `mv` bounded to same-parent (cross-dir move = follow-on). Both write smokes +4 subdir gates each, `fsck` clean; ext2 regression PASS; build 1,007,696 → **1,014,528 B**. **Removes the last FAT/exFAT-vs-ext2 asymmetry — the VFS-lift verb surface is functionally COMPLETE.** All zero-risk to the ext2 path. **1.39.9 tagged + out** (commit `99755c8`). Follow-ons (not arc-blocking): cross-dir `mv`, `ls <subdir>`.
> - **1.40.x exec-from-disk arc — OPEN 2026-05-28 (1.40.0 cycle-open).** The second base-maturity exit leg. `elf_load` (hardened static ELF64 *buffer* loader) + `proc`/`sched`/`spawn`/`waitpid` already exist; the gap is **disk → buffer** + a shell `run` verb. **1.40.1 DONE — `vfs_read_file`** (whole-file read past the 4 KB cap, FS-resolved; finding: `kmalloc`/`pmm_alloc` both cap at one 4 KB page — **no large-contiguous allocator** → streaming loader chosen, ext2-first). **1.40.2 DONE — streaming ELF loader (the LOAD half).** `elf_load_from_file` + `vfs_read_file_at`/`vfs_file_size`; streams each `PT_LOAD` segment **directly into its physical pages via the kernel identity map — no CR3 switch** (the CR3-switch-into-half-built-AS approach hung). `run <path>` loads + reports. exec-smoke PASS (ELF→ext2→stream-load→parse `entry=0x400078`→map→`fsck` clean); build 1,024,256 → **1,033,296 B**. **Scope discovery:** the ring-3 *execution* step (`exec_and_wait`) is unproven pre-existing infra (KTEST always bypassed the iretq/KPTI-user-CR3 path) → split into its own bite. **1.40.3 DONE — ring-3 execution (the RUN half) WORKS.** `run /prog` loads a static ELF64 off ext2, runs it in ring 3, prints its `EXEC-DISK-OK` (write→console) + `run: exit 42` (exit code captured); exec-smoke 6/6, `fsck` clean, no FS regression. Brought up the entire never-run ring-3+SYSCALL path — **10 first-run bugs**, core blocker was the SYSCALL stub's `mov cr3,r10` mis-encoded REX.R(`44`,→cr11→#UD) vs REX.B(`41`); also NX-stack LSTAR bytecode, EFER.SCE, KPTI dual-CR3 (collapsed to one full per-process CR3), syscall-kstack/user-stack VA collision, SMAP (STAC/CLAC), APIC-before-cr3-switch, timer-in-ring3 (IF masked), 2MB-vs-4KB alloc, fd1/2→console. Run-to-completion/single-threaded (interrupts masked in ring 3). **1.40.4 DONE — subdir/CWD program paths + ENOEXEC/E2BIG.** `run` resolves a subdir/CWD path (`sh_abspath`+`ext2_path_lookup`) and refuses non-ELF (ENOEXEC) / >16 MB (E2BIG); exec-smoke runs `/bin/prog2` from a subdir (EXEC-DISK-OK + exit 42) + refuses `/notelf`, `fsck` clean. **1.40.5 DONE — arc close: hardening + automated sweep + manual iron plan.** Fixed clean `exec_and_wait` return (full setjmp/longjmp of callee-saved + caller frame → caller continues; "selftest done" after the run) + the ~17% flake (reserve the SYSCALL kstack right after heap_init → phys 0x200000, below user VAs — was colliding when the heap pushed it to 0x400000). Added **`agnos/scripts/sweep.sh`** (one-command QEMU sweep of both arcs — baseline + FAT/exFAT r/w/subdir + ext2 regression + exec; **7/7 PASS**) + **`exec-iron-manual-tests.md`** (on-iron checklist for the combined burn). **Remaining: only the user-driven combined VFS+exec iron burn** ([`exec-iron-manual-tests.md`](exec-iron-manual-tests.md) + [`#tracker-139-cycle`](iron-nuc-zen-log.md#tracker-139-cycle)) → closes both arcs + the base maturity stage on hardware. **1.40.6 DONE — multi-`run` in one boot:** the shell runs many programs sequentially, each with its own exit code. Two fixes: `kernel_resume` restores the boot CR3 on exit (the per-process CR3 didn't map the NVMe BAR → the *next* run's ext2 read faulted) + `sh_cmd_run` sets `proc_current = pid` (exit-code attribution). exec-smoke runs `/bin/prog2` twice (EXEC-DISK-OK ×2, exit 42 ×2); sweep.sh hardened (single-run + retry) → 7/7. **1.40.7 DONE — argv:** `run <path> [args]` builds the SysV init stack (`rsp→argc/argv[]/NULL/envp/auxv`) in `elf_load_from_file`; `sh_cmd_run` splits the path token from args. `/bin/argc` selftest exits with argc → `run /bin/argc one two` = `run: exit 3`. sweep 7/7. **Post-arc remaining: 1.40.8 harden + burn-prep** (updated scripts). Deferred: envp/auxv contents, ≥3 sequential runs (depth flake), preemptive ring 3 (interrupt-KPTI), Meltdown-grade KPTI, FAT/exFAT exec. Static-only; argv/env + bare-name fallthrough + `$PATH` are follow-ons. Arc plan: [`exec-from-disk-prior-art.md`](exec-from-disk-prior-art.md). **1.41.x stays shell→agnoshi.** Per [[feedback_self_cut_after_work]] the remaining 1.40.x bites self-roll their cut.
>
> **Closed arcs (history lives in CHANGELOG + iron-log, not here):** storage backends + GPT + ext2/ext4 read, 1.31.x ([`#tracker-133-cycle`](iron-nuc-zen-log-mvp2.md#tracker-133-cycle) for the FS detail); networking, 1.32.x (see Networking line below); ext2/ext4 WRITE incl. the W5 demo→base iron burn + the 1.33.5 fsync/FLUSH-CACHE barrier, 1.33.x ([`#tracker-1335-cycle`](iron-nuc-zen-log-mvp2.md#tracker-1335-cycle)); 1.34.x FAT/exFAT write-completeness; 1.35.x comms (DNS/ICMP/TCP-hardening/NTP/RTC/mmap); 1.36.x net.cyr+main.cyr refactor (byte-identical); 1.37.x ext4 extent-allocation (iron Attempt 1373); 1.38.x jbd2 journaling (CSUM_V3 write+replay; **write-side + crash-recovery iron-validated at the `13810_*` re-burn**; arc closed at 1.38.11).
>
> **Open carry-forward debt:** **1.37 ext4 extent-alloc** ✓ (iron-validated) and **1.38 jbd2 journaling** ✓ (CSUM_V3 write+replay at 1.38.10; QEMU-green + Linux-e2fsck-oracle-validated; **write-side + crash-recovery iron-validated at the `13810_*` re-burn**) are DONE. **1.39.x VFS generic-write lift = functionally COMPLETE** — full FAT/exFAT shell verb set (bites 1–7), dispatch consolidated + ingress-hardened (bite 8 / 1.39.8), subdir paths (bite 9 / 1.39.9). The two writable FSes have earned the abstraction; the last FAT/exFAT-vs-ext2 asymmetry is gone. **Remaining in-arc: only the user-driven iron burn** (closes the arc on real hardware). Kernel-slimming: console-font→`kashi` already landed early at **1.37.5** (retired the planned 1.40.x cycle); **shell→agnoshi** remains. The user-driven **FAT/exFAT iron burn** (1.34.x arc's first iron touch; brick-safe via the non-ESP guard) is now folded into the 1.39.x VFS-lift burn rubric → [`#tracker-139-cycle`](iron-nuc-zen-log.md#tracker-139-cycle) (supersedes the older [`#tracker-1341-cycle`](iron-nuc-zen-log-mvp2.md#tracker-1341-cycle) pointer).
>
> **Networking arc (1.32.x): COMPLETE — iron-verified on archaemenid.** L2 → unicast TCP → DHCP real-lease all proven (the r8169 unicast-RX blocker was RX-ring delivery capacity, fixed 16→64 at 1.32.7; DHCP lease `.142` verified at 1.32.9). i225-V driver stays queued for Intel iron post-migration. Full narrative + iron evidence → [`#tracker-1329-cycle`](iron-nuc-zen-log-mvp2.md#tracker-1329-cycle) + CHANGELOG `[1.32.x]`.
>
> MVP gate (boot-to-shell on iron) green since Attempt 68 / 1.30.9.
>
> **Iron-log roads (base → server → platforms)** — logs split by maturity era; active one keeps the bare name. **base** (active — [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md), 1.37.x+) closes at FS-crash-safe (1.37 extent → 1.38 jbd2 → 1.39 VFS) + general exec-from-disk; **server** closes at self-hosting — *build agnos on agnos* (headless, **no desktop needed**; coincides with the public-beta gate); **platforms** (1.5x+ hardware) runs orthogonally. Chain: [`-mvp`](iron-nuc-zen-log-mvp.md) (boot) → [`-mvp2`](iron-nuc-zen-log-mvp2.md) (net+write) → active. Stage definitions: the maturity-arc memory.
>
> **Crate registries**: [`planning/shared-crates.md`](planning/shared-crates.md) (full, incl. pre-1.0); [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ subset).

### Storage + filesystem-read arc (1.31.x) — CLOSED 2026-05-22

All block backends + GPT + ext2/ext4 read landed and iron-debuted on archaemenid across 1.31.0 → 1.31.7: **NVMe** (Crucial P3 2 TB, Attempt 80), **AHCI/SATA** (WD Blue SA510 2 TB, 81), **USB-MS** BBB+SCSI (Silicon Motion stick, 87 — after the Phase 2.5–2.8 reset-recovery arc), **RAM-disk** + **VirtIO-blk modern** (QEMU-only by construction, 88), **GPT** Phase 1-3 (CRC32 + backup recovery + type-GUID classifier), **ext2/ext4 read** incl. 64BIT BGDT stride + partition-aware mount + shell UX (ext4 victory lap byte-exact on real NVMe NAND, Attempts 90-91). Per-cut detail → CHANGELOG `[1.31.0]`–`[1.31.7]`; iron Attempts 80-91 + the AHCI/USB-MS carry-forward resolutions → `iron-nuc-zen-log.md` + [`ahci-iron-burn-audit.md`](ahci-iron-burn-audit.md) / [`usb-ms-iron-burn-audit.md`](usb-ms-iron-burn-audit.md). **Optical via USB-MS (SCSI MMC, non-512-B sectors)** + **NTFS / squashfs read** stay deferred (roadmap rows 4 / 23).

**Out of cycle scope (parked):**
- AMD Zen scanout residue (Quiet Boot legibility) — separate cycle per [`project_amd_zen_scanout_residue`](../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_amd_zen_scanout_residue.md); HUBP `clear_tiling` port or shadow-buffer eval.
- SMP-AP wakeup on real hardware — carry-forward from earlier roadmap.
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

Each repo's `cyrius = "X.Y.Z"` pin (verified 2026-05-11 eve from local clones, with leading-edge spot updates). **Most pre-CYML consumers migrated**: agnoshi, bote, t-ron, kavach, itihas, nein all moved from `cyrius.toml` v3.x/v4.x to `cyrius.cyml` 5.10.44+. Only `hoosh` and `shravan` remain on pre-CYML format in the local-verified set. **The v5.11.x leading-edge bedrock is now where consumers will pause** — back-compat symlinks (`cc5 → cycc`, `cyrc → cybs`) keep them building unchanged through the v6.0.x window; natural-next-touch will graduate each consumer to v6.0.x and re-pin then.

```
PRE-CYML format / no pin field (remaining tail):
  hoosh (cyrius.toml, no pin field visible in snapshot)
  shravan (cyrius.toml, no pin field visible in snapshot)

CYML format — DEEP LAG (didn't roll forward; may carry latent stdlib breakage):
  v5.1.x:  ark (5.1.10)                              ← extreme lag, port pre-dates pin convention
  v5.6.x:  yantra (5.6.17)
  v5.7.x:  hisab (5.7.10), agnova (5.7.12),
           abaco (5.7.23), nous (5.7.29),
           bazaar (5.7.30), shakti (5.7.33)
  v5.7.48: mabda (3.0.0-rc.2), cyrius-doom (0.26.2),
           samvada (0.2.2)                           ← held-cluster (was 4; phylax exited)

CYML format — WARM CLUSTERS:
  v5.9.x:  sit (5.9.37), vidya (5.9.43)
  v5.10.x: vyakarana (5.10.5), owl (5.10.10),
           cyim (5.10.10), cyim-lsp (5.10.10),
           cyim-lsp (5.10.20),
           aegis (5.10.34)
           — darshana graduated to v6.0.1 cluster 2026-05-20 (color primitives bump)

CYML format — LIVE 5.10.44 BEDROCK (~14 repos, the boot path minus agnos + agnoshi):
  v5.10.44: agnostik (1.2.2), argonaut (1.7.0),
            bote (2.7.2), daimon (1.2.3),
            kavach (3.2.1), kybernet (1.2.1),
            libro (2.6.3) — exited 5.4.x deep-lag,
            majra (2.4.4) — exited 5.4.x deep-lag,
            nein (1.5.1), phylax (1.1.1) — exited 5.7.48 held cluster,
            t-ron (2.1.4)
            — agnoshi graduated to v6.0.1 cluster 2026-05-20 (1.3.2 → 1.3.3)

CYML format — 5.11.x post-burst sub-cluster (trailing; no leading-edge holdouts):
  v5.11.4:  agnosys (1.2.6), sigil (3.1.1), sankoch (2.2.5),
            sandhi (1.3.4), niyama (1.0.2), patra (1.9.4),
            sakshi (2.2.4), vani (0.9.3), yukti (2.2.3)
  v5.11.8:  ai-hwaccel (2.2.2)

CYML format — LEADING-EDGE 6.0.x cluster (post-v5.11.x graduations):
  v6.0.14: agnos (1.39.0)   ← re-pinned at the 1.39.0 cycle-open 2026-05-28
                              (6.0.1 mid-1.31.x → 6.0.3 at 1.35.5, held through
                              the 1.37/1.38 big-write arcs → 6.0.14; A/B
                              byte-identical, all gates green)
  v6.0.1:  agnoshi (1.3.3), mihi (1.0.0), iam (1.0.0),
           chakshu (0.6.0), bannermanor (1.0.0), darshana (0.3.5),
           hapi (0.5.0)
           — agnos originally graduated mid-1.31.x cycle for binary fixes
             in cycc 6.0.1 (was 5.11.64, the gvar-init-order anchor), then
             advanced to 6.0.14 at 1.39.0 (above). The 2026-05-20 terminal-
             aesthetics burst brought six: mihi + iam cut as NEW 1.0.0
             repos straight on v6.0.1; chakshu jumped 0.3.0 → 0.6.0 +
             5.10.20 → 6.0.1; bannermanor (`bnrmr` figlet-equivalent) +
             hapi (stow-equivalent) cut at 0.5.0 straight on v6.0.1;
             darshana graduated from
             v5.10.20 → v6.0.1 with the 0.3.0 → 0.3.5 color-primitives
             bump that bannermanor's banner colors needed.

CYRIUS TOOLCHAIN itself: 6.0.1 (v6.0.0 cycle opened 2026-05-19, same-day .1 patch for UEFI fncall ud2 emit regression; v5.11.x closed at 5.11.69)

NOT VERIFIED LOCALLY (remote-only, presumed pre-CYML or scaffolded):
  avatara, hadara, itihas, takumi, aethersafha, aethersafta, mela,
  seema, samay, kiran, joshua, salai, murti, tanur, encom-hits,
  cyrius-{bb,brynns-tale,stellar-swarm,sunset-drive,super-plumber-twins,
  grapevine,chellys-beach-adventure,nba-jam}
```

**Bands of attention (2026-05-20 PM — post-MVP-gate, post-v6.0.0 cycle-open, agnos + agnoshi graduated mid-1.31.x storage cycle):**
- **6.0.1 leading-edge cluster** (2026-05-20 → -22, **9 repos**): **agnos (1.32.1)** + **agnoshi (1.3.3)** + mihi (1.0.0), iam (1.0.0), chakshu (0.6.0), bannermanor (1.0.0), darshana (0.3.5), hapi (0.5.0), **kii (0.1.0)** (added 2026-05-22 — Hawaiian Polynesian micro-cluster joins via image→ANSI/ASCII converter). The morning brought sys-info substrate (mihi/iam/chakshu) and afternoon brought terminal-aesthetics (bannermanor / hapi / darshana). The 2026-05-20 evening MVP-path graduation pair (agnos + agnoshi) onto cycc 6.0.1 was the load-bearing change; agnos has since rolled through the storage arc and ext2/4 cycle on the same pin: 1.31.2 → 1.31.3 (USB MS Phase 2.8) → 1.31.4 (RAM-disk + VirtIO modern) → 1.31.5 (ext2/4 Phase 1-4) → 1.31.6 (cleanup cycle close) → **1.31.7** (FS follow-ups + shell UX close). The darshana 0.3.0 → 0.3.5 bump was demand-driven (bannermanor needed color escape sequences) — same shared-lib-evolves-to-second-consumer pattern as mihi's cyim → chakshu extraction.
- **5.11.x cluster**: now empty of leading-edge holdouts — agnosticos/scripts graduated 5.11.59 → 6.0.14 on 2026-05-30 (boot-side sweep; see toolchain banner above), joining agnos on the leading edge. agnos had already vacated 5.11.64 mid-1.31.x cycle. (genesis-repo VERSION flipped CalVer → SemVer at 0.1.0 cycle-open 2026-05-21.) The .4/.8 post-burst sub-cluster below still trails.
- **5.11.x post-burst cluster** (~10 repos at .4/.8) — sandhi, niyama, patra, sakshi, vani, yukti, agnosys, sigil, sankoch, ai-hwaccel. Ahead of the bedrock but trailing the leading-edge.
- **5.10.44 live bedrock** (~14 repos: kybernet, argonaut, kavach, daimon, bote, t-ron, libro, etc.) — agnoshi exited 2026-05-20, narrowing the MVP-path holdouts to **kybernet + argonaut** (these still pin 5.10.44 and still boot AGNOS on iron). Rest of the bedrock graduates to v6.0.x on natural-next-touch.
- **Deep-lag tail** shrank but didn't vanish: ark (5.1.10) extreme, hisab/agnova/abaco/nous/bazaar/shakti in v5.7.x cluster, yantra (5.6.17). The 5.4.x cluster (libro, majra) FULLY EXITED at 5.10.44.
- **Held cluster at 5.7.48** now **3 repos** (mabda, cyrius-doom, samvada) — phylax exited during v5.10.x. mabda is at 3.0.0-rc.2 (soak before GA fold to Cyrius stdlib); cyrius-doom is at 0.26.2 (gated on Cyrius optimization-arc closeout retroactive verification).
- **Pre-CYML format tail**: only `hoosh` and `shravan` remain in the local-verified set. The previous 11-repo tail collapsed in the v5.10–v5.11 window.

### New repos / milestone bumps since last refresh

| Repo | Version | Pin | Notes |
|------|---------|-----|-------|
| **aegis** | **1.0.0** | 5.10.34 | **Hit v1.0** (was 0.8.2 in last refresh). Real system-security daemon now shipping. Skipped 0.9.x — straight implementation closeout to 1.0.0. |
| **agnos** | **1.32.1** | **6.0.1** | **1.31.x storage + FS arc CLOSED 2026-05-22 / 1.32.0 networking arc CLOSED 2026-05-22 / 1.32.1 networking-arc-continued cycle OPEN 2026-05-22.** Through-line: 1.31.2 → 1.31.3 (USB MS Phase 2.8 eight-bug repair stack / Attempt 87 iron PASS) → 1.31.4 (RAM-disk + VirtIO 1.x modern / Attempt 88 iron PASS no-regression) → 1.31.5 (ext2/4 Phase 1-4 / Attempt 89 iron PASS no-regression) → 1.31.6 cleanup cycle (8 bites + 2 smoke-surfaced fixes + Iron Attempt 90 ext4 victory lap PASS) → 1.31.7 filesystem follow-ups + shell UX CLOSED (ext4 64BIT Phase 5 + `cd`/`pwd`/CWD scoping + bare-name `cat` + `ls -la` flag dispatch + Iron Attempt 91 PASS) → **1.32.0 networking arc CLOSED 2026-05-22**: TCP server primitives + UDP server primitives + DHCP client RFC 2131 + r8169 driver Phases 1-4 + iron Attempts 92 + 93 on archaemenid + DHCP gate predicate fix at `main.cyr:655`. **Iron evidence**: Attempt 92 PARTIAL surfaced gate predicate bug → same-day fix `if (vnet_active != 0 || nic_ready() != 0)` → **Attempt 93 PARTIAL VERIFIED the fix on iron** (`dhcp: DISCOVER` egresses through r8169 path for the first time; new failure mode `dhcp: OFFER timeout`). → **1.32.1 OPEN 2026-05-22** networking-arc-continued cycle-open (lean: VERSION bump 1.32.0 → 1.32.1 via canonical `scripts/version-bump.sh` + CHANGELOG `[1.32.1]` header + tracking surface, no code touches yet). Cycle theme: **r8169 driver-level OFFER-timeout debug** (H1 PHY-not-configured / H7 TX OWN stuck / H8 RX OWN stuck — the now-reachable audit hypothesis surface from Attempt 93's pre-burn rubric). Opening move: §5b extension to [`r8169-iron-burn-audit.md`](r8169-iron-burn-audit.md) per [[feedback_iron_burns_block_other_work]] + [[feedback_redesign_dont_reinvent]]. Carry-forward still in flight: i225-V driver bite C (Intel iron pending, post-archaemenid-migration); BBS + MUD userland (out-of-cycle, separate repos). Strategic destination: AGNOS installable-state on archaemenid → user's planned **dual-boot migration**: 1TB ex-USB drive becomes Beelink internal NVMe + hosts AGNOS-primary; WD Blue SA510 SATA stays in chassis as Linux daily-driver root; 2TB Crucial P3 NVMe migrates to i9. See § *archaemenid migration* above and [[project_archaemenid_install_plan]]. Multi-cycle path: 1.32.x networking → 1.33.x ext4 WRITE → installable-state cycle slot TBD. See § *1.32.0 cycle* (CLOSED) + § *1.32.1 cycle* (OPEN). Pin stable on cycc 6.0.1. Build trajectory: 578,432 B (1.31.7 close) → 601,392 B (1.32.0 close) → **601,392 B (1.32.1 open, zero structural delta — only `version_str` literals shifted across the bump)**. |
| **agnoshi** | **1.3.3** | **6.0.1** | AI shell + closed-beta MVP boot-path console. Was 1.3.2 / pin 5.10.44 (live-bedrock cluster) in last refresh; graduated straight to 6.0.1, skipping the 5.11.x leading-edge tier. After this bump + agnos's 6.0.1 graduation, the MVP-path 5.10.44 holdouts narrow to **kybernet + argonaut** — the two repos still on 5.10.44 that need to graduate before the entire closed-beta MVP path runs on v6.0.x. |
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

**AGNOS-native kernel** (`agnos` v1.30.9): structurally immune — verified at `kernel/core/syscall.cyr:32-36`, 26-syscall table contains no `socket`, no `splice`, no AF_ALG family. Bug class is unreachable. (Kernel has moved 1.26.1 → 1.30.9 since the original CVE audit across multiple bring-up cuts; syscall-surface unchanged. Syscall table verification is anchored on the syscall-table invariant, not the kernel patch level — re-verify only if the syscall surface grows.)

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
| [`articles/port-ledger-volume-1.md`](../articles/port-ledger-volume-1.md) | ✅ Refreshed 2026-05-15 — locked to v5.5.4 baseline; accreted body updates stripped; *What Comes Next* expanded to 5-volume arc (V1 baseline → V2 mid-arc → V3 end-of-5.x/v6.0 → V4 post-v6.x → V5 synthesis). Where-Rust-Still-Wins markers point at Volume 2/3. |
| **NEW** [`articles/port-ledger-volume-2.md`](../articles/port-ledger-volume-2.md) | ✅ Shipped 2026-05-15 — mid-arc state-of-things snapshot. Kernel iron-validation receipt (the V2 headline); pin-cluster review across 5.10/5.11 ecosystem; four new native subsystems (aegis 1.0.0, gnoboot 0.2.0, commandress 0.1.0, kriya 0.2.0); V1's "Where Rust Still Wins" reviewed for direction-of-motion. Re-measurement comprehensive-cut deferred to V3. |
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
