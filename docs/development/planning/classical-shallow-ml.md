# amuzesh — Classical / Shallow ML, Right-Tool Pluralism off the Deep-Learning Monoculture

> **amuzesh** (Persian آموزش — *learning / education / training*; transliterated *âmuzesh*).
> Named 2026-06-25. The name is the AGNOS non-English-direct-semantic lane (alongside the
> Sanskrit `tarka`/`prajna`): it means, literally, *learning* — the plain word for what this
> whole surface does, and a deliberate counterpoint to the deep-learning siblings.

> Forward design + reference map for the **model-class floor** of sovereign ML:
> the non-deep-learning mechanisms — clustering, generalized linear models, trees,
> filters — that are sometimes the *provably-smallest* right tool. This is the
> **fifth** axis-map alongside [`generative-paradigms.md`](generative-paradigms.md)
> (the **paradigm** axis), [`multimodal-substrate.md`](multimodal-substrate.md)
> (the **modality** axis), [`integer-native-ml.md`](integer-native-ml.md) (the
> **arithmetic-floor** axis), and [`self-improvement-lane.md`](self-improvement-lane.md)
> (the **self-improvement / adaptation-timescale** axis).
>
> **It is orthogonal in a way the other four are not:** those four are all *deep-learning*
> axes (where, how cheap, what modality, what timescale — but always a neural net
> trained by gradient descent). This axis steps off that monoculture entirely.
> It promotes the **"right-tool pluralism"** bullet from `generative-paradigms.md`'s
> Further-Horizons list (lines 310–312, 400–407) into a map of its own, because
> the sovereignty argument for it is distinct: *the most auditable, most
> integer-friendly, most defensible mechanism is often not a transformer.*

