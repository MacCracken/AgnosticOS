# Your Docs Are About to Rot

> A field report from the agent-speed frontier, and a warning about what most engineering orgs are going to hit by the end of 2026.

*This is the argument. The receipts — timestamps, filenames, the specific drift events that prompted it — are in the companion engineering piece, [*Docs Go Stale Before the Commit*](docs-go-stale-before-the-commit.md).*

---

## TL;DR

- Agent-speed engineering collapses the interval between *"document written"* and *"document wrong"* from weeks to minutes. Most engineering orgs will hit this by end of 2026. Most aren't set up to survive it.
- Three doc layers fail differently: **coordination** (handoffs) rot in sessions, **reference** (api/architecture/guides/examples/development) rot in releases, **ADRs** are **structurally drift-immune** — they change only when a new ADR explicitly supersedes them.
- AGNOS survives because it's a sovereign stack — every layer is under project control, so the five mitigations (manifest pins, handoffs-as-sync-artifacts, staleness-aware memory, re-verify gates, `git log` as the only honest state query with timestamps as agent-tempo corrective) are reachable. Teams on managed SaaS tooling can't add these where the vendor hasn't.
- Even with all four, drift still gets through. **Audit passes are non-negotiable.** Any vendor selling agent-coordinated engineering as *"drift-free, no audit needed"* is selling.
- Four moves before the drift hits production: audit your docs for pattern-vs-state content; treat handoffs as code; separate your three doc layers; budget for audit passes.

---

## The Claim

**Agent-speed engineering collapses the interval between "document written" and "document wrong" from weeks to minutes. Most engineering organizations are going to hit this gap by the end of 2026. Most of them are not set up to survive it.**

That's the claim. Everything below is the case for it.

---

## The Setup

For thirty years, documentation drift has been a tolerated cost of shipping software. READMEs fall behind code. Comment blocks contradict the functions they describe. The tempo of shipping has been slow enough that weekly or monthly doc passes kept the rot bounded.

Agent-speed engineering breaks that tempo.

On April 23, 2026, a single AGNOS session had three agents working in parallel on three subsystems. In the time it took one agent to write an article describing the state of a library, another agent finished implementing the next milestone. The article saved, describing a state that no longer existed. The CHANGELOG was already past it. The handoff document driving the work had been rewritten in place to describe the *next* handoff. That same day, the Cyrius compiler rolled through thirteen patches in 24 hours. Any article written on April 22 saying *"Cyrius is at v5.5.40"* was stale by April 23.

This is the velocity gap. The interval between *"I observed X"* and *"the world matches X"* has compressed to seconds in some places and minutes in others. The documents that describe the state do not auto-update with the state.

---

## Scope: Three Different Doc Problems

One reason this argument gets muddled: engineering orgs carry at least three distinct kinds of documentation, and they fail differently.

- **Coordination documents** — handoffs, migration plans, "here's what's frozen / here's what's open" contracts between agents or maintainers. Describe work in progress. Rot on the *session* timescale. The acute crisis.
- **Reference documents** — the standard v1-project tree: `api/`, `architecture/`, `guides/`, `examples/`, `development/`. Describe the shape of the system. Rot on the *release* timescale — slower, but real.
- **Decision records (ADRs)** — the *why* of past choices, filed under `docs/adrs/`. **Structurally drift-immune**: an ADR sits locked from the moment it's committed and only changes when a *new* ADR explicitly supersedes it. The old one stays in the tree as historical record. The failure mode isn't staleness — it's legibility: over time, finding the relevant ADR or following the supersession chain becomes its own problem. The fix is a readable index, not freshness discipline.

This article is about the coordination layer. Coordination artifacts must move with the code at agent speed or they mislead within a session. The reference layer still matters and still rots — the fixes are mostly the long-understood practices of doc CI, example-test coverage, and review discipline. ADRs need their own discipline (numbering, supersession chains, a readable index) — but once filed, they are one of the only doc types the velocity gap can't touch. Do not confuse the three. A handoff is not a substitute for an API reference; an API reference is not a synchronization contract; neither is a substitute for a trail of ADRs explaining why the current shape looks the way it does.

