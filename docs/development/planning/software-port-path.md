# AGNOS Software-Side Port Path (Rust → Cyrius)

> **The software side of the sovereignty path** — the Rust→Cyrius port surface across the whole ecosystem, and the order to walk it. Companion to the kernel/iron side (handled separately). Reference snapshot; refresh via the procedure at the end.
>
> **Status:** snapshot **2026-07-01** · **Scope:** every AGNOS subsystem repo, port status + tier · **Source:** GitHub org inventory (`api.github.com/users/MacCracken/repos`, 200 repos) cross-referenced against local `cyrius.cyml`/`Cargo.toml`.

---

## 0. Classification method (read first — the counts depend on it)

- **The reliable signal is local, not GitHub.** GitHub's linguist does **not** recognize Cyrius (`.cyr`), so a ported repo often still reads `language: Rust` on GitHub. **Truth = a local `cyrius.cyml` (Cyrius/done) vs `Cargo.toml` (Rust/to-port).** Evidence: 13 repos read "Rust" on GitHub but are Cyrius locally (agnova, ark, goonj, hoosh, itihas, kybernet, mela, naad, shakti, szal, t-ron, takumi, varna).
- **Heuristic for repos not cloned locally: not-local ⇒ probably Rust ⇒ port target** (user rule, 2026-07-01). The local clone set (109) is a subset of the org (200); ~91 repos aren't on disk and are treated as Rust until a clone proves otherwise.
- **Do not port-plan from `ls ~/Repos`** — it undercounts by ~half the port surface (e.g. the entire bhava affect/simulation family is GitHub-only).

**Counts:** 200 org repos → **88 Cyrius (done)** · **~74 AGNOS Rust port targets** · 9 `cyrius-*` games (separate lane, tracked in [`shared-crates.md`](shared-crates.md)) · ~29 excluded (websites, learning/forks, SecureYeoman, meta).

---

## 1. DONE — Cyrius-native (88, `cyrius.cyml` present locally)

abaco, aegis, agnodrm, agnos, agnoshi, agnostik, agnova, agora, ai-hwaccel, akshara, amuzesh, anuenue, argonaut, ark, attn11, avatara, bannermanor, bayan, bazaar, bhumi, bote, bsp, chakshu, chitra, cmdit, commandress, cyim, cyim-lsp, cyrius, cyrius-bb, cyrius-doom, cyrius-polyomino, cyrius-yeomans-descent, daimon, darshana, darshini, dig, encom-hits, ganita, gnoboot, goonj, hadara, hapi, hisab, hoosh, iam, itihas, kashi, kavach, kii, klug, kriya, kybernet, libro, mabda, majra, mehman, mela, mihi, mirshi, naad, nein, niyama, nous, owl, patra, phylax, prajna, puka, rosnet, sakshi, samvada, sandhi, sankoch, shakti, shravan, sigil, sit, szal, t-ron, taar, takumi, tarka, tentib, thoth, tyche, vani, varna

*(This is the sovereign core: the kernel, compiler, the whole ML reference family + substrate, the serving/agent layer, security stack, coreutils/tools, most libs.)*

---

## 2. PORT BACKLOG — still Rust (tiered)

`[L]` = local Rust clone (confirmed) · `[·]` = not-local (⇒ Rust by heuristic). Tiers are a best-effort domain grouping from repo descriptions — refine as clones land.

### Tier A — ML/AI + serving (the current focus)
| Repo | | Responsibility | Note |
|---|---|---|---|
| ifran | `[L]` | LLM management/training → **the training control plane** | biggest port; see §3 |
| seema | `[L]` | Edge **fleet** management | edge-stage |
| pramana | `[·]` | Statistics / probability | ML substrate (cognition cluster pramana→tarka→prajna) |
| agnosai | `[L]` | Core **agent system** | agent runtime; overlaps daimon — verify boundary |
| mneme | `[·]` | Knowledge base — **RAG** | the RAG/retrieval gap (kNN-LM/RETRO over patra) |
| jnana | `[·]` | Human-knowledge DB | RAG corpus / knowledge substrate |
| murti | `[·]` | LLM model runtime | **re-derived → not a build target**; seam prototypes in hoosh ([`murti.md`](murti.md)) |
| tanur | `[·]` | Desktop LLM studio | **re-derived → puka app, deferred** ([`tanur.md`](tanur.md)) |

