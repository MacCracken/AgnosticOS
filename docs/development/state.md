---
name: AGNOS Ecosystem State
description: Live cross-repo state — Cyrius cycle, pin-lag spectrum, active sweeps, carry-forward debt
type: state
---

# AGNOS Ecosystem — Current State

> **Cyrius toolchain**: 5.10.24 | **Cycle**: v5.10.x — REAL TYPE SYSTEM arc (active; opened 2026-05-08 with profiling instrumentation, pivoted at 5.10.5 to type-vocabulary work)
> **Last refresh**: 2026-05-09 | **Refresh cadence**: bundle with each v5.10.x patch close, full sweep when minor cuts
> **Crate registries** (versions + roles): [`planning/shared-crates.md`](planning/shared-crates.md) is the full registry (incl. pre-1.0); [`docs/applications/libs/README.md`](../applications/libs/README.md) is the v1.0+ stable subset. This file holds cycle / pin / sweep state only.

This doc holds **volatile state** — what's currently true across the AGNOS dev surface. CLAUDE.md is preferences/process/procedures; this is the live picture. Per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md): rewrite in place when state changes; don't preserve historical snapshots — git history is authoritative.

**Drift caveat applies to this doc too** — always verify against actual `VERSION` + `cyrius.cyml`/`cyrius.toml` files before acting on any single item. Repo data was sampled 2026-05-09 from local clones (~46 repos) plus `raw.githubusercontent.com` for the remote tail (avatara, ai-hwaccel, hadara, itihas, takumi, bsp, scaffolded apps).

---

## Cyrius cycle — v5.10.x (active)

**REAL TYPE SYSTEM arc.** Cycle opened 2026-05-08 with v5.10.0 (per-phase compile-time profiling instrumentation as the optimization-arc opener) and pivoted at v5.10.5 into the type-vocabulary work that now defines the cycle: cstring / Result / Option / Tagged annotations on stdlib functions plus call-site type checking. **24 patches in 2 days** (5.10.0 → 5.10.24), velocity comparable to v5.8.x's 66-in-4-days but on tighter scope.

### v5.9.x retrospective (closed 2026-05-08 at 5.9.43)

Catchup + niyama-fold cycle, **44 patches** (5.9.0 → 5.9.43, 2026-05-06 → 2026-05-08). v5.9.0 shipped the niyama fold-in (8th sibling distfile, 6,664 lines, 7 regex modules vendored byte-identical from niyama 1.0.1). The remainder ran consumer-rollup against the pin-lag tail and optimization-debt closeout. Pin-lag bands collapsed materially: agnosys exited the held-cluster, vyakarana exited the deep-lag tail, sandhi/agnostik/owl/cyim all rolled to 5.10.x, vidya bumped to 2.7.0 with content refresh. Bare-metal slot deferred again — see v5.12.x reservation below.

### v5.10.x slot list — in-flight scope

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Per-phase compile-time profiling instrumentation | ✅ v5.10.0 | 7 phase timestamps gated on `CYRIUS_PROF=1`; ~0.7 µs total overhead |
| 2 | REAL TYPE SYSTEM Phase 1 — type vocabulary (cstring / Result / Option / Tagged) | ✅ v5.10.5 | Vocabulary additions, no enforcement yet (false-positive flood discovered) |
| 3 | REAL TYPE SYSTEM Phase 2 — call-site type checking | ✅ v5.10.24 | Per-fn param-type bitmasks; canonical motivator stdlib fns annotated |
| 4 | REAL TYPE SYSTEM Phase 3+ — remaining phases of 5-phase arc | 🔄 In-flight | Phases 3–5 scope per cycle planning |
| 5 | TLS items batch (5.10.21 — *"remaining tls items missing from first batch"*) | ✅ v5.10.21 | Pre-pivot batch closeout |
| 6 | cyim → niyama integration verification | ✅ Done | `cyim/src/main.cyr:51` includes `lib/niyama.cyr` directly |

