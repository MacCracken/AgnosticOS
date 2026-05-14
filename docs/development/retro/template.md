# {Project} — v{N} cycle retrospective

> Written {YYYY-MM-DD} at the v{N}.0.0 cut. Covers the v0.1 → v1.0
> arc (or v(N-1).LAST → v{N}.0). Per the
> [agnosticos retro pattern](README.md): one entry per major version
> for regular projects.

## Header

- **Cycle**: v0.1.0 → v{N}.0.0
- **Span**: {YYYY-MM-DD} → {YYYY-MM-DD} ({days} days, {patches} releases)
- **Theme**: {one-line characterization of what this cycle was actually about — sometimes different from what it was *planned* to be about}
- **Companion docs**: {links to roadmap, CHANGELOG span, prior retro if any}

## What shipped

A bulleted inventory of the cycle's major arcs. Not a CHANGELOG
re-dump; rather, the {2–5} arcs that the cycle ended up being
about. Each arc gets a one-line description plus slot count.

- **Arc 1**: {description} ({patch range, e.g. v0.1.0 → v0.3.2})
- **Arc 2**: {description} ({patch range})
- ...

If meaningful, also list the **slot map**: what % of slots went to
headline arcs vs. bug fixes vs. tooling vs. emergent cross-repo
work. Helps the next-cycle agent plan capacity.

---

## == WHAT WORKED ==

Pattern-level wins. What *shapes* of slot worked. What *kinds* of
decision turned out right. Cite specific patches as evidence; don't
re-prosecute the wins, just point to them.

### {Pattern 1}

{2–4 sentences describing the pattern. Cite patches that exemplify it.
Note what about it worked — was it the scope discipline? The
cross-repo coordination? The premise-check at slot entry?}

### {Pattern 2}

{...}

### {Pattern 3}

{...}

---

## == WHAT DIDN'T WORK (FIRST TIME) ==

The partial fixes, the wrong-direction slots, the premise errors at
slot entry. Be honest. The next agent reads this to AVOID these,
not to admire the recovery. Cite the verbatim user feedback when
applicable — it lands harder than a paraphrase.

### {Anti-pattern 1}

{2–4 sentences describing what happened. Cite the patches. Name the
memory pins / lessons that emerged ("`feedback_xxx_yyy`" if pinned
in agent memory).}

### {Anti-pattern 2}

{...}

If the cycle had a famous "WTF" moment — a silent corruption, a
quiet revert, a partial-fix chain — give it its own subsection. Name
the bug. Describe the shape. Pin what the agent should look for
next time.

---

## == WHAT THE CYCLE TAUGHT ABOUT {topic} ==

Optional. Use this when one specific technical surface ate a
disproportionate share of the cycle and deserves its own field-note
treatment. Examples:

- "What the cycle taught about Mach-O ARM64" (cyrius v5.9.x)
- "What the cycle taught about strict-W^X UEFI" (gnoboot v1)
- "What the cycle taught about per-process page tables" (agnos v2)

Multiple of these are fine if the cycle hit multiple deep surfaces.

---

## Carry-forward

What slipped from this cycle that belongs in the next. Numbered
items, each with a one-line description + reason it's deferred (not
prioritized? blocked on upstream? scope-too-big?). The next-cycle
agent reads this list and either accepts the carry-forward or files
a counter-roadmap entry explaining why it's no longer relevant.

1. **{Item 1}** — {description}. {Why deferred.}
2. **{Item 2}** — {description}. {Why deferred.}
3. ...

---

## Cross-repo dependencies surfaced

What other AGNOS-family repos this cycle pulled into existence or
into tighter coupling. Each entry: the dep, what the cycle needed
from it, what the resolution was.

- **{repo}**: {what was needed; how it was resolved; how many
  patches/issues filed}
- ...

---

## Memory pins from this cycle

If the cycle produced new agent-memory pins (feedback_xxx_yyy,
project_xxx_yyy in [[agnosticos memory tree]]), list them. Keeps
the inheritance trail clear for the next agent who reads the pins.

- `feedback_{slug}` — {one-line summary of the lesson}
- `project_{slug}` — {one-line summary of the project context}

---

## What carries into v{N+1}

The roadmap entry for v{N+1}.0.0 should reflect:

- {bullet 1 from carry-forward / accumulated debt / open architectural questions}
- {bullet 2}
- {bullet 3}

These bullets become the seed of the next-cycle roadmap entry. The
roadmap doc owns the *what*; this retro section owns the *why
these and not something else*.

---

*Closeout note: a good retrospective gets written within a week of
the major cut, while the cycle is still fresh. Written 6 months
later it becomes archaeology, not learning.*
