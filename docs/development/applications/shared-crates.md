# Shared Crates — Registry & Status

> **Status**: Active | **Last Updated**: 2026-04-27
>
> **107 entries** — 82 at v1.0+ stable (75 libs + 6 binaries + 1 stdlib-folded), 19 pre-1.0 libs, 8 pre-1.0 binaries/tools, 10 non-library, 3 planned, plus the Audio I/O / Video Codec / GitHub-only sub-sections (overlap with the v1.0+/pre-1.0 counts above where applicable).
>
> **Classification rule**: pre-v1.0 crates are tracked in [`docs/development/applications/`](README.md). v1.0+ stable crates have their docs in [`docs/applications/libs/`](../../applications/libs/) (libraries) or [`docs/applications/`](../../applications/) (consumer apps).
> See [First-Party Standards](first-party-standards.md) for versioning and publishing conventions.

---

## v1.0+ Stable Index (82 entries)

Full documentation for each library: [docs/applications/libs/](../../applications/libs/README.md). Consumer apps live one level up at [docs/applications/](../../applications/README.md).

### OS & Infrastructure (24 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| agnosai | 1.1.0 | AI orchestration |
| agnostik | 1.0.1 | Shared types & domain primitives (Cyrius, GitHub-release only) — foundation for all AGNOS crates |
| agnosys | 1.0.2 | Kernel interface — Landlock, seccomp, syscall bindings (Cyrius, GitHub-release only) |
| ai-hwaccel | 2.0.0 | GPU detection |
| bote | 2.5.1 | MCP core (~5us/message, streamable HTTP) |
| daimon | 1.1.1 | Agent orchestrator (144 MCP tools, GitHub-release only) |
| hoosh | 2.0.0 | LLM gateway (15 providers) |
| ifran | 1.3.0 | LLM inference/training |
| kavach | 3.0.0 | Sandbox execution |
| libro | 2.0.5 | Cryptographic audit chain |
| mabda | 2.5.0 | GPU foundation |
| majra | 2.4.1 | Queue/pub-sub |
| nein | 1.0.0 | Programmatic nftables firewall |
| patra | 1.9.0 | Structured storage & SQL — B+ tree, WAL (Cyrius-native) |
| phylax | 1.0.0 | Threat detection — YARA, entropy, magic bytes, ML |
| sakshi | 2.1.0 | Tracing, error handling, structured logging (Cyrius-native) |
| sankoch | 2.1.0 | Lossless compression — LZ4, DEFLATE, zlib, gzip |
| sigil | 2.9.3 | Trust verification & crypto — AES-NI + SHA-NI hardware accel |
| soorat | 1.0.0 | GPU rendering |
| stiva | 2.0.0 | Container runtime |
| szal | 1.1.0 | Workflow engine |
| t-ron | 2.0.0 | MCP security |
| vidya | 2.3.0 | Programming reference |
| yukti | 2.1.1 | Device abstraction (USB, block, udev) |

### Science & Knowledge (27 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| abaco | 2.1.0 | Math engine |
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
| shravan | 2.3.2 | Audio codecs |
| svara | 2.0.0 | Vocal synthesis |
| tarang | 1.0.0 | Media framework (containers, decode/encode) |

### Graphics & Rendering (3 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| bsp | 1.1.2 | BSP geometry (Cyrius-native) |
| kiran | 1.0.0 | Game engine (ECS, scene hierarchy) |
| ranga | 1.0.0 | Image processing (color, blend, GPU compute) |

### Language & Navigation (3 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| raasta | 1.0.0 | Pathfinding |
| varna | 1.0.0 | Multilingual language engine |
| vyakarana | 1.0.2 | Source-code grammar + tokenizer (Cyrius-native, ten-kind palette, CYML grammars) |

### Physics & Engineering (6 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| impetus | 1.3.0 | Physics |
| pavan | 1.1.0 | Aerodynamics |
| prakash | 1.2.0 | Optics/light |
| pravash | 1.2.0 | Fluid dynamics |
| tanmatra | 1.2.1 | Atomic physics |
| ushma | 1.3.0 | Thermodynamics |

