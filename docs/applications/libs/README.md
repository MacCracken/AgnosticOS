# AGNOS Shared Libraries — Released (v1.0+)

> Reusable library crates that form the AGNOS stack. Consumer [applications](../README.md) depend on these — they should never depend on external libraries when an AGNOS crate covers the domain.
>
> **82 libraries at v1.0+** (80 standalone + 2 stdlib-folded: sandhi v5.7.0, niyama v5.9.0; **yantra 1.0.0 graduated 2026-06-18** — UI automation lib; **ganita + bayan added 2026-06-14**; aegis 1.0.0 graduated from pre-1.0 during v5.10.x; **mihi 1.0.0 graduated 2026-05-20** as system-info probe substrate for the terminal-aesthetics cohort) — pre-1.0 libs tracked in [development/planning/](../../development/planning/README.md). Binary tools at v1.0+ (agnos, agnoshi, agora, argonaut, **ark**, **bannermanor**, **commandress**, cyim, cyim-lsp, **darshini**, hapi, **iam**, kii, **kriya**, kybernet, **mela**, nous, owl, **sit**, **takumi**) are listed separately in the [full registry](../../development/planning/shared-crates.md#binaries--tools-20-crates). **2026-05-20 cohort**: mihi 1.0.0 (OS & Infrastructure, probe lib), iam 1.0.0 (Binaries & Tools, fastfetch-equivalent), bannermanor 1.0.0 (Binaries & Tools, figlet-equivalent — graduated PM after CLI surface + CYML font format + default font set frozen).
> Full registry: [Shared Crates Registry](../../development/planning/shared-crates.md) — that doc is the authoritative source; refresh from there.
>
> **Last Updated**: 2026-06-23 (**version-drift sweep** against local `VERSION` files, in lockstep with the [full registry](../../development/planning/shared-crates.md) — no new v1.0 graduations (every v1.0+ crate already documented here; tarka 1.0.0 stays a Non-Library reference binary by design). OS/Infra bumps: mabda 3.0.2→**3.4.4** · sigil 3.7.13→**3.9.2** · kavach 3.4.1→**3.5.2** · libro 2.7.3→**2.7.7** · patra 1.11.2→**1.12.3** · sankoch 2.3.1→**2.4.4** · sakshi 2.3.0→**2.4.1** · nein→1.5.4 · bote→2.7.6 · daimon→1.2.9 · hoosh→2.4.6 · majra→2.4.7 · t-ron→2.1.6 · ai-hwaccel→2.3.12 · yukti→2.2.6 · bayan→1.0.2 · agnostik→1.3.1; Science: abaco→2.3.0 · avatara→2.7.2 · hadara 1.0.0→**1.1.0** · hisab→2.6.6 · itihas→2.3.5; Graphics: bsp→1.1.4; Language: varna 1.0.0→**2.0.0**. Prior 2026-06-19 (**graduated-doc relocation**: moved the per-crate docs for **aegis / ark / mela / takumi** out of the old `docs/development/os/` planning area into this `libs/` tree, and renamed **agnosys.md → agnodrm.md** for the decomposition. ✅ Authored those 16 missing stubs the same day — agnostik, bayan, ganita, mihi, yantra + agora, bannermanor, commandress, cyim, cyim-lsp, darshini, hapi, iam, kii, kriya, sit — and removed the stale `os/nous` + `os/phylax` duplicates: **every graduated crate now has a doc in `libs/`.** Prior 2026-06-18: relocated the 4 v1.0 graduations from the development registry's pre-1.0 sections into the application area: **yantra 1.0.0** added here as an OS & Infrastructure lib; **ark / mela / takumi 1.0.0** added to the binary-tools pointer line — they live in the [full registry](../../development/planning/shared-crates.md#binaries--tools-20-crates). Prior 2026-06-14: full local-VERSION sweep — OS/Infra + Science + Language lib bumps synced to the 6.0→6.2 cyrius arc; **ganita + bayan added** as v1.0+ libs; binary-tools pointer refreshed for the sit + darshini graduations. GitHub-only science/media/physics libs not in the local clone left as-is. Prior 2026-06-04: version columns re-synced to the VERSION files — 17 stable-crate bumps. Prior 2026-05-22: post-1.31.6 close drift sweep.)

See also: [First-Party Standards — Own the Stack](../../development/first-party/first-party-standards.md#own-the-stack) | [Science Crate Specs](../../development/guides/science-crate-specs.md)

---

## OS & Infrastructure (28)

| Crate | Version | Domain |
|-------|---------|--------|
| aegis | 1.1.0 | Security daemon — absorbed agnosys's PAM at 1.1.0 (agnos → agnodrm decomposition) |
| agnosai | 1.1.0 | AI orchestration |
| agnostik | 1.3.1 | Shared types & domain primitives (Cyrius, GitHub-release only) |
| agnodrm | 1.4.4 | Device / DRM model — udev + DRM/KMS (was **agnosys**; decomposed 2026-06-19: trust→sigil, sec/mac/audit→kavach, pam→aegis, logging→sakshi, syscall layer→cyrius) |
| ai-hwaccel | 2.3.12 | GPU detection |
| bayan | 1.0.2 | Data-format & big-integer distfile — json/toml/cyml/csv/base64/bigint/u128 (foldable per sandhi pattern) |
| bote | 2.7.6 | MCP core (~5us/message, streamable HTTP) |
| daimon | 1.2.9 | Agent orchestrator (144 MCP tools) |
| hoosh | 2.4.6 | LLM gateway (15 providers) |
| ifran | 1.3.0 | LLM inference/training |
| kavach | 3.5.2 | Sandbox execution — absorbed agnosys's security (Landlock/seccomp) + mac + audit at 3.5.0 (decomposition) |
| libro | 2.7.7 | Cryptographic audit chain |
| mabda | 3.4.4 | GPU foundation — consumes chitra for image decode; exposes the GPU compute surface attn11/puka build on |
| majra | 2.4.7 | Queue/pub-sub |
| mihi | 1.1.0 | System-info probe library (CPU / RAM / GPU / kernel / uptime / distro / hostname) — substrate for iam, chakshu |
| nein | 1.5.4 | Programmatic nftables firewall |
| patra | 1.12.3 | Structured storage & SQL — B+ tree, WAL (Cyrius-native) |
| phylax | 1.2.1 | Threat detection — YARA, entropy, magic bytes, ML |
| sakshi | 2.4.1 | Tracing, error handling, structured logging (Cyrius-native) |
| sankoch | 2.4.4 | Lossless compression — LZ4, DEFLATE, zlib, gzip |
| sigil | 3.9.2 | Trust verification & crypto — AES-NI + SHA-NI hardware accel (TLS 1.3 live-verified); absorbed agnosys's trust stack at 3.9.0 (decomposition) |
| soorat | 1.0.0 | GPU rendering |
| stiva | — | Container runtime — **Rust-era scaffold; Cyrius port pending** (GitHub remote `MacCracken/stiva` last pushed 2026-04-29) |
| szal | 2.0.0 | Workflow engine — step/flow/DAG + branching/retry/rollback. **Cyrius-native (2.0.0 = Rust → Cyrius port graduation)** |
| t-ron | 2.1.6 | MCP security |
| vidya | 2.7.3 | Programming reference |
| yantra | 1.0.0 | Sovereign UI automation (Cyrius library) — browser + mobile; `.tcyr` files include `lib/yantra.cyr` and drive Chromium / Firefox / WebKit / Android / iOS. `cyrius test` stays the runner (not a framework). Graduated 2026-06-18 |
| yukti | 2.2.6 | Device abstraction (USB, block, udev) |

## Science & Knowledge (28)

| Crate | Version | Domain |
|-------|---------|--------|
| abaco | 2.3.0 | Math engine |
| avatara | 2.7.2 | Divine archetype overlay |
| ganita | 1.0.1 | Linear algebra (matrix, linalg) + advanced math (transcendental + number theory); foldable per sandhi pattern |
| badal | 1.1.0 | Weather/atmosphere |
| bhava | 2.0.0 | Emotion/personality |
| bijli | 1.1.0 | Electromagnetism |
| bodh | 1.0.0 | Psychology |
| brahmanda | 1.0.0 | Galactic cosmology |
| dravya | 1.2.0 | Material science |
| falak | 1.0.0 | Orbital mechanics |
| hadara | 1.1.0 | Culture modeling (Cyrius-native, 50 cultures) |
| hisab | 2.6.6 | Higher math |
| hisab-mimamsa | 1.0.0 | Theoretical physics |
| itihas | 2.3.5 | World history |
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
| bsp | 1.1.4 | BSP geometry (Cyrius-native) |
| kiran | 1.0.0 | Game engine (ECS, scene hierarchy) |
| ranga | 1.0.0 | Image processing (color, blend, GPU compute) |

## Language & Navigation (3)

| Crate | Version | Domain |
|-------|---------|--------|
| raasta | 1.0.0 | Pathfinding |
| varna | 2.0.0 | Multilingual language engine |
| vyakarana | 2.2.3 | Source-code grammar + tokenizer (Cyrius-native, ten-kind palette, CYML grammars) |

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
