# Type-3 "Pre-Trained" — Sovereign Weight Format + Importer + LoRA/QLoRA

> **Gap #1** of the ML/AI stack ([`software-port-path.md`](software-port-path.md)) — the highest-value unhomed ML capability. Promoted from the `generative-paradigms.md` **Type-3 "Pre-Trained"** section into its own opened planning doc.
>
> **Thesis:** *sovereign from the metal up **and** interoperable with the world's weights.* Run someone else's published checkpoint (GPT-2-small / TinyLlama-class) on AGNOS's own kernels, and adapt it (LoRA/QLoRA) — with **nothing borrowed** (no safetensors lib, no GGUF lib, no bitsandbytes, no PyTorch). The moment AGNOS produces correct logits from someone else's pretrained weights, the headline is real.

| Field | Value |
|-------|-------|
| Status | **M1 COMPLETE — a real foreign checkpoint runs on the sovereign stack AND matches HF exactly.** Chain shipped: **M0** `tula` **1.0.0** (format frozen) · forward lib `rupantara` **0.4.0** (whole forward + KV-cache decode; attn11 re-fold green + parity bit-identical) · **M1** `anukūlana` **0.3.0** imports a **real GPT-2-small safetensors** → maps onto rupantara → runs **clean** (config inferred V=50257/C=768/NL=12, 0 NaN in 123.6M widened params, batch fwd == KV-cache decode bit-identical, ~3.7s). Surfaced + fixed a real ecosystem bug on the way (`ganita` **1.0.2** `f64_tanh` NaN-overflow). Consumer `attn11` **1.12.0** delegates leaf ops to `ru_*`. **✅ The exact HF-fidelity gate CLOSED 2026-07-04** — `gpt2-oracle` vs a **committed HF-logits fixture** (torch ran once in a disposable venv; never a dependency): argmax exact at all 48 positions, last-row maxrel 1.05e-6, gate frozen at 1e-5. **✅ M2 (LoRA) + M3 (QLoRA/NF4) BOTH SHIPPED in anukūlana 0.4.0 (2026-07-04)** — FD-gated adapter over the frozen base (head scope, user-accepted; 8/8) and the NF4 codec + end-to-end QLoRA (124M base at 4 bits, adapter recovers 8/8, codes bit-frozen). **The Type-3 charter (format + import + fidelity + adapt + persist) is FULLY BUILT — anukūlana 0.5.0 (2026-07-04)** shipped the persistence tail: signed NF4 checkpoint (63.8 MB) + adapter (3.3 MB) via tula, **bit-identical round-trips**, Ed25519 tamper/wrong-key rejection; the base NF4 codec was reconciled to **delegate to tula's shipped codec** (only superblock-256 double-quant stays local). **anukūlana shipped 1.0.0 STABLE 2026-07-04** — API frozen (api.md/STABILITY), parsers fuzz-gated (2 audit DoS fixes in `st_open`), SECURITY.md + benchmarks. **The post-1.0 GGUF headline SHIPPED as anukūlana 1.1.0 (2026-07-05)**: sovereign GGUF v2/v3 parser + GPT-2 `blk.N.*` mapping; `gpt2-gguf` PASS on the real checkpoint and the **`gpt2-cross` cross-format gate — safetensors and GGUF doors bit-identical** (123.6M params / 402k logits, 0 diffs); 35k fuzz rounds in the same cut. **This planning doc's work is DONE** — the remaining additive lanes (quantized GGML payloads, llama-arch mapping) live in anukūlana's roadmap. |
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

- **M0 — Format codec. ✅ DONE** (`tula` 1.0.0, format v1 FROZEN — 105 assertions + 2M-iter fuzz + security audit). Sovereign weight-file format (manifest + payload + sigil-signed header); round-trips a checkpoint bit-identical; sigil verify rejects tampering.
- **M1 — Importer + fidelity gate. ✅ COMPLETE** (`anukūlana` 0.3.0, cut 2026-07-04). Parses a real **GPT-2-small safetensors** (bayan JSON DOM header + IEEE-754 fp32/fp16/bf16→f64 widen), maps onto rupantara's layout (fused-QKV split, no transpose — rosnet `linear_fwd` is `[in,out]` `y=x@W`, same as GPT-2 Conv1D), runs `ru_model_fwd`, and produces **finite logits** on the real 124M checkpoint (config inferred, 0 NaN params, batch fwd == KV-cache decode bit-identical). CPU-f64, no GPU. **✅ The exact HF-logit match landed 2026-07-04** as `gpt2-oracle` + a **committed reference fixture** (`tests/fixtures/gpt2_oracle_v1.bin`: 3 deterministic 16-token sequences → HF per-position argmax + last-position logits, generated once by `tests/oracle/gen_fixture.py` in a **disposable torch venv** — Python/torch is data-provenance, never a dependency). Result: **argmax identical at all 48 positions; last-row maxrel 1.05e-6** (= HF's own fp32 rounding vs our f64 over the same widened weights); gate frozen at maxrel ≤ 1e-5 + exact argmax + NaN-free. `make fidelity`.
  - ✅ **M1a — the foreign parser + name-mapping (the largest net-new effort) is DONE and hardened.** `anukūlana/src/safetensors.cyr` — a from-scratch safetensors parser over **untrusted foreign input** (header-length bounds-checked, every tensor's `data_offsets` validated within the buffer, malformed/truncated/overrun → clean reject, `__metadata__` skipped; 548 MB file mmap'd zero-copy to beat the 256 MB alloc cap) + `src/gpt2.cyr` the GPT-2→rupantara mapping. GGUF is a later source (not this cut).
