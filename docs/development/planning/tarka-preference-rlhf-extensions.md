# tarka — DPO + RLHF KL-to-Reference-Policy (forward plan)

> Forward design for two **charter-owned-but-unbuilt** extensions to
> [tarka](https://github.com/MacCracken/tarka) (the sovereign RL / reasoning
> reference), surfaced by the 2026-06-25 ifran + secureyeoman product-mining
> ([`ml-product-mining.md`](ml-product-mining.md)). tarka's charter is "owns ALL
> RL + ALL preference optimization," and both products carry these techniques —
> but only as thin TRL wrappers (the math shells out to Python), so this is
> **demand evidence**, and a grep of `tarka/src` confirms **neither is built**.

| Field | Value |
|-------|-------|
| Status | **✅ SHIPPED — superseded by the tarka 1.1.x line.** Both bites landed as user-authorized additive cuts: **tarka 1.1.0** (DPO `src/dpo.cyr` + the RLHF KL-to-reference-policy penalty + the frozen `dpo_snapshot()` reference, FD-gated) and **tarka 1.1.1** (`src/preference_ext.cyr` **IPO + KTO** — going *beyond* this doc's "DPO only" scope wall). This doc is retained as the pre-build spec; current truth = tarka's CHANGELOG. |
| Target | [tarka](https://github.com/MacCracken/tarka) — additive, post-1.0 levers |
| Reuses | `tarka/src/reward.cyr` (Bradley-Terry loss, hand-derived backward) · `rl.cyr` (rollout + EMA baseline) · [rosnet](https://github.com/MacCracken/rosnet) · the 24/24 finite-difference grad-check discipline |
| Created | 2026-06-25 |

---

## Why these two, and why tarka (not a new sibling)

The mining's duplication gate is decisive here: a sibling already owns the area,
so these route to **tarka as updates**, never to a new repo. The verifiers
confirmed both are *absent* today:

- **DPO** — `grep` for `dpo` / `reference.policy` in `tarka/src` → nothing. But the
  loss it needs is a **reparameterization of a loss tarka already has**.
- **RLHF KL-to-reference-policy** — `grep` for `kl_div` / `kl_coef` / `kullback`
  across all of `tarka/src` → **zero hits**; `rl.cyr` carries only an EMA baseline,
  not a reference-policy KL. This is a genuine, hand-derivable, FD-gateable
  primitive the "owns ALL RL" charter should hold and currently lacks.

Everything *else* RLHF-shaped that the products carry (PPO / GAE / value critic /
clipped surrogate / GRPO / reward & process-reward models) is **already shipped**
in tarka 1.0.0 — out of scope.

---

## Bite 1 — DPO (Direct Preference Optimization) · highest ROI, lowest effort

**The math.** The DPO implicit reward is
`r_θ(x,y) = β · (log π_θ(y|x) − log π_ref(y|x))`, and the loss over a preferred /
dispreferred pair `(y_w, y_l)` is
`L = −log σ(r_θ(x,y_w) − r_θ(x,y_l)) = softplus(−Δ)`, with
`Δ = β · [ (logp_θ − logp_ref)_w − (logp_θ − logp_ref)_l ]`.

**Why it is cheap.** `softplus(−Δ)` is *exactly* the Bradley-Terry pairwise loss
already implemented in `reward.cyr` (forward ≈ line 55, hand-derived backward ≈
line 102). DPO does not add a new loss — it **reparameterizes the score `Δ`** as
an implicit reward. The only genuinely new machinery:

1. **Sequence log-prob plumbing** — sum the per-token log-probs of a completion
   under the policy (`logp_θ`) and under a frozen reference (`logp_ref`).
2. **A frozen reference-policy snapshot** — copy policy params once, no-grad
   forward. (Shared with Bite 2 — build the snapshot mechanism once.)
3. **The `β` scale** — the one concretely-mined hyperparameter (`β = 0.1`, from
   both products' `train_dpo.py`).

**Verification.** FD-gate the new `Δ`→loss path (tarka's standard grad-check);
the Bradley-Terry backward is already gated, so only the reparam + seq-logprob
gradient is new.

**Scope wall.** First bite is **DPO only.** IPO / KTO are sound charter
follow-ons but are **not** evidenced by the mined wrappers — defer them.

---

## Bite 2 — RLHF KL-to-reference-policy penalty · completes the RLHF story

**The math.** Augment the per-token RL reward with a KL penalty against a
**frozen reference policy**: `r' = r − β · KL(π_θ(·|s) ‖ π_ref(·|s))`
(Ouyang 2022 / TRL `init_kl_coef`). Hand-derive the gradient of the KL term
through the policy logits; FD-gate it.

**Why it is distinct from what tarka has.** This is **not** tarka's existing
`π_old` importance-ratio clip (that is a PPO trust-region snapshot of the policy,
used in the ratio — not a penalty against a fixed *reference*), and **not** the
frozen reward model (a learned scalar, not a policy distribution). A reference
**policy** KL is a third, currently-missing thing.

**Reuses.** The frozen-snapshot mechanism from Bite 1; `rl.cyr`'s rollout +
advantage path; rosnet for the logit math.

**Priority.** Medium, post-1.0 lever — smaller demand pull than DPO, but it is the
last real gap in tarka's RLHF surface.

---

## Sequencing & gating

1. **DPO first** — lowest effort (reuses `reward.cyr`'s loss + backward), highest
   ROI, most-corroborated demand.
2. **KL-to-reference-policy second** — reuses Bite 1's snapshot mechanism.
3. Both are **additive** to tarka 1.0.0's frozen API and must land as
   **user-confirmed cuts** (1.0.0 froze the public surface; new objectives are a
   minor-version, user-driven decision — mirrors the attn11→tarka RL de-feature
   precedent where a cross-repo capability move was its own confirmed step).
4. Each new gradient path **finite-difference-gated** before merge (tarka holds
   24/24; new paths extend that count).
5. **No `tarka/` edits without explicit user authorization.** This doc is the
   spec; the work starts only on a go-ahead.

---

## Cross-references

- [`ml-product-mining.md`](ml-product-mining.md) — the mining that surfaced these.
- [`self-improvement-lane.md`](self-improvement-lane.md) — RLAIF / self-rewarding
  is a tarka **recipe-lane** feeding this DPO surface, not a new sibling; the
  sovereign form uses tarka's own trained reward/PRM as critic.
- tarka `docs/development/roadmap.md` + `docs/api.md` (frozen 1.x surface) — where
  these become real roadmap entries once authorized.

---

## Since This Was Written (2026-07-04)

Everything above shipped, user-authorized, as the **tarka 1.1.x preference line**:

- **1.1.0** — Bite 1 **DPO** (`src/dpo.cyr`, softplus(−Δ) over the reparameterized
  implicit reward; demo raises target frequency 0.94 → 24.00/24) **and** Bite 2
  **KL-to-reference-policy** (`β·KL(π_θ ‖ π_ref)`, frozen `q`; demo pulls mean KL
  3.33 → 2.46), sharing the `dpo_snapshot()` frozen-reference mechanism as planned.
  All new gradient paths FD-gated (maxrel ≤ 9e-9).
- **1.1.1** — **IPO + KTO** (`src/preference_ext.cyr`), completing the standard
  preference-loss set on the same frozen-reference machinery. This went *past* the
  scope wall above ("First bite is DPO only… defer IPO/KTO") in a later authorized
  cut.

The spec's math, reuse analysis (Bradley-Terry reparam), and sequencing all held.
Current truth lives in tarka's CHANGELOG + `docs/api.md`; this doc is historical.
