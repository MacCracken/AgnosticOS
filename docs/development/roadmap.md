# AGNOS Development Roadmap

> **Status**: Pre-Beta | **Last Updated**: 2026-04-03
> **Monolith fully dismantled** — all subsystems extracted to standalone repos. Workspace: examples only. agnostik (0.90.0), agnosys (0.51.0), shakti (0.1.0) all standalone.
> **Recipes**: 421 recipes across 11 categories — migrated to **zugot** (`MacCracken/zugot`) as of 2026-04-07. 90 bazaar community recipes.
> **Build order**: 178 packages in zugot `build-order.txt` (base + desktop, dependency-ordered)
> **Phases 10–14 complete** | **Phase 15A**: Core scanning done (phylax) | **Phase 16A**: Desktop essentials done | **Phase 17**: Local inference optimization (planned) | **Audit**: 16 rounds
> **Shared Crates**: 77 library crates — 56 at v1.0+ stable, 20 pre-1.0. Key milestones: sigil 1.0.0, kavach 2.0.0, bote 0.92.0, t-ron 0.90.0, agnostik 0.90.0, agnosys 0.51.0
> **Consumer Projects**: 19+ released (including Vidhana v1, Sutra v1, Abacus)

---

## Strategic Vision

AGNOS becomes a real operating system in two stages:

1. **OS Independence** (Beta) — AGNOS boots and builds itself without any host distro. Self-hosting LFS-style base, takumi recipes for the full stack, ark as sole package manager. This is the foundation.

2. **Desktop Completeness** (v1.0) — Ship a complete desktop experience by packaging existing open-source tools first (Thunar, Zathura, Alacritty, etc.), then progressively replace with AI-native alternatives where the AI is the primary value.

**Priority order**: OS identity → desktop essentials via recipes → AI-native apps

---

## Beta Goal

AGNOS boots as an **independent Linux distribution** — no Debian, no Ubuntu, no
host distro. A self-hosting LFS-style base system built entirely from source via
takumi recipes, with ark as the sole package manager. The userland (daimon,
hoosh, agnoshi, aethersafha, etc.) runs on top of a base system we control from
toolchain to init.

