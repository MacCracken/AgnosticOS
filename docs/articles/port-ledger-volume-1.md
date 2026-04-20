# Port Ledger Volume 1

> Every claim has a receipt. Ten production crates ported from Rust to Cyrius, each one with the Rust side preserved as a git tag and the benchmarks preserved as a CSV. Anyone can clone the repos, check out the Rust tag, run the benches, then switch to Cyrius main and re-run.
>
> The language turned seventeen days old the week these receipts were frozen. It has not yet had its first optimization sprint. Read these numbers with that in mind — and then read the forward trajectory, because the gaps we show are enumerated, scheduled, and already known to the compiler team.

---

## The Rule

Before a port ships:

1. **Freeze the Rust side.** Final Rust commit gets tagged `rust-final-v<N>` in that repo.
2. **Export the benchmarks.** Every Rust bench gets re-run on the same x86_64 host, results committed as `docs/rust-v<N>-bench-history.csv`.
3. **Record the shape.** Line counts, dependency counts, test counts, fuzz harness counts at the freeze point go into a `port-receipts.md`.
4. **Port, then measure.** Cyrius implementation lands, benchmarks re-run, new CSV committed as `bench-history.csv`.
5. **Ship receipts.** Both CSVs stay in the repo. Forever.

The rule exists because "trust me, it got faster" isn't a receipt. A git tag + a CSV is.

---

## The State of the Language

- **Cyrius v5.5.4** — self-hosting from a 29KB assembly seed, zero external dependencies, bootstrap chain of four items (CPU → seed → compiler → output)
- **Age:** 17 days old when Volume 1 was cut. First commit 2026-04-03. Kernel solid 2026-04-04 23:16 PDT (44 hours in)
- **Platforms:** x86_64 Linux byte-identical self-host; aarch64 Linux byte-identical on real Pi hardware (v5.3.15+); Apple Silicon Mach-O byte-identical self-host on M-series (v5.3.13); Windows PE32+ Win64 ABI call-site complete on real Windows 11 (v5.5.4)
- **Optimization arc:** not yet run. v5.6.x (O1–O6) is the dedicated minor that closes the remaining compute gaps.

The ledger below is the state before the first optimization sprint. That is the relevant framing.

---

## Volume 1 — The Ports

Ten ports with full receipts preserved. Deep-dives for the earliest four live in [`cyrius-vs-rust-benchmarks.md`](cyrius-vs-rust-benchmarks.md) — this article is the wide view.

### 1. agnosys — kernel interface

| | Rust v0.51.0 | Cyrius v1.0.0 |
|--|--------------|---------------|
| Binary | 6.9 MB | **117 KB** (59× smaller) |
| Lines | 29,257 | **8,460** (3.5× fewer) |
| Deps | 136 transitive | **0** |
| Compile | 11.7s | **8ms** (1,462× faster) |
| Syscall hot paths | baseline | **at parity or better** |

Packed error encoding (i64 = code + category) beats Rust's `Result<T, E>` stack enum on `err_from_errno` by 1.8×. Syscall-bound operations match because the kernel does identical work.

### 2. kybernet — PID 1 init system

| | Rust v0.51.0 | Cyrius v1.0.1 |
|--|--------------|---------------|
| Binary | 6.7 MB | **486 KB** (14× smaller) |
| Tests | — | 140 |
| Benchmarks | — | 46 |
| `is_mounted` | baseline | **1,583× faster** |
| Boot (init → event loop) | 120–140 ms | ~80 ms (~1.5–2× faster) |

The 486 KB binary is production — 140 tests, 46 benches, full feature surface. The ratio holds after production: small binary, fast boot, ready for real PID 1 duty.

### 3. agnostik — shared domain types

Agent IDs, trace contexts, sandbox configs, inference requests, audit entries. Cyrius wins **6 of 9** domain-object benchmarks. The three Rust wins are string serialization via serde (highly optimized) and multi-collection `sandbox_config` (hashmaps + vectors + sub-objects). Every integration benchmark — the real-world objects that flow through the runtime — Cyrius wins.

### 4. abaco — math / DSP / number theory

