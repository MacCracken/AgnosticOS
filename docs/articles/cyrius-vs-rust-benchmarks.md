# Cyrius vs Rust: Head-to-Head Benchmarks

> The first real-world comparison between Cyrius and Rust, measured on the same codebase: agnosys, the AGNOS kernel interface library.

---

## Background

agnosys provides safe Rust bindings for Linux kernel syscalls and security primitives (Landlock, seccomp, sysinfo, uname). It is one of the most syscall-heavy crates in the AGNOS ecosystem and a natural benchmark target — the core operations are thin wrappers around kernel calls, making it possible to isolate language overhead from application logic.

The Rust version (agnosys 0.51.0) is a published crate with 136 transitive dependencies. The Cyrius version was rewritten as part of the AGNOS crate migration. Both implement the same syscall interface.

---

## Compilation

| Metric | Rust | Cyrius | Ratio |
|--------|------|--------|-------|
| Clean build time | 11.7s | 0.008s | **1,462x faster** |
| Binary size (release) | 6.9 MB (.rlib) | 117 KB (ELF) | **59x smaller** |
| Source lines | 29,257 | 8,460 | **3.5x fewer** |
| Dependencies | 136 crates | 0 | **Zero** |

The compilation speed difference is structural: Rust compilation involves dependency resolution, macro expansion, type checking, borrow checking, monomorphization, MIR optimization, and LLVM codegen. Cyrius parses and emits x86_64 machine code directly. At 8ms, the compiler finishes before the operating system's process scheduler has completed its first time slice.

The binary size difference comes from the same source: no libc linkage, no Rust stdlib, no LLVM-generated code, no panic/unwind machinery, no format machinery, no allocator shim. The Cyrius binary contains only the code that was written.

The source line reduction (3.5x) reflects both language expressiveness and the absence of boilerplate that Rust requires for error handling, lifetime annotations, and trait implementations. The Cyrius version has no `use` imports, no `impl` blocks for standard traits, no lifetime parameters, and no `where` clauses.

---

## Runtime: Syscall Wrappers

The core function of agnosys — wrapping Linux syscalls — performs at parity:

| Operation | Rust (ns/op) | Cyrius (ns/op) | Ratio |
|-----------|-------------|----------------|-------|
| getpid | 308 | 306 | 1.01x (parity) |
| getuid | 292 | 287 | 1.02x (parity) |
| is_root | 292 | 295 | 0.99x (parity) |

This is expected. Both languages emit a `syscall` instruction with register setup. The kernel does the same work regardless of which compiler produced the calling code. The ~300ns measurement is dominated by the kernel-mode transition, not userspace code.

The 11ns overhead of a wrapped syscall versus a raw syscall in Cyrius (306 vs 295ns) represents one function call — argument passing and return value propagation.

---

## Runtime: Allocation-Heavy Operations

Operations involving heap allocation show Rust's advantage:

| Operation | Rust (ns/op) | Cyrius (ns/op) | Ratio | Explanation |
|-----------|-------------|----------------|-------|-------------|
| from_errno | 11 | 38 | Rust 3.4x faster | Rust uses stack-allocated enums. Cyrius heap-allocates tagged unions. |
| query_sysinfo | 467 | 1,110 | Rust 2.4x faster | Cyrius does an extra heap copy to escape the stack frame. |
| hostname | 469 | 1,104 | Rust 2.4x faster | Same pattern — uname syscall + heap copy overhead. |

The error creation gap (11ns vs 38ns) is a known architectural difference. Rust's `Result<T, E>` is a stack-allocated enum with zero heap allocation. Cyrius's tagged unions currently heap-allocate via the slab allocator. This is an optimization target — stack-allocated tagged unions would close the gap.

The sysinfo/hostname gap (2.4x) results from Cyrius copying the kernel-provided struct from the stack to the heap to return it. Rust returns the struct by value on the stack. This is also an optimization target — return-by-value semantics would eliminate the copy.

---

## Runtime: Cyrius-Specific Operations

Operations with no Rust equivalent, measured in isolation:

| Operation | Cyrius (ns/op) | Notes |
|-----------|----------------|-------|
| getpid (raw syscall) | 295 | Bare `syscall` instruction overhead |
| streq (16 chars) | 80 | Byte-by-byte string comparison |
| syscall_name_to_nr | 399 | Linear search through name table |
| err_create (heap) | 36 | Slab alloc + 3 field stores |
| Ok(42) | 15 | Tagged union allocation |
| create_seccomp_filter | 888 | 23-instruction BPF program generation |

