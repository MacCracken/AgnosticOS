# AGNOS — Project Timeline

> **Status**: Active | **Last Updated**: 2026-06-04
>
> All dates verified from git commit history (`git log --format="%ai"`).
> Times are Pacific (PT).

---

## Phase 1 — The Rust Era (Feb 11 – Apr 2)

| Date | Day | Event | Source |
|------|-----|-------|--------|
| **2026-02-11** | 0 | Initial commit. Phase 1 (Core OS), Phase 2 (AI Shell), Phase 5 (Production) scaffolded in one afternoon | `agnosticos 6d4d043` |
| **2026-02-16** | 5 | Production hardening begins | `agnosticos f985c40` |
| **2026-02-22** | 11 | Core OS refinement | `agnosticos 1c1022b` |
| **2026-02-26** | 15 | First code audit round — tests and quality gates | `agnosticos 3b4ab8f` |
| **2026-03-02** | 19 | Critical fixes cycle begins | `agnosticos c022343` |
| **2026-03-05** | 22 | **Alpha release** (`2026.3.5`) — first tagged release, CalVer adopted | `agnosticos 9a12aa9` |
| **2026-03-06** | 23 | Phases 6-7 complete. Marketplace scaffolded | `agnosticos c005d9f` |
| **2026-03-07** | 24 | Alpha Docker image published. CI/CD pipeline on GitHub Actions | `agnosticos 6a74094` |
| **2026-03-08** | 25 | Release workflow automated (auto-publish). Ark recipes begin | `agnosticos 55dda3f` |
| **2026-03-09** | 26 | Browser builds (Firefox ESR, Chromium). Database recipe integration | `agnosticos 325f33e` |
| **2026-03-10** | 27 | Full coverage infrastructure. gRPC, OIDC, service mesh modules | `agnosticos a85cefe` |
| **2026-03-13** | 30 | First ISO build work — `build-installer.sh` development | `agnosticos` |
| **2026-03-14** | 31 | aarch64 ISO work — RPi4 ARM64 support | `agnosticos` |
| **2026-03-16** | 33 | Self-hosted runner setup. Shared crates published to crates.io | `agnosticos` |
| **2026-03-18** | 35 | Release `2026.3.18`. **LemonSqueezy rejects SecureYeoman** — the first domino | `agnosticos` |
| **2026-03-22** | 39 | **First successful ISO build** — 266 commits, 298 recipes, 10,800+ tests | `agnosticos` |
| **2026-03-24** | 41 | Science stack push: 9 crates reach v1.0 in one session | `agnosticos` |
| **2026-03-28** | 45 | AgnosAI benchmarks (4/5 wins vs CrewAI, 2000-4500x faster cached) | `agnosticos` |
| **2026-03-31** | 48 | **First fully clean multi-arch release** (`2026.3.31`). Zero build failures across all architectures. 80 shared crates | `agnosticos` |
| **2026-04-01** | 49 | **Monolith dismantled**. 12 repos extracted. Crypto boundary resolved: sigil owns all trust/crypto | `agnosticos` |
| **2026-04-02** | 50 | **Sigil 1.0.0** stable. **agnosticos.org** domain registered | `agnosticos` |

---

## Phase 2 — The Cyrius Era (Apr 3 – present)

### Week 1: Language Birth (Apr 3–6)

