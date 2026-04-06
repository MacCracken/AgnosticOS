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

**Project B (AGNOS/Cyrius)** — One developer working with one Claude agent built a self-hosting systems language and operating system kernel over four days across three sessions, at a cost of ~$400 (two Max subscriptions — one for the compiler, one for the reference library that informed the methodology). The compiler is 136KB, self-hosts in 11ms from a 29KB seed binary, and has zero external dependencies. The kernel is 106KB with 27 subsystems including networking, process isolation, and an interactive shell.

**Motivation**: Project A was built as a capability demonstration. Project B was built out of necessity — the AGNOS operating system project encountered a crates.io name collision that blocked publishing a core crate, prompting the question of why the project depended on an external registry at all. Cyrius was the answer.

---

## Comparison

| Metric | Project A (Anthropic) | Project B (Cyrius) |
|--------|----------------------|-------------------|
| Duration | ~2 weeks | 4 days |
| Agents | 16 parallel | 1 (3 sessions total) |
| Sessions | ~2,000 | 3 |
| Cost | ~$20,000 (API) | ~$400 (subscription) |
| Compiler output | 100,000 lines Rust | 4,127 lines Cyrius (136KB binary) |
| Standard library | Rust stdlib | 21 modules, 3,099 lines (built from scratch) |
| Developer tools | None reported | cyrb build system (20+ commands), formatter, linter, doc generator, auditor |
| Self-hosting | No | Yes — byte-exact reproducibility |
| Self-compile time | Not applicable | 11ms |
| Seed binary | ~200MB (rustc) | 29KB |
| External dependencies | Rust, LLVM, GCC (16-bit), assembler, linker | Zero |
| Tests | GCC torture suite (99% pass) | 263 (0 failures) |
| Benchmarks | Not reported | 38 benchmarks, CSV regression tracking |
| Architectures | x86_64 | x86_64 + aarch64 (byte-identical self-hosting on Raspberry Pi) |
| Kernel | Compiles Linux kernel (external) | Compiles its own kernel — 106KB, 27 subsystems |
| Networking | Not demonstrated | IP/UDP stack, VirtIO-net driver, PCI bus scan |
| Total source | 100,000 lines | 14,849 lines (compiler + stdlib + programs + kernel) |

Project A has broader C compatibility. Project B has deeper sovereignty. These are different goals producing different architectures.

---

## Dependency Analysis

Project A's compiler is written in Rust. Building it requires a Rust toolchain (~200MB), which requires LLVM (~100MB), which requires a C++ compiler, which requires a C compiler, which requires libc. The compiler cannot build itself or the language it is written in.

Project B's compiler starts from a 29KB binary. From that seed, the full toolchain bootstraps in under 50ms. The compiler produces byte-identical output when compiling its own source. Removing Rust, GCC, LLVM, and libc from the system does not affect Project B's ability to build itself.

This distinction — **capability** versus **sovereignty** — is the central finding.

---

## Methodology: Incremental vs Parallel

**Project A** uses horizontal scaling: 16 agents working in parallel, synchronized through a shared git repository with lock files. Agents are assigned specializations (core compiler, code deduplication, performance optimization, architectural critique). Coordination overhead is managed through a "Ralph loop" harness and automated merge conflict resolution.

**Project B** uses vertical progression: each stage proves itself before the next begins.

```
Day 1:
  seed    → assembler (38 instructions, 102 tests)
  stage1a–1f → incremental capability addition
  stage1f → self-hosting compiler (bootstrap loop closed, byte-exact)

Day 2:
  cc2.cyr → modular compiler (7 modules)
            structs, pointers, inline asm, type annotations, buffered I/O
  kernel  → initial OS kernel (virtual memory, processes, syscalls)

Day 3:
  stdlib  → 21 modules (string, vec, hashmap, JSON, process, networking, etc.)
  tools   → cyrb, cyrfmt, cyrlint, cyrdoc, cyrc
  crates  → 5 Rust rewrites: agnostik, agnosys, kybernet, nous, ark
  aarch64 → cross-compiler, byte-identical self-hosting on Raspberry Pi

Day 4:
  kernel  → 106KB: Ring 3, memory isolation, VFS, initrd, IP/UDP, SMP-ready
            27 subsystems, 12 shell commands, 8 syscalls, kybernet init
  v1.0–v1.5 → closures, pattern matching, modules, traits, floats, operators
```

