# AGNOS Design Patterns

> **Status**: Outline / accretion document — pending GA retrospective.
> **Last Updated**: 2026-04-20
> **Purpose**: Document the recurring cognitive patterns behind AGNOS decisions — the through-lines that produced many specific choices across many repos. This is the *interpretation* layer.

## What This Doc Is (And Isn't)

- **Not ideology** — that's [`philosophy.md`](philosophy.md) (sovereignty, Temple framing, Hermetic role).
- **Not per-decision rationale** — that's the ADRs in each repo.
- **Not dated events** — that's [`history.md`](history.md) and [`timeline.md`](timeline.md).
- **Not per-release change lists** — that's `CHANGELOG.md` in each repo.
- **Not working rules for agents** — that's `CLAUDE.md` files.

This is the layer that lets a cold reader in 2030 reconstruct *why* the decisions fit together as a system — not just what each one was. Receipts preserve the *what*. The interpretation lives here.

## How to Use This Document

- Each section names a pattern, describes it briefly, gives examples, and points to where it's elaborated (article / ADR / memory / CLAUDE.md rule).
- Add a section when a new pattern surfaces — don't wait for GA.
- Keep entries brief; detail lives in the linked artifacts.
- At GA this outline becomes the spine of the full retrospective, expanded with hindsight commentary and arc framing.

---

## 1. Subtraction as Primary Cognitive Move

**Pattern.** Solve by removing redundant layers rather than adding clever new ones. Most major AGNOS receipts are subtractions, not additions.

**Examples.**
- Rust runtime removed: `exit42` dropped from 345 KB stripped to 152 B
- Dependencies collapsed: 131 crates → 0 in ai-hwaccel; 40 crates → 0 in hoosh; 448 crates → 1 in kavach
- Bootstrap chain: Rust seed retired; 29 KB hand-audited assembly as the foundation
- libc removed from the runtime
- mabda folded into Cyrius stdlib (removed an independent naming/versioning surface)
- `cc` → `cc2` → `cc3` → `cc5` → `cyc` at v6.0 (four rename events — the last one ends the treadmill for all future major versions)

**Why.** Addition looks like progress because it's visible. Subtraction looks like nothing happened until you measure what's left. The cultural pressure is all toward adding "value." AGNOS runs the other way — most of the receipts are what's no longer there.

**See also.** [Cyrius vs Rust: Head-to-Head Benchmarks](articles/cyrius-vs-rust-benchmarks.md), cyrius repo's `docs/size-comparisons.md` (multi-language `exit42` baselines).

---

## 2. Staged Optimization / No Deferred Debt

**Pattern.** Optimization and cleanup work are queued as the explicit next release block, never deferred to "someday." Each release contains specific improvements; improvements don't accumulate as floating technical debt.

**Examples.**
- v5.5.x Windows / Apple platform closeout → v5.6.x optimization arc (O1–O6) → v5.7.0 RISC-V → v5.8.0 bare-metal — each phase is a queued explicit block
- Port sequencing: system ports shipped now, compute ports scheduled after v5.6.x
- cc5 → `cyc` rename scheduled for v6.0 as the one-and-done cleanup — not deferred indefinitely

**Why.** Most projects ship features and leave "we'll optimize later" debt that never gets paid because priorities shift. AGNOS doesn't let optimization become a floating someday-item — it's always the literal next block. Drift can't accumulate because there's nowhere for it to sit.

**See also.** [The Price of Porting Early](articles/the-price-of-porting-early.md); memory: `project_execution_rhythm.md`.

---

## 3. Port-First Sequencing: System Before Compute

**Pattern.** Port workloads by compiler-readiness class. System ports (allocator-heavy, I/O-heavy, syscall-heavy) go first — they validate the language and drive compiler feedback. Compute ports (math, DSP, science) wait for the optimization arc that makes their numbers competitive on first publication.

