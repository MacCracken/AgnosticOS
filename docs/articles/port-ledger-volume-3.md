# Port Ledger Volume 3

> **STATUS — OPEN / ACCRETING.** This is the post-arc re-measurement cut promised by [Volume 1](port-ledger-volume-1.md) and [Volume 2](port-ledger-volume-2.md): the comparison against Volume 1's frozen v5.5.4 numbers, now that the optimization arc has run and Cyrius has crossed into the **v6.0.x** cycle (v5.x closed at v5.11.69, 2026-05-19). Unlike Volumes 1 & 2 — which are sealed snapshots — **Volume 3 fills in over time**, one port at a time, as each crate's re-benchmark comes online. It opens with **abaco** and **hisab**, and the **2026-06-04 accretion** adds six more Volume 1 ports back on the 6.0.x workflow — **agnosys**, **kybernet**, **ai-hwaccel**, **avatara**, **kavach**, and **nous** — bringing seven of the ten Volume 1 ports to published receipts. The **2026-06-20 completion** runs the last three on fresh 6.2.x bench runs — **agnostik**, **hoosh**, and **ark** (graduated all the way from 5.1.10 deep-lag to 1.0.0) — and reframes **agnosys**, now **decomposed into agnodrm** with its syscall layer absorbed into the language: **all ten Volume 1 ports now have published receipts.** Seeded 2026-06-01, expanded 2026-06-04, completed 2026-06-20.

---

## What This Volume Is

Volume 1 was the 17-day-old baseline at Cyrius v5.5.4, pre-optimization-arc. Volume 2 was the mid-arc state-of-things at v5.10/v5.11 — explicitly *not* a re-measurement, by design. Volume 3 is where the actual numbers land: the four "Where Rust Still Wins" categories either close, narrow with a specific bound, or persist with a named reason; the optimization arc gets a closure verdict; and every Volume 1 port gets a fresh CSV at a 6.0.x measurement point.

The honest framing carried forward from Volume 2: **what's measured is recorded; what hasn't been re-benchmarked stays un-asserted.** Volume 3 does not wait for all ten ports to publish at once — that would mean sitting on real receipts until the slowest one is ready. Instead each port enters Volume 3 the moment its 6.0.x re-bench exists, with its source date and commit attached. This is the same "every claim has a receipt" rule as Volumes 1 & 2; the only change is cadence.