| | Rust baseline | Cyrius v2.1.0 |
|--|---------------|---------------|
| Lines | 5,932 | **2,856** (−52%) |
| Assertions | 283 | **452** (+60%) |
| Fuzz harnesses | — | **3** |
| Security fixes in-port | — | **3 High / 3 Medium / 2 Low** |
| Miller-Rabin (end-to-end) | baseline | **~12× faster** (after `u64_mulmod` fast-path) |

**The closed-loop story.** Initial port showed a 32× gap on `is_prime_large`: Cyrius used 64-addition `mod_mul` emulation, Rust used native 128-bit multiply. Abaco **requested** a hardware `u64_mulmod` primitive from Cyrius. Cyrius **shipped it** in v4.8.5. Abaco **re-measured**: Miller-Rabin end-to-end ~12× faster than the original port. No other young language has a documented example of a port driving a compiler feature specification and then measuring the feature after landing. This is the canonical entry in the ledger.

### 5. hoosh — LLM inference gateway

| | Rust | Cyrius v2.0.0 |
|--|------|---------------|
| Binary | 5.1 MB | **474 KB** (10.8× smaller) |
| Lines | 22,956 | **1,361** (16.9× fewer) |
| Deps | 40 crates | **0** |
| Compile | 15s | **216 ms** (70× faster) |
| Providers | 15 | 15 (parity) |

16.9× fewer lines for a 15-provider LLM gateway. The Rust side carried the accumulated weight of async runtime + serde + tower + reqwest + tokio + tracing stacks. Cyrius's stdlib has the HTTP server + WS absorbed natively (v4.5.0), so the gateway is just the gateway.

### 6. ai-hwaccel — GPU detection

| | Rust | Cyrius v2.0.0 |
|--|------|---------------|
| Binary | 708 KB | **217 KB** (3.3× smaller) |
| Deps | 131 crates | **0** |
| Tests | — | 518 |
| Fuzz harnesses | — | 6 |
| Benchmarks | — | 20 |

131 transitive dependencies collapsed to zero. The device-enumeration paths (PCI for x86, device-tree for aarch64) are direct syscall code — no `libudev`, no `sysfs` crate, no RAII wrapper over a C FFI.

### 7. avatara — divine archetype overlay

| | Rust | Cyrius v2.3.0 |
|--|------|---------------|
| Cached access | baseline | **2,761× faster** |
| Lookup | baseline | **53× faster** |
| Tests | — | 195 |
| Benchmarks | — | 39 |

2,761× on cached access isn't a compiler trick — it's a data-structure rethink that became possible once the code left serde's reach. The Rust version marshaled via `serde_json` on every access; Cyrius stores the resolved struct directly and the cache hit is a pointer read.

### 8. kavach — sandbox execution

| | Rust v2.0.0 | Cyrius v3.0.0 |
|--|-------------|---------------|
| Binary | 2.4 MB | **344 KB** (−86%) |
| Lines | 25,935 | **5,775** (−77%) |
| Deps | 448 crates | **1** (sigil) |
| Compile | 45s | **0.64s** (70× faster) |
| `sandbox_full_lifecycle` | 3.06 ms | **6 µs** (500× faster) |
| Security fixes in-port | — | **9 CWE-class findings** |

448 crates → 1 (sigil for crypto). Sandbox full lifecycle — create, configure, drop privileges, execute, tear down — drops from 3 ms to 6 µs. For a sandbox that fires on every agent tool call, this is the difference between a 10% overhead and a rounding error.

### 9. ark — package manager

| | Rust | Cyrius v0.8.0 |
|--|------|---------------|
| Binary | 2.1 MB | **532 KB** (4× smaller) |
| Compile | 4.2s | **<0.1s** (40× faster) |
| `output_render` | baseline | **5.2× faster** |
| `txn_lifecycle` | baseline | **2.1× faster** |
| `cmd_create` | baseline | Rust 4× faster |
| `recent_10` | baseline | Rust 8× faster |

**Ark is where "no hiding" matters most.** The full operation paths — render output, transaction lifecycle — Cyrius wins 2–5×. The micro-op paths — command construction, recent-10 lookup — Rust wins 4–8× via zero-copy borrows. The reason is direct and nameable: Rust's `&str` slicing avoids allocation entirely on single-value hot paths; Cyrius's bump allocator + `str_builder` wins when the path allocates + formats + frees, but loses when the path barely touches memory at all.

