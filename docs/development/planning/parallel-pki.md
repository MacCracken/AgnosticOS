# Parallel PKI — Paper-as-Root-of-Trust

> **Status**: Planning — Design Phase | **Last Updated**: 2026-05-12
>
> Commercial certificate authorities (Let's Encrypt, DigiCert, Sectigo)
> and OS trust stores (Apple, Microsoft, Mozilla) can be coerced,
> subpoenaed, or unilaterally reorganized in ways that **revoke AGNOS's
> ability to authenticate itself** — to its users, to its updates, and
> to the wider internet. Trust-root capture is one of the empire's most
> potent deplatforming vectors because it requires no court order, no
> blockade, no DNS takedown — just a CA refusing to issue or a trust
> store removing an entry.
>
> **Architectural commitment**: AGNOS ships with a **parallel trust
> chain rooted in physical artifacts** — the 29 KB seed + SHA-256 chain
> distributed on bumper stickers, SD cards, and QR-encoded paper. The
> physical artifact *is* the signing authority. Any AGNOS install can
> verify any AGNOS-signed thing against the root without internet
> access, without commercial CA cooperation, without any rented
> infrastructure. The commercial PKI is *bridged* (cross-signed for
> browser compatibility) but never *required*.
>
> **Scope**: Cross-cutting — spans `sigil` (crypto primitives + signing
> infrastructure), `libro` (audit chain for signing events),
> distribution channels (DEF CON sticker, SD card, print-at-home), the
> 29 KB seed itself.
>
> **Companion**: [`dpi-resistance.md`](dpi-resistance.md) — when the
> wire-level surveillance is the attack vector, that doc answers; this
> doc answers when the trust-root attack is. Two parallel attack
> surfaces, two parallel defenses against the empire's leverage over
> the boundary between AGNOS and the world.

---

## The threat model

The commercial PKI ecosystem looks decentralized but is structurally
captured. Coercion vectors:

| Vector | Mechanism | Cost to attacker | Recovery for defender |
|--------|-----------|------------------|----------------------|
| **CA revocation** | Let's Encrypt / commercial CA refuses to renew or revokes existing certs | None — a policy decision | Months to find alternative CA, possibly impossible if all major CAs comply |
| **Trust store removal** | Apple / Microsoft / Mozilla remove a root CA from OS / browser trust stores | None — a software update | Catastrophic — affected software shows browser warnings, may refuse to run |
| **Registrar takedown** | Domain registrar revokes / unbinds project domain | Subpoena or terms-of-service action | New domain, but every existing cert + identity tied to old domain breaks |
| **CT log pressure** | Certificate Transparency logs refused or revoked, breaking the audit trail | Policy decision | Very limited — CT is critical infrastructure for trust |
| **HSTS-PRELOAD coercion** | Browser HSTS-preload list manipulated to enforce specific cert behavior | Browser policy | None — preload lists are unilateral |
| **CA/B Forum policy shifts** | Industry-body decisions change cert lifecycle (90-day, 47-day, eventually shorter) — increases coercion frequency | Industry consensus | None — AGNOS doesn't sit at the CA/B table |

### Why this matters for AGNOS specifically

**AGNOS's update pipeline, package distribution, and inter-node trust
all depend on cryptographic identity.** If those identities depend on
commercial CA cooperation:

- A single subpoena or policy decision can break AGNOS update
  signatures globally — users either accept unsigned updates (security
  catastrophe) or stop receiving updates (fork/abandonment)
- A trust-store removal can make every AGNOS-distributed binary show
  "untrusted" warnings on consumer OSes — chilling adoption
- A registrar takedown can break every existing certificate that
  references project domains
- The structural-immunity argument elsewhere in AGNOS (CVE-2026-31431,
  agent injection) is undone if the *identity layer* is rented from an
  attacker-controlled vendor

**The defense isn't "stay friends with Let's Encrypt." It's a parallel
trust root that doesn't depend on any commercial CA — anchored in
physical artifacts that survive digital takedown.**

---

## The architecture — paper as the signing authority

The 29 KB seed (Cyrius bootstrap) is already the cryptographic genesis
of the entire AGNOS ecosystem: byte-identical reproducible builds
across four platforms, hash-chained from the seed forward through
every artifact. The seed is *also* the trust root.

```
┌─────────────────── Physical artifact (paper / sticker / SD) ───────────────────┐
│                                                                                │
│  QR-encoded:                                                                   │
│    • 29 KB cyrius seed (bootstrap)                                            │
│    • SHA-256 hash chain header                                                │
│    • Root signing public key (Ed25519)                                        │
│    • Project canonical URL (for graceful bootstrap when online)               │
│                                                                                │
│  Printed:                                                                      │
│    • Human-readable hash fingerprint (groups of 4 hex)                        │
│    • QR code (machine-scannable)                                              │
│    • Project name + version                                                   │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
       │
       │ Scan / read / type into any AGNOS install
       ▼
┌─────────────────────── AGNOS local trust store ────────────────────────────────┐
│                                                                                │
│  Root: Ed25519 public key (from QR / paper)                                    │
│   │                                                                            │
│   ├── Project key (long-lived offline): cyrius project, agnos kernel project, │
│   │   ark project, etc. Each signed by root via the offline ceremony.         │
│   │                                                                            │
│   ├── Build key (per release): per-version signing key signed by project key │
│   │                                                                            │
│   └── Leaf signatures: per-binary, per-artifact sigil signatures, signed by  │
│       build key. libro audit chain links every signing event.                  │
│                                                                                │
│  Bridge: commercial CA cross-signatures stored alongside parallel chain.      │
│  Used opportunistically (browser compat) — never as the trust foundation.     │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

**The key property**: any AGNOS install that has the physical artifact
(or has loaded its contents) can verify *any* AGNOS-signed thing
without internet, without commercial CA, without rented
infrastructure. The verification path:

1. User holds physical artifact (sticker / card / printed sheet)
2. AGNOS reads/scans the artifact, extracts root pubkey + seed hash
3. AGNOS downloads or receives any artifact (binary, update, message)
4. AGNOS verifies the signature chain: artifact → build key → project
   key → root key (from artifact)
5. Verification succeeds entirely offline; commercial CA never
   involved

**The empire cannot revoke a sticker.**

### Why physical media is durable

| Property | Digital CA | Physical artifact |
|----------|-----------|-------------------|
| Revocable by issuer | Yes (Let's Encrypt can revoke at any time) | No (paper doesn't have a revocation API) |
| Subpoena-able | Yes (court order on CA operator) | No (paper is the user's possession) |
| Network-dependent | Yes (OCSP / CRL fetches required) | No (offline verification) |
| Tamper-evident | Software-evident (CT logs) | Physical-evident (hash fingerprint visible) |
| Distribution requires permission | Yes (CA business decision) | No (anyone can print) |
| Geographically targetable | Yes (CA can refuse per-country) | Hard (paper crosses borders trivially) |
| Survives long-term outage | No (cert expiry, OCSP downtime) | Yes (paper doesn't expire — only the key rotates, on AGNOS's schedule) |

The bumper-sticker-as-paper-signing-authority idea isn't just a DEF
CON novelty. It's the **structural answer to "what if the empire
revokes our certs."** The answer: it can't. Our root lives on cards
in people's wallets, stickers on laptops, prints in folders. Nothing
the empire can do — short of physically confiscating every artifact —
can remove the trust root.

---

## Bridging to commercial PKI

Pure separatism isn't usable. If AGNOS users try to visit
`agnos.example` and the browser shows a warning because the cert
isn't signed by a trusted commercial CA, adoption stalls. The bridge:

**Cross-sign opportunistically.** Project artifacts have *both*:

- The parallel-PKI signature (always present, the load-bearing trust)
- A commercial CA signature (when available, for browser compat)

When the commercial CA cooperates, the user sees a "trusted" cert and
no warning — friction-free. When the commercial CA refuses or is
revoked, AGNOS still verifies the artifact against the parallel chain
internally; the browser may show a warning but **AGNOS itself never
fails to trust its own artifacts**.

This is the same pattern as Linux distros' "we ship our own signing
keys *and* we cross-sign with commercial CAs for browser support" —
but turned permanent and structural rather than coincidental.

---

## Two principles, never collapsed

Parallel to [the compat subsystem's growth rule](cross-platform-compat-subsystem.md#two-growth-paths-never-collapsed)
and the [DPI-resistance principle](dpi-resistance.md#two-principles-never-collapsed):

| Layer | Grows when… | Never grows to… |
|-------|-------------|-----------------|
| **Parallel PKI** (paper-rooted, sigil-anchored) | New project keys are needed; key rotation per scheduled ceremony; new physical artifact formats (e.g. NFC card alongside QR) | Depend on a commercial CA. The root is paper, full stop. |
| **Commercial CA bridge** (cross-signed certs) | Browser / OS-trust-store compat is needed for specific deployments | Become the primary trust chain. The bridge is convenience; the root is paper. |

**Why the boundary is permanent**: if the parallel chain ever
*requires* the commercial bridge to function, the empire wins by
revoking the bridge. The parallel chain must always be the load-bearing
trust. The bridge is opportunistic add-on. Even if every commercial CA
in the world refused AGNOS tomorrow, AGNOS continues to function — at
the cost of browser warnings, not at the cost of broken signatures.

---

## Phasing

| # | Phase | Status | Dependency |
|---|-------|--------|------------|
| 1 | **sigil-rooted signing infrastructure** — ed25519 + SHA-256 chain primitives, offline-friendly verification | ✅ Substrate (sigil 3.1.1 ships this) | n/a |
| 2 | **Parallel-PKI verification path** — any AGNOS install can read a paper artifact, load the root key, and verify any AGNOS-signed binary | [ ] Queued — closed-beta scope | sigil 3.1.x + libro 2.6.x |
| 3 | **Cross-signing infrastructure** — pipeline to produce both parallel-signed and commercial-CA-signed artifacts | [ ] Queued | Phase 2 + Let's Encrypt or commercial CA pipeline |
| 4 | **Public artifact distribution — DEF CON 2026 August** | 🔄 Planned in roadmap (the bumper-sticker beat) | Phase 2 (paper-PKI must work before the artifact is meaningful) |
| 5 | **Print-at-home tooling** — `agnos pki print` generates a QR card with the current root + verification instructions, any user can print their own | [ ] Queued | Phase 2 |
| 6 | **Mirror network + transparency log** — distributed signing-event log so revocation history is publicly auditable | [ ] Future | Post-public-beta |
| 7 | **Key rotation ceremony** — formal process for root rotation (e.g. annual), how new artifacts supersede old ones without breaking old artifacts | [ ] Future | Phase 4 + governance maturity ([foundation-structure.md](foundation-structure.md)) |

---

## The DEF CON August 2026 beat

The roadmap's near-term cadence already includes:

> **August**: DEF CON / Black Hat distribution. ~$5K budget: 10K
> stickers + 500 SD cards + 1K quick-start cards. Bumper-sticker-as-
> cryptographic-root-of-trust: QR-encoded 29KB seed + SHA-256 chain +
> URL → **sticker becomes paper signing authority.**

This doc is the *architectural commitment behind that beat*. The
sticker isn't a marketing artifact. It's the trust-root distribution
mechanism. Treat it accordingly:

- The sticker QR encodes the actual root pubkey, not a marketing URL
- The 29 KB seed is byte-identical to the canonical seed (verify
  against the project repo before printing)
- The hash chain header is included so a recipient can chain-verify
  forward through any later artifact
- The human-readable hash fingerprint allows visual verification
  ("does this sticker match the one I already have")
- The print run becomes the trust-root distribution event of record;
  later additions chain forward through CT-log-equivalent transparency
  infrastructure

**Without Phase 2 shipped before August, the sticker is just a
sticker.** That's the dependency to call out.

---

## Why this is in `development/`, not `vision/`

Same reasoning as the companion docs: this is **immediate strategy**,
not speculative future-work. Closed-beta cohort (Phase 13A) needs to
verify AGNOS artifacts to trust their installs. They can't depend on
Let's Encrypt because Let's Encrypt doesn't know about AGNOS's signing
needs and could refuse at any time. They need the parallel chain
working *now* — at least in basic form — to have a real trust path
between the project and themselves.

---

## Open design questions (resolve when Phase 2 begins)

- **Root key location** — offline HSM, paper backup, or both? Paper
  backup makes the root recoverable from physical disaster but is also
  a stealable single point of failure. Recommended default: paper
  backup + offline HSM at multiple geographic locations; root rotation
  on schedule.
- **Key rotation cadence** — annual? Per major version? Driven by
  cryptographic standard shifts (e.g. post-quantum migration)?
- **QR encoding format** — raw bytes vs. text-encoded? Single QR vs.
  series? Capacity matters: 29 KB seed alone is ~10 QR codes at
  current density. May need a "lite" sticker (just root pubkey + URL
  to fetch seed) and a "full" sticker (everything offline).
- **Cross-signing relationship** — formal Let's Encrypt or commercial
  CA partnership? Or just opportunistic dual-signing? Tradeoff:
  partnership = better cross-sign reliability but ties project
  identity to the CA's continued cooperation.
- **Transparency log infrastructure** — run our own (sovereign but
  small) or use existing CT logs (broader audit but empire-controlled)?
  Recommended: run our own + mirror to existing CT logs while they're
  available; never depend on existing CT logs as the only history.
- **Anti-counterfeit measures** — what stops someone from printing
  fake stickers with a different root pubkey to phish AGNOS users?
  Holographic stickers? Hash-fingerprint comparison to canonical
  source? Multiple-channel verification (sticker + project repo +
  community-distributed mirrors)?

---

## Cross-references

- **Strategic Vision** ([`../roadmap.md`](../roadmap.md#strategic-vision)) — the agnostic-commitment note covers parallel infrastructure across multiple layers; this is the *trust layer* of that commitment.
- **Phase 22** ([`../roadmap.md`](../roadmap.md) — *to be added alongside Phase 20 + 21*) — the roadmap entry that points here.
- **August DEF CON cadence beat** ([`../roadmap.md`](../roadmap.md#near-term-cadence--may-1-v1-to-def-con)) — the physical distribution event that makes this real-world.
- **Companion**: [`dpi-resistance.md`](dpi-resistance.md) — wire-layer surveillance vs. trust-layer deplatforming; two parallel attack surfaces.
- **Companion**: [`foundation-structure.md`](foundation-structure.md) — the legal/governance layer that holds the trademarks, copyrights, and signing-key custody. Without Foundation governance, the parallel PKI is undermined by *who controls the root key*. The two docs depend on each other.
- **Companion**: [`agent-injection-defense.md`](agent-injection-defense.md) + [`cross-platform-compat-subsystem.md`](cross-platform-compat-subsystem.md) — same architectural pattern (parallel infrastructure rather than capture-resistant integration with empire infrastructure).

---

*Locked: paper-rooted trust chain, commercial CA as opportunistic bridge only. Last touched 2026-05-12. When Phase 2 begins, this doc moves from "Planning — Design Phase" to "Planning — Active". Root key location is the first thing to resolve.*
