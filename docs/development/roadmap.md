# AGNOS Development Roadmap

> **Status**: Pre-Beta | **Last Updated**: 2026-04-27
>
> 🔴 **NEXT ACTIVE WORK**: ISO Stage-4-only first cut — see
> **[`iso-stage4-plan.md`](iso-stage4-plan.md)**. This is the next-up item
> after the 2026-04-27 boot-pipeline updates (sigil 2.9.4 cut, agnostik
> reverted, scripts pinned to Cyrius 5.7.21). The plan has four open
> decisions (D1–D4) that need user input before coding begins. Next agent:
> **read the plan, then resolve D1–D4 with Robert.**
>
> **May 1 V1 release** is 4 days out — complete-system V1 (kernel + Cyrius + toolchain + 30+ ports + science library + ISO Stage 0+ working toward Stage-4-only first cut), positioned as *"Boots, runs DOOM, all Cyrius."* Biweekly cadence through August DEF CON distribution (see [Near-Term Cadence](#near-term-cadence--may-1-v1-to-def-con)).
> **Kernel 1.22.0 shipped** (2026-04-13) — 260KB, 33 subsystems, 26 syscalls, hardened pass.
> **Cyrius 5.7.0 shipped** (2026-04-25) — **THE SANDHI FOLD**. `lib/sandhi.cyr` adds (vendored byte-identical from sandhi v1.0.0, 376,037 B / 9,649 lines, 469 fns); `lib/http_server.cyr` deletes; sandhi repo enters maintenance mode per [ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md). Cyrius-side gates 1, 2, 3, 5, 6 ✅; gate 4 (downstream sweep) is separate user-organized work — only **vidya** actually `include`s `lib/http_server.cyr`; yantra and sit have orphan pre-fold copies (cleanup-only); the originally-listed `sit-remote`/`ark-remote` don't exist. v5.6.x closed at v5.6.45 on 2026-04-25 (45 patches — new longest-minor record). v5.6.0 opened the compiler-optimization arc on 2026-04-22 (**Phase O1** v5.6.0–v5.6.4 instrumentation + FNV-1a symbol hashing; **Phase O2** v5.6.11 partial strength reduction, flag-result reuse, push/pop elim, commutative + aarch64 combine-shuttle; **regalloc** v5.6.20–v5.6.24 default-on linear-scan; **closeout** v5.6.43 sigil 2.9.3 / sankoch 2.1.0 / output_buf 2MB).
> **Multi-platform closed.** x86_64 Linux byte-identical; aarch64 Linux byte-identical on real Pi (stdlib shakedown v5.5.18); Apple Silicon Mach-O self-host closed (v5.5.17); Windows PE32+ native self-host byte-identical on real Windows 11 (v5.5.10). NSS/PAM real-fix arc shipped v5.5.23–v5.5.27; `lib/fdlopen.cyr` landed in v5.5.x arc. **v5.7.x slate**: v5.7.1 cyrius-ts foundational (TS sync non-TSX subset; 10 phases P1 lex → P10 release; pinned 2026-04-24); v5.7.2 cyrius-ts completion (async/await/Promise + JSX scope decision; pinned 2026-04-25); v5.7.3 RISC-V rv64 (slid 3× from v5.7.0; pinned 2026-04-25); v5.8.0 bare-metal queued.
> **ISO pipeline started** — Stage 0 (component verification) implemented: `make iso-check`. See `docs/development/iso-pipeline.md`.
> **Kavach 3.0.0 shipped Cyrius-native** — 344KB (was 2.4MB Rust), 1 dep, 9 CWE fixes, sandbox lifecycle 500× faster.
> **Sankoch 2.0.0 shipped** — lossless compression (LZ4, DEFLATE, zlib, gzip). stdlib fold pending.
> **Abaco 2.1.0** — Miller-Rabin ~12× faster end-to-end via Cyrius hardware u64_mulmod fast-path.
> **Bote 2.5.1** / **T-Ron 2.0.0** shipped — both out of pre-release. Bote MCP pipeline ~5µs/message.
> **Ark 0.8.0** / **Nous 1.1.1** — package manager + resolver ported to Cyrius.
> **Phylax 1.0.0** / **Shakti 0.2.2** — threat detection + privilege escalation ported to Cyrius.
> **New shared crates (Apr 22–23)**: **owl** v0.1.0 (Cyrius-native `cat`/`bat` replacement, M0–M5 shipped) and **vyakarana** v0.1.0 (source-code grammar / tokenizer library — ten-kind palette locked; M1 agent started). owl M3b highlighting consumes vyakarana when M1 lands.
> **Critical path CLEARED**: libro ✅ argonaut ✅ kybernet ✅ kernel ✅ boot pipeline ✅ kavach ✅ ark ✅ nous ✅
> **Shared ecosystem**: 30+ repos ported to Cyrius. In port (partial, `rust-old/` still authoritative): takumi 0.8.0. Pending port: bhava, aegis, aethersafha.
> **Next milestone**: **May 1 V1** — bootable ISO runs DOOM from Cyrius; kernel + toolchain + 30+ ports + science library shipped. Then biweekly cadence to DEF CON.

---

## Strategic Vision

AGNOS becomes a real operating system in two stages:

1. **OS Independence** (Beta) — AGNOS boots and builds itself without any host distro. Self-hosting LFS-style base, takumi recipes for the full stack, ark as sole package manager. This is the foundation.

2. **Desktop Completeness** (v1.0) — Ship a complete desktop experience by packaging existing open-source tools first, then progressively replace with AI-native alternatives where the AI is the primary value.

**Priority order**: OS identity → desktop essentials via recipes → AI-native apps

---

## Critical Path to Beta

```
Cyrius ports (agnostik → agnosys → libro → argonaut → kybernet)
  ↓
kybernet folds into AGNOS kernel as PID 1
  ↓
Phase 13A (self-hosting boot) ──→ Phase 16 (desktop) ──→ Phase 13C (community) ──→ BETA
```

### Beta — Q4 2026

- [ ] **OS Independence (13A)** — PRIMARY BLOCKER
- [ ] Third-party security audit complete
- [ ] Community testing program active

### v1.0 — Q2 2027

- [ ] Phase 13C complete — Documentation, community
- [ ] Phase 16 complete — Full desktop experience
- [ ] All consumer apps published to mela
- [ ] 6 months of beta testing with no critical bugs

Long-term vision (v2.0 kernel, v3.0 Cyrius, v4.0 conscious objects, Foundation): [vision/release-vision.md](vision/release-vision.md)
Creator economy (sovereign distribution, bootable USB media): [vision/creator-economy.md](vision/creator-economy.md)

---

## Near-Term Cadence — May 1 V1 to DEF CON

Biweekly beats between the May 1 V1 release and DEF CON / Black Hat
August distribution. Each beat is a single headline — the thing
that's true that wasn't true two weeks ago.

| Date        | Beat                                                                                                | Primary repos                       |
|-------------|-----------------------------------------------------------------------------------------------------|-------------------------------------|
| **May 1**   | **V1: Boots, runs DOOM, all Cyrius.** ISO Stage 0+ cut; kernel 1.22.x + Cyrius toolchain + 30+ ports + science library | `agnos`, `cyrius`, `agnosticos`     |
| **May 15**  | **Library for Humanity.** Reference library + knowledge corpus (vidya + abaco + 27-crate science tier) shipped as a browseable first release | `vidya`, `abaco`, all science crates |
| **June 1**  | **Multi-platform byte-identical.** x86_64 + aarch64 + Apple Silicon + Windows PE32+ reproducible cross all four | `cyrius`                            |
| **June 15** | **Self-hosting in action.** Cyrius compiles itself from tarball on a booted AGNOS ISO, end-to-end   | `cyrius`, `agnos`, `agnosticos`     |
| **June 21** | **Solstice: higher-order items.** TBD gift — agent-tooling article + capstone receipts               | `agnosticos/docs/articles`          |
| **July 1**  | **Distribution at scale.** Ark OTA pipeline live; recipes buildable from zugot by third parties     | `ark`, `nous`, `zugot`              |
| **July 15** | **Reproducibility standard.** Every artifact in the stack has an SHA manifest; seed + hash chain published | `sigil`, `libro`, `agnosticos`      |
| **August**  | **DEF CON / Black Hat distribution.** ~$5K budget: 10K stickers + 500 SD cards + 1K quick-start cards. Bumper-sticker-as-cryptographic-root-of-trust: QR-encoded 29KB seed + SHA-256 chain + URL → **sticker becomes paper signing authority.** | `agnosticos`                        |

**Cadence discipline**: each beat is a release, not a blog post. If
the beat doesn't ship running software on the date, it slips to the
next biweekly slot — the list tightens, doesn't move right.

**Not in the cadence** (deliberately): Beta, v1.0, SY redesign,
Phase 17–19 work. Those remain on the Beta Q4 2026 / v1.0 Q2 2027
track above. (Polymorphic codegen previously listed here; slotted
to Cyrius v5.13.x as of 2026-04-25 — see
`cyrius/docs/development/roadmap.md`.)

---

## Status

### Cyrius Language — v5.6.13

Full milestone history lives in `cyrius/CLAUDE.md` + `cyrius/CHANGELOG.md`. Headline status for AGNOS:

| Milestone | Status |
|-----------|--------|
| Self-hosting compiler | **Done** (29KB seed, 467KB compiler, self-compile) |
| Multi-width types, unions, bitfields, defer | **Done** |
| Dependency resolution (cyrius.cyml, falls back to cyrius.toml) | **Done** |
| http_server + ws stdlib absorption | **Done** (v4.5.0) |
| Multi-file linker + cross-unit DCE | **Done** (v4.6.x) |
| PIC codegen, u128 types | **Done** (v4.7–4.8.x) |
| Jump tables + register allocation | **Done** (v4.8.4) |
| Math pack (u64_mulmod fast-path, 12× Miller-Rabin end-to-end) | **Done** (v4.8.5) |
| aarch64 cross-compiler + native Pi self-host (byte-identical) | **Done** (v5.3.15+) |
| Apple Silicon Mach-O (self-hosts byte-identically on M-series) | **Done** (v5.3.13) |
| Windows PE32+ — `hello\n` runs end-to-end on real hardware | **Done** (v5.4.8) |
| Windows Win64 ABI ≤4-arg (call-site + register mapping) | **Done** (v5.5.3) |
| Windows Win64 ABI >4-arg cyrius-to-cyrius call-site | **Done** (v5.5.4) |
| Windows `lib/fnptr.cyr` indirect fn-pointer Win64 calls | **Done** (v5.5.5–v5.5.7) |
| Windows native self-host (`cc5_win` compiling itself byte-identical) | **Done** (v5.5.10) |
| macOS aarch64 target closed (argv + Mach-O entry prologue) | **Done** (v5.5.17) |
| aarch64 Linux stdlib shakedown (4-thread mutex on Pi 4) | **Done** (v5.5.18) |
| u64-hashmap (SplitMix64, zero-alloc hot path) | **Done** (v5.5.20) |
| AES-NI 16-B array alignment fix (sigil 2.9.1 unblock) | **Done** (v5.5.21) |
| `cyrfmt --write` in-place rewrite | **Done** (v5.5.22) |
| NSS/PAM real-fix arc (pwd/grp/shadow/PAM via unix_chkpwd) | **Done** (v5.5.23–v5.5.27) |
| `lib/fdlopen.cyr` foreign-dlopen (Cosmopolitan pattern) | **Done** (v5.5.x arc) |
| v5.5.x closeout — 40 patches, longest minor in Cyrius history | **Done** (v5.5.40, 2026-04-22) |
| **Phase O1** — instrumentation + FNV-1a symbol hashing | **Done** (v5.6.0–v5.6.4) |
| **Phase O2** — peephole categories 1–5 (PSR, flag-result reuse, push/pop elim, commutative combine-shuttle, aarch64 combine-shuttle) | **Done** (v5.6.5–v5.6.11, closed 2026-04-23) |
| Linear-scan register allocator | **In flight** — v5.6.13 |
| Fused ops (madd, msub, ubfx, sbfx) — re-pinned post-regalloc | Queued — v5.6.14 |
| Compiler optimization arc — remaining phases (O3–O6: IR passes, maximal-munch, slab allocator, codebuf tuning) | Queued — v5.6.15–v5.6.22 |
| RISC-V rv64 codegen | Queued — v5.7.0 |
| Bare-metal / AGNOS kernel target | Queued — v5.8.0 |

### Cyrius Ports — Dependency Chain to Boot

| Crate | Rust → Cyrius | Status | Notes |
|-------|--------------|--------|-------|
| agnostik | 0.90.0 → 0.97.1 | **Done** | Shared types |
| agnosys | 0.51.0 → 1.0.0 | **Done** | Syscall wrappers (59× smaller) |
| sigil | 1.0.0 → 2.9.0 | **Done** | Crypto boundary |
| shravan | 1.1.0 → 2.3.2 | **Done** | Audio codecs |
| libro | 0.92.0 → 2.0.5 | **Done** | Audit chain |
| argonaut | 0.90.0 → 1.2.0 | **Done** | Init system library |
| kybernet | 0.51.0 → 1.0.1 | **Done** | PID 1 (14× smaller, 486KB) |
| AGNOS kernel | — → 1.22.0 | **Done** | 260KB, 33 subsystems, Cyrius-native |
| hoosh | 1.2.0 → 2.0.0 | **Done** | LLM gateway (10.8× smaller) |
| ai-hwaccel | 1.0.0 → 2.0.0 | **Done** | GPU detection (3.3× smaller) |
| avatara | 1.0.1 → 2.3.0 | **Done** | Archetype overlay (2,761× faster cached) |
| kavach | 2.0.0 → 3.0.0 | **Done** | Sandbox (500× faster lifecycle) |
| abaco | — → 2.1.0 | **Done** | Math/number theory (-52% lines, 12× Miller-Rabin) |
| bote | 0.92.0 → 2.5.1 | **Done** | MCP core (~5µs/message) |
| t-ron | 0.90.0 → 2.0.0 | **Done** | MCP security |
| daimon | 0.6.0 → 1.1.1 | **Done** | Agent orchestrator |
| agnoshi | 0.90.0 → 1.0.0 | **Done** | AI shell |
| itihas | 1.0.1 → 2.2.0 | **Done** | History/versioning |
| hadara | — → 1.0.0 | **Native** | Culture modeling (Cyrius-native) |
| mabda | 1.0.0 → 2.4.1 | **Done** | GPU foundation |
| sankoch | — → 2.0.0 | **Done** | Lossless compression (LZ4, DEFLATE, zlib, gzip) |
| ark | — → 0.8.0 | **Done** | Package manager (4× smaller, 40× faster) |
| nous | — → 1.1.1 | **Done** | Package resolver |
| phylax | — → 1.0.0 | **Done** | Threat detection |
| shakti | — → 0.2.2 | **Done** | Privilege escalation |
| hisab | — → 2.2.0 | **Done** | Higher math |
| bhava | — → 2.0.0 | Pending | Emotion/sentiment (has Cargo.toml) |
| takumi | 0.8.0 → 0.8.x | **In port** | Package build system — Cyrius port active, pinned 5.5.23, `rust-old/` authoritative until parity |
| aegis | — → 0.1.0 | Pending | System security daemon |
| aethersafha | — → 0.1.0 | Pending | Wayland compositor |

### Monolith Extraction — Complete

Full details: [sprint-history.md](sprint-history.md#monolith-extraction--complete-2026-04-01-to-2026-04-07)

### Open KPIs

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Boot Time | <10s | **3.2s** (kernel+init), **~80ms** init→event loop | **Achieved** |
| OS Independence | Yes | Pending | Phase 13A — critical path cleared, self-hosting validation remaining |
| DOOM | Playable | **2.59ms/frame**, cyrius-doom 0.26.1, hardened (5 CVEs fixed) | **Unblocked** — Cyrius Phase O2 closed v5.6.11; regalloc v5.6.13 in flight. Full-frame benchmark re-run pending v5.6.x closeout. |

---

## Active Work

### Phase 13A — OS Independence Validation (BETA BLOCKER)

**This is the single most important remaining work.** Without it, AGNOS is a Debian overlay.

**Previous blocker (CLEARED)**: kybernet Cyrius port. Dependency chain completed 2026-04-13: libro ✅ → argonaut ✅ → kybernet 1.0.1 ✅ → kernel 1.22.0 ✅ → boot pipeline (Cyrius, 56KB) ✅.

**Current work**: Sovereign boot pipeline active. Kernel boots in QEMU via `make boot-test`. Remaining items are self-hosting validation (can AGNOS rebuild itself from source without a host distro).

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Kernel boots in QEMU | **Done** | boot.cyr (67KB Cyrius binary, rebuilt against 5.7.21 on 2026-04-27), kernel 1.26.1 (248KB, real CI hygiene fix replaced 1.26.0 workaround) |
| 2 | Sovereign boot pipeline | **Done** | `make boot-test` from genesis repo |
| 2.5 | ISO `--iso-check` (Stage 0 component verification) | **Done** | 26-of-26 components READY (2026-04-27 audit), ISO assembly unblocked |
| **3** | **ISO Stage-4-only first cut (live image, pre-built binaries)** | **🔴 NEXT** — planned, awaiting D1–D4 | See [`iso-stage4-plan.md`](iso-stage4-plan.md). Days, not weeks. **Phase 1 of the May 1 V1 ISO story.** |
| 4 | LFS Stage 1: bootstrap-toolchain.sh end-to-end | Deferred to Phase 2 | Build cross-compiler from source tarballs. Not blocking first ISO. |
| 5 | LFS Stage 2: build base system in chroot | Deferred to Phase 2 | ark-build all 109 base recipes. Phase 2 = self-hosting story. |
| 6 | LFS Stage 3: build AGNOS userland on target | Deferred to Phase 2 | Cyrius-compiled binaries inside AGNOS (Stage-4-only ships pre-built). |
| 7 | Selfhost-validate passes all phases | Deferred to Phase 2 | Run `selfhost-validate --phase all` on booted ISO |
| 8 | CI automation | In progress | GitHub Actions workflows |

**Target**: May 1, 2026 (Beltane)

### P0 — Other Active Blockers

**Cyrius as Base Toolchain (CI/Release)**
- [ ] Add `zugot/base/cyrius.cyml` recipe
- [ ] CI builds use Cyrius for AGNOS-native components
- [ ] Release pipeline: Cyrius-compiled binaries as first-class artifacts
- [ ] `build-order.txt` updated — Cyrius inserted after Rust in toolchain stage

**agnosticos.org Website**
- [ ] Update landing page stats
- [ ] Add Cyrius mention and DOOM article
- [ ] Publish articles as web content
- [ ] Add philosophy page
- **Blocked on**: Cyrius maturity + core rewrites stabilized

### Engineering Backlog

*Completed items archived in [sprint-history.md](sprint-history.md).*

| # | Priority | Item | Notes |
|---|----------|------|-------|
| B1 | High | Self-hosted CI runners on AGNOS | Replace Arch/Ubuntu runners with AGNOS itself |
| B2 | High | RPi4 hardware boot test | Firmware blobs added, needs physical validation |
| R2 | High | Update scripts/CI for zugot | 16 scripts/CI/config files still reference local `recipes/` paths |
| E1 | Medium | ESP32 agent source repo | Recipe done, MQTT bridge done. Pending: source repo + firmware |
| V1 | Stretch | t-ron voice — contract Bruce Boxleitner | Direct voice-synthesis contract with the actor *infamous* for the role; permanently hardens t-ron's character identity to its namesake. **The play — the argument is the asset**: AGNOS ships a Tron that actually *exists* — t-ron is a living, executing MCP security monitor that demonstrably fights for users in the real tool layer. Disney's Tron is fiction; t-ron is shipped software. The substantive argument that move makes in public: *"the real version of this is now working software, not a 1982 film."* That argument is the asset — it lands the moment the cultural shift starts, and Disney litigating against it is them defending fiction against a working artifact (i.e. losing the argument). Disney's natural incentive then flips to **alignment** ("Tron is real"), not litigation. Boxleitner's voice/likeness is licensed directly (his to grant). Any litigation pressure is downstream noise, not the substance of the move. **Core idiom** — *"We fight for the users"* is t-ron's operating ethic, the line *made real*: it ties directly to the subsystem's job (MCP security monitor — protect the user from bad actors in the tool layer). **Capture corpus**: the core idiom is the non-negotiable seed; targeted phrase-set captured for inference seeding; everything else naturally generated by the model, no script-reading sessions. Iterative — once natural cadence locks, additional phrases / word recitations can be captured to refine the synthesis. **Reach goal**: Boxleitner's sign-off and active participation — the actor publicly endorsing the subsystem named in his role's honor, on par with the back-pocket-ally tier. **Sequencing**: post-V1, after first-tier ally relationships land. Outreach rides the public AGNOS news cycle (booted OS + DEF CON receipts + articles in circulation) so the conversation isn't cold — momentum opens the door. Budget + outreach path TBD. |

Repo-specific backlog items tracked in their respective repos.

---

## Pre-Beta

### Phase 13B — Arch-Neutral Boot Pipeline

**Gate**: opens on Cyrius v5.6.x compiler-optimization arc closeout (tracked to v5.6.22 per the milestone table above — O3–O6 remaining after regalloc and fused ops).
**Precedes**: Cyrius v5.7.0 RISC-V rv64 — this work lands *between* v5.6.x and v5.7.0.
**Rationale**: Cyrius locks the sequencing v5.6.x (optimization) → v5.7.0 (RISC-V) → v5.8.0 (bare-metal). Agnos already did the multi-arch split at v1.1.0 (`kernel/arch/x86_64/`, `kernel/arch/aarch64/`, `kernel/core/`, `kernel/user/`). The gap is that everything downstream of boot still carries x86_64/aarch64-shaped assumptions. Neutralizing now means v5.7.0 RISC-V and v5.8.0 bare-metal slot in as "add a target," not "rewrite the pipeline."

**Genesis-repo items (owned here):**

| # | Item | Notes |
|---|------|-------|
| 1 | `scripts/boot.cyr` arch detection + per-arch branch tables | Cross-compilation flag routing |
| 2 | ISO pipeline Stages 1–4 arch-aware | Stage output keyed on target triple |
| 3 | `bootstrap-toolchain.sh` cross-arch | x86_64 / aarch64 / riscv64 / bare-metal source tarball builds |
| 4 | `build-order.txt` per-arch gates | Failing arch doesn't block others |

**Downstream sweep (tracked in respective repos):**
- **Must-touch (boot path)**: agnos, kybernet, argonaut, agnosys, sigil
- **Should-touch (build/packaging)**: ark, nous, zugot, agnova, takumi
- **May-touch**: phylax, shakti, ai-hwaccel, seema

**Target**: complete before Cyrius v5.7.0 ships. Don't scope-creep before v5.6.x closeout — let the optimization arc re-baseline benchmarks first.

### Phase 13C — Community & Documentation

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Video tutorials | Not started | Installation, usage, agent creation |
| 2 | Support portal | Not started | Discord + forum |
| 3 | Community testing program | Not started | Beta tester enrollment |
| 4 | Third-party security audit | Not started | External vendor |

### Phase 13F — Hardware Testing Matrix

| # | Target | Arch | Profile | Status |
|---|--------|------|---------|--------|
| 1 | Rocky Linux VM | x86_64 | Dev/test | **Active** — DOOM testing environment |
| 2 | Touchscreen PC | x86_64 | Desktop | Available — needs AGNOS install |
| 3 | Raspberry Pi 4 | aarch64 | Full | Available — needs physical validation |
| 4 | AWS DeepLens | x86_64 | Edge | Available |
| 5 | 4U server blade | x86_64 | Build/storage | Available — CI runner candidate |
| 6 | 2x 1U blades | x86_64 | CI runners | Available |
| 7 | NAS conversion | x86_64 | Fleet storage | Available |
| 8 | DJI Tello drone | ARM | IoT | Available |
| 9 | ESP32 devices (multiple) | xtensa | IoT/Edge | Available |
| 10 | ASIC miners | — | Crypto accel | Available |
| 11 | Gaming cabinet | x86_64 | Desktop + kavach | Available — dual-purpose: AGNOS host + Windows guest |

### Phase 13G — Consumer App Bundle Tests

All 19 apps released. Bundle tests (`ark-bundle.sh`) not yet run.

### Phase 16 — Desktop Completeness

Detailed items tracked in respective repos:
- **16B/D/E** — Input, polish, configurability → `MacCracken/aethersafha`
- **16F** — Media ingestion & compositing → `MacCracken/aethersafta`
- **Desktop recipes** (fonts, themes, icons) → zugot

### Phase 15 — Threat Detection & Scanning

**Subsystem**: **phylax** — standalone repo (`MacCracken/phylax`). Detailed roadmap tracked there.

---

## Ecosystem

### Named Subsystems (30+)

All subsystems are standalone repos at `/home/macro/Repos/{name}/`.

| Name | Role | Repo | Version | Cyrius Port |
|------|------|------|---------|-------------|
| **agnos** | AGNOS kernel | `MacCracken/agnos` | 1.22.0 | **Native** |
| **cyrius** | Sovereign compiler | `MacCracken/cyrius` | 5.5.27 | **Native** |
| **kybernet** | PID 1 binary | `MacCracken/kybernet` | 1.0.1 | **Done** |
| **argonaut** | Init system (library) | `MacCracken/argonaut` | 1.2.0 | **Done** |
| **agnosys** | Kernel interface | `MacCracken/agnosys` | 1.0.0 | **Done** |
| **agnostik** | Shared types library | `MacCracken/agnostik` | 0.97.1 | **Done** |
| **sigil** | Trust verification & crypto | `MacCracken/sigil` | 2.9.0 | **Done** |
| **libro** | Audit chain | `MacCracken/libro` | 2.0.5 | **Done** |
| **hoosh** | LLM inference gateway | `MacCracken/hoosh` | 2.0.0 | **Done** |
| **avatara** | Divine archetype overlay | `MacCracken/avatara` | 2.3.0 | **Done** |
| **ai-hwaccel** | GPU detection | `MacCracken/ai-hwaccel` | 2.0.0 | **Done** |
| **kavach** | Sandbox execution | `MacCracken/kavach` | 3.0.0 | **Done** |
| **abaco** | Math/number theory | `MacCracken/abaco` | 2.1.0 | **Done** |
| **bote** | MCP core | `MacCracken/bote` | 2.5.1 | **Done** |
| **t-ron** | MCP security monitor | `MacCracken/t-ron` | 2.0.0 | **Done** |
| **daimon** | Agent orchestrator | `MacCracken/daimon` | 1.1.1 | **Done** |
| **agnoshi** | AI shell | `MacCracken/agnoshi` | 1.0.0 | **Done** |
| **hadara** | Culture modeling | `MacCracken/hadara` | 1.0.0 | **Native** |
| **shravan** | Audio codecs | `MacCracken/shravan` | 2.3.2 | **Done** |
| **mabda** | GPU foundation | `MacCracken/mabda` | 2.4.1 | **Done** |
| **sankoch** | Lossless compression | `MacCracken/sankoch` | 2.0.0 | **Done** |
| **itihas** | History/versioning | `MacCracken/itihas` | 2.2.0 | **Done** |
| **bsp** | BSP geometry library | `MacCracken/bsp` | 1.1.2 | **Done** (waiting on Cyrius 5.6.x optimization arc) |
| **cyrius-doom** | DOOM engine | `MacCracken/cyrius-doom` | 0.26.1 | **Native** (waiting on Cyrius 5.6.x optimization arc) |
| **ark** | Unified package manager | `MacCracken/ark` | 0.8.0 | **Done** |
| **nous** | Package resolver | `MacCracken/nous` | 1.1.1 | **Done** |
| **phylax** | Threat detection engine | `MacCracken/phylax` | 1.0.0 | **Done** |
| **shakti** | Privilege escalation | `MacCracken/shakti` | 0.2.2 | **Done** |
| **hisab** | Higher math | `MacCracken/hisab` | 2.2.0 | **Done** |
| **owl** | `cat`/`bat` replacement | `MacCracken/owl` | 0.1.0 | **Native** — M0–M5 shipped; M3b blocked on vyakarana |
| **vyakarana** | Source-code grammar / tokenizer | `MacCracken/vyakarana` | 0.1.0 | **Native** — M0 scaffold shipped 2026-04-23; M1 shell grammar in flight |
| **bhava** | Emotion/sentiment | `MacCracken/bhava` | 2.0.0 | Pending |
| **takumi** | Package build system | `MacCracken/takumi` | 0.8.0 | **In port** — pinned Cyrius 5.5.23, parity work in flight |
| **aegis** | System security daemon | `MacCracken/aegis` | 0.1.0 | Pending |
| **aethersafha** | Desktop compositor | `MacCracken/aethersafha` | 0.1.0 | Pending |
| **mela** | Agent marketplace | `MacCracken/mela` | 0.1.0 | Pending |
| **agnova** | OS installer | `MacCracken/agnova` | 0.1.0 | Pending |
| **seema** | Edge fleet management | `MacCracken/seema` | 0.1.0 | Pending |
| **samay** | Task scheduler | `MacCracken/samay` | 0.1.0 | Pending |
| **cyim** | Sovereign text editor (VIM-inspired) | `MacCracken/cyim` | 0.1.0 | **Scaffolded** 2026-04-25 — M0 ships, vyakarana consumer at M2 |
| **bazaar** | Community package repo | `MacCracken/bazaar` | — | — |

### Cross-Cutting Concerns

**Bazaar** — Community package repository. Repo: `MacCracken/bazaar`. 90 recipes across 8 categories.

**SecureYeoman & Agnostic** — Integration tracked in respective repos. Key ecosystem dependency: **sluice** (A2A protocol extraction from SY).

**Creator Economy** — The pipe, not the platform. Direct artist/creator support with zero middleman. Key crates: mudra, vinimaya, sigil, kavach, mela, libro. Details tracked in respective app repos.

### Post-Beta Phases (17-19)

Detailed roadmaps tracked in respective repos:

| Phase | Focus | Primary Repos |
|-------|-------|---------------|
| **17** | Local inference optimization | `MacCracken/murti`, `MacCracken/hoosh`, `MacCracken/ai-hwaccel` |
| **18** | Immersive communication | `MacCracken/dhvani`, `MacCracken/goonj`, `MacCracken/soorat` |
| **19** | Computational architecture | `MacCracken/murti`, `MacCracken/agnosys`, `MacCracken/ai-hwaccel` |

### Future Shared Crates — Demand-Gated

| Domain | Trigger | Likely Consumers | Priority |
|--------|---------|------------------|----------|
| **sandhi** (सन्धि — *junction, connection, joining*) | Service-boundary layer — shared HTTP/TCP/TLS + service discovery. Like sakshi for services. Absorbs `lib/http_server.cyr` extraction (landed sandhi v0.2.0); composes `lib/http.cyr`, `ws.cyr`, `tls.cyr`, `json.cyr`, `net.cyr` into full-featured client patterns. Named 2026-04-24; targets clean-break fold at **Cyrius v5.7.0** per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md). | vidya, hoosh, ifran, daimon, mela, yantra, sit-remote, ark-remote | **High — in flight** |
| **kula** (कुल) | Family/clan mesh — peer-to-peer identity, contact sharing, device fleet, shared storage. Depends on: sigil, bote, patra, seema, kavach. | Every family running AGNOS | High (post-beta) |
| **sit** (smriti / स्मृति — memory) | Sovereign version control — git replacement. Deps: sankoch (compression), sigil (crypto), patra (storage). *When-I-have-time* project; deep storyline with sankoch → stdlib fold. | AGNOS-wide | Low (when-ready) |
| **Geography / GIS** | joshua terrain, edge fleet, raasta pathfinding | joshua, kiran, raasta, nazar | Medium |
| **Music theory** | shruti or 3rd consumer needs shared scales/rhythm | shruti, naad, jalwa, kiran | Medium |
| **Typography / font metrics** | sahifa (PDF suite) needs font layout | sahifa, aethersafha, scriba | Low |
| ~~**Grammar / tokenizer**~~ | ~~owl M3b, cyim~~ | ~~owl, cyim, vidya, agnoshi~~ | **Satisfied** by `vyakarana` (2026-04-23) |

### Research & Publication

Unified Consciousness Model paper and bhava roadmap tracked in `MacCracken/bhava`.

---

## Meta

- **Long-term vision**: [vision/release-vision.md](vision/release-vision.md) — v2.0 kernel, v3.0 Cyrius, v4.0 conscious objects, Phase 20, Foundation
- **Sprint history**: [sprint-history.md](sprint-history.md)
- **App roadmap**: [applications/roadmap.md](applications/roadmap.md)
- **Changelog**: [CHANGELOG.md](/CHANGELOG.md)
- **Contributing**: [CONTRIBUTING.md](/CONTRIBUTING.md)
- **LFS Reference**: https://www.linuxfromscratch.org/lfs/view/stable/
- **BLFS Reference**: https://www.linuxfromscratch.org/blfs/view/stable/

---

*Last Updated: 2026-04-27 | Next Review: 2026-05-01 (V1 release date)*
