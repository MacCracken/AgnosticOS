# DPI Resistance — Network-Stack Defense Against Traffic Surveillance

> **Status**: Planning — Design Phase | **Last Updated**: 2026-05-12
>
> Empire-class adversaries (ISPs, CDNs, state-level censors, corporate
> firewalls) increasingly identify and act on traffic at the
> *application-protocol fingerprint* level — not just by destination IP
> or port. AGNOS users are at risk of being **selectively throttled,
> blocked, or surveilled** the moment AGNOS traffic becomes
> distinguishable from generic web traffic on the wire.
>
> **Architectural commitment**: DPI resistance is not a bolt-on. It is a
> property of the AGNOS network stack itself — every AGNOS-native
> application gets it for free, every `cyrius` TLS connection looks
> indistinguishable from a mainstream browser by default, traffic shape
> normalization is the network-stack baseline.
>
> **Scope**: Cross-cutting — spans `agnosys` (network primitives),
> `cyrius` stdlib `net.cyr` / `tls.cyr` (TLS layer + fingerprint
> surface), possibly a new transport-policy crate (working name TBD,
> likely Sanskrit for "*marga*" — path / route), `kula` (mesh fallback
> when fully censored), `libro` (transport-decision audit trail).
>
> **Companion**: [`parallel-pki.md`](parallel-pki.md) — when commercial
> PKI is the deplatforming vector, parallel PKI is the answer; when DPI
> is the surveillance vector, this doc is. Both are parallel defenses
> against the same boundary problem: the wire between the user and the
> rest of the world is empire territory.

---

## The threat model

DPI (Deep Packet Inspection) and adjacent surveillance happens at
multiple boundaries, with overlapping capabilities:

| Boundary | Capability | Visibility | Adversary class |
|----------|------------|------------|-----------------|
| **ISP / last mile** | TLS SNI inspection, JA3/JA4 fingerprinting, flow analysis | Connection metadata, traffic shape | Commercial ISP (analytics + ad-injection), state-level (CALEA tap) |
| **AS-level / IXP** | NetFlow aggregation, BGP-level routing manipulation | Endpoint pairs, aggregate volumes | Tier-1 carriers, intelligence agencies |
| **CDN** | Full TLS termination, content inspection, user-agent + behavioral fingerprinting | Everything inside the CDN-terminated session | Cloudflare, Akamai, Fastly, AWS CloudFront — increasingly aggressive about identifying "bot" and "non-mainstream" clients |
| **Corporate firewall** | TLS inspection (via internal CA), category-based allow/deny, application-protocol detection | Everything when TLS-MitM is enforced; protocol categorization otherwise | Enterprise IT, university networks, hostile workplaces |
| **State-level censor** | Combination of all above + GFW-class active probing | Everything attacker can reach, plus active fingerprint discovery | National firewalls (GFW, Roskomnadzor, etc.); increasingly normal in Western jurisdictions under "online safety" framings |

### Why this matters for AGNOS specifically

**AGNOS traffic, if not normalized, is distinctive.** A native `cyrius`
TLS handshake has a different cipher-order, extension-order, and
GREASE-value pattern than Chrome. An AGNOS-built HTTP client may emit
characteristic header sequences. Mesh-protocol traffic from `kula` or
inter-AGNOS-node coordination has shape patterns no mainstream
deployment has.

The empire doesn't need to *block* AGNOS to act against it. It just
needs to *recognize* it. Once AGNOS is recognized:

- ISPs can throttle, deprioritize, or capture-page AGNOS users
- CDNs can refuse service (Cloudflare-class "is your browser legitimate"
  challenge walls)
- Corporate networks can ban AGNOS-on-the-wire at the firewall
- State-level censors can list AGNOS traffic as a "circumvention tool"
- Behavioral analytics can correlate AGNOS users across sessions even
  without identity leakage

**The defense isn't "hide AGNOS" — it's "make AGNOS-on-the-wire
indistinguishable from mainstream web traffic by default."** The
identity-protection benefit is structural: if AGNOS traffic looks like
Chrome-on-Windows traffic, the empire can't selectively act against it
without acting against Chrome-on-Windows users at scale.

---

## The six-layer defense

Mirrors the layering in [`agent-injection-defense.md`](agent-injection-defense.md).
Each layer addresses a different fingerprint surface. **Failure of any
single layer should not surface AGNOS to the network.**

### L1 — TLS fingerprint normalization

The most-fingerprinted thing on the wire is the TLS ClientHello.
JA3/JA4 hashes capture: TLS version, cipher suites + order, extensions
+ order, elliptic curves, EC point formats, GREASE values. Mainstream
browsers (Chrome, Firefox, Safari) have well-known fingerprints; AGNOS
must emit one of these by default, not a unique cyrius-stdlib
fingerprint.

