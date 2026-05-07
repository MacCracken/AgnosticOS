# AGNOS Kernel — Layer Architecture

> **Status**: Layers 1–5 shipped. Kernel at **v1.26.1** — 248KB, 33 subsystems, 26 syscalls. (Live size in [`development/state.md`](../development/state.md).)
> **Last Updated**: 2026-04-20 (status line refreshed 2026-05-06)
> **Authoritative per-subsystem status**: [agnos/CLAUDE.md](https://github.com/MacCracken/agnos). This doc is the conceptual decomposition; the subsystem table in the agnos repo is the receipt.

The kernel was originally planned as five layers — "boots," "runs programs," "storage," "talks to the world," "usable." All five landed inside a ~7-week window (Cyrius scaffold 2026-04-03 → kernel v1.22.0 on 2026-04-14, hardened through to v1.26.1 / 248KB by 2026-04-28). The decomposition below reflects where each layer sits today and what it carries.

---

## Layer 1 — Can Boot and Respond ✅

**x86_64**: multiboot1 32-bit ELF entry, 32→64 long-mode shim, GDT (5 segments + TSS), IDT (256 vectors), PIC remap to INT 32+, Local APIC at `0xFEE00000` (timer, IPI), periodic ~100Hz timer, PS/2 keyboard (full US QWERTY), COM1 serial I/O at `0x3F8`.

**aarch64**: DTB boot, EL2→EL1 transition, GICv2 interrupt controller, ARM generic timer, PL011 UART.

**Memory**: page tables (2MB huge, 16MB identity map, per-process), PMM (bitmap, 4096 pages, next-free hint), VMM (map/unmap/alloc, user-accessible), slab heap (8 size classes, 32B–4096B).

---

## Layer 2 — Can Run Programs ✅

- **ELF loader** — static ELF64, per-process address space, Cyrius-emitted binaries load directly
- **Process table** — 16 slots, 168B context, CR3 per-process
- **Context switch** — full register save/restore (all 9 caller-saved regs) + CR3 switch
- **Scheduler** — round-robin on timer tick
- **SYSCALL/SYSRET** — MSR setup, ring 3 ↔ ring 0 transition
- **TSS** — RSP0 for ring 3 stack switching

---

## Layer 3 — Can Access Storage ✅

- **VFS** — file table, 7 file types (device, memfile, signalfd, epoll, timerfd, pipe, regular)
- **Initrd** — flat format, name lookup
- **VirtIO-Blk** — legacy PCI, sector read/write, DMA buffers
- **FAT16** — read-only, root directory listing, file open/read

**Not yet shipped**: ATA/NVMe drivers for real hardware disk, additional filesystems (ext2/ext4, FAT32), framebuffer/MMIO graphics.

---

## Layer 4 — Can Talk to the World ✅

- **VirtIO-Net** — legacy PCI, virtqueues, Ethernet frames
- **ARP + IPv4 + UDP** — full send/recv
- **TCP** — connect/send/recv/close with SYN/ACK/FIN state machine (not just the UDP-only MVP originally planned)
- **Serial console** — input + output via COM1 / PL011

---

## Layer 5 — Can Be Used ✅

- **Shell** — 19 commands: `help echo ps free cat uptime lspci cpus net send recv tcp pipe blkread ls disk bench test halt`
- **kybernet PID 1** — v1.0.1, 486KB, 140 tests, 46 benchmarks, 1,583× faster `is_mounted` vs Rust baseline
- **Signals** — per-process `proc_signals` / `proc_sigmask`, `kill` / `sigprocmask` / `signalfd`
- **Epoll** — `epoll_create`, `epoll_ctl`, `epoll_wait`
- **Timerfd** — `timerfd_create`, `timerfd_settime`
- **Pipes** — circular buffer IPC, read/write ends, VFS type 6

---

## Size — Projected vs Actual

| Milestone | Original estimate (Apr 7) | Actual |
|-----------|---------------------------|-------|
| Layer 1 alone | 31 KB | 31 KB ✓ |
| + Layer 2 (run programs) | ~38 KB | — |
| + Layer 3 (storage) | ~40 KB | — |
| + Layer 5 (shell) | ~42–45 KB | — |
| + VFS + signals + pipes | ~50 KB | — |
| + VirtIO + basic TCP | ~65 KB | — |
| Full Layer 1–5 | ~70–80 KB | **248 KB (v1.26.1)** |

The shipped kernel is ~3× the original estimate because it carries features outside the original 5-layer shortest-path plan:

- **SMP infrastructure** — APIC, IPI, trampoline, per-CPU stacks
- **Cross-architecture** — x86_64 *and* aarch64 (GIC, ARM generic timer, PL011 UART) in one binary via conditional compilation
- **Full TCP** instead of UDP-only
- **Slab allocator** with 8 size classes (rather than a simpler scheme)
- **FAT16 driver** (not assumed in original layer plan)
- **Ring 3 with proper TSS** (originally deferred)
- **Local APIC timer** (originally just PIT)

The conceptual 5-layer model still maps. The kernel simply carries more per layer than the MVP "boots into shell" scope intended.

---

## Syscalls (26)

```
exit(0)         write(1)        getpid(2)       spawn(3)
waitpid(4)      read(5)         close(6)        open(7)
dup(8)          mkdir(9)        rmdir(10)       mount(11)
sync(12)        reboot(13)      pause(14)       getuid(15)
kill(16)        sigprocmask(17) signalfd(18)    epoll_create(19)
epoll_ctl(20)   epoll_wait(21)  timerfd_create(22)  timerfd_settime(23)
umount(24)      pipe(25)
```

---

## Userland Alignment

| Kernel provides | Userland uses |
|-----------------|--------------|
| ELF loader (Layer 2) | Cyrius compiler emits ELF directly; no translation layer |
| Initrd + VFS (Layer 3) | Userspace tools packed into CPIO initrd at build |
| Signals + epoll + timerfd (Layer 5) | kybernet event loop, service supervision |
| SYSCALL/SYSRET (Layer 2) | agnosys kernel-interface library (`v0.97.2`, 20 modules, zero deps) |
| Pipes (Layer 3/5) | Shell pipelines, inter-service IPC |

---

## DOOM

The original plan named DOOM as a 3-stage milestone (run original → port to Cyrius → kernel demo).

- **cyrius-doom** exists as a Cyrius-native DOOM engine (v0.26.1). The port landed; it is waiting on the Cyrius v5.6.x compiler-optimization arc for performance work.
- **Kernel integration as a bootable demo** still requires a framebuffer / MMIO graphics driver. That's the one Layer 3 item from the original plan that hasn't shipped in the kernel.

---

## What's not yet in the kernel

| Gap | Why it's deferred |
|-----|-------------------|
| Framebuffer / MMIO graphics | Prereq for DOOM demo and Wayland compositor (aethersafha). Scheduled alongside ISO assembly work. |
| Real-hardware disk drivers (ATA/NVMe) | VirtIO-Blk covers QEMU; real-hw bring-up is post-Beltane. |
| Additional filesystems (ext2/ext4, FAT32) | FAT16 sufficient for current boot path. |
| USB stack | Not needed for current boot/test pipeline. |
| SMP scheduling (beyond infrastructure) | APIC/IPI/trampoline are in place; cross-core scheduler work deferred. |

---

*This doc is the conceptual layer map. For live per-subsystem status, read the Kernel Subsystems table in [agnos/CLAUDE.md](https://github.com/MacCracken/agnos) — it's updated per release and is the authoritative source.*