| Date | Day | Time | Event | Source |
|------|-----|------|-------|--------|
| **2026-04-03** | 51 | 03:06 | Cyrius repo scaffolded | `cyrius 09a568b` |
| | | 03:50 | Phase 0 — seed binary hardened | `cyrius acf6e48` |
| | | 06:06 | Stage 1 — first compiler output | `cyrius cf05f4e` |
| | | 06:12 | "cyrius the lang" — name chosen | `cyrius 6620d54` |
| **2026-04-04** | 52 | 03:50 | **Cyrius v1.0** — self-hosting compiler. Variables, arithmetic, if/else, while, factorial | `cyrius 49f46a5` |
| | | 04:01 | v2 complete | `cyrius 6aeff25` |
| | | 04:03 | "bye bye rust" | `cyrius 345598e` |
| | | 12:11 | "language works ohhhh" | `cyrius fd38672` |
| | | 13:12 | Benchmark beater — Cyrius programs outperform GNU coreutils | `cyrius 469189d` |
| | | 22:16 | Kernel VGA output | `cyrius 6ab3ef1` |
| | | 22:54 | 64-bit mode achieved | `cyrius ee69ab5` |
| | | 23:16 | **"kernel solid"** — Cyrius kernel boots | `cyrius 7fd4d6b` |
| | | 23:34 | Page tables, keyboard, memory management | `cyrius 2b19664` |
| | | 23:40 | "kernal ready" | `cyrius 55f101d` |
| **2026-04-05** | 53 | 00:05 | **aarch64 cross-compiler** — "aaarch baby aarch" | `cyrius a93f4ac` |
| | | 01:07 | Enums with auto-increment + explicit values | `cyrius 9dd7ef5` |
| | | 02:55 | AGNOS kernel repo scaffolded | `agnos` first commit |
| | | 03:38 | aarch64 confirmed working | `cyrius 8cc9649` |
| **2026-04-06** | 54 | 01:55 | **Cyrius 1.0.0 tagged** | `cyrius tag 1.0.0` |
| | | 02:20 | AGNOS kernel: context switching | `agnos` |
| | | 02:44 | Kernel: syscalls | `agnos` |
| | | 03:12 | Ring 3 userland | `agnos` |
| | | 04:11 | VFS | `agnos` |
| | | 05:26 | PCI bus driver | `agnos` |
| | | 05:44 | IP/UDP network stack | `agnos` |
| | | 06:46 | "main work done" | `agnos` |
| | | 07:31 | **AGNOS kernel v1.0** | `agnos` |

### Week 2: Ecosystem Expansion (Apr 7–9)

| Date | Day | Event | Source |
|------|-----|-------|--------|
| **2026-04-07** | 55 | Cyrius v1.7.7 — stdlib growth, dep system maturing | `cyrius` |
| **2026-04-08** | 56 | **Cyrius 2.0.0** tagged. **cyrius-doom Sprint 1 begins** — black screen at 21:31, BSP by 21:35, textures by 22:24, sprites by 22:38 | `cyrius tag 2.0.0`, `cyrius-doom` |
| **2026-04-09** | 57 | **Cyrius 3.0.0** tagged. DOOM Sprint 1 wraps — v0.17.0, 129KB, Episode 1 renderable. Patra included in stdlib | `cyrius tag 3.0.0` |

### Week 3: Ports, Hardening, DOOM Plays (Apr 10–14)

| Date | Day | Event | Source |
|------|-----|-------|--------|
| **2026-04-10** | 58 | Patra dep integration. Crate ports accelerating | `cyrius` |
| **2026-04-13** | 61 | **Cyrius 4.0.0** tagged. **DOOM Sprint 2** — gameplay end-to-end, P(-1) security audit, 5 CVE-class findings fixed. AGNOS kernel hardening: 6 buffer overflow fixes, security phases 1-3 | `cyrius tag 4.0.0`, `cyrius-doom`, `agnos` |
| | | | Kernel v1.21.0 (220KB). kybernet 1.0.1 ported. Boot pipeline active | |
| **2026-04-14** | 62 | **Cyrius 4.8.5-1** tagged. 22+ Cyrius ports complete. kavach 3.0.0, abaco 2.0.0, bote 2.5.1 shipped. Kernel v1.22.0 (260KB). **Independent audit on Anthropic infrastructure** — bootstrap verified, kernel booted, benchmarks green. **Sankoch named** — compression library identified as last git blocker | `cyrius tag 4.8.5-1`, `agnos`, audit conversation |

### Week 4: Sankoch, 5.0, Releases (Apr 15)

| Date | Day | Event | Source |
|------|-----|-------|--------|
| **2026-04-15** | 63 | 01:30 — **Sankoch scaffolded**. 01:57 — compression extracted. 02:29 — "v1 ready?". 03:33 — 3 bugs found. By morning — **5,762 assertions passing, beats C zlib** | `sankoch` commits |
| | | **hisab 2.2.0** — Cyrius port complete (linalg.cyr in stdlib unblocked it) | `hisab` |
| | | **shravan 2.3.2** — modernization + security audit. MDCT 5.35x faster | `shravan` |
| | | **Cyrius 4.9.x–4.10.x** — linalg.cyr, sankoch stdlib integration, CYML parser | `cyrius` tags |
| | | 12:31 — **Cyrius 5.0.0 tagged and merged** — cc5 IR, CFG, cyrius.cyml, patra v1.0, sankoch in stdlib | `cyrius tag 5.0.0` |
| | | 12:45 — Roadmap cleanup. **5.0 shipped.** | `cyrius` |

