# AGNOS System Architecture

> **Last Updated**: 2026-05-21
>
> Live ecosystem state (cycle, per-repo pins, sweeps): [`development/state.md`](development/state.md). Live kernel/cyrius versions + binary sizes: [`development/state.md`](development/state.md). Per-subsystem versions intentionally elided in this doc per the lib-doc precedent — refer to the registry files when quoting numbers.

This document provides the technical architecture of AGNOS (AI-Native General Operating System).

## Table of Contents

1. [System Overview](#system-overview)
2. [Kernel](#kernel)
3. [Kernel Layers](#kernel-layers)
4. [Named Subsystems](#named-subsystems)
5. [Security Architecture](#security-architecture)
6. [Data Flow](#data-flow)
7. [Technology Stack](#technology-stack)
8. [Design Decisions](#design-decisions)

## System Overview

AGNOS is a sovereign operating system written in Cyrius. The architecture consists of three layers:

```
+======================================================================+
|                        AGNOS Architecture                             |
+======================================================================+
|                                                                       |
|  Named Subsystems (standalone repos, Cyrius-native):                  |
|  +-------+ +-------+ +-------+ +-------+ +-------+ +-------+        |
|  |  ark  | | nous  | |takumi | | mela  | | aegis | | sigil |        |
|  |  pkg  | |resolve| | build | |market | |secure | | trust |        |
|  |  mgr  | |daemon | |system | | place | |daemon | |system |        |
|  +-------+ +-------+ +-------+ +-------+ +-------+ +-------+        |
|  +----------+ +---------+ +-------+ +-------+                        |
|  | argonaut | | agnova  | | kavach| | bote  |                        |
|  |   init   | |installer| |sandbox| |  MCP  |                        |
|  |  system  | |         | |       | |       |                        |
|  +----------+ +---------+ +-------+ +-------+                        |
|       |              |              |              |                   |
+-------+--------------+--------------+--------------+------------------+
|                                                                       |
|  +---------------------------------------------------------------+   |
|  |                     User Space Layer                           |   |
|  |  +-------------+ +-------------+ +------------------------+   |   |
|  |  | aethersafha | |  agnoshi   | |  Agent Applications    |   |   |
|  |  |  (desktop)  | |   (shell)   | | (daimon orchestrated)  |   |   |
|  |  +------+------+ +------+------+ +-----------+------------+   |   |
|  |         +----------------+------------------------+           |   |
|  |                          |                                    |   |
|  |  +-------------+  +-----+------+  +-----------+              |   |
|  |  |    hoosh    |  |   daimon   |  |  agnosys  |              |   |
|  |  | LLM gateway |  |   agent    |  |  kernel   |              |   |
|  |  |             |  |  runtime   |  | interface |              |   |
|  |  +-------------+  +-----+------+  +-----+-----+              |   |
|  +---------------------------------------------------------------+   |
|                             |                                         |
+-----------------------------+-----------------------------------------+
|                             |                                         |
|  +---------------------------------------------------------------+   |
|  |              AGNOS Kernel (Cyrius-native)                     |   |
|  |  +---------------------------------------------------+       |   |
|  |  |         35+ subsystems · live size in state.md      |       |   |
|  |  |  +-----------+ +-----------+ +----------------+    |       |   |
|  |  |  |  Memory   | | Process  | |   Network      |    |       |   |
|  |  |  |  Manager  | | Manager  | |   (TCP/IP)     |    |       |   |
|  |  |  +-----------+ +-----------+ +----------------+    |       |   |
|  |  |  +-----------+ +-----------+ +----------------+    |       |   |
|  |  |  |    VFS    | |   SMP    | |   VirtIO       |    |       |   |
|  |  |  | (FAT16)   | |          | | (Net + Blk)    |    |       |   |
|  |  |  +-----------+ +-----------+ +----------------+    |       |   |
|  |  |  +-----------+ +-----------+ +----------------+    |       |   |
|  |  |  |  Signals  | |  Pipes   | |  ELF Loader    |    |       |   |
|  |  |  |  + epoll  | | + IPC    | |  + 18-cmd sh   |    |       |   |
|  |  |  +-----------+ +-----------+ +----------------+    |       |   |
|  |  +---------------------------------------------------+       |   |
|  |                          |                                    |   |
|  |  +------------------------------------------------------+    |   |
|  |  |           Hardware Abstraction Layer                   |    |   |
|  |  |      (CPU, GPU, NPU, Memory, Storage, I/O)            |    |   |
|  |  +------------------------------------------------------+    |   |
|  +---------------------------------------------------------------+   |
|                                                                       |
+======================================================================+
```

## Kernel

AGNOS runs its own sovereign kernel, written in Cyrius. No Linux dependency at runtime.

**AGNOS kernel** — 35+ subsystems, 26 syscalls. Iron-validated end-to-end on NUC AMD archaemenid: kernel-init layer cleared 2026-05-15 (Attempt 28, agnos 1.30.0); closed-beta MVP gate (typeable shell via xHCI HID keyboard) hit 2026-05-18 (Attempt 68, agnos 1.30.9). Full arc captured in [`development/iron-nuc-zen-log-mvp.md`](development/iron-nuc-zen-log-mvp.md); post-MVP work continues in [`development/iron-nuc-zen-log.md`](development/iron-nuc-zen-log.md). Live kernel size, version, build trajectory: [`development/state.md`](development/state.md):
- Memory management, process management, SMP
- TCP/IP networking, VirtIO-Net/Blk
- FAT16 filesystem, ELF loader
- Pipes, signals, epoll, timerfd
- 18-command built-in shell
- kybernet as PID 1
- Sovereign UEFI handoff (Path C, RDI = `&boot_info` via gnoboot v0.2.0)
- Native XHCI + USB-HID-boot keyboard driver (all 5 phases landed; iron-side blocker remains on archaemenid silent-absorb arc)

The `kernel/` directory in this repo contains Linux kernel configs for **host bootstrap only** — building the cross-compiler toolchain on an existing Linux host before AGNOS can self-host.

## Kernel Layers

> Conceptual decomposition. Layers 1–5 shipped. Live per-subsystem status: [agnos repo](https://github.com/MacCracken/agnos). Live size: [`development/state.md`](development/state.md).

The kernel was originally planned as five layers — *boots*, *runs programs*, *storage*, *talks to the world*, *usable*. All five landed inside a ~7-week window (Cyrius scaffold 2026-04-03 → kernel v1.22.0 on 2026-04-14, hardened to v1.26.1 by 2026-04-28). Subsequent 1.27.x → 1.30.x work has been bring-up and hardening: KASLR data-only shipped at 1.28.0 (closed the security-track gate 13/13), sovereign-struct kernel ABI shipped 1.30.0 (Path-C UEFI handoff via gnoboot v0.2.0), native XHCI + USB-HID-boot driver across 1.30.1 → 1.30.5, xHCI cmd-path repair arc 1.30.6 (Repairs FF through QQ, MSI-X table programming closeout). The decomposition below reflects where each layer sits today; live per-version detail in [`development/state.md`](development/state.md).

### Layer 1 — Can Boot and Respond

**x86_64**: multiboot1 32-bit ELF entry, 32→64 long-mode shim, GDT (5 segments + TSS), IDT (256 vectors), PIC remap to INT 32+, Local APIC at `0xFEE00000` (timer, IPI), periodic ~100Hz timer, PS/2 keyboard (full US QWERTY), COM1 serial I/O at `0x3F8`.

**aarch64**: DTB boot, EL2→EL1 transition, GICv2 interrupt controller, ARM generic timer, PL011 UART.

**Memory**: page tables (2MB huge, 16MB identity map, per-process), PMM (bitmap, 4096 pages, next-free hint), VMM (map/unmap/alloc, user-accessible), slab heap (8 size classes, 32B–4096B).

### Layer 2 — Can Run Programs

- **ELF loader** — static ELF64, per-process address space, Cyrius-emitted binaries load directly
- **Process table** — 16 slots, 168B context, CR3 per-process
- **Context switch** — full register save/restore (all 9 caller-saved regs) + CR3 switch
- **Scheduler** — round-robin on timer tick
- **SYSCALL/SYSRET** — MSR setup, ring 3 ↔ ring 0 transition
- **TSS** — RSP0 for ring 3 stack switching

### Layer 3 — Can Access Storage

The original 5-layer plan listed VirtIO-Blk + FAT16. The 1.31.x cycle (Mar–May 2026) substantially expanded this layer into a full storage stack on real silicon. Five iron debuts on archaemenid (Beelink SER, AMD Renoir) — see Attempts 80 / 81 / 87 / 88 / 90 in [`development/iron-nuc-zen-log.md`](development/iron-nuc-zen-log.md).

**VFS layer:**
- **VFS** — file table, **8 file types**: device, memfile, signalfd, epoll, timerfd, pipe, regular, ext2_file (added 1.31.5 Phase 3)
- **Initrd** — flat format, name lookup; bare-name fallback for shell verbs after CWD-prefixed ext2 lookup miss

**Block-layer dispatch (5-backend, multi-backend probe):**
- **`block.cyr`** — priority-order tag dispatch: NVMe primary > AHCI secondary > USB MS tertiary > VirtIO fallback > RAM-disk
- **`blk_registered` bitmask** + **`blk_read_on(tag, sector, buf)`** — explicit per-backend dispatch independent of `blk_active`; lets the filesystem probe walk all registered backends instead of just the active one (1.31.6 bite G)

**Storage device drivers:**
- **NVMe (Phase 1-5)** — probe + admin queue + I/O queue + R/W + PRP1/2/list dispatch. Iron-validated on Crucial P3 2 TB at Attempt 80 (1.31.0, first-try clean)
- **AHCI/SATA (Phase 1-4)** — HBA probe + per-port CL+FIS bring-up + IDENTIFY DEVICE + READ/WRITE DMA EXT. Iron-validated on WD Blue SA510 2 TB at Attempt 81 (1.31.1); three carry-forward patches (port quiescence gate / ATA-string right-trim / RW_DEMO compile gate) landed in 1.31.2
- **USB Mass Storage (Phase 1-2.8)** — BBB transport + SCSI INQUIRY/TUR/RC10/READ(10)/WRITE(10). Eight-bug repair stack (bulk-timeout extension + strict TRB matching + SHORT_PACKET residue check + unified retry-recover wrapper + drain reposition + 64-bit param_hi). Iron-validated on Silicon Motion 125 GB stick at Attempt 87 (1.31.3)
- **VirtIO-blk modern (1.x)** — full PCI cap-list + MMIO + 64-bit FEATURES_OK + polled used-ring rewrite (1.31.4); replaces the legacy 0.9.5 transitional driver. QEMU-only by design
- **RAM-disk** — `pmm_alloc`-backed, `RAMDISK_ENABLE=1` compile-flag gated (1.31.4)

**Partition + filesystem layer:**
- **GPT (Phase 1-3)** — header + full 16 KB array walk + UTF-16LE partition names + table-less CRC32 + backup-header recovery + 7-GUID type classifier + `parts` shell command. Iron-validated multi-partition layouts at Attempts 81/89/90
- **ext2 / ext4 read-only (Phase 1-5)** — superblock + BGDT + inode (direct + single/double/triple indirect tree) + dirent walk + absolute-path resolution + `VFS_EXT2_FILE` FD type + ext4 extents header/leaf walker (FreeBSD-shape) + 64BIT support (s_desc_size + dynamic BGDT stride + bg_inode_table_hi guard). **Iron-validated** on real Linux ext4 on NVMe at Attempt 90 (1.31.6)
- **Partition-aware mount via GPT consumption** — `ext2_try_partition_mount` iterates Linux-FS-GUID partitions when whole-disk probe misses; mounts the first match
- **fatfs (read-only FAT16)** — root directory listing, file open/read; BPB validation sweep at 1.31.6 (num_fats / sectors_per_cluster / root_entry sanity)

**Multi-source convergent prior-art audits**: every non-trivial subsystem in this layer gets a written audit before its iron burn — see [`development/ext2-ext4-extents-prior-art.md`](development/ext2-ext4-extents-prior-art.md), [`development/ext4-64bit-prior-art.md`](development/ext4-64bit-prior-art.md), [`development/msc-reset-recovery-prior-art.md`](development/msc-reset-recovery-prior-art.md), [`development/ext2-iron-burn-audit.md`](development/ext2-iron-burn-audit.md). Linux is one source of many — FreeBSD / OpenBSD / NetBSD / Haiku / EDK2 / SeaBIOS / U-Boot / Plan 9 + vendor errata triangulated per [`feedback_redesign_dont_reinvent`](../../../.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_redesign_dont_reinvent.md).

**Not yet shipped at this layer**: FAT32 (no consumer pressure), per-backend GPT parsing (only `blk_active` parses today; deferred to next storage-cycle reopening), HTREE indexed directories, fast/slow symlink resolution, ext2/ext4 write paths (write cycle pinned to 1.33.x). Framebuffer/MMIO graphics belongs to a separate display layer, not Layer 3.

### Layer 4 — Can Talk to the World

- **VirtIO-Net** — legacy PCI, virtqueues, Ethernet frames
- **ARP + IPv4 + UDP** — full send/recv
- **TCP** — connect/send/recv/close with SYN/ACK/FIN state machine (not just the UDP-only MVP originally planned)
- **Serial console** — input + output via COM1 / PL011

### Layer 5 — Can Be Used

- **Shell** — 22 commands: `help echo ps free cat uptime lspci cpus net send recv tcp pipe blkread parts ls cd pwd disk bench test halt`. `ls` accepts flag tokens (`-la` no-op for now); `cat` falls through to initrd on ext2 miss; `cd` + `pwd` consume `sh_cwd_inode` / `sh_cwd_path` globals for CWD-relative path resolution (1.31.7 bites D/B/C)
- **kybernet PID 1** — service supervision, signal/event-loop, kernel-interface boundary. Per-repo benchmarks + test count in kybernet's own state.md.
- **Signals** — per-process `proc_signals` / `proc_sigmask`, `kill` / `sigprocmask` / `signalfd`
- **Epoll** — `epoll_create`, `epoll_ctl`, `epoll_wait`
- **Timerfd** — `timerfd_create`, `timerfd_settime`
- **Pipes** — circular buffer IPC, read/write ends, VFS type 6

### Size — Projected vs Actual

| Milestone | Original estimate (Apr 7) | Actual |
|-----------|---------------------------|-------|
| Layer 1 alone | 31 KB | 31 KB ✓ |
| + Layer 2 (run programs) | ~38 KB | — |
| + Layer 3 (storage) | ~40 KB | — |
| + Layer 5 (shell) | ~42–45 KB | — |
| + VFS + signals + pipes | ~50 KB | — |
| + VirtIO + basic TCP | ~65 KB | — |
| Full Layer 1–5 + Path-C UEFI ABI + USB-HID + xHCI cmd-path | ~70–80 KB | **see [`development/state.md`](development/state.md) for live size** |

The shipped kernel is several times the original estimate because it carries features outside the original 5-layer shortest-path plan: SMP infrastructure (APIC, IPI, trampoline, per-CPU stacks); cross-architecture (x86_64 + aarch64 in one binary); full TCP instead of UDP-only; slab allocator with 8 size classes; FAT16 driver; Ring 3 with proper TSS; Local APIC timer; v1.30.x's Path-C sovereign UEFI handoff and native XHCI / USB-HID-boot driver added another sizable chunk.

The conceptual 5-layer model still maps. The kernel simply carries more per layer than the MVP "boots into shell" scope intended.

### Syscalls (26)

```
exit(0)         write(1)        getpid(2)       spawn(3)
waitpid(4)      read(5)         close(6)        open(7)
dup(8)          mkdir(9)        rmdir(10)       mount(11)
sync(12)        reboot(13)      pause(14)       getuid(15)
kill(16)        sigprocmask(17) signalfd(18)    epoll_create(19)
epoll_ctl(20)   epoll_wait(21)  timerfd_create(22)  timerfd_settime(23)
umount(24)      pipe(25)
```

### Userland Alignment

| Kernel provides | Userland uses |
|-----------------|---------------|
| ELF loader (Layer 2) | Cyrius compiler emits ELF directly; no translation layer |
| Initrd + VFS (Layer 3) | Userspace tools packed into CPIO initrd at build |
| Signals + epoll + timerfd (Layer 5) | kybernet event loop, service supervision |
| SYSCALL/SYSRET (Layer 2) | agnosys kernel-interface library (Cyrius, zero deps) |
| Pipes (Layer 3/5) | Shell pipelines, inter-service IPC |

### What's not yet in the kernel

| Gap | Why it's deferred |
|-----|-------------------|
| Framebuffer text rendering quality (Quiet-Boot legibility on AMD Zen) | Banding observed on archaemenid Quiet-Boot framebuffer; closeout-pinned at gnoboot 0.4.2 / agnos 1.30.12 after two GOP SetMode levers were falsified. Next-cycle options: HUBP `clear_tiling` port or shadow-buffer architectural eval. Doesn't block MVP (VGA-path legible). |
| Wayland compositor (aethersafha) | Display-layer prereq for the GUI track; scaffold only at 0.1.0. Closed-beta MVP runs without it (agnoshi-as-console via argonaut 1.7.0 BOOT_MINIMAL). |
| Per-backend GPT parsing | `gpt.cyr` currently only parses against `blk_active`; partitions on non-active backends aren't reachable. Deferred to next storage-cycle reopening or to a real consumer surfacing demand. |
| ext2/ext4 write paths | Pinned to **1.33.x** as the WRITE cycle (block/inode allocator, dirent insertion/removal, file create/truncate/unlink, mkdir/rmdir). Substantial own-cycle (~1,500+ LOC); multi-source audit doc first. Read-only is sufficient for current iron + boot paths. |
| HTREE indexed dirs + fast/slow symlinks (ext4) | Performance optimizations + extension; linear dirent scan + indirect-tree read suffices today. Queue when a real consumer needs them. |
| FAT32 + additional read-only FSes | No consumer pressure. FAT16 + ext2/4 cover current boot path + iron read surface. |
| Full USB hub / hot-plug | xHCI cmd-path + USB-HID + USB Mass Storage classes shipped (1.30.x → 1.31.3); hub topology + hot-add deferred to plug-and-play cycle (pre-1.35.0). |
| SMP scheduling (beyond infrastructure) | APIC/IPI/trampoline are in place; cross-core scheduler + AP-wakeup-on-real-hardware deferred. Gated on hardware-validation infra. |
| Real-iron NIC (e1000e / I225-V / RTL8125) | Different device class; carved out for **1.32.x networking cycle** (`storage ✅ → networking → write`). |
| Optical via USB MS (SCSI MMC profile) | HP external USB Blu-ray on archaemenid derps the NUC at cold boot pre-power-on (firmware quirk). Deferred to plug-and-play cycle; AllInOne internal CD/DVD an alternative path. |

## Named Subsystems

Every subsystem is a standalone repo at `/home/macro/Repos/{name}/`. Each has its own CLAUDE.md, CHANGELOG, and version. **Live versions and per-repo status**: [`development/state.md`](development/state.md) and [`development/planning/shared-crates.md`](development/planning/shared-crates.md). Per-subsystem version numbers intentionally elided below — they drift fast and the registry files are the canonical source.

### ark — Unified Package Manager

User-facing CLI for all package operations. Substantial size/speed gains vs the prior Rust predecessor.

### nous — Package Resolver

Intelligence layer behind ark. Given a package name, determines which source to use.

### sigil — Trust System

System-wide trust and verification. Every binary, package, config, and update is verified through sigil. Ed25519 signing, revocation lists, trust levels.

### kavach — Sandbox Execution

Landlock + seccomp-bpf sandboxing. Single dependency (sigil). Substantial size + lifecycle-speed improvements over the prior Rust implementation.

### aegis — System Security Daemon

Unified security and threat protection. Coordinates threat detection, quarantine, and scanning. Cyrius-native; shipped v1.0+ in May 2026.

### takumi — Package Build System

Compiles packages from source into `.ark` binary packages via TOML recipes. Recipes live in the `zugot` repo. Cyrius port in flight; `rust-old/` authoritative until parity.

### argonaut — Init System

Init system library. Three boot modes: Server, Desktop, Minimal. The BOOT_MINIMAL mode landed agnoshi as a no-deps console service for the closed-beta MVP path.

### bote — MCP Core

MCP message pipeline + host registry. Streamable HTTP via stdlib http_server.

### t-ron — MCP Security

MCP security monitor.

### daimon — Agent Orchestrator

Agent lifecycle, sandboxing, and inter-agent communication. Ships 140+ MCP tools.

### hoosh — LLM Gateway

OpenAI-compatible API proxy with 15 provider backends, caching, rate limiting, hardware acceleration.

### agnoshi — AI Shell

Natural language terminal shell.

### aethersafha — Desktop Compositor

Wayland compositor with plugin host architecture. Cyrius port pending.

## Security Architecture

### Defense in Depth

```
+-----------------------------------------------------------+
|  Network: TLS (via sigil), certificate verification        |
+-----------------------------------------------------------+
|  Execution: Landlock + seccomp-bpf (kavach), namespaces    |
+-----------------------------------------------------------+
|  Storage: Encryption, integrity verification               |
+-----------------------------------------------------------+
|  Trust: Ed25519 signing, revocation (sigil)                |
+-----------------------------------------------------------+
|  Audit: Hash-chained log (libro), anomaly detection        |
+-----------------------------------------------------------+
```

### Sandbox Apply Order

1. MAC policy (Landlock)
2. Syscall filtering (seccomp-bpf)
3. Network isolation (namespaces)
4. Audit chain activation

### Package Trust Flow (sigil)

```
Publisher signs package with Ed25519 key
  -> sigil verifies signature against publisher keyring
  -> aegis scans contents
  -> kavach enforces sandbox profile at runtime
  -> libro records to audit chain
```

## Data Flow

### Agent Action Flow

```
User Request -> agnoshi -> daimon -> Agent Process (kavach-sandboxed)
                                |                       |
                           libro audit            hoosh (if LLM needed)
```

### Boot Flow

```
gnoboot (sovereign UEFI bootloader, Path-C handoff)
  -> AGNOS kernel (Cyrius-native, 35+ subsystems, 26 syscalls)
  -> kybernet PID 1
  -> argonaut init sequence
  -> daimon agent runtime
  -> hoosh LLM gateway
  -> agnoshi shell / aethersafha desktop
```

## Technology Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Kernel | Cyrius (AGNOS-native) | 35+ subsystems, 26 syscalls. Live size + version: [`development/state.md`](development/state.md) |
| Compiler | Cyrius (cc5) | self-hosting from 29KB seed, 42+ stdlib modules. Live version + cc5 size: [`development/state.md`](development/state.md) |
| Bootloader | gnoboot | sovereign UEFI bootloader (PE32+ EFI Application). Replaces GRUB as of v1.30.0 Path-C. |
| User space | Cyrius | All ported subsystems compile with `cyrius build` |
| Host bootstrap | Linux kernel configs | For building cross-compiler on existing host only |
| Build recipes | TOML (zugot repo) | 421 base + 90 bazaar recipes |
| Package format | `.ark` | Built by takumi, installed by ark |

### Pending Cyrius Ports

Per [`development/state.md`](development/state.md), these subsystems are still pending or in-flight (Rust authoritative):

| Subsystem | Notes |
|-----------|-------|
| bhava | Rust 2.0.0 — emotion/sentiment port can start; gating on v5.9.x stdlib + math additions |
| aethersafha | Scaffold — Wayland compositor real implementation pending |
| takumi | Cyrius port active, `rust-old/` authoritative until parity |
| goonj | Acoustics — Rust authoritative, port pending |
| naad | Audio synthesis — Rust authoritative, port pending |

Recently shipped (no longer pending): phylax, shakti, hisab, **aegis** (1.0+, Cyrius-native, May 2026), **gnoboot** (sovereign UEFI bootloader, v0.2.0), **kriya** (coreutils-equivalent multi-tool, M5 grep+find+xargs closeout). See [shared-crates registry](development/planning/shared-crates.md) for full status.

## Design Decisions

### 1. Sovereign Kernel

AGNOS has its own kernel written in Cyrius — iron-validated on NUC AMD 2026-05-15. No Linux dependency at runtime. Linux kernel configs in this repo are for host bootstrap only. Live kernel size + version: [`development/state.md`](development/state.md).

### 2. Cyrius for Everything

Cyrius is the sovereign systems language — 29KB seed, zero external dependencies, self-hosting compiler. All production subsystems are being ported from Rust to Cyrius. 30+ ports complete.

### 3. Landlock + seccomp-bpf

Combine unprivileged filesystem sandboxing (Landlock) with syscall filtering (seccomp-bpf). Implemented in kavach (Cyrius-native).

### 4. Local-First AI

Prioritize local LLM execution with cloud fallback. Privacy, offline capability, reduced latency. Implemented in hoosh.

### 5. Cryptographic Audit Chain

Immutable, hash-chained, signed audit logs via libro. sigil owns all cryptographic operations.

### 6. Named Subsystems

Major cross-cutting concerns get memorable names for clear identity and discoverability. Each is a standalone repo with its own lifecycle.

### 7. Standalone Repos

Every subsystem is extracted into its own repository. The genesis repo (agnosticos) is meta, narrative, and build wrapper only. This allows independent versioning, per-repo CI, and clear ownership boundaries.

---

## Related Documentation

- [Development Roadmap](development/roadmap.md)
- [Security Guide](security/security-guide.md)
- [ADR Index](adr/README.md)
