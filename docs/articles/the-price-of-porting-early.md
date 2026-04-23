# The Price of Porting Early

> Porting a codebase to a young language isn't free. The price isn't paid in the port itself — it's paid in the re-ports that follow every language update. Most projects don't notice until the third or fourth cycle. The fix is sequencing: port what validates the language now, port what *ships on* the language later.

---

## The Pattern

A new systems language reaches v1.0. Its ecosystem is empty. The temptation is obvious: port an existing codebase to populate the ecosystem, validate the language, generate receipts.

This works — until the language ships v1.1. Then v2. Then v3. Each version adds features that change what idiomatic code looks like. Code written against v1.0 uses workarounds for features that landed at v1.5. Code written against v2.0 carries patterns that become unnecessary at v3.0.

**This isn't new.** Python 2 to Python 3 took roughly a decade for the ecosystem to settle — the tipping point didn't arrive until Python 3.5 in 2015, seven years after Python 3.0 shipped in 2008 ([Stack Overflow: Why is the Migration to Python 3 Taking So Long?](https://stackoverflow.blog/2019/11/14/why-is-the-migration-to-python-3-taking-so-long/)). Rust's async/await stabilization in late 2019 forced a full re-port wave across the ecosystem as `futures 0.1` gave way to `futures 0.3` + `std::future`, so disruptive the `futures` team shipped an explicit `.compat()` compatibility layer to let codebases migrate incrementally ([Rust futures-rs Compatibility Layer](https://rust-lang.github.io/futures-rs/blog/2019/04/18/compatibility-layer.html)). Swift broke compatibility across versions 1, 2, 3, and 4 — Xcode shipped automated migration assistants for five years straight because the alternative would have stalled the ecosystem, with ABI stability finally landing in Swift 5 (March 2019) and module stability deferred further to Swift 5.1 ([Swift.org: ABI Stability and More](https://www.swift.org/blog/abi-stability-and-more/)). Go's 2022 generics release redefined what idiomatic library code looked like, retiring years of `interface{}` gymnastics ([go.dev: An Introduction to Generics](https://go.dev/blog/intro-generics)). Zig is living through the same thing right now, pre-1.0, with the 0.15 "Writergate" I/O overhaul as the most recent breaking rewrite of its standard library ([devclass: Zig lead makes 'extremely breaking' change](https://devclass.com/2025/07/07/zig-lead-makes-extremely-breaking-change-to-std-io-ahead-of-async-and-awaits-return/)).

Every language jump creates **re-port pressure**. The port was technically complete. It's just no longer the idiomatic form, and the benchmarks no longer reflect what the language can actually do.

Re-port once, you've paid tuition. Re-port across the same codebase three or four times — which is what happens if you port everything on the "prove the language works" schedule — and the aggregate cost exceeds the original port.

Three touchstones explain why this happens and how to navigate it. Each reads differently depending on which side of the port you're standing on.

---

## Pillar 1 — Re-Port Pressure

### Language side

Every version is a liability for its dependents. A feature that lands at v1.5 makes every v1.0 port slightly stale — not broken, just *no longer the idiomatic form*. The language team has to weigh each improvement against the re-port churn it creates downstream.

Pre-optimization languages face this acutely. Rust shipped non-lexical lifetimes, const generics, GATs, async/await, and `impl Trait` over roughly a decade post-1.0 — each a reshaping of what library code should look like. Swift's first five years were a sequence of breaking releases with migration tooling bundled into the IDE because the alternative would have stalled the ecosystem. Go held firm on compatibility for a decade, then accepted a single scheduled churn event for generics in 2022. Zig's pre-1.0 period has been one standard-library rewrite after another. Every velocity win is a dependent's revisit.

### Ported project side

Every early port accepts an implicit contract: *"I'll revisit this when the language moves."* The port isn't finished the day it compiles and passes tests — it's only finished when the language stabilizes at its target form. Pre-stabilization ports are living documents.

Library maintainers in the Rust ecosystem between 2015 and 2019 did this explicitly: `tokio`, `hyper`, `serde` all went through multiple major-version rewrites to absorb language-level changes. The Python scientific stack (`NumPy`, `SciPy`, `matplotlib`, `Django`) spent years straddling 2/3 before committing. The Go community is currently absorbing whether and how to retrofit generics into established libraries — a discussion the Go team explicitly opened with the community ([golang/go discussion #48287 — How to update APIs for generics](https://github.com/golang/go/discussions/48287)). Anyone maintaining a pre-stabilization port treats revisit passes as recurring expense, not one-time cost.

---

## Pillar 2 — The Feedback Loop

Re-port pressure isn't purely cost. Every revisit is also a chance for the port to drive the language. That's the feedback loop, and it cuts both ways.

### Language side

Ports are the language's best beta-testers. A language designed in isolation has no way to prioritize features by actual need — the roadmap becomes a wish-list exercise. A language with downstream ports has its roadmap driven by *measured friction*.

Rust's RFC process exists for exactly this reason: library authors hit walls, wrote RFCs, and the compiler team prioritized features by ecosystem weight. The `?` operator came from error-handling pain in real libraries. Async/await landed as [RFC 2394](https://rust-lang.github.io/rfcs/2592-futures.html) after the `futures` crate's maintainers demonstrated the limits of combinator chains in production. Go's proposal system works the same way — generics shipped when the evidence from actual Go library code made `interface{}` + reflection untenable. Swift Evolution originates from the ecosystem, not from Apple alone.

The pattern: language matures through use, not committee. Every language that's stayed relevant has wired a feedback loop from ports back to the design.

### Ported project side

The port isn't just consuming the language — it's shaping it. Early porters have disproportionate influence over what the language becomes. The friction you report becomes v-next's feature list. That's agency late porters don't have.

It's also agency most library maintainers underuse. The Rust ecosystem has a well-known pattern where early-adopting library authors (`serde`, `tokio`, `rayon`) drove disproportionate amounts of language evolution through their measured pain. Their workloads authored the roadmap; later library authors inherited the result.

---

## Pillar 3 — System Ports vs Compute Ports

Not every port has the same relationship with the compiler. This is the variable that makes Pillars 1 and 2 actionable.

### Language side

Different workloads stress different parts of the compiler.

- **System workloads** stress the allocator, syscall ergonomics, error handling, I/O codegen. Structural wins here tend to be architectural, not optimizer-dependent. Rust's zero-cost abstractions, Go's goroutines + netpoller — these are language-design wins that hold across compiler versions.
- **Compute workloads** stress inlining, constant folding, auto-vectorization, regalloc, loop unrolling. This is where LLVM's decades of optimization tuning shows. A compiler that handles system code well may still need years of optimization work before reaching compute-code parity.

Rust is a live example of the asymmetry. It hit system-code parity with C quickly, but its HPC and numerical-computing story continues to evolve versus Fortran and hand-tuned C++. Julia went the other direction — strong on compute from day one (LLVM plus type specialization), weaker on system-level primitives. Language design has to know which phase it's in, and communicate that phase honestly.

### Ported project side

Your port's success depends on whether the language is ready for *your* workload class. An I/O-heavy system port against a pre-optimization codegen will report strong numbers if the language's structural wins are solid. A math-heavy compute port against the same compiler will report weak numbers — not because the port is bad, but because the compiler hasn't hit its optimization arc yet.

Choosing when to port means choosing which language version measures you. Rust's early numerical libraries (before `rustc`'s LLVM integration matured) published numbers that aged poorly; later numerical libraries walked into a sharper compiler and got stronger first receipts. Same port class, different language moment — different result.

---

## The Sequencing Rule

Given the three pillars, the rule synthesizes simply:

- **Port what's invariant to compiler optimization now.** Allocation patterns, syscall wrappers, error paths, I/O plumbing, protocol handling, init sequences. Structural wins here hold across versions — and system ports drive the feedback loop that matures the compiler.
- **Port what's dependent on compiler optimization later.** Pure compute, tight numeric kernels, SIMD hot paths — anything sensitive to inlining, constant folding, regalloc. Wait for the optimization arc before measuring.

**A major language team has already demonstrated this discipline.** When Go shipped generics in 1.18 (2022), the Go team explicitly chose *not* to update the standard library to use generics in the same release. New generic-enabled libraries for slices, maps, and channels were placed in `golang.org/x/exp` as truly experimental packages, so the API could be tested, iterated, and stabilized across multiple releases before landing in the main standard library ([golang/go issue #48918 — don't change the libraries in 1.18](https://github.com/golang/go/issues/48918)). The reasoning: *"it's too much to do all at once and they might get it wrong."* That's sequencing discipline applied by a team that understood exactly what re-port pressure looks like when the language moves faster than the libraries can re-idiomatize.

Porting a compute stack before the optimization arc lands is porting to a compiler that's about to get significantly better. Every benchmark published would need re-running. Every "language X is slower at Y" claim would become a historical artifact within months. Worse: the first impression for external engineers would be the weaker numbers, and you don't get to un-publish first impressions.

Waiting costs momentum. Publishing weak first-impression compute numbers costs the whole record.

The cheaper cost is the correct one to pay.

---

## Benefits and Drawbacks

This sequencing isn't free. Being honest about both sides:

### Benefits

- **Strongest-first receipts** — initial benchmarks reflect structural wins, not the pre-optimization compute gap. First impression is the best-case truth.
- **Avoided re-port debt** — compute code gets ported once, in the final idiom, against mature codegen.
- **Port efficiency** — writing against a mature language means fewer workarounds. Ports read like native code, not like someone talking around a missing feature.
- **Cleaner sequencing story** — "system stack shipped, compute stack scheduled for post-optimization" is a discipline claim with receipts. "Everything ported, half the numbers about to be re-measured" is a red flag to any reviewer.
- **Compiler feedback stays closed** — the loops that ran through the system-port wave have already landed their features. The next wave inherits the tuning.

### Drawbacks

- **Momentum cost** — a multi-month gap between system-port completion and compute-port start. External observers read "incomplete ecosystem," and the perception is real even when the sequencing is correct.
- **Dependency friction** — any system-level work that needs a compute primitive (numeric validation in crypto, stats in observability) ends up waiting or stubbing.
- **Narrative complexity** — "30+ ports shipped, 80+ pending, by design" requires context. The simpler story is easier to tell and easier to misunderstand the absence of.
- **Attention-window risk** — external interest cycles don't wait for compiler maturity. Languages have missed their moment waiting for the right release.
- **Psychological drag** — finishing system ports while staring at an unstarted compute backlog is demoralizing, even when the sequencing is correct.

### Net position

Every drawback above is *recoverable*. Momentum rebuilds. Attention windows come back. Narrative can be re-explained. Dependency friction can be worked around.

The drawback on the *other* side — publishing weak compute numbers that become the canonical first impression — is not recoverable. The first benchmark everyone quotes is the one that sticks; you don't get to un-publish it.

The trade is recoverable cost against unrecoverable cost. That's the whole argument.

---

## Case Study — AGNOS / Cyrius (2026)

AGNOS's Cyrius is a contemporary example of this sequencing applied deliberately. Cyrius shipped v1.0 on 2026-04-04. In the next 16 days it went through:

- **v4.7–v4.8.x** — u128 integer type
- **v4.8.5** — hardware `u64_mulmod` fast-path (12× speedup on number theory, requested by a downstream port)
- **v5.3.13** — Apple Silicon self-host byte-identical
- **v5.3.15+** — aarch64 byte-identical
- **v5.5.3–5.5.4** — Windows PE32+ with Win64 ABI, byte-identical cross-build
- **v5.5.10** — Windows native self-host byte-identical fixpoint
- **v5.6.x (in flight)** — optimization arc: constant folding, inlining, regalloc, peephole, maximal-munch
- **v5.7.0 (queued)** — RISC-V

That's the same shape Rust showed in its post-1.0 years, compressed into weeks. Any port written against v4.x codegen will re-measure differently once v5.6.x lands.

**The feedback loop in its complete form — abaco:**

1. The math/number-theory port (abaco) identified missing-feature friction: no u128, so Miller-Rabin did 64 additions per multiply, landing 32× slower than Rust on `is_prime_large`.
2. abaco specified the fix back to the compiler (hardware `u64_mulmod`).
3. Cyrius v4.8.5 shipped the instruction.
4. abaco re-measured — **~12× faster end-to-end on Miller-Rabin**, now beating Rust on the same workload.

The pre-fix abaco port was publishing a number that lasted days, not months. That's the feedback loop's cost. The 12× follow-up is its payback.

**The sequencing applied:**

- **System ports shipped now** (pre-optimization): kernel (v1.22.0), kybernet, hoosh, ark, nous, kavach, sigil, agnosys, argonaut, libro, shakti, phylax, bote, t-ron, daimon, agnoshi, itihas, sankoch, hisab, avatara, ai-hwaccel, hadara, shravan, mabda, abaco, bsp, cyrius-doom — 30+ ports, with Cyrius winning structurally on allocation, syscalls, I/O, and dep collapse even pre-optimization.
- **Compute ports scheduled later** (post-v5.6.x / v5.7.x): the 82-crate science stack. Deliberately waiting for the optimization arc to land so the first published numbers on compute workloads are competitive, not historical artifacts.

Same principle the Go team applied in 1.18. Same principle Rust library authors wish they'd applied more consistently in 2015–2019. Applied deliberately, with receipts, by a language project explicit about which phase it's in.

### The pattern at compressed timescale — owl and vyakarana (April 22–23)

The AGNOS case above runs the three pillars at weeks-scale. Two sibling projects running in the same window illustrate the same pattern at *hours-to-days* scale, which is a stronger claim that the rule generalizes.

**owl** — a Cyrius-native `cat` / `bat` replacement scaffolded and driven through M0 → M5 in three calendar days (2026-04-21 to 2026-04-23):

- M0: `owl --version` / `--help` binary
- M1: plain-mode `cat` parity (byte-for-byte identical to `cat` on the corpus)
- M2: TTY detection + line numbers + file headers
- M3a: language detection + theme scaffolding (token-level highlighting deferred to M3b)
- M4: pager spawn with `OWL_PAGER` / `PAGER` precedence
- M5: non-printables + tab expansion + wrap modes

owl's M3b (token highlighting) was held — not because it was hard, but because the grammar library didn't exist in the ecosystem. A pre-implementation survey (documented in owl's ROADMAP) found no port-ready grammar source anywhere in the AGNOS repos. M3b was pinned; the rest of owl shipped. This is **Pillar 1 (re-port pressure) at sprint-scale** — refuse to build against a non-existent dependency; defer the milestone instead.

**vyakarana** — the grammar library owl M3b was waiting on. Scaffolded 2026-04-23 with the **scaffold-ahead pattern** (see also [*Port Ledger Vol 1 → Scaffold-ahead*](port-ledger-volume-1.md#scaffold-ahead--lock-types-stub-runtime-ship-handoff)):

- v0.1.0 ships the Token layout, the ten-kind palette, the entry-point signature, and the `vyk` CLI shape. All runtime returns 0.
- A `HANDOFF.md` at the repo root names the frozen invariants, the M1 exit criteria, and the explicit non-goals.
- M1 (hand-coded shell tokenizer) landed in the same afternoon against a Cyrius compiler that rolled v5.6.0 → v5.6.13 in the same session.

What this demonstrates about the three pillars:

- **Pillar 1 (re-port pressure).** vyakarana pinned `cyrius = "5.6.0"` in its manifest while the compiler shipped six minor bumps underneath it. The pin is the forcing function: pick a version, commit to it, re-port forward on a schedule rather than chasing every patch. The owl and vyakarana pins are visible artifacts of the pressure, not abstractions.
- **Pillar 2 (feedback loop).** Closed inside a single day: vyakarana M1 exercised Cyrius's hand-coded byte-emit paths for a real non-compiler program; any issue found would have been an immediate Cyrius-side ticket. None surfaced. The loop ran; it just happened to close cleanly.
- **Pillar 3 (system vs compute sequencing).** Neither project is compute-heavy. Both are I/O-bound on kernel syscalls (reading files, writing stdout). Pillar 3 predicts they ship clean pre-optimization — and they did. Neither needed v5.6.x to produce honest first-day numbers.

The case matters because the three pillars were written against quarters and years of language evolution. A pair of day-scale case studies with receipts — compiler rolled 13 patches in 24 hours, library went scaffold → M1 in the same window, the pinning-and-re-porting discipline held throughout — is evidence that the pattern isn't an artifact of slow project timescales. It's the same pattern the Go team applied at 1.18 and Rust authors applied at 2017-2019, compressed into an afternoon.

---

## Prior Art

The pattern is well-documented across four decades of language evolution. Key reference points:

**Python 2 → 3** — the canonical decade-long ecosystem migration. Official porting guidance lives at [docs.python.org: How to port Python 2 Code to Python 3](https://docs.python.org/3/howto/pyporting.html), with the comprehensive third-party guide at [python3porting.com](http://python3porting.com/strategies.html). Stack Overflow's retrospective, [Why is the Migration to Python 3 Taking So Long?](https://stackoverflow.blog/2019/11/14/why-is-the-migration-to-python-3-taking-so-long/) (2019), is the best short read on why ecosystem migrations take longer than anyone plans for.

**Rust post-1.0 async/await** — the most recent large-scale re-port event in a major language. [Official compatibility-layer blog post](https://rust-lang.github.io/futures-rs/blog/2019/04/18/compatibility-layer.html) explains the `.compat()` shim that let large codebases migrate incrementally. The formal design is in [RFC 2394/2592 — Futures and async/await](https://rust-lang.github.io/rfcs/2592-futures.html). Practitioner experience reports: [Migrating a crate from futures 0.1 to 0.3](https://www.ncameron.org/blog/migrating-a-crate-from-futures-0-1-to-0-3/) (nick cameron) and [My experience porting old Rust Futures to async/await](https://medium.com/dwelo-r-d/my-experience-porting-old-rust-futures-to-async-await-744430e9c576) (Jeff Hiner, Dwelo R&D).

**Swift 1–5 and ABI stability** — four major breaking-change releases followed by formal stability in Swift 5 (2019). Official retrospective: [Swift.org: ABI Stability and More](https://www.swift.org/blog/abi-stability-and-more/). Library-evolution deep dive: [Swift.org: Library Evolution in Swift](https://www.swift.org/blog/library-evolution/) and the [Apple/Swift ABI Stability Manifesto](https://github.com/apple/swift/blob/main/docs/ABIStabilityManifesto.md). Practitioner migration guidance: [SwiftLee: Swift 5.0 migration](https://www.avanderlee.com/swift/updating-swift-5/).

**Go 1.18 generics** — single scheduled compatibility event (2022) that redefined idiomatic library code. The direct external validation of this article's sequencing discipline lives at [golang/go issue #48918 — don't change the libraries in 1.18](https://github.com/golang/go/issues/48918), where the Go team explicitly chose to hold standard-library updates outside the initial generics release. See also [An Introduction to Generics](https://go.dev/blog/intro-generics) (go.dev) and the community discussion [How to update APIs for generics](https://github.com/golang/go/discussions/48287).

**Zig pre-1.0 (ongoing)** — current live example of pre-stabilization language churn. The 0.15 "Writergate" I/O overhaul is the clearest recent artifact: [devclass: Zig lead makes 'extremely breaking' change to std.io](https://devclass.com/2025/07/07/zig-lead-makes-extremely-breaking-change-to-std-io-ahead-of-async-and-awaits-return/), [LWN: Zig version 0.15.1](https://lwn.net/Articles/1034583/), [official 0.15.1 release notes](https://ziglang.org/download/0.15.1/release-notes.html). Downstream migration impact: [ghostty: Zig 0.15 migration issue](https://github.com/ghostty-org/ghostty/issues/8361).

If you've written about this pattern or know canonical pieces on any of the above — or on earlier cases (C++ standard revisions, Node.js ecosystem migrations, Nim 1→2) — references welcome for future revisions.

---

## Why This Is a General Rule, Not an AGNOS Detail

Any sovereign-language effort that wants an ecosystem faces the same choice. Port everything early and collect re-port debt with every language update. Or sequence by port-type: validate with system ports, wait on compute ports, port each class when the language is ready for it.

Languages spend their first few years gathering an ecosystem through slow organic adoption — no port debt, but no ecosystem either. The port-bootstrapped approach collapses that wilderness into weeks. But it only works if the sequencing respects what the language actually *is* at each point.

Port too early, and the ecosystem you built is the work you'll redo. Port at the right point, and the ecosystem you built is the ecosystem you keep.

---

*Related: [Cyrius vs Rust: Head-to-Head Benchmarks](cyrius-vs-rust-benchmarks.md) | [Python in the Bootstrap](python-in-the-bootstrap.md) | [Building a Sovereign Compiler with Claude](sovereign-compiler-vs-brute-force.md)*

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