| Field | Value |
|-------|-------|
| Status | **Active** — **scaffolded 2026-06-27**; M0 v0.1.0 shipped ([MacCracken/amuzesh](https://github.com/MacCracken/amuzesh), `cyrius init`, pin 6.2.44): k-means (Lloyd) + k-means++ (D²-weighted) + nearest-centroid prototype classifier on the ganita + tyche substrate — demo purity/accuracy 100%, suite **23/23**. Lane name **`amuzesh`** chosen 2026-06-25. The *further* mechanisms (logistic-IRLS, GLM / ridge / PCA, GBDT, Kalman / HMM, naive-Bayes) stay forward-mapped + second-consumer-triggered. (The Sanskrit `sankhya` was unavailable — a shipped v2.0.0 ancient-mathematics / calendar / archaeoastronomy lib — so the lane took the Persian word for *learning* instead.) |
| Axis | **Model-class floor** — orthogonal to the four deep-learning axes; "when the right model is *not* a neural net." |
| Owns | the **amuzesh** lane — the classical / shallow-ML reference surface. Nothing built yet; stands **on already-shipped numeric libs**, not re-implemented. |
| Substrate | [ganita](https://github.com/MacCracken/ganita) (linear algebra: LU / QR / Cholesky / SVD / eigen / least-squares / pseudo-inverse) · [hisab](https://github.com/MacCracken/hisab) (optimization: gradient-descent / CG / BFGS / LBFGS / Levenberg–Marquardt + autodiff / FFT) · [rosnet](https://github.com/MacCracken/rosnet) (f64 tensors) · [tyche](https://github.com/MacCracken/tyche) (sampling, k-means++ seeding) · [abaco](https://github.com/MacCracken/abaco) (statistical primitives). Live versions: [`state.md`](../state.md). |
| Created | 2026-06-25 (from the ifran + secureyeoman product-mining — see [`ml-product-mining.md`](ml-product-mining.md)) |

---

## The frame — why a classical axis is honest, not nostalgic

The deep-learning siblings (attn11 / tarka / tentib / prajna) prove that
*gradient-based learning* is expressible assembly-up in everything-is-i64 Cyrius.
That is the family's thesis and it is the right thesis. But "prove the mechanism
small, taken honestly" cuts both ways: on **tabular telemetry, noisy state
streams, and small-data classification**, a gradient-boosted tree or a Kalman
filter beats a deep net — and, crucially for AGNOS, it does so with an
**interpretable, auditable, often integer-friendly** decision path. The
sovereignty value here is not capability — it is **trust and smallness**:

- **phylax / aegis "ML" should be a sovereign auditable GBDT, not a neural black
  box.** A threat-detection split path you can *defend* in an audit beats a logit
  no one can explain. (Stated verbatim in `generative-paradigms.md`:407.)
- **Right-tool pluralism is a sovereignty stance.** Refusing to force every
  problem through a transformer is the same instinct as refusing the cloud:
  use the mechanism whose cost and behavior you can fully account for.
- **Most of it is integer- or small-matrix-friendly** — naturally aligned with
  the same metal-up discipline as the rest of the family.

> **This is not a deep-learning axis, so it does not inherit the
> finite-difference-gradient gate as its universal verifier.** Each mechanism gets
> the *honest* verification for its kind: FD-gate where there is a gradient
> (logistic-regression IRLS, GBDT leaf fitting), and a **convergence / coverage /
> regret** check where there is not (k-means inertia monotonicity, conformal
> finite-sample coverage, filter RMSE vs a Kalman-optimal baseline).

---

## The members (forward map — not a build order)

Most of these are **thin wrappers over already-shipped substrate** — the table
flags how much genuinely-new content each adds, because that is the whole
question for an emergent-extraction lane.

| Mechanism | What it proves | New content over ganita/hisab/abaco | Fit |
|-----------|----------------|--------------------------------------|-----|
| **k-means / k-means++** | unsupervised clustering; Lloyd iteration + ++ seeding (tyche) | **genuinely new** (assignment + centroid update + inertia) | strong |
| **Nearest-centroid / prototype classifier** | zero-/few-shot classification over embeddings | **genuinely new** (small) | strong |
| **Logistic regression (IRLS) / softmax** | the GLM classification floor; Newton/IRLS or GD | **modest new** (IRLS reweight; GD already in hisab) | strong |
| **Linear / ridge regression** | the GLM regression floor | **thin** — least-squares / pseudo-inverse already in ganita | moderate |
| **PCA** | linear dimensionality reduction | **thin** — eigen / SVD already in ganita | moderate |
| **Naive Bayes** | the probabilistic-classifier floor | **modest** (likelihood tables) | moderate |
| **Gradient-boosted trees (GBDT)** | the *auditable* tabular/telemetry workhorse — the phylax/aegis form | **substantial** (tree fitting, split search, leaf optimization) | strong (research-watch) |
| **Kalman / HMM filters** | state estimation over noisy streams; a tiny matrix recurrence / forward-backward | **modest** (predict/update; Viterbi) | strong (research-watch) |

The genuinely-new surface is therefore **small and concentrated**: k-means,
the prototype classifier, logistic-IRLS, and — when it moves — GBDT + the
filters. PCA and linear/ridge are near-free over `ganita`. That smallness is the
case *for* one coherent lane and *against* scaffolding prematurely.

---

## Demand evidence (weak, and that is fine)

The 2026-06-25 mining found classical-ML demand only as **shallow classifiers
over external embeddings** in secureyeoman (intent routing, retrieval ranking) —
modest glue, not a deep need, and like all the mined training math it is
shelled out, not implemented in-tree. So this axis is **genuine but unhurried**:
real enough to map (it is the honest home for capabilities currently scattered as
`generative-paradigms.md` research-watch bullets), not pressing enough to build.

---

## Sequencing & gating

- **Scaffolded (M0); the rest is research-watch + second-consumer-triggered.** The repo exists
  ([MacCracken/amuzesh](https://github.com/MacCracken/amuzesh), scaffolded 2026-06-27) and M0
  ships the largest genuinely-new core (k-means + prototype classifier). Extraction stays emergent
  in this family — a *further* mechanism becomes a shipped lib only when a *second* consumer
  actually needs it (the standard trigger that produced `taar` from yo+dig). M0 was the
  user-authorized first cut; subsequent mechanisms wait for the pull, not the push.
- **Likely first mover when it does move:** k-means + prototype classifier (the
  largest genuinely-new content, smallest dependency surface, clearest single
  demand), or **GBDT** if phylax/aegis pulls it forward as the auditable
  threat-feature model.
- **Substrate-first.** Build on `ganita` / `hisab` / `abaco` / `rosnet` — do not
  re-implement linear algebra or optimization. The novelty budget is spent only on
  the model-specific logic (assignments, split search, filter recurrences).
- **Honest verification per mechanism** (see the frame box) — FD-gate gradients,
  convergence/coverage/regret elsewhere; benchmark each vs a named real-world
  reference (scikit-learn / XGBoost / a Kalman-optimal baseline) under the
  family's fairness-ruled harness shape.

---

## Cross-references

- [`generative-paradigms.md`](generative-paradigms.md) — the paradigm axis; this
  doc promotes its "right-tool pluralism" Further-Horizons bullet into a map.
- [`integer-native-ml.md`](integer-native-ml.md) · [`self-improvement-lane.md`](self-improvement-lane.md)
  · [`multimodal-substrate.md`](multimodal-substrate.md) — the other axis maps.
- [`ml-product-mining.md`](ml-product-mining.md) — the 2026-06-25 ifran/secureyeoman
  mining that surfaced this axis (and why the products are orchestrators, not
  algorithm sources).
- [`shared-crates.md`](shared-crates.md) — ganita / hisab / abaco / rosnet / tyche
  registry.
