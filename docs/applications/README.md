# AGNOS Applications & Libraries

> Documentation for all first-party AGNOS software.
>
> See also: [First-Party Standards](../development/planning/first-party-standards.md) | [Application Roadmap](../development/planning/roadmap.md) | [Monolith Extraction](../development/monolith-extraction.md)

---

## Consumer Applications

Desktop, CLI, and service applications built on the AGNOS stack.

> **Status legend**: **Released** = ships and runs today; **Planned** = doc/spec exists, implementation pending. Per-app doc headers carry the authoritative status; this index reflects them as of 2026-05-06.

| App | Domain | Status | Notes |
|-----|--------|--------|-------|
| [Abacus](abacus.md) | Desktop calculator | Released | Built on abaco |
| [Aequi](aequi.md) | Self-employed accounting | Released | Tauri |
| [Agnostic](agnostic.md) | Agent automation platform | Released | Python/CrewAI |
| [BullShift](bullshift.md) | Trading platform | Released | |
| [Delta](delta.md) | Code hosting (git, PRs, CI/CD) | Released | Port 8070 |
| [Dhara](dhara.md) | Media streaming server | Planned | Port 8078, built on tarang |
| [Ifran](irfan.md) | LLM inference & training | Released | (filename `irfan.md` predates the Synapse → Irfan → Ifran rename) |
| [Jalwa](jalwa.md) | Media player | Released | Built on tarang |
| [Mneme](mneme.md) | Knowledge base | Released | |
| [Nazar](nazar.md) | System monitor | Released | Port 8095 |
| [Photis Nadi](photisnadi.md) | Productivity app | Released | |
| [Rahd](rahd.md) | Calendar & contacts | Released | |
| [Rasa](rasa.md) | Image editor | Released | |
| [SecureYeoman](secureyeoman.md) | Flagship AI agent platform | Released | TypeScript/Bun |
| [Selah](selah.md) | Screenshot & annotation | Released | |
| [Shruti](shruti.md) | DAW (digital audio workstation) | Released | |
| [Sutra](sutra.md) | Infrastructure orchestrator | Released | |
| [Tazama](tazama.md) | Video editor | Released | |
| [Vidhana](vidhana.md) | System settings | Released | |

## Shared Library Crates

Reusable libraries that form the stack. See **[libs/](libs/README.md)** for the full categorized index.

## Third-Party Packages

Packaged external software for AGNOS. See **[thirdparty/](thirdparty/)**.
