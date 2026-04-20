# Archive

> Historical documentation preserved for provenance. **Not authoritative for current state** — every file here describes AGNOS as it was before one of three inflection points: the Cyrius pivot (2026-04-04), the monolith extraction (2026-04-01), or an earlier rename/refactor.

## Why keep these

- **Narrative receipts.** The project's pivot from Rust-bootstrapped to sovereign Cyrius-from-seed is itself part of the story. Articles reference these docs as the "before" side of the before/after.
- **Naming archaeology.** Subsystems that were renamed (or retired) leave traces here. If a reader finds an old reference to `nein` or `majra` in a commit message or article, the archive says what those were.
- **No authoritative claims.** Nothing in `archive/` should be linked to as current documentation. When a historical context is needed, link to the specific archived file, not the directory.

## Organization

```
docs/archive/
├── README.md                            (this file)
├── *-rust-era.md                        (root-level: pre-Cyrius Rust-era docs)
├── *-pre-cyrius.md                      (root-level: planning docs that predated Cyrius)
├── cyrius-lang-migration.md             (root-level: the migration roadmap itself)
├── libs-pre-cyrius/                     (lib docs before the Cyrius port)
├── os-pre-cyrius/                       (OS-layer docs before the Cyrius port)
└── os-modules-pre-extraction/           (OS modules before the 2026-04-01 monolith extraction)
```

## Root-level files

| File | What it was | Archived | Superseded by |
|------|-------------|----------|---------------|
| `AGNOS-rust-era-2026-04-03.md` | Overall AGNOS description, Rust era | 2026-04-13 | `../AGNOS.md` + `../development/roadmap.md` |
| `agent-runtime-rust-era.md` | Daimon agent runtime spec (Rust) | 2026-04-07 | `MacCracken/daimon` repo |
| `agnostik-roadmap-pre-cyrius.md` | Agnostik 0.90→1.0 roadmap, pre-Cyrius | 2026-04-03 | `MacCracken/agnostik` repo (now v0.97.1 Cyrius-ported) |
| `api-readme-rust-era.md` | AGNOS API reference, Rust-era | 2026-03-11 | Pending — full API re-docs land with Phase 13A |
| `cyrius-lang-migration.md` | The migration planning doc that triggered the pivot | 2026-04-04 | Complete — `MacCracken/cyrius` is the successor. Kept as the "before" artifact of the pivot decision. |
| `desktop-environment-rust-era.md` | aethersafha desktop environment spec, Rust era | 2026-03-11 | `MacCracken/aethersafha` (pending Cyrius port) |
| `example_claude-rust-era.md` | CLAUDE.md template for Rust-era sibling repos | 2026-04-13 | Each active repo now maintains its own Cyrius-era CLAUDE.md |
| `first-party-standards-rust-era.md` | First-party application standards, Rust era | 2026-04-08 | `../development/applications/` docs + per-repo CONTRIBUTING.md |

## `libs-pre-cyrius/` — Library docs before the Cyrius port

Each file documents a library as it existed in Rust before being ported (or retired) under Cyrius. Where a current successor exists, it lives as a standalone repo at `MacCracken/<name>`.

| File | Successor |
|------|-----------|
| `abaco.md` | `MacCracken/abaco` v2.1.0 (Cyrius, +12× Miller-Rabin) |
| `ai-hwaccel.md` | `MacCracken/ai-hwaccel` v2.0.0 (Cyrius, 131 crates → 0) |
| `bote.md` | `MacCracken/bote` v2.5.1 (Cyrius) |
| `hadara.md` | `MacCracken/hadara` v1.0.0 (Cyrius-**native**, never re-ported — predates Cyrius transition) |
| `hoosh.md` | `MacCracken/hoosh` v2.0.0 (Cyrius, 40 crates → 0) |
| `itihas.md` | `MacCracken/itihas` v2.2.0 (Cyrius) |
| `kavach.md` | `MacCracken/kavach` v3.0.0 (Cyrius, 448 crates → 1) |
| `libro.md` | `MacCracken/libro` v2.0.5 (Cyrius) |
| `mabda.md` | Folded into Cyrius stdlib (v3.4.19) |
| `majra.md` | Retired — functionality absorbed into Cyrius stdlib + sibling crates |
| `nein.md` | Retired or renamed — not part of current ecosystem |
| `shravan.md` | `MacCracken/shravan` v2.3.2 (Cyrius) |
| `soorat.md` | Retired or pending — not in current named-subsystem roster |
| `stiva.md` | Retired — not in current named-subsystem roster |
| `szal.md` | Retired — not in current named-subsystem roster |
| `t-ron.md` | `MacCracken/t-ron` v2.0.0 (Cyrius) |
| `vidya.md` | `MacCracken/vidya` (reference library, separately maintained) |
| `yukti.md` | Folded into Cyrius stdlib as `yukti` hardware-enum module |

## `os-pre-cyrius/` — OS-layer docs before the Cyrius port

| File | Successor |
|------|-----------|
| `agnoshi.md` | `MacCracken/agnoshi` v1.0.0 (Cyrius) |
| `argonaut.md` | `MacCracken/argonaut` v1.2.0 (Cyrius) |
| `bote.md` | `MacCracken/bote` v2.5.1 (duplicate — original lived at both layers) |
| `daimon.md` | `MacCracken/daimon` v1.1.1 (Cyrius) |
| `libro.md` | `MacCracken/libro` v2.0.5 (duplicate) |
| `nein.md` | Retired (duplicate) |
| `t-ron.md` | `MacCracken/t-ron` v2.0.0 (duplicate) |
| `yukti.md` | Cyrius stdlib (duplicate) |

## `os-modules-pre-extraction/` — OS modules before the 2026-04-01 monolith extraction

Module-level docs as they existed inside the `userland/` Cargo workspace, before every module was extracted into its own repo on 2026-04-01. Files here describe modules that lived together in a single tree; the live documentation now lives in each repo's own `README.md` + `CLAUDE.md`.

Covered: ai-hwaccel, hoosh, kavach, mabda, majra, sigil, soorat, stiva, szal.

See [`../development/monolith-extraction.md`](../development/monolith-extraction.md) for the extraction event itself.

## Policy

### When to add a doc here
- A doc becomes inaccurate because of a structural change (pivot, rename, extraction, retirement)
- The doc has historical value (narrative continuity, naming archaeology) that makes deletion inappropriate

### When NOT to add a doc here
- A doc is merely stale — edit it in place, don't archive
- A doc describes current but unfinished work — leave it active with a status banner

### When to restore from archive
- Essentially never. If the state described here ever returns (unlikely), write a new doc referencing the archived one as prior art rather than copying forward.

### When to delete from archive
- Per-file: essentially never. The whole point is preservation. Deletion only makes sense if a file was archived by mistake (e.g., a current doc with an unfortunate filename).
- **Rust-era purge (planned):** after a few tagged GA releases past Beta — once the Rust-era and monolith context stops being actively referenced in day-to-day work — the entire Rust-era `docs/archive/` is deleted in a single commit. The preservation guarantee moves to git: the immediately-prior tag (`archive-final-v<N>`) becomes the canonical pointer, and historical refs use `git show <tag>:docs/archive/<file>` or a permalink to that tag's tree on GitHub.

### After the purge

`docs/archive/` may be recreated if — and only if — a Cyrius-era doc undergoes a structural supersession severe enough that the new doc can't carry the old context. The bar is **higher** than the Rust era: Rust-era archival was a bulk "the world changed" event; post-purge archival is a rare "this specific supersession is historically significant" event. Expected post-purge contents: near-zero. Normal doc updates edit in place.