Reference: [Linux From Scratch 12.4](https://www.linuxfromscratch.org/lfs/view/stable/)
(77 packages) + [Beyond LFS](https://www.linuxfromscratch.org/blfs/view/stable/)
for desktop/networking/GPU stack.

---

## Critical Path to Beta

```
Phase 13A (self-hosting) ──→ Phase 16 (desktop recipes) ──→ Phase 13C (community) ──→ BETA
         │                            │
         │                            └── Package existing tools (Thunar, Zathura, etc.)
         │                                so the desktop is usable
         │
         └── AGNOS builds AGNOS: toolchain, kernel, userland, packages
             This is THE beta blocker
```

---

## Monolith Extraction — Complete

Monolith fully dismantled (2026-04-01 to 2026-04-07). All userland code extracted to standalone repos. Recipes migrated to zugot. Workspace contains only `examples/`.

Full details: [sprint-history.md](sprint-history.md#monolith-extraction--complete-2026-04-01-to-2026-04-07)

**Open**: `examples/` — evaluate whether to move to agnostik repo or keep here.

---

## P0 — Active Blockers

### ~~Recipe Audit~~ — Complete
Moved to [sprint-history.md](sprint-history.md#recipe-audit--complete-moved-to-zugot). Remaining recipe work tracked in zugot.

### agnosticos.org Website (P0)
- [ ] Update landing page stats (82 crates, 420+ recipes)
- [ ] Add Cyrius mention and article link to landing page
- [ ] Publish "The 29KB Compiler vs The $20,000 Compiler" as web article
- [ ] Add philosophy page
- [ ] Full site roadmap: `agnosticos-org/docs/site-roadmap.md`
- **Blocked on**: Cyrius language maturity + agnosys/agnostik/kybernet Cyrius rewrites + micro OS tested. Plan now, execute after core stabilizes.

### Cyrius as Base Toolchain (P0 — CI/Release)
- [ ] Add `zugot/base/cyrius.toml` recipe — Cyrius compiler + stdlib + tools as a base system package alongside GCC, Rust, Python
- [ ] CI builds use Cyrius for AGNOS-native components (kybernet, agnostik, agnosys, ark, nous)
- [ ] Release pipeline: Cyrius-compiled binaries as first-class artifacts alongside Rust-compiled
- [ ] `build-order.txt` updated — Cyrius inserted after Rust in the toolchain stage
- [ ] Self-hosting validation: Cyrius compiles itself from the zugot recipe on the target system
- **Depends on**: aarch64 bootstrap complete, Phase 10 audit pass

---

## Phase 13A — OS Independence Validation (BETA BLOCKER)

**This is the single most important remaining work.** Without it, AGNOS is a Debian overlay.

Infrastructure complete. Validation remaining — requires real hardware/QEMU execution.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Run bootstrap-toolchain.sh end-to-end | Not started | Build cross-compiler from source tarballs |
| 2 | Build base system in chroot | Not started | ark-build all 109 base recipes in order |
| 3 | Build AGNOS userland on target | Not started | `cargo build --release --workspace` inside AGNOS |
| 4 | Build kernel modules on target | Not started | Compile AGNOS kernel modules without host |
| 5 | Selfhost-validate passes all phases | Not started | Run `selfhost-validate --phase all` on booted ISO |
| 6 | CI automation | In progress | GitHub Actions: `publish-toolchain.yml`, `selfhost-build.yml`, `selfhost-validation.yml` — bootstrap toolchain added to CI/CD |

**Critical path**: Download tarballs → bootstrap-toolchain.sh → enter-chroot.sh → ark-build recipes → cargo build userland → selfhost-validate

**To attempt now**: `sudo LFS=/mnt/agnos ./scripts/build-selfhosting-iso.sh`

---

## Phase 16 — Desktop Completeness

**Strategy**: Package existing open-source tools via takumi recipes for a complete desktop experience *now*. AI-native replacements come later (see `docs/development/applications/roadmap.md`).

Detailed items tracked in respective repos:
- **16B/D/E** — Input, polish, configurability → `MacCracken/aethersafha`
- **16F** — Media ingestion & compositing → `MacCracken/aethersafta`
- **Desktop recipes** (fonts, themes, icons) → zugot

---

## Bazaar — Community Package Repository

**Subsystem**: bazaar (Persian: بازار). Repo: `MacCracken/bazaar`. 90 recipes across 8 categories. Inventory tracked in bazaar repo.

---

## Phase 13C — Community & Documentation

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Video tutorials | Not started | Installation, usage, agent creation (needs recording) |
| 2 | Support portal | Not started | Discord + forum (needs external setup) |
| 3 | Community testing program | Not started | Beta tester enrollment (needs external setup) |
| 4 | Third-party security audit | Not started | External vendor (needs procurement) |

---

## Phase 15 — Threat Detection & Scanning

**Subsystem**: **phylax** (Greek: guardian/watchman) — standalone repo (`MacCracken/phylax`). Detailed roadmap tracked there.

---

## Phase 13F — Hardware Testing Matrix

| # | Target | Arch | Profile | Status |
|---|--------|------|---------|--------|
| 2 | Raspberry Pi 4 | aarch64 | Full | Ready — needs physical validation |
| 3 | Intel NUC (bare metal) | x86_64 | Desktop | Not started |
| 4 | Older x86_64 (~2014 era) | x86_64 | CLI | Not started |
| 5 | Touchscreen desktop | x86_64 | Desktop | Not started |
| 6 | AWS DeepLens | x86_64 | Edge | Ready |
| 7 | ARM64 SBC (QEMU) | aarch64 | Edge | Not started |
| 8 | ESP32-S3 | xtensa | Edge/IoT | Recipe done, needs source repo + flash test |
| 9 | ESP32-C3 | riscv32 | Edge/IoT | Recipe done, secondary target |
| 10 | Tiiny AI Pocket Lab | TBD | Edge+AI | Not started — see Phase 17D |
| 11 | **DJI Tello / micro drone** | ARM | Edge/IoT | AGNOS as drone OS — kybernet + daimon-lite + agnoshi (voice) + seema (fleet) + kavach (geofence). At Cyrius binary sizes (128KB toolchain), a meaningful stack fits on embedded ARM. Conscious object candidate (v4.0) — the drone bonds with its operator, acts independently within kavach boundary. SDK available (UDP commands). Target: autonomous companion drone running sovereign AGNOS. |
| 12 | **Hidizs AP80 Pro Max** | MIPS (Ingenic X1600E) | Audio/IoT | AGNOS as sovereign music player. jalwa with album art, metadata, video (via tarang). Dual ES9219C DACs (audiophile-grade), 2.95" touchscreen, WiFi, BT 5.1, 3.5mm SE + 4.4mm balanced. Needs MIPS backend for Cyrius (3rd arch). Semantic audio (.sra) playback. Artist-direct purchase via vinimaya. No streaming subscription. Target: the first sovereign audiophile player. |
| 13 | **ESP32-S3** | Xtensa | IoT/Edge | AGNOS on microcontrollers. 230KB Cyrius firmware vs 1.5MB MicroPython. kavach sandbox on IoT (the security model MicroPython doesn't have). seema fleet management. sigil device identity. libro audit. Needs Xtensa backend for Cyrius (4th arch). Target: sovereign IoT that's smaller, faster, and safer than Python. |
| 14 | **ESP32-C3** | RISC-V | IoT/Edge | RISC-V variant of ESP32. Needs RISC-V backend for Cyrius (5th arch). Open ISA — no proprietary architecture licensing. The most sovereign hardware target. |

---

## Phase 13G — Consumer App Bundle Tests

All 19 apps released. Bundle tests (`ark-bundle.sh`) not yet run.

| App | Bundle Test |
|-----|-------------|
| SecureYeoman, Photis Nadi, BullShift, Agnostic, Delta, Aequi, Irfan, Shruti, Tazama, Rasa, Mneme, Nazar, Selah, Abaco, Rahd, Tarang, Jalwa, Vidhana, Sutra | Not started |

---

## SecureYeoman & Agnostic Integration

Cross-project integration tracked in respective repos (`MacCracken/secureyeoman`, `MacCracken/agnostic`). Key ecosystem dependency: **sluice** (A2A protocol extraction from SY).

---

## Engineering Backlog

*Completed items archived in [sprint-history.md](sprint-history.md).*

### Active

| # | Priority | Item | Notes |
|---|----------|------|-------|
| B1 | High | Self-hosted CI runners on AGNOS | Replace Arch (x86_64) and Ubuntu (aarch64) runner OS with AGNOS itself — AGNOS builds AGNOS |
| B2 | High | RPi4 hardware boot test | Firmware blobs added, needs physical validation |
| R2 | High | Update scripts/CI for zugot | 16 scripts/CI/config files still reference local `recipes/` paths — update to source from zugot |
| E1 | Medium | ESP32 agent source repo | Recipe done, MQTT bridge done. Pending: source repo + firmware |

Repo-specific backlog items (S2/kavach, V1-PR1/new crates, L1/stiva, P1/cyrius, AgnosAI integration) tracked in their respective repos.

---

## Creator Economy — Direct Artist/Creator Support

**The pipe, not the platform.** AGNOS connects creators directly to supporters with no middleman, no platform cut, no gatekeeper.

```
agnoshi: "support @artist 5 credits"
  → nous resolves artist identity (sigil-verified)
  → vinimaya transfers mudra tokens
  → libro records the transaction
  → artist gets notification via bote
  → content unlocks via kavach permissions
```

**Key crates**: mudra (tokens), vinimaya (payments), sigil (identity), kavach (access control), mela (storefront), libro (audit).
**Surfaces**: jalwa, shruti, tazama, rasa, mneme, delta, SecureYeoman — each app integrates creator support. Details tracked in respective app repos.

---

## Release Roadmap

### Beta Release — Q4 2026

**Critical path**: 13A → 16B-E (polish) → 13C → Beta

- [ ] **OS Independence: AGNOS rebuilds itself from source without host distro (13A)** ← PRIMARY BLOCKER
- [ ] Third-party security audit complete
- [ ] Community testing program active

### v1.0 Release — Q2 2027

- [ ] Phase 13C complete — Documentation, community
- [ ] Phase 16 complete — Full desktop experience
- [ ] All consumer apps published to mela
- [ ] AI-native desktop replacements for Priority 1 items
- [ ] 6 months of beta testing with no critical bugs
- [ ] Commercial support available

### v2.0 Vision — 2028+

**The Rust Kernel Release.**

- [ ] Phase 20A-C complete — agnostic-kernel boots, runs agents, IPC works
- [ ] Phase 20D-E complete — drivers, Linux compat layer, existing userland runs
- [ ] Phase 20F-G complete — real hardware, self-hosting
- [ ] Dual-kernel support: users choose Linux or agnostic-kernel at install
- [ ] Agent IPC < 100ns (10x faster than Linux)
- [ ] Zero-seccomp sandboxing (capability model replaces syscall filtering)
- [ ] GPU/TPU-aware kernel scheduler (ai-hwaccel in ring 0)

### v3.0 Vision — 2029+

**Cyrius — AGNOS owns the language.**

> **C.Y.R.I.U.S.** — *Consciousness Yields Righteous Intelligence Unveiling Self*

AGNOS will ship its own sovereign systems language: **Cyrius**. Not a Rust fork. Not a superset. A language born from Assembly, educated by Rust, and stripped to what an AI-native OS actually needs. Rust's type system and safety guarantees are correct — its ecosystem governance and toolchain politics are not. AGNOS will not be held hostage by a package registry it doesn't control.

**Why Cyrius exists:**
- **Registry sovereignty** — no crates.io dependency. Packages distribute through ark. Names belong to the builders, not the squatters
- **OS-native primitives** — agents, sandboxes, capabilities, IPC as language-level constructs, not library abstractions
- **Full stack ownership** — language, compiler, stdlib, package manager, build system. No external dependency on any foundation or governance body
- **Assembly as foundation** — the build process stands on raw metal (viyda), not on abstractions. Assembly is the bedrock, not the escape hatch

**Bootstrap chain (active):**
- [x] Build rustc from source (1.96.0-dev)
- [x] cyrius-seed — zero-dependency assembler in Rust, reads `.cyr` assembly, emits raw x86_64 ELF binaries
- [x] hello.cyr → 199-byte static binary via direct syscalls. No libc, no linker, no external tools.

```
rustc 1.96.0-dev (we built it)
  → cyrius-seed (assembler, Rust, zero deps)
    → hello.cyr → hello (raw x86_64 ELF, 199 bytes) ✓
```

**Evolution path:**
1. **Assembly** (viyda) — own the build process at the metal level
2. **Rust** — learn from it, bootstrap with it, prove the types
3. **Rust++** — strip Rust to what AGNOS needs, shed external ecosystem dependency
4. **Cyrius** — sovereign language. The name Rust disappears from the toolchain

**Approach:**
- [x] Phase 0: Own the compiler — build rustc from source, prove the chain
- [x] Phase 1: cyrius-seed — **HARDENED**. 5 modules, 38 instructions, 102 tests, 9 examples, ~13 MB/s pipeline
- [x] Phase 1b: stage1b — **RUNTIME CODEGEN**. Compiler emits x86_64 that computes at runtime. if/while/variables, jump patching, 32 tests
- [x] Phase 1c-1f: Incremental compiler stages through self-hosting
- [x] **Phase 3 Step 1: BOOTSTRAP LOOP CLOSED** (2026-04-04). stage1f → asm.cyr → stage1f_v2 (byte-exact match). Rust seed retired.
- [x] **Cyrius 1.0** (2026-04-04). Self-hosting compiler: 1,467 lines, 43KB binary, 9ms self-compile, 41ms full bootstrap. 29KB auditable seed. Zero external dependencies. 6,560 total lines.
- [ ] Phase 2: viyda — Assembly foundation library, build process stands on raw metal
- [ ] Phase 3: Rust++ transitional compiler — rustc with crates.io stripped, ark as native backend
- [ ] Phase 4: Language extensions — agent types, capability annotations, sandbox-aware borrow checker
- [x] Phase 5: Self-hosting — Cyrius compiles Cyrius (1.0 achieved 2026-04-04, bootstrap loop closed)
- [ ] Phase 6: Migrate AGNOS codebase from Rust to Cyrius incrementally (full backward compat)
- [ ] Phase 7: Cyrius stdlib replaces std — OS-aware, agent-aware, zero-alloc where Rust allocates

**Implications for agnostik:**
- agnostik's types are the first things that must compile under Cyrius — every type shipped today is an implicit contract with the future compiler
- The cleaner agnostik is now (zero unwrap, zero panic, pure serde), the easier the port
- Feature gates (agent, security, telemetry, llm) are a preview of Cyrius-native modules
- ark + cyrius-seed converge into the sovereign build pipeline — no cargo, no crates.io

**Non-goals:** This is not a toy language or a research project. It is a sovereign systems language built from first principles. All existing Rust code compiles unchanged during transition. The migration is invisible to consumers.

### v4.0 Vision — 2030+

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

## Open KPIs

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Boot Time | <10s | **3.2s** (kernel+init), **~80ms** init→event loop | **Achieved** — Pure AGNOS, 0 external deps, 7 real binaries, 21MB initramfs, 512MB QEMU VM |
| OS Independence | Yes | Pending | Phase 13A — rebuild from source without host distro |

---

---

## Named Subsystems (25)

All subsystems are standalone repos at `/home/macro/Repos/{name}/` unless noted.
Per-subsystem docs: [docs/development/os/](os/README.md) | Non-OS libs: [docs/applications/libs/](../applications/libs/)

| Name | Role | Repo | Version |
|------|------|------|---------|
| **hoosh** | LLM inference gateway (port 8088) | `MacCracken/hoosh` | 1.2.0 |
| **daimon** | Agent orchestrator (port 8090) | `MacCracken/daimon` | 0.6.0 |
| **agnosys** | Kernel interface | `MacCracken/agnosys` | 0.51.0 |
| **agnostik** | Shared types library | `MacCracken/agnostik` | 0.90.0 |
| **shakti** | Privilege escalation | `MacCracken/shakti` | 0.1.0 |
| **agnoshi** | AI shell (`agnsh`) | `MacCracken/agnoshi` | 0.90.0 |
| **aethersafha** | Desktop compositor | `MacCracken/aethersafha` | 0.1.0 |
| **sigil** | Trust verification & crypto | `MacCracken/sigil` | 1.0.0 |
| **bote** | MCP core (JSON-RPC, host, dispatch) | `MacCracken/bote` | 0.92.0 |
| **t-ron** | MCP security monitor | `MacCracken/t-ron` | 0.90.0 |
| **kavach** | Sandbox execution | `MacCracken/kavach` | 2.0.0 |
| **ark** | Unified package manager | `MacCracken/ark` | 0.1.0 |
| **nous** | Package resolver | `MacCracken/nous` | 0.1.0 |
| **takumi** | Package build system | `MacCracken/takumi` | 0.1.0 |
| **mela** | Agent marketplace | `MacCracken/mela` | 0.1.0 |
| **aegis** | System security daemon | `MacCracken/aegis` | 0.1.0 |
| **argonaut** | Init system (library) | `MacCracken/argonaut` | 0.90.0 |
| **kybernet** | PID 1 binary (uses argonaut) | `MacCracken/kybernet` | 0.51.0 |
| **agnova** | OS installer | `MacCracken/agnova` | 0.1.0 |
| **seema** | Edge fleet management | `MacCracken/seema` | 0.1.0 |
| **samay** | Task scheduler | `MacCracken/samay` | 0.1.0 |
| **phylax** | Threat detection engine | `MacCracken/phylax` | 0.22.3 |
| **bazaar** | Community package repository | `MacCracken/bazaar` | — |
| **mabda** | GPU foundation | `MacCracken/mabda` | 1.0.0 |
| **cyrius-seed** | Cyrius assembler (`.cyr` → x86_64 ELF, 38 insns, 102 tests) | `MacCracken/cyrius-seed` | 0.1.0 |

---

## Post-Beta Phases (17–19)

Detailed roadmaps tracked in respective repos:

| Phase | Focus | Primary Repos |
|-------|-------|---------------|
| **17** | Local inference optimization | `MacCracken/murti`, `MacCracken/hoosh`, `MacCracken/ai-hwaccel` |
| **18** | Immersive communication | `MacCracken/dhvani`, `MacCracken/goonj`, `MacCracken/soorat` |
| **19** | Computational architecture | `MacCracken/murti`, `MacCracken/agnosys`, `MacCracken/ai-hwaccel` |

---

## AGNOS Foundation — Non-Profit Organization

**Goal**: Establish a non-profit organization (NPO) to steward AGNOS, its science crate ecosystem, and ongoing research. Not a commercial venture — a research foundation funded by donations, grants, and community support.

**Why NPO, not commercial**:
- AGNOS is GPL-3.0. The code belongs to the community.
- The science crates (hisab, prakash, bijli, pravash, ushma, kimiya, goonj, pavan, dravya, badal, bhava, raasta, impetus) are computational infrastructure that benefits everyone — researchers, educators, game developers, engineers.
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

### Revenue Streams (all non-commercial)

| Source | Description |
|--------|-------------|
| **GitHub Sponsors** | Individual and corporate monthly sponsorships |
| **Open Collective** | Transparent donation platform with expense tracking |
| **Research grants** | NSF, DARPA, EU Horizon — the science crates qualify as computational research infrastructure |
| **Academic partnerships** | Universities using AGNOS crates in coursework/research → institutional support |
| **Conference talks** | Speaking fees donated back to foundation |
| **Bounties** | Community-funded bounties for specific features/crates |

### What the Foundation Funds

| Area | Examples |
|------|---------|
| **Infrastructure** | CI/CD runners, crates.io publishing, documentation hosting |
| **Research** | External research step (P(-1) step 5) — fund domain experts to review science crate accuracy |
| **Hardware** | Test hardware (Pocket Lab, Raspberry Pi fleet, GPU test rigs) for Phase 13F/17D |
| **Community** | Documentation, video tutorials, conference attendance, beta testing programs |
| **Maintainer support** | Stipends for active maintainers (optional — founder not taking any) |

### What Stays Commercial (separate from foundation)

| Project | Model |
|---------|-------|
| **SecureYeoman** | AGPL-3.0 + commercial license (existing) |
| **Agnostic** | AGPL-3.0 + commercial license |
| **Consumer apps** (BullShift, Delta, Aequi, etc.) | Individual project licensing |

The foundation owns the commons. Commercial projects build on top. Clean separation.

### Timeline

| # | Item | Status |
|---|------|--------|
| 1 | Choose legal structure (501c3 vs fiscal sponsor) | Not started |
| 2 | File incorporation papers | Not started |
| 3 | Set up GitHub Sponsors + Open Collective | Not started |
| 4 | Write mission statement and bylaws | Not started |
| 5 | Recruit initial board members (2-4 community members) | Not started |
| 6 | Apply for research grants (NSF, private foundations) | Not started |
| 7 | Public announcement with donation page | Not started |

**Priority**: After beta. The code speaks first. The organization formalizes what the code already proved.

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

Merge criteria: Phase 20E passes — existing AGNOS userland (daimon, hoosh, agnoshi, aethersafha) runs on agnostic-kernel with equivalent or better performance. Until then, two worlds, one repo, zero risk to shipping.

### Non-Blockers

This does NOT block any AGNOS release:
- **Beta (Q4 2026)**: Linux 6.6 LTS
- **v1.0 (Q2 2027)**: Linux 6.6 LTS
- **v1.x**: Linux kernel, production-hardened
- **v2.0+**: agnostic-kernel option alongside Linux

The kernel is a parallel research track. AGNOS ships on Linux until the Rust kernel is proven on real hardware with real workloads.

### Success Criteria (Phase 20A exit gate)

- [ ] Boots on QEMU x86_64 to a Rust `main()`
- [ ] Creates and destroys an "agent" kernel object
- [ ] Two agents communicate via zero-copy IPC
- [ ] Measured IPC latency < 100ns (vs Linux ~1µs for pipe/socket)
- [ ] Agent isolation: one agent crash doesn't take down the kernel
- [ ] The proof-of-concept is < 10,000 lines of Rust

---

## Contributing

### Priority Contribution Areas

1. **OS Independence (Phase 13A)** — AGNOS rebuilds itself from source without host distro — THE beta blocker
2. **Desktop polish (Phase 16B-E)** — Touch input, HiDPI, compositor config, themes/icons
3. **Documentation (Phase 13C)** — Video tutorials, support portal
4. **Community testing** — Beta tester enrollment + bug tracker setup
5. **Hardware testing (Phase 13F)** — RPi4, Intel NUC, older hardware validation

### Getting Started

See [CONTRIBUTING.md](/CONTRIBUTING.md) for:
- Development environment setup
- Code style and testing requirements
- Git workflow and commit conventions
- Pull request process

---

## Research & Publication

Unified Consciousness Model paper and bhava roadmap tracked in `MacCracken/bhava`.

### Future Shared Crates — Demand-Gated

Scaffold when 3+ consumers need shared implementations, or when a P0/P1 app blocks on it. Names TBD.

| Domain | Trigger | Likely Consumers | Priority |
|--------|---------|------------------|----------|
| **Geography / GIS** | joshua terrain generation, edge fleet geolocation, raasta map-aware pathfinding | joshua, kiran, raasta, edge fleet, nazar | Medium — most likely next |
| **Music theory** | shruti or 3rd consumer needs shared scales, keys, chord progressions, rhythm patterns | shruti, naad, jalwa, kiran | Medium — extract from shruti when pattern repeats |
| **Typography / font metrics** | sahifa (PDF suite) needs font layout, kerning, glyph metrics; aethersafha text rendering | sahifa, aethersafha, scriba | Low — scaffold when sahifa starts |
| **Nutrition / food science** | NPC simulation depth (macros, calories, dietary→metabolic input) | joshua, kiran, rasayan | Low — rasayan covers the biochemistry mechanics |
| **Economics / finance** | BullShift split (`bullshift-core`) extracts shared financial models (pricing, risk, portfolio, market data) | bullshift-core, aequi, sutra (billing), marketplace | Low — gate on BullShift split, then evaluate 3-consumer rule |

---

## Resources

- **Repository**: https://github.com/MacCracken/agnosticos
- **Documentation**: https://docs.agnos.org (planned)
- **Changelog**: [CHANGELOG.md](/CHANGELOG.md)
- **Sprint history**: [docs/development/sprint-history.md](/docs/development/sprint-history.md)
- **Long-term app roadmap**: [docs/development/applications/roadmap.md](/docs/development/applications/roadmap.md)
- **LFS Reference**: https://www.linuxfromscratch.org/lfs/view/stable/
- **BLFS Reference**: https://www.linuxfromscratch.org/blfs/view/stable/

---

*Last Updated: 2026-04-07 | Next Review: 2026-04-14*
