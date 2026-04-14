# DOOM in 129KB: A 23-Hour Sprint in a 7-Day-Old Language

> From empty repo to feature-complete DOOM engine in under 24 hours. 129KB binary. 5,000 lines of Cyrius. Zero dependencies. The language didn't exist a week ago.

---

## The Timeline

**April 3, 2026** — Cyrius doesn't exist. There is no language, no compiler, no assembler. There is a crates.io name squatting problem and a question: "why am I asking permission to publish my own code?"

**April 3–8** — The question cascades. In six days, Cyrius goes from nothing to v2.2.2: a self-hosting compiler with multi-width types, native test/bench runners, fuzzing, and dependency resolution. 215KB compiler. 29KB seed. Zero external dependencies. ([Full story](sovereign-compiler-vs-brute-force.md))

**April 8, 3:31 AM** — First commit: `cyrius-doom` scaffolded. The compiler has never rendered a pixel.

**April 8, evening** — One developer, one agent. The renderer comes alive:

```
21:31  v1:  black screen → green blob (BSP traversal working, wrong palette)
21:35  v2:  palette colors (PLAYPAL lump loaded correctly)
21:47  v3:  natural DOOM colors (sector light levels applied)
22:00  v4:  COLORMAP distance shading (34 light levels)
22:24  v5:  wall textures + floor flats (WAD patches mapped to columns)
22:38  v6:  sprites (armor pickups visible in the world)
```

**April 8, ~midnight** — Patch cache added. Frame time drops from 5,000ms to 22ms. 200x speedup. Real-time rendering achieved.

**April 9, ~1:00 AM** — Weapon sprites, HUD with bitmap font, doors, lifts, automap, Doomguy face, level transitions.

**April 9, 2:23 AM** — Feature complete. v0.17.0. 129KB. Episode 1 playable.

**Total elapsed: ~23 hours.** The developer slept 5-6 hours during the sprint. The agent continued working during some of that time.

---

## The Numbers

| Metric | Original DOOM (1993) | Cyrius DOOM (2026) | Ratio |
|--------|---------------------|-------------------|-------|
| Binary size | ~700KB | 129KB | **5.4x smaller** |
| Source lines | ~30,000 (C) | ~5,000 (Cyrius) | **6x fewer** |
| Source files | ~60 | 19 | **3x fewer** |
| Dependencies | DOS extender, Watcom C runtime, custom memory manager | Zero | **Zero** |
| Render time | Real-time (1993 hardware) | 2.9ms (10x under budget) | — |
| Compile time | Minutes | 103ms | — |
| Compiler age | Watcom C (~1988) | Cyrius (7 days) | — |
| Compiler size | ~100MB+ | 215KB | — |
| Seed binary | N/A | 29KB | — |

---

## What the Binary Contains

19 modules. The complete engine. Episode 1 playable.

| Module | Function |
|--------|----------|
| fixed.cyr | 16.16 fixed-point math, `asr()` for signed right shifts |
| tables.cyr | 1024-entry sine table (Bhaskara I approximation), atan2 |
| wad.cyr | WAD file parser (IWAD/PWAD, directory, lump cache) |
| texture.cyr | Wall texture compositing, flat cache, 8-slot LRU patch cache |
| framebuf.cyr | 320x200 palette-indexed framebuffer, COLORMAP shading, PPM output |
| map.cyr | Full geometry: vertices, linedefs, sidedefs, sectors, segs, subsectors, BSP nodes, things |
| render.cyr | BSP traversal, textured wall columns, visplane spans, sky rendering |
| sprite.cyr | Thing sprites: distance sort, scale, clip to walls, sector lighting |
| input.cyr | Terminal raw mode, WASD + arrows, bitmask action flags |
| player.cyr | Movement, wall sliding collision, step height, ceiling clearance |
| tick.cyr | 35Hz game timer via clock_gettime + nanosleep |
| things.cyr | Monster/item types, AI state machine, pickups, damage |
| status.cyr | HUD: 3x5 bitmap font, health/ammo/armor, Doomguy face, keys |
| menu.cyr | Title screen, main menu, skill select |
| sound.cyr | PC speaker via ioctl tone queue |
| main.cyr | Full game loop: menu → load → input → AI → render → sprites → HUD → flip → wait |

Plus bsp library (821 lines, 8 modules) as a git dependency.

---

## Performance

| Operation | Time | Notes |
|-----------|------|-------|
| fixed_mul | 410ns | Core math primitive |
| sin_lookup | 414ns | Table lookup |
| pcache_get (hit) | 462ns | Patch cache — eliminated disk I/O during rendering |
| texture_get_column | 1μs | With patch cache |
| render_frame (walls + flats) | 2.2ms | BSP + textured columns + visplane spans |
| render + sprites | 2.9ms | Full pipeline including depth-sorted sprites |
| **Tick budget (35Hz)** | **28.6ms** | — |
| **Headroom** | **90%** | Could render ~345fps |

