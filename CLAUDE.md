# AGNOS — Claude Code Instructions

## Project Identity

**AGNOS** — AI-Native General Operating System

- **Type**: Genesis repository — meta, build wrapper, documentation
- **License**: GPL-3.0-only
- **Version**: SemVer (`MAJOR.MINOR.PATCH`) — currently **0.1.0** (clean + prep cycle, opened 2026-05-21 on the `monolith-extraction` branch on the way to merge into `main`). Scheme switched from CalVer (`YYYY.M.D`) to SemVer at the 0.1.0 cut because daily-update cadence doesn't fit a date-stamped scheme — CalVer worked when cuts were spaced out; with continuous-update cadence the date stamp would need patch suffixes constantly. **CalVer may return later** once cadence normalizes around named ship milestones (ISO release, beta cuts, GA). Per [`feedback_no_unprompted_version_bumps`](https://github.com/MacCracken/agnosticos/blob/main/.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_no_unprompted_version_bumps.md): bump on cycle OPEN, user tags on cycle CLOSE.
- **Version file**: `VERSION` at repo root (single source of truth)
- **Language**: Cyrius (sovereign systems language, 29KB seed, zero external deps)
- **Status**: Pre-Beta — kernel and boot pipeline active, ISO assembly in progress; closed beta target early June 2026, public beta Q4 2026 (see `docs/development/roadmap.md`); current versions/sizes in `docs/development/state.md`

## Role

This repo is the **genesis layer** — meta, narrative, and the infrastructure to build AGNOS from nothing. Once the system boots and ark takes over, this repo's job is done.

