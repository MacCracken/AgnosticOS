# AGNOS Pre-1.0 Development — Libraries, Tools & Applications

> Crates, binaries, and applications that have **not yet** reached v1.0 stable release.
>
> **For v1.0+ stable libraries**: see [docs/applications/libs/](../../applications/libs/README.md) — that's the canonical location for any released library.
> **For consumer apps shipped to v1.0+**: see [docs/applications/](../../applications/README.md).
> **For the full registry with current versions and lifecycle status**: see [shared-crates.md](shared-crates.md) — single source of truth, refreshed as crates ship.
>
> This README is a stage-based index for *pre-1.0 only*. Versions are intentionally omitted — they drift fast; consult `shared-crates.md`.
>
> **Last Updated**: 2026-05-09

---

## Lifecycle Stages

Crates are bucketed by where they sit in the path to v1.0. Once a crate reaches v1.0+, it leaves this index and gets a doc page under [`docs/applications/libs/`](../../applications/libs/README.md) (libraries) or [`docs/applications/`](../../applications/README.md) (consumer apps).

### Near-Stable Libraries (v0.5.0+)

Approaching v1.0 — surface largely settled, hardening and consumer adoption underway.

- **aethersafta** — media compositing (scene graph, capture, HW encoding)
- **jnana** — unified knowledge system (offline-accessible corpus)

### In-Progress Libraries (v0.1.0–v0.49.x)

Active development; surface still moving.

- **selah** — screenshot capture, annotation, PII redaction
- **cyrius-doom** — DOOM engine in Cyrius (hardened reference port)
- **muharrir** — editor primitives (text buffer, undo/redo, command pattern)
- **samvada** — DBus client (Cyrius-native, minimal logind subset)
- **vani** — audio device I/O (direct ALSA/OSS syscalls; vendored into Cyrius stdlib at v5.8.0)
- **sit** — sovereign version control (Cyrius-native git replacement, smriti)

### Scaffolded Libraries (v0.1.0)

Repo created, structure in place, implementation pending.

- **yantra** — sovereign UI automation (browser + mobile, as a Cyrius library)
- **mudra** — token/value primitives (asset identity, ownership, type)
- **vinimaya** — transaction layer (atomic transfers, escrow, settlement)
- **taal** — music theory (scales, intervals, chords, rhythm)
- **natya** — theater/drama/narrative (dramatic structure, archetypes)
- **kshetra** — temporal geography (spatiotemporal database)
- **leela** — sport (rules, athletes, tournaments, records)
- **nyaya** — structured legal knowledge (statutes, precedents, IP)

### Planned Libraries (not yet scaffolded)

- **krishi** — agriculture (crop science, soil, irrigation, yield modeling)
- **prakriti** — ecology (ecosystem modeling, food webs, biodiversity)

---

## System Tools & Binaries (pre-1.0)

- **ark** — package manager (Cyrius)
- **takumi** — build system (Cyrius port in progress; rust-old/ authoritative until parity)
- **shakti** — privilege escalation (sudo replacement)
- **aegis** — security daemon
- **aethersafha** — Wayland compositor
- **agnova** — OS installer (Cyrius port from 3,656 Rust lines)
- **mela** — agent marketplace
- **seema** — edge fleet management
- **samay** — task scheduler
- **chakshu** — AI-augmented system monitor (binary `shu`; replaces htop/btop at v1.0)

---

## Applications (pre-1.0)

Design docs in this folder where present:

- **murti** — core model runtime (Ollama replacement) — [murti.md](murti.md)
- **tanur** — desktop LLM studio (LM Studio replacement) — [tanur.md](tanur.md)
- **joshua** — game manager & AI simulation — [joshua.md](joshua.md)
- **salai** — game editor (egui visual editor for kiran)

---

## Non-Library Projects (pre-1.0)

Game catalog: see the **Non-Library Projects** section of [shared-crates.md](shared-crates.md) for the full list (cyrius-nba-jam, cyrius-brynns-tale, cyrius-grapevine, cyrius-super-plumber-twins, cyrius-stellar-swarm, cyrius-sunset-drive, cyrius-bb, cyrius-chellys-beach-adventure, cyrius-chelly-beach-dash, cyrius-mine-cart, etc.).

---

## See Also

- [shared-crates.md](shared-crates.md) — complete registry across all stages with current versions
- [roadmap.md](roadmap.md) — application roadmap and priorities
- [first-party-standards.md](first-party-standards.md) — code conventions
- [first-party-documentation.md](first-party-documentation.md) — doc conventions

---

*Last Updated: 2026-05-09*
