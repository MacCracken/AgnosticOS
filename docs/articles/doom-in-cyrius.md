# DOOM in Cyrius: Two Sprints to v1.0

> Empty repo to hardened, playable DOOM in two sprints, six days of wall-clock. Written in a language that began life as 29KB of assembly eleven days before the first DOOM commit. Part three — the Black Book audit — ships v1.0.

---

## The Arc

Three sprints planned. Two shipped. One pending.

| Sprint | When | Version | Agent | Claim |
|---|---|---|---|---|
| **1 — Renders** | April 8–9, ~23h | v0.17.0, 129KB | first agent | E1M1 renders. Black screen to full HUD in one night. |
| **2 — Plays, Hardens, Faster** | April 13, one day | v0.24.2, 196KB | second agent | Gameplay end-to-end. P(-1) audit. 32% faster *with zero engine changes* because the compiler improved underneath. |
| **3 — Black Book to v1.0** | pending | v1.0.0 target | second agent (continuing) | Fabien Sanglard's reference, implemented verbatim against the physical book. Ship. |

---

## Sprint 1 — Renders

One developer, one agent, one evening. Black screen at 21:31. BSP traversal visible by 21:35. Palette correct by 21:47. Wall textures and floor flats by 22:24. Sprites by 22:38. Patch cache landed near midnight — 5000ms/frame to 22ms/frame, 200× from one caching decision. By dawn: weapon sprites, HUD, doors, lifts, automap, Doomguy face. **v0.17.0 shipped at 02:23 local. 129KB. Episode 1 playable.**

The bug that made everything invisible turned out to be one operator. Cyrius `>>` is logical, not arithmetic — negative coordinates became huge positives, every wall projected off-screen. A four-line `asr()` helper fixed it. One operator. Four lines. The difference between a black screen and DOOM.

## Sprint 2 — Plays, Hardens, Faster

Five days later, v0.24.2. The engine went from **renders DOOM** to **plays DOOM** — E1M1 end-to-end, menus, weapons, ammo, hitscan, keys, armor, intermission. A **P(-1) security audit** fixed 5 CVE-class findings mapped against historical DOOM vulnerability classes. The DOOM Black Book pass landed proper scalelight/zlight tables and deferred masked midtextures. **BSP shipped 1.0.0** — the first stable library in the Cyrius ecosystem.

And render_frame dropped from 2.9ms to **2.66ms with zero engine changes**, because Cyrius shipped rep movsb, LASE, short-circuit `&&`, and dead-code elimination *during the session*. The compiler improved under the game.

## Sprint 3 — Black Book to v1.0 (pending)

Fabien Sanglard's *Game Engine Black Book: DOOM* is the authoritative reference. When the physical book arrives, the engine gets audited line-by-line against it. v0.25 is the first audit pass; v1.0 ships when everything in the book matches what the engine does — and what the book doesn't cover (WAD hardening, bare-metal boot, AGNOS kernel integration) ships under its own discipline. **The goal: boot AGNOS kernel → shell → `doom` → play.** Same agent continues across the line to keep the session context that earned the first two sprints.

---

## What The Two Sprints Prove

**Cyrius is a real systems language, not a toy.** A 23-hour DOOM engine is a demo. A second sprint that *plays, hardens, and accelerates* the same engine is a working relationship with a language. The second sprint didn't rediscover the first — it extended it.

**Compilers can co-evolve with their downstreams in real time.** Short-circuit `&&`, file:line errors, LASE, and DCE all landed in Cyrius while cyrius-doom was using the language. Workarounds collapsed as features shipped. The 32% render speedup required no engine work. This isn't a pattern most languages can produce — it requires owning the stack.

**Security is a sprint input, not a post-release patch.** Sprint 2 ran P(-1) audit *as part of shipping* — known DOOM CVE classes mapped, 5 findings fixed, WAD zero-fill-before-read as defense-in-depth. The engine is hardened against the exact vulnerability classes historical DOOM ports suffered, before v1.0 ships.

**Pair-programming has continuity mechanics worth preserving.** The first sprint's agent got the renderer working. The second sprint's agent got the game working. Keeping the same agent for sprint 3 is a deliberate choice — the session-level context on WAD parsing, bug patterns, and architectural decisions is itself a durable asset. Agent-continuity is now part of the project's plan.

---

## Consolidated Numbers

| | Sprint 1 (v0.17.0) | Sprint 2 (v0.24.2) |
|---|---|---|
| Binary | 129KB | 196KB (gameplay code added) |
| render_frame | 2.9ms | 2.66ms (compiler wins) |
| Tick headroom @ 35Hz | 90% | 91% |
| Does | **Renders** DOOM | **Plays** DOOM |
| Security | Untested | P(-1), 5 CVE-class findings fixed |
| BSP | 0.9 (git dep) | **1.0.0** (first 1.0 in ecosystem) |
| Dependencies | Zero | Zero |
| Compiler | Cyrius ~v2.2 (7d old) | Cyrius v4.4.x (11d old) |

---

## The Thesis

Every OS, every language, every platform eventually answers the question: can it run DOOM?

Cyrius doesn't just run DOOM. It rewrites DOOM smaller, hardens it against its own historical CVEs, runs it at 2.66ms/frame on a ten-day-old language — and the compiler keeps improving under it. The walls render. The WAD parser refuses malicious input. The frame finishes in 2.66ms. The compiler weighs less than the game it compiled. v1.0 is one more sprint away.

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
