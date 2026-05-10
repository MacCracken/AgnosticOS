# Sprint History

> Completed engineering backlog items and resolved sprint summaries.
> For full change details, see [CHANGELOG.md](/CHANGELOG.md).

---

## Completed Backlog Items

| # | Item | Completed |
|---|------|-----------|
| B3 | SHA256 checksums — all 264+ filled (100%) | 2026-03-18 |
| B4 | Debian debootstrap removal from build scripts | 2026-03-18 |
| E2 | MQTT bridge in daimon (`edge/mqtt_bridge.rs`, 14 tests) | 2026-03-18 |
| E3 | ESP32-CAM integration (13 tests) | 2026-03-18 |
| E4 | TinyML on ESP32-S3 (daimon side, 10 tests) | 2026-03-18 |
| S1 | gVisor/Firecracker runtime execution (`run_task()`, 47 tests) | 2026-03-18 |
| S3 | sy-agnos sandbox image Phase 1 (strength 80) | 2026-03-18 |
| S4 | sy-agnos dm-verity Phase 2 (strength 85) | 2026-03-18 |
| S5 | sy-agnos TPM measured boot Phase 3 (strength 88) | 2026-03-18 |
| T1 | Daimon remote exec API (10 tests) | 2026-03-18 |
| T2 | Daimon file transfer API (13 tests) | 2026-03-18 |
| T3 | Daimon playbook audit ingestion (5 tests) | 2026-03-18 |
| T4 | Hoosh playbook generation tuning | 2026-03-18 |
| T5 | sutra-community marketplace recipe | 2026-03-18 |
| H23 | File splitting (mcp_server, supervisor, wayland) | 2026-03-11 |
| H25 | Enum refactoring (MetricKind, BehaviorMetric, etc.) | 2026-03-11 |
| H26 | reqwest 0.11→0.12 upgrade (RUSTSEC-2025-0134) | 2026-03-14 |
| H27/H28 | Systemd Type=notify → Type=simple (boot fix) | 2026-03-14 |
| H29 | SSRF protection in HttpBridge | 2026-03-14 |
| H36 | Feature-gated desktop_environment behind `desktop` | 2026-03-14 |
| H37 | wasmtime 36→42 (WASI preview2 migration) | 2026-03-14 |

---

## Sprint Summaries

### 2026.3.22 (2026-03-19 to 2026-03-25)

| Category | Summary |
|----------|---------|
| Shared crate recipes | 37 new marketplace recipes (total 59). Every published crate now has a takumi recipe |
| Documentation | 15 new docs: app specs (impetus, joshua, muharrir, murti, stiva, t-ron, tanur), k8s-roadmap, monolith-extraction, network-evolution, science-crate-specs, shared-crates, AGNOS.md |
| Build pipeline | 10+ iterative ISO build fixes, selfhost-build.yml restructure, Rust MSRV 1.89 |
| Branding | Synapse → Irfan recipe rename |
| Refactor | llm-gateway `acceleration.rs` replaced with ai-hwaccel re-exports (−1128 lines) |

### 2026.3.20 (2026-03-19 to 2026-03-20)

| Category | Summary |
|----------|---------|
| Shared crates | 4 extracted: ai-hwaccel (crates.io), tarang (crates.io), aethersafta (scaffolded), hoosh (scaffolded) |
| ai-hwaccel | `acceleration.rs` replaced with re-exports (549 tests). Scheduler + finetune wired |
| ark-bundle | 23/23 bundles passing. 14 broken asset patterns fixed |
| Recipes | 10 created/updated |
| Release CI | tarang + ai-hwaccel multi-arch pipelines |

### 2026.3.18 (2026-03-18)