**Owns:**
- **scripts/** — Sovereign boot pipeline in **Cyrius** (build, boot, validate, ISO assembly)
- **kernel/** — Linux kernel configs (for host bootstrap; AGNOS kernel lives in `agnos` repo)
- **docs/** — Architecture, roadmap, articles, philosophy, specs, security
- **.github/workflows/** — CI/CD that validates the whole system
- **docker/** — Dockerfiles for dev/edge/installer

**Does NOT own (extracted):**
- **AGNOS kernel** → `agnos` repo (40+ subsystems incl. NVMe / AHCI / USB-MS / VirtIO-modern / GPT / RAM-disk; Cyrius-native — current version/size in `state.md`)
- **Cyrius compiler** → `cyrius` repo (self-hosting from 29KB seed — current toolchain in `state.md`)
- **Recipes** → `zugot` repo (421 base + 90 bazaar recipes)
- **Production code** → 130+ standalone repos under `/home/macro/Repos/{name}/`
- **Old userland/** — monolith fully dismantled 2026-04-01. No Cargo workspace remains.

## Standalone Repos (Cyrius-native)

> **Volatile state lives in [`docs/development/state.md`](docs/development/state.md)** — current versions, Cyrius pins, port status, active sweeps, carry-forward debt. Refresh that file, not this section.
>
> **Crate registries** (versions + roles): once a crate ships **v1.0 it leaves the planning registry** and lives under `docs/applications/` — v1.0+ **libraries** in [`docs/applications/libs/README.md`](docs/applications/libs/README.md), v1.0+ **binaries & tools** in [`docs/applications/binaries.md`](docs/applications/binaries.md). [`docs/development/planning/shared-crates.md`](docs/development/planning/shared-crates.md) tracks **pre-1.0 + planned + non-library projects** (games / ML reference binaries) only.

The role map below is for orientation. **Versions are intentionally omitted** — they drift fast; consult state.md or the registries.

| Subsystem | Role | Port Status |
|-----------|------|-------------|
| **agnos** | AGNOS kernel | **Native** |
| **cyrius** | Sovereign compiler + stdlib + toolchain | **Native** |
| **zugot** | Recipe repository (consumed by ark/nous/takumi) | — |
| **agnostik** | Shared types, domain primitives | **Ported** |
| **agnodrm** | Device / DRM model (udev enumeration + DRM/KMS device access; error+util support). Was **agnosys** (kernel-interface lib) — decomposed 2026-06-19: trust→sigil, security/mac/audit→kavach, pam→aegis, logging→sakshi, syscall layer→cyrius; udev/drm survive + the Linux-eccentric group (bootloader/update/netns/fuse/journald) parked post-v1 | **Ported** |
| **kybernet** | PID 1 init binary | **Ported** |
| **argonaut** | Init system library | **Ported** |
| **sigil** | Trust / crypto boundary | **Ported** |
| **libro** | Cryptographic audit chain | **Ported** |
| **hoosh** | LLM inference gateway | **Ported** |
| **avatara** | Divine archetype overlay | **Ported** |
| **ai-hwaccel** | GPU detection | **Ported** |
| **hadara** | Culture modeling | **Native** |
| **shravan** | Audio codecs | **Ported** |
| **mabda** | GPU foundation library | **Ported** |
| **daimon** | Agent orchestrator, MCP tools | **Ported** |
| **agnoshi** | AI shell | **Ported** |
| **aethersafha** | Wayland compositor | Pending |
| **ark** | Package manager | **Ported** |
| **nous** | Package resolver | **Ported** |
| **takumi** | Build system | **Ported** |
| **aegis** | Security daemon | **Ported** |
| **shakti** | Privilege escalation | **Ported** |
| **kavach** | Sandbox execution | **Ported** |
| **bote** | MCP core + host registry | **Ported** |
| **t-ron** | MCP security | **Ported** |
| **phylax** | Threat detection | **Ported** |
| **abaco** | Math / number theory library | **Ported** |
| **itihas** | History / versioning | **Ported** |
| **bsp** | BSP geometry library | **Ported** |
| **cyrius-doom** | DOOM engine in Cyrius | **Native** |
| **attn11** | GPT-style transformer (**trained**, not just inference) in Cyrius — hand-written forward + backprop + Adam on raw `f64` arrays (no BLAS / libc / autodiff). The ecosystem's reference that gradient-based learning is expressible in the sovereign "everything-is-i64" language; gradients gated by finite-difference checks. Binary. | **Native** |
| **tentib** | Integer-native / ternary (1.58-bit) ML reference in Cyrius (`bitnet` reversed) — attn11's everything-is-i64 thesis applied to the *weights*: BitNet b1.58 ternary {−1,0,+1} weights → a matmul-free (add/sub/skip) weight·activation path + int8 activations + the straight-through estimator (the canonical finite-difference-gate case study). Sibling reference to attn11 (Transformer) + tarka (RL/reasoning) on the same f64 substrate (rosnet/tyche/akshara). Scaffolded 2026-06-23; M0 = ternary quantizer + matmul-free dot. Binary. | **Native** |
| **prajna** | प्रज्ञा — meta-learning / learn-to-learn ML reference in Cyrius. The family's first **second-order / nested meta-gradient** (∂/∂θ *through* an inner SGD step), the one genuinely-new differentiable primitive the recursive-self-improvement exploration surfaced (RSI itself is a *tarka recipe-lane*, not a sibling — see [[project_rsi_is_a_lane_not_a_sibling]]). M1–M5 complete at 0.5.0 (2026-06-24): 2nd-order MAML (scalar→linear→nonlinear **Pearlmutter R-operator**), learned optimizers (feedforward + recurrent **BPTT**, beat SGD), text few-shot on the shared `akshara` tokenizer, continual-learning durability (experience replay; EWC honest-negative at toy scale). All hand-derived backprop FD-gated. 4th ML sibling to attn11 (Transformer) / tarka (RL) / tentib (ternary) on the same f64 substrate (rosnet/tyche/akshara). Hardened across the 0.6.x arc (NaN-safe gates, numerical robustness, security audit, refactor); **shipped 1.0.0 stable 2026-06-24** (API frozen — `docs/api.md` + ADR 0001; `SECURITY.md`, benchmarks, consumer example). Post-1.0 = maintenance only. Binary. | **Native** |
| **agora** | Telnet-served BBS (Greek ἀγορά — *civic marketplace / public assembly*) in Cyrius — server-stage app. Sigil-backed Ed25519 auth, multi-board threaded boards, fork-per-connection concurrency, full telnet RFC conformance; three door games (PA / Smuggler / The Handler) with `flock`'d Persistent-Universe shared-world multiplayer. Iron-validated on archaemenid. Anchors the BBS/MUD aesthetic cluster (1.3.0 Eliza+chat, 1.4.0 `descent` door → cyrius-yeomans-descent planned). | **Native** |
| **sankoch** | Lossless compression (LZ4, DEFLATE, zlib, gzip) | **Ported** |
| **bhava** | Emotion / sentiment modeling | Pending |
| **hisab** | Higher math | **Ported** |
| **agnova** | OS installer | **Ported** |
| **mela** | Agent marketplace | **Ported** |
| **seema** | Edge fleet management | Pending |
| **samay** | Task scheduler | Pending |
| **gnoboot** | Sovereign UEFI bootloader (PE32+ EFI Application, replaces GRUB) | **Native** |
| **commandress** | Structured shell prompt renderer (binary `cmdrs`, starship-equivalent) | **Native** |
| **kriya** | Coreutils-equivalent multi-tool (`cp`/`mv`/`rm`/`mkdir`/`echo`/`wc`/`find`/`grep`/…, BusyBox-style dispatcher) | **Native** |
| **mihi** | System-info probe library (CPU / RAM / GPU / kernel / uptime / distro / hostname) — substrate for iam, chakshu | **Native** |
| **iam** | fastfetch-equivalent system-info display (consumes mihi; inverse of `whoami`) | **Native** |
| **chakshu** | AI-augmented system monitor (`shu` binary; htop/btop-equivalent with LLM explanation hooks) | **Native** |
| **darshana** | TTY/color primitives library (termios + ANSI + cursor positioning) — substrate for cyim, chakshu, bannermanor | **Native** |
| **bannermanor** | figlet-equivalent ASCII-art banner generator (binary `bnrmr`; English-wordplay naming lane) | **Native** |
| **hapi** | GNU `stow`-equivalent dotfile / symlink farm manager (CYML manifest per package, capability-bounded execution) | **Native** |
| **kii** | `chafa` / `jp2a` / `viu`-equivalent — image → ANSI/ASCII-art converter for terminal display. **Four-layered name** across three language families: (1) Hawaiian *image / picture / likeness* — what the tool produces; (2) East Asian *ki* (気) / *chi* (氣) — life-force / vital energy: kii is the *ki of the terminal*, the animating force that brings the screen to life via images; (3) phonetic back-half of **a-scii** — what the tool emits; (4) functional convergence — produces images via ASCII to animate the terminal, all three language angles describe the same operation. Substrate for BBS MOTD banners, MUD room illustrations, `iam` splashes. Polynesian Hawaiian micro-cluster with `hapi`, `anuenue`. | **Native** |
| **kashi** | काशि — AGNOS console-font subsystem. Freestanding VGA 8x16 + CGA 8x8 + VGA 9x16 glyph cores (full CP437, `kashi_font_init` + `kashi_glyph_ptr`/`kashi_glyph_row` accessors; zero-stdlib so a freestanding kernel can include it directly via `[deps.kashi]`) + a stdlib-using library face (PSF1/PSF2 import, runtime registry). Extracted from agnos's inline `fb_console.cyr` tables 2026-05-20; vendored back into agnos at 1.37.5. Sanskrit/Hindi system-lib lane. Developed by a parallel agent per [[project_kashi_parallel_split]] — agnos sessions only touch the extraction/consumption boundary, never kashi internals. **v1.0.0 API freeze** 2026-05-28. | **Native** |

> **Live versions, sizes, test counts, and per-repo cycle state**: see [`docs/development/state.md`](docs/development/state.md) and [`docs/development/planning/shared-crates.md`](docs/development/planning/shared-crates.md). This table is intentionally version-free — embedded counts drift, and pointer-to-registry is the cleaner pattern.

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
- **NEVER use raw `cat file | cycc`** — always `cyrius build`
- `cyrius build` auto-resolves deps from `scripts/cyrius.cyml` and auto-prepends includes
- Toolchain version pinned in `scripts/cyrius.cyml` via the `cyrius = "<version>"` field
- If stdout/println doesn't work, you're missing includes — use `cyrius build`, not raw cycc
- **Programs must call main() at top level** — Cyrius executes top-level code, not fn main() automatically. Call main from a **bare statement** (NOT `var r = main();`) and exit via **`SYS_EXIT`** (NOT a literal `60`). This form is correct on host AND agnos:
  ```cyrius
  fn main(): i64 { ... return 0; }
  fn _entry(): i64 { var r = main(); syscall(SYS_EXIT, r); return 0; }
  _entry();                 # BARE call — do NOT write `var r = main();`
  ```
  - **Why bare-call, not `var r = main();`** (agnos): a module-scope `var r = main()` runs `main` during the **gvar-init** phase — *before* cycc emits the init-rsp capture (`_agnos_capture_rsp`, placed after gvar-inits as of cyrius 6.1.14) — so `argc()`/`argv()` read **0/null** and arg-reading tools see no args (`bnrmr agnos` printed help instead of rendering). A bare top-level statement runs in `PARSE_PROG`, *after* the capture. Filed as a cyrius issue (`agnos/docs/development/issue/2026-06-08-cyrius-agnos-argv-init-rsp-capture.md`); the `var r = main()` form may become valid again if cyrius moves the capture ahead of the main-gvar-init.
  - **Why `SYS_EXIT`, not `60`** (agnos): agnos redefines the `Sys` enum to its own numbers — `exit` is syscall **0**, not Linux's 60. A literal `syscall(60, …)` is a **no-op** on agnos (it only terminates because cycc auto-emits `EEXIT` at end of top-level). `SYS_EXIT` resolves to 0 on agnos and 60 on Linux — correct on both.
- **`var X[N]` allocation unit differs by scope**: **module-global** `var X[N]` = N×u64 (8N bytes); **function-local** `var X[N]` = N bytes. See `agnos/kernel/core/ext2.cyr:28-44` for canonical inline-commented examples. When porting Linux/BSD drivers, a module-scope `u8 buf[4096]` becomes `var buf[512]` in Cyrius. Memory: [[cyrius-var-array-u64-units]].
- **Study working programs** before writing new code — see `cyrius/programs/*.cyr` (65+ examples)
- **Binary names**: `cycc` (self-hosting compiler, was `cc5`) + `cybs` (bootstrap compiler, was `cyrc`) — renamed at cyrius v6.0.0 cycle-open 2026-05-19. Names are now permanent — no `cycc6` at v7.0.0, etc. `~/.cyrius/bin/` ships symlinks `cc5 → cycc` + `cyrc → cybs` through the v6.0.x window (drop at v6.1.0). The bridge step in the bootstrap chain was retired at cyrius v5.11.66 — chain is `seed → cybs → cycc`.

**Build:**
```sh
cd scripts
cyrius build src/boot.cyr build/boot
./build/boot --help
./build/boot --test --kernel /path/to/agnos
```

**Deps are declared in `scripts/cyrius.cyml`** — do NOT manually include stdlib.
Source files only need project includes (`src/types.cyr` etc.).

**Current Cyrius release:** see `cyrius/VERSION` (verify at session start). **v6.0.x active — "what the language GAINS"** (RISC-V rv64, PIE, closures, Class-B FFI, bare-metal target). v6.0.0 opened 2026-05-19 with the cyrc → cybs and cc5 → cycc rename ceremony. v5.x closed: v5.11.x (stdlib annotation arc + consumer-issue closeout) at v5.11.69 on 2026-05-19; v5.10.x earlier with three completed arcs — typed-simd ABI 11 phases, REAL TYPE SYSTEM 5 phases, struct-byval ABI 3 phases. The standalone `bridge.cyr` step was retired at v5.11.66 (chain shortened to `seed → cybs → cycc`). Toolchain pinned in `scripts/cyrius.cyml` via the `cyrius = "<version>"` field — manifest is single source of truth (no separate `.cyrius-toolchain` file). Cycle status, pin-lag spectrum, and active sweeps live in [`docs/development/state.md`](docs/development/state.md).

## Documentation Structure

```
Root files (required):
  README.md, CHANGELOG.md, CLAUDE.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, LICENSE

docs/ (required):
  architecture.md — system architecture overview (module map, data flow, tech stack)
  architecture.md (Kernel Layers section) — kernel layer decomposition (was architecture/kernel-layers.md, inlined 2026-05-09)
  design-patterns.md — recurring cognitive patterns across AGNOS decisions (through-line layer; accretion doc, becomes GA retrospective spine)
  philosophy.md — ideological basis (sovereignty, Temple, Hermetic role)
  history.md, timeline.md — project history and dated milestones
  development/state.md — live ecosystem state (Cyrius cycle, pin-lag, active sweeps, carry-forward)
  development/roadmap.md — completed, backlog, future, v1.0 criteria
  development/planning/shared-crates.md — crate registry (full, incl. pre-1.0)
  applications/libs/README.md — v1.0+ stable library registry
  articles/ — thematic engineering articles (port sequencing, sovereign compiler, etc.)

docs/ (when earned):
  adr/ — architectural decision records
  guides/usage.md — patterns and examples

scripts/ (Cyrius project):
  cyrius.cyml — build manifest + deps (modern CYML format)
  src/boot.cyr — sovereign boot pipeline (Cyrius-native)
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
