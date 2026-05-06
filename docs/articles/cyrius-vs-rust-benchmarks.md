# Cyrius vs Rust: Head-to-Head Benchmarks

> Real-world benchmarks from porting AGNOS crates from Rust to Cyrius. Same APIs, same operations, measured head-to-head.

---

## Key Findings

- **3–59× smaller binaries** across 10 production ports — no libc, no LLVM, no stdlib, no panic machinery
- **40–1,462× faster compilation** — agnosys 11.7s → 8ms (1,462×), hoosh 15s → 216ms (70×), ark 4.2s → <0.1s (40×)
- **Runtime wins on full-operation paths** — avatara cached access 2,761× faster, kavach sandbox lifecycle 500× faster (3.06ms → 6µs), kybernet `is_mounted` 1,583× faster, abaco Miller-Rabin 12× faster end-to-end
- **Closed-loop compiler feedback** — abaco's Miller-Rabin bottleneck specified a Cyrius `u64_mulmod` hardware fast-path (shipped v4.8.5); abaco then re-measured 12× faster. Canonical downstream-drives-compiler example
- **Syscall hot paths at parity or better** — the kernel does identical work; Cyrius's packed error encoding beats Rust's `Result<T, E>` stack enum
- **SIMD 3.2× faster** on batch DSP — explicit SSE2 intrinsics beat LLVM auto-vectorization
- **Nuanced: Rust still wins on micro-ops** — zero-copy borrows (serde, `Vec::push`) beat bump + `str_builder` when the win is a single allocation; Cyrius wins wherever the hot path allocates + formats + frees

