---
name: AGNOS Ecosystem State
description: Live cross-repo state — Cyrius cycle, pin-lag spectrum, active sweeps, carry-forward debt
type: state
---

# AGNOS Ecosystem — Current State

> **Cyrius toolchain**: 5.9.0 | **Cycle**: v5.9.x — niyama-fold opener; continuing sandhi-pattern stdlib foldins from v5.8.x Phase 3
> **Last refresh**: 2026-05-06 | **Refresh cadence**: bundle with each v5.9.x patch close
> **Crate registries** (versions + roles): [`applications/shared-crates.md`](applications/shared-crates.md) is the full registry (incl. pre-1.0); [`docs/applications/libs/README.md`](../applications/libs/README.md) is the v1.0+ stable subset. This file holds cycle / pin / sweep state only.

This doc holds **volatile state** — what's currently true across the AGNOS dev surface. CLAUDE.md is preferences/process/procedures; this is the live picture. Per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md): rewrite in place when state changes; don't preserve historical snapshots — git history is authoritative.

**Drift caveat applies to this doc too** — always verify against actual `VERSION` + `cyrius.cyml`/`cyrius.toml` files before acting on any single item. Repo data was sampled 2026-05-06 from local clones (~46 repos) and `raw.githubusercontent.com` (remote tail).

---

## Cyrius cycle — v5.9.x

**Catchup + fixes arc.** Pure-Cyrius compiler/stdlib work has run ahead of consumer rollups since v5.7.x; v5.9.x is when the ecosystem catches up to current toolchain and the remaining optimization-debt clears, so v5.10.x can open clean on bare-metal + RISC-V rv64. Prior cycles:

