# Major-cycle retrospectives — agnosticos pattern

> **Scope**: this directory holds AGNOS-family per-major-version retrospectives.
> Use the [`template.md`](template.md) for new entries.
>
> **What's a "regular project"**: any AGNOS-family repo that ships on a
> roadmap of major-minor-patch with meaningful work happening per major
> bump. agnos, gnoboot, ark, daimon, hadara, kavach, mabda, etc. fit
> this pattern.
>
> **Cyrius is the exception**: cyrius ships MANY patches per minor with
> meaningful cycle-shape per *minor*, not per major. Cyrius retros live
> in [vidya](https://github.com/MacCracken/vidya)'s
> `content/cyrius/field_notes/compiler/retros/` (one entry per minor).
> Don't duplicate cyrius's retros here. Don't shrink other projects'
> retros to per-minor — they don't have the patch density to justify
> the overhead.

## When to write one

Write a retrospective at every **major version bump** of a regular AGNOS
project: v1.0.0, v2.0.0, etc. Cuts at v0.5 → v1.0 or v1.7 → v2.0 are
the canonical moments. Patch-level (1.30.0 → 1.30.1) and minor-level
(1.29.x → 1.30.0) cuts get CHANGELOG entries; major cuts get a
CHANGELOG entry **and** a retrospective.

Optionally write one for **arc-class events** that aren't tied to a
version bump — a kernel ABI break (agnos 1.29 → 1.30 with the Path
C handoff swap qualified), a major rewrite of a load-bearing subsystem,
a multi-week incident that reshaped the project's roadmap. Use
judgment; if you can summarize the change with a CHANGELOG bullet
list, it doesn't need a retro.

## What a retrospective is for

- **Capture what the cycle actually taught**, beyond what shipped.
  Pattern-level lessons, not feature-level inventories.
- **Surface what didn't work the first time** — the partial fixes, the
  premise errors at slot entry, the splits that should have been
  bundles. Future agents need to read these and learn the shape, not
  just the outcome.
- **Pin the cross-repo dependencies** that surfaced during the cycle.
  gnoboot's v0.1.0 ride pulled 4 cyrius issues into existence; that
  link belongs in gnoboot's v1 retro.
- **Mark what carries forward** into the next major. Carry-forward
  items are the seed of the next cycle's roadmap; without an explicit
  list, they slip.

## What a retrospective is NOT

- A CHANGELOG. The CHANGELOG already enumerates what shipped per
  version. The retrospective is about the cycle's *shape*.
- A blog post. No marketing voice. No prose for prose's sake. If a
  bullet list captures the lesson, use a bullet list.
- A blame document. "Agents made these mistakes" is not the framing.
  "The cycle exposed this pattern" is.
- Speculation about the future. The next-cycle roadmap lives in
  `roadmap.md`; the retro is what *this* cycle taught.

## Format

Use [`template.md`](template.md) as the starting point. File naming:

```
docs/development/retro/v{N}_cycle.md
```

where N is the major version just cut. So agnos's v1 retro (cut when
agnos 1.0.0 → 2.0.0 happens) would be `docs/development/retro/v1_cycle.md`.

For pre-v1.0 first-major-cut (e.g. gnoboot v1.0 cut from v0.1+v0.x
work), the convention is `v1_cycle.md` capturing the v0.1 → v1.0 arc.

## Reference

The retrospective shape is extrapolated from cyrius's per-minor
field-notes (e.g. [v5.11.x retro](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes/compiler/retros/v511x.cyml)).
Cyrius's per-minor cadence is exceptional; other projects use the
same SHAPE on a per-major schedule.
