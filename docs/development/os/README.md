# OS Subsystems — Full Registry

> **Last Updated**: 2026-04-14

Every OS-level subsystem in AGNOS. Each is a standalone repo at `github.com/MacCracken/{name}` and locally at `/home/macro/Repos/{name}/`. The repo's own CLAUDE.md is the authoritative source for each.

---

## Kernel & Boot

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **agnos** | 1.22.0 | [MacCracken/agnos](https://github.com/MacCracken/agnos) | Native | AGNOS kernel (260KB, 33 subsystems, 26 syscalls) |
| **cyrius** | 4.8.5-1 | [MacCracken/cyrius](https://github.com/MacCracken/cyrius) | Native | Sovereign compiler + stdlib (373KB, 42 modules) |
| **kybernet** | 1.0.1 | [MacCracken/kybernet](https://github.com/MacCracken/kybernet) | Cyrius | PID 1 (486KB, 140 tests) |
| **argonaut** | 1.2.0 | [MacCracken/argonaut](https://github.com/MacCracken/argonaut) | Cyrius | Init system, service management |

## Agent & Intelligence

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **daimon** | 1.1.1 | [MacCracken/daimon](https://github.com/MacCracken/daimon) | Cyrius | Agent orchestrator, 144 MCP tools |
| **hoosh** | 2.0.0 | [MacCracken/hoosh](https://github.com/MacCracken/hoosh) | Cyrius | LLM gateway (474KB, 15 providers) |
| **agnoshi** | 1.0.0 | [MacCracken/agnoshi](https://github.com/MacCracken/agnoshi) | Cyrius | AI shell |

## MCP & Messaging

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **bote** | 2.5.1 | [MacCracken/bote](https://github.com/MacCracken/bote) | Cyrius | MCP core (~5µs/message, streamable HTTP) |
| **t-ron** | 2.0.0 | [MacCracken/t-ron](https://github.com/MacCracken/t-ron) | Cyrius | MCP security |

## Trust & Security

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **sigil** | 2.1.2 | [MacCracken/sigil](https://github.com/MacCracken/sigil) | Cyrius | Crypto boundary (Ed25519, trust) |
| **kavach** | 3.0.0 | [MacCracken/kavach](https://github.com/MacCracken/kavach) | Cyrius | Sandbox (344KB, 9 CWE fixes) |
| **libro** | 1.0.3 | [MacCracken/libro](https://github.com/MacCracken/libro) | Cyrius | Cryptographic audit chain |
| **aegis** | 0.1.0 | [MacCracken/aegis](https://github.com/MacCracken/aegis) | Pending | Security daemon |
| **shakti** | 0.1.0 | [MacCracken/shakti](https://github.com/MacCracken/shakti) | Pending | Privilege escalation |
| **phylax** | 0.22.3 | [MacCracken/phylax](https://github.com/MacCracken/phylax) | Pending | Threat detection |

## Kernel Interface & Types

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **agnosys** | 0.97.2 | [MacCracken/agnosys](https://github.com/MacCracken/agnosys) | Cyrius | Syscall bindings, Landlock, seccomp |
| **agnostik** | 0.97.1 | [MacCracken/agnostik](https://github.com/MacCracken/agnostik) | Cyrius | Shared types, domain primitives |

## Package Management

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **ark** | 0.1.0 | [MacCracken/ark](https://github.com/MacCracken/ark) | Cyrius | Package manager |
| **nous** | 0.1.0 | [MacCracken/nous](https://github.com/MacCracken/nous) | Cyrius | Package resolver |
| **takumi** | 0.1.0 | [MacCracken/takumi](https://github.com/MacCracken/takumi) | Pending | Build system |
| **zugot** | — | [MacCracken/zugot](https://github.com/MacCracken/zugot) | — | Recipe repository (421 base + 90 bazaar) |
| **mela** | 0.1.0 | [MacCracken/mela](https://github.com/MacCracken/mela) | Pending | App marketplace |

## Desktop & UI

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **aethersafha** | 0.1.0 | [MacCracken/aethersafha](https://github.com/MacCracken/aethersafha) | Pending | Wayland compositor |

## Media & Audio

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **shravan** | 2.1.1 | [MacCracken/shravan](https://github.com/MacCracken/shravan) | Cyrius | Audio codecs |
| **mabda** | 2.1.2 | [MacCracken/mabda](https://github.com/MacCracken/mabda) | Cyrius | GPU foundation |
| **ai-hwaccel** | 2.0.0 | [MacCracken/ai-hwaccel](https://github.com/MacCracken/ai-hwaccel) | Cyrius | GPU detection (217KB, 518 tests) |

## Knowledge & Culture

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **avatara** | 2.3.0 | [MacCracken/avatara](https://github.com/MacCracken/avatara) | Cyrius | Divine archetype overlay (362 archetypes) |
| **hadara** | 1.0.0 | [MacCracken/hadara](https://github.com/MacCracken/hadara) | Native | Culture modeling (50 cultures) |
| **bhava** | 2.0.0 | [MacCracken/bhava](https://github.com/MacCracken/bhava) | Pending | Emotion/sentiment modeling |
| **itihas** | 2.2.0 | [MacCracken/itihas](https://github.com/MacCracken/itihas) | Cyrius | History/versioning |

## Math & Compression

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **abaco** | 2.0.0 | [MacCracken/abaco](https://github.com/MacCracken/abaco) | Cyrius | Math/number theory (-52% lines, 12× Miller-Rabin) |
| **hisab** | 1.4.0 | [MacCracken/hisab](https://github.com/MacCracken/hisab) | Pending | Higher math |
| **sankoch** | 0.1.0 | [MacCracken/sankoch](https://github.com/MacCracken/sankoch) | Native | Compression (LZ4, DEFLATE — scaffolded) |

## Infrastructure

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **nein** | 1.0.0 | [MacCracken/nein](https://github.com/MacCracken/nein) | Cyrius | Programmatic nftables firewall |
| **stiva** | 2.0.0 | [MacCracken/stiva](https://github.com/MacCracken/stiva) | — | Container runtime |
| **yukti** | 1.2.0 | [MacCracken/yukti](https://github.com/MacCracken/yukti) | Cyrius | Device abstraction |
| **majra** | 2.2.0 | [MacCracken/majra](https://github.com/MacCracken/majra) | — | Queue/pub-sub |

## Game Engine

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **bsp** | 1.0.1 | [MacCracken/bsp](https://github.com/MacCracken/bsp) | Cyrius | BSP geometry library |
| **cyrius-doom** | 0.24.5 | [MacCracken/cyrius-doom](https://github.com/MacCracken/cyrius-doom) | Native | DOOM engine (2.59ms/frame) |

## Install & Edge

| Subsystem | Version | Repo | Port | Role |
|-----------|---------|------|------|------|
| **agnova** | 0.1.0 | [MacCracken/agnova](https://github.com/MacCracken/agnova) | Pending | OS installer |
| **seema** | 0.1.0 | [MacCracken/seema](https://github.com/MacCracken/seema) | Pending | Edge fleet management |
| **samay** | 0.1.0 | [MacCracken/samay](https://github.com/MacCracken/samay) | Pending | Task scheduler |

---

**Port status summary:** 22+ Cyrius-native, 2 Cyrius-native from scratch (hadara, sankoch), ~10 pending port.

Detailed dev docs for pending subsystems: [aegis](aegis.md), [aethersafha](aethersafha.md), [agnova](agnova.md), [ark](ark.md), [mela](mela.md), [nous](nous.md), [phylax](phylax.md), [samay](samay.md), [seema](seema.md), [takumi](takumi.md).

Stable crate profiles: [docs/os/](../../os/README.md)
Shared libraries: [shared-crates.md](../applications/shared-crates.md)
