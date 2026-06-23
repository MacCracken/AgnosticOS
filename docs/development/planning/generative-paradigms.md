# Generative-ML Paradigms — the GPT Lineage and Beyond, on the attn11 Core

> Forward design + reference map for sovereign machine learning along the
> **paradigm** axis. Sibling to [`multimodal-substrate.md`](multimodal-substrate.md)
> (the **modality** axis — sight & hearing). Both sit on the same core:
> **attn11** proved that gradient-based learning of a transformer is expressible
> in everything-is-i64 Cyrius (hand-written forward + backprop + Adam on raw
> `f64` arrays, no BLAS / libc / autodiff, gradients gated by finite-difference
> checks). This doc plans the **other generative paradigms** that build on — or
> evolve past — that core.

| Field | Value |
|-------|-------|
| Status | Planning (forward design — not scaffolded) |
| Axis | **Paradigm** (this doc) ⟂ **Modality** ([multimodal-substrate.md](multimodal-substrate.md)) — orthogonal maps on one core |
| Owns | nothing yet — substrate map; lib/repo names **deferred** per the attn11→libs naming decision (2026-06-08) |
| Substrate | [attn11](https://github.com/MacCracken/attn11) (transformer core) · [rosnet](https://github.com/MacCracken/rosnet) (f64 tensor BLAS + grad) · [tyche](https://github.com/MacCracken/tyche) (deterministic PRNG → sampling) · [mabda](https://github.com/MacCracken/mabda) (GPU foundation) · [hoosh](https://github.com/MacCracken/hoosh) (inference gateway / serving) |
| Created | 2026-06-15 |

---

## The frame — four descriptors of one model, then past it

"GPT" names four overlapping descriptors of a modern LLM: a **G**enerative,
**P**re-trained, autoregressive **T**ransformer. **attn11 is — and stays — the
Transformer** (type 1): the attention-architecture reference, kept scoped to that
aspect. The other three descriptors are not facets to bury inside attn11; each is
a distinct **paradigm** that comes online as its *own* sovereign reference, the
way attn11 isolates and proves *attention*. Where attn11 carries some of their
concerns **today** (a decode loop, a tokenizer, a training surface), that is only
because it is the sole reference that exists yet — a **short-term stand-in, not
ownership**. Each concern hands off to its type's reference as that reference
comes online; the pointers in this doc say "attn11 for now" precisely so they can
move. Together they answer: *can AGNOS do the major generative-ML paradigms from
the metal up, with nothing borrowed?*

> **We do not pre-plan which shared libraries fall out of this.** That is
> emergent — a mechanism extracts when a *second* reference actually needs it
> (the standard second-consumer trigger), never by up-front design. This doc
> maps the *paradigm references*, not a library taxonomy.

| # | Paradigm | Reference proves | Status |
|---|----------|------------------|--------|
| 1 | **Transformer** | attention + backprop + optimizer in everything-is-i64 | **attn11** (1.7.2, active) |
| 2 | **Autoregressive** | recurrence + backprop-through-time; the autoregressive decode/sampling discipline | planned |
| 3 | **Pre-Trained** | sovereign weight format + import a *real* foundation model + adapt (LoRA) | planned |
| 4 | **Generative** | the **non-autoregressive** generative families (diffusion / VAE / GAN) | planned |
| ∞ | **Beyond** | recurrence+attention hybrids (Griffin/Hawk) + test-time learned memory (Titans) — the architecture-evolution north star | research-watch |

**The shared substrate, in one line:** every paradigm reuses rosnet (tensors +
gradients), tyche (reproducible randomness), the finite-difference gradient
gate, and — once GPU lands — rosnet's mabda-backed GPU path. Each reference adds
only its *paradigm-specific* differentiable primitives on top. The planning
question per type is therefore narrow: *what minimum new substrate does this
paradigm add to the attn11 core?*

---

## Type 2 — Autoregressive (recurrence + the decode discipline)

attn11 is *already* autoregressive, so this type proves the part attention does
**not**: **autoregression without attention** — the recurrent lineage and its
distinct gradient-flow problem.

**The architecture reference (recurrent):** RNN → LSTM → GRU, trained with
**backprop-through-time (BPTT)**. BPTT is a genuinely different gradient
challenge from attention's parallel backward — unrolling over time, gradient
clipping, the vanishing/exploding-gradient regime that motivated gating. Proving
a hand-written LSTM with finite-difference-checked BPTT in everything-is-i64 is
the recurrent counterpart to attn11's attention proof. It is also the *honest
ancestor* of everything in the **Beyond** section (state-space models and Titans
are recurrence done with better memory dynamics).

**Minimum new substrate on the core:** a recurrent cell (gated linear maps +
elementwise nonlinearities — rosnet already has the linear/grad; the gates are
sigmoid/tanh fwd+bwd, small additions) and a BPTT unroll/accumulate loop. No new
tensor machinery.

**The decode / sampling discipline (this type's domain):** every autoregressive
model — transformer *and* recurrent — generates the same way: KV-cache (for
attention) / state-carry (for recurrence), and the **sampler zoo** (greedy,
temperature, top-k, top-p / nucleus, repetition/frequency penalty, beam search),
plus streaming emission and stop/EOS handling. This generation discipline is
conceptually the **Autoregressive type's** territory. attn11 carries a decode
path **today** only as the short-term stand-in; as this reference comes online it
becomes the home for the discipline and attn11 points at it. **tyche** is the
sampling RNG — reproducible, seed-replayable generation by construction. (Whether
any of this later becomes a shared library is the second-consumer trigger's call,
not designed here.)

**Real-world references:** char-rnn (Karpathy), the LSTM/GRU literature,
minGRU/minLSTM (2024 "were RNNs all we needed" line); llama2.c / nanoGPT for the
shared decode/sampler shape attn11 already benchmarks against.

---

## Type 3 — Pre-Trained (the transfer / foundation pillar)

The pillar that turns "we trained a toy" into "we run a real one." Emphasis is
**import + adapt**, not "train bigger." The pretraining-at-scale and corpus
side (data ingestion/curation, BPE tokenizer, checkpoints, eval-corpus) is this
type's domain; attn11 carries a slice of it **today** only to train the
transformer it proves — that surface migrates here as this reference comes
online.

**The headline capability — run a genuinely-pretrained model, sovereignly:**
1. A **sovereign weight-file format** — AGNOS's `safetensors`/`GGUF` analog:
   typed tensor manifest + raw `f64`/quantized payload, mmap-friendly, with a
   sigil-signable header (trust boundary). The archive lane (`vahana`/`sankoch`)
   is the natural container substrate.
2. A **weight importer** — read a published GPT-2-small (or TinyLlama-class)
   checkpoint, map its tensors onto attn11's transformer layout, and run
   inference. The moment AGNOS produces correct logits from *someone else's*
   pretrained weights, the "sovereign from the metal up *and* interoperable with
   the world's models" headline is real.
3. **Adaptation** — full fine-tune + **parameter-efficient LoRA** (low-rank
   adapter matrices on the attention/MLP projections; cheap, the standard
   sovereign-on-device adapt path). Instruction-tuning / preference data rides
   the same surface attn11's M17 RL arc is opening.

**Minimum new substrate on the core:** the weight format codec + a tensor-name
mapping layer; LoRA is two extra low-rank `linear`s rosnet already supports.
Quantized inference (int8/int4 dequant-on-the-fly) is the one heavier add, and
gates a later cut.

**Real-world references:** safetensors / GGUF (llama.cpp) for the format;
nanoGPT's `from_pretrained` (GPT-2 HF load) for the import map; the LoRA /
PEFT literature.

---

## Type 4 — Generative (the non-autoregressive paradigms)

"Generative" *distinct from* "autoregressive" points at the parallel/latent
families — generation that is **not** left-to-right next-token. This is the
image/audio-native generative axis and the densest tie to both **mabda** (these
are GPU-hungry) and the **multimodal substrate** (the same conv/FFT frontends).

- **Diffusion (lead) — DDPM** on a small image set. Forward noising schedule +
  a reverse denoiser trained to predict the noise (ε-prediction) / score. The
  dominant modern generative paradigm; the cleanest single proof that AGNOS does
  continuous generation. Needs `conv2d` fwd+bwd (shared with multimodal "sight")
  + a noise schedule + the sampling loop (DDPM/DDIM). tyche supplies the noise.
- **VAE (the latent-variable floor)** — encoder/decoder + the reparameterization
  trick + the ELBO (reconstruction + KL). The simplest latent generative model;
  a good first cut and a useful diffusion **latent space** (latent-diffusion).
- **GAN (the adversarial reference)** — generator/discriminator minimax. Proves
  the adversarial training dynamic (a distinct, finicky gradient game); lower
  priority than diffusion but completes the family.

**Minimum new substrate on the core:** `conv2d`/`conv1d` fwd+bwd (also needed by
multimodal sight/hearing — build once, both consume), a noise-schedule module,
and the per-family loss (ELBO / adversarial / ε-MSE). The transformer body is
*not* required for the small references, though diffusion-transformers (DiT)
later reuse attn11 directly.

**Real-world references:** DDPM (Ho et al.) / Karras EDM for diffusion;
the original VAE (Kingma) and DCGAN for the floors; nanoDiffusion-class minimal
implementations for the benchmark shape.

**Serving note:** the *application* side of "generative" — prompt→completion as
a product, chat templating, streaming to a client — is **hoosh's** job (the
OpenAI-compatible inference gateway), not a model-type reference. hoosh fronts
all four paradigms once they serve.

---

## Beyond the Transformer Base — hybrids (Griffin) & test-time memory (Titans)

The transformer's ceiling is its **context window**: attention is quadratic, so
"memory" is bounded by what fits in the prompt. The architecture-evolution axis
attacks exactly this, and attn11 already walks its first rungs (it carries a
**linear-attention** path and a **state-space model**). The north star of that
axis is **test-time learned memory**.

**Google, *Titans: Learning to Memorize at Test Time*** (Behrouz, Zhong,
Mirrokni — Google Research, 2024/25). The idea: a **deep neural long-term memory
module that updates its own weights at inference**, driven by a *surprise* signal
(the gradient of an associative-memory loss w.r.t. the memory) with **momentum**
and **adaptive forgetting** (weight decay) — i.e. the model runs gradient descent
on its own memory *while it reads*, not just at train time. Titans composes three
memories — **short-term** (attention), **long-term** (this learned neural memory),
and **persistent** (fixed task knowledge) — in three arrangements: Memory as
Context (MAC), Memory as Gate (MAG), Memory as Layer (MAL). It scales context
past 2M tokens and beats both transformers and modern linear-recurrent models
(Mamba-class) on long-context, needle-in-a-haystack, time-series, and genomics.

**Why this is the AGNOS north star, not just a citation:**
- **Sovereignty of adaptation.** "Learning to memorize at test time" means the
  model adapts *locally, at inference, with no external retraining run* — no
  cloud fine-tune, no dependence on someone else's training infra. A model that
  improves its own memory on the device it runs on is sovereignty expressed in
  the architecture itself.
- **It is the convergence point of the lineage we are already building.** Titans
  is recurrence (Type 2) + a learned-memory update (test-time training) layered
  with attention (Type 1). attn11's existing linear-attention + SSM components
  and the Type-2 recurrent reference are the honest prerequisites; Titans is
  where they meet.
- **The hard new primitive is already in our wheelhouse.** The test-time memory
  update is a small inner gradient step — exactly the hand-written
  forward/backward/optimizer machinery attn11 already proved, just run in the
  *inference* loop. The finite-difference gate transfers directly.

**The field is converging on two moves**, both of which the lineage we are
already building leads into: (a) **recurrence + attention hybrids** — keep an
efficient (often *gated, linear*) recurrence for the long context and spend
quadratic attention only on a small local window; and (b) **learned memory** —
let the model update a memory at inference. Two anchors:

- **Griffin / Hawk** (De et al., DeepMind, 2024 — *"Mixing Gated Linear
  Recurrences with Local Attention"*). Griffin interleaves a **gated linear
  recurrent** block (the **RG-LRU** — a real-gated linear recurrent unit,
  parallelizable like an SSM but with input/recurrence gates) with **local
  (sliding-window) attention**; Hawk is the pure-recurrent sibling. It matches
  transformer quality at far lower inference cost and **extrapolates past its
  training length**. For AGNOS this is the *practical* hybrid waypoint — the
  RG-LRU is the direct, linear-and-parallel evolution of the LSTM/GRU gating the
  **Type-2** reference proves (gated recurrence → *gated linear* recurrence), and
  local attention is a windowed reuse of attn11's existing attention. A Griffin
  block is therefore mostly substrate we will already have.
- **Titans** (above) — the learned-memory move: test-time gradient updates to a
  long-term neural memory. The sovereignty-of-adaptation north star.

**Lineage to track (references to pull when this moves):** fast-weight
programmers (Schmidhuber); test-time training (TTT layers, 2024); linear
attention / DeltaNet; state-space models (S4 → Mamba / Mamba-2); RWKV;
**Griffin / Hawk (RG-LRU + local attention)**; and **Titans (MAC/MAG/MAL)** as
the learned-memory synthesis. **Research-watch only** — gated behind the Type-2
recurrent reference and a stable rosnet GPU path; named when it moves.

---

## Shared substrate (consumed, not planned)

Every paradigm reference stands on a foundation it does **not** re-implement:
**rosnet** (f64 tensors + gradients), **tyche** (deterministic PRNG / sampling),
the finite-difference gradient gate, and — once it lands — rosnet's
**mabda**-backed GPU path. Each reference adds only its own paradigm-specific
differentiable primitives (a recurrent cell, a weight codec, conv2d, a noise
schedule) on top.

**No library taxonomy is planned here.** Which mechanisms eventually become
shared libraries is left to **fall out naturally** — extracted only when a
*second* reference actually needs one (the same second-consumer trigger that
produced `taar` from yo+dig). Until then each reference owns its own primitives;
**attn11 stays the Transformer**, and nothing is lifted out of it by up-front
design. Any names that do emerge stay **deferred** (descriptive working names)
per the 2026-06-08 decision.

---

## Sequencing & gating

- **Demand-gated, not calendared.** These are post-beta references; each opens
  when a concrete need (or a streaming-flex moment) pulls it forward, the same
  shape as the multimodal substrate.
- **GPU-gated where noted.** Type 4 (diffusion) and any serious Type-3 scale want
  rosnet's **mabda-backed GPU path** — itself paused on mabda 3.x. The CPU-f64
  references (Type 2 recurrent, the small VAE) need no GPU and can open first.
- **Suggested order when it moves:** Type 2 recurrent (cheapest, sets up the
  memory lineage) → Type 3 weight-format + GPT-2 import (highest credibility per
  unit effort) → Type 4 diffusion (needs conv + ideally GPU) → Titans
  (research-watch; gated on all of the above).
- **Each reference inherits attn11's discipline:** Cyrius-native, no
  BLAS/libc/autodiff, finite-difference-gated gradients, and a fairness-ruled
  benchmark vs a named real-world implementation (the B-series harness shape).

---

## Further Horizons — research-watch past the current map

> Once Types 2–4 and the Griffin/Titans rung are real, these are the directions
> worth a sovereign reference next. **Research-watch only** — none is scheduled;
> each is named-when-it-moves and demand-gated behind the current list. Surfaced
> by a six-cluster scout + completeness critic (2026-06-15), filtered through the
> sovereignty lens (runs-local / adapts-at-inference / interoperable / verifiable
> / integer-native-tiny / agent-owns-it).

**What makes these *AGNOS* horizons, not just an ML reading list.** The capability
frontier — deeper sequence models, more inference-time reasoning, faster
generation — matters, but it is not where AGNOS is *differentiated*. The
sovereignty-distinctive horizons are four orthogonal axes the pure-capability view
misses, and they are the **spine** the capability lanes hang off:

1. **Capability via DATA, not weights.** Grow what the model knows by editing a
   file or learning in place — retrieval, non-parametric memory, continual &
   federated learning — with zero or local-only weight change. *The OS owns and
   edits the model's knowledge, not just its parameters.*
2. **A trust/verification spine, co-equal with capability.** Symbolic-proof
   synthesis with a sound checker, sparse-autoencoder interpretability,
   conformal/calibrated uncertainty — "can the OS trust this model enough to let
   it touch capabilities?" *The sovereignty thesis applied to AI itself: own it
   AND verify it — wired to sigil / libro / phylax / the finite-difference gate.*
3. **Right-tool pluralism over a deep-learning monoculture.** Sometimes the
   provably-smallest mechanism is a decision tree or a Kalman filter, not a
   transformer. *prove-the-mechanism-small, taken honestly.*
4. **From one sovereign box to a sovereign COLLECTIVE.** How a fleet (seema) of
   sovereign machines gets stronger together with no center and no data egress.
   *The architectural opposite of the cloud dependence AGNOS refuses.*

### Deepen the model (the capability lanes)

- **Sequence-architecture frontier** (continues *Beyond*): the **delta-rule
  family** (DeltaNet → Gated DeltaNet → DeltaProduct, RWKV-7) — each token does
  one *in-context gradient step* editing an associative memory the agent owns;
  **Mamba-2 / SSD** — the theorem that an SSM *is* masked attention (the
  deterministic bridge to convert Transformer knowledge into constant-memory
  recurrence); **TTT layers** — the hidden state is itself a tiny model trained on
  the fly (the clean generalization of Titans); **Hyena** — FFT long-convolution,
  a distinct *convolutional* lane (→ abaco/hisab). All chunkwise matmul+scan on
  f64 — the most attn11-native post-Transformer mixers.
- **Inference-time reasoning**: **GRPO** (critic-free RL with a group-relative
  advantage — and a *verifiable Cyrius reward function*, a checker returning 0/1 —
  the lean R1-style recipe); **compute-optimal test-time scaling** (a small model
  with smart per-prompt allocation beats a 14× larger one; a 1B can pass a 405B —
  the formal "trade local compute for capability" result); **recurrent-depth +
  Coconut** (reason in latent space — depth / continuous-thought, not CoT tokens);
  **rStar-Math** (self-evolved MCTS, a 7B beats o1-preview, no big teacher);
  **speculative decoding** (lossless accel — the substrate that makes all the
  above affordable on-device). *The allocation/search policy is a planning knob
  the agent owns and budgets.*
- **Alignment the device owns**: **DPO** (alignment as one contrastive log-ratio
  loss — no reward model, no sampler — the most attn11-shaped objective here);
  **KTO** (unpaired thumbs-up/down — the *edge-adaptation* objective: tune locally
  on raw accept/reject, no annotation pipeline); **GKD** on-policy distillation
  (import a big open teacher → distill a tiny on-device student — the
  "import-then-shrink" half of Type 3); **self-rewarding loops** (manufacture your
  own preference data — the only objective needing no external annotator).
- **Generation past diffusion**: **flow matching / rectified flow** (the diffusion
  successor — MSE velocity-field regression + a deterministic ODE sampler, a
  few-hundred-line CFM toy with no SDE machinery); **consistency models** (1–2-step
  generation — what makes generative models run on the edge fleet); **VAR**
  (next-scale visual AR — *image gen reusing attn11's exact i64-token transformer*
  + a VQ tokenizer, the minimal-new-mechanism path to images); **discrete flow
  matching** (the frontier unifier — one core spanning continuous images/audio AND
  discrete text/code).
- **Extreme efficiency / integer-native — the most AGNOS-native lane**: **BitNet
  b1.58** (native ternary {−1,0,+1} weights → *matmul-free*, every multiply
  becomes add/subtract/skip; 2B at ~5–7 tok/s on a Pi 5 under 15 W — *attn11's i64
  thesis taken to the weights themselves*) — **promoted to a forward-design
  reference 2026-06-23 → [`integer-native-ml.md`](integer-native-ml.md)**; **QAT + straight-through estimator**
  (the train-to-integer discipline; the STE is the canonical case study for the
  finite-difference gate — prove the *surrogate* small, not the discontinuity);
  **rotation PTQ** (QuaRot / SpinQuant — make any imported fp16 checkpoint cleanly
  INT4 *post-hoc*, the quantize-the-import move); **one-shot sparsity** (SparseGPT
  / Wanda — halve an imported model's memory at load, no retrain);
  **Mixture-of-Depths** (token-routed compute the OS budgets as a governed
  resource); **low-rank factorization** (SVD-LLM — the structural-compression
  sibling of LoRA).

### The sovereign-AI spine (the differentiators)

- **Capability via DATA**: **retrieval-augmented / non-parametric memory** (kNN-LM,
  RETRO) over a local **ANN vector index** (HNSW / IVF-PQ) — a tiny on-device model
  + a datastore beats a huge model; add a document and it "knows" it instantly; the
  datastore *is* memory the OS curates and can redact per capability policy (the
  missing piece atop patra's B+tree). **Continual / lifelong learning** (EWC
  Fisher-penalty, replay, LoRA-merging) — adapt over a deployed lifetime without
  catastrophic forgetting — *the safety glue that makes every inference-time
  adaptation safe to run continuously*. **Federated / decentralized** (FedAvg +
  sigil-backed secure aggregation) — many AGNOS devices learn together, only weight
  deltas leave, raw data never does — *the seema-fleet endgame*.
- **The trust/verification spine**: **neuro-symbolic / program-&-proof synthesis**
  (DreamCoder, AlphaProof, LLM+SMT/Z3/Lean) — the model emits a *symbolic artifact
  a sound checker proves correct*: a synthesized firewall rule or capability policy
  *proven*, not sampled (and the most AGNOS-native reward signal is a deterministic
  Cyrius verifier). **Mechanistic interpretability** (sparse autoencoders —
  decompose activations into named, inspectable features) — if an imported model can
  touch capabilities, the OS must be able to *look inside* it: detect an anomalous
  feature firing, audit a decision, redact a concept. **Calibration & conformal
  prediction** (provable finite-sample coverage; temperature scaling) — the
  *abstention gate*: a model touching capabilities must know when to say "I don't
  know" and escalate. *This lane wires ML to sigil's crypto, libro's audit chain,
  and phylax/aegis — "AI you can trust to touch the OS."*
- **Understand & plan, don't just generate**: **JEPA** (LeCun joint-embedding
  predictive — learn structure in representation space, no pixel generation, cheap
  on-device); **Dreamer world models** (RSSM — the agent learns to act by
  *imagining* latent rollouts, a planning substrate no cloud mediates); **graph
  nets** (GATv2 / Graph-Transformer — reason over AGNOS's actual graph-shaped state:
  process trees, capability graphs, ark/nous dependency DAGs, the libro audit chain
  — attn11's attention with an adjacency mask); **E(3)-equivariant** (provable
  symmetry for molecules/physics → abaco/hisab); plus **CLIP / SigLIP** contrastive
  alignment as the cross-modal bridge into [`multimodal-substrate.md`](multimodal-substrate.md).
- **Right-tool pluralism**: **gradient-boosted trees** (still beat deep nets on
  tabular/telemetry — phylax/aegis threat features, seema fleet metrics; an
  *interpretable* split path you can defend); **Kalman / HMM filters** (state
  estimation over noisy streams — a tiny matrix recurrence); **spiking /
  neuromorphic SNNs** (event-driven integer threshold-and-fire, no multiplies,
  milliwatt always-on sensing — the alternative computational physics, the one
  direction that questions even attn11's f64 assumption). *phylax's "ML" should be
  a sovereign auditable GBDT, not a neural black box.*

**Provenance + gating.** Surfaced by a 6-cluster + completeness-critic scout
(2026-06-15); ~36 directions triaged to the strongest per lane. All
**research-watch** — gated behind the current four-type list, named when each
moves, held to attn11's discipline (Cyrius-native, no BLAS/libc/autodiff,
finite-difference-gated, benchmarked vs a named real-world reference).

---

## Cross-references

- [`multimodal-substrate.md`](multimodal-substrate.md) — the modality axis; shares
  `conv2d`/`conv1d`/FFT primitives with Type 4 here.
- [`shared-crates.md`](shared-crates.md) — attn11 / rosnet / tyche / mabda / hoosh
  registry + the attn11→libs extraction plan.
- attn11 `docs/development/roadmap.md` — the live transformer-core arc (RL/M17,
  the rosnet GPU backend on mabda).
