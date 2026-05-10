# First-Party Application Standards

> **Status**: Active | **Last Updated**: 2026-05-09
>
> Standards, conventions, and workflows for all AGNOS first-party applications.
> Non-negotiable for interoperability with daimon, agnoshi, mela, and the marketplace.
>
> **Language**: Cyrius (sovereign systems language). Pure Rust-era guidance has moved to [`docs/archive/first-party-standards-rust-era.md`](../../archive/first-party-standards-rust-era.md) — consult the archive for migrations from older repos; this doc is Cyrius-only going forward.
>
> **Companion**: [first-party-documentation.md](first-party-documentation.md) — the `docs/` tree, root docs (README, CHANGELOG, CLAUDE.md, SECURITY.md), ADRs, architecture, guides, examples, API reference, audit, benchmarks, standards, compliance, articles. This file covers *code*; the companion covers *docs*.
>
> **CLAUDE.md template**: [`example_claude.md`](example_claude.md) — copy to a new repo as `CLAUDE.md`.
>
> **Reference implementations**:
> - [hadara](https://github.com/MacCracken/hadara) — Cyrius-native gold standard
> - [kybernet](https://github.com/MacCracken/kybernet) — Cyrius port gold standard (PID 1, 486KB, 140 tests)
> - [cyrius](https://github.com/MacCracken/cyrius) — CLAUDE.md gold standard (durable rules in `CLAUDE.md`, volatile state in `docs/development/state.md`)
> - [sit](https://github.com/MacCracken/sit) — minimal docs-scaffold reference

---

## Scaffolding — Use the Tools

**Always use Cyrius tooling to scaffold and port.** Do not manually create project structures. The tools ensure consistency across 130+ repos. If the tools are missing something, fix the tools — don't work around them.

### New Cyrius-native project

```sh
cyrius init myproject
cd myproject
cyrius deps
cyrius build src/main.cyr build/myproject
```

`cyrius init` creates: `cyrius.cyml`, `src/main.cyr`, `src/test.cyr`, `lib/` (vendored stdlib), `scripts/`, `docs/`, CI workflows, VERSION, LICENSE, README, CHANGELOG, .gitignore. Everything aligned with first-party standards from the first commit.

- `cyrius init --ci` — also generates CI/release workflows
- `cyrius init --dry-run myproject` — shows what would be created without writing
- The toolchain is pinned in `cyrius.cyml` via `[package].cyrius = "X.Y.Z"` — no separate `.cyrius-toolchain` file

### Porting a Rust project to Cyrius

```sh
cyrius port /path/to/rust-project
```

`cyrius port` moves all Rust code to `rust-old/` (preserved for benchmark comparison), scaffolds the Cyrius project structure, vendors stdlib, and generates an initial source file.

After porting:
1. Implement the Cyrius source files referencing `rust-old/` for logic
2. Preserve Rust benchmark data in `docs/benchmarks-rust-v-cyrius.md`
3. Run comparative benchmarks
4. Delete `rust-old/` only after the Cyrius version has equal or better test coverage and benchmarks

The Rust-era code is preserved as a git-tagged snapshot for benchmark comparison — see the retirement-via-git-tag pattern in [first-party-documentation.md](first-party-documentation.md).

---

## Security Hardening (required before every release)

Every project must run a security audit pass before release. Added after the full-chain 0-day sweep on 2026-04-13 that found 30 kernel issues, 13 compiler issues, and additional shell issues — all in one night, triggered by a VIM CVE report.

**The process:**

1. **Input validation** — every function accepting external data validates bounds, types, ranges
2. **Buffer safety** — every `var buf[N]` verified: N is BYTES, max access < N, no overflow into adjacent variables
3. **Syscall review** — every syscall validated: args checked, returns handled, error paths complete
4. **Pointer validation** — no raw pointer dereference of untrusted input without bounds
5. **No command injection** — no `sys_system()` or `exec_cmd()` with unsanitized input; use `exec_vec()` with explicit argv
6. **No path traversal** — file paths from external input validated, no `../` escape
7. **Known CVE review** — check dependencies and patterns against current CVE databases
8. **Document findings** — file all issues in `docs/audit/YYYY-MM-DD-audit.md`

**Severity levels:** CRITICAL (remote/privilege escalation), HIGH (moderate effort), MEDIUM (specific conditions), LOW (defense-in-depth).

**The lesson:** The VIM zero-day (CVE-2026-34714) was a modeline sandbox escape — the editor managed its own security and its own features could bypass it. In AGNOS, **kavach owns the sandbox, not the application.** Applications never manage their own security boundaries.

CI projects should run the security scan job (see [CI/CD Workflows](#cicd-workflows)) on every push.

---

## Project Structure

### Required layout (Cyrius)

```
{project}/
├── VERSION                          # Single source of truth (CalVer or SemVer)
├── cyrius.cyml                      # Build manifest + deps + toolchain pin
├── CLAUDE.md                        # Claude Code project instructions (see example_claude.md)
├── README.md                        # Architecture, quick start, usage examples
├── CHANGELOG.md                     # Keep a Changelog format
├── CONTRIBUTING.md                  # Contribution guidelines
├── CODE_OF_CONDUCT.md               # Code of conduct
├── SECURITY.md                      # Security policy and reporting
├── LICENSE                          # GPL-3.0-only (or AGPL-3.0-only for desktop GUIs)
├── Makefile                         # Convenience targets (optional)
├── rust-old/                        # Preserved Rust source (ported projects only — delete after Cyrius parity)
├── src/
│   ├── main.cyr                     # CLI/server entrypoint (binaries) OR
│   ├── lib.cyr                      # Library root (libraries — includes all modules)
│   ├── test.cyr                     # Top-level test entrypoint
│   ├── bench.cyr                    # Top-level bench entrypoint (where applicable)
│   ├── {module}.cyr                 # Domain modules
│   └── seed.cyr                     # Pre-built data (if applicable)
├── lib/                             # Resolved deps (auto-generated by `cyrius deps`)
├── tests/
│   └── *.tcyr                       # Cyrius test files
├── benches/
│   └── *.bcyr                       # Cyrius benchmark files
├── programs/                        # Standalone programs / examples
├── build/                           # Build output (gitignored)
├── scripts/
│   └── version-bump.sh              # Updates VERSION
├── docs/
│   ├── development/
│   │   ├── roadmap.md               # Versioned milestones through v1.0
│   │   └── state.md                 # Volatile state (versions, sizes, in-flight slots) — bumped per release
│   ├── audit/                       # Security audit reports (YYYY-MM-DD-audit.md)
│   ├── adr/                         # Architectural decision records (when earned)
│   ├── guides/                      # Usage guides, integration patterns (when earned)
│   ├── sources.md                   # Per-module academic citations (science/math/domain crates — required)
│   └── benchmarks-rust-v-cyrius.md  # Port comparison data (ported crates only)
├── .github/workflows/
│   ├── ci.yml                       # cyrius deps + fmt + lint + vet + build + test + bench
│   └── release.yml                  # CI gate → build → version verify → release
└── .gitignore
```

**Key conventions:**
- `cyrius.cyml` replaces `Cargo.toml` — manifest, deps, build config, toolchain pin
- No lockfile by default — zero transitive deps. Optional `cyrius.lock` pins git-dep hashes when present
- `.tcyr` and `.bcyr` are the native test and benchmark formats
- `lib/` holds resolved deps after `cyrius deps` runs; vendored stdlib lives there too
- Build output goes in `build/`, not `target/` — seconds, not minutes
- Typical CI pipeline runs in ~1 minute
- **sakshi** is the standard error/tracing/logging crate — no `tracing`, no `thiserror`, no `anyhow`

### .gitignore (required)

```gitignore
# Build output
/build/
/dist/

# Resolved deps (auto-generated by `cyrius deps`) — vendored stdlib stays
lib/*.cyr
!lib/k*.cyr

# Lockfile policy: track when git-deps are present, otherwise omit
# (uncomment to ignore)
# cyrius.lock

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Claude Code
.claude/

# Environment / secrets
.env
.env.*
*.pem
*.key
```

Every project must have a `.gitignore` **before the first commit**. Missing this floods the repo with build artifacts.

---

## cyrius.cyml Manifest

The manifest is the single source of truth for build config, deps, and toolchain. Reference: [kybernet/cyrius.cyml](https://github.com/MacCracken/kybernet/blob/main/cyrius.cyml).

### Minimal (Cyrius-native, no external deps)

```toml
[package]
name = "{project}"
version = "${file:VERSION}"
description = "{Project} — one-line description"
license = "GPL-3.0-only"
repository = "https://github.com/MacCracken/{project}"
language = "cyrius"
cyrius = "5.8.0"                    # Toolchain pin — single source of truth

[build]
entry = "src/main.cyr"              # or src/lib.cyr for libraries
test = "src/test.cyr"
output = "build/{project}"

[deps]
stdlib = ["string", "fmt", "alloc", "io", "vec"]
```

### With external deps (ported / consumer)

```toml
[deps.agnosys]
git = "https://github.com/MacCracken/agnosys.git"
path = "../agnosys"                  # Local path for dev workflow
tag = "1.0.4"                        # Pinned version
modules = ["lib/syscalls_linux.cyr"] # Specific files to include

[deps.libro]
git = "https://github.com/MacCracken/libro.git"
path = "../libro"
tag = "2.0.5"
modules = ["src/chain.cyr", "src/verify.cyr"]
```

**Rules:**
- `version = "${file:VERSION}"` — pull from the VERSION file, never inline a number
- `cyrius = "X.Y.Z"` — pin the toolchain version. CI installs this exact version
- `tag = "X.Y.Z"` on every git dep — never an unpinned branch reference
- `modules = [...]` — explicit file list per dep; no glob imports

---

## Crate Naming

- Prefer **clean single-word names**: `hisab`, `dhvani`, `tarang`, `kavach`, `yukti`, `libro`, `kybernet`
- Naming pool: Sanskrit, Arabic, Persian, Hebrew, Greek, Japanese — see existing crates for tone
- Hyphens are reserved for game/demo subprojects (`cyrius-doom`, `cyrius-nba-jam`)
- Never mix hyphens and underscores
- Binary name: project name, lowercase

---

## Own the Stack

When AGNOS has a crate that wraps a domain, **depend on the AGNOS crate, not raw primitives or external libraries**:

| Need | Use | NOT |
|------|-----|-----|
| Vectors, matrices, transforms | `hisab` | inline math |
| Physics simulation | `impetus` (uses hisab) | rolling your own |
| Expression evaluation / DSP math | `abaco` | inline `powf`/`log10` |
| Hardware detection | `ai-hwaccel` | internal GPU probing |
| Media decode/encode | `tarang` | shelling to ffmpeg |
| Rendering (GPU, shaders, PBR) | `soorat` | custom draw calls |
| Optics / light physics | `prakash` | inline Fresnel, hardcoded color temp |
| Image processing | `ranga` | manual color conversion |
| Synthesis (oscillators, filters, envelopes) | `naad` | inline DSP primitives |
| Vocal synthesis | `svara` (uses naad) | inline vocal tract |
| Audio pipeline | `dhvani` | DSP reimplementation |
| Audio codecs | `shravan` | inline WAV/FLAC parsers |
| Audio device I/O | `vani` (folded into Cyrius stdlib v5.8.0) | direct ALSA ioctls |
| Compression | `sankoch` (folded into stdlib path) | inline deflate, shelling to gzip |
| Device abstraction | `yukti` | direct udev/sysfs |
| LLM inference | `hoosh` (client) | direct provider APIs |
| Queue/pubsub | `majra` | custom channels |
| Sandboxing | `kavach` | internal sandbox backends |
| Audit logging | `libro` | custom hash chains |
| MCP protocol | `bote` | custom JSON-RPC |
| MCP security | `t-ron` | per-app authorization |
| Threat detection | `phylax` | inline YARA/entropy |
| Trust / crypto / hashing | `sigil` | inline AES, custom SHA |
| Emotion/personality | `bhava` | per-app mood systems |
| Statistics / probability | `pramana` | inline distributions |
| Ancient math systems | `sankhya` | inline calendar math |
| Atomic / subatomic physics | `tanmatra` | inline nuclear formulas |
| Navigation / pathfinding | `raasta` | custom A* |
| Programming reference | `vidya` | hardcoded examples |
| Psychology / cognition | `bodh` | inline cognitive models |
| Social dynamics | `sangha` | custom network graphs |
| Microbiology | `jivanu` | inline growth curves |
| Neuroscience / neurotransmitters | `mastishk` | inline serotonin/dopamine |
| Enzyme kinetics / metabolism | `rasayan` | inline Michaelis-Menten |
| Phoneme / language data | `varna` | hardcoded IPA tables |
| Divine archetypes | `avatara` | per-app deity tables |
| Historical eras / events | `itihas` | inline timelines |
| Service-boundary HTTP/RPC | Cyrius stdlib `lib/sandhi.cyr` (folded v5.7.0) | external HTTP libs |
| Regex (BRE/RE2/PCRE/fuzzy/vim) | Cyrius stdlib `lib/niyama.cyr` (folded v5.9.0) | external regex libs |
| Source-code grammar / tokenizer | `vyakarana` | hand-rolled lexers |
| Tracing / errors / structured logging | `sakshi` | inline logging |

Only one crate should directly own each domain. Extract when **3+ projects** implement the same pattern.

For the live registry of who's at what version: [shared-crates.md](shared-crates.md).

---

## Versioning

### CalVer (consumer apps, binaries, ports of dated upstreams)

```
YYYY.M.D[-N]
```

- `YYYY.M.D` — release date (no zero-padding on month/day)
- `-N` — patch within the same day, starts at `-1`

### SemVer (shared library crates)

```
0.M.P     (pre-1.0: surface still moving)
M.N.P     (post-1.0: standard SemVer)
```

### VERSION file

- Single source of truth: `VERSION` at the project root
- Contains one line, no trailing newline
- CI reads it: `VERSION=$(cat VERSION | tr -d '[:space:]')`
- `cyrius.cyml` references it via `version = "${file:VERSION}"`
- Git tag matches exactly: `git tag $VERSION`
- Release workflow verifies VERSION matches tag

### Licensing

All AGNOS projects use **`GPL-3.0-only`**. No exceptions.

| License | SPDX | Use For |
|---------|------|---------|
| GNU GPL v3 | `GPL-3.0-only` | Library crates, CLI tools, daemons, kernel modules |
| GNU AGPL v3 | `AGPL-3.0-only` | Desktop GUI applications (network-copyleft variant) |

**Rules:**
- Always use the `-only` suffix — `GPL-3.0-only`, not `GPL-3.0` or `GPL-3.0+`
- The `license` field in `cyrius.cyml` must match the LICENSE file in the repo root
- Dual licensing is not permitted for first-party projects

**Known exception:** `stiva` uses `GPL-3.0-or-later` (historical, to be reviewed).

---

## CLAUDE.md (required)

Every AGNOS project must have a `CLAUDE.md` at the repo root. Read by Claude Code at the start of every session — defines project identity, development process, and constraints. **Not optional.**

**Template**: [`example_claude.md`](example_claude.md) — copy this, fill in the `{placeholders}`, add project-specific principles.

**Reference implementation**: [cyrius/CLAUDE.md](https://github.com/MacCracken/cyrius/blob/main/CLAUDE.md) — the gold standard. Durable rules live in `CLAUDE.md`; volatile state (current version, binary sizes, test counts, in-flight work) lives in `docs/development/state.md`. Inlined state rots within a minor release.

**Standard constraints (must appear in every CLAUDE.md):**

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not add unnecessary dependencies
- Do not skip benchmarks before claiming performance improvements
- Zero panic in library code — errors flow through sakshi
- Cyrius idioms: explicit syscall returns, bounded buffers, no FFI without justification

Project-specific additions: each project adds principles relevant to its domain (e.g., libro adds "No magic — every operation is auditable").

---

## CI/CD Workflows

Reference: [kybernet/.github/workflows/ci.yml](https://github.com/MacCracken/kybernet/blob/main/.github/workflows/ci.yml), [kybernet/.github/workflows/release.yml](https://github.com/MacCracken/kybernet/blob/main/.github/workflows/release.yml).

### ci.yml — every push and PR

Required jobs:

```yaml
jobs:
  build:                # cyrius deps + fmt + lint + vet + build + test + bench
                        # Pulls toolchain version from cyrius.cyml
                        # Verifies dep hashes against cyrius.lock (when present)
                        # Cross-builds aarch64 when cc5_aarch64 is in the bundle
                        # Verifies ELF magic bytes on output
                        # Runs cyrius bench (continue-on-error: bench numbers vary by runner)

  security:             # Pattern scan for dangerous constructs
                        # - raw execve / exit syscalls in lib modules
                        # - unbounded stack buffers (>= 64KB)
                        # - sys_open vs sys_close fd hygiene tracking
                        # - sys_system() / shell injection patterns

  docs:                 # Verify required files exist:
                        # README.md, CHANGELOG.md, VERSION, CONTRIBUTING.md,
                        # SECURITY.md, LICENSE, CLAUDE.md, cyrius.cyml
                        # Verify VERSION appears in CHANGELOG.md
```

**Toolchain install pattern:**

```yaml
- name: Install Cyrius toolchain
  run: |
    CYRIUS_VERSION="${CYRIUS_VERSION:-$(grep -oP '(?<=^cyrius = ")[^"]+' cyrius.cyml)}"
    curl -sLO "https://github.com/MacCracken/cyrius/releases/download/$CYRIUS_VERSION/cyrius-$CYRIUS_VERSION-x86_64-linux.tar.gz"
    tar xzf "cyrius-$CYRIUS_VERSION-x86_64-linux.tar.gz"
    # ... install into $HOME/.cyrius/{bin,lib} and prepend to PATH
```

**Build with dead-code elimination** (production releases):

```yaml
- name: Build (DCE)
  run: CYRIUS_DCE=1 cyrius build src/main.cyr build/{project}
```

### release.yml — tag push only

```yaml
jobs:
  ci:                   # uses: ./.github/workflows/ci.yml (CI gate)
  build:                # Multi-platform matrix:
                        #   x86_64-linux
                        #   aarch64-linux (cross-compile)
  verify:               # Check VERSION matches the git tag
  release:              # softprops/action-gh-release@v2
                        # generate_release_notes: true
                        # Attach build artifacts + bench-history.csv
```

**Release benchmark artifacts**: every tagged release runs `cyrius bench src/bench.cyr` and attaches results as release assets. Every version gets a permanent, reproducible performance snapshot.

CI/release benchmarks use reduced sample counts for smoke testing (~3 minute cap). Local development uses full samples for accurate measurement.

---

## Benchmarking

### Required for shared crates

Every shared crate must have benchmarks with CSV history tracking. Consumer apps benchmark optionally.

### Cyrius benchmarks

- Bench files: `src/bench.cyr` (top-level entrypoint) or `benches/*.bcyr`
- Run: `cyrius bench src/bench.cyr`
- Output is parsed by `scripts/bench-history.sh` into a CSV trail

### bench-history.sh — dual output

```sh
./scripts/bench-history.sh
```

The script must:
- Run `cyrius bench`, capture output
- Parse the time format, normalize all units to nanoseconds
- Append to CSV with timestamp, commit hash, branch
- Generate a Markdown table with human-readable units

### 3-point trend (recommended)

For mature crates, generate **baseline → optimized → current** with delta percentages — catches regressions and proves wins hold across commits:

```markdown
| Benchmark | Baseline (`abc123`) | Optimized (`def456`) | Current (`789abc`) |
|-----------|---------------------|----------------------|--------------------|
| `transform3d_apply_point` | 13.7 ns | 5.9 ns **-57%** | 5.9 ns **-57%** |
```

### Batch benchmarks

Include batch/throughput benchmarks alongside single-call latency:
- `ray_sphere×100` — what a broadphase actually does
- `dsp_batch_4096` — a real audio buffer
- `parse_100_expressions` — real workload

---

## Makefile (optional convenience)

Cyrius commands work directly without a Makefile, but a thin wrapper is useful:

```makefile
.PHONY: check fmt lint test bench build clean

check: fmt lint test            # Run all CI checks locally

fmt:
	for f in src/*.cyr src/lib/*.cyr; do \
		cyrius fmt --check $$f || exit 1; \
	done

lint:
	for f in src/*.cyr src/lib/*.cyr; do \
		cyrius lint $$f; \
	done

test:
	cyrius test src/test.cyr

bench:
	./scripts/bench-history.sh

build:
	mkdir -p build
	CYRIUS_DCE=1 cyrius build src/main.cyr build/$(notdir $(CURDIR))

clean:
	rm -rf build/
```

---

## Testing

### Conventions

- **Unit tests**: inline assertions in module files, run via `cyrius test src/test.cyr`
- **Integration tests**: `tests/*.tcyr` for cross-module behavior
- **Examples**: at least one runnable program in `programs/` — runs with `cyrius build`
- Minimum **100 assertions** across all modules for a releasable project
- Benchmarks: **required** for shared crates, optional for consumer apps

### DO

- Test domain logic extensively — every public function gets a happy path + at least one error path
- Test MCP tools with mock state (happy + error paths)
- Test all error variants and their formatted messages
- Test serialization roundtrips for all public types

### DON'T

- Use process-global state in parallel tests — they race
- `panic()` or unhandled syscall errors in library code
- Write tests that depend on network access without an explicit gate
- Skip the test entrypoint check at end-of-run: CI greps for `0 failed` in the summary line

### Test runner pattern

```cyrius
fn main() {
    var passed = 0;
    var failed = 0;

    test_module_a(&passed, &failed);
    test_module_b(&passed, &failed);

    println!("{} passed, {} failed", passed, failed);
    return failed == 0 ? 0 : 1;
}

var exit_code = main();
syscall(60, exit_code);
```

---

## Error Handling

**sakshi** is the canonical error/tracing crate for Cyrius. It replaces the Rust `thiserror` + `anyhow` + `tracing` stack with a single foundational crate.

| Context | Pattern |
|---------|---------|
| Library error types | sakshi `Error` with module-tagged variants |
| Application / CLI | sakshi `Result<T>` with context chains |
| MCP tools | JSON-RPC error: `{ "code": -32000, "message": "..." }` |

Errors should:
- Carry enough context to be diagnosed without a debugger
- Use structured fields, not string interpolation
- Flow through return values — never panic in library code
- Bubble up to a single error-printing site at the entrypoint

---

## Logging & Audit Tracing

### Structured logging via sakshi

Every crate uses **sakshi** for structured, auditable log output. This feeds libro's audit chain and AGNOS's observability infrastructure. There is no `tracing` dependency — sakshi is the standard.

### What to log

| Level | When | Example |
|-------|------|---------|
| `error` | Operation failed, caller must handle | `error!(path = path, "file not found")` |
| `warn` | Degraded behavior, operation succeeded with concerns | `warn!(error = e, "chain verification failed")` |
| `info` | Lifecycle events, state transitions, audit-worthy actions | `info!(entries = count, "store opened")` |
| `debug` | Detailed operation internals | `debug!(rule = name, "YARA rule compiled")` |
| `trace` | Per-call hot-path tracing (high volume, perf-sensitive) | `trace!(target = path, "scanning file")` |

### Structured fields

Always use structured key-value pairs, not string interpolation:

```cyrius
// DO — structured, machine-parseable, audit-friendly
info!(agent_id = id, action = "register", status = "success");
warn!(device = path, fs_type = fs, "unsupported filesystem");

// DON'T — unstructured, unparseable
info!("Agent registered: " + id);
```

### Env var convention

Per-crate log filtering via `{PROJECT}_LOG` in SCREAMING_SNAKE_CASE: `KYBERNET_LOG`, `PHYLAX_LOG`, `BHAVA_LOG`. Falls back to `info` if unset.

Supports per-module filtering: `HISAB_LOG=hisab::num=debug,hisab::geo=trace`.

### Audit-critical events

These MUST be logged at `info` or higher — they feed the audit trail:

- Agent registration / deregistration
- Device mount / unmount / eject
- Security scan results (findings, severity)
- MCP tool calls (via t-ron)
- Personality changes, mood stimuli above threshold
- File operations (create, delete, permission change)
- Configuration changes

---

## MCP Integration

### Tool naming

```
{project}_{verb}        # e.g. jalwa_play, rasa_export
{project}_{noun}        # e.g. tarang_codecs, mneme_notebook
```

- All lowercase, underscores between words
- Always prefixed with project name — no exceptions
- 5–8 tools per project (minimum 5)
- Every tool must have a JSON schema for inputs

### Required tests

- `test_tool_list()` — verifies all tools appear
- One test per tool — happy path
- One test per tool — error / invalid input path

---

## Daimon Integration

### Connection pattern

Daimon clients connect over Unix socket by default, TCP fallback for remote instances:

```cyrius
struct DaimonConfig {
    endpoint: str,        // default: /run/agnos/daimon.sock
    api_key: Option<str>,
}

struct HooshConfig {
    endpoint: str,        // default: /run/agnos/hoosh.sock
}
```

### Integration tiers

| Tier | What | When |
|------|------|------|
| **1 — Lifecycle** | `register_agent()`, heartbeat (long-running daemons) | Always required |
| **2 — Search** | `index_vector()`, `search_vector()` | Apps with searchable content |
| **3 — Knowledge** | `ingest_rag()`, `query_rag()` | Apps with documents/text |
| **4 — Inference** | LLM calls via hoosh | Apps with AI features |

### `src/ai.cyr` — the AI module

Feature-gated where applicable. Holds:
- DaimonClient construction
- Per-tool wrappers that translate domain operations into MCP calls
- Hoosh inference client for LLM-backed features

Reference: [agnoshi](https://github.com/MacCracken/agnoshi) — the canonical daimon/hoosh consumer.

---

## Documentation Requirements

> **Authoritative**: full doc standards live in [first-party-documentation.md](first-party-documentation.md). The summary below is a quick reference; the companion is authoritative when they conflict.

### ADRs

Store in `docs/adr/NNNN-short-title.md`. Each ADR includes:

- **Context** — what problem or choice prompted the decision
- **Decision** — what was decided and why
- **Consequences** — trade-offs, constraints that follow
- **Status** — proposed / accepted / deprecated / superseded

Create an ADR when choosing between competing approaches, adopting/rejecting a dependency, changing a public API, or accepting a performance trade-off.

### Source citations (required for science/math/domain crates)

Every algorithm, formula, constant, and domain model **must cite its source**.

**In code** — inline documentation with full citation:

```cyrius
// Rosenberg glottal pulse model for vocal fold simulation.
//
// Source: Rosenberg, A.E. (1971). "Effect of Glottal Pulse Shape on the
// Quality of Natural Vowels." J. Acoust. Soc. Am., 49(2B), 583-590.
// doi:10.1121/1.1912389
//
// Implementation Notes: uses the two-parameter model (Tp, Tn) from Section III.
fn glottal_pulse(t: f64, tp: f64, tn: f64) -> f64 {
    // ...
}
```

**In docs** — `docs/sources.md` listing every paper, textbook, or specification, URLs to freely available versions where possible, which module uses which source.

**The standard**: a reviewer unfamiliar with the domain should be able to trace any algorithm back to its origin and verify the implementation against the published source. No magic numbers. No undocumented formulas.

### Guides and examples

- **Guides** (`docs/guides/`) — written for consumers. Integration patterns, common usage, migration between versions
- **Examples** (`programs/` or `docs/examples/`) — working code with comments explaining *why*, not just *what*. Every public API gets at least one example

### Standards and compliance

- **Standards** (`docs/standards/`) — external specs the crate implements. Link to spec, note version, document deviations
- **Compliance** (`docs/compliance/`) — regulatory/licensing/security compliance. Audit results, certification status, known limitations

---

## Naming Conventions

| Thing | Convention | Example |
|-------|-----------|---------|
| Project name | Multilingual (Sanskrit, Arabic, Persian, Hebrew, Greek, Japanese, etc.) | jalwa, tarang, hisab, kybernet, kavach |
| MCP tools | `{project}_{verb}`, underscores | `jalwa_play`, `rasa_export` |
| Agnoshi intents | Match MCP tool names | `jalwa_play` pattern |
| Binary name | Project name, lowercase | `jalwa`, `tarang`, `kybernet` |
| Config dir | `~/.{project}/` or `~/.local/share/{project}/` | `~/.jalwa/` |
| Systemd unit | `{project}.service` | `phylax.service` |
| Desktop entry | `{project}.desktop` | `jalwa.desktop` |
| Cyrius source | `*.cyr` | `chain.cyr`, `verify.cyr` |
| Cyrius tests | `*.tcyr` | `kybernet.tcyr` |
| Cyrius benches | `*.bcyr` | `hisab.bcyr` |

---

## Marketplace Recipe

### Required: zugot recipe (`marketplace/{project}.toml`)

Recipes live in [zugot](https://github.com/MacCracken/zugot) (Hebrew: זוּגוֹת — pairs that enter the ark).

```toml
[package]
name = "{project}"
version = "YYYY.M.D"
description = "{Project} — one-line description"
license = "GPL-3.0-only"
groups = ["{domain}"]

[source]
github_release = "MacCracken/{project}"
release_asset = "{project}-*-linux-amd64.tar.gz"
sha256 = ""                         # Populate from release tarball

[depends]
runtime = []                         # No glibc dep — Cyrius binaries are static
build = ["cyrius"]                   # Cyrius toolchain at the manifest-pinned version

[marketplace]
category = "{category}"
runtime = "native-binary"
publisher = "AGNOS"
tags = [...]
min_agnos_version = "2026.5.1"

[marketplace.sandbox]
seccomp_mode = "basic"
network_access = true_or_false
data_dir = "~/.{project}/"

[build]
make = "CYRIUS_DCE=1 cyrius build src/main.cyr build/{project}"
check = "cyrius test src/test.cyr"

[security]
hardening = ["pie", "fullrelro", "fortify", "stackprotector", "bindnow"]
```

---

## Project Flow

### New project lifecycle

```
1. Scaffold       → cyrius init {project}
                     (creates: cyrius.cyml, src/{main,test}.cyr, lib/, docs/,
                      VERSION, LICENSE, README, CHANGELOG, CONTRIBUTING,
                      CODE_OF_CONDUCT, SECURITY, CLAUDE.md, .gitignore,
                      Makefile, scripts/, .github/workflows/)
2. Core logic     → src/lib.cyr + domain modules
3. Tests          → src/test.cyr + tests/*.tcyr + programs/*.cyr (examples)
4. Benchmarks     → src/bench.cyr or benches/*.bcyr + scripts/bench-history.sh
5. AI integration → src/ai.cyr (DaimonClient, HooshClient where applicable)
6. MCP server     → 5+ tools, JSON-RPC on stdio (if applicable)
7. CLI            → src/main.cyr, subcommands (if binary)
8. Docs           → docs/architecture/overview.md +
                     docs/development/{roadmap,state}.md +
                     docs/sources.md (science/math crates) +
                     docs/adr/ (when decisions are made) +
                     docs/guides/ + docs/examples/ (for consumers)
9. First release  → VERSION, CHANGELOG, git tag, CI builds + publishes
10. AGNOS integration:
    a. Zugot recipe          → zugot repo: marketplace/{project}.toml
    b. Agnoshi intents       → agnoshi repo: src/interpreter/patterns.cyr
    c. MCP tool registration → daimon repo: MCP tool list
    d. Application doc       → agnosticos docs/applications/{project}.md
    e. Bundle test           → ark-bundle.sh {recipe}
```

### P(-1): Scaffold Hardening

Before any feature work begins, every scaffolded project goes through hardening. The scaffold gets you compiling — P(-1) makes it production-grade. Build features on an unaudited foundation and every feature inherits the scaffold's shortcuts. P(-1) pays the debt before it compounds.

```
┌──────────────────────────────────────────────────────────────┐
│                  P(-1): SCAFFOLD HARDENING                   │
│                                                              │
│  1. TEST + BENCHMARK SWEEP                                   │
│     Comprehensive coverage of existing scaffold code         │
│     Cyrius benchmarks for all hot paths                      │
│                                                              │
│  2. CLEANLINESS CHECK                                        │
│     cyrius fmt --check src/*.cyr                             │
│     cyrius lint src/*.cyr                                    │
│     cyrius vet src/main.cyr                                  │
│                                                              │
│  3. GET BASELINE                                             │
│     ./scripts/bench-history.sh                               │
│     First CSV entry — this is the starting line              │
│                                                              │
│  4. INITIAL REFACTOR + AUDIT                                 │
│     Code review: performance, memory, security, edge cases   │
│     Apply standard patterns: bounded buffers, explicit       │
│     syscall return handling, sakshi error flow               │
│                                                              │
│  5. SECURITY SWEEP                                           │
│     Run the security-hardening checklist (see above)         │
│     File findings in docs/audit/YYYY-MM-DD-audit.md          │
│                                                              │
│  6. CLEANLINESS CHECK                                        │
│     cyrius fmt / lint / vet — must be clean                  │
│                                                              │
│  7. ADDITIONAL TESTS + BENCHMARKS                            │
│     From audit observations: edge cases, error paths,        │
│     regression tests, new benchmark targets                  │
│                                                              │
│  8. POST-AUDIT BENCHMARKS                                    │
│     ./scripts/bench-history.sh                               │
│     Compare against step 3 — prove the wins                  │
│                                                              │
│  9. IF AUDIT HEAVY → return to step 4                        │
│     Keep drilling until clean                                │
│                                                              │
│ 10. DOCUMENTATION AUDIT                                      │
│     ADRs for any design decisions made during hardening      │
│     Source citations for all algorithms/formulas/constants   │
│     docs/sources.md current (science/math/domain crates)     │
│     Guides and examples for public API surface               │
│     Standards/compliance docs if applicable                  │
│                                                              │
│  Exit: Crate is audit-clean, fmt-clean, lint-clean, vet-     │
│  clean, security-clean, documented, with baseline benches.   │
│  Enter the Development Loop.                                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Development Loop

The continuous improvement cycle. Each pass makes the crate measurably better.

```
┌──────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT LOOP                          │
│                                                              │
│  1. WORK PHASE                                               │
│     New features, roadmap items, bug fixes                   │
│                                                              │
│  2. CLEANLINESS CHECK                                        │
│     cyrius fmt --check src/*.cyr                             │
│     cyrius lint src/*.cyr                                    │
│     cyrius vet src/main.cyr                                  │
│                                                              │
│  3. TEST + BENCHMARK ADDITIONS                               │
│     Comprehensive coverage for new code                      │
│     New benchmarks for new hot paths                         │
│                                                              │
│  4. RUN BENCHMARKS                                           │
│     ./scripts/bench-history.sh                               │
│     Baseline captured in CSV                                 │
│                                                              │
│  5. AUDIT PHASE                                              │
│     Review: performance, memory, security, throughput,       │
│     correctness, edge cases                                  │
│                                                              │
│  6. CLEANLINESS CHECK                                        │
│     cyrius fmt / lint / vet — must be clean                  │
│                                                              │
│  7. TEST + BENCHMARK DEEPER ADDITIONS                        │
│     From audit observations: edge cases, error paths,        │
│     regression tests, new benchmark targets                  │
│                                                              │
│  8. RUN BENCHMARKS                                           │
│     ./scripts/bench-history.sh                               │
│     Compare against step 4 baseline — prove the wins         │
│                                                              │
│  9. IF AUDIT TOO HEAVY → return to step 5                    │
│     Keep drilling until clean                                │
│                                                              │
│ 10. DOCUMENTATION PHASE                                      │
│     Update CHANGELOG with changes                            │
│     Remove completed roadmap items                           │
│     Bump docs/development/state.md (versions, sizes, slots)  │
│     ADRs for any significant design decisions                │
│     Source citations for new algorithms/formulas/constants   │
│     Update docs/sources.md (science/math/domain crates)      │
│     Update guides and examples for new/changed API surface   │
│     Verify recipe version in zugot matches VERSION           │
│                                                              │
│ 11. RETURN TO STEP 1                                         │
│     Next work phase begins                                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Key principles:**
- Never skip benchmarks. Numbers don't lie.
- Audit after every work phase, not just before release.
- The CSV history is the proof. 3-point trends catch regressions.
- If the audit reveals deep issues, loop steps 4–7 until clean.
- Documentation is the *last* step of each cycle — but it is **not optional**. Document what *is*, not what *might be*.
- Source citations are mandatory for science/math/domain crates. Every algorithm traces to a paper.
- ADRs capture the *why* behind design decisions. Code shows *what*; ADRs show *why not the other thing*.
- Bound every buffer. Validate every syscall return. Errors flow through sakshi, never panic.

### Release Checklist

```
[ ] All tests pass (cyrius test src/test.cyr — "0 failed" in summary)
[ ] No fmt drift (cyrius fmt --check on every src file)
[ ] No lint warnings (cyrius lint clean)
[ ] cyrius vet clean
[ ] Security scan clean (CI security job — no FAIL)
[ ] Benchmarks run (./scripts/bench-history.sh — no regressions)
[ ] VERSION file updated
[ ] CHANGELOG.md updated, includes the new VERSION
[ ] cyrius.cyml toolchain pin matches the intended Cyrius release
[ ] docs/development/state.md bumped (size, test count, in-flight slots)
[ ] Git tag matches VERSION
[ ] CI passes on tag push (build + security + docs jobs)
[ ] Both x86_64-linux + aarch64-linux artifacts published
[ ] Zugot recipe updated (marketplace/{project}.toml — version + SHA256)
```

### DON'T

- Tag before CI passes on the branch
- Release without aarch64 builds (where the toolchain supports it)
- Skip the changelog — it's the audit trail
- Amend tags — create a new `-N` patch version instead
- **NEVER** use `gh` CLI — `curl` to GitHub API only
- Skip benchmarks — if you can't measure it, you can't claim it
- Inline volatile state in `CLAUDE.md` — version, sizes, in-flight work belong in `docs/development/state.md`

---

*Last Updated: 2026-05-09*
