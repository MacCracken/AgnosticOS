# AGNOS — Project History & Timeline

> **Status**: Active | **Last Updated**: 2026-05-31

---

## Timeline

| Date | Event |
|------|-------|
| **2026-02-11** | Initial commit. Kernel configuration, Phase 1 (Core OS bootable base), Phase 2 (AI Shell with human oversight), and Phase 5 (Production scaffolding) completed on Day 1 |
| **2026-02-16** | Continued Phase 5 development — production hardening and stabilization |
| **2026-02-22** | Core OS updates and refinement |
| **2026-02-26** | First code audit round — tests, fixes, quality gates |
| **2026-03-04** | Coverage expansion begins |
| **2026-03-05** | **Alpha release** (tag `2026.3.5`) — first tagged release, CalVer versioning adopted |
| **2026-03-06** | Phases 6-7 completed. Code audit work begins in earnest. Marketplace module scaffolded |
| **2026-03-07** | Alpha Docker image published (`ghcr.io/maccracken/agnosticos`). CI/CD pipeline established on GitHub Actions. Multiple audit rounds |
| **2026-03-08** | Release workflow automated (auto-publish instead of draft). Ark package recipes begin |
| **2026-03-09** | Browser builds (Firefox ESR, Chromium), CI integration, database recipe integration |
| **2026-03-10** | Full coverage infrastructure. gRPC, service mesh, OIDC modules. Multiple audit cycles |
| **2026-03-11** | Phase 14 (Edge OS Profile) added to roadmap. Continued audit and repair rounds |
| **2026-03-13** | First ISO build work begins — `build-installer.sh` development |
| **2026-03-14** | aarch64 ISO work — RPi4 ARM64 support |
| **2026-03-15** | RPi4 build fixes. Edge fleet management. Version and release patches |
| **2026-03-16** | Self-hosted runner setup begins for Tier 1 builds. Shared crates published to crates.io |
| **2026-03-17** | Audit completion rounds. Release `2026.3.17` |
| **2026-03-18** | Release `2026.3.18` — major milestone. Photis Nadi migrated from Flutter to Rust native. Consumer app packages updated. Sutra released (v2026.3.18). **LemonSqueezy rejects SecureYeoman** — the first domino |
| **2026-03-19** | Recipe updates and fixes across marketplace |
| **2026-03-20** | Self-hosted runner repaired. ISO build pipeline work continues |
| **2026-03-21** | Build improvements. stiva, nein, t-ron, impetus scaffolded. Multiple ISO build iterations |
| **2026-03-22** | **First successful ISO build** (early morning, after ~9 days of iteration). Abacus desktop calculator released. 266 commits, 298 recipes, 10,800+ tests, ~84.3% coverage |
| **2026-03-24** | Science stack push: 9 crates reach v1.0 in one session (impetus, hisab, bhava, bodh, sangha, and others). Agnosys integration ready for consumers |
| **2026-03-25** | Massive session: process refinement, SY migration planning, NPO groundwork |
| **2026-03-28** | AgnosAI benchmarks (4/5 wins vs CrewAI, 2000-4500x faster cached). Release `2026.3.29` |
| **2026-03-31** | **First fully clean release** (`2026.3.31`). All 17 artifacts built successfully — x86_64 ISO (desktop + minimal + edge), aarch64 SD card images (desktop + minimal + edge), userland tarballs, multi-arch Docker container. First release with zero build failures across all architectures. 80 shared crates (45 at v1.0+). 3 new science crates scaffolded (mastishk, rasayan, varna). 336 commits, 19 tagged releases |
| **2026-04-01** | **Monolith dismantled**. agent-runtime, ai-shell, llm-gateway, desktop-environment removed from workspace. 12 standalone repos extracted. 3 crate absorptions (bote 0.91.0, kavach 2.0.0, t-ron 0.90.0). Named subsystems: edge→seema, scheduler→samay. Crypto boundary resolved: sigil owns all AGNOS trust/crypto |
| **2026-04-02** | **Sigil 1.0.0** — first trust crate stable. Bote 0.91.0 — MCP 2025-11-25 spec compliance. **agnosticos.org** domain registered, coming-soon site deployed. 77 shared crates (56 at v1.0+). 95+ marketplace recipes |
| **2026-04-03** | **Cyrius seed** — cyrius-seed 0.1.0 (assembler, 102 tests). **Pure AGNOS desktop boot**: 3.2s, zero external deps. **Full recipe audit**: 109 marketplace recipes. **zugot** decided. **Genesis layer** architecture clarified. **Philosophy** documented. 6 new crates scaffolded (mudra, vinimaya, taal, natya, kshetra, zugot). 28 CLAUDE.md files standardized across ecosystem |
| **2026-04-04** | **Cyrius 1.0** — self-hosting compiler (29KB seed, 42ms bootstrap). Bootstrap loop closed. 44 programs, 58KB kernel (VM, processes, syscalls). Beats GNU on size (10-233x) and speed (wc 2.4x faster). 141 tests, 0 failures |
| **2026-04-05** | **Cyrius ecosystem** — 35 stdlib modules, 8 developer tools, 5 Rust crate rewrites (agnostik, agnosys, kybernet, nous, ark), aarch64 cross-compiler, 38 benchmarks, CI/CD pipelines. 186 tests, dual architecture. Day 3 and counting |
| **2026-05-15** | **Iron boot — MVP spine alive on archaemenid** (Attempt 28). After 28 attempts and a 9-letter repair ladder (F → O), `gnoboot` v0.1.0 (sovereign UEFI loader) hands off to `agnos` 1.30.1, which completes its full init spine on real hardware: GDT/TSS/IDT → APIC + timer → paging → PMM → heap → ACPI/PCI → VFS → initrd → SYSCALL → scheduler arming → idle survival → userland exec → kybernet-launch. Closed-beta gate (cp_fb 0x11 MAGENTA) re-held; four more checkpoints painted past it. The mem-iso block (Attempts 17–27) collapsed when Repair (O) deleted the 303-line post-MVP verification test per `uefi-boot-prior-art.md` §6 — turned out to be a 9-attempt detour through a test that wasn't on the boot critical path. Photo: [attempt-28-mvp-spine-alive.jpg](development/iron-nuc-zen-photos/attempt-28-mvp-spine-alive.jpg) |

