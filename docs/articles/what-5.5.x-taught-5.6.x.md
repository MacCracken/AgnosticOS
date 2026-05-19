# What v5.5.x Taught v5.6.x

> A micro-article. Pin for other articles to cite when they need the "lesson compounded forward" pattern — the discipline where one minor's postmortem becomes the next minor's codified process. Not receipts-driven; just the shape of how AGNOS absorbs its own engineering history.
>
> **Article date**: late April 2026 (between v5.6.x close and v5.7.0 open, ~2026-04-25). Dates corrected against `cyrius` git tags 2026-05-15. Subsequent-cycle confirmations appended below.

---

## The v5.5.x shape

v5.5.x ran **40 patches in 3 days** (v5.5.0 cut 2026-04-20, v5.5.40 cut 2026-04-22). Platform-completion work: Windows PE native self-host, Apple Silicon Mach-O toolchain, aarch64 Linux shakedown, NSS/PAM end-to-end, parser/lexer refactor via nested includes, cc3 retirement. Every patch shipped something real; a fraction of them bundled more than one fix.

It was the **densest minor in Cyrius history at the time of writing** — not the longest in absolute days (3-day burst), and subsequent cycles have since exceeded the patch count (v5.6.x → .45, v5.7.x → .48, v5.8.x → .66, v5.10.x → .50, v5.11.x → .55). But v5.5.x's lessons codified forward.

v5.6.x shipped cleaner. The delta wasn't that Cyrius got smarter — two specific v5.5.x lessons got codified as process by the time the v5.6.x arc opened, rather than being re-discovered mid-flight.

## Lesson — single-focus-per-patch

The v5.7.x roadmap prose literally says: *"single-issue patches in v5.4.x / v5.5.x style — one focused fix per release, no grab-bags."* That line is a v5.5.x postmortem compressed to a sentence.

**Why it works**: each patch's CHANGELOG entry is one complete thought. Bisect narrows cleanly to the change that regressed. Grab-bag patches obscure which change caused which effect, which forces hand-reading diffs instead of using `git bisect run` — and that cost scales with the bug density of the minor.

**Why v5.5.x re-taught it**: the minor's initial slate was cleanly scoped, but platform-completion work surfaced surprises that tempted bundled patches ("fix X, and while we're here, also fix Y"). Each bundled patch that shipped became a harder bisect target on the next regression. By patch 25-ish, the discipline had been re-learned from the inside.

## Lesson — byte-identity scope split

v5.5.x surfaced two distinct invariants the earlier versions had conflated:

- **Narrow-scope byte-identity**: the three-step fixpoint `cc5_a → cc5_b → cc5_c; b == c`. Load-bearing. Verified on every commit by `check.sh`.
- **Broad-scope self-host**: target binary runs on native hardware and reproduces itself there. Platform confidence gate. Verified periodically on real hardware (ssh-pi, Apple Silicon, Windows 11).

These are different invariants with different cadences. Conflating them made v5.5.x feel broken whenever broad-scope regressed ("can't self-host on Pi!") when narrow-scope was actually green the entire time. The v5.6.x roadmap header now codifies the distinction explicitly, with per-platform pins for the broad-scope gates.

## Why this is process, not philosophy

Neither lesson is a new idea. Single-focus patches and layered invariant definitions are engineering folklore. The delta is that v5.5.x took both from *"things we'd nod at"* to *"things the prose of the next minor's roadmap explicitly codifies."*

That's [§8 Pain → Procedure](../design-patterns.md#8-pain--procedure-encode-lessons-as-first-class) in action. The pain was real; the procedure is the prose in the v5.6.x roadmap that reads like it was written by someone who'd just finished v5.5.x. Because it was.

## How to cite

When another AGNOS article wants to refer to:

