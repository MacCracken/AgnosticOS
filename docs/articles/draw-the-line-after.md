# Every other language draws the line before what you can see. Cyrius draws it after.

> *UI automation as a library, not an ecosystem.*
>
> **Canonical source:** [`yantra/docs/articles/draw-the-line-after.md`](https://github.com/MacCracken/yantra/blob/main/docs/articles/draw-the-line-after.md) — this is the published mirror.

Pick any mainstream language and look at where its standard library stops. Rust,
Go, Zig, Swift, Python, JavaScript — every one of them draws a line, and the line
sits at the same place: right before the pixel surface. Unit tests? In the box.
Benchmarks? Often. Fuzzing? Sometimes. Driving a real browser or a real phone and
asserting on what a user would actually see? **Out of the box, every time.** That
last tier is always someone else's ecosystem — Selenium, Playwright, Appium,
Cypress, Puppeteer — with its own registry, its own maintainers, its own runner,
its own CI path.

Cyrius draws the line one tier later. `lib/yantra.cyr` is first-party. A `.tcyr`
file drives a browser or a device with `cyrius test` as the runner — the same
runner the unit tests already use. No second framework, no second runner, no
second CI path.

This is the receipts piece for [ADR 0001 — yantra is a library, not a
framework](https://github.com/MacCracken/yantra/blob/main/docs/adr/0001-yantra-is-a-library-not-a-framework.md).
The ADR makes the claim; this makes it pay.

## 1. The category that was never named

"UI automation" is a tool name, not a category name. The category is *automation
of the visible surface* — the same testing impulse as unit/integration tests,
just aimed at what a human would see. But the tools (Selenium, 2004) predated any
attempt to name the category, so the category got swallowed by its first vendor.
Every language since has inherited the assumption that this tier is *foreign* —
that it lives outside the language by nature.

It doesn't live outside by nature. It lives outside by habit.

## 2. What every language does

The testing pyramid, by where the stdlib line falls:

| Tier | Languages with it built-in |
|------|----------------------------|
| Unit tests | ~all (Go, Rust, Zig, Python, JS via runner, …) |
| Benchmarks | several (Go, Rust, Cyrius, …) |
| Fuzzing | a few (Go, Rust, Cyrius, …) |
| **UI automation of the visible surface** | **Cyrius** |

Nobody else crossed the last tier. Not because it's impossible — because the
incumbent ecosystems are *good enough* that no language team ever had reason to
absorb the capability. The line held by inertia, not by difficulty.

## 3. What it costs you to live across the line

When the capability is foreign, every test that touches the UI pays an ecosystem
tax:

- **A second runner.** `pytest` *and* Playwright's runner; `go test` *and* a
  WebDriver harness. Two ways to run tests, two failure surfaces, two configs.
- **A dependency tree.** A Playwright consumer installs one package that pulls a
  Node runtime and a managed browser download — hundreds of MB and a transitive
  graph you don't audit. A yantra consumer adds **zero** registry dependencies:
  `dist/yantra.cyr` is vendored, the transports are first-party Cyrius, the
  browser/driver is one you already run.
- **A separate CI path.** The UI suite gets its own job, its own caching, its own
  flake budget — because it's a different toolchain than the rest of the build.
- **A cold start.** Node spins up before the first action. yantra's `.tcyr` is a
  compiled binary that connects and goes.

None of this is Playwright being bad. Playwright is excellent. It's the *position
of the line* that imposes the tax — and the tax is unavoidable as long as the
capability is across it.

## 4. How Cyrius moves the line

Same mechanism as the rest of the sovereign stdlib: a subsystem gets folded in
behind a first-party API, built on first-party transports, shipped as one file.
mabda did it for the GPU (refusing the wgpu "borrow the incumbent" shape), sit
for version control, sigil for signatures — yantra does it for the visible
surface. The transports are owned end to end (CDP over an in-tree WebSocket;
WebDriver/Appium over the stdlib `sandhi` HTTP/RPC layer; **no FFI**), so there's
no C library smuggling the ecosystem back in through the basement.
`cyrius distlib` is the packaging mechanism; solo governance is the permission to
absorb a tier the committee-run languages never will.

## 5. Receipts

All five backends are live and exercised by yantra's own e2e suite in CI:
Chromium (CDP), Chrome/Firefox/WebKit (WebDriver), Android (Appium/UiAutomator2),
iOS (Appium/XCUITest). The numbers below are reproduced, never fabricated — the
incumbent columns come from `scripts/parity-playwright.mjs` (web) and
`scripts/parity-appium.py` (mobile), run on the same box, same workload.

**Web — yantra (CDP) vs Playwright (Chromium), same `data:` workload:**

| Operation | yantra | Playwright | |
|-----------|-------:|-----------:|--|
| navigate | ~19 ms | ~19 ms | parity (both bounded by Chromium's load) |
| eval (querySelector) | ~0.3 ms | ~0.6 ms | ~2× |
| type | ~0.6 ms | ~2.9 ms | ~5× |
| **flow** (navigate+click+assert) | **~21 ms** | **~67 ms** | **~3×** |

The flow win is real and it's the honest headline: speaking CDP directly, with no
framework client in the middle, is ~3× faster on the round trip that matters.

**Mobile — yantra vs Appium-Python, same app + same Appium server:**

| Operation | yantra | Appium-Python | |
|-----------|-------:|--------------:|--|
| source (Android) | ~224 ms | ~188 ms | parity |
| source (iOS) | ~455 ms | ~459 ms | parity |

And here's the honest part the receipts force: **mobile is parity, not a win** —
because *both* clients ride the same Appium server, so the device round trip
dominates and client overhead is noise. yantra doesn't beat Appium on speed
because it hasn't yet *moved the line* on mobile the way it has on web: Appium is
still the transport. The mobile win today is **structural** — one `.tcyr`, one
runner, zero extra deps — not a stopwatch win. (Owning the transport below Appium
is a named post-1.0 direction; that's where mobile speed numbers would diverge.)

The two structural receipts hold on every backend:

- **Dependencies:** consumer adds **0** registry deps (vendored `dist/yantra.cyr`
  + a browser/driver you run) vs Playwright's 1-package → Node + managed-browser
  graph.
- **Runner:** `cyrius test` for UI tests *and* unit tests — one invocation, one
  failure surface, one CI path. No node cold-start before the first action.

## 6. What yantra is not

The line moved, but not infinitely. yantra is **not**:

- **a world competitor** — not trying to out-feature Playwright's recorder, trace
  viewer, network interception, or device farm. It's the verbs, not the universe.
- **an FFI binding** — not libgit2-shaped, not "wrap the incumbent." Every
  transport is first-party Cyrius. The whole point is refusing that shape.
- **a framework** — it ships no runner, no config schema, no CI plugin. The
  moment an abstraction wants to become a framework, it gets pushed back to
  library shape. `cyrius test` is enough.

Auto-waiting is the one Playwright idea copied on purpose — every action waits for
the element to be actionable before operating, which kills the most common flake
class at the source. Copy the good decision; refuse the rest of the framework.

## 7. Where we are

yantra is **1.0.0 — stable**. All five backends are live and gating in CI;
auto-teardown + structured errors, the device matrix, docs + examples, and a
security pass with sigil-verified cert pinning are done. The public API (46
verbs) is frozen — additive only from here. Web parity is ~3×; mobile parity is
honest parity with a structural win.

The line every other language draws is a choice they stopped questioning. Moving
it one tier later isn't a trick — it's just refusing to inherit the habit.

---

*Related: [Why the GPU belongs in the stdlib](why-gpu-belongs-in-the-stdlib.md)
(mabda / wgpu refusal — same shape) · [Memory Should Be Sovereign
Too](memory-should-be-sovereign-too.md) (sit / git refusal). Thesis cross-linked
from [`design-patterns.md §0 — Refusal as
Architecture`](../design-patterns.md#0-refusal-as-architecture--the-master-frame).*
