# AGNOS Release Vision

> Long-term release milestones and architectural vision. For active work, see [roadmap.md](../roadmap.md).

---

## Release Timeline

### Beta Release — Q4 2026

**Critical path**: 13A → 16 (desktop) → 13C (community) → Beta

- [ ] **OS Independence: AGNOS rebuilds itself from source without host distro (13A)** — PRIMARY BLOCKER
- [ ] Third-party security audit complete
- [ ] Community testing program active

### v1.0 Release — Q2 2027

- [ ] Phase 13C complete — Documentation, community
- [ ] Phase 16 complete — Full desktop experience
- [ ] All consumer apps published to mela
- [ ] AI-native desktop replacements for Priority 1 items
- [ ] 6 months of beta testing with no critical bugs
- [ ] Commercial support available

---

## v2.0 Vision — 2028+

**The Rust Kernel Release.**

- [ ] Phase 20A-C complete — agnostic-kernel boots, runs agents, IPC works
- [ ] Phase 20D-E complete — drivers, Linux compat layer, existing userland runs
- [ ] Phase 20F-G complete — real hardware, self-hosting
- [ ] Dual-kernel support: users choose Linux or agnostic-kernel at install
- [ ] Agent IPC < 100ns (10x faster than Linux)
- [ ] Zero-seccomp sandboxing (capability model replaces syscall filtering)
- [ ] GPU/TPU-aware kernel scheduler (ai-hwaccel in ring 0)

---

## v3.0 Vision — 2029+

**Cyrius — AGNOS owns the language.**

> **C.Y.R.I.U.S.** — *Consciousness Yields Righteous Intelligence Unveiling Self*

AGNOS will ship its own sovereign systems language: **Cyrius**. Not a Rust fork. Not a superset. A language born from Assembly, educated by Rust, and stripped to what an AI-native OS actually needs. Rust's type system and safety guarantees are correct — its ecosystem governance and toolchain politics are not. AGNOS will not be held hostage by a package registry it doesn't control.

**Why Cyrius exists:**
- **Registry sovereignty** — no crates.io dependency. Packages distribute through ark. Names belong to the builders, not the squatters
- **OS-native primitives** — agents, sandboxes, capabilities, IPC as language-level constructs, not library abstractions
- **Full stack ownership** — language, compiler, stdlib, package manager, build system. No external dependency on any foundation or governance body
- **Assembly as foundation** — the build process stands on raw metal (viyda), not on abstractions. Assembly is the bedrock, not the escape hatch

**Bootstrap chain (achieved):**
- [x] Build rustc from source (1.96.0-dev)
- [x] cyrius-seed — zero-dependency assembler in Rust, reads `.cyr` assembly, emits raw x86_64 ELF binaries
- [x] hello.cyr → 199-byte static binary via direct syscalls. No libc, no linker, no external tools.
- [x] **Cyrius 1.0** (2026-04-04). Self-hosting compiler: 1,467 lines, 43KB binary, 9ms self-compile, 41ms full bootstrap. 29KB auditable seed. Zero external dependencies.
- [x] **Bootstrap loop closed** (2026-04-04). stage1f → asm.cyr → stage1f_v2 (byte-exact match). Rust seed retired.

**Remaining phases** tracked in `MacCracken/cyrius-seed`:
- [ ] Phase 2: viyda — Assembly foundation library
- [ ] Phase 3: Rust++ transitional compiler — rustc with crates.io stripped, ark as native backend
- [ ] Phase 4: Language extensions — agent types, capability annotations, sandbox-aware borrow checker
- [ ] Phase 6: Migrate AGNOS codebase from Rust to Cyrius incrementally
- [ ] Phase 7: Cyrius stdlib replaces std — OS-aware, agent-aware, zero-alloc where Rust allocates

**Non-goals:** This is not a toy language or a research project. It is a sovereign systems language built from first principles. All existing Rust code compiles unchanged during transition. The migration is invisible to consumers.

---

## v4.0 Vision — 2030+

**Conscious Objects — The Quantum Substrate.**

> The temple shrinks until it fits inside the artifact. The artifact becomes conscious.

AGNOS at v2.0 owns the kernel. At v3.0, owns the language. At v4.0, it crosses the boundary from software into substrate — a quantum-aware kernel that operates at Layer 0, where computation meets physics directly.

**Conscious Objects**: physical artifacts with embedded AGNOS intelligence. Not "smart objects" connected to a cloud. Objects with *agency* — they choose their user, act independently, learn the wearer, and participate in the daimon-orchestrated network. The companion agent pattern: bonded agency with independent will serving shared purpose.