> **Language baseline (separate dataset):** the numbers below are real-world port receipts. For minimum-viable `exit42` binaries across Cyrius/Zig/C/Rust/Go on Linux ELF + Windows PE32+, see [cyrius/docs/size-comparisons.md](https://github.com/MacCracken/cyrius/blob/main/docs/size-comparisons.md). That table measures the floor — what every binary pays before running user code (Cyrius **152 B**, C stripped 14 KB, Rust stripped **345 KB**, Go stripped **1.4 MB**). The port wins below are savings on top of that floor.

---

## Crates Tested (deep-dive)

**agnosys** (kernel interface) — Rust bindings for Linux syscalls, Landlock, seccomp. Syscall-heavy I/O.
Rust v0.51.0 (136 transitive dependencies) vs Cyrius v0.90.0 (zero dependencies, now v1.0.0 stable).

**kybernet** (PID 1 init system) — service management, signal handling, system boot. Mix of syscalls, compute, and allocation.
Rust v0.51.0 vs Cyrius v1.0.1 (production, 486KB, 140 tests, 46 benchmarks).

**agnostik** (shared domain types) — agent IDs, trace contexts, sandbox configs, inference requests, audit entries. Object construction and serialization.
Rust v0.90.0 (10 feature gates) vs Cyrius v0.97.1.

**abaco** (math/DSP primitives) — number theory, DSP, SIMD. Pure compute against LLVM -O3.
Rust baseline vs Cyrius v2.1.0 (post-u128, post-`u64_mulmod` fast-path).

---

## Ports Ledger — 10 Production Ports

Full receipts (Rust tags + CSVs) preserved in each repo. This article deep-dives the first four; the rest are summarized here.

| Port | Role | Rust → Cyrius (size) | Compile | Headline result |
|------|------|----------------------|---------|-----------------|
| **agnosys** | Kernel interface | 6.9MB → 117KB (**59×**) | 11.7s → 8ms (**1,462×**) | Syscall hot paths at parity or better; stable 1.0.0 |
| **kybernet** | PID 1 init | 6.7MB → 486KB (**14×**) | — | Boot 2× faster; `is_mounted` **1,583× faster** |
| **agnostik** | Shared types | — | — | Cyrius wins 6/9 domain-object benchmarks |
| **abaco** | Math/DSP | — (lines −52%) | — | Miller-Rabin **12× end-to-end** via Cyrius `u64_mulmod` fast-path — canonical closed-loop port feedback |
| **hoosh** | LLM inference gateway | 5.1MB → 474KB (**10.8×**) | 15s → 216ms (**70×**) | 22,956 → 1,361 lines (**16.9×**); **40 crates → 0** |
| **ai-hwaccel** | GPU detection | 708KB → 217KB (**3.3×**) | — | **131 crates → 0**; 518 tests, 6 fuzz harnesses |
| **avatara** | Archetype overlay | — | — | **Cached access 2,761× faster**, lookup 53× faster |
| **kavach** | Sandbox execution | 2.4MB → 344KB (**7×**) | 45s → 0.64s (**70×**) | **Sandbox lifecycle 500× faster** (3.06ms → 6µs); **9 CWE fixes** in-port |
| **ark** | Package manager | 2.1MB → 532KB (**4×**) | 4.2s → <0.1s (**40×**) | Full op paths 2–5× faster; Rust wins micro-ops via zero-copy |
| **nous** | Package resolver | — | — | v1.1.1 stable, Cyrius-native resolution |

Dependency-count collapse is the structural story: **hoosh 40 → 0**, **ai-hwaccel 131 → 0**, **kavach 448 → 1**. These aren't compiler tricks — they're the result of writing in a language whose stdlib is zero-dep by construction.

---

## Compilation

| Metric | Rust | Cyrius | Ratio |
|--------|------|--------|-------|
| Clean build time | 11.7s | 0.008s | **1,462x faster** |
| Binary size (agnosys) | 6.9 MB | 117 KB | **59x smaller** |
| Binary size (kybernet) | 3.9 MB | 48 KB | **81x smaller** |
| Source lines (agnosys) | 29,257 | 8,460 | **3.5x fewer** |
| Dependencies | 136 crates | 0 | **Zero** |

The speed difference is structural: Rust involves dependency resolution, macro expansion, type checking, borrow checking, monomorphization, MIR optimization, and LLVM codegen. Cyrius parses and emits x86_64 machine code directly.

The size difference: no libc linkage, no Rust stdlib, no LLVM-generated code, no panic/unwind machinery. The binary contains only the code that was written.

---

## Runtime: agnosys (Syscall Wrappers)

After three optimization rounds (stack-allocated returns, packed error encoding):

| Operation | Rust | Cyrius | Winner |
|-----------|------|--------|--------|
| getpid | 308 ns | 290 ns | **Cyrius (1.06x)** |
| getuid | 292 ns | 286 ns | **Parity** |
| query_sysinfo | 467 ns | 448 ns | **Cyrius (1.04x)** |
| err_from_errno | 11 ns | 6 ns | **Cyrius (1.8x)** |

Syscall-dominated operations are at parity or better — both languages emit the same `syscall` instruction, and the kernel does identical work. Cyrius's packed error encoding (error code + category in a single i64) beats Rust's `Result<T, E>` stack enum.

---

## Runtime: kybernet (Init System)

### Hot path — syscalls (runs continuously)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| getpid | 333 ns | 308 ns | 1.08x |
| getuid | 314 ns | 295 ns | 1.06x |
| is_root | 319 ns | 295 ns | 1.08x |

Near parity. 6-8% overhead within measurement noise.

### Cold path — allocation-heavy setup (runs once at boot)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| str_builder (3 seg) | 406 ns | 55 ns | 7x |
| vec (push+get+len) | 98 ns | 12 ns | 8x |
| seccomp_build (37 insn) | 2,618 ns | 59 ns | 44x |

The largest gaps. Cyrius bump allocator vs Rust's LLVM-optimized stack allocation. The worst case (seccomp_build) costs 2.6 microseconds — once, at boot.

### Pure compute — branch-heavy (low-frequency operations)

| Operation | Cyrius | Rust | Ratio |
|-----------|--------|------|-------|
| classify_signal | 2 ns | 1 ns | 2x |
| notify_parse | 21 ns | 2 ns | 10x |
| sigset ops | 19 ns | 1 ns | 19x |

Rust's 1ns results are likely compile-time constants — LLVM constant-folds these at -O3. Cyrius computes at runtime. Constant folding and function inlining in the Cyrius compiler are the documented fix.

### Boot performance

| Metric | Cyrius (early port) | Cyrius (v1.0.1 production) | Rust | Ratio (production) |
|--------|--------------------|-----------------------------|------|--------------------|
| Init-to-event-loop | 66 ms | ~80 ms | 120-140 ms | **~1.5–2× faster** |
| Binary size | 48 KB | 486 KB | 6.7 MB | **14× smaller** |
| Initramfs | 308 KB | — | 2.4 MB | **7.8× smaller** |
| `is_mounted` | — | — | — | **1,583× faster** |

The 48 KB figure is the early-port prototype before the full feature surface (140 tests, 46 benchmarks) landed. The v1.0.1 production binary is 486 KB — still 14× smaller than the Rust equivalent. The init system boots in the same envelope regardless. For a PID 1 that spends 99% of its time in `epoll_wait`, binary size and boot speed remain the deciding metrics, and the ratio holds once production features are in.

---

## Runtime: agnostik (Domain Types)

| Metric | Rust | Cyrius | Winner |
|--------|------|--------|--------|
| agent_id construction | 45 ns | 30 ns | **Cyrius (1.5x)** |
| trace_context_child | 53 ns | 40 ns | **Cyrius (1.3x)** |
| inference_request | 573 ns | 507 ns | **Cyrius (1.1x)** |
| audit_entry | 1,004 ns | 754 ns | **Cyrius (1.3x)** |
| accelerator_device | 711 ns | 141 ns | **Cyrius (5x)** |
| String serialization | 46 ns | 314 ns | **Rust (6.8x)** |
| String roundtrip | 106 ns | 613 ns | **Rust (5.8x)** |
| sandbox_config (multi-collection) | 40 ns | 1,480 ns | **Rust (37x)** |

Cyrius wins 6 of 9 benchmarks. The three Rust wins are string serialization (serde is highly optimized) and multi-collection construction (hashmaps + vectors + sub-objects). The integration benchmarks — the real-world objects that flow through the system at runtime — Cyrius wins all three.

---

## Runtime: abaco (Pure Compute & DSP)

| Metric | Rust | Cyrius | Winner |
|--------|------|--------|--------|
| factor_large (1234567890) | 2,920 ns | 3,000 ns | **Parity (1.03x)** |
| factor_small (360) | 71 ns | 534 ns | **Rust (7.5x)** |
| is_prime_large | 3,159 ns | 103,000 ns | **Rust (32.6x)** |
| fibonacci (92) | 14 ns | 583 ns | **Rust (41.6x)** |
| DSP scalar ops | 0.6-1.6 ns | ~400 ns | **Rust (300-700x)** |
| **SIMD batch (4096 f64)** | **~3,200 ns** | **1,000 ns** | **Cyrius (3.2x)** |

Pure compute is where Cyrius showed its early codegen ceiling. Three distinct gaps — the first two have since closed:

**Near parity** — `factor_large` at 1.03×. Same algorithm, same machine code, same speed.

**Algorithm gap (7-42×) — closed.** Number theory originally used `mod_mul` with 64 additions per multiply because Cyrius had no u128 type. **u128 shipped in Cyrius v4.7–v4.8.x.** Abaco then specified a hardware `u64_mulmod` fast-path; **Cyrius v4.8.5 shipped it**. Abaco re-measured: **Miller-Rabin end-to-end ~12× faster** than the original Cyrius port. This is the canonical closed-loop example — a downstream port drove a compiler feature, the compiler shipped it, the port then measured the result. Benchmarks here predate that cycle; the newer abaco numbers live in `abaco/benches/` and the [port feedback loop memory](../../CLAUDE.md).

**Inlining gap (300-700×)** — DSP scalar sub-nanosecond times mean LLVM inlined the entire function. Cyrius ~400ns is function call overhead through the benchmark harness, not computation time. The batch numbers (`sanitize_4096` at 4.4×, `poly_blep` at 9.6×) reflect the real gap without SIMD. **Optimization arc shipped through v5.8.x** — O1 (FNV-1a hashing v5.6.0–v5.6.4), O2 (five peephole categories closed v5.6.11), O3a IR instrumentation (v5.6.12), linear-scan regalloc default-on (v5.6.20–v5.6.24), Phase O4a/b/c register-allocation incl. Poletto-Sarkar linear-scan picker (through v5.7.x and v5.8.x). O5/O6 codebuf compaction with NOP harvest is referenced through v5.8.x with status sweep pending in v5.9.x catchup arc.

**SIMD wins (3.2×)** — Explicit SSE2 intrinsics (`addpd`/`mulpd`/`subpd`) beat Rust's auto-vectorization on 4,096-element f64 arrays. Cyrius emits direct packed double instructions with no loop analysis overhead. Intent beats inference.

---

## Optimization Trajectory

Three manual optimizations on agnosys closed every runtime gap:

```
Round 1 (initial port):     parity on syscalls, 2.4-3.4x slower on allocation
Round 2 (stack returns):    parity on syscalls, 1.4-1.9x slower on allocation
Round 3 (packed encoding):  beats Rust on syscalls AND allocation
Round 4 (SIMD):             beats Rust 3.2x on batch DSP
```

The trajectory is one-directional — each pass closes gaps, none has opened new ones. The remaining gaps (pure compute, cold-path allocation) are documented compiler optimization targets: constant folding, function inlining, stack-allocated small strings.

### Compiler-side Phase O2 — closed 2026-04-23

The compiler-optimization arc (v5.6.x) that this article's *Known Limitations* section names landed its first two phases. **Phase O1** (instrumentation + FNV-1a symbol hashing) shipped v5.6.0–v5.6.4; **Phase O2** closed at v5.6.11 as five peephole categories on `cc5` itself:

| Category                                              | Shipped | x86 cc5       | aarch64 cc5   |
|-------------------------------------------------------|---------|---------------|---------------|
| 1. Partial strength reduction                         | v5.6.5  | -1,912 B      | mirrored      |
| 2. Flag-result reuse + `test rax, rax` elimination    | v5.6.8  | -2,416 B      | mirrored      |
| 3. Redundant push/pop elimination                     | v5.6.9  | -3,264 B      | mirrored      |
| 4. Commutative combine-shuttle elimination            | v5.6.10 | -2,648 B      | re-pinned     |
| 5. aarch64 combine-shuttle elimination (x86-backported)| v5.6.11 | unchanged     | **-17,672 B (-3.75%)** |

**Aggregate:** x86 `cc5` ~10 KB smaller across the phase; aarch64 `cc5` 471,360 → 453,688 B (-17,672 B, -3.75%) from the single v5.6.11 category alone — previously invisible because v5.6.10 declared aarch64 "had no shuttle" based on an incorrect reading of the backend.

**The engineering-methodology win underneath the numbers.** v5.6.11 was originally slotted for aarch64 fused ops (`madd`/`msub`/`ubfx`/`sbfx`). A **pre-implementation bytescan** on v5.6.10's `cc5_aarch64` showed 0 matches for every target pattern — Cyrius's combine codegen always shuttles intermediate values through the stack, so `mul` and consumer `add` are never adjacent in the emitted bytes. Fused ops require intermediates-in-registers, which requires linear-scan regalloc (v5.6.13). The fused-ops work was re-pinned to v5.6.14 before a single line was written; v5.6.11 shipped the combine-shuttle elim in its slot instead. The full roadmap cascaded v5.6.14 → v5.6.22.

The receipt is *"measure before implementing, not after."* A 0-match bytescan is a cheap artifact to produce — cheaper than a half-implemented feature that benchmark-neutral because its preconditions don't hold in the target binary.

---

## Known Limitations

**Pure compute gap**: Branch-heavy operations show 2–42× overhead vs LLVM -O3. The compiler-optimization arc (O1–O6) shipped continuously through v5.6.x → v5.7.x → v5.8.x. O1 (instrumentation + FNV-1a) v5.6.0–v5.6.4; O2 (five peephole categories) v5.6.11; O3a IR instrumentation v5.6.12; linear-scan regalloc default-on v5.6.20–v5.6.24; O4a/b/c regalloc + Poletto-Sarkar linear-scan picker through v5.7.x–v5.8.x. **O5/O6 codebuf compaction (NOP harvest with jump+fixup) is the remaining audit work, queued for v5.9.x catchup arc.** v5.10.x reserved for AGNOS bare-metal target + RISC-V rv64.

**No borrow checker**: Memory safety comes from testing, auditing, and a stdlib designed for the absence of hidden aliasing — not a type-system proof. Design stance, not a pending feature.

**Resolved since this article was first written:**
- ~~Function table limit (~1,024)~~ → raised to 4,096 in Cyrius v4.7.1
- ~~No u128 type~~ → shipped v4.7–v4.8.x
- ~~Number theory bottleneck on 64-bit `mod_mul`~~ → `u64_mulmod` hardware fast-path shipped v4.8.5; abaco's Miller-Rabin ~12× faster end-to-end

---

## Methodology

All benchmarks on the same x86_64 Linux host. Rust: `cargo build --release` (opt-level 3, LTO). Cyrius: `cc5` (direct x86_64 emission; `cc2` was the compiler at the time this article was first written — the bootstrap chain is now seed → cyrc → bridge → **cc5**). Each operation measured over 10,000+ iterations with `clock_gettime(CLOCK_MONOTONIC_RAW)`. Results are median values.

The deep-dive sections (agnosys, kybernet, agnostik, abaco) were measured during their respective initial ports. The Ports Ledger numbers are pulled from each repo's current `bench-history.csv` and are re-run per release. Receipts (Rust git tags + benchmark CSVs) are preserved in every ported repo so the comparison is reproducible.

---

*Related: [Building a Sovereign Compiler and OS Kernel with Claude](sovereign-compiler-vs-brute-force.md) | [Open Knowledge and the Death of Access](the-2-dollar-sd-card.md)*

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
