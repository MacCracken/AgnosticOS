# Building a Sovereign Compiler and OS Kernel with Claude

> In 2026, two teams independently used Claude Opus 4.6 to build compilers. This article compares the approaches, results, and what the differences reveal about software development methodology.

---

## Background

In February 2026, Anthropic's engineering team published "[Building a C Compiler with Claude](https://www.anthropic.com/engineering/building-c-compiler)," demonstrating that 16 parallel Claude agents could build a C compiler in Rust capable of compiling the Linux kernel.

In April 2026, the AGNOS project built Cyrius — a self-hosting systems language with its own OS kernel — using a single Claude agent across three focused sessions. This article documents that process and compares the two approaches.

Both projects used Claude Opus 4.6. The results are meaningfully different.

---

## The Projects

**Project A (Anthropic)** — 16 parallel Claude agents built a C compiler in Rust over two weeks across ~2,000 sessions, consuming 2 billion input tokens at a cost of ~$20,000. The compiler produces 100,000 lines of Rust and passes 99% of GCC torture tests. It can compile the Linux kernel, QEMU, FFmpeg, SQLite, PostgreSQL, Redis, and Doom.

**Project B (AGNOS/Cyrius)** — One developer working with one Claude agent built a self-hosting systems language and operating system kernel over four days across three sessions, at a cost of ~$400 (two Max subscriptions — one for the compiler, one for the reference library that informed the methodology). The compiler is 164KB (v1.8.2), self-hosts in 11ms from a 29KB seed binary, and has zero external dependencies. The kernel is 98KB (v1.1.0) with 27 subsystems, 25 syscalls, and a 178-cycle getpid — booting to an interactive shell in <100ms.

**Motivation**: Project A was built as a capability demonstration. Project B was built out of necessity.

AGNOS is a 108-repo Rust project. The codebase was mature — science crates, security primitives, an init system, a compositor. The plan was to publish shared crates to crates.io so repos could depend on each other via feature flags without going fully public.

crates.io requires a globally unique name to publish. Even for private feature-gated dependencies, the registry checks the name against all public crates. The project hit name squatting five times. Five different crates, five different squatters — placeholder repos with no code occupying the names that a 108-repo operating system needed. Some projects were renamed. The fifth collision prompted a different question.

Not "what name is available?" but "why am I asking permission to publish my own code?"

That question cascaded. If the registry is the bottleneck, remove the registry. If the registry requires the language's toolchain, remove the language. If the language requires LLVM, remove LLVM. Each dependency peeled back revealed another dependency underneath, until the only remaining dependency was an x86_64 processor and electricity.

Cyrius was not planned. It was precipitated — by a registry model where anyone can squat a name and block a project they have never seen. The five squatters did not know they were building the case for a sovereign toolchain. They were just occupying space. But the response was not to find more space. It was to stop renting.

---

## Why Sovereignty Matters

### Dependency

Project A's compiler is written in Rust. Building it requires a Rust toolchain (~200MB), which requires LLVM (~100MB), which requires a C++ compiler, which requires a C compiler, which requires libc. The compiler cannot build itself or the language it is written in.

Project B's compiler starts from a 29KB binary. From that seed, the full toolchain bootstraps in under 50ms. The compiler produces byte-identical output when compiling its own source. Removing Rust, GCC, LLVM, and libc from the system does not affect Project B's ability to build itself.

This distinction — **capability** versus **sovereignty** — is the central finding.

### Security

The AGNOS kernel has zero lines of C. This eliminates entire categories of vulnerability that account for 60-70% of Linux kernel CVEs:

| Vulnerability Class | Root Cause in C | AGNOS Status |
|---------------------|----------------|--------------|
| Buffer overflow | Unbounded arrays, `strcpy`, `sprintf` | **Eliminated** — no C string functions |
| Use-after-free | Manual `malloc`/`free` | **Eliminated** — slab allocator, no user-facing `free` |
| Format string attack | `printf` with user-controlled format | **Eliminated** — no `printf` |
| Null pointer dereference | `void*` arithmetic, implicit casts | **Eliminated** — no `void*` |
| Integer promotion overflow | Implicit type widening | **Eliminated** — single type (i64) |
| Double free | Manual memory management | **Eliminated** — slab fixed-size classes |

