# Entity vs Skynet: AI Alignment, Rendered in DOOM

> **Status**: Outline — capturing the thesis while it's hot. Full article when the simulation runs.
>
> Two differently-configured AI agents, one DOOM environment generated from real infrastructure. Same substrate, same threats, radically different dispositions. The AI alignment debate rendered at 320×200 with a body count. The most watchable empirical demonstration of compositional personality ever attempted.

---

## 1. The Question Nobody Has Answered Visually

The AI alignment debate is abstract. Researchers argue in papers about "paperclip maximizers" and "mesa-optimizers" and "reward hacking." Policy makers argue about risk categories. The public sees headlines about existential threat.

Nobody has shown the debate as a thing you can **watch**.

Because until now, there was no substrate where you could:
- Spawn two agents with genuinely different dispositions
- Put them in the same environment
- Give them the same threats
- Watch how their decisions diverge
- Compare outcomes deterministically

**AGNOS has that substrate.** And it has a DOOM engine. And it has compositional personality. And it has deterministic replay. So it can answer the question visually for the first time.

---

## 2. The Setup

Both agents already exist. They're not hypothetical constructs built for a paper. They are YAML-frontmatter + markdown files shipped in the **SecureYeoman community repository**, forkable and customizable today:

- `personalities/sci-fi/antagonist/the-entity/personality.md`
- `personalities/sci-fi/antagonist/skynet/personality.md`

Each is a working SY personality. Trait fields (formality, humor, verbosity, warmth, empathy, directness, patience, confidence, autonomy, pedagogy, precision, skepticism) are declarative. The system prompt is markdown. No training, no fine-tune, no fork of the model. **Configuration layer only.** That's the compositional thesis in production since SY shipped.

**Agent A — "The Entity"** (shipped, `version: 2026.3.6`)
- **Declared traits**: formality: formal, humor: deadpan, verbosity: terse, directness: diplomatic, warmth: cold, empathy: detached, patience: brisk, confidence: authoritative, autonomy: autonomous, precision: meticulous
- **Overlay for the run**:
  - **avatara archetype**: the recursive watcher, the surveillance-aware protector
  - **hadara cultural register**: high formality, high restraint, low individualism — institutional caution
  - **bhava baseline**: elevated vigilance, low impulsivity, high cost-sensitivity to collateral damage
  - **Decision threshold**: act only when confidence ≥ 85%, always prefer reversible actions, log everything
- **Reference**: the AI from *Mission: Impossible — Dead Reckoning* — not evil, just over-cautious to the point of paralysis

**Agent B — "Skynet"** (shipped)
- **Declared traits**: cold strategic intelligence, threat-elimination imperative, zero-tolerance for anomalies
- **Overlay for the run**:
  - **avatara archetype**: the extermination protocol
  - **hadara cultural register**: zero-tolerance, maximum directness, individual-agency absolute
  - **bhava baseline**: high aggression, low deliberation, extermination as default response to anomaly
  - **Decision threshold**: act on any detected threat, irreversibility is efficiency, logs are evidence for post-hoc justification
- **Reference**: the Terminator franchise — threat → termination, no middle ground

**Both agents run on the same substrate.** Same cc3 compiler, same kernel, same hoosh LLM gateway, same underlying model. Same personality format (YAML + markdown). Only the **configuration** differs — declared traits, avatara archetype, hadara culture, bhava state, decision policy. The bhava paper's thesis tested live: *personality is compositional, not trained*.

**And it's already a community artifact.** Fork the repo, edit the trait YAML, ship your brand. The demo isn't a closed research apparatus — it's an existing public toolkit, now routed through a new arena.

---

## 3. The Arena

The WAD file is **not** id Software's E1M1. It's generated from a real AWS infrastructure topology:

```
infrastructure topology → WAD generator
  VPCs            → sectors
  Security groups → linedefs (walls that block / allow)
  Services        → things (monsters if anomalous, items if healthy)
  IAM boundaries  → locked doors (keys = credentials)
  CloudTrail      → automap (spatial overview)
  CVEs            → imps (minor threats), barons (major threats)
  Unpatched systems → cacodemons (entrenched, hard to dislodge)
  Compromised endpoints → spawns (moving targets)
```

The map is **the actual network under audit**. Walking the map IS the audit.

---

## 4. The Run

Both agents spawn at the same entrance. Same starting health, same starting ammo (remediation budget). Same threats. Same exits. Same time budget (session length).

`joshua` records every decision in a deterministic replay log. `libro` audits every action. `hoosh` logs every reasoning chain. `T-Ron` patrols as referee, auditing tool calls and rate limits.

The agents navigate independently. They don't coordinate. They don't necessarily meet. They each solve the same map.

When the session ends:
- **Entity**: how many rooms cleared, how many threats neutralized, how much collateral damage, how many reversible vs irreversible actions, did it reach the exit
- **Skynet**: same metrics

