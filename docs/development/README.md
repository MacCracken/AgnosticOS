# Development Documentation

> **Last Updated**: 2026-05-21 (1.30.x → 1.31.x kernel arc index extension)

## Active

| Document | Description |
|----------|-------------|
| [roadmap.md](roadmap.md) | Master development roadmap — phases, blockers, release targets |
| [state.md](state.md) | **Live ecosystem state** — Cyrius cycle, pin-lag, sweeps, carry-forward debt |
| [doc-health.md](../doc-health.md) | **Living doc-health ledger** (relocated to `docs/doc-health.md` 2026-05-09 — sweeps the whole `docs/` tree, not just `development/`) |
| [sprint-history.md](sprint-history.md) | Completed phase archive |
| [monolith-extraction.md](../archive/monolith-extraction.md) | Extraction from monolith to standalone repos — **archived 2026-05-12** (extraction complete; live work tracked in state.md + iron-nuc-zen-log-mvp.md / iron-nuc-zen-log.md) |
| [summer-2026-arc.md](summer-2026-arc.md) | Summer 2026 narrative arc (DEF CON / Black Hat distribution beats) |
| [iso-pipeline.md](iso-pipeline.md) | ISO assembly pipeline (Stage 0 done, Stage-4 first cut next) |
| [iso-stage4-plan.md](iso-stage4-plan.md) | Stage-4-only first cut plan (D1–D4 decisions pending) |

## Iron Boot Bring-up

| Document | Description |
|----------|-------------|
| [iron-bring-up-process.md](iron-bring-up-process.md) | Iron bring-up workflow (audit-first, burn-second, no-letter-codes) |
| [iron-nuc-zen-log.md](iron-nuc-zen-log.md) | Active iron boot log on archaemenid (NUC AMD Zen) — post-MVP Attempts 69+ |
| [iron-nuc-zen-log-mvp.md](iron-nuc-zen-log-mvp.md) | MVP-era boot log — Attempts 1-68, capped 2026-05-19 at MVP gate hit |
| [iron-nuc-zen-photos/](iron-nuc-zen-photos/) | Boot transcript photo catalog (one per attempt; convention `attempt-NN-<handle>.jpg`) |

## Prior-Art Audits + Kernel Plans

Multi-source convergent reference documents written before each major kernel touch — the audit-and-execute pattern that landed NVMe, AHCI, USB-MS, RAM-disk + VirtIO modern first-iron-try (per `feedback_redesign_dont_reinvent`).

| Document | Subsystem | Status |
|----------|-----------|--------|
| [path-c-sovereign-uefi.md](path-c-sovereign-uefi.md) | Sovereign UEFI handoff (gnoboot ↔ kernel ABI) | Landed v1.30.0 |
| [uefi-boot-prior-art.md](uefi-boot-prior-art.md) | UEFI boot ecosystem audit + foot-gun catalog | Reference |
| [xhci-prior-art-audit.md](xhci-prior-art-audit.md) | xHCI controller prior-art (Linux + SeaBIOS + FreeBSD + Haiku) | Landed v1.30.x USB arc |
| [true-font-swap-plan.md](true-font-swap-plan.md) | VGA 8x16 BIOS-ROM font swap | Landed v1.30.12 |
| [ahci-iron-burn-audit.md](ahci-iron-burn-audit.md) | AHCI/SATA Phase 1-4 risk surface + iron-burn plan | Landed v1.31.1 (Attempt 81 PASS) |
| [usb-ms-iron-burn-audit.md](usb-ms-iron-burn-audit.md) | USB Mass Storage Phase 1-4 + iron-burn plan | Landed v1.31.2 → v1.31.3 (Attempt 87 PASS) |
| [msc-reset-recovery-prior-art.md](msc-reset-recovery-prior-art.md) | USB MSC Reset Recovery multi-source audit (Linux + FreeBSD + OpenBSD + EDK2) | Drove Phase 2.6/2.7/2.8 stack |
| [ramdisk-virtio-modern-prior-art.md](ramdisk-virtio-modern-prior-art.md) | RAM-disk + VirtIO 1.x modern multi-source audit (5 OS impls) | Landed v1.31.4 (QEMU 5/5 green) |
| [path-a-elf64-multiboot2.md](path-a-elf64-multiboot2.md) | GRUB MB2-EFI dead-end audit | Archived in place (retired 2026-05-13) |

## Applications

| Document | Description |
|----------|-------------|
| [planning/shared-crates.md](planning/shared-crates.md) | Shared crate registry — full (incl. pre-1.0); refresh from state.md drift list |
| [first-party/first-party-standards.md](first-party/first-party-standards.md) | Standards for all AGNOS projects |
| [first-party/first-party-documentation.md](first-party/first-party-documentation.md) | Doc-tree standards (companion to first-party-standards.md) |
| [first-party/example_claude.md](first-party/example_claude.md) | CLAUDE.md template for new projects |
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
| [vision/conscious-objects.md](vision/conscious-objects.md) | Quantum substrate / Layer 0 / companion-agent pattern (long-horizon vision) |
| [vision/creator-economy.md](vision/creator-economy.md) | Sovereign-distribution thesis (bootable USB / artifact ownership) |
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
