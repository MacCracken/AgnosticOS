# AGNOS Shared Libraries — Released (v1.0+)

> Reusable library crates that form the AGNOS stack. Consumer [applications](../README.md) depend on these — they should never depend on external libraries when an AGNOS crate covers the domain.
>
> **77 libraries at v1.0+** (75 standalone + 2 stdlib-folded: sandhi v5.7.0, niyama v5.9.0) — pre-1.0 libs tracked in [development/planning/](../../development/planning/README.md). Binary tools at v1.0+ (agnoshi, argonaut, cyim, cyim-lsp, kybernet, nous, owl) are listed separately in the [full registry](../../development/planning/shared-crates.md#binaries--tools-7-crates).
> Full registry: [Shared Crates Registry](../../development/planning/shared-crates.md) — that doc is the authoritative source; refresh from there.
>
> **Last Updated**: 2026-05-09

See also: [First-Party Standards — Own the Stack](../../development/planning/first-party-standards.md#own-the-stack) | [Science Crate Specs](../../development/guides/science-crate-specs.md)

---

## OS & Infrastructure (24)

| Crate | Version | Domain |
|-------|---------|--------|
| agnosai | 1.1.0 | AI orchestration |
| agnostik | 1.2.0 | Shared types & domain primitives (Cyrius, GitHub-release only) |
| agnosys | 1.2.1 | Kernel interface — Landlock, seccomp, syscall bindings (Cyrius) |
| ai-hwaccel | 2.0.0 | GPU detection |
| bote | 2.5.1 | MCP core (~5us/message, streamable HTTP) |
| daimon | 1.1.4 | Agent orchestrator (144 MCP tools) |
| hoosh | 2.0.0 | LLM gateway (15 providers) |
| ifran | 1.3.0 | LLM inference/training |
| kavach | 3.0.0 | Sandbox execution |
| libro | 2.0.5 | Cryptographic audit chain |
| mabda | 3.0.0-rc.2 | GPU foundation |
| majra | 2.4.1 | Queue/pub-sub |
| nein | 1.0.0 | Programmatic nftables firewall |
| patra | 1.9.3 | Structured storage & SQL — B+ tree, WAL (Cyrius-native) |
| phylax | 1.1.0 | Threat detection — YARA, entropy, magic bytes, ML |
| sakshi | 2.2.3 | Tracing, error handling, structured logging (Cyrius-native) |
| sankoch | 2.2.4 | Lossless compression — LZ4, DEFLATE, zlib, gzip |
| sigil | 3.1.0 | Trust verification & crypto — AES-NI + SHA-NI hardware accel |
| soorat | 1.0.0 | GPU rendering |
| stiva | — | Container runtime — **Rust-era scaffold; Cyrius port pending** (GitHub remote `MacCracken/stiva` last pushed 2026-04-29) |
| szal | 1.1.0 | Workflow engine |
| t-ron | 2.0.0 | MCP security |
| vidya | 2.7.0 | Programming reference |
| yukti | 2.2.2 | Device abstraction (USB, block, udev) |

## Science & Knowledge (27)

| Crate | Version | Domain |
|-------|---------|--------|
| abaco | 2.2.0 | Math engine |
| avatara | 2.3.0 | Divine archetype overlay |
| badal | 1.1.0 | Weather/atmosphere |
| bhava | 2.0.0 | Emotion/personality |
| bijli | 1.1.0 | Electromagnetism |
| bodh | 1.0.0 | Psychology |
| brahmanda | 1.0.0 | Galactic cosmology |
| dravya | 1.2.0 | Material science |
| falak | 1.0.0 | Orbital mechanics |
| hadara | 1.0.0 | Culture modeling (Cyrius-native, 50 cultures) |
| hisab | 2.2.2 | Higher math |
| hisab-mimamsa | 1.0.0 | Theoretical physics |
| itihas | 2.2.0 | World history |
| jantu | 1.1.0 | Ethology/behavior |
| jivanu | 1.0.0 | Microbiology |
| jyotish | 1.0.0 | Astronomical computation |
| kana | 1.1.0 | Quantum mechanics |
| khanij | 1.1.0 | Geology/mineralogy |
| kimiya | 1.1.1 | Chemistry |
| mastishk | 1.1.0 | Neuroscience |
| pramana | 1.2.0 | Statistics |
| rasayan | 1.0.0 | Biochemistry |
| sangha | 1.0.0 | Sociology |
| sankhya | 2.0.0 | Ancient math systems |
| sharira | 1.1.0 | Physiology |
| tara | 1.0.0 | Stellar astrophysics |
| vanaspati | 1.0.0 | Botany |

## Media & Audio (12)

| Crate | Version | Domain |
|-------|---------|--------|
| dhvani | 1.1.0 | Audio engine |
| garjan | 1.1.0 | Environmental sound |
| ghurni | 1.0.0 | Mechanical sound |
| goonj | 1.4.3 | Acoustics |
| naad | 1.2.5 | Audio synthesis |
| nidhi | 1.1.0 | Sample playback |
| prani | 1.1.0 | Creature vocals |
| shabda | 2.0.0 | G2P conversion |
| shabdakosh | 2.0.0 | Pronunciation dict |
| shravan | 2.3.2 | Audio codecs |
| svara | 2.0.0 | Vocal synthesis |
| tarang | 1.0.0 | Media framework (containers, decode/encode) |

## Graphics & Rendering (3)

| Crate | Version | Domain |
|-------|---------|--------|
| bsp | 1.1.2 | BSP geometry (Cyrius-native) |
| kiran | 1.0.0 | Game engine (ECS, scene hierarchy) |
| ranga | 1.0.0 | Image processing (color, blend, GPU compute) |

## Language & Navigation (3)

| Crate | Version | Domain |
|-------|---------|--------|
| raasta | 1.0.0 | Pathfinding |
| varna | 1.0.0 | Multilingual language engine |
| vyakarana | 2.2.1 | Source-code grammar + tokenizer (Cyrius-native, ten-kind palette, CYML grammars) |

## Physics & Engineering (6)

| Crate | Version | Domain |
|-------|---------|--------|
| impetus | 1.3.0 | Physics |
| pavan | 1.1.0 | Aerodynamics |
| prakash | 1.2.0 | Optics/light |
| pravash | 1.2.0 | Fluid dynamics |
| tanmatra | 1.2.1 | Atomic physics |
| ushma | 1.3.0 | Thermodynamics |

## Stdlib-Folded (2)

Sibling distfiles vendored byte-identical into the Cyrius stdlib `lib/`. Standalone repos remain for direct consumers needing newer surface than the folded snapshot; subsequent surface patches land via Cyrius release cycle.

| Crate | Folded At | Domain |
|-------|-----------|--------|
| sandhi | Cyrius v5.7.0 | Service-boundary layer — HTTP/HTTP2/WS/TLS/JSON/net (376 KB / 9,649 lines / 469 fns). Set the fold pattern; sandhi repo entered maintenance mode per ADR 0002. |
| niyama | Cyrius v5.9.0 | Regex engines — bre / re2 / pcre / fuzzy / vim (6,664 lines / 7 modules). Multi-consumer gate: cyim + queued AGNOS bare-metal kernel. |
