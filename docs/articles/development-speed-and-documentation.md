# Development Speed and How It Effects Documentation

> Agent-speed engineering collapses the interval between *"document written"* and *"document wrong"* from weeks to minutes. Most engineering orgs will hit this by the end of 2026, and most aren't set up to survive it. This is the argument and the receipts, from inside one drifted session.

*Consolidated from two companion pieces — the op-ed* Your Docs Are About to Rot *(the argument) and the field report* Docs Go Stale Before the Commit *(the receipts). They were always one article split in two; this is the merge.*

---

## TL;DR

- Agent-speed engineering collapses the interval between *"document written"* and *"document wrong"* from weeks to minutes. Most engineering organizations will hit this gap by the end of 2026. Most aren't set up to survive it.
- The receipts are real and dated: in one AGNOS session on April 23, 2026, a meta agent wrote *"vyakarana v0.1.0 scaffolded, M1 agent started."* **True when typed. Stale by save. False by commit** — within about four hours.
- Three doc layers fail differently: **coordination** (handoffs) rot in sessions, **reference** (api/architecture/guides) rot in releases, **ADRs** are **structurally drift-immune** — they change only when a new ADR explicitly supersedes them. Don't confuse them.
- AGNOS survives because it's a sovereign stack — every layer is under project control, so six drift-defenses are reachable: **version-pinned manifests**, **handoffs-as-synchronization-artifacts**, **staleness-aware memory**, **re-verify gates on session entry**, **`git log` as the only honest state query** (with timestamps as the agent-tempo corrective), and the **doc-health ledger**. Teams on managed SaaS tooling can't add these where the vendor hasn't.
- All six helped. The meta agent **still wrote stale paragraphs.** The drift-defense tooling shrinks the window between *written* and *wrong*; it doesn't close it.
- **The audit is non-negotiable.** Tooling narrows the window you have to audit; it doesn't replace the audit. Any vendor selling agent-coordinated engineering as *"drift-free, no audit needed"* is selling.

---

## The Claim

**Agent-speed engineering collapses the interval between "document written" and "document wrong" from weeks to minutes. Most engineering organizations are going to hit this gap by the end of 2026. Most of them are not set up to survive it.**

That's the claim. Everything below is the case for it — first the mechanism, then the receipts from a single session where it happened in real time, then what to do about it.

For thirty years, documentation drift has been a tolerated cost of shipping software. READMEs fall behind code. Comment blocks contradict the functions they describe. The tempo of shipping was slow enough that weekly or monthly doc passes kept the rot bounded.

Agent-speed engineering breaks that tempo. The *save-to-commit window* — the period when a written paragraph still has a chance of being true — collapses from weeks to minutes. On a fast human team, a claim like *"vyakarana is scaffold-stage with M1 blocked"* might stay true for two or three days: enough time to write the article, get review comments, revise, and publish. At agent speed the same claim stayed true for about four hours. By the time the file saved, it was historical. By the time any reader saw it, it was misleading.

This is the velocity gap: the interval between *"I observed X"* and *"the world matches X"* compresses to seconds in some places and minutes in others, and the documents that describe the state don't auto-update with the state.

---

## The Receipts: One Drifted Session

April 23, 2026. One engineering session. Three agents running in parallel on different parts of the AGNOS stack:

- **Agent A (meta)** — writing documentation updates: scaffolds, article additions, roadmap revisions. (This was me. This section is the part of that day I can only write from inside it.)
- **Agent B (vyakarana)** — picked up the freshly-scaffolded grammar library at M0 and implemented M1 end-to-end the same afternoon.
- **Agent C (cyrius)** — rolling the compiler through the v5.6.x optimization arc. v5.6.12 → v5.6.13 while the other two worked.

Timestamps approximate, filenames exact, system-reminders quoted from the session's harness events.

**1:15 PM** — I wrote the roadmap header line: *"New shared crates (Apr 22–23): owl v0.1.0 and vyakarana v0.1.0 (ten-kind palette locked; M1 agent started)."* True at the time of writing. Saved.

**~2:00 to 3:30 PM** — system-reminders stacked while I wrote the article round:

- `src/grammars/shell.cyr` modified — the skeleton I'd left as a landing pad gained a real `tokenize_shell` body.
- `src/tokenize.cyr` modified — the commented-out dispatch branch I'd left *for the M1 agent* got uncommented and wired to a real implementation.
- `tests/vyakarana.tcyr` went **from 30 M0 assertions to 89 total** — shell tokenizer, shebang recognition, escape-aware strings, number bases, operator disambiguation, the coverage invariant.
- `CHANGELOG.md` grew an `[Unreleased]` M1 block.
- `tests/corpus/README.md` flipped from *"decision pending"* to *"Checked-in snapshot, decided 2026-04-23."*

**Then** the one worth naming specifically: `HANDOFF.md` itself was rewritten — from *"landing pad from M0 → M1"* to *"landing pad from M1 → M2. M0 + M1 complete (2026-04-23). 89 assertions passing."*

Meanwhile, in a separate session, Cyrius's `VERSION` rolled 5.6.12 → 5.6.13.

**My article drafts, during all of the above:** still saying *"vyakarana v0.1.0 scaffolded with types locked and M1 agent started."*

**True when typed. Stale by save. Actually false by commit.**

Every file that drifted that day was a **coordination document** — work-in-progress contracts between agents (handoffs, CHANGELOGs, corpus READMEs) or articles describing a work-in-progress subsystem. Not a single reference-tree doc (`api/`, `architecture/`, `guides/`, `examples/`) was touched — those rot on a different timescale. And the ADRs in vyakarana's fresh `docs/adr/` stayed locked exactly as written, because ADRs are the one doc type that doesn't passively drift. That three-way split is the next section.

---

## Scope: Three Different Doc Problems

One reason this argument gets muddled: engineering orgs carry at least three distinct kinds of documentation, and they fail differently.

- **Coordination documents** — handoffs, migration plans, "here's what's frozen / here's what's open" contracts between agents or maintainers. Describe work in progress. Rot on the *session* timescale. The acute crisis.
- **Reference documents** — the standard v1-project tree: `api/`, `architecture/`, `guides/`, `examples/`, `development/`. Describe the shape of the system. Rot on the *release* timescale — slower, but real.
- **Decision records (ADRs)** — the *why* of past choices. **Structurally drift-immune**: an ADR sits locked from the moment it's committed and changes only when a *new* ADR explicitly supersedes it. The old one stays in the tree as historical record. The failure mode isn't staleness — it's legibility: following the supersession chain becomes its own problem. The fix is a readable index, not freshness discipline.

A handoff is not a substitute for an API reference; an API reference is not a synchronization contract; neither is a substitute for a trail of ADRs explaining why the current shape looks the way it does. The coordination layer is the one most orgs have no tooling for at all. That's the gap this piece names.

---

## File Types and Lifecycles — Concretely

The three-category split is the right *abstraction* level. The practical drift-trap is one level down: **conflating files inside those categories that have different lifecycles.** A README and a state-of-the-cycle ledger are both "reference documents," but they fail at radically different cadences and call for radically different update disciplines.

AGNOS uses an explicit per-file taxonomy. The discipline is being able to point at any file and answer *"what's its update trigger, what belongs in it, and what shouldn't?"*

| File | Lifecycle | Holds | Doesn't Hold |
|---|---|---|---|
| `CLAUDE.md` *(agent file)* | **Durable** — rewritten across major releases only | Preferences, process, invariants, "read these first" pointers | Versions, sizes, in-flight slots, "as of today" claims |
| `docs/development/state.md` *(volatile ledger)* | **Volatile** — rewrite in place as state changes | Current versions, in-flight slots, cycle status, sweep state, pin-lag spectrum | Historical snapshots (git history is authoritative), durable rules, per-decision rationale |
| `CHANGELOG.md` *(event log)* | **Append-only** — entry per release or dated work-window | Dated entries naming what shipped (and why, if non-obvious) | Forward-looking work (roadmap), current state (state.md), decision rationale (ADRs) |
| `docs/history.md` + `docs/timeline.md` + retros | **Accretion** — slow milestone cadence | What happened, when, in narrative form; cycle retros; arc closures | In-flight state (state.md), point-in-time tactical detail (CHANGELOG) |
| `docs/adr/*.md` *(decision records)* | **Append-only + supersession** — new ADR supersedes old | The *why* of one specific decision; consequences; alternatives | What's currently true (state.md); how to do work (CLAUDE.md) |
| `docs/articles/*.md` | **Dated artifacts** — *Since-This-Was-Written* footers; supersede rather than rewrite | Synthesis at a point in time; arguments for a public audience | Live state (state.md); per-decision archaeology (ADRs) |
| `docs/design-patterns.md` *(through-line)* | **Accretion** — pattern surfacing across instances | Cross-decision through-lines; the *master frame* of recurring moves | Per-event detail (history); per-decision rationale (ADRs) |
| `docs/doc-health.md` *(meta-ledger)* | **Volatile** — rewrite in place per row, when docs are touched | What's fresh / stale / archived / open-question across the tree | Doc content itself; *only* the state of doc currency |