The coordination layer is the one most orgs have no tooling for at all. That's the gap this piece names.

---

## Why This Is Different From Fast-Team Drift

Fast human teams have always outrun their documentation. Agent-speed engineering collapses the relevant timescale by about three orders of magnitude.

A fast human team moves in days-to-weeks. A weekly doc pass can keep up. An agent-coordinated team moves in minutes-to-hours. No weekly pass can. No quarterly doc sprint is fast enough. The drift that used to accumulate over a quarter now accumulates over a single Thursday afternoon.

At that rate, most engineering documentation becomes structurally unable to describe the state of a system. You can describe the *shape* — the patterns, the invariants, the contracts. You cannot describe *the state at this moment*, because by the time anyone reads the description, the state has moved.

---

## What This Looks Like When It Hits Production

Doc-vs-state drift is not new at the *mechanism* level. What is new at agent speed is the velocity. Three public postmortems from the pre-agent era show what the drift produces when it lands in operations:

- **GitLab.com, 2017-01-31** ([postmortem](https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/)). An engineer working through a replication-lag incident ran `rm -rf /var/opt/gitlab/postgresql/data/*` on the production primary instead of the lagging replica. 300 GB deleted in two seconds. The recovery story is the part that matters here: **five backup mechanisms were documented; only one was actually working.** `pg_dump` was misconfigured and silently failing. Failure-alert emails were being silently rejected by DMARC for months. Retention windows were stale. The runbook described a backup posture that did not exist. Recovery took 18 hours, restored from a snapshot a different engineer had taken six hours earlier *by accident* during unrelated testing. Live-streamed. The lucky save was the only thing standing between GitLab and 24+ hours of customer data permanently gone.

