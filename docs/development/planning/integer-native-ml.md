# Integer-Native ML — the 1.58-bit (Ternary) Reference, on the attn11 Core

> Forward design + reference map for the **integer-native** lane of sovereign ML:
> models whose **weights are ternary {−1, 0, +1}** and whose hot path is
> **matmul-free** (every weight×activation becomes add / subtract / skip). This is
> the third axis-map alongside [`generative-paradigms.md`](generative-paradigms.md)
> (the **paradigm** axis) and [`multimodal-substrate.md`](multimodal-substrate.md)
> (the **modality** axis). It promotes the *integer-native* bullet from the
> generative-paradigms further-horizons list into a planned reference, because it
> is the single most **AGNOS-distinctive** model-making technique in the whole map:
> **attn11 proved learning is expressible in everything-is-i64 Cyrius; this takes
> the i64 thesis to the *weights themselves*.**

| Field | Value |
|-------|-------|
| Status | Planning (forward design — **not scaffolded**) |
| Axis | **Arithmetic floor** — orthogonal to paradigm + modality; the "how cheap can the model's own math get" axis |
| Owns | nothing yet — substrate map; reference-binary + lib names **deferred** per the attn11→libs naming decision (2026-06-08) |
| Substrate | [attn11](https://github.com/MacCracken/attn11) (transformer core) · [rosnet](https://github.com/MacCracken/rosnet) (f64 latent tensors + grad) · [tyche](https://github.com/MacCracken/tyche) (stochastic rounding RNG) · [akshara](https://github.com/MacCracken/akshara) (tokenizer) · [mabda](https://github.com/MacCracken/mabda) (later GPU ternary kernels) · [seema](https://github.com/MacCracken/seema) (edge-fleet target) |
| Created | 2026-06-23 |

---

## The thesis — the i64 claim, taken to the weights

attn11's whole point is that gradient-based learning is expressible in an
"everything-is-i64" sovereign language — but its arithmetic is still **f64 bit
patterns** simulating real-valued math. The honest next move in the sovereignty
direction is not a bigger model or a new modality; it is to make **the model's
own arithmetic integer-native**:

- **Weights → ternary {−1, 0, +1}** (log₂3 ≈ **1.58 bits/weight**). A weight that
  is only −1/0/+1 turns `weight × activation` into **−activation / nothing /
  +activation** — there is **no multiply left in the weight matmul**, only signed
  accumulation and skips.
- **Activations → int8** (per-token absmax). The one remaining product
  (int8 × ternary) collapses to add/subtract; accumulation is integer.

The result is a model whose hot path is **add / subtract / skip over integers** —
not f64 simulating reals. For a project whose founding claim is *"the sovereign
machine is integer all the way down,"* a **matmul-free, ternary-weight LLM** is
the most literal possible expression of that claim. It is also the path to a real
LLM on the **1.5x Pi-ARM line** under tight power (the b1.58 result: a 2B model at
~5–7 tok/s on a Pi 5 under ~15 W) — i.e. it feeds the **seema** edge-fleet endgame.

> This map promotes the *integer-native* lane from `generative-paradigms.md`'s
> research-watch list into a forward-design reference. It does **not** scaffold a
> repo. Per the maps' shared doctrine, a reference opens on demand (or as a
> deliberate sovereignty-demo / streaming-flex), and any shared libraries that
> fall out are emergent (the second-consumer trigger), never pre-designed.

---

## The technique — BitNet b1.58 (the lead)

**BitNet** (Wang et al., 2023) replaced `nn.Linear` with **BitLinear**: a layer
that quantizes its weights and activations inside the forward pass. **BitNet
b1.58** (Ma et al., 2024) added the **0** state → ternary instead of binary,
which buys feature-filtering (a weight can route to *nothing*) and, at ≥3B scale,
**matches the perplexity and downstream accuracy of an fp16 model of the same
size** while being multiply-free.

The BitLinear forward, per the converged shape (to be **ported, never copied** —
`feedback_redesign_dont_reinvent`):

1. **Latent weights stay full precision** (f64, in rosnet) — they are what the
   optimizer updates. Quantization happens only in the forward pass.
2. **Weight quantization (absmean / ternary):** `γ = mean(|W|)`; `W_q =
   clip(round(W / γ), −1, +1)`. Each entry lands in {−1, 0, +1}; `γ` is the
   per-tensor scale carried alongside.
3. **Activation quantization (absmax / int8):** scale `x` by `127 / max(|x|)` per
   token, round to int8.
4. **The matmul-free product:** `int8 × ternary` = signed accumulate; rescale by
   `γ · (max|x|/127)` at the end. A normalization (RMSNorm / SubLN) precedes the
   quantization for stability — attn11 has LayerNorm; SubLN is a minor variant.

