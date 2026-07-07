---
name: AGNOS Ecosystem State
description: Live cross-repo state — kernel head, Cyrius pin/cycle pointer, active sweeps, carry-forward debt, registry pointers
type: state
---

# AGNOS Ecosystem — Current State

> **⚠ NOT A LOG.** This file is **live state with pointers** — current truth only, plus links to where the history lives. Iron attempt history → [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md). Per-repo release history → each repo's `CHANGELOG.md`. Crate versions → the two registry pointers below. If you find yourself writing prose narrative here, it belongs in one of those other files.
>
> **Cyrius pin**: agnos holds **6.3.43** (`cyrius.cyml`, bumped 2026-07-03 from 6.3.9 to get on near-latest before the v6.3.x closeout; earlier 6.2.44→6.3.9 on 2026-06-30). The freestanding agnos kernel is `cmp`-byte-identical across pins (the 6.3.9→6.3.43 bump kept `build/agnos` at 1,345,512 B, `cmp`-proven — the freestanding kernel has no per-thread stacks, so **6.3.13's array-locals-to-stack default-on doesn't touch it**; hda-smoke + agnsh-smoke re-confirmed green post-bump), so the pin is provenance only — but **the symlink#63 syscall (1.51.0) created a hard floor: its userland peer `sys_symlink` exists only in cyrius ≥ 6.3.6**, so agnos (home of the syscall + the `symtest` exerciser that calls it) must pin ≥ 6.3.6 to cohere with the feature it ships. agnos now pins **6.3.43**; ark + the `symtest` exerciser still pin **6.3.9** (the version with the peer — bump them alongside when convenient). Latest released cyrius tag is **6.3.43** (the last v6.3.x work before closeout — cross-host stdlib verification + PE lint; v6.3.x is nearing its close). agnosticos boot-pipeline (`scripts/cyrius.cyml`) pins **6.0.14** (boot-script-only). ⚠ `scripts/build.sh` runs the cyrius wrapper **without `--strict-pin`**, so a newer installed `cycc` silently builds agnos (warn-only) until the pin is bumped — check `cyrius --version` when a build's provenance matters. Cyrius is **hands-off** here: cycle status + v6.x carry-forward triage (RISC-V rv64, bare-metal, PIE/closures/Class-B FFI, the O3–O6 opt-arc audit, held `ESTORESTACKPARM`, consumer-rollup tails) live in cyrius `roadmap.md` + `CHANGELOG.md`. v6.x opened 2026-05-19 at the v5→v6 boundary (v5.11.x closed at 5.11.69); **v6.3.x is the active minor**, v6.0.x/v6.1.x/v6.2.x closed.
>
> **Last refresh**: 2026-07-06. **Kernel head: agnos 1.53.5** (HDMI-audio arc cut) — the single tracked dev head; per-cut detail lives in the agnos CHANGELOG + [`agnos/docs/development/state.md`](https://github.com/MacCracken/agnos/blob/main/docs/development/state.md), **NOT here** (this file is current-truth + pointers, per the ⚠-banner above). **▶ ACTIVE — HDMI-audio arc (`04:00.1`):** bites 1-3 cut **1.53.5** (2026-07-06), QEMU-complete (multi-instance HDA driver + 2nd-controller probe/enum + unified HDMI/DP route with a digital-DigEn branch; `hda-dual-smoke`-validated, analog byte-unchanged RMS=5131.3). ⏳ **bite-3 digital arm IRON-PENDING** — the `BURN_HDMI=1 burn-prep` kernel (HDA_HDMI+HDA_TONE) + an HDMI/DP display on a firmware-LIT port; sweep audible from display speakers, serial `route … dev=5 … digi=1` + `hdmi DigEn set` (agnos has no amdgpu → a DARK port won't egress). Bite 4 (runtime analog↔HDMI sink-select) deferred. The `AUDIO_AGNOS_TARGET` latency trim (256→~60-90 ms) is app-side (cyrius-doom); kernel already latency-ready. → agnos CHANGELOG `[1.53.5]`. **Just-closed + iron-validated** (detail → CHANGELOG): **1.53.x FP/SIMD** (2026-07-06 — real f64 + naad DSP in ring 3 on real Zen, `fpex`→84 / `naadex`→88) · **1.52.x audio** (2026-07-05 — DOOM-with-sound out the archaemenid front jack; the iron echo was an uncalibrated LAPIC timebase, fixed 1.52.8 boot PIT-ch0 calibration; cyrius `vani` agnos backend).
>
> **Open carry-forward (parked):** the `owl`→`sit`/`SYS_CHDIR` agnos port (owl needs `sit`, which calls `SYS_CHDIR` — agnos has **no chdir by design** — plus the TLS peer; the agnos delegation runs owl 1.3.8 cat-only) · thorough per-project net-tool validation (`yo`/`dig`/`whirl`/`taar`) deferred — they already run at decent capacity on iron.
>
> **Closed arcs (history → each repo's CHANGELOG + iron-log, NOT here):** 1.31.x storage · 1.32.x networking · 1.33.x ext2/4 write · 1.34.x FAT/exFAT write · 1.35.x comms · 1.36.x refactor · 1.37.x ext4 extent-alloc · 1.38.x jbd2 · 1.39.x VFS write-lift · 1.40.x exec-from-disk · 1.41.x shell→agnoshi · 1.42.x perf/sysinfo/klug · 1.43.x graphics/DOOM · 1.44.x preemptive scheduling · 1.45.x TLS→net-tools · 1.46.x SMP · 1.47.x fault-resilience+perf · 1.48.x FAT/exFAT perf · 1.49.x >256 MB RAM · 1.50.x RAM full-usage+boot-CR3→own-PML4 · 1.51.x sovereign-pkg-mgr surface+net RX-IRQ — all iron-validated. **Live SMP gates:** `exec_preempt=1` / `smp_sched_aps=1` / `smp_wake_enabled=1` (P0 — IF=0 revert PROHIBITED; the 2-week IF=1 `#GP` was the AMD SYSRET SS-RPL bug, fixed 1.46.5 — [[project_agnsh_if1_preempt_iron_blocker]]). MVP gate (boot-to-shell on iron) green since 1.30.9. attn11 PARKED (MTP arc complete at 1.10.2; training-science backlog in its roadmap).
>
> **Iron-log roads** (split by maturity era; active keeps the bare name): **base** (active — [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md)) → **server** (self-hosting / public-beta gate) → **platforms** (1.5x+ hardware). Chain: [`-mvp`](iron-nuc-zen-log-mvp.md) → [`-mvp2`](iron-nuc-zen-log-mvp2.md) → active.
>
> **Crate registries** (per-repo versions/pins drift fast — consult these + each repo's live `VERSION`/`cyrius.cyml`, never an embedded table): [`planning/shared-crates.md`](planning/shared-crates.md) (full, incl. pre-1.0) · [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ libs) · [`docs/applications/binaries.md`](../applications/binaries.md) (v1.0+ binaries) · CLAUDE.md's version-free role-map for orientation. (The old 2026-06-01 pin-lag spectrum + per-repo version table were deleted — they were stale by orders of magnitude.)
>
> **agnosys → agnodrm decomposition (2026-06-19):** agnosys was over-scoped; the device/DRM model survives as **agnodrm** (udev + DRM/KMS), trust→sigil, security/mac/audit→kavach, pam→aegis, logging→sakshi, syscall layer→cyrius (the Linux-eccentric group bootloader/update/netns/fuse/journald parked post-v1). Detail → CLAUDE.md role-map + agnodrm `docs/development/2026-06-18-agnosys-to-agnodrm-decomposition-plan.md`.

**Out of cycle scope (parked):**
- AMD Zen scanout residue (Quiet Boot legibility) — separate cycle per [`project_archaemenid_hardware_target`](../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_archaemenid_hardware_target.md) (§ scanout residue); HUBP `clear_tiling` port or shadow-buffer eval.
- Kernel-side FB **double-buffer** (tear-free flips inside blit#39) — backlogged 2026-06-11 when zero-copy FB-mmap was closed as superseded. Trigger: observed tearing on iron, or future shell-launched games beyond cyrius-doom needing it. Always kernel-mediated (`fb_phys` stays unexposed — the hardened posture is the decision).
- i225-V NIC driver — queued for Intel iron post-migration (the r8169 / RTL8125 path is DONE + iron-verified, 1.32.x; i225-V is a separate hardware line, not an AMD blocker).

This doc holds **volatile state** — what's currently true across the AGNOS dev surface. CLAUDE.md is preferences/process/procedures; this is the live picture. Per [*Development Speed and How It Effects Documentation*](../articles/development-speed-and-documentation.md): rewrite in place when state changes; don't preserve historical snapshots — git history is authoritative.

**Drift caveat**: always verify against actual `VERSION` + `cyrius.cyml` files before acting on any single item in this doc.

---

## ML / AI reference arc (live)

The sovereign ML/AI work runs as a **separate thread** from the kernel arc above (own repos, no iron burns — validated in QEMU / on host). Live map: [[project_ml_ai_arc_overview]] memory + [`planning/type3-weight-import.md`](planning/type3-weight-import.md) (COMPLETE) + [`planning/software-port-path.md`](planning/software-port-path.md) + **[`planning/ifran-port.md`](planning/ifran-port.md) — SHIPPED: ifran 2.0.0 (2026-07-05), the training control plane, ported M0→M6 in two days and proven by attn11+tarka+anukūlana running entirely as ifran jobs; 2.1.0 same day = Lane 1 executor hardening (timeout/reaper/quoted-args/`show`), with the cross-repo lanes closed by anukūlana 1.1.1 (`--sk`) + tarka 1.1.2 (`--pref`); 2.2.0 = the rust-old pre-removal-audit additives (sweep leaderboard+budgets, `dataset validate`, 4-state prefs+conf), with the rust-old audit DONE and removal gated only on preserving the 3 SY-contract docs.** Per-repo detail lives in each repo's CHANGELOG — this is a pointer, not a log. **Runs-on-agnos gate (whole family): the kernel FP/SIMD arc** (agnos `planning/kernel-fp-arc-153x.md`, slotted 1.53.x) — agnos ring-3 enables no FP today, so all on-agnos inference (incl. tentib's integer kernel, whose dequant scales/norms are f64) waits on it; host/QEMU validation is unaffected.

**Substrate-freeze day (2026-07-04) — Type-3 M1 COMPLETE (the real foreign checkpoint runs AND matches HF exactly) + the substrate froze:** The exact-fidelity gate closed via `gpt2-oracle` + a **committed HF-logits fixture** (torch ran once in a disposable venv — never a dependency): argmax identical at all 48 positions, last-row maxrel 1.05e-6 (fp32-rounding scale), gate frozen at 1e-5 → **anukūlana 0.3.0 cut**. Same day, **rosnet 1.0.0 — the ML-substrate freeze** (six-consumer surface frozen, CPU + GPU profiles; benchmarks + audit captured; graduated to the [libs registry](../applications/libs/README.md)). **LoRA (M3) CLOSED + QLoRA/NF4 (M4 core) COMPLETE same day** (anukūlana `[Unreleased]`): FD-gated LoRA primitive set (two rosnet `linear_bwd` passes + hand-derived Adam) + `gpt2-lora` head adapter (xent 10.79→0.0000, argmax 1/8→8/8, base bit-frozen; head-scope accepted by user — deeper adapters would patch attn11, allowed **except SIMD** which cyrius delivers next arc) → sovereign **NF4 codec** (blockwise-64 + double-quant, 8-test exactness gate) + `gpt2-qlora`: **the whole 124M base at 4 bits, adapter recovers the task 8/8 over it, codes bit-frozen** (honest 124M-scale note: raw 4-bit forward drifts — the gated thesis is trainability at 4-bit memory). Findings: plain SGD diverges on real-GPT-2 features (massive-activation outliers → Adam); NF4's largest quantile gap is the negative side's. **The persistence tail shipped in anukūlana 0.5.0 (same day)** — signed NF4 checkpoint (63.8 MB) + adapter (3.3 MB) via tula, bit-identical round-trips, Ed25519 tamper/wrong-key rejection; the base NF4 codec was **reconciled to delegate to tula's shipped codec** (the 0.4.0 hand-roll duplicated tula 1.0.0's frozen surface — the know-the-ecosystem catch; only superblock-256 double-quant stays anukūlana-local). **anukūlana shipped 1.0.0 STABLE same day** (API frozen, fuzz gate + 2 audit fixes in the foreign parser, benchmarks + SECURITY.md; post-1.0 headline = **GGUF import**). **The Type-3 arc is COMPLETE and frozen end-to-end** (tula 1.0.0 · rupantara 0.4.0 · anukūlana 1.0.0 on rosnet 1.0.0). Chain state:

| Repo | Ver | Role | State |
|------|-----|------|-------|
| [`tula`](https://github.com/MacCracken/tula) | 1.0.0 | weight-file format (M0) | format v1 FROZEN (105 assert + 2M fuzz + audit) |
| [`rupantara`](https://github.com/MacCracken/rupantara) | 0.4.0 | transformer-forward lib (attn11→libs #4) | whole-forward parity-proven bit-identical vs attn11 + KV-cache decode |
| [`anukūlana`](https://github.com/MacCracken/anukulana) | **1.1.1** | Type-3 reference — **STABLE** | **charter FULLY built + FROZEN** (import → run → match-HF → LoRA/QLoRA → signed persistence; api.md + STABILITY + SECURITY + audit [2 st_open DoS fixes] + fuzz gate + benchmarks). **Post-1.0 headline GGUF import SHIPPED as 1.1.0 (2026-07-05)**: sovereign GGUF v2/v3 parser + GPT-2 `blk.N.*` mapping; `gpt2-gguf` PASS on the real 124M file; **`gpt2-cross` cross-format gate: both doors bit-identical (123.6M params / 402k logits, 0 diffs)**; +35k GGUF fuzz rounds; suite 80→121. **1.1.1 (2026-07-05): `--sk` operator-key signing — ifran Lane 2 CLOSED** (`gpt2-tula --sk` + `anuk_sk_load`; ifran `store add` now records `verified` end-to-end, proven on the real checkpoint). Next lanes: quantized GGML payloads, llama-arch (TinyLlama) mapping |
| [`attn11`](https://github.com/MacCracken/attn11) | **1.13.0** | GPT transformer + vision ref | CPU leaf-op re-fold onto rupantara `ru_*`; **1.13.0 (2026-07-05) added the VISION lane** (`--vision` — small CNN on rosnet conv2d, the sight proof: loss 1.377→0.0012, held-out 1000/1000, assembled backward FD-gated; suite 1049→1060) |
| [`ganita`](https://github.com/MacCracken/ganita) | 1.0.2 | linalg/math lib | `f64_tanh` NaN-overflow fix (surfaced by the real forward; folded into cyrius stdlib **6.3.31**) |
| [`rosnet`](https://github.com/MacCracken/rosnet) | 1.1.0 | f64 tensor/BLAS substrate | FROZEN 1.0.0 (2026-07-04); **1.1.0 (2026-07-05) added conv2d/conv1d** (FD-gated, per-axis stride/pad) — **the modality axis is substrate-complete** |

Other siblings: **tarka 1.1.2** (RL — the 1.1.x preference set DPO+KL / IPO+KTO shipped, closing out [`planning/tarka-preference-rlhf-extensions.md`](planning/tarka-preference-rlhf-extensions.md); **1.1.2 (2026-07-05) closed ifran Lane 3**: `tarka --pref <prefs.jsonl>` ingests ifran's `pref export` and trains DPO/IPO/KTO from the curated set — e2e proven, suite 73), prajna 1.0.0 (meta), **tentib 0.4.1** (ternary — **the int-SIMD gate LIFTED + SHIPPED 2026-07-06**: cyrius 6.4.6/6.4.7 delivered integer SIMD incl. `iv_dp8`, the u8·i8→i32 widening dot tentib's proposal asked for; `ternary_matmul_free_simd` is bit-identical to the scalar kernel and **~7.5× faster than rosnet's f64-SIMD matmul** on 128×128 [1,946 vs 14,670 ns; ~45× over branchless scalar] — *"multiply-free is also faster"* met; pin →6.4.10, suite 90/90; **0.5.0→0.8.0 ALL SHIPPED same day** — benchmarks.md [SIMD advantage grows 5.0×→18.4× with layer size; honest toy-scale quality delta vs f64 attn11 CE 0.006 vs 0.11] + api.md [surface frozen, alloc audit: inference paths allocation-free] + **pack-once serving** [`tx_pack`/`tx_fwd_packed`, bit-identical, **~13.5k tok/s vs ~2.3k f64 = 5.7×** whole-model; self-checking `examples/quickstart.cyr`] + **0.8.0 security audit** [6 fixed/guarded incl. the γ=0 quantizer sign bug; 5 verified sound; suite 101/101]; **ALL SIX v1.0 criteria green — next = the 1.0.0 clean cut**), amuzesh 0.1.0 (classical). **Substrate leafs FROZEN 2026-07-05: akshara 1.0.0 + tyche 1.0.0** — clean multi-consumer-soak freezes (no behavior change; api.md each), completing the rosnet/tyche/akshara extraction trio at v1.0+; both graduated to the [libs registry](../applications/libs/README.md). **The SIGHT PROOF PASSED same day — shipped as attn11 1.13.0** (vision lane, `--vision` — user-homed): small CNN on rosnet conv2d over a synthetic sovereign shape set, loss 1.377→0.0012, held-out **1000/1000**, assembled backward FD-gated (attn11 suite 1049→1060, rosnet pin → 1.1.0); the modality axis has its first consumer proof (hearing = STFT+mel glue next, on demand). anukūlana pins cyrius **6.3.31** (to pick up the folded ganita fix). **Current head (2026-07-05):** the three long-standing ML gaps are now closed or advanced — **Type-3 COMPLETE + frozen** (charter built end-to-end, GGUF shipped as anukūlana 1.1.0/1.1.1), **the ifran control-plane port SHIPPED** (2.0.0→2.2.0; all post-2.0 cross-repo lanes closed; `rust-old/` audited + removed), and gap #3 = **tanur** (the desktop model-studio — a puka desktop *app*, agnosticos [`planning/tanur.md`](planning/tanur.md); ifran stays CLI-only, tanur consumes it), **desktop-stage, backlogged**. Trigger-gated remainder: the hearing proof (STFT+mel over hisab FFT, on demand) + the DSpark decode lane (below); tentib's int-SIMD gate CLEARED 2026-07-06 (0.4.1 shipped, above).

**Mapped-but-unbuilt lane (2026-07-03):** DeepSeek **DSpark** (speculative decoding) was investigated and homed as an **attn11 decode lane** (not a new sibling) — it reuses attn11's MTP heads (self-speculative draft) + planned KD objective (draft training); correctness gate = losslessness; load-aware verification splits to hoosh/murti. Forward-design map: [`planning/speculative-decoding.md`](planning/speculative-decoding.md). Design reserved, build **not triggered** — attn11 is active again (1.13.0 vision lane), so the barrier is now a build-decision, not a reopening; the trigger is a decision to build speculative decoding (MTP-draft + KD), unchanged.

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
| **aethersafha** | 0.5.0 (in progress) | Wayland compositor — built-in-apps framework landed (Bite C1+C2, fork+execve spawn); backends **bhumi 1.0.0** + **mehman 1.0.0** |

> **Completed ports (out of this table 2026-07-03):** goonj → **2.0.0** Cyrius (37 modules, 3585 parity asserts) · naad → **2.1.0** Cyrius (+ post-port audit). Both part of the audio-synthesis wave feeding the 1.52.x audio arc; svara → **3.0.0** and nidhi → **2.0.0** Cyrius ports also landed same day.

> Note: **aethersafta** (Rust 0.50.0, media-compositing scene graph) is DISTINCT from aethersafha (the Wayland compositor) — a near-stable lib and a **Rust→Cyrius port target** (a Cyrius-native version is where it goes). ⚠ The earlier "**not** a Cyrius port target" note was **false** — it confused *agnos running various-language binaries* (swallow/compat, for foreign third-party apps) with AGNOS's own components, which always go Cyrius-native for implementation sovereignty. "agnos could just run the Rust binary" is never a reason to leave one of our own libs in Rust. See [[project_os_agnostic_layer_is_the_swallow_mechanism]].

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