| Category | Summary |
|----------|---------|
| Sutra | v1 released — 5 crates, 70 tests, 6 MCP tools, SSH transport, sutra-community (5 modules) |
| Documentation | First-party standards, 18 app docs, roadmap split, os_long_term.md migrated |
| sy-agnos | All 3 phases complete (rootfs → dm-verity → TPM), strength 80 → 88 |
| ESP32 | Recipe + MQTT bridge + CAM + TinyML (daimon side) |
| Build | Debian debootstrap removed, SHA256 100% coverage |
| Synapse | All 7 bridge paths corrected, 21 handler tests |

### 2026.3.17 (2026-03-17 to 2026-03-18)

| Category | Summary |
|----------|---------|
| Refactoring | 10 module splits (~25K lines reorganized) |
| GPU | G1-G4: orchestrator, hoosh, edge, consumer GPU awareness |
| SY integration | 4 items: GPU status, local models, Firecracker passthrough, fleet heartbeat |
| Sandbox wiring | S1-S3: credential proxy, externalization gate, trust demotion |
| Agnostic | 13 integration items complete |
| Toolchain | Go 1.24 → 1.26 |

### 2026.3.16 (2026-03-16 to 2026-03-17)

| Category | Summary |
|----------|---------|
| Phase 16A | 9 desktop essential recipes (foot, helix, yazi, fuzzel, mako, zathura, imv, mpv, cliphist) |
| CI/CD | Two-tier build architecture (slow base rootfs + fast userland releases) |
| MCP tools | 106 → 122 (tarang + jalwa expansion) |

---

## Cyrius Era — Cycle Summaries (2026-04-03 onwards)

### Cyrius v5.10.x — REAL TYPE SYSTEM arc (2026-05-08 → in flight, currently 5.10.24)

| Category | Summary |
|----------|---------|
| Cycle theme | Type-system rollout: cstring / Result / Option / Tagged vocabulary + call-site type checking |
| Volume | 24 patches in 2 days |
| Phase 0 | v5.10.0 — per-phase compile-time profiling instrumentation (CYRIUS_PROF=1, 7 phase timestamps, ~0.7 µs total overhead) |
| Phase 1B | v5.10.5 — type vocabulary additions (cstring / Result / Option / Tagged); false-positive flood discovered |
| Phase 2 | v5.10.24 — call-site type checking via per-fn param-type bitmasks; canonical-motivator stdlib fns annotated (`println` / `strlen` / `streq` / `atoi` / `strchr` / `strstr` / `str_lower_cstr` / `str_upper_cstr` / `file_open` / `file_open_r`) |
| cc5 size | 741,048 B → 783,408 B (+42 KB from instrumentation + type machinery) |
| Reservations | v5.11.x = TS testing suite + agnosys-agent-surfaced bug sweep; v5.12.x = bare-metal AGNOS target + RISC-V rv64 (slipped from v5.10.x → v5.11.x → v5.12.x) |

### Cyrius v5.9.x — Catchup + niyama-fold close (2026-05-06 → 2026-05-08)

| Category | Summary |
|----------|---------|
| Cycle theme | Niyama fold-in opener + consumer-rollup catchup |
| Volume | 44 patches in 3 days |
| Slot 1 | v5.9.0 — niyama fold-in (8th sibling distfile, 6,664 lines / 7 modules: posix_classes, unicode_props, bre, re2, pcre, fuzzy, vim) byte-identical from niyama 1.0.1 dist |
| Pin-lag collapse | agnosys 5.7.48 → 5.10.19 (out of held-cluster); vyakarana 5.6.0 → 5.10.5 (out of deep-lag tail); sandhi/agnostik/owl/cyim/agnova/vidya all rolled forward |
| Repo graduations | aegis 0.1.0 scaffold → 0.8.2 (real implementation underway); chakshu 0.1.0 → 0.2.0 |
| New repos | **darshana** (TTY/raw-mode primitives, दर्शन — *viewing*) extracted from cyim's `src/tty.cyr` when chakshu became second consumer; **cyim-lsp** 1.5.0 (LSP server companion to cyim) |
| Closeout | 5.9.43 (2026-05-08) |

### Cyrius v5.8.x — 3-phase, 66 patches in 4 days (2026-05-01 → 2026-05-05)

