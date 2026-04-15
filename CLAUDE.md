# AGNOS — Claude Code Instructions

## Project Identity

**AGNOS** — AI-Native General Operating System

- **Type**: Genesis repository — meta, build wrapper, documentation
- **License**: GPL-3.0-only
- **Version**: CalVer `2026.4.14` (YYYY.M.D, patches as `-N`)
- **Version file**: `VERSION` at repo root (single source of truth)
- **Language**: Cyrius (sovereign systems language, 29KB seed, zero external deps)
- **Status**: Pre-Beta — kernel 1.22.0 shipped (260KB, 33 subsystems), boot pipeline active

## Role

This repo is the **genesis layer** — meta, narrative, and the infrastructure to build AGNOS from nothing. Once the system boots and ark takes over, this repo's job is done.

**Owns:**
- **scripts/** — Sovereign boot pipeline in **Cyrius** (build, boot, validate, ISO assembly)
- **kernel/** — Linux kernel configs (for host bootstrap; AGNOS kernel lives in `agnos` repo)
- **docs/** — Architecture, roadmap, articles, philosophy, specs, security
- **.github/workflows/** — CI/CD that validates the whole system
- **docker/** — Dockerfiles for dev/edge/installer

**Does NOT own (extracted):**
- **AGNOS kernel** → `agnos` repo (v1.22.0, 260KB, Cyrius-native)
- **Cyrius compiler** → `cyrius` repo (v4.8.5-1, 373KB, self-hosting from 29KB seed)
- **Recipes** → `zugot` repo (421 base + 90 bazaar recipes)
- **Production code** → 130+ standalone repos under `/home/macro/Repos/{name}/`
- **Old userland/** — monolith fully dismantled 2026-04-01. No Cargo workspace remains.

## Standalone Repos (Cyrius-native)

| Subsystem | Version | Role | Port Status |
|-----------|---------|------|-------------|
| **agnos** | 1.22.0 | AGNOS kernel (260KB, 33 subsystems, 26 syscalls) | **Native** |
| **cyrius** | 4.8.5-1 | Sovereign compiler + stdlib + toolchain | **Native** |
| **zugot** | — | Recipe repository (all takumi build recipes) | — |
| **agnostik** | 0.97.1 | Shared types, domain primitives | **Ported** |
| **agnosys** | 0.97.2 | Kernel interface (Landlock, seccomp, syscalls) | **Ported** |
| **kybernet** | 1.0.1 | PID 1 binary (486KB, 140 tests, 46 benchmarks) | **Ported** |
| **argonaut** | 1.2.0 | Init system library | **Ported** |
| **sigil** | 2.1.2 | Trust/crypto boundary | **Ported** |
| **libro** | 1.0.3 | Cryptographic audit chain | **Ported** |
| **hoosh** | 2.0.0 | LLM inference gateway (474KB, 15 providers) | **Ported** |
| **avatara** | 2.3.0 | Divine archetype overlay (2,761× faster cached) | **Ported** |
| **ai-hwaccel** | 2.0.0 | GPU detection (217KB, 518 tests) | **Ported** |
| **hadara** | 1.0.0 | Culture modeling (50 cultures, Cyrius-native) | **Native** |
| **shravan** | 2.1.1 | Audio codecs | **Ported** |
| **mabda** | 2.1.2 | GPU foundation (folded into Cyrius stdlib) | **Ported** |
| **daimon** | 1.1.1 | Agent orchestrator, 144 MCP tools | **Ported** |
| **agnoshi** | 1.0.0 | AI shell | **Ported** |
| **aethersafha** | 0.1.0 | Wayland compositor | Pending |
| **ark** | 0.1.0 | Package manager | **Ported** |
| **nous** | 0.1.0 | Package resolver | **Ported** |
| **takumi** | 0.1.0 | Build system | Pending |
| **aegis** | 0.1.0 | Security daemon | Pending |
| **shakti** | 0.1.0 | Privilege escalation | Pending |
| **kavach** | 3.0.0 | Sandbox execution | **Ported** |
| **bote** | 2.5.1 | MCP core + host registry | **Ported** |
| **t-ron** | 2.0.0 | MCP security | **Ported** |
| **phylax** | 0.22.3 | Threat detection | Pending |
| **abaco** | 2.0.0 | Math/number theory library | **Ported** |
| **itihas** | 2.2.0 | History/versioning | **Ported** |
| **bsp** | 1.0.1 | BSP geometry library | **Ported** |
| **cyrius-doom** | 0.24.5 | DOOM engine in Cyrius | **Native** |
| **bhava** | 2.0.0 | Emotion/sentiment modeling | Pending |
| **hisab** | 1.4.0 | Accounting/calculation | Pending |

## Development Process

### Work Loop (continuous)

1. Work phase — scripts (Cyrius), kernel configs, doc improvements, CI/CD
2. If touching scripts/: `cd scripts && cyrius build src/boot.cyr build/boot`
3. Documentation — update CHANGELOG, roadmap, docs
4. Version check — VERSION and docs all in sync
5. Return to step 1

### Task Sizing

- **Low/Medium effort**: Batch freely — multiple items per work loop cycle
- **Large effort**: Small bites only — break into sub-tasks, verify each before moving to the next
- **If unsure**: Treat it as large

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not add unnecessary dependencies

## Cyrius (scripts/)

The `scripts/` directory is a **Cyrius project** — the sovereign boot pipeline.
Cyrius is the AGNOS systems language. It has its own build tool and dep system.

**Rules:**
- **NEVER use raw `cat file | cc3`** — always `cyrius build`
- `cyrius build` auto-resolves deps from `scripts/cyrius.toml` and auto-prepends includes
- Toolchain version pinned in `scripts/.cyrius-toolchain`
- If stdout/println doesn't work, you're missing includes — use `cyrius build`, not raw cc3
- **Programs must call main() at top level** — Cyrius executes top-level code, not fn main() automatically:
  ```cyrius
  fn main() { ... return 0; }
  var exit_code = main();
  syscall(60, exit_code);
  ```
- **Study working programs** before writing new code — see `cyrius/programs/*.cyr` (46 examples)

**Build:**
```sh
cd scripts
cyrius build src/boot.cyr build/boot
./build/boot --help
./build/boot --test --kernel /path/to/agnos
```

**Deps are declared in `scripts/cyrius.toml`** — do NOT manually include stdlib.
Source files only need project includes (`src/types.cyr` etc.).

**Current toolchain:** 3.10.2 — see `.cyrius-toolchain`

## Documentation Structure

```
Root files (required):
  README.md, CHANGELOG.md, CLAUDE.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, LICENSE

docs/ (required):
  architecture/overview.md — module map, data flow, consumers
  development/roadmap.md — completed, backlog, future, v1.0 criteria
  development/applications/shared-crates.md — 78-crate registry

docs/ (when earned):
  adr/ — architectural decision records
  guides/usage.md — patterns and examples

scripts/ (Cyrius project):
  cyrius.toml — build manifest + deps
  src/boot.cyr — sovereign boot pipeline (48KB compiled)
  tests/ — test suites
  archive-pre-cyrius/ — 34 archived bash scripts (Rust era, reference only)
```

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/). Performance claims MUST include benchmark numbers. Breaking changes get a **Breaking** section with migration guide.
