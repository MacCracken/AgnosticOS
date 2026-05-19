# AGNOS System Architecture

> **Last Updated**: 2026-05-18 | **Version**: 2026.5.18
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

- **VFS** — file table, 7 file types (device, memfile, signalfd, epoll, timerfd, pipe, regular)
- **Initrd** — flat format, name lookup
- **VirtIO-Blk** — legacy PCI, sector read/write, DMA buffers
- **FAT16** — read-only, root directory listing, file open/read

**Not yet shipped**: ATA/NVMe drivers for real hardware disk, additional filesystems (ext2/ext4, FAT32), framebuffer/MMIO graphics.

### Layer 4 — Can Talk to the World

- **VirtIO-Net** — legacy PCI, virtqueues, Ethernet frames
- **ARP + IPv4 + UDP** — full send/recv
- **TCP** — connect/send/recv/close with SYN/ACK/FIN state machine (not just the UDP-only MVP originally planned)
- **Serial console** — input + output via COM1 / PL011

### Layer 5 — Can Be Used

- **Shell** — 19 commands: `help echo ps free cat uptime lspci cpus net send recv tcp pipe blkread ls disk bench test halt`
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
| Framebuffer / MMIO graphics | Prereq for DOOM kernel demo and Wayland compositor (aethersafha). Scheduled alongside ISO assembly work. |
| Real-hardware disk drivers (ATA/NVMe) | VirtIO-Blk covers QEMU; real-hw bring-up is post-Beltane. |
| Additional filesystems (ext2/ext4, FAT32) | FAT16 sufficient for current boot path. |
| USB stack | Not needed for current boot/test pipeline. |
| SMP scheduling (beyond infrastructure) | APIC/IPI/trampoline are in place; cross-core scheduler work deferred. |

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