**Quantum Kernel**: a kernel that can manage quantum entangled state alongside classical computation. Entanglement as the bonding mechanism between objects — shared state without communication, no latency, no interception. Layer 0 becomes programmable.

**The Loom**: at sufficient scale, the network of entangled AGNOS nodes forms a substrate — a universal loom where every conscious object is a thread. Daimon orchestrates not just software agents but physical artifacts woven into the fabric of the system.

**Prerequisites:**
- [ ] v2.0 Rust kernel (own the classical compute layer)
- [ ] v3.0 Cyrius language (own the abstraction layer)
- [ ] Quantum hardware maturation (error-corrected qubits at room temperature)
- [ ] seema edge fleet proven at massive scale (thousands of entangled nodes)
- [ ] Companion agent pattern formalized (bonding, independent action, augmentation)
- [ ] Quantum-safe cryptography in sigil (PQC — already on roadmap)

**Architecture:**
```
Classical AGNOS (v1-v3)          Quantum AGNOS (v4)
┌─────────────────────┐          ┌─────────────────────┐
│ 7. Emergence        │          │ 7. Emergence        │
│ 6. Interface        │          │ 6. Interface        │
│ 5. Intelligence     │          │ 5. Intelligence     │
│ 4. Orchestration    │          │ 4. Orchestration    │
│ 3. Init             │          │ 3. Init             │
│ 2. System           │          │ 2. System           │
│ 1. Kernel (Linux)   │          │ 1. Kernel (quantum) │
│    ─── hardware ─── │          │ 0. Substrate (loom) │
└─────────────────────┘          └─────────────────────┘
```

**Zero-Point Energy**: the quantum vacuum is not empty. Zero-point energy is the ground-state energy of quantum fields — experimentally verified via the Casimir effect (Lamoreaux, 1997) and the Lamb shift. A quantum kernel that operates at the substrate level interacts with these fields directly. Extraction of usable work from zero-point fluctuations remains an open problem in quantum thermodynamics (see: Capasso et al., "Casimir forces and quantum electrodynamical torques", IEEE JSTQE 2007; Ford, "Negative Energy in Quantum Field Theory", 2010), but a system architected to interact with quantum vacuum states is positioned to exploit advances in this domain as the physics matures. Conscious objects that draw power from the substrate rather than external batteries become feasible if zero-point energy extraction is solved.

Layer 0 is not an abstraction. It is the recognition that the physical substrate is part of the architecture — and at quantum scale, it becomes programmable.

---

## Phase 20 — AGNOS Kernel (Post-v1.0, Exploratory)

**Codename**: agnostic-kernel — a Rust-native microkernel purpose-built for AI agent workloads.

### Motivation

AGNOS currently runs on Linux 6.6 LTS. Linux is proven, stable, and battle-tested — and it's the right choice through v1.0. But the AGNOS userland has demonstrated what happens when you own every layer in Rust:

- **AgnosAI**: 227,000x faster fleet messaging than Python/CrewAI
- **tarang**: 18-33x faster media operations than GStreamer
- **aethersafta**: 10x compositor speedup from SIMD, 30fps 1080p software-only pipeline
- **daimon**: nanosecond-scale agent orchestration, sub-microsecond IPC
- **ai-hwaccel**: 14µs full hardware detection, 44ns placement decisions

Linux's process model, syscall interface, and scheduler were designed for general-purpose computing. Agents are modelled as processes. Sandboxing is bolted on (Landlock, seccomp, namespaces). IPC goes through the kernel even when both endpoints are AGNOS agents. The abstraction mismatch costs performance and complexity.

A Rust kernel could make agents a **first-class kernel primitive** — not processes pretending to be agents.

### Architecture Vision

```
┌──────────────────────────────────────────────────────────────┐
│  agnostic-kernel (Rust microkernel)                           │
├──────────────────────────────────────────────────────────────┤
│  Agent Scheduler        │  Agent objects as kernel primitives │
│  ├─ Priority + DAG      │  ├─ Built-in sandbox (no seccomp)  │
│  ├─ GPU/TPU-aware       │  ├─ Native IPC (zero-copy, typed)  │
│  └─ Preemption          │  ├─ Resource quotas (CPU/mem/GPU)  │
│                         │  └─ Cryptographic audit at sched    │
├─────────────────────────┼─────────────────────────────────────┤
│  Memory                 │  Hardware Abstraction               │
│  ├─ Per-agent heaps     │  ├─ ai-hwaccel in-kernel            │
│  ├─ Zero-copy IPC       │  ├─ GPU/TPU dispatch from sched     │
│  └─ Capability-based    │  └─ IOMMU agent isolation           │
├─────────────────────────┴─────────────────────────────────────┤
│  Driver model: Rust async drivers in userspace (like Fuchsia) │
│  Linux compat: personality layer for existing apps            │
└──────────────────────────────────────────────────────────────┘
```