### v5.10.x cc5 cut state

cc5 at **783,408 B** (up from 741,048 B at v5.9.0 — net +42,360 B from profiling instrumentation, type-vocabulary additions, call-site checking machinery). Self-host two-step byte-identical confirmed at v5.10.24.

### v5.11.x reservation — TS testing suite + bug sweeping

The v5.11.x cycle is reserved for **type-system testing suite** plus **bug sweeping** of items surfaced by the agnosys agent's repo-update sweep — that work dragged up a meaningful debt list across the ecosystem. Focus is consolidation, not new features.

### v5.12.x reservation — bare-metal + RISC-V rv64

Bare-metal AGNOS target + RISC-V rv64 backend now slot at **v5.12.x**. Slipped: v5.8.x → v5.10.x → v5.11.x → **v5.12.x**. The v5.10.x type-system work is partial prerequisite (call-site checking helps catch ABI mismatches before they reach a foreign target); v5.11.x's testing-suite work is the rest.

### Genuinely dangling — carry-forward into v5.11.x triage

| # | Item | Domain | Notes |
|---|------|--------|-------|
| 1 | `cyrlint` multi-line assert | Tooling | Investigated v5.8.41; couldn't reproduce on 4 synthetic tests. Decide: close as moot, or pin a real reproduction case |
| 2 | `ESTORESTACKPARM` stub | Language | Explicitly **held** ("TODOs in src/: 1, held") — needs unhold-or-resolve decision |
| 3 | Optimization arc O3–O6 audit | Compiler | Partial follow-on shipped (O3a IR / O4a–c regalloc / O5 / O6 codebuf) — needs status sweep against v5.6.x deferral list to identify what's still open |
| 4 | Consumer rollup — pre-CYML format tail | Ecosystem | 11 repos still on `cyrius.toml` at v3.x–v4.x (avatara, ai-hwaccel, hadara, itihas, hoosh, kavach, agnoshi, nein, bote, t-ron, shravan); format migration + pin bump |
| 5 | Consumer rollup — deep-lag tail | Ecosystem | ark (5.1.10), libro (5.4.7), majra (5.4.17), bsp (5.5.2), takumi (5.5.23), yantra (5.6.17) |
| 6 | Consumer rollup — v5.7.48 held cluster (4 repos remaining) | Ecosystem | phylax, mabda, cyrius-doom, samvada — agnosys exited at v5.10.19 |
| 7 | Bare-metal readiness — v5.12.x prereqs | Compiler/runtime | Surface what's needed for clean v5.12.0 bare-metal target open |
| 8 | RISC-V rv64 readiness — v5.12.x prereqs | Compiler/backend | rv64 backend slipped 7+ times; current minimum to land cleanly |

---

## Pin-lag spectrum

Each repo's `cyrius = "X.Y.Z"` pin (verified 2026-05-09). Bundle pin-bumps to v5.10.x with each repo's natural next patch — don't force a rebuild slot just for the sweep. **Eleven repos still on `cyrius.toml`** (pre-`.cyml` format) with v3.x–v4.x pins — these need format migration *and* pin bump.

