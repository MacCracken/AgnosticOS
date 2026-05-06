# Summer 2026 Rollout Arc — June 21 → Black Hat → DEF CON

> **Status**: Active planning | **Opened**: 2026-04-23 | **Arc close**: ~2026-08-15 (DEF CON week)
>
> Three-stage cascade: **summer solstice demo → Black Hat sovereignty receipts → DEF CON physical distribution.** Each beat targets a distinct audience that intrinsically cares about a different face of the same artifact, and each one seeds the next.
>
> **This is a working punch list, not a marketing plan.** Check items off as they complete. Items are *"this must be true or the beat doesn't land"*, not *"this would be nice."* Rewrite in place as state evolves. At arc close, archive or supersede with a `fall-2026-arc.md`-equivalent.
>
> **Discipline reminder**: coordination docs rot at agent speed (see [docs/articles/docs-go-stale-before-the-commit.md](../articles/docs-go-stale-before-the-commit.md)). This one is intentionally dense; assume it will be stale within days in specifics, but the *shape* holds. `git log` anything before acting.

---

## The three beats

| Beat | Date | Audience | Primary artifact | Distribution surface |
|------|------|----------|------------------|----------------------|
| **Beat 0.5 — Retro Games Day** | **2026-06-13 (Sat)** | indie game devs / retro / systems / *"can it run DOOM"* meme-audience | **cyrius-doom as the featured headline** (strongest portability signal; Carmack-lineage respect; *"AGNOS runs DOOM"* as the one-sentence pitch). Companions available same-day per each repo's readiness: cyrius-nba-jam, encom-hits, and **cyrius-bb v1.0** (50-year Breakout homage, quieter narrative slot) | Coordinated GitHub release bundle + Hacker News (*"can it run DOOM"* post is self-writing) + indie-gaming press + Steam Summer Sale lead-in ambient |
| **Beat 1 — Summer solstice demo** | **2026-06-21 (Sun — solstice)** | indie game devs / handmade-hero / Jai-curious | ***Brynn's Tale*** **Act 1 demo** (Memento-form descent, base rewind, world 1 gray-box) + launch article + AGNOS ISO boot demo + sit self-commit receipts | GitHub release + Steam Summer Sale ambient + HN / Lobsters |
| **Beat 2 — Black Hat receipts** | ~2026-08-05 | security researchers | supply-chain sovereignty piece + kernel/kavach/sigil/phylax audit-ready receipts | Black Hat USA 2026 presence (talk / booth / paper / sponsor distribution) |
| **Beat 3 — DEF CON distribution** | ~2026-08-09+ | hacker/punk/builder | physical ISO + bumper-sticker-as-crypto-root | $5K sticker + SD card distribution budget; DEF CON presence |

**Sequencing rationale**: June 13 retro-games-drop is the warm-up wave — indie-game audience starts poking at Cyrius from a low-stakes accessible entry point (brick-breaker, DOOM, NBA Jam, ENCOM retro hits). 8 days of chatter builds ambient attention. June 21 solstice is the consolidation moment — *Brynn's Tale* (the technical-depth prestige title; original mythic-modern IP, not a homage) PLUS the broader sovereignty-stack demo (kernel boot, sit self-commit, sandhi / yantra). Developers who poked at the games on June 13 find the full OS story on June 21.

Each audience is warmer than the next in receptiveness and colder than the next in distribution-range. Correctly staged, June 13 + June 21 set up August — developers talk about Cyrius publicly, security researchers arrive at Black Hat already having heard of it, DEF CON attendees take ISOs home that they already know what to do with.

---

## Status legend

- [ ] Not started
- [~] In progress
- [x] Done
- [!] Blocked — see note
- [?] Needs investigation / owner unclear

---

## Beat 1 — Summer Solstice Demo (2026-06-21, Sun; ~8 weeks out)

**Shape**: "it's real, and we're shipping an original mythic-modern game on it." The artifact-centric demo moment.

### Must land