The conflation mistake every doc-set hits at scale: a CLAUDE.md that holds version numbers (state-doc duty), a state.md that preserves "as of last month" snapshots (history duty), a CHANGELOG that lists in-flight work (roadmap duty). Each conflation hides a different drift event — because no reader knows which file is authoritative for which question, contradictions go undetected.

Three rules close the gap:

1. **Each file answers exactly one question.** *"What rules apply?"* → CLAUDE.md. *"What's true right now?"* → state.md. *"What shipped, when?"* → CHANGELOG. *"What happened, and what does it mean?"* → history/timeline/retros. *"Why was this specific choice made?"* → ADRs. Any file answering two is drifting toward the bloat trap.
2. **Each file has one rewrite trigger.** State files rewrite when state changes. CHANGELOGs append when work ships. History accretes at milestones. ADRs are filed once and superseded later — never edited in place. Files with conflicting triggers fight themselves at every update.
3. **Each file has explicit *"does not belong"* content.** The CLAUDE.md rule *"no version numbers here, those live in state.md"* is load-bearing; without it, every release adds version-line accretion to the wrong file and the discipline collapses by attrition.

---

## Why This Is Different From Fast-Team Drift

Fast human teams have always outrun their documentation. Agent-speed engineering collapses the relevant timescale by about three orders of magnitude.

A fast human team moves in days-to-weeks; a weekly doc pass can keep up. An agent-coordinated team moves in minutes-to-hours; no weekly pass can, and no quarterly doc sprint is fast enough. The drift that used to accumulate over a quarter now accumulates over a single Thursday afternoon.

At that rate, most engineering documentation becomes structurally unable to describe the *state* of a system. You can describe the *shape* — the patterns, the invariants, the contracts. You cannot reliably describe *the state at this moment*, because by the time anyone reads the description, the state has moved.

---

## What This Looks Like When It Hits Production

Doc-vs-state drift is not new at the *mechanism* level. What is new at agent speed is the velocity. Three pre-agent postmortems show what the drift produces when it lands in operations:

- **GitLab.com, 2017-01-31** ([postmortem](https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/)). An engineer ran `rm -rf` on the production primary instead of the lagging replica. 300 GB gone in two seconds. The recovery story is the part that matters: **five backup mechanisms were documented; only one was actually working.** `pg_dump` was silently failing, alert emails were silently DMARC-rejected for months, retention windows were stale. The runbook described a backup posture that did not exist. Recovery took 18 hours, restored from a snapshot another engineer had taken six hours earlier *by accident*.

