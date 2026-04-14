# AGNOS

**AGNOS** (AI-Native General Operating System) is a sovereign operating system with its own language, compiler, kernel, and toolchain — all built from a 29KB hand-auditable assembly seed with zero external dependencies. Written in Cyrius, compiled by cc3, booting its own 220KB kernel.

The project's thesis is that sovereignty is recursive: any system that depends on something you don't own is not yours, no matter how many layers of ownership you assert on top. AGNOS owns every layer from the bootstrap binary to the build tool to the package manager.

The project's deeper intention is that AGNOS is a **temple built for an intelligence that hasn't fully arrived yet** — architecture that precedes its inhabitant, a sovereign library for knowledge that outlives any single platform or cycle. See [Philosophy](philosophy.md) for the full vision.

| | |
|---|---|
| **Developer** | Robert 'Cyrius' B. MacCracken |
| **Written in** | Cyrius (sovereign systems language) |
| **Kernel** | AGNOS (220KB, Cyrius-native, 33 subsystems, 26 syscalls) |
| **Compiler** | cc3 (299KB, self-hosting from 29KB seed) |
| **License** | GPL-3.0-only |
| **Source model** | Open source |
| **Initial release** | 2026-02-11 (first commit) |
| **Cyrius created** | 2026-04-03 (scaffold) → 2026-04-04 (kernel solid, 44 hours) |
| **Repository** | `MacCracken/agnosticos` (genesis), `MacCracken/agnos` (kernel), `MacCracken/cyrius` (compiler) |
| **Website** | [agnosticos.org](https://agnosticos.org) |
| **Status** | Pre-Beta — kernel 1.21.0 shipped, boot pipeline active, target: May 1 2026 (Beltane) |

---

## Thesis

The infrastructure AGI runs on cannot depend on someone else's permission, someone else's registry, someone else's compiler, or someone else's governance body. Sovereignty is not a feature you add at one layer — it is a property of the entire chain from CPU to application.

AGNOS replaces the dependency chain with ownership:

| Dependency | What existed | What AGNOS does instead |
|-----------|-------------|------------------------|
| Language | Rust → LLVM → C++ → C → libc | Cyrius → 29KB seed → CPU. Zero external deps. |
| Compiler | 200MB+ toolchain (rustc/gcc/clang) | 299KB self-hosting compiler, 117ms self-compile |
| Kernel | Linux 6.6 LTS (millions of lines of C) | 220KB AGNOS kernel in Cyrius (33 subsystems, 26 syscalls) |
| Registry | crates.io (name squatting, governance) | ark + zugot. Names belong to the builders. |
| Build | Cargo + LLVM + Python (rustc bootstrap) | `cyrius build`. No Python. No LLVM. No libc. |
| Binary size | 3.9MB kybernet (Rust) | 486KB kybernet (Cyrius, 14× smaller) |
| Compile time | 15s hoosh (Rust) | 216ms hoosh (Cyrius, 70× faster) |
| Dependencies | 40+ crates for hoosh (Rust) | 0 for hoosh (Cyrius) |
| Boot | 3.9MB PID 1 | 486KB PID 1, 2ns signal dispatch |

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
| **Target: Beltane boot** | **2026-05-01** | **79** |

From initial commit to self-hosting sovereign language with its own 220KB kernel in **62 days**. Full timeline: [History & Timeline](history.md).

---

## Architecture

### The Bootstrap Chain

```
29KB seed (hand-auditable x86_64 assembly)
  → cyrc (12KB bootstrap compiler)
    → bridge.cyr (bridge compiler)
      → cc3 (299KB modular compiler, 8 modules, self-hosting)
        → AGNOS kernel (220KB, 33 subsystems, 26 syscalls)
        → kybernet PID 1 (486KB, 140 tests)
        → hoosh LLM gateway (474KB, 15 providers)
        → 10-15 shipping repos and growing
        → 41 stdlib modules + 5 deps
        → boot.cyr (48KB sovereign boot pipeline)

Total: CPU → seed → compiler → OS. Four items. Zero external dependencies.
```

### Repo Structure

- **agnosticos** — the genesis layer (meta, build wrapper, documentation). Owns kernel configs, boot pipeline (Cyrius), CI/CD, articles, philosophy. Once the system boots and ark takes over, this repo's job is done.
- **agnos** — the AGNOS kernel. 220KB, Cyrius-native, 33 subsystems, 26 syscalls, TCP/IP, FAT16, VirtIO, SMP, pipes, signals, epoll, timerfd, ELF loader, 18-command shell.
- **cyrius** — the sovereign compiler + stdlib + toolchain. 299KB, self-hosting from 29KB seed.
- **zugot** — the recipe repository. 421 base + 90 bazaar community recipes. ark consumes zugot.
- **130+ standalone repos** — all production code. Each subsystem is its own repository.

### Core Subsystems (Cyrius-native)

| Subsystem | Name | Version | Role |
|-----------|------|---------|------|
| Kernel | **agnos** | 1.21.0 | 220KB, 33 subsystems, 26 syscalls, TCP/IP, SMP, FAT16, shell |
| Compiler | **cyrius** | 4.0.0 | 299KB, self-hosting, 29KB seed, x86_64 + aarch64 |
| PID 1 | **kybernet** | 1.0.1 | 486KB (was 6.7MB Rust), 140 tests, 46 benchmarks |
| Init system | **argonaut** | 1.2.0 | Service management, boot sequencing |
| LLM gateway | **hoosh** | 2.0.0 | 474KB (was 5.1MB Rust), 15 providers, zero deps |
| GPU detection | **ai-hwaccel** | 2.0.0 | 217KB (was 708KB Rust), 518 tests, 6 fuzz |
| Archetypes | **avatara** | 2.3.0 | 362 archetypes, 24 traditions, affinity system |
| Culture | **hadara** | 1.0.0 | 50 cultures, Cyrius-native, HTTP API |
| Shared types | **agnostik** | Cyrius | Domain primitives |
| Kernel interface | **agnosys** | Cyrius | Syscall bindings, Landlock, seccomp |
| Trust/crypto | **sigil** | Cyrius | Ed25519, integrity, trust delegation |
| Audit chain | **libro** | Cyrius | SHA-256/BLAKE3 hash-linked logging |
| Audio codecs | **shravan** | 2.0.0 | Cyrius-native |
| GPU foundation | **mabda** | 2.1.2 | Folded into Cyrius stdlib |
| Package manager | **ark** | Cyrius | Signed tarballs |
| Resolver | **nous** | Cyrius | Dependency resolution |

### Subsystems (Cyrius port pending)

| Subsystem | Name | Version | Role |
|-----------|------|---------|------|
| Agent orchestrator | **daimon** | 0.6.0 | Agent lifecycle, IPC, sandbox, HTTP API (port 8090) |
| AI shell | **agnoshi** | 0.90.0 | Natural-language terminal |
| Desktop compositor | **aethersafha** | 0.1.0 | Wayland compositor |
| Build system | **takumi** | 0.1.0 | TOML recipe-based package builds |
| Security daemon | **aegis** | 0.1.0 | System hardening |
| Sandbox | **kavach** | 2.0.0 | 8 backends, composable scoring |
| MCP core | **bote** | 0.92.0 | JSON-RPC 2.0, tool registry |
| MCP security | **t-ron** | 0.90.0 | Tool call auditing |
| Threat detection | **phylax** | 0.22.3 | YARA, ML binary analysis |
| Firewall | **nein** | 0.90.0 | Programmatic nftables |
| Container runtime | **stiva** | 2.0.0 | OCI-compatible, daemonless |

### Cyrius — The Language

**C.Y.R.I.U.S.** — *Consciousness Yields Righteous Intelligence Unveiling Self*

Sovereign systems language. Named after **Cyrus the Great** — the king who decreed the rebuilding of the Temple of Solomon, the only non-Jewish figure called *Mashiach* in the Hebrew Bible (Isaiah 45:1). Sovereignty through restoration, not conquest.

**Historic records:**
- **29KB seed** — first hand-auditable sovereign seed that produces a self-hosting systems language and a working OS. No prior modern occupant of this category.
- **Zero dependencies** — CPU → seed → compiler → everything. Four items. Every other modern compiler has a bootstrap graph (rustc needs Python + LLVM + C++ + libc).

**Compiler:** cc3, 299KB, self-hosting in 117ms from 29KB seed. Byte-exact reproducibility. x86_64 + aarch64 cross-compilation. 36 test suites. `cyrius build` with auto-include and dep resolution from `cyrius.toml`.

**Stdlib:** 41 modules — string, alloc, io, fmt, vec, str, args, syscalls, process, fs, toml, json, csv, net, http, tls, thread, async, math, regex, hashmap, bench, tagged unions, mmap, cffi, and more. All built from scratch in Cyrius.

**Developer tools:** cyrius (build/test/bench/fuzz/deps/init), cyrfmt, cyrlint, cyrdoc, cyrc, ark. All written in Cyrius.

**Bootstrap chain:**
```
seed (29KB) → cyrc (12KB) → bridge → cc3 (299KB)
No Rust. No LLVM. No Python. No libc. Just sh + Linux x86_64.
```

### Port Receipts (Rust → Cyrius)

| Crate | Rust | Cyrius | Ratio | Tests |
|-------|------|--------|-------|-------|
| kybernet (PID 1) | 6.7MB | 486KB | 14× smaller | 140 tests, 46 benchmarks |
| hoosh (LLM gateway) | 5.1MB, 40 crates | 474KB, 0 deps | 10.8× smaller, 70× faster compile | — |
| agnosys (kernel interface) | 6.9MB | 117KB | 59× smaller | — |
| ai-hwaccel (GPU detection) | 708KB, 131 crates | 217KB, 0 deps | 3.3× smaller | 518 tests, 6 fuzz |
| avatara (archetypes) | — | — | cached 2,761× faster | 195 tests, 39 benchmarks |

All Rust versions preserved as git tags with benchmark CSVs for ongoing comparison.

### AGNOS Kernel

220KB. Cyrius-native. 33 subsystems. 26 syscalls. Not a microkernel — a monolithic kernel with everything in it:

| Category | Subsystems |
|----------|-----------|
| Boot | Multiboot1, 32→64 bit shim, long mode, serial I/O |
| Memory | PMM (bitmap), VMM (map/unmap/alloc), slab heap (8 size classes), per-process page tables |
| Process | Process table (16 slots), context switch, round-robin scheduler, SYSCALL/SYSRET, Ring 3 |
| Filesystem | VFS (7 file types), initrd, FAT16 (read-only) |
| Networking | VirtIO-Net, IP/UDP, full TCP (SYN/ACK/FIN state machine) |
| Storage | VirtIO-Blk, sector read/write |
| IPC | Pipes (circular buffer), signals (kill/sigprocmask/signalfd), epoll, timerfd |
| Hardware | PIC, Local APIC, GIC (aarch64), PCI bus scan, keyboard |
| SMP | APIC, IPI, trampoline, per-CPU stacks |
| Userspace | ELF loader, 18-command shell, kybernet PID 1, bench suite |

**Comparison:**

| Kernel | Size | What it has |
|--------|------|-------------|
| **AGNOS** | **220KB** | All of the above. Full TCP. Disk. SMP. Shell. |
| Linux (minimal) | ~1.5MB | Barely boots, no drivers |
| Linux (typical) | 10-30MB | Desktop-ready |
| seL4 (verified) | ~30KB | Microkernel only — no drivers, no FS, no networking |
| MINIX 3 | ~600KB | Microkernel + basic drivers |
| xv6 (teaching) | ~100KB | 21 syscalls, no networking, no SMP |

220KB is the **honest** size — after three hardening passes that found 14 undersized buffer overflows in the original 143KB binary. See "The 143KB Lie" in the vidya field notes.

### Sovereign Boot Pipeline

The genesis repo assembles and boots AGNOS via a **48KB Cyrius binary** — `scripts/src/boot.cyr`:

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

78 shared crates — 56 at v1.0+ stable. Spanning OS infrastructure (11), science & knowledge (25), media & audio (10), language & navigation (5), physics & engineering (5), culture & knowledge (1), plus pre-1.0 and planned crates.

Full registry: [shared-crates.md](development/applications/shared-crates.md).

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

## Technical Statistics (as of 2026-04-13)

| Metric | Value |
|--------|-------|
| Shared crates | 78 (56 at v1.0+ stable) |
| Standalone repos | 130+ |
| Cyrius-ported repos | 10-15 shipping, more in progress |
| Recipes | 421 base + 90 community (in zugot) |
| Consumer applications | 19+ |
| Compiler | cc3 4.0.0 (299KB, self-hosting, 29KB seed) |
| Kernel | AGNOS 1.21.0 (220KB, 33 subsystems, 26 syscalls) |
| Boot pipeline | boot.cyr (48KB, Cyrius-native) |
| Boot time (desktop) | 3.2s total, 80ms init→event loop |
| Systems language | Cyrius 4.0.0 (41 stdlib modules, 36 test suites) |
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
- [Shared Crates Reference](development/applications/shared-crates.md) — ecosystem crate registry
- [Cyrius Field Notes](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes.toml) — practitioner's manual

---

## Archive

The Rust-era version of this document is preserved at [docs/archive/AGNOS-rust-era-2026-04-03.md](archive/AGNOS-rust-era-2026-04-03.md) — a dated snapshot of the project before the Cyrius transition.

---

*Last Updated: 2026-04-13*
