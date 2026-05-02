---
name: AGNOS Ecosystem State
description: Live cross-repo state — Cyrius cycle, pin-lag spectrum, active sweeps, carry-forward debt
type: state
---

# AGNOS Ecosystem — Current State

> **Cyrius toolchain**: 5.8.0 | **Cycle**: v5.8.x — optimization, math, language fixes
> **Last refresh**: 2026-05-01 | **Refresh cadence**: bundle with each v5.8.x patch close
> **Crate registries** (versions + roles): [`applications/shared-crates.md`](applications/shared-crates.md) is the full registry (incl. pre-1.0); [`docs/applications/libs/README.md`](../applications/libs/README.md) is the v1.0+ stable subset. This file holds cycle / pin / sweep state only.

This doc holds **volatile state** — what's currently true across the AGNOS dev surface. CLAUDE.md is preferences/process/procedures; this is the live picture. Per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md): rewrite in place when state changes; don't preserve historical snapshots — git history is authoritative.

**Drift caveat applies to this doc too** — always verify against actual `VERSION` + `cyrius.cyml` files before acting on any single item. Repo data was sampled 2026-05-01 from local clones (15 repos) and `raw.githubusercontent.com` (27 repos).

Supersedes `v5.7.x-post-fold-checklist.md` (deleted 2026-05-01 — git history is the reference).

---

## Cyrius cycle — v5.8.x

The **true optimization cycle**. Prior cycles:

- **v5.6.x** opened the optimization arc (O1 instrumentation + FNV-1a hashing; O2 strength reduction + commutative-combine-shuttle; regalloc default-on linear-scan) but closed at v5.6.45 with O3–O6 deferred.
- **v5.7.x** ended up sandhi-fold + cyrius-ts P1–P10 + 51 patches across 36 days. RISC-V rv64 slid 7 times (v5.7.7→v5.7.13→v5.7.30s→deferred). Optimization work was incidental.
- **v5.8.x** is positioned explicitly as "optimization + bug-fix theme" per the v5.8.0 CHANGELOG. Math + language correctness fixes anchor the slot list.