**Architecture**: `cyrius` stdlib `tls.cyr` ships with a
*fingerprint-target* parameter. Default is "Chrome stable, current
major version." Available targets: Chrome stable, Firefox stable,
Safari stable. The target shifts automatically with stdlib upgrades
so we don't gradually become "Chrome from 2 years ago" (which is its
own fingerprint).

**Cost**: TLS extension ordering and cipher-suite selection are
ABI-visible — switching them requires a real network-stack
modification, not a config flag. utls-style implementations exist as
prior art.

**Where it lives**: `cyrius` stdlib (`lib/tls.cyr` already in scope —
the fingerprint surface lives here, not in agnosys).

### L2 — Traffic shape normalization

Even with TLS-fingerprint parity, traffic *shape* (packet sizes,
inter-packet timing, burst patterns, total session volume) is
distinctive per application. An AGNOS-native MCP coordination flow
looks different from `https://example.com/index.html`.

**Architecture**: opt-in per-connection padding + jitter at the
agnosys socket layer. Three modes:
- *Off* (default for local/intra-AGNOS) — no overhead
- *Normalized* (default for user-facing connections to public
  internet) — pad to size buckets, jitter timings to mainstream-traffic
  distributions
- *Aggressive* (opt-in for adversarial environments) — meek-class
  padding, full-bandwidth uniform shape

The mode is set per-connection via a capability the application either
has or doesn't (default: user-facing apps get *Normalized*).

**Cost**: bandwidth overhead (5-15% in Normalized, 50%+ in Aggressive).
Acceptable tradeoff for the protection delivered.

**Where it lives**: `agnosys` socket primitives + a new
transport-policy crate (working name `marga` — path/route in Sanskrit;
naming is TBD when Phase 1 begins).

### L3 — Pluggable transports (obfs4-class outer wrappers)

When the inner TLS is observed (corporate firewall doing TLS-MitM with
an internal CA, e.g.) or when even mainstream TLS gets blocked, the
defense moves to an *outer wrapper* that makes the entire connection
look like something other than TLS.

**Architecture**: support for obfs4, meek-with-domain-fronting, and
snowflake-class WebRTC tunneling as opt-in transports. Reuses
Tor-project's well-vetted patterns (do not reimplement crypto; use
their reference implementations or a clean-room Cyrius port of them).

**Cost**: latency + bandwidth overhead, plus configuration complexity
the user mostly doesn't see (the network stack auto-selects when
direct TLS is being interfered with).

**Where it lives**: separate transport crates loaded as modules into
the transport-policy layer.

### L4 — Domain fronting / decoy routing (where viable)

Historically powerful but fading: domain fronting (sending traffic
that *appears* to go to a CDN-hosted innocent host but the inner SNI
goes to the actual destination) is increasingly blocked by major CDNs.
Decoy routing (cooperating ISPs that redirect traffic at the network
level) is research-grade.

**Architecture**: support as opt-in for power-users + research, not
default. Maintain knowledge of which CDNs currently allow fronting;
auto-degrade to L3 when fronting is broken.

**Cost**: politically fragile (CDN cooperation), not durable as a
primary defense — but a useful arrow when available.

**Where it lives**: transport-policy layer; configurable per
deployment context.

### L5 — Mesh fallback (when fully censored)

When the user is in an environment where direct internet access to
needed services is fully blocked, AGNOS falls back to peer-to-peer
mesh coordination. Use a nearby AGNOS node as a relay; route through
the mesh to the destination.

