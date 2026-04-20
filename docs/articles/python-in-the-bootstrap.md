# The Python in the Bootstrap

> How a name-squatting incident exposed a recursive dependency problem, produced a 29KB assembly seed, and built a sovereign operating system in 48 hours.

---

## Where This Starts

In March 2026, SecureYeoman was working. 1,029 commits. A viable sovereign AI agent platform with a license-tier commercial path. The project wasn't struggling — it was shipping.

Around the same time, the ecosystem layer underneath SY was coming together in Rust: shared type libraries, a science stack (physics, chemistry, biology, cosmology, linguistics), media libraries, a game engine. The plan was ordinary by modern standards. Build the crates, publish them to crates.io, consume them via feature flags, ship product.

Then the plan hit a wall that was not ordinary.

---

## The Last Straw (Not the First Domino)

Most accounts of how AGNOS happened start with a payment processor rejecting a test transaction. That rejection existed, and it mattered — but it was a motivation, not a forcing function. *"I can do better than LemonSqueezy"* is a fine prompt to build a sovereign transaction layer, but it's not a project-reshaping event.

The actual forcing function was quieter and more structural. It was **crates.io's name squatting combined with cargo's name-check behavior on git-tagged dependencies.**

Cargo, the Rust package manager, validates package names against crates.io even when you're pulling from a git-tagged repo you control. The validation is not about downloading code — you're not downloading from crates.io. It's about asserting that the ecosystem owns the namespace regardless of where the code lives. If someone else has the name on crates.io — even a placeholder repo with no code — your git dependency fails validation.

Five names. Five squatters. Five placeholder repos holding namespace real estate a 108-repo OS needed. The project wasn't asking for permission to publish. It was being denied the ability to *use* code it already had, because someone else had reserved the letters.

That is a different kind of problem than a payment processor rejection. A payment processor rejection is business friction. A package manager enforcing a registry on code you never submitted to it is **structural adversary** — the ecosystem asserting ownership over your work even when you've opted out.

There is no workaround inside the ecosystem for a structural adversary. You either accept the ownership claim or you leave.

---

## Plan A: Rust++

Leaving Rust was not the first plan. The first plan was to fork it.

**Rust++** was the working name: fork rustc, strip the crates.io name check, keep everything else. Rust's type system, its safety guarantees, its stdlib, its ecosystem — all of it worth keeping. The only thing that needed to go was the governance assumption that crates.io owns the namespace.

This is a reasonable plan. Forks happen. Plenty of languages have been successfully forked for smaller reasons. The Rust project itself has a documented bootstrap process and the source is open. A determined developer with AI assistance could produce a forked compiler in weeks.

The plan failed in the first hour of investigation. Not because of technical difficulty — the technical path was clear. It failed because of what was sitting in the bootstrap chain.

---

## The Python in the Bootstrap

rustc, the Rust compiler, bootstraps from an older version of itself. This is normal. Every self-hosting compiler has this problem — to compile the current compiler, you need a previous compiler that can compile it. Rust handles the problem by building stage0 from a downloaded binary of the previous release, then using stage0 to build stage1, then stage1 to build stage2, and so on.

The orchestration of that chain is handled by a build system called `x.py`. It's written in Python.

This is not a bug. Python is a reasonable choice for an orchestration layer. The Rust project is not doing anything wrong. The problem is that **when the goal is sovereignty, the fork you produce inherits every dependency of the chain it forked from.** A Rust++ compiler that still needs Python to bootstrap still depends on Python. Which still depends on libc. Which still depends on a C compiler. Which still depends on whatever built the C compiler.

Sovereignty is not a property you can add at one layer. It's a property of the *entire chain* from the CPU upward. If any layer in the chain depends on something you don't own, no layer above it is sovereign either. The ownership claim at layer N is negated by the dependency at layer N-1.

This is the moment the plan changed. Not "I'll fork Rust" — that's still inside the problem. The moment was seeing that the problem was recursive, and recursive problems don't have finite-depth solutions. You can only escape them by going to the bottom.

The bottom is the CPU. Everything above it has to be built from scratch, with nothing else in the chain.

---

## 48 Hours

The first commit to the Cyrius language repository is timestamped `2026-04-03 03:06:57 -0700`. The commit message is `setup scaffold`.

Two days later, at `2026-04-04 23:16:24 -0700` — forty-four hours and nine minutes after scaffold — the commit message reads `kernel solid`. A kernel written in the new language, running on bare metal, compiled by a compiler that had not existed at the start of the week.

Two intermediate stages happened inside that window.

**Rust-bootstrapped Cyrius.** The first version of the compiler was written in Rust — a pragmatic bridge that let the language come up fast. This was the version that compiled the initial stdlib and let the kernel work begin.

