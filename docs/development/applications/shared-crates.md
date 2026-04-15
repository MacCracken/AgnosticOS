# Shared Crates — Registry & Status

> **Status**: Active | **Last Updated**: 2026-04-15
>
> **102 crates** — 68 at v1.0+ stable, 20 pre-1.0, 7 scaffolded/planned, 4 Cyrius-native, 1 internal, 2 non-library
>
> v1.0+ crate documentation lives in [docs/applications/libs/](../../applications/libs/).
> Pre-1.0 crates tracked in [development/applications/](README.md).
> See [First-Party Standards](first-party-standards.md) for versioning and publishing conventions.

---

## v1.0+ Stable Index (68 crates)

Full documentation for each crate: [docs/applications/libs/](../../applications/libs/README.md)

### OS & Infrastructure (18 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| agnosai | 1.1.0 | AI orchestration |
| ai-hwaccel | 2.0.0 | GPU detection |
| bote | 2.5.1 | MCP core (~5us/message, streamable HTTP) |
| daimon | 1.1.1 | Agent orchestrator (144 MCP tools) |
| hoosh | 2.0.0 | LLM gateway (15 providers) |
| ifran | 1.3.0 | LLM inference/training |
| kavach | 3.0.0 | Sandbox execution |
| libro | 1.0.3 | Cryptographic audit chain |
| mabda | 2.1.2 | GPU foundation |
| majra | 2.2.0 | Queue/pub-sub |
| nein | 1.0.0 | Programmatic nftables firewall |
| sigil | 2.1.2 | Trust verification & crypto |
| soorat | 1.0.0 | GPU rendering |
| stiva | 2.0.0 | Container runtime |
| szal | 1.1.0 | Workflow engine |
| t-ron | 2.0.0 | MCP security |
| vidya | 2.2.0 | Programming reference |
| yukti | 1.2.0 | Device abstraction (USB, block, udev) |

### Science & Knowledge (27 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| abaco | 2.0.0 | Math engine |
| avatara | 2.3.0 | Divine archetype overlay |
| badal | 1.1.0 | Weather/atmosphere |
| bhava | 2.0.0 | Emotion/personality |
| bijli | 1.1.0 | Electromagnetism |
| bodh | 1.0.0 | Psychology |
| brahmanda | 1.0.0 | Galactic cosmology |
| dravya | 1.2.0 | Material science |
| falak | 1.0.0 | Orbital mechanics |
| hadara | 1.0.0 | Culture modeling (Cyrius-native, 50 cultures) |
| hisab | 1.4.0 | Higher math |
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

### Media & Audio (12 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| dhvani | 1.1.0 | Audio engine |
| garjan | 1.1.0 | Environmental sound |
| ghurni | 1.0.0 | Mechanical sound |
| goonj | 1.1.1 | Acoustics |
| naad | 1.0.0 | Audio synthesis |
| nidhi | 1.1.0 | Sample playback |
| prani | 1.1.0 | Creature vocals |
| shabda | 2.0.0 | G2P conversion |
| shabdakosh | 2.0.0 | Pronunciation dict |
| shravan | 2.1.1 | Audio codecs |
| svara | 2.0.0 | Vocal synthesis |
| tarang | 1.0.0 | Media framework (containers, decode/encode) |

### Graphics & Rendering (3 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| bsp | 1.0.1 | BSP geometry (Cyrius-native) |
| kiran | 1.0.0 | Game engine (ECS, scene hierarchy) |
| ranga | 1.0.0 | Image processing (color, blend, GPU compute) |

### Language & Navigation (2 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| raasta | 1.0.0 | Pathfinding |
| varna | 1.0.0 | Multilingual language engine |

### Physics & Engineering (6 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| impetus | 1.3.0 | Physics |
| pavan | 1.1.0 | Aerodynamics |
| prakash | 1.2.0 | Optics/light |
| pravash | 1.2.0 | Fluid dynamics |
| tanmatra | 1.2.1 | Atomic physics |
| ushma | 1.3.0 | Thermodynamics |

---

## Pre-1.0 (20 crates)

### Near-Stable (v0.5.0+)