The 200x optimization story: v0.9.0 rendered a frame in 5,000ms because every wall column triggered a WAD file read. An 8-slot LRU patch cache reduced WAD reads per frame from hundreds to ~8. Same renderer, same math, just cached I/O. 5,000ms → 22ms → 2.9ms.

---

## The Bug That Made Everything Invisible

The renderer produced a black screen for hours. Every module compiled. Every function ran. Zero pixels drawn.

Root cause: Cyrius `>>` is a logical right shift (zero-fills upper bits). Not arithmetic (sign-extends). In C, `>>` on signed types is implementation-defined but typically arithmetic on x86. In Cyrius, it is definitively logical.

```
fixed_mul(a, b) = (a * b) >> 16

If a * b is negative:
  Arithmetic >>:  sign-extends → correct negative result
  Logical >>:     zero-fills → huge positive number → wall projected off-screen
```

DOOM E1M1 player start is at (1056, -3616). Every calculation involving the player position was garbage. Every wall projected to Y = +billions.

The fix: four lines.

```cyrius
fn asr(val, bits) {
    if (val >= 0) { return val >> bits; }
    return 0 - ((0 - val) >> bits);
}
```

One operator. Four lines. The difference between a black screen and DOOM.

---

## The Comparison

In February 2026, Anthropic published "[Building a C Compiler with Claude](https://www.anthropic.com/engineering/building-c-compiler)": 16 parallel agents, ~$20,000, two weeks. The compiler produces 100,000 lines of Rust and can compile DOOM's C source.

| | Anthropic | AGNOS/Cyrius |
|---|----------|-------------|
| Agents | 16 parallel | 1 (+ 1 for testing/polish) |
| Cost | ~$20,000 (API) | ~$400 (subscription) |
| Duration | ~2 weeks | ~23 hours |
| Result | **Compiles** DOOM (C→Rust) | **Renders** DOOM (Cyrius-native, 129KB) |
| Binary | Not applicable | 129KB (5.4x smaller than original) |
| Language age | Rust (~10 years) | Cyrius (7 days) |
| Dependencies | Rust + LLVM + GCC + libc | Zero |

Both are genuine engineering achievements. They demonstrate different things: Anthropic proved parallel AI agents can produce a working compiler at scale. AGNOS proved a single developer with one agent can build a sovereign language and a game engine in a week.

---

## What Made It Work

**The 29KB seed.** The entire toolchain — compiler, test runner, benchmark system, fuzzer, package manager — bootstraps from 29KB. An 8ms compile means the edit-compile-test loop is faster than saving the file.

**vidya.** A curated reference library (36 topics, 11 languages, 396 examples) that teaches the agent how to implement anything in 30 seconds of research. Pointer support took minutes because the patterns were already documented.

**sakshi.** Structured tracing in every module. When the renderer produced a black screen, sakshi span timing showed exactly which function was consuming time and which was producing no output.

**The builder's QA instinct.** 20 years of game QA (Activision → Disney → enterprise) means bugs are found by observation, not guessing. The logical-shift bug was diagnosed by reading the output, not by stepping through a debugger.

**Fuzz testing.** Three fuzz harnesses found three bugs in 10 seconds that 74 unit tests missed. SIGFPE on degenerate BSP geometry, negative AABB width, division by zero in ray casting. Write the fuzz harness before you think the code is correct.

---

## Bugs Found and Fixed

| # | Bug | Root Cause | Fix |
|---|-----|-----------|-----|
| 1 | Black screen (no pixels drawn) | `>>` is logical, not arithmetic — negative coordinates became huge positives | `asr()` helper for all signed right shifts |
| 2 | Palette all zeros | `framebuf_set_palette` before `framebuf_init` wrote to null, then `init` re-allocated | Lazy init guards on both paths |
| 3 | Broken sign extension | `OR` bitmask operator precedence — `val | 0xFFFF0000` parsed wrong | Parentheses |
| 4 | Corrupted sprites | Shared WAD lump buffer overwritten during sprite rendering loop | Dedicated sprite read buffer |
| 5 | Wall shading reversed | Fake contrast E-W/N-S dimming was backwards | Swap the light offsets |
| 6 | BSP crash on random geometry | Division by zero in segment intersection | Division-free sign checks |
| 7 | BSP negative AABB | Inverted bounding box from random coordinates | `max(0, width)` guard |
| 8 | BSP ray overflow | Extreme coordinates overflowed fixed-point multiplication | Reduced-precision pre-shift |

