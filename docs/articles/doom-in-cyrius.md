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

The numbers above are the April 8–13 cut. Since then: **Cyrius v5.6.13** (488KB self-hosting compiler — still bootstrapping byte-identically from the same 29KB seed; aarch64 Linux, Apple Silicon Mach-O, and Windows PE32+ all byte-identical), now deep into the **v5.6.x compiler-optimization arc**. The "compiler keeps improving under it" pattern from sprint 2 hasn't stopped — it's the operating mode. **Phase O1** (instrumentation + FNV-1a symbol hashing) shipped v5.6.0–v5.6.4. **Phase O2** closed at v5.6.11 on 2026-04-23 — five peephole categories with aarch64 `cc5` shrinking 471,360 → 453,688 B (-3.75%) in the final category alone. **Linear-scan regalloc is in flight at v5.6.13**; fused ops (madd/msub/ubfx/sbfx) re-pinned to v5.6.14 after a pre-implementation bytescan showed the current combine codegen shuttles through the stack and blocks fusion opportunities until regalloc lands. For DOOM the practical read is that the *"waiting on 5.6.x"* caveat in sprint 2 is closing — the full-frame benchmark re-run is pending post-regalloc, and Sprint 3 (Black Book v1.0 audit) moves from queued-behind-V1 to concurrent-with-V1 once the arc wraps. cyrius-doom's per-tag receipts live in [vidya field notes](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes/doom.toml).

---

## Related

- [Building a Sovereign Compiler with Claude](sovereign-compiler-vs-brute-force.md) — how Cyrius got here
- [The Python in the Bootstrap](python-in-the-bootstrap.md) — why Cyrius had to exist
- [The Dandelion Core](the-2-dollar-sd-card.md) — what sovereignty enables
- [cyrius-doom field notes](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes/doom.toml) — per-session granular detail (bugs, features, timing, versions)
- [Game Engine Black Book: DOOM](https://fabiensanglard.net/gebbdoom/) — Fabien Sanglard's authoritative reference, sprint 3's audit target
- [BSP 1.0.0](https://github.com/MacCracken/bsp) — the ecosystem's first stable 1.0 library

---

*Robert 'Cyrius' B. MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
