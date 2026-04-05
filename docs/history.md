# AGNOS — Project History & Timeline

> **Status**: Active | **Last Updated**: 2026-04-05

---

## Timeline

| Date | Event |
|------|-------|
| **2026-02-11** | Initial commit. Kernel configuration, Phase 1 (Core OS bootable base), Phase 2 (AI Shell with human oversight), and Phase 5 (Production scaffolding) completed on Day 1 |
| **2026-02-16** | Continued Phase 5 development — production hardening and stabilization |
| **2026-02-22** | Core OS updates and refinement |
| **2026-02-26** | First code audit round — tests, fixes, quality gates |
| **2026-03-04** | Coverage expansion begins |
| **2026-03-05** | **Alpha release** (tag `2026.3.5`) — first tagged release, CalVer versioning adopted |
| **2026-03-06** | Phases 6-7 completed. Code audit work begins in earnest. Marketplace module scaffolded |
| **2026-03-07** | Alpha Docker image published (`ghcr.io/maccracken/agnosticos`). CI/CD pipeline established on GitHub Actions. Multiple audit rounds |
| **2026-03-08** | Release workflow automated (auto-publish instead of draft). Ark package recipes begin |
| **2026-03-09** | Browser builds (Firefox ESR, Chromium), CI integration, database recipe integration |
| **2026-03-10** | Full coverage infrastructure. gRPC, service mesh, OIDC modules. Multiple audit cycles |
| **2026-03-11** | Phase 14 (Edge OS Profile) added to roadmap. Continued audit and repair rounds |
| **2026-03-13** | First ISO build work begins — `build-installer.sh` development |
| **2026-03-14** | aarch64 ISO work — RPi4 ARM64 support |
| **2026-03-15** | RPi4 build fixes. Edge fleet management. Version and release patches |
| **2026-03-16** | Self-hosted runner setup begins for Tier 1 builds. Shared crates published to crates.io |
| **2026-03-17** | Audit completion rounds. Release `2026.3.17` |
| **2026-03-18** | Release `2026.3.18` — major milestone. Photis Nadi migrated from Flutter to Rust native. Consumer app packages updated. Sutra released (v2026.3.18). **LemonSqueezy rejects SecureYeoman** — the first domino |
| **2026-03-19** | Recipe updates and fixes across marketplace |
| **2026-03-20** | Self-hosted runner repaired. ISO build pipeline work continues |
| **2026-03-21** | Build improvements. stiva, nein, t-ron, impetus scaffolded. Multiple ISO build iterations |
| **2026-03-22** | **First successful ISO build** (early morning, after ~9 days of iteration). Abacus desktop calculator released. 266 commits, 298 recipes, 10,800+ tests, ~84.3% coverage |
| **2026-03-24** | Science stack push: 9 crates reach v1.0 in one session (impetus, hisab, bhava, bodh, sangha, and others). Agnosys integration ready for consumers |
| **2026-03-25** | Massive session: process refinement, SY migration planning, NPO groundwork |
| **2026-03-28** | AgnosAI benchmarks (4/5 wins vs CrewAI, 2000-4500x faster cached). Release `2026.3.29` |
| **2026-03-31** | **First fully clean release** (`2026.3.31`). All 17 artifacts built successfully — x86_64 ISO (desktop + minimal + edge), aarch64 SD card images (desktop + minimal + edge), userland tarballs, multi-arch Docker container. First release with zero build failures across all architectures. 80 shared crates (45 at v1.0+). 3 new science crates scaffolded (mastishk, rasayan, varna). 336 commits, 19 tagged releases |
| **2026-04-01** | **Monolith dismantled**. agent-runtime, ai-shell, llm-gateway, desktop-environment removed from workspace. 12 standalone repos extracted. 3 crate absorptions (bote 0.91.0, kavach 2.0.0, t-ron 0.90.0). Named subsystems: edge→seema, scheduler→samay. Crypto boundary resolved: sigil owns all AGNOS trust/crypto |
| **2026-04-02** | **Sigil 1.0.0** — first trust crate stable. Bote 0.91.0 — MCP 2025-11-25 spec compliance. **agnosticos.org** domain registered, coming-soon site deployed. 77 shared crates (56 at v1.0+). 95+ marketplace recipes |
| **2026-04-03** | **Cyrius seed** — cyrius-seed 0.1.0 (assembler, 102 tests). **Pure AGNOS desktop boot**: 3.2s, zero external deps. **Full recipe audit**: 109 marketplace recipes. **zugot** decided. **Genesis layer** architecture clarified. **Philosophy** documented. 6 new crates scaffolded (mudra, vinimaya, taal, natya, kshetra, zugot). 28 CLAUDE.md files standardized across ecosystem |
| **2026-04-04** | **Cyrius 1.0** — self-hosting compiler (29KB seed, 42ms bootstrap). Bootstrap loop closed. 44 programs, 58KB kernel (VM, processes, syscalls). Beats GNU on size (10-233x) and speed (wc 2.4x faster). 141 tests, 0 failures |
| **2026-04-05** | **Cyrius ecosystem** — 35 stdlib modules, 8 developer tools, 5 Rust crate rewrites (agnostik, agnosys, kybernet, nous, ark), aarch64 cross-compiler, 38 benchmarks, CI/CD pipelines. 186 tests, dual architecture. Day 3 and counting |

---

## Development Pace

AGNOS went from initial commit to first bootable ISO in **39 days** (2026-02-11 to 2026-03-22), and from first ISO to first fully clean multi-architecture release in **48 days** (2026-02-11 to 2026-03-31).

From first commit to sovereign self-hosting language with its own kernel in **53 days** (2026-02-11 to 2026-04-04).

The project accumulated **336+ commits** across **19+ tagged releases**, achieving 10,800+ passing tests and ~84.3% code coverage. The shared crate ecosystem grew to **82 crates** (56 at v1.0+ stable), with 19+ consumer applications developed in parallel.

The Cyrius language went from nothing to a self-hosting compiler with a 58KB kernel in **one day** (2026-04-04), and to a complete ecosystem (stdlib, tools, crate rewrites, dual architecture) in **three days**.

---

## Key Milestones

| Milestone | Date | Days from Start |
|-----------|------|----------------|
| First commit | 2026-02-11 | 0 |
| Alpha release | 2026-03-05 | 22 |
| First ISO build | 2026-03-22 | 39 |
| First clean multi-arch release | 2026-03-31 | 48 |
| Monolith dismantled | 2026-04-01 | 49 |
| Cyrius self-hosting | 2026-04-04 | 52 |
| AGNOS kernel (Cyrius) | 2026-04-04 | 52 |
| Cyrius ecosystem (stdlib, tools, crate rewrites) | 2026-04-05 | 53 |
| **Target: Beltane release** | **2026-05-01** | **79** |

---

*Last Updated: 2026-04-05*