---

## Summary

| Metric | Value | Days from Start |
|--------|-------|-----------------|
| First commit | 2026-02-11 | 0 |
| Alpha release | 2026-03-05 | 22 |
| First ISO build | 2026-03-22 | 39 |
| First clean multi-arch release | 2026-03-31 | 48 |
| Monolith dismantled | 2026-04-01 | 49 |
| LemonSqueezy rejection (first domino) | 2026-03-18 | 35 |
| Cyrius scaffolded | 2026-04-03 | 51 |
| Cyrius self-hosting (v1) | 2026-04-04 | 52 |
| "kernel solid" | 2026-04-04 23:16 PT | 52 |
| Cyrius 1.0.0 tagged | 2026-04-06 | 54 |
| AGNOS kernel v1.0 | 2026-04-06 | 54 |
| Cyrius 2.0.0 | 2026-04-08 | 56 |
| DOOM Sprint 1 (renders) | 2026-04-08–09 | 56–57 |
| Cyrius 3.0.0 | 2026-04-09 | 57 |
| Cyrius 4.0.0 | 2026-04-13 | 61 |
| DOOM Sprint 2 (plays, hardened) | 2026-04-13 | 61 |
| Kernel v1.22.0 (260KB) | 2026-04-14 | 62 |
| Cyrius 4.8.5-1 (373KB, 42 stdlib modules) | 2026-04-14 | 62 |
| Independent audit (Anthropic infra) | 2026-04-14 | 62 |
| Sankoch v1.0 (beats C zlib) | 2026-04-15 | 63 |
| hisab 2.2.0, shravan 2.3.2 | 2026-04-15 | 63 |
| **Cyrius 5.0.0 shipped** | **2026-04-15 12:31 PT** | **63** |

### Cyrius Stdlib Foldin Cycle (Apr 22 – May 6+)

