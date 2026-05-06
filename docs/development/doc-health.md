---
name: AGNOS Documentation Health
description: Living state of doc currency in the agnosticos repo — fresh / stale / archived / open-question, refreshed as docs are touched
type: state
---

# Documentation Health — agnosticos

> **Last refresh**: 2026-05-06 (initial audit) | **Refresh cadence**: when docs are touched, update the affected row.
> **Scope**: This repo only (`agnosticos`). Per-subsystem docs live in their own repos and are not audited here. State of cross-repo Cyrius pin/version drift lives in [`state.md`](state.md), not here.

This is a **ledger**, not a one-time audit. Rewrite-in-place as docs change. Per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md) and [*Your Docs Are About to Rot*](../articles/your-docs-are-about-to-rot.md), a doc-set this size needs an explicit health surface or it rots silently.

---

## At a glance — 2026-05-06 inventory

**265 markdown files** across the repo. Bucket counts (after 2026-05-06 audit pass — Stages 1–15):

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh / refreshed in this audit** | ~135 | Confirmed current or just edited. Includes ~56 lib docs cleaned (version lines removed) + ~28 fossil-noticed docs (now accurate) + 4 entry-points + ADRs + dev/os batch + history + timeline + dev/os/README.md restructure + dev/README.md index + 4 broken-link fixes (SUPPORT, CONTRIBUTING, mcp-tools-reference, joshua) + LICENSE-FIXES archived. |
| 🟡 **Stale — refresh in place** | ~0 | Cleared — no known-stale operational docs remain. Registries verified fresh. |
| 🟠 **Read-through outstanding** | ~10 | Light skim only on creative/, dated-artifact articles, .github templates. None known to be wrong. |
| 🔵 **Probably evergreen** | ~25 | Philosophy, thesis, code-of-conduct, .github templates — re-read pass annually, not weekly. |
| 📦 **Archive — frozen by design** | ~36 | `docs/archive/`. Verified — nothing misclassified. |
| ❓ **Open strategic question** | 0 | All 4 strategic questions (lib doc pattern, app doc inventory, ADR posture, entry-point refresh) resolved in this audit. Q4 (release-vision compass) closed in Stage 5. |

Numbers approximate; rolls up from the per-tier tables below.

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
- ✅ Stage 11 — `docs/development/applications/` batch (~12 planning docs): hadara updated (was "Scaffolded 0.1.0"; now "Released — Cyrius-native v1.0.0" per state.md); applications/roadmap.md drift removed (crate count "76 total / 55 at v1.0+" pulled in favor of shared-crates.md as source). Other planning docs verified — Status: Scaffolded framing on tanur/joshua/murti is accurate; first-party-standards/-documentation are current; bullshift-split, pdf-suite, agnostic-integration are accurate planning artifacts.
- ✅ Stage 12 — `docs/development/vision/` batch (12 files): all correctly labeled Vision/Theoretical/Future-consideration; one factual drift fixed (space-infrastructure.md "AGNOS at 204KB" → "~248KB at v1.26.1" with state.md pointer); release-vision.md fossil pointer was already updated in Stage 5.
- ✅ Stage 13 — history.md, timeline.md, sprint-history.md: history.md and timeline.md got post-Beltane milestone entries (Cyrius v5.5.x multi-platform → v5.6.x optimization arc → v5.7.0 sandhi-fold → kernel 1.26.1 → v5.8.x 66-patch arc → v5.9.0 niyama-fold → beta rescope), footer dates refreshed to 2026-05-06; sprint-history.md fine as-is (already pairs with CHANGELOG per its footer).
- ✅ Stage 14 — `docs/security/` batch (5 files): 4 already had accurate fossil notices; security-guide.md got CVE-2026-31431 structural-immunity note pointing to state.md.
- ✅ Stage 15 — CONTRIBUTING.md (`cc3` → `cc5` reference fix), SECURITY.md verified (mostly evergreen), iso-pipeline.md status note refreshed (Stage 0 implemented + Stage-4-only first cut planned + CHANGELOG 2026.4.27 26/26 components ready).
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
| `README.md` | 2026-05-06 | ✅ Fresh | Refreshed 2026-05-06: badges, architecture diagram, stack table (kernel 1.26.1/248KB, Cyrius 5.9.0/~741KB, sigil 2.9.4, libro 2.0.5, ark 0.8.0, nous 1.1.1), security versions, beta target (closed/public split), pointer to state.md added. |
| `CHANGELOG.md` | 2026-04-28 | 🟡 Stale | Last entry pre-dates Cyrius v5.8.x and v5.9.0. Add cycle close summaries. **Refresh** |
| `CLAUDE.md` | 2026-05-06 | ✅ Fresh | Just updated. State-table version cell intentionally points to state.md per established pattern. |
| `CONTRIBUTING.md` | 2026-04-21 | 🟠 Read-through | Verify Cyrius-build instructions are still current. |
| `SECURITY.md` | 2026-04-14 | 🟠 Read-through | CVE-2026-31431 should probably be referenced. |
| `SUPPORT.md` | 2026-03-11 | 🔵 Evergreen | Operational pointers. Re-check links. |
| `CODE_OF_CONDUCT.md` | (unverified) | 🔵 Evergreen | Standard. |
| `docs/AGNOS.md` | 2026-05-06 | ✅ Fresh | Refreshed 2026-05-06: lead paragraph (cc5, 248KB), header table (kernel/compiler versions, status), dependency comparison rows, history table (added 5 milestones since Beltane through 2026-05-06), bootstrap chain, core subsystems table, kernel size discussion ("248KB is the honest size at v1.26.1"), statistics block (rounded values + pointer to state.md), Last Updated. |
| `docs/architecture.md` | 2026-05-06 | ✅ Fresh | Refreshed 2026-05-06: header (date/version + state.md pointer), kernel diagram (v1.26.1, 248KB), kernel section, ark v0.8.0, nous v1.1.1, sigil v2.9.4, takumi v0.8.0, technology stack rows, pending Cyrius ports (refactored to current state with shipped-since note), design decisions, security architecture (libro 2.0.5, sigil 2.9.4). |
| `docs/architecture/kernel-layers.md` | 2026-04-20 | 🟠 Read-through | Verify against current 33-subsystem layout. |
| `docs/design-patterns.md` | 2026-05-06 | ✅ Fresh | Just touched. Note: state.md flags vani-fold + niyama-fold patterns + starship-prompt convention as "to add" — verify whether those landed. |
| `docs/philosophy.md` | 2026-04-22 | 🔵 Evergreen | Ideology, not status. Re-read pass annually. |
| `docs/thesis.md` | 2026-04-22 | 🔵 Evergreen | Same. |
| `docs/history.md` | 2026-04-20 | 🟠 Read-through | Major events since 2026-04-20 (Cyrius v5.8.x 4-day arc, v5.9.0 cut, beta rescope) should be appended. |
| `docs/timeline.md` | 2026-04-17 | 🟠 Read-through | Same — append milestones since. |
| `docs/os/README.md` | 2026-04-17 | 🟠 Read-through | Verify against current OS module map. |

