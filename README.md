# AGNOS — AI-Native General Operating System

> **A**rtificial **G**eneral **N**etwork **O**perating **S**ystem

[![License](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)
[![Kernel](https://img.shields.io/badge/kernel-AGNOS%201.22.0-orange)](https://github.com/MacCracken/agnos)
[![Language](https://img.shields.io/badge/Cyrius-4.8.5--1-red)](https://github.com/MacCracken/cyrius)
[![Status](https://img.shields.io/badge/status-pre--beta-yellow)](docs/development/roadmap.md)

**AGNOS** is a sovereign operating system written in **Cyrius** — a systems language with a 29KB seed, zero external dependencies, and a self-hosting compiler. The kernel is 260KB. The compiler is 373KB. 22+ subsystems ported from Rust to Cyrius. No Linux dependency at runtime.

> *AGI doesn't run on infrastructure built for web apps. It runs on infrastructure built for AGI.*
>
> *A system that can't prove its own integrity can't be trusted with autonomous action.*

---

## Architecture

```
+------------------------------------------------------------------+
|  Desktop                |  Agent Runtime          |  Kernel       |
|  +--------------------+ |  +--------------------+ |  +----------+ |
|  | aethersafha        | |  | daimon (1.1.1)     | |  | AGNOS    | |
|  | Wayland compositor | |  | 144 MCP tools      | |  | 1.22.0   | |
|  |                    | |  | Agent orchestrator | |  | 260KB    | |
|  +--------------------+ |  +--------------------+ |  | 33 sub-  | |
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
| **Kernel** | AGNOS | 1.22.0 | 260KB, 33 subsystems, Cyrius-native |
| **Compiler** | Cyrius | 4.8.5-1 | 373KB, self-hosting from 29KB seed |
| **PID 1** | kybernet | 1.0.1 | 486KB, 140 tests |
| **Init** | argonaut | 1.2.0 | 3 boot modes |
| **Sandbox** | kavach | 3.0.0 | 344KB, Landlock + seccomp-bpf |
| **Crypto** | sigil | 2.1.2 | Ed25519, trust verification |
| **Audit** | libro | 1.0.3 | Hash-chained event log |
| **MCP** | bote | 2.5.1 | ~5us/message pipeline |
| **LLM** | hoosh | 2.0.0 | 474KB, 15 providers |
| **Agents** | daimon | 1.1.1 | 144 MCP tools |
| **Shell** | agnoshi | 1.0.0 | Natural language terminal |
| **Packages** | ark + nous | 0.1.0 | Package manager + resolver |
| **Recipes** | zugot | — | 421 base + 90 bazaar |

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

**Pre-beta.** Phases 0-14 complete. Critical path to boot cleared.

| Milestone | Status |
|-----------|--------|
| Sovereign kernel (260KB, 33 subsystems) | Done |
| Cyrius compiler (self-hosting, 42 stdlib modules) | Done |
| 22+ subsystem ports (Rust to Cyrius) | Done |
| Sovereign boot pipeline (Cyrius, 56KB) | Done |
| LFS base recipes (421 base + 90 bazaar) | Done |
| Security (kavach 3.0.0, sigil 2.1.2, libro 1.0.3) | Done |
| 23 consumer apps with MCP integration | Done |
| **Self-hosting (AGNOS builds AGNOS)** | **Primary beta blocker** |
| Third-party security audit | Not started |

**Beta target: Q4 2026** | **v1.0 target: Q2 2027**

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
- **sigil 2.1.2** — Ed25519 trust verification, revocation
- **libro 1.0.3** — Cryptographic audit chain, hash-linked event log
- **AGNOS kernel** — 3 hardening passes, 14 buffer overflows found and fixed

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Documentation

| Document | Description |
|----------|-------------|
| [roadmap.md](docs/development/roadmap.md) | Development roadmap, KPIs |
| [architecture.md](docs/architecture.md) | System architecture |
| [shared-crates.md](docs/development/applications/shared-crates.md) | 78-crate registry |
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
