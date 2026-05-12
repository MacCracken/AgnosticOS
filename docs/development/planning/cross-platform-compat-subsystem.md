# Cross-Platform Compat Subsystem — Foreign-Platform Work, Sandboxed

> **Status**: Planning — Design Phase | **Last Updated**: 2026-05-12
>
> The agnosticism commitment in AGNOS's name: bring foreign-platform work
> in *transparently* — wrappers or native ports — without the user needing
> to make it viable. **It just works.** Native ports remain the preferred
> path; the compat subsystem is the bridge for software not yet ported.
>
> **Architectural commitment**: foreign code runs inside a kavach-isolated
> Linux personality container. The host kernel surface grows *organically
> with native AGNOS workloads* — never to mimic foreign-platform ABIs.
> Native AGNOS processes retain structural immunity against the broad
> class of Linux ABI CVEs (e.g. CVE-2026-31431 Copy Fail) because the
> Linux-side syscalls *never enter the kernel* — they live in the
> interpretive layer, which is and stays a separate concern. The
> subsystem is the *unit of compat* — opt in, audit-visible, revocable.
>
> **Scope**: Cross-cutting — spans kavach (sandbox primitive), ark
> (subsystem packaging), libro (audit trail for subsystem activity),
> agnostik (`Subsystem<T>` shared type), possibly daimon (agent
> orchestration of subsystem-bound services). This doc is the design
> spine; per-repo issues track the implementation when phasing reaches
> them.
>
> **Companion**: [`agent-injection-defense.md`](agent-injection-defense.md) —
> the other "post-public-beta, cross-cutting, absence-by-design" entry.
> Both preserve sovereignty at the kernel boundary while expanding the
> usable surface above it.

---

## The agnostic commitment

AGNOS is named for *agnosticism*: neutral on what you run, honest about
what each path costs. Pure sovereignty without compat is dogma — Plan9,
Hurd, and Mach all proved that an OS with no bridges stays academic.
The OS must accommodate other platforms' work or it never gains users.

But naive compat *erases* the structural-immunity argument that makes
AGNOS interesting. If the kernel grows 200+ Linux syscalls to run Linux
binaries, then AGNOS is just Linux with extra steps. The CVE class that
the 26-syscall surface was structurally immune to becomes reachable
again.

**The trade-off the user shouldn't have to think about:** AGNOS-native
software gets the sovereignty + structural-immunity benefit. Foreign
software runs in a kavach-isolated subsystem with a Linux personality
root. The user doesn't pick — both modes are available, and the system
makes the right call.

---

## The chosen architecture — sandboxed Linux subsystem (kavach container)

Foreign code runs inside a **fully Linux-personality environment** —
its own root filesystem (`/`), its own `/lib`, its own libc, its own
process tree. From *outside*, it's a kavach sandbox. From *inside*,
it's Linux: a process running there sees a Linux ABI, a Linux `/proc`,
Linux syscall semantics. The host AGNOS kernel never sees Linux
syscalls directly — the subsystem intermediates everything.

```
┌────────────────── AGNOS host (26 syscalls, sovereign) ──────────────────┐
│                                                                          │
│  ┌── kybernet (PID 1) ──┐  ┌── daimon ──┐  ┌── agnoshi ──┐              │
│  │ AGNOS-native         │  │ orchestrator│  │ AGNOS shell │   ← native, │
│  │ process              │  │             │  │             │     sovereign│
│  └──────────────────────┘  └─────────────┘  └─────────────┘              │
│                                                                          │
│  ┌────────────── kavach sandbox: linux-compat subsystem ───────────────┐│
│  │                                                                      ││
│  │  Linux personality root (/lib, /usr, /etc, /proc)                   ││
│  │                                                                      ││
│  │  ┌── linux binary (e.g. python3) ──┐  ┌── another Linux binary ──┐ ││
│  │  │ Speaks Linux ABI                 │  │ Speaks Linux ABI         │ ││
│  │  │ Syscalls intercepted/translated  │  │ Same                     │ ││
│  │  │ at the subsystem boundary        │  │                          │ ││
│  │  └──────────────────────────────────┘  └──────────────────────────┘ ││
│  │                                                                      ││
│  │  ↕ Subsystem boundary: Linux syscalls → AGNOS syscalls (kavach)    ││
│  └──────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│  ↕ AGNOS kernel — 26 syscalls, **unchanged**                            │
└──────────────────────────────────────────────────────────────────────────┘
```

**Why this preserves the immunity claim:**