- **Knight Capital, 2012-08-01** ([SEC release](https://www.sec.gov/newsroom/press-releases/2013-222)). A deployment runbook said "push to all eight SMARS servers." The actual process required a manual step on each host. One server got missed. The new code repurposed a feature flag the eighth server's old code still recognized as the deprecated *Power Peg* function — and orders began executing infinitely against a now-defunct fulfillment path. **45 minutes, 4 million executions across 154 stocks, $460M loss.** No machine-checkable assertion existed that all eight servers carried the same code; the runbook was documentation, not enforcement. *Power Peg* itself had been deprecated **eight years earlier**; the documentation describing its retirement had never been re-audited against the live deploy footprint. Knight survived only via emergency capital injection from a Jefferies-led consortium and was acquired the following year.

- **Atlassian, April 2022** ([post-incident review](https://www.atlassian.com/blog/atlassian-engineering/post-incident-review-april-2022-outage)). A maintenance script executed against the wrong ID type — Team A passed *site* IDs where Team B's deletion script expected *app* IDs. Peer review caught endpoint correctness; nobody caught the ID-type contract drift. **775 customers / 883 sites permanently deleted.** Recovery from backup; the longest-impacted customers were down for 14 days. The script did exactly what it was *documented* to do; the cross-team contract about what kind of ID flowed across the boundary had drifted from the system's actual deletion semantics.

Three different industries, three different timescales (one hour, 45 minutes, two weeks of customer impact), one mechanism: **the operational artifact described a system the system was no longer.** GitLab's runbook claimed a backup posture; reality was four of five backups silently broken. Knight's runbook claimed a deployment outcome; reality was one server still running eight-year-old code. Atlassian's cross-team contract claimed an ID type; reality was a different ID type with very different consequences.

These all happened on slow-moving pre-agent infrastructure, where the doc-vs-state gap accumulated over months or years. **At agent speed, the same gap accumulates between two paragraphs of an article being written.** The timescale for *"your runbook drifted from your system"* used to be the interval between annual audits. The agent-era equivalent is the interval between two consecutive `git commit` calls. Same mechanism, three orders of magnitude faster, same potential cost when it intersects production.

The audit-pass argument later in this piece is not theoretical. It is the difference between GitLab's snapshot-by-accident outcome (recoverable) and Atlassian's permanent-deletion outcome (775 customers down for two weeks). Tooling shrinks the window. Audits close the cases the tooling cannot see.

---

## What Sovereign Stacks Get That Most Teams Don't

AGNOS hit this gap early and engineered around it. What made the engineering-around-it possible is that AGNOS is a sovereign stack — every layer is under project control. When drift-defense surfaced as a problem, the fix could be made at whichever layer was cheapest.

Five mechanisms, all live across the AGNOS repos today:

1. **Version-pinned manifests.** Each Cyrius project pins its toolchain: `cyrius = "5.6.0"`. A contract against silent promotion. Readmes that say *"requires Cyrius 5.6.0"* do not block builds against 5.6.13; manifest pins do.
2. **Handoff documents as synchronization artifacts.** When a subsystem reaches a milestone, the maintaining agent writes a `HANDOFF.md` naming frozen invariants, exit criteria, and explicit non-goals. The *next* agent rewrites it in place as they complete the milestone. The document moves with the code because it's part of the code's contract — not commentary on it.
3. **Staleness-aware memory.** Entries in the meta agent's persistent memory carry write dates; entries older than a week prompt a warning before they're used as a basis for recommendations.
4. **Re-verify gates on entry.** Every handoff carries a line saying *"CI is green — here are the three commands. Re-run them on session entry before trusting this line."* The tooling is the source of truth; the document is a pointer.
5. **Git log as the canonical state query — and timestamps as agent-tempo corrective.** File-edit notifications describe working-tree state, not committed state; the two drift within a session, and `git log` is the only reliable tiebreaker. The commit timestamps double as a de-dilation signal: an agent's default estimate for *"a compiler optimization phase"* comes from training on slow-language histories (Rust's type system took years, LLVM's regalloc took years) and produces sentences calibrated to those tempos. The actual AGNOS timestamps say v5.5.x closed in one arc, Phase O2 opened and closed in one day — numbers that force-recalibrate the agent's tempo model against reality. Read them often.

None of the first four affordances are agent-specific — a disciplined human team benefits from them too. The fifth is: it exists specifically because the agent's prior is miscalibrated for the project's observed tempo, and only repeated exposure to actual commit dates retrains the estimates. What the agent-speed context makes clear is that items 1–4 stop being optional and item 5 becomes indispensable.

The organizational problem is that most teams can't implement the first four without stack control. Manifest pinning requires owning the manifest format. Sync-artifact handoffs require a culture that treats handoff docs as code. Staleness-aware memory requires agent tooling that persists with metadata. Re-verify gates require a CI pipeline the team actually owns. Item 5 is the one every team can reach — `git log` is universal — which is why it's also the one most teams will default to relying on without the scaffolding of 1–4 underneath it.

This is the sovereign-stack argument at a new layer. The registry refusals and supply-chain arguments got attention because they were framed as security. The drift-defense story is quieter and applies to the same logic: **sovereignty is what makes your mitigations reachable.**

---

## Tooling Narrows the Window. It Doesn't Close It.

All four mechanisms bought something real in the session that prompted this piece. Manifest pins kept the milestone-1 work reproducible. The handoff document moved with the code. Staleness warnings caught recommendations built on 11-day-old assumptions. Re-verify gates made exit criteria machine-runnable instead of vibes.

And the meta agent still wrote stale paragraphs that afternoon.

The drift-defense tooling shrinks the window between *"written"* and *"wrong."* It does not eliminate the window. Each mechanism is a partial mitigation — a contract that moves with the code, a warning that prompts a check, a pin that blocks silent promotion, a gate that forces a re-run.

The thing the tooling cannot do is re-read the article that was just written and flag the claim that stopped being true between paragraph 3 and paragraph 7. That is what audit passes do. Humans, or another agent specifically assigned to audit, catch what the tooling can't. **The audit is non-negotiable.** Any vendor selling agent-coordinated engineering as *"drift-free, no audit needed"* is selling. Good tooling narrows the window you have to audit. The work of auditing does not go away.

---

## What to Do Now

If you're running agent-coordinated engineering at any scale — or planning to in 2026 — four concrete moves are worth making before the drift hits production.

1. **Audit your docs for pattern-vs-state content.** Paragraphs that describe patterns (contracts, invariants, the shape of a decision) survive drift. Paragraphs that describe state (versions, counts, current status) rot at agent speed. Rewrite state paragraphs as pointers to machine-checkable sources; leave pattern paragraphs alone.
2. **Treat handoff documents as code.** Coordination artifacts between agents (or between humans and agents) should live next to the code, be versioned the same way, and give the next maintainer explicit permission to rewrite them in place.
3. **Separate your three doc layers.** The handoff pattern above is for work-in-progress coordination. It is *not* a replacement for `api/`, `architecture/`, `guides/`, `examples/`, `development/` — the reference tree most v1-grade projects maintain. Nor is it a replacement for `docs/adrs/` — the decision record trail that explains *why* the current shape is the current shape. Three doc kinds, three cadences, three structures. Conflating them is how organizations end up with bloated handoffs nobody updates, stale reference trees nobody trusts, and architecture choices nobody remembers the reason for.
4. **Budget for audit passes.** The velocity gap is going to hit your team whether you plan for it or not. The difference between teams that survive and teams that don't is whether they treat audit time as optional or required. Assume required. Schedule it. Name who does it. Make it part of the ship cadence, not "when we have time."
5. **Treat `git log` as the only honest state query — and its timestamps as the agent-time-sense corrective.** File-edit notifications, harness system-reminders, and agent recall describe working-tree state, not committed state; the two drift within a session. More subtly: the agent you're working with has priors calibrated on slow-moving incumbent projects. Rust took nine years from first commit to 1.0; Zig is still pre-1.0 after a decade; Go took five years. Those priors produce estimates like *"this compiler optimization phase lands in weeks or months"* when your actual git log will show *"opened yesterday, closed today."* For scale: Cyrius went from scaffold to self-hosting on four platforms, with a 40-patch closeout and two optimization phases shipped, in about a month — and a month from now the state will be something else entirely. Read the commit dates. They are the only signal that reliably corrects agent tempo estimates to the project's real tempo. Everything else is vibes filtered through a training-time prior from years ago.

Nothing on this list is exotic. All of it was good engineering practice in 2020, with the possible exception of item 5, which is specifically an agent-era move. The difference in 2026 is that the cost of skipping any of the five has gone from *"docs rot on a quarterly cadence"* to *"docs are unreliable at a daily cadence, calibrated against the wrong year."* Most organizations will discover this by hitting it.

---

## For the Receipts

Timestamps, filenames, and system-reminder events driving this argument are in the companion: [*Docs Go Stale Before the Commit*](docs-go-stale-before-the-commit.md). That one is a field report from inside a single drifted session. This one is the argument the field report makes.

The AGNOS repos are public. The manifest-pin convention is in every `cyrius.cyml`; the handoff pattern is visible in any `HANDOFF.md` at a repo root. You can audit both yourself — which, given the thesis, is the point.

One more turn worth naming: the standard specifying where AGNOS docs are supposed to live — the three-layer split above, the ADR numbering conventions, the directory tree — was itself written on the same day as this article, at [`docs/development/planning/first-party-documentation.md`](../development/planning/first-party-documentation.md). Until that day, the conventions were real but scattered across repo READMEs and whichever agent's memory had most recently implemented them. Which is also why the article you just read refers to `docs/adrs/` (plural, as the subsystem happened to have it when the piece was drafted) while the same-day standard canonizes `docs/adr/` (singular, matching older repos' convention). The article describing drift was itself drifting from the canonical form being written in parallel — across *one* session, in *one* repo family, with active drift-defense already in place. The pattern was the thing to codify; the list of directories in the pattern will itself drift.

---

## Related

- [*Docs Go Stale Before the Commit*](docs-go-stale-before-the-commit.md) — engineering receipts from the session that prompted this argument
- [*Port Ledger Vol 1 — Scaffold-ahead*](port-ledger-volume-1.md#scaffold-ahead--lock-types-stub-runtime-ship-handoff) — the coordination pattern that makes handoff-as-sync-artifact work
- [*The Price of Porting Early*](the-price-of-porting-early.md) — the pinning-against-a-moving-compiler rule; drift-at-agent-speed is a close cousin

---

*AGNOS project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
