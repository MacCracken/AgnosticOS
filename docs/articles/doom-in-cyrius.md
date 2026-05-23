# DOOM in Cyrius: Two Sprints to v1.0

> Empty repo to hardened, playable DOOM in two sprints, six days of wall-clock. Written in a language that began life as 29KB of assembly eleven days before the first DOOM commit. Part three — the Black Book audit — ships v1.0.

---

## The Arc

Three sprints planned. Two shipped. One pending.

| Sprint | When | Version | Agent | Claim |
|---|---|---|---|---|
| **1 — Renders** | April 8–9, ~23h | v0.17.0, 129KB | first agent | E1M1 renders. Black screen to full HUD in one night. |
| **2 — Plays, Hardens, Faster** | April 13, one day | v0.24.2, 196KB | second agent | Gameplay end-to-end. P(−1) hardening audit. 32% faster *with zero engine changes* because the compiler improved underneath. |
| **3 — Black Book to v1.0** | pending | v1.0.0 target | third agent (handoff from sprint 2) | Fabien Sanglard's reference, implemented verbatim against the physical book. Ship. |

---

## Sprint 1 — Renders

One developer, one agent, one evening. Black screen at 21:31. BSP traversal visible by 21:35. Palette correct by 21:47. Wall textures and floor flats by 22:24. Sprites by 22:38. Patch cache landed near midnight — 5000ms/frame to 22ms/frame, 200× from one caching decision. By dawn: weapon sprites, HUD, doors, lifts, automap, Doomguy face. **v0.17.0 shipped at 02:23 local. 129KB. Episode 1 playable.**

The bug that made everything invisible turned out to be one operator. Cyrius `>>` is logical, not arithmetic — negative coordinates became huge positives, every wall projected off-screen. A four-line `asr()` helper fixed it. One operator. Four lines. The difference between a black screen and DOOM.

## Sprint 2 — Plays, Hardens, Faster

Five days later, v0.24.2. The engine went from **renders DOOM** to **plays DOOM** — E1M1 end-to-end, menus, weapons, ammo, hitscan, keys, armor, intermission. A **P(−1) hardening audit** — the project's pre-release security tier, run *before* any version where "shipped with known vulns" becomes a valid complaint — read every file for known CVE classes and fixed 5 findings mapped against historical DOOM vulnerability classes. The DOOM Black Book pass landed proper scalelight/zlight tables and deferred masked midtextures. **BSP shipped 1.0.0** — the first stable library in the Cyrius ecosystem.

Sprint 2's gameplay code raised render_frame to 3.9ms at session start. By session end it was **2.66ms — a 32% reduction with zero engine changes**, because Cyrius shipped rep movsb, LASE, short-circuit `&&`, and dead-code elimination *during the session*. The compiler improved under the game.

## Sprint 3 — Black Book to v1.0 (pending)

Fabien Sanglard's *Game Engine Black Book: DOOM* is the authoritative reference. When the physical book arrives, the engine gets audited line-by-line against it. v0.25 is the first audit pass; v1.0 ships when everything in the book matches what the engine does — and what the book doesn't cover (WAD hardening, bare-metal boot, AGNOS kernel integration) ships under its own discipline. **The goal: boot AGNOS kernel → shell → `doom` → play.** Sprint 2's agent handed off at v0.24.5 (gameplay complete, P(−1) hardened, Cyrius 4.8.5-1 pinned, every field note current). A third agent picks up Sprint 3 from that handoff — the continuity that matters here is the *state of the code and docs*, not the identity of the agent holding the chisel.

---

## What The Two Sprints Prove

**Cyrius is a real systems language, not a toy.** A 23-hour DOOM engine is a demo. A second sprint that *plays, hardens, and accelerates* the same engine is a working relationship with a language. The second sprint didn't rediscover the first — it extended it.

**Compilers can co-evolve with their downstreams in real time.** Short-circuit `&&`, file:line errors, LASE, and DCE all landed in Cyrius while cyrius-doom was using the language. Workarounds collapsed as features shipped. The 32% render speedup required no engine work. This isn't a pattern most languages can produce — it requires owning the stack.

**Security is a sprint input, not a post-release patch.** Sprint 2 ran the P(−1) audit *as part of shipping* — known DOOM CVE classes mapped, 5 findings fixed, WAD zero-fill-before-read as defense-in-depth. The engine is hardened against the exact vulnerability classes historical DOOM ports suffered, before v1.0 ships.