**Architecture**: `kula` mesh layer (currently in the "future shared
crates" backlog) becomes the structural fallback. AGNOS nodes
coordinate transport policy: when one user is reachable, they relay
for others on the local mesh.

**Cost**: requires AGNOS adoption density to be useful (chicken-and-
egg). Initially limited to opt-in "friends and family" mesh; grows
organically.

**Where it lives**: `kula` + transport-policy integration.

### L6 — Steganographic channels (last-resort low-bandwidth)

For environments so aggressively surveilled that even pluggable
transports get detected, AGNOS supports steganographic channels: hide
small amounts of high-priority traffic inside ordinary-looking media
(images uploaded to social platforms, video frames, audio).

**Architecture**: low-bandwidth (kilobytes per minute), high-friction;
only for genuinely high-stakes communication. Compose with `shravan`
(audio codecs) and existing image-handling for the carrier media.

**Cost**: very low bandwidth, high CPU; deliberately limited use.

**Where it lives**: separate steg crate (future, post-MVP).

---

## Two principles, never collapsed

Parallel to the [compat subsystem's growth rule](cross-platform-compat-subsystem.md#two-growth-paths-never-collapsed):

| Layer | Grows when… | Never grows to… |
|-------|-------------|-----------------|
| **AGNOS network stack normalization** (L1, L2) | Mainstream browser fingerprints shift (annual update); new fingerprint surfaces are discovered | Become a unique "AGNOS fingerprint" — that defeats the purpose. If we can't match a mainstream target, we don't ship the protocol. |
| **Pluggable transports + mesh** (L3, L4, L5, L6) | Direct normalized TLS is being interfered with; new transports are needed | Be the default. Direct connections with L1+L2 are the normal path. Wrappers are exceptional. |

**Why the boundary is permanent**: if AGNOS network traffic ever
becomes *its own thing* on the wire (even a "well-known sovereign
fingerprint"), that thing is recognizable, and the empire can act on
it. Sovereignty at the OS layer requires *invisibility* at the network
layer — paradoxical but durable.

---

## Phasing

Real implementation work, sequenced post-MVP:

| # | Phase | Status | Dependency |
|---|-------|--------|------------|
| 1 | **L1 foundation** — JA3/JA4-normalized TLS in `cyrius` stdlib `tls.cyr`, target Chrome stable | [ ] Queued | Post-public-beta — needs stdlib stability |
| 2 | **L2 normalization** — agnosys socket padding/jitter primitives + per-connection capability model | [ ] Queued | Phase 1 |
| 3 | **L3 transport plugins** — obfs4 + meek port; transport-policy auto-detection | [ ] Queued | Phase 2 |
| 4 | **L5 mesh integration** — kula coordination of transport policy across local mesh | [ ] Queued | kula maturity + density |
| 5 | **L4 fronting / decoy** — opt-in advanced transports; updated knowledge base of which CDNs support fronting | [ ] Future | Phase 3 |
| 6 | **L6 steganographic channels** — low-bandwidth high-stakes carrier media | [ ] Future | Adoption + adversarial demand |

---

## Why this is in `development/`, not `vision/`

Same reasoning as
[`cross-platform-compat-subsystem.md`](cross-platform-compat-subsystem.md#why-this-is-in-development-not-vision):
this isn't speculative future-work. It's part of the **immediate
strategic arc** of being honest about what protecting users requires.
The moment AGNOS ships with any non-trivial adoption, traffic
identification becomes an attack vector. We need the architectural
commitment now so that whoever picks up the work doesn't relitigate
the fingerprint-target decision or treat normalization as optional.

---

## Open design questions (resolve when Phase 1 begins)

- **Fingerprint target — Chrome, Firefox, or rotating?** Chrome is the
  highest-traffic target (most cover) but most-fingerprinted; Firefox
  has cleaner crypto choices but less cover. Rotating per-session is
  detectable as "client that rotates" — itself a tell. Default
  recommendation: Chrome stable, with Firefox available as an opt-in
  config.
- **Per-application transport-policy granularity** — does every
  AGNOS-native app get the same default, or do high-risk apps (e.g.
  `agnoshi` exposing prompts to local inference) get aggressive
  defaults while low-risk apps (e.g. NTP sync) get minimal? Trade-off
  is complexity vs. context-appropriate protection.
- **What does the user see?** Power users want visibility into
  current transport policy; mainstream users want it to just work.
  CLI inspection via `agnosys netinfo` or similar; GUI surface TBD
  with `aethersafha` work.
- **Update cadence for browser fingerprint targets** — Chrome ships
  major versions every ~6 weeks. We need an automated mechanism to
  keep parity, not a manual sweep. Likely a build-time fetch of
  current Chrome JA4 from a maintained source.

---

## Cross-references

- **Strategic Vision** ([`../roadmap.md`](../roadmap.md#strategic-vision)) — the agnostic-commitment note now also covers this: parallel infrastructure for the wire layer, not just the OS layer.
- **Phase 21** ([`../roadmap.md`](../roadmap.md) — *to be added alongside Phase 20*) — the roadmap entry that points here.
- **Companion**: [`parallel-pki.md`](parallel-pki.md) — wire-layer surveillance vs. trust-layer deplatforming. Two parallel attack surfaces, two parallel defenses.
- **Companion**: [`agent-injection-defense.md`](agent-injection-defense.md) — same six-layer-defense template, applied to agent-layer threats rather than network-layer threats.
- **Companion**: [`cross-platform-compat-subsystem.md`](cross-platform-compat-subsystem.md) — same two-growth-paths-never-collapsed principle, applied to ABI rather than fingerprints.

---

*Locked: defense-in-depth at the network stack, default-on for user-facing connections, mainstream-fingerprint-by-default. Last touched 2026-05-12. When Phase 1 begins, this doc moves from "Planning — Design Phase" to "Planning — Active". The fingerprint-target decision is the first thing to resolve.*