---

## Tier 2 — Operational docs (`docs/development/`)

> **Important framing (per user 2026-05-06)**: Files under `docs/development/applications/` are **pre-v1 / forward-looking planning docs** — apps that may ship later, not vapor or candidates for archival. Treat 🟠 read-through here as "verify the planning is still the intent," not "candidate to delete." Subjects in `docs/applications/` (no `development/`) are the consumer-facing app surface; that's where shipped vs. scaffolded distinctions matter.

| File | Last touched | Status | Action |
|---|---|---|---|
| `roadmap.md` | 2026-05-06 | ✅ Fresh | Just rescoped (closed/public beta). Stale subsystem version table left intentionally — pattern is per-repo refresh via state.md drift list. |
| `state.md` | 2026-05-06 | ✅ Fresh | Refreshed for v5.9.0 cut day. |
| `summer-2026-arc.md` | 2026-05-06 | ✅ Fresh | Touched today. Verify v5.9.x framing in line ~217 still matches actual cycle theme (per state.md note). |
| `sprint-history.md` | 2026-04-07 | 🟠 Read-through | Append v5.7.x / v5.8.x / v5.9.0 cycle closeouts. |
| `monolith-extraction.md` | 2026-04-17 | 🔵 Evergreen | Extraction is **complete** (per CLAUDE.md). Doc is now historical record. Confirm framing reflects done-state. |
| `iso-pipeline.md` | 2026-04-17 | 🟡 Stale | Need to verify Stage status against current. |
| `iso-stage4-plan.md` | 2026-04-28 | 🔴 In-flight | D1–D4 decisions pending user input per roadmap callout. **Not stale — blocked.** |
| `README.md` | 2026-04-20 | 🟡 Stale | Header says shared-crates is "78-crate registry" — drifted (registry now ~76 per applications/roadmap.md, may have moved again). |
| `applications/shared-crates.md` | 2026-05-06 | ✅ Fresh | Touched today. Sweep against state.md drift list before declaring authoritative. |
| `applications/first-party-standards.md` | 2026-04-24 | 🟠 Read-through | Standards are evergreen; verify versions of cited tools. |
| `applications/first-party-documentation.md` | 2026-04-24 | 🟠 Read-through | Same. |
| `applications/example_claude.md` | 2026-04-24 | 🟠 Read-through | CLAUDE.md template — verify current Cyrius patterns. |
| `applications/agnostic-integration.md` | 2026-04-14 | 🟠 Read-through | |
| `applications/hadara.md` | 2026-04-13 | 🟠 Read-through | |
| `applications/joshua.md` | 2026-03-26 | 🟠 Oldest | 6+ weeks. Likely needs full re-read. |
| `applications/murti.md` | 2026-04-07 | 🟠 Read-through | |
| `applications/pdf-suite.md` | 2026-04-07 | 🟠 Read-through | Per applications/roadmap.md, pdf-suite is P0 active — verify status. |
| `applications/tanur.md` | 2026-04-07 | 🟠 Read-through | |
| `applications/bullshift-split.md` | 2026-04-07 | 🟠 Read-through | |
| `applications/roadmap.md` | 2026-04-07 | 🟡 Stale | Crate count "76 total" / "55 at v1.0+" — drifted. **Refresh** counts from state.md. |
| `applications/README.md` | 2026-04-15 | 🟠 Read-through | |
| `guides/agent-development.md` | 2026-04-14 | 🟠 Read-through | Verify against current daimon (1.1.1) + bote (2.5.1) APIs. |
| `guides/kernel-guide.md` | 2026-04-14 | 🟠 Read-through | Verify against kernel 1.26.1. |
| `guides/mcp-tools-reference.md` | 2026-04-07 | 🟠 Read-through | Verify against current 144-tool MCP set. |
| `guides/science-crate-specs.md` | 2026-04-05 | 🟠 Read-through | Long. Spot-check 2-3 crate specs. |
| `guides/testing.md` | 2026-04-14 | 🟠 Read-through | |
| `infrastructure/ci-cd-guide.md` | 2026-04-14 | 🟠 Read-through | |
| `infrastructure/dependency-watch.md` | 2026-04-21 | 🟠 Read-through | |
| `infrastructure/performance-benchmarks.md` | 2026-04-14 | 🟡 Stale | New benchmarks since (sigil 2.9.4, kernel 1.26.1, etc.). |
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
| `_outlines.md` | 2026-05-06 | ✅ Fresh — working file |
| `cyrius-vs-rust-benchmarks.md` | 2026-05-06 | ✅ Fresh — but state.md flags v5.8.x/v5.9.x rows as still pending |
| `doom-in-cyrius.md` | 2026-05-06 | ✅ Fresh — pending v5.9.x rebuild numbers per state.md |
| `entity-vs-skynet-doom.md` | 2026-05-06 | ✅ Fresh |
| `port-ledger-volume-1.md` | 2026-05-06 | ✅ Fresh — *Where Rust Still Wins* needs v5.8.x sweep per state.md |
| `python-in-the-bootstrap.md` | 2026-05-06 | ✅ Fresh |
| `sovereign-compiler-vs-brute-force.md` | 2026-05-06 | ✅ Fresh — cc5 size: 741,048 B baseline (v5.9.0) per state.md |
| `the-2-dollar-sd-card.md` | 2026-05-06 | ✅ Fresh |
| `what-justifies-a-stdlib-foldin.md` | 2026-05-06 | ✅ Fresh — shipped 2026-05-06 per state.md |
| `why-gigacenters.md` | 2026-05-06 | ✅ Fresh |
| `your-docs-are-about-to-rot.md` | 2026-05-06 | ✅ Fresh — meta-relevant to this audit |
| `your-claude-md-isnt-lying.md` | 2026-04-25 | 🔵 Dated artifact |
| `why-gpu-belongs-in-the-stdlib.md` | 2026-04-24 | 🔵 Dated artifact |
| `what-5.5.x-taught-5.6.x.md` | 2026-04-24 | 🔵 Dated artifact |
| `micro-work-and-agent-deferment.md` | 2026-04-24 | 🔵 Dated artifact |
| `memory-should-be-sovereign-too.md` | 2026-04-24 | 🔵 Dated artifact |
| `docs-go-stale-before-the-commit.md` | 2026-04-24 | 🔵 Dated artifact |
| `the-price-of-porting-early.md` | 2026-04-23 | 🔵 Dated artifact |
| `end-of-4x-independent-audit.md` | 2026-04-15 | 🔵 Dated artifact |

---

## Tier 5 — Per-subject docs (apps + libs)

❓ **The big strategic question lives here. See [Open questions](#open-strategic-questions).**

### Lib docs (`docs/applications/libs/`) — ~83 files (excluding README + LICENSE-FIXES)

Pattern: **pointer + role description + repo link + license + status + registry pointer**. As of 2026-05-06, all version lines have been removed (Stage 4 cleanup) — registry tables ([`shared-crates.md`](applications/shared-crates.md), [`libs/README.md`](../applications/libs/README.md)) are now the single source of truth for versions.

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
| `docs/installation/system-requirements.md` | 2026-04-21 | 🟠 Read-through | |
| `docs/installation/troubleshooting.md` | 2026-04-21 | 🟠 Read-through | |
| `docs/security/security-guide.md` | 2026-03-16 | 🟠 Oldest | 7+ weeks. Add CVE-2026-31431 reference. |
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

*Last refresh: 2026-05-06 (initial audit). Refresh in place when docs are touched.*