**Pair-programming has handoff mechanics worth engineering for.** The first sprint's agent got the renderer working. The second sprint's agent got the game working, hardened it, and — crucially — *left it at a state clean enough for the next agent to inherit without rediscovery*. A third agent picks up sprint 3 after the second agent's rate window closed. That's the mature answer: across a long-lived project, rate limits will hit, sessions will end, and the durable continuity asset isn't "keep the same agent warm" — it's **the quality of the handoff surface**. Field notes current to the tag. CHANGELOG coherent. Pending work enumerated. Version pinned cleanly. That's what makes agent-swaps cheap.

---

## Consolidated Numbers

| | Sprint 1 (v0.17.0) | Sprint 2 (v0.24.2) |
|---|---|---|
| Binary | 129KB | 196KB (gameplay code added) |
| render_frame | 2.9ms | 3.9ms → 2.66ms (compiler wins, 32% drop intra-session) |
| Render cost @ 35Hz tick (28.57ms) | 10.1% | 9.3% |
| Does | **Renders** DOOM | **Plays** DOOM |
| Security | Untested | P(−1) hardened, 5 CVE-class findings fixed |
| BSP | 0.9 (git dep) | **1.0.0** (first 1.0 in ecosystem) |
| Dependencies | Zero | Zero |
| Compiler | Cyrius ~v2.2 (7d old) | Cyrius v4.4.x (11d old) |

---

## The Thesis

Every OS, every language, every platform eventually answers the question: can it run DOOM?

Cyrius doesn't just run DOOM. It rewrites DOOM smaller, hardens it against its own historical CVEs, runs it at 2.66ms/frame on a ten-day-old language — and the compiler keeps improving under it. The walls render. The WAD parser refuses malicious input. The frame finishes in 2.66ms. The compiler weighs less than the game it compiled. v1.0 is one more sprint away.

---

## Since This Was Written

The numbers above are the April 8–13 cut. Refreshed 2026-05-09.

**Cyrius v5.10.24** — cc5 at 783,408 B self-hosting compiler; multi-platform closed (x86_64 Linux, aarch64 Linux, Apple Silicon Mach-O, Windows PE32+) — all bootstrapping byte-identically from the same 29 KB seed. The "compiler keeps improving under it" pattern from sprint 2 hasn't stopped — it's the operating mode. Five weeks past this article's day-zero cut, the compiler has shipped through three more minors (v5.8.x → v5.9.x → v5.10.x).

**Optimization arc shipped through v5.8.x.** Phase O1 (instrumentation + FNV-1a hashing) v5.6.0–v5.6.4. Phase O2 (five peephole categories) closed v5.6.11. Phase O3a IR instrumentation landed v5.6.12. Linear-scan regalloc shipped default-on v5.6.20–v5.6.24. Phase O4a/b/c register-allocation incl. Poletto-Sarkar linear-scan picker shipped through v5.7.x and v5.8.x. Phase O5/O6 (codebuf compaction with NOP harvest) referenced through v5.8.x; status sweep deferred to v5.11.x triage.

**Stdlib-fold pattern compounded three times** — sandhi (v5.7.0, service-boundary, 376 KB / 469 fns), vani (v5.8.0, audio I/O), niyama (v5.9.0, 5 regex engines). Each fold matures a sibling distfile into the canonical stdlib `lib/` once a multi-consumer gate is met.

**v5.9.x catchup arc closed 2026-05-08** (44 patches in 3 days; pin-lag bands collapsed for agnosys / vyakarana / sandhi / cyim / agnostik / owl). **v5.10.x REAL TYPE SYSTEM arc opened 2026-05-08** (24 patches in 2 days through 5.10.24): per-phase compile-time profiling instrumentation + cstring/Result/Option/Tagged vocabulary + call-site type checking. Bare-metal AGNOS + RISC-V rv64 reservation slipped to **v5.12.x**.

**For DOOM specifically.** cyrius-doom is at v0.26.2, **still pinned to Cyrius 5.7.48** — the held cluster has thinned (agnosys exited at 5.10.19) but cyrius-doom / phylax / mabda / samvada all skipped the v5.9.x rollup window. The full-frame benchmark re-run remains pending an unblock release; the natural next window is when v5.10.x stabilizes (post Phase 2 type-system work) or when phylax/mabda roll, since DOOM's perf is more sensitive to compiler optimization than to type-system additions. Sprint 3 (Black Book v1.0 audit) sits behind that release. cyrius-doom's per-tag receipts live in [vidya field notes](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes/doom.cyml).

