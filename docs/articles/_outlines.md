# Article Outlines — Pre-Draft Capture

> Planned articles with pre-committed framing. Outlines live here so the thesis, headline, trigger condition, and receipts don't drift out of memory between the decision moment (now) and the draft moment (when the receipts exist). Each outline lists the trigger that fires the article, the headline thesis, the section skeleton, and the specific receipts the article will deliver.
>
> **Not drafts.** These are skeletons. The full articles get written when their trigger fires. Outline drift is fine — *thesis* drift is the thing these files exist to prevent.

---

## 1. yantra knife article — *"Every other language draws the line before what you can see. Cyrius draws it after."*

**Status**: outline | **Trigger**: yantra M1 (Chromium CDP backend) live + benchmark vs Playwright-Python on identical workload

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

- [`yantra/docs/adr/0001-yantra-is-a-library-not-a-framework.md`](../../../Repos/yantra/docs/adr/0001-yantra-is-a-library-not-a-framework.md) — headline thesis in prologue, cross-linked to design-patterns.md §0
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

## 5. cyrius-braid knife article — *the JBlow-on-JBlow homage*

**Status**: outline | **Trigger**: `cyrius-braid` v1.0 (playable end-to-end, all worlds, art pass done)

### Provisional title (unlocked, options)

- *"Braid in Cyrius: a homage to the sovereign stance, from a stack that shipped first"*
- *"The Most Respectful Undermining in Software"*
- *"Braid-in-Cyrius"* — minimalist
- *"What 18 Years Buys You"* — 2008 Braid → 2026 Cyrius rebuild

### Headline thesis direction

Jonathan Blow spent 2014–2026 building Jai because he distrusted existing systems languages. In 2026 AGNOS / Cyrius shipped a sovereign systems language that self-hosts from a 29KB seed, in under a month of active work, for ~$400. As a gesture of respect *and* technical argument, cyrius-braid reimplements Blow's 2008 title — from observation, not source — in Cyrius. The game ships; the language shipped first.

The tone is homage, not attack. Braid is a great game; Blow is a serious practitioner. The sovereign-language receipt AGNOS offers is real, works, and is freely usable. If the rebuild lands well enough that it nudges Blow (or Jai's community, or any of the broader handmade-hero culture) toward Cyrius — that's the invitation implicit in the whole gesture.

### Section skeleton

1. **The Gesture** — what cyrius-braid is, what it isn't (not a port, not a clone, not a mod). The ADR-0001 / ADR-0002 stance in one paragraph each. Why this specific title: Braid is canonical, tractable, and Blow is the handmade culture's most visible refusal-practitioner.

2. **The Technical Bets** — time-rewind ring buffer, determinism under rewind-forward-rewind, puzzle-gated world progression, slot-loaded soundtrack. What the mabda / kiran / impetus / shravan / sankoch / sigil stack carried.

3. **Original Assets in the Spirit of the Original** — ADR 0002 in article form. What got newly painted, what got publicly-sourced, what didn't get shipped (the original score). Attribution transparency throughout.

4. **Receipts** — binary size, startup time, memory footprint, time-rewind buffer overhead, per-world load times. Comparison point: Braid's original published specs where Blow has disclosed them; otherwise versus a reasonable 2026 Unity / Godot / Bevy baseline for the same shape.

5. **The Meta-Argument** — what this rebuild says to the handmade-hero culture: *"the sovereign-language pitch isn't theoretical anymore. A language exists, it ships, a real game runs on it. Fork it, adopt it, or keep waiting on Jai — all three are defensible, only the third still costs you a decade."*

6. **Scope Discipline** — cyrius-braid is not a Braid-replacement. If Blow ships the Anniversary Edition, that's the canonical work. cyrius-braid is a parallel tribute. Its purpose is the gesture + the language demonstration, not market competition.

7. **What this invites** — a short section on the open-door posture. Cyrius is GPL-3.0, free to fork, specifically designed to be sovereign from anyone including AGNOS itself. If Blow, or any of the broader sovereignty-minded culture, wants to adopt it or fork it — that's the intended landing zone.

### Receipts the article delivers

- cyrius-braid binary size + startup time
- Time-rewind buffer overhead (MB per second of captured state; CPU per rewind-forward cycle)
- Full end-to-end playthrough performance (FPS, frame-time distribution)
- Consumer-matrix benchmark (mabda / kiran / impetus workload)
- Comparison to a 2026 Godot or Bevy baseline on the same mechanical workload (not to the original Braid binary, which we never reverse-engineer)

### Related (existing articles it extends)

- `memory-should-be-sovereign-too.md` — sit refusal piece; same series
- `why-gpu-belongs-in-the-stdlib.md` — mabda refusal piece; cyrius-braid is a mabda consumer
- `sovereign-compiler-vs-brute-force.md` — the $400 OS comparison; cyrius-braid is a receipt for "the language also runs real consumer software"

### Captured anchors

- [`cyrius-braid/docs/adr/0001-reimplementation-from-observation.md`](../../../Repos/cyrius-braid/docs/adr/0001-reimplementation-from-observation.md) — mechanics-from-observation thesis
- [`cyrius-braid/docs/adr/0002-original-assets-in-the-spirit-of-the-original.md`](../../../Repos/cyrius-braid/docs/adr/0002-original-assets-in-the-spirit-of-the-original.md) — asset-creation policy
- [`cyrius-braid/docs/design/README.md`](../../../Repos/cyrius-braid/docs/design/README.md) — art pipeline + soundtrack policy
- `shared-crates.md` — cyrius-braid registered under Non-Library Projects

### Marketing coda (optional)

The stream-donation distribution gag — time the v1.0 release around a Blow Twitch stream, drop a supporter tip with the GitHub URL and benchmark links, let the donation message ("*bro it does it better sorry — but hey, you can use it for FREE*") do its work. Aggressive recruitment dressed as a compliment dressed as a tip. If it lands, the Twitch clip *is* the article's launch asset.

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

*Last Updated: 2026-04-24*
