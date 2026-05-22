# Shared Crates — Registry & Status

> **Status**: Active | **Last Updated**: 2026-05-22 (post-1.31.6 close + 1.31.7 open drift sweep)
>
> **121 entries** — 91 at v1.0+ stable (76 libs + 14 binaries — `mihi` joined libs as system-info probe substrate; `iam` + `bannermanor` joined binaries — + **2 stdlib-folded**; aegis 1.0.0 graduated v5.10.x; **kriya 1.0.0** + **commandress 1.0.0** graduated 2026-05-18; **mihi 1.0.0 + iam 1.0.0** graduated 2026-05-20 morning; **bannermanor 1.0.0** graduated same day PM after CLI surface + CYML font format + default font set frozen as the v1.0 contract), 20 pre-1.0 libs, **12 pre-1.0 binaries/tools** (gnoboot 0.4.2 + **hapi 0.5.0** added 2026-05-20 PM; **kii 0.1.0** added 2026-05-22 — image→ANSI/ASCII converter, triple-layered name play: Hawaiian *image* + back-half of *a-scii* + functional convergence), 9 non-library, **2 planned** (krishi + prakriti + darshini — terminal-aesthetics quintet shipped 4 of 5 by 2026-05-20 PM; only darshini queued), plus the Audio I/O / Video Codec / GitHub-only sub-sections (overlap with the v1.0+/pre-1.0 counts above where applicable).
>
> **Classification rule**: pre-v1.0 crates are tracked in [`docs/development/planning/`](README.md). v1.0+ stable crates have their docs in [`docs/applications/libs/`](../../applications/libs/) (libraries) or [`docs/applications/`](../../applications/) (consumer apps).
> See [First-Party Standards](first-party-standards.md) for versioning and publishing conventions.

---

## v1.0+ Stable Index (89 entries)

Full documentation for each library: [docs/applications/libs/](../../applications/libs/README.md). Consumer apps live one level up at [docs/applications/](../../applications/README.md).

### OS & Infrastructure (26 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| aegis | 1.0.0 | Security daemon — graduated from pre-1.0 in the v5.10.x window |
| agnosai | 1.1.0 | AI orchestration |
| agnostik | 1.2.2 | Shared types & domain primitives (Cyrius, GitHub-release only) — foundation for all AGNOS crates |
| agnosys | 1.2.7 | Kernel interface — Landlock, seccomp, syscall bindings (Cyrius, GitHub-release only) |
| ai-hwaccel | 2.2.6 | GPU detection |
| bote | 2.7.2 | MCP core (~5us/message, streamable HTTP) |
| daimon | 1.2.3 | Agent orchestrator (144 MCP tools, GitHub-release only) |
| hoosh | 2.0.0 | LLM gateway (15 providers) |
| ifran | 1.3.0 | LLM inference/training |
| kavach | 3.2.1 | Sandbox execution |
| libro | 2.6.3 | Cryptographic audit chain |
| mabda | 3.0.0-rc.2 | GPU foundation |
| majra | 2.4.4 | Queue/pub-sub |
| mihi | 1.0.0 | System-info probe library (CPU / RAM / GPU / kernel / uptime / distro / hostname). Sanskrit-Hindi/Polynesian semantic lane (Maori: formal self-introduction ceremony). Substrate for iam, chakshu, and any tool that needs "tell me about this box." First of the 2026-05-20 v6.0.x graduations cut. |
| nein | 1.5.1 | Programmatic nftables firewall |
| patra | 1.9.4 | Structured storage & SQL — B+ tree, WAL (Cyrius-native) |
| phylax | 1.1.1 | Threat detection — YARA, entropy, magic bytes, ML |
| sakshi | 2.2.4 | Tracing, error handling, structured logging (Cyrius-native) |
| sankoch | 2.2.6 | Lossless compression — LZ4, DEFLATE, zlib, gzip |
| sigil | 3.2.6 | Trust verification & crypto — AES-NI + SHA-NI hardware accel |
| soorat | 1.0.0 | GPU rendering |
| stiva | — | Container runtime — **Rust-era scaffold; Cyrius port pending** (GitHub remote `MacCracken/stiva` last pushed 2026-04-29; no version pin until ported) |
| szal | 1.1.0 | Workflow engine |
| t-ron | 2.1.4 | MCP security |
| vidya | 2.7.1 | Programming reference |
| yukti | 2.2.3 | Device abstraction (USB, block, udev) |

