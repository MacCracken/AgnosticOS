# AGNOS Development Roadmap

> **Status**: Pre-Beta | **Last Updated**: 2026-04-07
> **Monolith fully dismantled** — all subsystems extracted to standalone repos. Workspace: examples only.
> **Recipes**: 421 recipes in **zugot** (`MacCracken/zugot`). 90 bazaar community recipes.
> **Shared Crates**: 82 library crates. Key milestones: sigil 1.0.0, kavach 2.0.0, hoosh 1.2.0, agnostik 0.90.0
> **Cyrius 1.0**: Self-hosting compiler achieved (2026-04-04). Bootstrap loop closed.

---

## Strategic Vision

AGNOS becomes a real operating system in two stages:

1. **OS Independence** (Beta) — AGNOS boots and builds itself without any host distro. Self-hosting LFS-style base, takumi recipes for the full stack, ark as sole package manager. This is the foundation.

2. **Desktop Completeness** (v1.0) — Ship a complete desktop experience by packaging existing open-source tools first (Thunar, Zathura, Alacritty, etc.), then progressively replace with AI-native alternatives where the AI is the primary value.

**Priority order**: OS identity → desktop essentials via recipes → AI-native apps

---

## Critical Path to Beta

```
Phase 13A (self-hosting) ──→ Phase 16 (desktop recipes) ──→ Phase 13C (community) ──→ BETA
         │                            │
         │                            └── Package existing tools so the desktop is usable
         │
         └── AGNOS builds AGNOS: toolchain, kernel, userland, packages
             This is THE beta blocker
```

### Beta — Q4 2026

- [ ] **OS Independence (13A)** — PRIMARY BLOCKER
- [ ] Third-party security audit complete
- [ ] Community testing program active

### v1.0 — Q2 2027

- [ ] Phase 13C complete — Documentation, community
- [ ] Phase 16 complete — Full desktop experience
- [ ] All consumer apps published to mela
- [ ] 6 months of beta testing with no critical bugs

Long-term vision (v2.0 kernel, v3.0 Cyrius, v4.0 conscious objects, Foundation): [vision/release-vision.md](vision/release-vision.md)

---

## Status

### Monolith Extraction — Complete

Monolith fully dismantled (2026-04-01 to 2026-04-07). All userland code extracted to standalone repos. Recipes migrated to zugot. Workspace contains only `examples/`.