**Soft backstop**: ~.44 patches (firm preference; v5.7.x's 51 was the high-water mark).

**Deferred to v5.9.x**: bare-metal target, RISC-V rv64 backend.

### v5.8.0 cut state

cc5 at **720,928 B** (net unchanged from v5.7.50). Three things shipped:

- **fmt sweep** — 24 first-party files reformatted to canonical `cyrius fmt` output. 1 skip (`lib/sandhi.cyr`, vendored byte-identical). 1 deferred (`src/frontend/ts/parse.cyr` at 195KB, awaits the 128KB output cap raise).
- **Vani audio distlib fold-in** — `lib/audio.cyr` removed, `dist/vani.cyr` (76KB, vani 0.9.1) added. Pre-flight grep confirmed zero external consumers; 3 in-tree fixtures migrated. Parallels the v5.7.0 sandhi fold pattern.
- **Cyriusly starship.toml prompt rework** — new format: `ॐ <pkg-name> <pkg-version> (<repo>) | 🌀 <toolchain-version>`. 🌀 cyclone (U+1F300) replaces `𝕮` as primary; `𝕮` retained as documented ASCII fallback for emoji-hostile terminals. ॐ Om (U+0950) marks Cyrius packages, distinguishing from rust 📦 / go gopher / python snake.

### v5.8.x slot list (12 deferred items from pre-5.8.0 audit)

| # | Item | Domain | Notes |
|---|------|--------|-------|
| 1 | `lint`/`fmt` 128KB output cap raise | Tooling | Blocks the `ts/parse.cyr` fmt sweep deferred from v5.8.0 |
| 2 | `f64_log2` polyfill | Math | Numerics surface |
| 3 | `sys_stat` / `fstat` backfill | Stdlib syscalls | Continues the v5.7.35 syscall-surface-gaps work |
| 4 | `_SC_ARITY` pass | Language | Correctness |
| 5 | NI-class dupe investigation | Stdlib | Drift audit |
| 6 | Preprocessor include-pattern | Language | Fixes |
| 7 | Vidya audit | Downstream consumer | |
| 8 | `var X;` error message | Language ergonomics | |
| 9 | `cyrlint` multi-line assert | Tooling | |
| 10 | `cyim` regex | Tooling | |
| 11 | `cyrius fmt --check` exit code | Tooling | |
| 12 | `ESTORESTACKPARM` stub | Language | Correctness |

Plus carry-forward closeout from v5.7.50:

- `build/cyrc_check` orphan delete
- `cc5_aarch64` packaging fix — move back under `bin/` in `install.sh` and release tarball

---

## Pin-lag spectrum

Each repo's `cyrius = "X.Y.Z"` pin in its `cyrius.cyml` (verified 2026-05-01). Bundle pin-bumps to v5.8.x with each repo's natural next patch — don't force a rebuild slot just for the sweep.

```
v5.1.x:  ark (5.1.10)                       ← extreme lag, port pre-dates pin convention
v5.4.x:  libro (5.4.7)
v5.5.x:  bsp (5.5.2), takumi (5.5.23)        ← takumi: rust-old/ authoritative until parity
v5.6.x:  vyakarana (5.6.0), yantra (5.6.17),
         sandhi (5.6.41 — maintenance per ADR 0002)
v5.7.0:  vidya (5.7.0)                      ← migrated to lib/sandhi.cyr at v5.7.0
v5.7.x:  argonaut (5.7.5), hisab (5.7.10),
         kybernet (5.7.12), agnostik (5.7.12),
         daimon (5.7.12), owl (5.7.12),
         agnos (5.7.22), abaco (5.7.23),
         nous (5.7.29), shakti (5.7.33)
v5.7.48: agnosys, sigil, phylax, sakshi, patra, yukti, mabda,
         sankoch, vani, cyrius-doom, samvada     ← end-of-cycle cluster
no pin:  hoosh, avatara, ai-hwaccel, bote, t-ron, itihas,
         shravan, hadara, kavach, agnoshi
         (cyrius.cyml predates the top-level `cyrius =` field;
          add during their next patch)
```

The v5.7.48 cluster (11 repos) is the natural "warm" group — they tracked the v5.7.x cycle to closeout. The pre-v5.7.x tail (libro, ark, takumi, bsp, vyakarana, sandhi, yantra) needs individual attention; they didn't roll forward and may carry latent breakage against current stdlib.

---

## Active sweeps

### Vani audio distlib fold-in (v5.8.0 downstream sweep)

Per [`vani/docs/development/cyrius-stdlib-fold-in.md`](https://github.com/MacCracken/vani/blob/main/docs/development/cyrius-stdlib-fold-in.md). Pattern parallels the v5.7.0 sandhi fold.

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (`grep -rn "include.*lib/audio.cyr"` across ecosystem) | ✅ Done at v5.8.0 — zero hits |
| 2 | In-tree fixture migration (3 preprocessor-cap regression tests) | ✅ Done in cyrius repo at v5.8.0 |
| 3 | Document the fold-in pattern alongside sandhi-fold in `design-patterns.md` | [ ] |
| 4 | Vani-fold-in article (parallels sandhi-fold article slot) | [ ] |

### v5.7.x debt carry-forward

Items that did not ship during v5.7.x — verify before acting (the original checklist was never rewritten in place during the cycle, so unchecked boxes there may or may not reflect actual state).

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | yantra orphan `lib/http_server.cyr` delete | ❌ Pending | Confirmed present in `yantra/lib/`; cleanup-only, no callers |
| 2 | sit orphan `lib/http_server.cyr` delete | ❓ Unverified | sit not cloned locally; check via raw.githubusercontent |
| 3 | vyakarana grammar refresh — index 469 sandhi fns | ❌ Pending | vyakarana stuck at 1.0.2 / pin 5.6.0; coordinate with owl colorizer work |
| 4 | vidya per-minor refresh (`language.toml` / `dependencies.toml` / `ecosystem.toml`) | ❓ Pending verification | vidya at 2.3.0 / pin 5.7.0 — check whether tomls reflect post-fold ecosystem |
| 5 | hoosh / ifran / daimon / mela / ark sandhi-fold audit-confirm | ❓ Unverified | v5.7.0 audit said no `[deps.sandhi]` and no `include`; re-confirm |

### Pending Cyrius ports

| Repo | Current state | Action |
|------|---------------|--------|
| **bhava** | 2.0.0 Rust | Port can start — v5.8.x stdlib + math additions are the gating concern |
| **aegis** | 0.1.0 scaffold | Real implementation |
| **aethersafha** | 0.1.0 scaffold | Real implementation (Wayland compositor) |

### Per-repo housekeeping (P1/P2)

Carry-forward from v5.6.x → v5.7.x → v5.8.x. None of these are blocking; bundle with each repo's next natural patch.

- **`docs/development/state.md` migration** (this pattern). Done: cyrius, owl (2026-04-23), agnosticos (this file, 2026-05-01), sandhi. Pending: every other repo that still carries volatile state in CLAUDE.md.
- **`[build].modules` → `[lib] modules` migration**: sigil, agnosys, shakti pending. sakshi has `dist/sakshi.cyr` but no `modules` block — investigate generation mechanism.
- **`docs/adr/` scaffold** (12 repos still missing): agnosys, sigil, takumi, phylax, ark, nous, sakshi, yukti, bsp, owl, cyrius-doom, majra. Copy `README.md` + `template.md` from sit; don't back-fill historical decisions.
- **`docs/adrs/` → `docs/adr/` rename**: argonaut last offender.
- **Crate registry refresh** — both registries are stale against current state. Sweep when next touched.
  - [`applications/shared-crates.md`](applications/shared-crates.md) (full registry, pre-1.0 + v1.0+): sigil 2.9.3→3.0.0, mabda 2.5.0→3.0.0-rc.2, sakshi 2.1.0→2.2.2, agnos 1.22.0→1.26.1, sankoch 2.1.0→2.2.3, abaco 2.1.0→2.2.0, phylax 1.0.0→1.1.0, etc.
  - [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ stable subset, "68 crates" — count itself stale; mabda 2.1.2→3.0.0-rc.2, libro 1.0.3→2.0.5, sigil 2.1.2→3.0.0, abaco 2.0.0→2.2.0, hisab 1.4.0→2.2.2, yukti 1.2.0→2.2.1, etc.). Last updated 2026-04-15 — predates the v5.7.x cluster bumps.

### CLAUDE.md table refresh

Root [`CLAUDE.md`](../../CLAUDE.md) "Standalone Repos" table also drifted (same pattern as shared-crates.md). When refreshing, prefer pointing to this file or to shared-crates.md rather than re-duplicating versions in CLAUDE.md.

---

## Doc / article update queue

| File | Action |
|------|--------|
| [`roadmap.md`](roadmap.md) | Re-touch on each v5.8.x ship; v5.7.x phase definitions are now historical |
| [`articles/cyrius-vs-rust-benchmarks.md`](../articles/cyrius-vs-rust-benchmarks.md) | Add v5.8.x rows once optimization-arc patches land; sweep "Pure compute gap" language for closed items |
| [`articles/port-ledger-volume-1.md`](../articles/port-ledger-volume-1.md) | *Where Rust Still Wins* — confirm which categories closed under v5.8.x |
| [`articles/doom-in-cyrius.md`](../articles/doom-in-cyrius.md) | v5.8.x rebuild numbers when cyrius-doom ships an unblock release |
| [`articles/sovereign-compiler-vs-brute-force.md`](../articles/sovereign-compiler-vs-brute-force.md) | cc5 size at 720,928 B (v5.8.0 baseline; net unchanged from v5.7.50) |
| [`applications/shared-crates.md`](applications/shared-crates.md) | Bump versions; re-verify all "v0.x.x" claims (see drift list above) |
| [`docs/applications/libs/README.md`](../applications/libs/README.md) | Bump versions for v1.0+ subset; "Last Updated 2026-04-15" predates the v5.7.x cluster |
| [`applications/first-party-documentation.md`](applications/first-party-documentation.md) | Re-read at each v5.8.x patch — meta-irony from *Docs Go Stale Before the Commit* |
| **NEW** Vani fold-in article | Refusal-as-Architecture instance #2 (sandhi was #1) |
| **NEW** starship.toml prompt convention | ॐ Om + 🌀 cyclone — possibly under `articles/` or `design-patterns.md` |

---

## Refresh procedure

When a v5.8.x patch closes:

1. Pull current `VERSION` + `cyrius.cyml` for affected repos
2. Update the pin-lag spectrum if any repo crossed a band
3. Tick off swept items
4. Re-anchor "Last refresh" date in the header
5. Re-anchor "Cyrius toolchain" if a new minor cut

When v5.8.x cycle closes (target ~.44):

1. Move v5.8.x slot list closeout summary into a brief retrospective
2. Repoint all `5.7.x` / `5.8.x` references to whichever cycle is next
3. Don't archive — rewrite in place. Git history is the snapshot.

---

## Related

- [`CLAUDE.md`](../../CLAUDE.md) — preferences/process/procedures (this doc holds the volatile state CLAUDE.md should NOT carry)
- [`applications/shared-crates.md`](applications/shared-crates.md) — authoritative crate registry (versions + roles)
- [`roadmap.md`](roadmap.md) — Cyrius milestone definitions and timeline
- [Cyrius CHANGELOG](https://github.com/MacCracken/cyrius/blob/main/CHANGELOG.md) — authoritative source for cycle status
- [Articles: *Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md) — the rationale for state.md as a pattern
- [Articles: *Your Docs Are About to Rot*](../articles/your-docs-are-about-to-rot.md) — the broader drift argument
- Per-repo `docs/development/state.md` (where it exists) — source of truth for that repo's local state; verify before acting

---

*Opened 2026-05-01 (v5.8.0 ship day). Rewrite-in-place as state changes. Supersedes `v5.7.x-post-fold-checklist.md`.*