Everything *around* BitLinear — attention, the MLP shape, the optimizer
(Adam), the training loop, the tokenizer (akshara), KV-cache decode, the
finite-difference grad-check harness — is **attn11 reused**. The new model is
attn11 with its `Linear`s swapped for `BitLinear` and an int8 activation path.

**Honest scope (the attn11 discipline):** the b1.58 "matches fp16" result is a
**scale** result (≈3B+ params). At the tiny scale a sovereign reference trains
from scratch, expect a measurable quality gap vs a same-size f64 attn11 — report
it the way attn11 reported the MTP honest-negative, not as a loss. The *proof* is
that ternary training converges and the integer kernel reproduces the model's
logits; the *scaling claim* is cited, not re-demonstrated at 3B.

---

## Minimum new substrate on the core

| Need | New? | Notes |
|------|------|-------|
| **BitLinear fwd** (ternary weight quant + int8 act quant + signed-accumulate + rescale) | **Yes — the core new primitive** | rosnet already has `linear` fwd/bwd; BitLinear = linear + quant wrappers. |
| **Straight-Through Estimator (STE) bwd** | **Yes — the key gradient trick** | `round`/`clip` are non-differentiable; backward passes the gradient to the latent weights as identity (with a clip-mask that zeros grads on saturated entries). See the gate section. |
| **Ternary pack / unpack + integer accumulate kernel** | **Yes — the payoff demo** | A packed {−1,0,+1} storage (2-bit, or 5-trits-per-byte) + the matmul-free signed-accumulate inference kernel. This is where "multiply-free" becomes a measured tok/s, not a claim. |
| **RMSNorm / SubLN** | Minor | Variant of attn11's LayerNorm, placed before BitLinear. |
| Stochastic rounding (optional, training-stability) | Minor | tyche supplies the RNG; round up/down with prob ∝ fractional part. |

No new tensor machinery, no attention change, no new optimizer. The two real
lifts are **BitLinear+STE** (the differentiable quantization) and **the packed
integer inference kernel** (the demonstration that the multiply is gone).

---

## The finite-difference gate meets the STE — the canonical case study

This is *why* BitNet is the right next reference and not just a quantization
chore: it is the cleanest possible test of attn11's correctness discipline
against a **non-differentiable** op.

- You **cannot** finite-difference-check through `round()`/`clip()` — the
  derivative is 0 almost everywhere and undefined at the steps. Naively FD-gating
  BitLinear "fails," and that failure is *correct*.
- The discipline is to **prove the surrogate, not the discontinuity**: (a)
  FD-check every *differentiable* sub-op of BitLinear (the underlying matmul, the
  per-tensor scaling, the rescale) exactly as attn11 FD-checks `linear`; (b)
  define the STE surrogate explicitly (gradient w.r.t. quantized = gradient w.r.t.
  latent, masked where the weight saturated to ±1), and verify it matches the
  gradient of the **non-quantized surrogate model** within tolerance; (c)
  validate end-to-end that ternary training *converges* and tracks a named QAT
  reference's loss trajectory. The gate moves from "is this derivative exact" to
  "is this surrogate the right one and does it train" — a strictly more
  sophisticated correctness story, and a reusable template for every future
  quantized / discrete op (Gumbel-softmax, hard routing, sign activations).

`generative-paradigms.md` already flags this ("the STE is the canonical case
study for the finite-difference gate — prove the *surrogate* small, not the
discontinuity"); this reference is where that gets built and the template
established.

---

## Proof-of-life

A tiny **ternary transformer trained from scratch** (attn11's char-LM corpus via
akshara, `Linear`→`BitLinear`), reaching three checks:

1. **Loss descends** under STE training, FD-gated per the section above —
   the ternary sibling of attn11's first loss curve.
2. **Integer kernel reproduces the model** — the packed-ternary / int8
   matmul-free inference path produces logits matching the f64-latent forward
   within the activation-quantization tolerance (bit-exact where integer-exact).
3. **The multiply is measurably gone** — tok/s of the integer kernel vs the f64
   path, plus a quality delta vs a same-size f64 attn11 (honest small-scale gap),
   benchmarked under the B-series fairness rules against a named reference
   (bitnet.cpp numbers / the b1.58 paper).

Proof-app lane: the ternary model runs the same FB / serving substrate attn11
already uses; a Pi-class tok/s demo is the sovereignty-flex headline.

---

## Sequencing & gating

- **No GPU gate.** Training uses f64 latent weights (rosnet, CPU); the payoff is a
  CPU **integer** kernel. It can open *before* mabda's GPU path matures (mabda
  ternary kernels are a later accelerator, not a prerequisite).
- **Stands on the attn11 core, prototypes as a sibling.** Like tarka, it
  reassembles from rosnet primitives and reuses attn11's optimizer / harness /
  tokenizer. It can prototype as an attn11 variant first; whatever genuinely
  generalizes (a `bitlinear` primitive, the packed-ternary codec) extracts only on
  a real second consumer.