### Binaries & Tools (6 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| [agnoshi](https://github.com/MacCracken/agnoshi) | 1.0.0 | AI shell (Cyrius) — depends on hoosh, daimon |
| [argonaut](https://github.com/MacCracken/argonaut) | 1.4.0 | Init system library (Cyrius) — depends on agnosys |
| [cyim](https://github.com/MacCracken/cyim) | 1.1.3 | Sovereign modal text editor (Cyrius-native, VIM-inspired, zero attack surface, no embedded scripting). Consumes vyakarana; consumers: agnoshi, aethersafha, daimon-orchestrated agents (the AI-agent edit loop closes through cyim). |
| [kybernet](https://github.com/MacCracken/kybernet) | 1.0.1 | PID 1 init binary (486KB, Cyrius, 140 tests) — depends on argonaut |
| [nous](https://github.com/MacCracken/nous) | 1.1.1 | Package resolver (Cyrius) |
| [owl](https://github.com/MacCracken/owl) | 1.1.6 | Watchful file viewer — `cat`/`bat` replacement (Cyrius-native, **O**bservant **W**atcher of **L**ines). `-p` byte-identical cat drop-in; decorated mode adds token highlighting + VCS gutter + paging. Consumes vyakarana for tokenization. |

### Stdlib-Folded (1 crate)

| Crate | Version | Domain |
|-------|---------|--------|
| [sandhi](https://github.com/MacCracken/sandhi) | 1.0.0 | Service-boundary layer (HTTP client+server, HTTP/2, streaming, JSON-RPC, service discovery, TLS policy). **Folded into Cyrius stdlib at v5.7.0** as `lib/sandhi.cyr` (vendored byte-identical, 376,037 B / 9,649 lines / 469 fns). Sandhi repo entered maintenance mode per [ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md); subsequent surface patches land via Cyrius release cycle. |

---

## Pre-1.0 (19 crates)

### Near-Stable (v0.5.0+)

| Crate | Version | Description | Key Consumers |
|-------|---------|-------------|---------------|
| [aethersafta](https://github.com/MacCracken/aethersafta) | 0.50.0 | Media compositing — scene graph, capture, HW encoding | aethersafha, tazama |
| [jnana](https://github.com/MacCracken/jnana) | 0.5.0 | Unified knowledge system — offline-accessible corpus | agnoshi, hoosh, daimon |

### In Progress (v0.1.0 - v0.49.x)

| Crate | Version | Description | Key Consumers |
|-------|---------|-------------|---------------|
| [selah](https://github.com/MacCracken/selah) | 0.29.4 | Screenshot capture, annotation, PII redaction | taswir, soorat |
| [cyrius-doom](https://github.com/MacCracken/cyrius-doom) | 0.26.1 | DOOM engine in Cyrius — hardened, 5 CVEs fixed, 2.59ms/frame | standalone game / kernel demo |
| [muharrir](https://github.com/MacCracken/muharrir) | 0.23.5 | Editor primitives — text buffer, undo/redo, command pattern | rasa, tazama, shruti |
| [vani](https://github.com/MacCracken/vani) | 0.1.0 | Audio device I/O — direct ALSA/OSS syscalls (Cyrius-native) | shravan, dhvani, naad, jalwa, shruti |
| [yantra](https://github.com/MacCracken/yantra) | 0.1.0 | Sovereign UI automation — browser + mobile, as a Cyrius library (Cyrius-native). `.tcyr` files include `lib/yantra.cyr` and drive Chromium / Firefox / WebKit / Android / iOS. Not a framework — `cyrius test` stays the runner. Planned backends: CDP, W3C WebDriver, Appium. | AGNOS E2E consumers (owl, agnoshi, tanur when GUI lands) |
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
| [sit](https://github.com/MacCracken/sit) | 0.7.1 | Sovereign version control — Cyrius-native git replacement (smriti, स्मृति — memory). Deps: sankoch (compression), sigil (hashing), patra (object store). No libgit2, no C, no FFI. | end user, owl (git-marker integration), ark |

---

## Binaries & Tools (pre-1.0, 9 entries)

| Binary | Version | Description | Depends On |
|--------|---------|-------------|------------|
| [shakti](https://github.com/MacCracken/shakti) | 0.2.2 | Privilege escalation (`sudo` replacement) | agnosys, sigil |
| [ark](https://github.com/MacCracken/ark) | 0.8.0 | Package manager (Cyrius) | nous, sigil |
| [takumi](https://github.com/MacCracken/takumi) | 0.8.0 | Build system — Cyrius port in progress (toolchain pinned 5.5.23; `rust-old/` authoritative until parity) | sigil |
| [aegis](https://github.com/MacCracken/aegis) | 0.1.0 | Security daemon | sigil, phylax |
| [aethersafha](https://github.com/MacCracken/aethersafha) | 0.1.0 | Wayland compositor | aethersafta, mabda |
| [mela](https://github.com/MacCracken/mela) | 0.1.0 | Agent marketplace | daimon, sigil |
| [agnova](https://github.com/MacCracken/agnova) | 0.1.0 | OS installer (Cyrius port from 3,656 Rust lines, base established) | ark, kavach |
| [seema](https://github.com/MacCracken/seema) | 0.1.0 | Edge fleet management | daimon, bote |
| [samay](https://github.com/MacCracken/samay) | 0.1.0 | Task scheduler | szal |

---

## Non-Library Projects

| Project | Version | Description | Key Consumers |
|---------|---------|-------------|---------------|
| [trump_epstein](https://github.com/MacCracken/trump_epstein) | 0.1.0 | Evidence database — court filings, depositions, flight logs | nyaya, patra, sigil, libro |
| [cyrius-nba-jam](https://github.com/MacCracken/cyrius-nba-jam) | 0.5.0 | NBA Jam reimplementation in Cyrius | standalone game |
| [encom-hits](https://github.com/MacCracken/encom-hits) | 1.0.0 | ENCOM retro arcade collection in Cyrius | standalone game |
| [cyrius-brynns-tale](https://github.com/MacCracken/cyrius-brynns-tale) | 0.1.0 | ***Brynn's Tale*** — original mythic-modern game in Cyrius. A wife uses a time-rewind power to save her husband from dying; the cost is herself. **Three-act diptych-becoming-triptych**: Act 1 backward-narrative descent (Memento-form, six rewind variants per world); Act 2 forward-irreversible survival (Bleed mechanic + every choice final); Act 3 NG+ as the integrated being THEM (alchemical *rebis* after Phoenix-rebirth, full toolkit, climaxes in cosmic-test rubedo). Selectively Souls-like (soft-fail everyday + hard-fail bosses). Pivoted 2026-04-26 from `cyrius-braid` Braid-reimplementation; original IP per ADR 0003. Formerly registered as `cyrius-braid`. | standalone game |
| [cyrius-super-plumber-twins](https://github.com/MacCracken/cyrius-super-plumber-twins) | 0.1.0 | 2.5D platformer with ragdoll-physics (homage to *Super Mario Bros*, Nintendo 1985 — reimplementation from observation, not a port). Stars **The Royals** (Royal/midnight Blue + Purple plumber **twins — boy + girl**, peer protagonists) who work for the Castle. Original cast: The Boy (the girl-twin's crush; jester/scribe dual-role with forest-green scribe attire + motley jester attire — **gender-flipped love-interest archetype inverts the Mario princess-rescuee trope**), Cousin Job (trade-rival trying to prove he's the better plumber, equal antagonism toward both twins), Mouser (GC / Head of Facilities final boss — three-layer name including Disney wink), Facility Sub-Managers (Koopalings × Mega Man Robot Masters hybrid). Nintendo-IP distinctiveness bar is the strictest in the retro-port series. Formerly `cyrius-super-plumber-bros`; renamed per [ADR 0004](https://github.com/MacCracken/cyrius-super-plumber-twins/blob/main/docs/adr/0004-twins-pivot.md). | standalone game |
| [cyrius-bb](https://github.com/MacCracken/cyrius-bb) | 0.1.0 | *Break-breaker* — 2.5D brick-breaker in Cyrius. 50-year homage to *Breakout* (Atari, 1976 — Bushnell / Wozniak-adjacent lineage). Atari-IP distinctiveness bar is relaxed (Atari SA tolerates respectful homages). | standalone game |
| [cyrius-stellar-swarm](https://github.com/MacCracken/cyrius-stellar-swarm) | 0.1.0 | 2.5D fixed-shooter (homage to *Galaga*, Namco 1981 — reimplementation from observation). Preserves formation-attack + tractor-beam capture-and-rescue + bonus challenging stages. Original ship + three-tier original enemy creatures + original chiptune-era synth music. Namco-IP distinctiveness bar moderate. | standalone game |
| [cyrius-sunset-drive](https://github.com/MacCracken/cyrius-sunset-drive) | 0.1.0 | 2.5D arcade coastal-racer (homage to *Outrun*, Sega / Yu Suzuki 1986 — reimplementation from observation). Pick-a-route + pick-a-track signature mechanics. Initial routes: Sunset Drive / Coastal Run / Ridgeline. Initial music selects: Yacht Rock / Smooth Jazz / Dance-Hi-Energy. Original convertible-coupe car (NOT a Ferrari Testarossa — Sega-IP moderate + Ferrari IP hard-excluded). | standalone game |
| [cyrius-grapevine](https://github.com/MacCracken/cyrius-grapevine) | 0.1.0 | 2.5D cozy meta-casual vineyard sim. Genre-synthesis of *My Vineyard* (Metaplace, 2010) + *Animal Crossing* (Nintendo, 2001) + *Stardew Valley* (ConcernedApe, 2016). First cozy-sim slot in the library. Vineyard-focused (grapes + 2-3 crops max), 8-12 Stardew-grade NPCs with schedules and dialogue, real-time seasonal rhythm, four seasonal festivals. **Trusted-pair multiplayer co-op as M3 core scope** (not stretch) — async-visit + real-time co-op via sandhi networking. Hard rules: no combat / mining / dungeons / bachelor-catalog. Save-format versioned from day one (players invest years). Three-tier distinctiveness bar: Nintendo-strict on AC-adjacent / Metaplace-defunct-relaxed / ConcernedApe-respect on Stardew-adjacent. | standalone game |
| [cyrius-chellys-beach-adventure](https://github.com/MacCracken/cyrius-chellys-beach-adventure) | 0.1.0 | 2.5D cascade-reel slot machine in Cyrius. **B2B commercial-platform-demo** designed to pitch Cyrius as secure, sovereign gaming-industry OS to Konami / IGT / Scientific Games / Light & Wonder / Aristocrat. Original game (not homage); slot mechanics are industry-convention used freely. **Column-cascade Wild** (entire column cascades on wild, not tile-cascade) as signature mechanical twist. Warm golden-hour beach theme. Characters Chelly (Black Bichpoo) and Mykala (GSD/Chow mix). Technical arguments: **provable-fair RNG native via sigil** (not bolted on), byte-identical cross-platform reproducible builds, small attack surface, kavach game-isolation. RTP 94-96% industry-standard validated via abaco. Not a consumer retail game; not a certified slot (certification post-manufacturer-commit). | B2B platform demo |
| [cyrius-chelly-beach-dash](https://github.com/MacCracken/cyrius-chelly-beach-dash) | 0.1.0 | **Chelly's Beach Dash** — 2.5D arcade beach-runner in Cyrius. Consumer-facing title sharing the **Chelly's Beach Adventure** brand with the slots B2B demo above (same characters, separate game). Trick-combo runner — mechanical homage to *Skate or Die* (Electronic Arts, 1987 — reimplementation from observation, not a port). Chelly (Black Bichpoo) dashes across the beach to her owner at the end of the pier; mechanical mapping: trick combos → tail-wag/leap combos, half-pipe → dune jumps, urban hazards → boardwalk crabs/seagulls/driftwood, finish line → owner-reunion at the pier. Same warm golden-hour beach theme as the slots. EA-IP distinctiveness bar relaxed (38-year-old NES-era title, mechanical-only homage). Sits in the same 2D sprite/AI/state lane as cyrius-nba-jam and cyrius-grapevine — tooling investment compounds. v0.2.0 = Flappy-Bird-first scope (one lane, one jump, one hazard family, one pier finish); magnum-opus catalog accretes through later versions. Scaffolded 2026-04-28. | standalone game |
| cyrius-mine-cart *(not scaffolded — slug + title provisional; 3D lane)* | — | **First 3D pilot for the kiran/joshua stack — deliberately scoped simple.** 3D mine-cart-on-rails action game in Cyrius. Mechanical homage to the mine-cart-action genre as established by *Indiana Jones and the Temple of Doom* (Paramount/Lucasfilm, 1984) and continued through *Donkey Kong Country* (Rare/Nintendo, 1994), *Crash Bandicoot 2* (Naughty Dog, 1996), and many others. Signature mechanics: branching rails, jumps over gaps, duck-under-low-beams, speed control, environmental hazards (collapsing rails / boulders / pursuing threats). **Why this title leads the 3D lane:** rail-constrained motion (camera-on-rails + character-on-rails) is the simplest 3D control surface to ship — no free 3D camera, no free 3D movement, no full physics sandbox. Picked specifically as the gentlest first-3D-load on kiran + joshua rather than the most ambitious. **Indiana Jones / Temple of Doom IP hard-excluded** (Disney/Lucasfilm, strictest bar) — original setting + original character + original score. Mine-cart-action genre is general; mechanical-only homage. **Lane gate:** depends on **kiran** (game engine) + **joshua** (game manager + AI sim runtime), both currently post-boot work. Long-standing concept; formally cataloged 2026-04-27. | standalone game |

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

---

## Extraction Guidelines

Extract when **3+ projects** implement the same pattern. Until then, keep it in-project.

- You're copying a module between repos
- Two projects have different implementations of the same algorithm
- A bug fix in one project should automatically benefit another

See [monolith-extraction.md](../monolith-extraction.md) for the daimon/hoosh/agnoshi extraction plan.

See [k8s-roadmap.md](../vision/architecture/k8s-roadmap.md) for stiva + nein + majra + kavach orchestration platform.

---

*Last Updated: 2026-04-27*
