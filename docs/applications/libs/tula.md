# tula

Sovereign ML weight-file format (तुला — *balance / scale; the instrument that weighs*) — a safetensors/GGUF analog, Cyrius-native, with a **sigil-signed header** those formats lack.

- **Repository**: [github.com/MacCracken/tula](https://github.com/MacCracken/tula)
- **License**: GPL-3.0-only
- **Status**: Stable — v1.0+ (format v1 **FROZEN**)
- **Language**: Cyrius

64-byte header + typed manifest entries (`f64` / `int8` / ternary-packed / nf4-block) + 8-byte-aligned payload; builder/reader with heap and zero-copy-mmap read paths; Ed25519 sign/verify over the content region (`sig_off`/`sig_len`), rejecting unsigned/tampered/wrong-key checkpoints at load. Format frozen after 105 assertions + a 2,003,000-iteration fuzz + a security audit.

**M0 of the [Type-3 weight-import chain](../../development/planning/type3-weight-import.md).** Depends on [sigil](sigil.md) (signed header). Consumed by `anukūlana` (the Type-3 importer), attn11/tentib checkpoints, and the murti model-load seam.

See the [shared-crates registry](../../development/planning/shared-crates.md) for full context and dependency graph.