- **Pairs with the Type-3 import lane.** True b1.58 is **train-from-scratch**; the
  *post-hoc* path (take an imported fp16 checkpoint → INT4/ternary without
  retraining) is **rotation-PTQ** (QuaRot / SpinQuant) — a *distinct* technique
  worth its own bullet, and the natural bridge to the weight-format + foundation-
  model-import reference. Keep them separate: QAT-from-scratch ≠ PTQ-the-import.
- **Demand-gated, but flex-eligible.** Post-beta by default; but it is a strong
  deliberate sovereignty-demo, so it is a fair candidate to pull forward as a
  *statement* open rather than wait for a downstream pull.
- **Inherits attn11's discipline:** Cyrius-native, no BLAS / libc / autodiff,
  finite-difference-gated (the STE surrogate), benchmarked vs a named real-world
  implementation.

---

## The wider integer-native lane (research-watch siblings)

BitNet b1.58 is the **lead**; the same arithmetic-floor axis holds adjacent moves,
each named-when-it-moves:

- **Scalable MatMul-free LM** (Zhu et al., 2024) — eliminates matmul from the
  *token mixer too* (a ternary-weight GRU-like recurrence), not just the linear
  layers — the further reach of "no multiply anywhere." Ties into the Type-2
  recurrent reference.
- **QAT + straight-through estimator** — the general train-to-integer discipline
  this reference establishes; reused by every later quantized op.
- **Rotation PTQ** (QuaRot / SpinQuant) — quantize an *imported* checkpoint to
  INT4 post-hoc; the "quantize-the-import" half, paired with the Type-3 lane.
- **One-shot sparsity** (SparseGPT / Wanda) — halve an imported model's memory at
  load with no retrain; structural sibling to quantization.
- **Mixture-of-Depths** — token-routed compute the OS budgets as a governed
  resource.

---

## References to pull in later

> **AGNOS method** (`feedback_redesign_dont_reinvent`): port the *converged shape*
> from multi-source prior art, then redesign to Cyrius conventions — **no FFI, no
> C, no copied code**. The codebases below are reference for the shape, never a
> dependency or transliteration target. Triangulate, port, gate with
> finite-difference / surrogate checks.

- **BitNet** — Wang et al., *BitNet: Scaling 1-bit Transformers for Large Language
  Models* (2023), arXiv:2310.11453. (Binary BitLinear; the original.)
- **BitNet b1.58** — Ma et al., *The Era of 1-bit LLMs: All Large Language Models
  are in 1.58 Bits* (2024), arXiv:2402.17764. (Ternary; the lead reference + the
  scaling claims to cite.)
- **BitNet b1.58 2B4T** (2025) — first open native 1-bit model at scale; a
  concrete checkpoint to validate an importer/kernel against, if wanted.
- **bitnet.cpp** (Microsoft) — official CPU inference framework for ternary
  models; read for the converged integer-kernel / packing shape only.
- **Scalable MatMul-free Language Modeling** — Zhu et al. (2024),
  arXiv:2406.02528. (Matmul-free token mixer; the further reach.)
- **Straight-Through Estimator** — Bengio, Léonard, Courville (2013),
  arXiv:1308.3432. (The QAT gradient trick; the surrogate the gate validates.)
- **QuaRot** (Ashkboos et al., 2024) / **SpinQuant** (Liu et al., 2024) — rotation
  PTQ, for the quantize-the-import sibling.

### In-ecosystem

- **attn11** — the transformer core (`ops.cyr` / `attn.cyr` / `train.cyr` /
  `persist.cyr`); `Linear`→`BitLinear` is the swap.
- **rosnet** — f64 latent tensors + `linear` fwd/bwd the BitLinear wraps.
- **tyche** — stochastic-rounding RNG (optional training stability).
- **akshara** — the tokenizer the proof-of-life trains over.
- **mabda** / **ai-hwaccel** — later GPU ternary kernels (accelerator, not gate).
- **seema** — the edge-fleet target the ternary-on-Pi result feeds.
- **hoosh** / **murti** — serving the ternary model once it inferences.

---

## Cross-references

- [`generative-paradigms.md`](generative-paradigms.md) — the *integer-native /
  extreme-efficiency* lane this doc promotes; also the Type-3 import reference that
  pairs with rotation-PTQ.
- [`multimodal-substrate.md`](multimodal-substrate.md) — the modality axis; a
  ternary conv stem is the eventual integer-native vision tie-in.
- [`shared-crates.md`](shared-crates.md) — attn11 / rosnet / tyche / akshara
  registry + the attn11→libs extraction the substrate rides.
- attn11 `docs/development/roadmap.md` — the live transformer-core arc the
  BitLinear swap forks from.