| Category | Summary |
|----------|---------|
| Cycle theme | Audit closeout + language vocabulary + stdlib foldin sweep |
| Volume | 66 patches across 4 days (velocity high-water mark) |
| Phase 1 | v5.8.1–v5.8.8 — closed 8 of 12 v5.8.0 audit items (lint/fmt cap raise, cc5_aarch64 packaging + cyrc_check orphan, ts/parse.cyr fmt sweep, f64_log2 polyfill, sys_stat/fstat backfill, _SC_ARITY cross-arch gate, NI-class dupe, phylax #4 closeout) |
| Phase 2 | v5.8.9–v5.8.26 — language vocabulary arc (`var X;` bare-decl diagnostic, `cyrius fmt --check` exit code, vidya audit pattern at v5.8.40, exhaustive match / Result+? / allocators) |
| Phase 3 | v5.8.27–v5.8.65 — stdlib foldin sweep (sandhi-pattern continuation, 27 foldin slots, **vani audio** at slot 1 as `lib/vani.cyr` v5.8.0 fold) |
| Slip | Original v5.8.0 plan was bare-metal — slipped to v5.9.0 then v5.10.x (ultimately v5.12.x) as foldin work compounded |

### Cyrius v5.7.x — Sandhi-fold + cyrius-ts + 51 patches (2026-04-25 → 2026-05-31)

| Category | Summary |
|----------|---------|
| Cycle theme | First stdlib absorption (sandhi-fold pattern established) + cyrius-ts proposals |
| Volume | 51 patches over 36 days |
| Slot 1 | v5.7.0 — **sandhi fold-in** (`lib/sandhi.cyr` 9,649 lines / 376,037 B / 469 fns vendored byte-identical from sandhi 1.0.0). sandhi repo enters maintenance mode per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md). Pattern set for vani (v5.8.0) and niyama (v5.9.0) |
| cyrius-ts | P1–P10 proposals (type-system precursors that informed the v5.10.x arc) |
| Optimization | Incidental — main optimization arc was v5.6.x; v5.7.x continued partial follow-on (O3a IR, O4a–c regalloc) |

### Cyrius v5.6.x — Optimization arc (2026-04-22 → 2026-04-25)

| Category | Summary |
|----------|---------|
| Cycle theme | Compiler optimization passes |
| O1 | IR instrumentation + FNV-1a hashing |
| O2 | Strength reduction + commutative-combine-shuttle |
| Regalloc | Linear-scan picker default-on |
| Closeout | v5.6.45; **O3–O6 deferred** (partial follow-on shipped through v5.7.x and v5.8.x: O3a IR; O4a/b/c register-allocation including Poletto-Sarkar linear-scan picker; O5 referenced; O6 codebuf compaction) |

### Cyrius v5.5.x — Multi-platform byte-identical (2026-04-22)

| Category | Summary |
|----------|---------|
| Achievement | Byte-identical reproducible builds across x86_64 Linux, aarch64 Linux on real Pi, Apple Silicon Mach-O, Windows PE32+ |

### Cyrius v1.0 → v5.0 — Self-hosting + ecosystem boot (2026-04-04 → 2026-04-15)