That gap does not close with more benchmarks. It closes with v5.6.x O1 (peephole) and O3 (IR-driven dead-store elimination) landing constant-folding for the zero-copy pattern so Cyrius emits the same single instruction Rust does.

### 10. nous — package resolver

Cyrius v1.1.1 stable. Ported to Cyrius-native resolution after ark; shipped production alongside ark as the package manager + resolver pair. Port was structural cleanup — the algorithms stayed, the ecosystem stack dropped.

---

## Patterns

### Dep collapse is structural, not a trick

hoosh 40 → 0. ai-hwaccel 131 → 0. kavach 448 → 1. These are not curated "we dropped the optional features" numbers — they are *transitive dependency graphs for a working production binary*. Cyrius's stdlib is zero-dep by construction, so everything that would have been pulled in as a crate is just code in the project.

The significance isn't benchmark ratios. It's **attack surface**. Every Rust crate is a supply-chain node that can be compromised, malicious-typo'd, or version-drift-broken. Going from 448 to 1 isn't a performance win — it's a security posture change.

### Line reductions are rethinks, not compressions

22,956 → 1,361 on hoosh. 25,935 → 5,775 on kavach. 5,932 → 2,856 on abaco. These are not line-golf. They reflect:

- Rust's derive macros expanding to code you don't see in the source but the compiler sees everywhere
- Error-handling ceremony (`Result<T, E>` wrapping, `?` propagation, `From` impls) that Cyrius handles via packed error encoding
- Async runtime boilerplate that vanishes when the HTTP server is stdlib
- Generic explosion + monomorphization that doesn't need explicit generics at Cyrius's abstraction layer

### Security fixes happen **in-port**

kavach 9 CWE-class findings. abaco 8 findings (3 High, 3 Medium, 2 Low). libro an entire layout-corruption class found during port. These are not "we audited separately" — porting forces a re-read of every line, in a language that doesn't hide control flow behind trait dispatch. Bugs that hid behind three layers of `impl Trait` come out.

### Closed-loop compiler feedback

The abaco → `u64_mulmod` → abaco cycle is not an isolated event. Every port's "what I missed" list becomes Cyrius roadmap signal. kavach votes for generics + pattern-match + exhaustiveness. Multiple ports vote for better codegen on small-string hot paths. The compiler's backlog is not "what we think users want" — it's the concrete list of "what shipping ports asked for."

No other young language has this loop at scale. Most young languages validate against toy programs or a single flagship. The ledger is ten working, tested, benchmarked production codebases all feeding the same compiler.

---

## Where Rust Still Wins — No Hiding

Four categories, all of them enumerated and scheduled:

**1. Zero-copy micro-ops** — `&str` slicing avoids allocation on single-value hot paths. Cyrius's bump allocator + `str_builder` wins when the path allocates + formats + frees, but loses when the path barely touches memory. Examples: ark `cmd_create` 4×, ark `recent_10` 8×, agnostik `sandbox_config` 37×, kybernet `vec_push_get_len` 8×, kybernet `seccomp_build` 44×.
**Closes with v5.6.1 (O2 peephole) + v5.6.2 (O3 IR-driven passes).**

**2. Constant folding on pure compute** — Rust's LLVM -O3 evaluates `classify_signal` (2 ns), `notify_parse` (2 ns), and `sigset` ops (1 ns) at *compile time* because the inputs are literals in the benchmark. Cyrius computes them at runtime. The 2–19× gaps on these benchmarks are not runtime differences — they are "Rust runs the benchmark in the compiler, Cyrius runs it in the CPU."
**Closes with v5.6.0 (O1 instrumentation + constant-folding pass) + v5.6.2.**

**3. Inlining on sub-nanosecond DSP** — LLVM inlines entire scalar DSP functions at -O3; Cyrius currently emits a call through the benchmark harness. The "300–700× gap" on abaco DSP scalar ops is almost entirely the call overhead. The batch numbers (`sanitize_4096` 4.4×, `poly_blep` 9.6×) show the real gap without SIMD.
**Closes with v5.6.3 (O4 linear-scan regalloc) + v5.6.4 (O5 maximal-munch instruction selection).**

