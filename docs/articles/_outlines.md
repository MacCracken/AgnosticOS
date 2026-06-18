# Article Outlines — Pre-Draft Capture

> Planned articles with pre-committed framing. Outlines live here so the thesis, headline, trigger condition, and receipts don't drift out of memory between the decision moment (now) and the draft moment (when the receipts exist). Each outline lists the trigger that fires the article, the headline thesis, the section skeleton, and the specific receipts the article will deliver.
>
> **Not drafts.** These are skeletons. The full articles get written when their trigger fires. Outline drift is fine — *thesis* drift is the thing these files exist to prevent.

---

## 1. yantra knife article — *"Every other language draws the line before what you can see. Cyrius draws it after."*

**Status**: **WRITTEN** 2026-06-16 → `draw-the-line-after.md` (mirror here; canonical in `yantra/docs/articles/draw-the-line-after.md`). Written at yantra 0.9.0 (all five backends live, API frozen for 1.0.0) — far past the M1 trigger. Receipts delivered: web ~3× vs Playwright (flow), mobile parity vs Appium (structural — both ride Appium), 0 consumer deps. | **Trigger** (met): yantra M1 live + benchmark vs Playwright on identical workload

### Headline thesis (locked)

> *"Every other language draws the line before what you can see. Cyrius draws it after."*

### Subtitle / hook

*UI automation as a library, not an ecosystem.* Or tighter: *The testing pyramid ends at your language boundary — except here.*

### Context this article writes against

Every mainstream language — Rust, Go, Zig, Swift, Python, JavaScript — treats UI automation as a third-party concern. Selenium, Playwright, Appium, Cypress, Puppeteer are all separate ecosystems with separate registries, separate maintainers, separate CI paths. The "language boundary" sits before the pixel surface in every case.

Cyrius doesn't. `lib/yantra.cyr` is first-party stdlib. A `.tcyr` file can drive a browser on day-one install with `cyrius test` as the runner.

### Sections

1. **The Category That Was Never Named** — UI automation is "automation of the visible surface." The industry's tools predated the category's name, so the category never got named. The line that every language draws is right before this unnamed category.

2. **What Every Language Does** — Tier table: unit tests (10 langs built-in), benchmarks (~5), fuzzing (~3), UI automation (**zero**). Nobody has crossed the last tier.

3. **Why the Line Is Where It Is** — Three structural reasons no mainstream language can cross: registry governance, small-core philosophy, captive-consumer absence. Not an accident; each language has a good reason it *can't* do this. Cyrius lacks all three constraints.

4. **How Cyrius Moves the Line** — stdlib-folded subsystems (mabda / sankoch / sigil / patra / yukti / yantra follow the same pattern). `cyrius distlib` as the mechanism. Solo governance as the permission.

5. **yantra Receipts** *(receipts-driven section — the numbers that prove the claim)*:
   - Chromium navigation-click-assert: yantra vs Playwright-Python, same workload, wall-clock latency
   - Binary size: yantra `.tcyr` test invocation vs Playwright+Node+Chromium
   - Dep count: yantra consumer (0 registry deps) vs Playwright consumer (1 dep → N transitive)
   - Auto-waiting hit rate: how often yantra's implicit-wait saved the test from flake

6. **Scope Discipline** — what yantra explicitly isn't (not a world competitor, not libgit2-style binding, not a framework). Same "What X Isn't" section shape as sit / mabda pieces.

7. **Where We Are** — at article-write-time, M1 is live, M2-M4 still gated on v5.7.x stdlib depth. Article honest about what's real vs what's pending.

### Receipts the article pre-commits to

| Metric | vs Playwright | Expected direction |
|--------|---------------|-------------------|
| Navigation-click-assert wall clock | ms per action | yantra lower or comparable |
| Binary + runtime install size | MB | yantra dramatically smaller |
| Transitive dep count | count | yantra 0, Playwright ~N |
| Cold-start `.tcyr` test execution | ms first run | yantra lower (no node startup) |

### Related (existing articles it extends)

- `memory-should-be-sovereign-too.md` (sit / git refusal — same shape)
- `why-gpu-belongs-in-the-stdlib.md` (mabda / wgpu refusal — same shape)
- `docs-go-stale-before-the-commit.md` (testing pyramid as context)

### Captured anchors (won't drift)