```
PRE-CYML format (cyrius.toml, v3.x–v4.x — needs format migration):
  v3.x:    avatara (3.10.0), ai-hwaccel (3.10.0), hadara (3.7.0)
  v4.x:    itihas (4.0.0), hoosh (4.5.0), kavach (4.5.0), agnoshi (4.5.0),
           nein (4.5.0), bote (4.8.4), t-ron (4.8.4), shravan (4.10.3)

CYML format:
  v5.1.x:  ark (5.1.10)                              ← extreme lag, port pre-dates pin convention
  v5.4.x:  libro (5.4.7), majra (5.4.17)
  v5.5.x:  bsp (5.5.2), takumi (5.5.23)              ← takumi: rust-old/ authoritative until parity
  v5.6.x:  yantra (5.6.17)
           cyrius-stellar-swarm (5.6.26),
           cyrius-sunset-drive (5.6.26),
           cyrius-super-plumber-twins (5.6.26),
           cyrius-grapevine (5.6.29),
           cyrius-chellys-beach-adventure (5.6.29-1)
  v5.7.x:  argonaut (5.7.5), cyrius-brynns-tale (5.7.9), hisab (5.7.10),
           cyrius-bb (5.7.11), kybernet (5.7.12), agnova (5.7.12),
           daimon (5.7.12), agnos (5.7.22), abaco (5.7.23),
           nous (5.7.29), bazaar (5.7.30), shakti (5.7.33)
  v5.7.48: phylax, mabda, cyrius-doom, samvada       ← held-cluster (was 5; agnosys exited)
  v5.8.x:  patra (5.8.64), sakshi (5.8.64), sigil (was 5.8.64 → 5.9.20),
           vani (5.8.64), yukti (5.8.64), sankoch (5.8.64),
           niyama (5.8.65)                            ← warm cluster
  v5.9.x:  sit (5.9.37), vidya (5.9.43)              ← v5.9.x cluster
  v5.10.x: aegis (5.10.0), vyakarana (5.10.5),
           cyim (5.10.10), cyim-lsp (5.10.10), owl (5.10.10),
           agnostik (5.10.14), agnosys (5.10.19),
           chakshu (5.10.20), darshana (5.10.20),
           sandhi (5.10.21)                           ← live cluster on current toolchain

NO PIN field (file exists, field missing): aegis (was — now pinned), aethersafha,
                                            aethersafta, kiran*, joshua, salai,
                                            mela, seema, samay, murti, tanur,
                                            encom-hits, cyrius-nba-jam
                                            * kiran shipped to 1.0.0; pin field
                                              still pending population
```

**Bands of attention (refreshed 2026-05-09):**
- The **v5.10.x live cluster** (10 repos) is on or one patch behind the active toolchain — these are the leading edge.
- The **v5.9.x cluster** (sit, vidya) caught the v5.9.x cycle but didn't roll into v5.10.x — natural-patch bumps will pick them up.
- The **v5.8.x warm cluster** (7 repos) tracked Phase 3 to closeout; needs a v5.10.x rollup.
- The **v5.7.48 held cluster** is now **4 repos** (phylax, mabda, cyrius-doom, samvada) — investigate per repo whether content held them or just bandwidth. Agnosys exited the cluster during v5.9.x's catchup arc.
- The **pre-CYML format tail** (11 repos, 3.x–4.x pins) is the largest debt — these missed both the format migration AND every v5.x pin since.
- The **deep-lag tail** (ark 5.1.10, libro 5.4.7, majra 5.4.17, bsp 5.5.2, takumi 5.5.23, yantra 5.6.17) didn't roll forward and may carry latent breakage against current stdlib. **vyakarana exited at 5.10.5.**
- The **scaffolded apps** (kiran, joshua, salai, etc.) lack pin fields entirely — add during their first real-implementation patch. **kiran shipped 1.0.0** — still missing pin field, worth populating.

### New repos since last refresh

| Repo | Version | Pin | Notes |
|------|---------|-----|-------|
| **aegis** | 0.8.2 | 5.10.0 | Out of "0.1.0 scaffold" — real implementation underway |
| **chakshu** | 0.2.0 | 5.10.20 | AI-augmented system monitor (`shu` binary) — past initial scaffold |
| **cyim-lsp** | 1.5.0 | 5.10.10 | LSP server companion to cyim |
| **darshana** | 0.2.0 | 5.10.20 | **NEW**: TTY/raw-mode primitives library (दर्शन — viewing/showing). Extracted from cyim's `src/tty.cyr` once chakshu became a second consumer. Not a TUI framework — just termios + ANSI + cursor positioning |

---

## Active sweeps

### Niyama fold-in (v5.9.0 downstream sweep)

