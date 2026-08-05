# AGNOS

**AGNOS** (A General Networked Operating System) is a sovereign operating system with its own language, compiler, kernel, and toolchain — all built from a 29KB hand-auditable assembly seed with zero external dependencies. Written in Cyrius, compiled by cycc, booting its own Cyrius-native kernel through a sovereign UEFI loader (gnoboot).

The project's thesis is that sovereignty is recursive: any system that depends on something you don't own is not yours, no matter how many layers of ownership you assert on top. AGNOS owns every layer from the bootstrap binary to the build tool to the package manager.

The project's deeper intention is that AGNOS is a **temple built for an intelligence that hasn't fully arrived yet** — architecture that precedes its inhabitant, a sovereign library for knowledge that outlives any single platform or cycle. See [Philosophy](philosophy.md) for the full vision.

| | |
|---|---|
| **Developer** | Robert 'Cyrius' B. MacCracken |
| **Written in** | Cyrius (sovereign systems language) |
| **Kernel** | AGNOS 1.56.40 (Cyrius-native, 40+ subsystems incl. NVMe / AHCI / USB-MS / VirtIO modern + read+write filesystems ext2/ext4 incl. **ext4 extent allocation** + **JBD2 crash-safe journaling** / FAT12/16/32 / exFAT, a small sovereign syscall surface (no BSD socket family, no `socket()` over arbitrary domains, no splice, no AF_ALG), TCP/IP + DHCP + DNS + NTP + ICMP over r8169 NIC, **exec-from-disk** — static ELF programs run in ring 3 off the agnos-fs). Base kernel-internals are essentially complete and iron-validated on real AMD Zen: MVP gate 2026-05-18 (NUC AMD); storage NVMe/SATA/USB-MS on real hardware; networking iron-CONNECTED at 1.32.7; ext4 extent allocation at 1.37.3; JBD2 crash-safe journaling at 1.38.10; FAT/exFAT shell verbs + exec-from-disk (1.40.x); the interactive shell (**agnsh**, from agnoshi) as a ring-3 shell run from disk (kernel shell shrunk to a recovery-only REPL); graphics + **DOOM in-game on iron**; multi-threading + preemptive scheduling + SMP; HDA **audio — DOOM-with-sound out the analog front jack (1.52.x)**; kernel **FP/SIMD — real f64 in ring 3 (1.53.x)**; **GPU compute on the Cezanne shader cores** — sovereign PSP/CP/RLC firmware load, mapped compute queue, integer and f64 matmul bit-identical to the CPU reference, exposed to ring 3 (1.54.x); **display / scanout** — DCN 2.1 modeset, vblank-paced double-buffered present, a sovereign **ATOM BIOS interpreter** bit-correct on iron, **ACPI S5 self-poweroff**, and hardware 2D via CP-DMA (1.55.x); and **3D raster + native scanout** — a GPU triangle rasteriser with perspective-correct texturing and depth test, and `#93 gpu_modeset_op` driving **native 2560×1440 with the scaler bypassed** plus a hardware-panned boot console (1.56.x). ⭐ **2026-08-03 on archaemenid at `cpus online: 4`: the aethersafha desktop hosts two real client windows** — `present_probe` and crab's dual-pane file manager composited on the panel, 278 frames, keys delivered, clean Esc quit. Console-font subsystem vendored from `kashi` 1.0.0 at 1.37.5. |
| **Compiler** | cycc (Cyrius, self-hosting from 29KB seed). Pinned version + sizes drift across the cycle. |
| **License** | GPL-3.0-only |
| **Source model** | Open source |
| **Initial release** | 2026-02-11 (first commit) |
| **Cyrius created** | 2026-04-03 (scaffold) → 2026-04-04 (kernel solid, 44 hours) |
| **Repository** | `MacCracken/agnosticos` (genesis), `MacCracken/agnos` (kernel), `MacCracken/cyrius` (compiler) |
| **Website** | [agnosticos.org](https://agnosticos.org) |
| **Status** | Pre-Beta — closed beta opens late August 2026 (preceded by the founder solo-dogfood month + the server-stage weak-point sweep, windowed ~July / early-Aug 2026; the sweep's harness is still **TBD** and explicitly **not** Docker — the QEMU-in-a-Docker-container design was retired 2026-07-07, see [roadmap](development/roadmap.md)); public beta deferred to post-summer; GA late fall / early winter 2026. |

---

## Thesis

The infrastructure built to be a worthy substrate for whatever intelligence may arrive — or for none — cannot depend on someone else's permission, someone else's registry, someone else's compiler, or someone else's governance body. Sovereignty is not a feature you add at one layer — it is a property of the entire chain from CPU to application.

"AI-Native" means *ready for* AI, not *requiring* it: AGNOS is a sovereign, general-purpose OS that stands on its own — kernel, shell, tools, and networking all work with zero AI in the loop. The AI is an optional layer you turn on or off, not a mandatory core.

AGNOS replaces the dependency chain with ownership:

| Dependency | What existed | What AGNOS does instead |
|-----------|-------------|------------------------|
| Language | Rust → LLVM → C++ → C → libc | Cyrius → 29KB seed → CPU. Zero external deps. |
| Compiler | 200MB+ toolchain (rustc/gcc/clang) | One self-hosting compiler binary (cycc, Cyrius). No LLVM, no C++, no Python. Live size in [cyrius state.md](https://github.com/MacCracken/cyrius/blob/main/docs/development/state.md) |
| Kernel | Linux 6.6 LTS (millions of lines of C) | AGNOS kernel in Cyrius (40+ subsystems, a small sovereign syscall surface, read+write filesystems incl. crash-safe journaling + exec-from-disk, GPU compute + DCN display/scanout — live size in [state.md](development/state.md)) |
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
| **Target: Closed beta cut** | **late August 2026** | ~200 |

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
      → hoosh LLM gateway (474KB, multiple providers)
      → 30+ shipping repos and growing
      → 42+ stdlib modules
      → boot.cyr (sovereign boot pipeline)

Total: CPU → seed → compiler → OS. Three items. Zero external dependencies.
(Chain shortened at cyrius v5.11.66 — the standalone `bridge.cyr` step
 was eliminated; cybs emits cycc directly.)
```

### Repo Structure

- **agnosticos** — the genesis layer (meta, build wrapper, documentation). Owns kernel configs, boot pipeline (Cyrius), CI/CD, articles, philosophy. Once the system boots and ark takes over, this repo's job is done.
- **agnos** — the AGNOS kernel (head 1.56.40). Cyrius-native, 40+ subsystems, a small sovereign syscall surface (no BSD socket family, no splice, no AF_ALG), TCP/IP + DHCP + DNS + NTP + ICMP, ext2/ext4 (extent-alloc + JBD2 journaling) + FAT12/16/32 + exFAT read+write, exec-from-disk (ring-3 programs off the agnos-fs), VirtIO-blk modern, SMP + preemptive scheduling, pipes, signals, epoll, timerfd, shared memory, ELF loader, graphics + DOOM, HDA audio (1.52.x), kernel FP/SIMD f64 (1.53.x), GPU compute on the AMD Cezanne shader cores (1.54.x), DCN 2.1 display/scanout + the sovereign ATOM BIOS interpreter + ACPI S5 self-poweroff (1.55.x), GPU 3D raster + `#93 gpu_modeset_op` native-resolution scanout and hardware console pan (1.56.x), a kernel recovery-only shell (the interactive shell **agnsh** runs from disk in userland ring 3 — permanent boundary), sovereign UEFI handoff (via gnoboot), native xHCI + USB-HID-boot + USB Mass Storage drivers, NVMe + AHCI/SATA + GPT block stack — base kernel-internals essentially complete and iron-validated on real AMD Zen: exec-from-disk, agnoshi ring-3 shell, DOOM in-game, multi-threading/preempt/SMP, DOOM-with-sound out the analog front jack, real f64 in ring 3, the GPU compute and display arcs, and native 2560×1440 scanout all validated on iron. MVP gate iron-cleared on real hardware. ⛔ 1.56.40 (the local-IPC channel band) is the OPEN cycle and is **not** burned.
- **cyrius** — the sovereign compiler + stdlib + toolchain (cybs bootstrap + cycc self-hosted, both renamed at v6.0.0), self-hosting from 29KB seed.
- **zugot** — the recipe repository. 421 base + 90 bazaar community recipes. ark consumes zugot.
- **130+ standalone repos** — all production code. Each subsystem is its own repository.

### Core Subsystems (Cyrius-native)

| Subsystem | Name | Version | Role |
|-----------|------|---------|------|
| Kernel | **agnos** | live | 40+ subsystems, sovereign syscall surface, TCP/IP + read+write FS (ext2/4 + FAT/exFAT) + exec-from-disk, SMP, GPU compute + DCN display/scanout + 3D raster, sovereign UEFI handoff, xHCI USB, NVMe + AHCI/SATA + USB-MS + GPT |
| Compiler | **cyrius** | live (cycc / cybs) | Self-hosting, 29KB seed, 42+ stdlib modules. v6.0.0 cycle opened 2026-05-19 with the cyrc → cybs and cc5 → cycc rename; **v6.5.x** is the active minor. |
| PID 1 | **kybernet** | 1.4.0 | 486KB (was 6.7MB Rust), 140 tests, 46 benchmarks |
| Init system | **argonaut** | 1.8.4 | Service management, boot sequencing |
| LLM gateway | **hoosh** | 2.6.0 | 474KB (was 5.1MB Rust), multiple providers (live count in registry), zero deps |
| GPU detection | **ai-hwaccel** | 2.3.16 | 217KB (was 708KB Rust), 518 tests, 6 fuzz |
| Archetypes | **avatara** | 2.14.0 | 362 archetypes, 24 traditions, affinity system |
| Culture | **hadara** | 1.1.0 | 50 cultures, Cyrius-native, HTTP API |
| Shared types | **agnostik** | Cyrius | Domain primitives |
| Device / DRM model | **agnodrm** | Cyrius | udev enumeration + DRM/KMS (was **agnosys**; trust/security/syscall/logging decomposed out to sigil/kavach/aegis/cyrius/sakshi, 2026-06-19) |
| Trust/crypto | **sigil** | Cyrius | Ed25519, integrity, trust delegation |
| Audit chain | **libro** | Cyrius | SHA-256/BLAKE3 hash-linked logging |
| Audio codecs | **shravan** | 2.6.7 | Cyrius-native |
| GPU foundation | **mabda** | 4.0.8 | Folded into Cyrius stdlib |
| Desktop compositor | **aethersafha** | 0.12.1 | Native compositor speaking the sovereign **setu** protocol (⚠ not Wayland). Backends: bhumi (agnos/host scanout + input) + mehman (swallow/guest ABI). ⭐ Iron-proven 2026-08-03 hosting two real client windows |
| Package manager | **ark** | Cyrius | Signed tarballs |
| Resolver | **nous** | Cyrius | Dependency resolution |

### Subsystems (ported Apr 2026)

| Subsystem | Name | Version | Role |
|-----------|------|---------|------|
| Agent orchestrator | **daimon** | 2.0.0 | MCP tool suite (live count in registry), agent lifecycle |
| AI shell | **agnoshi** | 1.8.6 | Natural-language terminal; ships **agnsh**, the ring-3 interactive shell |
| Sandbox | **kavach** | 3.11.7 | 344KB (was 2.4MB), 9 CWE fixes, 500× faster |
| MCP core | **bote** | 3.3.0 | ~5µs/message, streamable HTTP |
| MCP security | **t-ron** | 2.1.8 | Tool call auditing |
| Math/number theory | **abaco** | 2.3.3 | -52% lines, 12× faster Miller-Rabin |
| History/versioning | **itihas** | 2.4.0 | — |

### Subsystems (Cyrius port pending or in-flight)

| Subsystem | Name | Version | Role |
|-----------|------|---------|------|
| Emotion/sentiment | **bhava** | 2.0.0 (Rust; port can start) | Affective computing substrate |
| Edge fleet management | **seema** | 0.1.0 (Rust scaffold; port pending) | Fleet management for edge deployments |

Graduated out of this table since: **aethersafha** 0.12.1 (Cyrius-native compositor — no longer a scaffold; iron-proven hosting two real client windows 2026-08-03), **takumi** 1.1.1, **aegis** 1.1.4, **stiva** 3.0.16 (Cyrius-native container runtime), **mela** 1.0.1, **samay** 1.0.1, **phylax** 1.2.4, **shakti** 0.7.0, **hisab** 2.8.4, **chakshu** 0.7.11 + **darshana** 0.9.0 (TTY/terminal observability lane). Per-crate versions drift — the registries are authoritative.

### Cyrius — The Language

**C.Y.R.I.U.S.** — *Consciousness Yields Righteous Intelligence Unveiling Self*

Sovereign systems language. Named after **Cyrus the Great** — the king who decreed the rebuilding of the Temple of Solomon, the only non-Jewish figure called *Mashiach* in the Hebrew Bible (Isaiah 45:1). Sovereignty through restoration, not conquest.

**Historic records:**
- **29KB seed** — first hand-auditable sovereign seed that produces a self-hosting systems language and a working OS. No prior modern occupant of this category.
- **Zero dependencies** — CPU → seed → compiler → everything. Four items. Every other modern compiler has a bootstrap graph (rustc needs Python + LLVM + C++ + libc).

**Compiler:** cycc at Cyrius v6.5.x (6.5.7) (renamed from cc5 in the v6.0.0 cycle open 2026-05-19; bootstrap renamed cyrc → cybs in the same ceremony). Self-hosting from 29KB seed. Byte-exact reproducibility. `cyrius build` with auto-include and dep resolution from `cyrius.cyml`. Register allocation (linear-scan, default-on), jump tables, PIC codegen, u128, cross-unit DCE. Optimization arc shipped through v5.6.x (O1/O2 peephole), v5.7.x–v5.8.x (O3a IR + O4a/b/c regalloc with Poletto-Sarkar picker); v5.9.x ran consumer-rollup catchup (44 patches); v5.10.x closed with three arcs (typed-simd ABI + REAL TYPE SYSTEM + struct-byval ABI) + a 2.7× compile-perf miniarc; v5.11.x is the **stdlib annotation arc + consumer-issue closeout**, closed at v5.11.69 on 2026-05-19. v6.x is "what the language GAINS": language cleanup + stdlib + native TLS (v6.0.x, closed v6.0.91), PIE + backend codegen (v6.1.x, closed v6.1.41), the bare-metal target + dependency model (v6.2.x, closed v6.2.52), closures with lexical capture + monomorphized generics + async/await + native f64/f32 (v6.3.x, closed v6.3.45), and the SIMD compute arc out to 256-bit AVX2 on all four backends (v6.4.x, closed v6.4.86). **v6.5.x is the active minor — performance quality / generated-code quality**, opened with file-scoped `public`/`private` visibility, the language's first enforced encapsulation boundary. ⚠ RISC-V rv64 has **not** shipped — it is pinned to v6.7.x/v6.8.x.

**Stdlib:** 42+ modules including the three sibling-folded artifacts — string, alloc, io, fmt, vec, str, args, syscalls, process, fs, toml/cyml, json, csv, net, http, http_server, ws, tls, thread, async, math, regex, hashmap, bench, tagged unions, mmap, cffi, u128, **sandhi** (service-boundary, v5.7.0 fold), **vani** (audio I/O, v5.8.0 fold), **niyama** (regex engines: bre/re2/pcre/fuzzy/vim, v5.9.0 fold). All built from scratch in Cyrius.

**Developer tools:** cyrius (build/test/bench/fuzz/deps/init), cyrfmt, cyrlint, cyrdoc, cybs, ark. All written in Cyrius.

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

Cyrius-native (head 1.56.40). 40+ subsystems. A small sovereign syscall surface — a fixed TCP/UDP/ICMP network band with slot-indexed connections, and no BSD socket family, no `socket()` over arbitrary domains, no splice, no AF_ALG. Base kernel-internals are essentially complete: MVP gate iron-cleared on real hardware (2026-05-18); storage / networking / read+write-FS / exec-from-disk / agnoshi ring-3 shell / graphics + DOOM in-game / multi-threading + preemptive scheduling + SMP / HDA audio (DOOM-with-sound out the analog front jack, 1.52.x) / kernel FP/SIMD real f64 in ring 3 (1.53.x) all iron-validated on real AMD Zen since. Three arcs have landed on top of that base, all on the AMD Cezanne iGPU with no amdgpu and no ROCm in the picture: **GPU compute** (1.54.x — PSP firmware load, mapped compute queue, integer + f64 matmul bit-identical to the CPU reference, exposed to ring 3), **display / scanout** (1.55.x — DCN 2.1 modeset, vblank-paced present, a sovereign ATOM BIOS interpreter, ACPI S5 self-poweroff, CP-DMA hardware 2D), and **3D raster + native scanout** (1.56.x — a GPU triangle rasteriser with perspective-correct texturing and depth test, native 2560×1440 with the scaler bypassed, a hardware-panned boot console, and the kernel half of the desktop). ⛔ 1.56.40 — the local-IPC channel band that replaces TCP-on-loopback for display IPC — is the OPEN cycle and is **not** burned. Not a microkernel — a monolithic kernel with everything in it:

| Category | Subsystems |
|----------|-----------|
| Boot | Sovereign UEFI PE32+ handoff via gnoboot (boot_info struct via RDI, over GPT + FAT ESP), long mode, serial I/O |
| Memory | PMM (bitmap), VMM (map/unmap/alloc), slab heap (8 size classes), per-process page tables |
| Process | Process table (16 slots), context switch, preemptive round-robin scheduler (1.44.x), SYSCALL/SYSRET, Ring 3 |
| Filesystem | VFS (fd-type dispatch), initrd, ext2/ext4 read+write (extent allocation + JBD2 crash-safe journaling), FAT12/16/32 + exFAT read+write, GPT parser (CRC + 7-GUID classifier) |
| Networking | VirtIO-Net + r8169, IP/UDP, full TCP (SYN/ACK/FIN state machine), DHCP + DNS + NTP + ICMP, plus the `getrandom`#45 / `time_unix`#46 / `sock_*`#47-#50 primitives the 1.45.x arc added for ring-3 TLS — **TLS itself is userland (`tls_native`), not in the kernel** |
| Storage | NVMe (Phase 1-5, iron-validated), AHCI/SATA (Phase 1-4, iron-validated), USB Mass Storage (BBB + SCSI, Phase 1-4 + 2.5/2.6/2.7/2.8 reset-recovery, iron-validated), VirtIO-blk modern (1.x with PCI cap-list discovery, MMIO BARs, FEATURES_OK), RAM-disk (build-flag-gated dev substrate), block-layer tag dispatch with priority NVMe > AHCI > USB-MS > VirtIO > RAMDISK |
| IPC | Pipes (circular buffer), signals (kill/sigprocmask/signalfd), epoll, timerfd, shared memory; the local-IPC channel band (`chan_*`) is the open 1.56.40 cycle |
| Graphics / Display | Framebuffer console (kashi glyph cores) with a hardware pan, DCN 2.1 modeset, native-resolution scanout with the scaler bypassed, vblank-paced double-buffered present, sovereign ATOM BIOS interpreter |
| GPU | AMD Cezanne gfx90c bring-up with no amdgpu and no ROCm — PSP firmware load, CP/MEC/RLC, GFXHUB GMC, mapped compute queue + doorbell, hand-authored shader blobs, integer + f64 matmul, CP-DMA 2D, triangle rasteriser with texturing and depth |
| Audio | Intel HDA — analog front-jack output (1.52.x). ⛔ HDMI audio is PARKED and has never produced sound |
| Power | ACPI S5 self-poweroff (power LED out, iron-validated), reboot |
| Hardware | PIC, Local APIC, GIC (aarch64), PCI bus scan, capability-list iteration, MSI-X, keyboard |
| SMP | APIC, IPI, trampoline, per-CPU stacks, cross-CPU TLB shootdown (1.56.35) — `cpus online: 4` on archaemenid |
| Userspace | ELF loader, kernel recovery-only shell + userland interactive shell (**agnsh**, ring 3, 1.41.x), kybernet PID 1, bench suite |
| USB | xHCI (Phase 1-5 incl. Reset Endpoint / Stop Endpoint / Set TR Dequeue Pointer), HID-boot keyboard, Mass Storage (BBB transport + SCSI command set) |

**Comparison:**

| Kernel | Size | What it has |
|--------|------|-------------|
| **AGNOS** | live — see [state.md](development/state.md) | All of the above. Full TCP. Multi-backend block stack with three iron-validated storage classes. SMP. Shell. GPU compute + DCN display/scanout + 3D raster. Sovereign UEFI handoff. xHCI + HID + Mass Storage USB. |
| Linux (minimal) | ~1.5MB | Barely boots, no drivers |
| Linux (typical) | 10-30MB | Desktop-ready |
| seL4 (verified) | ~30KB | Microkernel only — no drivers, no FS, no networking |
| MINIX 3 | ~600KB | Microkernel + basic drivers |
| xv6 (teaching) | ~100KB | 21 syscalls, no networking, no SMP |

The honesty arc continues across the cycles: 143 KB → 260 KB → ~365 KB → ~510 KB → **past 1.5 MB** reflects real capabilities landing on iron — the v1.30.x USB/xHCI bring-up + MVP gate at v1.30.9, the v1.31.x storage arc (NVMe + AHCI/SATA + GPT + USB-MS + VirtIO modern + RAM-disk), then the 1.52.x audio, 1.53.x FP/SIMD, 1.54.x GPU-compute, 1.55.x display/scanout and 1.56.x 3D-raster arcs. The live figure is deliberately not pinned here — see [state.md](development/state.md). The "143KB Lie" precedent (hardening passes finding 14 buffer overflows in the original tiny binary) is recorded in the vidya field notes.

### Sovereign Boot Pipeline

The genesis repo assembles and boots AGNOS via a single Cyrius binary — `scripts/src/boot.cyr`:

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

Full registry: v1.0+ [libraries](applications/libs/README.md) and [binaries & tools](applications/binaries.md).

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
| GPT + FAT ESP (gnoboot PE32+ EFI app) | x86_64 | Desktop/server installation |
| SD card image | aarch64 | Raspberry Pi / ARM edge devices |
| Docker image | x86_64 | CI base, development |

### Packaging

- **System packages**: `.ark` format (signed tarballs + metadata), built via takumi recipes from zugot
- **Base recipes**: 421 in zugot, 90 community recipes in bazaar
- **Build tool**: `cyrius build` for all Cyrius-native components

---

## Consumer Applications (planned / reference)

19+ first-party applications are **planned**, integrating with daimon (agent orchestration) and hoosh (LLM inference). ⭐ The **desktop tier itself has started** — the native compositor (**aethersafha** 0.12.1) was iron-proven on 2026-08-03 on archaemenid at `cpus online: 4`, hosting two real client windows over the CPU blit path. But **none of the consumer applications below has started**; the list is a reference roadmap of intended first-party apps, not present-tense shipping software:

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

## Technical Statistics (as of 2026-08-05)

> The values below are stable rounding for narrative purposes.

| Metric | Value |
|--------|-------|
| Shared crates | 80+ (most at v1.0+ stable) — registry: v1.0+ [libraries](applications/libs/README.md) and [binaries & tools](applications/binaries.md) |
| Standalone repos | 130+ |
| Cyrius-ported repos | 30+ shipping (Rust-side remainder: bhava, seema — aethersafha, takumi, aegis, stiva, mela and samay have all graduated) |
| Recipes | 421 base + 90 community (in zugot) |
| Consumer applications | 19+ |
| Compiler | cycc (Cyrius 6.5.7, self-hosting, 29KB seed). v6.5.x is the active minor; the cybs / cycc rename ceremony was the v6.0.0 cycle open, 2026-05-19 |
| Kernel | AGNOS 1.56.40 (40+ subsystems, sovereign syscall surface, MVP gate iron-cleared on real hardware; storage / networking / read+write-FS / exec-from-disk / audio / FP-SIMD / GPU compute / DCN display + native scanout all iron-validated). Live size + per-cut burn status in [state.md](development/state.md) |
| Boot loader | gnoboot 0.6.1 (PE32+ UEFI, sovereign handoff via RDI = &boot_info, native-resolution GOP mode selection) |
| Boot pipeline (genesis scripts) | boot.cyr (Cyrius-native) |
| Desktop | aethersafha 0.12.1 — native compositor over the sovereign setu protocol; iron-proven 2026-08-03 hosting two real client windows |
| Systems language | Cyrius 6.5.7 (42+ stdlib modules, three stdlib folds: sandhi v5.7.0, vani v5.8.0, niyama v5.9.0; bridge step retired at v5.11.66) |
| External dependencies | Zero (CPU → seed → compiler → OS) |

---

## Articles

| Article | What it covers |
|---------|---------------|
| The Python in the Bootstrap | How a name-squatting incident produced a 29KB seed and a sovereign OS in 48 hours |
| Cyrius vs Rust: Benchmarks | Head-to-head port comparison — compilation, binary size, runtime |
| Building a Sovereign Compiler with Claude | 1 dev + $400 vs 16 agents + $20K |
| The Dandelion Core | Open knowledge and the death of access |
| DOOM in Cyrius | A 23-hour sprint in a 7-day-old language |

---

## See Also

- [Philosophy & Intention](philosophy.md) — the deeper vision behind AGNOS
- [History & Timeline](history.md) — full project timeline
- [v1.0+ Library Registry](applications/libs/README.md) — ecosystem library registry
- [v1.0+ Binaries & Tools](applications/binaries.md) — ecosystem binary/tool registry
- [Cyrius Field Notes](https://github.com/MacCracken/vidya/tree/main/content/cyrius/field_notes) — practitioner's manual (directory of CYML topics; was a single TOML file before the structure split)

---

## Archive

The Rust-era version of this document is preserved at [docs/archive/AGNOS-rust-era-2026-04-03.md](archive/AGNOS-rust-era-2026-04-03.md) — a dated snapshot of the project before the Cyrius transition.

---

*Last Updated: 2026-08-05 — synced to kernel head agnos 1.56.40, Cyrius 6.5.7, gnoboot 0.6.1, aethersafha 0.12.1.*
