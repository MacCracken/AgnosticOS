---
name: AGNOS Ecosystem State
description: Live cross-repo state — kernel head, Cyrius pin/cycle pointer, active sweeps, carry-forward debt, registry pointers
type: state
---

# AGNOS Ecosystem — Current State

> **⚠ NOT A LOG.** This file is **live state with pointers** — current truth only, plus links to where the history lives. Iron attempt history → [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md). Per-repo release history → each repo's `CHANGELOG.md`. Crate versions → the two registry pointers below. If you find yourself writing prose narrative here, it belongs in one of those other files.
>
> **Cyrius pin**: agnos holds **6.2.36** (`cyrius.cyml`, held-known-working — the freestanding agnos kernel is `cmp`-byte-identical across pins, so the pin only aligns provenance; **don't chase the number**). Latest released cyrius tag is **6.2.44**. agnosticos boot-pipeline (`scripts/cyrius.cyml`) pins **6.0.14** (boot-script-only). ⚠ `scripts/build.sh` runs the cyrius wrapper **without `--strict-pin`**, so a newer installed `cycc` silently builds agnos (warn-only) until the pin is bumped — check `cyrius --version` when a build's provenance matters. Cyrius is **hands-off** here: cycle status + v6.x carry-forward triage (RISC-V rv64, bare-metal, PIE/closures/Class-B FFI, the O3–O6 opt-arc audit, held `ESTORESTACKPARM`, consumer-rollup tails) live in cyrius `roadmap.md` + `CHANGELOG.md`. v6.x opened 2026-05-19 at the v5→v6 boundary (v5.11.x closed at 5.11.69); **v6.2.x is the active minor**, v6.0.x/v6.1.x closed.
>
> **Last refresh**: 2026-06-27. **Kernel head: agnos 1.46.11** (pin 6.2.36) — the single tracked dev head; the per-repo CHANGELOG owns cut-by-cut detail.
>
> **1.46.x SMP / multi-threading arc — COMPLETE + iron-validated.** STEP-2 (`smp_sched_aps=1`, real ring-3 procs on woken APs) PASSED on archaemenid 2026-06-26; the whole STEP-1 → STEP-1-at-IF=1 → STEP-2 ladder is iron-green (IF=1 preemptive agnsh, working coreutils, boot-to-shell all confirmed on real Zen). The 2-week IF=1 `#GP` was the AMD SYSRET SS-RPL bug, fixed one byte (`syscall_hw.cyr` STAR[63:48] `0x10`→`0x13`) at **1.46.5**. **Live kernel gates**: `exec_preempt=1` (P0 — IF=0 revert PROHIBITED by user), `smp_sched_aps=1` (=0 reverts to STEP-1), `smp_wake_enabled=1` (APs woken). Detail → agnos CHANGELOG `[1.46.x]` + iron-log [`#tracker-146x-cycle`](iron-nuc-zen-log.md#tracker-146x-cycle) + agnos `smp-arc-plan.md`; memory [[project_agnsh_if1_preempt_iron_blocker]] / [[project_multithreading_future_arc]].
>
> **Post-SMP landings (on top of the closed arc):** `input_lock` (1.46.9, kb_buf SMP lock) · exec argv cap 8→16 (1.46.10) · two-stage shell pipes `cmd1|cmd2` (kernel read#5 stdin-from-pipe at 1.46.11 + **agnoshi 1.8.0** `sh_run_pipeline`; store-and-forward, single-foreground; QEMU-validated `iam|anuenue`). **cyrius-doom 0.30.3** — sustained-play ring-3 `#PF` root-caused + fixed (sprite.cyr `clip_top` OOB / unclamped `sprite_w`, was masked by a cyrius-6.1.37 continue-miscompile already fixed in 6.2.x; the earlier "DOOM locks up after ~1-2 min" finding is now CLOSED). **anuenue 1.1.5** — truecolor-on-agnos color fix; pins cyrius 6.2.44.
>
> **Open carry-forward:** pipe follow-ons filed — pipe-buffer refcount + per-proc fd tables (streaming / SMP-safe pipes) · kernel should TERMINATE a faulting ring-3 proc + return to prompt instead of halting (server/desktop maturity, non-MVP) · the `owl`→`sit`/`SYS_CHDIR` agnos port (owl needs `sit` on agnos — `sit` calls `SYS_CHDIR`, and agnos has **no chdir by design** — plus the TLS peer; the agnos delegation runs owl 1.3.8 cat-only) · thorough per-project net-tool validation (`yo`/`dig`/`whirl`/`taar`) deferred — they already run at decent capacity on iron.
>
> **Closed arcs (history → each repo's CHANGELOG + iron-log, NOT here):** 1.31.x storage · 1.32.x networking · 1.33.x ext2/4 write · 1.34.x FAT/exFAT write · 1.35.x comms · 1.36.x refactor · 1.37.x ext4 extent-alloc · 1.38.x jbd2 · 1.39.x VFS write-lift · 1.40.x exec-from-disk · 1.41.x shell→agnoshi · 1.42.x perf/sysinfo/klug · 1.43.x graphics/DOOM · 1.44.x preemptive scheduling · 1.45.x TLS→net-tools · 1.46.x SMP — all iron-validated. MVP gate (boot-to-shell on iron) green since 1.30.9. The 1.45.x net-syscall surface (#45–#57, winsize#60, net_config#61) + timer-ISR RX drain (`net_rx_drain`) are landed kernel capability; `cyrius-yeomans-descent` 1.1.3 runs on agnos over server sockets (sock_listen#56/accept#57; harness `docker/descent-sweep/boot-serve.py`); the Docker service-sweep harness (net + sched, TCG-default) found/fixed the TCP CLOSE_WAIT listener slot-leak (1.45.11). attn11 PARKED (MTP arc complete at 1.10.2; parked training-science backlog in its roadmap).
>
> **Iron-log roads** (split by maturity era; active keeps the bare name): **base** (active — [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md)) → **server** (self-hosting / public-beta gate) → **platforms** (1.5x+ hardware). Chain: [`-mvp`](iron-nuc-zen-log-mvp.md) → [`-mvp2`](iron-nuc-zen-log-mvp2.md) → active.
>
> **Crate registries** (per-repo versions/pins drift fast — consult these + each repo's live `VERSION`/`cyrius.cyml`, never an embedded table): [`planning/shared-crates.md`](planning/shared-crates.md) (full, incl. pre-1.0) · [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ libs) · [`docs/applications/binaries.md`](../applications/binaries.md) (v1.0+ binaries) · CLAUDE.md's version-free role-map for orientation. (The old 2026-06-01 pin-lag spectrum + per-repo version table were deleted — they were stale by orders of magnitude.)
>
> **agnosys → agnodrm decomposition (2026-06-19):** agnosys was over-scoped; the device/DRM model survives as **agnodrm** (udev + DRM/KMS), trust→sigil, security/mac/audit→kavach, pam→aegis, logging→sakshi, syscall layer→cyrius (the Linux-eccentric group bootloader/update/netns/fuse/journald parked post-v1). Detail → CLAUDE.md role-map + agnodrm `docs/development/2026-06-18-agnosys-to-agnodrm-decomposition-plan.md`.

**Out of cycle scope (parked):**
- AMD Zen scanout residue (Quiet Boot legibility) — separate cycle per [`project_amd_zen_scanout_residue`](../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_amd_zen_scanout_residue.md); HUBP `clear_tiling` port or shadow-buffer eval.
- Kernel-side FB **double-buffer** (tear-free flips inside blit#39) — backlogged 2026-06-11 when zero-copy FB-mmap was closed as superseded. Trigger: observed tearing on iron, or future shell-launched games beyond cyrius-doom needing it. Always kernel-mediated (`fb_phys` stays unexposed — the hardened posture is the decision).
- i225-V NIC driver — queued for Intel iron post-migration (the r8169 / RTL8125 path is DONE + iron-verified, 1.32.x; i225-V is a separate hardware line, not an AMD blocker).

This doc holds **volatile state** — what's currently true across the AGNOS dev surface. CLAUDE.md is preferences/process/procedures; this is the live picture. Per [*Development Speed and How It Effects Documentation*](../articles/development-speed-and-documentation.md): rewrite in place when state changes; don't preserve historical snapshots — git history is authoritative.

**Drift caveat**: always verify against actual `VERSION` + `cyrius.cyml` files before acting on any single item in this doc.

---

## Active sweeps

Open housekeeping (none blocking; bundle with each repo's next natural touch):

- **yantra** orphan `lib/http_server.cyr` delete — still pending (cleanup-only, no callers; yantra deep-lag).
- **vyakarana** grammar refresh — re-verify the 469 sandhi-fn index reflects content.

### CVE-2026-31431 (Copy Fail) — roadmap item S1

`algif_aead` AF_ALG-in-place-AEAD + `splice()` Linux LPE (disclosed 2026-04-29). **AGNOS-native kernel structurally immune** — the sovereign syscall table (`kernel/core/syscall.cyr`) has no `socket`, no `splice`, no AF_ALG family, so the bug class is unreachable; re-verify only if the syscall surface grows. **Open:**
1. Pin `# CONFIG_CRYPTO_USER_API{,_HASH,_SKCIPHER,_AEAD,_RNG} is not set` in host defconfigs (`kernel/{6.6-lts,6.x-stable,7.0-devel}/configs/*defconfig` + `kernel/configs/edge-*.config`).
2. Finish the deferred per-repo `AF_ALG`/`algif_aead` audits (repos not all local).
3. Once defconfigs pinned, document the absence-by-design pattern alongside other AGNOS-vs-Linux structural-immunity examples in `design-patterns.md`.

### Pending Cyrius ports

| Repo | Current state | Action |
|------|---------------|--------|
| **bhava** | 2.0.0 Rust | Emotion/sentiment — port can start (stdlib + math additions gating) |
| **goonj** | 1.4.3 Rust | Acoustics — port pending |
| **naad** | 1.2.5 Rust | Audio synthesis — port pending |
| **aethersafha** | 0.1.0 scaffold | Real implementation (Wayland compositor) |

> Note: **aethersafta** (0.50.0, media compositing scene graph) is DISTINCT from aethersafha — a near-stable lib, **not** a Cyrius port target.

### Per-repo housekeeping (P1/P2, none blocking)

- `cyrius.toml` → `cyrius.cyml` format migration: **hoosh, shravan** remaining (last pre-CYML holdouts).
- `[build].modules` → `[lib] modules`: **sigil, agnodrm, shakti** pending.
- `docs/adr/` scaffold (~12 repos still missing); copy `README.md` + `template.md` from sit, don't back-fill historical decisions.
- `docs/adrs/` → `docs/adr/` rename: **argonaut** last offender.
- **kiran** `cyrius.cyml` pin-field population (shipped 1.0.0 but lacks the `cyrius = "X.Y.Z"` field).
- `docs/development/state.md` migration for repos still carrying volatile state in CLAUDE.md (kybernet, daimon, agnos, abaco, hoosh, kavach, mabda, sigil, … presumed similar for the unverified tail).

### CLAUDE.md table refresh

Root [`CLAUDE.md`](../../CLAUDE.md) "Standalone Repos" table also drifts — when refreshing, prefer pointing to this file / shared-crates.md / the registries rather than re-duplicating versions (it is intentionally version-free).

---

## Doc / article update queue

Open writing/refresh tasks only:

| File | Action |
|------|--------|
| [`roadmap.md`](roadmap.md) | Re-touch on each v6.x ship (v5.x phase defs are historical; v6.x = "what the language gains"). |
| [`summer-2026-arc.md`](summer-2026-arc.md) | Re-anchor cycle-theme references (v6.x framing + closed-beta MVP gate hit on iron). |
| [`articles/cyrius-vs-rust-benchmarks.md`](../articles/cyrius-vs-rust-benchmarks.md) | Add v6.x rows; sweep closed "pure compute gap" language. |
| [`articles/doom-in-cyrius.md`](../articles/doom-in-cyrius.md) | Rebuild numbers when cyrius-doom ships an unblock release. |
| [`articles/sovereign-compiler-vs-brute-force.md`](../articles/sovereign-compiler-vs-brute-force.md) | Pull current `cycc` self-host size from `cyrius/build/cycc` before publishing. |
| [`articles/port-ledger-volume-3.md`](../articles/port-ledger-volume-3.md) | 🌱 **OPEN / accreting** (seeded 2026-06-01) — fills per-port as 6.x re-benchmarks land. Volumes 1 + 2 are **FROZEN**. |
| [`planning/shared-crates.md`](planning/shared-crates.md) + [`docs/applications/libs/README.md`](../applications/libs/README.md) | Periodic version refresh of the registries. |
| [*Why AGNOS-native agents can't be drained by a tweet*] (working title) | Agent-injection-defense article (Phase 15A) — second instance of the absence-by-design structural-immunity pattern (CVE-2026-31431 was the first). Spec: [`planning/agent-injection-defense.md`](planning/agent-injection-defense.md). Draft after Phase 1 ships (post-closed-beta). |

---

## Refresh procedure

When a cyrius patch or agnos cut lands:

1. Pull current `VERSION` + `cyrius.cyml` for affected repos.
2. Tick off swept items.
3. Re-anchor "Last refresh" date, kernel head, and pins in the header.

When a cycle closes:

1. Collapse the closed arc to a one-line pointer in the "Closed arcs" ledger (history → repo CHANGELOG + iron-log).
2. Repoint any stale version references.
3. Don't archive — rewrite in place. Git history is the snapshot.

---

## Related

- [`CLAUDE.md`](../../CLAUDE.md) — preferences/process/procedures (this doc holds the volatile state CLAUDE.md should NOT carry).
- [`planning/shared-crates.md`](planning/shared-crates.md) + [`docs/applications/`](../applications/) — authoritative crate registries (versions + roles).
- [`roadmap.md`](roadmap.md) — AGNOS / Cyrius milestone definitions and timeline.
- [Cyrius CHANGELOG](https://github.com/MacCracken/cyrius/blob/main/CHANGELOG.md) — authoritative source for cyrius cycle status.
- [Articles: *Development Speed and How It Effects Documentation*](../articles/development-speed-and-documentation.md) — the rationale for state.md as a pattern + the broader drift argument.
- Per-repo `docs/development/state.md` (where it exists) — source of truth for that repo's local state; verify before acting.

---

*Refresh in place per [*Development Speed and How It Effects Documentation*](../articles/development-speed-and-documentation.md). Per-day refresh narratives previously accreted here have been pruned — git history is authoritative for prior-state recovery; CHANGELOGs + iron-nuc-zen-log are the canonical event ledgers.*
