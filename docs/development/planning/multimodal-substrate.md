# Multimodal ML Substrate — Sight & Hearing on the attn11 Core

> Forward design + reference map for extending sovereign machine learning beyond text.
> **attn11** already proved that gradient-based learning of a transformer is expressible
> in everything-is-i64 Cyrius (hand-written forward + backprop + Adam on raw `f64` arrays,
> no BLAS / libc / autodiff, gradients gated by finite-difference checks). This doc plans
> what **vision** ("sight") and **audio** ("hearing") models add *on top of that core* — and
> collects the references to pull in when those items move forward.

| Field | Value |
|-------|-------|
| Status | Planning (forward design — not scaffolded). **Refreshed 2026-07-04:** two of the original gating lifts have since landed elsewhere — the transformer-blocks extraction (→ **rupantara** 0.4.0, attn11 re-fold green) and the sovereign FFT (**hisab** ships FFT/DST/DCT/2D-FFT; shravan `fft.cyr`, naad `dsp_spectral.cyr`). **conv2d/conv1d LANDED 2026-07-05** (**rosnet 1.1.0**, released 2026-07-05: NCHW, per-axis stride/pad, hand-derived FD-gated gradients) — **the modality axis is now SUBSTRATE-COMPLETE**: decode (chitra) + FFT (hisab) + transformer (rupantara) + tokenizer (akshara) + conv (rosnet 1.1). **The SIGHT PROOF-OF-LIFE PASSED 2026-07-05, shipped as attn11 1.13.0** (user-homed as an **attn11 vision lane**, `src/vision.cyr` + `--vision`): a small CNN (rosnet conv2d + attn11 gelu/xent + Adam, strided-conv downsampling) on a synthetic sovereign shape set — **loss 1.377→0.0012, held-out 1000/1000**, end-to-end backward FD-gated 23/23, suite 1049→1060. **The HEARING PROOF-OF-LIFE PASSED 2026-07-07, landed as an attn11 hearing lane** (`src/hearing.cyr` + `--hearing`, sight-symmetric homing; cut pending): the "mel-spectrogram IS an image" reduction made literal — the STFT is sized **16 frames × 16 mel bands = the vision 16×16 canvas** (Hann STFT via **hisab `num_fft`** `[deps.hisab]` + a fixed 16-band mel filterbank, NOT trained — the plan's no-backprop-through-the-FFT simplification held) so the vision CNN + FD gates apply verbatim; 4 synthetic keyword-spotting-like classes (chirps up/down, two-tone syllable pair, harmonic stack; tyche-jittered + noise) — **loss 1.6713→0.0000, held-out 1000/1000**, assembled backward FD-gated 23/23, frontend gated tone→band without gradients, suite 1060→1066. The STFT+mel glue is lane-local (extraction to hisab/abaco on a second consumer, per the standing trigger). Remaining consumer work: **cross-attention** (the ASR/seq2seq + fusion gate — the last unopened item on this map), then real audio I/O via vani/shravan when "talking back and forth" wires up (the speaking half already exists: naad/goonj synthesis → vani, which plays on agnos). |
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
| **Image-decode frontend** | **✅ Exists — `chitra`** | The lift already happened: **chitra** (चित्र, 0.3.0) is the shared pure-Cyrius raster decoder (PNG all bit depths + Adam7; baseline JFIF JPEG grayscale/YCbCr, 4:4:4/4:2:2/4:2:0 + restarts → canonical RGBA8), extracted from kii's decoders — kii + mabda both consume it. The vision frontend only adds the trivial RGBA8 → normalized `f64` tensor conversion. |
| Pooling (avg/max), if doing a CNN | Small | Straightforward fwd+bwd. |

**Sight proof-of-life** = a ViT (or small CNN) trained to classify a tiny image set (MNIST-class), loss descending, finite-difference-gated — the exact sibling of attn11's first char-LM loss curve.

**Naming note:** the Sanskrit `drishti` (दृष्टि — *sight, seeing*) is already reserved for the **video-codec family** (`drishti-av1`/`h264`/`h265`/`vpx`/`rav1e`), and `sadish`/`rekha` for vector graphics. A vision-*model* lib wants a sibling name, not those — selection deferred.

---

## Hearing (audio)

The elegant collapse: **a mel-spectrogram is an image.** Once you compute it, hearing largely reduces to *the sight stack applied to a time-frequency feature map.* So the genuinely new substrate is small:

| Need | New? | Notes |
|------|------|-------|
| **FFT / STFT + mel filterbank** | **Mostly landed** (2026-07 refresh) | Critically a **fixed feature extractor, not trained** → **no backprop through the FFT**, no new gradient derivation. **Sovereign FFTs now exist:** [hisab](https://github.com/MacCracken/hisab) ships FFT/DST/DCT/2D-FFT as a registered lib; shravan carries `src/fft.cyr` (+ MDCT) and naad's Cyrius port landed `dsp_spectral.cyr`. abaco's [`dsp.cyr`](https://github.com/MacCracken/abaco) holds the windowing/dB/midi groundwork. Remaining: only the **STFT framing + mel filterbank glue** over an existing FFT. |
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
| **Tensor core** (matmul + grad, transpose, elementwise, softmax, layernorm) | ✅ | ✅ | **extracted** (rosnet 0.2.0) | rosnet |
| **conv2d / conv1d fwd + bwd** | ✅ | ✅ (1d stem) | **✅ LANDED** (rosnet 1.1, 2026-07-05 — FD-gated, per-axis stride/pad) | **rosnet** `src/conv.cyr` |
| **FFT / STFT + mel** | — | ✅ | **no** (fixed frontend — big simplification) | **FFT landed** (hisab; also shravan/naad); STFT+mel glue remains |
| **cross-attention** | (fusion) | ✅ (ASR) | yes — small generalization | attn11 / **rupantara** (the extracted blocks lib) |
| bidirectional attn + 2D pos-embed | ✅ | (via spectrogram) | trivial | attn11 variant |
| image decode → `f64` tensor | ✅ | — | n/a | **`chitra`** (shared decode lib, landed; + a trivial RGBA8→f64 normalize) |

The two real lifts *were* **convolution with hand-derived gradients** and **a sovereign FFT** — the FFT has since landed (hisab, 2026-07 refresh), so **the one remaining lift is convolution fwd+bwd**. Everything else is attn11/rupantara reused or a trivial variant.

---

## Fusion endgame (true multimodal)

Once vision and audio encoders both emit *the same `f64` embedding-vector sequences* attn11's transformer already consumes, "multimodal" is just concatenating token streams and letting **cross-attention** fuse them — exactly the CLIP / Flamingo / LLaVA pattern. attn11 stays the text backbone; the vision and audio encoders project into its embedding space. There is no separate "multimodal architecture" to design — only encoders that speak attn11's embedding dialect, plus the cross-attention block (which the ASR path needs anyway).

---

## Suggested sequencing (planning only — no scaffolds)

1. ~~**Finish the attn11→libs extraction**~~ — **✅ DONE**: rosnet (tensor core) + tyche (PRNG) extracted, and the transformer blocks shipped as **rupantara** 0.4.0 (whole-forward parity bit-identical vs attn11, re-fold green — the kashi/sandhi extract-and-re-fold pattern, completed 2026-07-02).
2. ~~**conv2d + bwd**~~ — **✅ LANDED in rosnet** (2026-07-05: conv2d + conv1d, per-axis stride/pad, hand-derived dx/dW/db FD-gated incl. strided/padded/non-square, conv1d bit-parity; benched ~1.1 G MAC/s). Shared with Type-4 diffusion as planned. **The sight proof (tiny ViT/CNN classifier) is now fully unblocked** — the axis's next opener when a consumer/flex moment pulls it.
3. ~~**Sovereign FFT**~~ — **✅ landed** (hisab FFT/DST/DCT/2D-FFT; shravan/naad carry their own). Remaining: **STFT framing + mel filterbank** glue — non-learned, no gradient work.
4. **Cross-attention** — the gate for ASR *and* for real fusion. Comes when encoder-decoder is wanted, not before.
5. Vision/audio **proof-apps** ride the existing FB substrate (`blit`#39, landed agnos 1.43.4) — no desktop required, same proof-app pattern as DOOM / agora.

This is **demand-gated, post-beta** work. It is not on the closed-beta (boot-to-shell) or public-beta (self-hosting) critical paths. Do not scaffold ahead of need.

**Runs-on-agnos gate: the kernel FP/SIMD arc** (agnos `docs/development/planning/kernel-fp-arc-153x.md`, slotted 1.53.x) — the vision/audio models are f64 end-to-end and agnos ring-3 enables no FP today; proof-apps validate on host/QEMU until that arc lands.

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
- **attn11→libs extraction** — **complete**: rosnet (tensor core) + tyche (PRNG) + **rupantara** (transformer blocks/forward, 0.4.0, re-fold green) — registry in [`shared-crates.md`](shared-crates.md).
- **hisab** — sovereign **FFT/DST/DCT/2D-FFT** (registered numerical lib) — the audio frontend's transform; **abaco** [`src/dsp.cyr`](https://github.com/MacCracken/abaco) holds the windowing/dB/midi groundwork; STFT + mel filterbank glue still to be homed (hisab or abaco — decide at build time). shravan (`fft.cyr`, MDCT) + naad (`dsp_spectral.cyr`) carry codec/synthesis-local spectral paths.
- **chitra** — the shared pure-Cyrius image-decode lib (PNG + JPEG → canonical RGBA8; extracted from kii, consumed by kii + mabda) — the vision frontend's decode path, ready.
- **vani / shravan / naad / dhvani / goonj / shruti** — audio device I/O, codecs, synth, engine, acoustics ([`shared-crates.md`](shared-crates.md) *Audio I/O*).
- **drishti-av1 / -h264 / -h265 / -vpx / -rav1e** — sovereign video codecs ([`shared-crates.md`](shared-crates.md) *Video Codec Projects*); sight-adjacent decode surface.
- **mabda** (GPU foundation) + **ai-hwaccel** (GPU detection) — the eventual hardware-acceleration path once correctness is proven on `f64` arrays.
- **hoosh** (LLM inference gateway), **murti** (model runtime), **daimon** (agent orchestrator), **mela** (agent marketplace) — downstream consumers of the multimodal models.

---

*See also: [`shared-crates.md`](shared-crates.md) (Audio I/O, Video Codec Projects, Planned), [`roadmap.md`](roadmap.md) (Post-Beta Phases 17–18), [`state.md`](../state.md) (live attn11 version / pin), and the attn11 repo (`MacCracken/attn11`).*