Every bug found became a test case. Every test case prevents the same bug in every future project. The golden rule: every bug is a test case that didn't exist yet.

---

## What's Next

Alpha is feature complete. Beta is polish:
- Input tuning and collision edge cases
- Black Book audit — verify rendering against Fabien Sanglard's analysis
- Real hardware testing (bare metal Linux, then AGNOS kernel)
- The goal: boot AGNOS kernel → shell → `doom` → play

---

## Second Session: Plays, Hardened, Faster

Five days later, v0.24.2. The engine went from **renders DOOM** to **plays DOOM** — E1M1 end-to-end, menus, weapons, ammo, hitscan, keys, armor. A P(-1) audit fixed 5 CVE-class findings against historical DOOM vulnerability classes. BSP hit **1.0.0** — the first stable library in the Cyrius ecosystem.

And render_frame dropped from 2.9ms to **2.66ms** with zero engine changes, because Cyrius shipped rep movsb, LASE, short-circuit `&&`, and dead-code elimination during the session. **The compiler improved under the game.**

| | v0.17.0 | v0.24.2 |
|---|---|---|
| Binary | 129KB | 196KB (game grew) |
| render_frame | 2.9ms | 2.66ms (compiler grew) |
| Does | Renders DOOM | **Plays** DOOM |
| Security | Untested | P(-1), 5 CVEs fixed |

Per-session granularity lives in the [cyrius-doom field notes](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes/doom.toml).

---

## What This Proves

Every OS, every language, every platform eventually answers the question: can it run DOOM?

Cyrius doesn't just run DOOM. It rewrites DOOM smaller, hardens it against its own historical CVEs, and runs it at 2.66ms/frame with 91% tick headroom on a ten-day-old language. The engine plays, the WADs parse safely, the compiler is still improving underneath it, and BSP shipped 1.0.0 as the first stable library in the ecosystem. In a language that bootstraps from a 29KB seed that didn't exist eleven days before the first DOOM commit.

The walls render. The textures map. The sprites draw. The lighting shades. The pistol fires. The shotgun picks up. The keys unlock doors. The HUD updates. The WAD parser refuses malicious input. The frame finishes in 2.66ms. And the compiler that made it all possible weighs less than the game it compiled.

---

---

## References

- [vidya field notes](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes.toml) — 907 lines of real-time development documentation from inside the build
- [vidya content expansion](https://github.com/MacCracken/vidya/blob/main/docs/content-expansion-2026-04-08.md) — how 396 examples got written in one session
- [The 29KB Compiler vs The $20,000 Compiler](sovereign-compiler-vs-brute-force.md) — the compiler comparison
- [The Dandelion Core](the-2-dollar-sd-card.md) — what the compiler enables
- [Game Engine Black Book: DOOM](https://fabiensanglard.net/gebbdoom/) — Fabien Sanglard's engine analysis (primary reference)
- [Unofficial DOOM Specs](https://doomwiki.org/wiki/WAD) — WAD format documentation

## Screenshots

All screenshots from the April 8-9 sprint, in order of progression:

![First BSP render — green blob](https://github.com/MacCracken/cyrius-doom/blob/main/docs/screenshots/doom_e1m1_v1.png)
*v1: First BSP traversal. Wrong palette. The geometry is there — the colors aren't.*

![Palette working](https://github.com/MacCracken/cyrius-doom/blob/main/docs/screenshots/doom_e1m1_v2.png)
*v2: PLAYPAL loaded. Blue ceiling, grey walls, brown floor. Multiple wall segments at different depths.*

![Natural colors](https://github.com/MacCracken/cyrius-doom/blob/main/docs/screenshots/doom_e1m1_v3.png)
*v3: Correct palette indexing with sector light levels.*

![COLORMAP shading](https://github.com/MacCracken/cyrius-doom/blob/main/docs/screenshots/doom_e1m1_colormap.png)
*v4: Distance-based lighting. 34 COLORMAP levels. The corridor darkens as it recedes.*

![Wall textures and floor flats](https://github.com/MacCracken/cyrius-doom/blob/main/docs/screenshots/doom_e1m1_flats.png)
*v5: STARTAN wall textures. Floor flats. The E1M1 starting corridor is unmistakable.*

![Sprites](https://github.com/MacCracken/cyrius-doom/blob/main/docs/screenshots/doom_east_spr.png)
*v6: First sprites — armor pickups visible in the world.*

![Full HUD with weapon](https://github.com/MacCracken/cyrius-doom/blob/main/docs/screenshots/doom_e1m1_wpn4.png)
*v0.10.0+: Pistol in hand. Status bar. Health, ammo, armor, Doomguy face. This is DOOM.*

---

*Robert 'Cyrius' B. MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