### Tier B — affect / life-science / simulation (feeds AI personas, agents, hadara, games)
bhava `[L]` (emotion) · bodh `[·]` (psychology) · sangha `[·]` (sociology) · sharira `[·]` (biomechanics) · jivanu `[·]` (microbiology/immune) · mastishk `[·]` (neuroscience) · jantu `[·]` (creature behavior) · prani `[·]` (animal vocalization) · vanaspati `[·]` (nature/growth) · rasayan `[·]` (biochemistry)

### Tier C — physical-science stack (sovereign science)
badal `[·]` (weather) · bijli `[·]` (EM) · brahmanda `[·]` (cosmology) · falak `[·]` (orbital) · hisab-mimamsa `[·]` (theoretical physics) · impetus `[·]` (physics) · jyotish `[·]` (astronomy) · kana `[·]` (quantum) · khanij `[·]` (geology) · kimiya `[·]` (chemistry) · dravya `[·]` (mineralogy) · pavan `[·]` (aerodynamics) · pravash `[·]` (fluid dynamics) · ushma `[·]` (thermodynamics) · tara `[·]` (stellar) · prakash `[·]` (optics/light) · tanmatra `[·]` (atomic/subatomic time) · sankhya `[L]` (ancient number systems)

### Tier D — audio / media
dhvani `[L]` (audio engine) · shruti `[L]` (music DAW) · svara `[·]` (vocal synth) · garjan `[·]` (ambient) · ghurni `[·]` (mechanical sound) · shabda `[·]` (word/sound) · nidhi `[L]` (sample engine) · tarang `[·]` (media codec) · jalwa `[·]` (media player) · tazama `[·]` (video editor) · ranga `[·]` (image compositor) · soorat `[·]` (rendering engine)

### Tier E — apps / desktop / tools
abacus `[·]` · aequi `[·]` · rasa `[·]` (image editor) · taswir `[·]` · selah `[·]` (screenshot) · muharrir `[·]` (editor engine) · nazar `[·]` (sysmon/task mgr) · rahd `[·]` (calendar/contacts) · vidhana `[·]` (system settings) · salai `[·]` (game editor) · kiran `[·]` (game engine) · joshua `[·]` (game AI runtime) · mudra `[·]` (token/asset) · leela `[·]` (sports) · natya `[·]` (drama/narrative) · nyaya `[·]` (law/logic) · taal `[·]` (music theory) · shabdakosh `[·]` (dictionary) · kshetra `[·]` (geography) · raasta `[·]` (pathfinding) · aethersafha `[·]` (desktop) · aethersafta `[·]` (media compositing) · BullShift `[·]` (trading — see [`bullshift-split.md`](bullshift-split.md))

### Tier F — infra
stiva `[L]` (container runtime) · sutra `[·]` (orchestrator) · samay `[L]` (task scheduler)

---

## 3. Tier-A port plan (the ML/AI + serving path)

The rest of the ML/AI layer is already Cyrius (§1). Tier A is what's left, and it's the focus.

### ifran → training control plane (the big one)
- **Is:** Rust 1.3.0, AGPL; shells all training math to Python; ~21 REST groups; owns **zero** math.
- **Becomes:** a Cyrius control plane — *thin over existing homes*, driving the sovereign siblings as jobs: lineage→**itihas**, serving→**hoosh**, marketplace→**mela**, fleet→**seema**, hashing→**sigil**, GPU→**mabda/ai-hwaccel**, checkpoint store→the model store.
- **Open decision (blocks the port):** **one ifran repo, or a cluster** of separately-releasable control-plane services (job/scheduler · dataset-curation · eval-runner · annotation-store · distributed-coord)? Don't carry the Rust monolith boundary across by default (monolithic-by-design).
- **Feeds SY:** SY currently HTTP-proxies external ifran (`routes/ifran_proxy.rs`); the port re-sovereignizes that seam.

### seema → edge fleet
- **Is:** Rust 0.1.0 (early). **Becomes:** Cyrius fleet mgmt — node registry, health, VRAM-aware placement, edge push; consumes **daimon** edge; the tentib-on-Pi distribution endgame (1.5x+ hardware). Depends on a model store + edge hardware → lags ifran.