- **Single-focus-per-patch discipline** → link to [§Lesson — single-focus-per-patch](#lesson--single-focus-per-patch)
- **Byte-identity scope split** → link to [§Lesson — byte-identity scope split](#lesson--byte-identity-scope-split)
- **The general "lesson compounds forward" pattern** → link to the page

---

## How the Pattern Compounded Forward

> Appended 2026-05-15. The two lessons above weren't a one-time codification — each subsequent Cyrius minor either repeated the discipline or extended it. The pattern's load-bearing because the receipts keep landing.

The cycle cadence below uses git-verified dates from `cyrius` tag refs. Patch counts are the highest patch number tagged within each minor; some minors have closed at higher numbers than reflected in older articles.

| Cycle | Opened | Closed | Patches | What the pattern looked like |
|---|---|---|---|---|
| v5.5.x | 2026-04-20 | 2026-04-22 | 40 | The lesson was *learned* mid-cycle (bundled-patch bisect cost surfaced ~patch 25) |
| v5.6.x | 2026-04-22 | ~2026-04-25 | 45 | The lesson was *codified* in the roadmap prose before patch 1 |
| v5.7.x | 2026-04-25 | 2026-04-30 | 48 | The TS work (cyrius-ts P1.3 through P2.7) showed single-focus discipline at sub-patch granularity — each `P<phase>.<step>` was a complete thought |
| v5.8.x | 2026-05-01 | 2026-05-05 | 66 | **66-in-4-days became the velocity record.** Discipline scaled — patches stayed single-focus even at >16/day cadence. Phase-based slot ordering (Phase 1 audit, Phase 2 vocabulary, Phase 3 foldin sweep) prevented bundling without slowing throughput |
| v5.9.x | 2026-05-06 | 2026-05-08 | 44 | Catchup arc — consumer-rollup of pin-lag bands. Each consumer-bump was its own patch; no "fix agnosys + vyakarana in one" temptation |
| v5.10.x | 2026-05-08 | 2026-05-10 | 50 | Three arcs (typed-simd ABI 11 phases / REAL TYPE SYSTEM 5 phases / struct-byval ABI 3 phases) interleaved without bundling. Each arc's phases were individually tagged |
| v5.11.x | 2026-05-11 | active | 55+ | 55 patches across 3 days (24+18+13). Stdlib annotation arc + consumer-issue closeout. Discipline held |

**What stayed constant across seven cycles**: every CHANGELOG entry has been one complete thought. `git bisect run` works against the cyrius tree because of that discipline.

**What evolved**: the byte-identity scope split codified in v5.5.x → v5.6.x became a *generic* pattern. By v5.8.x, the stdlib-fold-in framework explicitly captured the same kind of dual-invariant: "narrow-scope = does the fold compile and self-host" vs "broad-scope = does every consumer still build after the fold." Different domain, same lesson.

**Where the pattern showed its limits**: the iron-boot arc (Attempts 17–27, agnosticos `iron-nuc-zen-log-mvp.md`) burned 11 attempts on a single bug that turned out to be in a code path the prior research had already flagged as "post-MVP." The discipline that catches *bundled* patches doesn't catch *misplaced* patches. The premise-audit gate (codified in `feedback_known_knowledge_first` and `iron-bring-up-process.md`) is the third lesson in this lineage, extending the v5.5.x pattern into territory it didn't previously cover: not just "is this patch one thought" but "should this patch exist at all."

## Related

- [cyrius roadmap v5.6.x + v5.7.x sections](https://github.com/MacCracken/cyrius/blob/main/docs/development/roadmap.md) — where the codification lives
- [design-patterns.md §8 Pain → Procedure (Encode Lessons as First-Class)](../design-patterns.md#8-pain--procedure-encode-lessons-as-first-class) — the master pattern
- [*Docs Go Stale Before the Commit*](docs-go-stale-before-the-commit.md) — a different instance of the same compounding-forward pattern (agent-era coordination docs)
- [iron-bring-up-process.md § *The premise-audit gate*](../development/iron-bring-up-process.md) — the third lesson in the lineage

---

*AGNOS project — [agnosticos.org](https://agnosticos.org)*
*April 2026 (original); appended 2026-05-15 with seven-cycle compounding-forward receipts*
