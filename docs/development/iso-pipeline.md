# ISO Pipeline — Extraction Completion Plan

> **Status**: Stage 0 implemented; Stage-4-only first cut planned next | **Last Updated**: 2026-04-15 (status note refreshed 2026-05-09)
>
> Per [`iso-stage4-plan.md`](iso-stage4-plan.md), the next active work is the **Stage-4-only first cut** (live image with pre-built binaries) — D1–D4 decisions pending user input. Per [CHANGELOG 2026.4.27](../../CHANGELOG.md), `make iso-check` reports 26-of-26 components ready (Stage 0 cleanly passes); ISO assembly is unblocked. LFS Stages 1–3 (cross-toolchain + base-system build) are deferred to Phase 2 of the ISO arc.
>
> The monolith extraction moved every component into standalone repos.
> This document defines what it takes to **reassemble them into a bootable ISO** —
> the work that actually closes the extraction.

---

## The Problem

`boot.cyr` today is a thin QEMU launcher. It can direct-boot the kernel and
display component versions. It cannot build an ISO. The Makefile advertises
`make boot-iso` but it calls `--iso-only`, a flag `boot.cyr` doesn't implement.

The Rust-era scripts (`scripts/archive-pre-cyrius/`) had a full 4-stage
pipeline: download sources → bootstrap cross-toolchain → build base system
in chroot → package into ISO. That pipeline is dead — it references
`userland/`, `cargo build`, and a Debian-derived rootfs. The *structure*
is the reference; the implementation must be rewritten for Cyrius.

---

## What the ISO Pipeline Must Do

### Stage 0 — Resolve Components

Locate (or build) every artifact needed for the rootfs:

| Component | Source | Artifact |
|-----------|--------|----------|
| AGNOS kernel | `../agnos/build/agnos` | ELF binary (~248KB at v1.26.1) |
| kybernet (PID 1) | `../kybernet/build/kybernet` | ELF binary (~486KB) |
| Cyrius toolchain | `../cyrius/build/cc5` | Compiler binary (~783KB at v5.10.24) |
| ark (package manager) | `../ark/build/ark` | Binary |
| nous (resolver) | `../nous/build/nous` | Binary |
| takumi (build system) | `../takumi/` | Build tool (pending Cyrius port) |
| zugot recipes | `../zugot/` | TOML recipe files + build-order.txt |
| sigil (crypto) | `../sigil/build/sigil` | Library |
| kavach (sandbox) | `../kavach/build/kavach` | Library/binary |
| daimon (agents) | `../daimon/build/daimon` | Binary |
| hoosh (LLM gateway) | `../hoosh/build/hoosh` | Binary |
| agnoshi (AI shell) | `../agnoshi/build/agnoshi` | Binary |
| Config files | `config/` (this repo) | init, services, sysctl, etc. |

Stage 0 must **verify** each artifact exists and report what's missing before
proceeding. No silent fallbacks.

**Implemented**: `./build/boot --iso-check` (or `make iso-check`). Checks all
components, categorized as required/optional, reports READY/MISS/SKIP with
versions and artifact sizes, checks host tools (qemu, grub-mkrescue,
mksquashfs, xorriso), exits non-zero if any required component is missing.

### Stage 1 — Bootstrap Toolchain

Build a cross-toolchain so the ISO's packages are host-independent.

The Rust-era pipeline followed LFS Ch. 5–6: binutils pass 1 → GCC pass 1 →
Linux headers → glibc → libstdc++ → binutils pass 2 → GCC pass 2. This
produced `x86_64-agnos-linux-gnu-gcc` under `$LFS/tools/`.

**Cyrius-era question**: Does the Cyrius toolchain (`cc5`) replace GCC for
AGNOS-native packages, or do we still need GCC for the base system (glibc,
coreutils, etc.)? Current answer: **both**. Base system packages (glibc,
coreutils, bash, etc.) are C projects built with GCC from zugot recipes.
AGNOS-native components (kernel, kybernet, ark, etc.) are built with cc5
(Cyrius v5.10.24; cc5 → `cyc` rename queued for v6.0).
The cross-toolchain bootstrap remains necessary for the C layer.

### Stage 2 — Build Base System

Enter chroot at `$LFS` and build packages from zugot recipes in dependency
order (`zugot/build-order.txt`). This is the LFS-style base: glibc, coreutils,
bash, util-linux, etc.

The build tool should be `takumi` (or `ark-build` until takumi is ported).
Each recipe is a TOML file in `zugot/base/`.

Build order currently has ~4 tiers:
- **Tier 1a**: Minimal build tools (m4, xz, zlib, sed, grep, tar, etc.)
- **Tier 1b**: Compilers and core libs (gcc, binutils, glibc, openssl, etc.)
- **Tier 2**: System infrastructure (util-linux, e2fsprogs, dbus, eudev, etc.)
- **Tier 3**: AGNOS identity (kernel, cyrius, kybernet, AGNOS services)

### Stage 3 — Install AGNOS Components

Install the AGNOS-native binaries into the rootfs. This replaces the old
`cargo build --workspace` step:

```
/usr/lib/agnos/kernel          ← AGNOS kernel
/usr/bin/kybernet              ← PID 1
/usr/bin/ark                   ← Package manager
/usr/bin/nous                  ← Resolver
/usr/bin/cyrius                ← Compiler
/usr/bin/cc5                   ← Compiler backend
/usr/bin/daimon                ← Agent orchestrator
/usr/bin/hoosh                 ← LLM gateway
/usr/bin/agnoshi               ← AI shell
/usr/lib/agnos/libsigil.a      ← Crypto
/usr/lib/agnos/libkavach.a     ← Sandbox
/etc/agnos/                    ← Configuration
/var/lib/agnos/{agents,models,cache,audit}
/var/log/agnos/audit
/run/agnos
```

