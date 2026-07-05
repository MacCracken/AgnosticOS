# ifran — the Training Control-Plane Port (Rust → Cyrius)

> **The Tier-A headline port** ([`software-port-path.md`](software-port-path.md) §3):
> ifran becomes the **training control plane for the sovereign-ML family** — the
> layer that replaces every sibling's hand-rolled train/checkpoint/sweep/eval
> harness with "submit a job to ifran." Opened 2026-07-04, immediately after
> the Type-3 chain froze (anukūlana 1.0.0) — the model/checkpoint substrate the
> control plane stores into (tula + sigil) is now stable.

| Field | Value |
|-------|-------|
| Status | **M0 DONE 2026-07-04** — `cyrius port` ran (user-directed): the Rust tree lives at `rust-old/` (reference oracle, eventual dismissal); Cyrius skeleton builds (pin 6.4.3), manifest corrected (`${file:VERSION}` + AGPL matched to the LICENSE file — **relicensing to GPL-3.0-only flagged as a maintainer call**); in-repo tracker = ifran `docs/development/port-ledger.md`. **M1 (job core) DONE same day** — proof met: `ifran run` drove the real `anukulana gpt2-lora` end-to-end (spawn/capture/record; suite 18/18). **M2 (checkpoint/model store) DONE same day** — operator keys + tula/sigil-verified content-addressed store; proof: the gpt2-tula job's artifacts ingested + verified (suite 29/29). **M3 (datasets) DONE 2026-07-05** — content-addressed corpora + REAL line-dedup (the Rust fake replaced) + `{dataset}` job references; proof: attn11 trained on an ifran-managed dataset (43/43). **M4 (sweeps) DONE 2026-07-05** — grid + seeded-random over job templates; a real attn11 steps-sweep trained 3/3 on the M3 dataset (53/53). **M5 (eval runner) DONE 2026-07-05** — sibling gates as recorded evals + metric extraction; proof: the HF-fidelity oracle as eval 1, maxrel captured (64/64). **M6 (preference store) DONE 2026-07-05** — and the **v1.0 acceptance is DEMONSTRATED**: attn11 + anukūlana + tarka ran entirely as ifran jobs in one workspace (77/77). **✅ SHIPPED — 2.0.0 CUT + TAGGED 2026-07-05.** The full arc (M0–M6 + stabilization + cmdit CLI) ran 2026-07-04→05. GPL-3.0-only; rust-old held to ~2.1/2.2; CLI on cmdit. **This planning doc's work is DONE** — post-2.0 lives in ifran's own roadmap/api.md additive lane. |
| Source | `~/Repos/ifran` — Rust 1.3.0, AGPL, **187 files / 53.6k lines**, tokio/axum/serde stack; shells all training math to Python; owns zero math |
| Shape | **In-repo port** (the goonj/naad/svara pattern — repo keeps its name + history; `cyrius port` conventions), per the resolved decomposition: **one repo**, internal module boundaries on the candidate seams, second-consumer-gated extraction |
| Decomposition | **RESOLVED 2026-07-04** (user) — recorded in [`software-port-path.md`](software-port-path.md) §3 |
| Discipline | Thin over existing homes; NO training math (the siblings own it); NO serving (hoosh); sovereignty rules apply (bayan not serde, patra not SQLite, sigil not ring) |

---

## 1. Survey → disposition map (from the 2026-07-04 source walk)

### Ports (the control-plane core — ONE Cyrius repo, internal modules)

| Rust module | Becomes | Notes |
|---|---|---|
| `train/job`, `train/executor`, `train/approval` | **job manager + scheduler** | the heart: submit/run/status/store; drives sibling binaries (attn11/tarka/anukūlana CLIs) as child processes — the math NEVER moves in |
| `train/checkpoint`, `registry`, `storage`, `versioning` | **checkpoint/model store over tula** | tula = the codec (frozen v1, NF4-ready), sigil = signing; **the named first-extraction candidate** (murti-seam + hoosh are the would-be second consumers) — keep its internal boundary crisp |
| `train/dataset`, `dataset` | **dataset load/validate/curate** | akshara-tokenized corpora; honest re-derivation (the Rust "dedup"/"perplexity" were fakes per the 2026-06-25 mining — do NOT port those, build real ones or omit) |
| `train/experiment`, `experiment` | **sweep runner** | grid + random now; the black-box-optimization gap (GP-BO/CMA-ES) stays a later, separately-triggered lane |
| `eval` | **eval runner + benchmark store** | drives the siblings' own gates (FD checks, fidelity fixtures) as jobs |
| `preference`, `rlhf` | **preference/annotation store** | feeds tarka's shipped DPO/KL/IPO/KTO surface |
| `budget`, `audit` (thin parts) | job quotas + run journal | journal integrates **libro** (audit chain), not a reimplement |

### Does NOT port (already owned, or dead)

