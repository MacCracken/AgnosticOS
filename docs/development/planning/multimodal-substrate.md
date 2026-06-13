# Multimodal ML Substrate — Sight & Hearing on the attn11 Core

> Forward design + reference map for extending sovereign machine learning beyond text.
> **attn11** already proved that gradient-based learning of a transformer is expressible
> in everything-is-i64 Cyrius (hand-written forward + backprop + Adam on raw `f64` arrays,
> no BLAS / libc / autodiff, gradients gated by finite-difference checks). This doc plans
> what **vision** ("sight") and **audio** ("hearing") models add *on top of that core* — and
> collects the references to pull in when those items move forward.

| Field | Value |
|-------|-------|
| Status | Planning (forward design — not scaffolded) |
| Roadmap | Underpins Post-Beta **Phase 17** (local inference) + **Phase 18** (immersive communication); substrate is demand-gated |
| Trigger | attn11 reached **v1.0** → the attn11→libs extraction trigger has fired (see [`shared-crates.md`](shared-crates.md) *Planned*) |
| Gating new primitives | `conv2d`/`conv1d` fwd+bwd (learned); sovereign FFT/STFT + mel filterbank (fixed); cross-attention |
| Owns | nothing yet — this is a substrate map; lib names **deferred** per the attn11→libs naming decision (2026-06-08) |
| Created | 2026-06-13 |

---

## The reframe — why this is tractable

The instinct is to treat "vision model" and "audio model" as two from-scratch megaprojects. They aren't. **A transformer body — attention, MLP, LayerNorm, the optimizer, the finite-difference gradient gate — is identical across text, vision, and audio.** attn11 already carries all of it, and at the time of writing has grown well past a plain GPT: `ops.cyr` holds LayerNorm / GELU / dropout / softmax-xent fwd+bwd **and a Mixture-of-Experts fwd+bwd**; `attn.cyr` + `attn_linear.cyr` + `attn_ssm.cyr` hold full attention, linear attention, and a state-space model; with `tensor.cyr` / `train.cyr` / `persist.cyr` rounding out a real training surface.

What differs per modality is only:

1. **A frontend** that turns raw bytes (pixels / waveform) into a *sequence of `f64` embedding vectors*, and
2. **One or two new differentiable primitives.**

Everything downstream of "sequence of embedding vectors" is code attn11 already has. So the planning question is not *"how do we build a vision/audio model"* — it is *"what is the minimum new substrate each modality adds on top of attn11."* The answer is short.

**The integration contract, in one sentence:** *everything becomes a sequence of `f64` embedding vectors that the transformer attends over.* Vision and audio encoders project into attn11's embedding space; fusion is then just concatenating token streams and letting cross-attention mix them (the CLIP / Flamingo / LLaVA shape).

---

## Sight (vision)

Beyond what attn11 already has, sight needs:

| Need | New? | Notes |
|------|------|-------|
| **2D convolution, fwd + bwd** | **Yes — the main new gradient work** | The one genuinely new *learned* primitive. A pure ViT can skip it (non-overlapping patchify = reshape + matmul, which attn11 has via `tensor.cyr`); but CLIP-style conv stems and any CNN need `conv2d` with hand-derived grads — the direct analog of the attention backprop already done. `im2col` + matmul is the practical implementation path. |
| **Bidirectional attention** | Trivial | Drop attn11's causal mask. |
| **2D positional embeddings** | Minor | Extension of the existing 1D learned positional embed. |
| **Image-decode frontend** | Partly exists | **`kii`** already carries raster decoders (PNG / JPEG → pixel array). A model wants normalized `f64` tensors instead of quantized ANSI, but it's the same decode path — a candidate to lift into a shared lib rather than re-author. |
| Pooling (avg/max), if doing a CNN | Small | Straightforward fwd+bwd. |

**Sight proof-of-life** = a ViT (or small CNN) trained to classify a tiny image set (MNIST-class), loss descending, finite-difference-gated — the exact sibling of attn11's first char-LM loss curve.

**Naming note:** the Sanskrit `drishti` (दृष्टि — *sight, seeing*) is already reserved for the **video-codec family** (`drishti-av1`/`h264`/`h265`/`vpx`/`rav1e`), and `sadish`/`rekha` for vector graphics. A vision-*model* lib wants a sibling name, not those — selection deferred.

---

## Hearing (audio)

The elegant collapse: **a mel-spectrogram is an image.** Once you compute it, hearing largely reduces to *the sight stack applied to a time-frequency feature map.* So the genuinely new substrate is small:

| Need | New? | Notes |
|------|------|-------|
| **FFT / STFT + mel filterbank** | **Yes — the new DSP primitive** | Critically a **fixed feature extractor, not trained** → **no backprop through the FFT**, no new gradient derivation. abaco's [`dsp.cyr`](https://github.com/MacCracken/abaco) already has the groundwork (`window_hann`, batch math, dB conversions, `freq↔midi`); a real FFT/STFT + mel filterbank is the gating piece to confirm/build there. |
| **1D convolution, fwd + bwd** | Special case of conv2d | Whisper's stem is 1D conv over spectrogram frames. |
| **Cross-attention** | Yes (for ASR/seq2seq only) | Small generalization of attn11's self-attention: K/V come from a different source than Q. attn11 is decoder-only today; this is the one architectural addition, and it doubles as the **multimodal-fusion** primitive. |
| **Audio I/O frontend** | On roadmap | `vani` (PCM device I/O) / `shravan` (codecs); pipeline `vani(in) → shravan(decode) → dhvani(process)`. Synthesis side: `naad → dhvani → shravan → vani(out)`. |

Because the FFT/mel frontend is fixed, **hearing ≈ sight (conv + transformer over a 2D feature map) + an FFT feature extractor + (for ASR) attn11's autoregressive decoder via cross-attention.** Building the vision stack first largely buys the audio stack.

**Hearing proof-of-life** = a spoken-digit / keyword-spotting classifier on mel-spectrograms (`FFT → mel → conv/transformer → cross-entropy`). Full Whisper-style ASR is the magnum opus; the classifier is the equivalent of attn11's first loss curve.

**Naming note:** `shravan` / `shruti` (श्रवण / श्रुति — *hearing*) anchor the audio lane (codecs / device I/O). A hearing-*model* lib wants a sibling — deferred.

---

## The substrate that actually gates both

| Primitive | Sight | Hearing | Learned? (needs backprop) | Where it lives / would live |
|-----------|:-----:|:-------:|---------------------------|------------------------------|
| **Tensor core** (matmul + grad, transpose, elementwise, softmax, layernorm) | ✅ | ✅ | already extracting from attn11 (rosnet) | attn11→libs / rosnet |
| **conv2d / conv1d fwd + bwd** | ✅ | ✅ (1d stem) | **yes — main new gradient work** | new lib (name deferred) |
| **FFT / STFT + mel** | — | ✅ | **no** (fixed frontend — big simplification) | abaco `dsp.cyr` (extend) |
| **cross-attention** | (fusion) | ✅ (ASR) | yes — small generalization | attn11 / blocks lib |
| bidirectional attn + 2D pos-embed | ✅ | (via spectrogram) | trivial | attn11 variant |
| image decode → `f64` tensor | ✅ | — | n/a | `kii` decoders (lift to lib) |

The two real lifts are **convolution with hand-derived gradients** and **a sovereign FFT**. Everything else is attn11 reused or a trivial variant.

---

## Fusion endgame (true multimodal)

Once vision and audio encoders both emit *the same `f64` embedding-vector sequences* attn11's transformer already consumes, "multimodal" is just concatenating token streams and letting **cross-attention** fuse them — exactly the CLIP / Flamingo / LLaVA pattern. attn11 stays the text backbone; the vision and audio encoders project into its embedding space. There is no separate "multimodal architecture" to design — only encoders that speak attn11's embedding dialect, plus the cross-attention block (which the ASR path needs anyway).

---

## Suggested sequencing (planning only — no scaffolds)

