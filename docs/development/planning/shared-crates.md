# Shared Crates — Registry & Status

> **Status**: Active | **Last Updated**: 2026-06-14 (**full sweep against local VERSION files — 80 repos, ~40 row changes**). The 1.41→1.45 kernel arc + cyrius 6.0→6.2 drift synced: **agnos 1.43.2 → 1.45.4** (net-syscall arc #45-#55), **agnoshi 1.4.5 → 1.7.0** (kriya/owl delegation + `&` jobs + env), **owl 1.3.6 → 1.4.0** (bat-like + sit VCS gutter; agnos-compile blocked on the sit→tls chain), **kriya → 1.1.4**, **agora 1.2.0 → 1.4.2**, plus OS/Infra bumps (sigil 3.7.13, hoosh 2.4.5, patra 1.11.2, daimon 1.2.8, szal → 2.0.0, …). **New rows added:** `ganita` 1.0.1 + `bayan` 1.0.1 (v1.0+ libs), `rosnet` + `tyche` 0.1.0 (pre-1.0 libs, attn11 extractions). **Graduations:** `sit` 0.8.5 → **1.0.1** (pre-1.0 → v1.0+ Binaries); `darshini` 1.2.0 (terminal-quintet "planned" → v1.0+ Binaries — quintet now 5/5); `yo` 0.5.2 + `dig` 0.3.0 (network-tools "planned" → scaffolded pre-1.0 Binaries, consuming agnos #55 / #51-54); MUD `cyrius-yeomans-descent` 0.0.x → 1.0.1; `thoth` 0.3.0 → 0.6.3; `attn11` → 1.6.4. **Left as-is (can't verify locally):** the GitHub-only science/media/physics libs not in the local clone set, and `encom-hits` (forward-only — registry 1.0.0 ≥ local 0.6.1). Prior 2026-06-13 (**attn11 0.5.1 → 1.4.3** — registry was a full major behind. Now reflects the 1.x sequence-mixer arc: MoE top-K router + Switch aux (1.3.0), gated-linear/RetNet (1.4.0), selective SSM/Mamba-lite (1.4.2), per-layer hybrid `--attn-every K` (1.4.3), all hand-derived-backprop + finite-difference grad-checked; byte-level+BPE tokenizer; checkpoint v6; **857 checks** on x86_64+aarch64; **trains on the AGNOS kernel in ring 3** (50 steps, checkpoint bit-identical to native); cyrius pin 6.1.6 → **6.2.2**. Extraction-to-libs row's v1.0 timing gate is now MET — attn11 is in its 1.x extract/re-fold window. Prior 2026-06-08: **attn11 0.5.1 added** — from-scratch *trained* GPT-style transformer in Cyrius, the ecosystem's ML/training reference; → Non-Library Projects + a new **6.1.6** leading-edge pin band in state.md + the CLAUDE.md Standalone Repos table; **agora 1.0.0 → 1.2.0** — door-games subsystem (1.1.0) + Persistent Universe shared-world multiplayer (1.2.0; three door games PA/Smuggler/The Handler, cross-game leaderboards, pin → 6.1.5); 1.3.0 Eliza+chat & 1.4.0 `descent`-door-to-MUD planned). Prior 2026-06-07 (doc sweep — agnos→1.43.2, agnoshi→1.4.5 + verb_abspath ls fix, anuenue shipped 1.1.1 w/ positional-text mode, gnoboot refs→0.5.0. Prior 2026-06-04: **full version + membership reconciliation against the VERSION files.** (1) **Plain-format rows synced** — 17 bumps incl. sigil 3.7.2 / kavach 3.4.0 / libro 2.7.1 / avatara 2.7.0 / hisab 2.6.5 / mabda 3.0.1. (2) **Linked `[name](url)` rows synced** — 18 more (the prior sync had missed them), incl. agnos 1.41.11 / kybernet 1.3.3 / argonaut 1.8.2 / sandhi 1.4.1 / gnoboot 0.5.0 / cyrius-doom 0.27.5 / samvada 0.4.0 / yantra 0.6.2; **forward-only** (a stale local checkout can't downgrade the registry). (3) **Membership:** `agora` 1.0.0 added (BBS → v1.0+ Binaries); `hapi` 1.0.1 + `kii` 1.0.0 **graduated** pre-1.0 → v1.0+ Binaries; section counts updated (v1.0+ index 89→92, v1.0+ binaries 13→16, pre-1.0 binaries 11→9). **Residuals (flagged, not auto-fixed):** encom-hits registry 1.0.0 > local checkout 0.6.1 (left as-is — local likely behind GitHub); a few In-Progress rows are now ≥0.5.0 (yantra 0.6.2, darshana 0.5.3, sit 0.8.5) and belong in Near-Stable; `secureyeoman` (a Rust/TS product *consuming* AGNOS crates, AGPL) is intentionally not rowed here. Prior 2026-05-26: cyrius-polyomino 0.1.0 scaffold added.)
>
> **~129 entries** — 98 at v1.0+ stable (79 libs + 17 binaries + 2 stdlib-folded — **ganita + bayan** joined libs 2026-06-14; **sit + darshini** graduated to binaries 2026-06-14; `mihi` joined libs as system-info probe substrate; `iam` + `bannermanor` joined binaries; **agora** + graduated **hapi** + **kii** added 2026-06-04 — + **2 stdlib-folded**; aegis 1.0.0 graduated v5.10.x; **kriya 1.0.0** + **commandress 1.0.0** graduated 2026-05-18; **mihi 1.0.0 + iam 1.0.0** graduated 2026-05-20 morning; **bannermanor 1.0.0** graduated same day PM after CLI surface + CYML font format + default font set frozen as the v1.0 contract), **21 pre-1.0 libs** (+ rosnet + tyche 2026-06-14, − sit graduated), **13 pre-1.0 binaries/tools** (+ yo + dig 2026-06-14; gnoboot 0.5.0; **hapi 1.0.1 + kii 1.0.0 graduated to v1.0+ Binaries 2026-06-04**), 10 non-library (cyrius-polyomino added 2026-05-26; note: this headline count drifts — the Non-Library Projects table itself now holds 15 rows — 14 games + **attn11**, the first non-game there, an ML/training reference), **2 planned** (krishi + prakriti + darshini — terminal-aesthetics quintet shipped 4 of 5 by 2026-05-20 PM; only darshini queued), plus the Audio I/O / Video Codec / GitHub-only sub-sections (overlap with the v1.0+/pre-1.0 counts above where applicable).
>
> **Classification rule**: pre-v1.0 crates are tracked in [`docs/development/planning/`](README.md). v1.0+ stable crates have their docs in [`docs/applications/libs/`](../../applications/libs/) (libraries) or [`docs/applications/`](../../applications/) (consumer apps).
> See [First-Party Standards](first-party-standards.md) for versioning and publishing conventions.

---

## v1.0+ Stable Index (98 entries)

Full documentation for each library: [docs/applications/libs/](../../applications/libs/README.md). Consumer apps live one level up at [docs/applications/](../../applications/README.md).

### OS & Infrastructure (27 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| aegis | 1.0.0 | Security daemon — graduated from pre-1.0 in the v5.10.x window |
| agnosai | 1.1.0 | AI orchestration |
| agnostik | 1.3.0 | Shared types & domain primitives (Cyrius, GitHub-release only) — foundation for all AGNOS crates |
| agnosys | 1.4.2 | Kernel interface — Landlock, seccomp, syscall bindings (Cyrius, GitHub-release only) |
| ai-hwaccel | 2.3.9 | GPU detection |
| bayan | 1.0.1 | Data-format & big-integer distfile — json / toml / cyml / csv / base64 / bigint / u128. Foldable into stdlib per the sandhi pattern. Consumed by owl (and any crate parsing structured data). |
| bote | 2.7.5 | MCP core (~5us/message, streamable HTTP) |
| daimon | 1.2.8 | Agent orchestrator (144 MCP tools, GitHub-release only) |
| hoosh | 2.4.5 | LLM gateway (15 providers) |
| ifran | 1.3.0 | LLM inference/training |
| kavach | 3.4.1 | Sandbox execution |
| libro | 2.7.3 | Cryptographic audit chain |
| mabda | 3.0.2 | GPU foundation |
| majra | 2.4.6 | Queue/pub-sub |
| mihi | 1.1.0 | System-info probe library (CPU / RAM / GPU / kernel / uptime / distro / hostname). Sanskrit-Hindi/Polynesian semantic lane (Maori: formal self-introduction ceremony). Substrate for iam, chakshu, and any tool that needs "tell me about this box." First of the 2026-05-20 v6.0.x graduations cut. |
| nein | 1.5.2 | Programmatic nftables firewall |
| patra | 1.11.2 | Structured storage & SQL — B+ tree, WAL (Cyrius-native) |
| phylax | 1.2.0 | Threat detection — YARA, entropy, magic bytes, ML |
| sakshi | 2.3.0 | Tracing, error handling, structured logging (Cyrius-native) |
| sankoch | 2.3.1 | Lossless compression — LZ4, DEFLATE, zlib, gzip |
| sigil | 3.7.13 | Trust verification & crypto — AES-NI + SHA-NI hardware accel (TLS 1.3 live-verified) |
| soorat | 1.0.0 | GPU rendering |
| stiva | — | Container runtime — **Rust-era scaffold; Cyrius port pending** (GitHub remote `MacCracken/stiva` last pushed 2026-04-29; no version pin until ported) |
| szal | 2.0.0 | Workflow engine — step/flow execution with branching, retry, rollback, DAG + parallel stages. **Cyrius-native — the 2.0.0 major bump is the Rust → Cyrius port graduation** (the newest crate to graduate; the Rust 1.x line is historical). |
| t-ron | 2.1.5 | MCP security |
| vidya | 2.7.3 | Programming reference |
| yukti | 2.2.5 | Device abstraction (USB, block, udev) |

### Science & Knowledge (28 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| abaco | 2.2.4 | Math engine |
| avatara | 2.7.1 | Divine archetype overlay |
| ganita | 1.0.1 | Linear algebra (matrix, linalg) + advanced math (transcendental + number theory). Foldable into stdlib per the sandhi pattern. |
| badal | 1.1.0 | Weather/atmosphere |
| bhava | 2.0.0 | Emotion/personality |
| bijli | 1.1.0 | Electromagnetism |
| bodh | 1.0.0 | Psychology |
| brahmanda | 1.0.0 | Galactic cosmology |
| dravya | 1.2.0 | Material science |
| falak | 1.0.0 | Orbital mechanics |
| hadara | 1.0.0 | Culture modeling (Cyrius-native, 50 cultures) |
| hisab | 2.6.5 | Higher math |
| hisab-mimamsa | 1.0.0 | Theoretical physics |
| itihas | 2.3.4 | World history |
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
| vyakarana | 2.2.3 | Source-code grammar + tokenizer (Cyrius-native, ten-kind palette, CYML grammars) |

### Physics & Engineering (6 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| impetus | 1.3.0 | Physics |
| pavan | 1.1.0 | Aerodynamics |
| prakash | 1.2.0 | Optics/light |
| pravash | 1.2.0 | Fluid dynamics |
| tanmatra | 1.2.1 | Atomic physics |
| ushma | 1.3.0 | Thermodynamics |

### Binaries & Tools (17 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| [agnos](https://github.com/MacCracken/agnos) | 1.45.4 | AGNOS kernel (Cyrius-native, ELF64 + sovereign UEFI handoff via gnoboot). Cyrius pin 6.0.56. **Iron-validated on archaemenid (real Zen)** through boot-to-shell with a live multi-command keyboard. Arc history: MVP boot-to-shell (1.30.9) → storage (1.31.x: NVMe/AHCI/USB-MS/RAM-disk/VirtIO + GPT + 5-backend block dispatch) → networking (1.32.x: r8169 GbE + ARP/IPv4/UDP/TCP + DHCP) → ext2/4 + FAT/exFAT write (1.33-34) → comms substrate (1.35: DNS/ICMP/NTP/RTC/mmap) → exec-from-disk + VFS routing (1.40) → **shell→agnoshi** (1.41, iron burn `14115`) → perf + sysinfo/klug (1.42) → graphics + DOOM (1.43, iron `1439`) → **multi-threading / preemptive scheduling** (1.44: schedulable `&` jobs, SMP-AP wake+park, per-proc env) → **1.45.x TLS → HTTPS → `ark`-fetch** (OPEN): ring-3 net/entropy/clock syscalls #45-#55 (getrandom, time_unix, TCP sockets, UDP, ICMP-echo) — all of Phase A net-tools kernel-unblocked. Cyrius peer specced in `cyrius/docs/development/proposals/2026-06-14-agnos-net-entropy-clock-syscalls.md`. |
| [agnoshi](https://github.com/MacCracken/agnoshi) | 1.7.0 | AI shell (Cyrius) — the userland interactive shell, exec'd from disk in ring 3 (shell-separation arc, iron-complete burn `14115`). 1.5.0 dropped its in-process coreutils verbs → delegates to the **kriya `/bin` dispatcher + owl `cat`**; 1.6.x added `&` background jobs (job table + poll loop, schedulable via agnos 1.44.x); 1.7.0 inherits per-process env. Cyrius pin 6.1.14. Real entry is `src/agnsh.cyr` (`src/main.cyr` is dead legacy). |
| [agora](https://github.com/MacCracken/agora) | 1.4.2 | Telnet-served BBS (Greek ἀγορά — *civic marketplace / public assembly*), Cyrius-native. Multi-user, multi-board threaded boards; sigil-backed Ed25519 challenge/response auth; per-board posting policy; fork-per-connection concurrency; audit-hardened input; frozen ABI; full RFC 854/1143/1073/1091/1184 telnet conformance. **v1.0.0 shipped 2026-05-23 — iron-validated on archaemenid** (telnet round-trip + 8-user concurrent fanout green). **v1.1.0 added the door-games subsystem** (ADR 0009 — pure-module, side-effect-free game logic); **v1.2.0 "Persistent Universe"** (ADR 0010) made all **three door games** shared-world multiplayer — **PA** (TradeWars-lineage space-empire trading; shared galaxy + async-PvP garrisons), **Smuggler** (contraband running; shared per-district police heat), **The Handler** (spy-runner field-pressure; shared per-city alert levels) — via a `flock`'d *lock → read → compute → write* world transaction per game on disk, plus cross-game leaderboards (`scores <game>` telnet command). Pin lifted cyrius **6.0.52 → 6.1.5** (the ≥6.0.53 sigil/sha256 `SIGILL` blocker cleared on 6.1.x); 141 tests, 678,776 B. **Planned: 1.3.0 chat area + Eliza** (a live multi-user BBS teleconference / CB-simulator with a pure-module Rogerian-chatbot port of Weizenbaum's 1966 DOCTOR as its anchor inhabitant — also reachable as a `play eliza` door; builds on the 1.2.0 `flock`'d shared-disk framework, no new deps); **1.4.0 a `descent` door** — the BBS→MUD gateway into [cyrius-yeomans-descent](https://github.com/MacCracken/cyrius-yeomans-decent). Server-stage app; anchors the BBS/MUD aesthetic cluster (consumes the network-tools family, kii, anuenue, bnrmr). |
| [argonaut](https://github.com/MacCracken/argonaut) | 1.8.2 | Init system library (Cyrius) — depends on agnosys. v1.7.0 adds BOOT_MINIMAL agnoshi-as-no-deps-console-service (unblocks closed-beta MVP without aethersafha). |
| [bannermanor](https://github.com/MacCracken/bannermanor) | 1.1.1 | `figlet`-equivalent ASCII-art banner generator (binary `bnrmr` — vowel-dropped per the `commandress`→`cmdrs` compression pattern). English-wordplay naming lane. Drives login MOTDs, script intros, splash text. **Graduated to v1.0+ 2026-05-20 PM** — CLI flag surface, CYML font format (schema=1), and default in-tree font set (block / slim / big) all frozen as the v1.0 contract. Drove the 2026-05-20 darshana 0.3.0 → 0.3.5 color-primitives bump (banner colors). Cyrius pin 6.0.1. Consumers: end-user shells; agnoshi MOTD; iam (logo rendering); darshana, mihi. |
| [commandress](https://github.com/MacCracken/commandress) | 1.1.1 | Structured shell prompt renderer for agnoshi, bash, and zsh via per-shell adapters. Sovereign-stack equivalent of starship, in Cyrius. Binary name `cmdrs` (short for *commandress*). Stateless, segment-based, config-driven, zero non-stdlib deps. **Graduated to v1.0+ 2026-05-18** — segment renderer + config layer stabilized after the 2026-05-15 scaffold. Cyrius pin 5.11.64. Consumers: agnoshi, bash, zsh (prompt-hook adapters). |
| [cyim](https://github.com/MacCracken/cyim) | 1.7.1 | Sovereign modal text editor (Cyrius-native, VIM-inspired, zero attack surface, no embedded scripting). Consumes vyakarana + niyama (regex via stdlib fold v5.9.0); consumers: agnoshi, aethersafha, daimon-orchestrated agents. |
| [cyim-lsp](https://github.com/MacCracken/cyim-lsp) | 1.5.0 | Language Server Protocol companion to cyim (Cyrius-native). Editor-agnostic LSP backend serving cyim's grammar/regex/symbol surfaces over LSP. |
| [darshini](https://github.com/MacCracken/darshini) | 1.2.0 | `eza`-equivalent pretty file listing — colors, icons, git-status column, tree view, mime-type recognition (Sanskrit दर्शिनी — *she who shows*). Sibling-not-competitor to kriya's minimal `ls`; both ship. **Graduated from the terminal-aesthetics "planned" quintet** — was the last of the five queued, now shipped at 1.2.0. Consumes darshana (TTY/ANSI). |
| [hapi](https://github.com/MacCracken/hapi) | 1.0.1 | GNU `stow`-equivalent — dotfile / symlink farm manager. Dual-read name: Hawaiian हपी (*happy*) + **H**ome **A**sset **P**rovisioning **I**nterface; first Pacific Islands word in the AGNOS naming surface. CYML manifest per package, capability-bounded execution (`$HOME` only by default), lightweight audit trail. **Graduated to v1.0+.** Consumers: end-user shells; agnova (dotfile bootstrap); mihi. |
| [iam](https://github.com/MacCracken/iam) | 1.1.0 | fastfetch/neofetch-equivalent system-info display for login MOTD + screenshot flex. Pure inverse of `whoami` — whoami says who the user is, iam says what the system is. Thin presentation layer over the mihi probe library. **Graduated to v1.0+ 2026-05-20** straight to 1.0.0 on cyrius 6.0.1 — second v6.0.x graduation. English-wordplay/trickster naming lane. Consumes mihi (probe) + darshana (color/TTY). |
| [kii](https://github.com/MacCracken/kii) | 1.0.0 | `chafa`/`jp2a`/`viu`-equivalent — image → ANSI/ASCII-art converter for terminal display. Four-layered name (Hawaiian *image* + East Asian *ki* 気 *life-force* + back-half of *a-scii* + functional convergence). Reads PNG/JPEG/GIF/BMP, quantizes to a terminal palette + glyph set, emits ANSI sized to cols × rows. **Graduated to v1.0+.** Consumers: bannermanor (logo rendering), iam (system splash), BBS MOTD pipeline, MUD room illustrations, anuenue. |
| [kriya](https://github.com/MacCracken/kriya) | 1.1.4 | Coreutils-equivalent for AGNOS (Sanskrit क्रिया — *action, operation, verb*). One repo, many small static utilities (`cp`, `mv`, `rm`, `mkdir`, `echo`, `wc`, `find`, `grep`, `xargs`, …) sharing infrastructure. BusyBox-style dispatcher + symlinks per utility. **Graduated to v1.0+ 2026-05-18** after M5 closeout (grep + find + xargs); dispatcher + sovereign-boundary surface stabilized. Sovereign-replacement boundaries: owl owns `cat`, cyim owns `vim`, sit owns `git`, chakshu owns `htop`, agnoshi owns shell builtins; kriya fills the gaps. Cyrius pin 5.11.61. Consumers: agnoshi (PATH lookup), zugot (install-time symlinks). |
| [kybernet](https://github.com/MacCracken/kybernet) | 1.3.3 | PID 1 init binary (Cyrius, 140 tests) — depends on argonaut. v1.2.1 consumer pin bump for argonaut 1.7.0 BOOT_MINIMAL. |
| [nous](https://github.com/MacCracken/nous) | 1.2.5 | Package resolver (Cyrius) |
| [owl](https://github.com/MacCracken/owl) | 1.4.0 | Watchful file viewer — `cat`/`bat` replacement (Cyrius-native, **O**bservant **W**atcher of **L**ines). `-p` byte-identical cat drop-in; decorated mode adds token highlighting + paging + a **VCS change-marker gutter via `sit`** (1.4.0). Consumes vyakarana (tokenization) + bayan + sit. **AGNOS-compile note:** owl-on-agnos is blocked by its sit→tls transitive chain — needs the TLS stack adapted for `CYRIUS_TARGET_AGNOS` (agnos #45-#55 peer) AND a `sit`→agnos port; the delegation's working owl was 1.3.8 (cat-only, pre-sit). See the cyrius net-syscall proposal's *Transitive consumer: owl → sit* section. |
| [sit](https://github.com/MacCracken/sit) | 1.0.1 | Sovereign version control — Cyrius-native git replacement (smriti, स्मृति — *memory*). `sit_repo_open`/`sit_diff_path`/`sit_repo_close` library surface + a `wire`/`wire_http`/`serve` https remote layer (which pulls net/tls/tls_native/http). Deps: sankoch (compression), sigil (hashing), patra (object store). No libgit2, no C, no FFI. **Graduated to v1.0+** (was 0.8.5 pre-1.0). | end user, owl (VCS-gutter), ark |

### Stdlib-Folded (2 crates)

| Crate | Version | Domain |
|-------|---------|--------|
| [sandhi](https://github.com/MacCracken/sandhi) | 1.4.11 | Service-boundary layer (HTTP client+server, HTTP/2, streaming, JSON-RPC, service discovery, TLS policy). **Folded into Cyrius stdlib at v5.7.0** as `lib/sandhi.cyr` (vendored byte-identical, 376,037 B / 9,649 lines / 469 fns). Sandhi repo entered maintenance mode per [ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md); subsequent surface patches land via Cyrius release cycle. |
| [niyama](https://github.com/MacCracken/niyama) | 1.0.5 | Regex engines — bre / re2 / pcre / fuzzy / vim. **Folded into Cyrius stdlib at v5.9.0** as `lib/niyama.cyr` (vendored byte-identical, 6,664 lines / 7 modules: posix_classes, unicode_props, bre, re2, pcre, fuzzy, vim). Multi-consumer gate met by cyim (#1) + queued AGNOS bare-metal kernel (#2 → v5.10.x trigger). Public API frozen per [niyama ADR 0010](https://github.com/MacCracken/niyama); fold pattern documented in [niyama ADR 0011](https://github.com/MacCracken/niyama). |

---

## Pre-1.0 (21 crates)

### Near-Stable (v0.5.0+)

| Crate | Version | Description | Key Consumers |
|-------|---------|-------------|---------------|
| [aethersafta](https://github.com/MacCracken/aethersafta) | 0.50.0 | Media compositing — scene graph, capture, HW encoding | aethersafha, tazama |
| [jnana](https://github.com/MacCracken/jnana) | 0.5.0 | Unified knowledge system — offline-accessible corpus | agnoshi, hoosh, daimon |

### In Progress (v0.1.0 - v0.49.x)

| Crate | Version | Description | Key Consumers |
|-------|---------|-------------|---------------|
| [selah](https://github.com/MacCracken/selah) | 0.29.4 | Screenshot capture, annotation, PII redaction | taswir, soorat |
| [cyrius-doom](https://github.com/MacCracken/cyrius-doom) | 0.30.1 | DOOM engine in Cyrius — hardened, 5 CVEs fixed; renders in-game on real Zen (agnos iron burn `1439`); kernel-scaled blit consumer (0.29.0) | standalone game / kernel demo |
| [muharrir](https://github.com/MacCracken/muharrir) | 0.23.5 | Editor primitives — text buffer, undo/redo, command pattern | rasa, tazama, shruti |
| [samvada](https://github.com/MacCracken/samvada) | 0.4.0 | DBus client (Cyrius-native) — C-shim wrapping `sd_bus`, minimal logind subset (`TakeDevice` for DRM master delegation, `Pause`/`ResumeDevice` signals). v1.0 retires the libsystemd shim alongside mabda v4.0's wgpu-native retirement. | mabda (Phase D `gpu_surface_configure_native_logind`) |
| [vani](https://github.com/MacCracken/vani) | 0.9.5 | Audio device I/O — direct ALSA/OSS syscalls (Cyrius-native). Full audio stack (ALSA ioctls, ring buffer, XRUN recovery, mixer). **Vendored into Cyrius stdlib at v5.8.0** as `lib/vani.cyr` (replacing legacy `lib/audio.cyr`); standalone repo continues for direct consumers needing newer surface than the folded snapshot. | shravan, dhvani, naad, jalwa, shruti |
| [yantra](https://github.com/MacCracken/yantra) | 0.6.2 | Sovereign UI automation — browser + mobile, as a Cyrius library (Cyrius-native). `.tcyr` files include `lib/yantra.cyr` and drive Chromium / Firefox / WebKit / Android / iOS. Not a framework — `cyrius test` stays the runner. Planned backends: CDP, W3C WebDriver, Appium. | AGNOS E2E consumers (owl, agnoshi, tanur when GUI lands) |
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
| [darshana](https://github.com/MacCracken/darshana) | 0.7.0 | TTY/raw-mode primitives (Sanskrit दर्शन — *viewing/showing*). Linux termios + ANSI + cursor positioning + alt-screen + color escape sequences (0.3.5, 2026-05-20 — added so bannermanor's banners can render colored). Extracted from cyim's `src/tty.cyr` once chakshu became a second consumer. **Not a TUI framework** — just the syscalls and escape sequences below the framework. | cyim, chakshu, bannermanor |
| [rosnet](https://github.com/MacCracken/rosnet) | 0.1.0 | Sovereign dense f64 tensor algebra (the BLAS substrate) — storage, BLAS-1, matmul + its gradient. Extraction target from attn11's ML core (with tyche); not yet folded. | attn11, future ML/agent work |
| [tyche](https://github.com/MacCracken/tyche) | 0.1.0 | Sovereign deterministic statistical PRNG (xorshift64) — **NOT a CSPRNG** (those route to sigil). Extracted from attn11's randomness needs. | attn11, simulation/sampling consumers |

---

## Binaries & Tools (pre-1.0, 13 entries)

| Binary | Version | Description | Depends On |
|--------|---------|-------------|------------|
| [shakti](https://github.com/MacCracken/shakti) | 0.6.2 | Privilege escalation (`sudo` replacement) | agnosys, sigil |
| [ark](https://github.com/MacCracken/ark) | 0.8.0 | Package manager (Cyrius) | nous, sigil |
| [takumi](https://github.com/MacCracken/takumi) | 0.8.0 | Build system — Cyrius port in progress (toolchain pinned 5.5.23; `rust-old/` authoritative until parity) | sigil |
| [aethersafha](https://github.com/MacCracken/aethersafha) | 0.1.0 | Wayland compositor | aethersafta, mabda |
| [mela](https://github.com/MacCracken/mela) | 0.1.0 | Agent marketplace | daimon, sigil |
| [agnova](https://github.com/MacCracken/agnova) | 0.1.0 | OS installer (Cyrius port from 3,656 Rust lines, base established) | ark, kavach |
| [seema](https://github.com/MacCracken/seema) | 0.1.0 | Edge fleet management | daimon, bote |
| [samay](https://github.com/MacCracken/samay) | 0.1.0 | Task scheduler | szal |
| [chakshu](https://github.com/MacCracken/chakshu) | 0.7.5 | AI-augmented system monitor (Sanskrit चक्षु — *the eye*; binary `shu` — **S**ystem **H**ealth **U**tility, per ADR 0001). Cyrius-native, reads `/proc` directly. Replaces htop/btop Bazaar packages at v1.0; adds AI explanations via daimon/hoosh at M3+. Cyrius pin 6.0.1. | mihi, darshana, sandhi (M3), niyama (M3), daimon (M3) |
| [gnoboot](https://github.com/MacCracken/gnoboot) | 0.5.0 | Sovereign UEFI bootloader (Cyrius-native PE32+ EFI Application, ~33 KB) — replaces GRUB on the AGNOS boot path. Locates kernel at `\boot\agnos`, parses ELF64 program headers, allocates pages as `EfiLoaderCode`, zeroes BSS gap, captures GOP framebuffer + FrameBufferSize, builds 88-byte sovereign boot-info struct (magic `'AGNO'`), calls `ExitBootServices`, jumps with `RDI = &boot_info`. 0.4.x added GOP FrameBufferSize capture + SetMode arc (Attempts 73-74). Pairs with agnos 1.31.x. | agnos (kernel handoff consumer) |
| [thoth](https://github.com/MacCracken/thoth) | 0.6.3 | **Sovereign agentic coding TUI** — Claude-Code-style interactive REPL/agent (reads a task, plans, edits files, runs tools, iterates) with **mid-session backing-model switching** (route a turn to a different LLM / tier / provider via hoosh). Backronym: **T**hinks **H**andles **O**rchestrates **T**ransforms **H**eals (code); name = Egyptian **Thoth**, scribe-god of writing. Consumes the `avatara` Thoth archetype as its own personality overlay — a deliberate on-the-nose case (name = archetype = function aligned, see `vision/maat-42.md`), **not** a general pattern (avatara archetypes are normally overlaid by the system, not pulled by a namesake tool). User-facing front-end over daimon (orchestration) + bote/t-ron (MCP exec + security) + hoosh (model routing) + avatara (persona) — consumes them, does not duplicate. **Graduated from idea-log to scaffold 2026-06** (was "Planned, not scaffolded"); see [[project_tools_stable_ideas]]. Name settled, no rename. | hoosh, daimon, bote, t-ron, avatara |
| [yo](https://github.com/MacCracken/yo) | 0.5.2 | `ping`-equivalent — *Yodel-Out*, Cyrius-native sovereign ICMP echo probe. English-wordplay lane. **Scaffolded** (was the network-tools "planned" family). On agnos it consumes the ring-3 `icmp_echo`#55 syscall (agnos 1.45.4). | end-user shells; net-diagnostics |
| [dig](https://github.com/MacCracken/dig) | 0.3.0 | DNS resolver — sovereign Cyrius reimplementation of BIND `dig` (cultural double-anchor: *Domain Information Groper* + *Cyrus from The Warriors*). **Scaffolded** (was the network-tools "planned" family). On agnos it consumes the ring-3 UDP syscalls `udp_bind`/`send`/`recv`/`unbind` #51-54 (agnos 1.45.3). The second concrete consumer that triggers the `taar` extraction. | end-user shells; whirl (hostname resolution) |

---

## Non-Library Projects

| Project | Version | Description | Key Consumers |
|---------|---------|-------------|---------------|
| [attn11](https://github.com/MacCracken/attn11) | 1.6.4 | **GPT-style transformer — *trained*** — from scratch in Cyrius. Byte-level (default) + opt-in BPE tokenizer → token+learned-positional embeddings → pre-norm blocks (LayerNorm → causal mixer → residual → LayerNorm → GELU MLP / **MoE top-K router** → residual) → weight-tied LM head → softmax cross-entropy; hand-derived backprop + **Adam** (global-norm clip, warmup→cosine LR, NaN guard), KV-cached autoregressive generation (bit-identical to the uncached reference). **Sequence-mixer axis** (`--attn-kind`): softmax MHA, GQA/MQA, MLA, RetNet **gated-linear**, selective **SSM** (Mamba-lite, hand-derived BPTT) + **per-layer hybrid** (`--attn-every K`); + RoPE positions, MoE (`--experts N`/`--expert-topk K` w/ Switch load-balance aux). No BLAS / libc / autodiff — raw `f64` (IEEE-754 i64 bit-patterns via `f64_*` builtins) on flat row-major tensors, single static ELF (~312 KB stripped). Every op finite-difference grad-checked (**857 checks**, x86_64 **and** aarch64/qemu); checkpoint v6 (v1–v5 load). **Trains on the AGNOS kernel in ring 3** (50 steps on 1.44.15, loss/lr/grad-norm matching native to every digit, checkpoint bit-for-bit identical). The ecosystem's **ML / training reference** — proof real gradient-based learning is expressible in the "assembly-up, everything-is-i64" sovereign language. cyrius pin **6.2.2** (leading edge). | standalone binary / ML reference |
| [cyrius-nba-jam](https://github.com/MacCracken/cyrius-nba-jam) | 0.5.0 | NBA Jam reimplementation in Cyrius | standalone game |
| [encom-hits](https://github.com/MacCracken/encom-hits) | 1.0.0 | ENCOM retro arcade collection in Cyrius | standalone game |
| [cyrius-brynns-tale](https://github.com/MacCracken/cyrius-brynns-tale) | 0.1.0 | ***Brynn's Tale*** — original mythic-modern game in Cyrius. A wife uses a time-rewind power to save her husband from dying; the cost is herself. **Three-act diptych-becoming-triptych**: Act 1 backward-narrative descent (Memento-form, six rewind variants per world); Act 2 forward-irreversible survival (Bleed mechanic + every choice final); Act 3 NG+ as the integrated being THEM (alchemical *rebis* after Phoenix-rebirth, full toolkit, climaxes in cosmic-test rubedo). Selectively Souls-like (soft-fail everyday + hard-fail bosses). Pivoted 2026-04-26 from `cyrius-braid` Braid-reimplementation; original IP per ADR 0003. Formerly registered as `cyrius-braid`. | standalone game |
| [cyrius-super-plumber-twins](https://github.com/MacCracken/cyrius-super-plumber-twins) | 0.1.0 | 2.5D platformer with ragdoll-physics (homage to *Super Mario Bros*, Nintendo 1985 — reimplementation from observation, not a port). Stars **The Royals** (Royal/midnight Blue + Purple plumber **twins — boy + girl**, peer protagonists) who work for the Castle. Original cast: The Boy (the girl-twin's crush; jester/scribe dual-role with forest-green scribe attire + motley jester attire — **gender-flipped love-interest archetype inverts the Mario princess-rescuee trope**), Cousin Job (trade-rival trying to prove he's the better plumber, equal antagonism toward both twins), Mouser (GC / Head of Facilities final boss — three-layer name including Disney wink), Facility Sub-Managers (Koopalings × Mega Man Robot Masters hybrid). Nintendo-IP distinctiveness bar is the strictest in the retro-port series. Formerly `cyrius-super-plumber-bros`; renamed per [ADR 0004](https://github.com/MacCracken/cyrius-super-plumber-twins/blob/main/docs/adr/0004-twins-pivot.md). | standalone game |
| [cyrius-bb](https://github.com/MacCracken/cyrius-bb) | 0.7.2 | *Break-breaker* — 2.5D brick-breaker in Cyrius. 50-year homage to *Breakout* (Atari, 1976 — Bushnell / Wozniak-adjacent lineage). Atari-IP distinctiveness bar is relaxed (Atari SA tolerates respectful homages). | standalone game |
| [cyrius-polyomino](https://github.com/MacCracken/cyrius-polyomino) | 0.5.0 | Original falling-block puzzle in Cyrius — generic homage to the 1984-era falling-block genre (Alexey Pajitnov / *Tetris*). **Deliberately IP-clear**: a *polyomino* is the mathematical term for unit cells joined edge-to-edge (the four-cell **tetromino** — I/O/T/S/Z/J/L — is the genre primitive), so the name + core mechanics sit in the mathematical/public domain. **The Tetris Company trademark + branded assets hard-excluded** — not branded as the title, original assets only ([ADR 0002](https://github.com/MacCracken/cyrius-polyomino/blob/main/docs/adr/0002-original-assets-only.md)), reimplemented from documented public mechanics ([ADR 0001](https://github.com/MacCracken/cyrius-polyomino/blob/main/docs/adr/0001-original-puzzle-from-observation.md)); the canonical branded theme tune is *not* shipped. Pure integer 10×20-well grid sim — bit-deterministic / seed-replayable, fully unit-testable headless — with renderer/input/framebuffer self-rolled on bare stdlib ([ADR 0003](https://github.com/MacCracken/cyrius-polyomino/blob/main/docs/adr/0003-self-rolled-primitives.md)), same cyrius-doom / cyrius-bb lineage (no engine, no GPU, no FFI). MVP-first ramp: classic core (M1–M2 — gravity, line clears, classic scoring, per-level speed curve, DAS/lock-delay) then the **modern guideline layer** (M3 — SRS wall-kicks, 7-bag, hold, ghost, hard drop) layered on the proven core; vani audio (M4) + sankoch/sigil high-score save (M5) follow. Sibling self-rolled accessible-scope 2D entry alongside cyrius-bb. | standalone game |
| [cyrius-stellar-swarm](https://github.com/MacCracken/cyrius-stellar-swarm) | 0.1.0 | 2.5D fixed-shooter (homage to *Galaga*, Namco 1981 — reimplementation from observation). Preserves formation-attack + tractor-beam capture-and-rescue + bonus challenging stages. Original ship + three-tier original enemy creatures + original chiptune-era synth music. Namco-IP distinctiveness bar moderate. | standalone game |
| [cyrius-sunset-drive](https://github.com/MacCracken/cyrius-sunset-drive) | 0.1.0 | 2.5D arcade coastal-racer (homage to *Outrun*, Sega / Yu Suzuki 1986 — reimplementation from observation). Pick-a-route + pick-a-track signature mechanics. Initial routes: Sunset Drive / Coastal Run / Ridgeline. Initial music selects: Yacht Rock / Smooth Jazz / Dance-Hi-Energy. Original convertible-coupe car (NOT a Ferrari Testarossa — Sega-IP moderate + Ferrari IP hard-excluded). | standalone game |
| [cyrius-grapevine](https://github.com/MacCracken/cyrius-grapevine) | 0.1.0 | 2.5D cozy meta-casual vineyard sim. Genre-synthesis of *My Vineyard* (Metaplace, 2010) + *Animal Crossing* (Nintendo, 2001) + *Stardew Valley* (ConcernedApe, 2016). First cozy-sim slot in the library. Vineyard-focused (grapes + 2-3 crops max), 8-12 Stardew-grade NPCs with schedules and dialogue, real-time seasonal rhythm, four seasonal festivals. **Trusted-pair multiplayer co-op as M3 core scope** (not stretch) — async-visit + real-time co-op via sandhi networking. Hard rules: no combat / mining / dungeons / bachelor-catalog. Save-format versioned from day one (players invest years). Three-tier distinctiveness bar: Nintendo-strict on AC-adjacent / Metaplace-defunct-relaxed / ConcernedApe-respect on Stardew-adjacent. | standalone game |
| [cyrius-chellys-beach-adventure](https://github.com/MacCracken/cyrius-chellys-beach-adventure) | 0.1.0 | 2.5D cascade-reel slot machine in Cyrius. **B2B commercial-platform-demo** designed to pitch Cyrius as secure, sovereign gaming-industry OS to Konami / IGT / Scientific Games / Light & Wonder / Aristocrat. Original game (not homage); slot mechanics are industry-convention used freely. **Column-cascade Wild** (entire column cascades on wild, not tile-cascade) as signature mechanical twist. Warm golden-hour beach theme. Characters Chelly (Black Bichpoo) and Mykala (GSD/Chow mix). Technical arguments: **provable-fair RNG native via sigil** (not bolted on), byte-identical cross-platform reproducible builds, small attack surface, kavach game-isolation. RTP 94-96% industry-standard validated via abaco. Not a consumer retail game; not a certified slot (certification post-manufacturer-commit). | B2B platform demo |
| [cyrius-chelly-beach-dash](https://github.com/MacCracken/cyrius-chelly-beach-dash) | 0.1.0 | **Chelly's Beach Dash** — 2.5D arcade beach-runner in Cyrius. Consumer-facing title sharing the **Chelly's Beach Adventure** brand with the slots B2B demo above (same characters, separate game). Trick-combo runner — mechanical homage to *Skate or Die* (Electronic Arts, 1987 — reimplementation from observation, not a port). Chelly (Black Bichpoo) dashes across the beach to her owner at the end of the pier; mechanical mapping: trick combos → tail-wag/leap combos, half-pipe → dune jumps, urban hazards → boardwalk crabs/seagulls/driftwood, finish line → owner-reunion at the pier. Same warm golden-hour beach theme as the slots. EA-IP distinctiveness bar relaxed (38-year-old NES-era title, mechanical-only homage). Sits in the same 2D sprite/AI/state lane as cyrius-nba-jam and cyrius-grapevine — tooling investment compounds. v0.2.0 = Flappy-Bird-first scope (one lane, one jump, one hazard family, one pier finish); magnum-opus catalog accretes through later versions. Scaffolded 2026-04-28. | standalone game |
| cyrius-rampage *(not scaffolded — slug + title provisional; details TBD)* | — | **Giant-monster city-destruction action game in Cyrius.** Mechanical homage to *Rampage* (Bally Midway, 1986 — vertical climb-and-smash, building-collapse physics, 2–3-player monster co-op as the defining hook) with a meta-narrative layer riffing on *Wreck-It Ralph* (Disney, 2012 — destroyer-as-protagonist inversion). **Midway / Disney IP hard-excluded** — original monsters, original city setting, original score; mechanics-and-archetype-only homage. Sits naturally in the same 2D sprite/state lane as cyrius-nba-jam / cyrius-grapevine / cyrius-chelly-beach-dash — tooling investment compounds. Concept dropped 2026-05-15 (lunch-break observation: a Rampage-themed slot machine in a streaming session triggered the riff). | standalone game |
| cyrius-block-game *(not scaffolded — slug + title provisional; 3D lane; default to Path A at scaffold time)* | — | **Block-survival / mine-and-craft entry in the catalog. Default path = Path A (original-IP homage); Path B kept as a fallback fork.** **Path A — original-IP homage with cubist / voxel aesthetic** (mechanical-only AND visual-style-only homage; both layers IP-safe. **Visual style is not copyrightable** — the cubist / voxel / blocky aesthetic is a geometric primitive, not an expressive work — so the cube-world look IS the lane and stays. What IS hard-excluded: Microsoft/Mojang's *expressive elements* — no Creeper / Steve / Enderman / Zombie-Pigman / etc.; no "Minecraft" branding; no signature texture designs; no biome names or world-gen specifics from Mojang's catalog. Original mob roster + original block textures + original setting. Block-survival has pre-Mojang precedent — *Infiniminer* (Zachtronics, 2009) is the most-cited mechanical ancestor; *Dwarf Fortress* (Bay 12, 2006) and *Wurm Online* (Mojang predecessor, 2003) seeded the design space; living examples that ship under exactly this framing: Minetest (LGPL), Vintage Story (commercial), Cuberite (server-only) — none of them are in Microsoft's crosshairs. So Path A IS safe and gets the green light at scaffold time). **Path B — clean-room Java port (fallback only)**: explicitly NOT the cyrius-doom path because Mojang has not open-sourced Minecraft Java (id Software open-sourced DOOM 1.9 in 1997 → GPL-licensable; Mojang has not). Path B's only IP-safe form is clean-room reimplementation reading runtime behavior, NOT copying decompiled code. Kept as a fork in case a specific Java-edition compatibility goal surfaces later (e.g., reading existing `.mcworld` saves, networking with vanilla servers); otherwise Path A subsumes it. Sits in the 3D lane alongside cyrius-mine-cart; depends on **kiran** (game engine) + **joshua** (game manager + AI sim runtime), both post-boot work. **Concept dropped 2026-05-22** (post-1.31.7 close); **Path A endorsed same-day** ("cubist style isn't copyrighted so we're safe"). | standalone game |
| [cyrius-yeomans-decent](https://github.com/MacCracken/cyrius-yeomans-decent) *(**v1.0.1 shipped**; slug typo `decent` → `descent` to be fixed by user later — repo/GitHub name unchanged until then)* | 1.0.1 | ***Yeoman's Descent*** — AGNOS MUD (Multi-User Dungeon). Folds the project lead's first name **Yeoman** into the MUD-genre *Descent* (sword-and-sorcery dungeon lineage). English-wordplay lane (project-lead-name × genre-word, not an intentional misspelling pun). **README already uses the correct spelling** — typo is contained to the slug / repo URL pending user-driven rename. **Server-stage app** per the AGNOS maturity arc — sits alongside [`agora`](https://github.com/MacCracken/agora) (BBS, **v1.2.0**, Cyrius-native + iron-validated on archaemenid — its planned **1.4.0 `descent` door** is the BBS→MUD gateway *into this very MUD*) / sovereign remote-shell / web server in the non-desktop suite that validates the 1.32.x networking surface (per [[project_agnos_maturity_arc]] and [[project_archaemenid_install_plan]]). Naturally consumes the network-tools family (`taar` substrate + sockets), the image-to-ANSI family (`kii` for room illustrations), and `anuenue` / `bnrmr` for MOTD / banner flair — concrete second/third consumer for several proposed-but-unbuilt userland surfaces in the BBS/MUD aesthetic cluster. Repo carries full `src/`/`tests/`/`docs/`/`lib/`/`cyrius.cyml`/`VERSION` skeleton; project lead driving content. | standalone game / 1.32.x networking-arc proof-of-life |
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
| **sadish** | **Low-level 2D vector graphics core** — the sovereign rasterizer foundation: path construction (move/line/quadratic+cubic Bézier), curve flattening, scanline fill (even-odd / nonzero winding) with anti-aliased coverage, affine transforms, clipping, solid/gradient fills → a pixel/coverage buffer that blits via `blit`#39. **Name LOCKED 2026-06-08:** `sadish` (सदिश — स *with* + दिश् *direction* = literally *"having direction"*, the modern Sanskrit/Hindi word for **vector**; antonym अदिश *adish* = scalar) — user picked the on-the-nose term over `chitra`/`vakra`/`alekhana`; pairs with **rekha** (रेखा *line/outline*), which builds on it. The explicit **"low-level lib you build up from"** decision (user, 2026-06-08): *everything vector rasterizes here*; higher layers — a canvas/drawing API, compositing, SVG, eventually a UI toolkit — and **rekha** (font outlines) are CONSUMERS, not re-implementations. Pure userland: needs **no new kernel work** (the `blit`#39 / FB-access substrate already landed at agnos 1.43.4; zero-copy FB-mmap, a 1.43.x→1.44.x carry-forward, is only a later speed lever). Desktop-stage / aethersafha-era — long-horizon, parked in the desktop arc deliberately. Captured in `project_tools_stable_ideas.md`. | rekha; aethersafha; SVG / document viewers; UI toolkit |
| **rekha** | Vector / outline **font** subsystem — TrueType / OpenType outline parser + glyph shaping, **rasterized via the low-level `sadish` 2D vector core** (rekha emits glyph-outline paths; sadish fills them — rekha does NOT bundle its own Bézier rasterizer) (Sanskrit: रेखा *line/outline/contour/stroke*). Sibling-to-kashi pair: **kashi** handles bitmap glyph sources (BIOS ROM fonts, PSF1/PSF2, hand-drawn arrays — the *shining* glyph cores at v1.0.0 2026-05-28); **rekha** handles outline/Bézier sources for scalable typography (resolution-independent rendering). Discovered 2026-05-28 while working on kashi and asking about TIFF support — different decode pipeline, different render math, not a kashi extension. Likely follows kashi's parallel-agent pattern per [[project_kashi_parallel_split]]. Long-horizon — surfaces when aethersafha (Wayland compositor) gets real or when a document/viewer app demands scalable text. Captured in `project_tools_stable_ideas.md`. | aethersafha (eventual); document viewers; framebuffer console v2 |
| *attn11 → libs* **(names deferred)** | **Extract `attn11`'s reusable ML substrate into libs** — kashi-style: `attn11` stays the *reference binary* (the proof that gradient-based learning is expressible in sovereign everything-is-i64 Cyrius — hand-written forward + backprop + Adam on raw f64 arrays, no BLAS/libc/autodiff, gradients gated by finite-difference checks); the reusable cores split out + vendor back, parent becomes a thin consumer. Candidate lib boundaries: (1) **f64 tensor / linalg core** — matmul, transpose, elementwise, softmax, layernorm; (2) **optimizers** — Adam (+ friends); (3) **finite-difference gradient-check harness** — the correctness gate that lives in attn11 today; (4) **transformer blocks** — attention / MLP as a model lib. **Naming DEFERRED per user 2026-06-08** — settle later or keep plain descriptive names; explicitly NOT locking Sanskrit names now (unlike rekha/sadish). **Timing gate (user 2026-06-11): extraction waits for attn11 v1.0 — the 1.x minor cycles are the extract + re-fold vehicle** (kashi/sandhi pattern, run inside attn11's 1.x line, NOT pre-1.0). Do not carve attn11 into libs while it's still pre-1.0; the v1.0 cut is the trigger to revisit what's worth extracting. Captured in `project_tools_stable_ideas.md`. | future ML / agent work (hoosh, daimon, mela) |
| *sovereign tracker + m8c-equiv* **(audio proof-apps; names deferred)** | **The audio-stack acceptance test — proves the sovereign audio-ecosystem port to agnos *pre-desktop*** (proof-app pattern, cf. DOOM/agnsh/agora). Both are framebuffer apps (`blit`#39, landed agnos 1.43.4) — no desktop needed. **(1) Cyrius m8c-equivalent** — port of `github.com/Dirtywave/m8c`: mirror the user's real **M8** hardware over USB-serial (CDC-ACM SLIP screen-command stream) to the FB + forward keys (M8 has its own audio; host audio optional). Gate: plug-n-play USB-serial (the 1.35.x plug-and-play arc) + FB ✓. **(2) Sovereign old-school tracker** (NOT a DAW — pattern/sample tracker, ProTracker/M8 lineage) built on the **existing audio libs** — `vani` (device I/O) / `naad` (synth) / `shravan` (codecs) / `dhvani` (engine). Gate: an agnos audio-OUTPUT kernel arc (Intel-HDA or USB-audio-class; plug-n-play enables USB) + a cyrius `lib/vani.cyr` agnos backend (the audio analog of the `net.cyr` agnos-peer gap) + FB ✓. This app justifies the audio-ecosystem agnos port. Names deferred (user-facing → English-wordplay/Polynesian lane). Captured in `project_tools_stable_ideas.md`. | standalone apps; drives the vani/naad/shravan/dhvani agnos port |
| **krishi** | Agriculture — crop science, soil, irrigation, yield modeling (Sanskrit: कृषि) | vanaspati, badal, kimiya, kshetra |
| **prakriti** | Ecology — ecosystem modeling, food webs, biodiversity (Sanskrit: प्रकृति) | jantu, vanaspati, badal, jivanu |

### Terminal-aesthetics quintet (proposed 2026-05-18; ✅ 5 of 5 shipped)

Five Cyrius-native tools covering the daily-driver shell experience — prompt, file listing, dotfile placement, banner output, system identity. Together with `commandress` (1.0.0, in `Binaries & Tools`), they form a coherent personal-computing aesthetics layer for AGNOS. Each lives as a standalone repo when scaffolded.

**Shipped**: `mihi` 1.0.0 (v1.0+ OS & Infrastructure), `iam` 1.0.0 (v1.0+ Binaries & Tools), `bannermanor` 1.0.0 (v1.0+ Binaries & Tools — graduated 2026-05-20 PM), `hapi` 0.5.0 (pre-1.0 Binaries & Tools) — see those sections above for current entries. Brainstorm captured in `~/.claude/projects/-home-macro-Repos-agnosticos/memory/project_tools_stable_ideas.md`.

**✅ Quintet complete.** `darshini` 1.2.0 (the last queued — `eza`-equivalent pretty file listing) **shipped and graduated to v1.0+ Binaries & Tools** — see that section above. All five (mihi, iam, bannermanor, hapi, darshini) are now scaffolded/shipped.

### Network-tools family (proposed 2026-05-20)

Network observability tools — `ping`/`traceroute`/`dig`/`curl` territory. Each lives as a standalone repo (NOT in `kriya`; kriya is coreutils-strict, ping etc. are iputils/inetutils-family across every distro). Sanskrit/Hindi-named substrate library, English-wordplay-named user-facing tools, per `feedback_naming_lanes`. First tool drives the library; second consumer triggers the extraction per the `mihi → iam/chakshu` pattern.

**✅ Scaffolded (2026-06): `yo` 0.5.2 (ping) + `dig` 0.3.0 (DNS)** — both now in *Binaries & Tools (pre-1.0)* above, consuming the agnos 1.45.x ring-3 net syscalls (`yo` → `icmp_echo`#55; `dig` → UDP `udp_bind`/`send`/`recv`/`unbind` #51-54). **`dig` is the second concrete consumer** whose duplication-with-`yo` triggers the `taar` extraction. **Still planned below: `whirl` + the `taar` substrate.**

| Crate | Description | Key Consumers |
|-------|-------------|---------------|
| **whirl** | `curl + wget` unified — HTTP / HTTPS / file transfer in one verb. Man-page conceit: *"The packet whirls out; the response whirls back. Merges the historical curl + wget split; one verb for one fundamental network operation."* Smart-default behavior: auto-detect download-to-file (binary) vs print-to-stdout (text), follow redirects, recursive fetch (`-r`, the wget side), POST (`-d`), arbitrary methods (`-X`). One tool, combined feature set, no curl-vs-wget mental tax. English-wordplay lane. | end-user shells; download scripts; ark/zugot fetch paths long-term |
| **taar** | Network-probe substrate library — ICMP send/recv, socket primitives, DNS resolution, raw packet construction, HTTP client primitives, TLS handshake hooks. Hindi/Sanskrit तार (*wire/string/connection*). **Extraction order (user-decided 2026-05-23): yo → dig → extract taar → whirl.** yo ships first with ICMP needs vendored locally; dig adds the second concrete consumer surface (DNS + UDP/TCP-53 sockets — orthogonal to ICMP); the duplication friction between yo + dig is the extraction trigger. taar opens with two real consumers shaping the API, designed as per-protocol submodules (`taar/src/icmp.cyr` + `dns.cyr` + `socket.cyr` + the kernel-syscall shim). whirl arrives as the third consumer of an already-modular taar; adds `tcp.cyr` + `tls.cyr` + `http.cyr` as additive submodules. The three-consumer brainstorm window pins taar's eventual scope; it does NOT mandate cycle-open extraction. Same shape as mihi → iam/chakshu (2026-05-20). | yo, dig, whirl (all three); future yodel-trail / etc. |

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
| **anuenue** (**SHIPPED v1.1.1**, binary `anuenue`) | `lolcat`-equivalent — rainbow-tint stdin → stdout, per-character HSV cycling, optional animation flag (`-a`). Hawaiian ānuenue (*rainbow*); second Pacific Islands name in the AGNOS naming surface after `hapi`. Direct-semantic non-English lane. Pipe filter — `iam \| anuenue`, `bnrmr "AGNOS" \| anuenue` — **plus a positional-text mode** (`anuenue TEXT…` rainbows its argv and exits, added v1.1.1 so it's usable on agnos, which has no pipes/EOF; `run /bin/anuenue AGNOS`). Consumes `darshana` (ANSI), `sakshi`, `agnostik`. Cyrius pin 6.0.56; builds `--agnos` (static ELF64 on `/bin`). | end-user shells; agnoshi MOTD pipeline; iam / bannermanor display chains; demo / streaming flair |

---

## Extraction Guidelines

Extract when **3+ projects** implement the same pattern. Until then, keep it in-project.

- You're copying a module between repos
- Two projects have different implementations of the same algorithm
- A bug fix in one project should automatically benefit another

See [monolith-extraction.md](../../archive/monolith-extraction.md) (archived 2026-05-12) for the daimon/hoosh/agnoshi extraction plan.

See [k8s-roadmap.md](../vision/architecture/k8s-roadmap.md) for stiva + nein + majra + kavach orchestration platform.

---

*Last Updated: 2026-06-14 (full local-VERSION sweep — 80 repos; the 1.41→1.45 kernel arc + cyrius 6.0→6.2 drift; new libs ganita/bayan/rosnet/tyche; graduations sit→1.0.1 + darshini→1.2.0 + yo/dig scaffolded; agnos→1.45.4, agnoshi→1.7.0, owl→1.4.0 w/ sit→tls agnos-compile note). Earlier 2026-06-07 (doc sweep — agnos→1.43.2, agnoshi→1.4.5 + verb_abspath ls fix, anuenue shipped v1.1.1 w/ positional-text mode, gnoboot refs→0.5.0). Earlier 2026-05-26 (cyrius-polyomino 0.1.0 scaffold added to Non-Library Projects — original IP-clear falling-block puzzle, polyomino/tetromino mechanics in the public domain, The Tetris Company branding hard-excluded; self-rolled cyrius-doom/cyrius-bb lineage). Earlier 2026-05-22 context: kii 0.1.0 scaffold added — image→ANSI/ASCII converter, Hawaiian Polynesian micro-cluster with hapi + anuenue; post-Attempt-92 r8169 PARTIAL + DHCP gate fix landed in agnos 1.32.0 main.cyr:655; agnos 1.31.7 closed 2026-05-22 / 1.32.0 opened same day for networking arc). Earlier 2026-05-20 PM context: bannermanor + iam + mihi graduated to v1.0+; agnos 1.31.2 / agnoshi 1.3.3 pin-graduations to cycc 6.0.1; gnoboot 0.4.2.*