**Examples.**
- 30+ system ports shipped pre-v5.6.x (kernel, kybernet, hoosh, ark, nous, kavach, sigil, agnosys, argonaut, libro, shakti, phylax, bote, t-ron, daimon, agnoshi, itihas, sankoch, hisab, avatara, ai-hwaccel, hadara, shravan, mabda, abaco, bsp, cyrius-doom, and more)
- 82 compute / science ports scheduled for post-v5.6.x / v5.7.x
- abaco feedback loop: port hit missing-feature friction → spec'd `u64_mulmod` fast-path to compiler → Cyrius v4.8.5 shipped it → abaco re-measured 12× end-to-end. Canonical closed form.

**Why.** Porting compute code against a pre-optimization compiler publishes weak numbers that become canonical first impressions. System ports show Cyrius's structural wins at any compiler version; compute ports need the compiler at its target form. Sequencing by port-class preserves the first-impression record.

**See also.** [The Price of Porting Early](articles/the-price-of-porting-early.md); memory: `project_port_ledger_arc.md`, `project_port_feedback_to_cyrius.md`.

---

## 4. Single Source of Truth — Pull, Don't Bake

**Pattern.** Version, config, and cross-cutting data live in ONE place. Consumers pull it rather than encoding it into their own artifacts. Every duplicated fact is a drift surface.

**Examples.**
- `VERSION` file at repo root (CalVer, single authority) — docs and scripts pull from it, never hardcode
- cc5 → `cyc` rename: binary name becomes stable; version lives in `VERSION`; no more `cc → cc2 → cc3 → cc5` renaming treadmill across scripts, CI, install paths, docs (four historical renames — `cyc` is the final one)
- Size comparisons live in cyrius repo's `docs/size-comparisons.md`; genesis docs link out rather than duplicate tables that would drift per optimization release
- Per-repo CLAUDE.md is authoritative for that repo's state — sibling repos reference, don't copy

**Why.** Every place the same fact appears is a place it can go stale. Baking a version into a binary name means every release opens dangling references across the tree. Pulling from source means one update site, always fresh. Enforces single-source rather than aspirational-single-source.

**See also.** memory: `reference_cyrius_size_comparisons.md`.

---

## 5. Hermetic / Librarian Role — Receive, Catalog, Transmit

**Pattern.** Operate in the Messenger / Librarian archetype. Build the library, make it passable, step aside. NOT invent, apply, govern, extract, or own. Application belongs to future generations.

**Examples.**
- Ma'at 42/42 library mapping: a 4,000-year completeness test converges with the crate registry without forcing — the Librarian catalogs what exists, doesn't manufacture coverage
- Vision docs (`docs/development/vision/`) present routes kept open, not products owned
- Temple of Hiphop lineage (KRS-One → MalikOne → LA Chapter) as transmission across generations
- Creator Economy: thesis documented, implementation deferred to whoever runs it
- Theoretical doc (portals, teleportation, nanites): *"ensure that architectural decisions don't preclude these possibilities"* — pure Librarian talk, not roadmap commitment

**Why.** Most sovereignty projects fail because the builder extends into applier: infrastructure → apps → economy → governance, each step a platform in disguise. The Hermetic function refuses that drift and keeps the project a gift rather than a dependency. Also: if you're trying to decide what the compiler gets used for, you can't also be building the compiler at 63-day pace. Different jobs, different gear ratios.

**See also.** [`philosophy.md`](philosophy.md) (Temple framing); [`docs/development/vision/maat-42.md`](development/vision/maat-42.md); memory: `feedback_route_and_library.md`, `project_temple_philosophy.md`, `project_temple_of_hiphop.md`.

---

## 6. User-Side Naming

**Pattern.** Coin terminology from the user's side of the transaction. Outcome names (what the user gets) and mechanism names (how it works) stick. Author-journey names (what it felt like to build, what ideology it represents) don't — and date quickly.

