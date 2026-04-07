# Cyrius vs Rust: Head-to-Head Benchmarks

> Real-world benchmarks from porting three AGNOS crates — agnosys (kernel interface), kybernet (PID 1 init system), and agnostik (shared domain types) — from Rust to Cyrius. Same APIs, same operations, measured head-to-head.

---

## Background

agnosys provides Rust bindings for Linux kernel syscalls and security primitives (Landlock, seccomp, sysinfo, uname). kybernet is the AGNOS init system — PID 1, responsible for service management, signal handling, and system boot. agnostik is the shared types crate — domain primitives (agent IDs, trace contexts, sandbox configs, inference requests, audit entries) that every AGNOS subsystem depends on.

These three crates span the full spectrum: syscall-heavy I/O (agnosys), system orchestration (kybernet), and domain object construction and serialization (agnostik). Together they represent the core of the operating system.

Rust versions: agnosys 0.51.0 (136 transitive dependencies), kybernet 0.51.0 (similar dependency tree), agnostik 0.90.0 (10 feature gates). Cyrius versions: agnosys 0.90.0, matching API surface, zero dependencies.

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

### agnostik

| Metric | Rust | Cyrius | Winner |
|--------|------|--------|--------|
| Struct construction (agent_id) | 45 ns | 30 ns | **Cyrius (1.5x)** |
| Struct construction (trace_context_child) | 53 ns | 40 ns | **Cyrius (1.3x)** |
| Struct construction (trace_context_new) | 94 ns | 89 ns | **Cyrius (1.1x)** |
| Integration (inference_request) | 573 ns | 507 ns | **Cyrius (1.1x)** |
| Integration (audit_entry) | 1,004 ns | 754 ns | **Cyrius (1.3x)** |
| Integration (accelerator_device) | 711 ns | 141 ns | **Cyrius (5x)** |
| String serialization (agent_id) | 46 ns | 314 ns | **Rust (6.8x)** |
| String roundtrip (agent_id) | 106 ns | 613 ns | **Rust (5.8x)** |
| Multi-collection (sandbox_config) | 40 ns | 1,480 ns | **Rust (37x)** |

agnostik is the shared types crate — the domain primitives that every AGNOS subsystem depends on. Cyrius beats Rust on 6 of 9 comparable benchmarks. The three Rust wins are string serialization (serde is highly optimized for formatting) and multi-collection construction (sandbox_config creates hashmaps + vectors + sub-objects — arena allocator territory).

The Tier 3 integration benchmarks — the real-world objects that flow through the system at runtime (inference requests, audit entries, device descriptors) — Cyrius wins all three. The operations that dominate production throughput are already faster.

### abaco

| Metric | Rust | Cyrius | Winner |
|--------|------|--------|--------|
| factor_large (1234567890) | 2,920 ns | 3,000 ns | **Parity (1.03x)** |
| factor_small (360) | 71 ns | 534 ns | **Rust (7.5x)** |
| binomial (60,30) | 82 ns | 549 ns | **Rust (6.7x)** |
| totient (1000000) | 50 ns | 456 ns | **Rust (9.1x)** |
| is_prime_small (104729) | 914 ns | 17,000 ns | **Rust (18.6x)** |
| is_prime_large (999999999989) | 3,159 ns | 103,000 ns | **Rust (32.6x)** |
| next_prime (1000000) | 1,340 ns | 24,000 ns | **Rust (17.9x)** |
| fibonacci (92) | 14 ns | 583 ns | **Rust (41.6x)** |
| sanitize_4096 (batch) | 3,186 ns | 14,000 ns | **Rust (4.4x)** |
| poly_blep_4096 (batch) | 3,320 ns | 32,000 ns | **Rust (9.6x)** |
| DSP scalar ops | 0.6-1.6 ns | ~400 ns | **Rust (300-700x)** |

abaco is the first pure-compute benchmark — no syscalls, no I/O, no allocation patterns. Raw math and DSP against LLVM -O3. This is where Cyrius shows its current codegen ceiling and where specific compiler optimizations have the clearest targets.

**Three distinct gaps**:

**Near parity** — `factor_large` at 1.03x. Trial division with small divisors, same algorithm, same machine code, same speed. Proof that when the algorithm is identical and the operations are native, Cyrius matches LLVM.

**Algorithm gap (7-42x)** — Number theory operations dominated by `mod_mul`, which uses a binary method performing 64 additions per multiply because Cyrius has no u128 type. Rust uses native 128-bit multiplication in a single instruction. `fibonacci` at 41.6x reflects the same limitation — Rust uses fast-doubling with u128, Cyrius uses iterative i64. Adding u128 or mul-with-overflow to the compiler would collapse the is_prime gap to an estimated 2-3x.