- The AGNOS kernel grows only when an *AGNOS-native* workload demands
  a new syscall — never to make a foreign binary work. Native growth
  is organic and load-bearing for the sovereign system; foreign-ABI
  growth is rejected because that's what the interpretive layer is
  *for*.
- Linux binaries inside the subsystem can only do what the kavach
  sandbox allows. The wider Linux attack surface is *contained* — it
  cannot reach AGNOS-native processes, kernel data structures, or
  other subsystem instances.
- Subsystem instances are revocable as a unit. Misbehaving Linux
  workload? Kill the subsystem. The host is unaffected.
- The bug class (e.g. CVE-2026-31431, AF_ALG splice LPE) requires the
  vulnerable syscall to *exist in the kernel*. In AGNOS-the-kernel,
  it doesn't, and the subsystem can't add to the host kernel — it can
  only translate at its own boundary.

**Native ports remain the preferred path.** Software that's been ported
to Cyrius targets the AGNOS kernel directly and gets:

- Structural immunity to the bug classes the 26-syscall surface
  excludes
- Smaller binaries, faster startup, lower memory
- Audit-trail integration with libro
- Full kavach-policy flexibility per-process, not just per-subsystem

The compat subsystem is the bridge while ports happen — and for
software that will never be ported.

---

---

## Two growth paths, never collapsed

The kernel and the interpretive layer have **separate growth rules**.
They are not transitional states of each other; the boundary between
them is permanent.

| Layer | Grows when… | Never grows to… |
|-------|-------------|-----------------|
| **AGNOS kernel** (sovereign syscall surface) | A native AGNOS workload demonstrates a need that can't be satisfied at userspace. Growth is organic, audited, and load-bearing. | Make a Linux/Windows/macOS binary work. Foreign-platform pressure is *the* trigger for the interpretive layer, not for kernel growth. |
| **Interpretive layer** (compat subsystem + personality translation) | A new foreign platform or workload class needs to run. Growth here is expected and bounded — it's the layer's job. | Become "part of the kernel." The boundary is permanent. Even if 100% of workloads ran through the interpretive layer tomorrow, the kernel would still not absorb it. |

**Why the boundary is permanent:**

- The structural-immunity argument depends on the kernel *not knowing*
  foreign ABIs. Collapsing the interpretive layer into the kernel
  destroys the argument permanently — there's no rebuilding it after
  the merge.
- Foreign ABIs change. Linux adds syscalls every release. If AGNOS
  absorbed them, it would track Linux's ABI growth forever — the
  sovereignty premise dissolves into "we're a slow downstream of
  Linux."
- An explicit, permanent interpretive layer means the *contract* is
  clear: AGNOS-native is one tier of guarantee (immune, audited,
  sovereign); compat-subsystem is a different tier (sandboxed,
  bounded, Linux-grade-risk). Users can reason about each.

**Organic kernel growth examples** (these would be legitimate AGNOS
kernel additions, in contrast to "we need this to run Linux"):

- A new native AI/MCP service needs a primitive the existing 26
  syscalls can't compose efficiently
- A new hardware class (e.g. dedicated AI accelerator) needs an ioctl-
  family analog that exists in the AGNOS native idiom
- A capability gate identified by [agent-injection-defense.md](agent-injection-defense.md)
  L4 (irreversible-action confirmation tokens) needs kernel-side
  enforcement

Each of those grows the surface for AGNOS-native reasons. None grow it
for foreign compat. The interpretive layer stays the interpretive
layer.

---

## Rejected alternatives

### Option A — Linux ABI in-kernel (FreeBSD Linuxulator style)

Add ~200+ Linux syscalls to the AGNOS kernel directly. Linux binaries
run as ordinary AGNOS processes against the host kernel.

**Rejected**: erases the structural-immunity argument completely.
Every Linux CVE that targets one of the now-supported syscalls becomes
reachable on AGNOS too. The 26-syscall surface is the load-bearing
sovereignty claim; this trades it for compat convenience.

### Option B — Per-process Linux personality flag + userspace shim

Each process carries a personality bit. AGNOS-native processes use the
26-syscall surface. linux-personality processes route through a
userspace translation library (LD_PRELOAD style) that maps Linux ABI
calls to AGNOS syscalls.

**Considered, rejected** in favor of C because:

- The personality dispatch lives partly in the kernel (to route
  syscalls correctly per-process), which leaks Linux ABI awareness
  into the sovereign surface
- Security policy gets harder — same-host processes with different
  personalities sharing /tmp, signals, IPC create cross-personality
  attack channels
