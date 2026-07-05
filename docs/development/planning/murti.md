# Murti — Sovereign Model-Loading & Inference-Dispatch Seam

> **Murti** (Sanskrit: मूर्ति — *form, embodiment, the manifest image of the formless*) — the seam that takes a **weight file at rest** and gives it a running **form**: load a sovereign weight file, place it on the right hardware, dispatch the forward pass to the sovereign inference kernels, and hold the resident-model lifecycle. The *embodiment* layer between a stored model and a served answer.

| Field | Value |
|-------|-------|
| Status | **Re-architected planning doc (Cyrius-native), 2026-07-01. Supersedes the 2026-03-24 Rust-era draft in full.** Not scaffolded. |
| Repo existence | **OPEN QUESTION** — see §0. The *capability* is real; whether it earns a *separate repo* (vs living permanently inside hoosh) is gated on a real second consumer. |
| Priority | Deferred / demand-gated — opens (if at all) only after the Type-3 weight importer exists **and** a real second consumer of the load↔dispatch path appears. |
| Name | `murti` (मूर्ति) — kept as a **reserved** name in the Sanskrit/Hindi system-lib lane; reserving the name does **not** commit to the repo existing. |
| Runtime | Cyrius library, no HTTP server, no daemon (serving is hoosh's). |
| Domain | weight-file load → placement query → **dispatch** to rosnet/tentib → hand logits to hoosh. **Not** training, **not** serving, **not** GPU primitives, **not** the marketplace, **not** the foreign-engine compat seam. |

---

## 0. The decision (read this first)

**The Rust-era murti is dead. The concept that replaces it is a thin seam, and whether that seam is ever a separate repo is deliberately left open.**

The Rust-era murti's entire value proposition was **being a broker for 15 external inference backends** (llama.cpp, vLLM, TensorRT, Metal, Vulkan, ONNX, TPU, Gaudi, Inferentia, OneAPI, Qualcomm, XDNA, Candle, Ollama). In March 2026 that was the only way AGNOS could run a real model, so a backend broker *was* the runtime. As of 2026-07-01 that premise is dead: AGNOS runs local inference on its **own** kernels —

- **rosnet 1.0.0** (frozen 2026-07-04) — f64 tensors + hand-derived matmul gradient, plus a **mabda-gated `[lib.gpu]` GPU profile**. The f64 forward path.
- **tentib 0.4.0** — a **matmul-free integer inference kernel** (ternary weights, int8 activations, add/sub/skip), whole-model parity < 1e-9 vs f64. The integer forward path. *(Correctness-ready today; useful throughput is gated on cyrius integer-SIMD — see §3.)*
- **The Type-3 importer** (`generative-paradigms.md`) — a **sovereign weight-file format** + a real-checkpoint importer + LoRA/QLoRA. How someone else's pretrained weights become a sovereign model AGNOS can run.
- **hoosh 2.4.11** — the OpenAI-compatible serving / routing / budget plane.

A "runtime whose job is to shell to llama.cpp" is now the **exact opposite** of the sovereign-ML thesis. The broker dies. What is left is a genuinely-new but *thin* seam nobody owns cleanly:

> **The load↔place↔dispatch↔pool seam:** given a sovereign weight file, validate + mmap it (via sigil + the Type-3 importer), ask ai-hwaccel/mabda where it should live, dispatch the forward pass to the correct sovereign kernel (rosnet-f64 or tentib-integer), and hold the resident-model pool (VRAM-budget eviction, idle-unload, LoRA adapter hot-swap). Return logits to hoosh.

### Does this seam earn a separate repo? — OPEN QUESTION, deferred

Both the "collapse it into hoosh" and "extract it as murti" positions are defensible, and the honest posture is to **not decide yet**:

- **Case for collapsing into hoosh (the default today):** the seam is thin — load (Type-3 importer) + run (rosnet/tentib) + place (ai-hwaccel). hoosh already owns routing, budgets, cloud-fallback, and per-agent accounting; resident-model residency policy is *of a piece* with serving-side resource policy, not a foreign concern. The arithmetic dispatch fork (rosnet-f64 vs tentib-integer) is, today, **one branch on a manifest field** — a branch is not a subsystem. And the second-consumer trigger is **not yet satisfied**: hoosh is the only *live* consumer of local inference. A forecast that ifran-control-plane will later need the same path is not a second consumer — it is scaffolding-ahead-of-need until real code needs it.
- **Case for extracting murti later:** the resident-model *state* (which models on which device, VRAM-budget LRU eviction, crash-reload, adapter hot-swap) is genuine stateful runtime coordination that rosnet (stateless tensor lib), tentib (a kernel), and the Type-3 importer (a codec) do not hold. If that state grows, and if a **second live consumer** needs the load↔dispatch path *without going through hoosh* (the ifran-control-plane's post-train "load the checkpoint I just produced and eval it" is the expected trigger), the seam earns extraction — exactly the `yo`+`dig`→`taar` pattern.

**Decision: hoosh's local-inference provider IS the murti prototype.** Build the seam inside hoosh's local path first. Do **not** scaffold a murti repo. Extraction becomes a live question only when (a) the Type-3 importer exists (murti has nothing to load until then) **and** (b) a real second consumer with running code needs the seam independently of hoosh. Until both hold, "murti survives as a repo" is an open question, not a plan.

---

## 1. What the seam owns vs must NOT own

### The seam (whether it lives in hoosh or, later, in murti)

```
   sovereign weight file (Type-3 format, sigil-signed header)
              │
              ▼
   ┌────────────────────────────────────────────────┐
   │        load↔place↔dispatch↔pool seam            │
   │                                                  │
   │  load    — validate magic + sigil signature,     │
   │            mmap payload, drive the Type-3         │
   │            importer, hold tensor handles         │
   │  place   — ask ai-hwaccel: devices / VRAM / plan;│
   │            ask mabda for GPU buffers when needed  │
   │  dispatch— fork on declared arithmetic:          │
   │              f64 model     → rosnet forward       │
   │              ternary model → tentib kernel        │
   │  pool    — resident-model registry, VRAM-budget   │
   │            LRU eviction, idle-unload, LoRA swap    │
   └────────────────────────────────────────────────┘
              │
              ▼
        logits / token stream  ──►  hoosh (serving, routing, budgets, cloud fallback)
```

1. **Load** — validate the sovereign weight file (magic + **sigil**-verified signed header = the trust boundary), mmap the payload, drive the Type-3 importer to map tensor names onto the model layout, hold the live tensor handles. The seam *calls* the importer; it does not *own* the format spec (that is Type-3's).
2. **Place** — query **ai-hwaccel** for the device/VRAM/placement plan and **mabda** for concrete GPU allocations. The seam *consumes* placement intelligence; it does not *compute* it.
3. **Dispatch** — the arithmetic fork: route the forward pass to **rosnet** (f64) or **tentib** (ternary/integer) based on the weight file's declared kind + the placement plan. Today a branch; a subsystem only if it grows.
4. **Pool** — the resident-model lifecycle: which models are loaded where, VRAM-budget LRU eviction, idle-timeout unload, crash-reload, and **LoRA adapter hot-swap** over a resident base (adapter *construction* is Type-3's; live *swap* is this seam's).

### What the seam must NOT own

| Concern | Owner | Why not here |
|---|---|---|
| **Training** (SFT, LoRA/QLoRA *fit*, DPO/RLHF, distillation, pretrain) | attn11 / tarka / prajna / tentib (math) + **ifran-control-plane** (orchestration) | The seam runs a finished weight file; it never computes a gradient. |
| **Weight-file format spec + importer + NF4/LoRA construction** | **Type-3 "Pre-Trained" reference** (`generative-paradigms.md`) | The seam *consumes* the codec; owning the format couples the engine to the paradigm. |
| **Serving API** (OpenAI-compat, streaming, routing, caching, rate-limit, budgets, per-agent accounting, cloud fallback) | **hoosh 2.4.11** | Already shipped. The seam returns logits/tokens; hoosh makes a served product. No HTTP here. |
| **Marketplace** (publish/discover/sign models) | **mela 1.0.1** | Distribution ≠ execution. |
| **GPU primitives** (kernels, buffers, GFX9/wgpu) | **mabda 3.4.5** | The seam asks mabda for buffers/kernels; never writes a GPU kernel. |
| **Accelerator detection + placement planning** | **ai-hwaccel 2.3.12** | The seam consumes the plan. The Rust `GpuAllocator`'s VRAM-query/layer-split logic moves out to ai-hwaccel. |
| **Model / checkpoint store** (content-addressable blobs, index, dedup, eviction) | **ifran-control-plane** (writes checkpoints) with container = **vahana/sankoch**, hashing = **sigil** | A *stateful store* is a different artifact from the *codec* (Type-3) — do not fold the store into the format. The seam *loads what is on disk*; it is not the store. |
| **The foreign GGUF/llama.cpp path** | **mehman** (foreign surfaces sandboxed in **kavach**, the swallow/compat stage) | **Load-bearing doctrine call:** a model AGNOS cannot import sovereignly is a **mehman/compat concern reached *around* this seam, never *through* it.** The seam dispatches ONLY to sovereign kernels (rosnet/tentib). The moment it spawns a llama.cpp path it is a broker again — the very thing being killed. |
| **Lineage / provenance** | **itihas** (via ifran-control-plane) | Runtime dispatch is not provenance. |
| **Fleet / edge model distribution** | **seema** (fleet) + **daimon** (edge orchestration) | Pushing weights across a fleet is distribution, not local embodiment. The Rust `murti::fleet` module is removed. |
| **The 14 other external backends** (vLLM/TensorRT/Metal/TPU/Gaudi/…) | **Deleted.** | Rust-era hardware-vendor coupling the sovereign kernels + mabda now cover natively. |

**The polarity inversion in one line:** the Rust murti's public API centered on `pull()` / `import_ollama()` / `quantize()` (acquisition + format-wrangling); the sovereign seam centers on `load()` / `dispatch()` / `pool` (embodiment). Acquisition and format move to Type-3; the foreign path moves to mehman; only *making a loaded sovereign model run* stays.

---

## 2. Revised Cyrius dependency set

No Cargo. No reqwest / tokio / serde / thiserror / tracing / chrono / sha2 / blake3 crates. No feature-gated backend zoo. **No kavach** — because the seam does not host the foreign path (that is mehman's), it spawns no sandboxed foreign process and needs no sandbox dependency.

| Cyrius dep | Role | Replaces (Rust-era) |
|---|---|---|
| **rosnet** | f64 tensor forward path (default dispatch target); GPU forward via its mabda-gated `[lib.gpu]` profile | the entire `backends/` f64 story (Candle, direct-GGUF f32) |
| **tentib** | matmul-free **integer** forward path (ternary / int8) — correctness-ready; throughput gated on cyrius int-SIMD | — (no Rust-era equivalent) |
| **ai-hwaccel** | device enumeration, VRAM query, placement plan | Rust `ai-hwaccel` + absorbs murti's old `GpuAllocator` split logic |
| **mabda** | GPU buffers/kernels behind ai-hwaccel's plan | the CUDA/ROCm/Vulkan/Metal FFI backends (all deleted) |
| **sigil** | verify the signed weight-file header (trust boundary at load) | `sha2` + `blake3` crates |
| **sandhi** | any socket/HTTP a fetch needs (transport only) | `reqwest` + `tokio` net |
| **akshara** | tokenizer handle passed through to the dispatched forward | — |
| **chitra** | image decode when a loaded model is multimodal (future, gated on multimodal) | — |
| **sakshi** | structured runtime logging | `tracing` |
| **CYML** (`cyrius.cyml`) | model config + manifest parsing | `serde` + `toml` |

**Type-3 importer coupling** is at the ABI/contract level (the seam calls "importer, give me tensor handles from this mmap"), never by vendoring the codec — monolithic-by-design. While the codec is not yet its own extracted lib, the seam and the importer may co-live in the Type-3 reference.

---

## 3. Phased roadmap (prototype-in-hoosh first)

Every milestone is CPU-f64-first (no GPU gate) except where noted, mirroring the sibling discipline. **Nothing opens before the Type-3 importer exists**, and the early milestones live **inside hoosh's local-inference provider**, not a murti repo.

- **M0 — Load & validate (in hoosh's local provider).** Read a sovereign weight file: validate magic, verify the sigil-signed header (reject unsigned/tampered), mmap the payload, drive the Type-3 importer, hold tensor handles. Prove a loaded model round-trips to correct logits via rosnet on a tiny attn11-class checkpoint. *This is also the inference path the Type-3 importer needs to prove itself — it is a **precondition** of the importer test, not a downstream phase.*
- **M1 — Dispatch fork.** Read the weight file's declared arithmetic; route f64 → rosnet, ternary → tentib. Prove both paths return correct logits, selected automatically. **Gate:** tentib's kernel is *correctness*-ready now but *throughput*-gated on the cyrius integer-SIMD proposal (toolchain is f64-only, 2-wide SSE2) — the ternary path is a correct-logits target immediately, a fast target only once int-SIMD lands.
- **M2 — Placement query.** Consume ai-hwaccel's plan; when GPU-resident, obtain buffers from mabda and run rosnet's `[lib.gpu]` forward. CPU-only when no accelerator. *GPU branch gated on mabda 3.x + rosnet GPU path; the CPU branch ships regardless.*
- **M3 — The pool (resident lifecycle).** Multi-model residency registry, VRAM-budget LRU eviction, idle-unload, crash-reload. **This is the extraction checkpoint:** if a real second consumer (ifran-control-plane's post-train eval-load) now drives this path independently of hoosh, *this* is where murti becomes its own repo. If not, it stays in hoosh.
- **M4 — LoRA adapter hot-swap.** Swap a Type-3-produced adapter over a resident base without reloading the base.
- **M5+ (research-watch, demand-gated).** Activation-sparsity / hot-cold split as a *third dispatch target* (co-optimized with ai-hwaccel NUMA + mabda pinning) — **re-scoped** from the Rust doc's PowerInfer/llama.cpp-fork framing to the sovereign kernels; dequant-on-the-fly for imported int4/int8; multimodal input decode via chitra. All demand-gated, held to sibling discipline.

> **Note:** the Rust doc's M5 "spawn a foreign GGUF/llama.cpp runner" is **deleted**. The foreign path is mehman's, reached around this seam, never through it.

---

## 4. What changed vs the Rust-era doc

| Rust-era murti (2026-03-24) | Sovereign seam (this doc) |
|---|---|
| **Value prop = broker for 15 external backends.** | **Value prop = the load↔place↔dispatch↔pool seam over the *sovereign* kernels** (rosnet-f64, tentib-integer). The 15 backends are deleted; the foreign path moves to mehman. |
| A committed Priority-1 crate, "scaffolded 0.1.0," extract-from-ifran-now. | **Repo existence is an OPEN QUESTION.** Prototype lives in hoosh's local provider; extraction is second-consumer-gated behind the Type-3 importer. Do not scaffold. |
| Extract engine **from ifran-core / ifran-backends** (a Rust refactor). | **Greenfield Cyrius seam.** Nothing is "extracted from ifran"; ifran becomes the *training control plane*, not the seam's parent. |
| Owned `pull` / `PullManager` / HTTP downloads (reqwest+tokio). | **No acquisition.** Fetch (if any) routes to Type-3 / vahana / sankoch via **sandhi**. Loads what is on disk. |
| Owned `quantize` (15 GGUF levels) + `OllamaCompat` + `import_ollama`. | **Removed.** Import-quant (NF4/QLoRA) is Type-3; train-to-integer is tentib; Ollama/GGUF import is **mehman's** compat seam, not here. |
| Owned `GpuAllocator` (VRAM query + layer split). | **Moved to ai-hwaccel.** The seam keeps only *residency bookkeeping* (the pool). |
| Owned `murti::fleet`. | **Removed** — fleet is **seema** + **daimon**. |
| Owned the model store (`ModelStore`, content-addressable blobs). | **Moved.** The stateful store is the control-plane's (container vahana/sankoch, hashing sigil); the seam is not a store. |
| `sha2` + `blake3` for integrity. | **sigil** verifies the signed header. |
| Foreign-engine compat seam owned by murti (spawn llama.cpp in a sandbox). | **Owned by mehman** (kavach-sandboxed), reached *around* the seam — never inside it. `kavach` drops from the dependency set. |
| Sandbox via **agnosys**. | N/A (no foreign process here); sandboxing of the foreign path is mehman/kavach's. |
| Deps: reqwest, tokio, serde, toml, sha2, blake3, chrono, tracing, thiserror + 14 backend SDKs. | Deps: rosnet, tentib, ai-hwaccel, mabda, sigil, sandhi, akshara, chitra, sakshi, CYML. **Zero external crates, zero vendor SDKs, zero foreign engines.** |
| Model config = **TOML**. | Model config = **CYML**. |
| Consumers: **hoosh + Irfan** share murti; Irfan owns training. | Consumers: **hoosh (serving)** is the sole live consumer and the prototype host; **ifran-control-plane** is the *projected* second consumer that would justify extraction; the sovereign siblings + ifran own training; mela owns marketplace. |
| "Ollama replacement" framing. | **Sovereignty framing:** run inference on kernels AGNOS owns from the metal up. Foreign paths are mehman's sandboxed compat courtesy, not the product. |
| Name `murti` (मूर्ति) = "runtime broker." | **Name kept but reserved**, re-anchored to *embodiment* (weight-file-at-rest → running form). Reserving the name ≠ committing to the repo. |

---

## 5. Open questions (surface, don't decide)

1. **Does the seam ever earn a separate murti repo, or live in hoosh permanently?** Deferred until (a) the Type-3 importer exists and (b) a real second consumer needs the load↔dispatch path independently of hoosh. Today: prototype in hoosh.
2. **Is the model/checkpoint store the control-plane's, or its own thing?** This doc homes it to the control plane (container vahana/sankoch, hashing sigil); confirm when the control-plane port opens (see the audit's ifran section).
3. **Name vs repo:** `murti` is reserved in the naming registry; it does not obligate a repo to exist.

---

*Re-architected 2026-07-01 onto the sovereign Cyrius substrate; supersedes the 2026-03-24 Rust-era draft. Sovereign-core primary, foreign path to mehman (never here), sibling-not-chain, second-consumer extraction, demand-gated. Live substrate versions: rosnet 1.0.0 (frozen), tentib 0.4.0, ai-hwaccel 2.3.12, mabda 4.0.x (providers: AMD GFX9 + basic NVIDIA), hoosh 2.4.11, mela 1.0.1 — verify against [`state.md`](../state.md).*
