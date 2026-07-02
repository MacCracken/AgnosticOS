# Type-3 "Pre-Trained" — Sovereign Weight Format + Importer + LoRA/QLoRA

> **Gap #1** of the ML/AI stack ([`software-port-path.md`](software-port-path.md)) — the highest-value unhomed ML capability. Promoted from the `generative-paradigms.md` **Type-3 "Pre-Trained"** section into its own opened planning doc.
>
> **Thesis:** *sovereign from the metal up **and** interoperable with the world's weights.* Run someone else's published checkpoint (GPT-2-small / TinyLlama-class) on AGNOS's own kernels, and adapt it (LoRA/QLoRA) — with **nothing borrowed** (no safetensors lib, no GGUF lib, no bitsandbytes, no PyTorch). The moment AGNOS produces correct logits from someone else's pretrained weights, the headline is real.

| Field | Value |
|-------|-------|
| Status | **IN PROGRESS.** Chain scaffolded: `tula` 1.0.0 (format frozen), `rupantara` 0.2.0 (forward ported + `ru_*`-namespaced; attn11 leaf-op re-fold green 2026-07-02), `anukūlana` 0.1.0 (stub). ✅ rupantara whole-forward parity PROVEN bit-identical vs attn11 (2026-07-02). Next: anukūlana M1 importer (foreign parser = the real effort). |
| Axis | The **paradigm** axis, Type 3 (Pre-Trained) — [`generative-paradigms.md`](generative-paradigms.md) |
| Substrate | [rosnet](https://github.com/MacCracken/rosnet) (f64 tensors + forward + LoRA linears) · [attn11](https://github.com/MacCracken/attn11) (transformer layout to map onto) · [akshara](https://github.com/MacCracken/akshara) (tokenizer for the imported model) · [sigil](https://github.com/MacCracken/sigil) (signed-header trust boundary) · [tentib](https://github.com/MacCracken/tentib) (the *other* quantization — keep NF4 separate) · vahana/sankoch (container) |
| Naming | **Deferred** (Sanskrit/Hindi system-lib lane) per the 2026-06-08 attn11→libs decision; pick at scaffold time |
| Discipline | Cyrius-native, no BLAS/libc/autodiff, FD-gate the LoRA gradient, fairness-ruled logit-fidelity benchmark vs the reference impl, honest-negatives reported |

---

## 1. What it comprises (three parts)

### Part A — the sovereign weight-file format (a safetensors/GGUF analog)
A typed, mmap-friendly, **sigil-signable** container for model weights — the on-disk form that AGNOS-trained checkpoints (attn11, tentib ternary), imported foreign models, and control-plane checkpoints all take.

- **Header:** magic + version + a **sigil signature** over (manifest ‖ payload-hash) — the trust boundary (reject unsigned/tampered at load). i64 bit-pattern endianness note.
- **Manifest:** typed tensor entries `{name, dtype, shape, offset, length}` with `dtype ∈ {f64, int8, ternary-packed (tentib), nf4-block}`, plus arch metadata (layers, dims, layout hints for the importer). Binary manifest for mmap; optional CYML sidecar for human inspection.
- **Payload:** raw tensor bytes at aligned offsets (mmap-friendly, zero-copy load). Container may be raw or **sankoch**-compressed / **vahana**-packaged.
- **Vs prior art:** takes safetensors' *typed-manifest + raw-payload + mmap* shape and GGUF's *typed-KV metadata*, adds a **sovereign trust header (sigil)** they lack, Cyrius-native. Ported shape, not copied code.

### Part B — the weight importer (the headline proof)
- **Read** a real published checkpoint: parse foreign **safetensors** and/or **GGUF** headers → extract tensors. (Own parsers, no libs.)
- **Map** foreign tensor names/shapes onto the sovereign transformer layout (e.g. GPT-2 `transformer.h.N.attn.c_attn.weight` → our layout) via a per-source-arch mapping table. dtype convert (fp16/bf16 → f64 widen; or keep quantized for the NF4 path).
- **Run** the forward on rosnet and produce logits. **Fidelity gate:** logits match the reference implementation (HF / nanoGPT `from_pretrained`) on the same input, within tolerance — the fairness-ruled B-series benchmark shape.

### Part C — adaptation (LoRA → QLoRA)
- **LoRA** — `W' = W + (α/r)·B·A`; `A` gaussian-init, `B` zero-init; gradients route **only** into `A,B` = two ordinary `rosnet.linear_bwd` passes, **no new gradient op**. ⚠ the naive `dL/dA = Bᵀ·dL/dZ` one-liner is **wrong** (omits the activation `Xᵀ` term) — let `linear_bwd` supply it. FD-gate the `A,B` path.
- **QLoRA / NF4** — the mined, highest-credibility cut: 4-bit **blockwise NormalFloat** quantization (16 normal-distribution quantiles, per-block absmax scale) + **double-quantization** (quantize the per-block scales) + LoRA adapters in higher precision over the **frozen NF4 base**. Forward = dequant-on-the-fly. **NF4 lives HERE, not tentib** (tentib = QAT-from-scratch+STE; this = quantize-an-*imported*-checkpoint — per tentib ADR 0001). Land as a **user-confirmed additive step**.

---

## 2. Where it lives (the homing decision — the crux)

Type-3 is unusual among the paradigm references: its core deliverable is a **format + importer**, not a new differentiable primitive (LoRA is two rosnet linears; NF4 is a forward-only quant codec). So it homes as **two things**, and a prerequisite:

**Prerequisite — a consumable transformer forward.** Running imported weights needs a transformer forward pass. attn11 *is* the sovereign transformer but is a reference *binary*, not a lib. Two ways to satisfy this: (a) extract attn11's **transformer-blocks** to a lib (the planned attn11→libs boundary #4; the v1.0 extract window is open), or (b) **prototype inside attn11's 1.x line** (which already has the layout + forward + checkpoint infra). This is what makes prototype-in-attn11 the pragmatic first step.

**Recommended homing:**

| Piece | Where it lives | Rationale |
|---|---|---|
| **Format codec (Part A)** | Prototype in the importer; **extract to a sovereign weight-format lib** (name deferred) on the 2nd consumer — which is **immediate** (attn11 checkpoints + tentib ternary + the murti load-seam + control-plane checkpoints all want it). So it becomes a lib early. | It's pure serialization consumed by many — the clearest shared-lib in the whole gap. |
| **Importer + run (Part B)** | **Prototype inside attn11's 1.x line** (an `--import` path: foreign checkpoint → attn11 layout → logits on rosnet) as the **stand-in**, then **graduate to its own Type-3 reference repo** once adaptation grows it. | Prove-inline-then-extract (the rosnet/tyche/akshara precedent). The paradigm map explicitly casts attn11 as a temporary stand-in that hands off — this is that pattern. Importing+running is **not training** (respects attn11's M20 charter). |
| **Adaptation (Part C)** | The **Type-3 reference** (the graduated repo). **NOT attn11** (charter excludes training science), **NOT tentib** (that's QAT-from-scratch). | LoRA/QLoRA is where Type-3 becomes its own thing worth a repo. |
| **Stateful model/checkpoint store** | **control-plane (ifran)** + container **vahana/sankoch** + hashing **sigil** | A *store* (indexed, dedup, eviction) ≠ the *codec*. Different artifact, different lifecycle. |

**DECISION (2026-07-01): GREENFIELD the Type-3 reference repo now** (user chose clean separation over prototype-in-attn11). This makes the **attn11→libs transformer-blocks extraction a HARD PREREQUISITE** (a greenfield repo needs a consumable forward and must not duplicate it). Dependency chain to stand it up:

1. **`rupantara`** (रूपान्तर — *transformation / metamorphosis; change of form*) — the transformer-blocks lib (attn11→libs #4): extract attn11's transformer forward into a consumable lib (the kashi/sandhi extract+re-fold pattern). **✅ SCAFFOLDED + M1 forward ported (0.2.0) + `ru_*`-namespaced; the attn11 re-fold LANDED for the CPU leaf ops 2026-07-02** — attn11 delegates `ln_fwd`/`gelu_fwd`/`attn_core_fwd`(causal) to `ru_*` and its **1049 grad-checks are green in one binary** (the real parity gate). **✅ AND the whole composition forward is now proven bit-identical too** (2026-07-02): `test_rupantara_parity` in attn11's suite feeds attn11's `g_params` into `ru_model_fwd` and matches `model_forward` bit-for-bit (`diffs==0` / `maxrel=0`, 4 configs — MHA ±bias / GQA / MQA / 1–3 blocks; attn11 1057 green). The M1-acceptance parity gap is CLOSED. Name chosen 2026-07-01.
2. **`tula`** (तुला — *balance / scale; the instrument that weighs*) — the weight-format lib: the codec (manifest + payload + sigil header). **Independent of #1 — the recommended first repo** (round-trips attn11 checkpoints = M0). Name chosen 2026-07-01. **✅ SCAFFOLDED + M0 GREEN 2026-07-01** (`/home/macro/Repos/tula`, Cyrius pin 6.3.26, stdlib-only): format (header + typed manifest + payload) + builder/reader + in-memory round-trip, **22/22** assertions, `dist/tula.cyr` generated. Next: M0b sigil-signed header (`sig_off`/`sig_len` reserved), then M1 file I/O (mmap read / write-to-disk).
3. **`anukūlana`** (अनुकूलन — *adaptation*) — the Type-3 reference repo: importer + run + LoRA/QLoRA, consuming `rupantara` (#1) + rosnet + `tula` (#2). Name chosen 2026-07-01.

**Names chosen 2026-07-01 (Sanskrit/Hindi system-lib lane): `rupantara` / `tula` / `anukūlana`.** Nothing is created without an explicit **per-repo go** — `mkdir` + Write only, **no git** (user owns all git). The stateful checkpoint *store* still stays the control-plane's (vahana/sankoch + sigil), separate from the `tula` codec.

---

## 3. New content vs reused

**New:** the format codec + signed header (sigil integration) · the foreign safetensors/GGUF parsers · the tensor-name/shape mapping layer · **NF4** blockwise-NormalFloat + double-quant (forward dequant). **Reused:** rosnet (tensors, `linear`, the forward) · attn11 layout / transformer-blocks · **LoRA = two rosnet linears (no new gradient op)** · akshara (tokenizer) · sigil (signing) · the FD-gate discipline (for the LoRA path) · the B-series fairness harness.

---

## 4. Milestones

- **M0 — Format codec.** Define the sovereign weight-file format (manifest + payload + sigil-signed header); **round-trip an attn11 checkpoint** through it (write→read, bit-identical), sigil verify rejects tampering. *(Proves the format on a model we control.)*
- **M1 — Importer + fidelity gate.** Parse a real **GPT-2-small safetensors**, map onto the layout, run on rosnet, and **match the reference logits** on a fixed input (fairness-ruled). *The headline: AGNOS runs someone else's pretrained weights sovereignly.* CPU-f64, no GPU.
  - ⚠ **M1a — foreign parser + name-mapping is the single largest net-new effort in the whole chain, and it is invisible in the tula→rupantara→anukūlana box.** Neither `tula` (the *sovereign* format) nor `rupantara` (forward only) provides it: it's a **from-scratch safetensors (and later GGUF) header parser + a GPT-2 tensor-name/shape mapping table (nanoGPT `from_pretrained` shape)**, all consuming **untrusted foreign input**. Treat it as its own sub-milestone with a security callout, and **pull its hardening (bounds/overflow/malformed-header rejection) forward — do not defer it to anukūlana M5.**
- **M2 — LoRA.** Two low-rank rosnet linears over the imported base; **FD-gate the `A,B` gradient**; a fine-tune measurably adapts.
- **M3 — QLoRA / NF4.** Blockwise-NormalFloat 4-bit + double-quant + LoRA over the frozen NF4 base; correct dequant; the mined highest-credibility cut. **User-confirmed additive step.**
- **M4 — Extract + graduate.** Pull the **format codec → its own lib** (2nd consumer is real); **graduate the importer/adapt → a Type-3 reference repo** (name chosen then). Re-point attn11 to consume the format lib.

---

## 5. Gates & sequencing

- **CPU-f64 first.** GPT-2-small import + LoRA need **no GPU** — M0–M2 open with **no GPU/mabda gate**; **sigil (satisfied — 3.9.9)** is the only external dep, and only for M0's signed header. (Not "nothing external-gated": sigil *is* an external dep, it just happens to be already available.) Larger checkpoints / quantized-scale want rosnet's **mabda GPU path** (gate C, mabda 4.x).
- **Transformer forward** dependency (see §2) — satisfied by **rupantara** (the forward lib; scaffolded, M1 forward ported, `ru_*`-namespaced). The **rupantara→attn11 re-fold** (attn11 consuming rupantara's CPU leaf ops) **landed for the leaf ops 2026-07-02** — `ln_fwd`/`gelu_fwd`/`attn_core_fwd`(causal) delegate to `ru_*`, and attn11's full **1049 grad-check suite is green in one binary** (the real parity proof, no offline compare). ⚠ **The re-fold is attn11-internal maintenance, NOT a Type-3 blocker** — anukūlana consumes `rupantara` **directly and never attn11**. What anukūlana's importer/fidelity gate actually needs is rupantara's forward being **correct/proven**; its *composition* ops (`ru_model_fwd` etc.) are now **cross-validated bit-identical** against attn11 (`test_rupantara_parity`, `diffs==0` / `maxrel=0`, 4 configs, attn11 1057 green) — so M1's fidelity gate can lean on `ru_model_fwd`. Do not gate the importer behind the attn11 delegation.
- **Cyrius has no module-private scoping + silently shadows duplicate `fn`s** (last-def-wins, warn-only) — the re-fold required renaming the **full 36-symbol collision surface** (8 public + 28 private), not just the ~9 public ops the earlier draft listed; `comm -12` vs attn11 must be **empty** before linking. Any future extract-and-re-fold must budget for the private-helper collisions too.
- **Feeds downstream:** the format is the load target for the **murti seam** ([`murti.md`](murti.md)) and the checkpoint store the **ifran control-plane port** writes — doing gap #1 first produces the shared model/checkpoint store both depend on.
- **Keep separate:** NF4 (here) ≠ tentib ternary QAT ([`integer-native-ml.md`](integer-native-ml.md)); rotation-PTQ (QuaRot/SpinQuant) + one-shot sparsity (SparseGPT/Wanda) stay distinct **research-watch**, not this cut.

---

## 6. References (port the converged shape, never copy)

- **safetensors** (HF) — typed-manifest + raw-payload + mmap format shape.
- **GGUF** (llama.cpp) — typed-KV metadata + tensor layout; the other import source.
- **nanoGPT `from_pretrained`** — the GPT-2 HF→layout tensor-name mapping reference.
- **LoRA** — Hu et al. 2021 (arXiv:2106.09685).
- **QLoRA / NF4** — Dettmers et al. 2023 (arXiv:2305.14314): NF4 + double-quant + paged optimizers.
- **Mined demand** ([`ml-product-mining.md`](ml-product-mining.md)): ifran/secureyeoman `BitsAndBytesConfig` (NF4 + double-quant + bf16) — the most-corroborated training demand; **evidence, not portable code** (both shell to Python).

---

## 7. Open decisions

1. ~~Homing~~ — **RESOLVED 2026-07-01: greenfield** (§2).
2. ~~Format-lib timing~~ — **RESOLVED: its own lib from the start** (greenfield → dependency-chain step 2).
3. ~~attn11→libs blocks extraction~~ — **RESOLVED: yes, it's the hard prerequisite** (dependency-chain step 1).
4. ~~Names~~ — **ALL RESOLVED 2026-07-01:** (a) transformer-blocks lib = **`rupantara`** (रूपान्तर), (b) weight-format lib = **`tula`** (तुला), (c) Type-3 reference repo = **`anukūlana`** (अनुकूलन).
5. **Per-repo go** — each scaffold (`mkdir`+Write, no git) needs an explicit go. **`tula` DONE (now 1.0.0, format frozen).** **`rupantara` scaffolded + M1 forward ported + attn11 leaf-op re-fold green (2026-07-02).** **`anukūlana` — M1 (consume tula) DONE 2026-07-02** (`inspect` opens/enumerates/verifies a tula checkpoint; 9 tests green, CLI verified). Open work is now *within* the repos, not new scaffolds: ✅ rupantara whole-forward parity PROVEN + ✅ rupantara M2 KV-cache decode DONE + ✅ anukūlana M1 tula-I/O DONE (all 2026-07-02); next = **anukūlana M2** — the foreign **safetensors** importer + map onto rupantara + logit-fidelity gate (the M1a sub-milestone above is the real effort, now unblocked since rupantara 0.4.0 shipped).

---

*Opened 2026-07-01 as gap #1 of [`software-port-path.md`](software-port-path.md). Source paradigm: [`generative-paradigms.md`](generative-paradigms.md) Type-3. Consumers of its output: [`murti.md`](murti.md) (load-seam), the ifran control-plane port (checkpoint store). Live substrate versions: rosnet 0.2.0, attn11 1.11.1, akshara 0.1.0, sigil 3.9.9 — verify against [`state.md`](../state.md).*
