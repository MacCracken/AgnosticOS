# AGNOS Development Roadmap

> **Status**: Pre-Beta | **Last Updated**: 2026-04-20
> **Kernel 1.22.0 shipped** — 260KB, 33 subsystems, 26 syscalls, hardened pass.
> **Cyrius 5.5.4 shipped** — self-hosting from 29KB seed. Apple Silicon Mach-O self-hosts byte-identically on M-series (v5.3.13). Windows PE32+ Win64 ABI ≤4-arg (v5.5.3) + >4-arg cyrius-to-cyrius call-site (v5.5.4) produce correct code on real Windows 11; `lib/fnptr.cyr` indirect calls queued v5.5.5, native Windows self-host at v5.5.6. aarch64 cross-compiler + native Pi self-host byte-identical (v5.3.15+). v5.6.x compiler-optimization arc → v5.7.0 RISC-V → v5.8.0 bare-metal queued.
> **ISO pipeline started** — Stage 0 (component verification) implemented: `make iso-check`. See `docs/development/iso-pipeline.md`.
> **Kavach 3.0.0 shipped Cyrius-native** — 344KB (was 2.4MB Rust), 1 dep, 9 CWE fixes, sandbox lifecycle 500× faster.
> **Sankoch 2.0.0 shipped** — lossless compression (LZ4, DEFLATE, zlib, gzip). stdlib fold pending.
> **Abaco 2.1.0** — Miller-Rabin ~12× faster end-to-end via Cyrius hardware u64_mulmod fast-path.
> **Bote 2.5.1** / **T-Ron 2.0.0** shipped — both out of pre-release. Bote MCP pipeline ~5µs/message.
> **Ark 0.8.0** / **Nous 1.1.1** — package manager + resolver ported to Cyrius.
> **Phylax 1.0.0** / **Shakti 0.2.2** — threat detection + privilege escalation ported to Cyrius.
> **Critical path CLEARED**: libro ✅ argonaut ✅ kybernet ✅ kernel ✅ boot pipeline ✅ kavach ✅ ark ✅ nous ✅
> **Shared ecosystem**: 30+ repos ported to Cyrius. Pending port: bhava, takumi, aegis, aethersafha.
> **Cyrius platform cleanup**: Apple Silicon (done), aarch64 (done), Windows PE32+ (Win64 ABI call-site complete v5.5.4; fnptr v5.5.5, native self-host v5.5.6), RISC-V (v5.7.0 queued), bare-metal (v5.8.0 queued).
> **Next milestone**: Bootable ISO (Phase 1). `make iso-check` passes → Stage 1-4 implementation.

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
Creator economy (sovereign distribution, bootable USB media): [vision/creator-economy.md](vision/creator-economy.md)

---

## Status

### Cyrius Language — v5.5.4

Full milestone history lives in `cyrius/CLAUDE.md` + `cyrius/CHANGELOG.md`. Headline status for AGNOS:

| Milestone | Status |
|-----------|--------|
| Self-hosting compiler | **Done** (29KB seed, 467KB compiler, self-compile) |
| Multi-width types, unions, bitfields, defer | **Done** |
| Dependency resolution (cyrius.cyml, falls back to cyrius.toml) | **Done** |
| http_server + ws stdlib absorption | **Done** (v4.5.0) |
| Multi-file linker + cross-unit DCE | **Done** (v4.6.x) |
| PIC codegen, u128 types | **Done** (v4.7-4.8.x) |
| Jump tables + register allocation | **Done** (v4.8.4) |
| Math pack (u64_mulmod fast-path, 12× Miller-Rabin end-to-end) | **Done** (v4.8.5) |
| aarch64 cross-compiler + native Pi self-host (byte-identical) | **Done** (v5.3.15+) |
| Apple Silicon Mach-O (self-hosts byte-identically on M-series) | **Done** (v5.3.13) |
| Windows PE32+ — `hello\n` runs end-to-end on real hardware | **Done** (v5.4.8) |
| Windows Win64 ABI ≤4-arg (call-site + register mapping) | **Done** (v5.5.3) |
| Windows Win64 ABI >4-arg cyrius-to-cyrius call-site | **Done** (v5.5.4) |
| Windows `lib/fnptr.cyr` indirect fn-pointer Win64 calls | Queued — v5.5.5 |
| Windows native self-host (`cc5_win` compiling itself on `windows-latest`) | Queued — v5.5.6 |
| NSS/PAM end-to-end (shakti 0.2.x downstream blocker) | Queued — v5.5.10 |
| v5.5.x closeout | Queued — v5.5.16 |
| Compiler optimization arc (O1–O6: peephole, IR passes, regalloc, maximal-munch, slab) | Queued — v5.6.0–v5.6.6 |
| RISC-V rv64 codegen | Queued — v5.7.0 |
| Bare-metal / AGNOS kernel target | Queued — v5.8.0 |