Why now: the deep-lag tail is collapsing. abaco and hisab both sat on v5.7.x pins through the whole optimization arc (abaco 5.7.23, hisab 5.7.10 — see Volume 2's deep-lag table). Both have now graduated onto the 6.0.x workflow, which is exactly the before/after the ledger exists to measure. As more of that tail rolls forward, more ports come online here.

---

## abaco — number theory / DSP / math (re-measurement)

abaco is the canonical closed-loop entry in [Volume 1](port-ledger-volume-1.md#4-abaco--math--dsp--number-theory): the port that *requested* a hardware `u64_mulmod` primitive from Cyrius, got it shipped in v4.8.5, and re-measured a ~12× Miller-Rabin win. Volume 3's job is to answer the question Volume 1 left open: **did that win hold across the optimization arc and the 6.0.x crossing?**

It held. Source: `abaco/docs/benchmarks.md` + `abaco/bench-history.csv` (same `.bcyr` harness throughout). Three reference points — **baseline** (2026-04-07, before the 4.8.5 math-pack), **optimized** (2026-04-15, after `mod_mul`/`mod_pow` moved onto hardware `u64_mulmod`/`u64_powmod`), and **6.0.1** (2026-05-26):

| Benchmark | baseline `04-07` | optimized `04-15` | 6.0.1 `05-26` | net |
|-----------|-----------------:|------------------:|--------------:|-----|
| `is_prime_small` | 17,000 ns | 2,000 ns | **1,000 ns** | **−94%** |
| `is_prime_large` | 99,000 ns | 4,000 ns | **4,000 ns** | **−96%** |
| `next_prime` | 24,000 ns | 2,000 ns | **2,000 ns** | **−92%** |
| `totient` | 456 ns | 462 ns | **420 ns** | −8% |
| `fibonacci` | 569 ns | 595 ns | **462 ns** | −19% |
| `binomial` | 521 ns | 521 ns | **488 ns** | −6% |
| `factor_small` | 532 ns | 538 ns | 551 ns | ~flat |
| `factor_large` | 3,000 ns | 4,000 ns | 3,000 ns | ~flat |

**Reading it.** The order-of-magnitude primality wins are *not* a 6.0.x artifact — they landed with the 4.8.5 hardware-modmul collapse (the Volume 1 closed loop) and **held byte-for-byte across the 5.7.23 → 6.0.1 upgrade**. That "held" is itself the receipt Volume 3 came to collect: a deep-lag port can cross two major language eras and a full optimization arc without losing its hot-path win. On top of that, 6.0.1 added a further ~2× on `is_prime_small` (2,000 → 1,000 ns) and single-digit-percent gains on the f64 scalar paths (`totient`, `fibonacci`, `binomial`). **No benchmark regressed across the 2.2.x arc** — the "prove no regression held" evidence for abaco's P(−1) hardening pass.

(Small-end times are whole-microsecond-quantized by the harness; sub-µs f64 ops are reported in ns. The CSV carries 76 benchmarks across the suite; the eight above are the number-theory + classic-math core that Volume 1 deep-dived.)

**Verdict for the ledger:** abaco closes Volume 1's "is the closed-loop win durable?" question — *yes, durable across the arc, with incremental 6.0.x gains on top.*

---

## hisab — higher math / geometry / linear algebra (new port receipt)

hisab was not one of Volume 1's ten — it ports the higher-math / 3D-geometry / linear-algebra surface (transforms, ray tests, calculus, FFT, spatial structures, collision). Its receipt is a Rust-vs-Cyrius head-to-head, not a Cyrius-version delta. Source: `hisab/docs/benchmarks-rust-v-cyrius.md` (hisab v2.2.0; Rust criterion v0.5 release / f32 via glam SIMD, final run 2026-03-31; Cyrius `bench.cyr`, run 2026-04-15; x86_64 Linux).

This is a **"Where Rust Still Wins" entry by construction** — and the ledger says so plainly:

| Operation | Rust (ns) | Cyrius (ns) | Ratio | Why |
|-----------|----------:|------------:|------:|-----|
| `ease_in_out` | 0.60 | 403 | 672× | f32 inline vs f64 fn-call |
| `derivative` | 1.2 | 459 | 383× | fn-call overhead on a trivial op |
| `ray_sphere` | 2.9 | 492 | 170× | f32 SIMD vs f64 scalar |
| `ray_aabb` | 5.3 | 475 | 90× | f32 slab vs f64 slab |
| `mat4 inverse` | 20.1 | 745 | 37× | f32 SIMD vs f64 Cramer |
| `simpson_100` | 142.1 | 5,000 | 35× | one fn-call per sample |
| `slerp` | 21.1 | 680 | 32× | f32 SIMD vs f64 trig + heap |

The gap is honest and decomposable: heap allocation per Vec3/Quat/Mat4 (~200–400 ns), f64-vs-f32 (~1.5–2×), no SIMD on the f64 path (~2–4×), and fn-call overhead on trivial wrappers (the 400–700× cases are *all* call-overhead-dominated). **This is the inlining + zero-copy + SIMD gap from Volume 1's categories 1 & 3, measured on a fresh port.**

Where Cyrius wins is the structural axis the per-op numbers don't show:

| Metric | Rust | Cyrius |
|--------|------|--------|
| Binary | ~800 KB dynamic | **511 KB static** |
| Build | seconds | **instant** |
| Precision | f32 (~1e-7) | **f64 (~1e-12)** |
| Dependencies | 9 crates | **1** (sakshi) |
| Source | 33,612 lines | **15,676 lines** |

**The lib has grown past its port baseline.** The post-re-port CSV runs (2026-05-28/29, commits `8a08c99`/`b1165f9`) carry benchmarks that did not exist at the v2.2.0 head-to-head — `vec3_dot_x64`, `vec4_dot_x64`, `m4_mul_x16`, `m4_transform_x64` (batch/x64 paths) and `perlin_2d`. hisab is now v2.6.5; it is a bigger library than the one that was ported, and the new batch surface is exactly where the typed-simd ABI (v5.10.x, 11 phases) is meant to close the per-element gap. **A clean 6.0.x head-to-head re-bench is therefore still pending** — the current CSV is the regression-trail record (its own doc warns "numbers vary by runner," and the 2026-05-28/29 runs swing 2–7× run-to-run), not a citable absolute-speed receipt. hisab enters Volume 3 with its v2.2.0 head-to-head as the published baseline and an explicit *re-bench-pending* flag on the grown surface.

**Verdict for the ledger:** hisab is an open category-1/3 receipt — the f32-SIMD-vs-f64-scalar gap is real and named; closing it depends on inlining + the typed-simd ABI reaching these paths. Its structural wins (static binary, f64 precision, 1 dep, half the source) are already banked.

---

## agnodrm (was agnosys) — kernel-interface lib, decomposed (re-measurement + reframe)

Volume 1's port #1 was **agnosys** — the kernel-interface library, frozen at Cyrius v1.0.0 against Rust v0.51.0 with the headline structural sweep (59× smaller binary, ~3× fewer lines, 0 deps, 1,462× faster compile) and a packed-error hot-path claim. That entry is now **superseded by a decomposition**, and the honest story is the more interesting receipt.

agnosys was the project's **Linux kernel system-hooks layer** — the host system interface that, over time, accreted far more than a system interface should: trust, security/MAC/audit, pam, firmware, logging. When AGNOS deviated from the Linux path toward its sovereign kernel, an audit (2026-06-19) found the over-scope and dispersed it: the **per-arch syscall layer moved into `cyrius` itself — the language became the syscall provider** (sovereignty all the way down; nothing calls a hooks lib for syscalls anymore), trust → `sigil`, security/mac/audit → `kavach`, pam → `aegis`, logging → `sakshi`. What remains is **`agnodrm` 1.4.4** — the device/DRM model (udev enumeration + DRM/KMS), the error/util core, and the Linux-eccentric bootloader/update/fuse group parked post-v1.

The clearest proof of the decomposition is in the benchmark surface itself. Volume 1's agnosys numbers measured `getpid`/`getuid`/`validate_pin`/`ct_streq`/MAC-profile ops — **none of those survive in agnodrm**, because that work left the repo (the syscall benchmarks went where the syscalls went: into the language). A fresh run on the current 9-module remnant (`bash scripts/bench-history.sh`, cycc 6.2.26, 2026-06-20, commit `ccf352e` — 18 benchmarks across 6 groups) measures what agnodrm *is* now:

| Group | Benchmark | time |
|-------|-----------|-----:|
| error | `syserr_pack` | 4 ns |
| error | `from_errno_eperm` | 64 ns |
| error | `ok_create` | 55 ns |
| util | `wrap_syscall_ok` | 336 ns |
| bootloader | `validate_cmdline_safe` | 499 ns |
| bootloader | `is_dangerous_token_hit` / `miss` | 111 / 117 ns |
| update | `compare_versions` / `validate_ver_good` | 226 / 170 ns |
| udev | `parse_subsystem` | 44 ns |
| fuse | `starts_with_hit` / `miss` | 13 / 6 ns |
| string | `streq_16ch` / `memeq_16` / `strlen_16ch` | 53 / 31 / 11 ns |
| string | `map_get_hit` / `map_get_miss` | 68 / 37 ns |

**Reading it.** The packed-error core that Volume 1 hung its hot-path claim on **survives and is still at the floor** — `syserr_pack` is 4 ns. The one honest movement is the allocator-touching pair, `from_errno_eperm` 64 ns and `ok_create` 55 ns, elevated from their old ~21 / ~14 ns; that is the documented cyrius 6.0.64 allocator-spinlock cost (recorded at agnodrm 1.4.1) — a structural change carried in the open, not noise. (Single-estimate-per-commit on a shared runner — direction-of-motion, not stabilized absolute speed.)

The structural numbers are where the decomposition shows hardest, and they must **not** inherit agnosys's old 59× headline — that figure belonged to the 20-module library, not this remnant:

| Metric | old agnosys (Vol 1) | agnodrm now (v1.4.4) |
|--------|--------------------:|---------------------:|
| Scope | ~20 modules | **9 modules** (device/DRM + bootloader/update/udev/fuse + error/util) |
| Core lib | 55,688 B (whole lib) | **35,892 B** |
| Source | 9,884 lines | **4,137 lines** |
| Deps | 0 | **0** |
| Rust comparand | v0.51.0 head-to-head | **none valid** — the decomposed scope has no Rust twin |

**Verdict for the ledger:** agnosys's Volume 1 entry closes by **decomposition, not by a speed delta** — the honest receipt is that an over-scoped lib was audited and dispersed, its syscall surface absorbed into the language itself. agnodrm is the small sovereign device/DRM remnant (35,892-byte lib, 4,137 lines, 0 deps); the packed-error core (`syserr_pack` 4 ns) held, the alloc paths carry the documented 6.0.64 regression, and there is **no current Rust comparand** because the measured scope no longer maps onto the Rust agnosys. The old 59× / 334× structural headline stays in Volume 1 where it was measured — it described a library that no longer exists in that form.

---

## kybernet — PID 1 init system (re-measurement)

kybernet is [Volume 1](port-ledger-volume-1.md#2-kybernet--pid-1-init-system)'s entry #2: the PID-1 init binary that re-ported from Rust to Cyrius at v0.9.0, landed a 486 KB binary against Rust's 6.7 MB, and posted single-digit-nanosecond hot paths. Volume 1's headline numbers came from a Rust-vs-Cyrius head-to-head doc (`docs/benchmarks-rust-v-cyrius.md`, Cyrius side at v1.0.0). Volume 3's job is the one that doc could not do: it had no Cyrius-side version trail. kybernet now has one — a clean intra-6.0.x trend across the codegen arc.

Source: `kybernet/benches/history.csv` (the per-commit `.bcyr` bench trail), three reference points, all on the 6.0.x workflow, same harness throughout — **v1.2.3** (commit `676b8d5`, Cyrius pin **6.0.14**, run 2026-06-01), **v1.3.0** (commit `f915043`, pin **6.0.26**, run 2026-06-01), and **v1.3.1** (commit `1642373`, pin 6.0.26, run 2026-06-03). The repo head is v1.3.3 on pin 6.0.56 (`VERSION` + `cyrius.cyml`); the latest CSV run is the v1.3.1 tree, so this is a current-cycle receipt. Twelve of the suite's 51 benchmarks — the hot-path, service-op, and memory core Volume 1 deep-dived:

| Benchmark | v1.2.3 `6.0.14` | v1.3.0 `6.0.26` | v1.3.1 `6.0.26` | net |
|-----------|----------------:|----------------:|----------------:|-----|
| `classify_signal` | 3 ns | 3 ns | **3 ns** | flat |
| `is_mounted(/proc)` | 56 ns | 52 ns | **54 ns** | ~flat |
| `alloc(4 sizes burst)` | 30 ns | 23 ns | **23 ns** | −23% |
| `memset(128 bytes)` | 195 ns | 192 ns | **185 ns** | −5% |
| `getuid` | 322 ns | 316 ns | **278 ns** | −14% |
| `epoll_wait(timeout=0)` | 496 ns | 484 ns | **464 ns** | −6% |
| `seccomp_build(5 syscalls)` | 476 ns | 486 ns | **446 ns** | −6% |
| `capability_set(new+3push)` | 633 ns | 600 ns | **530 ns** | −16% |
| `hashmap(3 set+4 get/has)` | 1,330 ns | 1,234 ns | **1,188 ns** | −11% |
| `klog2_sim(4 writes)` | 1,536 ns | 1,482 ns | **1,331 ns** | −13% |
| `seccomp_basic_service+build` | 2,484 ns | 2,437 ns | **2,297 ns** | −7% |
| `epoll(new+add+close)` | 8,061 ns | 7,926 ns | **7,785 ns** | −3% |

**Reading it.** Two things hold at once. First, the hot path **does not move**: `classify_signal` is 3 ns at all three points, `is_mounted(/proc)` sits at 52–56 ns — these are already at the switch-dispatch / cached-lookup floor and the codegen arc has nothing left to give there. That stability is itself the receipt: the single-digit-nanosecond claim Volume 1 banked at v1.0.0 is still true a major-language-era and three minor cycles later. Second, everything with real instruction volume — the allocator-touching, syscall-wrapping, and struct-building paths — slid consistently *down* across 6.0.14 → 6.0.26. `capability_set` −16%, `klog2_sim` −13%, `getuid` −14%, `hashmap` −11%. Nothing in the twelve regressed.

This is the direction-of-motion evidence — but the receipt is precise about what drove it, because the two legs of the trend differ. The **v1.3.0 cut** (676b8d5 → f915043) was not a pure-toolchain advance: alongside the 6.0.14 → 6.0.26 pin bump it landed a hand-written **refactor/optimization pass** on three source files (`privdrop.cyr`, `reaper.cyr` — 5 log-writes collapsed to 1 per reaped pid — and `sandbox.cyr`; +74/−97 lines, per the 1.3.0 CHANGELOG's own "refactor/optimization pass" heading). The **v1.3.1 cut** (f915043 → 1642373) *is* src-clean — its `git diff -- src/` is empty and the 1.3.1 CHANGELOG calls it "dependency + lock + doc only." So the honest attribution is: the broad single-to-double-digit-percent improvement is the **combined** product of the 6.0.x codegen arc and kybernet's own 1.3.0 optimization pass — the band kybernet's CHANGELOG 1.3.2 later reported as "bench gate broadly improved (50/51 faster)" on the subsequent pure 6.0.26 → 6.0.53 toolchain leap.

(The trend points are whole-ns from the `.bcyr` harness and carry run-to-run jitter at the sub-100 ns end — `is_mounted` reads 56→52→54, which is noise, not a regression. Across all 51 benchmarks the worst adjacent-point swing in this trail is 1.41× — this is a *stable* trend record, not a 2–7× noisy trail. The honest read is *flat at the floor, down in the body*; the percentages above are the v1.2.3→v1.3.1 endpoints, not a claim of monotonic descent at every point. The Volume 1 doc's own Cyrius v1.0.0 figures — e.g. `classify_signal` 2 ns, `is_mounted (cached)` 90 ns — are a different harness/machine and are *not* folded into this trend; they appear here only as the structural baseline below.)

| Structural metric | Volume 1 (v1.0.0/1.0.1) | now (v1.3.x) |
|--------|------|------|
| Binary | 486 KB | **1.37 MB** (`build/kybernet`, 1,374,304 bytes) |
| Tests | 140 | **177** (`CHANGELOG` 1.3.3: 177 passed, 0 failed) |
| Cargo deps | 0 | **0** |
| libc | none (direct syscalls) | **none** |

**The binary grew, and the ledger says why.** Volume 1's 486 KB already linked the full transitive trust stack — argonaut + libro + sigil + sakshi (the v1.0.0 doc says so explicitly). The 486 KB → 1.37 MB growth is therefore *not* first-time trust-stack linkage; it is the **dist-bundle adoption** at the 1.1.x rebase (kybernet switched from selective `src/<module>.cyr` slim-imports to full `dist/<dep>.cyr` bundles for agnosys/agnostik/libro/patra — 447 KB at 1.0.2 → 1.29 MB at 1.1.1, per CHANGELOG), plus the 1.3.2 stdlib snapshot vendoring ~34 KB of **dead, NOP-retained non-Linux platform peers** (Windows/macOS/AGNOS-target modules, unreachable on a Linux PID-1 build). That is bundle-and-snapshot accretion, not bloat in the hot path — and it is still a zero-Cargo-dep, no-libc, direct-syscall PID-1 binary, which is the structural axis Volume 1 actually banked. The 1.3.2 cut did add a `thread_local` stdlib pin (sigil 3.6.0's per-thread `crypto_scratch` requires it), a genuine new feature dependency, but the trust-stack libraries themselves were present from v1.0.0.

**Verdict for the ledger:** kybernet's Volume 1 hot-path claim is durable — the single-digit-nanosecond floor (`classify_signal` 3 ns, `is_mounted` ~54 ns) held across the 6.0.x crossing, and the 6.0.x codegen arc *plus* the 1.3.0 optimization pass bought a clean 5–16% on the allocator/syscall body with no regressions in the twelve. The fresh-6.0.x Rust-vs-Cyrius re-bench is the one piece still pending: the only head-to-head on file is the v1.0.0 doc, so the Rust-side ratios stay at their Volume 1 values until a 6.0.x head-to-head is run.

---

## ai-hwaccel — AI hardware-accelerator detection / planning (Rust-vs-Cyrius head-to-head)

ai-hwaccel is Volume 1's entry #6 — the GPU/accelerator-detection port whose headline was a **131-crate dependency graph collapsing to zero**. Its citable receipt is a Rust-vs-Cyrius head-to-head, not a Cyrius-version delta. Source: `ai-hwaccel/docs/benchmarks-rust-v-cyrius.md` (ai-hwaccel v1.2.0; Rust criterion, final run commit `84dfb0d`, 2026-04-06; Cyrius `.bcyr` harness, same machine), with a supplementary 6.0.x direction-of-motion read from `bench-history.csv`. Pin is `cyrius = "6.0.54"` (`cyrius.cyml`); current `VERSION` is 2.3.7.

The structural wins are the banked half of the receipt:

| Metric | Rust | Cyrius (v1.2.0) | Delta |
|--------|------|----------------:|-------|
| Binary size | 708 KB (release, stripped) | **217 KB** | **−69%** |
| Compile time | ~1.8 s (release, cached) | **215 ms** | **−88%** |
| Source LOC | 11,278 | **5,602** | **−50%** |
| Dependencies | 131 crates (Cargo.lock) | **0** | **−100%** |
| Tests | 460 `#[test]` | **518 assertions** | +13% |

The per-op runtime axis is a **"Where Rust Still Wins" entry by construction** — and the ledger says so plainly. ai-hwaccel is a CLI detection tool where end-to-end latency is dominated by 100ms+ subprocess calls (`nvidia-smi`, `rocm-smi`), so the per-call gap is irrelevant to wall time, but the numbers are honest:

| Benchmark | Rust (LLVM) | Cyrius | Ratio | Why |
|-----------|------------:|-------:|------:|-----|
| `estimate_memory 70B FP16` | 257 ps | 9 ns | 35× | LLVM const-fold vs explicit if-chain |
| `bits_per_param (all)` | 295 ps | 3 ns | 10× | single instruction vs branch |
| `7B full finetune GPU` | 3.29 ns | 34 ns | 10× | fixed-point estimate path |
| `parse_vulkan_output 2gpu` | 1.85 µs | 3 µs | 1.6× | both I/O-bound string scan |
| `parse_cuda_output 8gpu` | 5.80 µs | 18 µs | 3× | both I/O-bound string scan |
| `best_available (13 dev)` | 39.56 ns | 858 ns | 22× | iterator fusion vs linear scan |
| `count_by_family GPU (13 dev)` | 7.88 ns | 272 ns | 35× | sorted-collection vs linear scan |
| `json_serialize (13 dev)` | 4.89 µs | 27 µs | 6× | str_builder vs serde pre-sized buffer |

**Reading it.** The gap is the same shape as every other detection-class port: sub-ns Rust ops reflect LLVM constant-folding and branch-elimination (these become single instructions), while Cyrius emits explicit if-chains — 10–35× slower but still sub-10 ns. **Parsing is the closest category (1.6–3×)** because both implementations are I/O-bound with identical string-scan logic; that is the category that actually matters for a tool whose hot loop is reading subprocess output. The registry-query 16–35× gaps are linear-scan-vs-iterator-fusion, not an algorithmic loss.

The 6.0.x re-bench is a **mixed record**, and the ledger separates the two halves rather than averaging them. On the high-iteration registry metrics (100,000 iters, avg=min=max each run) the 6.0.x trail is stable and citable: `has_accelerator_13dev` reads 27–42 ns across the June bench runs (commits `b9af260`…`36350e3`, bench-run timestamps 2026-06-01→06-04) vs 22–23 ns on the pre-6.0.x April runs (`4f5e272`/`5e7672d`, 2026-04-13) and 23 ns in the v1.2.0 doc; `total_memory_13dev` reads 139–163 ns vs 122–136 ns April vs 123 ns doc; `count_family_gpu_13dev` reads 298–354 ns vs 276–285 ns April vs 272 ns doc. That is a small **regression** from the April baseline — consistent with a different/louder runner, not an arc loss — but the order of magnitude holds. The low-iteration paths (parsing at 100 iters, JSON at 2,000 iters) swing 2–10× run-to-run in the June era (`json_serialize_13dev` max swings to 231,000 ns; `parse_cuda_8gpu` max to 89,000 ns), so those are **regression-trail telemetry, not citable absolute-speed receipts** — the same honesty bar the hisab receipt set.

**The lib has grown past its port baseline**, exactly like hisab: the v1.2.0 head-to-head measured a 217 KB binary and 5,602 source lines; the current 6.0.54 build is 288.9 KiB (`build/ai-hwaccel`, 295,880 bytes) over 6,159 source lines (`src/*.cyr`), and the registry suite has since grown new JSON benchmarks (`json_system_io`, `json_plan`, `json_training`, first appearing at commit `c50a57a`) that did not exist at the head-to-head. A clean 6.0.x **head-to-head** re-bench is therefore still pending against the grown surface; ai-hwaccel enters Volume 3 with its v1.2.0 head-to-head as the published baseline and its stable-metric 6.0.x trail as the direction-of-motion check.

**Verdict for the ledger:** ai-hwaccel's structural wins (−69% binary, −100% deps, −50% source) are banked and confirmed durable into 6.0.x; the per-op gap is the same const-fold/iterator-fusion category as the other detection ports, and **irrelevant to a tool whose wall time is 100ms+ subprocess calls.** The high-iteration registry metrics held their order of magnitude across the 6.0.x crossing with a small runner-attributable regression; the low-iteration parsing/JSON paths remain a noisy trail, not a speed receipt.

---

## avatara — divine archetype overlay (re-measurement)

avatara is [Volume 1](port-ledger-volume-1.md#7-avatara--divine-archetype-overlay)'s entry #7 — the port whose headline was **2,761× faster cached access** and **53× faster lookup**, both attributed there not to a compiler trick but to a data-structure rethink that became possible once the code left serde's reach (the Rust version marshaled via `serde_json` on every access; Cyrius resolves the struct once and the cache hit is a pointer read). Volume 3's job is the same question the other re-measurements ask: **did the cached-access win survive the crossing onto the 6.0.x workflow?**

It survived, and it's stable. Source: `avatara/bench-history.csv` (the `bench.cyr` per-version trail, 13 cuts from 2.4.0 → 2.7.0, dated 2026-06-02/03) and `avatara/cyrius.cyml` (pin `cyrius = "6.0.49"`, version 2.7.0). Two trend points — an early-trail cut (**2.4.0**) and the current head (**2.7.0**), both on the 6.0.49 pin — bracket the cached/registry/query surface that Volume 1 deep-dived:

| Benchmark | 2.4.0 | 2.7.0 | over the trail |
|-----------|------:|------:|----------------|
| `registry/all_profiles` | 20 ns | **24 ns** | 20–26 ns (one 39 ns outlier at 2.6.0) |
| `registry/lookup_by_name` | 2,000 ns | **2,000 ns** | flat 2,000 ns at every cut |
| `registry/query_courage_0.9` | 7,000 ns | **5,000 ns** | tightened to 5,000 |
| `registry/by_tradition` | 22,000 ns | **15,000 ns** | −32% |
| `history/query_civilization` | 55,000 ns | **43,000 ns** | −22% |
| `affinity/similar_to_5` | 559,000 ns | **536,000 ns** | ~flat |

**Reading it.** The two numbers Volume 1 hung its receipt on are the two that hold cleanest. `registry/all_profiles` — the "single `load64` cached-pointer return" path that produced the 2,761× figure — sits at 20–26 ns across all thirteen cuts, matching the **19 ns** the head-to-head source doc recorded for that single-`load64` path (the CSV trail opens at 20 ns at 2.4.0); the lone 39 ns blip at 2.6.0 reverts to 24 ns at 2.7.0. `registry/lookup_by_name` is **flat at 2,000 ns at every single cut** — the same ~2 µs that backed the 53× lookup claim. The pointer-cache architecture didn't just survive the 6.0.x crossing; it's the most boring line in the file, which is the point. The aggregate-query paths (`by_tradition`, `query_civilization`) drifted *down* 22–32% across the trail. **No cached/registry/query benchmark regressed** from 2.4.0 to 2.7.0.

**Two honesty flags, both inherited from the hisab precedent.** First: the *single-iteration micro-benchmarks* in this same CSV are a regression-trail record, not citable absolute speed. `kabbalah/single_profile` swings 185 → 367 → 293 ns and `hindu/all_devas` swings 7 → 22 → 9 ns across adjacent cuts — these are single-call paths quantized hard by the harness, and their run-to-run swing is noise, not motion. They are excluded from the table above by construction; only the stable cached/registry/aggregate paths are cited as numbers. Second: avatara's head-to-head doc, `avatara/benchmarks-rust-v-cyrius.md`, is a **pre-6.0.x baseline** — Rust v1.1.0 (Criterion v0.8, `--release`, 2026-04-01) vs Cyrius **v2.0.1 on cc3 3.7.0** (2026-04-12). That is where the 92×/2,761×/53× figures were originally measured; it is *not* a current 6.0.x head-to-head, so it stays the published Rust baseline rather than a fresh receipt.

The structural wins, by contrast, are bankable now and have grown past the port baseline:

| Metric | Rust v1.1.0 | Cyrius (head-to-head v2.0.1) | Cyrius 2.7.0 (current) |
|--------|------------:|------------------:|------------------:|
| Binary | ~800 KB–1.2 MB | 874 KB | **912 KB** (`build/avatara`, 934,440 B) |
| Source LOC | 18,804 | 15,644 | **18,232** (`src/*.cyr`) |
| External deps | 5 | **0** | **0** (stdlib + sakshi only) |
| Traditions | 19 | 22 | **27** |
| Archetypes | ~280 | 329 | **374** |

**The lib has grown past its port baseline** — 22 → 27 traditions and 329 → 374 archetypes (the current README count) since the v2.0.1 head-to-head, with the source climbing back to 18,232 lines as the new traditions (Solar, Canaanite, Etruscan) landed. The dependency count stayed at zero external the whole way. New benchmark rows that didn't exist at the head-to-head — `solar/all_4`, `canaanite/all_4`, `etruscan/all_4` at 2.7.0 — measure 5/14/6 ns, right in the cached-access band.

**Verdict for the ledger:** avatara closes Volume 1's durability question on the axis that mattered — *the pointer-cache cached-access and lookup wins held flat across the 6.0.x crossing* (registry lookup is the same 2,000 ns at every cut; cached all-profiles stayed in its ~20 ns band, against the 19 ns the source doc recorded). A clean **6.0.x Rust-vs-Cyrius re-bench is still pending** on the grown 374-archetype / 27-tradition surface — the v2.0.1 head-to-head is the standing Rust baseline, and the single-iteration micro-benchmarks remain a noisy regression-trail, not citable speed.

---

## kavach — sandbox execution framework (version-trend re-measurement)

kavach was [Volume 1's eighth port](port-ledger-volume-1.md#8-kavach--sandbox-execution): a Rust→Cyrius port of a 10-backend sandbox framework whose headline receipt was a 448-crate → 1-dep collapse and a `sandbox_full_lifecycle` that dropped from 3.06 ms (tokio per-iteration) to 6 µs (synchronous). Volume 1 froze that against Cyrius v3.0.0 on toolchain 4.4.3. Volume 3's job: a fresh trend on the **6.0.x** surface, and the answer to "did the port keep moving after it shipped?"

It did — and the most recent cut is the cleanest receipt in the file. Source: `kavach/benches/bench-history.csv` (the `tests/kavach.bcyr` harness via `cyrius bench`, all six 3.4.0 labels run 2026-06-02 and added in data commit `46e82bb` "ac scan") plus `kavach/CHANGELOG.md`; kavach v3.4.0, Cyrius pin `6.0.43` (held since v3.3.3; v3.3.0–3.3.2 ran on `6.0.40`, same 6.0.x line). The Rust-vs-Cyrius absolute table from `benchmarks-rust-v-cyrius.md` is the Volume 1 baseline and is **not** re-cited as a fresh receipt — it was measured at Cyrius v3.0.0 / toolchain 4.4.3, pre-6.0.x.

**The 3.4.0 Aho-Corasick win (the citable headline).** The code scanner used to run ~109 per-pattern `cstr_contains` walks of the artifact (O(patterns × n × m)); 3.4.0 replaced that with a single O(n) Aho-Corasick pass. The CSV carries both paths benchmarked side-by-side in the same run (2000 iterations each) on a ~16 KB benign artifact (worst case for the old path):

| Benchmark (v3.4.0, 16 KB artifact) | time | note |
|------------------------------------|-----:|------|
| `code_scan_large_naive` (old, ~109 scans) | **6.60 ms** | O(patterns × n) |
| `code_scan_large_ac` (new, one pass) | **0.54 ms** | O(n) + per-pattern lookup |

6,604,000 ns / 542,000 ns = **~12.2× faster**, and the CHANGELOG notes the ratio approaches the pattern count (~100×) on multi-MiB artifacts because naive is O(patterns × n) and AC is O(n). Because both paths are measured in the same run, this ~12× delta clears the µs-scale run-to-run noise by a wide margin. This is a Cyrius-side algorithmic win — an AC automaton hand-written in the port, not a compiler gift.

**The stable-point trend (3.3.0 → 3.4.0, ns).** The micro-op core held flat across the cuts — the receipt that the security-hardening arc (the 3.3.x bounds-checked-slice / Result-`_r` / container-entropy work) cost nothing measurable:

| Benchmark | 3.3.0 | 3.3.4 | 3.4.0 |
|-----------|------:|------:|------:|
| `score_backend_process_strict` | 37 ns | 38 ns | 46 ns |
| `cgroup_wrap_argv` | 545 ns | 565 ns | 545 ns |
| `http_allowlist_hit` | 74 ns | 83 ns | 84 ns |

**Reading it.** Two things are true at once. The pure-integer and pointer-loop core is *stable to the noise floor* across the whole 3.3.x hardening arc — `cgroup_wrap_argv` returns to 545 ns at 3.4.0, `http_allowlist_hit` sits in the low 80s — confirming the "no measurable cost" claims in the per-cut CHANGELOGs were honest. (The µs-scale rows in the same CSV are a deliberately noisy regression-trail — quantized to round thousands and swinging ~1.5–2× run-to-run — so only the stable ns micro-ops are read as direction-of-motion here; none of the noisy µs rows are cited as absolute speed.) The lone real movement is the AC collapse, which is exactly where a port *should* spend effort: not chasing the compiler's unoptimized-integer tax (the Volume 1 "10–25× slower on tight integer ops" gap, untouched here), but on the algorithmic hot path the scanner actually walks. One honest caveat the CSV surfaces: `gate_clean_output` reads 370,000 ns at 3.4.0 vs ~13,000–18,000 ns across 3.3.x — that row runs all three scanners including the new AC-backed code path, and the jump is recorded, not smoothed; it is the one number in the trend that moved the wrong way and is flagged rather than dropped.

**Structural axis (vs the Volume 1 port baseline).** The dependency and security posture from Volume 1 are intact; the binary has grown:

| Metric | Rust v2.0.0 | Cyrius port (Vol 1, v3.0.0) | now (v3.4.0) |
|--------|------------:|----------------------------:|-------------:|
| External deps | 448 crates | **1** (sigil) | **2 vendored** (sigil 3.5.9 + agnosys 1.3.0 override) |
| Source lines | 25,935 | 5,775 | 6,807 (`.cyr` in `src/`) |
| Binary (stripped) | ~2.4 MB | 344 KB | 1.35 MB (`build/kavach`) |
| Security fixes in-port | — | 9 CWE-class | 9 CWE-class (held) |

The −99.8% dep collapse and the 9-finding hardening pass are banked from Volume 1. The binary grew ~3.8× off the port-time 344 KB figure — and both endpoints are *stripped* measurements (the Vol 1 number is stripped, all-backends; `file build/kavach` confirms the current artifact is stripped too, no symtab), so this is a like-for-like comparison, not an artifact of build mode. The growth is real and benign — sigil 2.1.2 → 3.5.9 plus the vendored agnosys override, the hand-written AC automaton, and the 3.3.x hardening code all add `.text`/`.rodata` — a direction marker on a still-tiny binary, not a regression.

**Verdict for the ledger:** kavach is a *post-ship-still-moving* version-trend receipt. The hardening-arc cuts held the micro-op core flat to the noise floor (the "no regression" evidence Volume 3 came to collect), and the v3.4.0 Aho-Corasick pass is a clean, CSV-backed **~12× algorithmic win** on the code-scan path, measured side-by-side and robust to the µs-scale noise — a port improving its own hot path on the 6.0.x surface, independent of any compiler optimization. The Volume 1 Rust-vs-Cyrius absolute table stays the published baseline pending a fresh 6.0.x head-to-head; the dep collapse and CWE hardening are banked.

---

## nous — package resolver (version-trend re-measurement)

nous is Volume 1's port #10 — the [package resolver](port-ledger-volume-1.md#10-nous--package-resolver) shipped alongside ark, "structural cleanup — the algorithms stayed, the ecosystem stack dropped." Volume 1 gave it no benchmark table (it was a same-algorithm port), so there is no frozen v5.5.4 number to subtract from. What Volume 3 *can* collect is the receipt the port DID generate on its own: a five-point CSV trail across the 1.2.x hardening arc, all on the 6.0.x workflow. Source: `nous/bench-history.csv` (the `cyrius bench` harness, 18 benchmarks) + `nous/cyrius.cyml` (pin `cyrius = "6.0.3"`) + `nous/CHANGELOG.md`. nous is v1.2.5; the trend points are the local arc runs `1.2.0-local` through `1.2.4-local`, all timestamped 2026-05-27, with the earliest CSV anchor a pre-arc smoke run (`smoke-1777415331`, 2026-04-28).

The honest read first: this is a **regression-trail record, not an absolute-speed receipt.** The harness `max` column swings hard run-to-run (`validate_name` max ranges 132µs–678µs across the arc — e.g. 1.2.3's 148µs jumps to 1.2.4's 431µs in adjacent runs, ~3×) — that's scheduler noise on a non-isolated runner. But the `avg` and `min` columns are clean and flat across the five arc points, which is exactly the signal a stability trail exists to carry. Citing avg, three points (first / mid / last of the arc) plus the pre-arc smoke anchor:

| Benchmark | smoke `04-28` | 1.2.0 `05-27` | 1.2.2 `05-27` | 1.2.4 `05-27` |
|-----------|--------------:|--------------:|--------------:|--------------:|
| `resolve_mkt_hit` | 4 µs | 2 µs | 2 µs | **2 µs** |
| `validate_name` | 1 µs | 1 µs | 976 ns | **977 ns** |
| `search_100` | 92 µs | 95 µs | 94 µs | **95 µs** |
| `list_installed_100` | 15 µs | 15 µs | 14 µs | **15 µs** |
| `graph_resolve` | 11 µs | 10 µs | 10 µs | **10 µs** |
| `recipe_parse` | 18 µs | 19 µs | 18 µs | **18 µs** |
| `cycle_detect_20` | 24 µs | 22 µs | 22 µs | **22 µs** |
| `topo_sort_20` | 35 µs | 35 µs | 35 µs | **35 µs** |
| `recipe_db_load` | 5.823 ms | 7.474 ms | 7.118 ms | **7.313 ms** |

**Reading it.** The arc was a hygiene/codegen-workaround/return-annotation sweep (the 1.2.1–1.2.4 CHANGELOG entries) capped by a 1.2.5 *retraction* — the "issue-0001 Cyrius 6.0.1 `vec_get` miscompile" was investigated and **closed as not-a-defect** (the reproducer was self-defective; re-nesting every blamed site gives 271/0 on cycc 6.0.1 AND 6.0.3). The benchmark trail is the proof that retraction was safe to ship: across the whole sweep the hot paths held flat — graph resolution at 10µs, topo-sort at 35µs, cycle-detect at 22µs, the resolver micro-ops at 2µs — and the `resolve_mkt_hit` 4µs→2µs drop from the pre-arc smoke run is the one real movement, a ~2× win that landed early and stayed. The single honest *regression* in the trail is `recipe_db_load`: 5.823ms at the smoke point, ~7.1–7.5ms across the arc — disk-load work that got heavier, not faster, and the trail records it rather than hiding it.

The structural axis, the part the per-op µs don't show:

| Metric | Rust (v0.1.0 / v1.93) | Cyrius (nous 1.2.5) |
|--------|----------------------:|--------------------:|
| Binary | ~800 KB release | **217 KB** static (`build/nous`, 222,528 bytes) |
| External crate deps | 5 | **0** |
| Compile time | ~8 s | **<1 s** |
| Tests passing | — | **271/0** on 6.0.3 |

(The Rust column is from `nous/benchmarks-rust-v-cyrius.md`, the v1.0.0 head-to-head — but that doc was run at **Cyrius 5.1.7, 2026-04-16**, pre-6.0.x. Its per-op Rust-vs-Cyrius ratios, 2×–58×, are a Volume-1-era artifact, NOT a current receipt, and are not cited as such here. The dependency-collapse, binary-size, and compile-time facts are structural and carry forward; the speed ratios need a fresh 6.0.x head-to-head that does not yet exist. The doc's own Cyrius binary figure (412 KB) is likewise stale — the 217 KB above is the live `build/nous` stat.)

**Verdict for the ledger:** nous is a **stability receipt, not a speed receipt.** It had no Volume 1 number to beat, so its 6.0.x contribution is the flat avg/min trail proving a five-version hardening arc — including a "phantom codegen bug" retraction — left every hot path unmoved (271/0, benches unchanged), with one early 2× on `resolve_mkt_hit` banked and one honest `recipe_db_load` regression on record. A clean Rust-vs-Cyrius re-bench at 6.0.x is still owed.

---

## agnostik — shared types / domain primitives (re-measurement)

agnostik is Volume 1's shared-types / domain-primitives port, and the spot where Volume 1 named a **"Where Rust Still Wins"** category outright: serde string serialization, 5.8–6.8× on the agnostik roundtrip. Volume 3's job was to re-measure that category on the 6.2.x workflow — and the committed CSV had gone stale (frozen at 5.x-era rows), so the receipt required a **fresh run** (`scripts/bench-history.sh`, cycc 6.2.26, 2026-06-20, commit `b390347`, agnostik 1.3.1 / pin 6.2.11).

The serde tier — the exact Volume 1 weak spot — is where the codegen arc paid off. The CHANGELOG had claimed 6.2.x collapses in prose; the fresh run **confirms them in committed numbers**, against the 5.x-era baseline the CSV used to carry:

| `*_from_json` (deserialize) | 5.x baseline | 6.2.x fresh | net |
|---------|------------:|-----------:|-----|
| `accel_flags_from_json` | 6,000 ns | **803 ns** | **−87%** |
| `resource_limits_from_json` | 3,000 ns | **503 ns** | **−83%** |
| `injection_scores_from_json` | 2,000 ns | **376 ns** | **−81%** |
| `agent_stats_from_json` | 1,000 ns | **329 ns** | **−67%** |
| `token_usage_from_json` | — | **496 ns** | new |

Other tiers, same run: `token_usage_update` 88 ns, `accelerator_device_full` 296 ns, `version_to_str` 292 ns, `version_roundtrip` 666 ns, `security_context_full` 985 ns; the `*_to_json` serialize paths sit at 1–2 µs (whole-µs quantized).

**Reading it.** The deserialize collapse is real and now CSV-committed — the serde category Volume 1 flagged as a Rust win has narrowed sharply on the from_json side (sub-800 ns where it was multiple µs). One honest counter-movement belongs in the same receipt: the 1.0.0 **F-001 CSPRNG migration** moved `agent_id_new` ~65 → ~608 ns — a deliberate security trade (cryptographic IDs) that *inverts* Volume 1's old "Cyrius 1.4× faster on agent_id" headline. Feature cost, not regression. (Single-estimate-per-commit, whole-µs quantization, ±20–30% CI jitter — direction-of-motion, not stabilized speed.) The Rust head-to-head is a pre-1.0 legacy doc (Cyrius v0.95.0/cc2) and is **not** cited as a current comparand.

Structural: **392,840-byte** binary, **0** external deps (15 stdlib modules).

**Verdict for the ledger:** agnostik re-measures its Volume 1 weak category fresh at 6.2.x — the serde *from_json* paths dropped 67–87% off the 5.x baseline (the codegen-arc payoff, now in the CSV, not just the CHANGELOG); `agent_id` is slower **by design** (CSPRNG). Structural wins (sub-400 KB, 0 external deps) banked.

---

## ark — package manager (graduation + re-measurement)

ark is Volume 1's package-manager port and the ledger's **longest-running open item**: it sat at 0.8.0 on pin **5.1.10** — the extreme deep-lag tail, a port that pre-dated the pin convention — through the entire optimization arc. Volume 1 named it a "Where Rust Still Wins" example (zero-copy micro-ops: `cmd_create` 4×, `recent_10` 8×). The Volume 3 headline is that **ark has graduated**: as of **1.0.0 (2026-06-18, pin 6.2.21)** the full package manager is Cyrius end-to-end — resolve → plan → execute, native `.ark` packages (SHA-256 + Ed25519, fail-closed), shakti-escalated privileged steps, a mela marketplace path — **172/172 tests green, 0 external deps** (39 stdlib modules). The last deep-lag holdout is now on the leading edge.

The performance receipt is thinner, and the ledger says why. ark retired its `bench-history.sh` wrapper at 1.0 (benchmarking is now `cyrius bench tests/ark.bcyr`), so the committed CSV froze at its 2026-04-16 / 5.1.10 rows. A fresh run (cycc 6.2.26, 2026-06-20) produced current numbers — but they came in **higher** than the 5.1.10 baseline, on a **non-DCE build** (the run reported 3,888 unreachable fns / ~1 MB dead code + a 447 KB static-data warning) under pin-drift (cycc 6.2.26 vs pinned 6.2.21), as a single noisy run:

| Benchmark | 5.1.10 `04-16` | 6.2.x `06-20` (non-DCE) |
|-----------|---------------:|------------------------:|
| `cmd_create` | 187 ns | 748 ns |
| `config_default` | 227 ns | 682 ns |
| `db_search_20` | 1,239 ns | 2,379 ns |
| `db_integrity_20` | 1,005 ns | 4,357 ns |
| `txn_begin_commit` | 1,251 ns | 2,788 ns |
| `group_meta_pkg` | 68 ns | 53 ns |

**Reading it.** This is **not** a clean speed verdict and is explicitly not cited as one: two single noisy runs, two different toolchain eras, and a 6.2.x build that never had DCE applied (1 MB of unreachable code is real icache/layout pressure). The honest read is that ark's 1.0 microbench wants a **clean DCE-applied re-run** before any before/after claim — flagged, not buried. (`group_meta_pkg` going *down* on the same run is the tell that the rest is dominated by build/runner conditions, not a uniform algorithmic loss.) Volume 1's "Rust wins zero-copy micro-ops" note stays a pre-port figure.

**Verdict for the ledger:** ark's Volume 3 receipt is the **graduation** — the extreme deep-lag holdout reached 1.0.0, full package manager in Cyrius, 172/172 tests, 0 external deps. The microbench has fresh 6.2.x numbers on record but they ran high on a single non-DCE build, so they enter as flagged *direction-needs-a-clean-rerun* telemetry, not a speed receipt. Structural + milestone are the banked half.

---

## hoosh — LLM inference gateway (re-measurement)

hoosh is Volume 1's LLM-inference-gateway port, whose headline was a dependency collapse (200+ crates → a stdlib-only build, 0 external). Volume 1 left it without a Cyrius-side trend; Volume 3 now has one — and unlike the other three remaining ports, hoosh's committed CSV was already fresh, so the only gap was the single-point problem. A **repeat run** (cycc 6.2.26, 2026-06-20, commit `4e2aae1`) gives hoosh a clean **two-point 6.2.x baseline** (06-16 + 06-20) and resolves the apparent regressions in the first point as runner noise:

| Benchmark | 6.2.x `06-16` (n=1) | 6.2.x `06-20` (repeat) |
|-----------|-------------------:|----------------------:|
| `work_queue_push_pop` | 8 ns | **8 ns** |
| `estimate_tokens_per_provider` | 12 ns | **8 ns** |
| `route_matches_model` | 36 ns | **33 ns** |
| `cache_get_miss` | 57 ns | **51 ns** |
| `latency_bucket_find` | 72 ns | **56 ns** |
| `pool_available` | 7 ns | **4 ns** |
| `pool_reserve_commit` | 100 ns | **85 ns** |
| `cache_insert` | 91 ns | **86 ns** |
| `cache_get_hit` | 123 ns | **114 ns** |

Higher-cost ops (quantized): `route_select_20_providers` / `queue_*` / `batch_split_4` at 1 µs, `dlp_scan_clean_prompt` / `mcp_tools_list` at 4 µs, `mcp_tools_call` at 9 µs.

**Reading it.** The repeat is the whole point: every benchmark that *looked* like it regressed in the n=1 run (`pool_available` 7→4, `pool_reserve_commit` 100→85, `cache_insert` 91→86) **reverted on the second run** — runner noise, not motion. The genuine signal is a tier of sub-100 ns micro-ops at the floor (`work_queue_push_pop` 8 ns, `estimate_tokens` 8 ns, `route_matches_model` 33 ns). **No Rust ns head-to-head exists** — hoosh's `rust-old` bench CSV is header-only — so any cross-language *speed* ratio would be fabrication; only the binary (2,105,368 bytes) and dep-collapse (200+ crates → 0 external / 32 stdlib) are citable cross-language.

**Verdict for the ledger:** hoosh enters Volume 3 with a clean two-point 6.2.x baseline — the n=1 caveat is killed, the sub-100 ns gateway micro-ops are at the floor, and the apparent first-run regressions were noise. Structural dep-collapse banked; the Rust *speed* comparand does not exist (empty head-to-head CSV), so it stays uncited.

---

## Receipts Pending — The Wave

Volume 3 is seeded, not finished. What's still owed, and the gate on each:

- **The ten Volume 1 ports, re-benchmarked.** ✅ **All ten now have published receipts.** The 2026-06-04 wave landed seven (`abaco`, `agnosys` → now `agnodrm`, `kybernet`, `ai-hwaccel`, `avatara`, `kavach`, plus `nous` as a stability trail); the **2026-06-20 completion** ran the last three on fresh 6.2.x bench runs — **`agnostik`** (serde `from_json` collapse confirmed: 6,000→803 ns / 3,000→503 ns), **`hoosh`** (n=1 → clean two-point 6.2.x baseline), and **`ark`** (graduated 5.1.10 → 1.0.0; microbench flagged for a clean DCE re-run) — and reframed **`agnosys` → `agnodrm`** as a decomposition. The honesty bar held throughout: stale CSVs were *re-run*, not cited, and no number was published ahead of its measurement.
- **The four "Where Rust Still Wins" categories**, as measurement rather than direction-of-motion (Volume 2's conjecture table becomes Volume 3's verdict table). hisab already supplies fresh evidence for categories 1 (zero-copy / heap) and 3 (inlining on sub-ns ops).
- **The optimization-arc closure verdict** — O5/O6 codebuf compaction: shipped, retired, or still triage? Both Volume 2 and `cyrius-vs-rust-benchmarks.md` leave this open.
- **The held-cluster three** (mabda, cyrius-doom, samvada) — roll forward onto the 6.0.x surface, or enter Volume 3 with explicit "deliberately held" framing.
- **Cross-architecture comparison** — x86_64 vs aarch64 (vs rv64, once the v6.x backend lands) byte-identical-self-host divergence under the typed-simd ABI.

As the deep-lag tail collapses onto 6.0.x, each migrated port is a candidate receipt. abaco and hisab are the first two; the wave is opening.

---

## Audit Instructions

Same rule as Volumes 1 & 2 — every number here is reproducible on commodity hardware.

```sh
# abaco — the 6.0.x re-measurement trend
git clone https://github.com/MacCracken/abaco.git
cd abaco
cat docs/benchmarks.md          # the 3-point trend table
cat bench-history.csv           # full per-commit trail (76 benchmarks)
./scripts/bench-history.sh      # re-run; appends a fresh CSV row

# hisab — the Rust-vs-Cyrius head-to-head + grown surface
git clone https://github.com/MacCracken/hisab.git
cd hisab
cat docs/benchmarks-rust-v-cyrius.md   # v2.2.0 head-to-head (90 Rust / 21 Cyrius)
cat bench-history.csv                  # post-re-port runs, incl. new x64 batch ops

# the 2026-06-04 wave — six Volume 1 ports, each receipt reproducible
for p in agnosys kybernet ai-hwaccel avatara kavach nous; do
  git clone https://github.com/MacCracken/$p.git
done
cat agnosys/bench-history.csv          # packed-error core flat across the 6.0.x crossing
cat kybernet/benches/history.csv       # 6.0.14 -> 6.0.26 trend, 51 benchmarks
cat ai-hwaccel/docs/benchmarks-rust-v-cyrius.md   # head-to-head (131 crates -> 0)
cat avatara/bench-history.csv          # cached-access (the 2,761x path) held flat
cat kavach/benches/bench-history.csv   # the v3.4.0 Aho-Corasick ~12x win, side-by-side
cat nous/bench-history.csv             # 1.2.x hardening-arc stability trail

# the 2026-06-20 completion — the last three Vol 1 ports + the agnosys decomposition
cd agnostik && bash scripts/bench-history.sh   # serde from_json collapse at 6.2.x
cd ark      && cyrius bench tests/ark.bcyr     # 1.0.0 graduation run (bench-history.sh retired)
cd hoosh    && bash scripts/bench-history.sh   # second 6.2.x point (kills the n=1)
cd agnodrm  && bash scripts/bench-history.sh   # decomposed 18-bench surface (was agnosys)
```

The ledger is the code. The numbers are the receipts. Volume 3 grows as the receipts arrive.

---

*Related: [Port Ledger Volume 1](port-ledger-volume-1.md) | [Port Ledger Volume 2](port-ledger-volume-2.md) | [Cyrius vs Rust Benchmarks](cyrius-vs-rust-benchmarks.md) | [Sovereign Compiler vs Brute Force](sovereign-compiler-vs-brute-force.md)*

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*June 2026 (post-arc re-measurement; seeded 2026-06-01, expanded 2026-06-04, **all ten Volume 1 ports completed 2026-06-20** — agnostik/hoosh/ark on fresh 6.2.x runs, agnosys reframed as the agnodrm decomposition. Still accreting: held-cluster, cross-arch, opt-arc verdict.)*
