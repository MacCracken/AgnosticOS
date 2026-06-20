# Your CLAUDE.md Isn't Lying. You're Skimming.

> *Refusal as Architecture, applied to your prompt context. Discipline the surface you have — don't add another extension point.*

---

## TL;DR

- A meetup talk titled *"Your CLAUDE.md Is Lying to You"* hit the inbox on April 24, 2026, claiming Claude Code ignores carefully-written instructions ~30% of the time and pitching a plugin as the fix. The 30% number is plausibly real. The plugin is the wrong answer.
- **The actual problem**: `CLAUDE.md` is one layer of a five-layer surface (`CLAUDE.md` / `state.md` / `memory/` / `ADRs` / `docs/`). Collapse the layers into one bloated file and you get the wishlist problem — long, contradictory, half-stale, half-aspirational. The agent skims it, and skimming an inconsistent document is indistinguishable from ignoring it.
- **The skim is real**. LLMs allocate attention non-uniformly even on loaded context. Mitigation isn't another extension point — it's structural discipline at the existing surface, plus active re-read prompts at task boundaries.
- **The plugin anti-pattern** is the same shape as every other refusal in this stack: another build system, another middleware layer, another framework on top. The AGNOS pattern is the inverse — make the layer you already have load-bearing.
- **Live receipt**: this article was written in a session where CLAUDE.md + memory + ADRs coordinated a multi-domain decision (commission negotiation + corporate-structure pin + co-principal framing) without lying about anything. The same surface caught the agent in two factual errors mid-flow and pinned four corrected memory entries before the meetup talk's RSVP window closed.

---

## The Talk

> *"Claude Code ignores your carefully written instructions about 30% of the time — not because it's broken, but because you're using the wrong extension point."*

That's the pitch. The fix on offer is a plugin — *"a plugin for my team to tame Claude Code."*

The number is honest. The agent does drop instructions, often. Three things cause it more reliably than any other:

1. **The CLAUDE.md is a wishlist, not a contract.** Every preference, every scrap of state, every aspirational rule, every once-true note about a now-removed module — all in one file, never trimmed. The agent loads the whole thing, then has to weigh which lines are still operative and which are dead. Skim-bias picks the most prominent.
2. **State is inlined.** Versions, file sizes, port-status checkboxes, in-flight slot lists. The numbers are wrong by the next session. The agent hits a contradiction (CLAUDE.md says "v5.5.10," `git log` says "v5.5.27") and has to guess which surface to trust.
3. **No active re-read at task boundaries.** The agent loads CLAUDE.md once at session start. Forty messages later, when it's about to do the thing CLAUDE.md said not to, the rule lives in long-context. Long-context attention is uneven. The agent skims — even on its own loaded preface.

A plugin doesn't fix any of these. A plugin adds another extension point with its own bloat, its own staleness window, its own attention budget. You now have CLAUDE.md *and* the plugin, and the plugin's instructions also get skimmed.

The fix is structural, not bolted-on.

---

## The Five-Layer Surface

`CLAUDE.md` is a layer, not a destination. Treating it as the only place rules go is what produces the bloated-wishlist failure mode. AGNOS uses five layers; each has a specific job, each has a different lifecycle:

| Layer | Lifecycle | Job |
|-------|-----------|-----|
| `CLAUDE.md` | Durable; rewritten across major releases | Preferences, process, procedures, invariants ("read this first," "never use `gh`," "do not commit") |
| `docs/development/state.md` | Volatile; bumped by release post-hook | Current version, sizes, in-flight slots, recently-shipped lists |
| `~/.claude/.../memory/` (auto-loaded per session) | Mostly durable; trimmed when entries go stale | Behavioral feedback, project decisions, cross-session context |
| `docs/adr/NNNN-*.md` | Append-only; supersession via new ADR | Per-decision artifacts: why *this specific* choice |
| `docs/architecture/`, `docs/philosophy.md`, `docs/articles/` | Long-form; revised on milestone cadence | Architecture overview, ideology, thematic deep-dives |

When all five collapse into one CLAUDE.md, the file rots fast (state changes every release), self-contradicts (durable rules sit next to volatile facts), and bloats (every architectural decision lands as another bullet). The agent's skim is then the rational move: *most of what's here is no longer load-bearing, and I have no way to tell which lines are.*