| Category | Summary |
|----------|---------|
| v1.0 (2026-04-04) | Self-hosting compiler from 29KB seed in 44 hours after scaffold. Variables, arithmetic, if/else, while, factorial. Beats GNU on size (10–233×) and speed (wc 2.4× faster) |
| v1.0 → kernel | Same day: AGNOS kernel boots (VGA, 64-bit, page tables, keyboard, memory management). 23:16 PT — "kernel solid" |
| v2.0 (2026-04-08) | DOOM Sprint 1 — black screen at 21:31, BSP by 21:35, textures by 22:24, sprites by 22:38. v0.17.0 / 129KB / Episode 1 renderable |
| v3.0 (2026-04-09) | Stdlib growth, dep system maturing, Patra in stdlib |
| v4.0 (2026-04-13) | DOOM Sprint 2 — gameplay end-to-end, P(-1) security audit, 5 CVE-class findings fixed. AGNOS kernel hardening (6 buffer overflow fixes, security phases 1–3). Kernel v1.21.0 (220KB). kybernet 1.0.1 ported. Boot pipeline active |
| v4.8.5-1 (2026-04-14) | 22+ Cyrius ports complete. kavach 3.0.0, abaco 2.0.0, bote 2.5.1 shipped. Kernel v1.22.0 (260KB). Independent audit on Anthropic infrastructure (bootstrap verified, kernel booted, benchmarks green). Sankoch named as last git blocker |
| v5.0 (2026-04-15) | cc5 IR, CFG, cyrius.cyml, patra v1.0, sankoch in stdlib (beats C zlib). 5,762 assertions passing. cc3 → cc5 rename (cc4 skipped). hisab 2.2.0, shravan 2.3.2 modernized |

---

## Monolith Extraction — Complete (2026-04-01 to 2026-04-07)

The original monolith (`userland/`) contained agent-runtime, ai-shell, llm-gateway, desktop-environment, agnos-common, and agnos-sys. All have been extracted.

### Completed Extractions

| Original | Extracted To | Version | Method | Date |
|----------|-------------|---------|--------|------|
| `agent-runtime/` | 12 standalone repos (see below) | various | Code moved to new repos | 2026-04-01 |
| `ai-shell/` | **agnoshi** (`MacCracken/agnoshi`) | 0.1.0 | Code moved | 2026-04-01 |
| `llm-gateway/` | **hoosh** (`MacCracken/hoosh`) | 1.2.0 | Code moved | 2026-04-01 |
| `desktop-environment/` | **aethersafha** (`MacCracken/aethersafha`) | 0.1.0 | Code moved | 2026-04-01 |
| `agnos-common/` | **agnostik** (`MacCracken/agnostik`) | 0.90.0 | Git dep, tag `0.90.0` | 2026-04-02 |
| `agnos-sys/` | **agnosys** (`MacCracken/agnosys`) | 0.51.0 | Git dep, tag `0.51.0` | 2026-04-02 |
| `agnos-sudo/` | **shakti** (`MacCracken/shakti`) | 0.1.0 | Standalone repo | 2026-04-03 |

### Crate Absorptions (code merged into existing repos)

| Source Module | Absorbed Into | New Version |
|--------------|---------------|-------------|
| `agent-runtime/mcp_server/` | **bote** | 0.92.0 |
| `agent-runtime/sandbox_mod/` | **kavach** | 2.0.0 |
| `agent-runtime/safety/` | **t-ron** | 0.90.0 |

### Post-Extraction Cleanup

- [x] Clean up workspace `Cargo.toml` — removed 14 unused deps, fixed agnosys tag 0.50.0 → 0.51.0
- [x] Repo identity: meta-repo (docs, scripts, kernel configs, CI/CD). CLAUDE.md updated.
- [x] **Extract `recipes/` to zugot** — all 421 recipes migrated (2026-04-07). zugot is authoritative.

### Recipe Audit — Complete (moved to zugot)

- [x] License audit — all 109 marketplace recipes set to `GPL-3.0-only`
- [x] Version sync — 5 recipe versions corrected (agnosys, daimon, hoosh, kybernet, bote)
- [x] Header comments — 29 stale comments updated
- [x] Structural fixes — 3 misplaced install blocks, tazama stale gstreamer deps removed
- [x] Recipes extracted to zugot (2026-04-07) — zugot is authoritative
- [x] Edge recipes synced: openssl, glibc, bash, iproute2
- Remaining recipe work (SHA256 verification, version bumps) tracked in zugot

---

*This file is maintained alongside [CHANGELOG.md](/CHANGELOG.md). The changelog has full details; this file provides quick reference summaries.*

*Last updated: 2026-05-09 (Cyrius v5.7.x → v5.10.x cycles appended)*