The 15ns tagged union creation (Ok(42)) and 36ns error creation demonstrate that the heap allocator is efficient — the slab allocator pops from a free list and zeroes the requested bytes.

The 888ns seccomp filter generation is notable: producing a 23-instruction BPF program in under 1μs means runtime security policy generation is practical in Cyrius.

---

## Summary

| Metric | Rust | Cyrius | Winner |
|--------|------|--------|--------|
| Compile (clean) | 11.7s | 0.008s | **Cyrius (1,462x)** |
| Binary size | 6.9 MB | 117 KB | **Cyrius (59x)** |
| Source lines | 29,257 | 8,460 | **Cyrius (3.5x)** |
| Dependencies | 136 crates | 0 | **Cyrius** |
| Syscall performance | 308 ns | 306 ns | **Tie** |
| Error creation | 11 ns | 38 ns | **Rust (3.4x)** |
| Sysinfo query | 467 ns | 1,110 ns | **Rust (2.4x)** |
| Type safety | Full | i64-only | **Rust** |
| Memory safety | Borrow checker | Manual | **Rust** |

Cyrius wins decisively on toolchain metrics: compile speed, binary size, dependency count, and source conciseness. Rust wins on allocation-heavy code paths and safety guarantees. Pure syscall wrapping — the core function of agnosys — is at parity.

---

## Implications

The agnosys benchmark validates the migration thesis for syscall-heavy, I/O-bound code: Cyrius produces equivalent runtime performance in a fraction of the binary size with zero dependencies and near-instant compilation.

The allocation gap is a known optimization target, not a fundamental limitation. Stack-allocated tagged unions and return-by-value semantics are planned for Cyrius v1.2–v1.3.

The safety gap is acknowledged. Cyrius currently has no type enforcement beyond optional annotations and no borrow checker. These are planned for v1.3 (ownership) and v1.4 (full type system). Until then, the byte-exact self-hosting test and the 263-test suite provide correctness verification through testing rather than through the type system.

For the AGNOS migration (107 Rust repos, ~1M lines), these results suggest:
- **Syscall wrappers, I/O code, CLI tools**: migrate now — performance at parity, massive toolchain wins
- **Allocation-heavy library internals**: migrate after stack-allocated unions (v1.2)
- **Safety-critical code (crypto, sandbox)**: migrate after ownership/borrow checker (v1.3)

---

## Supply Chain

The dependency count is not a convenience metric. It is a security surface.

Rust's agnosys pulls 136 transitive crates. Each crate is maintained by an independent developer or team, hosted on crates.io, downloaded over HTTPS, and compiled into the final binary. Any one of those 136 maintainers can introduce malicious code, sell their account, abandon the project, change the license, or yank a version. The build's integrity depends on the continued good behavior of 136 independent parties.

Cyrius's agnosys has zero dependencies. The attack surface is the code that was written and the 29KB seed binary that can be audited by a single person in an afternoon. There is no registry to compromise, no download to intercept, no maintainer to social-engineer.

This is not a theoretical concern. Supply chain attacks through package registries are documented and ongoing: npm (event-stream, colors.js, ua-parser-js), PyPI (typosquatting at scale), Maven (log4j), and crates.io (name squatting). The common factor in every case is a dependency on code hosted on infrastructure the consumer does not control.

Cyrius eliminates this category of attack by eliminating the supply chain.

---

## Known Issues

**Function table limit**: Programs defining more than ~256 functions experience runtime segfaults due to function fixup table overflow. This blocks single-unit compilation of large modules. Workaround: split into separate compilation units or inline benchmark logic. This is a P1 bug on the Cyrius roadmap.

---

## Methodology

All benchmarks measured on the same x86_64 Linux host. Rust compiled with `cargo build --release` (opt-level 3, LTO). Cyrius compiled with `cc2` (direct x86_64 emission, no optimization passes). Each operation measured over 10,000+ iterations with `clock_gettime(CLOCK_MONOTONIC_RAW)`. Results are median values.

Rust agnosys version: 0.51.0 (136 transitive dependencies). Cyrius agnosys version: matching API surface, 8,460 lines, zero dependencies.

---

*Related: [Building a Sovereign Compiler and OS Kernel with Claude](sovereign-compiler-vs-brute-force.md)*

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
