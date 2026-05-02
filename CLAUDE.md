# AGNOS — Claude Code Instructions

## Project Identity

**AGNOS** — AI-Native General Operating System

- **Type**: Genesis repository — meta, build wrapper, documentation
- **License**: GPL-3.0-only
- **Version**: CalVer `2026.4.25` (YYYY.M.D, patches as `-N`)
- **Version file**: `VERSION` at repo root (single source of truth)
- **Language**: Cyrius (sovereign systems language, 29KB seed, zero external deps)
- **Status**: Pre-Beta — kernel 1.22.0 shipped (260KB, 33 subsystems), boot pipeline active, ISO assembly in progress

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
- **Cyrius compiler** → `cyrius` repo (v5.7.12, self-hosting from 29KB seed)
- **Recipes** → `zugot` repo (421 base + 90 bazaar recipes)
- **Production code** → 130+ standalone repos under `/home/macro/Repos/{name}/`
- **Old userland/** — monolith fully dismantled 2026-04-01. No Cargo workspace remains.

## Standalone Repos (Cyrius-native)

> **Volatile state lives in [`docs/development/state.md`](docs/development/state.md)** — current versions, Cyrius pins, port status, active sweeps, carry-forward debt. Refresh that file, not this section.
>
> **Crate registries** (versions + roles): [`docs/development/applications/shared-crates.md`](docs/development/applications/shared-crates.md) is the full registry (incl. pre-1.0); [`docs/applications/libs/README.md`](docs/applications/libs/README.md) is the v1.0+ stable subset.

The role map below is for orientation. **Versions are intentionally omitted** — they drift fast; consult state.md or the registries.

| Subsystem | Role | Port Status |
|-----------|------|-------------|
| **agnos** | AGNOS kernel (33 subsystems, 26 syscalls) | **Native** |
| **cyrius** | Sovereign compiler + stdlib + toolchain | **Native** |
| **zugot** | Recipe repository (all takumi build recipes) | — |
| **agnostik** | Shared types, domain primitives | **Ported** |
| **agnosys** | Kernel interface (Landlock, seccomp, syscalls) | **Ported** |
| **kybernet** | PID 1 binary (486KB, 140 tests, 46 benchmarks) | **Ported** |
| **argonaut** | Init system library | **Ported** |
| **sigil** | Trust/crypto boundary | **Ported** |
| **libro** | Cryptographic audit chain | **Ported** |
| **hoosh** | LLM inference gateway (15 providers) | **Ported** |
| **avatara** | Divine archetype overlay (2,761× faster cached) | **Ported** |
| **ai-hwaccel** | GPU detection (518 tests) | **Ported** |
| **hadara** | Culture modeling (50 cultures, Cyrius-native) | **Native** |
| **shravan** | Audio codecs | **Ported** |
| **mabda** | GPU foundation (folded into Cyrius stdlib) | **Ported** |
| **daimon** | Agent orchestrator, 144 MCP tools | **Ported** |
| **agnoshi** | AI shell | **Ported** |
| **aethersafha** | Wayland compositor | Pending |
| **ark** | Package manager (4× smaller than Rust) | **Ported** |
| **nous** | Package resolver | **Ported** |
| **takumi** | Build system | Pending |
| **aegis** | Security daemon | Pending |
| **shakti** | Privilege escalation | **Ported** |
| **kavach** | Sandbox execution | **Ported** |
| **bote** | MCP core + host registry | **Ported** |
| **t-ron** | MCP security | **Ported** |
| **phylax** | Threat detection | **Ported** |
| **abaco** | Math/number theory library | **Ported** |
| **itihas** | History/versioning | **Ported** |
| **bsp** | BSP geometry library (waiting on Cyrius v5.8.x optimization cycle) | **Ported** |
| **cyrius-doom** | DOOM engine in Cyrius (waiting on Cyrius v5.8.x optimization cycle) | **Native** |
| **sankoch** | Lossless compression (LZ4, DEFLATE, zlib, gzip) | **Ported** |
| **bhava** | Emotion/sentiment modeling | Pending port |
| **hisab** | Accounting/calculation | **Ported** |
| **agnova** | OS installer (Cyrius port from 3,656 Rust lines, base established) | **Ported** |

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
- **NEVER use raw `cat file | cc5`** — always `cyrius build`
- `cyrius build` auto-resolves deps from `scripts/cyrius.cyml` and auto-prepends includes
- Toolchain version pinned in `scripts/cyrius.cyml` via the `cyrius = "<version>"` field
- If stdout/println doesn't work, you're missing includes — use `cyrius build`, not raw cc5
- **Programs must call main() at top level** — Cyrius executes top-level code, not fn main() automatically:
  ```cyrius
  fn main() { ... return 0; }
  var exit_code = main();
  syscall(60, exit_code);
  ```
- **Study working programs** before writing new code — see `cyrius/programs/*.cyr` (65+ examples)
- **Heads-up:** cc5 → `cyc` rename is queued for v6.0 (single one-and-done cleanup so the binary name decouples from the version). Until then, `cc5` is current.

**Build:**
```sh
cd scripts
cyrius build src/boot.cyr build/boot
./build/boot --help
./build/boot --test --kernel /path/to/agnos
```

**Deps are declared in `scripts/cyrius.cyml`** — do NOT manually include stdlib.
Source files only need project includes (`src/types.cyr` etc.).

**Current Cyrius release:** see `cyrius/VERSION` (verify at session start; **v5.8.x active — optimization, math, language fixes cycle**). Toolchain pinned in `scripts/cyrius.cyml` via the `cyrius = "<version>"` field — manifest is single source of truth (no separate `.cyrius-toolchain` file). Cycle status, pin-lag spectrum, and active sweeps live in [`docs/development/state.md`](docs/development/state.md).

## Documentation Structure

```
Root files (required):
  README.md, CHANGELOG.md, CLAUDE.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, LICENSE

docs/ (required):
  architecture.md — system architecture overview (module map, data flow, tech stack)
  architecture/kernel-layers.md — kernel layer decomposition
  design-patterns.md — recurring cognitive patterns across AGNOS decisions (through-line layer; accretion doc, becomes GA retrospective spine)
  philosophy.md — ideological basis (sovereignty, Temple, Hermetic role)
  history.md, timeline.md — project history and dated milestones
  development/state.md — live ecosystem state (Cyrius cycle, pin-lag, active sweeps, carry-forward)
  development/roadmap.md — completed, backlog, future, v1.0 criteria
  development/applications/shared-crates.md — crate registry (full, incl. pre-1.0)
  applications/libs/README.md — v1.0+ stable library registry
  articles/ — thematic engineering articles (port sequencing, sovereign compiler, etc.)

docs/ (when earned):
  adr/ — architectural decision records
  guides/usage.md — patterns and examples

scripts/ (Cyrius project):
  cyrius.cyml — build manifest + deps (modern CYML format)
  src/boot.cyr — sovereign boot pipeline (48KB compiled)
  tests/ — test suites
  archive-pre-cyrius/ — 34 archived bash scripts (Rust era, reference only)
```

**Doc-layer map** (if you're reasoning about where something belongs):
- `philosophy.md` = why AGNOS exists at all (ideology)
- `design-patterns.md` = why the decisions fit together as a system (through-lines)
- ADRs = why *this specific* choice (per-decision)
- `history.md` / `timeline.md` = what happened when (events)
- `development/state.md` = what's true *right now* (volatile state — versions, pins, sweeps, debt)
- `articles/` = specific thematic arguments (deep-dives on particular patterns)
- `CHANGELOG.md` per repo = what changed in v-N
- Memory files = cross-session agent behavioral directives

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/). Performance claims MUST include benchmark numbers. Breaking changes get a **Breaking** section with migration guide.
