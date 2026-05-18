# AGNOS Planning Folder — Categorized Index

> Master index for `docs/development/planning/`. Splits planning docs by **scope** so it's clear what's a kernel-level driver plan vs. an overall project gate vs. an application design.
>
> Volatile state stays in [`../state.md`](../state.md). Crate registries: [`shared-crates.md`](shared-crates.md) (full, incl. pre-1.0) and [`../../applications/libs/README.md`](../../applications/libs/README.md) (v1.0+ stable).
>
> **Last Updated**: 2026-05-17 — categorized restructure (was: pre-1.0 library index only)

---

## Kernel-scope plans

Plans for kernel subsystems, drivers, and bring-up gates. These are MVP-blocking or near-blocking — closing them is what makes AGNOS bootable on iron at all.

| Doc | Status | Note |
|---|---|---|
| [usb-hid-keyboard-driver.md](usb-hid-keyboard-driver.md) | 🟠 Code complete; iron-side silent-absorb arc parallel-track | All 5 phases landed in agnos 1.30.0–1.30.5. Iron blocker on 1022:1639 — see § *Silent-Absorb Resolution Plan* in the doc + [`../iron-nuc-zen-log.md`](../iron-nuc-zen-log.md). |

*Future kernel plans land here: VFS, network stack (when scoped), USB mass-storage class driver (post-keyboard), GPU bring-up.*

---

## Project-level (overall AGNOS organization, governance, conventions)

| Doc | Scope |
|---|---|
| [roadmap.md](roadmap.md) | Application & phase roadmap (Phases 1–24, MVP gates, ship cadence) |
| [shared-crates.md](shared-crates.md) | Full crate registry (incl. pre-1.0 — live versions per `state.md`) |
| [foundation-structure.md](foundation-structure.md) | Phase 23 governance layer (mission-locked, contributor-protecting structure) |
| [first-party-standards.md](first-party-standards.md) | Code conventions (Cyrius-first; Rust-era archive separate) |
| [first-party-documentation.md](first-party-documentation.md) | Doc conventions (CLAUDE.md / doc-health pattern / README shape) |
| [example_claude.md](example_claude.md) | Template — CLAUDE.md scaffold for new repos |

---

## Application designs (per-app planning docs, pre-1.0)

Forward-looking design specs for applications shipping later. Once an app reaches v1.0+, its doc moves to [`../../applications/`](../../applications/README.md) and the planning doc here becomes a fossil reference (per [hadara.md](hadara.md) precedent).

| Doc | Status | Priority |
|---|---|---|
| [murti.md](murti.md) | Scaffolded (0.1.0) | P1 — Ollama replacement, hoosh + Ifran foundation |
| [tanur.md](tanur.md) | Scaffolded (0.1.0) | P2 — LM Studio replacement (desktop) |
| [joshua.md](joshua.md) | Scaffolded (0.1.0) | P4 — AI-native game manager / sim runtime |
| [pdf-suite.md](pdf-suite.md) (Sahifa + Scriba) | P0 — Design phase | Adobe Acrobat Pro replacement |
| [bullshift-split.md](bullshift-split.md) | ⏸️ Deferred until desktop ships | Engine/GUI split roadmap |
| [agnostic-integration.md](agnostic-integration.md) | ⏸️ Deferred until desktop ships | Running Agnostic QA on AGNOS via hoosh |

---

## Subsystem designs (cross-cutting; not application-bounded)

System-level capabilities that touch multiple repos / aren't owned by any single app. Mostly map to roadmap Phase 20–24 territory (empire-defense layers + Cyrius-native infrastructure).

| Doc | Roadmap | Note |
|---|---|---|
| [agent-injection-defense.md](agent-injection-defense.md) | Phase 15A | Six-layer encoded-prompt-injection defense (phylax / hoosh / t-ron / kavach / libro / agnostik) |
| [cross-platform-compat-subsystem.md](cross-platform-compat-subsystem.md) | Phase 20 | Kavach-sandboxed Linux personality (foreign workloads transparent; kernel grows native, compat stays separate) |
| [dpi-resistance.md](dpi-resistance.md) | Phase 21 | Network stack normalizes to mainstream-browser fingerprint by default |
| [parallel-pki.md](parallel-pki.md) | Phase 22 | Trust root in physical artifacts (sticker / SD / paper QR); CAs as opportunistic bridges only |
| [identity-and-authorization-model.md](identity-and-authorization-model.md) | Phase 24 | Recognition over interrogation; authorization > authentication; four-layer model |
| [hadara.md](hadara.md) | — (shipped v1.0) | Fossil reference — culture-as-entity design that drove hadara v1.0; for shipped capabilities, see hadara repo |

---

## See Also

- [`../state.md`](../state.md) — live ecosystem state (Cyrius cycle, pin-lag, sweeps, carry-forward debt)
- [`../iron-nuc-zen-log.md`](../iron-nuc-zen-log.md) — live iron bring-up log (Attempt-by-attempt narrative)
- [`../roadmap.md`](../roadmap.md) — top-level project roadmap (Phases 1–24, MVP gates)
- [`../../applications/libs/README.md`](../../applications/libs/README.md) — v1.0+ stable library registry
- [`../../doc-health.md`](../../doc-health.md) — doc-freshness ledger (every file in this folder tracked)

---

*Categorization established 2026-05-17. Prior framing (pre-1.0 library/tool/app index only) didn't fit kernel-driver plans like `usb-hid-keyboard-driver.md`; new sections accommodate kernel-scope + cross-cutting subsystems.*
