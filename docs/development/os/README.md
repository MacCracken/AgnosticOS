# OS Subsystems — Categorization Map

> **Last Updated**: 2026-05-06 (Version columns removed — defer to live registries)
>
> Every OS-level subsystem in AGNOS. Each is a standalone repo at `github.com/MacCracken/{name}` and locally at `/home/macro/Repos/{name}/`. The repo's own `CLAUDE.md` is the authoritative source for each subsystem's behavior; live version + cycle state lives in [`docs/development/state.md`](../state.md); the full versioned registry lives in [`shared-crates.md`](../planning/shared-crates.md).
>
> This file is the **categorization map** — what subsystems exist and what role each plays. Versions were previously inlined here and drifted; per the lib-doc precedent (2026-05-06 audit), version columns are stripped to remove drift surface.

---

## Kernel & Boot

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **agnos** | [MacCracken/agnos](https://github.com/MacCracken/agnos) | Native | AGNOS kernel (40+ subsystems, sovereign syscall surface; iron-validated 2026-05-15) |
| **cyrius** | [MacCracken/cyrius](https://github.com/MacCracken/cyrius) | Native | Sovereign compiler + stdlib + toolchain |
| **kybernet** | [MacCracken/kybernet](https://github.com/MacCracken/kybernet) | Cyrius | PID 1 (140 tests, 46 benchmarks) |
| **argonaut** | [MacCracken/argonaut](https://github.com/MacCracken/argonaut) | Cyrius | Init system, service management |

## Agent & Intelligence

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **daimon** | [MacCracken/daimon](https://github.com/MacCracken/daimon) | Cyrius | Agent orchestrator, ~144 MCP tools |
| **hoosh** | [MacCracken/hoosh](https://github.com/MacCracken/hoosh) | Cyrius | LLM gateway, 15 providers |
| **agnoshi** | [MacCracken/agnoshi](https://github.com/MacCracken/agnoshi) | Cyrius | AI shell |

## MCP & Messaging

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **bote** | [MacCracken/bote](https://github.com/MacCracken/bote) | Cyrius | MCP core (~5µs/message, streamable HTTP) |
| **t-ron** | [MacCracken/t-ron](https://github.com/MacCracken/t-ron) | Cyrius | MCP security |

## Trust & Security

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **sigil** | [MacCracken/sigil](https://github.com/MacCracken/sigil) | Cyrius | Crypto boundary (Ed25519, trust) |
| **kavach** | [MacCracken/kavach](https://github.com/MacCracken/kavach) | Cyrius | Sandbox (9 CWE fixes, 500× faster lifecycle) |
| **libro** | [MacCracken/libro](https://github.com/MacCracken/libro) | Cyrius | Cryptographic audit chain |
| **phylax** | [MacCracken/phylax](https://github.com/MacCracken/phylax) | Cyrius | Threat detection (was Rust 0.22.3; ported to Cyrius v1.0.0 in 2026-04) |
| **shakti** | [MacCracken/shakti](https://github.com/MacCracken/shakti) | Cyrius | Privilege escalation |
| **aegis** | [MacCracken/aegis](https://github.com/MacCracken/aegis) | Pending | Security daemon (scaffold) |

## Kernel Interface & Types

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **agnodrm** | [MacCracken/agnodrm](https://github.com/MacCracken/agnodrm) | Cyrius | Device/DRM model — udev + DRM/KMS (was **agnosys**; decomposed 2026-06-19 → trust→sigil, sec/mac/audit→kavach, pam→aegis, logging→sakshi, syscalls→cyrius) |
| **agnostik** | [MacCracken/agnostik](https://github.com/MacCracken/agnostik) | Cyrius | Shared types, domain primitives |

## Package Management

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **ark** | [MacCracken/ark](https://github.com/MacCracken/ark) | Cyrius | Package manager (4× smaller than Rust predecessor) |
| **nous** | [MacCracken/nous](https://github.com/MacCracken/nous) | Cyrius | Package resolver |
| **takumi** | [MacCracken/takumi](https://github.com/MacCracken/takumi) | In port | Build system (Cyrius port active; `rust-old/` authoritative until parity) |
| **zugot** | [MacCracken/zugot](https://github.com/MacCracken/zugot) | — | Recipe repository (421 base + 90 bazaar; not a versioned crate) |
| **mela** | [MacCracken/mela](https://github.com/MacCracken/mela) | Pending | App marketplace (scaffold) |

## Desktop & UI

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **aethersafha** | [MacCracken/aethersafha](https://github.com/MacCracken/aethersafha) | Pending | Wayland compositor (scaffold) |

## Media & Audio

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **shravan** | [MacCracken/shravan](https://github.com/MacCracken/shravan) | Cyrius | Audio codecs |
| **mabda** | [MacCracken/mabda](https://github.com/MacCracken/mabda) | Cyrius | GPU foundation (folded into Cyrius stdlib) |
| **ai-hwaccel** | [MacCracken/ai-hwaccel](https://github.com/MacCracken/ai-hwaccel) | Cyrius | GPU detection (518 tests) |

## Knowledge & Culture

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **avatara** | [MacCracken/avatara](https://github.com/MacCracken/avatara) | Cyrius | Divine archetype overlay (362 archetypes, 24 traditions) |
| **hadara** | [MacCracken/hadara](https://github.com/MacCracken/hadara) | Native | Culture modeling (50 cultures, Cyrius-native v1.0.0) |
| **bhava** | [MacCracken/bhava](https://github.com/MacCracken/bhava) | Pending | Emotion/sentiment modeling |
| **itihas** | [MacCracken/itihas](https://github.com/MacCracken/itihas) | Cyrius | History/versioning |

## Math & Compression

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **abaco** | [MacCracken/abaco](https://github.com/MacCracken/abaco) | Cyrius | Math/number theory (-52% lines, 12× faster Miller-Rabin) |
| **hisab** | [MacCracken/hisab](https://github.com/MacCracken/hisab) | Cyrius | Higher math |
| **sankoch** | [MacCracken/sankoch](https://github.com/MacCracken/sankoch) | Cyrius | Lossless compression (LZ4, DEFLATE, zlib, gzip) |

## Infrastructure

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **nein** | [MacCracken/nein](https://github.com/MacCracken/nein) | Cyrius | Programmatic nftables firewall |
| **stiva** | [MacCracken/stiva](https://github.com/MacCracken/stiva) | — | Container runtime |
| **yukti** | [MacCracken/yukti](https://github.com/MacCracken/yukti) | Cyrius | Device abstraction |
| **majra** | [MacCracken/majra](https://github.com/MacCracken/majra) | — | Queue/pub-sub |

## Game Engine

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **bsp** | [MacCracken/bsp](https://github.com/MacCracken/bsp) | Cyrius | BSP geometry library |
| **cyrius-doom** | [MacCracken/cyrius-doom](https://github.com/MacCracken/cyrius-doom) | Native | DOOM engine in Cyrius (2.59ms/frame) |

## Install & Edge

| Subsystem | Repo | Port | Role |
|-----------|------|------|------|
| **agnova** | [MacCracken/agnova](https://github.com/MacCracken/agnova) | Cyrius | OS installer (port from 3,656 Rust lines, base established) |
| **seema** | [MacCracken/seema](https://github.com/MacCracken/seema) | Pending | Edge fleet management (scaffold) |
| **samay** | [MacCracken/samay](https://github.com/MacCracken/samay) | Pending | Task scheduler (scaffold) |

---

**Port status summary** (2026-05-06): 30+ Cyrius-native or fully ported. ~5 still pending (bhava, aegis, aethersafha, takumi parity, mela). Live status: [`state.md`](../state.md).

Detailed dev docs for not-yet-v1.0 subsystems: [aethersafha](aethersafha.md), [agnova](agnova.md), [samay](samay.md), [seema](seema.md), [zugot](zugot.md). Graduated subsystems' docs now live in [docs/applications/libs/](../../applications/libs/) — **aegis**, **ark**, **mela**, **takumi** relocated there 2026-06-19 (joining nous/phylax, whose stale `os/` copies were removed 2026-06-19 — current docs live in `libs/`).

Stable subsystem overview: [`docs/architecture.md` § Named Subsystems](../../architecture.md#named-subsystems). Full crate registry: [`shared-crates.md`](../planning/shared-crates.md).
