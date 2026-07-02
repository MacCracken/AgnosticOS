# Tanur — Sovereign Desktop LLM Studio (Cyrius)

> **Tanur** (Persian/Arabic: تنور — *forge, kiln*) — the native windowed desktop app for AGNOS model management, training oversight, and inference. A pure Cyrius client that *renders* the sovereign ML stack; it forges nothing itself, it presents the forge.

| Field | Value |
|-------|-------|
| Status | **Re-architected planning doc (Cyrius-native), 2026-07-01. Supersedes the Rust egui/iced/Tauri draft (last touched 2026-05-09).** No repo exists; **do not scaffold** (see the Honest Gate). |
| Priority | Deferred — desktop-stage, gated behind the Cyrius desktop/UI path (puka) reaching maturity. |
| Name | `tanur` (تنور) — kept as a **reserved** name; reserving it does not commit to the repo existing. |
| Language | **Cyrius** (native windowed binary; no Rust, no Electron, no web runtime). |
| GUI substrate | **puka lineage** — Wayland-wire-from-scratch → mabda GPU → `wl_shm`; kashi glyph atlas + darshana ANSI/TTY; planned sadish/rekha vector graphics. |
| Transport | **sandhi** sockets (HTTP/Unix/TCP from scratch) — NOT reqwest/tokio/serde. |
| Connects to | the sovereign services *as their client contracts are defined* — hoosh (serving/chat), ifran-control-plane (train/eval/dataset/lineage), mela (marketplace), seema/daimon (fleet). Never murti/models directly. |
| Domain | desktop control surface for the sovereign ML/AI layer. |

---

## The Honest Gate (read this first)

**Tanur cannot be real until the Cyrius desktop UI path is real.** This is a hard dependency inversion, not a footnote:

- The entire Rust-era design (egui/iced/Tauri) is deleted. Those toolkits are non-sovereign externals and violate the AGNOS thesis exactly the way llama.cpp/vLLM do on the runtime side.
- The sovereign replacement is **puka** — the first windowed Cyrius program, which speaks the Wayland wire protocol from scratch (no libwayland, no toolkit, no FFI), renders through mabda GPU into `wl_shm`, and draws text via kashi/darshana.
- **puka itself is early.** Until puka proves the windowed-app loop (surface creation, damage/commit, input dispatch, a reusable widget vocabulary) and until sadish/rekha give vector primitives for charts and DAGs, tanur is a **paper design over an incomplete substrate**.

So this doc is staged as: *what the substrate must provide* → *what tanur is once it does* → *phased build behind that gate*. **The correct next action for "make tanur real" is to advance puka, not to create tanur.** Do not scaffold a tanur repo.

---

## Why First-Party (unchanged thesis, sovereign means)

The LM-Studio problem is still valid: the desktop LLM-management category is owned by closed, Electron, inference-only tools that can't touch training, eval, fleet, marketplace, or an OS-level agent runtime with per-agent budgets. AGNOS wants a first-party desktop studio.

What changed is **everything below the GUI is now sovereign Cyrius**, so tanur no longer sits on a Rust runtime talking to a Rust monolith. It is a thin native client over a Cyrius control plane and a Cyrius serving plane.

---

## The Sovereign Layer Tanur Sits On (verified 2026-07-01)

Tanur is a **pure client** and owns zero model logic. The real stack beneath it, and who owns what:

| Concern | Sovereign owner | Notes |
|---|---|---|
| **Serving / chat / inference** | **hoosh 2.4.11** | OpenAI-compatible gateway; routing, budgets, per-agent accounting, cloud fallback behind a seam |
| **Local inference math** | **rosnet 0.2.0** (f64 + `[lib.gpu]`), **tentib 0.4.0** (matmul-free ternary kernel — *correctness-ready; throughput gated on cyrius int-SIMD*), **Type-3 weight importer** (planned) | the sovereign inference path hoosh drives — NOT a shell to llama.cpp |
| **Training control plane** | **ported ifran** (from ifran 1.3.0 Rust holdover) | job mgmt/scheduling, checkpoint store, dataset load/validate/curate, HPO sweep, eval runner, lineage — the CONTROL PLANE, not the math. *(Whether this is one repo or a cluster of control-plane services is itself open — see the stack audit.)* |
| **Training math** | **attn11** (SFT/diffusion), **tarka** (RL/DPO/IPO/KTO), **prajna** (meta), **tentib** (ternary), **amuzesh** (classical) | ifran orchestrates; the siblings compute |
| **Marketplace** | **mela 1.0.1** | signed agent/model marketplace |
| **Fleet** | **seema** (edge fleet, Pending) + **daimon 1.2.9** | node registry, health, deployment |
| **Lineage / versioning** | **itihas** (via ifran-control-plane) | provenance DAG; ifran surfaces it, itihas stores it |
| **GPU detect / plan** | **ai-hwaccel 2.3.12** + **mabda 3.4.5** | surfaced through ifran/hoosh, not queried by tanur directly |