---

## Development Pace

AGNOS went from initial commit to first bootable ISO in **39 days** (2026-02-11 to 2026-03-22), and from first ISO to first fully clean multi-architecture release in **48 days** (2026-02-11 to 2026-03-31).

From first commit to sovereign self-hosting language with its own kernel in **53 days** (2026-02-11 to 2026-04-04).

The Cyrius language went from nothing to a self-hosting compiler with a kernel in **one day** (2026-04-04), and through major-version cuts (1.0 → 2.0 → 3.0 → 4.0 → 5.0) reaching the v5.x stdlib-foldin cycle (sandhi v5.7.0, vani v5.8.0, niyama v5.9.0) by week 12, then the **REAL TYPE SYSTEM arc** at v5.10.x (24 patches in 2 days). The AGNOS kernel hardened from 143KB (with 14 buffer overflows — "The 143KB Lie") through 220KB (v1.21.0) → 260KB (v1.22.0) → 248KB (v1.26.1, current). 30+ subsystems ported from Rust to Cyrius, each measured against its Rust predecessor.

The shared crate ecosystem now spans 80+ crates (most at v1.0+ stable), with 19+ consumer applications developed in parallel. Live counts and per-repo versions in [`development/state.md`](development/state.md) and [`development/planning/shared-crates.md`](development/planning/shared-crates.md).

---

## Key Milestones