### Cyrius Ports — Dependency Chain to Boot

| Crate | Rust → Cyrius | Status | Notes |
|-------|--------------|--------|-------|
| agnostik | 0.90.0 → 0.97.1 | **Done** | Shared types |
| agnosys | 0.51.0 → 1.0.0 | **Done** | Syscall wrappers (59× smaller) |
| sigil | 1.0.0 → 2.9.0 | **Done** | Crypto boundary |
| shravan | 1.1.0 → 2.3.2 | **Done** | Audio codecs |
| libro | 0.92.0 → 2.0.5 | **Done** | Audit chain |
| argonaut | 0.90.0 → 1.2.0 | **Done** | Init system library |
| kybernet | 0.51.0 → 1.0.1 | **Done** | PID 1 (14× smaller, 486KB) |
| AGNOS kernel | — → 1.22.0 | **Done** | 260KB, 33 subsystems, Cyrius-native |
| hoosh | 1.2.0 → 2.0.0 | **Done** | LLM gateway (10.8× smaller) |
| ai-hwaccel | 1.0.0 → 2.0.0 | **Done** | GPU detection (3.3× smaller) |
| avatara | 1.0.1 → 2.3.0 | **Done** | Archetype overlay (2,761× faster cached) |
| kavach | 2.0.0 → 3.0.0 | **Done** | Sandbox (500× faster lifecycle) |
| abaco | — → 2.1.0 | **Done** | Math/number theory (-52% lines, 12× Miller-Rabin) |
| bote | 0.92.0 → 2.5.1 | **Done** | MCP core (~5µs/message) |
| t-ron | 0.90.0 → 2.0.0 | **Done** | MCP security |
| daimon | 0.6.0 → 1.1.1 | **Done** | Agent orchestrator |
| agnoshi | 0.90.0 → 1.0.0 | **Done** | AI shell |
| itihas | 1.0.1 → 2.2.0 | **Done** | History/versioning |
| hadara | — → 1.0.0 | **Native** | Culture modeling (Cyrius-native) |
| mabda | 1.0.0 → 2.4.1 | **Done** | GPU foundation |
| sankoch | — → 2.0.0 | **Done** | Lossless compression (LZ4, DEFLATE, zlib, gzip) |
| ark | — → 0.8.0 | **Done** | Package manager (4× smaller, 40× faster) |
| nous | — → 1.1.1 | **Done** | Package resolver |
| phylax | — → 1.0.0 | **Done** | Threat detection |
| shakti | — → 0.2.2 | **Done** | Privilege escalation |
| hisab | — → 2.2.0 | **Done** | Higher math |
| bhava | — → 2.0.0 | Pending | Emotion/sentiment (has Cargo.toml) |
| takumi | — → 0.1.0 | Pending | Package build system |
| aegis | — → 0.1.0 | Pending | System security daemon |
| aethersafha | — → 0.1.0 | Pending | Wayland compositor |

### Monolith Extraction — Complete