When the layers are separated:

- CLAUDE.md stays under ~5K tokens of *durable* rules
- `state.md` carries the version numbers and gets re-read by hook on release
- Memory files live in their own files indexed by `MEMORY.md` (one line per entry, the index itself stays under context-limit)
- ADRs accumulate without disturbing the live-load surface
- Articles synthesize for a different audience (publishable; not session-coordination)

The agent isn't asked to keep five layers in working memory simultaneously. It's asked to follow the index pointers and re-read the relevant layer when the task hits its boundary.

That's the structural fix.

---

## The Skim Is Real (And Mitigatable)

A long-context LLM does not allocate attention uniformly. Material near the start of context, material near the most recent turn, and material that was emphasized via repetition or explicit invocation gets disproportionate attention. Older middle-of-context material gets less.

This is a known property of the architecture, not a bug to be patched out. Any prompt-discipline practice has to assume it.

Three mitigations work in production:

**1. Keep CLAUDE.md tight.** Below ~3-5K tokens, durable-rule density is high enough that skim-bias still hits the right material. Over that, the file is failing as a contract.

**2. Use index pointers (the MEMORY.md pattern).** A single index file with one-line pointers per memory ensures the index itself loads cleanly. Detail lives in linked files that the agent reads only when relevance triggers — instead of stuffing every memory into the always-loaded preface.

**3. Active re-read at task boundaries.** *The LLM will not re-read CLAUDE.md unprompted.* If a task is about to violate a CLAUDE.md rule, the agent's loaded copy is too old to catch it. The fix is explicit: *"Read the testing section of CLAUDE.md before running these tests."* *"Re-read the release procedure in CLAUDE.md before opening the PR."* Slash commands that bundle re-reads with workflows are the operational form of this — Claude Code's `/init` skill, for example, is a re-read of project structure before any new-project work begins.

Hooks (`settings.json` entries that fire shell commands on tool-use events) are the automated form. A `PreToolUse` hook that re-injects the relevant slice of CLAUDE.md before a `git commit` tool call runs is doing the same thing the human would otherwise have to remember to prompt.

**The remind-Claude-to-review pattern is the practical user takeaway.** Don't expect once-loaded context to govern long sessions. At every task boundary that depends on a specific durable rule, prompt the re-read. *This works. A plugin doesn't replace it; the plugin would also need to be re-read.*

---

## The Plugin Anti-Pattern

The talk's solution shape — *"build a plugin to tame Claude Code"* — has the same architectural problem as every other multiply-layers solution this project has refused.

| Domain | Inherited "fix" | AGNOS refusal |
|--------|-----------------|---------------|
| Compiler | Use LLVM | First-party Cyrius backend |
| Compression | Pull zlib | First-party sankoch |
| Crypto | Bind OpenSSL | First-party sigil |
| GPU | Bind wgpu | First-party mabda (folded into stdlib) |
| Version control | Use git | First-party sit |
| Prompt context | Add a plugin | Discipline the existing surface |

Every row is the same shape. There's a load-bearing layer. The conventional answer is to bolt another piece of software onto it. The AGNOS answer is *make the existing layer load-bearing for what you actually need it to do.*

This is *Refusal as Architecture* applied to prompt engineering. The discipline isn't to refuse all tools — Claude Code itself is a tool. The discipline is to refuse *the multiplication of indirection layers* when the existing surface can do the job with structural work.

A plugin to make CLAUDE.md instructions follow-able is, structurally, identical to using a Rust crate to bind to wgpu so your Cyrius program can render. Both add a dep chain to compensate for under-disciplined use of the layer below. The disciplined version skips the bolt-on.

---

## The Live Receipt

This article is written from inside a session where CLAUDE.md and the memory layer just demonstrated the thesis. The specific subject matter isn't the point; the mechanisms are. The session ran a multi-domain task across sibling repos, and the surface caught what it was supposed to catch.

What the structured surface actually did, earlier in the same session, before the meetup invite arrived:

- **CLAUDE.md routed the entry points.** *"Read each repo's CLAUDE.md before claiming anything about its state"* fired correctly; sibling-repo state was loaded from authoritative sources rather than recalled from session priors. Memory routed the cross-cutting context that didn't live in any single repo's tree.
- **Wrong analogy → user correction → guardrail pinned.** The agent reached for an analogy that turned out to be structurally wrong (two superficially-similar prior artifacts use fundamentally different patterns under the hood). The user corrected; the agent pinned a *"don't use this analogy here"* note into the relevant memory file so the same misframing wouldn't surface in a future session. Future-self gets the correction without future-user having to give it again.
- **New soft constraint → memory pinned with scope-calibration.** A new constraint surfaced mid-conversation. The agent pinned a project memory file calibrated to the actual scope — narrower than the slightly-larger framing the constraint was being communicated with externally — so future sessions wouldn't over-weight it.
- **Scattered references → combined memory → indexed.** A clarifying round surfaced a load-bearing framing the existing memory had only as scattered references across multiple files. The agent pinned a new combined memory pulling the references together as a single through-line, and indexed it in `MEMORY.md` so the next session loads it natively.
- **Typo caught → uncertainty bracket cleared.** A small factual correction was made; the bracket the memory was holding pending confirmation was cleared in a one-line edit.

Multiple memory file updates. Two factual corrections caught mid-conversation. Zero plugins. The CLAUDE.md surface didn't lie; it routed correctly when called and got corrected when wrong.

The ~30% failure mode the talk pitches a plugin to solve was instead handled by:

- One CLAUDE.md (read on session entry)
- Several memory files referenced by name across the conversation
- One ADR surfaced when its content was load-bearing for the in-flight decision
- Multiple re-read prompts at task boundaries — including the re-reads of the article-style feedback memories before drafting *this* article

That's the engineering version of *"Claude Code is ignoring my instructions"* not happening — because the surface was structured for it.

---

## What CLAUDE.md Is

- A durable contract about *how to work in this repo*. Preferences, process, invariants, "read these other things first."
- Short enough that the load is real. Under ~5K tokens.
- A pointer block to volatile state, not a holder of it.
- A reference template, not a wishlist.

## What CLAUDE.md Isn't

- A version-and-sizes dashboard. (That's `state.md`.)
- A behavioral-feedback log. (That's auto-memory.)
- A per-decision archive. (That's ADRs.)
- A philosophy doc. (That's `docs/philosophy.md`.)
- A complete ruleset. It's the *durable* ruleset; the rest of the layers carry the rest.

When CLAUDE.md tries to be all of these, it stops being any of them. That's the wishlist problem. That's also why the agent skims it.

---

## The Practical Takeaway

If your CLAUDE.md is over 10K tokens, it's probably trying to be five layers at once. Triage:

1. **Move volatile state out.** Versions, sizes, in-flight slots → `docs/development/state.md` (or your harness's equivalent). Wire the release hook to bump it.
2. **Move behavioral feedback out.** *"Don't do X because Y burned us last quarter"* → memory file (or your harness's equivalent).
3. **Move per-decision archaeology out.** *"We chose X over Y because…"* → ADR.
4. **Trim what's left.** Anything not durable, not invariant, not needed every session — cut it.
5. **At task boundaries, prompt the re-read.** *"Re-read the testing-discipline section of CLAUDE.md before running these tests."* The agent will not do this on its own.

CLAUDE.md isn't lying. The 30% failure mode is real, and it's almost always one of: bloat, contradiction, or absent re-read. Fix those structurally. The agent will follow.

The plugin can wait — or, more honestly, it can stay un-built. Discipline the surface you have.

---

## Related

- [*Development Speed and How It Effects Documentation*](development-speed-and-documentation.md) — the doc-drift-at-agent-speed argument and receipts; CLAUDE.md is one of the doc kinds that rots
- [*Memory Should Be Sovereign Too*](memory-should-be-sovereign-too.md) — the memory layer's place in the surface
- [*Why GPU Belongs in the Stdlib*](why-gpu-belongs-in-the-stdlib.md) — the same Refusal-as-Architecture pattern at a different layer
- [*Sovereign Compiler vs Brute Force*](sovereign-compiler-vs-brute-force.md) — the original argument template

---

*AGNOS project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