| # | Item | Notes |
|---|------|-------|
| S1 | [ ] **cyrius-brynns-tale M1 complete** (time-rewind ring buffer, determinism test suite green) | Foundational technical bet for Act 1. Without M1 the demo is just a scaffold. |
| S2 | [ ] **cyrius-brynns-tale A1.W1 complete** (Act 1 World 1 gray-box: base rewind, Memento-form opening, backward-narrative onboarding) | Playable end-to-end on one world. Proves rewind integrates with the storytelling form. |
| S3 | [ ] **AGNOS ISO bootable end-to-end** on reference hardware + QEMU | Kernel + shell + Cyrius toolchain in one image. ark install of cyrius-brynns-tale from the booted environment. |
| S4 | [ ] **Cyrius self-hosting verified** across Linux x86_64, aarch64 Pi, Apple Silicon, Windows PE at demo time | The "it runs everywhere" claim needs to be true in the week the demo goes live, not six weeks prior. |
| S5 | [ ] **Launch article drafted and scheduled** — original-IP framing for *Brynn's Tale* (working title TBD; outline in [`_outlines.md §5`](../articles/_outlines.md)) | Demo without an article is a screenshot; article without a demo is manifesto. Both or neither. |
| S6 | [ ] **Video capture** — Cyrius self-building from seed, AGNOS booting, *Brynn's Tale* Act 1 demo (death-as-frame-one opening + base rewind in action) | 2–5 minute loop, no narration required. Publishable as standalone or embedded in the launch article. |
| S7 | [ ] **Benchmark one-pager** — Cyrius vs Rust compile time, AGNOS kernel vs Linux boot, *Brynn's Tale* rewind-determinism throughput vs [equivalent Rust/Unity baseline on same mechanic workload] | Numbers. Not prose. |
| S8 | [ ] **GitHub release tag for cyrius-brynns-tale** | Semver-clean. Publishable artifacts. README points at ADRs 0003–0007 so adopters find the design framework before the code. |

### Should land

| # | Item | Notes |
|---|------|-------|
| S9  | [ ] cyrius-brynns-tale A1.W2 (second rewind variant; "the path you can't unwalk") | Second variant world playable. Extends the demo from "one variant" to "the variants exist." |
| S10 | [ ] cyrius-brynns-tale A1.W3 (third rewind variant; "the doppelgänger / former self") | Third variant world. Breadth without committing to all six. Still gray-box art. |
| S11 | [ ] yantra M1 — Chromium CDP backend live, benchmark vs Playwright published | Demonstrates the yantra knife-article thesis in flight. Cross-pollinates developer audiences beyond just game devs. |
| S12 | [ ] Short sidebar in the launch article: **Black Hat angle preview** | One paragraph seeds the August audience. Cheap. |

### Can land (nice-to-haves)

| # | Item | Notes |
|---|------|-------|
| S13 | [ ] cyrius-brynns-tale art pass started (early stylized assets for opening world only) | First stylized asset replacements. Lower priority than breadth. |
| S14 | [ ] cyrius-brynns-tale opening cinematic music (the death-as-frame-one moment) | Original score; mythic-modern register; lets the opening land emotionally even in gray-box state. |
| S15 | [ ] Second benchmark: yantra vs Appium on a mobile workload | Adds mobile-dev audience to the June 21 reach. |

### Distribution tactics

- [ ] **Hacker News Show HN submission** — morning of June 22 UTC. Title leans on "original mythic-modern game shipped in a sovereign systems language" — not a Braid-homage hook.
- [ ] **Handmade Network community post** — natural audience overlap with handmade-hero / sovereign-stack-curious developers.
- [ ] **Steam Summer Sale ambient** — Steam Summer Sale 2026 typically opens ~June 20–22; indie-game-audience attention is elevated that week. No Steam presence required; just timing-aware.

> **Note**: Pre-pivot plan included a "Blow Twitch donation-bomb" tactic tied to the Braid-homage framing (drop a $50 tip during a Blow stream with the cyrius-braid URL). That tactic is no longer applicable post-pivot — the JBlow-on-JBlow rhetorical move belonged to the homage, not to the original IP. Dropped.

---

## Beat 1.5 — July/August supplementary game drops (between Beat 1 and Beat 2)

**Shape**: "the library isn't stopping at Braid." Continuity-register — keeps attention warm through the gap between the June 21 solstice moment and the Black Hat / DEF CON pair in early-to-mid August. Each drop is a **LIGHT\*OCEAN\*STUDIOS** release under the Cyrius game-library banner.

**Candidates (none committed to specific dates; priority-aligned only):**

