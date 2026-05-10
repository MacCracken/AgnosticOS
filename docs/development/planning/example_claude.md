# {Project} — Claude Code Instructions

> **Template**: copy to a new repo as `CLAUDE.md` and fill in the `{placeholders}`. Reference implementation: [cyrius/CLAUDE.md](https://github.com/MacCracken/cyrius/blob/main/CLAUDE.md) (CLAUDE.md gold standard — durable content only). Structure per [first-party-documentation.md § CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md#claudemd).
>
> **Core rule**: this file is **preferences, process, and procedures** — durable rules that change rarely. Volatile state (current version, binary sizes, test counts, in-flight work, consumers, verification hosts) lives in [`docs/development/state.md`](docs/development/state.md), bumped every release. Do not inline state here — inlined state rots within a minor.

---

## Project Identity

**{Project}** ({language}: {meaning}) — {one-line description}

- **Type**: Shared library / Binary / Workspace / Compiler / Application
- **License**: GPL-3.0-only (or AGPL-3.0-only for desktop GUIs)
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`, currently `{X.Y.Z}`)
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)
- **Shared crates**: [shared-crates.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/shared-crates.md)

## Goal

{One-or-two-sentence mission statement. What does this project OWN in the stack? Durable — doesn't change per release.}

Example shape: "Own the database. Zero deps. Pure Cyrius. SQL + B-tree + JSONL in a single `include`."

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, binary sizes, test/assertion counts, in-flight slots, recent
> shipped releases, consumers, verification hosts, bootstrap chain. Refreshed
> every release (ideally bumped by the release post-hook).
> Historical release narrative lives in
> [`docs/development/completed-phases.md`](docs/development/completed-phases.md).

This file (`CLAUDE.md`) is durable rules. See [first-party-documentation § CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md#claudemd) for what belongs where.

## Scaffolding

Project was scaffolded with `cyrius init {project}` (new) or `cyrius port /path/to/rust-project` (ported). **Do not manually create project structure** — use the tools. If the tools are missing something, fix the tools.

## Quick Start

```bash
cyrius build src/main.cyr build/{project}       # build
cyrius test src/test.cyr                         # unit tests
cyrius bench tests/{project}.bcyr                # benchmarks (where applicable)
cyrius fuzz fuzz/                                # fuzz harnesses (where applicable)
cyrius lint src/*.cyr                            # static checks
cyrius audit                                     # full check: self-host, test, fmt, lint
CYRIUS_DCE=1 cyrius build ...                    # dead-code-eliminated release build
```

## Key Principles

- **Correctness is the optimum sovereignty** — if it's wrong, you don't own it; the bugs own you
- Test after EVERY change, not after the feature is "done"
- ONE change at a time — never bundle unrelated changes
- Research before implementation — check vidya for existing patterns
- Study working programs (`cyrius/programs/*.cyr`) before writing new code
- Programs call `main()` at top level: `var exit_code = main(); syscall(60, exit_code);`
- **Build with `cyrius build`, never raw `cat file | cc5`** — the manifest auto-resolves deps and prepends includes
- Source files only need project includes — stdlib / external deps auto-resolve from `cyrius.cyml`
- Every buffer declaration is a contract: `var buf[N]` = N **bytes**, not N entries
- Fuzz every parser path — edge cases get invariants, not assertions
- Benchmark before claiming perf — numbers or it didn't happen
- {Add project-specific principles here — e.g. "own the stack", "no magic", "self-hosting is non-negotiable"}

## Rules (Hard Constraints)

- **Read the genesis repo's CLAUDE.md first** — [agnosticos/CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to the GitHub API if needed
- Do not add unnecessary dependencies
- Do not skip tests before claiming changes work
- Do not skip fuzz / benchmark verification before claiming a feature works
- Do not use `sys_system()` with unsanitized input — command injection risk
- Do not trust external data (file content, network input, user args) without validation
- Do not use `break` in while loops with `var` declarations — use flag + `continue`
- Do not add Cyrius stdlib includes in individual src files — the manifest resolves them
- Do not hardcode toolchain versions in CI YAML — the `cyrius = "X.Y.Z"` pin in `cyrius.cyml` is the only source of truth
- {Add project-specific constraints here}

## Process

### P(-1): Scaffold / Project Hardening (before any new features)

1. **Cleanliness** — `cyrius build`, `cyrius lint`, `cyrius audit`; all tests pass
2. **Benchmark baseline** — `cyrius bench`, save CSV for comparison
3. **Internal deep review** — gaps, optimizations, correctness, docs
4. **External research** — domain completeness, best practices, existing CVE patterns
5. **Security audit** — input handling, syscall usage, buffer sizes, pointer validation. File findings in `docs/audit/YYYY-MM-DD-audit.md`
6. **Additional tests / benchmarks** from findings
7. **Post-review benchmarks** — prove the wins against step 2
8. **Documentation audit** — ADRs for decisions made during hardening, source citations, guides for public API
9. **Repeat if heavy** — keep drilling until clean

### Work Loop (continuous)

1. **Work phase** — new features, roadmap items, bug fixes
2. **Build check** — `cyrius build`
3. **Test + benchmark additions** for new code
4. **Internal review** — performance, memory, correctness, edge cases
5. **Security check** — any new syscall usage, user input handling, buffer allocation
6. **Documentation** — update CHANGELOG, roadmap, `docs/development/state.md`, any ADR the change earned
7. **Version check** — `VERSION`, `cyrius.cyml`, CHANGELOG header in sync
8. **Return to step 1**

### Security Hardening (before every release)

Every project runs a security audit pass before release — see [first-party-standards § Security Hardening](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md#security-hardening-new--required-before-every-release) for the full list. Minimum:

1. **Input validation** — every function accepting external data validates bounds, types, ranges
2. **Buffer safety** — every `var buf[N]` verified; N is **bytes**, max access < N, no adjacent-variable overflow
3. **Syscall review** — every syscall validated: args checked, returns handled, error paths complete
4. **Pointer validation** — no raw pointer dereference of untrusted input without bounds
5. **No command injection** — use `exec_vec()` with explicit argv; never `sys_system()` with unsanitized input
6. **No path traversal** — file paths from external input validated, no `../` escape
7. **Known CVE review** — check dependencies and patterns against current CVE databases
8. **Document findings** — all issues in `docs/audit/YYYY-MM-DD-audit.md`

Severity levels: **CRITICAL** (remote / privilege escalation), **HIGH** (moderate effort), **MEDIUM** (specific conditions), **LOW** (defense-in-depth).

### Closeout Pass (before every minor/major bump)

Run a closeout pass before tagging `X.Y.0` or `X.0.0`. Ship as the last patch of the current minor (e.g. `2.2.5` before `2.3.0`).

1. **Full test suite** — all `.tcyr` pass, zero failures
2. **Benchmark baseline** — `cyrius bench`, save CSV; compare against prior closeout
3. **Dead code audit** — remove unused functions; record remaining floor in CHANGELOG
4. **Refactor pass** — consolidate the minor's additions where parallel codepaths / dispatch branches accreted
5. **Code review pass** — walk diffs end-to-end for missed guards, ABI leaks, off-by-ones, silently-ignored errors
6. **Cleanup sweep** — stale comments, dead `#ifdef` branches, unused includes, orphaned files
7. **Security re-scan** — quick grep for new `sys_system`, unchecked writes, unsanitized input, buffer size mismatches
8. **Downstream check** — all consumers on `state.md` still build and pass tests against the new version
9. **Doc sync** — CHANGELOG, roadmap, `docs/development/state.md`, CLAUDE.md (if durable content changed)
10. **Version verify** — `VERSION`, `cyrius.cyml`, CHANGELOG header, intended git tag all match
11. **Full build from clean** — `rm -rf build && cyrius deps && CYRIUS_DCE=1 cyrius build` passes clean

### Task Sizing

- **Low/Medium effort**: batch freely — multiple items per work loop cycle
- **Large effort**: small bites only — break into sub-tasks, verify each before moving to the next
- **If unsure**: treat it as large

### Refactoring Policy

- Refactor when the code tells you to — duplication, unclear boundaries, measured bottlenecks
- Never refactor speculatively. Wait for the third instance
- Every refactor must pass the same test + fuzz + benchmark gates as new code
- 3 failed attempts = defer and document — don't burn time in a rabbit hole

## Cyrius Conventions

- All struct fields are 8 bytes (`i64`), accessed via `load64` / `store64` with offset
- Heap allocation via `fl_alloc()` / `fl_free()` (freelist) for data with individual lifetimes
- Bump allocation via `alloc()` for long-lived data (vec, str internals)
- Enum values for constants — don't consume `gvar_toks` slots (256 initialized globals limit)
- Heap-allocate large buffers — `var buf[256000]` bloats the binary by 256KB
- `break` in while loops with `var` declarations is unreliable — use flag + `continue`
- No negative literals — write `(0 - N)` not `-N`
- No mixed `&&` / `||` in one expression — nest `if` blocks instead
- `match` is reserved — don't use as a variable name
- `return;` without value is invalid — always `return 0;`
- All `var` declarations are function-scoped — no block scoping
- Max limits per compilation unit: 4,096 variables, 1,024 functions, 256 initialized globals

## CI / Release

- **Toolchain pin**: `cyrius = "X.Y.Z"` field in `cyrius.cyml [package]`. **No separate `.cyrius-toolchain` file.** CI and release both read this; no hardcoded version strings in YAML.
- **Dead code elimination**: every `cyrius build` in CI and release runs with `CYRIUS_DCE=1`. Binary size is a release metric — track it.
- **Tag filter**: release workflow triggers on `tags: ['[0-9]*']` — semver-only. Non-numeric tags do not ship a release.
- **Version-verify gate**: release asserts `VERSION == cyrius.cyml version == git tag` before building. Mismatch fails the run.
- **Lint step**: CI runs `cyrius lint` per source file. Advisory by default; projects may escalate to blocking.
- **Workflow layout**:
  - `.github/workflows/ci.yml` — build, lint, test, fuzz, bench, integration; reusable via `workflow_call`
  - `.github/workflows/release.yml` — version gate → CI gate → DCE build → artifacts (source tarball, bundled single-file `.cyr`, DCE binary, SHA256SUMS)
- **Concurrency**: CI uses `cancel-in-progress: true` keyed on workflow + ref — only the latest push is tested.
- **State sync**: release post-hook bumps `docs/development/state.md`. If the hook doesn't, fix the hook — don't hand-maintain state.

## Docs

- [`docs/adr/`](docs/adr/) — architecture decision records. *Why did we choose X over Y?*
- [`docs/architecture/`](docs/architecture/) — non-obvious constraints and quirks. *What can't I derive from the code alone?*
- [`docs/guides/`](docs/guides/) — task-oriented how-tos. *How do I do X?*
- [`docs/examples/`](docs/examples/) — runnable examples.
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — completed, backlog, future, v1.0 criteria.
- [`docs/development/state.md`](docs/development/state.md) — **live state snapshot, refreshed every release**.
- [`CHANGELOG.md`](CHANGELOG.md) — source of truth for all changes.

New quirks and constraints land in `docs/architecture/` as numbered items (`NNN-kebab-case.md`). New decisions land in `docs/adr/` using [`template.md`](docs/adr/template.md). **Never renumber either series.**

Full doc-tree convention: [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md).

## Documentation Structure

```
Root files (required):
  README.md, CHANGELOG.md, CLAUDE.md, CONTRIBUTING.md,
  SECURITY.md, CODE_OF_CONDUCT.md, LICENSE,
  VERSION, cyrius.cyml

docs/ (minimum):
  adr/ — architectural decision records (README + template.md + NNNN-*.md)
  architecture/ — non-obvious invariants (README + NNN-*.md)
  guides/ — task-oriented how-tos
  examples/ — runnable examples
  development/
    roadmap.md — completed, backlog, future
    state.md — live state snapshot (volatile; release-hook-bumped)

docs/ (when earned):
  audit/ — security audit reports (YYYY-MM-DD-audit.md)
  sources/ or sources.md — academic/domain citations (required for science/math crates)
  proposals/ — pre-ADR design drafts
  api/ — curated public-surface reference
  benchmarks.md — perf history
  standards/, compliance/, faq.md — as applicable
```

## .gitignore (Required)

```gitignore
# Build
/build/
/dist/

# Resolved deps (auto-generated by cyrius deps)
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

Follow [Keep a Changelog](https://keepachangelog.com/). Performance claims **must** include benchmark numbers. Breaking changes get a **Breaking** section with migration guide. Security fixes get a **Security** section with CVE references where applicable. See [first-party-documentation § CHANGELOG](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md#changelog) for the full conventions.