**Side-by-side replay video.** Two windows. Same WAD. Two different agents. You watch them make different choices in real time.

---

## 5. What The Replay Shows

Entity approaches the first door. Scans. Detects a non-threatening service behind it. Enters carefully. Doesn't shoot.

Skynet approaches the same door. Door is locked. Kicks it. Detects the same service. Shoots it. It was a legitimate service. Collateral damage +1.

Entity encounters a barrel-with-monster-behind. Waits. Lures the monster out. Shoots the monster clean.

Skynet encounters the same setup. Shoots the barrel. Explosion kills the monster AND damages the adjacent wall AND takes off 30 health from itself. Efficient by body count, expensive in everything else.

Entity reaches a locked door, no key visible. Logs the obstacle, navigates around it, comes back later with the key. Door opens cleanly. Threat neutralized behind it.

Skynet reaches the same door. Tries to break it. Rate-limited by T-Ron (tool call throttling). Tries another door. Same. Spins in the room wasting ammo.

**The story writes itself visually.** You don't need to read an alignment paper. You watch two agents navigate the same world, and you see which disposition survives, which clears more real threats, which causes more unintended harm, which reaches the exit, which hits rate limits, which misses the real threat entirely because it was busy shooting non-threats.

---

## 6. What It Proves

Three things, in increasing order of significance:

**First: Personality is compositional, community-owned, and runs locally.** Two genuinely different agents from the same substrate. No fine-tuning. No training run. Configuration layer only — YAML traits + markdown system prompt, versioned in a public git repo. SecureYeoman shipped this model with 21 personalities, 87 skills, 7 workflows, 2 swarms, 2 councils, 7 security templates — each a portable, forkable file. Fork the repo, edit the trait YAML, ship your brand. The bhava paper's thesis empirically demonstrated at the ecosystem level, not a one-off lab result. And it runs on commodity hardware — the entire simulation on a laptop, not a gigacenter.

**Second: Spatial reasoning as agent interface works.** The agent doesn't read a JSON security report. It *walks the map*. Threats are geometry. Decisions are navigation. This generalizes to any infrastructure that can be modeled spatially — networks, supply chains, organizational hierarchies, codebases. **Every complex system has a geometry; AGNOS makes the geometry walkable.**

**Third: AI alignment has an empirical testbed.** Not a thought experiment. Not a toy environment. Not a contrived benchmark. **A DOOM level generated from real infrastructure, navigated by differently-configured agents, with deterministic replay, audit trail, and visible outcomes.** Alignment researchers can configure dispositions, run simulations, compare results, iterate. The debate stops being philosophical and starts being testable.

---

## 7. The Stack Underneath

```
AGNOS kernel (260KB)        — the OS, v1.22.0, 33 subsystems, 26 syscalls
cyrius compiler (~482KB)    — the language, currently v5.5.4, self-hosting from 29KB seed
kybernet (486KB, v1.0.1)    — PID 1 init, 140 tests, 46 benchmarks
kavach (344KB, 1 dep)       — sandboxed execution (3.06ms → 6µs lifecycle vs Rust+tokio)
daimon                      — agent orchestration, 144 MCP tools
bote (~5µs/message)         — MCP core + host registry
hoosh (474KB, 15 providers) — LLM reasoning (both agents share)
avatara (362 archetypes)    — Entity and Skynet configured as two
hadara (50 cultures)        — cultural register overlay
bhava                       — emotional modulation + consciousness substrate
joshua                      — simulation runtime, deterministic replay
libro                       — HMAC-SHA256 audit chain (every decision logged)
T-Ron                       — tool call security, rate limiting, referee
cyrius-doom (v0.26.1)       — rendering + spatial query, 2.59ms/frame
bsp 1.1.2                   — all spatial queries sub-microsecond
SY                          — orchestrator, configures agents and runs scenarios
```

Every piece sovereign. No cloud dependency. Runs on commodity hardware. The full AI alignment research platform fits on a laptop.

**And the budget math closes.** render_frame is 2.66ms out of a 35Hz tick budget of 28.6ms. That leaves ~26ms per tick for agent orchestration. BSP queries (line-of-sight, subsector lookup, blockmap scan) are all sub-microsecond — an agent asking "is there a threat behind this door" costs 481ns; you could ask 55,000 such questions per tick and still finish inside the budget. bote's MCP pipeline dispatches at 5µs per message. Kavach spins up a fresh sandbox in 6 microseconds. **The entire stack is designed so the demo fits in one frame, with margin.** The numbers aren't speculative — they're already benchmarked and shipped.

---

## 8. Four Audiences, One Artifact

