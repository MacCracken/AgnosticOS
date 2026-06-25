# The Self-Improvement Lane — Recursive Self-Improvement as a Recipe-Lane over attn11 + tarka

> Forward design + reference map for the **self-improvement** lane of sovereign ML:
> systems that **improve themselves with no external teacher** — manufacturing
> their own training signal and/or running their own optimizer. This is the
> fourth axis-map alongside [`generative-paradigms.md`](generative-paradigms.md)
> (the **paradigm** axis), [`multimodal-substrate.md`](multimodal-substrate.md)
> (the **modality** axis), and [`integer-native-ml.md`](integer-native-ml.md)
> (the **arithmetic-floor** axis).
>
> **It differs from those three in one decisive way, and the difference is the
> whole point of this doc:** the other maps each promote toward a *new sovereign
> reference binary* (a sibling of attn11/tarka/tentib that proves one new
> hand-derived differentiable primitive). **This lane does NOT.** Recursive
> self-improvement, examined honestly, is **not a fourth sibling** — it is a
> *recipe-lane over tarka + attn11* plus exactly **one** extractable new
> primitive (the second-order meta-gradient) that earned a narrow sibling of its
> own: **[`prajna`](https://github.com/MacCracken/prajna)**, the meta-learning /
> learn-to-learn reference (promoted + scaffolded 2026-06-24, M1 green). This map
> exists to record that finding, draw the boundary that keeps
> the lane from duplicating tarka, and consolidate the self-improvement threads
> that are currently scattered across four sections of `generative-paradigms.md`.

| Field | Value |
|-------|-------|
| Status | **Lane map.** The *self-improvement orchestration* stays a recipe-lane (NOT scaffolded — a tarka recipe by design). **The one extractable primitive WAS promoted 2026-06-24 → [`prajna`](https://github.com/MacCracken/prajna)**, which then went the full distance: M1–M5 complete, hardened across the 0.6.x arc, **shipped 1.0.0 stable 2026-06-24** (API frozen). See *The one genuinely-new primitive* below. |
| Axis | **Self-improvement / adaptation timescale** — orthogonal to paradigm + modality + arithmetic-floor; the "can the model improve *itself*, and when is that real vs a trap" axis |
| Owns | **Nothing as a binary** (the orchestration half). A recipe-lane: outer-loop *control structure* + cross-generation *measurement*, sitting on tarka (reward+search) and attn11 (SFT). The one genuinely-new primitive it surfaced — the **2nd-order meta-gradient** ("learn-to-learn") — **is now its own reference, [`prajna`](https://github.com/MacCracken/prajna)** (प्रज्ञा; sibling to attn11/tarka/tentib). |
| Substrate | [attn11](https://github.com/MacCracken/attn11) (transformer core + SFT) · [tarka](https://github.com/MacCracken/tarka) (RL/reward/search — the inner step, even when the reward is self-generated) · [rosnet](https://github.com/MacCracken/rosnet) (f64 tensors + grad) · [tyche](https://github.com/MacCracken/tyche) (PRNG/sampling) · [akshara](https://github.com/MacCracken/akshara) (tokenizer) |
| Created | 2026-06-24 (from a 6-cluster research scout + a 4-lens adversarial review that **rejected** the original "fourth sibling" framing) |

---

## Why this is a lane, not a sibling — the finding that shaped this doc

The instinct was natural: attn11 is the **Transformer** reference, tarka is the
**Reasoning-Learning** reference, tentib is the **integer-native** reference — so
"Recursive Improvements" should be the next sovereign sibling. **A four-lens
adversarial review killed that framing, repo-grounded and convergent.** The honest
decomposition:

1. **Every existing sibling earns its place by one new hand-derived differentiable
   primitive**, proven small and finite-difference-gated: attn11 = attention
   forward/backward; tarka = the policy-gradient inner update; tentib = BitLinear
   forward + the STE surrogate gradient. The recursive-self-improvement **outer
   flywheel adds no new differentiable op** — its loop body is *generate → verify
   → filter → retrain via an already-existing objective*. A harness over
   tarka+attn11 with no new gradient is a **benchmark script, not a reference**.

2. **A self-generated reward is still a reward.** tarka's charter is "owns ALL
   reinforcement learning, reward models, PRMs, search, and the one inner policy
   update." The two flagship "RSI" methods decompose straight into that surface:
   **Self-Rewarding LMs** = {self-judge = reward model} + {preference-pair DPO =
   inner update} = tarka; **SEAL** = {ReST-EM filter + downstream-accuracy reward}
   = tarka. The "self-signal manufacture" the lane seemed to own is **a
   data-provenance label on tarka's reward signal, not a new mechanism** — tarka
   does not care where the scalar came from.

3. **The genuinely-new primitive in this space is already homed elsewhere.** The
   *fast* test-time inner-update (TTT / Titans / dynamic-evaluation) is a real new
   op — but `generative-paradigms.md` already classifies it as the **Beyond /
   Type-2 "learned-memory" rung** and already states (Beyond §): *"the test-time
   memory update is a small inner gradient step — exactly the machinery attn11
   already proved, just run in the inference loop. The finite-difference gate
   transfers directly."* The Titans bullet's own title is **"Sovereignty of
   adaptation"** — i.e. the recursive-self-improvement thesis is *already named* on
   the paradigm map.

So the lane's two halves fail the sovereign-reference bar **in opposite
directions**: the slow flywheel has no new primitive *and* overlaps tarka; the
fast inner-update has a new primitive *but it is already owned* by the Beyond rung.
Stapling them into one "RSI" binary is the **near-coupling EWWW** the
[[project_monolithic_by_design]] doctrine says to reject — coupling at the
codebase/narrative level, not at an ABI/contract. **There is no single named
real-world implementation that unifies STaR with Titans**, so attn11's
one-fairness-ruled-benchmark-vs-one-named-impl discipline cannot even be satisfied
for the union.

**What that leaves — and it is genuinely worth mapping:** a coherent *lane* with a
clean boundary, a real honest-negative, and one extractable nugget.

---

## The two timescales (both belong to owners that already exist)

The same thesis — *the model improves itself, nothing borrowed* — appears at two
timescales. Naming them is useful; **minting a binary for either is not.**

### Slow loop — the self-improvement flywheel (a **tarka recipe**)
*Across training rounds:* self-generated, verifier-filtered data bootstraps a
stronger model; the stronger model mines harder data; repeat.
- **STaR / RFT / ReST / ReST-EM** — generate rationales → filter by a checkable
  verifier → SFT on survivors → repeat. ReST-EM is the clean EM framing (E-step
  generate+filter, M-step reward-weighted SFT, base-restart per round).
- **rStar-Math** — the recent small-model, *no-larger-teacher*, verifier-grounded
  round-over-round result (the AGNOS-scale existence proof).
- **Absolute Zero / R-Zero** — the zero-data frontier: one model **proposes** tasks
  at its own learnability frontier and **solves** them, a code-executor the only
  reward.

**Ownership:** the generate step is attn11/tarka sampling; the verify/filter/best-of-N
and any reward/PRM is **tarka**; the SFT retrain is **attn11**. The lane owns only
the *outer control structure* — round controller, cross-generation dataset ledger
(M₀…Mₙ, accumulate-vs-replace, base-restart-vs-continue, dedup of distinct
reasoning paths) — and the *measurement*. **This is a recipe/example over tarka,
not a reference.**

### Fast loop — test-time / continual self-adaptation (the **Beyond/Type-2 rung**)
*Within one inference pass / over a deployed life:* the model runs an optimizer on
its **own weights** mid-forward.
- **TTT layers / dynamic-evaluation** — the hidden state *is* a model; the
  state-update rule is one SGD step of a self-supervised loss (cheap, on-device,
  FD-checkable).
- **Titans** — a deep neural memory that runs gradient descent on itself at test
  time, keyed by a *surprise* signal with momentum and adaptive forgetting
  (MAC/MAG/MAL). The `generative-paradigms.md` north star.
- **SEAL** — the model generates its own LoRA finetune directives; trained by
  ReST-EM with downstream accuracy as reward (so its *training* loop is **tarka's**).
- **EWC + experience replay** — the mandatory safety glue; catastrophic forgetting
  is the confirmed dominant failure of unattended self-adaptation.

**Ownership:** this rung is **already on the paradigm map** as the Type-2-recurrent /
Beyond "learned-memory" mixer, gated behind the Type-2 recurrent reference + a
stable rosnet GPU path. The lane does **not** annex it — it points at it.

---

## The boundary, redrawn correctly

The first draft drew the line at *within-round (tarka) vs across-round (RSI)*. The
adversarial review showed that leaks — it is a **scheduling** distinction, not a
**mechanism** distinction. The line that actually holds:

> **tarka owns every step that consumes a reward to update a policy — reward model,
> PRM, DPO/GRPO/PPO inner update, search (MCTS/beam/best-of-N) within a fixed
> policy — INCLUDING when the reward is self-generated.** A self-generated reward
> is still a reward.
>
> **attn11 owns** the transformer, forward/backprop/Adam, the SFT objective, the
> akshara tokenizer, KV-cache decode, persist/checkpoint.
>
> **The self-improvement lane owns** only what neither models: the **outer-loop
> control structure** (checkpoint-as-new-base re-seeding, cross-generation
> bookkeeping, support/tail-variance tracking, curriculum/learnability gating that
> decides *which* tarka-round to run next and on what data) and the
> **collapse-vs-climb measurement**. It is a **meta-controller / scheduler over
> tarka**, contributing zero new gradient math.

**Guardrail (executable):** if a lane artifact ever implements a reward, a PRM, a
DPO/GRPO update, or in-rollout search, **the boundary has been violated and that
code belongs in tarka**. A lane recipe must *call* tarka for every reward and every
policy step. The one exception that is genuinely the lane's to grow is the
**learnability/proposer objective** ("reward the task-*proposer* for the *solver's*
marginal learning") — but even that is a reward, so the honest call is: **propose
it as a tarka objective extension** (a tarka ADR), not a lane-owned gradient.

---

## The honest-negative — the headline is a scale phenomenon, cite don't claim

The seductive thesis is *"verifier-grounded self-improvement climbs; ungrounded
self-training collapses."* It is **true at scale and not demonstrable from
scratch** — and shipping it as a demonstrated result would violate the family's own
honest-negatives standard. Three preconditions an i64-from-scratch model cannot
meet at once:

- **Collapse needs a rich distribution to lose.** The Curse-of-Recursion signature
  is tails vanishing / variance contracting to a point — but a from-scratch i64
  transformer *starts* near-degenerate. *You cannot photograph a fall from a model
  already on the floor.*
- **Climb needs a capable base.** The *invisible-leash* result: on-policy
  self-improvement only redistributes mass **within base-model support** — it
  cannot assign probability outside it. A from-scratch model has ~empty support
  over any nontrivial task; there is nothing to sharpen toward.
- **At this scale the "grounded climb" is indistinguishable from ordinary
  rejection-sampling SFT** on verifier-filtered data — which is already
  tarka/attn11 surface, not a novel demonstration.

**The tentib posture, applied here:** the *thesis* (verifier-grounding separates
self-improvement from collapse) is **cited** from the large-scale literature
(Curse-of-Recursion; the invisible-leash / sharpening results), explicitly flagged
as **not reproducible at sovereign scale**. The *mechanism* — the full
generate → score → filter → update → re-seed loop, finite-difference-gated, on a
toy task whose answer **is** in base support (synthetic arithmetic / grammar) — is
**demonstrated locally**, showing the measurable signatures (pass@1 rise,
answer-entropy / tail-variance contraction) rather than a close-vs-climb story on a
hard task. **The defensible deliverable is the mechanism + the metrics that would
detect collapse/climb, validated against the published large-scale signatures** —
plus the honest finding that at i64 scale both arms are leash-bound to a near-empty
base. That negative *is* the contribution.

---

## The one genuinely-new primitive — the second-order meta-gradient ("learn-to-learn")

There is exactly one thing in this whole space that clears the tentib/attn11/tarka
bar — a new hand-derived differentiable primitive no sibling has:

> **The second-order meta-gradient** — differentiating *through* an inner SGD step
> (∂/∂θ of a loss measured **after** an inner gradient update). This is the
> MAML / learned-optimizer / TTT-trainable-inner-loop move. attn11 (first-order
> attention grad), tarka (first-order policy grad), and tentib (first-order STE
> surrogate) are **all first-order**. A meta-gradient reference would be the
> family's **first nested grad**, requiring a hand-derived **second-order
> backward** and a finite-difference gate over a **two-level** computation — a new
> high-water mark for the correctness discipline, exactly the way tentib's STE
> surrogate was a new high-water mark for the gate.

This was the **only** future-sibling candidate to come out of the exploration — and
note what it is: a **"learn-to-learn" / meta-learning reference**, *not* a
"recursive self-improvement orchestration" reference.

> **✅ PROMOTED 2026-06-24 → [`prajna`](https://github.com/MacCracken/prajna)
> — SHIPPED 1.0.0 STABLE the same day** (प्रज्ञा — *the cognition that refines
> itself*; completes the cognition cluster pramana → tarka → prajna). **M1–M5 all
> complete**: M1 scalar second-order meta-gradient (`dM/dt = Lq'(t')·(1 − α·Ls'')`,
> FD-gated `|Δ|=0`, the FOMAML contrast proving the 2nd-order term *observably real*)
> → M2 MAML (scalar → linear → nonlinear via the **Pearlmutter R-operator** double-
> backward) → M3 learned optimizers (feedforward + recurrent **BPTT**, beats best
> fixed-lr SGD) → M4 text few-shot on the shared `akshara` tokenizer → M5 continual-
> learning durability (experience replay + EWC). Hardened across the **0.6.x arc**
> (NaN-safe gates, numerical robustness, security audit, refactor); API frozen. All
> hand-derived backprop FD-gated; `cyrius test` green.

**Key refinement found at promotion:** the meta-gradient has **two incarnations
with different gating**. (a) As the differentiable core *under Titans/TTT*
(test-time learned memory) it stays the **Type-2-gated Beyond rung**. (b) As a
**standalone MAML / learned-optimizer reference** (`prajna`) it needs **no
recurrence and no Type-2** — only `rosnet`'s f64 tensor algebra (the nesting is
hand-derived in prajna) — and is demonstrable at *toy scale* (MAML sine regression),
which is why it could open *now* where the Titans incarnation cannot. The
orchestration half of this lane stays a tarka recipe; only the primitive was minted.

---

## What the lane owns vs consumes (the honest substrate table)

| Need | New? | Owner / Notes |
|------|------|---------------|
| Reward / PRM / Bradley-Terry — **even self-generated** (self-judge, learnability) | Reused | **tarka.** A self-generated reward is still a reward. |
| Search (MCTS / beam / best-of-N / self-consistency) within a fixed policy | Reused | **tarka.** |
| Inner policy update (REINFORCE / PPO / GRPO+GAE / DPO) | Reused | **tarka.** |
| SFT retrain step, transformer fwd/bwd/Adam, tokenizer, decode, persist | Reused | **attn11** / akshara. |
| First-order test-time inner SGD step (TTT / dynamic-eval / Titans memory update) | Reused-relocated | **Beyond/Type-2 rung** of `generative-paradigms.md`. "attn11's optimizer run in the inference loop." Not the lane's to mint. |
| Outer round controller + cross-generation dataset ledger (M₀…Mₙ, accumulate/replace, base-restart, dedup) | **Lane (orchestration)** | Genuinely nowhere else — but it is *control structure*, not a gradient. → a tarka **recipe/example**, not a binary. |
| Collapse/climb instrumentation (held-out curve, verifier-ablation, support / answer-entropy / tail-variance, gen-verification-gap, Goodhart/overopt curve) | **Lane (measurement)** | The scientific deliverable; the loop-level analogue of the FD-gate. |
| **Second-order meta-gradient** (∂/∂θ through an inner SGD step) | **Yes — core, and the ONLY one** | The family's first nested grad. The single future-sibling candidate. **Gated behind Type-2; name deferred.** |

Net: the lane is ~100% reused arithmetic + inner-loop substrate, **owning only
control + measurement**, with **one** extractable differentiable primitive that is
itself gated and belongs to a *meta-learning* framing, not an orchestration one.

---

## Sequencing & gating

- **Do not open as a sibling now.** It is redundant with the already-queued
  Beyond/Titans rung, and opening it inverts the dependency DAG: Titans =
  recurrence (Type-2) + learned-memory + attention, so its honest prerequisites are
  the **Type-2 recurrent reference** and a **stable rosnet GPU path**, neither of
  which exists.
- **Order:** Type-2 recurrent → Type-3 GPT-2 import → Type-4 diffusion → *then* the
  test-time-learning / meta-gradient rung. If a forward-design promotion happens
  next (the way BitNet → `integer-native-ml.md` did on 2026-06-23), the
  higher-value candidate is **Type-2 or Type-3, not this.**
- **No GPU gate for the cheap mechanism demos** (the slow-loop recipe is f64 SFT;
  a TTT-Linear / dynamic-eval inner step is a matmul + one backward) — so a *local
  mechanism demonstration* (per the honest-negative section) can be built as a
  tarka example any time without waiting on mabda.
- **Inherits the family discipline** for whatever does get built: Cyrius-native, no
  BLAS/libc/autodiff, finite-difference-gated (the meta-grad's two-level gate is
  the new bar), benchmarked vs a named real-world implementation, honest-negatives
  reported as findings.

---

## The methods map (the six research clusters, with their honest verdicts)

| Cluster | Canonical methods | Verdict for AGNOS |
|---------|-------------------|-------------------|
| **Bootstrap self-training** | STaR · RFT · ReST · ReST-EM · V-STaR | **tarka recipe** (verify/filter/reward = tarka; SFT = attn11; lane owns round controller + climb measurement). |
| **Self-evolved reasoning** | rStar-Math · AlphaProof / AlphaGeometry · iterative-DPO | **tarka recipe.** rStar-Math's MCTS + PPM are tarka territory; the lane owns the cross-round ledger + the verifier-ablation proof. |
| **Self-play & expert iteration** | ExIt · AlphaZero · SPIN · Absolute Zero · R-Zero | **tarka recipe.** "Add MCTS" / "train a reward model" = tarka, full stop. The proposer/learnability objective → propose as a **tarka objective extension**. |
| **Self-critique & self-reward** | Self-Refine · Reflexion · Constitutional-AI/RLAIF · Self-Rewarding LMs · Meta-Rewarding · CriticGPT | **Mostly tarka** (self-judge = reward model; DPO = inner update). Training-free Self-Refine / Reflexion are the only tarka-free pieces (in-context, no weight update). |
| **Test-time & continual** | TTT · Titans · dynamic-evaluation · SEAL · EWC/replay | **Beyond/Type-2 rung** (already on the paradigm map). SEAL's training loop is tarka. This is where the **meta-gradient** primitive lives. |
| **The science & limits** | Curse-of-Recursion · reward-overoptimization (Goodhart) · invisible-leash / sharpening · easy-to-hard curricula · weak-to-strong | **The lane's actual intellectual core** — supplies the cite-don't-claim honest-negative and the metrics (support / entropy / tail-variance / gen-verification-gap) the lane *can* own. |

---

## Naming — deferred (and why the obvious candidates miss)

Per the **2026-06-08 naming-deferral rule**, no name is assigned to a research-watch
rung. Recorded for whenever (if ever) the meta-gradient sibling is promoted:

- **`abhyasa`** (अभ्यास, *repeated practice / drill*) — **rejected.** Names the
  *activity* (iteration toward a fixed target by an external practitioner), not the
  *function*. Loses the two load-bearing semes: **self-reference** (improver and
  improved are the same system) and **recursion** (each pass operates on the prior
  pass's output). Fails the `तर्क` test (which names the *function*, disciplined
  inference, precisely).
- **`bhavana`** (भावना, contemplative cultivation) — rejected, even more
  practitioner-external / meditative.
- **`vardhana`** (वर्धन, growth/increase) — rejected; names magnitude change, not
  self-directed improvement (a tumor does vardhana).
- **`parinama`** (परिणाम) — the closest single Sanskrit word (Samkhya/Yoga technical:
  a substance evolving into its own modifications), but still names *directionless
  transformation*, not *self-improvement-via-own-output*.
- If a name is ever needed, a **self-reference compound** — `atma-parinama`
  (आत्मपरिणाम, *self-transformation*) or `svayam-vardhana` (स्वयंवर्धन,
  *self-augmentation*) — names the function the way `तर्क` does. **But defer**:
  picking a function-imprecise label for a gated research-watch rung is premature.

---

## References to pull in later

> **AGNOS method** (`feedback_redesign_dont_reinvent`): port the *converged shape*
> from multi-source prior art, then redesign to Cyrius conventions — no FFI, no C,
> no copied code. The works below are reference for the shape, never a dependency.
> 2025+ items were surfaced web-sourced during the research scout (post-cutoff;
> verify arXiv ids before citing in a shipped artifact).

**Slow flywheel (tarka recipes):** STaR — Zelikman et al. 2022, arXiv:2203.14465 ·
RFT — Yuan et al. 2023, arXiv:2308.01825 · ReST — Gulcehre et al. 2023,
arXiv:2308.08998 · ReST-EM (*Beyond Human Data*) — Singh et al. 2023,
arXiv:2312.06585 · V-STaR — Hosseini et al. 2024, arXiv:2402.06457 · rStar-Math —
Guan et al. 2025, arXiv:2501.04519 · AlphaGeometry — Trinh et al., Nature 2024 ·
ExIt — Anthony et al. 2017, arXiv:1705.08439 · AlphaZero — Silver et al. 2017,
arXiv:1712.01815 · SPIN — Chen et al. 2024, arXiv:2401.01335 · Absolute Zero —
Zhao et al. 2025, arXiv:2505.03335 *(web-sourced)* · R-Zero — Huang et al. 2025,
arXiv:2508.05004 *(web-sourced)*.

**Self-critique / self-reward (mostly tarka):** Self-Refine — Madaan et al. 2023,
arXiv:2303.17651 · Reflexion — Shinn et al. 2023, arXiv:2303.11366 ·
Constitutional AI / RLAIF — Bai et al. 2022, arXiv:2212.08073 · Self-Rewarding LMs
— Yuan et al. 2024, arXiv:2401.10020 · Meta-Rewarding — Wu et al. 2024,
arXiv:2407.19594 · CriticGPT — McAleese et al. 2024, arXiv:2407.00215.

**Test-time / continual (Beyond rung) + the meta-gradient primitive:** TTT layers —
Sun et al. 2024, arXiv:2407.04620 · Titans — Behrouz et al. 2024/25,
arXiv:2501.00663 · SEAL — Zweiger et al. 2025, arXiv:2506.10943 *(web-sourced)* ·
Dynamic Evaluation — Krause et al. 2018, arXiv:1709.07432 · EWC — Kirkpatrick et al.
2017, arXiv:1612.00796 · **MAML** — Finn et al. 2017, arXiv:1703.03400 *(the
meta-gradient anchor)* · **Learning to learn by gradient descent by gradient
descent** — Andrychowicz et al. 2016, arXiv:1606.04474 *(learned-optimizer anchor)*.

**The science & limits (the honest-negative spine):** *The Curse of Recursion* /
model collapse — Shumailov et al. 2023, arXiv:2305.17493 (Nature 2024,
s41586-024-07566-y) · *Is Model Collapse Inevitable?* (accumulate-don't-replace) —
Gerstgrasser et al. 2024, arXiv:2404.01413 · *Scaling Laws for Reward Model
Overoptimization* (Goodhart curve) — Gao et al. 2022, arXiv:2210.10760 · *The
Sharpening Mechanism* (generation-verification gap) — Huang et al. 2024,
arXiv:2412.01951 · *Does RL Really Incentivize Reasoning Beyond the Base Model?*
(the invisible-leash pass@k ceiling) — Yue et al. 2025, arXiv:2504.13837
*(web-sourced)* · *Self-Improving Transformers Overcome Easy-to-Hard…* — Lee et al.
2025, arXiv:2502.01612 *(web-sourced)* · *Weak-to-Strong Generalization* — Burns
et al. 2023, arXiv:2312.09390 · classical lineage: I.J. Good 1965; Bostrom,
*Superintelligence* 2014 (recursive-self-improvement framing — narrative context
only, do not build on it).

### In-ecosystem
- **tarka** — the inner step for the entire slow flywheel (reward + search + one
  update, **even when the reward is self-generated**); the proposer/learnability
  objective belongs here as a tarka ADR, not a lane gradient.
- **attn11** — the SFT retrain step + the transformer + akshara tokenizer.
- **rosnet / tyche** — f64 tensors+grad / PRNG; the meta-gradient primitive needs a
  rosnet re-entrant + nested (second-order) grad path.
- **generative-paradigms.md** — the **Beyond/Type-2 rung** that already owns the
  test-time learned-memory primitive (Titans = "sovereignty of adaptation").
- **phylax / aegis / sigil / libro** — the trust spine for the alignment-orthogonal
  failure (the "uh-oh moment": a task-verifier grounds *capability* but not
  *values*; an unattended self-curriculum can wander into misaligned reasoning).

---

## Cross-references

- [`generative-paradigms.md`](generative-paradigms.md) — the paradigm axis; **owns
  the test-time / Titans rung** this lane points at, and scatters the
  self-improvement threads (self-rewarding, rStar-Math, TTT, continual-learning)
  this doc consolidates.
- [`integer-native-ml.md`](integer-native-ml.md) — the arithmetic-floor axis; the
  sibling forward-design map this one is modeled on (but **inverts**: that one
  *promotes to a reference*; this one *declines to*).
- [`multimodal-substrate.md`](multimodal-substrate.md) — the modality axis.
- [`shared-crates.md`](shared-crates.md) — attn11 / tarka / rosnet / tyche / akshara
  registry.
- tarka `docs/adr/0001-tarka-scope-and-rl-migration.md` — the RL-ownership boundary
  this lane is careful not to cross.

> **Provenance.** This map is the output of a 6-cluster literature scout followed by
> a 4-lens adversarial review that **rejected** the original "Recursive Improvements
> = fourth sovereign sibling" proposal. The rejection is the finding; the lane
> framing, the redrawn tarka boundary, the cite-don't-claim honest-negative, and the
> single meta-gradient nugget are what survived it.
