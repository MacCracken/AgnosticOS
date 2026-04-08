# Building a Sovereign Compiler and OS Kernel with Claude

> In 2026, two teams independently used Claude Opus 4.6 to build compilers. This article compares the approaches, results, and what the differences reveal about software development methodology.

---

## The Projects

**Project A (Anthropic)** — In February 2026, Anthropic published "[Building a C Compiler with Claude](https://www.anthropic.com/engineering/building-c-compiler)." 16 parallel Claude agents built a C compiler in Rust over two weeks across ~2,000 sessions, consuming 2 billion input tokens at a cost of ~$20,000. The compiler produces 100,000 lines of Rust and passes 99% of GCC torture tests. It compiles the Linux kernel, QEMU, FFmpeg, SQLite, PostgreSQL, Redis, and Doom.

**Project B (AGNOS/Cyrius)** — In April 2026, one developer working with one Claude agent built a self-hosting systems language and operating system kernel over four days across three sessions, at a cost of ~$400 (two Max subscriptions). The compiler is 164KB (v1.8.2), self-hosts in 11ms from a 29KB seed binary, and has zero external dependencies. The kernel is 98KB (v1.1.0) with 27 subsystems, 25 syscalls, and a 178-cycle getpid — booting to an interactive shell in <100ms.

Project A was built as a capability demonstration. Project B was built out of necessity.

---

## Why Cyrius Exists

AGNOS is a 108-repo Rust project. The plan was to publish shared crates to crates.io so repos could depend on each other via feature flags.

crates.io requires a globally unique name. The project hit name squatting five times — placeholder repos with no code occupying names a 108-repo OS needed. The fifth collision changed the question from "what name is available?" to "why am I asking permission to publish my own code?"

That question cascaded. If the registry is the bottleneck, remove the registry. If the registry requires the language's toolchain, remove the language. If the language requires LLVM, remove LLVM. Each dependency peeled back revealed another, until the only remaining dependency was an x86_64 processor.

---

## Capability vs Sovereignty

Project A's compiler is written in Rust. Building it requires a Rust toolchain (~200MB), which requires LLVM (~100MB), which requires a C++ compiler, which requires libc. The compiler cannot build itself.

Project B's compiler starts from a 29KB binary. From that seed, the full toolchain bootstraps in under 50ms. The compiler produces byte-identical output when compiling its own source. Removing Rust, GCC, LLVM, and libc from the system does not affect Project B's ability to build itself.

Project A demonstrates capability — what Claude can produce at scale. Project B demonstrates sovereignty — a system that depends on nothing external.

### Security Implications

The AGNOS kernel has zero lines of C. This eliminates vulnerability categories that account for 60-70% of Linux kernel CVEs:

| Vulnerability Class | Root Cause in C | AGNOS Status |
|---------------------|----------------|--------------|
| Buffer overflow | Unbounded arrays, `strcpy`, `sprintf` | Eliminated — no C string functions |
| Use-after-free | Manual `malloc`/`free` | Eliminated — slab allocator, no user-facing `free` |
| Format string attack | `printf` with user-controlled format | Eliminated — no `printf` |
| Null pointer dereference | `void*` arithmetic | Eliminated — no `void*` |
| Integer promotion overflow | Implicit type widening | Eliminated — single type (i64) |
| Double free | Manual memory management | Eliminated — slab fixed-size classes |

This does not mean AGNOS is bug-free — logic errors, race conditions, and design flaws remain possible. Cyrius has no borrow checker today (planned for v1.3), so memory safety comes from testing and auditing, not the type system. But the largest single category of kernel vulnerabilities is eliminated at the language level.

### Prior Art

Other projects have attempted single-language operating systems:

| Project | Language | External Dependency |
|---------|----------|-------------------|
| Singularity (Microsoft) | C# | Bootloader in assembly, runtime in C++ |
| Redox | Rust | Compiler requires LLVM (C++) |
| MirageOS | OCaml | Runs on Xen hypervisor (C) |
| TempleOS | HolyC | Compiler bootstrapped from C |
| **AGNOS** | **Cyrius** | **29KB seed → self-hosting compiler → kernel → init → tools** |

AGNOS is, to our knowledge, the first single-language OS stack where the compiler is self-hosting from a hand-auditable seed with no external toolchain in the build path. That said, the kernel is young (2,979 lines, 25 syscalls) compared to the decades of development in Redox or the formal verification work behind seL4. Sovereignty is achieved; maturity is not.

---

## Comparison

| Metric | Project A (Anthropic) | Project B (Cyrius) |
|--------|----------------------|-------------------|
| Duration | ~2 weeks | 4 days |
| Agents | 16 parallel | 1 (3 sessions) |
| Sessions | ~2,000 | 3 |
| Cost | ~$20,000 (API) | ~$400 (subscription) |
| Compiler | 100,000 lines Rust | 4,127 lines Cyrius (164KB) |
| Self-hosting | No | Yes — byte-exact |
| Self-compile | N/A | 11ms |
| Seed binary | ~200MB (rustc) | 29KB |
| External dependencies | Rust, LLVM, GCC, assembler, linker | Zero |
| Tests | GCC torture suite (99%) | 267 (0 failures) |
| Architectures | x86_64 | x86_64 + aarch64 |
| Kernel | Compiles Linux kernel | Builds its own — 98KB, 27 subsystems |
| Lines of C in stack | 100,000 (Rust needs LLVM/GCC) | Zero |

