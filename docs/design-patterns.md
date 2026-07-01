# AGNOS Design Patterns

> **Status**: Outline / accretion document — pending GA retrospective.
> **Last Updated**: 2026-05-28 (added three new pattern-instance stubs after the 1.36.x refactor / 1.37.x extent / 1.38.x JBD2 arcs: per-bite smoke discipline (§2 + §8 instance), kashi-style parallel-agent extraction (§0 instance at the work-allocation layer), dedicated refactor cycle before heavy arcs (§2 inter-cycle instance); appended a third bite-decomposition-cadence example noting the JBD2 9-bite-in-a-day run). Earlier 2026-05-22 sweep added: multi-source convergent prior-art audits, audit-before-iron-burn, bite-decomposition cadence; corrected stale `cc5 → cyc` references to actual `cc5 → cycc` rename that landed at Cyrius v6.0.0 on 2026-05-19; refreshed kernel-size anchors.
> **Purpose**: Document the recurring cognitive patterns behind AGNOS decisions — the through-lines that produced many specific choices across many repos. This is the *interpretation* layer.

## What This Doc Is (And Isn't)

- **Not ideology** — that's [`philosophy.md`](philosophy.md) (sovereignty, Temple framing, Hermetic role).
- **Not per-decision rationale** — that's the ADRs in each repo.
- **Not dated events** — that's [`history.md`](history.md) and [`timeline.md`](timeline.md).
- **Not per-release change lists** — that's `CHANGELOG.md` in each repo.
- **Not working rules for agents** — that's `CLAUDE.md` files.

This is the layer that lets a cold reader in 2030 reconstruct *why* the decisions fit together as a system — not just what each one was. Receipts preserve the *what*. The interpretation lives here.

## How to Use This Document

- Each section names a pattern, describes it briefly, gives examples, and points to where it's elaborated (article / ADR / memory / CLAUDE.md rule).
- Add a section when a new pattern surfaces — don't wait for GA.
- Keep entries brief; detail lives in the linked artifacts.
- At GA this outline becomes the spine of the full retrospective, expanded with hindsight commentary and arc framing.

---

## 0. Refusal as Architecture — The Master Frame

**Pattern.** AGNOS's outcomes — small binaries, zero deps, short compile times, tiny API surfaces, clean scope — are not engineered goals. They are *consequences* of a consistent refusal to support dead legacy. Every layer of an incumbent system exists to keep something alive that is no longer alive: a hardware generation no longer sold, a paradigm no longer practiced, a compatibility contract with a caller no longer running. Most projects port that scaffolding forward. AGNOS refuses to port it forward. The receipts are shadows cast by things that were never inherited.

**Patterns §1–§9 are all instances of this.** The numbered patterns describe specific *shapes* of refusal — refuse redundant layers, refuse to defer optimization debt, refuse incumbent architecture, refuse author-journey names, refuse the applier role, etc. This pattern names the master move: **the architecture itself is refusal.**

**Examples — each receipt traces to a refused inheritance.**
- **Cyrius 29 KB seed, zero deps.** Refused the Rust bootstrap chain — a dead-legacy graph supporting every architecture, license boundary, and paradigm Rust has ever targeted.
- **kybernet 14× smaller than systemd.** Refused cgroup-v1 support, sysv compatibility, 20 years of unit-file accretion. All scaffolding for paradigms no one still runs fresh.
- **hoosh 40 crates → 0, 70× compile.** Refused the Python-dominant-inference-stack era. Its scaffolding supports an ecosystem AGNOS isn't in.
- **kavach 448 crates → 1, 500× sandbox lifecycle.** Refused pre-Landlock sandboxing (seccomp workarounds, cgroup isolation tricks). Dead once Landlock is a first-class primitive.
- **ark 4× smaller than cargo.** Refused serde + format! + alloc/dealloc as the baseline dep-graph paradigm.
- **AGNOS kernel ~571 KB at v1.31.7 / 40+ subsystems.** Refused Linux's decomposition, which carries driver models and device support spanning 30 years of hardware most users never touch. **Iron-validated**: MVP gate at Attempt 68 (v1.30.9, typeable shell on archaemenid), storage arc closed at Attempt 90 (v1.31.6, real Linux ext4 mounted on NVMe NAND).
- **mabda v3 ~3× smaller API than wgpu.** Refused pre-2018 GPU hardware support. VMA's 20 K lines exist to support every GPU-memory combination since 2016. wgpu's 7 buffer variants carry DX9 / OpenGL shape that nothing new uses. 30-stage pipeline bitmask carries transform-feedback, conditional-rendering, and legacy fixed-function stages no modern workload hits.
- **yantra in Cyrius stdlib — UI automation as a library, not an ecosystem.** Refused the inherited "UI automation is a third-party concern" default that Selenium, Playwright, Appium, Cypress, and Puppeteer all ride. Every other mainstream language draws its own boundary short of the pixel surface — Rust, Go, Zig, Swift, Python, JS all expect you to pull a separate registry dep when `.tcyr`-style tests need to drive a browser or a mobile device. The headline: ***"Every other language draws the line before what you can see. Cyrius draws it after."*** Stdlib-folded UI automation is the receipt; the refused inheritance is the entire ecosystem-as-governance-boundary pattern.
- **Librarian role (§5).** Refused extending into applier — which inherits the scope-creep drift that kills every sovereignty project.
- **Single source of truth (§4).** Refused maintaining multiple copies of the same fact. Drift is dead-sync support.