**murti is not in tanur's path.** The old "embedded murti wrapping 15 external inference backends" is anti-thesis; its legitimate responsibilities re-homed (local math → rosnet/tentib; run-someone-else's-weights → the Type-3 importer; serving → hoosh). Any residual desire to run a *foreign* engine lives behind a **mehman/kavach** compat seam — never in the primary path, and never something tanur reaches into.

---

## Design Principles (sovereign revision)

1. **Pure client, zero logic.** No model runtime, no inference, no training. Tanur renders state fetched over sandhi and issues commands over sandhi. All state lives server-side.
2. **sandhi-first transport.** Default is the control-plane Unix socket under `/run/agnos/`; TCP for a remote control plane. Chat/inference streams come from hoosh. All HTTP/socket work is **sandhi**, hand-rolled — no reqwest, no tokio, no serde. Wire framing is defined by the *owning services* and parsed by sandhi.
3. **Native windowed, sovereign toolkit.** Cyrius binary on the **puka** lineage: Wayland wire from scratch → mabda GPU → `wl_shm`; text via kashi/darshana. No Electron, no web runtime, no FFI toolkit.
4. **Progressive disclosure.** Chat + model browse are front and center (the LM-Studio replacement surface). Training, eval, fleet, lineage are discoverable, not overwhelming — a real constraint given the widget vocabulary will be young.
5. **Streaming without polling — but honest about the primitive.** Inference chunks, training progress, and fleet health arrive as event streams over sandhi. The *shape* is whatever the owning service exposes; tanur consumes, does not dictate.
6. **Charts/DAGs need vector graphics — and that's a gate.** Loss curves, GPU meters, and lineage DAGs require sadish/rekha (planned). Until those land, those panels degrade to darshana-drawn text tables, not real graphs.

---

## Architecture

### Connection model (sovereign — client of contracts *as they are defined*)

```
Tanur (Cyrius windowed app, puka lineage)
  │
  ├── sandhi ──→ hoosh                  (chat / inference serving, budgets, routing)
  │                   └── rosnet (f64+GPU) · tentib (ternary) · Type-3 importer · cloud fallback (seam)
  │
  ├── sandhi ──→ ifran-control-plane   (training / eval / dataset / experiment / lineage)
  │                   └── orchestrates attn11 / tarka / prajna / tentib / amuzesh
  │                   └── checkpoint store · itihas lineage · ai-hwaccel/mabda plan
  │
  ├── sandhi ──→ mela                   (signed model/agent marketplace)
  └── sandhi ──→ seema / daimon         (edge fleet + agent orchestration)
```