Project A has broader C compatibility. Project B has deeper sovereignty. These are different goals.

---

## Methodology

### Incremental vs Parallel

**Project A** uses horizontal scaling: 16 agents in parallel with lock-file synchronization and a "Ralph loop" harness for continuous task assignment.

**Project B** uses vertical progression: each stage proves itself before the next begins.

```
Day 1:  seed → assembler → stage1a–1f → self-hosting compiler (bootstrap loop closed)
Day 2:  modular compiler → structs, pointers, inline asm → initial OS kernel
Day 3:  stdlib (21 modules) → tools → 5 Rust crate rewrites → aarch64 cross-compiler
Day 4:  kernel v1.1.0 (98KB, 27 subsystems, 25 syscalls, networking, shell) → Cyrius v1.5
```

At every stage, the system compiles itself and produces verified output. The parallel approach scales throughput. The incremental approach scales confidence.

### The Vidya Effect

AGNOS maintains **vidya** — a curated programming reference library (36 topics, 10 languages). When the compiler needed pointer support, the cycle was: research (30 seconds, patterns already documented) → implementation (15 lines) → testing (48/48 first run). Total: minutes.

Struct support, implemented before vidya coverage existed, took hours. Same developer, same agent, same compiler. The variable was documentation coverage.

---

## Results

### Kernel

The AGNOS kernel (v1.1.0) is 98KB. It boots to an interactive shell in <100ms with:

- Ring 3 user mode, SYSCALL/SYSRET, per-process page tables
- PMM, VMM, slab heap allocator
- VFS, device drivers, initrd filesystem
- PCI bus scan, VirtIO-net driver, IP/UDP stack
- SMP infrastructure (LAPIC, IPI, AP trampoline)
- kybernet init (PID 1), 12 shell commands, 25 syscalls

Benchmarks (QEMU, ~1GHz emulated):

| Operation | Cycles | Throughput |
|-----------|--------|------------|
| Syscall (getpid) | 178 | 5.6M/sec |
| PMM alloc+free | 1,222 | 818K/sec |
| Heap 32B alloc+free | 1,187 | 843K/sec |
| VFS open+read+close | 5,374 | 186K/sec |

The 178-cycle getpid is within the range of Linux on native hardware (100-200 cycles) while running under QEMU emulation.

### Toolchain Size

| Component | Size |
|-----------|------|
| Seed binary | 29KB |
| Compiler (v1.8.2) | 164KB |
| Kernel (v1.1.0) | 98KB |
| **Seed → networked OS** | **291KB** |

For context: GCC is ~100MB, Clang/LLVM is ~500MB.

Head-to-head Cyrius vs Rust benchmarks on real crate conversions: [Cyrius vs Rust Benchmarks](cyrius-vs-rust-benchmarks.md).

---

## Limitations

**Project B cannot compile C.** Porting existing C/Rust codebases requires rewriting in Cyrius. An automated tool (`cyrb port`) scaffolds projects, but the migration of 107 Rust repos (~1M lines) is ongoing.

**Project B's kernel is not Linux.** It lacks: full TCP (UDP only), disk drivers (initrd only), multi-user support, POSIX compatibility, and decades of driver support.

**Project A cannot self-host.** It depends on external toolchains but compiles real-world C codebases today.

**Cyrius has no borrow checker.** Ownership and borrow checking are planned for v1.3.

Both projects represent genuine engineering achievements with different trade-offs.

---

## Cost

| | Project A | Project B |
|---|----------|----------|
| Spend | ~$20,000 (API) | ~$400 (subscription) |
| Ratio | 50x | 1x |
| Output | C compiler (capability demo) | Language + OS kernel (production infrastructure) |

The 50x cost difference reflects the difference between parallel brute-force and incremental, documentation-driven development.

---

## Credits

One developer and three Claude Opus 4.6 agent sessions:

| Role | Contribution |
|------|-------------|
| **Developer** (Robert MacCracken) | Architecture, decisions, steering. All design choices are human. |
| **Agent 1 — Meta** | Documentation, roadmaps, ecosystem standards. No compiler or kernel code. |
| **Agent 2 — Language** | Cyrius from seed to v1.5: compiler, stdlib, tools, initial kernel boot, `cyrb port` migration tool, vidya documentation. |
| **Agent 3 — Kernel** | Kernel from initial boot to 98KB networked OS (v1.1.0): Ring 3, VFS, networking, SMP, 25 syscalls, shell. |

The developer held the vision. The agents held the context. The reference library accelerated all three.

---

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