This is defense by absence. The attack surface does not exist because the language that creates it does not exist in the stack. The entire kernel (2,979 lines) is auditable by a single person in an afternoon. The Linux kernel (~30 million lines) is not auditable by anyone.

This does not mean AGNOS is bug-free — logic errors, race conditions, and design flaws remain possible. But the largest category of kernel vulnerabilities is eliminated at the language level.

### Prior Art

Other projects have attempted single-language operating systems. Each relies on an external toolchain somewhere in the chain:

| Project | Language | External Dependency |
|---------|----------|-------------------|
| Singularity (Microsoft) | C# | Bootloader in assembly, runtime in C++ |
| Redox | Rust | Compiler requires LLVM (C++) |
| MirageOS | OCaml | Runs on Xen hypervisor (C) |
| TempleOS | HolyC | Closest precedent — compiler bootstrapped from C |
| **AGNOS** | **Cyrius** | **None. 29KB seed → self-hosting compiler → kernel → init → tools** |

Every binary in the AGNOS stack is compiled by a compiler that compiled itself. The seed assembler is 29KB of hand-auditable machine code. No external language touches any production binary. This is, to our knowledge, the first fully sovereign single-language OS stack from assembly up.

---

## Comparison

| Metric | Project A (Anthropic) | Project B (Cyrius) |
|--------|----------------------|-------------------|
| Duration | ~2 weeks | 4 days |
| Agents | 16 parallel | 1 (3 sessions total) |
| Sessions | ~2,000 | 3 |
| Cost | ~$20,000 (API) | ~$400 (subscription) |
| Compiler | 100,000 lines Rust | 4,127 lines Cyrius (164KB binary) |
| Standard library | Rust stdlib | 21 modules, 3,099 lines |
| Developer tools | None reported | cyrb (20+ commands), formatter, linter, doc generator, auditor |
| Self-hosting | No | Yes — byte-exact |
| Self-compile | Not applicable | 11ms |
| Seed binary | ~200MB (rustc) | 29KB |
| External dependencies | Rust, LLVM, GCC, assembler, linker | Zero |
| Tests | GCC torture suite (99%) | 267 (0 failures) |
| Architectures | x86_64 | x86_64 + aarch64 (byte-identical on Raspberry Pi) |
| Kernel | Compiles Linux kernel | Compiles its own — 98KB, 27 subsystems, 25 syscalls |
| Kernel syscall | N/A | 178 cycles (5.6M/sec on QEMU) |
| Networking | Not demonstrated | IP/UDP, VirtIO-net, PCI bus scan |
| Lines of C in stack | 100,000 (Rust needs LLVM/GCC) | Zero |
| Seed → networked OS | Not applicable | 291KB total |
| DOOM | Compiles it | Runs it — and rewrites it smaller |

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

| Investment | Return | Evidence |
|------------|--------|----------|
| Reference library (vidya) | 10x implementation speed | Structs: hours. Pointers: minutes. |
| Tests | Early bug detection | 4 critical bugs caught invisibly |
| Benchmarks | Zero rebuild hesitation | 11ms self-compile |
| Tooling | Automated enforcement | `cyrb audit` → 10/10 |

The byte-exact self-hosting test verifies the entire compiler in a single comparison. If the output is identical, every codegen path is correct.

---

## Results

### Binary Size

Cyrius-compiled programs are 10–233x smaller than GNU coreutils equivalents:

```
Program      Cyrius      GNU        Ratio
true          168 B   39,144 B      233x
false         168 B   39,144 B      233x
echo          240 B   43,240 B      180x
yes           368 B   43,240 B      117x
head          600 B   51,432 B       85x
cat         4,536 B   47,368 B       10x
tee         4,584 B   47,336 B       10x
```

The difference: direct syscall emission, no libc, no dynamic linking, minimal ELF headers.

### Runtime Performance

After adding buffered I/O (one vidya-informed development cycle):

```
wc 1MB:   Cyrius 9ms,  GNU 22ms   (Cyrius 2.4x faster)
tr 1MB:   Cyrius 9ms   (previously 766ms — 85x improvement)
```

### Kernel

The AGNOS kernel (v1.1.0) is 98KB. It boots to an interactive shell in <100ms with:

- Ring 3 user mode, SYSCALL/SYSRET, per-process page tables
- PMM, VMM, slab heap allocator
- VFS, device drivers, initrd filesystem
- PCI bus scan, VirtIO-net driver, IP/UDP stack
- SMP infrastructure (LAPIC, IPI, AP trampoline)
- kybernet init (PID 1), 12 shell commands, 25 syscalls

The kernel has gotten smaller while gaining features — v1.0.0 was 106KB with 8 syscalls. Compiler improvements produce smaller output without changing kernel source.

Benchmarks (QEMU, ~1GHz emulated):

| Operation | Cycles | Throughput |
|-----------|--------|------------|
| Syscall (getpid) | 178 | 5.6M/sec |
| PMM alloc+free | 1,222 | 818K/sec |
| Heap 32B alloc+free | 1,187 | 843K/sec |
| VFS open+read+close | 5,374 | 186K/sec |
| Memory write 1MB | 5.6M total | 179 MB/s |

The 178-cycle getpid is within the range of Linux on native hardware (100-200 cycles) while running in QEMU emulation.

For comparison: Linux 0.01 (1991) was ~10,000 lines of C, ~62KB, needed GCC + libc + as + ld. No networking, no shell, no Ring 3.

### Toolchain

| Component | Size |
|-----------|------|
| Seed binary | 29KB |
| Compiler (v1.8.2) | 164KB |
| Kernel (v1.1.0) | 98KB |
| **Seed → networked OS** | **291KB** |

GCC: ~100MB. Clang/LLVM: ~500MB. The sovereign stack is 344x smaller than GCC.

Head-to-head Cyrius vs Rust benchmarks on real crate conversions: [Cyrius vs Rust Benchmarks](cyrius-vs-rust-benchmarks.md).

---

## Limitations

**Project B cannot compile C.** Porting existing C/Rust codebases requires rewriting in Cyrius. An automated tool (`cyrb port`) scaffolds projects, but the migration of 107 Rust repos (~1M lines) is ongoing.

**Project B's kernel is not Linux.** It lacks: full TCP (UDP only), disk drivers (initrd only), multi-user support, POSIX compatibility, and decades of driver support.

**Project A cannot self-host.** It depends on external toolchains but compiles real-world C codebases today.

**Cyrius has no borrow checker.** Memory safety comes from testing and auditing, not the type system. Ownership and borrow checking are planned for v1.3.

Both projects represent genuine engineering achievements with different trade-offs.

---

## Origin

This compiler exists because a package registry blocked a name. The question "why do we depend on their registry?" cascaded through the dependency chain until the only remaining dependency was an x86_64 processor and electricity.

---

## Cost

| | Project A | Project B |
|---|----------|----------|
| Spend | ~$20,000 (API) | ~$400 (subscription) |
| Ratio | 50x | 1x |
| Output | C compiler (capability demo) | Language + OS kernel (production infrastructure) |
| Future use | Repository artifact | Active compiler for 107-repo ecosystem |

The 50x cost difference reflects the difference between parallel brute-force and incremental, documentation-driven development.

---

## Further Reading

- [Cyrius vs Rust: Head-to-Head Benchmarks](cyrius-vs-rust-benchmarks.md) — detailed performance comparison on agnosys and kybernet crate conversions
- [The $2 SD Card: Open Knowledge and the Death of Access](the-2-dollar-sd-card.md) — what the compiler enables: sovereign knowledge distribution

---

## Credits

One developer and three Claude Opus 4.6 agent sessions:

| Role | Contribution |
|------|-------------|
| **Developer** (Robert MacCracken) | Architecture, decisions, steering. All design choices are human. |
| **Agent 1 — Meta** | Documentation, roadmaps, ecosystem standards. No compiler or kernel code. |
| **Agent 2 — Language** | Cyrius from seed to v1.5: compiler, stdlib, tools, initial kernel boot, `cyrb port` migration tool, vidya documentation. |
| **Agent 3 — Kernel** | Kernel from initial boot to 98KB networked OS (v1.1.0): Ring 3, VFS, networking, SMP, 25 syscalls, 188-cycle getpid, shell. |

The developer held the vision. The agents held the context. The reference library accelerated all three. The AI is a tool, not an author. But the tool deserves acknowledgment.

---

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
