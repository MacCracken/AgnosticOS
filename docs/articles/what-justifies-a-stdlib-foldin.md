# What Justifies a Stdlib Foldin

> Three sibling repos folded into Cyrius stdlib in three minor releases — sandhi (v5.7.0), vani (v5.8.0), niyama (v5.9.0). Every fold is a subtraction of a dep-graph layer. But which surfaces deserve that promotion, and which don't? The pattern compounds; the decision framework deserves to be articulated before the fourth fold makes it implicit.

---

## The Cost — Front-Loaded

Folding is not a soft move. It is irreversible in practice, and the costs are real:

- **Independent versioning ends.** The sibling repo cannot ship a patch ahead of its consumers anymore — surface patches land through the Cyrius release cycle.
- **The standalone repo enters maintenance mode.** It still exists for direct consumers needing newer surface than the folded snapshot, but it is no longer the canonical source.
- **Release-cadence coupling.** A bug fix in the folded surface ships when Cyrius ships, not when the original repo wants to ship. The author trades autonomy for stdlib-presence.
- **The fold is a one-way action.** Pulling a folded artifact back out is a v6.0-class breaking change. You don't fold to experiment.

If those four costs aren't acceptable to the sibling repo's authors, the surface doesn't fold. Period. The stdlib does not absorb against consent.

---

## The Gates

Six criteria. **All of them.** Not three of six.

### 1. Multi-consumer gate

The surface must be consumed by **at least two** AGNOS consumers, with a third on the immediate roadmap. Below that threshold, you are folding for one user — adding stdlib mass without removing dep-graph complexity.