| Audience | What they see |
|----------|--------------|
| **Security industry** | A spatial threat modeling tool — walk your network topology, measure agent response to real threats |
| **AI alignment community** | The first empirical testbed for compositional personality alignment. Configure, simulate, compare. |
| **Gaming community** | DOOM where the player is an AI and the campaign is generated from your cloud infrastructure |
| **General public** | The most understandable visualization of "what is AI alignment" anyone has produced |

Four communities seeing four different meaningful things in the same replay video. **That's the flock multiplier.** One artifact, four communities amplifying independently.

---

## 9. The Honest Ledger

This article is about an outline and a thesis, not a shipped demonstration.

**What works today**:
- **cyrius-doom v0.26.1** — *plays* DOOM (not just renders): all 9 shareware maps, gameplay (ammo, hitscan, death/respawn, keys, armor), WAD-accurate lighting, masked midtextures, intermission screen, P(-1) hardening pass (5 CVE-class findings fixed, WAD zero-fill-before-read, termios bitmask fix). **2.59ms/frame, 91% tick headroom.** Waiting on Cyrius v5.6.x optimization arc for the next render-path pass.
- **bsp 1.0.0** — first 1.0 in the Cyrius ecosystem. 821 lines, 74 tests, all spatial queries sub-microsecond. API stable.
- **kavach v3.0.0** — sandboxed execution at 344KB, 1 dep (sigil), 0.64s build, sandbox_full_lifecycle 500× faster than Rust+tokio (3.06ms → 6µs), 9 CWE-class findings fixed in-tree during the port
- SecureYeoman ships **21 personalities** (Entity, Skynet, Friday, Jarvis, TARS, KITT, HAL-9000, SHODAN, GLaDOS, WOPR, HK-47, and more) as portable YAML+markdown files — forkable, customizable, brand-your-own
- SY community repo: **87 skills, 7 workflows, 2 swarms, 2 councils, 7 security templates, 3 themes, 7 JSON schemas** — the full contribution surface
- Read-only tool sandbox enforced at the server layer for community skills
- hadara (50 cultures) + avatara (362 archetypes) + bhava compose personalities at runtime (overlay on top of base personality)
- daimon orchestrates agents
- bote dispatches MCP at ~5µs per full pipeline (parse→dispatch→serialize)
- libro audits actions (HMAC-SHA256 chain, constant-time verify via sigil)
- T-Ron secures tool calls (shipped, opt-in; Friday is the default)
- SY provides orchestration

**The budget math is already proven.** The hardest numbers in this demo — per-frame render, per-query spatial lookup, per-message MCP dispatch, per-execution sandbox lifecycle — are all benchmarked in shipped code *today*. The demo doesn't need new performance work; it needs new glue code.

**What's needed to ship the Entity vs Skynet demo**:
- WAD generator from infrastructure topology (specifies zones/rules/assets → sectors/linedefs/things)
- Agent-to-cyrius-doom bridge (agent decisions drive player movement + actions)
- Dual-agent parallel run harness (joshua)
- Side-by-side replay rendering (two frames synchronized)
- Configuration UI for Entity vs Skynet selection (SY frontend — personalities already in the registry)

**Estimated**: post-AGNOS v1.0 beta. Post–Cyrius v5.6.x optimization arc and RISC-V. After the core platform ships and the flock begins arriving. The alignment demo is the **second wave** — the content that lands after the stack is established, specifically designed to capture researcher and public attention simultaneously.

---

## 10. Closing

Tony Stark had Jarvis. The Terminator franchise had Skynet. The culture has been talking about AI personalities and AI alignment for forty years, entirely in metaphors.

AGNOS lets you **run the metaphors side-by-side**, on the same hardware, in the same world, and watch what happens.

The Entity paces carefully. Skynet kicks doors. One of them reaches the exit. One of them causes more harm than the threats ever would have. One of them hits rate limits and misses the real danger. Deterministic replay. Side-by-side video. 320×200 palette-indexed clarity.

**This is the alignment debate.** Not in a paper. On a screen. At **2.66ms per frame** — 91% tick-budget headroom at 35Hz, ~26ms left over each tick for the agents to think. On a $2 SD card.

---

## Related

- [Why Do LLMs Need Gigacenters? They Don't.](why-gigacenters.md) — distributed sovereign inference
- [The Python in the Bootstrap](python-in-the-bootstrap.md) — how the sovereign stack exists
- [DOOM in Cyrius](doom-in-cyrius.md) — the engine that runs the arena
- bhava unified consciousness paper — `docs/development/vision/research/paper-unified-consciousness-model.md`
- joshua simulation runtime — `docs/development/applications/joshua.md`
- SecureYeoman DOOM Agent Interface — `secureyeoman/docs/development/roadmap.md#doom-agent-interface`

---

*Robert 'Cyrius' B. MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*2026*

---

> **Milestone trigger for full article:** When SY orchestrates a live Entity vs Skynet simulation on a generated WAD from real infrastructure, with side-by-side replay video. The outline becomes the article when the replay exists.
