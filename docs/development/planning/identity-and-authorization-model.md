# Identity & Authorization Model — Recognition Over Interrogation

> **Status**: Planning — Design Phase (fluid; mechanisms evolve as research/hardware/UX mature) | **Last Updated**: 2026-05-12
>
> AGNOS rejects the Unix-login-by-default pattern as the wrong shape for
> single-owner sovereign devices + AI agents. The empire's "authenticate
> at the device, then your session can do anything" model imports
> assumptions from 1970s mainframes and 2010s federated-identity
> platforms that don't match the AGNOS problem space.
>
> **Architectural commitment**: **recognition over interrogation;
> authorization > authentication.** The device tries to *know* who's
> there (ambient, continuous), offers a way to correct it when wrong,
> and gates sensitive operations behind *capability checks* that fire
> regardless of who the system thinks is at the keyboard. Authentication
> is best-effort; authorization is rigorous.
>
> **Fluid-document caveat** explicit: the mechanism choices per layer
> (biometric vs token vs behavioral vs password) are open research
> questions with no clean answer. The architecture commits to the
> *framework* — layered concerns, pluggable mechanisms, recognition
> primary, capability-gates primary security — and explicitly defers
> mechanism selection to "evolves with hardware and UX research." This
> doc updates as the research matures.
>
> **Scope**: Cross-cutting — spans `sigil` (cryptographic identity),
> `kavach` (capability sandboxing), `t-ron` (MCP-boundary policy),
> `libro` (audit chain), `avatara` (identity overlay + bonded
> recognition), `kula` (cross-device family/clan mesh), kybernet (PID 1
> service launch + console attach), agnoshi (the shell that receives
> the bonded user).
>
> **Companion**: [`agent-injection-defense.md`](agent-injection-defense.md) —
> capability-gates-at-the-agent-boundary; this doc is capability-gates-at-the-user-boundary.
> Both implement the same "authorization is the primary security layer"
> principle at different surfaces. [`foundation-structure.md`](foundation-structure.md) —
> Foundation governance is the meta-layer that holds the project across
> the multi-year horizon while this doc evolves.

---

## The thesis

Three commitments, in order of architectural weight:

1. **Authentication and authorization are separate concerns** that the
   empire's model conflates. Authentication is "who is at this device";
   authorization is "what may this process do." Conflating them
   produces the failure mode where one cracked password grants
   unlimited subsequent action. AGNOS keeps them separate: the user
   recognized at the device is *not* automatically authorized to drain
   the wallet — irreversible operations need *fresh* per-action
   confirmation regardless.

2. **Recognition is the right shape for authentication on a
   sovereign device**, not interrogation. A device you own should *try
   to know* you — passively, continuously, ambiently — and offer a
   correction path when wrong, rather than *demanding proof* every time
   you sit down. The empire model is interrogation-shaped because the
   empire's devices aren't yours; AGNOS inverts that.

3. **Theft, presence, identity, and capability are four separate
   layers** with four separate mechanism stacks. They don't share a
   single "login" abstraction. Encryption-at-rest answers theft.
   Auto-lock + presence recognition answers presence. Multi-user
   differentiation answers identity. Per-action capability gates answer
   authorization. Conflating them is the empire's mistake.

---

## Why Unix login is the wrong default for AGNOS

The Unix-login pattern (`getty` → `login` → `/etc/passwd` → `uid` →
`shell`) was the right answer to a 1970s problem: multi-user mainframes
running time-sharing systems, where physical resource access *was* the
authorization model, accounts *were* the billing unit, and `uid` *was*
the natural permission root. Linux generalized that pattern to personal
computers by making `root` the founder and ordinary users feudal
subjects, requesting privilege via `sudo`. It works, but it's a model
designed for multi-tenant mainframes pretending to serve single-user
desktops.

The empire then layered federated identity (OAuth, "Sign in with X")
on top of that base. Now every interaction with the wider network
requires authenticating to a third-party identity provider that the
user doesn't control. Empire-shaped from the bottom up:

| Empire layer | What it assumes | What AGNOS rejects |
|---|---|---|
| Unix login at boot | Multi-user device, must prove identity to enter | Sovereign device — proving identity to *your own* device is security theater |
| Federated identity for services | Identity belongs to platform vendors | Identity belongs to the user, rooted in their own cryptographic keys ([parallel-pki.md](parallel-pki.md)) |
| Session-grants-all-powers | Authentication = authorization | Authentication is best-effort; authorization is per-action, capability-gated |
| Account/uid as multi-user primitive | Permissions are coarse-grained by user | Permissions are fine-grained by capability ([kavach](../../../../../Repos/kavach/CLAUDE.md), [t-ron](../../../../../Repos/t-ron/CLAUDE.md)) |
| Sudo-and-retype-password for privilege | Password reprompt = intent verification | Physical presence + capability token = intent verification |
| syslog (mutable, root can rewrite) | Audit is best-effort | [`libro`](../../../../../Repos/libro/CLAUDE.md) cryptographic audit chain (append-only, tamper-evident) |

Notice the structural pattern: every empire-layer assumption maps to a
specific AGNOS subsystem that already implements the alternative. The
parts are all there. This doc names the *framework* that ties them
together.

---

## The four-layer model

Each layer is a separate concern with its own threat model and its own
mechanism stack. Don't combine them.

### Layer 1 — Theft (encryption at rest)

**Threat**: Physical theft of the device. Adversary has unbounded time
in unknown location. Possibly disassembles the storage to bypass any
OS-level controls.

**Defense**: Full-disk encryption rooted in `sigil`. Power-off + theft
= adversary holds encrypted bricks. Unlock key derived from one or
more of:
- Hardware token presence (Yubikey, smartphone via NFC/Bluetooth)
- Boot-time password (single fallback, not the primary)
- TPM-bound + verified-boot chain (the `agnosys-trust` profile that
  kybernet 1.2.0+ already pulls in for edge boot)

**Independent of login UX entirely.** Unix systems also need this
(LUKS, FileVault, BitLocker); the answer doesn't change based on
authentication model.

**Mechanism status today**: `sigil` provides cryptographic primitives;
the storage-encryption integration is a future kavach-3.x / kybernet
edge-boot enhancement. Not closed-beta-MVP scope (the MVP is "boot to
shell" — encryption at rest comes when persistent storage comes).

### Layer 2 — Presence (active-while-away)

**Threat**: Brief physical absence in a partially-trusted environment.
Coffeeshop, shared workspace, family member walking past unattended
desk. Adversary is opportunistic, has limited time, may not be
explicitly hostile (just curious / nosy).

**Defense**: Auto-lock on inactivity + a re-presence mechanism. The
device locks after `N` minutes idle (or on explicit gesture); re-unlock
requires whichever presence-mechanism is configured.

**Mechanism options** (any can be the active choice; user picks):

| Mechanism | Pros | Cons |
|---|---|---|
| **Hardware token tap** (Yubikey, phone proximity) | Fast, no biometric capture, no password | Requires hardware, can be lost/stolen |
| **Behavioral resumption** (typing rhythm, mouse pattern) | Ambient, no friction | Training period, drift, false positives |
| **Biometric** (fingerprint, face) | Fast, hardware-bound | Privacy-loaded, irrevocable if compromised, accuracy issues |
| **Phone-presence** (BlueZ-paired device near keyboard) | Convenient, multi-device-coherent | Requires phone, spoofable in some adversary models |
| **Password fallback** | Universal hardware support, simple | Friction, phishing-vulnerable, reuse |

**Layer 2 boundary**: this is about brief presence-while-active, not
about identifying *who* is present. The device knows *it's you* (or
not) based on the chosen mechanism. Multi-user differentiation is
Layer 3, separate concern.

### Layer 3 — Identity (multi-user differentiation)

**Threat**: Shared device used by multiple humans (household,
collaborator, multi-context professional). Each user has their own
preferences, their own daimon companions, their own data, their own
`sigil` identity for remote services. The device needs to know whose
context to load.

