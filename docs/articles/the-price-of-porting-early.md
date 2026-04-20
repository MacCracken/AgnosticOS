# The Price of Porting Early

> Porting a codebase to a young language isn't free. The price isn't paid in the port itself — it's paid in the re-ports that follow every language update. Most projects don't notice until the third or fourth cycle. The fix is sequencing: port what validates the language now, port what *ships on* the language later.

---

## The Pattern

A new systems language reaches v1.0. Its ecosystem is empty. The temptation is obvious: port an existing codebase to populate the ecosystem, validate the language, generate receipts.

This works — until the language ships v1.1. Then v2. Then v3. Each version adds features that change what idiomatic code looks like. Code written against v1.0 uses workarounds for features that landed at v1.5. Code written against v2.0 carries patterns that become unnecessary at v3.0.

Every language jump creates **re-port pressure**. The port was technically complete. It's just no longer the idiomatic form, and the benchmarks no longer reflect what the language can actually do.

Re-port once, you've paid tuition. Re-port across the same codebase three or four times — which is what happens if you port everything on the "prove the language works" schedule — and the aggregate cost exceeds the original port.

Three touchstones explain why this happens and how to navigate it. Each one reads differently depending on which side of the port you're standing on.

---

## Pillar 1 — Re-Port Pressure

### Language side

Every version is a liability for its dependents. A feature that lands at v1.5 makes every v1.0 port slightly stale — not broken, just *no longer the idiomatic form*. The language team has to weigh each improvement against the re-port churn it creates downstream. Pre-optimization languages face this acutely: the first 18 months are when most foundational features land, which is exactly when the most ports are already written against earlier versions. Every velocity win is a dependent's revisit.

### Ported project side

Every early port accepts an implicit contract: *"I'll revisit this when the language moves."* The port isn't finished the day it compiles and passes tests — it's only finished when the language stabilizes at its target form. Pre-stabilization ports are living documents. Anyone maintaining one has to treat revisit passes as a recurring expense, not a one-time cost.

### Evidence — 16 days of Cyrius velocity

Cyrius shipped v1.0 on 2026-04-04. In the next 16 days:

- **v4.7–v4.8.x** — u128 integer type (Miller-Rabin had been using 64 additions per multiply)
- **v4.8.5** — hardware `u64_mulmod` fast-path (abaco-requested; 12× speedup on number theory)
- **v5.3.13** — Apple Silicon self-host byte-identical
- **v5.3.15+** — aarch64 (Raspberry Pi) byte-identical
- **v5.5.3–5.5.4** — Windows PE32+ with Win64 ABI, byte-identical cross-build
- **v5.5.10** — Windows native self-host byte-identical fixpoint
- **v5.6.x (in flight)** — optimization arc: constant folding, inlining, regalloc, peephole, maximal-munch
- **v5.7.0 (queued)** — RISC-V

Any port written against v4.x codegen will re-measure differently once v5.6.x lands. Not because the port is wrong — because the compiler got better. A port pinned to v4.0 for its numbers is publishing stale receipts the moment v5.7.x ships.

---

## Pillar 2 — The Feedback Loop

Re-port pressure isn't purely cost. Every revisit is also a chance for the port to drive the language. That's the feedback loop, and it cuts both ways.

### Language side

Ports are the language's best beta-testers. A language designed in isolation has no way to prioritize features by actual need — the roadmap becomes a wish-list exercise. A language with downstream ports has its roadmap driven by *measured friction*. When abaco hit 32× slower than Rust on Miller-Rabin, that wasn't a preference — it was a measurement with a specific fix spec'd to the compiler. Cyrius shipped `u64_mulmod` at v4.8.5 *because* abaco specified it. Every port's "what I wished was different" becomes the compiler's next minor version. The language matures through use, not through committee.

### Ported project side

The port isn't just consuming the language — it's shaping it. Early porters have disproportionate influence over what the language becomes. The friction you report becomes v-next's feature list. That's agency late porters don't have, and it's the quiet benefit of taking on re-port risk early. Your workload authors the roadmap; you just have to be honest about where you hit walls.

### Evidence — port → feature mapping

- **abaco** → u128 + `u64_mulmod` hardware fast-path
- **kavach** → generics, pattern matching, exhaustiveness checking
- **hoosh** → HTTP / TLS / JSON stdlib surface
- **agnosys** → syscall ergonomics + packed-error encoding
- **kybernet** → signal / epoll / timerfd kernel-interface work
- **sigil** → Ed25519 + hash primitives in stdlib

Every port was a downstream user running the language hard enough to find its gaps. Every shipped improvement made the next port easier. The compiler is what it is today *because* of them.

### The canonical closed form — abaco

1. Port identified the missing-feature friction (no u128, 64-add multiply)
2. Port specified the fix back to the compiler (hardware `u64_mulmod`)
3. Cyrius v4.8.5 shipped the instruction
4. abaco re-measured — **~12× faster end-to-end on Miller-Rabin**, now beating Rust on the same workload

The pre-fix abaco port was publishing a number that lasted days, not months. That's the feedback loop's cost. The 12× follow-up is its payback.

