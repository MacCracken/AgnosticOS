# What v5.5.x Taught v5.6.x

> A micro-article. Pin for other articles to cite when they need the "lesson compounded forward" pattern — the discipline where one minor's postmortem becomes the next minor's codified process. Not receipts-driven; just the shape of how AGNOS absorbs its own engineering history.

---

## The v5.5.x shape

v5.5.x was the longest minor in Cyrius history — 40 patches. Platform-completion work: Windows PE native self-host, Apple Silicon Mach-O toolchain, aarch64 Linux shakedown, NSS/PAM end-to-end, parser/lexer refactor via nested includes, cc3 retirement. Every patch shipped something real; a fraction of them bundled more than one fix.

v5.6.x is shipping cleaner. The delta isn't that Cyrius got smarter — it's that two specific v5.5.x lessons got codified as process by the time the v5.6.x arc opened, rather than being re-discovered mid-flight.

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

## Related

- [cyrius roadmap v5.6.x + v5.7.x sections](https://github.com/MacCracken/cyrius/blob/main/docs/development/roadmap.md) — where the codification lives
- [design-patterns.md §8 Pain → Procedure (Encode Lessons as First-Class)](../design-patterns.md#8-pain--procedure-encode-lessons-as-first-class) — the master pattern
- [*Docs Go Stale Before the Commit*](docs-go-stale-before-the-commit.md) — a different instance of the same compounding-forward pattern (agent-era coordination docs)

---

*AGNOS project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