**Why refusal is load-bearing.** Every incumbent is a carcass of every generation it was meant to serve. Each layer exists to keep something alive: a hardware class no one ships anymore, an OS version no one runs, a language feature no one writes, a security model no one deploys fresh. Most projects port those layers forward on the reasoning that *"we can't break compatibility with the dead thing."* But the dead thing is not watching. The carcass is just code someone has to build, test, ship, teach, debug, and pay for.

The refusal move: **confirm what is actually alive; refuse to carry the rest.** You don't cut the 20 K-line allocator — you never write it, because the hardware it was supporting has been unplugged. You don't delete 40 Python crates — you never add them, because the Python inference era isn't what AGNOS is shipping into. You don't subtract systemd's compat layers — you never inherit them.

The receipts — 14×, 10.8×, 500×, 59×, 4×, 248 KB, 29 KB, 3× smaller API — are not accomplishments. They are the *measurement of what AGNOS refused to support.* The number gets large when the thing being refused is large.

**How to apply.** Before porting, writing, or designing anything: enumerate what the incumbent shape is keeping alive. For each item, ask *"is this actually alive in AGNOS's target world?"* If not, refuse to inherit it. The smaller API, fewer deps, faster builds, and cleaner scope fall out automatically. You aren't engineering subtraction — you are declining to inherit.

**How the refusal operates — interrogation.** Refusal is not passive. It is *active interrogation* of every inherited layer. Every dep, API, file format, build step, config convention, and architectural decision must justify itself with a **living reason**. The following are **not accepted answers:**

- *"Because it's always been that way."*
- *"Because it's the industry standard."*
- *"Because cargo / systemd / Vulkan / Linux does it that way."*
- *"For compatibility."* (with what? still-running? in AGNOS's target world?)
- *"Because that's the convention."*

These are prompts for further interrogation, not defenses. The question every inherited component must answer is: **what is alive *today, in AGNOS's target world,* that requires you to exist?** If the only defense is tradition, industry convention, or compatibility with something AGNOS isn't shipping into, the layer is refused. This interrogation is applied continuously — not once at design time, but every time the temptation to inherit arises.

**Design for self — the mechanism that enables refusal.** Refusal works only when the criterion for "living" is specific. Designing for "everyone" makes refusal impossible: every dead-legacy layer is load-bearing for *someone*, so nothing can be cut. Designing for yourself — one user with known needs — produces a coherent criterion. You can answer *"is this alive in my world?"* cleanly; you cannot answer *"is this alive in everyone's world?"* at all.

This is the Linux move. Linus wrote a kernel he could use, didn't try to be universal, and the world adapting was the *consequence* of the artifact being good — not the goal. Every attempt to design-for-everyone produces committee architecture; design-for-self produces a coherent artifact others adapt to (or don't).

AGNOS runs the same way. Every subsystem, every API surface, every deletion — the criterion is *does the architect need this, today, in the world he's building?* That specificity is what makes refusal operational rather than aspirational. Refusal without design-for-self fails (no clean criterion for "dead"). Design-for-self without refusal produces idiosyncrasy. Paired moves.

**Origin.** This pattern is the engineering form of a practical questioning discipline: **Always Question Authority.** Applied continuously to every inherited layer — code, architecture, tooling, docs, scope, naming, process. *"Because it's always been that way"* is explicitly rejected as a justification. Demand a living reason; reject tradition-as-authority. Nothing mythological or ideological about it — a method for interrogating inheritance.

**The stance outlives the person.** The method — AQA, interrogation, refusal — is a mental discipline. Transmissible in principle. In practice it requires two preconditions the method doesn't supply: *freedom* (uninterrupted attention and autonomy to do the work) and *stubbornness* (willingness to keep interrogating when the comfortable answer appears, rather than accept the first plausible reason to stop). Without both, interrogators give up at the first real wall and inherit dead legacy anyway. Most sovereignty projects fail there — method understood, preconditions missing. The receipts so far are from one practitioner with both. The method is *designed to be* transmissible; empirical reproduction across practitioners is a pending claim, not a proven one.