- **M2 — LoRA. ▶ BITE 1 LANDED 2026-07-04** (anukūlana `[Unreleased]`). The primitive set (`lora_fwd`/`lora_bwd` = two rosnet `linear_bwd` passes, `lora_merge`, xent, SGD + hand-derived **Adam**) with the **FD gate on every dA/dB entry** (rel < 1e-5), plus `gpt2-lora`: a **head adapter fine-tunes the real imported GPT-2** — xent 10.79 → 0.0000, greedy argmax 1/8 → 8/8, the 124M base bit-frozen, adapter-off logits bit-identical (the fidelity gate holds with the adapter off). Two findings: **plain SGD diverges on real-GPT-2 features** (massive-activation outlier dims — the ganita-tanh phenomenon again — make `dA` explode at any flat lr; Adam per-param scaling is the remedy, as in the paper); the head adapter stays **unmerged** (tied tok_emb). **Open scope question:** deeper per-layer adapters (paper's q/v) need a backward chain through the network tail — attn11's territory; accept head-scope → M3, or hand-derive a minimal tail-chain (user call, see anukūlana roadmap).
- **M3 — QLoRA / NF4. ✅ CORE COMPLETE 2026-07-04** (user-confirmed at the LoRA close; anukūlana `[Unreleased]`). The sovereign NF4 codec (`src/nf4.cyr`: 16 NormalFloat quantiles cited from the paper's converged table, blockwise-64 absmax, 2-codes-per-byte, **double-quantized scales** — symmetric-u8 variant of FP8+offset, documented) with an 8-test exactness gate (round-trip ≤ max-half-gap × absmax on every element — the largest quantile gap is the *negative* side's; requant idempotent; double-quant bounded). `gpt2-qlora` runs the thesis end-to-end on the real checkpoint: the whole 124M base at 4 bits (989 MB → ~62 MB codes + ~15.5 MB scale bytes), **adapter recovers the task 8/8 over the frozen NF4 base, codes bit-frozen, 0 NaN**. Honest 124M-scale finding: the raw 4-bit forward drifts (base argmax 0/8 vs f64 on arbitrary-token probes) — the paper's near-lossless claims live at larger scale; the gated thesis is **trainability at 4-bit memory**, which holds. **✅ Follow-on SHIPPED (anukūlana 0.5.0):** signed NF4 checkpoints + adapter save/load via tula — bit-identical round-trips, trust boundary gated (tamper/wrong-key rejected); the base codec now **delegates to tula's shipped NF4** (the hand-rolled duplicate was reconciled away — only superblock-256 double-quant stays anukūlana-local).
- **M4 — Extract + graduate. ✅ ALREADY GREENFIELD** (2026-07-01 decision superseded prototype-in-attn11). The format lib (`tula`) and the Type-3 reference repo (`anukūlana`) were stood up as their own repos from the start; attn11 already consumes the forward lib (`rupantara`). No extraction step remains.

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
5. **Per-repo go** — each scaffold (`mkdir`+Write, no git) needs an explicit go. All three repos are stood up and shipping: **`tula` 1.0.0** (format frozen), **`rupantara` 0.4.0** (whole forward + KV-cache decode; attn11 re-fold green + parity bit-identical), **`anukūlana` 0.3.0** (real GPT-2-small imports + runs clean; **exact-fidelity gate closed + cut 2026-07-04**). Open work is now *within* `anukūlana`, not new scaffolds: **M2 LoRA** → M3 QLoRA/NF4. No further extraction (greenfield already, decision #4 above).

---

*Opened 2026-07-01 as gap #1 of [`software-port-path.md`](software-port-path.md). Source paradigm: [`generative-paradigms.md`](generative-paradigms.md) Type-3. Consumers of its output: [`murti.md`](murti.md) (load-seam), the ifran control-plane port (checkpoint store). Chain versions (2026-07-04): tula 1.0.0, rupantara 0.4.0, anukūlana **1.0.0 STABLE**; substrate rosnet **1.0.0** (frozen 2026-07-04), attn11 1.12.0, akshara 0.1.0, sigil 3.9.9, ganita 1.0.2 — verify against [`state.md`](../state.md).*
