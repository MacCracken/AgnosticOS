# Port Ledger Volume 3

> **STATUS — OPEN / ACCRETING.** This is the post-arc re-measurement cut promised by [Volume 1](port-ledger-volume-1.md) and [Volume 2](port-ledger-volume-2.md): the comparison against Volume 1's frozen v5.5.4 numbers, now that the optimization arc has run and Cyrius has crossed into the **v6.0.x** cycle (v5.x closed at v5.11.69, 2026-05-19). Unlike Volumes 1 & 2 — which are sealed snapshots — **Volume 3 fills in over time**, one port at a time, as each crate's re-benchmark comes online. It opens here with the first two ports back on the 6.0.x workflow: **abaco** and **hisab**. The rest of the ten-port ledger lands as its receipts are generated (see *Receipts Pending — The Wave*). Seeded 2026-06-01.

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

## Receipts Pending — The Wave

Volume 3 is seeded, not finished. What's still owed, and the gate on each:

- **The ten Volume 1 ports, re-benchmarked at 6.0.x.** Only `abaco` (above) has a published 6.0.x trend; `agnosys` has a recent CSV (`bench-history.csv`, 2026-05-09) awaiting write-up; the rest (kybernet, agnostik, hoosh, ai-hwaccel, avatara, kavach, ark, nous) need fresh runs against their Volume 1 numbers. Each lands here as its CSV is generated — no fabricated numbers ahead of the measurement.
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
```

The ledger is the code. The numbers are the receipts. Volume 3 grows as the receipts arrive.

---

*Related: [Port Ledger Volume 1](port-ledger-volume-1.md) | [Port Ledger Volume 2](port-ledger-volume-2.md) | [Cyrius vs Rust Benchmarks](cyrius-vs-rust-benchmarks.md) | [Sovereign Compiler vs Brute Force](sovereign-compiler-vs-brute-force.md)*

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*June 2026 (post-arc re-measurement — open, accreting; seeded 2026-06-01)*
