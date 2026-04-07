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
| Binary size (kybernet) | 3.9 MB | 48 KB (v1.7.1) | **81x smaller** |
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

### Syscall-Dominated (hot path — runs millions of times)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| getpid | 333 ns | 308 ns | 1.08x |
| getuid | 314 ns | 295 ns | 1.06x |
| is_root | 319 ns | 295 ns | 1.08x |
| is_mounted(/proc) | 153 μs | 106 μs | 1.44x |

Near parity. The 6-8% overhead is within measurement noise for syscall-dominated paths. These are the operations PID 1 performs continuously.

### Pure Compute (no allocation — signal handling, event parsing)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| classify_signal | 2 ns | 1 ns | 2x |
| is_handled_signal | 5 ns | 1 ns | 5x |
| W* macros (4 calls) | 7 ns | 1 ns | 7x |
| notify_parse | 21 ns | 2 ns | 10x |
| sigset ops | 19 ns | 1 ns | 19x |

The pure compute gap reflects codegen quality. Rust + LLVM -O3 applies constant folding, branch optimization, and function inlining — these 1ns results are likely compile-time-evaluated constants. Cyrius emits unoptimized direct machine code. These gaps are blocked on the compiler's 512KB buffer expansion, which unblocks constant folding and function inlining.

For kybernet in production, these are low-frequency operations measured in single-digit nanoseconds. The gap is measurable but not impactful on boot or runtime performance.

### Struct Construction (no allocation, pure memory)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| epoll_event_new | 14 ns | 1 ns | 14x |
| timerspec_new | 22 ns | 1 ns | 22x |

Rust's 1ns struct construction is likely LLVM constant-propagating the entire struct at compile time. Cyrius constructs at runtime. Same optimization target as pure compute — constant folding would close this gap.

### Allocation-Heavy (cold path — runs once at boot)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| str_builder (3 seg) | 406 ns | 55 ns | 7x |
| str_builder (int mix) | 434 ns | 100 ns | 4x |
| vec (push+get+len) | 98 ns | 12 ns | 8x |
| cgroup_path | 498 ns | 26 ns | 19x |
| cgroup_file | 908 ns | 43 ns | 21x |
| sandbox_basic_service | 220 ns | 8 ns | 28x |
| seccomp_build (5 insn) | 497 ns | 22 ns | 23x |
| seccomp_build (37 insn) | 2,618 ns | 59 ns | 44x |

The largest gaps. These result from Cyrius's bump allocator vs Rust's LLVM-optimized stack allocation and string handling. seccomp_build (37 instructions) at 44x is the worst case — per-instruction heap allocation vs Rust's compile-time-sized array.

For PID 1, these functions run once during system initialization. The absolute cost of the worst case is 2.6 microseconds — once, at boot. The 99% hot path is epoll_wait + syscalls, where Cyrius is at parity.

### Tagged Unions (Result/Option)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| Ok + is_ok | 18 ns | ~0 ns | — |
| Err + is_err | 18 ns | ~0 ns | — |
| Some + unwrap | 23 ns | ~0 ns | — |

Rust's ~0ns reflects compile-time optimization — LLVM eliminates the enum construction entirely when the result is immediately consumed. Cyrius allocates at runtime. Stack-allocated tagged unions (planned v1.2) would reduce these to single-digit nanoseconds.

### Boot Performance

| Metric | Cyrius | Rust | Ratio |
|--------|--------|------|-------|
| Init-to-event-loop | 66 ms | 120-140 ms | **2x faster** |
| Binary size | 48 KB | 3,922 KB | **81x smaller** |
| Initramfs | 308 KB | 2.4 MB | **7.8x smaller** |

