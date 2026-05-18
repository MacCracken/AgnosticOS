---
name: AGNOS Ecosystem State
description: Live cross-repo state — Cyrius cycle, pin-lag spectrum, active sweeps, carry-forward debt
type: state
---

# AGNOS Ecosystem — Current State

> **Cyrius toolchain**: 5.11.59 | **Cycle**: v5.11.x — stdlib annotation arc + consumer-issue closeout (active; **59 patches landed across 3 days** 2026-05-11/12/13 — 24 + 18 + 17)
> **Last refresh**: 2026-05-17 — **Attempt 59 closed classes 2 + 4; cmd-path triage collapses to two open classes (10a CRCR-latch / 10c doorbell-absorbed); HH + II staged for Attempt 60.** Attempt 59 burned `agnos@83345d2` (Edit B gate reworked from gvar to `xhci_cmd_ring_idx <= 2` after the gvar-init-order theory) — iron FB delivered `xhci: cmd_submit#1 trb_phys=<X> dw3=9217`. **9217 = 0x2401 = (ENABLE_SLOT << 10) | cycle=1**: TRB type + cycle bit both healthy at the moment of write. Class 2 (cycle wrong) and class 4 (trb_phys mismatch) FALSIFIED in one read. The cmd-path search now collapses to: (10a) CRCR write absorbed → cmd ring base never latched, or (10c) doorbell write absorbed by PCI posted-write barrier. Repairs queued in `agnos@2fa4b58`: **Repair (HH)** = post-doorbell `load32` flush at `xhci_cmd.cyr:131` (matches Linux `xhci_ring_cmd_db`'s `writel + readl` — behavioral, direct target for class 10c, sourced from Linux prior art for documented AMD-FCH missed-doorbell symptom); **Repair (II)** = timeout-path CRCR + USBSTS readback stamped to extended-CMOS slots `[0x88..0x8B]` at `xhci_cmd.cyr:228-250` (conditional instrumentation — runs ONLY on timeout return, so if HH unblocks, II never executes). Build verified fresh: `build/agnos` **367,960 B** mtime 22:40:55, all three literals (`xhci: cmd_submit#`, `xhci: CRCR.CRR=`, `xhci: timeout state CRCR_lo=`) present via `strings`. `read-boot-log.cyr` decoder extended to slots 0x88-0x8B with II interpretation matrix. **Iron status**: Phase 3 reset on port 3 still UNBLOCKED (Repair EE intact across Attempts 55-59). No VERSION bump — 1.30.6 banner retained through HH/II cycle. **Attempt 60 awaits user-side USB flash + per-action burn approval.** Pre-bound decision grid: HH success → `evt#1 type=33` (CMD_COMPLETION) + Address Device starts; HH falsification + CRR=1 → class 10a falsified, gate is CCE-routing; HH falsification + CRR=0 → 10c partial / CRCR write itself absorbed (cache attribute on op-reg region — verify op-reg in BAR's UC 2MB mapping). Per-attempt detail in [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md) §§ Attempts 56-60. Per-repair detail in [`agnos/CHANGELOG.md`](https://github.com/MacCracken/agnos/blob/main/CHANGELOG.md) § 1.30.6 + [Unreleased]. **Cyrius toolchain**: 5.11.59 active — v5.11.x cycle theme + per-patch detail in [`cyrius/CHANGELOG.md`](https://github.com/MacCracken/cyrius/blob/main/CHANGELOG.md).
> **Crate registries** (versions + roles): [`planning/shared-crates.md`](planning/shared-crates.md) is the full registry (incl. pre-1.0); [`docs/applications/libs/README.md`](../applications/libs/README.md) is the v1.0+ stable subset. This file holds cycle / pin / sweep state only.

This doc holds **volatile state** — what's currently true across the AGNOS dev surface. CLAUDE.md is preferences/process/procedures; this is the live picture. Per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md): rewrite in place when state changes; don't preserve historical snapshots — git history is authoritative.

**Drift caveat applies to this doc too** — always verify against actual `VERSION` + `cyrius.cyml`/`cyrius.toml` files before acting on any single item. Repo data refreshed 2026-05-11 eve from local clones across ~52 repos; pin-update sweep largely closed (kernel + most kernel-adjacent repos now on 5.10.44 or 5.11.4; agnosticos/scripts boot pipeline rebuilt against 5.10.44 same day). **2026-05-14 spot-update**: agnos pin moved 5.10.44 → **5.11.55**, agnosticos/scripts pin moved → **5.11.55**, agnos version 1.29.1 → **1.30.0** (sovereign boot-info ABI break). **2026-05-17 follow-up**: agnos pin → **5.11.59** alongside Repair (EE) in `agnos@41ee6dc`; agnosticos/scripts pin sweep deferred until next agnosticos-side work surface touches the boot pipeline. Pin-lag spectrum below reflects 2026-05-11 snapshot — agnos has since exited the 5.10.44 bedrock to the 5.11.59 leading edge.

---

## Cyrius cycle — v5.11.x (active)

**Stdlib annotation arc + consumer-issue closeout.** Cycle opened 2026-05-11 with v5.11.0 — kavach P1 sandbox syscall wrappers (`sys_fchmod`, `sys_setresuid/gid`, `sys_prctl`, `sys_seccomp`, `sys_execveat` — async-signal-safe, both x86_64 + aarch64 backends) plus roadmap restructure mapping the v5.11.x arc. The chapter-open lands real code, not bookkeeping (per `feedback_release_needs_code_not_just_docs`).

### v5.11.x cycle theme

v5.10.x left three carry-forward classes that define the v5.11.x scope:

1. **Stdlib annotation arc** (pinned 2026-05-10) — 1,010 unannotated public fns across ~75 % stdlib coverage. 7-phase breakout: foundational core / I/O / strings / collections / big consumers / closeout / compiler internals. Phase 1 (alloc/vec/fmt/freelist/fnptr/result/tagged/assert) lands at **v5.11.1**.
2. **7 consumer-filed issues** (bote / daimon / kavach 2026-05-10 wave): P1 kavach sandbox wrappers ✅ landed v5.11.0; P2×4 daimon aarch64 epoll_wait, bote net recv_timeout + getaddrinfo, bote arena fl_free, bote streaming/async; Low×2 bote ws_server RFC 6455 key validation + parser assert/string-literal quirk.
3. **Held-forward items** — Class B FFI/wgpu fncall6, cyim regex, float.cyr peephole. Surface-on-ask.

Plus infrastructure carry-forward: `cyrius deps` symlink → file-copy (v5.10.37 pin), `tests/regression-*.sh` → cyrius port + Cyriusly cmdtools port (v5.10.36 pin), TS test harness program promotion.

### v5.11.x slot tracking

**Three-day burst: 55 patches v5.11.0 → v5.11.55 across 2026-05-11/12/13** (24 + 18 + 13). Sustained 18–24 patches/day exceeds the v5.10.x rate (50 patches in 5 days = 10/day) by ~2×. Individual slot resolution lags this doc; the headline counters move faster than the table. Refresh from `cyrius/CHANGELOG.md` for per-patch resolution.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | kavach P1 sandbox syscall wrappers | ✅ v5.11.0 | 6 wrappers, both backends, async-signal-safe; closes kavach 3.1.1 raw-syscall workaround |
| 2 | Stdlib annotation arc Phase 1 (alloc/vec/fmt/freelist/fnptr/result/tagged/assert) | 🔄 In-flight across v5.11.1–.24 | Lands cumulatively across the same-day burst — exact phase boundaries in cyrius CHANGELOG |
| 3 | Stdlib annotation arc Phases 2–7 | 🔄 In-flight | At burst rate, multiple phases likely landed in the .1–.24 window |
| 4 | Consumer-filed P2 wave (daimon/bote) | [ ] Queued | Interleave per slot-ordering heuristic |
| 5 | Infrastructure (deps copy fix, regression port, TS test harness) | [ ] Queued | Later in v5.11.x |
| 6 | **argonaut 1.7.0 + kybernet 1.2.1 (BOOT_MINIMAL agnoshi)** | ✅ Cut 2026-05-11 eve | Genesis-repo MVP path: adds agnoshi as a no-deps console service in BOOT_MINIMAL, unblocks boot-to-shell-on-iron without aethersafha. argonaut 1.7.0 = the feature; kybernet 1.2.1 = consumer pin bump. See respective CHANGELOGs. |
| 7 | **Cyrius 5.11.29/.30/.31 — ELF section-header fix arc** | ✅ Cut 2026-05-12 | GRUB `grub_elf32_get_shnum` rejection on first iron-boot attempt traced to `EMITELF_KERNEL`/`EMITELF`/`cyrld` emitting `e_shoff=0`. Three patch releases mirrored a 5-section table (.text/.rodata/.bss/.shstrtab) across x86 kernel emitter (.29), aarch64 kernel emitter (.30), cyrld ELF64 user-binary linker (.31). agnos 1.29.0 re-pinned to 5.11.29; USB refresh via new `install-usb.sh --update` mode. |
| 8 | **Iron-boot bring-up (NUC AMD archaemenid)** | 🔄 Phase 3 unblocked Attempt 55 (Repair EE); Phase 4 Enable Slot root-caused Attempt 56 (Repair FF — IE=0 blocking event posting); Attempt 57 will iron-test FF | Closed-beta gate is boot-to-shell on iron with typeable keyboard. **Silent-absorb arc closed 2026-05-17 Attempt 55** — root cause was `xhci_portsc_write` inner re-mask `& XHCI_PORTSC_NEUTRAL` stripping the RW1S PR bit before `store32`; one-line fix in agnos@41ee6dc removed the re-mask. 13 falsified hypotheses chasing a homegrown bug in our own helper. EDK2 XhciDxe + Linux xhci-hub.c diff surfaced it (neither re-masks). **1.30.4 closeout (cut 2026-05-17)**: H1-H4 xHCI Linux-diff hardening (PAGESIZE assert / IMAN.IP clear / IMOD=250µs / USBCMD.HSEE bit 3) — kernel 350,008 → 350,272 B, no iron burn. **1.30.5 (cut 2026-05-17)**: Phase 4 (`hid_kbd_configure` Get Config Descriptor + interface walk + Configure Endpoint TRB type 12 + SET_PROTOCOL=boot + interrupt-IN transfer ring) + Phase 5 (`hid_poll` event-ring drain + HID→PS/2 translation table + report differ + `kb_buf` writer) — kernel 350,272 → 364,736 B, fmt-clean. **Attempt 54** (1.30.5 iron-clean baseline, silent-absorb persists pre-EE): Row 1 hit. **Attempt 55** (post-EE): `CMOS[0x64]=0x04` port 3 reset-OK (first non-zero in arc); FB shows `kbd: Enable Slot failed, ccode=0` → `xhci: enumeration timeout`. ccode=0 is `xhci_last_cmd_ccode`'s default — no matching Command Completion Event consumed within `XHCI_CMD_TIMEOUT_SPINS`. **Attempt 56 (read-only event-ring instrumentation burn, 2026-05-17)**: FB shows `xhci: enable_slot entry idx=1 cycle=1` + `xhci: cmd completion timeout, final_idx=1 cycle=1 events_seen=0` — controller posts ZERO events to the ring over the full wait. Falsifies triage class 3 (no events to poll). **Root cause: IMAN.IE=0** (xhci.cyr:541 wrote `0x1` — IP clear, IE=0 — with a "poll mode for MVP" comment; AMD FCH 1022:1639 silently drops all events when IE=0 even though spec §5.5.2.1 implies IE only gates interrupt generation). **1.30.6 (cut 2026-05-17, Repair FF)**: `xhci_rt_write32(ir0 + XHCI_IR_IMAN, 0x3)` — IP clear + IE set, matching Linux `xhci-mem.c` convention. Safe under MSI-X function-mask. Awaiting Attempt 57 iron burn. agnos cyrius pin remains 5.11.59. **kriya 0.6.0** shipped 2026-05-17 (M5 closeout: grep + find + xargs; cyrius pin 5.11.59) — three milestones past the Attempt 54 gate version (0.3.0); gate cleared well in advance. |

### v5.10.x retrospective (closed 2026-05-11 at 5.10.50)

**50 patches in 5 days** (2026-05-06 → 2026-05-11). THREE completed arcs plus a compile-perf miniarc:

- **Typed-simd ABI arc — 11 phases** (closeout v5.10.39). `lib/simd.cyr` rewrite: every math op exists in value-form + pointer-form siblings with parser-side `&IDENT → _ptr` overload routing; f64v2 args in XMM0/XMM1 (SysV) / V0/V1 (aarch64), f64v4 in register pairs; PE-gated via `CYRIUS_HAS_VAL_SIMD_PARAMS`. **This is the substrate for Cyrius-native codec work long-term** — typed SIMD primitives + cross-platform ABI-aware register routing is the floor of any handwritten-SIMD codec port (tarang's current dav1d/openh264/libvpx C-FFI layer is the placeholder until that future arc opens).
- **REAL TYPE SYSTEM arc — 5 phases** (Phase 2 v5.10.24, Phase 3 v5.10.25 overload generalize). Per-fn param-type bitmasks, call-site type checking, cstring / Result / Option / Tagged vocabulary on stdlib.
- **Struct-byval ABI arc — 3 phases** (.45 + .46 + .47). Cross-backend struct-byval return surface.
- **Compile-time-perf miniarc** (.40 + .41) — **2.7× total compile speedup**.

Plus one TLS contract pin (.42), one PE premise debunk (.49 — 15-slot phantom pin closed by empirical re-test), 4 open issues closed (str_split, exec_*, parser cosmetics, kernel-reserved-word), and 9+ in-cycle pin re-scopings driven by premise-check discipline.

api-surface 2,769 → 2,876 (+107 public fns). cc5 (x86) 741,048 B → **804,472 B**. check.sh 66 gates stable. cyrius test count 132 → ~146.

### cc5 cut state

cc5 at **809,200 B** at v5.11.24 (+4,728 B across the .0–.24 burst from v5.11.0's 804,472 B baseline). v5.11.0 was a stdlib-only addition (cc5 doesn't include `lib/syscalls_*_linux.cyr`); the .1–.24 burst added compiler-internal annotation surface that DOES land in cc5. Self-host fixpoint clean across the burst. **v5.11.25 → v5.11.55 cc5 delta**: not snapshotted in this doc — pull from `cyrius/cc5` if needed. Patches .29/.30/.31 (ELF section-header fix arc) and .43–.55 (Path A→Path C diagnostic + sovereign UEFI emit support) all landed here.

### v5.12.x reservation — bare-metal + RISC-V rv64

Bare-metal AGNOS target + RISC-V rv64 backend now slot at **v5.12.x**. Slip path: v5.8.x → v5.10.x → v5.11.x → **v5.12.x**. The v5.10.x typed-simd ABI + REAL TYPE SYSTEM + struct-byval ABI together form the substrate prerequisite (call-site checking catches ABI mismatches before they reach a foreign target; typed-simd primitives are needed for SIMD-aware backends); v5.11.x's stdlib annotation arc is the remaining prereq.

### Genuinely dangling — carry-forward into v5.11.x triage

| # | Item | Domain | Notes |
|---|------|--------|-------|
| 1 | `cyrlint` multi-line assert | Tooling | Investigated v5.8.41; couldn't reproduce on 4 synthetic tests. Decide: close as moot, or pin a real reproduction case |
| 2 | `ESTORESTACKPARM` stub | Language | Explicitly **held** ("TODOs in src/: 1, held") — needs unhold-or-resolve decision |
| 3 | Optimization arc O3–O6 audit | Compiler | Partial follow-on shipped (O3a IR / O4a–c regalloc / O5 / O6 codebuf) — needs status sweep against v5.6.x deferral list to identify what's still open |
| 4 | Consumer rollup — pre-CYML format tail | Ecosystem | 11 repos still on `cyrius.toml` at v3.x–v4.x (avatara, ai-hwaccel, hadara, itihas, hoosh, kavach, agnoshi, nein, bote, t-ron, shravan); format migration + pin bump |
| 5 | Consumer rollup — deep-lag tail | Ecosystem | ark (5.1.10), libro (5.4.7), majra (5.4.17), bsp (5.5.2), takumi (5.5.23), yantra (5.6.17) |
| 6 | Consumer rollup — v5.7.48 held cluster (4 repos remaining) | Ecosystem | phylax, mabda, cyrius-doom, samvada — agnosys exited at v5.10.19 |
| 7 | Bare-metal readiness — v5.12.x prereqs | Compiler/runtime | Surface what's needed for clean v5.12.0 bare-metal target open |
| 8 | RISC-V rv64 readiness — v5.12.x prereqs | Compiler/backend | rv64 backend slipped 7+ times; current minimum to land cleanly |

---

## Pin-lag spectrum

Each repo's `cyrius = "X.Y.Z"` pin (verified 2026-05-11 eve from local clones — pin sweep largely closed). **Most pre-CYML consumers migrated**: agnoshi, bote, t-ron, kavach, itihas, nein all moved from `cyrius.toml` v3.x/v4.x to `cyrius.cyml` 5.10.44+. Only `hoosh` and `shravan` remain on pre-CYML format in the local-verified set.

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
           chakshu (5.10.20), darshana (5.10.20),
           cyim-lsp (5.10.20),
           aegis (5.10.34)

CYML format — LIVE 5.10.44 BEDROCK (~15 repos, the boot path minus agnos):
  v5.10.44: agnoshi (1.3.2),
            agnostik (1.2.2), argonaut (1.7.0),
            bote (2.7.2), daimon (1.2.3),
            kavach (3.2.1), kybernet (1.2.1),
            libro (2.6.3) — exited 5.4.x deep-lag,
            majra (2.4.4) — exited 5.4.x deep-lag,
            nein (1.5.1), phylax (1.1.1) — exited 5.7.48 held cluster,
            t-ron (2.1.4)

CYML format — LEADING-EDGE 5.11.x post-burst cluster:
  v5.11.55: agnos (1.30.1), agnosticos/scripts (2026.5.13)
            — both moved to head during the .29/.30/.31 ELF fix arc
              and Path-A→Path-C transition
  v5.11.4:  agnosys (1.2.6), sigil (3.1.1), sankoch (2.2.5),
            sandhi (1.3.4), niyama (1.0.2), patra (1.9.4),
            sakshi (2.2.4), vani (0.9.3), yukti (2.2.3)
  v5.11.8:  ai-hwaccel (2.2.2)

CYRIUS TOOLCHAIN itself: 5.11.55 (after 55-patch 3-day burst 2026-05-11/12/13)

NOT VERIFIED LOCALLY (remote-only, presumed pre-CYML or scaffolded):
  avatara, hadara, itihas, takumi, aethersafha, aethersafta, mela,
  seema, samay, kiran, joshua, salai, murti, tanur, encom-hits,
  cyrius-{bb,brynns-tale,stellar-swarm,sunset-drive,super-plumber-twins,
  grapevine,chellys-beach-adventure,nba-jam}
```

**Bands of attention (2026-05-11 eve + 2026-05-14 spot-update for agnos/scripts):**
- **5.11.55 leading-edge boot-path pair**: agnos (1.30.0) + agnosticos/scripts. These moved off the 5.10.44 bedrock during the .29/.30/.31 ELF fix arc (forced) and the Path-A→Path-C transition (required sovereign UEFI emit support).
- **5.11.x post-burst cluster** (~10 repos at .4/.8) — ahead of the bedrock but trailing the leading-edge pair.
- **5.10.44 live bedrock** (~15 repos: kybernet, argonaut, agnoshi, kavach, daimon, bote, t-ron, libro, etc.) — still where the rest of the closed-beta MVP path runs.
- **Deep-lag tail** shrank but didn't vanish: ark (5.1.10) extreme, hisab/agnova/abaco/nous/bazaar/shakti in v5.7.x cluster, yantra (5.6.17). The 5.4.x cluster (libro, majra) FULLY EXITED at 5.10.44.
- **Held cluster at 5.7.48** now **3 repos** (mabda, cyrius-doom, samvada) — phylax exited during v5.10.x. mabda is at 3.0.0-rc.2 (soak before GA fold to Cyrius stdlib); cyrius-doom is at 0.26.2 (gated on Cyrius optimization-arc closeout retroactive verification).
- **Pre-CYML format tail**: only `hoosh` and `shravan` remain in the local-verified set. The previous 11-repo tail collapsed in the v5.10–v5.11 window.

### New repos / milestone bumps since last refresh

| Repo | Version | Pin | Notes |
|------|---------|-----|-------|
| **aegis** | **1.0.0** | 5.10.34 | **Hit v1.0** (was 0.8.2 in last refresh). Real system-security daemon now shipping. Skipped 0.9.x — straight implementation closeout to 1.0.0. |
| **chakshu** | 0.3.0 | 5.10.20 | AI-augmented system monitor (`shu` binary). Past initial scaffold; +0.0.1 from last refresh's 0.2.0. |
| **cyim-lsp** | 1.5.0 | 5.10.20 | LSP server companion to cyim. Pin moved 5.10.10 → 5.10.20. |
| **darshana** | 0.3.0 | 5.10.20 | TTY/raw-mode primitives library (दर्शन — viewing/showing). Extracted from cyim's `src/tty.cyr` once chakshu became a second consumer. Not a TUI framework — just termios + ANSI + cursor positioning. +0.0.1 from last refresh's 0.2.0. |

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

### gnoboot 0.2 merge + version bump (queued for next gnoboot touch)

Branch `0.2` is one commit ahead of `main` (`d981fae` — "cleanup of canary and clear framebuffer for initial display", 2026-05-15). Structurally clean for merge; staged separately so the iron-boot ground truth (Attempt 29 → shell visible) lands first, then gnoboot rolls forward with the cleanup batched.

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
| 6 | **Boot-to-shell MVP enablement** | ✅ Cut 2026-05-11 eve | argonaut 1.7.0 + kybernet 1.2.1 add agnoshi to BOOT_MINIMAL defaults (no aethersafha dep). Unblocks closed-beta MVP path. Genesis-repo `scripts/install.cyr` provisioner is next active work. |

### CVE-2026-31431 (Copy Fail) cleanup + audit

Linux kernel LPE in `algif_aead` (AF_ALG in-place AEAD + `splice()` → 4-byte page-cache write → root). Disclosed 2026-04-29; affects mainline kernels from 2017 onward. Roadmap item **S1**.

**AGNOS-native kernel** (`agnos` v1.30.0): structurally immune — verified at `kernel/core/syscall.cyr:32-36`, 26-syscall table contains no `socket`, no `splice`, no AF_ALG family. Bug class is unreachable. (Kernel has moved from 1.26.1 → 1.30.0 since the original CVE audit; the 1.30.0 cut is a kernel-ABI break for Path-C handoff, not a syscall-surface change. Syscall table verification is anchored on the syscall-table invariant, not the kernel patch level — re-verify only if the syscall surface grows.)

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
- **Crate registry refresh** — both registries are stale against current state. Sweep when next touched.
  - [`planning/shared-crates.md`](planning/shared-crates.md) (full registry, pre-1.0 + v1.0+): bumped 2026-05-09; **now stale again against 2026-05-11 eve snapshot** — needs another sweep. Notable bumps to apply: agnostik 1.2.0→1.2.2, agnosys 1.2.1→1.2.6, sigil 3.1.0→3.1.1, sankoch 2.0.0→2.2.5, libro 2.0.5→2.6.3, sandhi 1.3.0→1.3.4, niyama 1.0.1→1.0.2, aegis 0.8.2→**1.0.0**, cyim 1.6.7→1.7.0, chakshu 0.2.0→0.3.0, darshana 0.2.0→0.3.0. New: argonaut 1.7.0, kybernet 1.2.1 (today's cuts).
  - [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ stable subset). Last updated 2026-04-15 — predates three full minors (v5.8 / v5.9 / v5.10).

### CLAUDE.md table refresh

Root [`CLAUDE.md`](../../CLAUDE.md) "Standalone Repos" table also drifted (same pattern as shared-crates.md). When refreshing, prefer pointing to this file or to shared-crates.md rather than re-duplicating versions in CLAUDE.md.

---

## Doc / article update queue

| File | Action |
|------|--------|
| [`roadmap.md`](roadmap.md) | v5.7.x / v5.8.x / v5.9.x / v5.10.x phase definitions are now historical; v5.11.x = stdlib annotation arc + consumer-issue closeout (active); v5.12.x = bare-metal + rv64. Re-touch on each v5.11.x ship. |
| [`summer-2026-arc.md`](summer-2026-arc.md) | Cycle-theme references need re-anchoring against v5.10.x three-arc retro + v5.11.x stdlib-annotation framing. |
| [`articles/cyrius-vs-rust-benchmarks.md`](../articles/cyrius-vs-rust-benchmarks.md) | Add v5.9.x / v5.10.x / v5.11.x rows; sweep "Pure compute gap" language for closed items |
| [`articles/port-ledger-volume-1.md`](../articles/port-ledger-volume-1.md) | ✅ Refreshed 2026-05-15 — locked to v5.5.4 baseline; accreted body updates stripped; *What Comes Next* expanded to 5-volume arc (V1 baseline → V2 mid-arc → V3 end-of-5.x/v6.0 → V4 post-v6.x → V5 synthesis). Where-Rust-Still-Wins markers point at Volume 2/3. |
| **NEW** [`articles/port-ledger-volume-2.md`](../articles/port-ledger-volume-2.md) | ✅ Shipped 2026-05-15 — mid-arc state-of-things snapshot. Kernel iron-validation receipt (the V2 headline); pin-cluster review across 5.10/5.11 ecosystem; four new native subsystems (aegis 1.0.0, gnoboot 0.2.0, commandress 0.1.0, kriya 0.2.0); V1's "Where Rust Still Wins" reviewed for direction-of-motion. Re-measurement comprehensive-cut deferred to V3. |
| [`articles/doom-in-cyrius.md`](../articles/doom-in-cyrius.md) | v5.11.x rebuild numbers when cyrius-doom ships an unblock release (still on pin 5.7.48) |
| [`articles/sovereign-compiler-vs-brute-force.md`](../articles/sovereign-compiler-vs-brute-force.md) | cc5 size at **809,200 B** at v5.11.24 baseline (was 741,048 B at v5.9.0; +68 KB across v5.10.x three-arc cycle + v5.11.x .0–.24 annotation burst). **v5.11.25 → v5.11.55 delta not snapshotted** — pull current size from `cyrius/cc5` before publishing. |
| [`planning/shared-crates.md`](planning/shared-crates.md) | 🔄 Stale again as of 2026-05-11 eve. Refresh queue: agnostik 1.2.2, agnosys 1.2.6, sigil 3.1.1, sankoch 2.2.5, libro 2.6.3, sandhi 1.3.4, niyama 1.0.2, aegis **1.0.0**, cyim 1.7.0, chakshu 0.3.0, darshana 0.3.0. New: argonaut 1.7.0, kybernet 1.2.1. |
| [`docs/applications/libs/README.md`](../applications/libs/README.md) | Bump versions for v1.0+ subset; "Last Updated 2026-04-15" predates three minors |
| [`planning/first-party-documentation.md`](planning/first-party-documentation.md) | Re-read at each v5.10.x patch — meta-irony from *Docs Go Stale Before the Commit* |
| [`planning/first-party-standards.md`](planning/first-party-standards.md) | ✅ Refreshed 2026-05-09 — full Cyrius-first rewrite; Rust-era archive at `docs/archive/first-party-standards-rust-era.md` |
| **NEW** ✅ [*What Justifies a Stdlib Foldin*](../articles/what-justifies-a-stdlib-foldin.md) | Shipped 2026-05-06 — meta-process article covering the gate framework, anti-criteria, mechanism, and three-instance pattern across sandhi/vani/niyama. Subsumes per-instance article slots. |
| **NEW** ✅ Phase-3-stdlib-foldin retrospective | Landed 2026-05-06 in vidya at `content/cyrius/field_notes/compiler/retros/foldin_arc_v57_v59.cyml`. Companion to *what-justifies-a-stdlib-foldin* (process) — the retro is the experiential ledger. |
| **NEW** [*v5.10.x: three arcs in five days*] (working title) | v5.10.x retro candidate — reframe past *REAL TYPE SYSTEM in 24 patches* working title. Cycle closed 2026-05-11 at .50 with three completed arcs (typed-simd ABI 11 phases, REAL TYPE SYSTEM 5 phases, struct-byval ABI 3 phases) + 2.7× compile-perf miniarc + PE premise debunk. Draftable now. |
| **NEW** [*Typed SIMD: the substrate for native codec ports*] (working title) | Companion to *port-ledger* — the typed-simd ABI arc (v5.10.28 → v5.10.39) is the foundation that turns tarang's "framework-only, codecs via C FFI" placeholder into an eventual handwritten-SIMD-codec lane (dav1d/FFmpeg territory). Frame as the *prerequisite landed; codec arc is future-arc work post-bare-metal*. Tarang competition framing piece. |
| **NEW** ✅ darshana extraction note | When darshana ships 1.0.0, document the cyim-private → shared-library extraction pattern (single-consumer-private → second-consumer-triggers-extraction) alongside other extraction examples. |
| **NEW** [*Why AGNOS-native agents can't be drained by a tweet*] (working title) | Black Hat / summer-2026-arc Beat 2 article — AGNOS agent-injection defense as second instance of the absence-by-design structural-immunity pattern (kernel CVE-2026-31431 was the first). Spec: [`planning/agent-injection-defense.md`](planning/agent-injection-defense.md). Roadmap: Phase 15A. Draft after Phase 1 ships (post-closed-beta). |

---

## Refresh procedure

When a v5.11.x patch closes:

1. Pull current `VERSION` + `cyrius.cyml`/`cyrius.toml` for affected repos
2. Update the pin-lag spectrum if any repo crossed a band
3. Tick off swept items
4. Re-anchor "Last refresh" date in the header
5. Re-anchor "Cyrius toolchain" if a new minor cut

When v5.11.x cycle closes:

1. Move v5.11.x slot list closeout summary into a brief retrospective (one paragraph)
2. Repoint all `5.10.x` / `5.11.x` references to whichever cycle is next (likely v5.12.x — bare-metal + rv64)
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