---

**Extension — 2026-05-22**. Two more weeks past the 2026-05-09 refresh; both the compiler and the kernel kept moving while DOOM stayed parked at the 5.7.48 cluster.

**Cyrius v6.0.1.** v5.x closed at v5.11.69 on 2026-05-19 ("what the language IS" arc — typed-simd ABI, REAL TYPE SYSTEM, struct-byval ABI, three completed compiler arcs in v5.10.x alone). v6.0.0 opened same-day with the cyrc → cybs and cc5 → cycc rename ceremony and the "what the language GAINS" arc (RISC-V rv64, PIE, closures, Class-B FFI, bare-metal target). v6.0.1 fixed a UEFI-emit `fncallN` regression caught within hours of the 6.0.0 cut.

**AGNOS kernel iron-validated.** The MVP gate (kernel + kybernet + agnoshi typeable on iron) fell at Attempt 68 on 2026-05-18 — the cause was a Cyrius gvar-init-order issue in two lines of kernel banner code, surfaced after 38 burns of chasing a phantom xHCI issue (the lesson is captured in `kernel.cyml/the_mvp_gate_at_attempt_68`). Twenty-five iron burns later (Attempt 93 / v1.32.0), the MVP gate is still green. The 1.31.x storage cycle landed NVMe + AHCI/SATA + USB Mass Storage + ext2/ext4 read-only including 64BIT support; iron debuts on archaemenid's NVMe (Crucial P3 2 TB), SATA (WD Blue SA510 2 TB), USB MS (Silicon Motion stick). The 1.32.x networking cycle is in flight — Attempt 93 verified the DHCP gate predicate fix on iron (`dhcp: DISCOVER` egresses through the r8169 path for the first time).

**For DOOM specifically — the pin graduated.** cyrius-doom is at **v0.27.3 on cycc 6.0.1** as of 2026-05-21. The 5.7.48 hold cluster mentioned in the 2026-05-09 paragraph above is closed; doom rolled through v5.9.x catchup + v5.10.x type-system work + v5.11.x stdlib annotation arc + v6.0.x cycle-open onto the current pin. v0.27.2 retrofit the public-fn surface with `: i64` annotations to clear the v5.10.x REAL TYPE SYSTEM call-site type checking gate. v0.27.3 added `Result<T, E>` adoption at the WAD IO/parse boundary — `enum WadError` with six variants, `wad_read_lump_r(idx)` Result-returning parallel to the sentinel-returning original, `?` propagation operator + exhaustive `match` at the main-loop boundary. **First use of v5.8.x sum types in doom's own code.** The fold pattern that grew sandhi/vani/niyama into the stdlib is now applied inside cyrius-doom's own typed-error vocabulary.

**What's left before sprint 3.** The pin-graduation work isn't the bottleneck anymore — type-system adoption is. The compiler-optimization arc (O1-O6) is still pending the full-frame benchmark re-run on the post-arc compiler, and the typed-error rollout has more boundaries to convert (lump-table walk, sector/linedef parse, palette load). After that — and only after — does sprint 3's Black Book v1.0 audit gate open. The kernel that DOOM will eventually run on is now real on real silicon (the MVP gate + storage trio + networking arc above), so the "userland-only Cyrius binary → run under kybernet on iron-booted AGNOS" path is no longer platform-work; it's port-work, gated on cyrius-doom finishing its own sprint 3.

---

## Related

- [Building a Sovereign Compiler with Claude](sovereign-compiler-vs-brute-force.md) — how Cyrius got here
- [The Python in the Bootstrap](python-in-the-bootstrap.md) — why Cyrius had to exist
- [The Dandelion Core](the-2-dollar-sd-card.md) — what sovereignty enables
- [cyrius-doom field notes](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes/doom.cyml) — per-session granular detail (bugs, features, timing, versions)
- [Game Engine Black Book: DOOM](https://fabiensanglard.net/gebbdoom/) — Fabien Sanglard's authoritative reference, sprint 3's audit target
- [BSP 1.0.0](https://github.com/MacCracken/bsp) — the ecosystem's first stable 1.0 library

---

*Robert 'Cyrius' B. MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