| Crate | Version | Description | Key Consumers |
|-------|---------|-------------|---------------|
| [agnosys](https://github.com/MacCracken/agnosys) | 0.97.2 | Kernel interface — Landlock, seccomp, syscall bindings (Cyrius) | daimon, aethersafha, kavach, argonaut |
| [agnostik](https://github.com/MacCracken/agnostik) | 0.97.1 | Shared types & domain primitives (Cyrius, GitHub-release only) | all AGNOS crates |
| [sakshi](https://github.com/MacCracken/sakshi) | 0.9.0 | Tracing, error handling, structured logging — zero-alloc hot path (Cyrius-native) | every crate — foundational |
| [aethersafta](https://github.com/MacCracken/aethersafta) | 0.50.0 | Media compositing — scene graph, capture, HW encoding | aethersafha, tazama |
| [phylax](https://github.com/MacCracken/phylax) | 0.5.0 | Threat detection — YARA, entropy, magic bytes, ML | daimon, aegis |
| [jnana](https://github.com/MacCracken/jnana) | 0.5.0 | Unified knowledge system — offline-accessible corpus | agnoshi, hoosh, daimon |

### In Progress (v0.1.0 - v0.49.x)

| Crate | Version | Description | Key Consumers |
|-------|---------|-------------|---------------|
| [selah](https://github.com/MacCracken/selah) | 0.29.4 | Screenshot capture, annotation, PII redaction | taswir, soorat |
| [cyrius-doom](https://github.com/MacCracken/cyrius-doom) | 0.24.5 | DOOM engine in Cyrius — hardened, 5 CVEs fixed, 2.59ms/frame | standalone game / kernel demo |
| [muharrir](https://github.com/MacCracken/muharrir) | 0.23.5 | Editor primitives — text buffer, undo/redo, command pattern | rasa, tazama, shruti |
| [patra](https://github.com/MacCracken/patra) | 0.14.0 | Structured storage & SQL — B+ tree, WAL, 243 tests (Cyrius-native) | libro, daimon, vidya, agnoshi |
| [sankoch](https://github.com/MacCracken/sankoch) | 0.1.0 | Lossless compression — LZ4, DEFLATE, zlib, gzip. Gate to sovereign git. | ark, delta, patra |
| [vani](https://github.com/MacCracken/vani) | 0.1.0 | Audio device I/O — direct ALSA/OSS syscalls (Cyrius-native) | shravan, dhvani, naad, jalwa, shruti |
| [joshua](https://github.com/MacCracken/joshua) | 0.1.0 | Game manager — AI NPCs, headless simulation | end user |
| [murti](https://github.com/MacCracken/murti) | 0.1.0 | Model runtime — registry, store, inference backends | hoosh, ifran, tanur |
| [salai](https://github.com/MacCracken/salai) | 0.1.0 | Game editor — egui visual editor for kiran | kiran |
| [tanur](https://github.com/MacCracken/tanur) | 0.1.0 | Desktop LLM studio — model management GUI | end user |
| [mudra](https://github.com/MacCracken/mudra) | 0.1.0 | Token/value primitives — asset identity, ownership, type | vinimaya, mela, aequi, bullshift |
| [vinimaya](https://github.com/MacCracken/vinimaya) | 0.1.0 | Transaction layer — atomic transfers, escrow, settlement | mela, daimon, ark, seema, aequi |
| [taal](https://github.com/MacCracken/taal) | 0.1.0 | Music theory — scales, intervals, chords, rhythm | naad, svara, shruti, jalwa |
| [natya](https://github.com/MacCracken/natya) | 0.1.0 | Theater/drama/narrative — dramatic structure, archetypes | bhava, agnoshi, hoosh, joshua |
| [kshetra](https://github.com/MacCracken/kshetra) | 0.1.0 | Temporal geography — spatiotemporal database | itihas, badal, khanij, vanaspati |
| [leela](https://github.com/MacCracken/leela) | 0.1.0 | Sport — rules, athletes, tournaments, records | hadara, itihas, avatara, jnana |
| [nyaya](https://github.com/MacCracken/nyaya) | 0.1.0 | Structured legal knowledge — statutes, precedents, IP | trump_epstein, hadara, itihas, jnana |

---

## System Binaries & Tools (pre-1.0)

| Binary | Version | Description | Depends On |
|--------|---------|-------------|------------|
| [kybernet](https://github.com/MacCracken/kybernet) | 1.0.1 | PID 1 init binary (486KB, Cyrius, 140 tests) | argonaut |
| [argonaut](https://github.com/MacCracken/argonaut) | 1.2.0 | Init system library (Cyrius) | agnosys |
| [agnoshi](https://github.com/MacCracken/agnoshi) | 1.0.0 | AI shell (Cyrius) | hoosh, daimon |
| [shakti](https://github.com/MacCracken/shakti) | 0.1.0 | Privilege escalation (`sudo` replacement) | agnosys, sigil |
| [ark](https://github.com/MacCracken/ark) | 0.1.0 | Package manager (Cyrius) | nous, sigil |
| [nous](https://github.com/MacCracken/nous) | 0.1.0 | Package resolver (Cyrius) | — |
| [takumi](https://github.com/MacCracken/takumi) | 0.1.0 | Build system | — |
| [aegis](https://github.com/MacCracken/aegis) | 0.1.0 | Security daemon | sigil, phylax |
| [aethersafha](https://github.com/MacCracken/aethersafha) | 0.1.0 | Wayland compositor | aethersafta, mabda |
| [mela](https://github.com/MacCracken/mela) | 0.1.0 | Agent marketplace | daimon, sigil |
| [agnova](https://github.com/MacCracken/agnova) | 0.1.0 | OS installer | ark, kavach |
| [seema](https://github.com/MacCracken/seema) | 0.1.0 | Edge fleet management | daimon, bote |
| [samay](https://github.com/MacCracken/samay) | 0.1.0 | Task scheduler | szal |

---

## Non-Library Projects

| Project | Version | Description | Key Consumers |
|---------|---------|-------------|---------------|
| [trump_epstein](https://github.com/MacCracken/trump_epstein) | 0.1.0 | Evidence database — court filings, depositions, flight logs | nyaya, patra, sigil, libro |
| [cyrius-nba-jam](https://github.com/MacCracken/cyrius-nba-jam) | 1.0.0 | NBA Jam reimplementation in Cyrius | standalone game |
| [encom-hits](https://github.com/MacCracken/encom-hits) | 1.0.0 | ENCOM retro arcade collection in Cyrius | standalone game |

---

## GitHub Release Only (internal)

| Crate | Version | Description |
|-------|---------|-------------|
| [agnostik](https://github.com/MacCracken/agnostik) | 0.97.1 | Shared types and domain primitives for AGNOS (Cyrius) |

---

## Audio I/O (pure Cyrius)

| Crate | Description | Key Consumers |
|-------|-------------|---------------|
| **vani** | Audio device I/O — the voice (Sanskrit: वाणी). PCM playback/capture via direct syscalls to ALSA/OSS. No PulseAudio, no PipeWire daemon. | shravan, dhvani, naad, jalwa, shruti, cyrius-doom, agnoshi |

```
naad (create) → dhvani (process) → shravan (encode) → vani (output to speakers)
vani (input from mic) → shravan (decode) → dhvani (process)
```

## Video Codec Projects (pure Cyrius, post-tarang core)

Sovereign video codecs — no C, no FFI, no libav*. Each codec is a standalone crate. **drishti** (Sanskrit: दृष्टि — vision, sight, seeing).

| Crate | Replaces | Description | Key Consumers |
|-------|----------|-------------|---------------|
| **drishti-av1** | dav1d | AV1 decode — royalty-free, next-gen video | tarang, tazama, jalwa |
| **drishti-h264** | openh264 | H.264/AVC decode/encode — ubiquitous video codec | tarang, tazama, aethersafta |
| **drishti-h265** | libde265 | H.265/HEVC decode — 4K/HDR video | tarang, tazama |
| **drishti-vpx** | libvpx | VP8/VP9 decode — WebM video | tarang, tazama, jalwa |
| **drishti-rav1e** | rav1e | AV1 encode — royalty-free encoding | tarang, tazama, aethersafta |

---

## Planned (not yet scaffolded)

| Crate | Description | Key Consumers |
|-------|-------------|---------------|
| **krishi** | Agriculture — crop science, soil, irrigation, yield modeling (Sanskrit: कृषि) | vanaspati, badal, kimiya, kshetra |
| **prakriti** | Ecology — ecosystem modeling, food webs, biodiversity (Sanskrit: प्रकृति) | jantu, vanaspati, badal, jivanu |
| **cyim** | Sovereign text editor — Cyrius-native, VIM-inspired, zero attack surface | agnoshi, aethersafha |

---

## Extraction Guidelines

Extract when **3+ projects** implement the same pattern. Until then, keep it in-project.

- You're copying a module between repos
- Two projects have different implementations of the same algorithm
- A bug fix in one project should automatically benefit another

See [monolith-extraction.md](../monolith-extraction.md) for the daimon/hoosh/agnoshi extraction plan.

See [k8s-roadmap.md](../vision/architecture/k8s-roadmap.md) for stiva + nein + majra + kavach orchestration platform.

---

*Last Updated: 2026-04-15*
