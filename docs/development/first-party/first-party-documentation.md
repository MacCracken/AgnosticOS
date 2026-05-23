# First-Party Documentation Standards

> **Status**: Active | **Last Updated**: 2026-04-23
>
> Companion to [first-party-standards.md](first-party-standards.md). The standards doc governs *code* conventions; this doc governs the `docs/` tree, the root-level docs, and CLAUDE.md. Every AGNOS first-party repo follows both.
>
> **Reference implementation**: [sit](https://github.com/MacCracken/sit) — minimal scaffold with the full pattern (ADR 0001, architecture note 001, README / CLAUDE.md / CHANGELOG at root).

---

## Doc Layer Map

Each artifact answers a different question. Writing in the wrong layer is the most common docs mistake — a decision rationale buried in a guide, or a constraint captured in a changelog, both rot faster than the code.

| Layer | Lives in | Answers |
|---|---|---|
| Decision | `docs/adr/NNNN-*.md` | *Why did we choose X over Y?* |
| Proposal (pre-decision) | `docs/proposals/*.md` | *Here's a design to evaluate — should we adopt it?* |
| Architecture note | `docs/architecture/NNN-*.md` | *What non-obvious constraint is true about the code?* |
| Architecture overview | `docs/architecture/overview.md` or `docs/architecture.md` | *What's the system-level module map and data flow?* |
| Guide | `docs/guides/*.md` | *How do I do X?* |
| Tutorial | `docs/tutorial.md` | *How do I learn this from zero?* |
| Example | `docs/examples/` | *What does working code look like?* |
| API reference | `docs/api/` | *What's every public symbol, with signatures and semantics?* |
| Source citation | `docs/sources/` or `docs/sources.md` | *Where does this algorithm/formula/constant come from?* |
| Roadmap | `docs/development/roadmap.md` | *What's done, next, and future?* |
| Current state snapshot | `docs/development/state.md` | *What's the live status right now (version, tests, blockers)?* |
| Doc-health ledger | `docs/doc-health.md` | *Which docs are fresh / stale / archive / open-question, and when were they last touched?* (Lives at `docs/` root, not under `development/` — its scope is the whole `docs/` tree plus root files.) |
| Sprint-tagged dev log | `docs/development/sprint-history.md` | *What did each named sprint cover?* (genesis-style time-bound prose; `CHANGELOG.md` covers per-tag chronology) |
| Known issues / backlog | `docs/development/issues/` | *What's broken, deferred, or under investigation?* |
| Process notes | `docs/development/process-notes.md` | *How does dev on this repo actually work day-to-day?* |
| Migration strategy | `docs/development/migration-*.md` | *How do we move from state A to state B across releases?* |
| Threat model | `docs/development/threat-model.md` or `docs/security/` | *What are we defending against, and how?* |
| Security audit | `docs/audit/YYYY-MM-DD-audit.md` | *What did the pre-release audit find, and what was fixed?* |
| Benchmark history | `docs/benchmarks.md`, `docs/benchmarks-rust-v-cyrius.md`, or `BENCHMARKS.md` | *How has perf moved across versions?* |
| Performance notes | `docs/development/performance.md` | *Where are the hot paths, what's been optimized, what's next?* |
| External standards | `docs/standards/` | *What external specs does this project implement?* |
| Compliance | `docs/compliance/` | *What regulatory / licensing / cert status does this have?* |
| FAQ | `docs/faq.md` | *What do people keep asking that isn't covered elsewhere?* |
| Docs landing | `docs/index.md` or `docs/README.md` | *Where do I start reading the docs?* |
| Changelog | `CHANGELOG.md` (root) | *What changed in version N?* |
| Project identity | `CLAUDE.md` (root) | *What is this repo and how do I work in it?* |
| Reader landing page | `README.md` (root) | *What does this do, why would I use it, how do I start?* |
| Article (narrative-owning repos) | `docs/articles/` | *What's the newsworthy milestone story?* |

If a new note doesn't fit cleanly into one of these, pause and ask where it belongs before inventing a category. Inventing a new top-level `docs/` subdir should be a deliberate decision, not a reflex — prefer reusing an existing layer or proposing a new one in an ADR.

---

## Required Root Files

Every repo ships these before its first tag:

```
README.md            # Landing page — what / why / quick start / install
CHANGELOG.md         # Keep a Changelog format — one section per version
CLAUDE.md            # Agent instructions (see "CLAUDE.md" below)
CONTRIBUTING.md      # How to contribute
SECURITY.md          # Security policy and reporting
CODE_OF_CONDUCT.md   # Code of conduct
LICENSE              # GPL-3.0-only (AGPL-3.0-only for desktop GUIs)
```

All seven are scaffolded by `cyrius init` — do not hand-roll them. If a template change is needed, fix `cyrius init`, then re-propagate.

---

## `docs/` Tree

Minimum layout every repo carries from day one:

```
docs/
├── adr/                              # Architecture Decision Records
│   ├── README.md                     # Index + conventions
│   ├── template.md                   # Copy this to start a new ADR
│   └── NNNN-kebab-case-title.md
├── architecture/                     # Non-obvious invariants / quirks
│   ├── README.md                     # Index + conventions
│   └── NNN-kebab-case-title.md
├── guides/                           # Task-oriented how-tos
│   └── getting-started.md
├── examples/                         # Runnable examples (may be empty early)
└── development/
    └── roadmap.md                    # Versioned milestones through v1.0
```

Optional subtrees — add when earned, name consistently with the patterns below:

```
docs/
├── api/                              # Curated or generated API reference
│   └── README.md                     # Index per module/public surface
├── audit/                            # Security audit reports
│   └── YYYY-MM-DD-audit.md
├── compliance/                       # Regulatory / licensing / cert docs
├── development/
│   ├── issues/                       # Known bugs / deferred work (one file per issue)
│   ├── migration-*.md                # Cross-version migration strategy
│   ├── performance.md                # Hot paths, wins, remaining targets
│   ├── process-notes.md              # Day-to-day workflow specifics
│   ├── sprint-history.md             # Time-bound dev log (genesis-style)
│   ├── state.md                      # Current live status snapshot
│   └── threat-model.md               # What we defend against
├── proposals/                        # Pre-ADR design drafts under discussion
├── security/                         # Security architecture (if broader than threat-model.md)
├── sources/                          # Per-module academic citations (science/math)
├── sources.md                        # Single-file citation index
├── standards/                        # External specs this project implements
├── articles/                         # Narrative-owning repos only
├── benchmarks.md                     # Benchmark history (native repos)
├── benchmarks-rust-v-cyrius.md       # Port perf comparison (ported crates)
├── faq.md                            # Recurring questions with durable answers
├── index.md                          # Docs landing page (when docs/ grows past the minimum)
└── tutorial.md                       # Zero-to-working learning path
```

**Naming consistency rules**:

- Numbered series use zero-padding and **never renumber**: `adr/NNNN-*`, `architecture/NNN-*`, `audit/YYYY-MM-DD-*`.
- Every numbered-series directory ships a `README.md` index with a one-line hook per entry.
- Kebab-case for all filenames. No underscores, no CamelCase.
- `docs/development/` is the home for *how the work happens*; `docs/architecture/` is the home for *how the code is*; `docs/adr/` is the home for *why the code is that way*. Don't cross the streams.

---

## Architecture Decision Records (ADRs)

Capture *why not the other thing*. If a future reader will reasonably ask "why did we do it this way?", the answer belongs in an ADR, not a commit message.

**Conventions** (mirrored in [sit's docs/adr/README.md](https://github.com/MacCracken/sit/blob/main/docs/adr/README.md)):

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. **Never renumber.**
- **One decision per ADR.** Supersessions add a new ADR and mark the old one `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use `docs/adr/template.md` as the starting point.
- Index them in `docs/adr/README.md` with a one-line hook per ADR.

**Template sections** (see [sit's template.md](https://github.com/MacCracken/sit/blob/main/docs/adr/template.md)):

1. **Status** + **Date**
2. **Context** — what forces a decision; the reader wasn't in the room
3. **Decision** — one-sentence headline, then scope (what's in, what's out)
4. **Consequences** — positive / negative / neutral follow-ons
5. **Alternatives considered** — paths not taken, and why each lost

**When to write an ADR**: competing approaches with real trade-offs, adopting or rejecting a dependency, changing a public API, accepting a performance or portability trade-off. If the decision could credibly have gone the other way, write the ADR.

**Gold standard**: [sit 0001 — No FFI, first-party only](https://github.com/MacCracken/sit/blob/main/docs/adr/0001-no-ffi-first-party-only.md).

---

## Architecture Notes

Invariants, constraints, and quirks that a reader **cannot derive from the code alone**. These are *how the world is*, not *what we chose*.

**Conventions** (mirrored in [sit's docs/architecture/README.md](https://github.com/MacCracken/sit/blob/main/docs/architecture/README.md)):

- **Filename**: `NNN-kebab-case-title.md`, zero-padded to three digits. **Never renumber.**
- Numbered chronologically in order of discovery.
- Not a decision (that's an ADR), not a how-to (that's a guide). An architecture note documents reality.
- Index them in `docs/architecture/README.md` with a one-line hook per note, including **what it affects** so readers skimming the index can tell if it matters to their work.

**What belongs here**:

- Stdlib quirks the project relies on (see [sit 001 — `args.cyr` post-return stack memory](https://github.com/MacCracken/sit/blob/main/docs/architecture/001-args-stack-buffer-lifetime.md)).
- Cross-module invariants enforced by convention, not by the compiler.
- Ordering requirements, lifetime assumptions, memory-layout assumptions.
- "Don't touch X without reading Y first" warnings.

**What does NOT belong here**: bug reports (use the issue tracker), TODOs (use code comments or roadmap), narrative prose (use articles).

---

## Proposals (Pre-ADR)

When a design is still under active discussion and not yet a decision, it lives in `docs/proposals/`. This is the notebook before the ADR.

- **Filename**: `kebab-case-title.md` — no numbering, since proposals may be abandoned, merged, or promoted into an ADR.
- A proposal graduates by being accepted into an ADR (same number series as other ADRs) and then **deleted** from `proposals/`, or by being rejected and deleted.
- If a proposal sits in `proposals/` for more than one release cycle without being resolved, it's stale — either promote it to an ADR, reject it, or reopen it with a fresh dated revision.
- Proposals are not a dumping ground for TODOs or vague ideas. If it can't be argued for/against in concrete terms, it isn't a proposal.

---

## Guides

Task-oriented. Every guide answers one question with a reproducible sequence of steps.

- `docs/guides/getting-started.md` is universal — it covers build, test, and the minimum working invocation.
- Additional guides earn their spot: integration with a specific consumer, migration between versions, common operational tasks.
- Guides may link to examples; don't inline runnable code that also exists in `docs/examples/`.

---

## Tutorials (Optional, Distinct from Guides)

A tutorial teaches a concept from zero and makes the reader competent. A guide assumes context and gets them from A to B.

- Most repos don't need one — a good `getting-started.md` guide plus `README.md` covers onboarding.
- Languages, compilers, editors, and major subsystems with teachable concepts *do* need one: e.g. `docs/tutorial.md` in the Cyrius repo.
- If a repo has both, the tutorial is the long-form "learn" path and the guides directory is the short-form "do" path. Link them reciprocally.

---

## Examples

Working code, not prose. Every public API should have at least one example once the API stabilizes.

- **Cyrius**: `docs/examples/*.cyr` — runnable via `cyrius run`.
- Early-stage repos may have an empty `docs/examples/` with a README placeholder — that's fine; backfill as the API surface grows.
- Every example has a top-of-file comment explaining *why*, not just *what*.

---

## API Reference

Curated or generated surface documentation for public symbols. Lives in `docs/api/`.

**When to create it**: when the crate has downstream consumers and its API surface is large enough that grepping is worse than reading. Small library crates can skip `docs/api/` and rely on inline doc comments plus `docs/examples/`.

**Structure**:

- `docs/api/README.md` — index of modules, one-line hook per module.
- `docs/api/<module>.md` — public types, public functions, public constants. Each entry has a signature, a one-paragraph semantic description, and a link to a concrete example if one exists.
- Generated API docs (where available) go in `docs/api/generated/` and are regenerated by CI. Never hand-edit generated files.

**API reference vs. guides**: reference describes *what exists*; guides describe *how to use it*. Don't duplicate. If a guide and a reference both describe the same thing, one of them is the wrong shape.

**Stability note**: a symbol listed in `docs/api/` is a stability commitment proportional to the version number (pre-1.0 = experimental; 1.0+ = SemVer-stable). Removing or breaking a listed symbol means an ADR and a `Breaking` CHANGELOG entry.

---

## Development Docs (`docs/development/`)

The home for *how the work happens on this repo*. Distinct from `docs/architecture/` (code invariants) and `docs/adr/` (decision rationale).

**Required**:

- **`roadmap.md`** — versioned milestones. Lists *Completed*, *In Progress / Backlog*, *Future*, and *v1.0 Criteria*. Updated every release.

**Added when earned**:

- **`state.md`** — current live status snapshot. Cheap substitute for "what's going on right now?" Always reflects the tip of the branch — update it in the same PR that changes the state.
- **`docs/doc-health.md`** (note: at `docs/` root, **not** under `development/`) — fresh / stale / archive / open-question ledger across the whole doc tree. Pattern parallels `state.md` (state.md = code-state ledger; doc-health.md = doc-state ledger). Refreshed in place when docs are touched. Worth scaffolding once a repo has more than ~30 docs or any meaningful drift surface; smaller repos can defer until the surface justifies it. Earn it before you create it — but the convention is the same wherever it lands: `> **Last refresh**: YYYY-MM-DD | **Refresh cadence**: ...` header, tier tables (root files / development / articles / etc.), buckets (✅ Fresh / 🟡 Stale / 🟠 Read-through / 🔵 Evergreen / 📦 Archive). **Location matters**: it goes at `docs/doc-health.md`, not `docs/development/doc-health.md` — the ledger sweeps the whole tree and the location should match the scope.
- **`sprint-history.md`** — time-bound dev log for repos that work in named sprints (genesis pattern). The previous `completed-phases.md` pattern is **retired** ecosystem-wide as of 2026-05-21 — it relitigated `CHANGELOG.md` per-tag chronology. New repos do not scaffold it; existing repos (incl. cyrius) are slowly phasing it out. Per-tag chronological "what shipped" → `CHANGELOG.md`. Named-sprint narrative across multiple tags → `sprint-history.md` (genesis-style only — most repos don't need this either).
- **`issues/`** — one file per known-but-deferred issue. Complements the GitHub issue tracker when an issue needs durable, in-repo prose (design context, rejected fixes, invariants to preserve).
- **`migration-*.md`** — per-migration strategy docs, e.g. `migration-strategy.md`, `migration-rust-to-cyrius.md`. Each covers source state, target state, steps, and verification.
- **`performance.md`** — where the hot paths are, what's been optimized (with numbers), what's next. Links to benchmark history.
- **`process-notes.md`** — repo-specific dev practices. "How we format commits", "how we handle the release dance", etc. Not global policy (that lives here) — just what's true of this repo.
- **`threat-model.md`** — what the project defends against, trust boundaries, known non-goals. For deep security-domain crates (phylax, kavach, sigil), `docs/security/` with multiple files is appropriate.
- **`benchmarks.md`** — native crate perf history. Rust-ported crates use `benchmarks-rust-v-cyrius.md` at `docs/` root instead.

**Non-goal**: `docs/development/` is not a dumping ground for anything development-adjacent. If it could go in `docs/architecture/`, `docs/adr/`, or `docs/guides/`, it goes there instead.

---

## Security and Audit Docs

Two overlapping but distinct concerns:

- **`docs/audit/YYYY-MM-DD-audit.md`** — output of a security audit pass. Every project runs one before release (see [first-party-standards § Security Hardening](first-party-standards.md#security-hardening-new--required-before-every-release)). Each audit file records findings by severity, fixes, and anything carried forward.
- **`docs/development/threat-model.md`** — the model the audits check against. What's in scope, what's out, trust boundaries, attack surface.
- **`docs/security/`** — used when threat-model and related content outgrow a single file. Multiple files indexed by `docs/security/README.md`. Most repos don't need this level; security-domain repos do.

**SECURITY.md at root** — the public reporting policy. Separate from the in-repo security docs above. SECURITY.md is for external reporters; `docs/audit/` and `docs/security/` are for implementers.

---

## Benchmarks and Performance Docs

Three patterns, pick one per repo:

- **`BENCHMARKS.md` at root** — short, top-level perf summary (release artifact format).
- **`docs/benchmarks.md`** — native-crate perf history with version-over-version comparisons.
- **`docs/benchmarks-rust-v-cyrius.md`** — ported-crate perf comparison against the Rust predecessor (see `rust-old/` preservation in [first-party-standards](first-party-standards.md#porting-a-rust-project-to-cyrius)).

Performance *prose* (hot paths, optimization plan, remaining targets) lives in `docs/development/performance.md`. Performance *numbers* live in the files above or in CSV alongside them. Don't mix: the numbers file is machine-readable, the prose file is human-readable.

---

## External Standards and Compliance

- **`docs/standards/`** — external specifications this project implements. One file per spec: link to the spec, pin the version, document any deviations. Examples: an MCP implementation pins the MCP spec; a codec implementation pins the ISO/IETF document.
- **`docs/compliance/`** — regulatory, licensing, or certification status. Audit results, cert IDs, known limitations. Only used when there's real external compliance to track.

Both are opt-in. Most repos have neither.

---

## FAQ and Docs Landing

- **`docs/faq.md`** — recurring questions with durable answers. Not a dumping ground for one-off support; an entry earns its spot by being asked more than once. Prune stale entries aggressively.
- **`docs/index.md`** or **`docs/README.md`** — docs landing page. Only create one when `docs/` is large enough that readers need a starting pointer. For most repos, the root `README.md` plus `docs/guides/getting-started.md` covers it.

---

## Source Citations (Science / Math / Domain Crates)

Mandatory for crates implementing scientific, mathematical, financial, or domain-specific algorithms. No magic numbers. No undocumented formulas.

**In code** — inline citation on the declaring item:

```cyrius
# Rosenberg glottal pulse model.
# Source: Rosenberg, A.E. (1971). "Effect of Glottal Pulse Shape on the
# Quality of Natural Vowels." J. Acoust. Soc. Am., 49(2B), 583-590.
# doi:10.1121/1.1912389
fn glottal_pulse(t: f64, tp: f64, tn: f64) -> f64 { ... }
```

**In docs** — `docs/sources.md` (or `docs/sources/` for large crates with per-module files):

- Every paper, textbook, and specification the crate draws from.
- URL to a freely available version where possible.
- Which module or function uses each source.
- Why this source was chosen over alternatives.

**The bar**: a reviewer unfamiliar with the domain should be able to trace any algorithm back to its published origin and verify the implementation against it.

---

## CHANGELOG

Follow [Keep a Changelog](https://keepachangelog.com/). One section per released version, most recent first.

- **Performance claims must include benchmark numbers.** "5× faster" unaccompanied is not acceptable; "5.2× faster (324ms → 62ms, measured by `scripts/bench-history.sh`)" is.
- **Breaking changes get a `Breaking` subsection** with a migration paragraph. Never slip a breaking change into `Changed`.
- **Security fixes get a `Security` subsection** and, for CVE-severity issues, a pointer into `docs/audit/`.
- An `[Unreleased]` section at the top collects in-flight changes; the release workflow renames it at tag time.

The CHANGELOG is the audit trail. Don't skip a version, don't rewrite history, don't compress multiple releases into one section.

---

## CLAUDE.md

Every repo root carries a `CLAUDE.md`. It's read at the start of every agent session.

**The core rule**: CLAUDE.md is **preferences, process, and procedures** — durable rules that change rarely. Volatile state (current version, sizes, in-flight slots, recent releases, consumers, verification hosts, bootstrap chain) does **not** belong in CLAUDE.md. It belongs in [`docs/development/state.md`](#development-docs-docsdevelopment), refreshed every release and ideally bumped by the release post-hook. CLAUDE.md reads the same across a whole minor series; `state.md` moves every tag.

**Reference implementation**: [cyrius/CLAUDE.md](https://github.com/MacCracken/cyrius/blob/main/CLAUDE.md) is the standard as of 2026-04-23 — it shows the durable-vs-volatile split with a short pointer block where "Current State" used to live. [sit/CLAUDE.md](https://github.com/MacCracken/sit/blob/main/CLAUDE.md) is the minimal-scaffold analogue for young repos that don't yet have enough state to justify an external `state.md`.

**Template**: [example_claude.md](example_claude.md). Copy, fill in, add project-specific rules.

**Required sections** (durable content only):

1. **Project Identity** — name + etymology, type, license, language + toolchain pin, version-file pointer, genesis-repo link. No version number inlined here if the `VERSION` file is the source of truth — reference the file, don't duplicate the number.
2. **Goal** — one paragraph on what this repo owns. Changes rarely.
3. **Current State (pointer block)** — a short block pointing to `docs/development/state.md` for volatile state and `CHANGELOG.md` for historical release narrative. **Do not inline state here.** See [cyrius/CLAUDE.md#current-state](https://github.com/MacCracken/cyrius/blob/main/CLAUDE.md) for the pattern.
4. **Quick Start** — the 3–7 commands that get a new contributor from clone to built-and-tested. Durable; these commands don't change per release.
5. **Key Principles / Rules** — at minimum: *read genesis `CLAUDE.md` first*, *never use `gh` CLI*, *do not commit or push*, plus build-tool rules and any domain-specific invariants ("self-hosting is non-negotiable", "own the stack", "no magic", etc.).
6. **Process (P(-1), closeout, release, etc.)** — the procedures the project runs on. Durable.
7. **Scaffolding note** — "project was scaffolded with `cyrius init` / `cyrius port`; don't manually create structure — use the tools." One line.
8. **Docs pointer** — one-line hooks for `docs/adr/`, `docs/architecture/`, `docs/guides/`, `docs/examples/`, and any other doc subtrees this repo uses.

**What does NOT belong in CLAUDE.md** (moves to `docs/development/state.md` or a sibling):

- Current version number, compiled binary sizes, lines-of-code counts.
- In-flight work, "recently shipped" lists, active-sprint pointers.
- Consumer lists, verification-host lists, bootstrap-chain state.
- Test counts, assertion counts, coverage percentages.

Any of these in CLAUDE.md will be stale within a release. The pointer block is shorter, durable, and points at a file the release hook keeps current.

**Per-project additions**: domain principles ("own the stack", "no magic", "self-hosting is non-negotiable", etc.). Keep additions concrete and durable — "follow sigil naming" beats "be consistent."

**Hard rules**:

- **CLAUDE.md reflects durable truth.** If a claim in CLAUDE.md drifts by more than a minor version's worth of work, either move the claim to `state.md` or delete it.
- **`state.md` reflects live truth.** Bumped every release. The release post-hook should touch it; if it doesn't, fix the hook.
- **Stale CLAUDE.md is worse than no CLAUDE.md** — it actively misleads.

---

## Articles (Narrative-Owning Repos Only)

`docs/articles/` is a genesis-repo and major-subsystem pattern, not a universal requirement. Most library repos don't have one.

**When articles make sense**: a repo owns a public-facing narrative arc — AGNOS genesis (sovereignty thesis, port receipts, milestones), a language compiler release arc, a major subsystem with press-level milestones.

**What articles are**:

- **Newsworthy milestone captures.** One article = one press-level moment with one hook.
- **Synthesis, not time capsule.** Compress to the essential claim. Granular per-session detail belongs in field notes (e.g., `vidya/content/<project>/field_notes.toml`), not in articles.
- **Engineering evidence only.** Receipts, benchmarks, commits, concrete artifacts.

**What articles are NOT**:

- Comprehensive project scope (roadmap does that).
- Running dev journal (CHANGELOG does that).
- Personal philosophy, creative framing, or author-facing narrative. Those live in their own tracks and stay separate from the engineering record.

**Filename convention**: `kebab-case-hook.md`. The filename is the hook.

### "Since This Was Written" footer pattern

Articles are dated artifacts — they describe a state at the moment of writing. As the underlying state moves (kernel size, port count, Cyrius cycle), the body becomes a **time capsule**, not a current claim. Two refresh patterns are valid:

- **In-place body refresh** — only when the article *is* about the current state (registries, indexes, status pages). Update inline; rewrite-in-place per *Docs Go Stale Before the Commit*.
- **"Since This Was Written" footer** (preferred for narrative articles) — keep the body as the dated record; append a footer noting what's changed. Pattern:

  ```markdown
  ## Since This Was Written

  **Refreshed YYYY-MM-DD — N weeks past the original cut.** Body figures above are the [original date] snapshot. Rewrite-in-place per *Docs Go Stale Before the Commit* — git history is authoritative for prior figures.

  - **<subsystem>** — what changed since the body
  - **<thing>** — what changed since the body
  - ...

  Live ecosystem state in [`docs/development/state.md`](...).
  ```

  This preserves the article's voice and dated framing while keeping reader-context current. Used in `the-2-dollar-sd-card.md`, `python-in-the-bootstrap.md`, `sovereign-compiler-vs-brute-force.md`, `memory-should-be-sovereign-too.md`, `why-gpu-belongs-in-the-stdlib.md`, etc. (2026-05-06 audit).

  When the footer grows long enough that it eclipses the body, that's a signal to write a successor article instead — not to keep extending the footer.

### "Last Updated" header convention

Inconsistent across the genesis repo today. The convention going forward:

- **Operational and reference docs** (anything in `docs/` other than `archive/` and `articles/`): `> **Last Updated**: YYYY-MM-DD` in the top header block, immediately under `# Title`. Make it visible to readers landing on the doc.
- **Articles**: `*Author Name* / *AGNOS Project — [agnosticos.org](...)* / *Month YYYY*` footer. Add `(refreshed footer Month YYYY)` if the body was preserved but a "Since This Was Written" footer was added.
- **Archive docs**: keep the header date the doc was written; add `(ARCHIVED — short reason)` to the title.
- **Living-state docs** (`state.md`, `doc-health.md`, etc.): `> **Last refresh**: YYYY-MM-DD | **Refresh cadence**: ...` in header. The cadence note is load-bearing — it sets reader expectations.
- **CHANGELOG**: per-entry dates only; no global "Last Updated" — the topmost entry's date *is* the last-updated.

When in doubt, top header. The footer convention from older articles persists for backward compatibility but new docs should put it up front where it's read.

---

## What Goes In Which File

Quick reference for when an agent is about to write the wrong kind of doc:

| The thing you want to capture | Goes in |
|---|---|
| *"I chose X because Y"* | `docs/adr/NNNN-*.md` |
| *"Here's a design to argue through before we commit"* | `docs/proposals/*.md` |
| *"Watch out — Z is true and not obvious"* | `docs/architecture/NNN-*.md` |
| *"Here's the system-level module map"* | `docs/architecture/overview.md` |
| *"To do the thing, run these commands"* | `docs/guides/*.md` |
| *"Teach me from zero"* | `docs/tutorial.md` |
| *"Here's working code that uses the API"* | `docs/examples/` |
| *"Every public symbol with signatures and semantics"* | `docs/api/` |
| *"This formula comes from Paper P"* | source citation (inline + `docs/sources.md`) |
| *"What's shipped, next, and future"* | `docs/development/roadmap.md` |
| *"What's the current status right now"* | `docs/development/state.md` |
| *"Which docs are fresh / stale / archive"* | `docs/doc-health.md` (whole-tree ledger; lives at `docs/` root, not under `development/`) |
| *"What's already shipped, chronologically"* | `CHANGELOG.md` (per-tag) or `sprint-history.md` (genesis-style sprint prose) |
| *"Here's a deferred bug with design context"* | `docs/development/issues/*.md` |
| *"How the work actually happens on this repo"* | `docs/development/process-notes.md` |
| *"How we move from state A to state B"* | `docs/development/migration-*.md` |
| *"What we defend against"* | `docs/development/threat-model.md` or `docs/security/` |
| *"What the audit found, and what was fixed"* | `docs/audit/YYYY-MM-DD-audit.md` |
| *"How perf has moved across versions"* | `docs/benchmarks.md` or `docs/benchmarks-rust-v-cyrius.md` |
| *"Where the hot paths are and what's next"* | `docs/development/performance.md` |
| *"External spec this project implements"* | `docs/standards/` |
| *"Cert status, licensing obligations"* | `docs/compliance/` |
| *"People keep asking this"* | `docs/faq.md` |
| *"Where to start reading the docs"* | `docs/index.md` (or root `README.md` for small repos) |
| *"In version 2.1 we added feature F"* | `CHANGELOG.md` |
| *"This is what this repo is and how to work in it"* | `CLAUDE.md` |
| *"Here's a one-paragraph pitch for a newcomer"* | `README.md` |
| *"This is a landmark milestone worth a public story"* | `docs/articles/` (if this repo owns a narrative arc) |
| *"How to report a vulnerability"* | `SECURITY.md` (root) |

When in doubt, default to the smaller / more specific layer and let it graduate upward if a pattern emerges across multiple instances. Inventing a new top-level `docs/` subdir is an ADR-worthy decision — don't do it silently.

---

## Cross-References

- [first-party-standards.md](first-party-standards.md) — code conventions, versioning, licensing, CI/CD, testing, benchmarking, MCP/daimon integration, marketplace recipes. The *code* side of first-party standards.
- [example_claude.md](example_claude.md) — CLAUDE.md starting template.
- [shared-crates.md](shared-crates.md) — crate registry (what exists, at what version, who consumes it).
- [roadmap.md](roadmap.md) — agnosticos-level roadmap.

---

*Last Updated: 2026-05-21 (`completed-phases.md` pattern retired — it relitigated `CHANGELOG.md`; sprint-history.md remains the genesis-style alternative when named-sprint prose adds value beyond per-tag chronology)*
