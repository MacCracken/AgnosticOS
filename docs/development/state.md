---
name: AGNOS Ecosystem State
description: Live cross-repo state — Cyrius cycle, pin-lag spectrum, active sweeps, carry-forward debt
type: state
---

# AGNOS Ecosystem — Current State

> **⚠ NOT A LOG.** This file is **live state with pointers** — current truth only, plus links to where the history lives. Iron attempt history → [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md). Per-repo release history → each repo's `CHANGELOG.md`. Crate versions → the two registry pointers below. If you find yourself writing prose narrative here, it belongs in one of those other files.

> **Cyrius toolchain**: 6.0.1 (v6.0.0 cycle opened 2026-05-19; same-day .1 patch fixed a UEFI-emit `fncallN` regression — see [`issues/2026-05-19-cycc-6.0.0-uefi-fncall-ud2-emit.md`](issues/2026-05-19-cycc-6.0.0-uefi-fncall-ud2-emit.md)). v5.11.x closed at **5.11.69** on 2026-05-19.
> **Last refresh**: 2026-05-26. **agnos kernel: 1.34.5 RELEASED** · gnoboot 0.4.2. The **1.34.x FAT-family write-completeness continuation** (FS roadmap row 21) is **feature-COMPLETE through 1.34.5**, all RELEASED + `fsck`-clean in QEMU: **1.34.0** FAT12/16/32 read+write · **1.34.1** exFAT read+write · **1.34.2** exFAT write parity · **1.34.3** FAT LFN/truncate completeness · **1.34.4** directory growth (root extension + spanning dir-set append, exFAT + FAT) · **1.34.5** exFAT Unicode names (real up-case table for NameHash + case-fold). Production build **798,648 B**; `test.sh` 4/4. **Only the arc cap remains**: ESP-write safety guard + the user-driven FAT/exFAT iron burn — the first iron touch of the FAT-family arc. Per-cut detail → CHANGELOG `[1.34.0]`–`[1.34.5]` + [`#tracker-1341-cycle`](iron-nuc-zen-log.md#tracker-1341-cycle). **NEXT = user git tag of 1.34.5; then the arc-cap iron burn (user-driven) closes 1.34.x.**
>
> **Closed arcs (history lives in CHANGELOG + iron-log, not here):** storage backends + GPT + ext2/ext4 read, 1.31.x ([`#tracker-133-cycle`](iron-nuc-zen-log.md#tracker-133-cycle) for the FS detail); networking, 1.32.x (see Networking line below); ext2/ext4 WRITE incl. the W5 demo→base iron burn + the 1.33.5 fsync/FLUSH-CACHE barrier, 1.33.x ([`#tracker-1335-cycle`](iron-nuc-zen-log.md#tracker-1335-cycle)).
>
> **Open carry-forward debt:** shell verbs (`touch`/`rm`/`mkdir`/`cat`/`ls`) for FAT/exFAT → **1.39.x VFS generic-write lift** (where two writable FSes finally earn the abstraction); big-write own-cycles **1.37** ext4 extent-alloc / **1.38** jbd2 journaling / **1.39** VFS; kernel-slimming **1.40** console-font→`kashi` / **1.41** shell→agnoshi.
>
> **Networking arc (1.32.x): COMPLETE — iron-verified on archaemenid.** L2 → unicast TCP → DHCP real-lease all proven (the r8169 unicast-RX blocker was RX-ring delivery capacity, fixed 16→64 at 1.32.7; DHCP lease `.142` verified at 1.32.9). i225-V driver stays queued for Intel iron post-migration. Full narrative + iron evidence → [`#tracker-1329-cycle`](iron-nuc-zen-log.md#tracker-1329-cycle) + CHANGELOG `[1.32.x]`.
>
> MVP gate (boot-to-shell on iron) green since Attempt 68 / 1.30.9.
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

CYML format — 5.11.x cluster (no leading-edge holdouts after agnos graduation):
  v5.11.59: agnosticos/scripts (genesis 0.1.0)
            — boot pipeline; pin sweep deferred to next boot-side touch
            — only 5.11.x leading-edge member remaining after agnos
              graduated to 6.0.1 mid-1.31.x cycle
  v5.11.4:  agnosys (1.2.6), sigil (3.1.1), sankoch (2.2.5),
            sandhi (1.3.4), niyama (1.0.2), patra (1.9.4),
            sakshi (2.2.4), vani (0.9.3), yukti (2.2.3)
  v5.11.8:  ai-hwaccel (2.2.2)

CYML format — LEADING-EDGE 6.0.x cluster (post-v5.11.x graduations):
  v6.0.1:  agnos (1.31.7), agnoshi (1.3.3), mihi (1.0.0), iam (1.0.0),
           chakshu (0.6.0), bannermanor (1.0.0), darshana (0.3.5),
           hapi (0.5.0)
           — eight repos on the v6.0.x lane. agnos graduated mid-1.31.x
             cycle for binary fixes in cycc 6.0.1 (was 5.11.64, the
             gvar-init-order anchor). The 2026-05-20 terminal-
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
- **5.11.x cluster (no leading-edge holdouts)**: agnosticos/scripts (5.11.59 — boot pipeline; sweep deferred; genesis-repo VERSION flipped CalVer → SemVer at 0.1.0 cycle-open 2026-05-21). agnos vacated 5.11.64 mid-1.31.x cycle. Back-compat symlinks (`cc5 → cycc`, `cyrc → cybs`) keep this cluster building unchanged through the v6.0.x window.
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
