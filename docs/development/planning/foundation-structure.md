# Foundation Structure — Meta-Defense at the Governance Layer

> **Status**: Planning — Pre-Foundation | **Last Updated**: 2026-05-12
>
> Technical sovereignty can be undone in a courtroom. A 26-syscall
> kernel doesn't protect the project from a subpoena ordering the
> handover of trademarks, copyrights, signing keys, or contributor
> records. A parallel PKI doesn't protect the project from being
> *legally* unable to operate. The wire-level DPI defenses don't help
> when an injunction shuts the project down.
>
> **The governance layer is the meta-defense.** It's not code; it's
> the legal-structural posture that keeps the code from being captured.
>
> **Architectural commitment**: AGNOS evolves toward a **multi-
> jurisdictional, mission-locked, contributor-protecting Foundation**
> that holds project assets (trademarks, copyrights, signing-key
> custody) in a way no single state actor or commercial entity can
> coerce. The Foundation is the legal substrate that makes the rest of
> the project's parallel infrastructure (parallel PKI, parallel
> distribution, parallel finance) actually defensible.
>
> **Scope**: governance + legal — not code. Touches every project
> asset: code copyright, trademarks (`AGNOS`, `Cyrius`, subsystem
> names), signing-key custody, contributor IP, financial accounts,
> domain registrations, distribution channels.
>
> **Companion**: [`parallel-pki.md`](parallel-pki.md) holds the
> cryptographic identity; this doc holds the *legal* identity. The
> parallel-PKI root key needs an owner; this doc designs who that
> owner is and how it can't be coerced. They depend on each other —
> neither works alone.

---

## The threat model

Coercion at the governance layer doesn't require breaking any code.
Mechanisms:

| Attack | Mechanism | Coercion bar |
|--------|-----------|--------------|
| **Trademark capture** | Empire-aligned entity registers `AGNOS` or subsystem trademarks in a jurisdiction project hasn't covered; uses them to enforce against project | Very low — trademark filing is mostly paperwork |
| **Subpoena of project assets** | State actor orders custodian (Robert, Foundation board, or registered entity) to hand over signing keys, contributor records, donor lists | Variable — depends on jurisdiction and asset class |
| **Forced license change** | Court orders project to switch licenses (e.g. "AGNOS poses national security risk, must permit government use without GPL terms") | High in adversarial jurisdictions; absent elsewhere |
| **Contributor employer retaliation** | Empire-aligned employer pressures employee-contributors to stop contributing, hand over IP, or modify code | Medium — employment contracts vary, but pressure is real |
| **Funding withdrawal** | Single funder pulls support; project unable to operate; assets revert to single point of failure | Low if dependent on one funder; high if diversified |
| **Hostile acquisition** | Empire-aligned entity offers to buy the project; founder accepts; mission drifts | Variable — depends on founder's resolve and structure |
| **Founder death / incapacity** | Project assets in founder's name are subject to estate proceedings; mission paused indefinitely | Inevitable eventually — must be planned for |
| **License enforcement gap** | GPL violations not enforced because no entity has standing; project becomes de facto proprietary in commercial use | Low — most open-source projects under-enforce |
| **Sanctions / export control** | Project legally barred from operating in certain markets or against certain users; contributors in sanctioned countries cut off | Increasing — see recent US export-control trends on AI/software |

### Why this matters for AGNOS specifically

AGNOS is structurally hostile to the empire's business model. The
empire's response options:

1. **Compete and lose** (technically AGNOS is better-positioned for
   privacy/sovereignty — unlikely path)
2. **Coopt** (acquire / influence / dilute — see Mozilla story)
3. **Legalize obsolete** (regulatory capture making AGNOS-class
   systems infeasible — early warning signs already visible in
   "online safety" legislation)
4. **Litigate** (patent suits, trademark suits, antitrust theater)
5. **Pressure custodians** (subpoenas, sanctions, employer
   retaliation)

Options 3, 4, 5 are governance-layer attacks. Code-level sovereignty
doesn't address them. The Foundation is the answer.

---

## Architectural commitments

### Commitment 1: Multi-jurisdictional asset distribution

**No single legal jurisdiction can effectively coerce the whole
project.** Project assets distributed across legal entities in at
least two jurisdictions with different legal traditions:

