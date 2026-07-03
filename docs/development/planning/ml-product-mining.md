# ML Product Mining — ifran + secureyeoman for the Sovereign-ML Lane

> Record of the 2026-06-25 review: what the ecosystem's two LLM **products** —
> [ifran](https://github.com/MacCracken/ifran) (Rust LLM controller) and
> secureyeoman (Rust/TS local-first AI assistant) — offer the sovereign Cyrius-native
> ML family ([attn11](https://github.com/MacCracken/attn11) /
> [tarka](https://github.com/MacCracken/tarka) /
> [tentib](https://github.com/MacCracken/tentib) /
> [prajna](https://github.com/MacCracken/prajna) on
> [rosnet](https://github.com/MacCracken/rosnet) /
> [tyche](https://github.com/MacCracken/tyche) /
> [akshara](https://github.com/MacCracken/akshara)). Mined by a 26-agent
> fan-out → adversarial-verify → synthesize workflow.

| Field | Value |
|-------|-------|
| Status | **Reference record + forward pointers.** The actionable items live in the linked docs. |
| Created | 2026-06-25 |
| Method | 6 parallel readers (ifran train-methods / data-lineage / HPO-eval-distributed / preference + sy-code; sy ADRs+guides+Cyrius; sibling+axis-map coverage) → synthesis → adversarial verify of every candidate (duplication gate + sovereign-reference-philosophy check) → ranked synthesis. ~1.9M tokens. |

---

## The core finding — orchestrators, not algorithm sources

**Both products shell ALL training math to Python** (peft / unsloth /
transformers / trl / bitsandbytes) or to external HTTP LLM/embedding services.
Almost no hand-derived, minable learning algorithm exists in either tree. The
*only* in-tree hand-written loss on either surface is ifran's KD soft-target
(`ifran/src/train/scripts/train_distill.py`). LoRA, DPO, RLHF, NF4, FedAvg are all
thin delegating wrappers — so the fact that a technique appears across *both*
products is **demand evidence** (which techniques AGNOS will eventually want), not
portable code.

Honest-negatives the verification caught (so they are not re-mined):
- ifran "dedup" = opaque caller-hash SQLite `COUNT` membership (computes no hash);
  ifran "perplexity" = `(1/contains-rate).min(1000)` (fake); FedAvg aggregation
  math is **absent** (shells to a non-present Python module).
- secureyeoman's `yeo-cy-test/` has **ZERO Cyrius ML** — it is a web/SQL/TSX CRUD
  porting slice. `regression.cyr` / `regression_agnos.cyr` are fork/exec/SSH
  *test*-regression harnesses (not statistical regression); `ganita.cyr` /
  `math.cyr` / `simd.cyr` are **vendored cyrius stdlib**, and `simd.cyr` is
  **f64-only → does NOT unblock tentib 0.4.1's int-SIMD-gated kernel**.

---

## The strategic conclusion — ifran-when-ported is the training *control plane*

The orchestration-not-algorithms finding is not a disappointment — it is the
**right division of labor**, and it points at ifran's real role in the sovereign
stack:

> **The siblings own the MATH; a ported ifran owns the ORCHESTRATION.**
> attn11 / tarka / tentib / prajna prove the *learning primitives* (hand-derived
> forward+backward, FD-gated, no BLAS/libc/autodiff). Each today also hand-rolls
> its **own** training/eval harness — a train loop, a checkpoint scheme, a
> grad-check runner, an ad-hoc sweep. **ifran is exactly the layer that replaces
> those hand-built harnesses**: job management + scheduling, checkpoint store,
> dataset load/validate/curate, hyperparameter sweeps, the eval runner, and
> lineage/provenance — the *control plane* around a training run.

So the catalogued "infra tail" (below) is **out-of-scope as a sovereign
*primitive*, but in-scope as the orchestration a ported ifran delivers** to the
whole family. Once ifran is ported to Cyrius / runs natively on AGNOS, the
siblings stop reinventing run-management and instead *submit jobs to ifran* —
ifran drives `attn11 train …` / `tarka train …`, stores the checkpoints, runs the
eval suite, sweeps the hyperparameters (random/grid now; the planned black-box
optimizer later), and records the dataset→training→eval→deploy lineage. The
sovereign-ML siblings provide the model definitions and the FD-gated gradients;
ifran provides "run this, checkpoint it, sweep it, evaluate it, track it."

**Gating.** This is a forward direction, not a scheduled task — it turns on the
**ifran Cyrius port** (ifran is AGPL Rust today, integrating with agnosticos as a
systemd service with capability registration). Until then the siblings keep their
hand-built harnesses. The point of recording it now: when the ifran port opens,
its target is **the training control plane for the sovereign-ML family**, and the
process catalog below is the spec of what that control plane already knows how to
do.

**Control-plane process catalog (what a ported ifran brings):** job manager +
scheduler + status/store (`src/train/job/`); checkpoint store (`src/train/checkpoint/`);
dataset loader / validator / labeler / curator (`src/train/dataset/`, `src/dataset/`);
hyperparameter experiment runner + search (`src/train/experiment/`, `src/experiment/`);
eval runner + benchmark store (`src/eval/`); preference / RLHF annotation stores
(`src/preference/`, `src/rlhf/`); lineage/provenance DAG (`src/lineage/`); distributed
coordinator/worker/placement (`src/train/distributed/`). Each maps to an existing
AGNOS home where it is *not* ifran's to own (lineage → itihas; inference serving →
hoosh; GPU → mabda/ai-hwaccel; real hashing → sigil; provider routing → hoosh).

---

## The harvest (deduped vs the 7 siblings + 5 axis maps)

### Updates to existing siblings — where the primitive value concentrates
| Sibling | Feature | Priority | Spec |
|---------|---------|----------|------|
| **tarka** | DPO (reparam `reward.cyr` Bradley-Terry + frozen ref-policy, β=0.1) | **high** | [`tarka-preference-rlhf-extensions.md`](tarka-preference-rlhf-extensions.md) |
| **tarka** | RLHF KL-to-reference-policy penalty (grep-confirmed absent) | med | same |
| **attn11** | KD soft-target objective (`--objective KD`) | med | gated on attn11 reopening (M20 is infra-only) |
| **tarka** | Multi-armed bandits / Thompson sampling | med | seeds the black-box-opt continuum |
| **tarka** | pass@k unbiased binomial estimator | low | the one real eval nugget (perplexity already in attn11) |
| **tyche** | DP noise (Gaussian/Laplace, ε-budget) | low | seema-gated; see `generative-paradigms.md` federated bullet |
| **attn11** | speculative decoding (DSpark ref) · EDA text-aug | low→med | now a full map: [`speculative-decoding.md`](speculative-decoding.md) — DeepSeek DSpark (2026-06) upgraded it to a concrete reference arch, homed as an attn11 **decode lane** reusing MTP heads + the KD objective; still gated on attn11 reopening |
| **abaco** | z/t-test CDF · robust-aggregation stats | low | non-sibling system-math home |

### New-lib candidates (names deferred — second-consumer-triggered)
- **QLoRA seed (LoRA adapter + NF4 quant)** — *high.* Routes to the already-planned
  `generative-paradigms.md` **Type-3 "Pre-Trained"** reference (NOT attn11, NOT
  tentib). The most-corroborated demand. Spec folded into
  [`generative-paradigms.md`](generative-paradigms.md) Type-3.
- **Black-box / derivative-free optimization** (GP-BO + acquisition + CMA-ES) —
  *medium.* The **single true unmapped gap** (on no axis map, colliding with no
  sibling). Weak demand (both products ship only grid+random) → prototype on
  rosnet+tyche, let a sibling hyperparameter sweep trigger the cut.
- **Trust-spine (SAE + split-conformal)** — *low.* Already research-watch in
  `generative-paradigms.md`; do not scaffold.

### New axis map
- **Classical / shallow ML** → the **`amuzesh`** lane (Persian آموزش, *learning*; named
  2026-06-25), mapped in [`classical-shallow-ml.md`](classical-shallow-ml.md) — the one
  genuinely orthogonal gap (all other axes are deep-learning; substrate already ships via
  ganita + hisab). **Named, not scaffolded** — repo waits for a second consumer.

### Verified out-of-scope as a *primitive* (but see the control-plane section)
Federated-as-a-new-axis (rejected, ~80% infra), ACT-R/Hebbian associative-memory
("smriti" — RAG ranking plumbing), drift-detection (textbook stats → abaco),
RAGAS / fairness / tool-call / BLEU-ROUGE eval, and the whole
stores / CRUD / REST / RAG-plumbing / governance / fleet tail. Already-owned:
PPO/GAE/GRPO/reward/PRM (tarka 1.0), SFT/pretrain/SSM (attn11), experience-replay
continual learning (prajna). Rejected new-lib names: `mulyankan` (eval),
`prakash` (interpretability), `smriti`.

---

## Cross-references

- [`generative-paradigms.md`](generative-paradigms.md) — QLoRA→Type-3 seed,
  federated routing, trust-spine cores (all enriched 2026-06-25).
- [`classical-shallow-ml.md`](classical-shallow-ml.md) — the new axis this mining
  surfaced.
- [`tarka-preference-rlhf-extensions.md`](tarka-preference-rlhf-extensions.md) —
  the DPO + KL-penalty spec.
- [`integer-native-ml.md`](integer-native-ml.md) · [`self-improvement-lane.md`](self-improvement-lane.md)
  · [`multimodal-substrate.md`](multimodal-substrate.md) — the other axis maps.