At every stage, the system compiles itself and produces verified output. No stage depends on functionality that has not been proven by the previous stage.

The parallel approach (Project A) scales throughput. The incremental approach (Project B) scales confidence — each layer is proven before the next is built on it.

---

## Binary Size

Cyrius-compiled programs are 10–233x smaller than their GNU coreutils equivalents:

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

The size difference results from direct syscall emission (no libc), no dynamic linking overhead, no locale or i18n support, and minimal ELF headers. These are not stripped or compressed — they are the raw compiler output.

---

## Runtime Performance

Initial benchmarks showed GNU `wc` outperforming Cyrius by 30% due to buffered I/O. After adding a buffered read layer (one development cycle, informed by the reference library):

```
wc 1MB:   Cyrius 9ms,  GNU 22ms   (Cyrius 2.4x faster)
tr 1MB:   Cyrius 9ms   (previously 766ms — 85x improvement from buffering)
```

The performance advantage comes from the same source as the size advantage: fewer abstraction layers between the program logic and the syscall interface.

---

## Kernel

The AGNOS kernel is a 106KB binary compiled by Cyrius. It boots to an interactive shell with 12 commands. Key capabilities:

- **Boot**: multiboot1, 32→64 bit shim, long mode
- **Hardware**: GDT, IDT, TSS, LAPIC, PIC, APIC timer, PS/2 keyboard (full QWERTY)
- **Memory**: PMM (bitmap), VMM, per-process page tables, slab heap allocator
- **Processes**: 16-slot table, context switching, round-robin scheduler
- **Isolation**: Ring 3 user mode, SYSCALL/SYSRET, separate address spaces
- **I/O**: VFS, device drivers, serial, keyboard
- **Storage**: initrd filesystem with name lookup
- **Network**: PCI bus scan, VirtIO-net driver, IP/UDP stack
- **SMP**: LAPIC, IPI primitives, AP trampoline infrastructure
- **Init**: kybernet (PID 1)
- **Shell**: help, echo, ps, free, cat, uptime, lspci, cpus, net, send, bench, halt

Source: 2,979 lines of Cyrius, 122 functions.

For comparison, Linux 0.01 (1991) was approximately 10,000 lines of C producing a ~62KB binary. It required GCC, libc, an assembler, and a linker. It had no networking, no interactive shell, and no user mode isolation.

### Kernel Benchmarks (QEMU, ~1GHz emulated)

| Operation | Cycles/op | Time | Throughput |
|-----------|-----------|------|------------|
| Syscall (getpid) | 306 | ~306ns | 3.3M/sec |
| PMM alloc+free | 2,041 | ~2μs | 490K/sec |
| Heap alloc+free | 2,565 | ~2.6μs | 390K/sec |
| Memory write 1MB | 10.9M total | ~10.9ms | 91 MB/s |

The 306-cycle syscall is measured in QEMU emulation. Linux getpid on native hardware is typically 100–200 cycles. The low cycle count reflects the minimal code path: read the PID from the process table and return. No namespace resolution, cgroup accounting, or security module hooks.

---

## The Vidya Effect

A pattern emerged that explains the development velocity.

AGNOS maintains **vidya** — a curated programming reference library (36 topics, 10 languages) containing best practices, gotchas, and performance notes. When the compiler needed pointer support, the development cycle was:

1. Research: 30 seconds (patterns already documented)
2. Implementation: 15 lines of code
3. Testing: 48/48 passed on first run
4. Total: minutes

Struct support, implemented before vidya had coverage for the relevant patterns, took hours due to a function table overflow, hex parsing edge cases, and dual-compiler capacity issues.

The variable was reference library coverage. The same developer, same agent, same compiler — structs without documentation took hours; pointers with documentation took minutes.

### Compounding Investments

| Investment | Return | Evidence |
|------------|--------|----------|
| Reference library (vidya) | 10x implementation speed | Structs (no coverage): hours. Pointers (covered): minutes. |
| Tests | Early bug detection | 4 critical bugs caught that would have been invisible (function table overflow, duplicate vars, hex parsing, brace imbalance) |
| Benchmarks | Elimination of rebuild hesitation | 11ms self-compile means the developer never hesitates to test a change |
| Tooling | Automated quality enforcement | `cyrb audit` runs 10 checks in one command |