### Supporting Tier-A ports
- **pramana** (statistics/probability) — the cognition-cluster stats sibling; an ML substrate the reasoning/eval work leans on.
- **agnosai** (core agent system) — **verify the boundary vs daimon** before porting (possible overlap → may fold, not port).
- **mneme / jnana** (RAG knowledge base / knowledge DB) — the retrieval gap; research-watch (ANN index over patra) — port when the retrieval lane opens.
- **murti / tanur** — **not straight ports**: re-derived onto Cyrius as [`murti.md`](murti.md) (seam in hoosh) and [`tanur.md`](tanur.md) (puka app, deferred).

### Sequencing
```
decide ifran decomposition (1 repo vs cluster)     ← the one open decision
        │
   [GAP #1: Type-3 weight-file format + importer]   ← greenfield Cyrius; the shared
        │                                              checkpoint/model-store falls out here
        ├── ifran port  (module-by-module, thin over each sovereign home)
        ├── pramana / agnosai(verify) / mneme(when retrieval opens)
        └── seema port  (edge-stage; lags; needs model-store + HW lines)
```
Gap #1 first (the model/checkpoint store it produces is the shared dependency under both the importer and the ifran port).

---

## 4. Cross-cutting gates (pace everything above)

- **Type-3 weight importer** — greenfield; #1 value; unblocks "run real models sovereignly" + the model store. **✅ M1 HIT 2026-07-02:** chain shipped (tula 1.0.0 / rupantara 0.4.0 / anukūlana 0.2.0) — a real GPT-2-small checkpoint imports + runs clean on the sovereign stack. Remaining: exact HF-fidelity gate → LoRA/QLoRA. Detail: [`type3-weight-import.md`](type3-weight-import.md).
- **tentib int-SIMD** — external cyrius-toolchain gate (integer SIMD); blocks tentib throughput, not correctness.
- **mabda GPU speedup** — needs matrix-core f64 / the NVIDIA-native arc (mabda 4.x); gates diffusion + scale.
- **puka** — gates any desktop GUI (tanur, and desktop-tier apps in Tier E).

---

## 5. Explicitly NOT port targets

- **Games** (`cyrius-*`, 9): brynns-tale, chellys-beach-adventure, chellys-beach-dash, grapevine, nba-jam, stellar-swarm, sunset-drive, super-plumber-twins — separate games lane, tracked in [`shared-crates.md`](shared-crates.md). *(Several games are ALREADY Cyrius — bb, doom, polyomino, yeomans-descent, encom-hits — in §1.)*
- **SecureYeoman** (`secureyeoman`, `secureyeoman-community-repo`) — **stays Rust** (the progenitor/pinnacle product + integration/probe harness; not a port target).
- **Websites / personal / learning / forks** — agnosticos-org, cyriusb, lightoceanstudios, personal_site, pitw_ebook_site, npc_generator, offline_kb, PhotisNadi, plus the DevOps/Selenium/Go-learning forks. Out of scope.

---

## 6. Caveats & refresh

- **GitHub language is unreliable** for Rust-vs-Cyrius (linguist has no Cyrius); always confirm with a local `cyrius.cyml`. The `[·]` not-local rows are *probable* Rust — verify on clone.
- **Tiers are best-effort** from one-line descriptions; several repos could move (nidhi/sample, jnana/RAG, sankhya/math).
- This is a **snapshot** (2026-07-01), not live state — live per-repo versions/roles live in [`shared-crates.md`](shared-crates.md) + [`state.md`](../state.md).
- **Refresh:** re-run the org enumeration (`api.github.com/users/MacCracken/repos`, curl — never gh CLI), re-cross-reference against local `cyrius.cyml`, and move ported repos from §2 → §1.

---

*Software-side companion to the kernel/iron sovereignty path. The endgame is the whole backlog on Cyrius — the ecosystem being SecureYeoman decomposed and re-sovereignized from the metal up; see [[project_secureyeoman_progenitor_pinnacle]]. Tier A is the near-term focus; gap #1 (Type-3 importer) is the first build.*