| Milestone | Date | Days from Start |
|-----------|------|----------------|
| First commit | 2026-02-11 | 0 |
| Alpha release | 2026-03-05 | 22 |
| First ISO build | 2026-03-22 | 39 |
| First clean multi-arch release | 2026-03-31 | 48 |
| Monolith dismantled | 2026-04-01 | 49 |
| Cyrius self-hosting | 2026-04-04 | 52 |
| AGNOS kernel (Cyrius) | 2026-04-04 | 52 |
| Cyrius ecosystem (stdlib, tools, crate rewrites) | 2026-04-05 | 53 |
| Kernel v1.21.0 (220KB, 3 hardening passes) | 2026-04-13 | 62 |
| Cyrius 4.0.0 + sovereign boot pipeline | 2026-04-13 | 62 |
| 22+ Cyrius ports, kavach 3.0, abaco 2.0, bote 2.5.1 | 2026-04-14 | 63 |
| Kernel v1.22.0 (260KB), Cyrius 4.8.5-1 (373KB) | 2026-04-14 | 63 |
| Sankoch (compression library) scaffolded | 2026-04-14 | 63 |
| Cyrius 5.0.0 shipped | 2026-04-15 | 63 |
| Cyrius v5.5.x — multi-platform byte-identical (x86_64 Linux, aarch64 Linux on real Pi, Apple Silicon Mach-O, Windows PE32+) | 2026-04-22 | 70 |
| Cyrius v5.6.x — optimization arc (O1 instrumentation + FNV-1a; O2 peephole; linear-scan regalloc default-on); v5.6.45 closeout | 2026-04-25 | 73 |
| **Cyrius v5.7.0 — sandhi-fold** (first stdlib absorption: `lib/sandhi.cyr` 9,649 lines vendored byte-identical from sandhi v1.0.0; sandhi repo enters maintenance mode) | 2026-04-25 | 73 |
| Boot pipeline rebuilt against Cyrius 5.7.21; sigil 2.9.4; ISO `--iso-check` reports 26-of-26 components ready | 2026-04-27 | 75 |
| **AGNOS kernel v1.26.1 (248KB)** — replaces v1.26.0's CI/release-hygiene workaround with a real fix | 2026-04-28 | 76 |
| Cyrius v5.8.x — **66 patches in 4 days** (3-phase: audit closeout, language vocabulary, stdlib foldin sweep with vani-fold at slot 1) | 2026-05-01 → 2026-05-05 | 79–83 |
| **Cyrius v5.9.0 cut — niyama-fold opener** (8th sibling distfile, 5 regex engines, 6,664 lines vendored). cc5 binary at 741,048 B | 2026-05-06 | 84 |
| **Beta rescoped — two-stage**: closed beta (early June 2026, 13A + friend-tester cohort) + public beta (Q4 2026, adds audit + community testing); ADR-008 catch-up records the Cyrius pivot | 2026-05-06 | 84 |
| **Cyrius v5.9.x close — 44 patches over 3 days** (catchup + niyama-fold cycle); pin-lag bands collapse — agnosys/vyakarana/sandhi/cyim/agnostik/owl all roll forward; aegis graduates 0.1.0 → 0.8.2; **darshana** extracted from cyim's TTY layer when chakshu became second consumer | 2026-05-08 | 87 |
| **Cyrius v5.10.x — REAL TYPE SYSTEM arc** opens with per-phase compile-time profiling instrumentation (v5.10.0), pivots at v5.10.5 to type vocabulary (cstring / Result / Option / Tagged) and call-site type checking (Phase 2 at v5.10.24); 24 patches in 2 days. cc5 binary at 783,408 B (+42 KB). Bare-metal + RISC-V rv64 reservation slips to v5.12.x; v5.11.x reserved for TS testing suite + bug sweep | 2026-05-08 → 2026-05-09 | 87–88 |
| **Iron boot — MVP spine alive on archaemenid** (Attempt 28, NUC AMD Beelink SER). Path C sovereign UEFI (`gnoboot`) hands off to `agnos` 1.30.1 via the sovereign boot-info struct at RDI; kernel completes its full init spine on real hardware — GDT/TSS/IDT, APIC + timer, paging, PMM, heap, ACPI/PCI enumeration, VFS, initrd, SYSCALL, stack canary, scheduler arming (closed-beta gate cp_fb 0x11 MAGENTA re-held), userland exec test, kybernet-launch site. Four checkpoints past the closed-beta gate. The mem-iso ladder (Attempts 17-27, repair letters F-O across 11 burns) closed when Repair (O) deleted the offending 303-line test block per `uefi-boot-prior-art.md` §6. Closes the "boots-on-iron" front; remaining work to typeable-shell MVP is fb glyph renderer + PS/2-emulation verification for USB keyboards. [Photo](development/iron-nuc-zen-photos/attempt-28-mvp-spine-alive.jpg) · [Attempt 28 entry](development/iron-nuc-zen-log-mvp.md) | 2026-05-15 | 93 |
| **MVP GATE HIT — typeable shell on iron** (Attempt 68, agnos 1.30.9). Closed-beta MVP (kernel + kybernet + agnoshi typeable on archaemenid) clears after the xhci silent-absorb arc closed (9 repair letters / 5 days / 19 attempts ending at cyrius v5.11.64's gvar-init-order fix; root cause was an upstream cyrius bug, not silicon) | 2026-05-18 | 96 |
| **Cyrius v6.0.0 cycle-open + two-binary rename ceremony**: `cc5` → `cycc` (production), `cyrc` → `cybs` (bootstrap); v5.11.x closes at **5.11.69** — 70 patches across 11 days, longest minor in Cyrius history | 2026-05-19 | 97 |
| **kashi extracted** (काशि — AGNOS console-font subsystem; freestanding VGA 8x16 + CGA 8x8 glyph cores split from `fb_console.cyr` for parallel-agent development). v1.0+ binaries cohort jumps to 13 with sys-info + terminal-aesthetics burst (mihi/iam/chakshu/bannermanor/darshana/hapi) | 2026-05-20 | 98 |
| **Storage arc (agnos 1.31.x) CLOSED** — all 5 block backends + GPT + ext2/ext4 read landed with iron debuts: NVMe Attempt 80, AHCI/SATA 81, USB-MS 87, RAM-disk + VirtIO-blk modern 88, ext2/ext4 read 1.31.5 + 64BIT 1.31.7 | 2026-05-22 | 100 |
| **r8169 unicast-RX delivery arc CLOSED at 1.32.7** (`missed` collapsed 176 → 0 via RX-ring deepen 16 → 64). **Networking-iron-COMPLETE at 1.32.9** (DHCP `.142` real lease on archaemenid) | 2026-05-25 | 103 |
| **W5 demo→base iron burn PASS** (Attempt 91 / agnos 1.33.1) — `persist.txt` survives reboot on unmodified default `mkfs.ext4`; **demo→base maturity exit on real NAND**. `fsync` FLUSH-CACHE barrier at 1.33.5 | 2026-05-26 | 104 |
| **FAT-family arc COMPLETE** (1.34.0–1.34.6 across FAT12/16/32 + exFAT read+write + LFN + dir growth + Unicode names + ESP-write guard; `fsck`-clean in QEMU). **1.35.x networking-comms arc COMPLETE** (DNS + ICMP + TCP hardening B0-B4 + NTP + anonymous mmap/munmap + RTC boot clock + DNS cache + arc-close hardening). **1.36.x refactor cycle COMPLETE** (net.cyr split, main.cyr selftest extraction). **1.37.x ext4 extent-allocation arc OPENS** | 2026-05-27 | 105 |
| **Iron Attempt 1373 PASS — ext4 extent allocation iron-validated** (agnos 1.37.3 depth-2 PASS + e2fsck-clean on real NVMe). **1.37.5 arc-close: kashi 0.6.0 vendored into kernel** (retires inline glyph tables). **kashi v1.0.0 API freeze** later same day. **1.38.x JBD2 journaling arc COMPLETE in a single day** — 9 bites: probe → probe-deepen → log reader → replay → lifecycle → write path → integration → crash smoke → hardening + iron-burn audit. AGNOS now both *consumes* Linux-left journals AND *produces* its own; sync-checkpoint with 3 FLUSH-CACHE barriers; `jbd2-crash-smoke.sh` 4/4 e2fsck-clean across SIGKILL points | 2026-05-28 | 106 |
| **JBD2 crash-safe journaling iron-validated** (13810 burn — CSUM_V3 write-side commit + 100-tx crash stress + mid-cycle power-cut recovery, host `e2fsck -fn` clean throughout). **1.39.x VFS generic-write lift COMPLETE** (FAT/exFAT shell verbs + subdir paths + mount-namespace routing). | 2026-05-30 | 107 |
| **🎯 exec-from-disk iron-validated — base-maturity exec leg closed on real Zen** (1409 burn: `/bin/prog2` + `/bin/argv` run in ring 3, `run: exit 42`/`90`). The `14013_final*` burn validated the whole 1.40.x arc in one boot — exec (1.40.9) + scheduler-reset fix (1.40.10) + boot-stack relocation (1.40.12) + VFS mount routing (1.40.13): FAT shell verbs pass with ext2 at `/`, clean boot past scheduler to kybernet. **1.40.14 process teardown/reaping.** **1.41.0 shell-separation arc OPENS** (interactive shell → userland `agnoshi`; cyrius-gated `CYRIUS_TARGET_AGNOS` syscall-ABI prereq). | 2026-05-31 | 108 |
| **Target: Closed beta cut** | **early June 2026** | ~115 |

---

## Compiler Binary Naming

The Cyrius compiler binary has been renamed four times over the language's evolution. Each rename created drift across scripts, CI, install paths, and docs — which motivates the final rename to `cyc` at v6.0 to end the treadmill by decoupling binary name from language version.

| Binary | Cyrius era | Notes |
|--------|------------|-------|
| `cc` | v1.x | Initial self-hosting compiler (2026-04-04) |
| `cc2` | v2.x | First rename (v2.0, ~2026-04-08) |
| `cc3` | v3.x and v4.x | Stayed across both major versions (v3.0 shipped ~2026-04-09; persisted through v4.8.x on 2026-04-14) |
| `cc5` | v5.x (current) | `cc3` → `cc5` at v5.0.0 (2026-04-15) — **cc4 was never shipped**; that binary name/version was skipped |
| `cycc` | v6.x (current) | `cc5` → `cycc` ("Cyrius Computer Compiler") at v6.0.0 ceremony on 2026-05-19. Bootstrap `cyrc` → `cybs` ("Cyrius Bootstrap") in the same ceremony. **Names are now permanent** — no `cycc7` at v7.0.0; the cc3 → cc5 (v5.0.0) → cycc (v6.0.0) sequence was the LAST name-change penalty paid |

Four renames total across four language-major transitions. The `cc5` → `cycc` event at v6.0 (landed 2026-05-19) is the one-and-done cleanup that future major versions inherit without further renaming. Back-compat symlinks `cc5 → cycc` + `cyrc → cybs` ship through the v6.0.x window (drop at v6.1.0).

---

*Last Updated: 2026-05-31*