- **Primary**: a jurisdiction with strong open-source legal precedent
  and reasonable courts (e.g. US 501(c)(3), Netherlands Stichting,
  Switzerland Verein). Holds primary trademark + copyright assignment
  pool.
- **Secondary**: a jurisdiction in a different legal tradition that
  acts as a *fallback custodian*. If the primary jurisdiction becomes
  hostile, mission-critical assets (signing keys, trademark records,
  ability to continue operating) can transfer to the secondary
  without requiring the primary's cooperation.
- **Geographic + legal-tradition diversity matter more than count** —
  two entities in jurisdictions that move in lockstep (e.g. two EU
  member states) provide less protection than two in genuinely
  different traditions.

**Open question**: which two jurisdictions? Recommended preliminary
shortlist:
- **Switzerland** (Verein structure, strong neutrality precedent,
  separate from EU)
- **Netherlands** (Stichting structure, EU-aligned for European
  contributor base, strong open-source ecosystem)
- **US 501(c)(3)** (largest contributor pool, most open-source
  precedent, but US is increasingly adversarial on AI/encryption)

Pre-Foundation period (now), assets stay with Robert as creator. The
*goal* is multi-jurisdictional structure by v1.0.

### Commitment 2: License-as-shield (GPL-3.0-only, no exceptions)

**Already chosen, already locked.** GPL-3.0-only protects against:

- "Embrace and extend" capture by commercial vendors (any derivative
  must also be GPL-3.0)
- Tivoization (DRM-locked hardware preventing the user from running
  modified versions)
- Patent retaliation (GPLv3 patent clauses)
- Anti-DRM provisions

**Important**: the Foundation enforces the GPL. Without an entity
that has standing to enforce, the license is a hope. The Foundation
takes copyright assignment (or covenants not to sue, per the DCO
model) and *uses its standing to file when violations are material.*

**Open question — DCO vs CLA?** Two models:

- **DCO (Developer Certificate of Origin)** — contributors retain
  copyright; sign-off on commits affirms right to contribute. Used
  by Linux kernel. Pros: contributors keep IP, harder to be
  pressured. Cons: enforcement weaker — Foundation has no copyright
  to enforce on, only the contributor does.
- **CLA (Contributor License Agreement)** — contributors grant
  copyright (or perpetual license) to the Foundation. Used by
  Apache, FSF, many others. Pros: Foundation can enforce uniformly.
  Cons: concentrates IP in one entity, increases attack surface.

Recommended: **hybrid** — DCO by default (contributors retain
copyright), but Foundation acts as *enforcement coordinator* through
covenants and standing-rights agreements when material violations
occur. Avoids the IP concentration of pure CLA while still allowing
coordinated enforcement.

### Commitment 3: Contributor protection

**Contributors must be safe to contribute.** This means:

- No CLA copyright-transfer that hands employer-leverage to the
  Foundation
- Pseudonymous contribution accepted (real identity not required;
  use sigil-signed commits with cryptographic identity)
- Contributors in adversarial jurisdictions can route through
  pseudonyms + the parallel PKI; commits are verifiable without
  identity-binding
- Foundation does not maintain donor / contributor lists that can be
  subpoenaed beyond the minimum legally required
- Contributors retain copyright (DCO model — see above)
- Foundation provides legal defense fund for contributors targeted
  for project work

**Open question**: how to handle contributor disputes (mission drift,
code-of-conduct violations)? Mission drift cases need clear
arbitration. CoC enforcement needs explicit policy. Recommended:
defer to existing patterns (Contributor Covenant + neutral
arbitration via Software Freedom Conservancy or similar) for
operational specifics; encode the *outcomes* (no copyright transfer,
no pseudonym unmasking) in Foundation bylaws.

### Commitment 4: Asset segregation

**Project assets do not commingle with personal or commercial assets.**