- **sandhi** (v5.7.0): 6+ consumers across vidya / hoosh / ifran / daimon / mela / yantra
- **vani** (v5.8.0): shravan / dhvani / naad / jalwa / shruti / cyrius-doom / agnoshi
- **niyama** (v5.9.0): cyim (#1) + queued AGNOS bare-metal kernel (#2)

The third niyama consumer (the bare-metal kernel) is on the v5.10.x roadmap. The fold is justified by the gate-of-three even though only one consumer is shipping today.

### 2. API maturity (ADR-locked)

The public surface must be frozen via an architectural decision record in the sibling repo, with the freeze authored by the sibling repo's owner. Future patches via stdlib cycle is acceptable to *them*.

- sandhi ADR 0002 — clean-break fold at Cyrius v5.7.0
- niyama ADR 0010 (frozen API) + ADR 0011 (fold gate met)

If the surface is still in API flux, every ABI break would cascade across stdlib's release cadence. The freeze is not optional.

### 3. Domain alignment

The surface must fit stdlib's *kind* — systems primitives. Networking, regex, audio I/O, compression, hashing, parsing. The test: would a hypothetical second OS, written from scratch in Cyrius, also need this?

- Yes for sandhi (HTTP/TLS — every system needs networking)
- Yes for vani (audio I/O — every system needs sound)
- Yes for niyama (regex — pattern-matching is universal)
- **No** for kavach (sandbox semantics are AGNOS-specific)
- **No** for daimon (agent orchestration is application territory)
- **No** for any game

Application-specific surfaces stay standalone. They consume stdlib; they don't *become* it.

### 4. Byte-identical distlib

`cyrius distlib` must produce `dist/<name>.cyr` deterministically from the sibling repo's tag. The fold is a vendoring of that tag's distlib output, with sha256 verification.

- sandhi: 376,037 B / 9,649 lines / sha256 verified
- niyama: 6,664 lines / sha256 `4f6bf9fd...4fe06a` verified

If the distlib generation is non-deterministic, the fold can't be byte-identical, and the verification chain breaks. v1.0.0 of niyama actually hit this — the manifest scaffold had unresolved `include "src/*.cyr"` references that would have dangled at fold time. The fix shipped as niyama 1.0.1 with corrected distlib generation. The tag that gets folded is the tag whose distlib is reproducible.

### 5. Repo author consent

The sibling repo's author accepts maintenance mode. **This isn't a takeover. It's a handoff.**

The ADR (gate #2) is the consent mechanism. The author writes it. They decide when their repo is mature enough to fold. The Cyrius side responds to a met gate; it doesn't initiate one.

### 6. cc5 size guard

The foldin is `lib/` content — it must not reach the compiler binary. cc5 stays the same size before and after the fold.

| Fold | cc5 before | cc5 after | Delta |
|------|-----------|-----------|-------|
| sandhi v5.7.0 | (pre-fold cycle) | unchanged at next-tag | 0 |
| vani v5.8.0 | 720,928 B | 720,928 B | 0 |
| niyama v5.9.0 | 741,048 B | 741,048 B | 0 |

If a foldin would bloat cc5 (because the compiler itself starts including the surface), the surface is too speculative for stdlib. Wait until consumers prove they need it inlined into the compiler — and at that point the work is no longer a fold, it's a compiler change.

---

## The Anti-Criteria

When NOT to fold, even if some gates pass:

- **Single-consumer surfaces.** You're paying coupling cost without dep-graph gain. The gate-of-three exists for a reason.
- **API still in flux.** Every ABI break cascades across stdlib's release cadence. If you're still iterating on shape, fold-in is premature.
- **Application-specific domains.** Slot machines, games, agent orchestrators, package managers — these are consumers, not stdlib. Folding them would bloat stdlib for users who don't need them.
- **Author wants independent release cadence.** Their call. Some surfaces are intentionally standalone-forever even when they meet every other gate. The stdlib doesn't override author preference.
- **Surface is large enough to bloat cc5 if inlined.** A surface that's only useful when the compiler can see it (e.g., a parsing library the compiler itself needs) isn't a fold candidate; it's a compiler change.

The anti-criteria exist so that "yes" is a deliberate decision, not a default. **Subtraction is the primary cognitive move (§1)** — the default state of any candidate is *do not fold*. The gates have to argue *for* the fold against that default.

---

## The Mechanism

How a fold actually happens, in order:

1. **Sibling repo author writes the gate-met ADR.** Names the multi-consumer count, the frozen API surface, the distlib reproducibility receipt, and their consent to maintenance mode.
2. **Cyrius distlib generates the artifact.** `cyrius distlib` produces `dist/<name>.cyr` from the sibling tag. sha256 recorded.
3. **Cyrius `lib/` vendors byte-identical.** The Cyrius-side patch (typically `vN.x.0` of the next minor) adds `lib/<name>.cyr` with the verified sha256.
4. **Cyrius `cyrius.cyml` `[deps.<name>]` removed.** The fold replaces the dep-resolution surface with `lib/` content; the manifest no longer needs to resolve `<name>` as an external dep.
5. **In-tree fixture migration.** Any in-tree tests that previously consumed `<name>` as a dep are migrated to the folded artifact. Zero external-consumer hits is verified via `grep -rn "include.*<name>"` across the ecosystem.
6. **Sibling repo enters maintenance mode.** Per its own ADR. Subsequent surface patches land via Cyrius release cycle.
7. **Verification gates green.** Self-host two-step byte-identical (cc5 → cc5b), check.sh full pass, target-surface smoke test (e.g., niyama re2 compile + search runs from `lib/niyama.cyr`).

Step 1 is the hard part. Steps 2–7 are mechanical once consent and gate-met are established.

---

## What This Isn't

The fold pattern is consistently misread three ways. Naming the misreadings explicitly:

- **NOT "absorb everything we wrote."** Most AGNOS crates won't fold. agnosys, kybernet, hoosh, kavach, sigil, libro, daimon — these are consumer-facing OS subsystems consuming stdlib, not systems primitives that *become* stdlib. They stay standalone forever.
- **NOT "make stdlib bigger by default."** Subtraction-as-primary-cognitive-move means stdlib growth is a deliberate add against the *do not fold* default. Each fold is an explicit decision, not passive accretion.
- **NOT a takeover.** Sibling repos go to maintenance mode by *agreement*, via their own ADR. The fold is a handoff initiated from the sibling side — Cyrius responds to a met gate, never reaches across.

If any of those misreadings start landing in pull-request review, the framework needs re-articulating. This article is the re-articulation.

---

## Why This Matters

The fold pattern is the operational form of **Refusal as Architecture (§0)** at the stdlib-boundary layer. Refuse the multiplication of dep-graph layers when the surface is mature enough to anchor in stdlib. Refuse to ship sibling repos as deps when the consumer count makes that maintenance burden disproportionate. The receipts — cc5 unchanged, dep-graph reduced, release cadence coupled — are the measurement of what was refused.

It's also an instance of **Reference, Don't Mimic (§9)**. The incumbent (Rust + crates.io) treats every reusable library as a separately-versioned external dep, with the registry as the system of record. AGNOS references that incumbent as the *problem statement* (sovereignty wants fewer dep-resolution surfaces), and refuses to mimic the *solution* (registry-as-governance). Stdlib-fold for mature multi-consumer surfaces is the AGNOS-specific answer; it's not what Rust would do, and that's the point.

---

## The Pattern Compounds

Each successful fold reduces friction on the next decision. **Sandhi was first** — the precedent had to be set, the ADR template had to be written, the verification chain had to be established. **Vani was easier** — the path was paved; the audio fold was a 1-day Cyrius-side action because the sandhi pattern was already in muscle memory. **Niyama was a same-day decision once the gate was met** — the framework was implicit, the verification chain was rehearsed, the maintenance-mode handoff was documented form.

The fourth fold (whichever surface earns it next) lands cleaner still — because this article exists, because the gates are explicit, and because three successful instances de-risk the fourth by construction. **Pattern instance of Happy Accidents (§10)** — the structure quietly built itself across three minor releases, and now we name what it became.

The stdlib is small for a reason. It will stay small for a reason. Every surface that folds in earned the fold, and every surface that didn't is still earning standalone status. That's the framework.

---

*Related: [Design Patterns §0 — Refusal as Architecture](../design-patterns.md#0-refusal-as-architecture--the-master-frame), [§9 — Reference, Don't Mimic](../design-patterns.md#9-reference-dont-mimic), [Sibling-distfile fold pattern stub](../design-patterns.md#sibling-distfile-fold-added-2026-05-06).*

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*May 2026*