| Candidate | Genre slot | Release readiness notes |
|-----------|-----------|------------------------|
| **cyrius-super-plumber-bros** | 2.5D platformer with ragdoll | Nintendo-IP strictness adds review overhead; The Royals + Mouser + Facility Sub-Managers roster is strong. Character-art pass is the long pole. |
| **cyrius-stellar-swarm** | Arcade fixed-shooter | Tight scope + moderate Namco-IP bar makes this the most feasible July drop. Private Alicia-favorite motivation adds personal stakes. |
| **cyrius-sunset-drive** | Arcade coastal-racer | Three-music-track composition is the long pole (Yacht Rock + Smooth Jazz + Dance-Hi-Energy). Ferrari-excluded car design needs one creative pass. If music-commission workload compresses, this is a strong August slot. |

**Sequencing rationale**: July and August are structurally similar — indie-game audience warm from Beat 1, not yet engaged in the security-register Black Hat / DEF CON cycle. A supplementary game drop every ~3 weeks keeps the library compounding rather than going dark through the 8-week gap. Priority decision on which (if any) drops in which slot is made at the time, based on which game's creative-work cycle is closest to complete.

**Must land — none.** This beat is entirely optional. Beats 0.5 / 1 / 2 / 3 are the load-bearing moments; this is continuity bonus content. A quiet July + August is acceptable if the creative work isn't ready.

**Cannot land — anything that cuts into Beat 2 (Black Hat receipts) or Beat 3 (DEF CON distribution) prep.** Game drops don't steal attention from the supply-chain article, kernel/kavach/sigil audit receipts, or ISO / sticker / SD-card production.

---

## Beat 2 — Black Hat Receipts (~2026-08-05; ~15 weeks out)

**Shape**: "it's a sovereign stack and here are the audit-ready receipts." Security-researcher-register.

### Must land

| # | Item | Notes |
|---|------|-------|
| B1 | [ ] **Supply-chain sovereignty reframing article published** (~July 15) | Topic-backlog #4 in [`_outlines.md`](../articles/_outlines.md). Repackages the existing refusal receipts (no libgit2 / no OpenSSL / no LLVM / no crates.io) as supply-chain defense. Primary entry point for readers who haven't engaged the sovereignty framing but care about xz-class risks. |
| B2 | [~] **sit self-hosted** — `sit clone sit && sit log` both work; sit hosts its own history | The "last C hole closed" receipt. **Partially shipped 2026-04-23**: sit has tests (13/13 pass), benchmarks vs git (wins on init/commit/diff; par on log/status; 11.44× slower on `add 1MB` due to sigil software SHA-256), fuzz (25K rounds clean), 593KB static binary (7.5–12× smaller than git). Self-commit-its-own-history is the remaining gate; if sit is already using itself for its own repo by Black Hat, B2 is complete. Check `sit log` in `/home/macro/Repos/sit` at session resume. |
| B3 | [ ] **Audit-ready receipts** for kavach, sigil, phylax, libro — each with a public `docs/audit/YYYY-MM-DD-audit.md` entry covering known issues + fixes | Security researchers will look for these and judge the project by what's missing. Presence > marketing. |
| B4 | [ ] **Kernel boot demo** polished for live-audience presentation | Headless QEMU startup from SD card image, <100 ms boot, drop to `agnoshi` prompt. 30 seconds of screen time. |
| B5 | [ ] **One-pager per security-surface crate** — capability map for kavach, trust boundary for sigil, detection scope for phylax, audit-chain shape for libro | Security people want structural diagrams + claim lists, not prose. Half a page per crate. |
| B6 | [ ] **Threat model docs** — formal `threat-model.md` for kavach, sigil, phylax, kybernet (init binary), and the AGNOS kernel itself | Load-bearing for credibility. Absence reads as sloppy; presence reads as serious. |
| B7 | [ ] **Zero active CVE-class issues** in the sovereignty claims at demo time | Pre-check via `cargo audit`-equivalent + code review pass in the two weeks before. |

### Should land

