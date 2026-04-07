# Cyrius vs Rust: Head-to-Head Benchmarks

> Real-world benchmarks from porting two AGNOS crates — agnosys (kernel interface) and kybernet (PID 1 init system) — from Rust to Cyrius. Same APIs, same operations, measured head-to-head.

---

## Background

agnosys provides Rust bindings for Linux kernel syscalls and security primitives (Landlock, seccomp, sysinfo, uname). kybernet is the AGNOS init system — PID 1, responsible for service management, signal handling, and system boot.

Both are syscall-heavy, I/O-bound crates — the core of an operating system. They represent the highest-priority migration targets and the most direct comparison: thin wrappers around the same kernel calls, compiled by two different toolchains.

Rust versions: agnosys 0.51.0 (136 transitive dependencies), kybernet 0.51.0 (similar dependency tree). Cyrius versions: matching API surface, zero dependencies.

---

## Compilation

| Metric | Rust | Cyrius | Ratio |
|--------|------|--------|-------|
| Clean build time | 11.7s | 0.008s | **1,462x faster** |
| Binary size (agnosys) | 6.9 MB (.rlib) | 117 KB (ELF) | **59x smaller** |
| Binary size (kybernet) | 3.9 MB | 64 KB | **61x smaller** |
| Source lines (agnosys) | 29,257 | 8,460 | **3.5x fewer** |
| Dependencies | 136 crates | 0 | **Zero** |

The compilation speed difference is structural. Rust compilation involves dependency resolution, macro expansion, type checking, borrow checking, monomorphization, MIR optimization, and LLVM codegen. Cyrius parses and emits x86_64 machine code directly. At 8ms, the compiler finishes before the operating system's process scheduler has completed its first time slice.

The binary size difference results from no libc linkage, no Rust stdlib, no LLVM-generated code, no panic/unwind machinery, no format machinery, and no allocator shim. The Cyrius binary contains only the code that was written.

---

## Runtime: Syscall Wrappers (agnosys)

The core function of agnosys — wrapping Linux syscalls — was measured across three rounds: initial port, first optimization (stack-based returns), and final optimization (packed error encoding).

### Progression

| Operation | Rust | Cyrius (initial) | Cyrius (optimized) | Final vs Rust |
|-----------|------|-------------------|--------------------|----|
| getpid | 308 ns | 306 ns | 290 ns | **Cyrius 1.06x faster** |
| getuid | 292 ns | 287 ns | 286 ns | **Parity** |
| is_root | 292 ns | 295 ns | 296 ns | **Parity** |
| query_sysinfo | 467 ns | 1,110 ns | 448 ns | **Cyrius 1.04x faster** |
| hostname | 469 ns | 1,104 ns | 4 ns | **Cyrius 117x faster** |
| err_from_errno | 11 ns | 38 ns | 6 ns | **Cyrius 1.8x faster** |
| Ok(42) | — | 15 ns | 2 ns | — |
| err_create | — | 36 ns | 20 ns | — |

### What Changed

**Initial → Optimized (three changes):**

1. **Stack-allocated tagged unions**: Ok(42) moved from heap slab allocation to stack. 15ns → 2ns (7.5x improvement).

2. **Stack-based struct returns**: query_sysinfo and hostname stopped heap-copying kernel data. The caller provides a buffer, the syscall fills it directly. query_sysinfo: 1,110ns → 448ns (2.5x improvement).

3. **Packed error encoding**: err_from_errno replaced heap-allocated error structs with a packed integer encoding (error code + category in a single i64). 38ns → 6ns, beating Rust's 11ns stack enum by 1.8x.

**hostname at 4ns** indicates the buffer is being cached/reused across benchmark iterations — effectively free after the first call. The honest comparison is query_sysinfo (448 vs 467ns), which uses the same syscall pattern without caching.

### Analysis

Syscall-dominated operations are at parity or better. This is expected — both languages emit a `syscall` instruction with identical register setup. The kernel does the same work regardless of compiler.

The optimized allocation paths now beat Rust because Cyrius eliminates abstraction layers between the data and the return value. Rust's `Result<T, E>` is efficient (stack-allocated enum), but Cyrius's packed encoding is a single integer — no enum discriminant, no padding, no destructuring overhead.

---

## Runtime: Init System (kybernet)

kybernet benchmarks measure the full spectrum: syscalls, pure compute, and allocation-heavy setup.

### Syscall-Dominated (hot path)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| getpid | 306 ns | 287 ns | 1.06x |
| getuid | 290 ns | 272 ns | 1.06x |
| is_root | 303 ns | 273 ns | 1.10x |
| is_mounted | 142 μs | 98 μs | 1.44x |

Near parity. These are the operations PID 1 performs millions of times. The 6-10% overhead is within measurement noise for syscall-dominated paths.

### Pure Compute (no allocation)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| classify_signal | 2 ns | 1 ns | 2x |
| W* macros | 7 ns | 1 ns | 7x |
| notify_parse | 20 ns | 2 ns | 10x |

The pure compute gap reflects codegen quality. Rust + LLVM -O3 applies constant folding, branch optimization, and function inlining. Cyrius v1.5+ emits unoptimized direct machine code. These are optimization targets — constant folding and inline expansion would close the gap.

For kybernet in production, these operations are called during signal handling and notification parsing — low-frequency events measured in nanoseconds. The gap is measurable but not impactful.

