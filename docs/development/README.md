# Development Documentation

> **Last Updated**: 2026-05-06

## Active

| Document | Description |
|----------|-------------|
| [roadmap.md](roadmap.md) | Master development roadmap — phases, blockers, release targets |
| [state.md](state.md) | **Live ecosystem state** — Cyrius cycle, pin-lag, sweeps, carry-forward debt |
| [doc-health.md](../doc-health.md) | **Living doc-health ledger** (relocated to `docs/doc-health.md` 2026-05-09 — sweeps the whole `docs/` tree, not just `development/`) |
| [sprint-history.md](sprint-history.md) | Completed phase archive |
| [monolith-extraction.md](monolith-extraction.md) | Extraction from monolith to standalone repos (complete) |
| [summer-2026-arc.md](summer-2026-arc.md) | Summer 2026 narrative arc (DEF CON / Black Hat distribution beats) |
| [iso-pipeline.md](iso-pipeline.md) | ISO assembly pipeline (Stage 0 done, Stage-4 first cut next) |
| [iso-stage4-plan.md](iso-stage4-plan.md) | Stage-4-only first cut plan (D1–D4 decisions pending) |

## Applications

| Document | Description |
|----------|-------------|
| [planning/shared-crates.md](planning/shared-crates.md) | Shared crate registry — full (incl. pre-1.0); refresh from state.md drift list |
| [planning/first-party-standards.md](planning/first-party-standards.md) | Standards for all AGNOS projects |
| [planning/first-party-documentation.md](planning/first-party-documentation.md) | Doc-tree standards (companion to first-party-standards.md) |
| [planning/example_claude.md](planning/example_claude.md) | CLAUDE.md template for new projects |
| [planning/roadmap.md](planning/roadmap.md) | Consumer application roadmap (forward planning, pre-v1) |

## Guides

| Document | Description | Status |
|----------|-------------|--------|
| [guides/mcp-tools-reference.md](guides/mcp-tools-reference.md) | MCP tools reference (144+ tools) | Active |
| [guides/science-crate-specs.md](guides/science-crate-specs.md) | Science crate specifications | Active |
| [guides/testing.md](guides/testing.md) | Test conventions | Pre-Cyrius |
| [guides/agent-development.md](guides/agent-development.md) | Agent development guide | Pre-Cyrius (fossil notice) |
| [guides/kernel-guide.md](guides/kernel-guide.md) | Host kernel module docs | Pre-Cyrius (fossil notice) |

## Infrastructure

| Document | Description |
|----------|-------------|
| [infrastructure/ci-cd-guide.md](infrastructure/ci-cd-guide.md) | CI/CD pipeline documentation |
| [infrastructure/rpi4-runner-setup.md](infrastructure/rpi4-runner-setup.md) | RPi4 self-hosted runner setup |
| [infrastructure/dependency-watch.md](infrastructure/dependency-watch.md) | Dependency monitoring |
| [infrastructure/performance-benchmarks.md](infrastructure/performance-benchmarks.md) | Benchmark framework (pre-Cyrius, fossil notice) |

## Vision

Future architecture, theoretical exploration, and long-range planning.

| Document | Description |
|----------|-------------|
| [vision/release-vision.md](vision/release-vision.md) | Release milestones v2-v4 (fossil — pre-Cyrius kernel) |
| [vision/maat-42.md](vision/maat-42.md) | Ma'at 42 Confessions mapped to AGNOS crates |
| **vision/architecture/** | |
| [k8s-roadmap.md](vision/architecture/k8s-roadmap.md) | Kubernetes-equivalent orchestration |
| [network-evolution.md](vision/architecture/network-evolution.md) | TCP → QUIC → binary agent protocol |
| *kernel-layers moved* → | [`docs/architecture.md` § Kernel Layers](../architecture.md#kernel-layers) (was `architecture/kernel-layers.md`; inlined 2026-05-09) |
| **vision/applications/** | |
| [holodeck.md](vision/applications/holodeck.md) | Immersive simulation architecture |
| [time-machine.md](vision/applications/time-machine.md) | Temporal simulation engine |
| [semantic-audio.md](vision/applications/semantic-audio.md) | Recipe-based audio compression |
| [personality-architecture.md](vision/applications/personality-architecture.md) | Runtime personality via LLM + bhava |
| **vision/research/** | |
| [paper-unified-consciousness-model.md](vision/research/paper-unified-consciousness-model.md) | Unified consciousness framework |
| [theoretical.md](vision/research/theoretical.md) | Spatial transit, directed energy, programmable matter |
| [space-infrastructure.md](vision/research/space-infrastructure.md) | Orbital & deep space AGNOS nodes |

## OS Subsystems

| Directory | Description |
|-----------|-------------|
| [os/](os/) | OS subsystems categorization map — repos + roles. Live versions in [state.md](state.md) and [shared-crates.md](planning/shared-crates.md). |