**Key inversion from the Rust doc:** the old tanur connected to *exactly one* endpoint (ifran's socket) and everything tunneled through ifran → hoosh → murti. The sovereign layer is decomposed into separately-releasable services (monolithic-by-design), so tanur will be a **multi-endpoint client** coupling to each owner's socket contract rather than one god-service.

> **Caveat (do not over-commit the wiring):** most of these client contracts **do not exist yet** — ifran-control-plane is unbuilt, seema is Pending, and mela/hoosh have no stated GUI-client wire API. Tanur consumes each owner's contract *as that owner defines it*; this diagram is the intended shape, **not** a fixed set of endpoints to design against now. Tanur's own puka gate means these contracts will be defined by their owners long before tanur can consume them.

### Panel re-mapping (old → current owner)

Every Rust-era panel keyed off ifran's 21 REST groups. Re-mapped to the decomposed sovereign owners:

| Panel | Old (ifran REST) | Current sovereign owner | Substrate need |
|---|---|---|---|
| **Chat** | ifran `/v1/chat/completions` | **hoosh** (OpenAI-compat) | text render (kashi/darshana), streaming over sandhi |
| **Model Hub** | ifran `/models` + `/marketplace` | **hoosh** (`/v1/models` local) + **mela** (marketplace) | list/cards = text; pull progress = text bar |
| **Training** | ifran `/training/jobs` | **ifran-control-plane** (drives attn11/tarka/prajna) | job forms, progress stream; loss curve wants sadish/rekha |
| **Distributed Training** | ifran `/training/distributed` | **ifran-control-plane** + **seema** (workers) | worker table = text; placement map wants vector gfx |
| **Experiments** | ifran `/experiments` | **ifran-control-plane** | leaderboard table = text |
| **Evaluation** | ifran `/eval/runs` | **ifran-control-plane** (eval runner over the siblings) | results table; compare = side-by-side text |
| **Datasets** | ifran `/datasets` | **ifran-control-plane** (load/validate/curate) | preview/validate = text; drag-drop needs puka input |
| **RAG** | ifran `/rag` | **research-watch retrieval lane** (kNN-LM/RETRO over an ANN index atop patra) — *not* the control plane | deferred behind that lane existing |
| **RLHF / Preference** | ifran `/rlhf` | **ifran-control-plane** (annotation store) → exports to **tarka** (DPO/IPO/KTO) | A/B side-by-side = text panes |
| **Fleet** | ifran `/fleet` | **seema** (fleet) + **daimon** (agents) | node table = text; GPU gauges + map want vector gfx |
| **Lineage** | ifran `/lineage`, `/versions` | **ifran-control-plane** ← **itihas** | ancestry DAG **requires** sadish/rekha (hardest panel) |
| **System** | ifran `/system/status`, GPU telemetry | **hoosh** + **ai-hwaccel/mabda** surfaced via ifran | hardware = text; GPU telemetry gauges want vector gfx |

**Reading of the gate from this table:** the *form-and-table* panels (chat, model list, job forms, leaderboards, eval results, RLHF A/B) are buildable on **text-only puka + kashi/darshana**. The *graphical* panels (loss curves, GPU gauges, lineage/ancestry DAG, fleet map) are **blocked on sadish/rekha**. Tanur can ship a useful text-tier v1 and grow into the graphical tier.

### UI substrate: exists vs still needed (the real honesty)

| Capability tanur needs | Source | Status |
|---|---|---|
| Window / surface (Wayland wire, no libwayland) | **puka** | **Early — proving the loop.** Whole app depends on this. |
| GPU-backed pixel buffer (`wl_shm` via mabda) | **puka** + **mabda 3.4.5** | mabda mature; the puka→`wl_shm` bring-up is the young part |
| Monospace/glyph text | **kashi** (v1.0.0) + **darshana** | stable — the solid tier |
| Input dispatch (keyboard/pointer, focus, drag-drop) | **puka** | needed for forms, chat, RLHF clicks, dataset drag-drop |
| Reusable widgets (button, list, form field, tab, scroll) | **none yet** | **the biggest missing piece** — second-consumer-extract from puka when tanur is the concrete consumer; do NOT pre-build a toolkit lib |
| Vector graphics (lines, curves, filled paths, graphs) | **sadish / rekha** | **planned, not built** — gates all chart/DAG/gauge panels |
| Socket/HTTP/stream transport | **sandhi** | client-side transport dep; must handle streaming |
| Markdown/code-block rendering in chat | **none yet** | small sovereign renderer over kashi; likely tanur-local until a 2nd consumer appears |

The **widget vocabulary** is as much the blocker as vector graphics. puka proves *a* window; a *studio* with a dozen panels needs buttons, tabbed nav, scrollable lists, text entry. Per second-consumer-extraction: do **not** pre-build a Cyrius GUI toolkit as a library — let puka carry the first widgets inline; extract a shared widget layer only when tanur (or another windowed app) is the concrete second consumer.

---

## Revised Cyrius Dependency Set

The Rust dep table (eframe/egui, reqwest, tokio, serde, eventsource-client, hyper-unix-connector, chrono, tracing) is **entirely deleted**.

| Dependency | Role | Status |
|---|---|---|
| **puka** | windowing / surface / input (Wayland-wire-from-scratch) | early — hard gate |
| **mabda** | GPU render into `wl_shm` | stable (3.4.5) |
| **kashi** | glyph atlas / console fonts | stable (v1.0.0) |
| **darshana** | TTY/ANSI/color/cursor primitives | stable |
| **sadish / rekha** | vector graphics (charts, DAGs, gauges) | planned — gates graphical panels |
| **sandhi** | HTTP/socket/stream transport to services | dependency; must support streaming |
| Cyrius stdlib | everything else (no external runtime) | — |

No rosnet/tentib/mabda-as-inference and no ai-hwaccel dependency *in tanur* — those live below the services tanur talks to. Tanur stays a pure client.

---

## Phased Cyrius Roadmap (all behind the desktop-UI gate)

**Gate 0 — Substrate readiness (NOT tanur work; the dependency inversion).** Tanur does not start until: puka proves the windowed loop + input dispatch; a minimal widget vocabulary exists (in puka, or extracted on second-consumer demand); sandhi can drive a streaming socket. Vector graphics (sadish/rekha) can lag into a later phase.

**Phase 1 — Text-tier core** (needs puka window+input, kashi/darshana, sandhi). sandhi client to hoosh (chat) + control-plane (models/system); chat panel (streaming, model selector, system prompt, temp/top_p — text only); Model Hub (list local models via hoosh, cards, delete; mela browse as a list); System panel (hardware + backend status as tables; GPU telemetry as numeric readout). No charts, no DAGs — a genuinely useful LM-Studio-replacement floor on text alone.

**Phase 2 — Training studio (text tier).** Training panel (job forms → control-plane; progress stream as text + numeric %); Experiments (leaderboard table); Evaluation (results table, side-by-side compare); Datasets (preview/validate as text; drag-drop deferred until puka input matures). Loss "curve" as a text/sparkline placeholder until sadish/rekha.

**Phase 3 — Graphical tier** (needs sadish/rekha). Real loss curves, GPU/VRAM/thermal gauges, fleet map, lineage/ancestry **DAG** (the hardest panel). Upgrades the Phase 1–2 placeholders in place.

**Phase 4 — Advanced / breadth.** RLHF A/B annotation UI, RAG ingest + query-with-sources (behind the retrieval lane existing), distributed-training worker assignment + placement (seema), full marketplace publish/pull (mela). Fleet inference map with drag-and-drop deployment — depends on vector gfx + mature puka drag-drop.

**Phase 5 — Sovereign inference-UX (ties to the ML forward-design).** Type-3 weight-import UX (import a foreign checkpoint into the sovereign weight-file format; LoRA/QLoRA config surfaced); **tentib ternary path selector** with tok/s + memory estimates — *surfaced honestly: the multiply-free memory win is real now, the throughput number is gated on cyrius int-SIMD*; rosnet f64-vs-GPU path selector via the mabda-gated profile; hoosh cloud-fallback indicator; LoRA hot-swap picker. (The old Phase-4 "GPU-CPU neuron split / PowerInfer sparsity heatmap" is **re-scoped** — the sovereign path is tentib ternary + rosnet, not a PowerInfer/llama.cpp fork; surface those knobs.)

**MCP / agnoshi (any phase once core exists).** `tanur_open`, `tanur_chat`, `tanur_status`, `tanur_models`, `tanur_train` as MCP tools via daimon/bote; agnoshi intents `tanur open|chat|train|pull|eval`. Sandbox profile: sandhi socket access to `/run/agnos/` services + opt-in network for remote/mela; no filesystem/model access.

---

## What Changed vs the Rust-Era Doc

- **GUI toolkit: egui/iced/Tauri → puka.** Native windowed Cyrius on Wayland-wire-from-scratch → mabda GPU → `wl_shm`, text via kashi/darshana, charts/DAGs via planned sadish/rekha. No Electron, no web runtime, no FFI toolkit.
- **Transport: reqwest/tokio/serde/eventsource-client/hyper-unix-connector → sandhi.** Hand-rolled HTTP/socket/stream client. No async runtime, no serde.
- **murti is not in the picture.** Local inference = rosnet + tentib + Type-3 importer, served by hoosh. Foreign engines, if ever, live behind a **mehman/kavach** compat seam — never in tanur's path.
- **One god-endpoint → multi-endpoint sovereign client — stated as intent, not committed wiring.** Tanur will talk directly to the decomposed owners (hoosh, ifran-control-plane, mela, seema/daimon) as each defines its client contract. It does not design against contracts that don't exist yet.
- **ifran re-scoped to a control plane** — not "the everything server with an embedded runtime." (One-repo-vs-cluster is an open question in the stack audit.)
- **`ifran-desktop` supersession section deleted** — it referenced a Rust Tauri crate that doesn't exist in the sovereign world; nothing to supersede.
- **The honest gate is now explicit and dominant.** The Rust doc treated the GUI as available (egui exists). In Cyrius it does not — tanur is DESKTOP-STAGE, DEMAND-GATED, blocked on puka + widgets + sadish/rekha.
- **Dependency inversion flagged.** The action item for "make tanur happen" is **advance puka**, not scaffold tanur. Per demand-gating and never-scaffold-ahead-of-need: **do not create a tanur repo yet.**
- **Sparsity/PowerInfer UX re-scoped** to the sovereign path (tentib ternary + rosnet), not a murti PowerInfer fork.
- **No unprompted panels.** A persona/avatara panel was considered and is **left as an open question** ("should the studio surface avatara personas?"), not a committed panel — it was never in the Rust doc and is not a re-homing.

---

## Open questions (surface, don't decide)

1. **Name vs repo:** `tanur` is reserved; it does not obligate a repo. The true blocker is puka, not any missing service.
2. **Should the studio surface avatara personas?** A candidate panel, not a commitment.
3. **Which service owns the RAG panel's backend** once a sovereign retrieval lane exists (patra + ANN index) — deferred behind that lane.

---

*Sovereign re-derivation 2026-07-01; supersedes the Rust egui/iced/Tauri + reqwest/tokio design (last touched 2026-05-09). Tanur remains planning-only and un-scaffolded; its true blocker is the Cyrius desktop/UI path (puka + a widget vocabulary + sadish/rekha), not any missing service — the sovereign ML/serving layer beneath it already exists or is the well-defined ifran port. Verify substrate versions against [`state.md`](../state.md).*