**Defense**: Recognition-first, switch-user-fallback.

The device *attempts* to know who's there from ambient signals:
- Typing rhythm (the avatara extension for bonded recognition)
- Voice (`shabda` if a mic is present)
- Time-of-day patterns (different humans use the device on different
  schedules)
- Proximity signals (whose phone is nearby, whose Yubikey is inserted)
- Visual recognition (`chakshu` if a camera is configured and the user
  consented)

When recognition is confident, the device loads that user's
`avatara` overlay (their identity context — bonded daimons,
preferences, `sigil` keys, kavach policies). When uncertain or wrong,
the device presents a *lightweight switch* — a list of known users,
pick one. Not a password challenge; a recognition correction.

**Multi-user via avatara overlay, not via uid.** Same kernel process
space, different identity contexts. Each user's data sits behind
their `sigil` identity; their `kavach` capabilities are theirs.

**The household case** (which is genuinely hard): the system can't
differentiate parents from kids without *some* signal. Volunteered
("I'm Robert"), inferred (typing rhythm), or contextual (your phone is
here) are the three signal classes. AGNOS supports all three; the user
picks which mix matters to them.

### Layer 4 — Capability (per-action authorization)

**Threat**: Authentication was wrong (recognition false-positive,
stolen token, social engineering, agent compromised). The wrong entity
is now at the keyboard or driving an agent — and they try to do
something irreversible / sensitive / privilege-escalating.

**Defense**: Per-action capability gates. The action *cannot proceed*
without an explicit per-action authorization signal, regardless of who
the system thinks is at the keyboard.

**This is the load-bearing security layer.** Authentication failure
doesn't cascade into authorization failure if authorization is
rigorous. The wallet doesn't drain even if recognition was wrong
because the irreversible-action gate fires anyway.

**Per [agent-injection-defense.md L4](agent-injection-defense.md)** the
gate for irreversible actions is:
1. A capability the calling process must hold (`kavach`)
2. A *confirmation token* issued by an out-of-band channel (physical
   button, hardware token tap, explicit user gesture) — not derivable
   from the current session alone