**Inlining gap (300-700x)** — DSP scalar results are misleading. Rust's sub-nanosecond times mean LLVM inlined the entire function and is measuring a single already-computed instruction. Cyrius's ~400ns floor is the function call overhead through the benchmark harness — `bench_run` → `fncall0` → actual computation → return. The batch numbers (sanitize_4096 at 4.4x, poly_blep_4096 at 9.6x) are the honest comparison: Cyrius has no SIMD auto-vectorization and no cross-function inlining, but processes 4,096-sample audio buffers at usable rates. Cross-function inlining and SIMD are documented compiler optimization targets.

---

## Optimization Trajectory

Three manual optimizations on agnosys closed every runtime gap and opened new leads:

```
Round 1 (initial port):     parity on syscalls, 2.4-3.4x slower on allocation
Round 2 (stack returns):    parity on syscalls, 1.4-1.9x slower on allocation
Round 3 (packed encoding):  beats Rust on syscalls AND allocation
```

The trajectory is one-directional. Each optimization pass closes gaps. No pass has opened new ones. The remaining gaps in kybernet (pure compute, cold-path allocation) are documented optimization targets for the Cyrius compiler — constant folding, function inlining, and stack-allocated small strings.

The agnosys and kybernet benchmarks are from Cyrius v1.5–v1.6 with zero optimization passes. The agnostik benchmarks are from v1.7.7, which includes constant folding, tail call optimization, dead code elimination, and jump tables for dense switches. Rust uses LLVM -O3 with LTO across all comparisons.

The progression from v1.5 to v1.7.7 confirms the trajectory: each compiler optimization closes gaps without opening new ones. agnostik — benchmarked with the most mature compiler version — shows Cyrius winning 6 of 9 comparable benchmarks against LLVM -O3. The remaining gaps (string serialization, multi-collection construction) map to known optimization targets (stack-allocated small strings, arena allocator).

---

## Development Velocity

The benchmarks document performance. The release history documents something else: the speed at which a language can evolve when the developer and the compiler are in the same feedback loop.

Cyrius v1.7.0 through v1.7.8 shipped in hours, not weeks. Eight point releases in a single development stretch:

```
v1.7.0  DCE (dead code elimination)
v1.7.1  Compiler size stabilized at 131KB
v1.7.2  Tail call optimization, 512KB input buffer
v1.7.3  Constant folding (* / << >>)
v1.7.4  256 locals, && / || in expressions
v1.7.5  aarch64 tail calls, allocator regression fixed
v1.7.6  tok_names/struct_ftypes overlap fixed, all P1 bugs resolved
v1.7.7  Constant folding (+ - & | ^), jump tables for dense switches
v1.7.8  Self-hosting verified, both architectures
```

Each release was driven by a real port hitting a real limitation. Port agnosys — discover the allocator needs stack returns. Port kybernet — discover the pure compute gap needs constant folding. Port agnostik — discover the identifier buffer overlaps the struct table. The port is the test suite. The benchmark is the acceptance criteria. The fix ships in the same session.

This is the human/AI collaboration loop applied to language development. The human identifies the architectural need, steers the port, and reads the benchmarks. The AI holds the full compiler context — every codegen path, every memory layout, every optimization interaction — and implements at a speed that keeps pace with the discovery rate. The result is a language that evolves in hours at a pace that traditional language development measures in months.

GCC has mass. LLVM has mass. They are correct and complete and slow to change. Cyrius has no mass. A memory layout bug is found, diagnosed, fixed, self-hosted, and benchmarked before a traditional compiler team would finish triaging the issue. The 29KB seed is not just small in bytes — it is small in inertia.

The velocity is also a function of the migration source. AGNOS is not a greenfield project — it is 108 Rust repos totaling ~1M lines, with production APIs, real test suites, and real dependency trees. These are not toy programs: physics engines, math libraries, DSP primitives, audio/video codecs, cryptography, GPU acceleration, a Wayland compositor, kernel interfaces, security sandboxing, and build tooling. The kind of crates that engineers depend on for real infrastructure. Each port is a genuine stress test against code that was already working. This is why v1.7.x evolved so fast: the ports surface real compiler limitations, not synthetic ones.

The economic case compounds across the ecosystem. A single Rust crate like agnosys pulls 136 transitive dependencies. Multiply that across 108 repos and the disk footprint — `target/` directories, `.rlib` files, LLVM artifacts, duplicated dependencies compiled per-project — measures in gigabytes. The same ecosystem in Cyrius compiles in seconds, fits in megabytes, and shares zero transitive dependencies because there are none to share. The storage savings alone justify the migration before the performance numbers enter the conversation.

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