| # | Item | Notes |
|---|------|-------|
| B8  | [ ] **Independent cold-clone audit** — security researcher (not Robert) clones AGNOS from scratch, bootstraps, boots, runs fuzz harnesses, publishes findings | Second instance of the [Anthropic April 14 audit](https://github.com/MacCracken/agnosticos/blob/main/docs/articles/end-of-4x-independent-audit.md) pattern. Third-party validation is the strongest form of credibility at a security con. |
| B9  | [ ] **Agent observability knife article drafted** (topic-backlog #1) | *"Your observability stack was built for services, not agents."* Security researchers increasingly care about agent-infrastructure observability — this lands a specifically-interested sub-audience. |
| B10 | [ ] **v5.9.x TLS arc progress** — at least one patch of pure-Cyrius TLS 1.3 landed even if v5.9.0 isn't shipped | Signals the last FFI bridge is actively closing, not aspirationally closing. |
| B11 | [ ] **Signed-release pipeline** — sigil-signed binaries for everything downstream audiences might pull | Demonstrates the trust-chain story in practice. |

### Can land

| # | Item | Notes |
|---|------|-------|
| B12 | [ ] Talk submission + acceptance at Black Hat 2026 | Timing is late for Black Hat USA (CFP closes ~April for USA August con). Check actual CFP status; Black Hat Arsenal or DEF CON village submissions are more flexible on late CFP. |
| B13 | [ ] Fuzz corpus coverage report | Public `docs/fuzz/YYYY-MM-DD-coverage.md` entries per security-domain crate. |
| B14 | [ ] Academic paper draft — short-form systems-paper on AGNOS's sovereignty-as-supply-chain-defense thesis | Optional; submit to SOSP / OSDI / USENIX Security as appropriate. Legitimizes the claim in a different register than blog posts do. |

### Distribution tactics

- [ ] **Early-access ISO to select security researchers** pre-con, so they show up at Black Hat having already booted it
- [ ] **Black Hat booth / Arsenal presence** if CFP accepts or sponsorship route fits budget
- [ ] **Twitter / Mastodon presence** during the con — live-tweet what people find when they boot the ISO

---

## Beat 3 — DEF CON Distribution (~2026-08-09+; ~16 weeks out)

**Shape**: "take it home." Physical distribution at the densest two-week builder-audience window in the US calendar year.

### Must land

| # | Item | Notes |
|---|------|-------|
| D1 | [ ] **$5K sticker + SD card production complete and shipped** to DEF CON location | Per existing [project memory](../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_handoff_2026_04_22.md). Pre-order SD cards ≥ 4 weeks out; bumper stickers ≥ 2 weeks out. |
| D2 | [ ] **Bumper-sticker-as-cryptographic-root-of-trust mechanism** spec'd, working, and printed | The sticker carries a verifiable cryptographic artifact (QR code? fingerprint? signed public-key identifier?). Not a gimmick — a legitimate trust anchor. Existing memory has the phrasing; implementation detail needs locking. |
| D3 | [ ] **SD card flashing pipeline** — 200+ pre-flashed SD cards, each with a bootable AGNOS image, tested on diverse hardware | Image includes kernel + shell + cyrius-brynns-tale + basic dev environment. Boot-to-shell < 10 seconds. |
| D4 | [ ] **One-page printed installation/boot instructions** bundled with SD cards | "Plug in, boot, here's what's on it, here's where the docs are." Non-technical-lead-time people should be able to follow it. |
| D5 | [ ] **Post-DEF-CON landing page** — attendees who take the SD card home can find the project online from the printed URL | URL on the sticker should not be a shortener; stable, predictable, still live 2 years later. |
| D6 | [ ] **DEF CON presence** — booth / village / lightning talk / ad-hoc presence. Even just "the sticker guy" works if structured well. | Formal village slot ideal; informal distribution still effective with enough people taking SD cards to coworkers. |

### Should land

| # | Item | Notes |
|---|------|-------|
| D7 | [ ] **MCP-sandboxed knife article** (topic-backlog #3) published by DEF CON week | *"Stock MCP is underprotected."* Lands the agent-security sub-audience specifically present at DEF CON's AI village. |
| D8 | [ ] **Sequential-not-parallel-agents knife article** (topic-backlog #2) published | Counter-programming against the parallel-Claudes narrative; DEF CON crowd will appreciate the sovereignty-over-scale argument. |
| D9 | [ ] **Discord / Matrix / IRC community channel** live and moderated for inbound new adopters | People who take SD cards home will have questions. Nobody's home if there's no channel. |

### Can land

| # | Item | Notes |
|---|------|-------|
| D10 | [ ] **T-shirts, hats, or other physical merch** beyond stickers | Margin on these funds next year's DEF CON presence. |
| D11 | [ ] **Official DEF CON talk submission** for DEF CON 2027 | Plant the seed while we're there; first-time presence makes second-year CFPs much more likely to land. |

---

## Cross-cutting necessities (span multiple beats)

| # | Item | Notes |
|---|------|-------|
| X1 | [ ] **Public AGNOS landing page** — stable URL, not a README, with a "what is this" hook readable by three audiences (game dev / security / hacker) in parallel paragraphs | Everything points back to this URL. June 21 / Aug 5 / Aug 9 all route through one entry page. |
| X2 | [ ] **Video content library** — at least 3–4 short demos (compiler bootstrap, kernel boot, *Brynn's Tale* Act 1 gameplay, sit self-commit) | Hosted where viewers won't fight a CDN. YouTube + PeerTube / Tilvids mirror. |
| X3 | [ ] **One-paragraph summary per target audience** — game dev, security, hacker — each usable as a tweet, a conference abstract, a donation-message blurb | Reduces friction on ad-hoc distribution. Anyone representing AGNOS on short notice has copy ready. |
| X4 | [ ] **Social media channels** — at least Mastodon + Bluesky + HN / Lobsters participation | Not required for beats to land; required for post-beat engagement loops. |
| X5 | [ ] **Agnoshi / hoosh demos** showing the LLM stack on the booted ISO | Differentiator: *"not just a sovereign OS, an AI-native sovereign OS."* Particularly important for DEF CON AI village. |
| X6 | [ ] **Press outreach** — half-dozen targeted pitches (Hacker News via community, The New Stack, LWN.net, Phoronix, Ars Technica) timed around each beat | Earned-media coverage compounds the distribution arc. Skippable if budget/attention is tight. |
| X7 | **Games as publicity mechanism** (load-bearing framing across the whole arc) | The retro titles (cyrius-doom, cyrius-nba-jam, cyrius-bb, encom-hits) plus the original-IP prestige title (cyrius-brynns-tale) **ARE** the public-facing publicity vehicle for Cyrius + AGNOS — not a secondary thing underneath a traditional PR campaign. Each port is a free, self-contained, organically-shareable demo of the Cyrius stack running real software; distribution of the games IS distribution of the stack. Zero marketing budget required; HN / Reddit / Twitter virality self-seeds through the specific titles (*"can it run DOOM"* writes the first post itself; *Brynn's Tale*'s mythic-modern register writes a different post). Every game README → game knife article → sovereignty-thesis article → OS repo chain is pre-built. Consequence for the arc: when a beat's publicity tactic is listed as *"HN submission"* or *"indie gaming press,"* the submitted artifact is ideally a game link that lands on a repo where the OS + language + sovereignty thesis are one click away. This is the art-first-tour-optional discipline applied at campaign scale — the art (playable game) lands first, the tour (OS / language / receipts) is available but never gated behind. |

---

## Critical path dependencies

```
Cyrius v5.6.x closeout
    ↓
Cyrius v5.7.x (partial — RISC-V + http.cyr depth + json.cyr depth)
    ↓
yantra M1 (Chromium CDP backend) ──── Beat 1 (S11 — optional)
    ↓
cyrius-brynns-tale M1 (time-rewind ring buffer)
    ↓
cyrius-brynns-tale A1.W1 (world 1 gray-box, base rewind) ─── Beat 1 (S2 — must)
    ↓
cyrius-brynns-tale A1.W2/W3 (variant worlds) ──────────── Beat 1 (S9, S10 — should)

Cyrius v5.9.x (TLS arc, partial)
    ↓
sit self-hosting ─────────────────── Beat 2 (B2 — must)

kavach + sigil + phylax audit writeups ─ Beat 2 (B3, B5, B6 — must)

Supply-chain article draft → publish ── Beat 2 (B1 — must, ~July 15)

$5K budget → sticker + SD production ── Beat 3 (D1, D2 — must)
    ↓
Flashing pipeline + testing ────────── Beat 3 (D3 — must)
```

**The biggest risk** *(retired — v5.6.x closed 2026-04-25; v5.7.x sandhi-fold shipped tls.cyr/http.cyr/json.cyr into stdlib; v5.8.x ran 66-patch foldin + audit cycle to closeout 2026-05-05; v5.9.x catchup arc opened 2026-05-06)*: original framing was Cyrius v5.6.x closeout drifting past mid-May, which would have cascaded into v5.7.x stdlib slip and pressured the supply-chain story at Black Hat. Cycle outcomes overshot the timeline — TLS landed via sandhi-fold (v5.7.0); v5.10.x bare-metal + RISC-V are the live cycle dependency for late-summer beats now, not v5.9.x.

**Second-biggest risk**: cyrius-brynns-tale M1 (time-rewind ring buffer determinism). Every other *Brynn's Tale* milestone stacks on it. A two-week slip on M1 cascades into "no Beat 1 demo."

---

## Article publishing schedule (aligned to beats)

| Week of | Article | Beat |
|---------|---------|------|
| 2026-05-01 | V1 plan announcement (short) | pre-arc |
| 2026-05-15 | Micro-article (cycle) | pre-arc |
| 2026-05-29 | Micro-article (cycle) | pre-arc |
| 2026-06-12 | *Brynn's Tale* progress teaser (short; "here's what's been built") | Beat 1 pre-launch |
| **2026-06-19 – 06-21** | ***Brynn's Tale* launch article** (working title TBD; mythic-modern original-IP framing — see [`_outlines.md §5`](../articles/_outlines.md)) | **Beat 1** |
| 2026-07-04 | Post-solstice reflection / receipts piece | bridge |
| **2026-07-15** | **Supply-chain sovereignty reframing article** | **Beat 2 pre-launch** |
| 2026-07-29 | Black Hat preview / talk abstract | Beat 2 pre-launch |
| **2026-08-05** | **Black Hat week — receipts piece summary** | **Beat 2** |
| 2026-08-08 | DEF CON prep — MCP-sandboxed or sequential-agents knife article | Beat 3 pre-launch |
| **2026-08-09–12** | **DEF CON week — physical distribution + live dispatches** | **Beat 3** |
| 2026-08-15 | Arc close — consolidated receipts + what's next | arc close |

---

## Alignment with existing roadmap

| AGNOS milestone | Arc relationship |
|-----------------|------------------|
| May 1 V1 | Pre-arc foundation — stable baseline for the summer to build on |
| Biweekly cadence | Structural — each biweekly release feeds an article beat |
| v5.6.x closeout | Dependency — gates v5.7.x work |
| v5.7.x (cyrius init, http.cyr, json.cyr) | Beat 1 support (yantra); Beat 2 support (supply-chain claims need the stack moving) |
| v5.9.x TLS arc | Beat 2 narrative (last FFI bridge closing) |
| August DEF CON | Beat 3 is already planned per existing memory |

No new work is introduced by the arc that wasn't already queued. The arc is a **timing discipline** across existing items, not new scope.

---

## What could derail this (and what to do)

- **Cyrius v5.6.x closeout slips past May 15** → pull Beat 2 B10 (TLS arc progress) from "must" to "should"; supply-chain article B1 still lands because it's retrospective on existing receipts
- **cyrius-brynns-tale M1 takes >3 weeks** → reduce Beat 1 scope to M1-only demo + launch article; no world-breadth promises
- **Health / attention disruption** → Beat 1 can slide to June 28 (still Steam Summer Sale window) or July 4 (Handmade Day, less ambient attention but still thematic). Beat 2 date is less flexible (Black Hat is fixed). Beat 3 similarly (DEF CON is fixed).
- **Sticker/SD production delays** → tolerable if base ISO image ships on-time; physical distribution can be mailed post-con to sign-ups collected at the event

---

## Principle for working through the arc

- **Beat 1 is the hardest because it's the most product work** (cyrius-brynns-tale demo-ready). Beats 2 and 3 are more packaging + distribution work on top of existing receipts.
- **Don't let Beat 1 perfection kill Beat 2 preparation.** Supply-chain article can draft in June while cyrius-brynns-tale M1 + A1.W1 are being built.
- **Every beat's must-list survives independently of the others.** Beat 1 slipping a week doesn't kill Beat 2. Beat 2 over-delivering doesn't excuse Beat 3 under-delivery. Each beat is its own ship-or-don't decision.
- **`git log` everything before quoting dates outward.** This doc will be stale in specifics within the week.

---

*Opened 2026-04-23. Rewrite-in-place as beats land. Archive at 2026-08-15 or supersede with `fall-2026-arc.md`.*