---

## Pillar 3 — System Ports vs Compute Ports

Not every port has the same relationship with the compiler. This is the variable that makes Pillars 1 and 2 actionable.

### Language side

Different workloads stress different parts of the compiler.

- **System workloads** stress the allocator, syscall ergonomics, error handling, I/O codegen. Cyrius's structural wins live here: zero runtime overhead, packed error encoding, bump allocator vs malloc. These wins hold across compiler versions because they're architectural, not optimizer-dependent.
- **Compute workloads** stress inlining, constant folding, auto-vectorization, regalloc, loop unrolling. This is where LLVM's 20+ years of optimization tuning shows. A compiler that handles system code well may still need years of optimization work before reaching compute-code parity.

A language that's shipped system support is not a language that's ready for compute. The language needs to know which phase it's in, and communicate that phase honestly to porters.

### Ported project side

Your port's success depends on whether the language is ready for *your* workload class. An I/O-heavy system port in 2026-04 against Cyrius 5.5.4 will report strong numbers. A math-heavy compute port against the same compiler will report weak numbers — not because the port is bad, but because the compiler hasn't hit its optimization arc yet.

Choosing when to port means choosing which language version will measure you. System ports can be measured now; compute ports should be measured later. Same port, different language moment — different result.

### Evidence

AGNOS separates them by design. **System ports shipped now** (pre-optimization): kernel (v1.22.0), kybernet, hoosh, ark, nous, kavach, sigil, agnosys, argonaut, libro, shakti, phylax, bote, t-ron, daimon, agnoshi, itihas, sankoch, hisab, avatara, ai-hwaccel, hadara, shravan, mabda, abaco, bsp, cyrius-doom — 30+ shipped. **Compute ports scheduled later** (post-v5.6.x / v5.7.x): the 82-crate science stack — falak, bijli, impetus, prakash, kshetra, and the rest.

---

## The Sequencing Rule

Given the three pillars, the rule synthesizes simply:

- **Port what's invariant to compiler optimization now.** Allocation patterns, syscall wrappers, error paths, I/O plumbing, protocol handling, init sequences. Cyrius already wins here structurally — and system ports drive the feedback loop that matures the compiler.
- **Port what's dependent on compiler optimization later.** Pure compute, tight numeric kernels, SIMD hot paths — anything sensitive to inlining, constant folding, regalloc. Wait for v5.7.x before measuring.

Porting the compute stack before v5.6.x lands is porting to a compiler that's about to get significantly better. Every benchmark published would need re-running. Every "Cyrius is slower at X" claim would become a historical artifact within months. Worse: the first impression for external engineers would be the weaker numbers, and you don't get to un-publish first impressions.

Waiting costs momentum. Publishing weak first-impression compute numbers costs the whole record.

The cheaper cost is the correct one to pay.

---

## Benefits and Drawbacks

This sequencing isn't free. Being honest about both sides:

### Benefits

- **Strongest-first receipts** — initial benchmarks reflect Cyrius's structural wins (allocation, I/O, syscalls, dep reduction), not its pre-optimization compute gap. First impression is the best-case truth.
- **Avoided re-port debt** — compute crates get ported once, in the final idiom, against a mature codegen. No rewrite pass when v5.6.x lands.
- **Port efficiency** — writing against a mature language means fewer workarounds. Ports read like native code, not like someone talking around a missing feature.
- **Cleaner sequencing story** — "system stack shipped, compute stack scheduled for post-v5.7.x" is a discipline claim with receipts. "Everything ported, half the numbers about to be re-measured" is a red flag to any engineer reviewing the record.
- **Compiler feedback stays closed** — the loops that ran through the first 30+ ports have already landed their features. The next wave inherits the tuning without re-running the painful version of the cycle.

### Drawbacks

- **Momentum cost** — a multi-month gap between system-port completion and compute-port start. External observers glancing at the repo list read "incomplete ecosystem." The perception is real even when the sequencing is correct.
- **Dependency friction** — any system-level work that needs a math crate (numeric validation in crypto, stats in observability, etc.) ends up waiting on the compute-port timeline or stubbing around it.
- **Narrative complexity** — explaining "30+ ports shipped, 80+ pending, by design" requires context. The simpler story ("everything ported") is easier to tell and easier to misunderstand the absence of.
- **Attention-window risk** — external interest cycles don't wait for compiler maturity. The moment when the world might pay attention can pass before the optimization arc completes.
- **Psychological drag** — finishing 30+ system ports while staring at 80+ unstarted compute ports is demoralizing. The Librarian stance (transmission, not completion) helps, but it doesn't eliminate the drag.

### Net position

Every drawback above is *recoverable*. Momentum rebuilds. Attention windows come back. Narrative can be re-explained. Dependency friction can be worked around.

The drawback on the *other* side — publishing weak compute numbers that become the canonical first impression — is not recoverable. The first benchmark everyone quotes is the one that sticks; you don't get to un-publish it, and no later measurement fully overwrites it.

The trade is recoverable cost against unrecoverable cost. That's the whole argument.

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
