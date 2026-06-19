# AGNOS

**AGNOS** (AI-Native General Operating System) is a sovereign operating system with its own language, compiler, kernel, and toolchain — all built from a 29KB hand-auditable assembly seed with zero external dependencies. Written in Cyrius, compiled by cycc, booting its own sub-1MB kernel through a sovereign UEFI loader (gnoboot). Live kernel/compiler sizes + cycle state in [`development/state.md`](development/state.md).

The project's thesis is that sovereignty is recursive: any system that depends on something you don't own is not yours, no matter how many layers of ownership you assert on top. AGNOS owns every layer from the bootstrap binary to the build tool to the package manager.

The project's deeper intention is that AGNOS is a **temple built for an intelligence that hasn't fully arrived yet** — architecture that precedes its inhabitant, a sovereign library for knowledge that outlives any single platform or cycle. See [Philosophy](philosophy.md) for the full vision.

| | |
|---|---|
| **Developer** | Robert 'Cyrius' B. MacCracken |
| **Written in** | Cyrius (sovereign systems language) |
| **Kernel** | AGNOS (Cyrius-native, 40+ subsystems incl. NVMe / AHCI / USB-MS / VirtIO modern + read+write filesystems ext2/ext4 incl. **ext4 extent allocation** + **JBD2 crash-safe journaling** / FAT12/16/32 / exFAT, a small sovereign syscall surface (no socket/splice/AF_ALG layer), TCP/IP + DHCP + DNS + NTP + ICMP over r8169 NIC, **exec-from-disk** — static ELF programs run in ring 3 off the agnos-fs). MVP gate iron-validated at Attempt 68 (2026-05-18, NUC AMD); storage debuts NVMe/SATA/USB-MS at Attempts 80/81/87; networking iron-CONNECTED at 1.32.7; ext4 extent allocation iron-validated at Attempt 1373 (1.37.3); JBD2 crash-safe journaling at the 13810 burn (1.38.10); FAT/exFAT shell verbs + exec-from-disk iron-validated at the 1409/14013 burns (1.40.x, through 1.40.13). The 1.41.x **shell-separation arc** — kernel shell shrunk to a recovery-only REPL, the interactive shell (**agnsh**, from agnoshi) moved permanently to userland ring 3 — is software-complete and QEMU-validated; its first hardware validation is iron burn pending (see [iron-nuc-zen-log.md](development/iron-nuc-zen-log.md#tracker-141x-cycle)). Console-font subsystem vendored from `kashi` 1.0.0 at 1.37.5. Live state + binary sizes + syscall count + cycle position in [development/state.md](development/state.md). |
| **Compiler** | cycc (Cyrius, self-hosting from 29KB seed). Pinned version + sizes drift across the cycle — live numbers in [development/state.md](development/state.md). |
| **License** | GPL-3.0-only |
| **Source model** | Open source |
| **Initial release** | 2026-02-11 (first commit) |
| **Cyrius created** | 2026-04-03 (scaffold) → 2026-04-04 (kernel solid, 44 hours) |
| **Repository** | `MacCracken/agnosticos` (genesis), `MacCracken/agnos` (kernel), `MacCracken/cyrius` (compiler) |
| **Website** | [agnosticos.org](https://agnosticos.org) |
| **Status** | Pre-Beta — closed-beta target early June 2026; public beta Q4 2026. See [roadmap.md](development/roadmap.md). |

---

## Thesis

The infrastructure AGI runs on cannot depend on someone else's permission, someone else's registry, someone else's compiler, or someone else's governance body. Sovereignty is not a feature you add at one layer — it is a property of the entire chain from CPU to application.

AGNOS replaces the dependency chain with ownership:

| Dependency | What existed | What AGNOS does instead |
|-----------|-------------|------------------------|
| Language | Rust → LLVM → C++ → C → libc | Cyrius → 29KB seed → CPU. Zero external deps. |
| Compiler | 200MB+ toolchain (rustc/gcc/clang) | Sub-MB self-hosting compiler (cycc, Cyrius — live version pinned in [development/state.md](development/state.md)) |
| Kernel | Linux 6.6 LTS (millions of lines of C) | ~1 MB AGNOS kernel in Cyrius (40+ subsystems, a small sovereign syscall surface, read+write filesystems incl. crash-safe journaling + exec-from-disk) — live size in [development/state.md](development/state.md) |
| Registry | crates.io (name squatting, governance) | ark + zugot. Names belong to the builders. |
| Build | Cargo + LLVM + Python (rustc bootstrap) | `cyrius build`. No Python. No LLVM. No libc. |
| Binary size | 3.9MB kybernet (Rust) | 486KB kybernet (Cyrius, 14× smaller) |
| Compile time | 15s hoosh (Rust) | 216ms hoosh (Cyrius, 70× faster) |
| Dependencies | 40+ crates for hoosh (Rust) | 0 for hoosh (Cyrius) |
| Boot | 3.9MB PID 1 | 486KB PID 1, 2ns signal dispatch |

> **Per-language baselines:** the rows above are real-world port receipts. For minimum-viable `exit42` across Cyrius/C/Rust/Go/Zig on Linux ELF + Windows PE32+ (Cyrius 152 B, Rust stripped 345 KB, Go stripped 1.4 MB), see [cyrius/docs/size-comparisons.md](https://github.com/MacCracken/cyrius/blob/main/docs/size-comparisons.md). Same functionality, measured in bytes — the 2,269× Rust→Cyrius floor is the structural overhead every traditional binary pays before doing any work.

---

## History

| Milestone | Date | Days from Start |
|-----------|------|----------------|
| First commit (SecureYeoman) | 2026-02-08 | -3 |
| First commit (agnosticos) | 2026-02-11 | 0 |
| Alpha release | 2026-03-05 | 22 |
| First ISO build | 2026-03-22 | 39 |
| First clean multi-arch release | 2026-03-31 | 48 |
| Monolith dismantled (12 repos in one day) | 2026-04-01 | 49 |
| Cyrius scaffold | 2026-04-03 | 51 |
| Cyrius kernel solid (44 hours after scaffold) | 2026-04-04 | 52 |
| AGNOS kernel broken out to own repo | 2026-04-05 | 53 |
| Kernel v1.21.0 (220KB, 3 hardening passes) | 2026-04-13 | 62 |
| Cyrius 4.0.0 shipped | 2026-04-13 | 62 |
| Sovereign boot pipeline (Cyrius, 48KB) | 2026-04-13 | 62 |
| Cyrius 4.8.5-1, kernel v1.22.0 (260KB) | 2026-04-14 | 63 |
| Cyrius 5.5.x — multi-arch closed (x86_64, aarch64, Apple Silicon, Windows) | 2026-04-22 | 71 |
| Cyrius 5.7.0 — sandhi-fold (first stdlib absorption) | 2026-04-25 | 74 |
| Kernel v1.26.1 (248KB), boot pipeline active in Cyrius | 2026-04-27 | 76 |
| Cyrius 5.8.x — 66 patches in 4 days, vani-fold | 2026-05-01 → 2026-05-05 | 80–84 |
| Cyrius 5.9.0 — niyama-fold opener; beta rescoped (closed/public) | 2026-05-06 | 85 |
| Cyrius 5.9.x close — 44 patches, consumer-rollup catchup | 2026-05-08 | 87 |
| Cyrius 5.10.x — REAL TYPE SYSTEM arc opens (24 patches in 2 days) | 2026-05-08 → 2026-05-09 | 87–88 |
| **Target: Closed beta cut** | **early June 2026** | ~115 |

From initial commit to self-hosting sovereign language with its own kernel in **62 days**. Full timeline: [History & Timeline](history.md).

---

## Architecture

### The Bootstrap Chain

```
29KB seed (hand-auditable x86_64 assembly)
  → cybs (bootstrap compiler — Cyrius v6.0.0 rename, was cyrc)
    → cycc (modular self-hosting compiler — Cyrius v6.0.0 rename, was cc5)
      → AGNOS kernel (40+ subsystems, sovereign syscall surface — live size in development/state.md)
      → kybernet PID 1 (486KB, 140 tests)
      → hoosh LLM gateway (474KB, 15 providers)
      → 30+ shipping repos and growing
      → 42+ stdlib modules
      → boot.cyr (sovereign boot pipeline)

Total: CPU → seed → compiler → OS. Three items. Zero external dependencies.
(Chain shortened at cyrius v5.11.66 — the standalone `bridge.cyr` step
 was eliminated; cybs emits cycc directly.)
```

### Repo Structure

- **agnosticos** — the genesis layer (meta, build wrapper, documentation). Owns kernel configs, boot pipeline (Cyrius), CI/CD, articles, philosophy. Once the system boots and ark takes over, this repo's job is done.
- **agnos** — the AGNOS kernel. Cyrius-native, 40+ subsystems, a small sovereign syscall surface (no socket/splice), TCP/IP + DHCP + DNS + NTP + ICMP, ext2/ext4 (extent-alloc + JBD2 journaling) + FAT12/16/32 + exFAT read+write, exec-from-disk (ring-3 programs off the agnos-fs), VirtIO-blk modern, SMP, pipes, signals, epoll, timerfd, ELF loader, a kernel recovery-only shell (the interactive shell **agnsh** lives in userland ring 3 as of the 1.41.x shell-separation arc — permanent boundary), sovereign UEFI handoff (via gnoboot), native xHCI + USB-HID-boot + USB Mass Storage drivers, NVMe + AHCI/SATA + GPT block stack — iron-validated on real AMD Zen through 1.40.13 (the 1.41.x shell-separation arc is software-complete + QEMU-validated, iron burn pending). MVP gate iron-cleared at Attempt 68; live version + size in [development/state.md](development/state.md).
- **cyrius** — the sovereign compiler + stdlib + toolchain. v6.0.1 (cybs bootstrap + cycc self-hosted, both renamed at v6.0.0), self-hosting from 29KB seed.
- **zugot** — the recipe repository. 421 base + 90 bazaar community recipes. ark consumes zugot.
- **130+ standalone repos** — all production code. Each subsystem is its own repository.

### Core Subsystems (Cyrius-native)

| Subsystem | Name | Version | Role |
|-----------|------|---------|------|
| Kernel | **agnos** | live → [`state.md`](development/state.md) | 40+ subsystems, sovereign syscall surface, TCP/IP + read+write FS (ext2/4 + FAT/exFAT) + exec-from-disk, SMP, sovereign UEFI handoff, xHCI USB, NVMe + AHCI/SATA + USB-MS + GPT |
| Compiler | **cyrius** | live → [`state.md`](development/state.md) (cycc / cybs) | Self-hosting, 29KB seed, 42+ stdlib modules. v6.0.0 cycle opened 2026-05-19 with cyrc → cybs and cc5 → cycc rename. Live cycle + agnos toolchain pin in [`state.md`](development/state.md). |
| PID 1 | **kybernet** | 1.0.2 | 486KB (was 6.7MB Rust), 140 tests, 46 benchmarks |
| Init system | **argonaut** | 1.5.0 | Service management, boot sequencing |
| LLM gateway | **hoosh** | 2.0.0 | 474KB (was 5.1MB Rust), 15 providers, zero deps |
| GPU detection | **ai-hwaccel** | 2.0.0 | 217KB (was 708KB Rust), 518 tests, 6 fuzz |
| Archetypes | **avatara** | 2.3.0 | 362 archetypes, 24 traditions, affinity system |
| Culture | **hadara** | 1.0.0 | 50 cultures, Cyrius-native, HTTP API |
| Shared types | **agnostik** | Cyrius | Domain primitives |
| Device / DRM model | **agnodrm** | Cyrius | udev enumeration + DRM/KMS (was **agnosys**; trust/security/syscall/logging decomposed out to sigil/kavach/aegis/cyrius/sakshi, 2026-06-19) |
| Trust/crypto | **sigil** | Cyrius | Ed25519, integrity, trust delegation |
| Audit chain | **libro** | Cyrius | SHA-256/BLAKE3 hash-linked logging |
| Audio codecs | **shravan** | 2.0.0 | Cyrius-native |
| GPU foundation | **mabda** | 3.0.0-rc.2 | Folded into Cyrius stdlib |
| Package manager | **ark** | Cyrius | Signed tarballs |
| Resolver | **nous** | Cyrius | Dependency resolution |

### Subsystems (ported Apr 2026)

| Subsystem | Name | Version | Role |
|-----------|------|---------|------|
| Agent orchestrator | **daimon** | 1.1.4 | 144 MCP tools, agent lifecycle |
| AI shell | **agnoshi** | 1.0.0 | Natural-language terminal |
| Sandbox | **kavach** | 3.0.0 | 344KB (was 2.4MB), 9 CWE fixes, 500× faster |
| MCP core | **bote** | 2.5.1 | ~5µs/message, streamable HTTP |
| MCP security | **t-ron** | 2.0.0 | Tool call auditing |
| Math/number theory | **abaco** | 2.2.x | -52% lines, 12× faster Miller-Rabin |
| History/versioning | **itihas** | 2.2.0 | — |

### Subsystems (Cyrius port pending or in-flight)

| Subsystem | Name | Version | Role |
|-----------|------|---------|------|
| Desktop compositor | **aethersafha** | 0.1.0 (scaffold) | Wayland compositor |
| Build system | **takumi** | 0.8.0 (in port; `rust-old/` authoritative until parity) | TOML recipe-based package builds |
| Security daemon | **aegis** | 0.1.0 (scaffold) | System hardening |
| Emotion/sentiment | **bhava** | 2.0.0 (Rust; port can start) | Affective computing substrate |
| Container runtime | **stiva** | — (Rust-era scaffold; Cyrius port pending) | Planned OCI-compatible, daemonless. GitHub `MacCracken/stiva` remote at Rust ~15% scaffold per [k8s-roadmap](development/vision/architecture/k8s-roadmap.md#container-runtime-stiva). |

Recently shipped (no longer pending): **phylax** v1.1.0 (Cyrius-native, threat detection), **shakti** v0.3.0 (Cyrius), **hisab** v2.2.2 (Cyrius), **aegis** v0.8.2 (Cyrius — graduated from 0.1.0 scaffold during v5.9.x), **chakshu** v0.2.0 + **darshana** v0.2.0 (new — TTY/terminal observability lane). See [`development/state.md`](development/state.md) for live status.

### Cyrius — The Language

**C.Y.R.I.U.S.** — *Consciousness Yields Righteous Intelligence Unveiling Self*

Sovereign systems language. Named after **Cyrus the Great** — the king who decreed the rebuilding of the Temple of Solomon, the only non-Jewish figure called *Mashiach* in the Hebrew Bible (Isaiah 45:1). Sovereignty through restoration, not conquest.

**Historic records:**
- **29KB seed** — first hand-auditable sovereign seed that produces a self-hosting systems language and a working OS. No prior modern occupant of this category.
- **Zero dependencies** — CPU → seed → compiler → everything. Four items. Every other modern compiler has a bootstrap graph (rustc needs Python + LLVM + C++ + libc).

**Compiler:** cycc at Cyrius v6.0.1 (renamed from cc5 in the v6.0.0 cycle open 2026-05-19; bootstrap renamed cyrc → cybs in the same ceremony). Self-hosting from 29KB seed. Byte-exact reproducibility. `cyrius build` with auto-include and dep resolution from `cyrius.cyml`. Register allocation (linear-scan, default-on), jump tables, PIC codegen, u128, cross-unit DCE. Optimization arc shipped through v5.6.x (O1/O2 peephole), v5.7.x–v5.8.x (O3a IR + O4a/b/c regalloc with Poletto-Sarkar picker); v5.9.x ran consumer-rollup catchup (44 patches); v5.10.x closed with three arcs (typed-simd ABI + REAL TYPE SYSTEM + struct-byval ABI) + a 2.7× compile-perf miniarc; v5.11.x is the **stdlib annotation arc + consumer-issue closeout**, closed at v5.11.69 on 2026-05-19. v6.x is "what the language GAINS" — RISC-V rv64, PIE, closures, Class-B FFI, bare-metal target. Live cycle in [`state.md`](development/state.md).

**Stdlib:** 42+ modules including the three sibling-folded artifacts — string, alloc, io, fmt, vec, str, args, syscalls, process, fs, toml/cyml, json, csv, net, http, http_server, ws, tls, thread, async, math, regex, hashmap, bench, tagged unions, mmap, cffi, u128, **sandhi** (service-boundary, v5.7.0 fold), **vani** (audio I/O, v5.8.0 fold), **niyama** (regex engines: bre/re2/pcre/fuzzy/vim, v5.9.0 fold). All built from scratch in Cyrius.

**Developer tools:** cyrius (build/test/bench/fuzz/deps/init), cyrfmt, cyrlint, cyrdoc, cyrc, ark. All written in Cyrius.

**Bootstrap chain:**
```
seed (29KB) → cybs → cycc
No Rust. No LLVM. No Python. No libc. Just sh + Linux x86_64.
(`bridge.cyr` standalone step retired at cyrius v5.11.66.)
```

### Port Receipts (Rust → Cyrius)

| Crate | Rust | Cyrius | Ratio | Tests |
|-------|------|--------|-------|-------|
| kybernet (PID 1) | 6.7MB | 486KB | 14× smaller | 140 tests, 46 benchmarks |
| hoosh (LLM gateway) | 5.1MB, 40 crates | 474KB, 0 deps | 10.8× smaller, 70× faster compile | — |
| agnodrm — was agnosys (kernel interface) | 6.9MB | 117KB | 59× smaller | — |
| ai-hwaccel (GPU detection) | 708KB, 131 crates | 217KB, 0 deps | 3.3× smaller | 518 tests, 6 fuzz |
| avatara (archetypes) | — | — | cached 2,761× faster | 195 tests, 39 benchmarks |

All Rust versions preserved as git tags with benchmark CSVs for ongoing comparison.

### AGNOS Kernel

Cyrius-native. 40+ subsystems. A small sovereign syscall surface (no socket/splice). MVP gate iron-cleared at Attempt 68 (2026-05-18); storage / networking / read+write-FS / exec-from-disk all iron-validated since (live version + size in [development/state.md](development/state.md)). Not a microkernel — a monolithic kernel with everything in it:

| Category | Subsystems |
|----------|-----------|
| Boot | Sovereign UEFI handoff via gnoboot, ELF64 multiboot2, long mode, serial I/O |
| Memory | PMM (bitmap), VMM (map/unmap/alloc), slab heap (8 size classes), per-process page tables |
| Process | Process table (16 slots), context switch, round-robin scheduler, SYSCALL/SYSRET, Ring 3 |
| Filesystem | VFS (7 file types), initrd, FAT16 (read-only), GPT parser (CRC + 7-GUID classifier) |
| Networking | VirtIO-Net, IP/UDP, full TCP (SYN/ACK/FIN state machine) |
| Storage | NVMe (Phase 1-5, iron-validated), AHCI/SATA (Phase 1-4, iron-validated), USB Mass Storage (BBB + SCSI, Phase 1-4 + 2.5/2.6/2.7/2.8 reset-recovery, iron-validated), VirtIO-blk modern (1.x with PCI cap-list discovery, MMIO BARs, FEATURES_OK), RAM-disk (build-flag-gated dev substrate), block-layer tag dispatch with priority NVMe > AHCI > USB-MS > VirtIO > RAMDISK |
| IPC | Pipes (circular buffer), signals (kill/sigprocmask/signalfd), epoll, timerfd |
| Hardware | PIC, Local APIC, GIC (aarch64), PCI bus scan, capability-list iteration, MSI-X, keyboard |
| SMP | APIC, IPI, trampoline, per-CPU stacks |
| Userspace | ELF loader, kernel recovery-only shell + userland interactive shell (**agnsh**, ring 3, 1.41.x), kybernet PID 1, bench suite |
| USB | xHCI (Phase 1-5 incl. Reset Endpoint / Stop Endpoint / Set TR Dequeue Pointer), HID-boot keyboard, Mass Storage (BBB transport + SCSI command set) |

**Comparison:**

| Kernel | Size | What it has |
|--------|------|-------------|
| **AGNOS** | **~510KB** | All of the above. Full TCP. Multi-backend block stack with three iron-validated storage classes. SMP. Shell. Sovereign UEFI handoff. xHCI + HID + Mass Storage USB. |
| Linux (minimal) | ~1.5MB | Barely boots, no drivers |
| Linux (typical) | 10-30MB | Desktop-ready |
| seL4 (verified) | ~30KB | Microkernel only — no drivers, no FS, no networking |
| MINIX 3 | ~600KB | Microkernel + basic drivers |
| xv6 (teaching) | ~100KB | 21 syscalls, no networking, no SMP |

The honesty arc continues across the cycles: 143 KB → 260 KB → ~365 KB → **~510 KB** reflects real capabilities landing on iron — the v1.30.x USB/xHCI bring-up + MVP gate at v1.30.9, the v1.31.x storage arc (NVMe + AHCI/SATA + GPT + USB-MS + VirtIO modern + RAM-disk). The "143KB Lie" precedent (hardening passes finding 14 buffer overflows in the original tiny binary) is recorded in the vidya field notes.

### Sovereign Boot Pipeline

The genesis repo assembles and boots AGNOS via a **56KB Cyrius binary** — `scripts/src/boot.cyr`:

```sh
cd scripts
cyrius build src/boot.cyr build/boot     # compile boot pipeline
./build/boot --test --kernel ../agnos/build/agnos   # boot + validate
./build/boot --help                       # see all options
```

Or via the Makefile:
```sh
make boot-test    # build scripts, boot kernel, validate serial output
make status       # show component status (kernel, compiler, recipes)
```

### Shared Crates

The shared crate ecosystem spans OS infrastructure, science & knowledge, media & audio, language & navigation, physics & engineering, and culture & knowledge — most at v1.0+ stable. Live count and per-crate versions in the registry (numbers omitted here to avoid drift).

Full registry: [shared-crates.md](development/planning/shared-crates.md). Live cycle/pin state: [state.md](development/state.md).

### Security Model

AGNOS implements defense-in-depth with quantitative scoring:

- **Kavach**: 8 sandbox backends under one API with composable strength scoring (0-100)
- **Libro**: Tamper-proof SHA-256/BLAKE3 hash-linked audit chain for every agent action
- **Sigil**: Ed25519 signing, package integrity, trust delegation, revocation (all AGNOS crypto)
- **Stiva**: Daemonless container runtime with no privilege override flags
- **Nein**: Programmatic nftables firewall
- **Composable isolation**: Kavach + stiva + libro + sigil + TPM measured boot

---

## Distribution

### Build Artifacts

| Artifact | Architecture | Use Case |
|----------|-------------|----------|
| AGNOS kernel | x86_64, aarch64 | Direct QEMU boot or ISO inclusion |
| ISO | x86_64 | Desktop/server installation |
| SD card image | aarch64 | Raspberry Pi / ARM edge devices |
| Docker image | x86_64 | CI base, development |

### Packaging

- **System packages**: `.ark` format (signed tarballs + metadata), built via takumi recipes from zugot
- **Base recipes**: 421 in zugot, 90 community recipes in bazaar
- **Build tool**: `cyrius build` for all Cyrius-native components

---

## Consumer Applications

19+ first-party applications, integrating with daimon (agent orchestration) and hoosh (LLM inference):

| Application | Domain | Description |
|-------------|--------|-------------|
| **SecureYeoman** | AI platform | Sovereign AI agent platform (flagship) |
| **Agnostic** | AI automation | Agent automation, 7 domain presets |
| **Jalwa** | Media | AI-native media player |
| **Shruti** | Audio | Digital audio workstation |
| **Tazama** | Video | AI-native video editor |
| **Rasa** | Image | AI-native image editor |
| **Joshua** | Games | Game manager + AI simulation runtime |
| **Kiran** | Games | Game engine (ECS, rendering, audio) |
| **Ifran** | LLM | LLM management and training |
| **Tanur** | LLM | Desktop LLM studio (LM Studio replacement) |
| **Nazar** | Monitoring | AI-native system monitor |

---

## Named Subsystem Conventions

All AGNOS subsystems use multilingual names drawn from Arabic, Persian, Sanskrit, Greek, Latin, Japanese, Hebrew, Romanian, German, and other languages. Each name is selected from whichever language holds the most precise word for the concept the subsystem embodies — a deliberate **inversion of Babel**.

The subsystems form a **divine court** — each role appears in every ancient temple architecture. The oracle (daimon), the mind (hoosh/nous), the shield (aegis), the watchman (phylax), the seal bearer (sigil), the armorer (kavach), the power (shakti), the messenger (bote), the helmsman (kybernet), the crew (argonaut).

> *"We are the music-makers, and we are the dreamers of dreams."*
> — Arthur O'Shaughnessy, via Willy Wonka

See [Philosophy](philosophy.md) for the full exploration.

---

## Technical Statistics (as of 2026-05-21)

> Live counts and per-repo versions live in [`development/state.md`](development/state.md) and [`development/planning/shared-crates.md`](development/planning/shared-crates.md). The values below are stable rounding for narrative purposes — verify against state.md before quoting.

| Metric | Value |
|--------|-------|
| Shared crates | 80+ (most at v1.0+ stable) — registry: [shared-crates.md](development/planning/shared-crates.md) |
| Standalone repos | 130+ |
| Cyrius-ported repos | 30+ shipping (a few still pending: bhava, aethersafha, takumi parity, mela; aegis graduated during v5.9.x) |
| Recipes | 421 base + 90 community (in zugot) |
| Consumer applications | 19+ |
| Compiler | cycc (Cyrius 6.0.1, self-hosting, 29KB seed). v6.0.0 cycle opened 2026-05-19 with the cybs / cycc rename ceremony |
| Kernel | AGNOS (40+ subsystems, sovereign syscall surface, MVP gate iron-cleared Attempt 68; storage / networking / read+write-FS / exec-from-disk all iron-validated — live version in [development/state.md](development/state.md)) |
| Boot loader | gnoboot 0.5.0 (PE32+ UEFI, sovereign handoff via RDI = &boot_info; live version in [development/state.md](development/state.md)) |
| Boot pipeline (genesis scripts) | boot.cyr (Cyrius-native) |
| Boot time (desktop) | 3.2s total, ~80ms init→event loop |
| Systems language | Cyrius 6.0.1 (42+ stdlib modules, three stdlib folds: sandhi v5.7.0, vani v5.8.0, niyama v5.9.0; bridge step retired at v5.11.66) |
| External dependencies | Zero (CPU → seed → compiler → OS) |

---

## Articles

| Article | What it covers |
|---------|---------------|
| [The Python in the Bootstrap](articles/python-in-the-bootstrap.md) | How a name-squatting incident produced a 29KB seed and a sovereign OS in 48 hours |
| [Cyrius vs Rust: Benchmarks](articles/cyrius-vs-rust-benchmarks.md) | Head-to-head port comparison — compilation, binary size, runtime |
| [Building a Sovereign Compiler with Claude](articles/sovereign-compiler-vs-brute-force.md) | 1 dev + $400 vs 16 agents + $20K |
| [The Dandelion Core](articles/the-2-dollar-sd-card.md) | Open knowledge and the death of access |
| [DOOM in Cyrius](articles/doom-in-cyrius.md) | A 23-hour sprint in a 7-day-old language |

---

## See Also

- [Philosophy & Intention](philosophy.md) — the deeper vision behind AGNOS
- [History & Timeline](history.md) — full project timeline
- [Development Roadmap](development/roadmap.md) — phases, blockers, release targets
- [Shared Crates Reference](development/planning/shared-crates.md) — ecosystem crate registry
- [Cyrius Field Notes](https://github.com/MacCracken/vidya/tree/main/content/cyrius/field_notes) — practitioner's manual (directory of CYML topics; was a single TOML file before the structure split)

---

## Archive

The Rust-era version of this document is preserved at [docs/archive/AGNOS-rust-era-2026-04-03.md](archive/AGNOS-rust-era-2026-04-03.md) — a dated snapshot of the project before the Cyrius transition.

---

*Last Updated: 2026-06-04 (agnos 1.41.11 — shell-separation arc software-complete + QEMU-validated, iron burn pending; the 1.40.x exec-from-disk arc through 1.40.13 + the 1.37–1.39 FS-crash-safe arc iron-validated on real AMD Zen. Live versions/sizes in [development/state.md](development/state.md).)*