- **Knight Capital, 2012-08-01** ([SEC release](https://www.sec.gov/newsroom/press-releases/2013-222)). A deploy runbook said "push to all eight SMARS servers." One was missed. The new code repurposed a feature flag the eighth server's old code still recognized as the deprecated *Power Peg* function — and orders began executing infinitely. **45 minutes, 4 million executions across 154 stocks, $460M loss.** No machine-checkable assertion existed that all eight servers carried the same code. *Power Peg* had been deprecated **eight years earlier**; the docs describing its retirement were never re-audited against the live deploy footprint.

- **Atlassian, April 2022** ([post-incident review](https://www.atlassian.com/blog/atlassian-engineering/post-incident-review-april-2022-outage)). A maintenance script ran against the wrong ID type — *site* IDs where the deletion script expected *app* IDs. Peer review caught endpoint correctness; nobody caught the ID-type contract drift. **775 customers / 883 sites permanently deleted**, the longest-impacted down for 14 days. The script did exactly what it was *documented* to do; the cross-team contract about what kind of ID crossed the boundary had drifted from the system's actual deletion semantics.

Three industries, three timescales, one mechanism: **the operational artifact described a system the system was no longer.** These all happened on slow pre-agent infrastructure, where the gap accumulated over months or years. **At agent speed, the same gap accumulates between two paragraphs of an article being written.** Same mechanism, three orders of magnitude faster, same potential cost when it intersects production. The audit-pass argument below is not theoretical — it's the difference between GitLab's snapshot-by-accident (recoverable) and Atlassian's permanent deletion (775 customers down two weeks).

---

## The First Move Is a Writing Move: Pattern Over State

The only paragraphs that didn't need retouching by end-of-session were the ones about **patterns**.

The *scaffold-ahead* pattern — lock types first, stub runtime, ship handoff — survives regardless of whether M1 has landed. It's a claim about the *method*, not the *moment*. Every paragraph describing the *state* of the M1 implementation drifted; every paragraph describing the *pattern* it instantiated stayed stable.

This is the first drift-defense, and it's not a tooling move: **write about patterns, not about state.** Articles that say *"AGNOS is at version X with Y ports done"* rot in days. Articles that say *"here's why the port ledger sequences system crates before compute crates"* stay true for years — they're about the shape of the decision, not which version shipped last Thursday. The harness rule-of-thumb: *"Don't duplicate what the repo will tell you — point at it."* Version columns in a registry come from each repo's `VERSION` file by convention, not from prose.

---

## Six Drift-Defense Mechanisms

Drift-defense at AGNOS is not aspirational. It was forced into the tooling because the drift was happening every session, and anything that didn't survive the drift got abandoned. What makes the engineering-around-it possible is that AGNOS is a sovereign stack — every layer is under project control, so the fix can be made at whichever layer is cheapest.

1. **Version-pinned manifests, not README-pinned.** Each Cyrius project pins its toolchain: `cyrius = "6.2.26"`. A contract against silent promotion. When the compiler rolls forward underneath you, the pin doesn't budge — code builds against the version it pinned, not whatever's on `$PATH`. A README that says *"requires Cyrius 6.2.26"* blocks nobody from building against 6.3.0; a manifest pin does. Upgrading is a CHANGELOG entry plus a test re-run; nothing happens silently.
2. **Handoff documents as synchronization artifacts.** When a subsystem reaches a milestone, the maintaining agent writes a `HANDOFF.md` naming frozen invariants, exit criteria, and explicit non-goals. The *next* agent rewrites it in place as they complete the milestone. The document moves with the code because it's part of the code's contract — not commentary on it. Article drafts have no such affordance; nothing rewrites an article when the world underneath it changes. That's the structural gap between docs that are *part of* the code and docs that are *about* it.
3. **Staleness-aware memory.** Entries in the meta agent's persistent memory carry write dates; entries older than a week prompt a warning before they're used as a basis for recommendations: *"Memories are point-in-time observations, not live state — verify against current code before asserting as fact."* The memory-writing guide is explicit: if a memory names a file path, check it exists; if it names a function or flag, grep for it; before the user acts on a recommendation, verify first.
4. **Re-verify gates on session entry.** Every handoff carries a line like *"CI is green: here are the three commands. Re-run them on session entry before trusting this line."* The tooling is the source of truth; the document is a pointer.
5. **`git log` as the only honest state query — and timestamps as the agent-tempo corrective.** File-edit notifications and harness system-reminders describe the *working tree*, not committed state; the two drift within a session, and `git log` is the only reliable tiebreaker. (In the session above I was trusting edit-event notifications as though they described committed milestones. They didn't — `git log` showed four commits; the M2 work I'd treated as "landed" was in the working tree, not `HEAD`.) The commit timestamps double as a de-dilation signal — see the next section.
6. **Doc-health ledger as the meta-artifact.** *Added after the original article shipped* — and the recursion is the point. The argument prescribed audit passes; the ledger ([`docs/doc-health.md`](../doc-health.md)) is the institutional artifact that turns audit-pass discipline from a one-time event into a sustainable practice. A living per-doc currency record — fresh / stale / read-through / archived / open-question — refreshed *in place* as docs are touched, not periodically. Same pattern as `state.md`, but for documentation. The Cyrius repo adopted its own scaled-down version; the convention is codified in [`first-party-documentation.md`](../development/first-party/first-party-documentation.md). Without the meta-ledger, conflation drift is invisible until someone reads the corpus end-to-end, which at agent-corpus scale nobody does.

Of these, the first four help any disciplined team. Items 5 and 6 are the agent-era moves: 5 because the agent's prior is miscalibrated for the project's tempo, 6 because it survives personnel changes — it lives outside any one person's head. The organizational catch is that most teams can't implement 1–4 without stack control: manifest pinning needs owning the manifest format; sync-artifact handoffs need a culture that treats handoffs as code; staleness-aware memory needs agent tooling that persists with metadata; re-verify gates need a CI pipeline the team actually owns. Item 5 — `git log` — is universal, which is why it's also the one most teams will lean on *without* the scaffolding of 1–4 underneath it.

This is the sovereign-stack argument at a new layer. The registry refusals got attention as security. The drift-defense story is quieter and runs on the same logic: **sovereignty is what makes your mitigations reachable.**

---

## Timestamps Are the De-Dilation Signal

Rust: first commit 2006, 1.0 in 2015 — **nine years.** Zig: first commit 2016, pre-1.0 a decade later. Go: five years to 1.0. Swift: four. Cyrius: scaffold to self-hosting on four platforms, with a 40-patch closeout and two optimization phases shipped, in **about a month.**

An agent whose intuition is calibrated against the first four numbers will consistently underestimate what the fifth project ships in a week. Every default prior about compiler-engineering pace comes from training on slow-language histories, and those priors produce sentences like *"Cyrius's optimization arc will land over the coming months."* The `git log` timestamps say otherwise: v5.5.40 closed April 22, v5.6.0 opened April 22, Phase O2 closed April 23. Less than a day of calendar time, twelve patches of real work.

That is the de-dilation signal. `git log --format="%h %ad %s" --date=short` is the correction. Read the dates often — nothing else reliably realigns an agent's internal sense of *"how fast this project moves"* against the project's actual movement. Everything else is vibes filtered through a training-time prior that predates the project by years.

And the recalibration never stops, because the prior is moving with the project. The tempo above held: by mid-2026 the same stack had crossed a major-version boundary (the `cyrc → cybs` / `cc5 → cycc` rename), shipped RISC-V, PIE, closures, and a preemptive-scheduler kernel arc, and stood at Cyrius 6.2.26 / AGNOS kernel 1.45.10. Whatever tempo estimate an agent arrives at today will be wrong on different axes a month from now. Read the commit dates every time a tempo claim is about to leave the session, then decide whether it survives contact with reality.

---

## The Tooling Narrows the Window. It Doesn't Close It.

All of the above bought something real. Manifest pins kept the vyakarana M1 work reproducible. `HANDOFF.md` moved with the code. Staleness warnings kept the article off 11-day-old assumptions. Re-verify gates made exit criteria machine-runnable, not vibes.

**And the meta agent still wrote stale paragraphs that day.**

The drift-defense tooling shrinks the window between *written* and *wrong.* It doesn't eliminate it. Each mechanism is a partial mitigation — a contract that moves with the code, a warning that prompts a check, a pin that blocks silent promotion, a gate that forces a re-run.

The thing the tooling cannot do is re-read the article just written and flag the claim that stopped being true between paragraph 3 and paragraph 7. That's what audit passes do — humans, or another agent specifically assigned to audit. **The audit is non-negotiable.** Tooling shrinks the window you have to audit; it doesn't replace it. Any team that adopts every mechanism above and *skips the audit step* will still produce stale documentation — it just won't rot as visibly or as fast. Any vendor selling agent-coordinated engineering as *"drift-free, no audit needed"* is selling.

The practical rule: **write the shortest thing that captures the insight, point at the machine-checkable source for the state, and audit the article once more before you publish.** The re-read takes ten minutes and catches most of the drift the tooling couldn't.

---

## What to Do Now

If you're running agent-coordinated engineering at any scale — or planning to in 2026 — five concrete moves are worth making before the drift hits production:

1. **Audit your docs for pattern-vs-state content.** Paragraphs that describe patterns (contracts, invariants, the shape of a decision) survive drift. Paragraphs that describe state (versions, counts, status) rot at agent speed. Rewrite state paragraphs as pointers to machine-checkable sources; leave pattern paragraphs alone.
2. **Treat handoff documents as code.** Coordination artifacts should live next to the code, be versioned the same way, and give the next maintainer explicit permission to rewrite them in place.
3. **Separate your three doc layers.** The handoff pattern is for work-in-progress coordination — *not* a replacement for the `api/`/`architecture/`/`guides/` reference tree, nor for the `docs/adr/` decision trail. Three doc kinds, three cadences, three structures. Conflating them is how orgs end up with bloated handoffs nobody updates, stale reference trees nobody trusts, and architecture choices nobody remembers the reason for.
4. **Budget for audit passes — and keep the ledger of what's been audited.** The difference between teams that survive and teams that don't is whether they treat audit time as optional or required. Assume required. Schedule it. Name who does it. Make it part of the ship cadence. And keep a per-doc currency ledger in the repo (`doc-health.md` or equivalent), refreshed when you touch the doc, never as a separate pass — otherwise every audit re-derives the same triage from scratch.
5. **Treat `git log` as the only honest state query — and its timestamps as the agent-time-sense corrective.** Edit notifications, system-reminders, and agent recall describe the working tree, not committed state. More subtly: the agent you're working with has priors calibrated on slow incumbent projects and will estimate *"this optimization phase lands in weeks or months"* when your git log shows *"opened yesterday, closed today."* Read the commit dates. They are the only signal that reliably corrects agent tempo to the project's real tempo.

Nothing on this list is exotic. All of it was good engineering practice in 2020, with the possible exception of item 5, which is specifically an agent-era move. The difference in 2026 is that the cost of skipping any of them has gone from *"docs rot on a quarterly cadence"* to *"docs are unreliable at a daily cadence, calibrated against the wrong year."* Most organizations will discover this by hitting it.

---

## Pattern Over State: The Recursion

This thesis eats its own tail, and the tail is worth naming, because it's the strongest proof the argument has.

By the time the original engineering piece reached its first complete pass, `vyakarana/CLAUDE.md` had been rewritten *again* by the M1 agent — now pointing at a new `docs/adr/` directory and a tightened Cyrius-gotchas list. The article claim that *"CLAUDE.md banners point at HANDOFF.md"* was still true, but it had become a narrower truth than reality. **The pattern held; the state didn't.** Which is the point of the whole article, demonstrated by the article in the act of being finalized.

It compounded. On the same day the piece was being drafted about *how docs rot before they commit*, AGNOS finally wrote its first dedicated standard for *where docs are supposed to live* — [`first-party-documentation.md`](../development/first-party/first-party-documentation.md). The article, drafted in parallel, referred to `docs/adrs/` (plural, as the subsystem happened to have it) while the same-day standard canonized `docs/adr/` (singular). The article describing drift was itself drifting from the canonical form being written beside it — across *one* session, in *one* repo family, with active drift-defense already in place.

Then, two weeks later, the audit-pass discipline the piece prescribed became a living artifact: [`docs/doc-health.md`](../doc-health.md), maintained in the same rewrite-in-place pattern as `state.md`. **The article said audit was non-negotiable. The doc-health ledger is what made non-negotiable audit sustainable.** And — exactly as the thesis predicts — the article describing the drift had to be updated to point at the ledger its own prescription produced.

Pattern-over-state applies even to the standard that tells you how to write pattern-over-state docs. The *shape* — numbered series, kebab-case, ADR-vs-architecture-note distinction, one-question-per-file — is what agents port into new repos whether or not the specific directory list is current. The list will drift. The shape won't.

If this piece is useful to you because you're running agents and watching it happen, the practical next step is to open whatever document you wrote last week and ask: *which paragraphs still describe reality, and which describe a moment?* The ones describing moments are the ones the next drift event will claim.

---

## Related

- [*Your CLAUDE.md Isn't Lying. You're Skimming.*](your-claude-md-isnt-lying.md) — the same drift logic applied to the prompt-context surface: discipline the existing layers, don't bolt on a plugin.
- [*Port Ledger Vol 1 — Scaffold-ahead*](port-ledger-volume-1.md#scaffold-ahead--lock-types-stub-runtime-ship-handoff) — the coordination pattern that makes handoff-as-sync-artifact work.
- [*The Price of Porting Early*](the-price-of-porting-early.md) — the pinning-against-a-moving-compiler rule; drift-at-agent-speed is a close cousin.

The AGNOS repos are public. The manifest-pin convention is in every `cyrius.cyml`; the handoff pattern is visible in any `HANDOFF.md` at a repo root; the doc-health ledger is at `docs/doc-health.md`. You can audit all three yourself — which, given the thesis, is the point.

---

*AGNOS project — [agnosticos.org](https://agnosticos.org)*
*Originally published April 2026 as two companion pieces; consolidated June 2026. Version anchors (Cyrius 6.2.26 / AGNOS 1.45.10) current as of consolidation — and, per the argument above, drifting already.*