Also install:
- `/etc/os-release` (AGNOS identity)
- `/etc/hostname`
- Init services from `config/services/`
- sysctl from `config/sysctl/`

### Stage 4 — Package ISO

1. Find/verify kernel (`vmlinuz`) and initramfs
2. Build GRUB config with boot menu entries:
   - AGNOS (normal boot, kybernet as init)
   - AGNOS (recovery, `/bin/bash` as init)
3. Create squashfs of rootfs (`mksquashfs`, zstd compression)
4. Assemble ISO with `grub-mkrescue` / `xorriso`
5. Generate SHA256 checksum
6. Optionally validate: boot the ISO in QEMU and check for AGNOS banner

### Stage 5 — Validate (optional but recommended)

Boot the ISO in QEMU and run `selfhost-validate`:
- Kernel boots and prints banner
- kybernet starts as PID 1
- Shell is responsive
- `cyrius --version` works (self-hosting proof)
- `ark --version` works
- Basic service startup (daimon, hoosh if models present)

---

## Blockers

Status verified 2026-05-09. Several previously-pending blockers have shipped — see [`state.md`](state.md) for live versions.

| Blocker | Status | Impact |
|---------|--------|--------|
| **takumi** not ported to Cyrius | In port (5.5.23 pin; rust-old/ authoritative until parity) | Can't build recipes natively. Workaround: shell-based `ark-build` |
| **aegis** | ✅ Graduated 0.1.0 → 0.8.2 (real implementation underway during v5.9.x) | Security daemon now scaffolded with real code; full integration pending |
| **aethersafha** not ported | Pending | No Wayland compositor. Desktop profile blocked |
| **shakti** | ✅ Shipped v0.3.0 | Privilege escalation available |
| **phylax** | ✅ Shipped v1.1.0 (Cyrius-native) | Threat detection available |
| **Cyrius multi-platform** | ✅ Shipped v5.5.x (byte-identical builds across x86_64 Linux / aarch64 Linux on real Pi / Apple Silicon Mach-O / Windows PE32+) | Multi-arch ISO unblocked at the toolchain layer |
| **sankoch** | ✅ Shipped v2.2.4 | Compression for squashfs/initramfs available |
| **Bare-metal AGNOS target** (Cyrius v5.12.x) | Reservation slipped from v5.10 → v5.11 → v5.12 | Self-hosting ISO (Phase 2) gated on this. v5.10.x = type-system arc; v5.11.x = TS testing + bug sweep; v5.12.x = bare-metal + RISC-V rv64 |

---

## Implementation Path

The pipeline should be written in Cyrius (`scripts/src/`) as an extension of
or companion to `boot.cyr`. The Rust-era scripts are **reference only** — the
structure (4 stages, LFS-style, chroot, squashfs+GRUB) is proven, but the
implementation is dead.

### Phase 1 — Minimum viable ISO (first boot target)

Scope: x86_64, minimal profile (headless), host-built toolchain assumed.

1. Extend `boot.cyr` with `--iso` mode, or write `iso.cyr` as a new entry point
2. Implement Stage 0 (component resolution + verification)
3. Shell out to host tools for Stage 1 (cross-toolchain) — don't rewrite LFS in Cyrius
4. Drive recipe builds through `ark-build` or `takumi` in chroot
5. Install AGNOS binaries (Stage 3)
6. Package with host `grub-mkrescue` + `mksquashfs` (Stage 4)
7. QEMU validation (Stage 5)

### Phase 2 — Self-hosting ISO

Scope: the ISO can rebuild itself from source.

1. Include Cyrius toolchain + cc5 in the rootfs
2. Include zugot recipes in `/usr/src/agnos/`
3. Include source for all AGNOS-native components
4. `selfhost-validate --phase all` passes inside the booted ISO

### Phase 3 — Desktop ISO

Scope: aethersafha (Wayland), Mesa, PipeWire, fonts.

Blocked on aethersafha Cyrius port. Desktop recipes exist in `zugot/desktop/`.

### Phase 4 — Multi-arch

Scope: aarch64, RISC-V.

aarch64 multi-platform codegen shipped at Cyrius v5.5.x (byte-identical Linux + Apple Silicon Mach-O). RISC-V rv64 backend reserved for Cyrius v5.12.x — that's the gate for full RISC-V ISO. aarch64 ISO can begin earlier.

---

## Profiles

Carried forward from the Rust era, adapted for current component names:

| Profile | Contents |
|---------|----------|
| **minimal** | Base system + kybernet + ark + agnoshi + daimon + hoosh. No GUI. SSH. |
| **server** | minimal + networking services + monitoring. No GUI. |
| **desktop** | server + aethersafha (Wayland) + Mesa + PipeWire + fonts + apps |

---

## Relation to Beta Target

The original "May 1 (Beltane)" boot target is **superseded** by the two-stage beta rescope (2026-05-06): closed beta in **early June 2026** with a 5–15 trusted-tester cohort, public beta in **Q4 2026** with audit + community testing.

The boot-in-QEMU milestone (`make boot-test` — kernel + kybernet PID 1) works today. The ISO pipeline (`make boot-iso` producing a real bootable artifact) is the next gate, and it's the closed-beta dependency. Phase 1 (minimum viable ISO) is what closes the extraction branch.