Full details: [sprint-history.md](sprint-history.md#monolith-extraction--complete-2026-04-01-to-2026-04-07)

### Open KPIs

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Boot Time | <10s | **3.2s** (kernel+init), **~80ms** init→event loop | **Achieved** |
| OS Independence | Yes | Pending | Phase 13A — critical path cleared, self-hosting validation remaining |
| DOOM | Playable | **2.59ms/frame**, cyrius-doom 0.26.1, hardened (5 CVEs fixed) | Waiting on Cyrius 5.6.x optimization arc |

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

### Phase 13B — Arch-Neutral Boot Pipeline

**Gate**: opens on Cyrius v5.6.x compiler-optimization arc closeout (v5.6.5 or v5.6.6).
**Precedes**: Cyrius v5.7.0 RISC-V rv64 — this work lands *between* v5.6.x and v5.7.0.
**Rationale**: Cyrius locks the sequencing v5.6.x (optimization) → v5.7.0 (RISC-V) → v5.8.0 (bare-metal). Agnos already did the multi-arch split at v1.1.0 (`kernel/arch/x86_64/`, `kernel/arch/aarch64/`, `kernel/core/`, `kernel/user/`). The gap is that everything downstream of boot still carries x86_64/aarch64-shaped assumptions. Neutralizing now means v5.7.0 RISC-V and v5.8.0 bare-metal slot in as "add a target," not "rewrite the pipeline."

**Genesis-repo items (owned here):**

| # | Item | Notes |
|---|------|-------|
| 1 | `scripts/boot.cyr` arch detection + per-arch branch tables | Cross-compilation flag routing |
| 2 | ISO pipeline Stages 1–4 arch-aware | Stage output keyed on target triple |
| 3 | `bootstrap-toolchain.sh` cross-arch | x86_64 / aarch64 / riscv64 / bare-metal source tarball builds |
| 4 | `build-order.txt` per-arch gates | Failing arch doesn't block others |

**Downstream sweep (tracked in respective repos):**
- **Must-touch (boot path)**: agnos, kybernet, argonaut, agnosys, sigil
- **Should-touch (build/packaging)**: ark, nous, zugot, agnova, takumi
- **May-touch**: phylax, shakti, ai-hwaccel, seema

**Target**: complete before Cyrius v5.7.0 ships. Don't scope-creep before v5.6.x closeout — let the optimization arc re-baseline benchmarks first.

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

### Named Subsystems (30+)

All subsystems are standalone repos at `/home/macro/Repos/{name}/`.

| Name | Role | Repo | Version | Cyrius Port |
|------|------|------|---------|-------------|
| **agnos** | AGNOS kernel | `MacCracken/agnos` | 1.22.0 | **Native** |
| **cyrius** | Sovereign compiler | `MacCracken/cyrius` | 5.5.4 | **Native** |
| **kybernet** | PID 1 binary | `MacCracken/kybernet` | 1.0.1 | **Done** |
| **argonaut** | Init system (library) | `MacCracken/argonaut` | 1.2.0 | **Done** |
| **agnosys** | Kernel interface | `MacCracken/agnosys` | 1.0.0 | **Done** |
| **agnostik** | Shared types library | `MacCracken/agnostik` | 0.97.1 | **Done** |
| **sigil** | Trust verification & crypto | `MacCracken/sigil` | 2.9.0 | **Done** |
| **libro** | Audit chain | `MacCracken/libro` | 2.0.5 | **Done** |
| **hoosh** | LLM inference gateway | `MacCracken/hoosh` | 2.0.0 | **Done** |
| **avatara** | Divine archetype overlay | `MacCracken/avatara` | 2.3.0 | **Done** |
| **ai-hwaccel** | GPU detection | `MacCracken/ai-hwaccel` | 2.0.0 | **Done** |
| **kavach** | Sandbox execution | `MacCracken/kavach` | 3.0.0 | **Done** |
| **abaco** | Math/number theory | `MacCracken/abaco` | 2.1.0 | **Done** |
| **bote** | MCP core | `MacCracken/bote` | 2.5.1 | **Done** |
| **t-ron** | MCP security monitor | `MacCracken/t-ron` | 2.0.0 | **Done** |
| **daimon** | Agent orchestrator | `MacCracken/daimon` | 1.1.1 | **Done** |
| **agnoshi** | AI shell | `MacCracken/agnoshi` | 1.0.0 | **Done** |
| **hadara** | Culture modeling | `MacCracken/hadara` | 1.0.0 | **Native** |
| **shravan** | Audio codecs | `MacCracken/shravan` | 2.3.2 | **Done** |
| **mabda** | GPU foundation | `MacCracken/mabda` | 2.4.1 | **Done** |
| **sankoch** | Lossless compression | `MacCracken/sankoch` | 2.0.0 | **Done** |
| **itihas** | History/versioning | `MacCracken/itihas` | 2.2.0 | **Done** |
| **bsp** | BSP geometry library | `MacCracken/bsp` | 1.1.2 | **Done** (waiting on Cyrius 5.6.x optimization arc) |
| **cyrius-doom** | DOOM engine | `MacCracken/cyrius-doom` | 0.26.1 | **Native** (waiting on Cyrius 5.6.x optimization arc) |
| **ark** | Unified package manager | `MacCracken/ark` | 0.8.0 | **Done** |
| **nous** | Package resolver | `MacCracken/nous` | 1.1.1 | **Done** |
| **phylax** | Threat detection engine | `MacCracken/phylax` | 1.0.0 | **Done** |
| **shakti** | Privilege escalation | `MacCracken/shakti` | 0.2.2 | **Done** |
| **hisab** | Higher math | `MacCracken/hisab` | 2.2.0 | **Done** |
| **bhava** | Emotion/sentiment | `MacCracken/bhava` | 2.0.0 | Pending |
| **takumi** | Package build system | `MacCracken/takumi` | 0.1.0 | Pending |
| **aegis** | System security daemon | `MacCracken/aegis` | 0.1.0 | Pending |
| **aethersafha** | Desktop compositor | `MacCracken/aethersafha` | 0.1.0 | Pending |
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

*Last Updated: 2026-04-20 | Next Review: 2026-04-27*
