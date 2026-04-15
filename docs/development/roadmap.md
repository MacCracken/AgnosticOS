# AGNOS Development Roadmap

> **Status**: Pre-Beta | **Last Updated**: 2026-04-14
> **Kernel 1.22.0 shipped** — 260KB, 33 subsystems, 26 syscalls, hardened pass.
> **Cyrius 4.8.5-1** — 373KB self-hosting compiler, 42 stdlib modules. http_server + ws absorbed (v4.5.0); linker + cross-unit DCE (v4.6.x); PIC codegen (v4.7.x); types & codegen (u128, jump tables, math pack) (v4.8.x). Next major: v5.0 platforms (Mach-O, PE/COFF, RISC-V, bare-metal).
> **Kavach 3.0.0 shipped Cyrius-native** — 344KB (was 2.4MB Rust), 1 dep, 9 CWE fixes, sandbox lifecycle 500× faster.
> **Abaco 2.0.0 shipped Cyrius-native** — 5932→2856 lines (-52%), Miller-Rabin ~12× faster end-to-end via Cyrius 4.8.5 hardware u64_mulmod fast-path. Canonical port-feedback closed-loop instance.
> **Cyrius-doom 0.24.5** — plays DOOM, hardened (P(-1), 5 CVEs fixed), 2.59ms/frame (-4.7% from jump-table dispatch, 91%+ tick headroom), BSP 1.0.1 stable dep, pinned to Cyrius 4.8.5-1.
> **Bote 2.5.1** / **T-Ron 2.0.0** shipped — both out of pre-release. Bote MCP pipeline ~5µs/message, streamable HTTP unlocked by v4.5.0 stdlib absorption.
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

### Cyrius Language — v4.8.5-1

