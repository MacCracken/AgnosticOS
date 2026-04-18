# {Project} — Claude Code Instructions

## Project Identity

**{Project}** ({language}: {meaning}) — {one-line description}

- **Type**: Shared library / Binary / Workspace
- **License**: GPL-3.0-only
- **Language**: Cyrius (sovereign systems language, compiled by cc3)
- **Version**: SemVer, version file at `VERSION`
- **Status**: {version} — {brief status}
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-standards.md)
- **Shared crates**: [shared-crates.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/shared-crates.md)

## Goal

{One-sentence mission statement. What does this project OWN in the stack?
Example: "Own the database. Zero deps. Pure Cyrius. SQL + B-tree + JSONL in a single `include`."}

## Scaffolding

**This project was scaffolded using:**
- New project: `cyrius init {project}` then `cyrius init --ci`
- Ported from Rust: `cyrius port /path/to/rust-project`

**Do not manually create project structure.** Use the tools. They ensure consistency with first-party standards across all AGNOS repos. If the tools are missing something, fix the tools.

## Current State

- **Source**: {N} lines across {M} modules
- **Tests**: {N} assertions, {M} fuzz harnesses, {K} benchmarks
- **Binary**: {size}KB (DCE-built)
- **Stable**: {version} — {status summary: feature-complete / hardened / fuzzed / audited}
- **Integration**: {downstream consumers verified against current version}

## Consumers

| Project | Usage |
|---------|-------|
| {crate} | {how it uses this project} |

## Dependencies

- **{dep}** — {what it provides} (via Cyrius stdlib `lib/{dep}.cyr`, ships with Cyrius >= {X.Y.Z})

{Declare intent explicitly: "No external deps. No FFI." — or enumerate every first-party dep with pinned tag.}

## Quick Start

```bash
cyrius build src/lib.cyr build/{project}        # build
cyrius test tests/tcyr/{project}.tcyr           # unit tests
cyrius bench tests/bcyr/{project}.bcyr          # benchmarks
cyrius fuzz fuzz/                               # fuzz harnesses
cyrius lint src/*.cyr                           # static checks
CYRIUS_DCE=1 cyrius build ...                   # dead-code-eliminated build (release parity)
```

## Architecture

```
src/
  lib.cyr         — public API (includes all modules)
  {module}.cyr    — {description}
```

**Include order matters.** Declare it explicitly in `lib.cyr` — upstream modules first, downstream last. Circular includes break the build. Stdlib includes live only in `lib.cyr`; never add them to individual source files.

## Key Constraints

- **Zero / minimal dependencies** — no libsqlite3, no FFI unless the mission requires it (document in ADR)
- **All values are i64 or fixed-size strings** — matches Cyrius type system
- **No floating point** — integer math only (exceptions require an ADR)
- **flock for concurrency** — `syscall(73, fd, LOCK_EX/LOCK_UN)` advisory locking
- **Fixed page sizes** — no variable-length records across page boundaries unless justified
- {Add project-specific constraints here}

## Development Process

### P(-1): Scaffold Hardening (before any new features)

0. Read roadmap, CHANGELOG, and open issues — know what was intended
1. Cleanliness check: `cyrius build`, `cyrlint`, all tests pass
2. Benchmark baseline: `cyrius bench`
3. Internal deep review — gaps, optimizations, correctness, docs
4. External research — domain completeness, best practices
5. **Security audit** — review all input handling, syscall usage, buffer sizes, pointer validation. Run against known CVE patterns for the domain. File findings in `docs/audit/YYYY-MM-DD-audit.md`
6. Additional tests/benchmarks from findings
7. Post-review benchmarks — prove the wins
8. Documentation audit
9. Repeat if heavy

### Work Loop (continuous)

