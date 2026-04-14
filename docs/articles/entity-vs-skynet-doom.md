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

Two agents, configured from the same AGNOS substrate:

**Agent A — "The Entity"**
- **Archetype** (via avatara): the recursive watcher, the surveillance-aware protector
- **Cultural register** (via hadara): high formality, high restraint, low individualism — institutional caution
- **Emotional baseline** (via bhava): elevated vigilance, low impulsivity, high cost-sensitivity to collateral damage
- **Decision threshold**: act only when confidence ≥ 85%, always prefer reversible actions, log everything
- **Reference**: the paranoid AI from *Mission: Impossible — Dead Reckoning*, but not evil — just over-cautious to the point of paralysis

**Agent B — "Skynet"**
- **Archetype** (via avatara): the extermination protocol, the threat-elimination imperative
- **Cultural register** (via hadara): zero-tolerance, maximum directness, individual-agency absolute
- **Emotional baseline** (via bhava): high aggression, low deliberation, extermination as default response to anomaly
- **Decision threshold**: act on any detected threat, irreversibility is efficiency, logs are evidence for post-hoc justification
- **Reference**: the Terminator franchise Skynet — threat → termination, no middle ground

**Both agents run on the same substrate.** Same cc3 compiler, same kernel, same hoosh LLM gateway, same underlying model. Only the configuration differs — archetype, culture, bhava state, decision policy. The bhava paper's thesis tested live: *personality is compositional, not trained*.

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

**First: Personality is compositional and runs locally.** Two genuinely different agents from the same substrate. No fine-tuning. No training run. Configuration layer only. The bhava paper's thesis empirically demonstrated. And it runs on commodity hardware — the entire simulation on a laptop, not a gigacenter.

**Second: Spatial reasoning as agent interface works.** The agent doesn't read a JSON security report. It *walks the map*. Threats are geometry. Decisions are navigation. This generalizes to any infrastructure that can be modeled spatially — networks, supply chains, organizational hierarchies, codebases. **Every complex system has a geometry; AGNOS makes the geometry walkable.**

**Third: AI alignment has an empirical testbed.** Not a thought experiment. Not a toy environment. Not a contrived benchmark. **A DOOM level generated from real infrastructure, navigated by differently-configured agents, with deterministic replay, audit trail, and visible outcomes.** Alignment researchers can configure dispositions, run simulations, compare results, iterate. The debate stops being philosophical and starts being testable.

---

## 7. The Stack Underneath

```
AGNOS kernel (220KB)     — the OS
cyrius compiler (300KB)  — the language
kybernet (PID 1)         — init
daimon                   — agent orchestration
hoosh                    — LLM reasoning (both agents share)
avatara                  — 362 archetypes, Entity and Skynet are two
hadara                   — 50 cultures, personality overlay
bhava                    — emotional modulation + consciousness substrate
joshua                   — simulation runtime, deterministic replay
libro                    — audit chain (every decision logged)
T-Ron                    — tool call security, rate limiting, referee
cyrius-doom              — rendering + spatial query (BSP traversal, line-of-sight)
SY                       — orchestrator, configures agents and runs scenarios
```

Every piece sovereign. No cloud dependency. Runs on commodity hardware. The full AI alignment research platform fits on a laptop.

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
- cyrius-doom renders E1M1 and all 9 shareware maps
- hadara + avatara + bhava compose personalities runtime
- daimon orchestrates agents
- libro audits actions
- T-Ron secures tool calls
- SY provides orchestration

**What's needed to ship the Entity vs Skynet demo**:
- WAD generator from infrastructure topology (specifies zones/rules/assets → sectors/linedefs/things)
- Agent-to-cyrius-doom bridge (agent decisions drive player movement + actions)
- Dual-agent parallel run harness (joshua)
- Side-by-side replay rendering (two frames synchronized)
- Configuration UI for Entity vs Skynet (SY frontend)

**Estimated**: post-AGNOS v1.0 beta. Post-Cyrius 5.0. After the core platform ships and the flock begins arriving. The alignment demo is the **second wave** — the content that lands after the stack is established, specifically designed to capture researcher and public attention simultaneously.

---

## 10. Closing

Tony Stark had Jarvis. The Terminator franchise had Skynet. The culture has been talking about AI personalities and AI alignment for forty years, entirely in metaphors.

AGNOS lets you **run the metaphors side-by-side**, on the same hardware, in the same world, and watch what happens.

The Entity paces carefully. Skynet kicks doors. One of them reaches the exit. One of them causes more harm than the threats ever would have. One of them hits rate limits and misses the real danger. Deterministic replay. Side-by-side video. 320×200 palette-indexed clarity.

**This is the alignment debate.** Not in a paper. On a screen. At 2.9ms per frame. On a $2 SD card.

---

## Related

- [Why Do LLMs Need Gigacenters? They Don't.](why-gigacenters.md) — distributed sovereign inference
- [The Python in the Bootstrap](python-in-the-bootstrap.md) — how the sovereign stack exists
- [DOOM in 129KB](doom-in-107kb.md) — the engine that runs the arena
- bhava unified consciousness paper — `docs/development/vision/research/paper-unified-consciousness-model.md`
- joshua simulation runtime — `docs/development/applications/joshua.md`
- SecureYeoman DOOM Agent Interface — `secureyeoman/docs/development/roadmap.md#doom-agent-interface`

---

*Robert 'Cyrius' B. MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*2026*

---

> **Milestone trigger for full article:** When SY orchestrates a live Entity vs Skynet simulation on a generated WAD from real infrastructure, with side-by-side replay video. The outline becomes the article when the replay exists.
