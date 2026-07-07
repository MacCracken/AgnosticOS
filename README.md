# AGNOS — AI-Native General Operating System

> **A**rtificial **G**eneral **N**etwork **O**perating **S**ystem

[![License](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)
[![Kernel](https://img.shields.io/badge/kernel-AGNOS%201.51.2-orange)](https://github.com/MacCracken/agnos)
[![Language](https://img.shields.io/badge/Cyrius-6.3.21-red)](https://github.com/MacCracken/cyrius)
![Status](https://img.shields.io/badge/status-pre--beta-yellow)

**AGNOS** is a sovereign operating system written in **Cyrius** — a systems language with a 29KB seed, zero external dependencies, and a self-hosting compiler. The kernel boots to a typeable shell on real AMD hardware (Boot-to-Shell MVP, 2026-05-15). Since then, validated **on real AMD Zen** unless noted:

- **Storage** — NVMe / SATA / USB-MS stack, iron-validated.
- **Networking** — full TCP/IP + DHCP + DNS + NTP + ICMP over an r8169 NIC, iron-validated.
- **Filesystems** — read+write ext2/ext4 (incl. **ext4 extent allocation** + **JBD2 crash-safe journaling**), FAT12/16/32, exFAT; FS-crash-safety confirmed on hardware.
- **exec-from-disk** — static programs load + run in ring 3 off the agnos-fs, iron-validated.
- **Userland shell** — the interactive shell is the userland **agnsh** binary, exec'd from disk in ring 3 (the in-kernel shell is now a recovery-only REPL, locking the kernel↔userland boundary); shell-separation arc **iron-complete** (2026-06-06, past a real DHCP lease). First AGNOS-tic tools (`bnrmr`/`cmdrs`/`klug`/`anuenue`) live on `/bin`, run via `run /bin/<tool>`.
- **Graphics + DOOM** — a framebuffer / timing / input path (`fbinfo`/`blit`/`uptime_ms`/`sleep_ms`/`kbscan`) culminating in **DOOM (cyrius-doom) exec'd from disk in ring 3** — the first real userland app, **iron-complete** on real hardware (plays in-game, keyboard-driven).
- **Preemptive scheduling** — the 1.44.x arc moved the kernel from cooperative single-core round-robin to **preemptive ring-3 time-slicing**: concurrent ring-3 processes (each on its own CR3, both syscalling), and a ring-3 **parent** that `spawn`s a child ELF + poll-`waitpid`s it entirely from ring 3 (**QEMU-validated** via `scripts/ring3-smoke.sh`; iron-validated at 1.46.x on real Zen).
- **Console fonts** — vendored from **kashi 1.0.0** (parallel-agent-developed sibling repo).

30+ subsystems ported from Rust to Cyrius. No Linux dependency at runtime — the kernel exposes a **small sovereign syscall surface with no socket/splice/AF_ALG layer** (structurally immune to that CVE class). Live binary sizes, per-repo versions, syscall count, and cycle state track in the ecosystem state ledger.

> *AGI doesn't run on infrastructure built for web apps. It runs on infrastructure built for AGI.*
>
> *A system that can't prove its own integrity can't be trusted with autonomous action.*

---

## Architecture

```
+------------------------------------------------------------------+
|  Desktop                |  Agent Runtime          |  Kernel       |
|  +--------------------+ |  +--------------------+ |  +----------+ |
|  | aethersafha        | |  | daimon             | |  | AGNOS    | |
|  | Wayland compositor | |  | 144+ MCP tools     | |  | kernel   | |
|  |                    | |  | Agent orchestrator | |  | 40+ sub- | |
|  +--------------------+ |  +--------------------+ |  | systems  | |
|  | agnoshi            | |  | hoosh              | |  | sovereign| |
|  | AI shell           | |  | LLM gateway        | |  | syscalls | |
|  |                    | |  | 15 providers       | |  | Cyrius-  | |
|  +--------------------+ |  +--------------------+ |  | native   | |
|  | 23+ consumer apps  | |  | aegis + sigil      | |  | iron-    | |
|  | marketplace (mela) | |  | kavach (sandbox)   | |  | validated| |
|  +--------------------+ |  +--------------------+ |  +----------+ |
+------------------------------------------------------------------+
```

## The Stack

| Layer | Component | Notes |
|-------|-----------|-------|
| **Kernel** | AGNOS | Cyrius-native, 40+ subsystems, iron-validated NUC AMD 2026-05-15 |
| **Compiler** | Cyrius | self-hosting from 29KB seed |
| **PID 1** | kybernet | service supervision, signal/event-loop |
| **Init** | argonaut | 3 boot modes (Server / Desktop / Minimal) |
| **Sandbox** | kavach | Landlock + seccomp-bpf |
| **Crypto** | sigil | Ed25519, trust verification |
| **Audit** | libro | Hash-chained event log |
| **MCP** | bote | message pipeline + host registry |
| **LLM** | hoosh | OpenAI-compatible proxy, 15 providers, hardware accel |
| **Agents** | daimon | agent orchestrator, MCP tool host |
| **Shell** | agnoshi | natural-language terminal |
| **Packages** | ark + nous | package manager + resolver |
| **Recipes** | zugot | 421 base + 90 bazaar |

> v1.0+ stable libraries: [`docs/applications/libs/README.md`](docs/applications/libs/README.md); v1.0+ binaries & tools: [`docs/applications/binaries.md`](docs/applications/binaries.md).

## Port Receipts (Rust to Cyrius)

| Subsystem | Before | After | Ratio |
|-----------|--------|-------|-------|
| agnodrm (was agnosys) | 6.9MB | 117KB | 59x smaller |
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
| Sovereign kernel (40+ subsystems, iron-validated NUC AMD 2026-05-15) | Done |
| Kernel perf + hardening (heap-zero perf, page-map/RBP/reap hardening) + sysinfo/klog syscalls (`uname`/`sysinfo`/`klog`) | **QEMU-validated, iron-pending** (1.42.x) |
| Graphics path + first real userland app — DOOM (cyrius-doom) exec'd from disk in ring 3 | **Iron-complete** (plays in-game on real Zen) — 1.43.x |
| Preemptive ring-3 multi-threading (per-proc CR3, time-slicing, concurrent exec + clean exit, real ELF spawn) | **iron-validated on real Zen** (1.44.x arc; SMP/preempt iron-confirmed 1.46.x) |
| Cyrius compiler (self-hosting, 42+ stdlib modules) | Done |
| 30+ subsystem ports (Rust to Cyrius) | Done |
| Sovereign boot pipeline (Cyrius) — sovereign UEFI handoff via gnoboot | Done |
| LFS base recipes (421 base + 90 bazaar) | Done |
| Security stack (kavach, sigil, libro, aegis at v1.0+) | Done |
| 19+ consumer apps with MCP integration | Done |
| **Self-hosting (AGNOS builds AGNOS)** | **Public-beta scope — not a closed-beta gate.** Kernel already builds + boots against current Cyrius; the bare-metal toolchain target lands in Cyrius **v6.0.x** but does not gate the MVP (the earlier "closed-beta blocker" framing was pre-monolith-extraction residue, corrected 2026-05-12) |
| Closed-beta tester cohort (5–15 trusted testers) | Pending closed-beta cut |
| Third-party security audit | Public-beta gate |
| Community testing program (formal enrollment) | Public-beta gate |

**Closed-beta target: late August 2026** (preceded by a ~July founder solo-dogfood month) | **Public-beta target: deferred post-summer** | **GA target: late fall / early winter 2026**

See [CHANGELOG.md](CHANGELOG.md) for full details.

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

- **kavach** — Landlock + seccomp-bpf sandboxing
- **sigil** — Ed25519 trust verification, revocation
- **libro** — Cryptographic audit chain, hash-linked event log
- **aegis** — System security daemon (threat detection, quarantine, scanning)
- **AGNOS kernel** — Security hardening 13/13 closed (S1-S13 incl. KASLR data-only, KPTI-light, IBRS Spectre v2 mitigations, VT-d IOMMU, stack canaries); structurally immune to CVE-2026-31431 (no socket/splice/AF_ALG surface in the sovereign syscall table)

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Documentation

| Document | Description |
|----------|-------------|
| [architecture.md](docs/architecture.md) | System architecture |
| [libs/README.md](docs/applications/libs/README.md) | v1.0+ stable library registry |
| [binaries.md](docs/applications/binaries.md) | v1.0+ binaries & tools registry |
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