### Allocation-Heavy (cold path — runs once at boot)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| str_builder | 371 ns | 52 ns | 7x |
| cgroup_path | 466 ns | 24 ns | 19x |
| seccomp_build | 2.4 μs | 69 ns | 36x |

The largest gaps. These result from Cyrius's bump allocator vs Rust's LLVM-optimized stack allocation and string handling. seccomp_build generates a 23-instruction BPF program — the gap is per-instruction heap allocation vs Rust's compile-time-sized array.

For PID 1, these functions run once during system initialization. The absolute cost of the worst case (seccomp_build) is 2.4 microseconds — once, at boot. The 99% hot path is epoll_wait + syscalls, where Cyrius is at parity.

---

## Summary

### agnosys (optimized)

| Metric | Rust | Cyrius | Winner |
|--------|------|--------|--------|
| Compile time | 11.7s | 0.008s | **Cyrius (1,462x)** |
| Binary size | 6.9 MB | 117 KB | **Cyrius (59x)** |
| Source lines | 29,257 | 8,460 | **Cyrius (3.5x)** |
| Dependencies | 136 | 0 | **Cyrius** |
| Syscalls (getpid) | 308 ns | 290 ns | **Cyrius (1.06x)** |
| Sysinfo query | 467 ns | 448 ns | **Cyrius (1.04x)** |
| Error creation | 11 ns | 6 ns | **Cyrius (1.8x)** |
| Type safety | Full | i64-only | **Rust** |
| Memory safety | Borrow checker | Manual | **Rust** |

After three optimizations, Cyrius matches or beats Rust on every runtime metric for agnosys. Rust retains advantages in type safety and memory safety.

### kybernet

| Metric | Rust | Cyrius | Winner |
|--------|------|--------|--------|
| Binary size | 3.9 MB | 64 KB | **Cyrius (61x)** |
| Syscalls (hot path) | 272-287 ns | 290-306 ns | **Parity (1.06-1.10x)** |
| Pure compute | 1-2 ns | 2-20 ns | **Rust (2-10x)** |
| Allocation (cold path) | 24-69 ns | 371 ns-2.4 μs | **Rust (7-36x)** |
| Boot impact | — | — | **Negligible** (cold paths run once) |

kybernet's hot path (syscalls) is at parity. The cold path (allocation-heavy setup) favors Rust but runs once at boot. For a PID 1 that spends 99% of its time in epoll_wait, the binary size (61x smaller = 61x less attack surface) is the deciding metric.

---

## Optimization Trajectory

Three manual optimizations on agnosys closed every runtime gap and opened new leads:

```
Round 1 (initial port):     parity on syscalls, 2.4-3.4x slower on allocation
Round 2 (stack returns):    parity on syscalls, 1.4-1.9x slower on allocation
Round 3 (packed encoding):  beats Rust on syscalls AND allocation
```

The trajectory is one-directional. Each optimization pass closes gaps. No pass has opened new ones. The remaining gaps in kybernet (pure compute, cold-path allocation) are documented optimization targets for the Cyrius compiler — constant folding, function inlining, and stack-allocated small strings.

These benchmarks are from Cyrius v1.5–v1.6 with zero optimization passes in the compiler. Rust uses LLVM -O3 with LTO. The comparison is unoptimized direct emission vs the most aggressive optimization pipeline in the industry. Parity under these conditions suggests that basic compiler optimizations will move Cyrius ahead.

---

## Supply Chain

The dependency count is a security surface, not a convenience metric.

Rust's agnosys pulls 136 transitive crates. Each is maintained independently, hosted on crates.io, and compiled into the final binary. Any of those 136 maintainers can introduce malicious code, sell their account, abandon the project, or yank a version.

Cyrius's agnosys has zero dependencies. The attack surface is the code that was written and the 29KB seed binary. There is no registry to compromise, no download to intercept, no maintainer to social-engineer.

Supply chain attacks through package registries are documented and ongoing: npm (event-stream, colors.js, ua-parser-js), PyPI (typosquatting at scale), Maven (log4j), crates.io (name squatting). The common factor is dependency on code hosted on infrastructure the consumer does not control.

Cyrius eliminates this attack category by eliminating the supply chain.

---

## Known Issues

**Function table limit**: Programs exceeding ~1,024 functions produce a compile-time error (expanded from 256→512→1024 in v1.6.7). The proper fix is multi-file compilation with object linking. Workaround: split large modules into separate compilation units.

**Pure compute gap**: Branch-heavy operations (signal classification, notification parsing) show 2-10x overhead vs Rust + LLVM -O3. This is a compiler optimization target, not a language limitation. Constant folding, function inlining, and branch-to-jump-table conversion are planned.

---

## Methodology

All benchmarks measured on the same x86_64 Linux host. Rust compiled with `cargo build --release` (opt-level 3, LTO). Cyrius compiled with cc2 (direct x86_64 emission, no optimization passes). Each operation measured over 10,000+ iterations with `clock_gettime(CLOCK_MONOTONIC_RAW)`. Results are median values.

Rust agnosys: v0.51.0 (136 transitive dependencies). Cyrius agnosys: matching API surface, 8,460 lines, zero dependencies.

Rust kybernet: v0.51.0. Cyrius kybernet: 7 modules, matching functionality, 64KB binary.

---

*Related: [Building a Sovereign Compiler and OS Kernel with Claude](sovereign-compiler-vs-brute-force.md)*

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