1. **Finish the attn11→libs extraction** (rosnet tensor core + tyche PRNG + optimizer + grad-check harness + transformer blocks). Both modalities sit on it; it's already triggered by the v1.0 cut and runs inside attn11's 1.x line (the kashi/sandhi extract-and-re-fold pattern).
2. **conv2d + bwd → sight proof** (tiny ViT/CNN classifier). Cheapest next win, and it unlocks hearing too (spectrogram-as-image).
3. **Sovereign FFT/STFT + mel** in abaco `dsp.cyr`, in parallel — non-learned, so no gradient work.
4. **Cross-attention** — the gate for ASR *and* for real fusion. Comes when encoder-decoder is wanted, not before.
5. Vision/audio **proof-apps** ride the existing FB substrate (`blit`#39, landed agnos 1.43.4) — no desktop required, same proof-app pattern as DOOM / agora.

This is **demand-gated, post-beta** work. It is not on the closed-beta (boot-to-shell) or public-beta (self-hosting) critical paths. Do not scaffold ahead of need.

---

## References to pull in later

> **AGNOS method (per `feedback_redesign_dont_reinvent`):** solved-problem subsystems are *ported from multi-source prior art then redesigned to Cyrius conventions* — **no FFI, no C, no copied code.** The codebases below are **reference for understanding the converged shape**, never a dependency or a transliteration target. Triangulate, port the converged shape, gate with finite-difference checks (the attn11 discipline).

### Foundational papers

- **Transformer / cross-attention** — Vaswani et al., *Attention Is All You Need* (2017), arXiv:1706.03762. (Cross-attention = the encoder-decoder attention here.)
- **ViT** — Dosovitskiy et al., *An Image Is Worth 16×16 Words* (ICLR 2021), arXiv:2010.11929. (Patchify + transformer; the sight backbone.)
- **CLIP** — Radford et al., *Learning Transferable Visual Models From Natural Language Supervision* (2021), arXiv:2103.00020. (Vision encoder projected into a text-shared embedding space — the fusion contract.)
- **Whisper** — Radford et al., *Robust Speech Recognition via Large-Scale Weak Supervision* (2022), arXiv:2212.04356. (mel-spectrogram → 1D conv stem → transformer encoder + autoregressive text decoder — the ASR shape.)
- **AST** — Gong et al., *Audio Spectrogram Transformer* (2021), arXiv:2104.01778. (Spectrogram-as-image, ViT directly on mel — the "hearing ≈ sight" reduction, made literal.)
- **Conformer** — Gulati et al., *Convolution-augmented Transformer for Speech Recognition* (2020), arXiv:2005.08100. (conv + attention hybrid for audio.)
- **wav2vec 2.0** — Baevski et al. (2020), arXiv:2006.11477. (Self-supervised audio frontend, if labels are scarce.)
- **LLaVA** — Liu et al., *Visual Instruction Tuning* (2023), arXiv:2304.08485; **Flamingo** — Alayrac et al. (2022), arXiv:2204.14198. (Vision-encoder-into-LLM fusion via cross-attention / projection — the multimodal endgame.)
- **MoE** (already in attn11) — Shazeer et al., *Outrageously Large Neural Networks* (2017), arXiv:1701.06538; Fedus et al., *Switch Transformer* (2021), arXiv:2101.03961.

### Classic algorithms (no single paper — implement from the math)

- **FFT** — Cooley–Tukey radix-2 (1965); real-input FFT variants. Forward only (fixed frontend).
- **Mel filterbank / MFCC** — standard DSP; triangular filters on the mel scale over the STFT magnitude.
- **2D/1D convolution backprop + `im2col`** — standard; see Goodfellow/Bengio/Courville *Deep Learning* ch. 9, and the CS231n convolutional-networks notes for the fwd/bwd derivation.

### Minimal from-scratch implementation references (lineage of attn11)

- **karpathy/nanoGPT**, **karpathy/llm.c**, **karpathy/micrograd** — minimal, dependency-light transformer + autodiff references in the same spirit as attn11.
- **tinygrad** — minimalist autograd / op surface; useful for the conv fwd/bwd shape.
- **ggerganov/whisper.cpp** — C inference reference for the Whisper pipeline (mel → conv → transformer); read for the converged shape only.
- **ggml / llama.cpp** — tensor-lib reference (op set, memory layout) for the rosnet extraction.

### In-ecosystem (the pieces that already exist or are planned)

- **attn11** — the reference binary + `ops.cyr` / `tensor.cyr` / `attn.cyr` / `attn_linear.cyr` / `attn_ssm.cyr` / `train.cyr` / `persist.cyr`. The modality-agnostic core.
- **attn11→libs extraction** (rosnet tensor core, tyche PRNG, optimizers, grad-check harness, transformer blocks) — [`shared-crates.md`](shared-crates.md) *Planned*; trigger fired at attn11 v1.0.
- **abaco** [`src/dsp.cyr`](https://github.com/MacCracken/abaco) — DSP groundwork (windowing, batch math, dB/midi); FFT/STFT + mel to be added here.
- **kii** — image raster decoders (PNG/JPEG → pixel array); lift to a shared decode lib for the vision frontend.
- **vani / shravan / naad / dhvani / goonj / shruti** — audio device I/O, codecs, synth, engine, acoustics ([`shared-crates.md`](shared-crates.md) *Audio I/O*).
- **drishti-av1 / -h264 / -h265 / -vpx / -rav1e** — sovereign video codecs ([`shared-crates.md`](shared-crates.md) *Video Codec Projects*); sight-adjacent decode surface.
- **mabda** (GPU foundation) + **ai-hwaccel** (GPU detection) — the eventual hardware-acceleration path once correctness is proven on `f64` arrays.
- **hoosh** (LLM inference gateway), **murti** (model runtime), **daimon** (agent orchestrator), **mela** (agent marketplace) — downstream consumers of the multimodal models.

---

*See also: [`shared-crates.md`](shared-crates.md) (Audio I/O, Video Codec Projects, Planned), [`roadmap.md`](roadmap.md) (Post-Beta Phases 17–18), [`state.md`](../state.md) (live attn11 version / pin), and the attn11 repo (`MacCracken/attn11`).*
