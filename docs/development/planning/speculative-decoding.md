# Speculative Decoding — Lossless Inference Acceleration, on the attn11 Core

> Forward design + reference map for the **decode-efficiency** lane of sovereign
> ML: making the model's **generation loop** faster **without changing what it
> generates**. This is the *decode* axis — orthogonal to the **paradigm** axis
> ([`generative-paradigms.md`](generative-paradigms.md)), the **modality** axis
> ([`multimodal-substrate.md`](multimodal-substrate.md)), and the **arithmetic
> floor** ([`integer-native-ml.md`](integer-native-ml.md)). Where those ask *what*
> the model learns and *how cheap its math is*, this asks *how few sequential
> forward passes it takes to emit N tokens*. It promotes the **speculative
> decoding** bullet from the `generative-paradigms.md` inference-time-reasoning
> list into a planned reference, triggered by **DeepSeek DSpark** (June 2026) — the
> concrete modern architecture that fills a slot the arc already reserved.

| Field | Value |
|-------|-------|
| Status | **Planned — mapped, not built.** Pre-reserved as an **attn11-deferred** decode-work item ([`ml-product-mining.md`](ml-product-mining.md), [`roadmap.md`](../roadmap.md)); this doc upgrades it from a one-line "low, gated" mention into a real reference spec, motivated by DSpark. **Gated on attn11 reopening for decode work** (attn11 is parked at infra-only M20). No repo, no scaffold — a lane inside attn11's generation arc. |
| Axis | **Decode efficiency** — how few sequential target-forward passes to emit N tokens; orthogonal to paradigm / modality / arithmetic-floor |
| Homing | **attn11 generation-arc lane** (user decision 2026-07-03), **NOT a new sibling** — the decode loop, MTP heads, and KD objective it needs already live in attn11/rupantara; a sibling would duplicate them |
| Substrate | [attn11](https://github.com/MacCracken/attn11) (KV-cache decode loop + **MTP heads** = the self-speculative draft) · [rupantara](https://github.com/MacCracken/rupantara) (the verify-forward) · [rosnet](https://github.com/MacCracken/rosnet) (tensors) · [akshara](https://github.com/MacCracken/akshara) (tokenizer) · [tyche](https://github.com/MacCracken/tyche) (sampler RNG — the losslessness gate rides its determinism) |
| Splits to serving | **Load-aware dynamic verification depth → hoosh / murti** (a systems policy, not an ML-reference thesis) |
| Created | 2026-07-03 (DSpark investigation) |

---

## The thesis — free speed, provably free

Autoregressive decoding is sequential: one target forward pass per token, and each
pass is memory-bandwidth-bound (the whole KV-cache + weights stream through for a
single token). The GPU is starved — it has the FLOPs to score *many* tokens at
once but is fed one at a time.

**Speculative decoding** breaks the one-token-per-pass floor without changing the
output distribution:

1. A cheap **draft** proposes the next *k* tokens (guesses).
2. The expensive **target** scores all *k* in **one** parallel forward pass.
3. A **verification** rule accepts the longest correct prefix and resamples the
   first rejected token from a corrected distribution.

The magic is step 3: with the right acceptance test (modified rejection sampling,
Leviathan et al. / Chen et al. 2023), the emitted sequence is **distributionally
identical** to plain sampling from the target — same model, same outputs, *fewer
sequential passes*. It is the rare optimization that is **lossless by
construction**: you are not trading quality for speed, you are removing wasted
sequential latency. That is exactly why `generative-paradigms.md` calls it *"the
substrate that makes all the [test-time-compute methods] affordable on-device"* —
every reasoning/search technique that spends more tokens (self-consistency,
best-of-N, MCTS, recurrent-depth) is gated by decode throughput, and this lane is
the throughput multiplier under all of them.

For a sovereign OS that must run capable models **on the user's own hardware**
(the seema edge fleet, the desktop, the Pi-ARM line) rather than a datacenter,
lossless 2–4× decode speedup is not a nicety — it is what makes on-device
inference competitive at all. And proving it **assembly-up in Cyrius** — that the
acceptance math is *exactly* lossless, hand-derived and gated — is the same
sovereignty demonstration attn11/tentib/tarka make for learning.

> This map promotes the *speculative decoding* bullet from
> `generative-paradigms.md`'s inference-time list into a forward-design reference.
> Per the maps' shared doctrine, the reference opens as a deliberate
> sovereignty-demo lane inside attn11; any shared library that falls out (a
> `specdecode` decode-loop primitive) is emergent on a real second consumer, never
> pre-designed.

---

## The technique — DSpark (the lead reference)

**DSpark** (DeepSeek, June 2026, MIT) is the concrete architecture this lane
ports the *converged shape* of (**never copy** — `feedback_redesign_dont_reinvent`).
What it is, from the release + the DeepSpec repo:

- **Self-speculative, not a second model.** DSpark attaches a lightweight **draft
  module to the base checkpoint's own weights** (HF card: *"not a new model — the
  same checkpoint with a speculative decoding module attached"*). It is the
  **EAGLE family** (DeepSpec ships `DSpark / DFlash / Eagle3` side by side) — the
  draft is a small autoregressive head conditioned on the target's own hidden
  states, not an independent small LLM to load and keep in sync.
- **Draft trained by distillation.** DeepSpec *"trains a draft model against the
  cached target outputs"* — the draft learns to mimic the target's next-token
  distribution. This is a **knowledge-distillation objective** — the same family
  as attn11's already-planned `--objective KD` deferred item.
- **The Markov head vs "suffix decay."** DSpark's named novelty: draft quality
  normally rots as the proposed run gets longer (later guesses condition on
  earlier guesses, compounding error → the accept-length caps out). DSpark pairs
  the draft backbone with a **lightweight Markov (low-order n-gram-style) head**
  that keeps late-position drafts sharp, extending the mean accepted length.
- **Confidence-scheduled verification.** DSpark tunes *how many* draft tokens it
  proposes/verifies per step from **draft confidence** (accept longer runs when
  the draft is sure) and, in production, **live GPU load** (back off under
  contention to protect tail latency). The confidence half is a decode-policy; the
  **load half is a serving concern** (see Splits, below).

*(Deeper specifics — the exact Markov-head parameterization and the confidence
schedule — are in the `DSpark_paper.pdf` referenced by the DeepSpec repo; pull
them at build time. The characterization above is confirmed from the release
coverage + the HF card + the DeepSpec README, not the paper's internals.)*

The sovereign port keeps the **shape** (self-speculative EAGLE-style draft +
anti-suffix-decay head + confidence-scheduled draft length + lossless verify) and
re-derives the math on rosnet/attn11, FD-gated where trained and
distribution-gated at the loop.

---

## Minimum new substrate on the core

The reason this is a **lane, not a sibling**: attn11 already owns nearly every
piece. Speculative decoding is a *wrapper around* the decode loop attn11/rupantara
already have.

| Need | New? | Already in the arc |
|------|------|--------------------|
| **Decode loop / KV-cache generation** | No | attn11 KV-cached autoregressive generation + **rupantara** `ru_model_fwd_row` KV-cache decode (0.4.0) |
| **Self-speculative draft head** | **Reuse, not new** | attn11's **MTP heads** (Multi-Token Prediction, complete at 1.10.2) — the *exact* mechanism EAGLE/DeepSeek repurpose as the draft. The parked MTP arc's **payoff** |
| **Draft-head training** (distill draft ← target) | **Partly planned** | attn11's deferred **`--objective KD`** (soft-target distillation) — same family as DeepSpec's "train against cached target outputs" |
| **Parallel verify forward** (score *k* proposed tokens in one pass) | **Small — the core loop op** | a batched/multi-position `rupantara` forward over the draft window; attn11 already does full-sequence forward — this is a windowed variant |
| **Lossless acceptance test** (modified rejection sampling) | **Yes — the correctness primitive** | new: per-position accept-prob `min(1, p_target/p_draft)`, resample-from-residual on reject; the losslessness gate (below) |
| **Markov anti-suffix-decay head** | **Yes — DSpark's novelty** | new: a small low-order head that sharpens late-position drafts |
| **Confidence-scheduled draft length** | **Yes — small scalar policy** | new: pick *k* from draft confidence (the reference); load-aware *k* is serving |

No new tensor machinery, no attention change, no new optimizer. The genuinely new
work is **(a) the lossless accept/resample math** and **(b) the Markov head**;
everything else is attn11/rupantara reused.

---

## The correctness gate — losslessness, the decode-axis analog of the FD-gate

Every sibling has a correctness discipline that *is* its thesis: attn11/tarka/
prajna **finite-difference-gate** their gradients; tentib proves the **STE
surrogate**; amuzesh proves **convergence**. Speculative decoding's is
**distributional equivalence** — and it is the cleanest possible statement of
"faster but identical":

- **The claim to prove:** for a fixed prompt + fixed RNG seed, the token sequence
  produced by the speculative loop is **identical** to the sequence produced by
  plain autoregressive sampling from the target — not "close," *identical*, because
  the acceptance test is exact rejection sampling. Greedy decoding is the trivial
  case (accept iff draft-argmax == target-argmax); sampled decoding is the real
  test (the residual-resample must reconstruct the exact target distribution).
- **How it's gated (three checks, mirroring the integer-native STE section):**
  1. **Analytic:** derive the accept probability + residual distribution and show
     on paper the marginal per-position output distribution equals the target's
     (the Leviathan/Chen identity).
  2. **Empirical (the loop gate):** run the speculative loop and plain decode from
     the **same seed** over many prompts; assert the emitted token streams are
     **bit-identical** for greedy, and that sampled-decode token **histograms**
     match the target's within Monte-Carlo tolerance (KL → 0 as samples grow).
     This is the spec-decode analog of the FD-gate: a mechanical, falsifiable
     equivalence check, not a vibe.
  3. **Draft head (trained → FD-gated):** the draft/Markov head *is* trained, so
     its backward is finite-difference-checked exactly as attn11 FD-checks its
     heads. The draft being a *bad* predictor only costs speed (lower accept
     rate), never correctness — the loop is lossless for *any* draft — so the FD
     gate is about training it well, and the loop gate is about the math being
     exactly lossless.

The headline metric is then **honest and unambiguous**: mean accepted length /
speedup (× fewer target passes) **at provably zero quality change**. Report the
speedup like attn11 reports a loss curve; report any draft-quality shortfall as an
honest accept-rate number, never as a correctness caveat (there is none).

---

## Proof-of-life

On attn11's own char-LM (akshara corpus), reopened for decode work:

1. **Lossless greedy** — speculative loop with attn11's MTP heads as the draft
   emits a **bit-identical** stream to plain greedy decode over a battery of
   prompts. (The equivalence gate, greedy case.)
2. **Lossless sampled** — speculative sampled decode's token histogram matches
   plain sampled decode's (same seed schedule), KL within Monte-Carlo tolerance.
   (The equivalence gate, the real case.)
3. **The speed is real and measured** — mean accepted length > 1 and a measured
   **× reduction in target forward passes** vs plain decode, with the Markov head
   ablated in/out to show it lifts accept length (the suffix-decay fix earning its
   place). Benchmarked under the B-series fairness rules.
4. **Draft trained, FD-gated** — the distilled draft/Markov head's backward passes
   finite-difference-check green (the training half).

Proof-app lane: the accelerated decode runs the same FB / serving substrate attn11
already uses; an on-device tok/s lift is the sovereignty-flex headline (and the
concrete feeder into the seema / desktop on-device story).

---

## Sequencing & gating

- **Gated on attn11 reopening for decode work.** attn11 is deliberately parked at
  infra-only M20; this lane is the motivation to reopen its *decode/objective*
  surface (the roadmap already names "attn11 reopening for objective/decode work"
  as the gate). Reopening is a **user call** — this doc reserves the design, it
  does not trigger the build.
- **Rides on already-built substrate.** The decode loop (rupantara), the draft
  heads (attn11 MTP), and the draft-training family (attn11 KD) exist or are
  planned — so the net-new surface is small (accept math + Markov head). This is
  the "know the ecosystem / don't duplicate" win that keeps it a lane.
- **No GPU gate.** The whole point works on CPU f64; the win is *fewer sequential
  passes*, orthogonal to per-pass acceleration. mabda's GPU path multiplies the
  benefit later (batched verify is GPU-shaped) but is not a prerequisite.
- **Pairs with the test-time-compute lanes.** Every `generative-paradigms.md`
  inference-time method (self-consistency, best-of-N, tarka's verifier-guided
  search, recurrent-depth) gets cheaper under this lane — it is the throughput
  substrate beneath them, not a competitor to them.
- **Inherits attn11's discipline:** Cyrius-native, no BLAS / libc / autodiff;
  trained parts FD-gated; the loop distribution-gated; benchmarked vs a named
  reference (DSpark / EAGLE numbers).

### Splits to the serving layer (NOT the reference)

- **Load-aware dynamic verification depth** — adapting *k* to live GPU/CPU
  contention to protect tail latency is a **scheduling policy**, and belongs in
  **hoosh** (the inference gateway) / **murti** (the model runtime), where request
  load actually lives. The *reference* carries only the confidence-driven *k* (a
  property of the draft), so the sovereign spec-decode proof stays a pure
  decode-correctness artifact.

---

## The wider decode-efficiency lane (research-watch siblings)

DSpark is the **lead**; the same decode-efficiency axis holds adjacent moves, each
named-when-it-moves:

- **Medusa** (Cai et al., 2024) — multiple decoding heads + tree attention; the
  simplest self-speculative baseline, closest to reusing attn11's MTP heads
  directly.
- **EAGLE-1/2/3** (Li et al., 2024–2025) — feature-level autoregressive draft
  (draft on the target's hidden states, not just tokens); DSpark's direct lineage
  (`Eagle3` ships in DeepSpec beside it).
- **Lookahead decoding** (Fu et al., 2024) — Jacobi-iteration n-gram drafting with
  **no draft model at all**; the "draft-free" corner of the axis.
- **DFlash** — the other DeepSpec algorithm; pull its distinction from DSpark at
  build time.
- **Blockwise / parallel decoding** (Stern et al., 2018) — the original
  multi-token-at-once idea the whole axis descends from.

Keep this axis **distinct from tarka's inference-time reasoning**: spec-decode
makes *the same tokens* come out faster (lossless); tarka's search makes *better
tokens* come out (different distribution). They compose — spec-decode is the
throughput layer under tarka's deliberation — but they are different theses.

---

## References to pull in later

> **AGNOS method** (`feedback_redesign_dont_reinvent`): port the *converged shape*
> from multi-source prior art, then redesign to Cyrius conventions — **no FFI, no
> C, no copied code**. The codebases/papers below are reference for the shape,
> never a dependency or transliteration target.

- **DSpark / DeepSpec** — DeepSeek (2026), <https://github.com/deepseek-ai/DeepSpec>
  (+ `DSpark_paper.pdf` therein); the lead architecture (Markov head,
  confidence-scheduled verification). MIT.
- **Speculative decoding** — Leviathan, Kalman, Matias, *Fast Inference from
  Transformers via Speculative Decoding* (2023), arXiv:2211.17192. (The lossless
  acceptance test — the losslessness proof to re-derive.)
- **Speculative sampling** — Chen et al., *Accelerating Large Language Model
  Decoding with Speculative Sampling* (2023), arXiv:2302.01318. (The parallel
  independent derivation; the residual-resample.)
- **Medusa** — Cai et al. (2024), arXiv:2401.10774. (Multi-head self-speculation —
  the MTP-heads-as-draft baseline.)
- **EAGLE / EAGLE-2 / EAGLE-3** — Li et al. (2024–2025), arXiv:2401.15077 et seq.
  (Feature-level draft; DSpark's family.)
- **Lookahead decoding** — Fu et al. (2024), arXiv:2402.02057. (Draft-free.)
- **Blockwise parallel decoding** — Stern et al. (2018), arXiv:1811.03115. (The
  ancestor.)

### In-ecosystem

- **attn11** — the decode loop + **MTP heads** (the draft) + the planned KD
  objective (draft training); the lane reopens attn11's decode surface.
- **rupantara** — `ru_model_fwd_row` KV-cache decode = the verify-forward the loop
  batches over.
- **rosnet / tyche / akshara** — tensors / sampler RNG (losslessness rides its
  determinism) / tokenizer.
- **hoosh / murti** — where the **load-aware** dynamic-verification policy lives
  (the serving split); also the first real consumers of the accelerated decode.
- **anukūlana** — a downstream consumer: imported foreign checkpoints decode faster
  under this lane (foreign models ship MTP-less, so their draft is trained fresh —
  the DeepSpec path).
- **seema** — the edge-fleet target the on-device tok/s lift ultimately feeds.

---

## Cross-references

- [`generative-paradigms.md`](generative-paradigms.md) — the inference-time-reasoning
  list this doc promotes the *speculative decoding* bullet from; the test-time
  compute methods this lane is the throughput substrate beneath.
- [`integer-native-ml.md`](integer-native-ml.md) — the arithmetic-floor axis; the
  sibling forward-design map this one mirrors (per-pass cost ↓ there, sequential
  pass count ↓ here — the two are multiplicative on-device).
- [`ml-product-mining.md`](ml-product-mining.md) — where speculative decoding was
  first mined as an attn11-deferred item; this doc is its spec.
- [`type3-weight-import.md`](type3-weight-import.md) — anukūlana, a downstream
  consumer (accelerate imported-model decode).
- [`shared-crates.md`](shared-crates.md) — attn11 / rupantara / rosnet / akshara
  registry.
- attn11 `docs/development/roadmap.md` — the parked decode surface this lane
  reopens.
