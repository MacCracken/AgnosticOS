# AGNOS Installation Guide

> **Version:** 2026.5.6 | **Last Updated:** 2026-05-06
>
> **Status:** AGNOS is **Pre-Beta** — closed beta opens late August 2026 (preceded by a ~July founder solo-dogfood month + Docker server-sweep); public beta is deferred to post-summer, with GA targeted late fall/early winter 2026. The kernel boots in QEMU and the sovereign boot pipeline is active. The full installer (`agnova`) and bootable distribution ISO land with **Phase 1**. This guide describes what is buildable and testable **today**, and what is coming.

---

## What Works Today

- **Sovereign boot pipeline** — `scripts/boot.cyr` (Cyrius, ~67KB compiled) launches the AGNOS kernel in QEMU.
- **AGNOS kernel** — Cyrius-native, 40+ subsystems, a small sovereign syscall surface (no socket/splice). Boots to shell on iron (NUC AMD).
- **Component verification** — `make iso-check` walks every downstream repo and confirms the artifacts an ISO would need are present and current.
- **Per-subsystem builds** — every subsystem (kybernet, ark, nous, sigil, libro, agnoshi, …) builds standalone from its own repo via `cyrius build`.

## What is Coming (Phase 1)

- **ISO Stages 1–4** — source download, cross-toolchain bootstrap, base-system build in chroot, ISO packaging.
- **agnova** (installer) — currently at 0.1.0 scaffold. Will own disk partitioning, LUKS2, bootloader install, profile selection (Desktop / Server / Minimal).
- **takumi** (build system) — pending Cyrius port. Drives recipe builds during ISO assembly.
- **Target**: closed beta cut, **late August 2026** — gated on the Cyrius bare-metal target (v6.x line).

---

## Requirements (target hardware for Beta)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | x86_64 or aarch64, 2 cores | x86_64, 4+ cores; or Raspberry Pi 4/5 (aarch64) |
| RAM | 2 GB | 8 GB (16 GB for local LLM workloads) |
| Disk | 20 GB | 100 GB NVMe SSD |
| Boot | UEFI or Legacy BIOS | UEFI with Secure Boot |
| GPU | — (CLI/server) | NVIDIA, AMD, or Intel integrated (for desktop) |

Full hardware matrix: [system-requirements.md](system-requirements.md).

---

## Building and Testing Today

All commands run from the genesis repo root unless noted.

### Prerequisites

Cyrius toolchain (required):
```sh
# Install from release tarball or build from source (cyrius repo)
# Toolchain version pinned in scripts/cyrius.cyml (manifest is single source of truth)
which cyrius  # verify on PATH
```

Host build tools (for QEMU):
```sh
# Debian/Ubuntu
sudo apt install qemu-system-x86 qemu-utils

# Arch
sudo pacman -S qemu-full
```

### Build the Sovereign Boot Pipeline

```sh
cd scripts
cyrius build src/boot.cyr build/boot
./build/boot --help
```

The `boot` binary is the Cyrius-native launcher used by every `make boot-*` target.

### Component Verification

```sh
make iso-check
```

Walks every downstream repo (agnos, kybernet, ark, nous, sigil, libro, …) and verifies the artifacts an ISO would need are present at the expected versions. Current ISO-pipeline entry point — **Stage 0**.

### QEMU Boot Test (Kernel)

```sh
make boot-test
```

Direct-boots the AGNOS kernel in QEMU via `boot.cyr`. No rootfs, no userland — just the kernel reaching shell. Serves as the ongoing smoke test for kernel + boot pipeline health.

### Build a Specific Subsystem

Each subsystem lives in its own repo; build from there. Example:

```sh
cd /home/macro/Repos/kybernet
cyrius build src/main.cyr build/kybernet
```

Repo map: see the public map in [`docs/architecture.md`](../architecture.md).

---

## Installer and ISO — Status

The installer (`agnova`) and the bootable ISO do not exist yet as user-facing artifacts. They are tracked under **Phase 13A** on the roadmap.

Progress against the ISO pipeline:

| Stage | What it does | Status |
|-------|--------------|--------|
| 0 | Resolve components (verify artifacts across all repos) | **Implemented** — `make iso-check` |
| 1 | Download / vendor upstream sources | Not started |
| 2 | Bootstrap cross-toolchain from source | Not started |
| 3 | Build base system in chroot | Not started |
| 4 | Package into ISO | Not started |

Phase 13B (Arch-Neutral Boot Pipeline) is being neutralized on the Cyrius v6.x line to keep both the bare-metal and RISC-V rv64 targets clean.

---

## Troubleshooting

### Boot Pipeline

| Symptom | Cause / Fix |
|---------|-------------|
| `cyrius: command not found` | Toolchain not on PATH. Check `~/.cyrius/bin/` or install from cyrius release tarball. |
| `cyrius build` fails with missing stdlib | Running `cycc` directly; always use `cyrius build` (auto-prepends includes). |
| `make boot-test` hangs on black screen | QEMU serial not wired; check with `qemu-system-x86_64 --version` ≥ 7.0. |
| `make iso-check` reports a stale artifact | Sibling repo hasn't been rebuilt. `cd ../<repo> && cyrius build …` then retry. |

### Kernel in QEMU

```sh
# Verbose boot (shows subsystem init order)
./scripts/build/boot --test --kernel ../agnos/build/agnos --verbose

# Run with serial console forwarded to host
./scripts/build/boot --test --kernel ../agnos/build/agnos --serial
```

### Getting Help

- **Issue Tracker**: https://github.com/MacCracken/agnosticos/issues
- **Security Issues**: see [SECURITY.md](/SECURITY.md)
- **Roadmap**: tracked in the project's development docs

---

## Historical Note

Prior versions of this document described a Debian-based rootfs + `userland/` Cargo workspace + Docker distribution path. That toolchain was retired during the monolith extraction (2026-04-01) and the Cyrius pivot (2026-04-04). Scripts from that era live in `scripts/archive-pre-cyrius/` for reference only and do not build.

---

*See also: [CONTRIBUTING.md](/CONTRIBUTING.md) for development setup, [troubleshooting.md](troubleshooting.md) for common issues, [system-requirements.md](system-requirements.md) for the full hardware matrix.*
