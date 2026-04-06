# AGNOS Kernel — Layer Roadmap

> **Status**: Layer 1 complete (31KB) | **Last Updated**: 2026-04-06
>
> 5 layers from "boots" to "usable OS." Layer 1 is done. Each layer builds on the previous.
> The shortest path to "boots into a shell" is 5 items from Layer 2 + Layer 3 + Layer 5.

---

## Layer 1 — Can Boot and Respond ✅ DONE (31KB)

17.5KB of code, 32 functions, 656 source lines.

- [x] Multiboot1 boot, 32→64 bit shim (long mode)
- [x] GDT, IDT (256 vectors), PIC remap, PIT timer (100Hz)
- [x] Keyboard input (IRQ1, ring buffer, scancode→ASCII)
- [x] Serial I/O (console output)
- [x] Page tables (16MB identity map, 2MB pages)
- [x] Physical memory manager (bitmap, 4096 pages)
- [x] Virtual memory manager (map/unmap/alloc)
- [x] Process table (create, state management)
- [x] Syscall interface (exit, write, getpid)

---

## Layer 2 — Can Run Programs

**Goal**: Load and execute Cyrius-compiled binaries. Multiple processes running concurrently.

| # | Feature | What It Does | Effort | Notes |
|---|---------|-------------|--------|-------|
| 1 | **ELF loader** | Load userspace binaries from memory/initrd | Medium | Parse ELF headers, map segments, set entry point. Cyrius already emits valid ELF. |
| 2 | **Context switching** | Save/restore register state on timer interrupt | Medium | Push all GPRs + RIP + RFLAGS on ISR, restore on schedule. The core of multitasking. |
| 3 | **Scheduler** | Round-robin process scheduling | Low | Walk process table on timer tick, pick next READY process, context switch. Priority-based comes later. |
| 4 | **User/kernel mode split** | Ring 3 userspace, Ring 0 kernel | High | Separate page tables per process, SYSCALL/SYSRET transition, TSS for stack switching. Currently all Ring 0. |
| 5 | **Fast syscall interface** | SYSCALL/SYSRET instruction path | Medium | Replace INT 0x80 with SYSCALL for user→kernel transition. MSR setup for STAR/LSTAR/SFMASK. |

**Shortest path**: Items 1-3 get processes running. Item 4-5 add proper isolation (can defer for initial "boots into a shell" milestone).

---

## Layer 3 — Can Access Storage

**Goal**: Read files. Load programs from disk or initrd.

| # | Feature | What It Does | Effort | Notes |
|---|---------|-------------|--------|-------|
| 6 | **ramfs / initrd** | In-memory filesystem for initial boot | Low | Pack Cyrius binaries into CPIO archive, load via multiboot module. No disk driver needed. **Do this first.** |
| 7 | **VFS** | Virtual filesystem abstraction | Medium | Open/read/write/close interface. Mount points. File descriptors per process. |
| 8 | **ATA/NVMe driver** | Read/write actual disks | High | PIO mode ATA first (simple), DMA later. NVMe for modern hardware. |
| 9 | **FAT32 or ext2 driver** | Parse filesystem on disk | High | FAT32 is simpler. ext2 is more Unix-native. Pick one for first boot. |

**Shortest path**: Item 6 (ramfs) alone is enough to boot into a shell with all the Cyrius-compiled utilities packed in.

---

## Layer 4 — Can Talk to the World

**Goal**: Network connectivity. External communication.

| # | Feature | What It Does | Effort | Notes |
|---|---------|-------------|--------|-------|
| 10 | **VirtIO drivers** | Network + block device for QEMU | Medium | VirtIO is the standard paravirtualized device interface. Gives network + disk in QEMU without hardware-specific drivers. |
| 11 | **TCP/IP stack** | Basic networking | Very High | ARP, IP, ICMP, TCP, UDP. Minimum: DHCP + TCP connect/listen. Could start with UDP-only for simplicity. |
| 12 | **UART/serial console** | Interactive serial shell | Low | Partially done. Complete with line editing, history. |

---

## Layer 5 — Can Be Used

**Goal**: Interactive operating system. User runs commands, manages processes.

| # | Feature | What It Does | Effort | Notes |
|---|---------|-------------|--------|-------|
| 13 | **Shell** | Command interpreter | Medium | Read line, parse command + args, fork+exec, wait. Tab completion later. The Cyrius-compiled cat/echo/head/etc. are the commands. |
| 14 | **Init system** | PID 1, service management | Low | kybernet is already written in Cyrius (7 modules, 38 tests). Port to run on the AGNOS kernel. |
| 15 | **Signal handling** | SIGTERM, SIGKILL, SIGCHLD | Medium | Signal delivery on process table. Parent notified on child exit. Required for proper shell job control. |
| 16 | **Pipe/redirect** | `cmd1 \| cmd2`, stdin/stdout redirect | Medium | Pipe syscall (anonymous pipe), dup2 for redirect. Required for Unix-style composition. |

---

## Shortest Path to "Boots Into a Shell"

Five items. Each builds on the previous. This is the critical path.

```
Step 1: ELF loader (Layer 2, #1)
  → Load Cyrius binaries we already have (true, false, echo, cat, head, wc, etc.)

Step 2: Context switch (Layer 2, #2)
  → Save/restore registers on timer interrupt
  → Multiple processes can run

Step 3: Scheduler (Layer 2, #3)
  → Round-robin over process table
  → Processes take turns

Step 4: ramfs (Layer 3, #6)
  → Pack binaries into CPIO initrd
  → Kernel loads them at boot
  → File descriptors: open("/bin/cat") → read → execute

Step 5: Shell (Layer 5, #13)
  → Read line from keyboard (already have keyboard input)
  → Parse command
  → Fork + load ELF from ramfs + exec
  → Wait for exit
  → Print prompt again

Result: AGNOS boots → shell prompt → user types "cat /etc/motd" → it works
```

**Estimated total**: ~1,500-2,500 lines of Cyrius. At current velocity (vidya-driven, ~15 lines/minute for known patterns), this is 2-4 sessions.

**Binary size estimate**: Current 31KB + ~10-15KB for Layer 2-3 + shell = ~42-46KB total.

---

## Size Projections

| Milestone | Estimated Binary | Notes |
|-----------|-----------------|-------|
| Layer 1 (done) | 31KB | VM, processes, syscalls, interrupts |
| + ELF loader + context switch + scheduler | ~38KB | Can run programs |
| + ramfs | ~40KB | Can load files |
| + shell | ~42-45KB | Boots into interactive shell |
| + VFS + signals + pipes | ~50KB | Unix-like usability |
| + VirtIO + basic TCP | ~65KB | Network connected |
| Full Layer 1-5 | ~70-80KB | Complete usable OS |

For reference: a single GNU `cat` binary is 47KB. The entire AGNOS kernel with all 5 layers may be smaller than one GNU utility.

---

## Relationship to Existing AGNOS Components

| Kernel Layer | Existing Cyrius Code | Status |
|-------------|---------------------|--------|
| Layer 2 (ELF) | Cyrius compiler emits ELF — the loader just parses what the compiler outputs | Ready |
| Layer 3 (ramfs) | 58 Cyrius-compiled programs ready to pack into initrd | Ready |
| Layer 5 (init) | kybernet (7 modules, 38 tests) already written in Cyrius | Ready to port |
| Layer 5 (shell) | agnoshi concepts applicable, but kernel shell is simpler | Design ready |

The kernel doesn't need to invent much. The userspace is already built. The kernel just needs to load and run it.

---

*Last Updated: 2026-04-06*
