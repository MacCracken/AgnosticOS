# AGNOS Development Roadmap

> **Status**: Pre-Beta | **Last Updated**: 2026-04-14
> **Kernel 1.22.0 shipped** — 260KB, 33 subsystems, 26 syscalls, hardened pass.
> **Cyrius 4.7.0-alpha2** — 353KB self-hosting compiler, 42 stdlib modules. http_server + ws absorbed (v4.5.0); linker + cross-unit DCE in progress (v4.6.x); PIC codegen alpha (v4.7.x).
> **Kavach 3.0.0 shipped Cyrius-native** — 344KB (was 2.4MB Rust), 1 dep, 9 CWE fixes, sandbox lifecycle 500× faster.
> **Cyrius-doom 0.24.3** — plays DOOM, hardened (P(-1), 5 CVEs fixed), 2.66ms/frame (91% tick headroom), BSP 1.0.1 stable dep.
> **Bote 1.3.0** — MCP pipeline ~5µs/message; v1.4.0 streamable HTTP enabled by v4.5.0 stdlib absorption.
> **Boot script v2026.3.31** — sovereign Cyrius boot pipeline (56KB), `--status` surfaces full ecosystem snapshot.
> **Critical path CLEARED**: libro ✅ argonaut ✅ kybernet ✅ kernel ✅ boot pipeline ✅ kavach ✅
> **Shared ecosystem**: 10-15 repos shipping on the Cyrius toolchain; ports done: agnostik, agnosys, sigil, shravan, argonaut, kybernet, nous, ark, sakshi, majra, bsp, cyrius-doom, mabda, patra, libro, tarang, yukti, avatara, ai-hwaccel, hoosh, hadara (native), kavach. In progress: bhava, hisab. Blocked: vidya MCP (needs bote v1.4.0).
> **Next major**: **Cyrius 5.0 — Multi-Platform** (Mach-O + PE/COFF + RISC-V + bare-metal). 4.x finishes with PIC codegen + types/codegen (u128, defmt, jump tables, regalloc).
> **Handoff note (2026-04-14)**: base OS stack updates held until Cyrius 5.0 lands; then refresh all sibling repo versions and bump `scripts/src/boot.cyr` to match. Likely continues on a rotated account session.

---

## Strategic Vision

AGNOS becomes a real operating system in two stages:

1. **OS Independence** (Beta) — AGNOS boots and builds itself without any host distro. Self-hosting LFS-style base, takumi recipes for the full stack, ark as sole package manager. This is the foundation.

2. **Desktop Completeness** (v1.0) — Ship a complete desktop experience by packaging existing open-source tools first, then progressively replace with AI-native alternatives where the AI is the primary value.

**Priority order**: OS identity → desktop essentials via recipes → AI-native apps

---

## Critical Path to Beta