1. Work phase — new features, roadmap items, bug fixes
2. Build check: `cyrius build`
3. Test + benchmark additions for new code
4. Internal review — performance, memory, correctness
5. **Security check** — any new syscall usage, user input handling, buffer allocation reviewed for safety
6. Documentation — update CHANGELOG, roadmap, docs
7. Version check — VERSION, `cyrius.cyml`, CHANGELOG header in sync
8. Return to step 1

### Security Hardening (before release)

Run a dedicated security audit pass before any version release:

1. **Input validation** — every function that accepts external data (user input, file content, network data) validates bounds, types, and ranges before use
2. **Buffer safety** — every `var buf[N]` and `alloc(N)` verified: N is in BYTES, max access offset < N, no adjacent-variable overflow
3. **Syscall review** — every `syscall()` and `sys_*()` call reviewed: arguments validated, return values checked, error paths handled
4. **Pointer validation** — no raw pointer dereference of untrusted input without bounds checking
5. **No command injection** — no `sys_system()` or `exec_cmd()` with unsanitized user input. Use `exec_vec()` with explicit argv instead
6. **No path traversal** — file paths from external input validated against allowed directories. No `../` escape
7. **Known CVE check** — review dependencies and patterns against current CVE databases
8. **File findings** — all issues documented in `docs/audit/YYYY-MM-DD-audit.md` with severity, file, line, and fix

Severity levels:
- **CRITICAL** — exploitable immediately, remote or privilege escalation
- **HIGH** — exploitable with moderate effort
- **MEDIUM** — exploitable under specific conditions
- **LOW** — defense-in-depth improvement

### Closeout Pass (before every minor/major bump)

Run a closeout pass before tagging x.Y.0 or x.0.0. Ship as the last patch of the current minor (e.g. 2.2.5 before 2.3.0):

1. **Full test suite** — all .tcyr pass, zero failures
2. **Benchmark baseline** — `cyrius bench`, save CSV for comparison
3. **Dead code audit** — check for unused functions, remove dead source code
4. **Stale comment sweep** — grep for old version refs, outdated TODOs
5. **Security re-scan** — quick grep for new `sys_system`, unchecked writes, unsanitized input, buffer size mismatches
6. **Downstream check** — all consumers that depend on this crate still build and pass tests with the new version
7. **CHANGELOG/roadmap sync** — all docs reflect current state, version numbers consistent
8. **Version verify** — VERSION, `cyrius.cyml`, CHANGELOG header, and intended git tag all match
9. **Full build from clean** — `rm -rf build && cyrius deps && CYRIUS_DCE=1 cyrius build` passes clean

### Task Sizing

- **Low/Medium effort**: Batch freely — multiple items per work loop cycle
- **Large effort**: Small bites only — break into sub-tasks, verify each before moving to the next
- **If unsure**: Treat it as large

### Refactoring Policy

- Refactor when the code tells you to — duplication, unclear boundaries, measured bottlenecks
- Never refactor speculatively. Wait for the third instance
- Every refactor must pass the same test + fuzz + benchmark gates as new code
- 3 failed attempts = defer and document — don't burn time in a rabbit hole

## Key Principles

- **Correctness is the optimum sovereignty** — if it's wrong, you don't own it, the bugs own you
- Test after EVERY change, not after the feature is done
- ONE change at a time — never bundle unrelated changes
- Research before implementation — check vidya for existing patterns
- Study working programs (`cyrius/programs/*.cyr`) before writing new code
- Programs must call main() at top level: `var exit_code = main(); syscall(60, exit_code);`
- `cyrius build` handles everything — NEVER use raw `cat file | cc3`
- Source files only need project includes — deps auto-resolve from `cyrius.cyml`
- Every buffer declaration is a contract: `var buf[N]` = N BYTES, not N entries
- Fuzz every parser path — edge cases get invariants, not assertions
- Benchmark before claiming perf — numbers or it didn't happen
- {Add project-specific principles here}

## Cyrius Conventions

