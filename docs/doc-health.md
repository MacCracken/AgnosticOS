---
name: AGNOS Documentation Health
description: Living state of doc currency in the agnosticos repo — fresh / stale / archived / open-question, refreshed as docs are touched
type: state
---

# Documentation Health — agnosticos

> **Last refresh**: 2026-06-04 (post-agnos-1.41.x-arc kernel-fact refresh — the shell-separation arc went **1.41.0 → 1.41.11 software-complete** since the 2026-05-31 sweep had set the docs at 1.41.0). Ground-truth dossier (agnos **1.41.11** / cyrius pin **6.0.56** / cyrius latest 6.0.61 / gnoboot **0.5.0** / build 1,070,720 B / `shell.cyr` 813 LOC / syscall surface 0–33) mined + adversarially fact-checked, then a parallel per-doc refresh+verify pass (two multi-agent workflows; same QEMU-vs-iron honesty bar as the vidya kernel field-notes work). **Touchpoints**: `README.md` (badges 1.41.0→**1.41.11** + 6.0.14→**6.0.56**; capability paragraph adds shell-separation **software-complete / QEMU-validated / iron-pending** with the explicit "not yet booted on real hardware" honesty bar — `#tracker-141x-cycle`), `AGNOS.md` (1.41.x completion + `agnsh` as the userland interactive shell + gnoboot 0.5.0), `architecture.md` (Layer-5: interactive shell → userland `agnsh`, in-kernel shell = recovery REPL ~813 LOC; gnoboot "recently shipped v0.2.0" → milestone phrasing), `history.md` + `timeline.md` (1.41.x shell-separation milestone rows; **also fixed a pre-existing days-from-start off-by-one** 107/108→108/109; dropped a stale "248KB … current" tag → trajectory + state.md pointer), `roadmap.md` (1.41.x slot active→software-complete/iron-pending), `installation/system-requirements.md` (kernel → 1.41.11; `.cyrius-toolchain`→`cyrius.cyml` path fix), **`SECURITY.md`** (**stripped the stale "26 syscalls / agnos v1.26.1 / 248KB" hardcode** the 2026-05-31 count-reframe had missed → the durable "no socket/splice/AF_ALG surface" anchor + state.md pointer, noting the table grew 26→34). **`development/state.md` heavily refreshed** (the anchor): header advanced 1.40.14-OPEN/1.41.0-OPEN → **1.41.11 software-complete + iron-pending**; the ~3,000-word 1.40.x forensic-triage line **COLLAPSED to a one-liner** (it had drifted into a LOG, violating the file's own *NOT A LOG* rule — full detail already in CHANGELOG + iron-log); jbd2 + 1.39.x verbose bite-ladders condensed to one-liners; gnoboot 0.4.3→0.5.0; **pin-lag spectrum re-surveyed** — the 1.41.x arc (`CYRIUS_TARGET_AGNOS` at cyrius 6.0.55/56) pulled the boot-path core off the uniform 6.0.14 pin into a **6.0.14→6.0.61 spread** (agnos/agnoshi/kybernet/argonaut 6.0.56, agnosys/libro 6.0.52/53, agnostik 6.0.26, mabda 6.0.43, sigil 6.0.61, only **hisab** still 6.0.14); toolchain 6.0.24→6.0.61; the **fossil agnos table row (was 1.32.1!)** + the agnoshi row updated to current. **`CLAUDE.md` verified current** — no edit (already defers to `cyrius/VERSION` + state.md, and correctly states there's no `.cyrius-toolchain` file). **Left alone** (correctly dated/historical): all `articles/`, `prior-art/`, iron-logs, `archive/`; the broader pin-lag ecosystem rows (.0/.1/.3 — didn't move with the arc, last surveyed 2026-06-01).
>
> **2026-06-01 sweep** (port-ledger **freeze pass** — user-driven). Volumes 1 & 2 sealed as immutable snapshots: each gets a top-of-file `STATUS — FROZEN` banner (Vol 1 locked to Cyrius v5.5.4 / Apr 2026; Vol 2 mid-arc, captured 2026-05-15). Fixed Vol 1's structural drift — it was authored under the original **3-volume** plan (Vol 2 = the re-measurement) but the series grew to **5** (Vol 2 = mid-arc, **Vol 3 = re-measurement**), so every "Re-measurement is Volume 2 scope" / "Volume 2 measures what happened after the arc" / "Volume 2 is where the gaps close" pointer was corrected to **Volume 3**, and the never-cut `v5.12.x` bare-metal/RISC-V reservation re-pointed to the **v6.x** arc (v5.x closed at v5.11.69). **Receipt tables untouched** — the frozen measurements are the whole point. The post-arc re-measurement is now **Volume 3** — **seeded this pass** (`articles/port-ledger-volume-3.md`, OPEN/accreting): the first two ports back on the 6.0.x workflow get real receipts — `abaco` (the 3-point trend from its own `benchmarks.md`: primality wins −94/−96/−92% landed at 4.8.5 and HELD across 5.7.23→6.0.1, +~2× on `is_prime_small` at 6.0.1, no regression) and `hisab` (its v2.2.0 Rust-vs-Cyrius head-to-head + a flagged *re-bench-pending* on the grown x64-batch surface; CSV is noisy regression-trail, not citable absolute speed). The remaining ten-port wave is listed as pending with per-port gates. No fabricated numbers. Articles otherwise stay dated artifacts (a 2026-06-01 staleness fan-out flagged ~8 `cc5→cycc` / `v5.10.x→v6.0.x` footer-drift items as low-priority opportunistic — not swept in this pass). **Also this date** (separate, ISO-pivot-back): refreshed `development/state.md` § *Pin-lag spectrum* from a live 2026-06-01 survey (deep-lag tail collapsed onto 6.0.x; toolchain 6.0.24; only ark/yantra/agnova/samvada + pre-CYML hoosh/shravan remain behind), and **rebaselined `development/iso-stage4-plan.md`** to the post-iron gnoboot + agnos + ext4 model (the 2026-04-27 GRUB/`vmlinuz`/`pivot_root`/squashfs draft was obsolete; D1/D2/D4 resolved by the iron-boot arc, new live decisions N1–N3, initramfs found vestigial — gnoboot passes `initramfs_phys=0`); roadmap top-matter pointer synced. The plan's stale 26-component inputs table was then replaced with a tiered **base-OS manifest** (user decision: ship the **T0–T3 "base stage" profile** — minimal + CLI + ark/nous + security; **T4 AI layer deferred** to a fast-follow), plus the static-linking correction (sovereign binaries link libraries IN, so libs are build-time deps, not rootfs files — the old table wrongly listed them as ISO artifacts).
>
> **2026-05-31 sweep** (post-agnos-1.41.0 kernel-fact sweep + `prior-art/` consolidation; user-driven). **Three changes.** (1) **Kernel-fact refresh** — the 1.38.8-era facts the 2026-05-28 sweep set had drifted through 1.39 (VFS lift) / 1.40 (exec-from-disk, **iron-validated**) / 1.41.0 (shell-sep open). Touchpoints: `README.md` (badges 1.38.8→1.41.0 + 6.0.9→6.0.14; capability line adds exec-from-disk iron-validated + shell-sep), `AGNOS.md` (was stuck at **v1.31.4** in its body — stripped the repeated `~510KB at v1.31.4` to state.md pointers per lib-doc precedent, reframed the syscall count, added 1.37–1.41 iron-validations + FAT16→FAT/exFAT + exec-from-disk; footer 05-21→05-31), `architecture.md` (Layer-3 "what's not in the kernel" table: added the exec-from-disk **✅ Shipped** row, marked JBD2 + FAT-family **iron-validated**, dropped the now-shipped JBD2-CSUM "not yet" line; shell verb list +`run`; footer→05-31), `history.md` + `timeline.md` (new milestone rows 107/108 + 108/109 — the 13810 jbd2 + 1409/14013 exec iron PASSes; footers→05-31), `installation/system-requirements.md`. (2) **"26-syscall" anchor reframed** (user call) — the security-immunity narrative no longer hardcodes a count that drifts (26→28→33+); it now anchors on the durable basis "**no socket/splice/AF_ALG surface**" + a state.md pointer, across `security-guide.md`, `cross-platform-compat-subsystem.md` (×6 incl. 2 ASCII), `foundation-structure.md`, `conscious-objects.md`, `os/README.md`, `installation/README.md`, `philosophy.md`, `state.md`, `roadmap.md`, README, AGNOS, architecture. **Articles + archive left as dated snapshots** (their "26" was true when written — they go *dated*, not stale). (3) **`prior-art/` consolidation** (user call) — see Structural changes below. **Known cosmetic residual** (low-stakes, not chased): the big architecture.md ASCII block still labels "FAT16" / "18-cmd sh" inside the diagram (prose is correct). **Earlier 2026-05-28 sweep** (full-tree, after the agnos 1.36/1.37/1.38 surge; user-driven post-arc doc sweep, expanded from the morning's mini-sweep). **Touchpoints**: `README.md` (kernel badge 1.34.6→1.38.8, Cyrius badge 6.0.1→6.0.9, capability paragraph adds ext4 extent allocation + JBD2 crash-safe journaling + DNS/NTP/ICMP + kashi 1.0.0 vendoring), `CLAUDE.md` (added kashi row to Standalone Repos table — was missing despite kashi being in active use), `AGNOS.md` (stripped stale `~510KB` + `1.31.4` kernel size from the marketing paragraph + the Sovereignty Replacement Table — replaced with state.md pointers per lib-doc precedent; capability table refreshed with extent allocation + JBD2 + DNS/NTP/ICMP + kashi vendoring + Attempt 1373 iron PASS), `architecture.md` (Layer 3 storage rewritten with ext4 read+write+extent-alloc+JBD2 + FAT-family read+write + ESP-write guard + 6 new prior-art audit cross-refs; Layer 4 expanded with r8169 + DHCP + DNS + ICMP + NTP + RTC + hardening; Layer 5 shell verb count 22→34; Size table footnote refreshed; What's-not-yet-in-the-kernel table converted from "deferred" rows to "✅ Shipped" rows for the 1.33/1.37/1.38 ext-arcs + 1.34 FAT-family + 1.32 networking), `design-patterns.md` (3 new pattern stubs in "Patterns Yet to Add": per-bite smoke discipline §2+§8, kashi-style parallel-agent extraction §0 work-allocation, dedicated refactor cycle before heavy-arc cycles §2 inter-cycle; appended JBD2-9-bites-in-a-day to existing bite-decomposition-cadence stub), `timeline.md` (new "Iron-Boot + Arc-Series Surge May 13 – May 28" table with 10 milestone rows + "Pace" footer extended with weeks 6 + arc-series surge + language version sequence to 6.0.x; last-updated 2026-05-09 → 2026-05-28), `history.md` (8 new milestone rows: MVP gate / Cyrius v6.0.0 ceremony / kashi extraction / 1.31.x storage close / 1.32.x networking close + iron-CONNECTED / 1.33.1 W5 demo→base burn / 1.34/35/36 arc completes / 1.37+1.38+kashi-1.0 same-day; compiler-naming table updated with `cycc` row and permanent-names note; last-updated 2026-05-15 → 2026-05-28), this ledger. The JBD2 arc's prior-art + iron-burn audits (`ext4-jbd2-prior-art.md` + `ext4-jbd2-iron-burn-audit.md` — new files, landed dated in-cycle, not edited in this sweep). **Left alone** (correctly historical / current via pointer): `state.md` (kept current per-cut), `roadmap.md` (forward-facing structure stable from 2026-05-26), `philosophy.md` / `thesis.md` / `installation/*` (versions already pointer-deferred), all `articles/` + `*-prior-art.md` + dated iron-burn audits (dated engineering artifacts — don't re-touch).
>
> **2026-05-26 sweep** (after agnos 1.33.x ext2/4-WRITE + 1.34.x FAT-family arcs landed). **Touchpoints**: `README.md` (kernel badge 1.32.7→1.34.6, capability line + subsystem count 35+→40+ + storage/networking/read-write-FS framing), `docs/development/roadmap.md` (**forward-facing restructure** per user directive — stripped the stale top-matter quote-block, the completed "Status" section (Cyrius milestone table + ports dependency chain + monolith + KPIs), and the completed 1.30.x-keyboard / 1.31.x-storage / 1.32.x-networking cycle-tracking; kept the maturity arc, vision, beta path, forward phases 13B-24, ecosystem; dropped the drift-prone Version column from the Named Subsystems table; 742→544 lines).
>
> **Earlier 2026-05-25 pass** (version-currency + cruft sweep — second 2026-05-25 pass). Stale `cc5`→`cycc` (the v6.0.0 rename), `v5.12.x`→`v6.0.x` (never-opened slot, folded into the active cycle), and old kernel sizes (`~365KB`/`v1.30.5`, `~571KB`/`v1.31.7`) stripped to state.md pointers per the lib-doc precedent (don't chase volatile values to a new number that re-drifts). **Touchpoints**: `README.md` (kernel badge 1.32.5→1.32.7), `docs/thesis.md` (×4, incl. Cyrius v5.11.55→6.0.1), `docs/architecture.md`, `docs/philosophy.md`, `docs/installation/{README,system-requirements,troubleshooting}.md`, `docs/development/iso-pipeline.md` (×8), `docs/development/summer-2026-arc.md`. Dead-link fossils flagged in place with pre-extraction banners (not path-chasing): `guides/kernel-guide.md`, `infrastructure/performance-benchmarks.md`, `vision/architecture/k8s-roadmap.md`. **Left alone** (correctly historical/meta): all `articles/` (dated artifacts — go *dated*, not stale), `sprint-history.md`, roadmap.md frozen top-matter, `iron-nuc-zen-log-mvp.md`, `adr-008`, and `state.md`'s own rename-surface docs. **Deferred** (live-ish, lower-traffic): `summer-2026-arc.md` retro framing, `first-party/example_claude.md:61` template `cc5`.
>
> Earlier 2026-05-25 pass (root-version staleness): README kernel badge 1.31.4→1.32.5, README:102 self-hosting cell reframed to public-beta scope, roadmap.md ~7 `v5.12.x`→`v6.0.x` refs.
>
> **Older sweeps (2026-05-06 → 2026-05-22, Stages 1–20) are recorded in the dated "Stages complete" list below** — not re-narrated here, per this file's own rule (*"record the result of an audit pass, not per-doc reasoning"*). The prior nested per-sweep header narratives were collapsed into this pointer on 2026-05-25 to stop the header itself from accreting.
>
> **Scope**: This repo only (`agnosticos`) — the entire `docs/` tree plus root-level files (README, CHANGELOG, CLAUDE.md, etc.). Per-subsystem docs live in their own repos and are not audited here. State of cross-repo Cyrius pin/version drift lives in [`development/state.md`](development/state.md), not here.
>
> **Relocated 2026-05-09**: previously at `docs/development/doc-health.md`. Moved to `docs/doc-health.md` so the location reflects the actual scope (the whole genesis-repo doc tree, not just `docs/development/`).

This is a **ledger**, not a one-time audit. Rewrite-in-place as docs change. Per [*Docs Go Stale Before the Commit*](articles/docs-go-stale-before-the-commit.md) and [*Your Docs Are About to Rot*](articles/your-docs-are-about-to-rot.md), a doc-set this size needs an explicit health surface or it rots silently.

---

## At a glance — 2026-05-09 inventory

**~265 markdown files** across the repo (count post-re-org: −2 from `docs/architecture/kernel-layers.md` + `docs/os/README.md` deletions). Bucket counts (after 2026-05-06 audit pass — Stages 1–15):

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh / refreshed in this audit** | ~165 | Includes 2026-05-06 audit (~135 items) + 2026-05-09 sweep (+~30 items: doc-health relocation, 3 re-org actions, README/AGNOS/CHANGELOG version refresh, state.md cycle refresh, first-party-standards Cyrius-first rewrite, shared-crates 12-version bump + 2 new repos, libs/README.md, history/timeline cycle extension, SECURITY.md CVE callout, sprint-history Cyrius-era summaries, iso-pipeline blockers, summer-2026-arc cycle re-cast, 4 articles cycle-bump, planning/{joshua,murti,pdf-suite,hadara,tanur,roadmap,README,shared-crates,first-party-{standards,documentation},example_claude}). |
| 🟡 **Stale — refresh in place** | 0 | Cleared. |
| 🟠 **Read-through outstanding** | ~25 | Light skim remaining on guides/* (fossil-noticed), infrastructure/* (fossil-noticed), dev/os/* (Stage 8 batch), creative/, vision/* (long-range planning), .github templates. None known to be wrong. |
| ⏸️ **Deferred** | 2 | `planning/agnostic-integration.md` + `planning/bullshift-split.md` — both deferred per user direction until desktop is shipping. |
| 🔵 **Probably evergreen** | ~25 | Philosophy, thesis, code-of-conduct, .github templates — re-read pass annually, not weekly. |
| 📦 **Archive — frozen by design** | ~36 | `docs/archive/`. Verified — nothing misclassified. |
| ❓ **Open strategic question** | 0 | All 4 strategic questions (lib doc pattern, app doc inventory, ADR posture, entry-point refresh) resolved in this audit. Q4 (release-vision compass) closed in Stage 5. |

Numbers approximate; rolls up from the per-tier tables below.

**Structural changes (2026-05-31)**:
- ✅ **`docs/development/prior-art/` created** — 39 completed/dead-arc prior-art + iron-burn-audit docs moved out of `docs/development/` (top-level 54 → 15 .md). Move set = closed-arc research/audit for storage (1.31) / networking (1.32) / write+extents+jbd2 (1.33/37/38) / FAT-family (1.34) / comms (1.35) / refactor (1.36) / VFS (1.39) / exec (1.40) + the dead-end `path-a-elf64-multiboot2` + `true-font-swap-plan`. **Kept in `development/`** (active / living-reference / process): `shell-separation-prior-art` (1.41.x open), `uefi-boot-prior-art` + `path-c-sovereign-uefi` (current bring-up reference), `exec-iron-manual-tests`, `iron-bring-up-process`, the iron logs, state/roadmap/sprint/summer/iso. New `prior-art/README.md` indexes the archive by arc. **All cross-refs rewritten + verified zero-broken** across BOTH repos (agnos GitHub URLs `…/docs/development/X` → `…/development/prior-art/X`; agnosticos relative + sibling links incl. the capped `iron-nuc-zen-log-mvp2.md`). The agnos kernel's normative syscall-ABI contract (`agnos-userland-abi.md`) lives in the **agnos** repo, not here (normative kernel spec, co-located with `syscall.cyr`).

**Structural changes (2026-05-09)**:
- ✅ `docs/development/doc-health.md` → `docs/doc-health.md` (relocated; whole-tree scope reflected in location).
- ✅ `docs/architecture/kernel-layers.md` → inlined into `docs/architecture.md` § Kernel Layers (singleton subdir deleted).
- ✅ `docs/os/README.md` → deleted (10-line stub redundant with `docs/architecture.md` § Named Subsystems).
- ✅ `docs/development/applications/` → `docs/development/planning/` (rename — name better reflects pre-v1 forward-looking content; sibling dir collision with `docs/applications/` resolved). 73 files / 108 cross-refs updated.
- ✅ `docs/development/first-party/first-party-documentation.md` — codified the doc-health.md convention (location, header pattern, when to scaffold) so smaller repos can adopt it cleanly.

**Stages complete (2026-05-06)**:
- ✅ Stage 1 — Entry-point doc refresh (README, AGNOS, architecture, installation/README → 🟡 to ✅).
- ✅ Stage 2 — ADR-008 (Cyrius pivot) drafted; ADR-001 marked partially superseded; ADR README index updated.
- ✅ Stage 3 — App README refresh (added Status column, fixed Vidhana drift, corrected Ifran display name).
- ✅ Stage 4 — Lib doc cleanup (deleted version lines from 56 files; registry tables now sole source of truth for versions).
- ✅ Stage 5 — release-vision.md fossil notice updated to point at roadmap.md as the compass (closes the unfulfilled-promise gap).
- ✅ Stage 6 — CLAUDE.md inline kernel sizes removed (was "260KB"; deferred to state.md per its own "no volatile state" principle).
- ✅ Stage 7 — CHANGELOG.md new entry [2026.5.6] covering Cyrius v5.7→5.9 cycle progression, beta rescope, doc audit work.
- ✅ Stage 8 — `docs/development/os/` batch (11 files): bulk-deleted version lines from 9 bulleted-pattern files (aegis, aethersafha, agnova, ark, mela, nous, samay, seema, takumi); refreshed phylax (Rust → Cyrius-native v1.0.0; 5 crates → 5 modules); refreshed zugot (recipe-DB framing, no versioned-crate semantics).
- ✅ Stage 9 — `docs/development/guides/` batch (5 files): 3 had accurate fossil notices (agent-development, kernel-guide, testing); refreshed kernel-guide fossil notice (1.22.0/260KB → state.md pointer); added drift notice to mcp-tools-reference (71 → ~144 tools); added fossil notice to science-crate-specs (Rust-era scaffolding).
- ✅ Stage 10 — `docs/development/infrastructure/` batch (4 files): all 4 had accurate fossil notices; refreshed rpi4-runner-setup fossil notice to reflect Cyrius cross-compilation now partly shipped (v5.5.x multi-platform), RISC-V + bare-metal still queued (v5.10.x).
- ✅ Stage 11 — `docs/development/planning/` batch (~12 planning docs): hadara updated (was "Scaffolded 0.1.0"; now "Released — Cyrius-native v1.0.0" per state.md); applications/roadmap.md drift removed (crate count "76 total / 55 at v1.0+" pulled in favor of shared-crates.md as source). Other planning docs verified — Status: Scaffolded framing on tanur/joshua/murti is accurate; first-party-standards/-documentation are current; bullshift-split, pdf-suite, agnostic-integration are accurate planning artifacts.
- ✅ Stage 12 — `docs/development/vision/` batch (12 files): all correctly labeled Vision/Theoretical/Future-consideration; one factual drift fixed (space-infrastructure.md "AGNOS at 204KB" → "~248KB at v1.26.1" with state.md pointer); release-vision.md fossil pointer was already updated in Stage 5.
- ✅ Stage 13 — history.md, timeline.md, sprint-history.md: history.md and timeline.md got post-Beltane milestone entries (Cyrius v5.5.x multi-platform → v5.6.x optimization arc → v5.7.0 sandhi-fold → kernel 1.26.1 → v5.8.x 66-patch arc → v5.9.0 niyama-fold → beta rescope), footer dates refreshed to 2026-05-06; sprint-history.md fine as-is (already pairs with CHANGELOG per its footer).
- ✅ Stage 14 — `docs/security/` batch (5 files): 4 already had accurate fossil notices; security-guide.md got CVE-2026-31431 structural-immunity note pointing to state.md.
- ✅ Stage 15 — CONTRIBUTING.md (`cc3` → `cc5` reference fix), SECURITY.md verified (mostly evergreen), iso-pipeline.md status note refreshed (Stage 0 implemented + Stage-4-only first cut planned + CHANGELOG 2026.4.27 26/26 components ready).
- ✅ Stage 19 — spring-cleaning batch (8 items):
  - **CLAUDE.md Standalone Repos table** — embedded counts/sizes in Role column ("kybernet | PID 1 binary (486KB, 140 tests, 46 benchmarks)") cleaned to pure role descriptions; added mela/seema/samay rows; added pointer note that the table is intentionally version-free with state.md / shared-crates.md as live source.
  - **Verified clean (no audit needed)**: `Makefile`, `.github/workflows/{ci,release}.yml` — all post-Cyrius-pivot, no Rust references. `scripts/cyrius.cyml` is an active engineering pin (5.8.0); not touched.
  - **Planning docs spot-check**: tanur/joshua/murti still at "Scaffolded (0.1.0)" — accurate, no drift.
  - **first-party-documentation.md** — codified two new conventions: "Since This Was Written" footer pattern (with template) + "Last Updated" header convention (per doc type).
  - **Vidya field-notes link sweep** — 1 stale URL fixed in `docs/AGNOS.md` (was pointing at `field_notes.toml` single-file path; now directory). Other vidya links in articles already had corrective parentheticals.
  - **Forward doc-policy commitments section** added to `doc-health.md` — captures the Rust-era archive purge plan ("after a few tagged GA releases past Beta") so the compressed beta timeline doesn't leave it forgotten.
  - **Memory saved**: `feedback_doc_audit_discipline.md` captures the ledger pattern, lib-doc precedent, "Since This Was Written" footer, tier bucketing, stage-based execution, what-to-leave-alone — so future audit sessions don't re-derive the discipline.

- ✅ Stage 18 — heavy ecosystem-wide sweep (10+ files): refreshed `philosophy.md` (kernel size, Cyrius cycle paragraph, "as of" date), `thesis.md` (kernel + compiler versions, shipped/in-flight ledger including foldin pattern + closed/public beta), `design-patterns.md` (4 instances of "260 KB" → "248 KB"), `AGNOS.md` (repo-structure section, core subsystems table mabda 2.1.2 → 2.4.1 / abaco 2.0.0 → 2.2.x, pending-port table reframed with bhava added and phylax/shakti/hisab moved to "recently shipped", compiler section cc3 → cc5 / 373KB → ~741KB / stdlib reflects three foldins, kernel section 260KB → 248KB, shared-crates count → defer-to-registry pointer), `architecture.md` (diagram), `installation/system-requirements.md` (kernel row), `iso-pipeline.md` (cc3 → cc5 across 4 instances, kernel size in artifact table), `roadmap.md` (4 lines: kernel-shipped header callout, ports-table kernel row, blocker-cleared chain, named-subsystems table agnos row), `installation/troubleshooting.md` (2 cc3 references → cc5 with historical note), `architecture/kernel-layers.md` (kernel-size comparison table). Article body refreshes per user "heavy sweep" directive: `the-2-dollar-sd-card.md` "What We Know" section refreshed (kernel v1.22.0 → v1.26.1 + CVE-2026-31431 immunity note), `memory-should-be-sovereign-too.md` body table refreshed inline (kernel/compiler/sigil/sankoch versions; pointer to state.md added).

- ✅ Stage 17 — article review pass (19 files in `docs/articles/`, ~38K words total):
  - **Batch A — mechanical 248 KB drift fix**: `the-2-dollar-sd-card.md`, `python-in-the-bootstrap.md`, `sovereign-compiler-vs-brute-force.md` — kernel size in "Since This Was Written" footers corrected from 260 KB to 248 KB.
  - **Batch B — light tech refresh**: `why-gpu-belongs-in-the-stdlib.md` got a "Since This Was Written" footer noting the v5.6.x → v5.9.0 progression and the three stdlib fold-ins. `the-price-of-porting-early.md` Cyrius timeline block (Case Study section) refreshed from "v5.7.0 (queued)" tail through to v5.9.0 + v5.10.x reservation. `memory-should-be-sovereign-too.md` got a "Since This Was Written" footer with body-table currency notes (sigil 2.9.1→2.9.4, Cyrius v5.6.17→v5.9.0, sankoch 2.0.1→2.2.4, kernel 1.22.0/260KB→1.26.1/248KB).
  - **Batch C — structural tightening**: `micro-work-and-agent-deferment.md` "How to cite" section reduced from 9-bullet anchor enumeration to a 1-paragraph note pointing at the most-cited section. ~10% length reduction; intent preserved.
  - **Held outlines (deliberately untouched)**: `entity-vs-skynet-doom.md`, `why-gigacenters.md` — explicitly held until trigger events fire.
  - **Working file untouched**: `_outlines.md`.

- ✅ Stage 16 — index/registry refresh + broken-link sweep:
  - `docs/architecture/kernel-layers.md` status line: v1.22.0/260KB → v1.26.1/248KB with state.md pointer.
  - `docs/development/README.md` index refreshed: added state.md, doc-health.md, summer-2026-arc.md, iso-pipeline.md, iso-stage4-plan.md, first-party-documentation.md to active lists; removed "78-crate registry" stale; updated os/ description.
  - `docs/development/os/README.md` restructured: removed Version column from all 11 subsystem tables (defer to state.md/shared-crates.md per lib-doc precedent); refreshed port-status summary (22+ → 30+); phylax noted as Cyrius-native (no longer Rust); sankoch/agnova/zugot/takumi statuses corrected.
  - `docs/applications/libs/LICENSE-FIXES.md` archived to `docs/archive/license-fixes-rust-era.md` with banner explaining all items moot post-Cyrius pivot. archive README index updated.
  - **Broken-link fixes**: SUPPORT.md (referenced non-existent `docs/agent-runtime.md` and `docs/troubleshooting.md`); CONTRIBUTING.md "Documentation Locations" section confused per-repo conventions with genesis-repo paths (rewritten to enumerate genesis tree honestly + pointer to first-party-documentation.md for per-repo conventions); mcp-tools-reference.md (referenced non-existent `docs/api/explorer.html`); joshua.md (stale `userland/agent-runtime/src/` path → current `/home/macro/Repos/daimon/`).

**Open** (very small surface remaining):
- ~10 truly evergreen items (philosophy, thesis, code-of-conduct, .github templates, creative/, articles in dated-artifact bucket) — sample-check, no urgent edits expected.
- CHANGELOG historical entries reference long-dead paths (docs/agent-runtime.md, docs/api/) — leave alone, they're historical.

---

## Tier 1 — Structural docs (root + /docs root)

| File | Last touched | Status | Action |
|---|---|---|---|
| `README.md` | 2026-06-04 | ✅ Fresh | **2026-06-04 (1.41.x kernel-fact sweep)**: badges 1.41.0→**1.41.11** + 6.0.14→**6.0.56**; capability line adds shell-separation (**software-complete / QEMU-validated / iron-pending**, `#tracker-141x-cycle`). **Refreshed 2026-05-26**: kernel badge 1.32.7 → **1.34.6**; lead capability line rewritten (boots to typeable shell + storage/networking/read-write-FS landed, iron-validation status); kernel subsystem count 35+ → **40+** (ASCII diagram + Stack table). Prior 2026-05-18 (lib-doc precedent sweep): Stack-table Version column dropped, badges, Path-C milestone reflow. |
| `CHANGELOG.md` | 2026-05-11 | ✅ Fresh | **New [2026.5.11] entry 2026-05-11** covering v5.10.x cycle close (50 patches, three arcs) + v5.11.x open (stdlib annotation arc + kavach P1 sandbox wrappers at .0); state.md refresh; typed-simd ABI substrate framing; new article slots (v5.10.x three-arc retro + typed SIMD codec-substrate piece); outline #6 added to `_outlines.md`. Earlier `[2026.5.9]` entry retained. |
| `CLAUDE.md` | 2026-05-11 | ✅ Fresh | **Touched 2026-05-11**: Cyrius release line refreshed (was "v5.8.x active — optimization, math, language fixes cycle"; now "v5.11.x active — stdlib annotation arc + consumer-issue closeout" with v5.10.x three-arc retro callout). State-table version cell still intentionally points to state.md per established pattern. |
| `CONTRIBUTING.md` | 2026-05-09 | ✅ Fresh | **Touched 2026-05-09**: doc-health row separated from Developer-docs row to surface the convention; doc-health pointed at new `docs/doc-health.md` location. |
| `SECURITY.md` | 2026-06-04 | ✅ Fresh | **2026-06-04 (1.41.x kernel-fact sweep)**: **stripped the stale "26 syscalls / agnos v1.26.1 / 248KB" hardcode** → the durable "no socket/splice/AF_ALG surface" anchor + state.md pointer. **Refreshed 2026-05-09**: CVE-2026-31431 structural-immunity section added (Notable Hardening callout + 6th defense-in-depth layer + canonical absence-by-design pattern). Last Updated bumped + Next Review pushed to 2026-08-09. |
| `SUPPORT.md` | 2026-03-11 | 🔵 Evergreen | Operational pointers. Re-check links. |
| `CODE_OF_CONDUCT.md` | (unverified) | 🔵 Evergreen | Standard. |
| `docs/AGNOS.md` | 2026-06-04 | ✅ Fresh | **2026-06-04 (1.41.x kernel-fact sweep)**: 1.41.x shell-separation completion + `agnsh` as the userland interactive shell + gnoboot 0.5.0. Refreshed 2026-05-06: lead paragraph (cc5, 248KB), header table (kernel/compiler versions, status), dependency comparison rows, history table (added 5 milestones since Beltane through 2026-05-06), bootstrap chain, core subsystems table, kernel size discussion ("248KB is the honest size at v1.26.1"), statistics block (rounded values + pointer to state.md), Last Updated. |
| `docs/architecture.md` | 2026-06-04 | ✅ Fresh | **2026-06-04 (1.41.x kernel-fact sweep)**: Layer-5: interactive shell → userland `agnsh` (in-kernel shell = recovery REPL ~813 LOC); gnoboot version → ship-milestone phrasing. **Refreshed 2026-05-18 (doc-staleness audit S4 — lib-doc precedent sweep)**: header bumped to 2026-05-18 / 2026.5.18; ASCII kernel-block dropped version+size cells; Named Subsystems section heading-versions stripped (`### ark — Unified Package Manager (v0.8.0, Cyrius)` → `### ark — Unified Package Manager`); Technology Stack table Kernel + Compiler rows defer to state.md for version + size; Pending Cyrius Ports table version column removed; Boot Flow updated for Path-C / gnoboot; Design Decisions section version cells stripped; aegis status bumped (scaffold → Cyrius-native 1.0+, May 2026). Previous refresh 2026-05-09: kernel-layers content inlined; 2026-05-06: initial. |
| `docs/design-patterns.md` | 2026-05-09 | ✅ Fresh | All flagged patterns already present from Stage 19 (sibling-distfile fold covers sandhi/vani/niyama; Om-cyclone covers starship-prompt convention). Absence-by-design pattern from CVE-2026-31431 still gated on host-defconfig pinning per state.md. Date bump only. |
| `docs/philosophy.md` | 2026-04-22 | 🔵 Evergreen | Ideology, not status. Re-read pass annually. |
| `docs/thesis.md` | 2026-04-22 | 🔵 Evergreen | Same. |
| `docs/history.md` | 2026-06-04 | ✅ Fresh | **2026-06-04 (1.41.x kernel-fact sweep)**: 1.41.x shell-separation milestone + fixed a pre-existing days-from-start off-by-one + dropped a stale "248KB … current" tag. **Refreshed 2026-05-09**: Key Milestones table extended with v5.9.x close (44 patches) + v5.10.x REAL TYPE SYSTEM arc opener; Development Pace paragraph updated; "~76 crates" drift replaced with 80+ pointer to registry. |
| `docs/timeline.md` | 2026-06-04 | ✅ Fresh | **2026-06-04 (1.41.x kernel-fact sweep)**: 1.41.x shell-separation timeline row. **Refreshed 2026-05-09**: Stdlib Foldin Cycle table extended through 2026-05-09 (v5.9.x close, v5.10.x REAL TYPE SYSTEM arc, v5.11/v5.12 reservation slip, doc tree re-org); Pace section adds week-5 Cyrius era entry. |
| ~~`docs/os/README.md`~~ | — | 🗑️ Deleted | **2026-05-09**: deleted (10-line stub redundant with `docs/architecture.md` § Named Subsystems). The one inbound link from `docs/development/os/README.md` repointed at the architecture-section anchor. Subdir removed. |

---

## Tier 2 — Operational docs (`docs/development/`)

> **Important framing (per user 2026-05-06)**: Files under `docs/development/planning/` are **pre-v1 / forward-looking planning docs** — apps that may ship later, not vapor or candidates for archival. Treat 🟠 read-through here as "verify the planning is still the intent," not "candidate to delete." Subjects in `docs/applications/` (no `development/`) are the consumer-facing app surface; that's where shipped vs. scaffolded distinctions matter.

| File | Last touched | Status | Action |
|---|---|---|---|
| `roadmap.md` | 2026-06-04 | ✅ Fresh | **2026-06-04 (1.41.x kernel-fact sweep)**: 1.41.x slot → software-complete / iron-pending. **Forward-facing restructure 2026-05-26** (per user directive): stripped the stale top-matter quote-block (~35 lines of frozen pre-MVP/v5.11.0 per-cycle quotes), the completed "Status" section (Cyrius milestone table + ports dependency chain + monolith-complete + KPIs), and the completed 1.30.x-keyboard / 1.31.x-storage / 1.32.x-networking cycle-tracking → all moved to CHANGELOG/state.md. Kept: maturity arc (demo→base transition updated), strategic vision, beta path, active 1.35.x, forward phases 13B-24, ecosystem. Dropped the drift-prone Version column from the Named Subsystems table (defer to state.md/shared-crates.md). 742 → 544 lines. |
| `state.md` | 2026-06-04 | ✅ Fresh | **2026-06-04 (1.41.x kernel-fact sweep)**: header → **1.41.11** (software-complete / iron-pending); the ~3,000-word 1.40.x triage line **collapsed to a one-liner** (NOT-A-LOG hygiene); pin-lag spectrum re-surveyed (boot-path core 6.0.14→6.0.61); fossil 1.32.1 agnos row + agnoshi row fixed. **Refreshed 2026-05-18 (FF→QQ arc + audit-result framing)**: header rewritten three times across the day (NN+OO bundle falsification → vendor-cap dry well → MSI-X audit divergence found → QQ candidate staged). Cycle slot 8 updated for Attempts 56-62 cmd-path arc; QQ + QQ'' MSI-X table programming staged but not yet burned; PP heavy-hammer DMA UC remap as bottoming-out path. Cyrius 5.11.59 active. Previous refresh 2026-05-17: agnos 1.30.4 H1-H4 + 1.30.5 Phase 4/5 + Attempt 54 prep. |
| `summer-2026-arc.md` | 2026-05-09 | ✅ Fresh | **Refreshed 2026-05-09**: TLS-arc framing retired (TLS shipped via sandhi-fold v5.7.0); B10 superseded; Critical-path graph updated to v5.10.x → v5.11.x → v5.12.x; Alignment table re-cast for current cycle reality; biggest-risk and derail sections updated; May 1 Beltane target replaced with closed-beta-cut framing. |
| `sprint-history.md` | 2026-05-09 | ✅ Fresh | **Refreshed 2026-05-09**: Cyrius Era cycle summaries appended (v1.0 → v5.0 + ecosystem boot; v5.5.x multi-platform; v5.6.x optimization arc; v5.7.x sandhi-fold + 51 patches; v5.8.x 66-in-4-days; v5.9.x catchup + niyama; v5.10.x REAL TYPE SYSTEM arc in flight). |
| `monolith-extraction.md` | 2026-04-17 | 🗄 Archived | **Moved to `docs/archive/` on 2026-05-12** — historical milestone, extraction completed 2026-04-01. Live work tracked in `state.md` + `iron-nuc-zen-log-mvp.md` (the iron log was renamed to `-mvp.md` at MVP gate; `iron-nuc-zen-log.md` is now the active post-MVP log). |
| `iso-pipeline.md` | 2026-05-09 | ✅ Fresh | Refreshed 2026-05-09: cc5 size + version bump (v5.9.0/741KB → v5.10.24/783KB), blockers table updated (phylax/shakti/sankoch shipped; aegis graduated; multi-platform codegen shipped at v5.5.x), bare-metal reservation slipped to v5.12.x, May 1 boot target superseded by two-stage beta rescope. |
| `iso-stage4-plan.md` | 2026-04-28 | 🔴 In-flight | D1–D4 decisions pending user input per roadmap callout. **Not stale — blocked.** |
| `iron-bring-up-process.md` | 2026-05-15 | ✅ Fresh | **NEW 2026-05-15** — generic process example for bringing AGNOS up on a new hardware target. Distilled from the NUC AMD Zen arc (Attempts 1–29) post-cycle-close. Patterns: diagnostic-channel ladder, repair-letter convention, premise-audit gate, MVP-to-X gap re-audit, walls common to UEFI x86_64 targets, Cyrius-side gotchas. Companion to `iron-nuc-zen-log-mvp.md` (the canonical example arc). Read alongside `uefi-boot-prior-art.md`. |
| `iron-nuc-zen-log-mvp.md` | 2026-05-19 (cap) | 🗄 Capped | NUC AMD (Beelink SER / archaemenid) target — MVP-era log, **Attempts 1–68, ~7,375 lines**. Frozen historical record from project start through closed-beta MVP gate (Attempt 68 / agnos 1.30.9 / typeable shell on iron, 2026-05-18). Successor: `iron-nuc-zen-log.md`. Capped 2026-05-19. Photo dir: `iron-nuc-zen-photos/` (cataloged at `iron-nuc-zen-photos/README.md`). |
| `iron-nuc-zen-log.md` | 2026-05-19 (open) | 🆕 Active | Post-MVP iron bring-up log. Picks up where `-mvp.md` left off. First attempt (#69) lands when a 1.30.10 framebuffer-refresh burn is proposed. Open carry-forward from MVP era: fb refresh quality (1.30.10), VGA-vs-HDMI handoff (1.30.11 hardening), glyph-to-font extraction (post-1.30.11), aarch64 boot test (Pi SSH blocked), cyrius user-binary ELF cleanup. |
| `path-c-sovereign-uefi.md` | 2026-05-15 | ✅ Fresh | Path C design doc — the AGNOS sovereign UEFI handoff (gnoboot PE32+ → kernel via 80-byte boot-info struct in RDI). Current production path. Updated 2026-05-13 with Diagnosis 2 closure (Path A→C pivot rationale). Read first when starting any UEFI x86_64 bring-up. |
| `path-a-elf64-multiboot2.md` | 2026-05-13 | 🗄 Archived in place | Path A (GRUB MB2-EFI + ELF64 + EFI64 entry tag). **Dead-end approach** — strict-W^X UEFI faults inside `grub_relocator64_efi_boot`. Retained as prior art: explains why Path C exists. Header carries "DO NOT use to start a new bring-up" notice. |
| `uefi-boot-prior-art.md` | 2026-05-14 | ✅ Fresh | Industry comparison: Linux EFI stub, FreeBSD `loader.efi`, OpenBSD `BOOTX64.EFI`, Windows `winload.efi`, Limine. AGNOS converged on the same architectural shape via Path C. Read first when starting any UEFI x86_64 bring-up. |
| `xhci-prior-art-audit.md` | 2026-05-18 | ✅ Fresh | **NEW 2026-05-18** — convergent-prior-art audit doc for the xHCI cmd-path silent-absorb arc on AMD FCH 1022:1639 (archaemenid). Four-source diff (Linux v6.13 + FreeBSD HEAD + Haiku master + EDK2 master) of register-write ordering between reset-complete and R/S=1. Surfaced two convergent divergences (ERDP-before-ERSTBA per 3-of-4; CRCR-after-IMOD per 2-of-4) staged as Repair (NN) for Attempt 62 (falsified). Closed by cyrius v5.11.64 gvar-init-order fix → MVP gate hit at Attempt 68; the prior-art-audit pattern (diff against ≥2 independent impls; bundle only convergent divergences) is the durable framework, distinct from the specific-bug closeout. |
| `ahci-iron-burn-audit.md` | 2026-05-20 | ✅ Fresh — **NEW** | **NEW 2026-05-20** — pre-burn safety audit for the first AHCI/SATA iron exercise on archaemenid's `sda` 1.8 TB SSD. 11 sections: Phase 1-4 code surface table, LBA-5 sentinel write danger byte-for-byte (lands at GPT partition entries 12-15 under standard layout → corrupts array CRC32), `AHCI_RW_DEMO` compile-gate mitigation matching KTEST/XHCI_VERBOSE pattern, expected iron output, CMOS checkpoint trail (0x4B → 0x50), success/partial/failure rubrics, explicit exclusions. Awaits §4-patch decision before burn scheduling. Companion to `iron-nuc-zen-log.md` § Attempt 80 (NVMe iron debut precedent). |
| `planning/usb-hid-keyboard-driver.md` | 2026-05-17 | 🟠 Plan complete | **All 5 phases landed** across agnos 1.30.0–1.30.5: Phase 1 (PCIe discovery) → Phase 5 (HID-usage→PS/2 translation + `kb_buf` feed). Iron-side blocker remains: archaemenid USB2 silent-absorb gates Phase 3 enumeration completion, so Phases 4/5 dormant on this hardware (compile-verified; QEMU xhci-pci is the active validation surface). Iron-progress tracking moves to `iron-nuc-zen-log-mvp.md` (the MVP arc captured the silent-absorb work) and continues in `iron-nuc-zen-log.md` for post-MVP; this doc keeps the architectural-decision record. Status header refreshed 2026-05-17. |
| `README.md` | 2026-05-09 | ✅ Fresh | Index doc; "78-crate registry" drift removed in earlier pass; verified clean 2026-05-09 with planning/ rename reflected. |
| `planning/shared-crates.md` | 2026-06-04 | ✅ Fresh | **2026-06-04: full version + membership reconciliation against `/home/macro/Repos/*/VERSION`** (scripted, forward-only). **35 version cells synced** — 17 plain-format rows (sigil 3.7.2 / kavach 3.4.0 / libro 2.7.1 / avatara 2.7.0 / hisab 2.6.5 / mabda 3.0.1 …) **plus 18 linked `[name](url)` rows the first pass had missed** (agnos 1.41.11 / kybernet 1.3.3 / argonaut 1.8.2 / sandhi 1.4.1 / gnoboot 0.5.0 / cyrius-doom 0.27.5 / yantra 0.6.2 …). The "Folded At" historical table was skipped. **Membership:** agora 1.0.0 added (BBS → v1.0+ Binaries); hapi 1.0.1 + kii 1.0.0 graduated pre-1.0 → v1.0+; section + headline counts updated. `libs/README.md` got the same sync. **Flagged residuals (deliberate):** encom-hits registry 1.0.0 > local 0.6.1 (local checkout likely behind GitHub — not downgraded); yantra/darshana/sit now ≥0.5.0 sit in the In-Progress table (minor placement); secureyeoman (Rust/TS product consuming AGNOS crates) intentionally excluded. The 2026-05-11 pin-cluster drift is fully cleared. |
| `first-party/first-party-standards.md` | 2026-05-09 | ✅ Fresh | **Full Cyrius-first rewrite 2026-05-09**: 1109 lines (mid-transition, ~70% Rust) → 972 lines (Cyrius-only). Rust archive at `docs/archive/first-party-standards-rust-era.md`. Replaced Cargo.toml/cargo/criterion/thiserror/anyhow/tracing with cyrius.cyml/cyrius commands/.bcyr/sakshi. |
| `first-party/first-party-documentation.md` | 2026-05-09 | ✅ Fresh | **Refreshed 2026-05-09**: doc-health.md convention codified — table row + body section + FAQ-lookup-table entry (location at `docs/` root, header pattern, when-to-scaffold guidance for smaller repos). |
| `first-party/example_claude.md` | 2026-05-09 | ✅ Fresh | Verified 2026-05-09: fully Cyrius-current (cyrius.cyml format, sakshi, .tcyr, no Rust-era tokens). Template by design — no Last Updated footer needed. |
| `planning/agnostic-integration.md` | 2026-03-08 | ⏸️ Deferred | Per user 2026-05-09: "same as agnostic" — defer until desktop is working. References `llm-gateway` daemon (now hoosh) and `userland/` paths (extracted 2026-04-01); rewrite scheduled for after desktop ships. |
| `planning/hadara.md` | 2026-05-09 | ✅ Fresh | Verified 2026-05-09: fossil notice (2026-05-06) remains the right framing — design rationale that drove v1.0 ship; for shipped capabilities, see hadara repo. |
| `planning/joshua.md` | 2026-05-09 | ✅ Fresh | Verified 2026-05-09: design intent unchanged; **kiran shipped 1.0.0** noted in footer (engine dependency no longer a forward-looking gate); joshua itself still at 0.1.0 scaffold. |
| `planning/murti.md` | 2026-05-09 | ✅ Fresh | Verified 2026-05-09: design intent unchanged; consumer deps all at v1.0+ noted in footer. |
| `planning/pdf-suite.md` | 2026-05-09 | ✅ Fresh | Verified 2026-05-09: design intent unchanged; P0 status retained; design-phase footer note added. |
| `planning/agent-injection-defense.md` | 2026-05-10 | ✅ Fresh | **NEW 2026-05-10**: full design spec for encoded-prompt-injection defense (six-layer plan across phylax / hoosh / t-ron / kavach / libro / agnostik). Triggered by 2026-05 incident (third-party AI agent drained $200K via Morse code in tweet). Roadmap entry at Phase 15A. |
| `planning/tanur.md` | 2026-05-09 | ✅ Fresh | **Refreshed 2026-05-09**: 39 occurrences of `Irfan/IrfanConnection/irfan.sock/irfan.local` → `Ifran/IfranConnection/ifran.sock/ifran.local` (canonical name from registry). |
| `planning/bullshift-split.md` | 2026-03-30 | ⏸️ Deferred | Per user 2026-05-09: "we will but its later when desktop is working" — defer until desktop is shipping. Rust-era split plan; needs Cyrius-port reframing whenever bullshift's port window opens. |
| `planning/roadmap.md` | 2026-05-09 | ✅ Fresh | **Refreshed 2026-05-09**: footer `2026-04-01 → 2026-05-09`; header bumped to match; stale "77 crates (56 stable)" count stripped (defer to shared-crates.md). |
| `planning/README.md` | 2026-05-09 | ✅ Fresh | **Full rewrite 2026-05-09**: pre-1.0 only; v1.0+ entries link to `docs/applications/libs/` (lib-doc precedent — version columns dropped); shared-crates.md cited for live state. |
| `guides/agent-development.md` | 2026-04-14 | 🟠 Read-through | Verify against current daimon (1.1.1) + bote (2.5.1) APIs. |
| `guides/kernel-guide.md` | 2026-04-14 | 🟠 Read-through | Verify against kernel 1.26.1. |
| `guides/mcp-tools-reference.md` | 2026-04-07 | 🟠 Read-through | Verify against current 144-tool MCP set. |
| `guides/science-crate-specs.md` | 2026-04-05 | 🟠 Read-through | Long. Spot-check 2-3 crate specs. |
| `guides/testing.md` | 2026-04-14 | 🟠 Read-through | |
| `infrastructure/ci-cd-guide.md` | 2026-04-14 | 🟠 Read-through | |
| `infrastructure/dependency-watch.md` | 2026-04-21 | 🟠 Read-through | |
| `infrastructure/performance-benchmarks.md` | 2026-06-04 | 📦 Fossil (correctly) | Re-classified 2026-06-04: this is **not stale-needing-refresh** — it's a deliberately-fossilized Rust-era doc with a clear 2026-04-14 notice and dead-by-design `userland/…` paths. The Cyrius-era benchmark home is the per-repo `benchmarks-rust-v-cyrius.md` + the **Port Ledger** articles (V1/V2/V3). Updated its notice to point at the Port Ledger (was pointing only at per-repo docs + MEMORY.md). Leave the body frozen. |
| `infrastructure/rpi4-runner-setup.md` | 2026-04-14 | 🟠 Read-through | |
| `os/README.md` | 2026-04-14 | 🟠 Read-through | |
| `os/aegis.md`, `os/aethersafha.md`, `os/agnova.md`, `os/ark.md`, `os/mela.md`, `os/nous.md`, `os/phylax.md`, `os/samay.md`, `os/seema.md`, `os/takumi.md`, `os/zugot.md` | 2026-04-02 to 2026-04-13 | 🟠 Read-through | 11 files. Most ~5 weeks old. Some subsystems shipped major versions since (ark 0.8.0, nous 1.1.1, phylax 1.0.0). Refresh in batch. |

---

## Tier 3 — Vision / Research / Speculative (`docs/development/vision/`)

12 files, all touched 2026-04-07 to 2026-04-22.

| File | Status | Notes |
|---|---|---|
| `vision/release-vision.md` | 📦 **Fossil** | Explicitly marked fossil 2026-04-11. Successor "forward-looking compass document" promised but never written. **Open question**: write it, or close the gap by treating roadmap.md as the compass? |
| `vision/creator-economy.md` | 🟠 Read-through | |
| `vision/maat-42.md` | 🟠 Read-through | |
| `vision/applications/holodeck.md` | 🔵 Evergreen | Speculative by design. Re-read for assumption drift only. |
| `vision/applications/personality-architecture.md` | 🔵 Evergreen | |
| `vision/applications/semantic-audio.md` | 🔵 Evergreen | |
| `vision/applications/time-machine.md` | 🔵 Evergreen | |
| `vision/architecture/k8s-roadmap.md` | 🟠 Read-through | K8s posture may have shifted with kernel becoming primary surface. |
| `vision/architecture/network-evolution.md` | 🟠 Read-through | |
| `vision/research/paper-unified-consciousness-model.md` | 🔵 Evergreen | Research artifact. |
| `vision/research/space-infrastructure.md` | 🔵 Evergreen | |
| `vision/research/theoretical.md` | 🔵 Evergreen | |

---

## Tier 4 — Articles (`docs/articles/`)

19 files. 11 touched today, balance in April. Articles are **time-stamped artifacts** — they don't go "stale" the way operational docs do; they go *dated*. Don't refresh in place; supersede with a follow-up if the position changes.

| File | Last touched | Status |
|---|---|---|
| `_outlines.md` | 2026-05-11 | ✅ Fresh — working file. **2026-05-11**: TWO new outlines added — #6 *Structuring Major Work During Release Cycles* (REAL TYPE SYSTEM as canonical infrastructure-first example; locname-staleness three-surfacing tailing-bug pattern; ports-as-compass deviation framing) [outline only]; #7 *Methodology is the Trap — direct reply to Lars Faye* [**outline → draft same day**; full draft shipped to `methodology-is-the-trap.md`]. Both pair-ship intended (internal-methodology + public-argument surfaces of the same thesis). |
| `methodology-is-the-trap.md` | 2026-05-11 | ✅ Fresh — **NEW 2026-05-11**: full draft taken from outline #7 same day. ~270 lines / ~3,500 words. Direct reply to Lars Faye's *Agentic Coding is a Trap*. Locks the chisel aphorism, TL;DR, four-methodology-variables core (sequential/reference-staged/single-focus/five-layer), Faye-prescription-examined section with Tuszynski cross-link, receipt stack with v5.11.0 cycle close + locname-staleness three-catch + $400-vs-$20K, "same chisel cuts both ways" Anthropic comparison, and aphorism-restated close. Related-articles map covers all four anti-drift companion pieces + design-patterns §8. Anchors: Faye article + HN #48002442 + Tuszynski reply + Anthropic C-compiler post. Ready for review/polish; not yet linked from articles/README or external surfaces. |
| `cyrius-vs-rust-benchmarks.md` | 2026-05-09 | ✅ Fresh — Since-This-Was-Written footer added (v5.9.x close + v5.10.x REAL TYPE SYSTEM arc + v5.11/v5.12 reservation slip + cc5 size 783,408 B); Pure-compute-gap and inlining-gap notes refreshed |
| `doom-in-cyrius.md` | 2026-05-09 | ✅ Fresh — Since-This-Was-Written refreshed: cc5 783KB / v5.10.24; v5.9.x close + v5.10.x type-system arc; cyrius-doom still on 5.7.48 (held cluster thinned but DOOM didn't roll); next benchmark window noted |
| `entity-vs-skynet-doom.md` | 2026-05-06 | ✅ Fresh |
| `port-ledger-volume-1.md` | 2026-05-15 | ✅ Fresh — Locked to Cyrius v5.5.4 baseline; accreted in-place body updates stripped; *What Comes Next* expanded to 5-volume narrative arc (V1 baseline → V2 mid-arc state → V3 end-of-5.x/v6.0 re-measurement → V4 post-v6.x platform expansion → V5 synthesis); Where-Rust-Still-Wins markers point at Volume 2 / Volume 3 scope instead of describing in-place arc status. |
| `port-ledger-volume-2.md` | 2026-05-15 | ✅ Fresh (NEW) — Mid-arc state-of-things snapshot: agnos 1.30.1 iron-validated (the headline V2 receipt), kernel size/walk summary, four new native subsystems inventoried (aegis 1.0.0 graduated, gnoboot 0.2.0, commandress 0.1.0, kriya 0.1.0), pin-cluster review across 7 bands (5.11.55 leading edge → deep-lag tail), Volume 1's "Where Rust Still Wins" categories reviewed for *direction of motion* without claiming closure. Explicit "what shipped is recorded; what hasn't measured stays un-asserted." Comprehensive re-measurement deferred to Volume 3 (end-of-5.x / v6.0). |
| `port-ledger-volume-3.md` | 2026-06-04 | ✅ Fresh (OPEN/accreting) — Post-arc re-measurement ledger; **seeded 2026-06-01** (abaco + hisab), **expanded 2026-06-04** with six more Volume 1 port receipts (agnosys, kybernet, ai-hwaccel, avatara, kavach, nous) — **seven of the ten Vol 1 ports now have published 6.0.x receipts**. Gathered by a fan-out workflow that read each port's real CSV/bench-doc and adversarially verified every number against source (cardinal rule: **no fabricated numbers**; noisy single-run trails framed as regression-trail/direction-of-motion per the hisab precedent, not absolute speed). Three remain pending on a real run: agnostik (no 6.0.x CSV row yet), hoosh (Cyrius `.bcyr` suite not run), ark (still pre-6.0.x at 5.1.10). Accreting article — each port lands as its receipt exists. |
| `python-in-the-bootstrap.md` | 2026-05-06 | ✅ Fresh |
| `sovereign-compiler-vs-brute-force.md` | 2026-05-11 | ✅ Fresh — **2026-05-11**: added "Update 2026-05-11 — direct reply to *Agentic Coding is a Trap*" section as new dated subsection (didn't rewrite the 2026-05-09 snapshot per article-as-dated-artifact convention). Names the four methodology variables ($400 vs $20K), the v5.10.x cycle close (50 patches, three arcs), the locname-staleness three-surfacings catch as institutional-artifact receipt. Carries the "Tools don't make the craftsman; method does" aphorism + points at outline #7 for the standalone reply article. |
| `the-2-dollar-sd-card.md` | 2026-05-06 | ✅ Fresh |
| `what-justifies-a-stdlib-foldin.md` | 2026-05-06 | ✅ Fresh — shipped 2026-05-06 per state.md |
| `why-gigacenters.md` | 2026-05-06 | ✅ Fresh |
| `your-docs-are-about-to-rot.md` | 2026-05-11 | ✅ Fresh — **2026-05-11** (multi-touch same day): (1) added doc-health ledger as 6th mechanism in *What Sovereign Stacks Get That Most Teams Don't* section (was 5); (2) updated "What to Do Now" item 4 to point at the ledger pattern as concrete institutionalization of audit-pass discipline; (3) appended recursive-irony paragraph to *For the Receipts* — doc-health pattern emerged after the article shipped, article had to drift to acknowledge the tool it prescribed; (4) updated Cyrius version refs (5.6.0 → 5.11.0) + tempo example (v5.5.x close → v5.10.x .50-in-five-days three-arc); (5) **NEW section** *File Types and Lifecycles — Concretely* added after *Scope: Three Different Doc Problems* — 9-row per-file taxonomy table (CLAUDE.md / state.md / CHANGELOG / history+timeline+retros / ADRs / articles / design-patterns / doc-health) with lifecycle + holds + doesn't-hold columns; three conflation-closing rules; doc-health framed as audit-surface for the taxonomy itself. |
| `your-claude-md-isnt-lying.md` | 2026-04-25 | 🔵 Dated artifact |
| `why-gpu-belongs-in-the-stdlib.md` | 2026-04-24 | 🔵 Dated artifact |
| `what-5.5.x-taught-5.6.x.md` | 2026-04-24 | 🔵 Dated artifact |
| `micro-work-and-agent-deferment.md` | 2026-04-24 | 🔵 Dated artifact |
| `memory-should-be-sovereign-too.md` | 2026-04-24 | 🔵 Dated artifact |
| `docs-go-stale-before-the-commit.md` | 2026-04-24 | 🔵 Dated artifact |
| `the-price-of-porting-early.md` | 2026-04-23 | 🔵 Dated artifact |
| `end-of-4x-independent-audit.md` | 2026-04-15 | 🗄 Archived | **Moved to `docs/archive/` on 2026-05-12** — Kernel-Boot finding was QEMU-only, contradicted on real iron 2026-05-12 (`grub_elf32_get_shnum` rejection; repair in Cyrius v5.11.29/.30/.31). Bootstrap-Chain finding still holds. |

---

## Tier 5 — Per-subject docs (apps + libs)

❓ **The big strategic question lives here. See [Open questions](#open-strategic-questions).**

### Lib docs (`docs/applications/libs/`) — ~83 files (excluding README + LICENSE-FIXES)

Pattern: **pointer + role description + repo link + license + status + registry pointer**. As of 2026-05-06, all version lines have been removed (Stage 4 cleanup) — registry tables ([`shared-crates.md`](development/planning/shared-crates.md), [`libs/README.md`](applications/libs/README.md)) are now the single source of truth for versions.

**Stage 4 result (2026-05-06)**:
- Before: 56 of ~83 lib docs had `- **Version**: X.Y.Z` lines (drift surface).
- After: 0. Bulk-deleted via `sed -i '/^- \*\*Version\*\*/d' *.md`. Remaining list items (Repository, License, Status) and body paragraphs preserved.
- Verified clean on `abaco.md` and `sandhi.md` (the only file with an annotated version-line variant; its body paragraph already carries the fold-into-stdlib context, no info loss).

The `~25` lib docs that never had version lines were unchanged (they were already pattern-clean: badal, bhava, bijli, dravya, garjan, ghurni, goonj, hisab, ifran, impetus, khanij, kimiya, nidhi, pavan, prakash, pramana, prani, pravash, shabdakosh, shabda, tanmatra, tarang, ushma, varna).

### App docs (`docs/applications/`) — 19 files (+ README)

All 19 touched 2026-04-07 — single-batch artifact from a previous planning session.

**Status (per per-doc headers, verified 2026-05-06):** 18 of 19 marked Released; 1 marked Planned (Dhara — media streaming server, Port 8078). Earlier audit claim that "8 apps have files but aren't in the index" was wrong — the README does list all 19; my initial sample read was truncated.

**README refresh (2026-05-06)**: added Status column, fixed Vidhana description (was "File manager" → "System settings" per per-doc header), corrected "Irfan" display name to "Ifran" (filename `irfan.md` predates the Synapse → Irfan → Ifran rename), enriched a few descriptions. Status legend added to clarify the index reflects per-doc headers.

---

## Tier 6 — ADRs (`docs/adr/`)

9 files (8 ADRs + README). ADR-008 added 2026-05-06 to record the Cyrius pivot. ADR-001 marked partially superseded. ADR README index refreshed.

This is fine *if* no architecturally significant decisions have been made since. They have:

**Decisions made since last ADR that arguably warrant ADRs:**
- **Cyrius pivot** (2026-04-04) — language shift from Rust to sovereign Cyrius. ADR-001 still says "Language (Rust)". This is the biggest unrecorded decision in the project.
- **Kernel extraction to `agnos` repo** (2026-04-05) — separation of kernel from genesis repo
- **Monolith dismantle complete** (2026-04-01) — Cargo workspace removed, 130+ standalone repos
- **Sandhi-fold pattern** (v5.7.0) → vani-fold (v5.8.0) → niyama-fold (v5.9.0) — stdlib absorption pattern
- **Two-stage beta rescope** (2026-05-06, today) — closed beta + public beta split
- **AGNOS-native kernel structurally immune to CVE-2026-31431** — design decision worth recording

**Open strategic question**: catch up the ADR series, or close it (declaring `design-patterns.md` + `state.md` + commit history as the system of record going forward)?

---

## Tier 7 — Reference (security, installation, .github)

| File | Last touched | Status | Notes |
|---|---|---|---|
| `docs/installation/README.md` | 2026-05-06 | ✅ Fresh | Refreshed 2026-05-06: header (date + closed/public beta status line), what-works-today (kernel 1.26.1/248KB, boot.cyr ~67KB), Beltane target → closed-beta target, `.cyrius-toolchain` → `cyrius.cyml` per current pin convention, cc3 → cc5 troubleshooting, Phase 13B framing → current. |
| `docs/installation/system-requirements.md` | 2026-06-04 | ✅ Fresh | **2026-06-04 (1.41.x kernel-fact sweep)**: kernel → **1.41.11**; `.cyrius-toolchain` → `scripts/cyrius.cyml` path fix. RISC-V + bare-metal target rows updated to **v5.12.x** (was v5.7 / v5.8); date bumped. |
| `docs/installation/troubleshooting.md` | 2026-05-09 | ✅ Fresh | kybernet expected-version 1.0.1 → 1.0.2; date bumped. |
| `docs/security/security-guide.md` | 2026-05-06 (CVE pointer) | ✅ Fresh | CVE-2026-31431 structural-immunity callout already added in Stage 14 (2026-05-06); body content still applicable; verified 2026-05-09. |
| `docs/security/cis-benchmarks.md` | 2026-04-14 | 🟠 Read-through | |
| `docs/security/penetration-testing.md` | 2026-04-14 | 🟠 Read-through | |
| `docs/security/security-checklist.md` | 2026-04-14 | 🟠 Read-through | |
| `docs/security/vulnerability-management.md` | 2026-04-14 | 🟠 Read-through | |
| `.github/SUPPORT.md` | 2026-02-26 | 🔵 Evergreen | |
| `.github/pull_request_template.md` | 2026-02-11 | 🔵 Evergreen | |
| `.github/ISSUE_TEMPLATE/*` | 2026-03-05 to 2026-03-11 | 🔵 Evergreen | |
| `scripts/README.md` | 2026-04-21 | 🟠 Read-through | Verify Cyrius build commands match current toolchain. |

---

## Tier 8 — Archive (`docs/archive/`)

36 files. Frozen by design. Pattern: `*-rust-era.md`, `*-pre-cyrius/`, `*-pre-extraction/` naming.

✅ **Verified**: archive contents are correctly classified (sample: `agnostik-roadmap-pre-cyrius.md`, `cyrius-lang-migration.md`, `desktop-environment-rust-era.md`). Leave alone.

---

## Tier 9 — Private (`docs/private/`)

Gitignored. 2 files, both created today.

| File | Status |
|---|---|
| `private/outreach/angel-and-partnership-framework.md` | ✅ Fresh |
| `private/outreach/ljff-pilot-brief.md` | ✅ Fresh |

---

## Tier 10 — Creative (`docs/creative/`)

5 files, dates 2026-04-05 to 2026-04-17. Narrative / brand artifacts. Treat as dated artifacts, not operational docs. Re-read for accuracy of any embedded technical claims.

---

## Open strategic questions

These are the calls that need user input before per-file action. Mass-editing without answering these wastes work.

### Q1 — Lib doc pattern (105 files)

The lib docs are minimal pointers (3 lines + version + repo link). The drift surface is the version line. Three honest options:

- **(A) Keep as-is, mass-refresh version lines.** Quick win. Drift returns within weeks.
- **(B) Delete the version line, rely on the registry table.** Less drift surface, registry is the source. Lib docs become pure pointers + role description.
- **(C) Delete the lib docs entirely, expand the registry table to carry the role.** One source of truth. Loses per-lib URL slugs (links to `docs/applications/libs/abaco.md` would break).

**Recommendation**: B. Cheapest sustainable fix. Preserves URLs.

### Q2 — App doc inventory (19 files + README mismatch)

App docs were a planning batch from one date. Some apps shipped; many didn't. README only lists 11 of 19. Options:

- **(A) Refresh README to list all 19, mark scaffolds vs. shipped honestly.**
- **(B) Refresh README to list only what's real; archive the speculative ones to `docs/archive/apps-speculative/`.**
- **(C) Per-app audit: keep, update, or archive each individually.**

**Recommendation**: A first (cheap, immediate honesty), then C as part of normal work.

### Q3 — ADR catch-up vs. closure

ADRs haven't been touched since 2026-03-08. Several major decisions have happened since. Options:

- **(A) Catch up: write ADRs 008–013 covering Cyrius pivot, kernel extraction, monolith dismantle, fold pattern, beta rescope, kernel structural immunity.**
- **(B) Close the ADR series: declare design-patterns.md + state.md + commit history the canonical decision record going forward.** Add a closing ADR-008 explaining the close.
- **(C) Hybrid: write ADR-008 only for the Cyrius pivot (the biggest gap), then evaluate.**

**Recommendation**: C. Cyrius pivot deserves its own ADR; subsequent decisions are downstream and can ride design-patterns.md.

### Q4 — release-vision.md fossil + missing compass

The fossil notice promises a successor "forward-looking compass document." It was never written. Options:

- **(A) Write the compass doc** as `docs/development/vision/compass.md` (or similar). Future-looking, post-Cyrius-pivot reset.
- **(B) Declare roadmap.md the compass.** Update fossil notice on release-vision.md to point at roadmap.md instead of the unwritten doc.
- **(C) Leave the gap.** Live with the fossil pointing at nothing.

**Recommendation**: B. roadmap.md already serves the compass function; explicit pointer closes the gap with no new doc to maintain.

### Q5 — Mass-refresh stale version refs

README, AGNOS.md, architecture.md, installation/README.md all have stale version refs. Refresh now or batch later? They don't get re-checked otherwise.

**Recommendation**: Refresh now. They are entry-point docs read by newcomers; old version numbers in those is the worst stale.

---

## In-flight (blocked, not stale)

- `iso-stage4-plan.md` — D1–D4 decisions pending user input.
- Vani-fold + niyama-fold pattern docs — flagged as pending in `state.md`.
- `cyrius-vs-rust-benchmarks.md` v5.8.x / v5.9.x rows — pending per state.md.
- Niyama-fold-in article slot — pending per state.md.

---

## Forward doc-policy commitments

Items that are *scheduled* doc decisions, not stale state. Surfaced here so they aren't forgotten when the trigger date arrives.

| # | Commitment | Trigger | Source | Notes |
|---|---|---|---|---|
| 1 | **Rust-era archive purge** — delete the entire `docs/archive/` Rust-era + monolith-pre-extraction content in a single commit; tag the prior commit as `archive-final-v<N>` so historical refs use `git show <tag>:docs/archive/<file>` or a permalink to that tag's tree on GitHub. | "after a few tagged GA releases past Beta" | [`docs/archive/README.md:96-98`](archive/README.md) | The 2026-05-06 beta rescope (closed beta early June 2026 + public beta Q4 2026) compresses the runway. Re-evaluate at v1.0 cut whether the archive is still being actively referenced; if not, execute. |
| 2 | **CHANGELOG.md historical purge** — same shape as #1 if the historical entries (most pre-Cyrius-pivot entries before 2026-04-04) become noise. | TBD — keep as-is unless the file becomes unwieldy | none yet | Lower priority; CHANGELOG entries are dated and clearly historical. |

When the trigger fires, the purge is a single commit, not a per-file decision.

---

## Refresh procedure

When docs are touched:

1. Find the affected row in the relevant tier table.
2. Update **Last touched** column to the new date.
3. Update **Status** column if the bucket changed.
4. Update **Action** column if the next step changed.
5. If a doc moved or was archived, update its row to reflect the new home.
6. Re-anchor "Last refresh" date in the header.

When the bucket counts at the top drift by more than ~5 in any cell, refresh the at-a-glance table.

This file's refresh cadence is **opportunistic** (touched when other docs are touched), not periodic.

---

## What this file is NOT

- Not a substitute for state.md (which holds cross-repo Cyrius cycle/pin/sweep state).
- Not a CHANGELOG (which records what shipped, not what's stale).
- Not a TODO list (open work for the project lives in roadmap.md and per-repo backlogs).
- Not a per-doc review log (we record the result of an audit pass, not the per-doc reasoning).

---

*Last refresh: 2026-06-04 (post-1.41.x-arc kernel-fact sweep — shell separation 1.41.0→1.41.11 software-complete; state.md anchor collapse + pin-lag re-survey; SECURITY.md 26-syscall hardcode stripped). Refresh in place when docs are touched.*
