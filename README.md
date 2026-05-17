# AGNOS — AI-Native General Operating System

> **A**rtificial **G**eneral **N**etwork **O**perating **S**ystem

[![License](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)
[![Kernel](https://img.shields.io/badge/kernel-AGNOS%201.30.5-orange)](https://github.com/MacCracken/agnos)
[![Language](https://img.shields.io/badge/Cyrius-5.11.55-red)](https://github.com/MacCracken/cyrius)
[![Status](https://img.shields.io/badge/status-pre--beta-yellow)](docs/development/roadmap.md)

**AGNOS** is a sovereign operating system written in **Cyrius** — a systems language with a 29KB seed, zero external dependencies, and a self-hosting compiler. The kernel is ~365KB and iron-validated on NUC AMD (Boot-to-Shell MVP, 2026-05-15). The compiler is ~809KB. 30+ subsystems ported from Rust to Cyrius. No Linux dependency at runtime.

> *AGI doesn't run on infrastructure built for web apps. It runs on infrastructure built for AGI.*
>
> *A system that can't prove its own integrity can't be trusted with autonomous action.*

---

## Architecture

```
+------------------------------------------------------------------+
|  Desktop                |  Agent Runtime          |  Kernel       |
|  +--------------------+ |  +--------------------+ |  +----------+ |
|  | aethersafha        | |  | daimon (1.1.4)     | |  | AGNOS    | |
|  | Wayland compositor | |  | 144 MCP tools      | |  | 1.30.5   | |
|  |                    | |  | Agent orchestrator | |  | ~365KB   | |
|  +--------------------+ |  +--------------------+ |  | 35+ sub- | |
|  | agnoshi (1.0.0)    | |  | hoosh (2.0.0)      | |  | systems  | |
|  | AI shell           | |  | LLM gateway        | |  | 26 sys-  | |
|  |                    | |  | 15 providers       | |  | calls    | |
|  +--------------------+ |  +--------------------+ |  | Cyrius-  | |
|  | 23 consumer apps   | |  | aegis + sigil      | |  | native   | |
|  | marketplace (mela) | |  | kavach (3.0.0)     | |  +----------+ |
|  +--------------------+ |  +--------------------+ |              |
+------------------------------------------------------------------+
```

## The Stack

| Layer | Component | Version | Notes |
|-------|-----------|---------|-------|
| **Kernel** | AGNOS | 1.30.5 | ~365KB, 35+ subsystems, Cyrius-native, iron-validated NUC AMD |
| **Compiler** | Cyrius | 5.11.55 | ~809KB, self-hosting from 29KB seed |
| **PID 1** | kybernet | 1.0.2 | 486KB, 140 tests |
| **Init** | argonaut | 1.5.0 | 3 boot modes |
| **Sandbox** | kavach | 3.0.0 | 344KB, Landlock + seccomp-bpf |
| **Crypto** | sigil | 3.1.0 | Ed25519, trust verification |
| **Audit** | libro | 2.0.5 | Hash-chained event log |
| **MCP** | bote | 2.5.1 | ~5us/message pipeline |
| **LLM** | hoosh | 2.0.0 | 474KB, 15 providers |
| **Agents** | daimon | 1.1.4 | 144 MCP tools |
| **Shell** | agnoshi | 1.0.0 | Natural language terminal |
| **Packages** | ark + nous | 0.8.0 / 1.1.2 | Package manager + resolver |
| **Recipes** | zugot | — | 421 base + 90 bazaar |

> Live versions for the full ecosystem: [`docs/development/state.md`](docs/development/state.md) — refreshed each cycle close.

## Port Receipts (Rust to Cyrius)

| Subsystem | Before | After | Ratio |
|-----------|--------|-------|-------|
| agnosys | 6.9MB | 117KB | 59x smaller |
| kybernet | 6.7MB | 486KB | 14x smaller |
| hoosh | 5.1MB | 474KB | 10.8x smaller |
| kavach | 2.4MB | 344KB | 7x smaller, 500x faster lifecycle |
| ai-hwaccel | 708KB | 217KB | 3.3x smaller, 518 tests |
| avatara | — | — | 2,761x faster cached access |

## Consumer Apps (23)

All ship as `.agnos-agent` marketplace bundles:

| App | Description |
|-----|-------------|
| **SecureYeoman** | Sovereign AI agent platform (flagship) |
| **AgnosAI** | Agent orchestration engine |
| **Irfan** | LLM management and training |
| **Delta** | Code hosting (git, PRs, CI/CD) |
| **Aequi** | Self-employed accounting |
| **Jalwa** | AI-native media player |
| **Tazama** | AI-native video editor |
| **Shruti** | Digital audio workstation |
| **Rasa** | AI-native image editor |
| **Mneme** | AI-native knowledge base |
| **Photis Nadi** | Productivity app |
| **Nazar** | System monitor |
| And 11 more... | |

## Development Status

**Pre-beta.** Critical path to boot cleared. Closed-beta cohort prep underway.

| Milestone | Status |
|-----------|--------|
| Sovereign kernel (~365KB, 35+ subsystems, iron-validated 2026-05-15) | Done |
| Cyrius compiler (self-hosting, 42+ stdlib modules) | Done |
| 30+ subsystem ports (Rust to Cyrius) | Done |
| Sovereign boot pipeline (Cyrius) | Done |
| LFS base recipes (421 base + 90 bazaar) | Done |
| Security (kavach 3.0.0, sigil 3.1.0, libro 2.0.5) | Done |
| 19+ consumer apps with MCP integration | Done |
| **Self-hosting (AGNOS builds AGNOS)** | **Primary closed-beta blocker — gated on Cyrius v5.12.x bare-metal target (slipped from v5.10.x → v5.11.x → v5.12.x)** |
| Closed-beta tester cohort (5–15 trusted testers) | Pending closed-beta cut |
| Third-party security audit | Public-beta gate |
| Community testing program (formal enrollment) | Public-beta gate |

**Closed-beta target: early June 2026** | **Public-beta target: Q4 2026** | **v1.0 target: Q2 2027**

See [docs/development/roadmap.md](docs/development/roadmap.md) for full details.

## Quick Start

### Build the boot pipeline (Cyrius)

```bash
git clone https://github.com/MacCracken/agnosticos.git
cd agnosticos/scripts
cyrius build src/boot.cyr build/boot
./build/boot --status
```

### Boot in QEMU

```bash
cd agnosticos
make boot-test
```

## System Requirements

| | Minimum (CLI) | Recommended (Desktop + LLMs) |
|---|---|---|
| **CPU** | x86_64 | 8+ cores |
| **RAM** | 4 GB | 32 GB+ |
| **Storage** | 20 GB SSD | 100 GB NVMe |
| **GPU** | -- | NVIDIA/AMD/Intel discrete |

## Security

- **kavach 3.0.0** — Landlock + seccomp-bpf sandboxing (344KB, 9 CWE fixes)
- **sigil 3.1.0** — Ed25519 trust verification, revocation
- **libro 2.0.5** — Cryptographic audit chain, hash-linked event log
- **AGNOS kernel** — 3 hardening passes, 14 buffer overflows found and fixed; structurally immune to CVE-2026-31431 (no socket/splice/AF_ALG surface in 26-syscall table)

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Documentation

| Document | Description |
|----------|-------------|
| [roadmap.md](docs/development/roadmap.md) | Development roadmap, KPIs |
| [architecture.md](docs/architecture.md) | System architecture |
| [shared-crates.md](docs/development/planning/shared-crates.md) | Shared crate registry (full, incl. pre-1.0) |
| [doc-health.md](docs/doc-health.md) | Living doc-health ledger |
| [state.md](docs/development/state.md) | Live ecosystem state (cycle, pins, sweeps) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines |
| [SECURITY.md](SECURITY.md) | Security policies |

## License

**GNU General Public License v3.0** (GPLv3). See [LICENSE](LICENSE).

Desktop GUI applications are **AGPL-3.0**.

---

<div align="center">

**AGNOS** -- The Operating System for the Age of AI

*Built for agents. Controlled by humans. Written in Cyrius.*

</div>