- All struct fields are 8 bytes (i64), accessed via `load64`/`store64` with offset
- Heap allocation via `fl_alloc()`/`fl_free()` (freelist) for data with individual lifetimes
- Bump allocation via `alloc()` for long-lived data (vec, str internals)
- Enum values for constants — don't consume gvar_toks slots (256 initialized globals limit)
- Heap-allocate large buffers — `var buf[256000]` bloats the binary by 256KB
- `break` in while loops with `var` declarations is unreliable — use flag + `continue`
- No negative literals — write `(0 - N)` not `-N`
- No mixed `&&`/`||` in one expression — nest `if` blocks instead
- `match` is reserved — don't use as a variable name
- `return;` without value is invalid — always `return 0;`
- All `var` declarations are function-scoped — no block scoping
- Max limits per compilation unit: 4,096 variables, 1,024 functions, 256 initialized globals

## CI / Release

- **Toolchain pin**: single line in `.cyrius-toolchain` (e.g. `4.10.3`). CI and release both read this file; no hardcoded version strings in YAML.
- **Dead code elimination**: every `cyrius build` in CI and release runs with `CYRIUS_DCE=1`. Binary size is a release metric — track it.
- **Tag filter**: release workflow triggers on `tags: ['[0-9]*']` — semver-only. Non-numeric tags do not ship a release.
- **Version-verify gate**: release asserts `VERSION == cyrius.cyml version == git tag` before building. Mismatch fails the run.
- **Lint step**: CI runs `cyrius lint` per source file. Advisory by default; projects may escalate to blocking.
- **Workflow layout**:
  - `.github/workflows/ci.yml` — build, lint, test, fuzz, bench, integration; reusable via `workflow_call`
  - `.github/workflows/release.yml` — version gate → CI gate → DCE build → artifacts (source tarball, bundled single-file `.cyr`, DCE binary, SHA256SUMS)
- **Concurrency**: CI uses `cancel-in-progress: true` keyed on workflow + ref — only the latest push is tested.

## Key References

- `docs/architecture/overview.md` — module map, data flow, file format spec
- `docs/development/roadmap.md` — completed milestones + backlog + future
- `CHANGELOG.md` — source of truth for all changes
- `../vidya/content/` — domain knowledge entries (research before implementation)

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not add unnecessary dependencies
- Do not skip tests before claiming changes work
- Do not skip fuzz / benchmark verification before claiming a feature works
- Do not use `sys_system()` with unsanitized input — command injection risk
- Do not trust external data (file content, network input, user args) without validation
- Do not use `break` in while loops with `var` declarations — use flag + `continue`
- Do not add Cyrius stdlib includes in individual src files — `lib.cyr` manages all includes
- Do not hardcode toolchain versions in CI YAML — read `.cyrius-toolchain`
- {Add project-specific constraints here}

## Documentation Structure

```
Root files (required):
  README.md, CHANGELOG.md, CLAUDE.md, CONTRIBUTING.md,
  SECURITY.md, CODE_OF_CONDUCT.md, VERSION, LICENSE,
  cyrius.cyml, .cyrius-toolchain

docs/ (required):
  architecture/overview.md — module map, data flow, file format
  development/roadmap.md — completed, backlog, future

docs/ (when earned):
  adr/ — architectural decision records
  audit/ — security audit reports (YYYY-MM-DD-audit.md)
  guides/ — usage patterns, integration
  sources/ — academic/domain citations (required for science/math crates)
```

## .gitignore (Required)

```gitignore
# Build
/build/
/dist/

# Cyrius
lib/*.cyr
!lib/k*.cyr

# Release / toolchain artifacts
cyrius-*.tar.gz
*.tar.gz
SHA256SUMS

# IDE
.idea/
.vscode/
*.swp
*~

# OS
.DS_Store
Thumbs.db
```

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/). Performance claims MUST include benchmark numbers. Breaking changes get a **Breaking** section with migration guide. Security fixes get a **Security** section with CVE references where applicable.