| Milestone | Status |
|-----------|--------|
| Self-hosting compiler | **Done** (29KB seed, 373KB compiler, self-compile) |
| Multi-width types (i8/i16/i32) | **Done** (v2.0) |
| Native .tcyr/.bcyr/.fcyr | **Done** (test/bench/fuzz) |
| Dependency resolution (cyrius.toml) | **Done** |
| Min version enforcement | **Done** (v3.3.0) |
| Small function inlining | **Done** (v3.3.5) |
| `#if`/`#define` preprocessor | **Done** |
| 3-tier benchmarking (cyrb bench) | **Done** |
| tok_names expanded (bug #32) | **Done** (v3.4.0, 32KB→64KB) |
| http_server + ws stdlib absorption | **Done** (v4.5.0) |
| Multi-file linker + cross-unit DCE | **Done** (v4.6.x) |
| PIC codegen | **Done** (v4.7.x) |
| u128 types | **Done** (v4.8.x) |
| Jump tables + register allocation | **Done** (v4.8.4) |
| Math pack (u64_mulmod fast-path) | **Done** (v4.8.5) |
| Multi-platform (Mach-O, PE, RISC-V) | Next — v5.0 |

### Cyrius Ports — Dependency Chain to Boot

| Crate | Rust → Cyrius | Status | Notes |
|-------|--------------|--------|-------|
| agnostik | 0.90.0 → 0.97.1 | **Done** | Shared types |
| agnosys | 0.51.0 → 0.97.2 | **Done** | Syscall wrappers (59× smaller) |
| sigil | 1.0.0 → 2.1.2 | **Done** | Crypto boundary |
| shravan | 1.1.0 → 2.1.1 | **Done** | Audio codecs |
| libro | 0.92.0 → 1.0.3 | **Done** | Audit chain |
| argonaut | 0.90.0 → 1.2.0 | **Done** | Init system library |
| kybernet | 0.51.0 → 1.0.1 | **Done** | PID 1 (14× smaller, 486KB) |
| AGNOS kernel | — → 1.22.0 | **Done** | 260KB, 33 subsystems, Cyrius-native |
| hoosh | 1.2.0 → 2.0.0 | **Done** | LLM gateway (10.8× smaller) |
| ai-hwaccel | 1.0.0 → 2.0.0 | **Done** | GPU detection (3.3× smaller) |
| avatara | 1.0.1 → 2.3.0 | **Done** | Archetype overlay (2,761× faster cached) |
| kavach | 2.0.0 → 3.0.0 | **Done** | Sandbox (500× faster lifecycle) |
| abaco | — → 2.0.0 | **Done** | Math/number theory (-52% lines) |
| bote | 0.92.0 → 2.5.1 | **Done** | MCP core (~5µs/message) |
| t-ron | 0.90.0 → 2.0.0 | **Done** | MCP security |
| daimon | 0.6.0 → 1.1.1 | **Done** | Agent orchestrator |
| agnoshi | 0.90.0 → 1.0.0 | **Done** | AI shell |
| itihas | 1.0.1 → 2.2.0 | **Done** | History/versioning |
| hadara | — → 1.0.0 | **Native** | Culture modeling (Cyrius-native) |
| mabda | 1.0.0 → 2.1.2 | **Done** | GPU foundation |
| bhava | — → 2.0.0 | Pending | Emotion/sentiment (has Cargo.toml) |
| hisab | — → 1.4.0 | Pending | Accounting (has Cargo.toml) |

### Monolith Extraction — Complete

Full details: [sprint-history.md](sprint-history.md#monolith-extraction--complete-2026-04-01-to-2026-04-07)

### Open KPIs

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Boot Time | <10s | **3.2s** (kernel+init), **~80ms** init→event loop | **Achieved** |
| OS Independence | Yes | Pending | Phase 13A — critical path cleared, self-hosting validation remaining |
| DOOM | Playable | **2.59ms/frame**, cyrius-doom 0.24.5, hardened (5 CVEs fixed) | Sprint 3 pending (Black Book → v1.0) |

---

## Active Work

### Phase 13A — OS Independence Validation (BETA BLOCKER)

**This is the single most important remaining work.** Without it, AGNOS is a Debian overlay.

**Previous blocker (CLEARED)**: kybernet Cyrius port. Dependency chain completed 2026-04-13: libro ✅ → argonaut ✅ → kybernet 1.0.1 ✅ → kernel 1.22.0 ✅ → boot pipeline (Cyrius, 56KB) ✅.

**Current work**: Sovereign boot pipeline active. Kernel boots in QEMU via `make boot-test`. Remaining items are self-hosting validation (can AGNOS rebuild itself from source without a host distro).

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Kernel boots in QEMU | **Done** | boot.cyr (56KB Cyrius binary), kernel 1.22.0 (260KB) |
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
| **agnos** | AGNOS kernel | `MacCracken/agnos` | 1.22.0 | **Native** |
| **cyrius** | Sovereign compiler | `MacCracken/cyrius` | 4.8.5-1 | **Native** |
| **kybernet** | PID 1 binary | `MacCracken/kybernet` | 1.0.1 | **Done** |
| **argonaut** | Init system (library) | `MacCracken/argonaut` | 1.2.0 | **Done** |
| **agnosys** | Kernel interface | `MacCracken/agnosys` | 0.97.2 | **Done** |
| **agnostik** | Shared types library | `MacCracken/agnostik` | 0.97.1 | **Done** |
| **sigil** | Trust verification & crypto | `MacCracken/sigil` | 2.1.2 | **Done** |
| **libro** | Audit chain | `MacCracken/libro` | 1.0.3 | **Done** |
| **hoosh** | LLM inference gateway | `MacCracken/hoosh` | 2.0.0 | **Done** |
| **avatara** | Divine archetype overlay | `MacCracken/avatara` | 2.3.0 | **Done** |
| **ai-hwaccel** | GPU detection | `MacCracken/ai-hwaccel` | 2.0.0 | **Done** |
| **kavach** | Sandbox execution | `MacCracken/kavach` | 3.0.0 | **Done** |
| **abaco** | Math/number theory | `MacCracken/abaco` | 2.0.0 | **Done** |
| **bote** | MCP core | `MacCracken/bote` | 2.5.1 | **Done** |
| **t-ron** | MCP security monitor | `MacCracken/t-ron` | 2.0.0 | **Done** |
| **daimon** | Agent orchestrator | `MacCracken/daimon` | 1.1.1 | **Done** |
| **agnoshi** | AI shell | `MacCracken/agnoshi` | 1.0.0 | **Done** |
| **hadara** | Culture modeling | `MacCracken/hadara` | 1.0.0 | **Native** |
| **shravan** | Audio codecs | `MacCracken/shravan` | 2.1.1 | **Done** |
| **mabda** | GPU foundation | `MacCracken/mabda` | 2.1.2 | **Done** |
| **itihas** | History/versioning | `MacCracken/itihas` | 2.2.0 | **Done** |
| **bsp** | BSP geometry library | `MacCracken/bsp` | 1.0.1 | **Done** |
| **cyrius-doom** | DOOM engine | `MacCracken/cyrius-doom` | 0.24.5 | **Native** |
| **ark** | Unified package manager | `MacCracken/ark` | 0.1.0 | **Done** |
| **nous** | Package resolver | `MacCracken/nous` | 0.1.0 | **Done** |
| **bhava** | Emotion/sentiment | `MacCracken/bhava` | 2.0.0 | Pending |
| **hisab** | Higher math | `MacCracken/hisab` | 1.4.0 | Pending |
| **shakti** | Privilege escalation | `MacCracken/shakti` | 0.1.0 | Pending |
| **aethersafha** | Desktop compositor | `MacCracken/aethersafha` | 0.1.0 | Pending |
| **takumi** | Package build system | `MacCracken/takumi` | 0.1.0 | Pending |
| **aegis** | System security daemon | `MacCracken/aegis` | 0.1.0 | Pending |
| **phylax** | Threat detection engine | `MacCracken/phylax` | 0.22.3 | Pending |
| **mela** | Agent marketplace | `MacCracken/mela` | 0.1.0 | Pending |
| **agnova** | OS installer | `MacCracken/agnova` | 0.1.0 | Pending |
| **seema** | Edge fleet management | `MacCracken/seema` | 0.1.0 | Pending |
| **samay** | Task scheduler | `MacCracken/samay` | 0.1.0 | Pending |
| **bazaar** | Community package repo | `MacCracken/bazaar` | — | — |

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

*Last Updated: 2026-04-14 | Next Review: 2026-04-21*