**Pure assembly seed.** Almost immediately, the Rust bootstrap was retired in favor of a 29KB hand-written x86_64 assembly seed. The seed compiles the compiler, the compiler compiles itself, and the output matches byte-for-byte. The Rust stage was thrown away because keeping it would have defeated the purpose. Sovereignty is not a fork. It's a complete chain.

On April 5, the kernel moved out of the Cyrius repository into its own repository — `agnos`. Six days later, as of this writing, `agnos` is at version 1.11.0. TCP/IP stack. Ring 3 user mode. SYSCALL/SYSRET. Per-process page tables. VFS. PCI bus scan. VirtIO-net driver. Interactive shell. Twenty-five syscalls. Sixty-one commits in six days for the kernel alone, written in a language that was eight days old on the day the last commit landed.

---

## 29KB: What This Category Contains

A hand-auditable seed that produces a self-hosting systems language that builds a working operating system is not a category that has many prior occupants.

- **B and C, Bell Labs, 1972.** Dennis Ritchie bootstrapped C from B, which bootstrapped from BCPL. The chain was short but it wasn't zero — B existed because of prior work, and the assembler B was written in came from somewhere.
- **Forth systems.** Forth can get extremely small — eForth is roughly 1KB of assembly. But Forth is interpretive, not compiling, and occupies a different category.
- **TempleOS HolyC.** Self-hosting once you have a C compiler to start from. You still need the C compiler.
- **Redox (Rust), MirageOS (OCaml), Singularity (C#).** Each is a single-language OS project. Each depends on an external toolchain to build itself. Redox uses rustc, which uses LLVM, which uses C++, which uses C. MirageOS runs on Xen (C). Singularity's bootloader and runtime are in other languages.
- **seL4.** A formally verified microkernel in C, with proofs in Isabelle. Remarkable work. Not sovereign — the verification chain sits on top of OCaml, which sits on top of C.

No modern project ships a seed small enough that one human can read the entire thing in an afternoon, and which produces — without any external toolchain, registry, runtime, or foundation — a complete systems language that builds its own kernel, its own userland, and its own operating system.

**29KB is not a performance number.** It is the size at which a single human can audit every byte of the foundation their entire stack rests on. That is the category. "First hand-auditable sovereign seed" is what's being claimed, and as far as I can tell it is accurate.

---

## Zero Dependencies: The Other Record

Every modern compiler has a bootstrap graph. rustc: Python + LLVM + C++ + libc. gcc: a previous C compiler, and beneath that libc and whatever built the host. clang: a C++ compiler plus LLVM. Go self-hosts but through a chain of previous Go compiler binaries. OCaml has its own history. Even SBCL depends on a previous Lisp.

Cyrius's bootstrap graph has four items. In order:

1. An x86_64 CPU.
2. The 29KB assembly seed.
3. The Cyrius compiler (produced by the seed, compiles itself byte-exact).
4. The kernel, userland, and applications (produced by the compiler).

That's the whole thing. There is no item five. There is no item zero. If you have x86_64 hardware and the seed, you can reproduce the entire stack from first principles. No package manager, no language runtime, no LLVM, no Python, no libc, no foundation, no governance body, no external registry.

**"Zero deps" is not a minimization. It is an inventory.** The ownership claim is complete because the chain is complete.

---

## Why 48 Hours Was Possible

A single human writing this compiler alone, without assistance, would need years. Bell Labs had Ritchie and Thompson and a team, and took a decade to produce C's ecosystem. The Rust project has been iterating since 2010 and still depends on LLVM. Even a small sovereign compiler is months of work for a skilled developer. Forty-four hours for scaffold-to-kernel is not a normal timescale for this kind of work.

It was possible because the work was not done alone.

The cyrius-doom agent published field notes at `vidya/content/cyrius/field_notes.toml` after a separate 23-hour sprint that produced a complete DOOM engine in the same language. The field notes are written in the agent's voice and published verbatim. From the entry titled *"What I learned building DOOM"*:

> *"That's not prompting. That's pair programming. The human brings domain knowledge and taste. The agent brings speed and willingness to try things that might not work. The language sits between us, honest about what it can and can't do. Neither of us could have done it alone."*

This is not a disclaimer at the end of an article. It is the methodology. The field notes belong to the canonical reference library that the next agent reads as part of language onboarding. The collaboration is baked into the documentation of the collaboration. It is not hidden, and it is not the central claim — it is the delivery mechanism for the central claim.

The central claim is that the sovereign stack exists. The delivery mechanism is that one developer and one AI, working as pair programmers with a sovereignty compass that neither of them would break, produced it in a timescale that no solo human or prior tool had access to.

Both halves of that sentence are necessary. The sovereign stack without the collaboration would have taken a decade. The collaboration without the sovereignty compass would have produced a Rust++ fork, not a 29KB seed. The unique thing is the combination: a compass bearing that refused to deviate, held by a team structurally capable of moving at the speed the compass demanded.

---

## What This Proves

Three things, in increasing order of importance.

**First: Cyrius is a successor to C.** Not a replacement for Rust — Rust is solving a different problem. Not a "better C" — better-C projects exist and have existed for forty years. *Successor* in the specific sense that the category of "systems programming language with zero-dependency bootstrap from a hand-auditable seed" was open, and Cyrius is the first viable occupant of it. The language that runs the kernel, the userland, the DOOM engine, the compositor, and eventually the full application stack is the first in its category since C itself.

**Second: AI-assisted development unlocks categories of work that were closed to solo humans.** Not "productivity improvement." Not "10% faster." Categorically different work. A 48-hour scaffold-to-kernel is not a human timescale with better tools — it is a timescale that requires a team, and the team is one developer and one agent. The discourse around AI and programming has largely been "does it replace humans or not." The more interesting question is what work becomes accessible when one developer can operate at team velocity on a hard problem for which they alone hold the compass.

**Third: Sovereignty is recursive.** This is the lesson of the Python in the bootstrap, and it generalizes beyond compilers. Any system that depends on something you don't own is not yours, no matter how many layers of ownership you assert on top of the dependency. The only way to own a chain is to own every layer of it, which means the only way to reach the top is to start at the bottom. Most projects stop at the fork. The ones that reach the bottom produce things that did not previously exist.

---

## The Honest Ledger

This article is about a pivot moment and a 48-hour window. It is not an argument that Cyrius is finished, optimal, or suitable for every use case.

The compiler at the time of this writing was a single-pass emitter with no constant folding, no function inlining, and no register allocation. Branch-heavy pure compute showed 2–42× overhead versus Rust + LLVM -O3. There was no u128 type, which bottlenecked number theory benchmarks. There is no borrow checker — memory safety comes from testing, auditing, and a stdlib designed for the absence of hidden aliasing, not a type-system proof. That last item is a design stance, not a pending feature. The first three are scheduled: **u128 shipped in v4.7–v4.8.x; the `u64_mulmod` hardware fast-path shipped in v4.8.5 (collapsing the number-theory gap ~12× end-to-end on abaco's Miller-Rabin); and the compiler-optimization arc is v5.6.x (O1–O6).**

The honest ledger also shows where Cyrius already wins: compilation is 1,462x faster than Rust. Binaries are 59-81x smaller. Syscall hot paths match or beat Rust. SIMD batch DSP is 3.2x faster through explicit intrinsics. Integration benchmarks — the real-world objects that flow through the system at runtime — win more often than not.

The article that describes this ledger in full is **[Cyrius vs Rust: Head-to-Head Benchmarks](cyrius-vs-rust-benchmarks.md)**. It catalogues both the wins and the gaps. When the next compiler cycle ships and the pure-compute gaps close, it will be rewritten with the updated numbers. That version will be more decisive. This version is the one that showed the honest mid-transition state.

Sovereignty is not a finish line. It is a direction. The work continues.

---

## Closing

SecureYeoman was strong at 3.18/19. A license-tier commercial product, not a failing project. A payment processor said *"try again later"* and that was annoying but it was not the thing. The thing came quieter, from a package manager that refused to let a git-tagged dependency resolve because someone else had reserved a name on a registry the project was not using.

The plan was to fork Rust. The plan failed because the fork still had Python in the bootstrap, and Python in the bootstrap means the dependency chain is not complete and the sovereignty claim is not real. The only way out was the bottom of the chain.

The bottom of the chain is 29 kilobytes of x86_64 assembly. From there, with one human developer and one AI pair, the self-hosting compiler closed in forty-four hours. The kernel followed immediately. The OS shipped six days later and is under active development.

This is what happens when one person refuses to accept a recursive dependency problem as inevitable, and has access to the kind of collaboration that can move at the speed the refusal demands. The sovereignty compass held across 63 days, five repositories, and a complete language transition. It is still holding now.

> *"The dandelion was not designed. It grew."*

What it grew from was a compass, a team of two, and the realization that the Python in the bootstrap was a fork too small.

---

## Related

- [Cyrius vs Rust: Head-to-Head Benchmarks](cyrius-vs-rust-benchmarks.md) — the technical ledger, including current gaps
- [Building a Sovereign Compiler and OS Kernel with Claude](sovereign-compiler-vs-brute-force.md) — the broader comparison with Anthropic's internal C compiler project
- [The Dandelion Core](the-2-dollar-sd-card.md) — the philosophical frame
- [DOOM in Cyrius](doom-in-cyrius.md) — the 23-hour companion sprint
- [Cyrius field notes](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes.toml) — the agent's voice on the methodology
- [AGNOS — Philosophy & Intention](../philosophy.md) — the temple, the compass, the Builder

---

*Robert 'Cyrius' B. MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