Fresh sibling-fold per niyama ADR 0011. Pattern parallels sandhi-fold (v5.7.0) and vani-fold (v5.8.0).

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (cyim is #1 multi-consumer gate; bare-metal kernel queued #2) | ✅ Done at v5.9.0 |
| 2 | In-tree fixture migration if needed | ✅ N/A — no fixtures touched |
| 3 | cyim → niyama integration verification (regex sweep) | ✅ Done — `cyim/src/main.cyr:51` includes `lib/niyama.cyr` directly |
| 4 | Document the niyama-fold pattern alongside sandhi/vani-fold in `design-patterns.md` | [ ] Pending |
| 5 | Niyama-fold-in article slot | [ ] Subsumed by [*What Justifies a Stdlib Foldin*](../articles/what-justifies-a-stdlib-foldin.md) — per-fold piece optional |

### Vani audio distlib fold-in (v5.8.0 downstream sweep)

Per [`vani/docs/development/cyrius-stdlib-fold-in.md`](https://github.com/MacCracken/vani/blob/main/docs/development/cyrius-stdlib-fold-in.md). Pattern parallels v5.7.0 sandhi fold.

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (`grep -rn "include.*lib/audio.cyr"` across ecosystem) | ✅ Done at v5.8.0 — zero hits |
| 2 | In-tree fixture migration (3 preprocessor-cap regression tests) | ✅ Done in cyrius repo at v5.8.0 |
| 3 | Document the fold-in pattern alongside sandhi-fold in `design-patterns.md` | ❌ Still pending (now subsumed by fold-in article) |
| 4 | Vani-fold-in article (parallels sandhi-fold article slot) | ❌ Still pending (now subsumed) |

### v5.7.x → v5.8.x → v5.9.x → v5.10.x debt carry-forward

Status verified 2026-05-09.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | yantra orphan `lib/http_server.cyr` delete | ❌ Pending | File still present at `yantra/lib/http_server.cyr`; cleanup-only, no callers. yantra still at 5.6.17. |
| 2 | sit orphan `lib/http_server.cyr` delete | ✅ Done | Removed during v5.8.x; sit now at 5.9.37 |
| 3 | vyakarana grammar refresh — index 469 sandhi fns | ❓ Re-verify | vyakarana exited deep-lag at 2.2.1 / 5.10.5 — version moved, content reflection unverified |
| 4 | vidya per-minor refresh (`language.toml` / `dependencies.toml` / `ecosystem.toml`) | ✅ Likely done | vidya now at 2.7.0 / pin 5.9.43 — version-bumped through two minors with active content tree |
| 5 | hoosh / ifran / daimon / mela / ark sandhi-fold audit-confirm | ✅ Confirmed clean | Zero `[deps.sandhi]` and zero include-sandhi refs in any of the five (note: hoosh uses `cyrius.toml`; daimon/ark use `cyrius.cyml`) |

### CVE-2026-31431 (Copy Fail) cleanup + audit

Linux kernel LPE in `algif_aead` (AF_ALG in-place AEAD + `splice()` → 4-byte page-cache write → root). Disclosed 2026-04-29; affects mainline kernels from 2017 onward. Roadmap item **S1**.

**AGNOS-native kernel** (`agnos` v1.26.1): structurally immune — verified at `kernel/core/syscall.cyr:32-36`, 26-syscall table contains no `socket`, no `splice`, no AF_ALG family. Bug class is unreachable.

| # | Action | Status |
|---|--------|--------|
| 1 | Host defconfigs — pin `# CONFIG_CRYPTO_USER_API{,_HASH,_SKCIPHER,_AEAD,_RNG} is not set` in `agnosticos/kernel/{6.6-lts,6.x-stable,7.0-devel}/configs/*defconfig` and `kernel/configs/edge-{deeplens,nuc,rpi4,rpi5}.config` | ❌ Pending — re-verified 2026-05-09: zero `CRYPTO_USER_API` refs in any host defconfig |
| 2 | Audit local crypto-adjacent repos for `AF_ALG` / `algif_aead` refs: sigil, agnosys, phylax | ✅ Done 2026-05-03 — zero hits |
| 3 | Audit when next cloned: kybernet, libro, kavach, shakti, aegis, t-ron, argonaut, ark, agnostik, bote, daimon, hoosh | ❓ Deferred — repos not all local |
| 4 | Once defconfigs pinned, document the absence-by-design pattern alongside other AGNOS-vs-Linux structural-immunity examples in `design-patterns.md` | [ ] |

### Pending Cyrius ports

| Repo | Current state | Action |
|------|---------------|--------|
| **bhava** | 2.0.0 Rust (no `cyrius.cyml` on remote) | Port can start — v5.10.x stdlib + math additions are the gating concern |
| **goonj** | 1.4.3 Rust (Cargo.toml present locally) | Acoustics — port pending |
| **naad** | 1.2.5 Rust (Cargo.toml present locally) | Audio synthesis — port pending |
| **aethersafha** | 0.1.0 scaffold | Real implementation (Wayland compositor) |
| **aethersafta** | 0.50.0 (media compositing scene graph) | Distinct from aethersafha — not a Cyrius port target, near-stable lib |

### Per-repo housekeeping (P1/P2)

Carry-forward from v5.6.x → v5.7.x → v5.8.x → v5.9.x → v5.10.x. None blocking; bundle with each repo's next natural patch.

- **`docs/development/state.md` migration** (this pattern). **Done**: cyrius, owl (2026-04-23), agnosticos (this file), sandhi, sit, vidya. **Pending**: every other repo that still carries volatile state in CLAUDE.md (verified 2026-05-06: kybernet, daimon, agnos, abaco, hoosh, kavach, mabda, sigil all missing; presume similar for the unverified tail).
- **`cyrius.toml` → `cyrius.cyml` format migration** (11 repos): avatara, ai-hwaccel, hadara, itihas, hoosh, kavach, agnoshi, nein, bote, t-ron, shravan. Each migration also re-pins to current toolchain.
- **`[build].modules` → `[lib] modules` migration**: sigil, agnosys, shakti pending. sakshi has `dist/sakshi.cyr` but no `modules` block — investigate generation mechanism.
- **`docs/adr/` scaffold** (12 repos still missing): agnosys, sigil, takumi, phylax, ark, nous, sakshi, yukti, bsp, owl, cyrius-doom, majra. Copy `README.md` + `template.md` from sit; don't back-fill historical decisions.
- **`docs/adrs/` → `docs/adr/` rename**: argonaut last offender.
- **kiran pin-field population** — kiran shipped 1.0.0 but `cyrius.cyml` still lacks `cyrius = "X.Y.Z"`. Worth populating now that it's stable.
- **Crate registry refresh** — both registries are stale against current state. Sweep when next touched.
  - [`planning/shared-crates.md`](planning/shared-crates.md) (full registry, pre-1.0 + v1.0+): bumped 2026-05-09 — agnostik 1.2.0, sigil 3.1.0, vidya 2.7.0, agnosys 1.2.1, owl 1.3.6, vyakarana 2.2.1, sandhi 1.3.0 (folded; standalone repo continues), sit 0.7.6, cyim 1.6.7, niyama 1.0.1, aegis 0.8.2, chakshu 0.2.0; **darshana** + **cyim-lsp** added; **kiran** already at v1.0+. Re-verify on next cycle close.
  - [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ stable subset). Last updated 2026-04-15 — predates three full minors (v5.8 / v5.9 / v5.10).

### CLAUDE.md table refresh

Root [`CLAUDE.md`](../../CLAUDE.md) "Standalone Repos" table also drifted (same pattern as shared-crates.md). When refreshing, prefer pointing to this file or to shared-crates.md rather than re-duplicating versions in CLAUDE.md.

---

## Doc / article update queue

| File | Action |
|------|--------|
| [`roadmap.md`](roadmap.md) | v5.7.x / v5.8.x / v5.9.x phase definitions are now historical; v5.10.x = REAL TYPE SYSTEM arc; v5.11.x = TS testing + bug sweep; v5.12.x = bare-metal + rv64. Re-touch on each v5.10.x ship. |
| [`summer-2026-arc.md`](summer-2026-arc.md) | Cycle-theme references need re-anchoring against v5.10.x type-system framing. |
| [`articles/cyrius-vs-rust-benchmarks.md`](../articles/cyrius-vs-rust-benchmarks.md) | Add v5.9.x and v5.10.x rows; sweep "Pure compute gap" language for closed items |
| [`articles/port-ledger-volume-1.md`](../articles/port-ledger-volume-1.md) | *Where Rust Still Wins* — confirm which categories closed under v5.8.x / v5.9.x / v5.10.x |
| [`articles/doom-in-cyrius.md`](../articles/doom-in-cyrius.md) | v5.10.x rebuild numbers when cyrius-doom ships an unblock release (still on pin 5.7.48) |
| [`articles/sovereign-compiler-vs-brute-force.md`](../articles/sovereign-compiler-vs-brute-force.md) | cc5 size at **783,408 B** (v5.10.24 — was 741,048 B at v5.9.0; +42 KB from profiling instrumentation + type-vocabulary + call-site checking) |
| [`planning/shared-crates.md`](planning/shared-crates.md) | ✅ Refreshed 2026-05-09 (versions bumped, darshana + cyim-lsp added). Re-verify on next cycle close. |
| [`docs/applications/libs/README.md`](../applications/libs/README.md) | Bump versions for v1.0+ subset; "Last Updated 2026-04-15" predates three minors |
| [`planning/first-party-documentation.md`](planning/first-party-documentation.md) | Re-read at each v5.10.x patch — meta-irony from *Docs Go Stale Before the Commit* |
| [`planning/first-party-standards.md`](planning/first-party-standards.md) | ✅ Refreshed 2026-05-09 — full Cyrius-first rewrite; Rust-era archive at `docs/archive/first-party-standards-rust-era.md` |
| **NEW** ✅ [*What Justifies a Stdlib Foldin*](../articles/what-justifies-a-stdlib-foldin.md) | Shipped 2026-05-06 — meta-process article covering the gate framework, anti-criteria, mechanism, and three-instance pattern across sandhi/vani/niyama. Subsumes per-instance article slots. |
| **NEW** ✅ Phase-3-stdlib-foldin retrospective | Landed 2026-05-06 in vidya at `content/cyrius/field_notes/compiler/retros/foldin_arc_v57_v59.cyml`. Companion to *what-justifies-a-stdlib-foldin* (process) — the retro is the experiential ledger. |
| **NEW** [*REAL TYPE SYSTEM in 24 patches*] (working title) | v5.10.x retro candidate — opens with profiling instrumentation, pivots at 5.10.5 to type-vocabulary work, Phase 2 closes 5.10.5 false-positive flood. Wait for cycle close before drafting. |
| **NEW** ✅ darshana extraction note | When darshana ships 1.0.0, document the cyim-private → shared-library extraction pattern (single-consumer-private → second-consumer-triggers-extraction) alongside other extraction examples. |

---

## Refresh procedure

When a v5.10.x patch closes:

1. Pull current `VERSION` + `cyrius.cyml`/`cyrius.toml` for affected repos
2. Update the pin-lag spectrum if any repo crossed a band
3. Tick off swept items
4. Re-anchor "Last refresh" date in the header
5. Re-anchor "Cyrius toolchain" if a new minor cut

When v5.10.x cycle closes:

1. Move v5.10.x slot list closeout summary into a brief retrospective (one paragraph)
2. Repoint all `5.9.x` / `5.10.x` references to whichever cycle is next (likely v5.11.x — TS testing suite)
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

*Refreshed 2026-05-09 (v5.10.24 day, mid-cycle). Rewrite-in-place as state changes. v5.9.x history captured here is closeout-context only — Cyrius CHANGELOG is the receipt.*