The byte-exact self-hosting test is notable: if the compiler compiles itself and produces an identical binary, every codegen path, parser rule, and fixup is verified in a single comparison.

---

## Toolchain Size

| Component | Size |
|-----------|------|
| Seed binary | 29KB |
| Compiler (cc2) | 136KB |
| Kernel (AGNOS) | 106KB |
| **Seed → networked OS** | **271KB** |

For comparison: GCC is ~100MB installed. Clang/LLVM is ~500MB installed. The entire Cyrius stack from bootstrap seed to networked operating system with a shell is 271KB.

---

## Cost

| | Project A | Project B |
|---|----------|----------|
| Spend | ~$20,000 (API) | ~$400 (subscription) |
| Ratio | 50x | 1x |
| Output | C compiler (capability demo) | Systems language + OS kernel (production infrastructure) |
| Future use | Repository artifact | Active compiler for 107-repo OS ecosystem |

Project A consumed 2 billion input tokens and 140 million output tokens. Project B used standard subscription sessions. The 50x cost difference reflects the difference between parallel brute-force and incremental, documentation-driven development.

---

## Limitations and Honest Gaps

**Project B cannot compile C.** It compiles its own language. Porting existing C codebases requires rewriting them in Cyrius. An automated migration tool (`cyrb port`) scaffolds Cyrius projects from Rust repos, but the migration of 107 Rust repositories (~1M lines) is ongoing work.

**Project B's kernel is not Linux.** It has 27 subsystems but lacks: a full TCP stack (UDP only), disk drivers (initrd only), multi-user support, POSIX compatibility, and the decades of driver support that Linux provides.

**Project A cannot self-host.** It cannot compile the language it is written in, and depends on external toolchains. But it compiles real-world C codebases today, which Project B cannot.

Both projects represent genuine engineering achievements with different trade-offs.

---

## Origin

This compiler exists because a package registry blocked a name.

In early 2026, the AGNOS project attempted to publish its shared types crate to crates.io. The name was taken. Rather than rename the crate, the developer asked why the project depended on an external registry. That question cascaded through the dependency chain:

```
Registry dependency   → why depend on their registry?
Toolchain dependency  → why depend on their compiler?
Runtime dependency    → why depend on their libc?
```

Each question removed a dependency. The cascade produced a sovereign language, compiler, and operating system kernel with zero external dependencies. The entire stack bootstraps from a 29KB seed binary.

---

## Conclusion

Both projects demonstrate that AI-assisted compiler development is practical. The difference is in what they optimize for.

Project A optimizes for **capability** — what can the system compile? The answer: the Linux kernel and major open-source codebases. This is valuable and impressive.

Project B optimizes for **sovereignty** — what does the system depend on? The answer: 29 kilobytes. From that seed: a 136KB self-hosting compiler, 21 standard library modules, a 106KB operating system kernel with 27 subsystems, networking, process isolation, and an interactive shell. 271 kilobytes from void to networked OS. Built in four days.

Both approaches used the same model. The difference was the question.

---

## Credits

One developer and three Claude Opus 4.6 agent sessions, each with a distinct role:

| Role | Contribution |
|------|-------------|
| **Developer** (Robert MacCracken) | Architecture, decisions, steering. All design choices are human. |
| **Agent 1 — Meta** | Documentation, roadmaps, ecosystem standards. No compiler or kernel code. |
| **Agent 2 — Language** | Cyrius from seed to v1.5: compiler, stdlib, tools, initial kernel boot, `cyrb port` migration tool, vidya documentation. |
| **Agent 3 — Kernel** | Kernel from initial boot to 106KB networked OS: Ring 3, VFS, networking, SMP, shell. |

The developer held the vision. The agents held the context. The reference library (vidya) accelerated all three agents. The documentation standards shaped how all agents worked. The builder's corrections — "not yet," "defer that," "dig deeper" — kept the work pointed at what mattered.

The AI is a tool, not an author. But the tool deserves acknowledgment.

---

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