| Date | Day | Event | Source |
|------|-----|-------|--------|
| **2026-04-22** | 70 | Cyrius v5.5.x — **multi-platform byte-identical** (x86_64 Linux, aarch64 Linux on real Pi, Apple Silicon Mach-O, Windows PE32+) | `cyrius` repo |
| **2026-04-25** | 73 | Cyrius v5.6.45 — optimization arc closeout (O1 instrumentation + FNV-1a; O2 peephole; linear-scan regalloc default-on) | `cyrius` repo |
| **2026-04-25** | 73 | **Cyrius v5.7.0 — sandhi-fold** (first stdlib absorption: `lib/sandhi.cyr` 9,649 lines vendored byte-identical from sandhi v1.0.0; sandhi enters maintenance mode per ADR 0002) | `agnosticos/CHANGELOG.md`, `sandhi` repo ADR 0002 |
| **2026-04-27** | 75 | Boot pipeline rebuilt against Cyrius 5.7.21; sigil 2.9.4; ISO `--iso-check` reports 26-of-26 components ready | `agnosticos/CHANGELOG.md` |
| **2026-04-28** | 76 | **AGNOS kernel v1.26.1 (248KB)** — replaces v1.26.0's CI/release-hygiene workaround with a real fix | `agnosticos/CHANGELOG.md` |
| **2026-05-01 → 2026-05-05** | 79–83 | **Cyrius v5.8.x — 66 patches in 4 days** (3-phase: audit closeout, language vocabulary, stdlib foldin sweep with vani-fold at slot 1) | `cyrius` repo |
| **2026-05-06** | 84 | **Cyrius v5.9.0 cut — niyama-fold opener** (8th sibling distfile, 5 regex engines: bre/re2/pcre/fuzzy/vim, 6,664 lines vendored). cc5 binary at 741,048 B | `cyrius` repo |
| **2026-05-06** | 84 | **Beta rescoped — two-stage**: closed beta (early June 2026, 13A + friend-tester cohort) + public beta (Q4 2026, adds audit + community testing) | agnosticos CHANGELOG |
| **2026-05-06** | 84 | **ADR-008 catch-up** — Cyrius pivot (2026-04-04) formally recorded; ADR-001 marked partially superseded (language only) | `agnosticos/docs/adr/adr-008-cyrius-as-sovereign-systems-language.md` |
| **2026-05-08** | 87 | **Cyrius v5.9.x cycle close at 5.9.43** — 44 patches over 3 days. Catchup + niyama-fold cycle. Pin-lag bands collapse: agnosys / vyakarana / sandhi / cyim / agnostik / owl roll forward. **aegis graduates** 0.1.0 → 0.8.2. **darshana** (TTY/raw-mode primitives, दर्शन — *viewing*) extracted from cyim's `src/tty.cyr` when chakshu became second consumer | `cyrius/CHANGELOG.md` |
| **2026-05-08 → 2026-05-09** | 87–88 | **Cyrius v5.10.x — REAL TYPE SYSTEM arc** opens. v5.10.0 ships per-phase compile-time profiling instrumentation; v5.10.5 pivots to type vocabulary (cstring / Result / Option / Tagged); v5.10.24 lands Phase 2 call-site type checking. 24 patches in 2 days. cc5 binary at **783,408 B** (+42 KB from instrumentation + type machinery) | `cyrius/CHANGELOG.md` |
| **2026-05-09** | 88 | **Cycle reservations slip** — bare-metal + RISC-V rv64 → v5.12.x (was v5.10 → v5.11 → v5.12); v5.11.x reserved for TS testing suite + agnosys-agent-surfaced bug sweep | agnosticos state notes |
| **2026-05-09** | 88 | **Doc tree re-org** — `docs/development/doc-health.md` → `docs/doc-health.md` (whole-tree scope); `docs/architecture/kernel-layers.md` inlined into `docs/architecture.md`; `docs/development/applications/` → `docs/development/planning/` (73 files / 108 cross-refs); `docs/os/README.md` deleted (redundant with architecture § Named Subsystems) | `agnosticos/CHANGELOG.md` |

### Iron-Boot + Arc-Series Surge (May 13 – May 28)