```
Cyrius ports (agnostik → agnosys → libro → argonaut → kybernet)
  ↓
kybernet folds into AGNOS kernel as PID 1
  ↓
Phase 13A (self-hosting boot) ──→ Phase 16 (desktop) ──→ Phase 13C (community) ──→ BETA
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

### Cyrius Language — v3.4.1

| Milestone | Status |
|-----------|--------|
| Self-hosting compiler | **Done** (29KB seed, 215KB compiler, 11ms self-compile) |
| Multi-width types (i8/i16/i32) | **Done** (v2.0) |
| Native .tcyr/.bcyr/.fcyr | **Done** (test/bench/fuzz) |
| Dependency resolution (cyrius.toml) | **Done** |
| Min version enforcement | **Done** (v3.3.0) |
| Small function inlining | **Done** (v3.3.5) |
| `#if`/`#define` preprocessor | **Done** |
| 3-tier benchmarking (cyrb bench) | **Done** |
| tok_names expanded (bug #32) | **Done** (v3.4.0, 32KB→64KB) |
| Multi-file linker | .o emission done, linker not yet |
| u128 | Research |

### Cyrius Ports — Dependency Chain to Boot

| Crate | Rust → Cyrius | Status | Notes |
|-------|--------------|--------|-------|
| agnostik | 0.90.0 → Cyrius | **Done** — updating to 3.2.5 | Shared types |
| agnosys | 0.51.0 → Cyrius | **Done** — updating to 3.2.5 | Syscall wrappers |
| sigil | 1.0.0 → Cyrius | **Done** | Crypto boundary |
| shravan | 1.1.0 → 2.0.0 Cyrius | **Done** — working on 2.1.0 | Audio codecs |
| libro | 0.92.0 → Cyrius | **In progress** — needs Cyrius fixes first | Audit chain |
| argonaut | 0.90.0 → Cyrius | **Done** — needs libro dep folded in | Init system library |
| tarang | 0.21.3 → Cyrius | **Started** | Media framework |
| kybernet | 0.51.0 → Cyrius | **Next** — blocked on libro+argonaut | PID 1 → folds into kernel |
| AGNOS kernel | — | Waiting for kybernet | Boot target |

### Monolith Extraction — Complete

Full details: [sprint-history.md](sprint-history.md#monolith-extraction--complete-2026-04-01-to-2026-04-07)

### Open KPIs

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Boot Time | <10s | **3.2s** (kernel+init), **~80ms** init→event loop | **Achieved** |
| OS Independence | Yes | Pending | Phase 13A — blocked on kybernet port |
| DOOM | Playable | **2.9ms/frame**, 129KB, Episode 1 feature-complete | Alpha done, beta polish |

---

## Active Work

### Phase 13A — OS Independence Validation (BETA BLOCKER)

**This is the single most important remaining work.** Without it, AGNOS is a Debian overlay.

**Previous blocker (CLEARED)**: kybernet Cyrius port. Dependency chain completed 2026-04-13: libro ✅ → argonaut ✅ → kybernet 1.0.1 ✅ → kernel 1.21.0 ✅ → boot pipeline (Cyrius, 48KB) ✅.

**Current work**: Sovereign boot pipeline active. Kernel boots in QEMU via `make boot-test`. Remaining items are self-hosting validation (can AGNOS rebuild itself from source without a host distro).

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Kernel boots in QEMU | **Done** | boot.cyr (48KB Cyrius binary), kernel 1.21.0 (220KB) |
| 2 | Sovereign boot pipeline | **Done** | `make boot-test` from genesis repo |
| 3 | Run bootstrap-toolchain.sh end-to-end | Not started | Build cross-compiler from source tarballs (scripts need Cyrius port) |
| 4 | Build base system in chroot | Not started | ark-build all 109 base recipes in order |
| 5 | Build AGNOS userland on target | Not started | Cyrius-compiled binaries inside AGNOS |
| 6 | Selfhost-validate passes all phases | Not started | Run `selfhost-validate --phase all` on booted ISO |
| 7 | CI automation | In progress | GitHub Actions workflows |

**Target**: May 1, 2026 (Beltane)

### P0 — Other Active Blockers

**Cyrius as Base Toolchain (CI/Release)**
- [ ] Add `zugot/base/cyrius.toml` recipe
- [ ] CI builds use Cyrius for AGNOS-native components
- [ ] Release pipeline: Cyrius-compiled binaries as first-class artifacts
- [ ] `build-order.txt` updated — Cyrius inserted after Rust in toolchain stage

**agnosticos.org Website**
- [ ] Update landing page stats
- [ ] Add Cyrius mention and DOOM article
- [ ] Publish articles as web content
- [ ] Add philosophy page
- **Blocked on**: Cyrius maturity + core rewrites stabilized

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
| 1 | Rocky Linux VM | x86_64 | Dev/test | **Active** — DOOM testing environment |
| 2 | Touchscreen PC | x86_64 | Desktop | Available — needs AGNOS install |
| 3 | Raspberry Pi 4 | aarch64 | Full | Available — needs physical validation |
| 4 | AWS DeepLens | x86_64 | Edge | Available |
| 5 | 4U server blade | x86_64 | Build/storage | Available — CI runner candidate |
| 6 | 2x 1U blades | x86_64 | CI runners | Available |
| 7 | NAS conversion | x86_64 | Fleet storage | Available |
| 8 | DJI Tello drone | ARM | IoT | Available |
| 9 | ESP32 devices (multiple) | xtensa | IoT/Edge | Available |
| 10 | ASIC miners | — | Crypto accel | Available |
| 11 | Gaming cabinet | x86_64 | Desktop + kavach | Available — dual-purpose: AGNOS host + Windows guest |

### Phase 13G — Consumer App Bundle Tests

All 19 apps released. Bundle tests (`ark-bundle.sh`) not yet run.

### Phase 16 — Desktop Completeness

Detailed items tracked in respective repos:
- **16B/D/E** — Input, polish, configurability → `MacCracken/aethersafha`
- **16F** — Media ingestion & compositing → `MacCracken/aethersafta`
- **Desktop recipes** (fonts, themes, icons) → zugot

### Phase 15 — Threat Detection & Scanning

**Subsystem**: **phylax** — standalone repo (`MacCracken/phylax`). Detailed roadmap tracked there.

---

## Ecosystem

### Named Subsystems (25+)

All subsystems are standalone repos at `/home/macro/Repos/{name}/`.

| Name | Role | Repo | Version | Cyrius Port |
|------|------|------|---------|-------------|
| **hoosh** | LLM inference gateway (port 8088) | `MacCracken/hoosh` | 1.2.0 | Pending |
| **daimon** | Agent orchestrator (port 8090) | `MacCracken/daimon` | 0.6.0 | Pending |
| **agnosys** | Kernel interface | `MacCracken/agnosys` | Cyrius | **Done** |
| **agnostik** | Shared types library | `MacCracken/agnostik` | Cyrius | **Done** |
| **shakti** | Privilege escalation | `MacCracken/shakti` | 0.1.0 | Pending |
| **agnoshi** | AI shell | `MacCracken/agnoshi` | 0.90.0 | Pending |
| **aethersafha** | Desktop compositor | `MacCracken/aethersafha` | 0.1.0 | Pending |
| **sigil** | Trust verification & crypto | `MacCracken/sigil` | Cyrius | **Done** |
| **bote** | MCP core | `MacCracken/bote` | 0.92.0 | Pending |
| **t-ron** | MCP security monitor | `MacCracken/t-ron` | 0.90.0 | Pending |
| **kavach** | Sandbox execution | `MacCracken/kavach` | 2.0.0 | Pending |
| **ark** | Unified package manager | `MacCracken/ark` | 0.1.0 | Pending |
| **nous** | Package resolver | `MacCracken/nous` | 0.1.0 | Pending |
| **takumi** | Package build system | `MacCracken/takumi` | 0.1.0 | Pending |
| **mela** | Agent marketplace | `MacCracken/mela` | 0.1.0 | Pending |
| **aegis** | System security daemon | `MacCracken/aegis` | 0.1.0 | Pending |
| **argonaut** | Init system (library) | `MacCracken/argonaut` | Cyrius | **Done** — needs libro |
| **kybernet** | PID 1 binary | `MacCracken/kybernet` | Cyrius (partial) | **Next** |
| **agnova** | OS installer | `MacCracken/agnova` | 0.1.0 | Pending |
| **seema** | Edge fleet management | `MacCracken/seema` | 0.1.0 | Pending |
| **samay** | Task scheduler | `MacCracken/samay` | 0.1.0 | Pending |
| **phylax** | Threat detection engine | `MacCracken/phylax` | 0.22.3 | Pending |
| **bazaar** | Community package repo | `MacCracken/bazaar` | — | — |
| **mabda** | GPU foundation | `MacCracken/mabda` | 1.0.0 | Pending |
| **shravan** | Audio codecs | `MacCracken/shravan` | 2.0.0 Cyrius | **Done** |
| **tarang** | Media framework | `MacCracken/tarang` | Cyrius (partial) | **In progress** |
| **libro** | Audit chain | `MacCracken/libro` | Cyrius (partial) | **In progress** |

### Cross-Cutting Concerns

**Bazaar** — Community package repository. Repo: `MacCracken/bazaar`. 90 recipes across 8 categories.

**SecureYeoman & Agnostic** — Integration tracked in respective repos. Key ecosystem dependency: **sluice** (A2A protocol extraction from SY).

**Creator Economy** — The pipe, not the platform. Direct artist/creator support with zero middleman. Key crates: mudra, vinimaya, sigil, kavach, mela, libro. Details tracked in respective app repos.

### Post-Beta Phases (17-19)

Detailed roadmaps tracked in respective repos:

| Phase | Focus | Primary Repos |
|-------|-------|---------------|
| **17** | Local inference optimization | `MacCracken/murti`, `MacCracken/hoosh`, `MacCracken/ai-hwaccel` |
| **18** | Immersive communication | `MacCracken/dhvani`, `MacCracken/goonj`, `MacCracken/soorat` |
| **19** | Computational architecture | `MacCracken/murti`, `MacCracken/agnosys`, `MacCracken/ai-hwaccel` |

### Future Shared Crates — Demand-Gated

| Domain | Trigger | Likely Consumers | Priority |
|--------|---------|------------------|----------|
| **Service mesh** | Cyrius services need shared HTTP/TCP/TLS layer + service discovery. Like sakshi for services. | vidya, hoosh, ifran, daimon, mela | High (post-boot) |
| **kula** (कुल) | Family/clan mesh — peer-to-peer identity, contact sharing, device fleet, shared storage. Depends on: sigil, bote, patra, seema, kavach. | Every family running AGNOS | High (post-beta) |
| **Geography / GIS** | joshua terrain, edge fleet, raasta pathfinding | joshua, kiran, raasta, nazar | Medium |
| **Music theory** | shruti or 3rd consumer needs shared scales/rhythm | shruti, naad, jalwa, kiran | Medium |
| **Typography / font metrics** | sahifa (PDF suite) needs font layout | sahifa, aethersafha, scriba | Low |

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

*Last Updated: 2026-04-11 | Next Review: 2026-04-18*