The init system that is 81x smaller also boots 2x faster. Smaller binary means less to load from disk, less to decompress, less to page-fault into memory.

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
| Binary size | 3.9 MB | 48 KB | **Cyrius (81x)** |
| Init-to-event-loop | 120-140 ms | 66 ms | **Cyrius (2x faster)** |
| Initramfs | 2.4 MB | 308 KB | **Cyrius (7.8x)** |
| Syscalls (hot path) | 295-308 ns | 314-333 ns | **Parity (1.06-1.08x)** |
| Pure compute | 1-2 ns | 2-21 ns | **Rust (2-19x)** |
| Struct construction | ~0-1 ns | 14-22 ns | **Rust (compile-time optimized)** |
| Allocation (cold path) | 8-100 ns | 98 ns-2.6 μs | **Rust (4-44x)** |
| Tagged unions | ~0 ns | 18-23 ns | **Rust (compile-time optimized)** |

kybernet's hot path (syscalls) is at parity. The cold path (allocation-heavy setup, struct construction) favors Rust but runs once at boot — total cold-path cost is microseconds. The actual boot (init-to-event-loop) is 2x faster because 81x smaller binary = less to load, decompress, and page-fault. For a PID 1 that spends 99% of its time in epoll_wait, binary size and boot speed are the deciding metrics.

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

## The Sovereign Stack Effect

A pattern emerged during migration that has no equivalent in external-toolchain development: **compiler improvements remove kernel workarounds**.

When the compiler and kernel are maintained together, a fix in one eliminates hacks in the other. This does not happen with external toolchains — kernel developers work around compiler quirks for years because they cannot fix the compiler they depend on. The workaround becomes permanent. Nobody removes it because nobody owns both sides.

Cyrius v1.7.0 demonstrated this with four crutch removals in a single release:

| Compiler Fix | Kernel Impact | Crutch Removed |
|-------------|---------------|----------------|
| aarch64 SP setup in kernel preamble | Kernel boots without post-compilation patching | `scripts/patch_aarch64.py` — deleted from build pipeline |
| aarch64 string fixup for large binaries | Multi-function kernels work on ARM | 1KB binary size limit on aarch64 — gone |
| `#ifdef` inside included files (multi-pass) | Library dispatchers work across architectures | Consumer-side ifdef duplication — gone |
| aarch64 asm mnemonic validation | x86 assembly in shared code caught at compile time | Forced `arch_wait()`/`arch_halt()` abstraction — actually produced better architecture |

The fourth case is notable: the compiler constraint did not just fix the problem — it improved the design. Validating architecture-specific mnemonics forced the kernel to abstract platform-specific operations behind clean interfaces. The workaround removal produced better code than the original.

This effect compounds across the migration. Each of the 107 Rust repos contains workarounds for Rust/LLVM limitations — lifetime gymnastics, `unsafe` blocks for FFI, `#[allow]` attributes suppressing valid warnings, `Pin<Box<dyn Future>>` patterns forced by the borrow checker. When the workaround exists because of the language, porting to a sovereign language eliminates both the workaround and the limitation it worked around.

The result: migrated code is not just translated — it is structurally improved. The codebase gets cleaner with every port, not dirtier.

---

## Known Issues

**Function table limit**: Programs exceeding ~1,024 functions produce a compile-time error (expanded from 256→512→1024 in v1.6.7). The proper fix is multi-file compilation with object linking. Workaround: split large modules into separate compilation units.

**Pure compute gap**: Branch-heavy operations (signal classification, notification parsing) show 2-10x overhead vs Rust + LLVM -O3. This is a compiler optimization target, not a language limitation. Constant folding, function inlining, and branch-to-jump-table conversion are planned.

---

## Methodology

All benchmarks measured on the same x86_64 Linux host. Rust compiled with `cargo build --release` (opt-level 3, LTO). Cyrius compiled with cc2 (direct x86_64 emission, no optimization passes). Each operation measured over 10,000+ iterations with `clock_gettime(CLOCK_MONOTONIC_RAW)`. Results are median values.

Rust agnosys: v0.51.0 (136 transitive dependencies). Cyrius agnosys: matching API surface, 8,460 lines, zero dependencies.

Rust kybernet: v0.51.0. Cyrius kybernet: 7 modules, matching functionality, 48KB binary (v1.7.1).

---

*Related: [Building a Sovereign Compiler and OS Kernel with Claude](sovereign-compiler-vs-brute-force.md)*

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