**4. serde string serialization** — Rust's serde is the most-optimized serialization path in any systems language. Cyrius currently emits general-purpose string code for the same work. agnostik shows 5.8–6.8× gaps on string roundtrip.
**Closes with targeted stdlib work + v5.6.2.**

These are not excuses. They are a backlog with patch numbers.

---

## The Sprint That Runs Out in Front

Cyrius v5.6.x is the dedicated compiler-optimization arc. Six phases, each with its own patch number:

| Phase | What it does |
|-------|--------------|
| **v5.6.0** (O1) | Instrumentation + FNV-1a symbol table — baseline measurement before optimizing |
| **v5.6.1** (O2) | Peephole quick wins (x86_64 + aarch64) |
| **v5.6.2** (O3) | IR-driven passes: constant folding, dead-store elimination, common subexpression elimination |
| **v5.6.3** (O4) | Linear-scan register allocation (Poletto-Sarkar) |
| **v5.6.4** (O5) | Maximal-munch instruction selection (per-target tiles) |
| **v5.6.5** (O6) | Slab allocator for IR pools (measurement-gated; skippable if O4 benchmarks say bump is fine) |

The arc closes the four gaps above by construction. It also does something Rust cannot: **every new Cyrius port shipped after v5.6.x inherits these optimizations automatically, on the same compiler that's 482 KB and still bootstraps from 29 KB of assembly.** Rust's LLVM is a 20-year codebase of millions of lines. The Cyrius compiler fits in a browser tab.

After v5.6.x: RISC-V rv64 (v5.7.0), then bare-metal / AGNOS kernel target (v5.8.0) — surface Rust cannot reach without shelling out to external toolchains.

The ledger in Volume 1 shows a young language at near-parity or ahead after seventeen days and zero compiler optimization. The sprint that runs it out in front is scheduled, named, and on disk.

---

## What Comes Next

The ledger is a three-volume arc, then an epilogue:

- **Volume 1 — early (this).** Under twenty ports, pre-v5.6.x optimization. The baseline.
- **Volume 2 — mid (55–70 ports).** Post-v5.6.x re-measurements written into the ledger next to the Volume 1 originals, plus the mid-era ports (bhava, takumi, aegis, aethersafha, and the ecosystem crates whose receipts weren't formalized in time for Volume 1), **plus the AGNOS kernel re-write.** The v1.22 kernel — 260 KB, 33 subsystems, 26 syscalls — gets frozen and benchmarked, then the re-write ships with the full before/after on the ledger. This is where the four enumerated gaps above either close or don't, *and* where the kernel's specific re-architecture wins get measured end-to-end.
- **Volume 3 — end.** Full ecosystem ledger. Every port with a Rust antecedent closed and measured. Native subsystems (hadara, takumi, aegis, aethersafha if they land native-first) documented alongside.
- **Epilogue — where we are.** Retrospective. What the three volumes prove about the category. Where the gaps are that Rust still holds. Where Cyrius has pulled into territory Rust cannot reach without external toolchains (RISC-V, bare-metal, self-hosting from 29 KB). The synthesis of the syntheses.

Receipts pending for the near cut:
- **bhava** (emotion/sentiment) — Rust side exists, port queued
- **takumi** (build system) — 0.1.0 scaffold, port will be native-first
- **aegis** (security daemon) — 0.1.0 scaffold
- **aethersafha** (Wayland compositor) — 0.1.0 scaffold; the biggest port on the schedule

---

## Audit Instructions

Everything in this article is reproducible on commodity hardware.

```sh
# Pick any port. Example: kavach.
git clone https://github.com/MacCracken/kavach.git
cd kavach

# Check out the Rust side at the freeze point
git checkout rust-final-v2.0.0
cat docs/rust-v2.0-bench-history.csv

# Run the Rust benches
cargo bench --release

# Switch to Cyrius main, run current benches
git checkout main
cyrius bench

# Compare the two CSVs
diff docs/rust-v2.0-bench-history.csv bench-history.csv
```

The ledger is the code. The numbers are the receipts. Volume 2 ships when the sprint closes.

---

*Robert 'Cyrius' B. MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
