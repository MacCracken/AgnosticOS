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

## Scaffolding

**This project was scaffolded using:**
- New project: `cyrius init {project}` then `cyrius init --ci`
- Ported from Rust: `cyrius port /path/to/rust-project`

**Do not manually create project structure.** Use the tools. They ensure consistency with first-party standards across all AGNOS repos. If the tools are missing something, fix the tools.

## Consumers

| Project | Usage |
|---------|-------|
| {crate} | {how it uses this project} |

## Architecture

```
src/
  lib.cyr         — public API (includes all modules)
  {module}.cyr    — {description}
```

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

### Work Loop / Working Loop (continuous)

1. Work phase — new features, roadmap items, bug fixes
2. Build check: `cyrius build`
3. Test + benchmark additions for new code
4. Internal review — performance, memory, correctness
5. **Security check** — any new syscall usage, user input handling, buffer allocation reviewed for safety
6. Documentation — update CHANGELOG, roadmap, docs
7. Version check — VERSION, cyrius.toml in sync
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
8. **Version verify** — VERSION, cyrius.toml, CHANGELOG header all match
9. **Full build from clean** — `rm -rf build && cyrius deps && cyrius build` passes clean

### Task Sizing

- **Low/Medium effort**: Batch freely — multiple items per work loop cycle
- **Large effort**: Small bites only — break into sub-tasks, verify each before moving to the next
- **If unsure**: Treat it as large

## Key Principles

- **Correctness is the optimum sovereignty** — if it's wrong, you don't own it, the bugs own you
- Test after EVERY change, not after the feature is done
- ONE change at a time — never bundle unrelated changes
- Research before implementation — check vidya for existing patterns
- Study working programs (`cyrius/programs/*.cyr`) before writing new code
- Programs must call main() at top level: `var exit_code = main(); syscall(60, exit_code);`
- `cyrius build` handles everything — NEVER use raw `cat file | cc3`
- Source files only need project includes — deps auto-resolve from cyrius.toml
- Every buffer declaration is a contract: `var buf[N]` = N BYTES, not N entries
- {Add project-specific principles here}

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not add unnecessary dependencies
- Do not skip tests before claiming changes work
- Do not use `sys_system()` with unsanitized input — command injection risk
- Do not trust external data (file content, network input, user args) without validation
- {Add project-specific constraints here}

## Documentation Structure

```
Root files (required):
  README.md, CHANGELOG.md, CLAUDE.md, CONTRIBUTING.md,
  SECURITY.md, CODE_OF_CONDUCT.md, VERSION, LICENSE

docs/ (required):
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