- Audit becomes per-process rather than per-container, fragmenting
  libro's view of foreign code
- kavach already provides the sandbox primitive; not using it for the
  compat boundary is duplication

C uses the existing isolation unit (kavach sandbox) as the unit of
compat. Less new machinery, cleaner reasoning, audit-friendly.

### Option D — Recompile-only (no runtime Linux compat)

Provide porting headers + a shim library; Linux source code can be
recompiled against AGNOS, but compiled Linux binaries don't run.

**Rejected as primary strategy**: contradicts the "user shouldn't need
to make it viable, it just works" commitment. Recompilation is a
viable *optimization* path (compat → port → native) but isn't a
runtime-compat answer. Plenty of useful Linux software is closed-source
or has build complexity AGNOS users shouldn't inherit.

This becomes the natural follow-up *to* C, not a replacement for it:
software that proves it's worth running in the subsystem eventually
earns a native port.

---

## Phasing

This is **post-public-beta, foundational**. Not MVP, not closed beta,
not v1.0 desktop. It belongs in the development arc that follows
self-hosting (the public-beta milestone) — once AGNOS can build itself
and the sovereign userland is operational, the compat subsystem opens
the door to the broader ecosystem.

| # | Phase | Status | Dependency |
|---|-------|--------|------------|
| 1 | **Foundation** — kavach sandbox primitives mature, agnostik `Subsystem<T>` type defined | ✅ Substrate | kavach 3.x is shipped; `Subsystem<T>` to add when phasing starts |
| 2 | **Proof of concept** — boot a static busybox inside a kavach-sandboxed minimal Linux personality root | [ ] Queued | Public Beta closeout |
| 3 | **Subsystem packaging via ark** — `ark install linux-compat-env` provisions the personality root; reproducible build | [ ] Queued | Phase 2 + ark recipes mature |
| 4 | **Runtime UX** — `agnos run path/to/foo` auto-detects Linux binary, spawns appropriate subsystem, runs binary, returns exit code. User does not interact with the subsystem directly. | [ ] Queued | Phase 3 |
| 5 | **Curated profiles** — subsystem variants for workload classes (AI/Python+models, build-tooling, desktop-apps). Each is a curated capability surface, smaller than full Linux. | [ ] Queued | Phase 4 + usage telemetry |
| 6 | **Port pipeline integration** — when a workload runs often in the subsystem, surface "this would benefit from a native port" recommendation; track porting candidates. | [ ] Future | Compat usage at scale |

**Naming the subsystem**: TBD. Sanskrit-naming convention applies
when the architecture stabilizes (Phase 2/3). Suggestions to surface
when relevant — but the doc deliberately avoids naming the subsystem
prematurely. "The compat subsystem" or "linux-compat-env" works as a
placeholder.

---

## Why this is in `development/`, not `vision/`

Vision-grade items (v2.0 kernel, v3.0 Cyrius, v4.0 conscious objects)
are *speculative* — they shape long-term thinking but don't anchor
near-term work. The compat subsystem is different: it's part of the
**immediate strategic arc**. Without it, the agnostic claim in the
project name is unbacked. Users will ask "can I run X?" the moment
AGNOS ships, and the answer needs to be "yes, via the compat
subsystem" — not "someday, in vision/".

Anchoring this doc in `development/planning/` (alongside
`agent-injection-defense.md`, which has the same "post-public-beta,
cross-cutting, absence-by-design" shape) keeps the architectural
commitment visible without forcing scope into MVP.

---

## Cross-references

- **Strategic Vision** ([`../roadmap.md`](../roadmap.md#strategic-vision)) — the three-stage MVP / OS Independence / Desktop framing. Compat subsystem is post-stage-3 but referenced from stage 1 so the agnostic claim is visible from the top.
- **Phase 20** ([`../roadmap.md`](../roadmap.md) — *to be added*) — the roadmap entry that points here.
- **Companion**: [`agent-injection-defense.md`](agent-injection-defense.md) — the other planning doc in the same pattern. Both extend AGNOS-native sovereignty with a containment layer for the wider problem.
- **Design pattern**: the *absence-by-design + opt-in containment* pattern. Documented retrospectively in `design-patterns.md` once Phase 2 ships proof-of-concept.

---

*Locked: kavach-container architecture (Option C). Last touched 2026-05-12. When Phase 2 begins, this doc moves from "Planning — Design Phase" to "Planning — Active". Naming the subsystem happens then.*