**Why this is the master frame.** §1 (Subtraction) is what refusal looks like in quantity. §9 (Reference Don't Mimic) is what refusal looks like at the architecture level. §5 (Library for Humanity) is refusal at project-scope. §4 (SSoT) is refusal at data-maintenance. §2 (Staged Optimization) is refusal across time. §10 (Happy Accidents) is refusal of forced wedges — which leaves room for incidental fits to emerge and compound. §11 (Discipline the Surface) is refusal at the prompt-context layer. Every numbered pattern below is a refusal modality. This section names the move they share — and the interrogation stance that keeps it consistent.

**See also.** All of §1–§9 as instances; memory `project_refusal_as_architecture.md` for the practical framing, transmissibility preconditions, and design-for-self mechanism.

---

## 1. Subtraction as Primary Cognitive Move

**Pattern.** Solve by removing redundant layers rather than adding clever new ones. Most major AGNOS receipts are subtractions, not additions.

**Examples.**
- Rust runtime removed: `exit42` dropped from 345 KB stripped to 152 B
- Dependencies collapsed: 131 crates → 0 in ai-hwaccel; 40 crates → 0 in hoosh; 448 crates → 1 in kavach
- Bootstrap chain: Rust seed retired; 29 KB hand-audited assembly as the foundation
- libc removed from the runtime
- mabda folded into Cyrius stdlib (removed an independent naming/versioning surface)
- `cc` → `cc2` → `cc3` → `cc5` → `cycc` at v6.0.0 (2026-05-19, paired with `cyrc` → `cybs` for the bootstrap compiler — four rename events total; both new names declared permanent, no `cycc6`/`cybs7` at future major versions)

**Why.** Addition looks like progress because it's visible. Subtraction looks like nothing happened until you measure what's left. The cultural pressure is all toward adding "value." AGNOS runs the other way — most of the receipts are what's no longer there.

**See also.** [Cyrius vs Rust: Head-to-Head Benchmarks](articles/cyrius-vs-rust-benchmarks.md), cyrius repo's `docs/size-comparisons.md` (multi-language `exit42` baselines).

---

## 2. Staged Optimization / No Deferred Debt

**Pattern.** Optimization and cleanup work are queued as the explicit next release block, never deferred to "someday." Each release contains specific improvements; improvements don't accumulate as floating technical debt.

**Examples.**
- v5.5.x Windows / Apple platform closeout → v5.6.x optimization arc (O1–O6) → v5.7.0 RISC-V → v5.8.0 bare-metal — each phase is a queued explicit block
- Port sequencing: system ports shipped now, compute ports scheduled after v5.6.x
- cc5 → `cycc` rename scheduled for v6.0 as the one-and-done cleanup — shipped 2026-05-19; not deferred indefinitely

**Why.** Most projects ship features and leave "we'll optimize later" debt that never gets paid because priorities shift. AGNOS doesn't let optimization become a floating someday-item — it's always the literal next block. Drift can't accumulate because there's nowhere for it to sit.

**See also.** [The Price of Porting Early](articles/the-price-of-porting-early.md); memory: `project_execution_rhythm.md`.

---

## 3. Port-First Sequencing: System Before Compute

**Pattern.** Port workloads by compiler-readiness class. System ports (allocator-heavy, I/O-heavy, syscall-heavy) go first — they validate the language and drive compiler feedback. Compute ports (math, DSP, science) wait for the optimization arc that makes their numbers competitive on first publication.

**Examples.**
- 30+ system ports shipped pre-v5.6.x (kernel, kybernet, hoosh, ark, nous, kavach, sigil, agnosys, argonaut, libro, shakti, phylax, bote, t-ron, daimon, agnoshi, itihas, sankoch, hisab, avatara, ai-hwaccel, hadara, shravan, mabda, abaco, bsp, cyrius-doom, and more)
- 82 compute / science ports scheduled for post-v5.6.x / v5.7.x
- abaco feedback loop: port hit missing-feature friction → spec'd `u64_mulmod` fast-path to compiler → Cyrius v4.8.5 shipped it → abaco re-measured 12× end-to-end. Canonical closed form.

**Why.** Porting compute code against a pre-optimization compiler publishes weak numbers that become canonical first impressions. System ports show Cyrius's structural wins at any compiler version; compute ports need the compiler at its target form. Sequencing by port-class preserves the first-impression record.

**See also.** [The Price of Porting Early](articles/the-price-of-porting-early.md); memory: `project_port_ledger_arc.md`, `project_port_feedback_to_cyrius.md`.

---

## 4. Single Source of Truth — Pull, Don't Bake

**Pattern.** Version, config, and cross-cutting data live in ONE place. Consumers pull it rather than encoding it into their own artifacts. Every duplicated fact is a drift surface.

**Examples.**
- `VERSION` file at repo root (SemVer, single authority) — currently 0.1.0; docs and scripts pull from it, never hardcode
- cc5 → `cycc` rename (Cyrius v6.0.0, 2026-05-19): binary name becomes stable; version lives in `VERSION`; no more `cc → cc2 → cc3 → cc5` renaming treadmill across scripts, CI, install paths, docs (four historical renames — `cycc` is declared the final one, paired with `cyrc → cybs` for the bootstrap binary)
- Size comparisons live in cyrius repo's `docs/size-comparisons.md`; genesis docs link out rather than duplicate tables that would drift per optimization release
- Per-repo CLAUDE.md is authoritative for that repo's state — sibling repos reference, don't copy

**Why.** Every place the same fact appears is a place it can go stale. Baking a version into a binary name means every release opens dangling references across the tree. Pulling from source means one update site, always fresh. Enforces single-source rather than aspirational-single-source.

**See also.** memory: `reference_cyrius_size_comparisons.md`.

---

## 5. Library for Humanity — Build, Make Passable, Step Aside

**Pattern.** The project's public thesis: build a **library for humanity** — infrastructure designed to be received, used, and extended by whoever picks it up. Build the library, make it passable, step aside. NOT invent, apply, govern, extract, or own. What users do with the library is theirs.

**Examples.**
- Vision docs (`docs/development/vision/`) present routes kept open, not products owned
- Creator Economy: thesis documented, implementation deferred to whoever runs it
- Theoretical doc (portals, teleportation, nanites): *"ensure that architectural decisions don't preclude these possibilities"* — route-keeping language, not roadmap commitment
- Shared crate registry (78 crates across physical sciences, life sciences, formal sciences, earth/space, human sciences, media) — build the catalog so every domain has a place; don't try to write every book
- Core subsystems under GPL-3.0-only / AGPL-3.0-only: copyleft keeps the library *for humanity* rather than absorbed into proprietary stacks

**Why.** Most sovereignty projects fail because the builder extends into applier: infrastructure → apps → economy → governance, each step a platform in disguise. The Librarian discipline refuses that drift and keeps the project a gift, not a dependency. Practically: if the builder is also deciding what the compiler gets used for, he can't also be building the compiler at this pace. Different jobs, different gear ratios.

**See also.** memory: `feedback_route_and_library.md` (the role discipline in practice); vision docs under `docs/development/vision/`.

---

## 6. User-Side Naming

**Pattern.** Coin terminology from the user's side of the transaction. Outcome names (what the user gets) and mechanism names (how it works) stick. Author-journey names (what it felt like to build, what ideology it represents) don't — and date quickly.

**Examples.**
- Accepted: *surface-at-launch* (outcome), *port-bootstrapped language* (mechanism)
- Rejected: *ecosystem transplant* (author-vivid image, doesn't inform the user), *permitted-to-sovereign migration* (author-ideology arc)
- Subsystem names (Sanskrit, Arabic, Hebrew, Japanese) are cultural references chosen to describe *function*, not Robert's journey: `kavach` = armor (sandbox), `sigil` = seal (trust), `kybernet` = helmsman (PID 1), `hoosh` = consciousness (inference routing)

**Why.** Names that stick describe utility to readers. Self-experiential names get ignored even when evocative. "DevOps" stuck because it described what the thing *was*. Applies to paradigms, subsystems, articles, feature names, foundation names — every terminology decision.

**See also.** memory: `feedback_name_from_user_side.md`.

---

## 7. Art First, Tour Optional

**Pattern.** Structure public-facing content so receipts stand alone. The narrative track is available but never required to understand the art. A visitor who wants the receipts walks in, sees the bytes, and leaves informed. A visitor who wants the story takes the tour when they choose.

**Examples.**
- Technical docs (`docs/architecture/`, subsystem tables, benchmarks) open with tables / numbers / code, not origin story
- Articles (`docs/articles/`) and philosophy (`philosophy.md`) live in separate doc families, not embedded in every technical page
- Cross-references point to the tour from the art ("for the *why*, see X") — never the reverse
- [`docs/architecture.md` § Kernel Layers](architecture.md#kernel-layers) stands alone without requiring `philosophy.md` or the Temple framing to be useful
- Receipts (CSVs, git tags) are preserved in each ported repo — reproducible without reading any narrative

**Why.** Gating art on reading the tour turns a museum into a lecture hall. The Librarian displays the library; he doesn't force visitors to read his memoir before they can see the exhibits.

**See also.** memory: `feedback_art_first_tour_optional.md`, `feedback_articles_are_synthesis.md`, `feedback_personal_vs_technical.md`.

---

## 8. Pain → Procedure (Encode Lessons as First-Class)

**Pattern.** When a hardening step, workflow improvement, testing discipline, or review checkpoint surfaces as useful, promote it to first-class status immediately — memory, CLAUDE.md rule, workflow doc, or script. Don't leave it as a lesson learned.

**Examples.**
- **API-surface check** — originated in agnosys as `scripts/check-api-surface.sh`, propagated to cyrius as standard procedure
- **Port-feedback loop** — named after abaco → Cyrius `u64_mulmod`, now documented pattern (see Pattern 3)
- **Recipe audit** — *"never just bump version; audit ALL fields"* encoded after a specific near-miss
- **Build-check-before-tests** — encoded as `feedback_test_efficiency.md` after repeated pain
- **P(-1) Scaffold Hardening** — 7-step audit formalized in cyrius `CLAUDE.md`
- **Close-out procedures** — verify build, update changelog, check inbound references — each one exists because unsupervised drift went wrong once

**Why.** Without promotion, learnings bleed off. Next cycle, same mistake. Promotion prevents regression because the loop itself enforces the learning — same mechanism as automated tests preventing code regressions. The compound-interest effect across iterations only works when lessons become execution, not footnotes. Compounding is on *practice*, not just knowledge.

**See also.** memory: `feedback_promote_learnings.md`, `feedback_api_surface_check.md`, `feedback_recipe_audit.md`, `feedback_test_efficiency.md`.

---

## 9. Reference, Don't Mimic

**Pattern.** Incumbents define what problems are real, not what solutions look like. Every port starts by cataloging what the incumbent learned the hard way — then designs the replacement as if the incumbent didn't exist. The incumbent is the reference specification of the problem domain, not the template for the new implementation.

**Examples.**
- **kybernet** is not "systemd in Cyrius." It's PID 1 designed in 2026 without carrying cgroup-v1 baggage, sysv compatibility layers, or the 20-year unit-file accretion. → 14× smaller, 1583× faster is_mounted
- **hoosh** is not "Ollama in Cyrius." It's an inference gateway designed without needing 40 Python crates to sit behind it. → 10.8× smaller, 70× compile
- **kavach** is not "bubblewrap in Cyrius." It's a sandbox designed with Landlock as a first-class primitive rather than an afterthought. → 500× sandbox lifecycle, 448 crates → 1
- **ark** is not "cargo in Cyrius." It's a package manager designed around bump allocator + str_builder instead of serde + format! + alloc/dealloc. → 4× smaller, 40× compile
- **Cyrius** is not "C++ in Cyrius." It's C's successor designed after 50 years of watching what went wrong with the C family. → 29KB seed, zero deps, byte-identical self-host
- **AGNOS kernel** is not "Linux in Cyrius." It's ~571 KB at v1.31.7 across 40+ subsystems — a completely different decomposition of the kernel problem. Multi-source convergent prior-art audits across BSDs / Haiku / EDK2 / SeaBIOS surface what the *problem* shape is, then redesign for AGNOS — Linux is one source of many, never the singular reference.
- **mabda v3** (in flight) is not "wgpu in Cyrius." It's a GPU API designed around a render-graph orchestrator, a modern hardware floor, and Cyrius idioms — dropping 20 years of Vulkan/legacy-device accretion.
- **abaco** is not "GMP in Cyrius." It's a number-theory library designed to drive hardware-primitive feedback into the compiler (→ `u64_mulmod` intrinsic in Cyrius 4.8.5 → 12× end-to-end on Miller-Rabin).

**Why.** The reflex to duplicate is the safe move because the incumbent is battle-tested. Matching its shape feels responsible. But the incumbent's shape encodes every workaround, every deprecated-but-kept compatibility layer, every decision made against hardware that no longer exists. Copying the shape inherits all of it. Using the incumbent as a reference — "what problems does it solve? what scars does its architecture show?" — without mimicking its solution is how you get a 14× receipt instead of a 1.1× receipt. Duplicating produces parity; referencing produces leapfrog.

**How to spot the failure mode.** Watch for "let's do what X did." When the reflexive plan is the incumbent's architecture transliterated into Cyrius, stop and restart from the problem, not the existing solution. The v3 mabda branch caught this at the "dual-backend runtime-dispatcher" prototype step — exact duplication of wgpu's shape — and reframed.

**See also.** memory: `feedback_reference_dont_mimic.md`, `project_port_feedback_to_cyrius.md`; Pattern 1 (Subtraction as Primary Cognitive Move) — subtraction is often what the reframe produces, because the incumbent's shape had layers the new context doesn't need.

---

## 10. Happy Accidents Shape; Forced Wedges Don't

**Pattern.** Things added for small, incidental, or pragmatic reasons often turn out to be load-bearing later. Conversely, things forced in against the grain — *"we should add X because some incumbent expects it"* — tend to not work, or require constant maintenance against the project's natural shape. Work with attention, leave room for accidents, and recognize when something incidental has quietly become structural.

**Examples.**
- **Mabda's `render_graph.cyr`** — added in v2.5.0 as a structural nicety for clean pass organization. When v3.0 began work on the native Cyrius GPU backend, the render graph turned out to be the de-risking layer: v3.0 wasn't *"design a render graph AND a native backend simultaneously"* — it was *"harden the graph we already have and make the backend assume the graph."* The accidental load-bearing move.
- **Cyrius itself** — SY was the plan. Cyrius was what emerged when the missing floor became unignorable. Not *"the strategic next move,"* but *"the thing the work needed that happened to be the next piece to make."*
- **Bhava's compositional framework** — SY's YAML traits were already doing compositional-personality work before there was a name for it. Bhava formalized what the prototype was already proving out.
- **Hadara as first Cyrius-native crate** — emerged from the port work as a natural first test case, not from a planned *"let's prove Cyrius-native on hadara"* roadmap item.
- **abaco → Cyrius `u64_mulmod` feedback loop** — the abaco port surfaced a missing hardware primitive; Cyrius shipped the primitive; abaco re-measured ~12× end-to-end on Miller-Rabin. The optimization opportunity was received, not planned.
- **The kernel going from zero to a Boot-to-Shell-iron-validated ~571 KB in weeks** (initial bare-metal-iron debut at v1.30.5 / 2026-05-15; MVP gate at v1.30.9 / Attempt 68 / typeable shell on archaemenid; storage arc closed at v1.31.6 / Attempt 90 / ext4 on real NVMe NAND) — not a *"plan for rapid kernel development."* A consequence of having a sovereign compiler ready and needing a kernel to run on it.

**Why.** Projects that force their shape end up fighting themselves — every decision has to be defended against the shape instead of flowing with it. Projects that work with attention, noticing when something fits unexpectedly, compound faster: each happy accident reduces the next design's cost, because the structure has been quietly building itself. Bob Ross's "happy accidents": you weren't planning that cloud, but now that it's there, the painting is better. The discipline is *noticing* — and promoting the incidental-that-became-load-bearing to first-class, rather than leaving it as an incidental.

The inverse is the **forced wedge** failure mode: adding a subsystem because an incumbent has one, sticking to a plan after the work has revealed a better path, or refusing to recognize when an incidental choice has become structural. All three happen when the builder is fighting the work instead of listening to it.

**How to apply.**
- Leave room for accidents. Don't pre-design every interface to the last detail. Pragmatic-now becoming load-bearing-later is a feature, not a failure of foresight.
- When something incidental turns out to fit unexpectedly well, promote it to first-class — don't leave it buried as *"oh that's just a nicety."*
- When a decision has to be forced against the grain, interrogate it (per §0, §9): is it inherited expectation, or is it actually needed in the world you're building in?
- Distinguish **happy accident** (emerged organically, fits, should be recognized) from **sloppy accident** (emerged because nobody thought about it, doesn't fit, should be cleaned up). The test is whether the thing is doing genuine structural work or just occupying space.

**See also.** §0 (Refusal as Architecture — refusing forced wedges is the stance); §9 (Reference Don't Mimic — refusing the incumbent's shape leaves room for unexpected fits); the causal chain in [`philosophy.md`](philosophy.md) (AGNOS itself is the largest happy accident — SY pointing at missing floor, refusing to look away, and what emerged when each layer was noticed).

---

## 11. Discipline the Surface, Don't Multiply Layers

**Pattern.** AGNOS treats prompt context as a layered surface — `CLAUDE.md` / `docs/development/state.md` / `~/.claude/.../memory/` / per-repo ADRs / `docs/`. Each layer has one job and a different lifecycle. When agent compliance drops, the move is structural cleanup at the existing surface — separation of concerns + active re-read at task boundaries — not bolting on another extension point.

**Examples.**

- **CLAUDE.md as preferences/process/procedures only.** Volatile state (versions, sizes, in-flight slots, recently-shipped lists) lives in `docs/development/state.md`, bumped by the release post-hook. CLAUDE.md reads the same across a whole minor series.
- **`MEMORY.md` as one-line index.** Detail in linked files; the index itself stays under context-limit so it loads cleanly while detail loads on-trigger. Per-memory frontmatter (`name`, `description`, `type`) lets the agent decide relevance before reading the body.
- **ADRs append-only per repo.** Supersession via new ADR rather than mutation. Each decision keeps its own paper. (sit/CLAUDE.md and cyrius/CLAUDE.md are the gold-standard scaffolds.)
- **Slash commands as bundled re-read + workflow.** `/init` re-reads project structure before any new-project work; project-specific commands bundle the re-read into the workflow rather than relying on once-loaded context to govern the run.
- **Hooks as automated re-read.** `settings.json` `PreToolUse` entries that re-inject the relevant slice of CLAUDE.md before specific tool-use events fire. Same effect as a human-prompted re-read, automated.
- **Refused: plugin-as-fix.** When a meetup talk pitched *"build a plugin to tame Claude Code"* as the answer to the ~30% instruction-drop rate, AGNOS's response was: the 30% number is real, the failure modes are bloat / contradiction / absent re-read, all three are structural problems at the existing surface. A plugin adds another extension point with its own staleness window and attention budget. Refused.

**Why.** Same shape as §0 and §9. The plugin is the multiplied layer; the surface is the existing layer. The ~30% failure mode the prompt-engineering industry is currently solving with extension points is bloat (collapse all five layers into CLAUDE.md), contradiction (volatile state inlined next to durable rules), or absent re-read (LLM attention is uneven; once-loaded context drifts as the conversation grows). All three respond to structural discipline at the layer that already exists. The plugin doesn't fix any of them; it just adds another layer that also gets skimmed.

This is *Refusal as Architecture* applied to prompt engineering. The discipline isn't to refuse all tools — Claude Code itself is a tool. The discipline is to refuse *the multiplication of indirection layers* when the existing surface can do the job with structural work.

**How to apply.** Triage any over-bloated CLAUDE.md against the five-layer surface: move volatile state out (→ `state.md`), move behavioral feedback out (→ memory), move per-decision archaeology out (→ ADRs), trim what's left, and prompt the re-read at task boundaries. The agent will not re-read unprompted; the prompt is the discipline.

**See also.** [*Your CLAUDE.md Isn't Lying. You're Skimming.*](articles/your-claude-md-isnt-lying.md) (deep-dive); [*Development Speed and How It Effects Documentation*](articles/development-speed-and-documentation.md) (the same drift dynamics one doc-layer over); memory: `feedback_claude_md_durable_state_external.md`. Pattern §0 (Refusal as Architecture — master frame) and §9 (Reference Don't Mimic — sibling refusal pattern at the implementation layer rather than the documentation layer).

---

## Patterns Yet to Add

Space for accretion. When a pattern surfaces in work and isn't covered above, add a stub here with the date and a pointer to context. Expand into a full section when material accrues.

### Sibling-distfile fold (added 2026-05-06)

Three instances now: **sandhi** (Cyrius v5.7.0, service-boundary layer, 376 KB / 469 fns), **vani** (Cyrius v5.8.0, audio device I/O), **niyama** (Cyrius v5.9.0, regex engines, 6,664 lines / 5 engines). The pattern: a sibling repo proves out a domain, hits multi-consumer status, gets vendored byte-identical into Cyrius stdlib's `lib/` as a single artifact, and the standalone repo enters maintenance mode while the fold becomes the canonical source. Multi-consumer gate is the trigger (sandhi: 6+ AGNOS consumers; niyama: cyim + queued bare-metal kernel). `cycc` binary size is unaffected (foldins are `lib/` content; the compiler doesn't include them). Pattern instance of §0 (Refusal as Architecture) at the stdlib-boundary layer — refusing the multiplication of dep-graph layers when the surface is mature enough to anchor in stdlib. The decision framework (gates + anti-criteria + cost) is articulated in [*What Justifies a Stdlib Foldin*](articles/what-justifies-a-stdlib-foldin.md). Expand into a full §12 once the next fold lands and the framework's been tested across four instances.

### Terminal-symbol identity (added 2026-05-06)

Cyrius packages render in the shell prompt with **ॐ** (Om, U+0950) and the active toolchain version with **🌀** (cyclone, U+1F300), formatted: `ॐ <pkg-name> <pkg-version> (<repo>) | 🌀 <toolchain-version>`. Shipped Cyrius v5.8.0 via the `cyriusly` starship.toml prompt rework. The convention establishes Cyrius as a distinct ecosystem alongside the existing prompt-engine visual vocabulary (Rust 📦, Go gopher, Python snake) — not by adopting one of those, not by going symbol-less, but by picking glyphs that *describe what the ecosystem is*: **Om** = source/origin in the Sanskrit lineage that names AGNOS subsystems; **cyclone** = active rotation, the cycle the toolchain ships in. `𝕮` (mathematical fraktur C, U+1D49C) is retained as documented ASCII fallback for emoji-hostile terminals — graceful degradation rather than feature-loss. Pattern instance of §6 (User-Side Naming) extended to visual identity at the terminal: the symbol describes function, not personality, not author-journey. Possible promotion path: if more ecosystem-identity micro-conventions accrete (CLI banner, file-type icon, error-marker glyph), hoist into a fuller pattern about *visual sovereignty at the surface*.

### Multi-source convergent prior-art audits (added 2026-05-22)

Pattern instance of **§9 (Reference Don't Mimic)** with a sharpened operational rule: when porting a solved-problem subsystem (storage drivers, filesystem code, USB stacks, GPT parsing), the audit reads from **multiple references and triangulates the converged shape** — never a single source treated as authoritative. Captured as memory `feedback_redesign_dont_reinvent` after the 2026-05-21 USB MS Phase 2.7 recovery: an earlier draft of the rule said "port from Linux"; user pushback ("LINUX ISN'T THE ONLY RESOURCE OF PRIOR ART") refined it to read FreeBSD `umass.c` + OpenBSD `umass.c` + EDK2 `UsbMassBot.c` + Linux confirmatory — that four-source convergence is what surfaced the 100ms post-BOT-Reset device stall and the EP-state-aware Reset Endpoint dispatch ordering that became Phase 2.7. Live instances landed under the 1.31.x storage arc: [`msc-reset-recovery-prior-art.md`](development/prior-art/msc-reset-recovery-prior-art.md), [`ext2-ext4-extents-prior-art.md`](development/prior-art/ext2-ext4-extents-prior-art.md), [`ext4-64bit-prior-art.md`](development/prior-art/ext4-64bit-prior-art.md). Why it matters: single-source porting inherits one project's accretion and architecture; multi-source converged porting surfaces the *invariants* across multiple implementations, which are the genuine domain truths. Possible promotion path: when a fourth audit doc lands (next storage cycle or networking arc), hoist into a full §12 with the audit-doc template + the "Linux is one source of many" discipline as named rules.

### Audit before iron burn (added 2026-05-22)

Pattern instance of **§8 (Pain → Procedure)**. Iron burns on archaemenid (the user's primary AMD test target) hold up the user's other work — the machine is in-use, the cabling is non-trivial, and a burn cycle costs 5–15 min of physical interruption. Encoded as memory `feedback_iron_burns_block_other_work` after a stretch of speculative-fix iron burns wasted multiple cycles: **no iron burn is proposed without a written line-by-line audit first.** Audit docs live alongside the iron-nuc-zen-log per cycle: [`ext2-iron-burn-audit.md`](development/prior-art/ext2-iron-burn-audit.md), [`ahci-iron-burn-audit.md`](development/prior-art/ahci-iron-burn-audit.md), [`usb-ms-iron-burn-audit.md`](development/prior-art/usb-ms-iron-burn-audit.md). Each follows the same shape: scope, hypotheses ranked by iron-specific risk, what NOT to do, success rubrics (full PASS + partial-failure paths + FALSIFIED), mitigations applied, multi-source prior-art references, audit disposition. The Attempt 87 USB MS PASS, Attempt 90 ext4 PASS, and Attempt 82 AHCI carry-forward PASS each cleared their audit's success rubric on the first iron try — the audit's job is to make that outcome the default, not the exception. Possible promotion path: companion rule **no instrumentation bundled with diagnostic burns** (memory `feedback_no_instrumentation_means_no_instrumentation`) is the same discipline at the instrumentation layer; together they'd form a fuller "pre-iron rigor" pattern when a fourth audit doc + a fourth burn-discipline rule accumulate.

### Bite-decomposition cadence (added 2026-05-22)

Pattern instance of **§2 (Staged Optimization)** at the cycle-internal scale. Multi-bite cycles (1.31.6 cleanup with bites A–H; 1.31.7 filesystem-follow-ups + shell-UX with bites D/B/C/A/E) order their work **smallest-first to bank wins quickly** rather than starting with the biggest bite. 1.31.7 ordering: `ls -la` flag dispatch (~25 LOC, 30 min) → bare-name `cat` ext2 fall-through (~20 LOC) → `cd` + `pwd` + CWD scoping (~190 LOC, the medium piece) → ext4 64BIT Phase 5 (~25 LOC + new prior-art audit doc, the heaviest because of the audit gating) → cycle-close sweep + iron Attempt 91. Why the order matters: each landed bite verifies the toolchain + build pipeline + smoke matrix before the next bite ships; a regression in a small early bite is cheap to bisect, a regression in a large late bite is expensive. Compounds with the **audit-before-iron-burn** rule: the cycle's small bites can ship through QEMU smoke with no iron involvement; iron burn happens once at cycle close for no-regression validation. Possible promotion path: when a third multi-bite cycle ships in this cadence (1.32.x networking would be a natural candidate), hoist into a fuller pattern with the explicit ordering heuristic + the QEMU-iron split + the audit-doc gating-by-bite-size dimension. — *Update 2026-05-28: 1.38.x JBD2 arc shipped in 9 bites in a single day (probe → probe-deepen → log reader → replay → lifecycle → write path → integration → crash smoke → hardening + iron-burn audit), each with its own smoke + each gated PASS before the next bite opened. The pattern continues to scale: third instance landed; promotion to §12 ripe whenever the next cycle ships in this cadence.*

### Per-bite smoke discipline (added 2026-05-28)

Pattern instance of **§2 (Staged Optimization)** + **§8 (Pain → Procedure)** at the same scale as bite-decomposition above but a different axis. Every bite of a multi-bite cycle ships with a **dedicated smoke script** — a host-side validation that drives the new code through QEMU and emits PASS/FAIL gates. The smoke is the load-bearing gate; without it the bite isn't closed regardless of what the QEMU log shows. JBD2 arc instances: `jbd2-refusal-smoke.sh` (1.38.1), `jbd2-logdump-smoke.sh` (1.38.2), `jbd2-replay-smoke.sh` (1.38.3), `jbd2-tx-smoke.sh` (1.38.4), `jbd2-writepath-smoke.sh` (1.38.5), `jbd2-integration-smoke.sh` (1.38.6), `jbd2-crash-smoke.sh` (1.38.7) — seven smokes for seven bites. Why this matters: a bite's claim of correctness is only as strong as the smoke that gates it, and gates that *can* be machine-checked *should* be machine-checked (rather than re-reading the QEMU log by eye each cycle). Each smoke also becomes a regression spec for subsequent cuts — the 1.38.7 crash smoke gating "all kills produce e2fsck-clean" stays valuable forever. Compounds with **audit-before-iron-burn**: smokes prove the QEMU correctness; the iron-burn audit + actual burn close the real-hardware gap.

### kashi-style parallel-agent extraction (added 2026-05-28)

When a subsystem reaches multi-consumer status AND has a maintainable surface AND the agnos sessions don't need to evolve its internals: **extract it to a sibling repo for a parallel agent to develop independently**, with agnos sessions only touching the extraction/consumption boundary. kashi (काशि — AGNOS console-font subsystem) is the canonical instance: extracted 2026-05-20 from `fb_console.cyr`'s inline VGA 8x16 + CGA 8x8 tables (byte-for-byte audit at 0.1.0 = zero mismatches), then evolved 0.1.0 → 1.0.0 over 8 days by a parallel agent (PSF1/PSF2 import, runtime registry, CP437 widening, hardening audit) while agnos sessions consumed it at the boundary (1.37.5 vendor-in via `[deps.kashi]`). The discipline: agnos sessions DO NOT touch kashi internals (per memory `project_kashi_parallel_split`); agnos sessions ONLY change the extraction or consumption surface. The benefit: parallel work, faster end-to-end shipping, and clean separation of concerns. The cost: dep-management surface (CI fetch / version pinning / re-test on bump), which 1.37.5's `KASHI_REF` env var + `scripts/build.sh` auto-clone fallback handles. Pattern instance of **§0 (Refusal as Architecture)** at the work-allocation layer: refusing the assumption that one agent must develop everything, when the surface allows clean splits. Possible promotion path: when a second sibling subsystem extracts in this pattern (the next candidate per state.md is `commandress`/`bannermanor`/`darshana` clusters), hoist into a fuller pattern about *agent-boundary discipline* alongside the existing extraction/consumption rules.

### Dedicated refactor cycle before heavy-arc cycles (added 2026-05-28)

Pattern instance of **§2 (Staged Optimization)** at the inter-cycle scale. Before opening a substantial-change arc (1.37 extent allocation / 1.38 JBD2 journaling — both touching `ext2.cyr` deeply), AGNOS allocates a **dedicated refactor cycle** with structural changes only, every cut **byte-identical** to its predecessor (verified via SHA + smoke-suite-no-regression). The 1.36.x refactor cycle is the instance: 1.36.0 split `net.cyr` TCP → `net_tcp.cyr` (~780 LOC, byte-identical build); 1.36.1 split app-protocols + ingress → `net_dhcp/icmp/dns/ntp/rtc/ingress.cyr` (`net.cyr` 2019 → 272 LOC, byte-identical); 1.36.2 extracted boot self-tests + kybernet launch from `main.cyr` (1661 → 1244 LOC, byte-identical). Why the cycle separation matters: structural refactors and feature additions both touch the same file; bundling them makes regression bisection painful because a smoke failure could be EITHER the refactor OR the new feature. Separating them gives clean attribution + a clean baseline for the feature work. Why byte-identical: any non-zero binary delta = something more than refactor happened; refusing the binary delta is the procedural enforcement. The 1.36.x cycle deferred `ext2.cyr` split to 1.39.x VFS arc and `shell.cyr` split to 1.41.x agnoshi-shell arc — only split files when the next cycle is the natural decomposition trigger. Possible promotion path: when a second refactor cycle precedes another heavy arc (e.g., 1.39.x VFS lift would naturally pair with an `ext2.cyr` split refactor), hoist into a fuller pattern with the byte-identical-build rule + the deferral-until-natural-trigger heuristic + the smoke-suite-no-regression gate.

---

## Relationship to Other Docs

| Layer | Doc | Answers |
|-------|-----|---------|
| Ideology | [`philosophy.md`](philosophy.md) | Why AGNOS exists at all |
| **Patterns (this doc)** | `design-patterns.md` | Why the decisions fit together as a system |
| Events | [`history.md`](history.md), [`timeline.md`](timeline.md) | What happened when |
| Per-decision | ADRs in each repo | Why *this specific* choice over alternatives |
| Specific argument | `docs/articles/*.md` | Thematic deep-dives on particular patterns |
| Per-release | `CHANGELOG.md` in each repo | What changed in v-N |
| Working rules | `CLAUDE.md` files | How to operate in each repo |
| Agent norms | `memory/*.md` | Cross-session behavioral directives |

Each layer has its own job. This doc is the through-line layer — the recurring moves that produced many of the per-decision choices and per-release changes.

---

*This outline will become the spine of the GA retrospective doc. Patterns added here during development become hindsight-framed at GA. The material accretes; the form finishes at release.*
