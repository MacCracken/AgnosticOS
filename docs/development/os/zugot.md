# Zugot

> **Zugot** (Hebrew: זוּגוֹת — pairs, as in the paired creatures that entered the ark) — Recipe repository

| Field | Value |
|-------|-------|
| Status | Active |
| Version | 0.1.0 |
| Repository | [MacCracken/zugot](https://github.com/MacCracken/zugot) |
| Type | Recipe database (TOML files, not a Rust crate) |
| License | GPL-3.0-only |

---

## What It Does

Zugot is the package database for AGNOS. Every package that can be built or installed — from the C library to the desktop compositor to the science crates — has a recipe here. Recipes are TOML files defining source, dependencies, build steps, and security hardening flags.

Each recipe is a *zug* — a matched pair of definition and source. Without zugot, ark is an empty vessel.

## Consumers

- **[ark](ark.md)** — Package manager (installs from recipes)
- **[nous](nous.md)** — Resolver (reads dependency graphs from recipes)
- **[takumi](takumi.md)** — Build system (executes build steps from recipes)
- **[mela](mela.md)** — Marketplace (distributes marketplace packages)

## Structure

```
zugot/
├── base/          — 116 recipes (LFS toolchain, kernel, core libs)
├── desktop/       — 112 recipes (Wayland, PipeWire, GPU, fonts, apps)
├── marketplace/   — 111 recipes (AGNOS crates + consumer apps)
├── ai/            — 25 recipes (CUDA, ONNX, PyTorch, whisper, llama.cpp)
├── edge/          — 31 recipes (fleet management, IoT, minimal profile)
├── network/       — 9 recipes (nftables, iproute2, wireless)
├── browser/       — 8 recipes (Firefox ESR, Chromium)
├── python/        — 4 recipes
├── database/      — 3 recipes
├── sandbox/       — 3 recipes
└── build-order.txt — 225 packages in dependency order
```

**Total**: 420+ recipes across 10 categories, plus 90+ community recipes planned for bazaar.

## Recipe Format

```toml
[package]
name = "example"
version = "1.0.0"
description = "Example — one-line description"
license = "GPL-3.0-only"
groups = ["category"]

[source]
github_release = "MacCracken/example"
release_asset = "example-*-linux-amd64.tar.gz"
sha256 = "abc123..."

[depends]
runtime = ["glibc"]
build = ["rust"]

[build]
make = "cargo build --release"
check = "cargo test"
install = "cp target/release/example $PKG/usr/bin/"

[security]
hardening = ["pie", "fullrelro", "fortify", "stackprotector", "bindnow"]
```

## Build Order

`build-order.txt` contains 225 packages in dependency-sorted order for building the complete base + desktop system from source. This is the self-hosting critical path — AGNOS builds AGNOS using these recipes in this order.

## Architecture: The Three Arks

Three meanings of "ark" converge in the AGNOS package system:

1. **Noah's Ark** — zugot (the pairs) preserves the knowledge of how to build every package so the system can be rebuilt after any disruption
2. **Ark of the Covenant** — the OS is the vessel built to hold intelligence
3. **ark** (the package manager) — the tool that carries zugot and assembles the world

## Relationship to Other Subsystems

```
zugot (recipes — the what and how)
  ↓ consumed by
nous (resolver — the dependency graph)
  ↓ feeds
ark (package manager — the install plan)
  ↓ delegates to
takumi (build system — the actual build)
  ↓ verified by
sigil (trust — package signing)
  ↓ distributed via
mela (marketplace — discovery and access)
```

## Key Design Decisions

- **Recipes live separate from tools** — zugot is the database, ark/nous/takumi are the tools. Like how PKGBUILDs don't live in the pacman repo.
- **TOML format** — human-readable, parseable, versionable in git.
- **SHA256 required** — every source must have a verified hash. Placeholder with `# TODO` only for unreleased packages.
- **Security hardening mandatory** — every recipe specifies hardening flags. No package ships without PIE, RELRO, FORTIFY at minimum.
- **License audit enforced** — every recipe must use SPDX `-only` suffix. Verified against actual repo LICENSE files.

---

See also: [Philosophy — The Three Arks](../../philosophy.md#the-three-arks)