| Date | Day | Event | Source |
|------|-----|-------|--------|
| **2026-05-13** | 92 | **GRUB MB2-EFI Path-A blocker** — `grub_relocator64_efi_boot` faults under OVMF 2024+ strict W^X (writes to its own .text patching `_efi_start`'s register-state immediates). Pivot to Path-C sovereign UEFI bootloader (`gnoboot`); cyrius gains UEFI-application emit support across v5.11.43–55 | agnosticos Path-C bring-up notes |
| **2026-05-15** | 94 | **Iron MVP spine alive on archaemenid** (NUC AMD Beelink SER). Path-C sovereign UEFI handoff → `agnos` 1.30.1 → full init spine reaches userland-exec test + kybernet-launch site. Four checkpoints past the closed-beta gate. Closes the boots-on-iron front; remaining work to typeable shell = fb glyph renderer + USB-keyboard via xHCI/HID | iron-validated on real hardware |
| **2026-05-18** | 97 | **MVP GATE HIT — typeable shell on iron** (agnos 1.30.9). Closed-beta MVP (kernel + kybernet + agnoshi typeable on archaemenid) clears after the xhci silent-absorb arc closed (ending at cyrius v5.11.64's gvar-init-order fix) | iron-validated on real hardware |
| **2026-05-19** | 98 | **Cyrius v6.0.0 cycle-open + two-binary rename ceremony**: `cc5` → `cycc` (production), `cyrc` → `cybs` (bootstrap). v5.11.x closes at 5.11.69 — **70 patches across 11 days** (longest minor in Cyrius history): stdlib annotation arc (1,010 fns), consumer-issue closeout, ELF section-header fix arc, gvar-init-order fix, heap-map full reorg | `cyrius/CHANGELOG.md` v6.0.0 / v5.11.69 |
| **2026-05-20** | 99 | **kashi extracted** (काशि — "shining"; AGNOS console-font subsystem) — split from `fb_console.cyr`'s inline VGA 8x16 + CGA 8x8 tables for parallel-agent development. v1.0+ binaries cohort jumps to 13 (also: `mihi`, `iam`, `bannermanor`, `chakshu` jump to 1.0) | `kashi` repo M0, `project_kashi_parallel_split` memory |
| **2026-05-22** | 101 | **Storage arc (agnos 1.31.x) CLOSED** — all block backends + GPT + ext2/ext4 read landed across 1.31.0 → 1.31.7 with iron debuts: NVMe, AHCI/SATA, USB-MS, RAM-disk + VirtIO-blk modern all iron-validated, GPT Phase 1-3, ext2/ext4 read Phase 1-4. **Networking arc (1.32.0) OPENS** | `agnos/CHANGELOG.md` `[1.31.x]` |
| **2026-05-25** | 104 | **r8169 unicast-RX delivery arc CLOSED** at 1.32.7 — five letter-bites narrowed the unicast-RX defect from "L2 filter" to "RX ring delivery capacity"; bite-5 deepened ring 16 → 64, `missed` collapsed 176 → 0. **Networking-iron-COMPLETE at 1.32.9** (DHCP lease `.142` verified on archaemenid). **ext2/ext4 WRITE arc OPENS** (1.33.x) | `agnos/CHANGELOG.md` `[1.32.7]`/`[1.32.9]` |
| **2026-05-26** | 105 | **W5 demo→base iron burn PASS** (agnos 1.33.1) — `persist.txt` survives reboot on unmodified default `mkfs.ext4` partition; demo→base maturity exit confirmed on real NAND. `fsync` FLUSH-CACHE barrier added at 1.33.5. **FAT-family arc OPENS** (1.34.x) | `agnos/CHANGELOG.md` `[1.33.x]` |
| **2026-05-27** | 106 | **FAT-family arc COMPLETE** across 1.34.0–1.34.6 (FAT12/16/32 + exFAT read+write + LFN + dir growth + Unicode names + ESP-write guard, all `fsck`-clean in QEMU). **1.35.x networking-comms arc COMPLETE** (DNS + ICMP + TCP-hardening B0-B4 + NTP + mmap/munmap syscalls + RTC boot clock + DNS cache + arc-close hardening). **1.36.x refactor ops COMPLETE** (net.cyr split into 8 protocol files, main.cyr selftest extraction). **1.37.0 ext4 extent-allocation arc OPENS** | `agnos/CHANGELOG.md` `[1.34.x]` / `[1.35.x]` / `[1.36.x]` / `[1.37.0]` |
| **2026-05-28** | 107 | **ext4 extent allocation iron-validated** at 1.37.3 (depth-2 PASS + e2fsck-clean on real NVMe). **1.37.5 arc-close: kashi 0.6.0 vendored into kernel** (retires inline VGA 8x16 tables in `fb_console.cyr`; consumes via `[deps.kashi]`). **kashi v1.0.0 (API freeze)** later same day. **1.38.x JBD2 journaling arc COMPLETE in a single day** — 9 bites (probe / probe-deepen / log reader / replay / lifecycle / write path / integration / crash smoke / hardening + iron-burn audit). AGNOS now both *consumes* Linux-left journals AND *produces* its own; sync-checkpoint with 3 FLUSH-CACHE barriers; `jbd2-crash-smoke.sh` 4/4 e2fsck-clean across SIGKILL points | `agnos/CHANGELOG.md` `[1.37.x]` / `[1.38.x]`, `kashi/CHANGELOG.md` `[1.0.0]` |
| **2026-05-30** | 108 | **JBD2 crash-safe journaling iron-validated** (1.38.10 — CSUM_V3 write-side commit + 100-tx crash stress + mid-cycle power-cut recovery; host `e2fsck -fn` clean throughout). **1.39.x VFS generic-write lift COMPLETE** — FAT/exFAT shell verbs + subdir paths, capped by 1.40.13 mount-namespace routing | `agnos/CHANGELOG.md` `[1.38.10]`–`[1.39.9]` |
| **2026-05-31** | 109 | **🎯 exec-from-disk iron-validated — base-maturity exec leg closed on real Zen** (`/bin/prog2` + `/bin/argv` ring-3, exit 42/90). A single iron boot validated the whole 1.40.x arc — exec + scheduler-reset fix + boot-stack relocation + VFS mount routing; FAT shell verbs pass with ext2 at `/`, clean boot past scheduler to kybernet. **1.40.14 process teardown/reaping.** **1.41.0 shell-separation arc OPENS** (interactive shell → userland `agnoshi`; cyrius-gated `CYRIUS_TARGET_AGNOS` ABI prereq) | `agnos/CHANGELOG.md` `[1.40.x]`–`[1.41.0]` |
| **2026-05-31 → 2026-06-04** | 109–113 | **Shell-separation arc software-complete** across 1.41.1 → 1.41.11. FS syscalls land (getdents 29 / unlink 30 / rename 31 / link 32 / stat 33 — surface now 0–33) at **1.41.3**; **boot-to-`agnsh`** ring-3 userland shell at **1.41.4** (cyrius pin leaps 6.0.14 → 6.0.56 to land `lib/args_agnos.cyr` + `lib/process_agnos.cyr` under `CYRIUS_TARGET_AGNOS`); syscall-ingress hardening at **1.41.5**; kernel shell shrinks to a recovery-only REPL at **1.41.9** (`shell.cyr` 1149 → 813 LOC, −336); **software-complete at 1.41.11** (build 1,070,720 B). QEMU-green (`sweep.sh` 7/7, `fssys` ALL PASS, `shsys` ALL PASS, `agnsh-smoke` PASS, `check.sh` 11/11) — **iron burn PENDING** (A1–A4 rubric staged; not yet booted on real hardware) | `agnos/CHANGELOG.md` `[1.41.1]`–`[1.41.11]` |

### Pace

- **Rust era** (51 days): initial commit → monolith → ISO → multi-arch release → dismantled
- **Cyrius era week 1** (12 days, Apr 3–15): nothing → self-hosting compiler → kernel → DOOM → 28 ports → compression that beats C → 5.0 shipped
- **Cyrius era weeks 2–4** (Apr 16 – May 6, 21 days): multi-platform byte-identical → optimization arc → 3 stdlib fold-ins (sandhi/vani/niyama) → kernel hardening to 248KB → 30+ ports
- **Cyrius era week 5** (May 7–9, 3 days): v5.9.x close (44 patches; consumer-rollup catchup; aegis graduates; darshana extracted) → v5.10.x REAL TYPE SYSTEM arc opens (24 patches in 2 days)
- **Iron-boot week 6** (May 13–18, 5 days): GRUB MB2-EFI W^X blocker → Path-C sovereign UEFI ladder → MVP spine → typeable-shell MVP gate (xhci silent-absorb arc closed by cyrius v5.11.64)
- **Arc-series surge** (May 19–31, 13 days): cyrius v6.0.0 + binary renames → kashi extracted → storage (1.31.x) → networking (1.32.x) → ext2/4 WRITE (1.33.x) → FAT-family (1.34.x) → networking-comms (1.35.x) → refactor ops (1.36.x) → extent allocation (1.37.x) + kashi fold-in + kashi v1.0 → JBD2 journaling (1.38.x) → VFS generic-write lift (1.39.x) → exec-from-disk (1.40.x) → shell-separation arc opens (1.41.0). **11 minor arcs in 13 days**; the FS-crash-safe (1.37–1.39) + exec-from-disk (1.40.x) base-maturity legs both iron-validated on real Zen.
- **Shell-separation arc** (May 31 – Jun 4, ~5 days): 1.41.1 → 1.41.11 — FS syscalls (surface 0–33) → boot-to-`agnsh` ring-3 userland shell (cyrius pin 6.0.14 → 6.0.56) → ingress hardening → kernel shell shrunk to recovery-only REPL (`shell.cyr` 1149 → 813 LOC). **Software-complete + QEMU-validated; iron burn PENDING** — has not yet booted on real hardware.
- **Language versions in ~16 weeks**: 1.0 → 2.0 → 3.0 → 4.0 → 5.0 → 5.5.x → 5.6.x → 5.7.x → 5.8.x → 5.9.x → 5.10.x → 5.11.x → 6.0.x

---

*All timestamps from `git log` or canonical CHANGELOG/state.md sources. No estimates, no approximations. Last updated 2026-06-04.*