| Rust module | Fate |
|---|---|
| `backends/` (candle/llamacpp/gguf/ollama/onnx/tensorrt/metal/tpu/gaudi/inferentia/oneapi/qualcomm + router/cost/health/circuit-breaker) | **DEAD** — the murti-era 15-backend broker, anti-sovereign per the [`murti.md`](murti.md) re-derivation. Local inference = rosnet/tentib via hoosh; foreign engines → **mehman**, reached around the core |
| `server/` (axum REST, ~21 groups) | **not carried by default** — the Rust API boundary is the monolith's, not ours (see Open Question 2) |
| `lineage` | → **itihas** (integrate, don't reimplement) |
| `marketplace` | → **mela** |
| `fleet` | → **seema** (its own later port) |
| `rag` | → **mneme** (future retrieval lane) |
| `hardware` | → **ai-hwaccel** |
| `tenant` | deferred — single-operator sovereign box first; multi-tenant is a server-stage question (aegis/kavach seams) |
| `bridge`, `pull`, `training_events`, telemetry (OTLP) | dead or re-derived minimally (events → the libro-backed journal) |
| `train/methods`, `train/scripts`, `train/distributed` | **the Python shells** — the whole reason the siblings exist; methods = attn11/tarka/tentib/prajna/anukūlana already; `distributed` deferred to seema-stage |

## 2. Milestones (small bites, each gated)

- **M0 — in-repo Cyrius scaffold + inventory. ✅ DONE 2026-07-04** via `cyrius
  port` (Rust → `rust-old/`); skeleton builds + scaffold tests green; the
  disposition map committed as ifran's `docs/development/port-ledger.md`.
- **M1 — the job core (the heart). ✅ DONE 2026-07-04.** CYML job specs →
  fork+pipe+execve (own capture — stdlib exec_capture discards exit status) →
  patra run store (`id INT AUTOINCREMENT`) → `ifran run`/`ifran runs`. Suite
  18/18. **Proof met:** the real `anukulana gpt2-lora` ran as an ifran job
  (33.6 s, exit 0, log captured, recorded). Porting notes in ifran's CHANGELOG.
- **M2 — the checkpoint/model store. ✅ DONE 2026-07-04.** Operator Ed25519
  keys (getrandom → sigil; 0600; no-clobber) + validate/verify/content-address
  ingest with honest sig status (`verified`/`signed-unknown-key`/`unsigned`)
  + tamper-detecting `store verify`. Proof: the `gpt2-tula` job's artifacts
  (63.8 MB + 3.3 MB) ingested + verified. Follow-on: producers sign with the
  operator key (additive anukūlana `--sk`, or sign-on-ingest).
- **M3 — datasets. ✅ DONE 2026-07-05.** Content-addressed text corpora
  (sigil sha256 identity, honest byte/line stats) + a REAL exact-line dedup
  replacing the Rust fake (do-not-port honored) + id-referencing (`dataset =
  N` / `{dataset}` resolves at run time, dangling ids fail loud). Proof:
  attn11 trained on a deduped ifran-managed corpus as an ifran job.
- **M4 — sweeps. ✅ DONE 2026-07-05.** Grid (cartesian) + seeded-DETERMINISTIC
  random (reproducible draws, suite-proven) over job templates; within-token
  `{axis}` substitution; every combo a sweep-tagged first-class run. Scope held
  to the honest Rust surface (grid/random); BBO stays its own lane. Proof: a
  3-combo attn11 steps-sweep trained on the M3-curated dataset.
- **M5 — eval runner. ✅ DONE 2026-07-05.** Sibling gates as recorded evals
  (exit code = the gate — the family's own discipline) + verbatim metric
  extraction from run logs into the benchmark store. Proof: anukūlana's
  HF-fidelity oracle as eval 1 — PASS, maxrel=0.000001049 captured.
- **M6 — preference/annotation store. ✅ DONE 2026-07-05.** Sets, DPO/IPO
  pairs, KTO thumbs (±1), escaped JSONL export (bayan parse-back proven).
  tarka file-ingestion of the export = a flagged, user-authorized follow-on.
- **v1.0 — ACCEPTANCE DEMONSTRATED 2026-07-05.** One workspace: attn11 trained
  (job + 3-combo sweep), anukūlana's fidelity oracle gated + benchmarked
  (maxrel captured), its artifacts in the signed store, tarka's full gate
  suite passed — all as recorded ifran jobs over ifran-curated datasets, with
  a preference set exported. Remaining for the CUT: the stabilization pass
  (freeze per first-party standards) + license/interface/rust-old calls.

## 3. Open questions (user calls, flagged not decided)

1. ~~In-repo vs fresh repo~~ — **RESOLVED (user 2026-07-04): in-repo via `cyrius
   port`** (Rust preserved at `rust-old/` for reference and eventual dismissal).
   NEW flag in its place: **license** — the Rust ifran is AGPL-3.0 (the LICENSE
   file, matched by the port manifest); relicensing the Cyrius port to the
   ecosystem's GPL-3.0-only is the maintainer's call.
2. **The interface surface.** CLI-first + library is the sovereign default;
   the Rust REST server is NOT carried by default. But SY currently
   HTTP-proxies ifran (`routes/ifran_proxy.rs`) — the re-sovereignized seam
   could be (a) CLI-only until SY re-wires, (b) a thin REST re-derivation
   later, or (c) MCP via **bote** (the agnos-native answer — bote already
   serves on agnos). Leaning (a) now + (c) when SY re-wires; decide by M2.
3. **Name.** Stays `ifran` (in-repo port keeps the name; the non-English
   semantic lane already fits — عرفان *gnosis*).

## 4. Cross-references

- [`software-port-path.md`](software-port-path.md) §3 — the resolved
  decomposition + Tier-A sequencing this plan implements.
- [`ml-product-mining.md`](ml-product-mining.md) — the control-plane process
  catalog (what the Rust ifran already knows how to orchestrate) + the
  honest-negatives (fake dedup/perplexity — do not port).
- [`murti.md`](murti.md) — why `backends/` is dead; the load-seam the M2 store
  feeds.
- [`type3-weight-import.md`](type3-weight-import.md) — tula/anukūlana, the
  frozen substrate the store builds on.
- [[project_ml_ai_arc_overview]] + [[project_secureyeoman_progenitor_pinnacle]]
  — the SY seam this port re-sovereignizes.