**Examples.**
- Accepted: *surface-at-launch* (outcome), *port-bootstrapped language* (mechanism)
- Rejected: *ecosystem transplant* (author-vivid image, doesn't inform the user), *permitted-to-sovereign migration* (author-ideology arc)
- Subsystem names (Sanskrit, Arabic, Hebrew, Japanese) are cultural references chosen to describe *function*, not Robert's journey: `kavach` = armor (sandbox), `sigil` = seal (trust), `kybernet` = helmsman (PID 1), `hoosh` = consciousness (inference routing)

**Why.** Names that stick describe utility to readers. Self-experiential names get ignored even when evocative. "DevOps" stuck because it described what the thing *was*. Applies to paradigms, subsystems, articles, feature names, foundation names — every terminology decision.

**See also.** memory: `feedback_name_from_user_side.md`.

---

## 7. Art First, Tour Optional

**Pattern.** Structure public-facing content so receipts stand alone. The narrative track is available but never required to understand the art. A visitor who wants the receipts walks in, sees the bytes, and leaves informed. A visitor who wants the story takes the tour when they choose.

**Examples.**
- Technical docs (`docs/architecture/`, subsystem tables, benchmarks) open with tables / numbers / code, not origin story
- Articles (`docs/articles/`) and philosophy (`philosophy.md`) live in separate doc families, not embedded in every technical page
- Cross-references point to the tour from the art ("for the *why*, see X") — never the reverse
- [`docs/architecture/kernel-layers.md`](architecture/kernel-layers.md) stands alone without requiring `philosophy.md` or the Temple framing to be useful
- Receipts (CSVs, git tags) are preserved in each ported repo — reproducible without reading any narrative

**Why.** Gating art on reading the tour turns a museum into a lecture hall. The Librarian displays the library; he doesn't force visitors to read his memoir before they can see the exhibits.

**See also.** memory: `feedback_art_first_tour_optional.md`, `feedback_articles_are_synthesis.md`, `feedback_personal_vs_technical.md`.

---

## 8. Pain → Procedure (Encode Lessons as First-Class)

**Pattern.** When a hardening step, workflow improvement, testing discipline, or review checkpoint surfaces as useful, promote it to first-class status immediately — memory, CLAUDE.md rule, workflow doc, or script. Don't leave it as a lesson learned.

**Examples.**
- **API-surface check** — originated in agnosys as `scripts/check-api-surface.sh`, propagated to cyrius as standard procedure
- **Port-feedback loop** — named after abaco → Cyrius `u64_mulmod`, now documented pattern (see Pattern 3)
- **Recipe audit** — *"never just bump version; audit ALL fields"* encoded after a specific near-miss
- **Build-check-before-tests** — encoded as `feedback_test_efficiency.md` after repeated pain
- **P(-1) Scaffold Hardening** — 7-step audit formalized in cyrius `CLAUDE.md`
- **Close-out procedures** — verify build, update changelog, check inbound references — each one exists because unsupervised drift went wrong once

**Why.** Without promotion, learnings bleed off. Next cycle, same mistake. Promotion prevents regression because the loop itself enforces the learning — same mechanism as automated tests preventing code regressions. The compound-interest effect across iterations only works when lessons become execution, not footnotes. Compounding is on *practice*, not just knowledge.

**See also.** memory: `feedback_promote_learnings.md`, `feedback_api_surface_check.md`, `feedback_recipe_audit.md`, `feedback_test_efficiency.md`.

---

## Patterns Yet to Add

Space for accretion. When a pattern surfaces in work and isn't covered above, add a stub here with the date and a pointer to context. Expand into a full section when material accrues.

*(no stubs yet — this doc begins 2026-04-20)*

---

## Relationship to Other Docs

| Layer | Doc | Answers |
|-------|-----|---------|
| Ideology | [`philosophy.md`](philosophy.md) | Why AGNOS exists at all |
| **Patterns (this doc)** | `design-patterns.md` | Why the decisions fit together as a system |
| Events | [`history.md`](history.md), [`timeline.md`](timeline.md) | What happened when |
| Per-decision | ADRs in each repo | Why *this specific* choice over alternatives |
| Specific argument | `docs/articles/*.md` | Thematic deep-dives on particular patterns |
| Per-release | `CHANGELOG.md` in each repo | What changed in v-N |
| Working rules | `CLAUDE.md` files | How to operate in each repo |
| Agent norms | `memory/*.md` | Cross-session behavioral directives |

Each layer has its own job. This doc is the through-line layer — the recurring moves that produced many of the per-decision choices and per-release changes.

---

*This outline will become the spine of the GA retrospective doc. Patterns added here during development become hindsight-framed at GA. The material accretes; the form finishes at release.*