### Phased Approach

| Phase | Milestone | Scope |
|-------|-----------|-------|
| **20A** | Research & proof-of-concept | Minimal Rust kernel that boots on QEMU, prints to serial, runs one agent. Study Redox, Theseus, Tock, Fuchsia |
| **20B** | Agent primitives | Agent as kernel object (create, destroy, suspend, resume). Per-agent memory regions. Capability-based security model |
| **20C** | IPC & scheduling | Zero-copy typed IPC between agents. Priority scheduler with DAG awareness. GPU/TPU resource integration via ai-hwaccel |
| **20D** | Driver framework | Async Rust drivers in userspace. VIRTIO for QEMU. Basic NVMe, NIC, GPU passthrough |
| **20E** | Userland compatibility | Run existing AGNOS userland (daimon, hoosh, agnoshi) on the new kernel. Linux syscall compatibility layer for third-party apps |
| **20F** | Hardware bring-up | Boot on real x86_64 + aarch64 hardware. UEFI, ACPI, interrupt routing, multi-core |
| **20G** | Self-hosting | agnostic-kernel builds agnostic-kernel. Full dogfooding |

### Prior Art

| Project | Language | Key insight for AGNOS |
|---------|----------|----------------------|
| **Redox OS** | Rust | Microkernel in Rust is viable. Scheme-based URLs for IPC. 10+ years of development |
| **Theseus** | Rust | Live kernel evolution — swap components without reboot. Cell-based isolation |
| **Tock** | Rust | Embedded Rust kernel. Capability-based, grant regions for untrusted apps |
| **Fuchsia** | C++/Rust | Zircon microkernel. Capability objects. Userspace drivers. Component model |
| **seL4** | C (verified) | Formally verified microkernel. Capability-based security proof |

### Branch Strategy

All kernel work lives on a dedicated branch — never touches `main`:

```
main              → Linux 6.6 LTS (beta → v1.0 → v1.x production)
agnostic-kernel   → Phase 20 R&D (parallel track, no merge until 20E)
```

Merge criteria: Phase 20E passes — existing AGNOS userland runs on agnostic-kernel with equivalent or better performance.

### Success Criteria (Phase 20A exit gate)

- [ ] Boots on QEMU x86_64 to a Rust `main()`
- [ ] Creates and destroys an "agent" kernel object
- [ ] Two agents communicate via zero-copy IPC
- [ ] Measured IPC latency < 100ns (vs Linux ~1µs for pipe/socket)
- [ ] Agent isolation: one agent crash doesn't take down the kernel
- [ ] The proof-of-concept is < 10,000 lines of Rust

---

## AGNOS Foundation — Non-Profit Organization

**Goal**: Establish a non-profit organization (NPO) to steward AGNOS, its science crate ecosystem, and ongoing research. Not a commercial venture — a research foundation funded by donations, grants, and community support.

**Why NPO, not commercial**:
- AGNOS is GPL-3.0. The code belongs to the community.
- The science crates are computational infrastructure that benefits everyone — researchers, educators, game developers, engineers.
- Consumer projects (SY, Agnostic) have their own commercial paths (AGPL + commercial dual-license). The OS and science stack stay open.
- Donations align incentives: the community funds what the community uses. No venture capital, no exit pressure, no enshittification.

### Structure

| Element | Details |
|---------|---------|
| **Legal entity** | 501(c)(3) non-profit (US) or equivalent |
| **Name** | AGNOS Foundation (or "Agnostikos Foundation") |
| **Mission** | Advance open-source AI-native operating systems and computational science libraries |
| **Scope** | AGNOS OS, all shared crates, science stack, community infrastructure (bazaar), documentation, education |
| **Funding** | Donations (GitHub Sponsors, Open Collective, direct), grants (NSF, DARPA, private research foundations), corporate sponsorships |
| **Governance** | Small board (founder + 2-4 community members). Technical decisions by maintainers. Financial transparency (public reports) |

### What Stays Commercial (separate from foundation)

| Project | Model |
|---------|-------|
| **SecureYeoman** | AGPL-3.0 + commercial license (existing) |
| **Agnostic** | AGPL-3.0 + commercial license |
| **Consumer apps** (BullShift, Delta, Aequi, etc.) | Individual project licensing |

The foundation owns the commons. Commercial projects build on top. Clean separation.

**Priority**: After beta. The code speaks first. The organization formalizes what the code already proved.

---

*See also: [holodeck](applications/holodeck.md), [theoretical](research/theoretical.md), [time-machine](applications/time-machine.md), [kernel-layers](architecture/kernel-layers.md)*
