# AGNOS System Architecture

> **Last Updated**: 2026-05-06 | **Version**: 2026.5.6
>
> Live ecosystem state (cycle, per-repo pins, sweeps): [`development/state.md`](development/state.md). Stable narrative values below — verify against state.md before quoting per-repo versions.

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
|  |  |         v1.26.1 — 248KB, 33 subsystems             |       |   |
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

**AGNOS kernel v1.26.1** — 248KB, 33 subsystems, 26 syscalls:
- Memory management, process management, SMP
- TCP/IP networking, VirtIO-Net/Blk
- FAT16 filesystem, ELF loader
- Pipes, signals, epoll, timerfd
- 18-command built-in shell
- kybernet as PID 1 (486KB, 140 tests)

The `kernel/` directory in this repo contains Linux kernel configs for **host bootstrap only** — building the cross-compiler toolchain on an existing Linux host before AGNOS can self-host.

## Kernel Layers

> Conceptual decomposition. Layers 1–5 shipped. Live per-subsystem status: [agnos repo](https://github.com/MacCracken/agnos). Live size: [`development/state.md`](development/state.md).

The kernel was originally planned as five layers — *boots*, *runs programs*, *storage*, *talks to the world*, *usable*. All five landed inside a ~7-week window (Cyrius scaffold 2026-04-03 → kernel v1.22.0 on 2026-04-14, hardened through to v1.26.1 / 248KB by 2026-04-28). The decomposition below reflects where each layer sits today.

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
- **kybernet PID 1** — v1.0.2, 486KB, 140 tests, 46 benchmarks, 1,583× faster `is_mounted` vs Rust baseline
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
| Full Layer 1–5 | ~70–80 KB | **248 KB (v1.26.1)** |

The shipped kernel is ~3× the original estimate because it carries features outside the original 5-layer shortest-path plan: SMP infrastructure (APIC, IPI, trampoline, per-CPU stacks); cross-architecture (x86_64 + aarch64 in one binary); full TCP instead of UDP-only; slab allocator with 8 size classes; FAT16 driver; Ring 3 with proper TSS; Local APIC timer.

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

Every subsystem is a standalone repo at `/home/macro/Repos/{name}/`. Each has its own CLAUDE.md, CHANGELOG, and version.

### ark — Unified Package Manager (v0.8.0, Cyrius)

User-facing CLI for all package operations. 4× smaller, 40× faster than the Rust predecessor.

### nous — Package Resolver (v1.1.1, Cyrius)

Intelligence layer behind ark. Given a package name, determines which source to use.

### sigil — Trust System (v2.9.4, Cyrius)

System-wide trust and verification. Every binary, package, config, and update is verified through sigil. Ed25519 signing, revocation lists, trust levels.

### kavach — Sandbox Execution (v3.0.0, Cyrius)

344KB (was 2.4MB Rust). Landlock + seccomp-bpf sandboxing. 1 dependency (sigil), 9 CWE fixes, sandbox lifecycle 500× faster than Rust version.

### aegis — System Security Daemon (v0.1.0, pending Cyrius port)

Unified security and threat protection. Coordinates threat detection, quarantine, and scanning.

### takumi — Package Build System (v0.8.0, Cyrius port in flight)

Compiles packages from source into `.ark` binary packages via TOML recipes. Recipes live in the `zugot` repo. Cyrius port active; `rust-old/` authoritative until parity.

### argonaut — Init System (v1.2.0, Cyrius)

Init system library. Three boot modes: Server, Desktop, Minimal.

### bote — MCP Core (v2.5.1, Cyrius)

MCP message pipeline at ~5µs/message. Streamable HTTP via stdlib http_server.

### t-ron — MCP Security (v2.0.0, Cyrius)

MCP security monitor. Out of pre-release as of Apr 2026.

### daimon — Agent Orchestrator (v1.1.1, Cyrius)

Agent lifecycle, sandboxing, and inter-agent communication. 144 MCP tools.

### hoosh — LLM Gateway (v2.0.0, Cyrius)

474KB. OpenAI-compatible API proxy with 15 provider backends, caching, rate limiting, hardware acceleration.

### agnoshi — AI Shell (v1.0.0, Cyrius)

Natural language terminal shell.

### aethersafha — Desktop Compositor (v0.1.0, pending Cyrius port)

Wayland compositor with plugin host architecture.

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
AGNOS kernel (248KB at v1.26.1, Cyrius-native)
  -> kybernet PID 1 (486KB)
  -> argonaut init sequence
  -> daimon agent runtime
  -> hoosh LLM gateway
  -> agnoshi shell / aethersafha desktop
```

## Technology Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Kernel | Cyrius (AGNOS-native) | 248KB (v1.26.1), 33 subsystems, 26 syscalls |
| Compiler | Cyrius 5.9.0 (cc5) | ~741KB, self-hosting from 29KB seed, 42+ stdlib modules |
| User space | Cyrius | All ported subsystems compile with `cyrius build` |
| Host bootstrap | Linux kernel configs | For building cross-compiler on existing host only |
| Build recipes | TOML (zugot repo) | 421 base + 90 bazaar recipes |
| Package format | `.ark` | Built by takumi, installed by ark |

### Pending Cyrius Ports

Per [`development/state.md`](development/state.md), these subsystems are still pending or in-flight (Rust authoritative):

| Subsystem | Version | Notes |
|-----------|---------|-------|
| bhava | 2.0.0 (Rust) | Emotion/sentiment — port can start; gating on v5.9.x stdlib + math additions |
| aegis | 0.1.0 (scaffold) | Security daemon — real implementation pending |
| aethersafha | 0.1.0 (scaffold) | Wayland compositor — real implementation pending |
| takumi | 0.8.0 | Build system — Cyrius port active, `rust-old/` authoritative until parity |

Recently shipped (no longer pending): phylax 1.0.0, shakti 0.2.2, hisab 2.2.0 (all Cyrius-native). See [shared-crates registry](development/planning/shared-crates.md) for full status.

## Design Decisions

### 1. Sovereign Kernel

AGNOS has its own kernel written in Cyrius (248KB, v1.26.1). No Linux dependency at runtime. Linux kernel configs in this repo are for host bootstrap only.

### 2. Cyrius for Everything

Cyrius is the sovereign systems language — 29KB seed, zero external dependencies, self-hosting compiler. All production subsystems are being ported from Rust to Cyrius. 30+ ports complete.

### 3. Landlock + seccomp-bpf

Combine unprivileged filesystem sandboxing (Landlock) with syscall filtering (seccomp-bpf). Implemented in kavach (3.0.0, Cyrius-native).

### 4. Local-First AI

Prioritize local LLM execution with cloud fallback. Privacy, offline capability, reduced latency. Implemented in hoosh (2.0.0).

### 5. Cryptographic Audit Chain

Immutable, hash-chained, signed audit logs via libro (2.0.5). sigil (2.9.4) owns all cryptographic operations.

### 6. Named Subsystems

Major cross-cutting concerns get memorable names for clear identity and discoverability. Each is a standalone repo with its own lifecycle.

### 7. Standalone Repos

Every subsystem is extracted into its own repository. The genesis repo (agnosticos) is meta, narrative, and build wrapper only. This allows independent versioning, per-repo CI, and clear ownership boundaries.

---

## Related Documentation

- [Development Roadmap](development/roadmap.md)
- [Security Guide](security/security-guide.md)
- [ADR Index](adr/README.md)