Full details: [sprint-history.md](sprint-history.md#monolith-extraction--complete-2026-04-01-to-2026-04-07)

### Open KPIs

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Boot Time | <10s | **3.2s** (kernel+init), **~80ms** init→event loop | **Achieved** — Pure AGNOS, 0 external deps, 7 real binaries, 21MB initramfs, 512MB QEMU VM |
| OS Independence | Yes | Pending | Phase 13A — rebuild from source without host distro |

---

## Active Work

### Phase 13A — OS Independence Validation (BETA BLOCKER)

**This is the single most important remaining work.** Without it, AGNOS is a Debian overlay.

Infrastructure complete. Validation remaining — requires real hardware/QEMU execution.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Run bootstrap-toolchain.sh end-to-end | Not started | Build cross-compiler from source tarballs |
| 2 | Build base system in chroot | Not started | ark-build all 109 base recipes in order |
| 3 | Build AGNOS userland on target | Not started | `cargo build --release --workspace` inside AGNOS |
| 4 | Build kernel modules on target | Not started | Compile AGNOS kernel modules without host |
| 5 | Selfhost-validate passes all phases | Not started | Run `selfhost-validate --phase all` on booted ISO |
| 6 | CI automation | In progress | GitHub Actions: `publish-toolchain.yml`, `selfhost-build.yml`, `selfhost-validation.yml` |

**Critical path**: Download tarballs → bootstrap-toolchain.sh → enter-chroot.sh → ark-build recipes → cargo build userland → selfhost-validate

**To attempt now**: `sudo LFS=/mnt/agnos ./scripts/build-selfhosting-iso.sh`

### P0 — Other Active Blockers

**Cyrius as Base Toolchain (CI/Release)**
- [ ] Add `zugot/base/cyrius.toml` recipe
- [ ] CI builds use Cyrius for AGNOS-native components (kybernet, agnostik, agnosys, ark, nous)
- [ ] Release pipeline: Cyrius-compiled binaries as first-class artifacts
- [ ] `build-order.txt` updated — Cyrius inserted after Rust in toolchain stage
- [ ] Self-hosting validation: Cyrius compiles itself from the zugot recipe
- **Depends on**: aarch64 bootstrap complete, Phase 10 audit pass

**agnosticos.org Website**
- [ ] Update landing page stats (82 crates, 420+ recipes)
- [ ] Add Cyrius mention and article link
- [ ] Publish "The 29KB Compiler vs The $20,000 Compiler" as web article
- [ ] Add philosophy page
- **Blocked on**: Cyrius maturity + core Cyrius rewrites + micro OS tested

### Engineering Backlog

*Completed items archived in [sprint-history.md](sprint-history.md).*

| # | Priority | Item | Notes |
|---|----------|------|-------|
| B1 | High | Self-hosted CI runners on AGNOS | Replace Arch/Ubuntu runners with AGNOS itself |
| B2 | High | RPi4 hardware boot test | Firmware blobs added, needs physical validation |
| R2 | High | Update scripts/CI for zugot | 16 scripts/CI/config files still reference local `recipes/` paths |
| E1 | Medium | ESP32 agent source repo | Recipe done, MQTT bridge done. Pending: source repo + firmware |

Repo-specific backlog items tracked in their respective repos.

---

## Pre-Beta

### Phase 13C — Community & Documentation

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Video tutorials | Not started | Installation, usage, agent creation |
| 2 | Support portal | Not started | Discord + forum |
| 3 | Community testing program | Not started | Beta tester enrollment |
| 4 | Third-party security audit | Not started | External vendor |

### Phase 13F — Hardware Testing Matrix

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
| 10 | Tiiny AI Pocket Lab | TBD | Edge+AI | Not started |
| 11 | DJI Tello / micro drone | ARM | Edge/IoT | Not started |
| 12 | Hidizs AP80 Pro Max | MIPS | Audio/IoT | Not started |
| 13 | ESP32-S3 (microcontroller) | Xtensa | IoT/Edge | Not started |
| 14 | ESP32-C3 (RISC-V) | RISC-V | IoT/Edge | Not started |

### Phase 13G — Consumer App Bundle Tests

All 19 apps released. Bundle tests (`ark-bundle.sh`) not yet run.

| App | Bundle Test |
|-----|-------------|
| SecureYeoman, Photis Nadi, BullShift, Agnostic, Delta, Aequi, Irfan, Shruti, Tazama, Rasa, Mneme, Nazar, Selah, Abaco, Rahd, Tarang, Jalwa, Vidhana, Sutra | Not started |

### Phase 16 — Desktop Completeness

**Strategy**: Package existing open-source tools via takumi recipes for a complete desktop. AI-native replacements come later.

Detailed items tracked in respective repos:
- **16B/D/E** — Input, polish, configurability → `MacCracken/aethersafha`
- **16F** — Media ingestion & compositing → `MacCracken/aethersafta`
- **Desktop recipes** (fonts, themes, icons) → zugot

### Phase 15 — Threat Detection & Scanning

**Subsystem**: **phylax** — standalone repo (`MacCracken/phylax`). Detailed roadmap tracked there.

---

## Ecosystem

### Named Subsystems (25)

All subsystems are standalone repos at `/home/macro/Repos/{name}/`.
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
| **cyrius-seed** | Cyrius assembler | `MacCracken/cyrius-seed` | 0.1.0 |

### Cross-Cutting Concerns

**Bazaar** — Community package repository. Repo: `MacCracken/bazaar`. 90 recipes across 8 categories. Inventory tracked in bazaar repo.

**SecureYeoman & Agnostic** — Integration tracked in respective repos. Key ecosystem dependency: **sluice** (A2A protocol extraction from SY).

**Creator Economy** — The pipe, not the platform. Direct artist/creator support with zero middleman.

```
agnoshi: "support @artist 5 credits"
  → nous resolves artist identity (sigil-verified)
  → vinimaya transfers mudra tokens
  → libro records the transaction
  → artist gets notification via bote
  → content unlocks via kavach permissions
```

Key crates: mudra (tokens), vinimaya (payments), sigil (identity), kavach (access control), mela (storefront), libro (audit). Details tracked in respective app repos.

### Post-Beta Phases (17-19)

Detailed roadmaps tracked in respective repos:

| Phase | Focus | Primary Repos |
|-------|-------|---------------|
| **17** | Local inference optimization | `MacCracken/murti`, `MacCracken/hoosh`, `MacCracken/ai-hwaccel` |
| **18** | Immersive communication | `MacCracken/dhvani`, `MacCracken/goonj`, `MacCracken/soorat` |
| **19** | Computational architecture | `MacCracken/murti`, `MacCracken/agnosys`, `MacCracken/ai-hwaccel` |

### Future Shared Crates — Demand-Gated

Scaffold when 3+ consumers need shared implementations, or when a P0/P1 app blocks on it.

| Domain | Trigger | Likely Consumers | Priority |
|--------|---------|------------------|----------|
| **Geography / GIS** | joshua terrain, edge fleet, raasta pathfinding | joshua, kiran, raasta, nazar | Medium |
| **Music theory** | shruti or 3rd consumer needs shared scales/rhythm | shruti, naad, jalwa, kiran | Medium |
| **Typography / font metrics** | sahifa (PDF suite) needs font layout | sahifa, aethersafha, scriba | Low |
| **Nutrition / food science** | NPC simulation depth | joshua, kiran, rasayan | Low |
| **Economics / finance** | BullShift split extracts shared models | bullshift-core, aequi, sutra | Low |

### Research & Publication

Unified Consciousness Model paper and bhava roadmap tracked in `MacCracken/bhava`.

---

## Meta

- **Long-term vision**: [vision/release-vision.md](vision/release-vision.md) — v2.0 kernel, v3.0 Cyrius, v4.0 conscious objects, Phase 20, Foundation
- **Sprint history**: [sprint-history.md](sprint-history.md)
- **App roadmap**: [applications/roadmap.md](applications/roadmap.md)
- **Changelog**: [CHANGELOG.md](/CHANGELOG.md)
- **Contributing**: [CONTRIBUTING.md](/CONTRIBUTING.md)
- **LFS Reference**: https://www.linuxfromscratch.org/lfs/view/stable/
- **BLFS Reference**: https://www.linuxfromscratch.org/blfs/view/stable/

---

*Last Updated: 2026-04-07 | Next Review: 2026-04-14*