| Asset class | Pre-Foundation custodian | Post-Foundation custodian |
|-------------|--------------------------|---------------------------|
| Code copyright | Contributors (DCO) | Contributors (DCO maintained) |
| Trademark `AGNOS` + subsystem names | Robert (registered as creator) | Foundation (primary jurisdiction) + mirrored secondary |
| Parallel-PKI root signing key | Robert (offline + paper backup) | Foundation board custodianship; M-of-N multi-sig |
| Domain registrations | Robert | Foundation, multi-registrar |
| Distribution infrastructure | Robert (current) | Foundation + community-mirrored |
| Financial accounts | Robert (informal) | Foundation accounts, transparent reporting |
| Build infrastructure / CI | Self-hosted, Robert-controlled | Self-hosted, Foundation-controlled with community ops |

The transition from "Robert holds everything" to "Foundation holds
everything" is the *purpose of the pre-Foundation phase*. Done
prematurely (before there's a community), it's premature. Done too
late (after assets become contested), it's impossible.

### Commitment 5: Funding diversity

**No single funder can pull the plug.** Foundation aims for:

- Multiple recurring funding sources (sustaining members, individual
  donors, project sponsorships)
- No single source > 25% of total annual budget
- Reserve fund covering at least 12 months of minimum operating cost
- Transparent annual financial reports (donors + amounts disclosed
  *only with consent*; categories + totals always public)
- Outreach to NPO-track grants in parallel to commercial-track equity
  (see [outreach framework memory](../../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_outreach_framework.md))

**The two-track outreach framework** (NPO commons vs commercial
equity) directly informs Foundation funding strategy:

- *NPO commons track* (Track A) feeds Foundation general operating
  budget; Foundation is the recipient; funds project core
  (compiler, kernel, ports)
- *Commercial equity track* (Track B) feeds parallel for-profit
  entities that pay royalties / licensing to the Foundation;
  Foundation is upstream beneficiary, never owns the commercial
  entity directly

This keeps the Foundation mission-pure (no commercial pressure on
the open-source core) while letting commercial AGNOS-adjacent work
exist and contribute back.

### Commitment 6: Succession planning

**The project survives Robert.** Robert is the BDFL of pre-Beta;
post-Foundation, role transitions to:

- Board chair (formal) + founder emeritus (cultural)
- Technical decisions move to a Technical Steering Committee of
  active maintainers, elected by contributors
- BDFL veto power exists in pre-Beta; sunsets at the Foundation
  formation milestone
- If Robert is unable to continue (death, incapacity, withdrawal),
  the Foundation continues operating on the existing bylaws — no
  single-point-of-failure for project continuity

**Open question — when does BDFL veto sunset?** Candidates:
- At Foundation formation (likely around v1.0)
- At first major-version release (v2.0)
- At a defined adoption threshold (e.g. 10K users)

Recommended: formal Foundation forms around v1.0; BDFL veto becomes
"founder advisory" (non-binding) at v2.0. This gives Robert
operational control through the founding arc while ensuring the
project becomes truly community-governed when it matures.

### Commitment 7: Mission lock

**Bylaws prevent mission drift.** The Foundation's articles of
incorporation must:

- Specify the mission explicitly (free, sovereign, agnostic
  operating system; user-protecting; community-governed)
- Prohibit license changes away from GPL-3.0-only
- Prohibit asset sale or transfer to commercial entities
- Require supermajority + multi-jurisdictional consent for any
  amendment that could change the above
- Provide for dissolution that returns assets to a compatible
  successor (e.g. SFC, FSF) rather than allowing private
  appropriation

The Mozilla Foundation/Corp story is the cautionary tale: mission
lock that wasn't strong enough, commercial pressure that eroded the
original vision. AGNOS Foundation bylaws need to be *aggressively
restrictive* compared to typical OSS Foundation bylaws.

---

## Two principles, never collapsed

Parallel to the technical-layer principles in companion docs:

| Layer | Grows when… | Never grows to… |
|-------|-------------|-----------------|
| **Foundation operational scope** | New projects/subsystems need governance umbrella; new funding sources need formal handling | Run commercial activities directly. Commercial entities are separate (see commitment 5); Foundation receives, never operates commercially. |
| **Foundation jurisdictional footprint** | New regions need legal coverage; primary jurisdiction becomes adversarial | Centralize. Even when one jurisdiction is friendly, mirror to a second. Single-jurisdiction Foundation = single-point-of-failure. |

**Why these boundaries are permanent**: The Mozilla pattern (single
jurisdiction, commercial subsidiary, gradual mission drift) is the
cautionary tale. AGNOS Foundation must structurally prevent each
failure mode the Mozilla story illustrates.

---

## Phasing

This is governance work, not code. The phasing is **deliberately
slow** — premature Foundation formation creates more attack surface
(formal entity to subpoena, financial accounts to seize) than it
defends; late Foundation formation lets pre-Foundation chaos become
hard to clean up.

| # | Phase | Status | Trigger |
|---|-------|--------|---------|
| 0 | **Pre-Foundation (current)** — Robert holds all project assets as creator. GPL-3.0-only license. DCO for commits. No Foundation entity exists. | ✅ Active | n/a |
| 1 | **Trademark filings** — file `AGNOS`, `Cyrius`, key subsystem names as trademarks in primary jurisdiction(s). Robert holds, assigns to Foundation when formed. | [ ] Queued | Pre-closed-beta — before public adoption begins, before squatters file |
| 2 | **DCO infrastructure** — every commit signed-off; sigil-signed commits accepted; pseudonymous contribution path documented | [ ] Queued | Pre-closed-beta — establishes pattern before contributor base grows |
| 3 | **Foundation legal counsel** — retain legal counsel familiar with multi-jurisdictional OSS Foundation work. Initial scope: jurisdiction selection, bylaws drafting, asset transfer planning | [ ] Queued | Around v1.0 prep — needs funding to begin |
| 4 | **Primary Foundation formation** — incorporate in selected primary jurisdiction. Initial board: Robert + 2-4 founding members. Bylaws drafted per commitments above. Asset transfer plan agreed. | [ ] Queued | At v1.0 release |
| 5 | **Asset transfer** — trademarks assigned to Foundation; signing-key custody migrates to Foundation board (M-of-N multi-sig); domain registrations transferred | [ ] Queued | Phase 4 + 6-12 months |
| 6 | **Secondary jurisdiction mirror** — second Foundation entity in different legal tradition; mirrored asset registrations; cross-jurisdictional cooperation agreement | [ ] Queued | After Phase 5 stabilizes |
| 7 | **Mature governance** — TSC elections, formal succession, transparent operations, BDFL → founder emeritus transition | [ ] Future | At v2.0 |

---

## Why this is in `development/`, not `vision/`

The temptation is to call this "v2.0+ vision work" and defer it. The
reason it belongs in development:

- **Trademark filings need to happen before adoption, not after.**
  Phase 1 isn't post-Beta — it's pre-closed-beta. If someone else
  registers `AGNOS` as a trademark before Robert does, the legal
  recovery is expensive and uncertain.
- **The parallel-PKI root key custody question** ([`parallel-pki.md`](parallel-pki.md#open-design-questions-resolve-when-phase-2-begins))
  immediately raises *who is the legal custodian*. That's a
  Foundation-structure question that needs at least a *preliminary*
  answer before parallel-PKI Phase 2 ships.
- **Contributor protection patterns** need to be established as the
  contributor base grows, not retrofitted later.
- **The empire's coercion-at-governance-layer attacks happen earliest**
  in a project's life when the structure is weakest. Mozilla had its
  worst pressure when it was small and undercapitalized. AGNOS
  shouldn't replay that.

Anchoring this doc in `development/planning/` keeps it visible as
strategic work, not deferrable speculation. Phase 1 (trademark) and
Phase 2 (DCO) should happen *during the MVP-to-closed-beta arc*, not
after.

---

## Open design questions (resolve in Phase 3, legal counsel engagement)

These are not for the next agent to resolve — they're for Robert to
work through with retained legal counsel. Capturing here so the
questions don't get lost.

1. **Primary jurisdiction**: US 501(c)(3), Netherlands Stichting,
   Switzerland Verein, or other? Trade-offs include US contributor
   base size vs. US increasingly adversarial AI/encryption climate.
2. **Secondary jurisdiction**: complementary legal tradition;
   recommended candidates: if primary = US, secondary = NL or CH; if
   primary = NL, secondary = CH or US; if primary = CH, secondary =
   NL or US.
3. **DCO vs CLA vs hybrid** (recommended hybrid; commitment 2 above).
4. **Mission-lock bylaws specifics** — how do you write
   bylaws that are amendable enough to fix unforeseen problems but
   restrictive enough to prevent the Mozilla drift pattern?
5. **Two-track outreach legal structure** — how do the NPO commons
   track (Foundation-direct) and commercial equity track (separate
   for-profit entities) connect legally so that royalties /
   licensing flow back without commingling? Likely answer:
   trademark-licensing agreements with explicit per-entity terms.
6. **Pseudonymous contribution and tax-deductibility** — donations
   to a 501(c)(3) require donor identity for receipt; how do
   pseudonymous contributors who *also* donate financially get
   handled? Likely separate paths: pseudonymous code contribution
   always allowed; financial donations require minimum identity per
   tax law, but minimal beyond that.
7. **Sanctions / export-control posture** — how does AGNOS handle
   the increasing tendency of US (and other) export controls to
   restrict open-source AI / encryption distribution? Foundation
   needs explicit legal-compliance strategy that doesn't
   compromise the universal-access mission.
8. **Trademark licensing policy** — strict (RedHat / Mozilla model:
   only blessed distributions can use the trademark) or permissive
   (Linux-kernel model: anyone can call their fork "Linux")?
   Recommended: middle — permissive for non-commercial use; require
   compliance attestation for commercial use; reserve right to revoke
   for misrepresentation.

---

## Pre-Foundation immediate actions (Robert can do now, no counsel needed)

Concrete, low-cost, time-sensitive:

1. **File trademark applications** for `AGNOS`, `Cyrius`, and any
   subsystem names with significant brand identity (e.g. `kybernet`,
   `agnoshi`) in primary jurisdiction(s). Filing now is far cheaper
   than recovery after a squatter beats us to it.
2. **Establish DCO sign-off** in contribution docs and CI. Pattern:
   `Signed-off-by: Name <email>` on every commit; CI enforces.
3. **Document the contributor IP model** in `CONTRIBUTING.md`
   (across all repos). Make clear: DCO, copyright stays with
   contributor, contributor warranties they have right to contribute,
   contributor accepts GPL-3.0-only for their contribution.
4. **Identify 2-4 candidate founding board members** — people who
   share the mission, have credibility in the relevant communities
   (security, open-source, privacy), and would accept board service
   when the Foundation forms. Quiet outreach, no commitments yet.
5. **Open a project bank account** separate from Robert's personal
   finances (even if pre-Foundation, this is the start of asset
   segregation). Use it for any project-related income or expense.
6. **Document signing-key custody** — even pre-Foundation, who has
   the parallel-PKI root key, where it's stored, what the recovery
   procedure is if the custodian is unreachable.

These six are immediate, cost ~hours not weeks, and prevent the most
common pre-Foundation failure modes.

---

## Cross-references

- **Strategic Vision** ([`../roadmap.md`](../roadmap.md#strategic-vision)) — the meta-defense layer of the empire-protection posture; without governance protection, technical sovereignty is a hope, not a guarantee.
- **Phase 23** ([`../roadmap.md`](../roadmap.md) — *to be added alongside Phases 20, 21, 22*) — the roadmap entry that points here.
- **Companion**: [`parallel-pki.md`](parallel-pki.md) — the cryptographic-identity layer; this doc holds the *legal-identity* layer that the parallel PKI needs to be defensible. Each depends on the other.
- **Companion**: [`cross-platform-compat-subsystem.md`](cross-platform-compat-subsystem.md) and [`dpi-resistance.md`](dpi-resistance.md) — together with this doc, form the four-layer empire-protection planning surface (compat / wire / trust / governance).
- **Outreach framework memory** ([`../../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_outreach_framework.md`](../../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_outreach_framework.md)) — the two-track NPO/commercial split directly informs Foundation funding strategy (commitment 5).
- ~~`vision/release-vision.md`~~ — retired 2026-05-12 (was fossil from pre-Cyrius-pivot era). Foundation governance content lived there as long-term concept; *this doc supersedes it* as the immediate planning layer.

---

*Locked: multi-jurisdictional, mission-locked, contributor-protecting Foundation as the meta-defense governance layer. Last touched 2026-05-12. Phase 1 (trademark filings) should start now, regardless of when later phases trigger. Pre-Foundation immediate actions are the most time-sensitive part of this doc.*