3. Logged irrevocably to `libro` (whatever happened, there's a record)

**Examples of "sensitive enough to require capability gates":**
- Disk format / partition modification
- Permanent file deletion (vs trash/recycle)
- Outbound payment / cryptographic signature on financial transaction
- Granting agent capability to access sensitive data domain
- Adding a remote service to the trusted set
- Changing the boot configuration / signed-firmware updates
- Cross-user data access (one avatara reading another's sigil-encrypted data)

**Examples of *NOT* requiring fresh authorization** (don't introduce
friction for routine work):
- Opening files in your own avatara context
- Launching trusted local services
- Routine agent interactions within scoped capabilities the user
  granted at agent-creation time
- Reading already-decrypted state

The line is **irreversibility + cross-domain reach**. Reversible
in-context actions stay frictionless; irreversible or cross-domain
actions require the fresh signal.

---

## Cross-cutting principles

### Principle 1 — Recognition over interrogation

Default to *trying to know* the user (ambient, continuous, passive),
not *demanding proof* (active, one-shot, interrupting). When
recognition is wrong, *offer a correction* (light gesture, switch-user
pick), not a *challenge* (type your password).

**Why**: Sovereign devices don't owe their owners proof-of-identity at
every interaction. Interrogation is the empire's posture because
empire devices doubt their users; AGNOS's posture is that the device
*trusts the user is its owner until evidence accumulates otherwise*.

### Principle 2 — Authorization > authentication

The primary security layer is **capability-per-action**, not
**identity-at-entry**. Even with perfect authentication, sloppy
authorization fails. Even with imperfect authentication, rigorous
authorization holds.

**Concrete corollary**: any "the user is authenticated" is a *weakest*
guarantee, not a strongest one. Code that relies on it without
additional capability checks is doing the empire's mistake. `kavach`,
`t-ron`, and the `agent-injection-defense` L4 gates are the actual
security boundary.

### Principle 3 — Pluggable mechanisms per layer

Each of the four layers accepts *multiple mechanism implementations*.
The user (or admin) picks per-layer; mechanisms can be combined
(any-of, all-of). The architecture doesn't bake in a specific
mechanism choice — that lets the UX evolve as research matures and
hardware availability changes.

**Concrete corollary**: AGNOS ships with multiple mechanism options
for each layer and defaults to the lightest/least-invasive that's
viable for the user's hardware. Users escalate to heavier mechanisms
(token, biometric, password) when they explicitly choose to.

### Principle 4 — Context modulates friction, not capability

Trusted locations (home WiFi SSID, known Bluetooth devices nearby,
expected time-of-day) can *reduce auth friction* — auto-resumption
from lock might require only a typing-rhythm confirmation in trusted
context vs a hardware token elsewhere. But context **does not grant
additional capabilities**. The same user has the same authorization
set in every context; what changes is how easily they can re-attest
their presence.

**Why**: Anything that grants more *power* in trusted context is
spoof-vulnerable (fake WiFi SSID, fake GPS, fake phone-proximity). But
context as a *convenience modulator* is safe — failure mode is
reverting to higher-friction auth, not granting unwarranted powers.

### Principle 5 — Theft is solved independently

Encryption at rest answers theft. Power-off + encrypted = thief gets
nothing usable. This is a *separate* mechanism stack from
authentication. Don't conflate them.

**Concrete corollary**: a stolen powered-on AGNOS device is still
vulnerable to *that session's* state until auto-lock kicks in. Theft
defense extends to *unattended time-to-lock*, not just at-rest
encryption. Configure both layers explicitly.

---

## How this maps to existing AGNOS subsystems

| Subsystem | Role in this framework | Status |
|---|---|---|
| **`sigil`** ([repo](https://github.com/MacCracken/sigil)) | Cryptographic identity primitive. User's identity-to-the-network is rooted here. Storage encryption keys derive here. | Shipping (3.1.1) |
| **`kavach`** ([repo](https://github.com/MacCracken/kavach)) | Sandbox + capability primitives. Per-action authorization gates live here. | Shipping (3.2.1) |
| **`t-ron`** ([repo](https://github.com/MacCracken/t-ron)) | MCP-boundary capability policy. Agent-side authorization gates. | Shipping (2.1.4) |
| **`avatara`** ([repo](https://github.com/MacCracken/avatara)) | Identity overlay; will extend to bonded recognition as research matures (typing rhythm, voice, ambient signals) | Shipping (2.3.0); bonded-recognition extension is future |
| **`libro`** ([repo](https://github.com/MacCracken/libro)) | Cryptographic audit chain. Every privileged action logged tamper-evidently. | Shipping (2.6.3) |
| **`kula`** | Family/clan mesh for cross-device identity propagation. Future shared crate. | Future (post-MVP) |
| **`chakshu`** | Visual recognition (camera) if user has hardware + consent. | Shipping (0.3.0) — not currently wired to identity layer |
| **`shabda`** | Speech recognition; voice-based identity signal. | Shipping (varies) — not currently wired to identity layer |
| **kybernet** ([repo](https://github.com/MacCracken/kybernet)) | PID 1 sets up the user-session context, attaches the recognized user's avatara to console / tty / agnoshi | Shipping (1.2.1); current MVP is single-user no-recognition |
| **agnoshi** ([repo](https://github.com/MacCracken/agnoshi)) | The shell that receives the bonded user; presents the (eventually) AI-augmented interface | Shipping (1.3.2); currently no-auth single-shell |

The architecture doesn't need new subsystems — it needs the *framework* across the existing ones to be made explicit (this doc).

---

## Phasing

This is **post-public-beta** for full implementation. Closed-beta MVP
is single-user no-auth (as currently shipping). The framework matures
as the project does.

| # | Phase | Status | Trigger |
|---|-------|--------|---------|
| 1 | **Document the framework** (this doc) | ✅ Phase 1 of this work; 2026-05-12 | n/a — establishing the architectural commitment |
| 2 | **Layer 1: encryption at rest** — sigil-rooted FDE, kybernet edge-boot integration | [ ] Queued (post-public-beta) | When persistent storage lands (Phase 2 of agnosticos 13A — public beta) |
| 3 | **Layer 2 mechanism shipping**: hardware-token tap + password fallback as initial mechanism set | [ ] Queued | Post-public-beta |
| 4 | **Layer 3 multi-user via avatara overlay**: switch-user UX, separate sigil identities per overlay | [ ] Queued | Once Layer 2 is solid + avatara extensions ready |
| 5 | **Layer 4 capability-gates UX**: physical-presence button / token-tap for irreversible actions | [ ] Queued | Parallel with kavach 4.x + agent-injection-defense Phase 2 |
| 6 | **Bonded-recognition research arc**: typing rhythm, voice, ambient signals — replace volunteered switch-user with passive recognition | [ ] Future research | Multi-year horizon; tied to conscious-objects work in [`../vision/conscious-objects.md`](../vision/conscious-objects.md) |
| 7 | **Context modulation**: WiFi SSID / BlueZ / time-of-day as friction modulators | [ ] Future | When daily-driver use surfaces the need |

---

## Two principles, never collapsed

Mirroring the patterns in [`cross-platform-compat-subsystem.md`](cross-platform-compat-subsystem.md),
[`dpi-resistance.md`](dpi-resistance.md), [`parallel-pki.md`](parallel-pki.md):

| Layer | Grows when… | Never grows to… |
|-------|-------------|-----------------|
| **Authentication** (recognition, presence, identity) | New mechanisms become viable (better behavioral models, new hardware tokens, new sensors). Recognition gets more accurate. | Replace authorization. Stronger auth doesn't relax authorization. |
| **Authorization** (capability gates, per-action confirmation) | New action classes need protection (new sensitive operation, new agent capability). The gate surface grows with the action surface. | Trust authentication. Even with perfect authentication, every irreversible action gets a fresh gate check. |

**Why the boundary is permanent**: the empire's failure mode is
*authentication-grants-authorization*. Once you're logged in, you can
do anything (in your scope). AGNOS's structural-immunity claim depends
on never making that mistake. Authentication and authorization stay
permanently separate; capability gates stay primary.

---

## Why this is in `development/`, not `vision/`

Same reasoning as the other Phase 20+ planning docs:

- The framework affects **current and near-term code** — kybernet's
  PID-1 setup, kavach's capability primitives, t-ron's policy gates,
  the agent-injection-defense L4 work. Even though full implementation
  is post-public-beta, *not introducing the empire pattern by default*
  starts now.
- **Closed-beta MVP is single-user no-auth** — that's compatible with
  this framework (Layers 1-3 deferred, Layer 4 nascent). What this doc
  prevents is anyone retrofitting `/etc/passwd` / `getty` / `login`
  into kybernet "because that's how Linux does it." Stop the
  empire-pattern import at the architectural commitment.
- **Multi-year fluid evolution** is consistent with `development/`
  planning — the foundation-structure doc has similar long-horizon
  phasing.

---

## Open design questions (live)

These don't have answers today and may not have answers for years.
Captured here so they don't get re-litigated each time:

1. **Default Layer 2 mechanism** — when AGNOS ships an MVP that
   includes lock-screen behavior, what's the default? Hardware token
   only? Password fallback? Behavioral-with-password-escape? The choice
   matters for adoption (password is universal but high-friction) and
   for security (behavioral is friction-light but immature).

2. **Bonded-recognition training period** — behavioral recognition
   needs training time. How does a brand-new AGNOS install handle the
   first session before any training data exists? Probably: explicit
   user selection during onboarding + behavioral training accumulates
   over time + switch-user remains a quick gesture forever.

3. **Cross-user data isolation on shared hardware** — when Layer 3
   multi-avatara is live, how rigorously is user A's data isolated
   from user B on the same kernel? `kavach` per-overlay sandboxing +
   sigil-encrypted at-rest is the answer, but the *implementation*
   detail (separate user namespaces? per-avatara mount namespaces?
   per-process kavach overlays?) is open.

4. **Theft response actions** — encryption-at-rest is the passive
   defense, but what about active theft response? Remote-wipe via
   `kula` mesh signal? Tamper detection that triggers re-encryption?
   GPS-based geofencing that locks tighter if device leaves trusted
   area? Open.

5. **Hardware-presence button** — the L4 capability-gate "physical
   presence" signal needs *some* hardware. Yubikey-class USB token?
   Dedicated button on the device? Phone-as-token via BLE? Should AGNOS
   define a standard "physical presence" abstraction that hardware
   implementers can target?

6. **Recovery from lost token / forgotten password / broken
   biometric** — every security mechanism needs a recovery path.
   What's the AGNOS recovery posture? "If you lose all your
   credentials, your encrypted disk stays encrypted forever; here's a
   sigil-rooted paper backup of a recovery key" is one model. The
   tradeoff: paper backup is theft-vulnerable but covers
   user-forgetfulness. Open.

7. **Empire-service interop** — when users need to authenticate to
   empire services (banking, government, current-job-mandated SaaS),
   how does AGNOS bridge? OAuth client + sigil-signed token storage?
   Per-service avatara overlay that holds the empire credential?
   Compat subsystem handles it inside the Linux personality? Open.

8. **Agent identity vs user identity** — agents act on behalf of the
   user. When an agent does something irreversible, is the agent
   prompted (with its capability gate) or is the *user* prompted
   (because the action is the user's responsibility)? Both — agents
   confirm at the capability layer, users confirm at the intent layer.
   But the UX choreography is open.

These questions are *good to have open* — they're the right
questions, evidence the architectural commitment is well-shaped.
They'll close as research matures and the project ships incrementally.

---

## Cross-references

- **Strategic Vision** ([`../roadmap.md`](../roadmap.md#strategic-vision)) — the empire-defense parallel-infrastructure thesis; this doc is the *user-boundary* layer of that thesis (Layer 4 within the four-layer empire-defense set alongside compat / wire / trust / governance).
- **Phase 24** ([`../roadmap.md`](../roadmap.md) — *to be added*) — the roadmap entry that points here.
- **Companion**: [`agent-injection-defense.md`](agent-injection-defense.md) — capability-gates-at-the-agent-boundary; this doc is capability-gates-at-the-user-boundary. Both implement the "authorization > authentication" principle at different surfaces.
- **Companion**: [`parallel-pki.md`](parallel-pki.md) — cryptographic identity rooted in paper artifacts. The user's "identity at the boundary" depends on this. Sigil's identity layer for remote services is rooted in this PKI, not in commercial IDPs.
- **Companion**: [`foundation-structure.md`](foundation-structure.md) — governance layer that holds the project across the multi-year horizon while this framework matures. Contributor protection in the Foundation context relates to identity-handling here (pseudonymous contribution).
- **Companion**: [`cross-platform-compat-subsystem.md`](cross-platform-compat-subsystem.md) — when foreign-platform (Linux) software runs in the compat container, it sees Unix uid/gid because Linux binaries assume it. The compat container *contains* the Unix model; the host stays sovereign. Two universes; bridge in the middle.
- **Companion**: [`dpi-resistance.md`](dpi-resistance.md) — wire-level identity invisibility complements user-level identity sovereignty.
- **Vision**: [`../vision/conscious-objects.md`](../vision/conscious-objects.md) — bonded-recognition (Layer 3 phase 6) is the bridge to conscious-objects work where the physical artifact *recognizes its bonded user*. Same principle, different scale.

---

*Locked: framework architectural commitments (four-layer model;
recognition over interrogation; authorization > authentication;
pluggable mechanisms per layer; context modulates friction not
capability). Mechanism choices deliberately fluid. Last touched
2026-05-12. Phase 1 of this work (this doc) ships now; Phases 2+ land
as the relevant subsystems and research mature. The doc updates as
mechanisms evolve — explicit fluid-document posture.*