- [`yantra/docs/adr/0001-yantra-is-a-library-not-a-framework.md`](https://github.com/MacCracken/yantra/blob/main/docs/adr/0001-yantra-is-a-library-not-a-framework.md) — headline thesis in prologue, cross-linked to design-patterns.md §0
- [`design-patterns.md §0 Refusal as Architecture`](../design-patterns.md#0-refusal-as-architecture--the-master-frame) — thesis in the Examples list as a receipt bullet

---

## 2. sit receipts sequel — *follow-up to "Memory Should Be Sovereign Too"*

**Status**: **receipts captured** 2026-04-23 — article near-write-ready. | **Trigger**: effectively satisfied; sit has working tests (13/13), bench suite, fuzz (25K rounds no crashes), and head-to-head numbers vs git.

### Benchmarks in hand

- **Binary**: sit 593 KB static / git primary 4.4 MB / git total 7.4 MB across 183 binaries — **7.5× to 12× smaller**
- **Perf** (min ms, 10–20 runs): init 0.37–0.40× (sit wins), add small file 0.83× (sit wins — common case), commit 0.44–0.49× (sit wins), diff 0.52× (sit wins), log 1.05× (par), status 1.16× (par), add 1MB 11.44× (sit slower — named bottleneck: sigil software SHA-256 at ~16 MB/s vs git native-C; fix paths: SHA-NI intrinsics or streaming-hash I/O pipeline)
- **Sovereignty**: zero dynamic deps, one static binary, every layer first-party Cyrius
- **Correctness**: 13/13 tests, 25,000 fuzz rounds no crashes, git-SHA-256 blob framing byte-compatible
- **Canonical source**: sit's own `benchmarks-git-v-sit.md` (live doc, re-run cadence = sit release cadence)

### Framing observation (process architecture — worth leading with)

**patra open/close per command costs less than the fork+exec+libc startup git pays per command.** git's many-small-binaries installation shape (183 binaries per install) was a 2005 Linux-dev tooling choice for an era that no longer applies the same way; sit's single-static-binary + direct-syscall-to-storage is cheaper per-command *because* it refused that shape. The 183-binary install refusal paid twice — smaller install footprint (7.5–12× on binary size) AND faster command startup (visible in init / add / commit wins, including on add-small-file where there's no hashing advantage to explain the win).

This is the sovereignty thesis applied at process architecture, not just at dependency chains. Worth leading with in the receipts piece because the binary-size table alone doesn't convey it — readers see 7.5× smaller and might assume it's a memory-footprint win only. The per-command-startup story is a separate dimension, and it's the one that shows up in latency numbers for operations that have nothing to do with hashing or file handling. **Add-small-file at 0.83× is the single cleanest receipt for the architecture claim** — there's no hashing bottleneck to confound it, and it's still faster.

### Provisional title (unlocked, options)

- *"sit Remembers Itself"*
- *"smriti, Receipted"*
- *"The First Commit That Wasn't Git's"*
- *"sit, Post-Receipts"*

### Headline thesis direction

The sit article ("Memory Should Be Sovereign Too") committed to a specific set of receipts. This article delivers them. Not a rehash of the refusal — a receipts piece, with numbers.

### Sections

1. **The Commit That Wrote Itself** — the self-hosting moment: sit's own history committed through sit. Timestamp, commit hash, short narrative. The engineering milestone in two paragraphs.

2. **Per-Operation Benchmark Matrix**:
   - `sit init` vs `git init`
   - `sit add` vs `git add` on representative file sets
   - `sit commit` vs `git commit`
   - `sit log` vs `git log`
   - `sit diff` vs `git diff`
   - `sit clone` vs `git clone`
   - Matrix rows by operation, columns by sample size (small repo / AGNOS genesis repo / cyrius repo)

3. **Layer Comparisons** *(each dep against its C incumbent)*:
   - sankoch vs zlib 1.3.1 on sit's pack-file path (per-object compression ratios, throughput)
   - sigil vs OpenSSL on sit's SHA-256 hashing path
   - patra vs loose-objects+packfiles on sit's object-store path

4. **CVE-Class Audit** — git's 2019-2025 CVE history broken down by class (shell injection, path traversal, memory corruption, hash collision). How many of those categories sit eliminates by construction (Cyrius bounds checks + first-party hashing + no shell-out).

5. **What sit Didn't Need to Do** — the refused inheritance. Submodules absent. Hooks-as-shell absent. `.gitattributes` drama absent. LFS-as-bolt-on absent. Porcelain-vs-plumbing split absent. Each "absent" is a CVE class not owned.

6. **What sit Does Differently** — opinionated design points the object model enabled once accretion was refused.

7. **Where We Are** — sit's own repo now hosted in sit. shared-crates.md says v1.0.0 (when it does). The post-receipts moment.

### Receipts the article delivers

Quantitative, with CSV history from `bench-history.sh` at sit M_receipts milestone:

- Per-operation latency table (sit vs git, 6+ operations)
- Compression layer comparison (sankoch vs zlib on AGNOS-representative corpus)
- Hashing layer comparison (sigil vs OpenSSL on sit's hot path)
- Storage layer comparison (patra vs libgit2 object-store on equivalent workloads)
- Total dep chain: sit (0 C deps) vs git (zlib + OpenSSL + libcurl + ...)
- Binary size: sit vs git + libgit2 + zlib + OpenSSL

### Related

- `memory-should-be-sovereign-too.md` (the refusal piece this is the sequel to)
- `port-ledger-volume-1.md` (series pattern)

### Captured anchors

- [`memory-should-be-sovereign-too.md`](memory-should-be-sovereign-too.md) — the pre-commitment of the exact receipts this article delivers
- Memory: [`project_sit.md`](/home/macro/.claude/projects/-home-macro-Repos-agnosticos/memory/project_sit.md) — "**Article**: Memory Should Be Sovereign Too shipped 2026-04-23. Names the receipts the sequel commits to..."

---

## 3. mabda receipts sequel — *follow-up to "Why GPU Belongs in the Stdlib"*

**Status**: outline | **Trigger**: the `[deps.wgpu]` FFI bridge line disappears from mabda's effective build path (native GPU driver at parity for the consumer set)

### Provisional title (unlocked, options)

- *"The Last FFI Bridge Closed"*
- *"GPU in the Stdlib, Continued"*
- *"wgpu, Receipted Out"*
- *"mabda: Native"*

### Headline thesis direction

"Why GPU Belongs in the Stdlib" committed to receipts — per-consumer benchmarks, driver-roundtrip latency, SPIR-V compile time, memory-layout comparisons. This article delivers them. The headline is that the wgpu line is gone from `cyrius.cyml` — the exception is closed.

### Sections

1. **The Line That Disappeared** — the `cyrius.cyml` diff where `[deps.wgpu]` vanishes. Commit timestamp, narrative, two paragraphs. The engineering milestone.

2. **Per-Consumer Benchmark Matrix**:
   - soorat (rendering): frame time, draw-call throughput, pipeline-switch latency
   - kiran (game engine): ECS-to-GPU upload, per-frame scene composition
   - ai-hwaccel (capability enumeration): cold-start device query, capability cache hit rate
   - joshua (AI simulation): buffer round-trip latency, compute dispatch throughput
   - cyrius-doom (reference): frame time (previously 2.59ms/frame baseline)

3. **Driver-Roundtrip Latency** — wgpu-FFI path vs native-driver path, per operation. Where the FFI overhead showed up and by how much.

4. **SPIR-V Compile Time** — naga (through wgpu) vs first-party SPIR-V emitter on representative shader sets.

5. **Memory-Layout Comparisons** — wgpu's buffer-usage enumeration vs mabda-native's. Alignment-constraint handling. Device-local vs host-visible policy.

6. **What the Exception Cost** — honest accounting: wgpu lived in mabda from vN to vM. During that window, AGNOS shipped *with* a Rust-toolchain-linked C dep. Worth naming the cost candidly: what didn't work during the FFI era (what fixes had to go through wgpu's release cadence, what security windows stayed open).

7. **Scope Discipline** — what the native mabda still doesn't do and why. Cross-vendor GPU abstraction was explicitly refused; this article reaffirms that and shows the consumer set hasn't needed it.

### Receipts the article delivers

- Full consumer-matrix benchmark table (5 consumers × 4+ operations each)
- `cyrius.cyml` diff showing the wgpu block removed
- Bundled binary size delta (Rust toolchain / wgpu deps / naga removed from the build-chain footprint)
- CVE-class comparison: what Rust-toolchain / wgpu / naga CVE classes the native path retires

### Related

- `why-gpu-belongs-in-the-stdlib.md` (the refusal piece this is the sequel to)
- `memory-should-be-sovereign-too.md` (the sit sequel's pattern)
- `cyrius-vs-rust-benchmarks.md` (existing GPU benchmarks this extends)

### Captured anchors

- [`why-gpu-belongs-in-the-stdlib.md`](why-gpu-belongs-in-the-stdlib.md) — the pre-commitment
- Memory: FFI-exception policy entry in Cyrius FFI policy

---

## 4. TLS native knife article — *the fourth knife in the series*

**Status**: outline | **Trigger**: Cyrius v5.9.7 closes. `lib/tls.cyr` stops being an OpenSSL dynlib bridge; X25519 + ChaCha20-Poly1305 + record layer + handshake all in pure Cyrius.

### Provisional title (unlocked, options — pair with subheader)

- *"The Last Dynlib Bridge"* — parallel to "The Last C Hole" / "The Last FFI Bridge"
- *"TLS Belongs in the Stdlib"* — parallel to "Why GPU Belongs in the Stdlib"
- *"No More OpenSSL"* — direct cut
- *"Trust, Without Borrowed Code"*

### Headline thesis direction

OpenSSL (via `dynlib` to `libssl.so.3` / `libcrypto.so.3`) was the last FFI bridge in the Cyrius stdlib — scoped, named, closing per the v5.9.0–v5.9.7 roadmap. The bridge is closed now. The stdlib has no FFI in it. Same shape as the three earlier knife pieces: refusal → receipts.

### Sections

1. **The One FFI Left** — before v5.9.x, `tls.cyr` was the last exception in the Cyrius FFI policy. Named, documented, scoped. Same status mabda's wgpu exception had, and sit's git-holding-sit had.

2. **What OpenSSL Costs You** — CVE history (Heartbleed, POODLE, etc.), build-toolchain drag, version-skew drama (1.0 → 1.1 → 3.0 migrations), dep-chain footprint.

3. **Why dynlib Was the Right Compromise (At the Time)** — the FFI exception was deliberate, not an oversight. `lib/tls.cyr` didn't try to hide it; the FFI was named at the API boundary. This article doesn't disrespect the compromise — it records the close of it.

4. **Why dynlib Isn't the Right Compromise Anymore** — Cyrius v5.9.x maturity: slices and effect annotations (`#pure`, `#io`, `#alloc`) landed first, which is exactly what TLS code wants. The language is ready in ways it wasn't at v5.0.

5. **The v5.9.x Arc** — X25519 + ChaCha20-Poly1305 + record layer + handshake. Each patch a landing.

6. **Scope Discipline** — TLS 1.3 only. Not 1.2. Not 1.0. Not the legacy RSA-kex paths. This is "reference don't mimic" applied to TLS: the modern cipher suite is load-bearing; the legacy compatibility surface is not.

7. **Receipts** — handshake latency vs OpenSSL, record layer throughput, cert verification, binary size delta, CVE-class audit.

### Receipts the article delivers

- Handshake benchmark (pure-Cyrius vs libssl) across handshake types
- Record layer throughput (MB/s encrypted / decrypted)
- Cert verification latency (trust store walk)
- Cipher suite coverage table
- Stdlib build-chain footprint: libssl.so.3 + libcrypto.so.3 removed from required runtime
- CVE classes retired (the historical Heartbleed-shape issues that cannot exist in Cyrius by construction)

### Related

- `memory-should-be-sovereign-too.md` (sit / git — structurally identical refusal)
- `why-gpu-belongs-in-the-stdlib.md` (mabda / wgpu — structurally identical refusal)
- `sovereign-compiler-vs-brute-force.md` (original refusal template)

### Captured anchors

- Cyrius roadmap v5.9.0–v5.9.7 arc (pure-Cyrius TLS 1.3)
- Cyrius FFI policy doc (tls.cyr as the last exception)

---

## 5. *Brynn's Tale* launch article — *original mythic-modern game shipped on a sovereign stack*

**Status**: outline | **Trigger**: `cyrius-brynns-tale` Beat 1 demo (Act 1 World 1 playable end-to-end; v0.3.0 milestone; ~2026-06-21 solstice). Full v1.0 launch article comes later when all three acts ship; this Beat 1 article is the *demo* article.

> **Pivot context** (2026-04-26): this slot was previously *"Braid in Cyrius: a homage to the sovereign stance"* — a JBlow-on-JBlow gesture tied to the cyrius-braid Braid-reimplementation framing. On 2026-04-26 the project pivoted to original IP (*Brynn's Tale*); the article slot pivots with it. The article is no longer about Braid or Blow — it is about *Brynn's Tale* on its own terms (mythic-modern register, three-act diptych-becoming-triptych, mechanic-as-narrative-form). The sovereignty-stack / sovereign-language receipt argument carries forward; the homage framing does not.

### Provisional titles (unlocked, options)

- *"Brynn's Tale: a mythic-modern game on a sovereign stack"*
- *"What Mechanic-as-Narrative Looks Like Without Engine Drag"*
- *"How a 1.5-Person Team Shipped Six Time Mechanics in Cyrius"*
- *"The Time Mechanic Is the Storytelling Form"* — design-thesis-forward
- *"Brynn's Tale, Beat 1: First Act Playable"* — demo-launch literal

### Headline thesis direction

*Brynn's Tale* is an original mythic-modern game built on a tightly-coupled mechanic-narrative spine. Brynn uses time-rewind to save her dying husband; the cost is herself. Act 1 is told **backward** (Memento-form), Act 2 forward and irreversible (Bleed mechanic for witness-of-the-past, no rewind), Act 3 NG+ as the integrated being THEM after a Phoenix-rebirth — three acts where mechanic and storytelling form are one thing on each side, not separable.

That design framework runs on AGNOS / Cyrius — a sovereign systems language that self-hosts from a 29KB seed, ships zero external dependencies, and has built and shipped both the OS and the game. The article's argument is two-track: *here is the design framework on its own terms*, and *here is what shipping it on a sovereign stack costs and gains*.

The sovereignty-stack argument carries from previous articles in the series; the design-framework argument is new. Both land as receipts, neither as manifesto.

### Section skeleton

1. **The Premise** — Brynn, her husband, the trade. *Brynn's Tale* in one paragraph. The hook is mythic-modern stakes: lover's-sacrifice, contemporary setting, time-mechanic as narrative-form. Not a Braid homage; not a fairytale lift; not a prestige-indie grief walking-sim. The bridge between cosmic and reachable.

2. **The Three Acts** — Act 1 (backward, rewind, Memento-form descent). Act 2 (forward, Bleed + irreversible, Orpheus-as-survivor). Act 3 (NG+, full toolkit, alchemical *rebis* after Phoenix-rebirth). Each act's mechanic IS its mythic position. Pointer to the ADR set (0003–0007) for the design-framework deep-dive; this article surfaces, doesn't duplicate.

3. **The Technical Bets** — time-rewind ring buffer (six variants on Brynn's side; deterministic across rewind-forward-rewind), Bleed visual-register coupling on the husband's side (the aesthetic shifts when he bleeds; mechanic and visuals are the same thing), full-toolkit composition in NG+ (deterministic rewind+Bleed compounding). What the mabda / kiran / impetus / shravan / sankoch / sigil stack carried.

4. **Bosses Are Selectively Souls-like** — soft-fail everyday + hard-fail bosses. Brynn's external mythic figures (threshold-keepers + Yama). The husband's internal mythic figures (grief-aspects + shadow-self requiring **die-to-merge**, not defeat). The "YOU DIED" screen used straight at the chosen-death moment that triggers Phoenix-rebirth.

5. **Receipts** — binary size, startup time, time-rewind buffer overhead, Bleed transition latency, NG+ verb-composition determinism. Comparison point: a 2026 Godot or Bevy baseline on the same mechanical workload (not to any specific other game).

6. **The Sovereignty-Stack Argument** — what shipping this on Cyrius costs and gains. No Unity license fee, no engine drag, no FFI bridge. The whole stack from kernel to GPU is first-party. Mechanic-design questions ("can we make the Bleed mechanic feel right at 60 FPS while also recording for determinism?") get answered by writing a stdlib patch, not by negotiating with a black-box engine. The sovereign-language receipt pays back specifically when the design wants something the engine doesn't already do.

7. **What This Invites** — open-door posture. Cyrius is GPL-3.0, free to fork, designed to be sovereign from anyone including AGNOS itself. The sovereignty-minded creative community is the audience.

### Receipts the article delivers

- cyrius-brynns-tale binary size + startup time + memory footprint
- Time-rewind buffer overhead (MB per second of captured state; CPU per rewind-forward cycle) — six variants
- Bleed transition latency + visual-register-shift overhead
- Full Act 1 World 1 playthrough performance (FPS, frame-time distribution)
- Consumer-matrix benchmark (mabda / kiran / impetus / shravan workload)
- Comparison to a 2026 Godot or Bevy baseline on the same mechanical workload

### Related (existing articles it extends)

- `memory-should-be-sovereign-too.md` — sit refusal piece; same series
- `why-gpu-belongs-in-the-stdlib.md` — mabda refusal piece; *Brynn's Tale* is a mabda consumer
- `sovereign-compiler-vs-brute-force.md` — the $400 OS comparison; *Brynn's Tale* is a receipt for "the language also runs real consumer software with a complete design framework"

### Captured anchors

- [`cyrius-brynns-tale/docs/adr/0003-pivot-to-original-mythic-modern-ip.md`](https://github.com/MacCracken/cyrius-brynns-tale/blob/main/docs/adr/0003-pivot-to-original-mythic-modern-ip.md) — pivot to original IP (the meta-decision that supersedes ADRs 0001 + 0002)
- [`cyrius-brynns-tale/docs/adr/0004-two-perspective-diptych-structure.md`](https://github.com/MacCracken/cyrius-brynns-tale/blob/main/docs/adr/0004-two-perspective-diptych-structure.md) — three-act structure
- [`cyrius-brynns-tale/docs/adr/0005-verb-sets-per-half.md`](https://github.com/MacCracken/cyrius-brynns-tale/blob/main/docs/adr/0005-verb-sets-per-half.md) — rewind / Bleed+irreversible / THEM toolkit
- [`cyrius-brynns-tale/docs/adr/0006-boss-tier-philosophy.md`](https://github.com/MacCracken/cyrius-brynns-tale/blob/main/docs/adr/0006-boss-tier-philosophy.md) — selective Souls-like; what bosses are
- [`cyrius-brynns-tale/docs/adr/0007-phoenix-rebirth-and-rebis-integration.md`](https://github.com/MacCracken/cyrius-brynns-tale/blob/main/docs/adr/0007-phoenix-rebirth-and-rebis-integration.md) — die-to-merge, Phoenix-rebirth, *rebis*, rubedo
- [`cyrius-brynns-tale/docs/design/README.md`](https://github.com/MacCracken/cyrius-brynns-tale/blob/main/docs/design/README.md) — art direction, music direction, asset-licensing standards
- `shared-crates.md` — cyrius-brynns-tale registered under Non-Library Projects

---

## 6. Structuring Major Work During Release Cycles — *infrastructure-first, tailing-bugs, and ports as compass*

**Status**: outline | **Trigger**: v5.11.x cycle close (lets the article land "two cycles into the pattern" — v5.10.x three-arc parallel + v5.11.x stdlib-annotation closeout — rather than mid-cycle handwaving). Anchored 2026-05-11 at v5.11.0 open.

### Headline thesis (locked)

> *"REAL TYPE SYSTEM didn't ship a feature. It shipped the permission for the next three years of features to be writable. That's the shape of a release cycle done right."*

### Subtitle / hook

*Why the v5.10.x cycle had to land two heavy arcs in parallel, why one bug class surfaced three times, and why consumer-filed deviations are signal, not noise.*

### Context this article writes against

The industry default for managing a language compiler's release cycle is the *feature-roadmap* shape: one cycle, one or two named features, ship-and-iterate. That works when downstream consumers don't really care which order capabilities arrive, and when the language has decoupled subsystems that don't compose.

Cyrius doesn't. Every capability in the stack composes through the type system and the ABI surface. **You cannot ship a typed-simd ABI without first having type vocabulary to describe `f64v2` at parse time. You cannot enforce type discipline at call sites without the vocabulary to annotate stdlib functions. You cannot do bare-metal codegen without struct-byval discipline + REAL TYPE SYSTEM enforcement + typed-simd primitives in the same compiler.**

So the cycle structure has to be *infrastructure-first* — the foundational arc lands BEFORE the consumer-facing arc that depends on it. v5.10.x is the canonical example of this pattern at work, and the v5.10.x retro tells us *how* it worked, *what tailed it*, and *what role consumer deviations played in shaping it.*

### Sections

1. **The Wrong Pattern: Feature-Roadmap Cycles** — Industry default. Rust's 6-week train, Go's release notes, Zig's per-minor highlight reel. Works when subsystems are loosely coupled. Doesn't work when every consumer composes through the type system. Frame: "you cannot ship feature B until infrastructure A is in the same compiler."

2. **The v5.10.x Setup: Two Heavy Arcs in Parallel** —
   - REAL TYPE SYSTEM (Phase 1-5 across v5.10.1-.26) — type vocabulary + bulk annotation + call-site checking + registry overload dispatch + default-on enforcement with silent-regression repair.
   - Typed-simd value-type ABI (Phase 1-11 across v5.10.28-.39) — `f64v2`/`f64v4` as first-class primitives, end-to-end consumer ABI across five backends (XMM0 SysV / V0 NEON / r0+r1 cx / inheritance for macho-arm / PE retptr), value-form param ABI, overload dispatch + typed wrappers closing the arc.
   - **The dependency is real**: the typed-simd ABI Phase 1 *could not have started* without the type vocabulary from REAL TYPE SYSTEM Phase 1B. The parser literally has nothing to dispatch on without `f64v2` being a named type.

3. **What "Infrastructure-First" Means** — Generalize. Historical pattern enumeration:
   - Multi-platform closed (v5.5.x) → unblocked Apple Silicon Mach-O + Windows PE self-host work
   - Optimization arc Phase O1 instrumentation (v5.6.x) → enabled per-phase profiling much later in v5.10.0
   - Sandhi-fold (v5.7.0) → unblocked TLS work via sandhi 1.3.x consumer filings hitting v5.10.13/.21/.27/.34
   - REAL TYPE SYSTEM (v5.10.x Phase 1-5) → unblocked typed-simd ABI (v5.10.28-.39)
   - Typed-simd ABI (v5.10.28-.39) → substrate for future Cyrius-native codec work (tarang's eventual dav1d/FFmpeg-lane entry; currently C-FFI as placeholder)
   - Stdlib annotation arc (v5.11.x in flight) → enables the *enforcement* layer of REAL TYPE SYSTEM at compile time
   - Bare-metal + rv64 (v6.2.x reservation — was v5.12.x, retired 2026-05-12 at tight-close) → needs typed-simd + RTS enforcement + struct-byval ABI all in the same compiler

4. **The Tailing Bugs Pattern: Locname-Staleness Three Surfacings** — One bug class surfaced THREE distinct times across v5.10.x as the typed-simd arc churned the parser locname slots:
   - **v5.10.35 — PARSE_SIMD_EXT 3-arg intrinsics**: stash slots from EFLSTORE didn't clear locname; stale "r" from a prior fn's parse caused FINDLOCAL to pick up a stash-slot pointer-value instead of the real var. Fixed with `_SIMD_STASH` helper that clears `locname[idx] = -1`.
   - **v5.10.38 ship verification — ptyp 89-91 missed**: the v5.10.35 fix patched PARSE_SIMD_EXT but f64v_add/sub/mul live at a *different* dispatch (ptyp 89-91 in parse_expr.cyr). v5.10.35's fix missed them. The bug stayed *latent* because pre-v5.10.39 lib/simd.cyr's pointer-form-only wrappers had a stable locname layout that didn't trigger the stale collision.
   - **v5.10.39 fix-in-slot**: the v5.10.39 rewrite of lib/simd.cyr (adding value-form siblings, doubling fn count, churning locname slots) made the stale-collision reliable. Same `_SIMD_STASH` pattern applied to ptyp 89-91; bisection diagnosis isolated to lib/simd.cyr body, not to overload dispatch.
   - **Lesson**: when fixing a bug class, *audit for duplicates across the codebase*. parse_expr.cyr has multiple intrinsic dispatch sites. A single-site fix is a half-fix.
   - **Frame for the article**: heavy infrastructure arcs *churn* the substrate. Latent bug classes that depended on the substrate's stability *will* surface once the substrate moves. Plan for this — don't be surprised by it. The cycle's discipline has to include "audit for duplicates" as a first-class step on any bug-class fix during a major arc.

5. **Ports as Compass: Deviation Is Often Information** — Consumer-filed issues are *not* interruptions to the planned arc. They are *signal* about which parts of the substrate need exercising:
   - **TLS surface completion** (4 slots: v5.10.13, .21, .27, .34) — driven entirely by sandhi 1.3.x consumer filings. Each filing exposed a missing primitive (typed wrappers around libssl, session cache + 0-RTT, staged-connect timing, client-side acceptance-status). The pre-planned v5.10.x arc list didn't include TLS at slot-0 — the consumer compass added it.
   - **hisab keystone-consumer-driven SIMD expansion** (v5.10.16, .17) — added dot/scale/axpy primitives + paid 3.5 years of latent aarch64-stub + x86-codegen debt that `programs/simd_expand_test.cyr` had hidden because it was never wired into `check.sh`. Without hisab's pressure, the debt would still be latent.
   - **kavach 3.1.1 raw-syscall workaround → v5.11.0 P1 wrappers** — kavach's `SYS_FCHMOD` raw-syscall workaround was the *symptom*; the v5.11.0 P1 work (6 sandbox syscall wrappers, async-signal-safe, both backends) was the *cure*. The cure couldn't have been correctly specified without the consumer having field-tested which 6 syscalls actually mattered.
   - **install.sh symlink collision** (user-side discovery during v5.10.37 work) — `cp -L` + parallel symlink + `set -e` left `~/.cyrius/bin` stale across version bumps; symptom looked like "starship.toml corruption" from user perspective. Two version-discovery paths (cyrius --version vs cyrius-prompt-info) had diverged silently. *Wasn't on any roadmap.* Closeout fix pinned at v5.10.46.
   - **Frame**: a planned arc tells you *what you think you need*. Consumer deviations tell you *what you actually need*. Both are real signal. The discipline is to *accept* the deviation when it's pointing at the substrate (TLS, SIMD primitives, syscall wrappers) and to *defer* it when it's pointing past the substrate (a new feature unrelated to the arc).

6. **The Cycle-Structure Discipline That Made v5.10.x Work** — What kept two heavy arcs + four port-driven sub-arcs + one bug-class-with-three-surfacings coherent across 50 patches in 5 days:
   - **v5.10.0 P(-1) hardening as cycle opener** — foundation, not feature. The cycle starts by reinforcing the rules.
   - **Premise-check at slot entry** — v5.7.x heritage. Empirical re-test of pinned assumptions before committing scope. v5.10.45 (struct-byval re-cast) + v5.10.49 (PE pin debunked entirely) both paid for themselves twice.
   - **Pre-planned split as replacement for lazy deferment** — "A+B in .38, C as .39" specified at slot entry, not after the fact. 11-phase typed-simd arc closed in 12 slots with no mid-flight reshuffles.
   - **Cross-arch propagation in-slot** — every ABI change verified on pi (aarch64 Linux) / ecb (macOS Mach-O) / cass (Win64 PE) BEFORE ship. Not deferred. v5.10.37 f64v4 LDUR Q imm9 overflow caught at slot-entry test; fix landed in-slot.
   - **Closeout pass as the LAST patch of the minor** — mechanical fail-fast checks → judgment passes → compliance → doc sync. v5.10.50 was a pure-closeout slot; cc5 byte-identical to .49.
   - **Slot acceptance principle** — no bookkeeping-only slots. "Updated 1 doc to plan next steps" is HELL NO. The minor-open chapter (v5.11.0) lands real code (kavach P1 wrappers) plus the roadmap restructure, not the restructure alone.

7. **What This Means for v5.11.x and v6.x** — Pattern-extension to the in-flight and reserved cycles (v5.12.x retired 2026-05-12 at the tight-close decision; its scope moved into v6.x platform expansion):
   - **v5.11.x** is the *enforcement layer* atop v5.10.x's vocabulary layer AND the final 5.x minor. Stdlib annotation arc Phase 1 (alloc/vec/fmt/freelist/fnptr/result/tagged/assert) at v5.11.1 starts wiring the type vocabulary into stdlib enforcement. The P2 consumer wave (daimon aarch64 epoll_wait, bote primitives) is the deviation surface — accept the ones that exercise the substrate. Closes as a .68/.69 pair (heap-map reorg + optional dep fold).
   - **v6.2.x** (was v5.12.x) is downstream of *both* prior cycles. Bare-metal target needs RTS enforcement + struct-byval ABI + typed-simd substrate + stdlib annotation. Each was a separate arc in v5.10.x or v5.11.x. None of them could have been delivered alongside bare-metal itself — which is why the tight-close decision pushed bare-metal across the major boundary into v6.x.
   - **The pattern repeats**: infrastructure-first arc lands → enables the next-tier consumer-facing work → consumer-filed deviations surface tail bugs and missing primitives → arc closes with retroactive fixes baked into the substrate → next cycle's infrastructure-first arc starts from a higher floor.

### Receipts the article pre-commits to

- v5.10.x cycle stats: **50 patches in 5 days** (2026-05-06 → 2026-05-11), THREE completed arcs + compile-perf miniarc + TLS pin + PE premise debunk, api-surface 2,769 → 2,876 (+107 public fns), cc5 741,048 → 804,472 B
- Locname-staleness three-surfacing timeline: v5.10.35 (PARSE_SIMD_EXT) → v5.10.38 (ptyp 89-91 missed) → v5.10.39 (fix-in-slot)
- TLS port-driven sequence: v5.10.13 (typed wrappers) → .21 (session cache + 0-RTT) → .27 (staged-connect) → .34 (client acceptance-status) — all sandhi 1.3.x consumer-filed
- agnosys 1.1.12 cascade: v5.10.7, .8, .10, .12, .14 (5 follow-on slots driven by v5.9.x carry-forward)
- v5.11.0 P1 receipts: 6 kavach sandbox syscall wrappers (`sys_fchmod`, `sys_setresuid/gid`, `sys_prctl`, `sys_seccomp`, `sys_execveat`), both x86_64 + aarch64 backends, async-signal-safe, 6 new syscall enum entries per backend
- Infrastructure-first chain: v5.5.x multi-platform → v5.6.x optimization → v5.7.0 sandhi-fold → v5.10.x three-arc → v5.11.x annotation + close → **v6.2.x bare-metal** (each cycle's deliverable is the next cycle's substrate; v5.x → v6.x boundary is the "frozen vs gaining capability" line per the 2026-05-12 tight-close decision)

### Related (existing articles it extends)

- [`what-justifies-a-stdlib-foldin.md`](what-justifies-a-stdlib-foldin.md) — closest companion. Process article on the foldin gate framework. This article does the same for cycle structuring: when to start a major arc, when to interrupt for ports, when to close out.
- [`port-ledger-volume-1.md`](port-ledger-volume-1.md) — port sequencing as architecture. This article extends to: ports also *spur deviation* in the compiler cycle, and that's a feature not a bug.
- [`sovereign-compiler-vs-brute-force.md`](sovereign-compiler-vs-brute-force.md) — cc5 size as discipline. This article uses cc5 cycle-growth (741→804 KB across v5.10.x) as a *visible* signal that infrastructure-first arcs cost real bytes and that's correct.
- [`what-5.5.x-taught-5.6.x.md`](what-5.5.x-taught-5.6.x.md) — cycle-to-cycle inheritance pattern. Direct ancestor of this article's thesis at a smaller-scope cycle.
- [`docs-go-stale-before-the-commit.md`](docs-go-stale-before-the-commit.md) — cycle discipline shapes doc currency. Adjacent: the state.md / doc-health.md ledger pattern is itself a manifestation of cycle-aware doc structure.
- [`design-patterns.md §2 Staged Optimization / No Deferred Debt`](../design-patterns.md#2-staged-optimization--no-deferred-debt) — through-line layer for the pattern.
- [`design-patterns.md §8 Pain → Procedure`](../design-patterns.md#8-pain--procedure-encode-lessons-as-first-class) — locname-staleness lesson encoded as a slot-discipline rule fits this pattern exactly.

### Captured anchors (won't drift)

- [`cyrius/CHANGELOG.md` v5.10.0 → v5.10.50 entries](https://github.com/MacCracken/cyrius/blob/main/CHANGELOG.md) — primary receipt for all v5.10.x claims
- [`vidya/content/cyrius/field_notes/compiler/retros/v510x.cyml`](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes/compiler/retros/v510x.cyml) — narrative retro, source of the "three locname-staleness surfacings" framing
- [`vidya/content/cyrius/field_notes/compiler/retros/foldin_arc_v57_v59.cyml`](https://github.com/MacCracken/vidya/blob/main/content/cyrius/field_notes/compiler/retros/foldin_arc_v57_v59.cyml) — pattern-companion for stdlib-foldin arc structure
- [`docs/development/state.md` v5.11.x cycle section + v5.10.x retro section](../development/state.md) — current state-of-the-cycle pointer
- [`docs/articles/what-justifies-a-stdlib-foldin.md`](what-justifies-a-stdlib-foldin.md) — process-article precedent and structural template

### Working sub-thesis candidates (sharpen at draft time)

- *"Infrastructure isn't a phase. It's a prerequisite."*
- *"The cycles where you ship a feature are downstream of the cycles where you shipped the permission to write it."*
- *"Latent bugs surface when the substrate moves. Plan for the audit, not just the fix."*
- *"Consumer-filed issues are the compass. Pre-planned slots are the map. You need both."*
- *"A cycle that closes cleanly didn't avoid the deviations — it absorbed them."*

---

## 7. Methodology is the Trap — *direct reply to Lars Faye, "Agentic Coding is a Trap"*

**Status**: ✅ **SHIPPED 2026-05-11** — full article at [`methodology-is-the-trap.md`](methodology-is-the-trap.md). Outline retained below as the trace for how the locked thesis + section skeleton + receipt-stack pre-commitments were drafted before the article landed (the pre-commit-then-ship pattern this outlines.md file exists to demonstrate). Pair-ship with outline #6 (still outline-only) intended at v5.11.x close. | **Original Trigger**: paired ship with outline #6 (*Structuring Major Work During Release Cycles*) so the methodology-public-argument piece and the methodology-internal-cycle-structure piece land together. Alternative trigger: a second high-traffic anti-agentic piece in the same vein where AGNOS's existence proof gains rhetorical leverage. Anchored 2026-05-11 against Faye's article + HN #48002442 + Tuszynski's reply.

### Headline thesis (locked)

> *"Tools don't make the craftsman. Method does. The same chisel makes a simple box or a home — whether the result is one or the other is downstream of how the chisel is held, not which chisel is in the drawer."*

### TLDR (locked)

The "trap" Faye names is real. It's just not located where he points it. The failure mode he describes — cognitive debt, LGTM reviews, vibe coding, vendor-stranded teams — is **methodology failure**, not **tool failure**. Same agentic-coding stack produces $20K throwaway capability-demos in one shop and a $400 self-hosting OS in another. The differentiator is method. Faye's prescription (demote agents to reference tools; rely on personal vigilance) treats the symptom; AGNOS's existing trio of articles (*Sovereign Compiler vs Brute Force*, *Your CLAUDE.md Isn't Lying*, *Micro-Work and Agent Deferment*) already treats the cause.

### Subtitle / hook

*Same chisel. Different result. The variable was never the tool.*

### Context this article writes against

[Faye's article](https://larsfaye.com/articles/agentic-coding-is-a-trap) + [HN thread #48002442](https://news.ycombinator.com/item?id=48002442) + the broader May 2026 wave of "AI coding is destroying engineers" pieces. The genre treats agentic coding as a unit and indicts the unit. AGNOS exists as the existence-proof that the unit *isn't a unit* — it's a stack with a tool layer and a methodology layer, and the methodology is what determines whether the output is craft or junk.

### Sections

1. **The Aphorism** — Tools don't make the craftsman. Open with the chisel image: junior carpenter and master carpenter with identical chisel kits; output diverges by craft, not by chisel. Apply to agentic coding: same Claude Code instance, same agent capabilities, same context window. The variable is method.

2. **What Faye Got Right** — Honest reading. Atrophy is real if you don't engage. Cognitive debt is real when there's no audit trail. Hallucinations exist. Vendor outages happen. The diagnosis is accurate. The prescription is what misses.

3. **The Methodology Variables** — Enumerate the four AGNOS methodology choices that distinguish $400 from $20K:
   - **Sequential over parallel** — 3 agents (Meta / Language / Kernel) one at a time, not 16 in parallel. Tightens the decision loop; the developer holds the vision.
   - **Reference-staged over context-fresh** — Vidya (36 topics, ~200K words pre-distilled) so the agent walks in senior, not as a perpetual junior. Cost-per-token plummets when rediscovery is staged away. *Struct support* (pre-Vidya) took hours of false starts; *pointer support* (post-Vidya) shipped in minutes with 48/48 first-run test pass. Same dev, same agent, same week.
   - **Single-focus-per-patch over vibe-shipping** — Each commit is one complete thought. No silent slot-narrowing. *"When stuck, ASK, never slip"* as the load-bearing CLAUDE.md rule. Reduced-scope patches carry an explicit *"reduced scope because: <reason>"* line in the CHANGELOG. That's the audit trail Faye's "LGTM teams" don't keep.
   - **Five-layer surface over single-CLAUDE.md** — CLAUDE.md / state.md / memory / ADRs / docs each carry a specific lifecycle. The agent isn't asked to navigate a wishlist; it follows index pointers.

4. **Faye's Prescription, Examined** — "Demote agents to reference tools; rely on personal vigilance" treats LLMs as opt-out. Won't scale. **Personal vigilance is exactly the failure mode** — humans skim, forget, ship-pressure-collapse, swap personnel. Tuszynski's reply names it: institutional artifacts that survive personnel changes are the answer (tests, types, linters, runtime hooks, code review, append-only mistake logs). AGNOS shipped that institutional surface eight months before the debate landed — and named the layers explicitly: state.md is the volatile-state institutional artifact; memory files are the cross-session behavior-anchor institutional artifact; ADRs are the per-decision institutional artifact; design-patterns.md is the through-line institutional artifact.

5. **The Receipt Stack** —
   - Cyrius v5.11.0, 50-patch v5.10.x cycle in 5 days, three completed compiler arcs (typed-simd ABI / REAL TYPE SYSTEM / struct-byval ABI). Three arcs, not three vibe-checks.
   - Self-hosting compiler, byte-identical reproduction, 29 KB hand-auditable seed → 804 KB cc5 at v5.11.0 across two-and-a-half months of agentic-driven development.
   - The locname-staleness bug class surfaced three times across v5.10.x — and was **caught all three times** because the methodology demanded duplicate-audit on bug-class fixes (v5.10.x retro, vidya field-notes). The "LGTM team" caricature Faye describes would have shipped the first fix and let the latent collisions sleep until customer-reported.
   - One developer. Three sequential agent sessions. $400. Every design decision human. Vidya for context. No vibe coding.

6. **The Same Chisel Cuts Both Ways** — Anthropic's $20,000 parallel-Claude C compiler is the same agentic-coding methodology *with different choices*: horizontal scaling, no reference-staging, no sequential discipline, no single-focus patches. It's not "agentic coding done wrong" — it's a *different methodology*, made with the same tool, optimizing for a different goal (throughput / capability demo, not sovereignty). Both work for what they're trying to do. Neither is "the trap." The trap is the shop that doesn't specify the methodology and still expects engineering output.

7. **What the Trap Actually Is** — Refusing to admit that *method* is a load-bearing variable. The trap is treating "agentic coding" as monolithic — pro or con. The discipline is to specify the methodology, then measure the output. AGNOS specifies; Anthropic-C-compiler specifies; Faye's "trap" is whatever shop doesn't specify.

8. **Closing — Pick Your Chisel** — Same tool, two outputs. Box or home. The aphorism repeated as the close. The trap is method-shaped, not tool-shaped. Choose the method; the output follows.

### Receipts the article pre-commits to

- The $400-vs-$20K cost line (already shipped in [`sovereign-compiler-vs-brute-force.md`](sovereign-compiler-vs-brute-force.md)).
- The Vidya Effect contrast (struct support without Vidya vs pointer support with Vidya — same dev, same agent, same week, same compiler; minutes vs hours).
- The locname-staleness three-surfacings catch (already shipped in [`state.md` v5.10.x retro](../development/state.md)).
- The cyrius CLAUDE.md "When stuck, ASK" rule as the explicit anti-vibe-coding discipline.
- The five-layer surface specification (already shipped in [`your-claude-md-isnt-lying.md`](your-claude-md-isnt-lying.md)).
- v5.10.x → v5.11.0 cycle close mid-write — 50 patches in 5 days, three completed arcs, self-host byte-identical.

### Related (existing articles it extends)

- **[`sovereign-compiler-vs-brute-force.md`](sovereign-compiler-vs-brute-force.md)** — the receipt-piece this article argues *from*. The new article is the methodology argument that the existing piece's numbers already support. (Already updated 2026-05-11 with a direct-reply section pointing here.)
- **[`your-claude-md-isnt-lying.md`](your-claude-md-isnt-lying.md)** — the surface-discipline piece. Names the five-layer structure that makes the receipt possible.
- **[`micro-work-and-agent-deferment.md`](micro-work-and-agent-deferment.md)** — the slot-discipline piece. Names "ask, don't slip" as the explicit anti-vibe rule.
- **[`docs-go-stale-before-the-commit.md`](docs-go-stale-before-the-commit.md)** — the doc-discipline companion. State-doc rot is the same drift class that Faye misdiagnoses as cognitive debt.
- **[`memory-should-be-sovereign-too.md`](memory-should-be-sovereign-too.md)** — the cross-tool-vendor sovereignty argument applied at the memory layer. Faye's vendor-lock-in concern lives here.
- **[`design-patterns.md §8 Pain → Procedure`](../design-patterns.md#8-pain--procedure-encode-lessons-as-first-class)** — through-line. The locname-staleness catch, the "ask, don't slip" rule, the five-layer surface — each is a lesson encoded as procedure.

### Captured anchors (won't drift)

- [Lars Faye, *Agentic Coding is a Trap*](https://larsfaye.com/articles/agentic-coding-is-a-trap) — primary respondent
- [HN thread #48002442](https://news.ycombinator.com/item?id=48002442) — public-discussion anchor
- [Mateusz Tuszynski, *Agentic Coding Isn't the Trap. Supervising From Your Head Is.*](https://www.mpt.solutions/agentic-coding-isnt-the-trap-supervising-from-your-head-is/) — friendly co-respondent; same methodology-not-tools diagnosis from a different angle (institutional-artifact framing)
- [Anthropic, *Building a C Compiler with Claude*](https://www.anthropic.com/engineering/building-c-compiler) — the $20K side of the same chisel
- [`docs/articles/sovereign-compiler-vs-brute-force.md`](sovereign-compiler-vs-brute-force.md) — the $400 side; carries the receipt this article argues from

### Working sub-thesis candidates (sharpen at draft time)

- *"The same chisel makes a simple box or a home."*
- *"Tools don't make the craftsman. Method does."*
- *"$20K and $400 used the same tool. The variable was method."*
- *"'Vibe coding' isn't an indictment of agents. It's an indictment of methodology absence."*
- *"The trap is refusing to specify the method, then expecting the output to specify itself."*
- *"Personal vigilance is the failure mode, not the cure. Institutional artifacts are the cure."*

### Pairing with outline #6

Outline #6 covers cycle-structuring methodology *internally* — how Cyrius cycles structure major arcs + tail bugs + port deviations. Outline #7 covers methodology *as a public argument* — replying to Faye and the broader anti-agentic wave. Same thesis at two surfaces. Best shipped paired so they reinforce.

---

## Topical backlog (surfaced by 2026-04-23 research survey)

Four topics that current (2024–2026) AI-engineering blogs are covering where AGNOS is on-thesis but not-yet-covered. Listed here so they don't fall out of memory; not yet promoted to full outlines because the receipts (or the provocation) aren't ripe. Each gets 2–3 sentences plus a trigger condition.

### Agent observability — *"Your observability stack was built for services, not agents"*

**Status**: topical backlog | **Trigger**: libro or phylax ships a named "agent trace format" that differs intentionally from OpenTelemetry's service-trace assumptions. Knife-article shape.

AGNOS runs three coordinated agents and has `libro` (audit chain) + `phylax` (threat detection) as first-party observability infrastructure — but has never framed that as agent-observability publicly. Langfuse / Datadog / OpenTelemetry dominate the 2025 conversation on tracing agent runs; none of them are built against a sovereign stack. Refusal target: "the observability stack we have was designed for request/response services, not for agents that branch, pause, recall memory, and consume context windows." On-thesis adjacent to `docs-go-stale-before-the-commit.md` but deserves its own piece.

### Sequential-not-parallel agents — *"Parallel Agents Were the Wrong Default"*

**Status**: topical backlog | **Trigger**: fourth+ comparison data point (beyond the $20K vs $400 receipt from the sovereign-compiler article) showing sequential-3-agent workflows outperforming parallel-N-agent workflows on AGNOS-scale problems. Knife-article shape.

Anthropic's *"Building a C compiler with a team of parallel Claudes"* is the canonical 2025 piece on parallel multi-agent orchestration. `sovereign-compiler-vs-brute-force.md` already answers that piece with the $20K-vs-$400 receipt for a sequential three-agent workflow. A dedicated knife article would name the sequential-vs-parallel architectural choice as a deliberate stance (Meta / Language / Kernel agents, one at a time), not an accident of solo development, and argue the coordination-cost math explicitly.

### MCP sandboxed — *"Stock MCP is Underprotected"*

**Status**: topical backlog | **Trigger**: kavach + t-ron + bote end-to-end demonstration showing a sandbox-escape attack class that stock MCP deployments would have permitted. Knife-article shape; potentially security-research tone.

AGNOS has `bote` (MCP core), `t-ron` (MCP security), `kavach` (sandbox execution with 500× lifecycle win post-port) — all first-party, all Cyrius-native, all composable into an MCP deployment with kernel-enforced isolation. Stock MCP deployments ship without this. Refusal target: "MCP tools ship without sandbox discipline because the MCP spec stops at the protocol layer — here's what kernel-enforced sandbox + capability-drop wrappers look like on an MCP tool surface." Adjacent to the 144-tools daimon story that's never been written up.

### Sigil SHA-NI — *"Closing the Last Perf Gap"*

**Status**: topical backlog | **Trigger**: sigil ships SHA-NI hardware intrinsics (Intel SHA Extensions on x86_64 / ARMv8 Crypto Extension) and sit's `add 1MB` benchmark closes to parity or better with git.

Short-form knife-article subpiece. The sit receipts piece (§2 above) names software SHA-256 at ~16 MB/s as the one honest perf gap where sit loses to git (11.44× on `add 1MB`). This article ships when sigil closes the gap — same two-article pattern as the main knife series (refusal pre-commits the receipt; sequel delivers it). Probably 600–1,000 words, more technical microcase than full refusal-register piece. Fits [`design-patterns.md §8 Pain → Procedure`](../design-patterns.md#8-pain--procedure-encode-lessons-as-first-class) — honest gap named in sit article → sigil fix scheduled → receipt shipped.

### Supply-chain sovereignty reframing — *"The Refusal Was Also a Supply-Chain Argument"*

**Status**: topical backlog | **Trigger**: next xz-utils-scale supply-chain incident, OR a new-reader-reach push where the existing refusal narrative needs a different entry point. Retrospective / synthesis shape, not knife-article.

The xz-utils backdoor of 2024 produced a wave of supply-chain-focused writing across 2024–2026 that AGNOS's existing articles intersect with thematically but never name explicitly. *"No crates.io, no libgit2, no LLVM, no OpenSSL"* is a supply-chain argument as much as it is a sovereignty argument — the two stances are the same move with different audiences. Reframing the existing receipt list as supply-chain defense would land with readers who care about the xz class of risks but who haven't engaged with the sovereignty framing. Not a new-technical-content article; a new-audience-packaging article.

---

## 8. Shell on Iron — *the iron-boot bring-up story as a public receipt*

**Status**: outline | **Trigger**: keyboard input lands on iron (xHCI Phases 2–5 of [`planning/usb-hid-keyboard-driver.md`](../development/planning/usb-hid-keyboard-driver.md) — at that point the shell is *typeable*, not just visible, and the receipt is complete enough to publish). Anchored 2026-05-15 against the iron-validation milestone of agnos 1.30.0 + the 29-attempt arc captured in [`iron-nuc-zen-log-mvp.md`](../development/iron-nuc-zen-log-mvp.md) and [`iron-bring-up-process.md`](../development/iron-bring-up-process.md).

### Headline thesis (locked)

> *"A sovereign OS reaching shell-on-iron in 2026 is the headline. The walk that got us there is the receipt."*

### Subtitle / hook

*29 attempts. 16 repair letters. 11 of them deleted. One sovereign UEFI bootloader. One shell prompt on a NUC AMD framebuffer at 4:45 PM on a Friday.*

### Context this article writes against

The "is AGNOS real" question has had a series of answers — first the kernel boots in QEMU; then the toolchain self-hosts byte-identical; then 30+ ports complete; then the sovereign UEFI bootloader replaces GRUB. **The shell-on-iron milestone is the answer that converts believers from "this is impressive scaffolding" to "this is a real OS."** Most readers of the prior receipts haven't internalized what changed in 2024–2026 around UEFI firmware that makes booting a sovereign OS on modern hardware non-trivial. The article makes that change visible by walking the actual walls.

### Sections

1. **Where the walk started** — the kernel that compiled, booted clean in QEMU, and crashed on iron. Last data point of the previous article (*The Road to Iron* private vidya entry). Wall: the QEMU/iron divergence under strict-W^X UEFI was not in any public reference.

2. **GRUB walked itself off the platform** — multiboot2-EFI + strict-W^X is dead under OVMF 2024+. `grub_relocator64_efi_boot` self-patches its own `.text`; the writes fault under NX-marked PE pages. Linux distros don't see this because `linuxefi` uses a different relocator; AGNOS hit the cliff because we used the multiboot path. **The architectural conclusion**: AGNOS needed its own UEFI bootloader (gnoboot) — *the industry had already arranged around this; we got the bill that everyone else paid quietly over 2023–2024.*

3. **Path C — what every modern OS already does** — the 80-byte boot-info struct in RDI is the shape Linux EFI stub / FreeBSD `loader.efi` / OpenBSD `BOOTX64.EFI` / Windows `winload.efi` / Limine all converged on. AGNOS did the same shape in Cyrius. The Cyrius PE32+ emit was the novel part; the architecture is 10+ years old.

4. **The bisector ladder + the rabbit hole** — Attempts 9–27 of the iron-boot walk. Repairs A through N. The eleven-attempt sequence chasing a bug in a memory-isolation test block that turned out to be post-MVP work breaking pre-MVP boot. The **premise-audit gate** that codified out of that pain ("3+ diagnostic rounds without resolving → grep prior research before instrumenting more"). The discipline accreted.

5. **Attempt 28 — MVP spine alive on iron** — the kernel completes its full init spine end-to-end: GDT → TSS → IDT → APIC → timer → SMP → keyboard ISR → paging → PMM → KASLR → heap → ACPI → PCI → VFS → SYSCALL → stack canary → test procs → scheduler armed → idle loop survived → userland exec → kybernet-launch. Closed-beta gate held. Photo.

6. **Attempt 29 — shell visible on iron** — Repair (P) for the cyrius non-zero-gvar-init bug surfaced. The cleanup pass that landed in the same session (cp_fb cells stripped, kprint mirror to fb, FB_CONSOLE_Y0 80 → 8). Burn at 4:45 PM rendered the full kernel log + the `agnos>` prompt on the framebuffer. Photo.

7. **What's left** — USB keyboard input. Modern UEFI doesn't emulate PS/2 over XHCI post-EBS. Native XHCI + USB-HID-boot driver, in scope. Phase 1 (PCIe discovery + capability reads) landed same-session as the cycle close. **This article ships when the rest of the driver lands and the prompt becomes typeable on iron.**

8. **The methodology receipt** — what this walk proves about the AGNOS process: that 29 iron attempts produced a working OS not because of personal heroics but because the methodology bent without breaking. The repair-letter convention emerged. The premise-audit gate codified. The CMOS-as-post-mortem-channel discipline solidified. The dev-setup constraint got memory-pinned after three wasted serial-cable recommendations. Tools were the same throughout; the methodology surface kept extending where the load required it. **Direct line to *Methodology is the Trap*: this is method working under stress, in the most physically real failure-mode the project has yet encountered.**

### Receipts the article pre-commits to

- The cycle-close kernel size: 273,816 B at 1.30.1 [Unreleased] (with xHCI Phase 1 staged); 1.30.0 closed at 266,312 B
- The 29-attempt timeline (commit-verifiable in `agnos` git log)
- The 16 repair letters A–P, with 11 of them (Repairs F–N + diagnostic-only stamps) deleted at Repair (O)
- Photo: `iron-nuc-zen-photos/attempt-28-mvp-spine-alive.jpg` (spine alive)
- Photo: `iron-nuc-zen-photos/attempt-29-shell-logging-cleanup.jpg` (shell + coherent log)
- Pointer to `iron-bring-up-process.md` for the generic pattern that this arc generated
- Pointer to vidya field-notes `kernel.cyml` entries `the_road_to_iron` + `shell_on_iron` for the agent-facing version of the same story

### Cross-captures

- `iron-bring-up-process.md` (the durable process pattern; this article is the narrative receipt that pattern was extracted from)
- `methodology-is-the-trap.md` § *Method Accretes Where Method Fails* (the premise-audit gate cited there is one of this article's central receipts)
- vidya `kernel.cyml` entries (the agent-facing version — companion, not duplicate)

---

## Smaller planned articles (backlog — may or may not land)

These are listed in memory ([`project_article_backlog.md`](../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_article_backlog.md)) and carry their own future slot. Not part of the knife-article series; distinct genre.

### HANDOFF.md methodology

*Agent coordination pattern.* Short piece on the `HANDOFF.md`-as-synchronization-artifact pattern — the contract-moves-with-code move first surfaced in vyakarana → owl and now live across AGNOS repos. Engineering-doc genre, not knife-article register.

### CYML-vs-TextMate — Refusal §9 microcase

*Reference-don't-mimic at format-design scale.* Tight 400–800 word piece on why CYML's grammar format is not TextMate's and not tree-sitter's. Microcase of the Refusal §9 pattern. Doesn't need full-length treatment — a single worked example of "incumbents define the problem, not the solution."

---

## Capture discipline

- **Thesis is locked** before the article is written. The outline captures the thesis so it can't drift.
- **Receipts are pre-committed.** The outline lists specific benchmarks / comparisons / metrics the article will carry. When the trigger fires, those receipts are the article's spine.
- **Trigger is named.** Each article has a specific "this is ready to write when…" condition. No article gets drafted pre-trigger (the refusal-piece counterpart already did that work).
- **Cross-captures** in ADRs and `design-patterns.md` entries exist so the framing survives outside this file too — this file is the primary index, not the only anchor.
- **Point at live data, don't mirror figures.** When an article will carry benchmark numbers, version counts, binary sizes, test counts, or other state figures that come from a live canonical source (a project's `benchmarks-X.md`, its `state.md`, a CHANGELOG), the outline **points at that source with a re-run-cadence note** rather than duplicating the current snapshot. Between outline-time and publish-time, those numbers shift; pointing-at-live lets the drafter pull fresh data from the authoritative source. The trade: slightly more work at draft-time. The payoff: no accidentally-outdated figures in published articles. This is the [*Docs Go Stale Before the Commit*](docs-go-stale-before-the-commit.md) thesis applied to the outline layer — lock the durable thing (thesis, section skeleton, architecture observations), float the volatile thing (numbers).

---

*Last Updated: 2026-05-15* — outline #7 marked shipped; outline #8 (*Shell on Iron*) added against the iron-validation milestone of agnos 1.30.0.