- **v5.6.x** opened the optimization arc (O1 instrumentation + FNV-1a hashing; O2 strength reduction + commutative-combine-shuttle; regalloc default-on linear-scan) but closed at v5.6.45 with **O3–O6 deferred** — partial follow-on shipped through v5.7.x and v5.8.x (O3a IR instrumentation; O4a/b/c register-allocation incl. Poletto-Sarkar linear-scan picker; O5 referenced; O6 codebuf compaction).
- **v5.7.x** ended up sandhi-fold + cyrius-ts P1–P10 + 51 patches across 36 days. RISC-V rv64 slid 7 times. Optimization work was incidental.
- **v5.8.x** ran a **3-phase 66-patch cycle in 4 days** (2026-05-01 → 2026-05-05). Phase 1 (v5.8.1–v5.8.8) closed 8 of the 12 original v5.8.0 audit items + carry-forwards (lint/fmt cap, cc5_aarch64 packaging + cyrc_check orphan, ts/parse.cyr fmt sweep, f64_log2 polyfill, sys_stat/fstat backfill, _SC_ARITY cross-arch gate, NI-class dupe / phylax #4 closeout). Phase 2 (slots 9–26) was the language-vocabulary arc (`var X;` diagnostic, fmt --check exit code, vidya audit pattern at v5.8.40, exhaustive match / Result+? / allocators). Phase 3 (slots 27–65) was the **stdlib foldin sweep** (sandhi-pattern continuation, 27 foldin slots, vani audio at slot 1). Original v5.8.0 plan was bare-metal — slipped to v5.9.0 then to v5.10.x as foldin work compounded.
- **v5.9.x** opens with **niyama fold-in** (slot 1; 8th sibling distfile, 6,664 lines, 5 regex engines: bre / re2 / pcre / fuzzy / vim) — multi-consumer gate met by cyim (#1) + queued AGNOS bare-metal kernel (#2 → v5.10.x trigger). Cycle scope is **catchup + fixes**: consumer-rollup of the pin-lag tail, optimization-debt audit, dangling-item closeout, and bare-metal-readiness work for v5.10.x.

**Soft backstop**: v5.7.x's 51 patches was the duration high-water; v5.8.x's 66-in-4-days was the velocity high-water. v5.9.x cadence TBD — catchup work is per-repo, not per-slot.

**v5.10.x reservation**: AGNOS bare-metal target + RISC-V rv64 backend (both slipped from v5.8.0 / earlier cycles). v5.9.x's job is leaving the ecosystem ready for both.

### v5.9.0 cut state

cc5 at **741,048 B** (net unchanged from v5.8.65 — foldin is `lib/` content only; the compiler binary doesn't include niyama). One thing shipped:

- **`lib/niyama.cyr`** — 6,664-line bundled artifact vendored byte-identical from niyama 1.0.1 `dist/niyama.cyr` (sha256 `4f6bf9fd...4fe06a`). Inlines 7 niyama modules (posix_classes, unicode_props, bre, re2, pcre, fuzzy, vim). Public API frozen per niyama ADR 0010.
- **api-surface snapshot** — 2,725 → 2,760 public fn entries (+35 from niyama). All additions non-breaking per the api-surface gate.
- **Verification** — self-host two-step byte-identical (cc5 → cc5b 741,048 B); check.sh 65/65 green; niyama smoke (re2 compile + search) links and runs from vendored lib.

### v5.9.x slot list — actual scope

The original v5.8.0 12-item slot list largely **shipped during v5.8.x Phase 1–2** (verified against cyrius CHANGELOG 2026-05-06). What remains is genuinely dangling:

**Closeouts from v5.8.0 audit:**

| # | Item | Status | Notes |
|---|------|--------|-------|
| – | `lint`/`fmt` 128KB cap raise | ✅ v5.8.1 | Mabda Class A1 closed |
| – | `cc5_aarch64` packaging + `cyrc_check` orphan | ✅ v5.8.2 | Both carry-forwards closed in same slot |
| – | ts/parse.cyr fmt sweep | ✅ v5.8.3 | |
| – | `f64_log2` polyfill | ✅ v5.8.4–5 | aarch64 polyfill + SSH-gate hardware verification |
| – | `sys_stat` / `fstat` backfill | ✅ v5.8.6 | phylax #2 |
| – | `_SC_ARITY` cross-arch gate | ✅ v5.8.7 | phylax #3 + sakshi |
| – | NI-class dupe investigation | ✅ v5.8.8 | phylax #4 closeout |
| – | Preprocessor include-pattern | ✅ v5.8.x | dated 2026-05-01 |
| – | Vidya audit | ✅ v5.8.40 | "Vidya audit pattern matures" |
| – | `var X;` bare-decl diagnostic | ✅ v5.8.x | Mabda C1 |
| – | `cyrius fmt --check` exit code | ✅ v5.8.x | Mabda A2 |

**Genuinely dangling — v5.9.x candidates:**

| # | Item | Domain | Notes |
|---|------|--------|-------|
| 1 | niyama fold-in | Stdlib | ✅ Shipped v5.9.0 |
| 2 | cyim → niyama integration | Consumer | Multi-consumer gate #1 — verify cyim regex paths now route through niyama |
| 3 | `cyrlint` multi-line assert | Tooling | Investigated v5.8.41; couldn't reproduce on 4 synthetic tests. Decide: close as moot, or pin a real reproduction case |
| 4 | `ESTORESTACKPARM` stub | Language | Explicitly **held** ("TODOs in src/: 1, held") — needs unhold-or-resolve decision |
| 5 | Optimization arc O3–O6 audit | Compiler | Partial follow-on shipped (O3a IR / O4a–c regalloc / O5 / O6 codebuf) — needs status sweep against v5.6.x deferral list to identify what's still open |
| 6 | Consumer rollup — pre-CYML format tail | Ecosystem | 11 repos still on `cyrius.toml` at v3.x–v4.x (avatara, ai-hwaccel, hadara, itihas, hoosh, kavach, agnoshi, nein, bote, t-ron, shravan); format migration + pin bump |
| 7 | Consumer rollup — deep-lag tail | Ecosystem | ark (5.1.10), libro (5.4.7), majra (5.4.17), bsp (5.5.2), takumi (5.5.23), vyakarana (5.6.0), yantra (5.6.17) |
| 8 | Consumer rollup — v5.7.48 held cluster | Ecosystem | agnosys, phylax, mabda, cyrius-doom, samvada — investigate per repo whether content held them or just bandwidth |
| 9 | Bare-metal readiness — v5.10.x prereqs | Compiler/runtime | Surface what's needed for clean v5.10.0 bare-metal target open |
| 10 | RISC-V rv64 readiness — v5.10.x prereqs | Compiler/backend | rv64 backend slipped 7+ times through v5.7.x; what's the current minimum to land it cleanly |

**Status of in-flight optimization phases** (verify before scheduling):

- O3a IR instrumentation — landed v5.6.12 (referenced as pre-existing through v5.8.x)
- O4a/b/c regalloc — Poletto-Sarkar linear-scan picker shipped through v5.8.x (O4b explicit at line 17551 of CHANGELOG)
- O5 — referenced but full status unverified
- O6 codebuf compaction (NOP harvest with jump+fixup) — referenced; full status unverified

---

## Pin-lag spectrum

Each repo's `cyrius = "X.Y.Z"` pin (verified 2026-05-06). Bundle pin-bumps to v5.9.x with each repo's natural next patch — don't force a rebuild slot just for the sweep. **Eight repos still on `cyrius.toml` (pre-`.cyml` format) with v3.x–v4.x pins** — these need format migration *and* pin bump.

```
PRE-CYML format (cyrius.toml, v3.x–v4.x — needs format migration):
  v3.x:    avatara (3.10.0), ai-hwaccel (3.10.0), hadara (3.7.0)
  v4.x:    itihas (4.0.0), hoosh (4.5.0), kavach (4.5.0), agnoshi (4.5.0),
           nein (4.5.0), bote (4.8.4), t-ron (4.8.4), shravan (4.10.3)

CYML format:
  v5.1.x:  ark (5.1.10)                              ← extreme lag, port pre-dates pin convention
  v5.4.x:  libro (5.4.7), majra (5.4.17)
  v5.5.x:  bsp (5.5.2), takumi (5.5.23)              ← takumi: rust-old/ authoritative until parity
  v5.6.x:  vyakarana (5.6.0), yantra (5.6.17)
           cyrius-stellar-swarm (5.6.26),
           cyrius-sunset-drive (5.6.26),
           cyrius-super-plumber-twins (5.6.26),
           cyrius-grapevine (5.6.29),
           cyrius-chellys-beach-adventure (5.6.29-1)
  v5.7.x:  argonaut (5.7.5), cyrius-brynns-tale (5.7.9), hisab (5.7.10),
           cyrius-bb (5.7.11), kybernet (5.7.12), agnostik (5.7.12),
           daimon (5.7.12), owl (5.7.12), agnova (5.7.12),
           agnos (5.7.22), abaco (5.7.23), cyim (5.7.23),
           nous (5.7.29), bazaar (5.7.30), shakti (5.7.33)
  v5.7.48: agnosys, phylax, mabda, cyrius-doom, samvada     ← held-cluster, didn't roll into v5.8.x
  v5.8.x:  vidya (5.8.34), sandhi (5.8.36), sit (5.8.51),
           patra (5.8.64), sakshi (5.8.64), sigil (5.8.64),
           vani (5.8.64), yukti (5.8.64), sankoch (5.8.64),
           niyama (5.8.65)                                  ← warm cluster, tracked v5.8.x to closeout

NO PIN field (file exists, field missing): aegis, aethersafha, aethersafta,
                                            kiran, joshua, salai, mela, seema,
                                            samay, murti, tanur, encom-hits,
                                            cyrius-nba-jam
                                            (most are pre-1.0 scaffolds)
```

**Bands of attention:**
- The **v5.8.x warm cluster** (10 repos) tracked Phase 3 to closeout — these will roll naturally into v5.9.x.
- The **v5.7.48 held cluster** (5 repos: agnosys, phylax, mabda, cyrius-doom, samvada) skipped v5.8.x entirely — investigate per repo whether content held them back or just bandwidth.
- The **pre-CYML format tail** (11 repos, 3.x–4.x pins) is the largest debt — these missed both the format migration AND every v5.x pin since.
- The **deep-lag tail** (ark 5.1.10, libro 5.4.7, majra 5.4.17, bsp 5.5.2, takumi 5.5.23, vyakarana 5.6.0, yantra 5.6.17) didn't roll forward and may carry latent breakage against current stdlib.
- The **scaffolded apps** (kiran, joshua, salai, etc.) lack pin fields entirely — add during their first real-implementation patch.

---

## Active sweeps

### Niyama fold-in (v5.9.0 downstream sweep)

Fresh sibling-fold per niyama ADR 0011. Pattern parallels sandhi-fold (v5.7.0) and vani-fold (v5.8.0).

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (cyim is #1 multi-consumer gate; bare-metal kernel queued #2) | ✅ Done at v5.9.0 |
| 2 | In-tree fixture migration if needed | ✅ N/A — no fixtures touched |
| 3 | cyim → niyama integration verification (regex sweep) | ❓ Pending verification |
| 4 | Document the niyama-fold pattern alongside sandhi/vani-fold in `design-patterns.md` | [ ] |
| 5 | Niyama-fold-in article slot | [ ] |

### Vani audio distlib fold-in (v5.8.0 downstream sweep)

Per [`vani/docs/development/cyrius-stdlib-fold-in.md`](https://github.com/MacCracken/vani/blob/main/docs/development/cyrius-stdlib-fold-in.md). Pattern parallels v5.7.0 sandhi fold.

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (`grep -rn "include.*lib/audio.cyr"` across ecosystem) | ✅ Done at v5.8.0 — zero hits |
| 2 | In-tree fixture migration (3 preprocessor-cap regression tests) | ✅ Done in cyrius repo at v5.8.0 |
| 3 | Document the fold-in pattern alongside sandhi-fold in `design-patterns.md` | ❌ Still pending |
| 4 | Vani-fold-in article (parallels sandhi-fold article slot) | ❌ Still pending |

### v5.7.x → v5.8.x debt carry-forward

Status verified 2026-05-06.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | yantra orphan `lib/http_server.cyr` delete | ❌ Pending | Confirmed file still present at `yantra/lib/http_server.cyr`; cleanup-only, no callers |
| 2 | sit orphan `lib/http_server.cyr` delete | ✅ Done | Remote returns 404 — file removed |
| 3 | vyakarana grammar refresh — index 469 sandhi fns | ❌ Pending | vyakarana stuck at 1.0.2 / pin 5.6.0; coordinate with owl colorizer work |
| 4 | vidya per-minor refresh (`language.toml` / `dependencies.toml` / `ecosystem.toml`) | ❓ Pending verification | vidya at 2.6.4 / pin 5.8.34 — version bumped, content reflection unverified |
| 5 | hoosh / ifran / daimon / mela / ark sandhi-fold audit-confirm | ✅ Confirmed clean | Zero `[deps.sandhi]` and zero include-sandhi refs in any of the five (note: hoosh/daimon use `cyrius.toml`; ark uses `cyrius.cyml`) |

### CVE-2026-31431 (Copy Fail) cleanup + audit

Linux kernel LPE in `algif_aead` (AF_ALG in-place AEAD + `splice()` → 4-byte page-cache write → root). Disclosed 2026-04-29; affects mainline kernels from 2017 onward. Roadmap item **S1**.

**AGNOS-native kernel** (`agnos` v1.26.1): structurally immune — verified at `kernel/core/syscall.cyr:32-36`, 26-syscall table contains no `socket`, no `splice`, no AF_ALG family. Bug class is unreachable.

| # | Action | Status |
|---|--------|--------|
| 1 | Host defconfigs — pin `# CONFIG_CRYPTO_USER_API{,_HASH,_SKCIPHER,_AEAD,_RNG} is not set` in `agnosticos/kernel/{6.6-lts,6.x-stable,7.0-devel}/configs/*defconfig` and `kernel/configs/edge-{deeplens,nuc,rpi4,rpi5}.config` | ❌ Pending — verified zero `CRYPTO_USER_API` refs in any of the 5 host defconfigs |
| 2 | Audit local crypto-adjacent repos for `AF_ALG` / `algif_aead` refs: sigil, agnosys, phylax | ✅ Done 2026-05-03 — zero hits |
| 3 | Audit when next cloned: kybernet, libro, kavach, shakti, aegis, t-ron, argonaut, ark, agnostik, bote, daimon, hoosh | ❓ Deferred — repos not local |
| 4 | Once defconfigs pinned, document the absence-by-design pattern alongside other AGNOS-vs-Linux structural-immunity examples in `design-patterns.md` | [ ] |

### Pending Cyrius ports

| Repo | Current state | Action |
|------|---------------|--------|
| **bhava** | 2.0.0 Rust (no `cyrius.cyml` on remote) | Port can start — v5.9.x stdlib + math additions are the gating concern |
| **aegis** | 0.1.0 scaffold | Real implementation |
| **aethersafha** | 0.1.0 scaffold | Real implementation (Wayland compositor) |
| **aethersafta** | 0.50.0 (media compositing scene graph) | Distinct from aethersafha — not a Cyrius port target, near-stable lib |

### Per-repo housekeeping (P1/P2)

Carry-forward from v5.6.x → v5.7.x → v5.8.x → v5.9.x. None of these are blocking; bundle with each repo's next natural patch.

- **`docs/development/state.md` migration** (this pattern). **Done**: cyrius, owl (2026-04-23), agnosticos (this file, 2026-05-06), sandhi, sit. **Pending**: every other repo that still carries volatile state in CLAUDE.md (verified 2026-05-06: kybernet, daimon, agnos, abaco, hoosh, kavach, mabda, sigil all missing; presume similar for the unverified tail).
- **`cyrius.toml` → `cyrius.cyml` format migration** (11 repos, see pin spectrum): avatara, ai-hwaccel, hadara, itihas, hoosh, kavach, agnoshi, nein, bote, t-ron, shravan. Each migration also re-pins to current toolchain.
- **`[build].modules` → `[lib] modules` migration**: sigil, agnosys, shakti pending. sakshi has `dist/sakshi.cyr` but no `modules` block — investigate generation mechanism.
- **`docs/adr/` scaffold** (12 repos still missing): agnosys, sigil, takumi, phylax, ark, nous, sakshi, yukti, bsp, owl, cyrius-doom, majra. Copy `README.md` + `template.md` from sit; don't back-fill historical decisions.
- **`docs/adrs/` → `docs/adr/` rename**: argonaut last offender.
- **Crate registry refresh** — both registries are stale against current state. Sweep when next touched.
  - [`applications/shared-crates.md`](applications/shared-crates.md) (full registry, pre-1.0 + v1.0+): sigil 2.9.3→3.0.1, mabda 2.5.0→3.0.0-rc.2, sakshi 2.1.0→2.2.3, agnos 1.22.0→1.26.1, sankoch 2.1.0→2.2.4, abaco 2.1.0→2.2.0, phylax 1.0.0→1.1.0, vidya 2.3.0→2.6.4, libro 1.0.3→2.0.5, hisab 1.4.0→2.2.2, yukti 1.2.0→2.2.2, agnos 1.26.1, niyama 1.0.1, etc.
  - [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ stable subset, "68 crates" — count itself stale). Last updated 2026-04-15 — predates the v5.7.x cluster bumps and the entire v5.8.x cycle.

### CLAUDE.md table refresh

Root [`CLAUDE.md`](../../CLAUDE.md) "Standalone Repos" table also drifted (same pattern as shared-crates.md). When refreshing, prefer pointing to this file or to shared-crates.md rather than re-duplicating versions in CLAUDE.md.

---

## Doc / article update queue

| File | Action |
|------|--------|
| [`roadmap.md`](roadmap.md) | v5.7.x / v5.8.0 phase definitions are now historical; v5.8.0 = "bare-metal queued" reference rolled to v5.10.x. Re-touch on each v5.9.x ship. |
| [`summer-2026-arc.md`](summer-2026-arc.md) | v5.9.x TLS-progress framing in line 217 may not match actual cycle theme (niyama-foldin opener) — verify intent. |
| [`articles/cyrius-vs-rust-benchmarks.md`](../articles/cyrius-vs-rust-benchmarks.md) | Add v5.8.x / v5.9.x rows once optimization-arc patches land; sweep "Pure compute gap" language for closed items |
| [`articles/port-ledger-volume-1.md`](../articles/port-ledger-volume-1.md) | *Where Rust Still Wins* — confirm which categories closed under v5.8.x |
| [`articles/doom-in-cyrius.md`](../articles/doom-in-cyrius.md) | v5.9.x rebuild numbers when cyrius-doom ships an unblock release (still on pin 5.7.48) |
| [`articles/sovereign-compiler-vs-brute-force.md`](../articles/sovereign-compiler-vs-brute-force.md) | cc5 size at 741,048 B (v5.9.0 baseline; net unchanged from v5.8.65) |
| [`applications/shared-crates.md`](applications/shared-crates.md) | Bump versions; re-verify all "v0.x.x" claims (see drift list above) |
| [`docs/applications/libs/README.md`](../applications/libs/README.md) | Bump versions for v1.0+ subset; "Last Updated 2026-04-15" predates two cycles |
| [`applications/first-party-documentation.md`](applications/first-party-documentation.md) | Re-read at each v5.9.x patch — meta-irony from *Docs Go Stale Before the Commit* |
| **NEW** Vani fold-in article | Refusal-as-Architecture instance #2 (sandhi was #1) — still pending |
| **NEW** Niyama fold-in article | Refusal-as-Architecture instance #3 — slot opened v5.9.0 |
| **NEW** Phase-3-stdlib-foldin retrospective | v5.8.x's 27 foldin slots in 4 days is its own story — sandhi-pattern compounded |
| **NEW** starship.toml prompt convention (v5.8.0) | ॐ Om + 🌀 cyclone — possibly under `articles/` or `design-patterns.md` |

---

## Refresh procedure

When a v5.9.x patch closes:

1. Pull current `VERSION` + `cyrius.cyml`/`cyrius.toml` for affected repos
2. Update the pin-lag spectrum if any repo crossed a band
3. Tick off swept items
4. Re-anchor "Last refresh" date in the header
5. Re-anchor "Cyrius toolchain" if a new minor cut

When v5.9.x cycle closes:

1. Move v5.9.x slot list closeout summary into a brief retrospective
2. Repoint all `5.8.x` / `5.9.x` references to whichever cycle is next
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

*Refreshed 2026-05-06 (v5.9.0 ship day). Rewrite-in-place as state changes. v5.8.x history captured here is for cycle-context only — Cyrius CHANGELOG is the receipt.*