### Science & Knowledge (27 crates)

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

### Media & Audio (12 crates)

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

### Graphics & Rendering (3 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| bsp | 1.1.3 | BSP geometry (Cyrius-native) |
| kiran | 1.0.0 | Game engine (ECS, scene hierarchy) |
| ranga | 1.0.0 | Image processing (color, blend, GPU compute) |

### Language & Navigation (3 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| raasta | 1.0.0 | Pathfinding |
| varna | 1.0.0 | Multilingual language engine |
| vyakarana | 2.2.1 | Source-code grammar + tokenizer (Cyrius-native, ten-kind palette, CYML grammars) |

### Physics & Engineering (6 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| impetus | 1.3.0 | Physics |
| pavan | 1.1.0 | Aerodynamics |
| prakash | 1.2.0 | Optics/light |
| pravash | 1.2.0 | Fluid dynamics |
| tanmatra | 1.2.1 | Atomic physics |
| ushma | 1.3.0 | Thermodynamics |

### Binaries & Tools (13 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| [agnos](https://github.com/MacCracken/agnos) | 1.31.7 | AGNOS kernel (Cyrius-native, ELF64 + sovereign UEFI handoff via gnoboot v0.4.2). **MVP gate cleared on iron at Attempt 68 (1.30.9); storage arc closed 1.31.6 at Attempt 90 (2026-05-22) — five iron debuts (NVMe @ 80 / SATA @ 81 / USB MS @ 87 / RAM-disk+VirtIO @ 88 QEMU + iron no-regression / ext4 @ 90 partition-aware-on-NVMe).** 1.31.x = storage arc (NVMe Phase 1-5 + AHCI/SATA Phase 1-4 + USB MS BBB+SCSI Phase 1-2.8 + RAM-disk + VirtIO 1.x modern + GPT Phase 1-3 with CRC32 + backup-header + type-GUID classifier + 5-backend block-layer dispatch with multi-backend probe + partition-aware mount + ext2/ext4 read-only Phase 1-5). **Cyrius pin lifted 5.11.64 → 6.0.1 mid-1.31.x cycle.** 1.31.7 OPEN 2026-05-22 (filesystem follow-ups + shell UX: `ls -la` flag dispatch + bare-name `cat` ext2 fall-through + `cd`/`pwd`/CWD scoping + ext4 64BIT Phase 5; 4/5 code bites landed; Attempt 91 PENDING). |
| [agnoshi](https://github.com/MacCracken/agnoshi) | 1.3.3 | AI shell (Cyrius) — depends on hoosh, daimon. Cyrius pin lifted 5.10.44 → 6.0.1 mid-1.31.x cycle (followed agnos in the MVP-path graduation pair). |
| [argonaut](https://github.com/MacCracken/argonaut) | 1.7.1 | Init system library (Cyrius) — depends on agnosys. v1.7.0 adds BOOT_MINIMAL agnoshi-as-no-deps-console-service (unblocks closed-beta MVP without aethersafha). |
| [bannermanor](https://github.com/MacCracken/bannermanor) | 1.0.0 | `figlet`-equivalent ASCII-art banner generator (binary `bnrmr` — vowel-dropped per the `commandress`→`cmdrs` compression pattern). English-wordplay naming lane. Drives login MOTDs, script intros, splash text. **Graduated to v1.0+ 2026-05-20 PM** — CLI flag surface, CYML font format (schema=1), and default in-tree font set (block / slim / big) all frozen as the v1.0 contract. Drove the 2026-05-20 darshana 0.3.0 → 0.3.5 color-primitives bump (banner colors). Cyrius pin 6.0.1. Consumers: end-user shells; agnoshi MOTD; iam (logo rendering); darshana, mihi. |
| [commandress](https://github.com/MacCracken/commandress) | 1.0.1 | Structured shell prompt renderer for agnoshi, bash, and zsh via per-shell adapters. Sovereign-stack equivalent of starship, in Cyrius. Binary name `cmdrs` (short for *commandress*). Stateless, segment-based, config-driven, zero non-stdlib deps. **Graduated to v1.0+ 2026-05-18** — segment renderer + config layer stabilized after the 2026-05-15 scaffold. Cyrius pin 5.11.64. Consumers: agnoshi, bash, zsh (prompt-hook adapters). |
| [cyim](https://github.com/MacCracken/cyim) | 1.7.1 | Sovereign modal text editor (Cyrius-native, VIM-inspired, zero attack surface, no embedded scripting). Consumes vyakarana + niyama (regex via stdlib fold v5.9.0); consumers: agnoshi, aethersafha, daimon-orchestrated agents. |
| [cyim-lsp](https://github.com/MacCracken/cyim-lsp) | 1.5.0 | Language Server Protocol companion to cyim (Cyrius-native). Editor-agnostic LSP backend serving cyim's grammar/regex/symbol surfaces over LSP. |
| [iam](https://github.com/MacCracken/iam) | 1.0.0 | fastfetch/neofetch-equivalent system-info display for login MOTD + screenshot flex. Pure inverse of `whoami` — whoami says who the user is, iam says what the system is. Thin presentation layer over the mihi probe library. **Graduated to v1.0+ 2026-05-20** straight to 1.0.0 on cyrius 6.0.1 — second v6.0.x graduation. English-wordplay/trickster naming lane. Consumes mihi (probe) + darshana (color/TTY). |
| [kriya](https://github.com/MacCracken/kriya) | 1.0.0 | Coreutils-equivalent for AGNOS (Sanskrit क्रिया — *action, operation, verb*). One repo, many small static utilities (`cp`, `mv`, `rm`, `mkdir`, `echo`, `wc`, `find`, `grep`, `xargs`, …) sharing infrastructure. BusyBox-style dispatcher + symlinks per utility. **Graduated to v1.0+ 2026-05-18** after M5 closeout (grep + find + xargs); dispatcher + sovereign-boundary surface stabilized. Sovereign-replacement boundaries: owl owns `cat`, cyim owns `vim`, sit owns `git`, chakshu owns `htop`, agnoshi owns shell builtins; kriya fills the gaps. Cyrius pin 5.11.61. Consumers: agnoshi (PATH lookup), zugot (install-time symlinks). |
| [kybernet](https://github.com/MacCracken/kybernet) | 1.2.2 | PID 1 init binary (Cyrius, 140 tests) — depends on argonaut. v1.2.1 consumer pin bump for argonaut 1.7.0 BOOT_MINIMAL. |
| [nous](https://github.com/MacCracken/nous) | 1.1.2 | Package resolver (Cyrius) |
| [owl](https://github.com/MacCracken/owl) | 1.3.6 | Watchful file viewer — `cat`/`bat` replacement (Cyrius-native, **O**bservant **W**atcher of **L**ines). `-p` byte-identical cat drop-in; decorated mode adds token highlighting + VCS gutter + paging. Consumes vyakarana for tokenization. |

### Stdlib-Folded (2 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| [sandhi](https://github.com/MacCracken/sandhi) | 1.3.5 | Service-boundary layer (HTTP client+server, HTTP/2, streaming, JSON-RPC, service discovery, TLS policy). **Folded into Cyrius stdlib at v5.7.0** as `lib/sandhi.cyr` (vendored byte-identical, 376,037 B / 9,649 lines / 469 fns). Sandhi repo entered maintenance mode per [ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md); subsequent surface patches land via Cyrius release cycle. |
| [niyama](https://github.com/MacCracken/niyama) | 1.0.3 | Regex engines — bre / re2 / pcre / fuzzy / vim. **Folded into Cyrius stdlib at v5.9.0** as `lib/niyama.cyr` (vendored byte-identical, 6,664 lines / 7 modules: posix_classes, unicode_props, bre, re2, pcre, fuzzy, vim). Multi-consumer gate met by cyim (#1) + queued AGNOS bare-metal kernel (#2 → v5.10.x trigger). Public API frozen per [niyama ADR 0010](https://github.com/MacCracken/niyama); fold pattern documented in [niyama ADR 0011](https://github.com/MacCracken/niyama). |

---

## Pre-1.0 (20 crates)

### Near-Stable (v0.5.0+)

| Crate | Version | Description | Key Consumers |
|-------|---------|-------------|---------------|
| [aethersafta](https://github.com/MacCracken/aethersafta) | 0.50.0 | Media compositing — scene graph, capture, HW encoding | aethersafha, tazama |
| [jnana](https://github.com/MacCracken/jnana) | 0.5.0 | Unified knowledge system — offline-accessible corpus | agnoshi, hoosh, daimon |

### In Progress (v0.1.0 - v0.49.x)

| Crate | Version | Description | Key Consumers |
|-------|---------|-------------|---------------|
| [selah](https://github.com/MacCracken/selah) | 0.29.4 | Screenshot capture, annotation, PII redaction | taswir, soorat |
| [cyrius-doom](https://github.com/MacCracken/cyrius-doom) | 0.26.2 | DOOM engine in Cyrius — hardened, 5 CVEs fixed, 2.59ms/frame | standalone game / kernel demo |
| [muharrir](https://github.com/MacCracken/muharrir) | 0.23.5 | Editor primitives — text buffer, undo/redo, command pattern | rasa, tazama, shruti |
| [samvada](https://github.com/MacCracken/samvada) | 0.2.2 | DBus client (Cyrius-native) — C-shim wrapping `sd_bus`, minimal logind subset (`TakeDevice` for DRM master delegation, `Pause`/`ResumeDevice` signals). v1.0 retires the libsystemd shim alongside mabda v4.0's wgpu-native retirement. | mabda (Phase D `gpu_surface_configure_native_logind`) |
| [vani](https://github.com/MacCracken/vani) | 0.9.3 | Audio device I/O — direct ALSA/OSS syscalls (Cyrius-native). Full audio stack (ALSA ioctls, ring buffer, XRUN recovery, mixer). **Vendored into Cyrius stdlib at v5.8.0** as `lib/vani.cyr` (replacing legacy `lib/audio.cyr`); standalone repo continues for direct consumers needing newer surface than the folded snapshot. | shravan, dhvani, naad, jalwa, shruti |
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
| [nyaya](https://github.com/MacCracken/nyaya) | 0.1.0 | Structured legal knowledge — statutes, precedents, IP | hadara, itihas, jnana |
| [darshana](https://github.com/MacCracken/darshana) | 0.5.2 | TTY/raw-mode primitives (Sanskrit दर्शन — *viewing/showing*). Linux termios + ANSI + cursor positioning + alt-screen + color escape sequences (0.3.5, 2026-05-20 — added so bannermanor's banners can render colored). Extracted from cyim's `src/tty.cyr` once chakshu became a second consumer. **Not a TUI framework** — just the syscalls and escape sequences below the framework. | cyim, chakshu, bannermanor |
| [sit](https://github.com/MacCracken/sit) | 0.8.5 | Sovereign version control — Cyrius-native git replacement (smriti, स्मृति — memory). Deps: sankoch (compression), sigil (hashing), patra (object store). No libgit2, no C, no FFI. | end user, owl (git-marker integration), ark |

---

## Binaries & Tools (pre-1.0, 11 entries)

| Binary | Version | Description | Depends On |
|--------|---------|-------------|------------|
| [shakti](https://github.com/MacCracken/shakti) | 0.3.0 | Privilege escalation (`sudo` replacement) | agnosys, sigil |
| [ark](https://github.com/MacCracken/ark) | 0.8.0 | Package manager (Cyrius) | nous, sigil |
| [takumi](https://github.com/MacCracken/takumi) | 0.8.0 | Build system — Cyrius port in progress (toolchain pinned 5.5.23; `rust-old/` authoritative until parity) | sigil |
| [aethersafha](https://github.com/MacCracken/aethersafha) | 0.1.0 | Wayland compositor | aethersafta, mabda |
| [mela](https://github.com/MacCracken/mela) | 0.1.0 | Agent marketplace | daimon, sigil |
| [agnova](https://github.com/MacCracken/agnova) | 0.1.0 | OS installer (Cyrius port from 3,656 Rust lines, base established) | ark, kavach |
| [seema](https://github.com/MacCracken/seema) | 0.1.0 | Edge fleet management | daimon, bote |
| [samay](https://github.com/MacCracken/samay) | 0.1.0 | Task scheduler | szal |
| [chakshu](https://github.com/MacCracken/chakshu) | 0.6.1 | AI-augmented system monitor (Sanskrit चक्षु — *the eye*; binary `shu` — **S**ystem **H**ealth **U**tility, per ADR 0001). Cyrius-native, reads `/proc` directly. Replaces htop/btop Bazaar packages at v1.0; adds AI explanations via daimon/hoosh at M3+. Cyrius pin 6.0.1. | mihi, darshana, sandhi (M3), niyama (M3), daimon (M3) |
| [gnoboot](https://github.com/MacCracken/gnoboot) | 0.4.2 | Sovereign UEFI bootloader (Cyrius-native PE32+ EFI Application, ~33 KB) — replaces GRUB on the AGNOS boot path. Locates kernel at `\boot\agnos`, parses ELF64 program headers, allocates pages as `EfiLoaderCode`, zeroes BSS gap, captures GOP framebuffer + FrameBufferSize, builds 88-byte sovereign boot-info struct (magic `'AGNO'`), calls `ExitBootServices`, jumps with `RDI = &boot_info`. 0.4.x added GOP FrameBufferSize capture + SetMode arc (Attempts 73-74). Pairs with agnos 1.31.x. | agnos (kernel handoff consumer) |
| [hapi](https://github.com/MacCracken/hapi) | 0.7.0 | GNU `stow`-equivalent — dotfile / symlink farm manager. Dual-read name: Hawaiian हपी (*happy*) + **H**ome **A**sset **P**rovisioning **I**nterface. First Pacific Islands word in the AGNOS naming surface. CYML manifest per package, capability-bounded execution (`$HOME` only by default), lightweight audit trail. | end-user shells; possibly agnova for dotfile bootstrap; mihi |
| [kii](https://github.com/MacCracken/kii) | 0.1.0 | `chafa` / `jp2a` / `viu`-equivalent — image → ANSI/ASCII-art converter for terminal display. **Four-layered name** across three language families: (1) **Hawaiian** *image / picture / likeness* — what the tool produces; (2) **East Asian** *ki* (気) / *chi* (氣) — life-force / vital energy: kii is the *ki of the terminal*, the animating force that brings the screen to life via images; (3) **English-phonetic** — back-half of **a-scii** — what the tool emits; (4) **functional convergence** — produces images via ASCII to animate the terminal, all three language angles describe the same operation. Rare triple-lane crossover: Polynesian-direct semantic + East Asian metaphysical + English-phonetic-wordplay all fit because they describe the same function. Reads raster input (PNG, JPEG, GIF, BMP planned), quantizes to terminal-renderable color palette + glyph set, emits ANSI escape sequences sized to terminal cols × rows. Polynesian Hawaiian micro-cluster with `hapi`, `anuenue`. Cut at 0.1.0 on cyrius 6.0.1 (2026-05-22). | bannermanor (logo rendering inside ASCII-art banners); iam (system splash images); future BBS MOTD pipeline; future MUD room-illustration renderer; `anuenue` (image → ASCII → rainbow-tint chain) |

---

## Non-Library Projects

| Project | Version | Description | Key Consumers |
|---------|---------|-------------|---------------|
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
| cyrius-rampage *(not scaffolded — slug + title provisional; details TBD)* | — | **Giant-monster city-destruction action game in Cyrius.** Mechanical homage to *Rampage* (Bally Midway, 1986 — vertical climb-and-smash, building-collapse physics, 2–3-player monster co-op as the defining hook) with a meta-narrative layer riffing on *Wreck-It Ralph* (Disney, 2012 — destroyer-as-protagonist inversion). **Midway / Disney IP hard-excluded** — original monsters, original city setting, original score; mechanics-and-archetype-only homage. Sits naturally in the same 2D sprite/state lane as cyrius-nba-jam / cyrius-grapevine / cyrius-chelly-beach-dash — tooling investment compounds. Concept dropped 2026-05-15 (lunch-break observation: a Rampage-themed slot machine in a streaming session triggered the riff). | standalone game |
| cyrius-block-game *(not scaffolded — slug + title provisional; 3D lane; default to Path A at scaffold time)* | — | **Block-survival / mine-and-craft entry in the catalog. Default path = Path A (original-IP homage); Path B kept as a fallback fork.** **Path A — original-IP homage with cubist / voxel aesthetic** (mechanical-only AND visual-style-only homage; both layers IP-safe. **Visual style is not copyrightable** — the cubist / voxel / blocky aesthetic is a geometric primitive, not an expressive work — so the cube-world look IS the lane and stays. What IS hard-excluded: Microsoft/Mojang's *expressive elements* — no Creeper / Steve / Enderman / Zombie-Pigman / etc.; no "Minecraft" branding; no signature texture designs; no biome names or world-gen specifics from Mojang's catalog. Original mob roster + original block textures + original setting. Block-survival has pre-Mojang precedent — *Infiniminer* (Zachtronics, 2009) is the most-cited mechanical ancestor; *Dwarf Fortress* (Bay 12, 2006) and *Wurm Online* (Mojang predecessor, 2003) seeded the design space; living examples that ship under exactly this framing: Minetest (LGPL), Vintage Story (commercial), Cuberite (server-only) — none of them are in Microsoft's crosshairs. So Path A IS safe and gets the green light at scaffold time). **Path B — clean-room Java port (fallback only)**: explicitly NOT the cyrius-doom path because Mojang has not open-sourced Minecraft Java (id Software open-sourced DOOM 1.9 in 1997 → GPL-licensable; Mojang has not). Path B's only IP-safe form is clean-room reimplementation reading runtime behavior, NOT copying decompiled code. Kept as a fork in case a specific Java-edition compatibility goal surfaces later (e.g., reading existing `.mcworld` saves, networking with vanilla servers); otherwise Path A subsumes it. Sits in the 3D lane alongside cyrius-mine-cart; depends on **kiran** (game engine) + **joshua** (game manager + AI sim runtime), both post-boot work. **Concept dropped 2026-05-22** (post-1.31.7 close); **Path A endorsed same-day** ("cubist style isn't copyrighted so we're safe"). | standalone game |
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

### Terminal-aesthetics quintet (proposed 2026-05-18; 4 of 5 shipped by 2026-05-20)

Five Cyrius-native tools covering the daily-driver shell experience — prompt, file listing, dotfile placement, banner output, system identity. Together with `commandress` (1.0.0, in `Binaries & Tools`), they form a coherent personal-computing aesthetics layer for AGNOS. Each lives as a standalone repo when scaffolded.

**Shipped**: `mihi` 1.0.0 (v1.0+ OS & Infrastructure), `iam` 1.0.0 (v1.0+ Binaries & Tools), `bannermanor` 1.0.0 (v1.0+ Binaries & Tools — graduated 2026-05-20 PM), `hapi` 0.5.0 (pre-1.0 Binaries & Tools) — see those sections above for current entries. Brainstorm captured in `~/.claude/projects/-home-macro-Repos-agnosticos/memory/project_tools_stable_ideas.md`.

**Still planned**:

| Crate | Description | Key Consumers |
|-------|-------------|---------------|
| **darshini** | `eza`-equivalent — pretty file listing with colors, icons, git-status column, tree view, mime-type recognition. Sanskrit: दर्शिनी (*she who shows/displays*). Sibling-not-competitor to `kriya`'s minimal `ls` — different aesthetic goals, both ship. Consumes `darshana` (TTY/ANSI primitives) as rendering substrate. | end-user shells; chakshu (potentially, for monitor-style file panes) |

### Network-tools family (proposed 2026-05-20)

Network observability tools — `ping`/`traceroute`/`dig`/`curl` territory. Each lives as a standalone repo (NOT in `kriya`; kriya is coreutils-strict, ping etc. are iputils/inetutils-family across every distro). Sanskrit/Hindi-named substrate library, English-wordplay-named user-facing tools, per `feedback_naming_lanes`. First tool drives the library; second consumer triggers the extraction per the `mihi → iam/chakshu` pattern.

| Crate | Description | Key Consumers |
|-------|-------------|---------------|
| **yo** | `ping`-equivalent — *Yodel-Out*. ICMP echo request across the network valley, awaiting return-call. Man-page conceit: *"Like a yodel across an Alpine valley, yo sends a small call into the network and waits for the return. The time between the call and the answer is the measure of the path between you and the host."* English-wordplay/trickster lane (cmdrs / bnrmr / iam / hapi). Iron LAN support gated on r8169 / Intel NIC driver (was 1.31.x = networking, displaced by storage). QEMU + localhost works as soon as kernel ICMP egress lands. | end-user shells; future net-diagnostics scripts |
| **whirl** | `curl + wget` unified — HTTP / HTTPS / file transfer in one verb. Man-page conceit: *"The packet whirls out; the response whirls back. Merges the historical curl + wget split; one verb for one fundamental network operation."* Smart-default behavior: auto-detect download-to-file (binary) vs print-to-stdout (text), follow redirects, recursive fetch (`-r`, the wget side), POST (`-d`), arbitrary methods (`-X`). One tool, combined feature set, no curl-vs-wget mental tax. English-wordplay lane. | end-user shells; download scripts; ark/zugot fetch paths long-term |
| **dig** | DNS resolver — name kept from upstream BIND `dig`. Cultural double-anchor: mechanically *Domain Information Groper* (the upstream meaning), but the AGNOS-side joke is *Cyrus from The Warriors (1979) — "Can you dig it?"* — consonant with **Cyrius** the language. Same triple-layer reading as `t-ron` (security daemon / Bruce Boxleitner / *fights for the users*). English-wordplay lane via the cultural-reference path, not the abbreviation path. Surface: A / AAAA / MX / TXT / NS / CNAME / SOA / SRV queries, `+short` / `+trace` / `+tcp` / `+dnssec` flag aesthetics from upstream. | end-user shells; whirl (for hostname resolution path); future net-diagnostics scripts |
| **taar** | Network-probe substrate library — ICMP send/recv, socket primitives, DNS resolution, raw packet construction, HTTP client primitives, TLS handshake hooks. Hindi/Sanskrit तार (*wire/string/connection*). With **three** named consumers in the same brainstorm window (yo / dig / whirl), there is no "extract on second consumer" gate to wait on — `taar` is a real lib from network-tools cycle open, scoped to ICMP + sockets + DNS + TCP + TLS + HTTP-client from the start. Its surface area maps to the union of the three tools' needs. | yo, dig, whirl (all three); future yodel-trail / etc. |

### Archive-and-storage-tools family (proposed 2026-05-20, mid-1.31.x storage arc)

User-facing CLI for archive / compressed-file handling. Substrate is the already-shipped `sankoch` stdlib (LZ4 / DEFLATE / zlib / gzip), so this is the "shell usage" of that lib — same producer/consumer shape as the terminal-aesthetics tools-over-`darshana`, or `iam`-over-`mihi`. Sanskrit naming for the tools fits because the artifacts carry rich double-meanings (vehicle / mount → archive carrier).

| Crate | Description | Key Consumers |
|-------|-------------|---------------|
| **vahana** | `tar`-replacement and one-verb archive tool — Sanskrit वाहन (*vehicle / mount / conveyance*). Triple-layer reading: mechanical (carries files), mythological (every deity's vahana is their mount — Garuda for Vishnu, Nandi for Shiva), and language-internal (the verb of carrying across formats). Surface: produces / extracts `tar` (POSIX ustar / GNU / pax) **plus** `zip` / `cpio` / `ar` (Debian) / `7z` / single-stream `.gz` / `.xz` / `.zst` / `.lz4`. One CLI verb for one fundamental operation (pack, unpack, list, append), with format auto-detected on extract and chosen by extension or flag on pack. Same shape-of-thinking as `whirl` (one verb collapsing curl+wget) — collapse the tar/zip/cpio/7z UI tax into a unified surface. Compression layer delegates entirely to `sankoch`; archive-container layout is vahana's responsibility. **Binary name (undecided 2026-05-20):** candidates `vhn` (vowel-dropped, matches the `cmdrs` / `bnrmr` compression pattern) and `vah` (front-syllable, mirrors how `darshini` reads vs full `vahana`). User to decide at scaffold time. | end-user shells; `ark` / `zugot` (package fetch + unpack paths); long-term any subsystem that writes/reads archives |

> **Why this matters for AGNOS specifically.** `tar` is the lingua franca of Unix software distribution — every source release, every Docker layer, every CI artifact, every Debian/RPM payload travels in some `.tar.*` shape. AGNOS shipping its own native archiver is *necessary*, not optional, the moment package distribution becomes real. The collapse-many-formats-into-one-verb framing is the AGNOS-side ergonomics win, not the gating concern.

> **AGNOS-native compression composition channel.** Once `vahana` is the shell-level archive surface and `sankoch` is the codec substrate, the pair becomes the natural channel for AGNOS-native compression formats: compose new compression schemes from sankoch's primitives (or new primitives added to sankoch), distribute the resulting algorithm through vahana. Same idiom as `cyrius.cyml` (AGNOS's own manifest format alongside existing ones) — interop with the world's formats *and* ship AGNOS's own where divergence has a reason. Not a v1 deliverable; the design space the v1 architecture has to leave room for.

### Pipe-decorator family (proposed 2026-05-21)

Stdin → stdout aesthetic / transform filters. Composable into any shell pipeline; each is a pure-filter consumer of `darshana` (ANSI color + cursor positioning) or related rendering substrate. Distinct family from terminal-aesthetics tools (those produce their own output); pipe-decorators only transform what passes through them.

| Crate | Description | Key Consumers |
|-------|-------------|---------------|
| **anuenue** | `lolcat`-equivalent — rainbow-tint stdin → stdout, per-character HSV cycling, optional animation flag (`-a`). Hawaiian ānuenue (*rainbow*); second Pacific Islands name in the AGNOS naming surface after `hapi`. Direct-semantic non-English lane (vs the English-wordplay default for user-facing tools). Pure pipe filter — `iam \| anuenue`, `bnrmr "AGNOS" \| anuenue`, `kriya cat README.md \| anuenue`. Consumes `darshana` as ANSI color substrate. Binary name (undecided at capture): full `anuenue` (matches `darshini` precedent) or `anue` (front-syllable, mirrors the `vahana → vah` candidate shape). | end-user shells; agnoshi MOTD pipeline; iam / bannermanor display chains; demo / streaming flair |

---

## Extraction Guidelines

Extract when **3+ projects** implement the same pattern. Until then, keep it in-project.

- You're copying a module between repos
- Two projects have different implementations of the same algorithm
- A bug fix in one project should automatically benefit another

See [monolith-extraction.md](../../archive/monolith-extraction.md) (archived 2026-05-12) for the daimon/hoosh/agnoshi extraction plan.

See [k8s-roadmap.md](../vision/architecture/k8s-roadmap.md) for stiva + nein + majra + kavach orchestration platform.

---

*Last Updated: 2026-05-22 (kii 0.1.0 scaffold added — image→ANSI/ASCII converter, Hawaiian Polynesian micro-cluster with hapi + anuenue; post-Attempt-92 r8169 PARTIAL + DHCP gate fix landed in agnos 1.32.0 main.cyr:655; agnos 1.31.7 closed 2026-05-22 / 1.32.0 opened same day for networking arc). Earlier 2026-05-20 PM context: bannermanor + iam + mihi graduated to v1.0+; agnos 1.31.2 / agnoshi 1.3.3 pin-graduations to cycc 6.0.1; gnoboot 0.4.2.*
