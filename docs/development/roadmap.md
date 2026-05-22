# AGNOS Development Roadmap

> **Status**: Pre-Beta — Closed Beta targeting **early June 2026** | **Last Updated**: 2026-05-22 (maturity arc section added; live cycle/version state lives in [`state.md`](state.md) — refer there for current kernel / Cyrius / per-repo status, not the stale per-cycle quotes embedded in this doc's top-matter below).
>
> 🔴 **BETA RESCOPED (2026-05-06)**: Two-stage beta. **Closed beta** targets early June 2026 — Phase 13A complete, exercised by a small private cohort of trusted testers (friend-network), no formal community-program enrollment. **Public beta** retains the original Q4 2026 window and adds the third-party security audit + community testing program. This is a deliberate compression: previously-mandatory beta gates (audit, community program) move to the public-beta gate so the closed-beta line is honest about what shipped.
>
> 🔴 **MVP GATE — NEXT ACTIVE WORK**: ISO Stage-4-only first cut — see
> **[`iso-stage4-plan.md`](iso-stage4-plan.md)**. **This is the
> closed-beta MVP gate**: pre-built kernel + kybernet + agnoshi on a live
> image that boots to a shell on real iron. After the 2026-04-27
> boot-pipeline updates (sigil 2.9.4 cut, agnostik reverted, scripts
> pinned to Cyrius 5.7.21 — pin bump to 5.11.x queued). The plan has four
> open decisions (D1–D4) that need user input before coding begins. Next
> agent: **read the plan, then resolve D1–D4 with Robert.** MVP target:
> shell prompt on NUC AMD (primary) or Pi 4 inside ~3 weeks. Intel hosts (Skytech) queued after AMD is proven.
>
> 🟡 **Iron-boot attempts running log**: [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md) (active, post-MVP) + [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) (Attempts 1–68, capped 2026-05-19 at MVP gate). Append-only per-attempt log
> (symptom / root cause / repair / verification). Attempt 1 (2026-05-12) FAILED on the GRUB
> `grub_elf32_get_shnum` chain; root cause was Cyrius's `EMITELF_KERNEL`
> emitting `e_shoff=0` ELFs; repaired in Cyrius 5.11.29 (x86 kernel),
> 5.11.30 (aarch64 kernel), 5.11.31 (cyrld); USB refreshed via the new
> `install-usb.sh --update` mode. Attempt 2 pending.
>
> **May 1 V1 release** has passed. Per [`state.md`](state.md), kernel is at **1.29.0** (past the 1.22.x predicted in the original V1 line; +3 minor bumps since the 1.26.1 May-1 cut), Cyrius is at **v5.11.24** (cut day was 2026-05-11 — same-day **24-patch burst** from v5.11.0 to v5.11.24; v5.10.x closed at .50 with three completed arcs — typed-simd ABI, REAL TYPE SYSTEM, struct-byval ABI), and **v5.12.x** now holds the **AGNOS bare-metal target + RISC-V rv64 backend** (slipped v5.8 → v5.10 → v5.11 → v5.12). V1 status itself: verify against ISO/CI receipts before re-asserting in any public copy. Biweekly cadence through August DEF CON distribution (see [Near-Term Cadence](#near-term-cadence--may-1-v1-to-def-con)).
> **Kernel 1.29.0 active** — 26 syscalls invariant, structurally immune to CVE-2026-31431 (Copy Fail). v1.26.1 (2026-04-28, 248KB) shipped through three hardening passes from v1.22.0 (260KB); v1.27.x → v1.29.0 continued the cycle on the 5.10.44 pin. Patch-level detail in `agnos/CHANGELOG.md`.
> **Cyrius 5.7.0 shipped** (2026-04-25) — **THE SANDHI FOLD**. `lib/sandhi.cyr` adds (vendored byte-identical from sandhi v1.0.0, 376,037 B / 9,649 lines, 469 fns); `lib/http_server.cyr` deletes; sandhi repo enters maintenance mode per [ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md). Cyrius-side gates 1, 2, 3, 5, 6 ✅; gate 4 (downstream sweep) is separate user-organized work — only **vidya** actually `include`s `lib/http_server.cyr`; yantra and sit have orphan pre-fold copies (cleanup-only); the originally-listed `sit-remote`/`ark-remote` don't exist. v5.6.x closed at v5.6.45 on 2026-04-25 (45 patches — new longest-minor record). v5.6.0 opened the compiler-optimization arc on 2026-04-22 (**Phase O1** v5.6.0–v5.6.4 instrumentation + FNV-1a symbol hashing; **Phase O2** v5.6.11 partial strength reduction, flag-result reuse, push/pop elim, commutative + aarch64 combine-shuttle; **regalloc** v5.6.20–v5.6.24 default-on linear-scan; **closeout** v5.6.43 sigil 2.9.3 / sankoch 2.1.0 / output_buf 2MB).
> **Multi-platform closed.** x86_64 Linux byte-identical; aarch64 Linux byte-identical on real Pi (stdlib shakedown v5.5.18); Apple Silicon Mach-O self-host closed (v5.5.17); Windows PE32+ native self-host byte-identical on real Windows 11 (v5.5.10). NSS/PAM real-fix arc shipped v5.5.23–v5.5.27; `lib/fdlopen.cyr` landed in v5.5.x arc. **v5.7.x shipped** sandhi-fold (lib/sandhi.cyr) + cyrius-ts P1–P10 across 51 patches in 36 days. **v5.8.x shipped** (2026-05-01 → 2026-05-05, 66 patches in 4 days) as a 3-phase cycle: Phase 1 (slots 1-8) closed the v5.8.0 audit (lint/fmt cap, f64_log2 polyfill, sys_stat/fstat backfill, _SC_ARITY cross-arch gate, NI-class dupe, cc5_aarch64 packaging + cyrc_check orphan); Phase 2 (slots 9-26) handled language vocabulary (var X; diagnostic, fmt --check exit code, vidya audit at v5.8.40); Phase 3 (slots 27-65) was the **stdlib foldin sweep** (sandhi-pattern continuation, vani audio at slot 1). **v5.9.0 opened** (2026-05-06) with niyama fold-in (8th sibling distfile, 5 regex engines). **v5.9.x closed** at 5.9.43 (44 patches, 2026-05-06 → 2026-05-08, catchup + fixes — consumer rollup of pin-lag tail, optimization-debt audit O5/O6, dangling-item closeout). **v5.10.x closed** at 5.10.50 (50 patches in 5 days, 2026-05-06 → 2026-05-11): three completed arcs — **typed-simd ABI** (11 phases, value-form f64v2/f64v4 with parser-side `&IDENT → _ptr` overload routing, ABI-aware register routing; this is the substrate for future Cyrius-native codec work), **REAL TYPE SYSTEM** (5 phases, cstring/Result/Option/Tagged vocabulary + call-site type checking), **struct-byval ABI** (3 phases, cross-backend return surface). Plus 2.7× compile speedup miniarc (.40 + .41), TLS contract pin, PE premise debunk. **v5.11.0 cut 2026-05-11** — stdlib annotation arc + consumer-issue closeout cycle (kavach P1 sandbox syscall wrappers landed at .0; stdlib annotation Phase 1 queued for .1). **v5.12.x reserved**: AGNOS bare-metal target + RISC-V rv64 backend (both slipped from earlier cycles; v5.10.x typed-simd + REAL TYPE SYSTEM + struct-byval ABI form substrate prereq, v5.11.x stdlib annotation is the remaining prereq).
> **ISO pipeline started** — Stage 0 (component verification) implemented: `make iso-check`. See `docs/development/iso-pipeline.md`.
> **Kavach 3.0.0 shipped Cyrius-native** — 344KB (was 2.4MB Rust), 1 dep, 9 CWE fixes, sandbox lifecycle 500× faster.
> **Sankoch 2.0.0 shipped** — lossless compression (LZ4, DEFLATE, zlib, gzip). stdlib fold pending.
> **Abaco 2.1.0** — Miller-Rabin ~12× faster end-to-end via Cyrius hardware u64_mulmod fast-path.
> **Bote 2.5.1** / **T-Ron 2.0.0** shipped — both out of pre-release. Bote MCP pipeline ~5µs/message.
> **Ark 0.8.0** / **Nous 1.1.1** — package manager + resolver ported to Cyrius.
> **Phylax 1.0.0** / **Shakti 0.2.2** — threat detection + privilege escalation ported to Cyrius.
> **New shared crates (Apr 22–23)**: **owl** v0.1.0 (Cyrius-native `cat`/`bat` replacement, M0–M5 shipped) and **vyakarana** v0.1.0 (source-code grammar / tokenizer library — ten-kind palette locked; M1 agent started). owl M3b highlighting consumes vyakarana when M1 lands.
> **Critical path CLEARED**: libro ✅ argonaut ✅ kybernet ✅ kernel ✅ boot pipeline ✅ kavach ✅ ark ✅ nous ✅
> **Shared ecosystem**: 30+ repos ported to Cyrius. In port (partial, `rust-old/` still authoritative): takumi 0.8.0. Pending port: bhava, aethersafha. (aegis hit **1.0.0** in the v5.10.x window — out of pending.)
> **Next milestone**: **May 1 V1** — bootable ISO runs DOOM from Cyrius; kernel + toolchain + 30+ ports + science library shipped. Then biweekly cadence to DEF CON.

---

## Maturity Arc

AGNOS capability follows a **5-stage arc** that anchors what "the next stage" means at any cycle. Orthogonal to the [Strategic Vision](#strategic-vision) (release-milestone framing) and the [Phase 13A / 13C / 16 numbering](#critical-path-to-beta) (work-area framing) — the arc is the *capability lens* above both. User-defined 2026-05-22.

| Stage | Capability content | Status (2026-05-22) | Exit trigger |
|---|---|---|---|
| **demo** | Boots to shell on iron, ext4 read-only, networking client-side. Can be *shown* working but not lived in — no state persistence across reboots. | **Current.** MVP gate (Attempt 68 / 1.30.9 / 2026-05-15) was the demo entry; everything since has been demo-stage hardening (storage drivers Phase 2-5, ext2/4 read, GPT, USB MS, kybernet+agnoshi typeable, r8169 Phase 1-4). | 1.33.x ext4 WRITE landing. |
| **base** | Kernel solid; ext4 read+write; ark/nous package manager working end-to-end (resolve / fetch / install / remove); AGNOS-side update mechanism; enough soak surface for real-workload exposure without weekly showstoppers. | **Pending 1.33.x WRITE + ark/nous client maturation.** Triggers archaemenid dual-boot migration (AGNOS-primary on internal NVMe + Linux on SATA — see [`state.md`](state.md) § *archaemenid migration*). Functional-readiness trigger ≠ full base-stage exit; the stage matures over the subsequent ark/nous client cycles. | Native installer + server ecosystem landing. |
| **server** | **agnova native installer** (AGNOS installs itself onto target hardware; install-usb.sh host-side script retires); non-desktop subsystem suite (BBS, MUD, sovereign remote-shell, web server, ark+nous server-side) + the libs they consume. **Most of "Linux's purpose" gets absorbed at this stage** — archaemenid Linux usage is predominantly server-flavored (build hosting, file serving, CLI dev, network services), so server-stage AGNOS replaces it without needing GUI work. Archaemenid Linux eviction lands at **server**, not "swallow." | **Not started.** 1.32.x server-side TCP primitives (bite A) are the kernel foundation. | aethersafha + GUI userland landing. |
| **desktop** | aethersafha (Wayland compositor — currently Pending in CLAUDE.md table) + display drivers (mabda + iGPU/dGPU) + user-facing app ports + GUI userland. Absorbs the daily-driver / GUI / browser workloads that server stage couldn't. | **Not started.** | Compat sandbox + non-native-workload absorption. |
| **swallow** | **Compat sandbox layer** — AGNOS hosts non-AGNOS-native apps (Windows binaries, Linux binaries, web apps) inside a sovereign sandbox so endusers can move to AGNOS without giving up their existing app ecosystem. Connects directly to **Phase 20 — Cross-Platform Compat Subsystem** below. Sovereignty via **universal hosting**, not eviction — AGNOS becomes the host that can run anything, removing the last reason anyone would keep a separate non-AGNOS install. | **End-state.** No fixed date; trigger is final-workload capability parity. | (Terminal — no exit.) |

**The arc is sequential.** Don't skip stages: desktop work doesn't open before server lands; swallow doesn't open before desktop lands. Stage exits map loosely to release milestones — demo→base ≈ MVP entry maturation, base→server ≈ Public Beta, server→desktop ≈ v1.0, desktop→swallow ≈ post-v1.0 horizon.

**Distributed swallowing.** The "swallow" eviction events are distributed *across* stages 3-4-5 based on each workload's nature: server stage absorbs most Linux workloads (native replacements); desktop stage absorbs daily-driver / GUI workloads (native GUI apps via aethersafha); swallow stage absorbs the long-tail niche workloads via compat sandbox (no per-app native port needed). This is why "swallow" is small as a capability-construction stage despite being the terminal stage — most work is already done by stages 3+4.

---

## Strategic Vision

AGNOS becomes a real operating system in three stages — **rubber-hits-the-road, then independence, then completeness.**

1. **MVP — Boot to Shell on Hardware** (Closed Beta) — AGNOS kernel + kybernet (PID 1) + agnoshi (shell) + sovereign boot pipeline reach a shell prompt on real iron. Pre-built binaries; self-hosting NOT required. This is the line where AGNOS stops being a slide deck and starts being a thing that runs.

2. **OS Independence** (Public Beta) — AGNOS rebuilds itself without a host distro. Self-hosting LFS-style base, takumi recipes for the full stack, ark as sole package manager. Adds "and it can grow itself" to the MVP.

3. **Desktop Completeness** (v1.0+) — Ship a complete desktop experience by packaging existing open-source tools first, then progressively replace with AI-native alternatives where the AI is the primary value.

**Priority order**: boot to shell on iron → self-hosting → desktop essentials → AI-native apps. Desktop ambitions do not gate the MVP; the MVP is what proves the kernel + init + shell stack is real on hardware.

**The agnostic + empire-defense commitments** (running in parallel after public beta, not gating MVP): AGNOS protects users from the empire by giving them **exit options without total disconnection** — parallel infrastructure that doesn't pay the empire's rent, plus sandboxed bridges for the moments where empire services are genuinely needed. Five parallel-infrastructure / bounded-coupling commitments:

- **Phase 20 — Cross-Platform Compat Subsystem** ([spec](planning/cross-platform-compat-subsystem.md)): foreign-platform work runs transparently via a kavach-sandboxed Linux personality container. Kernel grows organically per native workload; the interpretive layer stays permanently separate.
- **Phase 21 — DPI Resistance** ([spec](planning/dpi-resistance.md)): the AGNOS network stack normalizes traffic to mainstream-browser fingerprints by default. The empire cannot selectively act against AGNOS-on-the-wire without acting against Chrome-on-Windows users at scale.
- **Phase 22 — Parallel PKI** ([spec](planning/parallel-pki.md)): trust root anchored in physical artifacts (bumper sticker / SD card / paper QR). Commercial CAs serve as opportunistic bridges, never as the load-bearing trust. The empire cannot revoke a sticker.
- **Phase 23 — Foundation Structure** ([spec](planning/foundation-structure.md)): multi-jurisdictional, mission-locked, contributor-protecting governance layer that holds project assets in a way no single state actor or commercial entity can coerce. The meta-defense — without it, all the technical sovereignty is undone in a courtroom.
- **Phase 24 — Identity & Authorization Model** ([spec](planning/identity-and-authorization-model.md)): recognition over interrogation; authorization > authentication. AGNOS rejects the Unix-login-by-default + federated-IDP empire pattern in favor of a layered model (theft / presence / identity / capability) with pluggable mechanisms per layer. The user owns the device; sensitive operations are gated by capability-per-action, not by session-grants-all-powers.

Native ports + native sovereignty remain the preferred path. The five phases above are the compat bridges, the wire-layer cover, the parallel trust root, the legal substrate, and the user-boundary security posture that make sovereignty actually defensible against an adversary-class threat model. **The boundary between the kernel and the interpretive layers is permanent** — the kernel never absorbs foreign ABIs, the trust root never depends on commercial PKI, the Foundation never sits in a single coercible jurisdiction, authentication never grants authorization.

---

## Critical Path to Beta

```
Cyrius ports (agnostik → agnosys → libro → argonaut → kybernet)
  ↓
kybernet folds into AGNOS kernel as PID 1
  ↓
Phase 13A items 1–3 (boot → shell on hardware) ──→ CLOSED BETA (MVP)
                                                       ↓
                                  Phase 13A items 4–7 (self-hosting) ──→ PUBLIC BETA
                                                       ↓
                                  Phase 13C (community) + Phase 16 (desktop) ──→ v1.0
```

### Closed Beta — Selective Summer 2026 Program

**MVP scope: AGNOS boots to a shell prompt on real hardware.** That's the *entry* line. Closed beta is not a single cut date — it's a **selective rolling program through summer 2026**, opening with the first hardware boot (achieved 2026-05-15) and running through the summer with a growing-but-curated cohort. Self-hosting, package builds from source, and full userland validation against the AGNOS kernel ABI are NOT required for closed beta — they're Public Beta concerns.

**Opening gate** (target early June 2026):
- [x] **Boot-to-Shell MVP (13A items 1–3.5)** — ✅ Iron-validated 2026-05-15 on archaemenid (NUC AMD Beelink SER). Kernel completes full init spine → kybernet (PID 1) launches → agnoshi (`AGNOS shell v1.30.0`) prompt rendered on framebuffer. Twenty-nine attempts across three weeks of bring-up; full arc in [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md); generic process pattern in [`iron-bring-up-process.md`](iron-bring-up-process.md). **The shell prompt is visible. The base OS is real.**
- [ ] **USB-keyboard input** — shell prompt visible but typing produces no echo (modern UEFI doesn't emulate PS/2 over XHCI post-`ExitBootServices`). Native XHCI + USB-HID-boot driver scoped at [`../archive/usb-hid-keyboard-driver-shipped.md`](../archive/usb-hid-keyboard-driver-shipped.md) (5 phases, ~1.2–2.1k Cyrius LOC). **All 5 phases landed across agnos 1.30.0 → 1.30.5** (Phase 1-3 iron-validated through Attempt 52; Phase 4-5 compile-verified in 1.30.5). **2026-05-17 — silent-absorb root cause identified**: a one-line bug in `xhci_portsc_write` (double-applying `XHCI_PORTSC_NEUTRAL` mask, silently stripping the PR bit on every write). 13 hypotheses falsified across Attempts 32-54 were all chasing AMD silicon ghosts — bug was AGNOS's own helper. Surfaced via prior-art diff (EDK2 XhciDxe + Linux xhci-hub.c + coreboot Cezanne + AMD openSIL convergence). One-line fix queued; expected to unblock Phase 4/5 + every downstream USB device class (mouse, mass storage). Full resolution plan + pre-bound outcome matrix in [`../archive/usb-hid-keyboard-driver-shipped.md § Silent-Absorb Resolution Plan`](../archive/usb-hid-keyboard-driver-shipped.md#silent-absorb-resolution-plan-2026-05-17). MVP-gate cleared at Attempt 68 (2026-05-18, agnos 1.30.9).
- [ ] First hardware boot session on AMD NUC (matrix row 14) or Pi 4 (row 3) — **non-founder tester sits at the prompt**. Now hardware-ready; awaits keyboard input + tester schedule.

**Through summer 2026** (closed-beta program proper):
- [ ] Initial cohort: friend-network, 5–15 testers, sitting at a shell on iron
- [ ] Selective expansion: invites only, no public enrollment, no marketing campaign
- [ ] Cohort feedback drives hardening: bug reports, hardware-matrix gap-fill, kybernet/argonaut/agnoshi P1 issue closeout
- [ ] **DEF CON August 2026** (contingent — see cadence table): if Phase 22 paper-PKI ships in time, this becomes the *credible public introduction event during closed beta* — stickers as cryptographic root distribution, not as marketing. Aug 2027 baseline if not ready.

**Closeout** (early fall 2026):
- [ ] Cohort report consolidated; critical-bug list cleared
- [ ] Hardware matrix coverage: at least 3 different architectures booted (x86_64 NUC, aarch64 Pi 4, plus one more — Skytech or laptop)
- [ ] Public beta criteria met (or explicitly carried as known-gap)

**Gate philosophy**: closed beta is the honest "the kernel + init + shell stack runs on real iron, and humans other than the founder have sat at the prompt over a sustained selective program" milestone. Self-hosting, audit, and broad community testing are deliberately deferred to public beta — a cleaner, smaller line that ships when ready. The MVP entry proves the *base* OS is real; the summer-long program proves it's *durable* across diverse hardware and use; sovereignty of the rest of the userland against the AGNOS-kernel ABI is the next milestone.

**Cadence dependency**: opening gate is **toolchain-independent** — the kernel already builds and boots against the current Cyrius (5.10.44 pin). The dependency reduces to *agnosticos-side work* (install.cyr Stage-4 cut + first hardware boot session). The earlier framing that gated MVP on Cyrius v5.12.x bare-metal target was conceptual residue from pre-monolith-extraction days; corrected 2026-05-12. Opening slips by week, not by month. **The summer-long program then runs independently of Cyrius cycles** — it's hardware-and-cohort-paced, not toolchain-paced. Cyrius work continues in parallel (v5.11.x stdlib annotation arc active; v5.12.x bare-metal formalization queued) but does not gate the MVP ship.

### Public Beta — Q4 2026

- [ ] Closed beta exited cleanly (cohort report + critical-bug closeout)
- [ ] Third-party security audit complete
- [ ] Community testing program active (formal enrollment)

### v1.0 — Q2 2027

- [ ] Phase 13C complete — Documentation, community
- [ ] Phase 16 complete — Full desktop experience
- [ ] All consumer apps published to mela
- [ ] 6 months of beta testing with no critical bugs

Long-term vision: [`vision/conscious-objects.md`](vision/conscious-objects.md) — the quantum-substrate / Layer-0 horizon (post-v3.0, multi-year). Foundation governance is now [`planning/foundation-structure.md`](planning/foundation-structure.md) (promoted from vision → planning 2026-05-12). v2.0 Rust-kernel and v3.0 Cyrius-pivot vision sections were retired 2026-05-12 — both happened ahead of schedule (Cyrius kernel shipped 2026-04-04; Cyrius language at v5.11.24 already).
Creator economy (sovereign distribution, bootable USB media): [`vision/creator-economy.md`](vision/creator-economy.md)
Knowledge-completeness mapping (42 confessions of Ma'at ↔ AGNOS crates): [`vision/maat-42.md`](vision/maat-42.md)

---

## Cadence — V1 to Public Beta (Fall 2026 arc)

**Rescope (2026-05-12)**: the original biweekly May 1 → August 2026 cadence was written from the rust/linux-era mindset and was hopeful-not-realistic. With the boot-to-shell MVP recast and the actual schedule — **closed beta = selective summer 2026 program**, **public beta = Q4 2026**, **cadence beats = fall 2026** — the realistic timeline lands the cadence work *after* the summer-long closed-beta program has produced hardening receipts. The beats ride on top of a real, multi-machine-tested MVP rather than racing parallel to one.

Each beat is still a release, not a blog post. The beats are the right work; the dates moved to honest planning windows. **Fall 2026 is the planning target. Summer acceleration past that remains the stretch case if Cyrius cycles continue at the 3–5 day cadence, the MVP ships on the closed-beta opening, and the summer program reaches the right hardening density faster than expected.**

| Target window | Beat | Primary repos |
|---|---|---|
| **May 1 2026** *(shipped, partial — historical)* | V1: Boots, runs DOOM, all Cyrius. ISO Stage 0+ cut; kernel 1.26.1 (predicted 1.22.x — shipped ahead) + Cyrius toolchain + 30+ ports + science library. ISO Stage-4 cut + first hardware boot remain — the actual MVP gate. | `agnos`, `cyrius`, `agnosticos` |
| **Fall 2026** | **Library for Humanity.** Reference library + knowledge corpus (vidya + abaco + 27-crate science tier) shipped as a browseable first release. | `vidya`, `abaco`, science tier |
| ~~Fall 2026~~ **Already shipped (v5.5.x)** | **Multi-platform byte-identical.** x86_64 Linux byte-identical (Cyrius core); aarch64 Linux byte-identical on real Pi (v5.5.18 stdlib shakedown); Apple Silicon Mach-O self-host (v5.5.17); Windows PE32+ native self-host (v5.5.10). **No future work required** — beat retained as a public-announcement event if marketing wants it; otherwise this row can be retired from the cadence. | `cyrius` |
| **Fall 2026** | **Self-hosting in action.** Cyrius compiles itself from tarball on a booted AGNOS ISO, end-to-end. **This is the public-beta technical milestone**, not a separate beat. | `cyrius`, `agnos`, `agnosticos` |
| **Fall 2026 (winter solstice 2026-12-21)** | **Solstice: higher-order items.** TBD gift — agent-tooling article + capstone receipts. (Date shifted from summer to winter solstice given the fall rescope.) | `agnosticos/docs/articles` |
| **Fall 2026** | **Distribution at scale.** Ark OTA pipeline live; recipes buildable from zugot by third parties. | `ark`, `nous`, `zugot` |
| **Fall 2026** | **Reproducibility standard.** Every artifact in the stack has an SHA manifest; seed + hash chain published. *Aligns with Phase 22 parallel-PKI work — same hash-chain infrastructure.* | `sigil`, `libro`, `agnosticos` |
| **August 2026** *(contingent)* or **August 2027** *(baseline)* | **DEF CON / Black Hat distribution.** ~$5K budget: 10K stickers + 500 SD cards + 1K quick-start cards. **Bumper-sticker-as-cryptographic-root-of-trust** — QR-encoded 29KB seed + SHA-256 chain + URL = paper signing authority. **Critical dependency**: [`Phase 22 paper-PKI verification path`](planning/parallel-pki.md) must ship before the print run is meaningful. Aug 2026 if it lands; Aug 2027 if not. | `agnosticos` |

**Cadence discipline (revised)**: dates are *target windows*, not strict biweekly slots. Each beat ships running software when ready. If a beat misses its target window, it goes to "next window" — not "next biweekly." The list tightens (drop beats that become irrelevant) and the windows move, but the *beats themselves* are the right work and stay on the roadmap until shipped or explicitly retired.

**Not in the cadence** (deliberately): Beta, v1.0, SY redesign, Phase 17–19 work, **Phase 20–23 empire-defense planning work** (each has its own spec, see [Strategic Vision](#strategic-vision)). Those remain on the Beta Q4 2026 / v1.0 Q2 2027 / post-public-beta track above. (Polymorphic codegen previously listed here; slotted to Cyrius v5.13.x as of 2026-04-25 — see `cyrius/docs/development/roadmap.md`.)

**Honesty note**: the rust/linux-era cadence assumed the project would be near-shipping in May-August 2026. The cyrius/agnos-era reality is that the MVP (boot-to-shell on iron) is what closed-beta gates on, and the cadence beats above are *public-beta-era ship work* — they ride on top of a working MVP, not in parallel with one. The fall 2026 anchor is what reflects that sequencing honestly.

---

## Status

### Cyrius Language — v5.11.0 (cut 2026-05-11)

Full milestone history lives in `cyrius/CLAUDE.md` + `cyrius/CHANGELOG.md`. Live cycle status in [`state.md`](state.md). Headline status for AGNOS:

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
| Linear-scan register allocator | **Done** — v5.6.20–v5.6.24 default-on |
| Fused ops (madd, msub, ubfx, sbfx) | **Done** — v5.6.x post-regalloc |
| Phase O3a IR instrumentation | **Done** — v5.6.12 (referenced as pre-existing through v5.8.x) |
| Phase O4a/b/c regalloc — Poletto-Sarkar linear-scan picker | **Done** — v5.8.x (O4b explicit) |
| Phase O5 / O6 (NOP harvest with jump+fixup, codebuf compaction) | **Done** — O5/O6 audit closed in v5.9.x |
| v5.10.x — typed-simd ABI (11 phases), REAL TYPE SYSTEM (5 phases), struct-byval ABI (3 phases) | **Done** (v5.10.x closed 2026-05-11 at 5.10.50) |
| v5.11.x — stdlib annotation arc + consumer-issue closeout (kavach P1 sandbox syscall wrappers landed v5.11.0) | **Active** (opened 2026-05-11) |
| RISC-V rv64 codegen | Queued — **v5.12.x** (slipped 7+ from v5.7.0) |
| Bare-metal / AGNOS kernel target | Queued — **v5.12.x** (slip path v5.8.0 → v5.10.x → v5.11.x → v5.12.x; v5.10.x typed-simd + REAL TYPE SYSTEM + struct-byval ABI form substrate prereq, v5.11.x stdlib annotation is the remaining prereq) |

### Cyrius Ports — Dependency Chain to Boot

| Crate | Rust → Cyrius | Status | Notes |
|-------|--------------|--------|-------|
| agnostik | 0.90.0 → 0.97.1 | **Done** | Shared types |
| agnosys | 0.51.0 → 1.2.6 | **Done** | Syscall wrappers (59× smaller) |
| sigil | 1.0.0 → 3.1.1 | **Done** | Crypto boundary |
| shravan | 1.1.0 → 2.3.2 | **Done** | Audio codecs |
| libro | 0.92.0 → 2.6.3 | **Done** | Audit chain |
| argonaut | 0.90.0 → 1.7.0 | **Done** | Init system library — BOOT_MINIMAL agnoshi added 2026-05-11 |
| kybernet | 0.51.0 → 1.2.1 | **Done** | PID 1 (14× smaller, 486KB at 1.0; now ~1.15MB at 1.2.1 with edge_boot profile) |
| AGNOS kernel | — → 1.29.0 | **Done** | 248KB at 1.26.1; current pin 5.10.44; 33 subsystems, 26 syscalls, Cyrius-native |
| hoosh | 1.2.0 → 2.0.0 | **Done** | LLM gateway (10.8× smaller) — pre-CYML format still |
| ai-hwaccel | 1.0.0 → 2.2.2 | **Done** | GPU detection (3.3× smaller) |
| avatara | 1.0.1 → 2.3.0 | **Done** | Archetype overlay (2,761× faster cached) — remote-only |
| kavach | 2.0.0 → 3.2.1 | **Done** | Sandbox (500× faster lifecycle) |
| abaco | — → 2.2.0 | **Done** | Math/number theory (-52% lines, 12× Miller-Rabin) |
| bote | 0.92.0 → 2.7.2 | **Done** | MCP core (~5µs/message) |
| t-ron | 0.90.0 → 2.1.4 | **Done** | MCP security |
| daimon | 0.6.0 → 1.2.3 | **Done** | Agent orchestrator |
| agnoshi | 0.90.0 → 1.3.2 | **Done** | AI shell |
| itihas | 1.0.1 → 2.2.0 | **Done** | History/versioning — remote-only |
| hadara | — → 1.0.0 | **Native** | Culture modeling (Cyrius-native) |
| mabda | 1.0.0 → 3.0.0-rc.2 | **Done** | GPU foundation — soaking pre-GA stdlib fold |
| sankoch | — → 2.2.5 | **Done** | Lossless compression (LZ4, DEFLATE, zlib, gzip) |
| ark | — → 0.8.0 | **Done** | Package manager (4× smaller, 40× faster) — still on 5.1.10 pin (extreme lag) |
| nous | — → 1.1.2 | **Done** | Package resolver |
| phylax | — → 1.1.1 | **Done** | Threat detection — exited 5.7.48 held cluster |
| shakti | — → 0.3.0 | **Done** | Privilege escalation |
| hisab | — → 2.2.2 | **Done** | Higher math |
| bhava | — → 2.0.0 | Pending | Emotion/sentiment (has Cargo.toml) |
| takumi | 0.8.0 → 0.8.x | **In port** | Package build system — Cyrius port active, pinned 5.5.23, `rust-old/` authoritative until parity |
| aegis | — → 1.0.0 | **Done** | System security daemon — hit v1.0 in v5.10.x window |
| aethersafha | — → 0.1.0 | Pending | Wayland compositor |

### Monolith Extraction — Complete

Full details: [sprint-history.md](sprint-history.md#monolith-extraction--complete-2026-04-01-to-2026-04-07)

### Open KPIs

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Boot Time | <10s | **3.2s** (kernel+init), **~80ms** init→event loop | **Achieved** |
| Boot-to-Shell on Hardware (MVP) | Yes | Pending | Phase 13A items 1–3 — kernel + kybernet + agnoshi on iron; Stage-4 ISO is the gate |
| OS Independence (full self-hosting) | Yes | Pending | Phase 13A items 4–7 — explicitly post-MVP, Public Beta scope |
| DOOM | Playable | **2.59ms/frame**, cyrius-doom 0.26.1, hardened (5 CVEs fixed) | **Unblocked** — Cyrius Phase O2 closed v5.6.11; regalloc v5.6.13 in flight. Full-frame benchmark re-run pending v5.6.x closeout. |

---

## Active Work

### Phase 13A — Boot-to-Shell MVP + OS Independence (BETA BLOCKER)

**Two scopes in one phase.** The MVP (items 1–3 + 8) is the closed-beta line. The self-hosting block (items 4–7) is public-beta scope and is explicitly *post-MVP*.

**MVP ship test** — when this passes, closed beta cuts:
> Boot the Stage-4 ISO on the NUC AMD (primary), the Pi 4, or any matrix-row machine that has been validated. The kernel comes up. kybernet runs as PID 1. agnoshi prints a prompt. A tester other than the founder sits at that prompt.

That's it. No package builds, no recipe sweeps, no self-host loop. Those come after.

**Previous blocker (CLEARED)**: kybernet Cyrius port. Dependency chain completed 2026-04-13: libro ✅ → argonaut ✅ → kybernet 1.0.1 ✅ → kernel 1.22.0 (later hardened to 1.26.1, 248KB; now at 1.29.0) ✅ → boot pipeline (Cyrius, ~67KB → 81KB rebuilt against 5.10.44 on 2026-05-11) ✅.

**Current MVP work**: Sovereign boot pipeline active. Kernel boots in QEMU via `make boot-test`. ISO Stage-4 cut + first hardware boot session remain.

| # | Item | Scope | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Kernel boots in QEMU | **MVP** | **Done** | boot.cyr (~81KB Cyrius binary, rebuilt against **5.10.44** on 2026-05-11), kernel **1.29.0** (was 1.26.1 at 248KB; current cycle on 5.10.44 pin) |
| 2 | Sovereign boot pipeline | **MVP** | **Done** | `make boot-test` from genesis repo |
| 2.5 | ISO `--iso-check` (Stage 0 component verification) | **MVP** | **Done** | 26-of-26 components READY (2026-04-27 audit), ISO assembly unblocked |
| **3** | **ISO Stage-4-only first cut (live image, pre-built binaries)** | **MVP** | **🔴 NEXT** — planned, awaiting D1–D4 | See [`iso-stage4-plan.md`](iso-stage4-plan.md). Days, not weeks. Was the MVP gate; now the **distribution** path (kernel boots iron-direct via gnoboot + USB stick today). |
| **3.5** | **First hardware boot session — kernel + kybernet + agnoshi shell prompt** | **MVP** | ✅ **Iron-validated 2026-05-15** | NUC AMD (archaemenid / Beelink SER, matrix row 14) — Attempt 28 hit MVP boot spine alive on iron; Attempt 29 + cleanup-pass burn at 16:45 PDT rendered shell prompt + full kernel log on framebuffer. Pi 4 (row 3, aarch64 secondary) pending USB-keyboard-input closure. Skytech Legacy 4 (row 12, Intel) queued post-AMD-proof. See [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md). |
| **3.6** | **USB-keyboard input on modern UEFI** (no SMM PS/2 emulation post-EBS) | **MVP** | 🟡 In flight (1.30.1) | Native XHCI + USB-HID-boot driver, 5 phases scoped at [`../archive/usb-hid-keyboard-driver-shipped.md`](../archive/usb-hid-keyboard-driver-shipped.md). **Phase 1 code landed in `agnos` [Unreleased] 2026-05-15** (PCIe discovery + capability reads; report-only, does not enable typing yet). **Awaiting Attempt 30 iron burn** — verification gate, expected `xhci:` framebuffer lines, CMOS `kcp=0x30`, and failure-mode triage captured in [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) § *Attempt 30 prep*. Phases 2–5: controller init / port enum / HID boot protocol / interrupt-driven kb_buf feed. Closes the "typeable" half of "boot-to-typeable-shell." |
| 8 | CI automation | **MVP-adjacent** | In progress | GitHub Actions workflows — supports MVP and beyond |
| 4 | LFS Stage 1: bootstrap-toolchain.sh end-to-end | **Post-MVP** (Public Beta) | Deferred | Build cross-compiler from source tarballs. Not in MVP scope — pre-built binaries ship in the Stage-4 ISO. |
| 5 | LFS Stage 2: build base system in chroot | **Post-MVP** (Public Beta) | Deferred | ark-build all 109 base recipes. Public Beta = self-hosting story. |
| 6 | LFS Stage 3: build AGNOS userland on target | **Post-MVP** (Public Beta) | Deferred | Cyrius-compiled binaries inside AGNOS. Also where userland ↔ AGNOS-kernel ABI bridge gets exercised end-to-end. |
| 7 | Selfhost-validate passes all phases | **Post-MVP** (Public Beta) | Deferred | Run `selfhost-validate --phase all` on booted ISO |

**MVP target**: Closed beta opening gate, **early June 2026** (~3 weeks from 2026-05-11). Gated on:
- (a) **ISO Stage-4 D1–D4 resolved + Stage-4 ISO cut** — our work, install.cyr in agnosticos/scripts/
- (b) **First hardware boot session** — kernel + kybernet + agnoshi reaching a shell on real iron (Pi 4 or AMD NUC)
- (c) **Non-founder tester** sits at the prompt

**NOT a gate**: Cyrius v5.12.x bare-metal target. Earlier framing carried this as a dependency — that was conceptual residue from when Cyrius and agnos lived in the same repo (pre-2026-04-01 monolith extraction). The kernel already boots end-to-end in QEMU as a multiboot1 ELF — bare-metal compilation works *now*, via ad-hoc bare-metal mode in agnos. v5.12.x formalizes the toolchain side (ELF no-libc target format, interrupt-handler emit conventions, kernel-mode syscall stubs stripped) — useful for cleaner future kernel work, but **not required for the MVP to ship**. Language and kernel are separately-releasable subsystems; coupling MVP to a language-side cleanup is the residue-pattern of when they were one project.

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
| S1 | High | CVE-2026-31431 (Copy Fail) — host kernel cleanup + cross-repo audit | AF_ALG `algif_aead` + `splice()` LPE in mainline Linux 2017→. AGNOS-native kernel **structurally immune** (no socket/splice surface; verified against 26-syscall table invariant — anchored on table size, not patch level. Current: `agnos` v1.29.0). Local repos clean: sigil, agnosys, phylax — no AF_ALG refs. **Do**: (a) host bootstrap defconfigs in `agnosticos/kernel/{6.6-lts,6.x-stable,7.0-devel,configs}` — pin `# CONFIG_CRYPTO_USER_API* is not set` (HASH/SKCIPHER/AEAD/RNG); (b) audit when cloned: kybernet, libro, kavach, shakti, aegis, t-ron, argonaut, ark, agnostik, bote, daimon, hoosh. Live tracking in [`state.md`](state.md#cve-2026-31431-copy-fail-cleanup--audit). |
| R2 | High | Update scripts/CI for zugot | 16 scripts/CI/config files still reference local `recipes/` paths |
| E1 | Medium | ESP32 agent source repo | Recipe done, MQTT bridge done. Pending: source repo + firmware |
| V1 | Stretch | t-ron voice — contract Bruce Boxleitner | Direct voice-synthesis contract with the actor *infamous* for the role; permanently hardens t-ron's character identity to its namesake. **The play — the argument is the asset**: AGNOS ships a Tron that actually *exists* — t-ron is a living, executing MCP security monitor that demonstrably fights for users in the real tool layer. Disney's Tron is fiction; t-ron is shipped software. The substantive argument that move makes in public: *"the real version of this is now working software, not a 1982 film."* That argument is the asset — it lands the moment the cultural shift starts, and Disney litigating against it is them defending fiction against a working artifact (i.e. losing the argument). Disney's natural incentive then flips to **alignment** ("Tron is real"), not litigation. Boxleitner's voice/likeness is licensed directly (his to grant). Any litigation pressure is downstream noise, not the substance of the move. **Core idiom** — *"We fight for the users"* is t-ron's operating ethic, the line *made real*: it ties directly to the subsystem's job (MCP security monitor — protect the user from bad actors in the tool layer). **Capture corpus**: the core idiom is the non-negotiable seed; targeted phrase-set captured for inference seeding; everything else naturally generated by the model, no script-reading sessions. Iterative — once natural cadence locks, additional phrases / word recitations can be captured to refine the synthesis. **Reach goal**: Boxleitner's sign-off and active participation — the actor publicly endorsing the subsystem named in his role's honor, on par with the back-pocket-ally tier. **Sequencing**: post-V1, after first-tier ally relationships land. Outreach rides the public AGNOS news cycle (booted OS + DEF CON receipts + articles in circulation) so the conversation isn't cold — momentum opens the door. Budget + outreach path TBD. |

Repo-specific backlog items tracked in their respective repos.

---

## Post-MVP — Closed-Beta Hardening Queue (1.30.x cycle)

> **MVP iron-validated 2026-05-15.** The kernel boots to a shell prompt on real hardware. This section is the work *after* that line — making the prompt typeable, then hardening the cohort surface, then opening the path to OS Independence (Public Beta). Not a hypothetical roadmap — concrete next-cycle items the kernel and ecosystem need before the first non-founder tester sits at the prompt.

### 1.30.0 → 1.30.5 — Keyboard input (code complete, iron-gated)

Native XHCI + USB-HID-boot driver in `agnos/kernel/arch/x86_64/usb/`. Modern UEFI firmware does not emulate PS/2 over XHCI post-`ExitBootServices`; the legacy port 0x60 path is silent. Native bus + class driver is the real-answer fallback. Scoped: [`../archive/usb-hid-keyboard-driver-shipped.md`](../archive/usb-hid-keyboard-driver-shipped.md). **All 5 phases landed across 1.30.0 → 1.30.5**; the cycle-arc framing (one section per minor) has been collapsed to one section since the gate-to-ship variable is now iron-side, not code-side.

| Phase | Scope | LOC | Status |
|---|---|---|---|
| 1 | PCIe discovery + capability reads (`xhci_probe`, MMIO map, `MaxSlots`/`MaxIntrs`/`MaxPorts`/`CSZ`/`DBOFF`/`RTSOFF` cache) | ~250 | ✅ Landed + iron-validated. kcp=0x30. |
| 2 | Controller init (halt + reset + DCBAA + cmd ring + event ring + ERST + start) | ~450 | ✅ Landed + iron-validated. kcp=0x31. |
| 2.5 | USBLEGSUP BIOS hand-off + USBLEGCTLSTS SMI-disable | ~55 | ✅ Landed + iron-validated. Renoir reports `already OS-owned`. |
| 3 | Port enum + device address (Enable Slot + Address Device + Get Descriptor + HID predicate) | ~600 | ⚠️ **Code landed**; iron-blocked by silent-absorb arc on AMD FCH 1022:1639 (12 hypotheses falsified across Attempts 32-52; arc closed as "non-spec gate, parallel-track only" per the Attempt 52 decoupling decision). Phase 3 enumerates cleanly on QEMU xhci-pci. kcp=0x32 stamps on QEMU. |
| 4 | HID boot protocol + interrupt endpoint (Configure Endpoint + Set Protocol = boot + transfer ring) | ~320 | ✅ Landed in agnos 1.30.5 (2026-05-17); compile-verified. kcp=0x33 stamps inside `hid_kbd_configure` on success. **Dormant on archaemenid** (no slot addressed → not called); QEMU is the active validation surface. |
| 5 | Poll-driven `kb_buf` feed (HID usage → PS/2 set-1 scancode + modifier translation + report differ + event-ring drain) | ~280 | ✅ Landed in agnos 1.30.5 (2026-05-17); compile-verified. `kb_has_key()` calls `hid_poll()` so the existing `scancode_to_ascii` consumer path lights up unchanged. **Dormant on archaemenid** (same root cause as Phase 4). **This is the phase that closes the "typeable" gate.** |

**Typeable-shell-on-iron ships when**: the archaemenid silent-absorb arc unblocks (or another iron target proves out — Skytech Intel / a Pi 4 / different AMD silicon — see [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) § Attempt 54 prep + carry-forward). The CODE is complete and QEMU-testable today; the IRON path is gated on a Phase 3 enumeration unblock, not on more Phase 4/5 work.

**Iron-burn cadence**: per `feedback_iron_burns_block_other_work`, burns are bundled with other "ready-to-ship" work to amortize single-machine disruption. **Next burn (Attempt 54) is externally gated on kriya 0.3.0 (M2 file operations) ship** — see [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) § Attempt 54 prep for the pre-bound outcome matrix and protocol.

### 1.31.x — Storage device backends (active, NVMe arc closed 2026-05-20)

User-directed scope pivot 2026-05-20: 1.31.x is the **storage devices** cycle. Networking moved out to 1.32.x (next cycle). NVMe was the first and most-needed backend (archaemenid has NVMe; every modern x86 host has NVMe); landing it first unblocks every real-iron storage path that doesn't require a USB stick.

**1.31.0** — cycle-open cut (2026-05-20). Lean-by-default build via `KTEST` + `XHCI_VERBOSE` compile gates, FB-absent guard, stale Attempt-N prose cleanup, new `agnos/docs/development/build.md`. No storage engineering — just the production-default-lean posture that makes subsequent storage cuts easier to validate. **Test 1.31.0 as the base; fixes for it go in 1.31.x patches.**

**1.31.1 (queued — NVMe arc)** — five phases sitting in `[Unreleased]` 2026-05-20, ready to cut as a single tagged release:
- Phase 1: PCI class probe + BAR0 UC-remap + CAP/VS decode + controller disable
- Phase 2: admin queue + IDENTIFY CONTROLLER + IDENTIFY NAMESPACE
- Phase 3: Create I/O CQ + Create I/O SQ + blocking Read
- Phase 4: Write + multi-LBA + PRP1 / PRP2 / PRP-list dispatch
- Phase 5: `kernel/core/block.cyr` tag-dispatch abstraction (virtio-blk + nvme behind one `blk_*` API; NVMe overrides virtio when both present)
- ~940 LOC across `kernel/core/nvme.cyr` + new `kernel/core/block.cyr`
- QEMU end-to-end validated with byte-exact disk persistence (`CYRIUS!!` pattern round-trips through MMIO + DMA + I/O CQ)
- MSI-X true-IRQ-driven completion **deferred** — xhci precedent (enable in PCI config, poll on timer ticks) covers correctness; real vector dispatch is a cross-driver framework slot, not an NVMe-only blocker

**1.31.x — storage device backends (status after 1.31.1 cut)**

Each backend gets its own patch cycle. Block-layer dispatch abstraction landed in NVMe Phase 5 means each new backend just registers itself via `blk_register_*(capacity, lba_bytes)` and implements the three wrapper functions (`*_blk_read` / `*_blk_write` / `*_blk_read_sectors`). The branch-arm-count discipline from CLAUDE.md applies — reach for fn-ptr dispatch only when the branches start to repeat meaningfully.

| Patch slot | Backend | Status | Scope estimate |
|---|---|---|---|
| **1.31.0** | NVMe Phase 1-5 + block-layer dispatch | ✅ shipped 2026-05-20 (iron debut Attempt 80 — Crucial P3 2 TB) | ~940 LOC |
| **1.31.1** | **AHCI / SATA Phase 1-4 + GPT Phase 1-3** | ✅ shipped 2026-05-20 (iron debut Attempt 81 — WD Blue SA510 2 TB; PASS-WITH-CAVEAT — post-RW IDENTIFY hang; three carry-forward patches landed in 1.31.2 `[Unreleased]`) | ~1,970 LOC (AHCI ~1,100 + GPT ~870) |
| **1.31.2** | **AHCI carry-forward (3 patches) + USB Mass Storage Phase 1-4 + 2.5 + 2.6 + 2.7** | ✅ shipped 2026-05-21 (AHCI iron-validated Attempt 82 — full success rubric cleared; USB-MS iron Attempts 83/84/85/86 partial/falsified — Phase 2.7 Reset Recovery executed correctly on iron but post-recovery TUR still failed with `CSW signature mismatch` → eight-bug audit for 1.31.3) | ~990 LOC USB MS + AHCI patches |
| **1.31.3** | **USB MS Phase 2.8 — eight-bug repair stack** (`XHCI_BULK_TIMEOUT_SPINS=200M` + strict TRB-pointer matching + SHORT_PACKET residue check + `msc_scsi_exec` unified retry+recover + drain repositioned + Reset Endpoint CSE tolerance + 64-bit `set_tr_dequeue`) | ✅ shipped 2026-05-21 (iron debut Attempt 87 PASS — full INQUIRY / TUR / RC10 chain on real Silicon Motion silicon; third storage-class iron debut closes after NVMe@80 + SATA@81) | ~200 LOC delta |
| **1.31.4** | **RAM-disk backend + VirtIO 1.x modern virtio-blk-pci** | ✅ shipped 2026-05-21 (iron Attempt 88 PASS as no-regression burn — full storage trio re-registered cleanly, kernel reaches scheduler init; RAM-disk + VirtIO themselves QEMU-only by construction — RAM-disk is `pmm_alloc`-backed, VirtIO has no bare-metal device) | ~640 LOC (RAM-disk ~140 + VirtIO ~500 rewrite of 181-LOC transitional 0.9.5) |
| **1.31.5** | **ext2 / ext4 read-only filesystem (Phase 1-4: superblock+BGDT+inode, indirect tree, dir walk + `ls`/`cat` + VFS_EXT2_FILE, ext4 extents)** | ✅ shipped 2026-05-21 (QEMU green on both ext2 + ext4 images byte-exact; iron burn 89 PENDING) | ~870 LOC across `kernel/core/ext2.cyr` + vfs.cyr + shell.cyr; build 520,920 → **568,960 B** (+47 KB); multi-source convergent audit at [`ext2-ext4-extents-prior-art.md`](ext2-ext4-extents-prior-art.md) (Linux v6.6 + FreeBSD + OpenBSD + Haiku + spec). Pre-iron-burn audit at `iron-nuc-zen-log.md` § Attempt 89. |
| **1.31.6** | **Cleanup / hardening / audit cycle** *(post-greenfield discipline)* | planned next | Eight bites: (A) ext2 input validation sweep (~80 LOC); (B) fatfs BPB validation sweep (~30 LOC); (C) drop ext2 boot-time smoke hook (-40 LOC); (D) save Cyrius `var X[N]` byte-vs-u64 gotcha as feedback memory + CLAUDE.md note; (E) pre-iron-burn audit doc; (F) state.md / roadmap / iron-log sweep; **(G) multi-backend ext2 probe** — walks all registered backends for `0xEF53` magic at LBA 2-3 instead of using only `blk_active` (~80 LOC); **(H) partition-aware mount** — `ext2_init_partition(first_lba)` via GPT consumption (~50-100 LOC). Bite (G) is **gating for iron burn 89** since archaemenid's NVMe is btrfs (in use, can't reformat); iron FS surface = 125 GB Silicon Motion USB stick reformatted ext2/4 (per user decision 2026-05-21). ~270 LOC + ~200 audit prose. |
| **1.31.7** | **ext4 64BIT support (Phase 5)** | planned | Modern `mkfs.ext4` defaults to 64bit even for filesystems well under 16 TB. Scope: BGDT entry size 32 → 64 bytes + block# width 32 → 64 throughout (~200 LOC). Closes the audit gap and ensures any real-world Linux ext4 partition mounts. Pre-burn derisk via `tune2fs -l /dev/nvme0n1p2 \| grep 64bit` informs scope timing; 1.31.7 is pinned regardless to close the audit. |
| **1.32.0** | **Networking arc — TCP/UDP server primitives + DHCP client + r8169 driver Phase 1-4 + iron debut** | ✅ shipped 2026-05-22 (cycle opened + closed same-day; Iron Attempts 92 + 93 burned on archaemenid; **Attempt 93 verified DHCP gate fix on iron** — `dhcp: DISCOVER` egresses through r8169 path; OFFER-timeout + i225-V + BBS/MUD carry-forward to 1.32.1) | ~1,000 LOC across `net.cyr` + `r8169.cyr` + `main.cyr`. Build 578,432 → 601,392 B. See § *1.32.x cycle* in state.md for full bite table. |
| **1.32.1** | **r8169 driver-level OFFER-timeout debug** (H1 PHY-not-configured / H7 TX OWN stuck / H8 RX OWN stuck) + i225-V driver bite C (pending Intel iron) + BBS/MUD userland (out-of-cycle) | queued — opens after user tag of 1.32.0 | Audit doc first per [[feedback_iron_burns_block_other_work]] then discriminator instrumentation (CMOS-bank stamps per no-serial-on-iron) then driver patches. |
| **1.33.x** | **WRITE cycle — ext2/ext4 mutation** | **pinned** | Cycle theme: block/inode allocator (bitmap walk + cursor), dirent insertion/removal, file create/truncate/unlink, mkdir/rmdir, write + journal-less commit semantics. ~1,500+ LOC; multi-source audit doc first per `feedback_redesign_dont_reinvent`. ext2 has no journal (spec-defined); power-loss = fsck-required image. |
| **deferred to plug-and-play cycle (pre-1.35.0)** | **Optical via USB MS (SCSI MMC profile)** *(was bundled with 1.31.2; pulled out 2026-05-21)* | deferred — currently *derps archaemenid at cold boot* if HP external Blu-ray is plugged in pre-power-on (USB hand-off / firmware quirk; resolves when plugged post-boot, but iron arc isn't set up for hot-add yet). Proper home is the plug-and-play cycle (hot-add device support), which would also fix the cold-plug quirk as a side effect. **Alternative iron path**: older Intel All-in-One in the Intel-stocked stable has an *internal* CD/DVD drive — likely SATA ATAPI (would revive the "punted ATAPI/AHCI passthrough" path on a non-archaemenid surface). Choose path when the cycle opens. | ~200 LOC additional over USB MS for the SCSI MMC profile + non-512-B-sector plumbing; +~800 LOC if ATAPI/AHCI lane gets reopened for the AllInOne |
| punted | ~~Optical (ATAPI / AHCI passthrough on archaemenid)~~ | **un-punted as alternative path** — see "deferred to plug-and-play cycle" row above. Was originally superseded by USB MS, but the archaemenid USB-optical cold-boot quirk surfaces ATAPI/AHCI on AllInOne as a parallel option. | — |

**Iron-validation coverage through 1.32.0**: NVMe (Crucial P3, Attempt 80) + SATA (WD Blue SA510, Attempts 81+82) + USB MS (Silicon Motion stick, Attempt 87) + 1.31.4 no-regression (Attempt 88) + 1.31.5 no-regression (Attempt 89) + 1.31.6 ext4 victory lap (Attempt 90) + 1.31.7 ext4 64BIT + shell-UX (Attempt 91) + **1.32.0 r8169 iron debut (Attempt 92 PARTIAL — r8169 Phase 1-4 byte-clean, DHCP gate predicate bug surfaced + fixed same-day) + 1.32.0 DHCP gate-fix verification (Attempt 93 PARTIAL — `dhcp: DISCOVER` egresses through r8169 path on iron; new failure mode `dhcp: OFFER timeout` = 1.32.1 carry-forward)**. RAM-disk is `pmm_alloc`-backed (no hardware variable — see "RAM-disk iron exercise" in the opportunistic block for the optional `RAMDISK_ENABLE=1` cosmetic burn); VirtIO-blk has no bare-metal device. Optical defers to the plug-and-play cycle (pre-1.35.0). **Cycle sequencing post-1.32.0**: 1.32.1 = r8169 driver-level OFFER-timeout debug + i225-V (queued for Intel iron) + BBS/MUD userland (out-of-cycle); 1.33.x = WRITE cycle (ext2/ext4 mutation paths).

### 1.32.x — Networking on iron (CLOSED 2026-05-22 at 1.32.0; 1.32.1 carry-forward pending user tag)

Originally planned as 1.31.x; storage took priority 2026-05-20 because the AMD archaemenid iron path needs real disk access before any user-facing FS work makes sense. Cycle opened + closed same-day on 2026-05-22 as **1.32.0 feature-complete**.

**Shipped at 1.32.0**:
- `kernel/core/net.cyr` (~543 LOC added) — TCP server primitives (`tcp_listen`/`tcp_bind`/`tcp_accept` + passive-open SYN handler + SYN_RCVD branch + ARP REQUEST handler), UDP server primitives (`udp_bind`/`udp_recv_from`/`udp_send_from` + 8-listener table), DHCP client (RFC 2131 DISCOVER → OFFER → REQUEST → ACK with full BOOTP header + option parsing).
- `kernel/core/r8169.cyr` (~400 LOC) — first real-iron NIC driver: PCI probe + MAC read + soft reset (Phase 1), 16-entry RX descriptor ring + per-buffer 4 KB pages + `r8169_poll` (Phase 2), 16-entry TX descriptor ring + `r8169_send` + TPPoll NPQ kick (Phase 3), NIC dispatcher `nic_ready` / `nic_send` / `nic_poll` with priority r8169 > virtio_net (Phase 4). Multi-source convergent per [`network-arc-prior-art.md`](network-arc-prior-art.md) (Linux `r8169_main.c` + FreeBSD `if_re.c` + OpenBSD `re.c` + NetBSD `re.c` + Haiku + RTL8168 datasheet).
- `kernel/core/main.cyr:655` DHCP gate predicate fix (`if (vnet_active != 0 || nic_ready() != 0)`) — explicit OR with generic NIC abstraction on RHS so future backends extend in-place without gate edits.
- `kernel/core/virtio_net.cyr` (148 LOC, unchanged from prior cycles) — still works for QEMU; r8169 takes priority on iron.

**Iron evidence**: Attempt 92 PARTIAL lit r8169 Phase 1-4 byte-clean on archaemenid (BAR2 byte-matched lspci, MAC byte-matched lspci, chip-rev decoded, rings up); same-day gate fix landed; Attempt 93 PARTIAL verified the fix on iron (`dhcp: DISCOVER` egresses through the r8169 path for the first time). Storage trio + GPT + ext4 mount + kybernet + shell all byte-clean — no regression. MVP gate stayed green at Attempt 93.

**Carry-forward to 1.32.1**: r8169 driver-level OFFER-timeout debug (H1 PHY-not-configured / H7 TX OWN stuck / H8 RX OWN stuck — the originally-anticipated audit hypothesis surface, now reachable post-gate-fix); i225-V driver port (bite C, ~700-1100 LOC, pending Intel-NIC iron); BBS + MUD userland consumer apps (separate standalone repos, out-of-cycle by design). See state.md § *1.32.1 carry-forward* for full breakdown.

### 1.33.x — ISO Stage-4 cut + distribution (queued)

The boot pipeline currently flashes via `install-usb.sh` directly. ISO Stage-4 cut packages the kernel + gnoboot + userland into a distributable live image (per [`iso-stage4-plan.md`](iso-stage4-plan.md)). Was a pre-MVP gate; now becomes the *distribution* gate once the typeable shell + network + storage trio is in place.

### Parallel cycle work (no version pin — opportunistic)

These can land in any 1.30.x patch without blocking the gate cycle:

- **RAM-disk iron exercise** (post-1.31.4, pre-1.35.0) — rebuild agnos 1.31.4+ with `RAMDISK_ENABLE=1` and burn on archaemenid to see the `ramdisk: 512 LBAs x 512B (64 pages; virtio primary)` line print on iron. Low information value (RAM-disk is `pmm_alloc`-backed; hardware tells us nothing new) — purely for CHANGELOG completeness so the 1.31.4 RAM-disk bite carries an iron mention. Bundle with any other iron burn that's already scheduled per `feedback_iron_burns_block_other_work`; don't stand up a dedicated burn for it.



- **kriya v0.3.0** — M2 file-operations milestone (`cp` / `mv` / `rm` / `mkdir` / `touch` / `ln`) per [kriya M2](https://github.com/MacCracken/kriya/blob/main/docs/development/roadmap.md#m2--file-operations-v030). **Co-gates iron Attempt 54 alongside the active Cyrius agent cycle** — burn fires after BOTH gates release (single-machine dev setup; burns disrupt unrelated work; per `feedback_iron_burns_block_other_work`).
- **commandress v0.2.0** — minimum viable prompt (config loader + cwd segment + exit-code segment + render pipeline) per [commandress M1](https://github.com/MacCracken/commandress/blob/main/docs/development/roadmap.md#m1--minimum-viable-prompt-v020)
- **agnos kernel hardening** — single-line correctness fixes surfaced during 1.30.x iron burns; SMP AP-wakeup IPI gating decided post-Attempt-54 outcome
- **gnoboot 0.3.x** — only as iron burns surface bootloader-side bugs; otherwise stable at 0.2.0 per the "lean is good" stance after the CMOS-removal cleanup track
- **Cyrius bugs filed during iron work** — non-zero gvar-init issue currently filed at `cyrius/docs/development/issues/2026-05-15-cyrius-nonzero-gvar-init-not-honored.md`; the cyrius repo handles its own cycle (per `feedback_cyrius_hands_off`)
- **Framebuffer — quiet-boot GOP rendering regression** — `fb_console` renders cleanly when BIOS quiet-boot is **OFF** (legacy VGA-style fallback, lower res) but garbles glyphs when quiet-boot is **ON** (GOP framebuffer at native 1080p+). Surfaced 2026-05-16 during Attempts 33–34: bisection initially pointed at Phase 2.5 USBLEGSUP claim, but Attempt 34 (Phase 2.5 disabled, quiet-boot ON) still corrupts — quiet-boot is the actual variable. **Iron-burn BIOS workaround**: Quiet Boot **OFF**, USB Legacy Support **On/Auto**, XHCI **Enabled**, Mass Storage **Enabled**. **Real fix** (defer to opportunistic): either root-cause the GOP rendering regression (what changed between Attempt 32 clean and Attempt 33+ garbled — gnoboot GOP capture, fb pixel-format/stride assumption, MTRR/PAT cache attributes on FB region) or land dual rendering paths (legacy VGA text-mode at `0xB8000` + linear GOP). Not blocking MVP — CMOS post-mortem (kcp slot) carries enough signal for phase-gate verification; VGA-mode visual is readable for surface triage.

### Public-Beta path (Q4 2026 — Phase 13A items 4-7)

Self-hosting LFS-style work moves from "Phase 13A future" to "Public Beta scope" once the closed-beta cohort program has produced hardening receipts across multi-architecture hardware. **Items 4–7 of Phase 13A** below remain the public-beta deliverable; the iron-validated MVP doesn't shift that scope — it just clears the runway for the program that justifies running it.

---

## Pre-Beta

### Phase 13B — Arch-Neutral Boot Pipeline

**Gate**: v5.6.x optimization arc closed through v5.8.x; O5/O6 audit closed in v5.9.x.
**Precedes**: Cyrius v5.12.x RISC-V rv64 + bare-metal — this work lands *during* v5.11.x stdlib annotation arc so v5.12.x opens clean.
**Rationale**: Cyrius sequencing settled to v5.6.x (optimization arc) → v5.7.x (sandhi-fold + cyrius-ts) → v5.8.x (audit closeout + language vocabulary + stdlib foldins) → v5.9.x (catchup + O5/O6 close) → v5.10.x (typed-simd ABI + REAL TYPE SYSTEM + struct-byval ABI — three completed arcs in 5 days) → **v5.11.x (stdlib annotation arc + consumer-issue closeout)** → **v5.12.x (RISC-V + bare-metal)**. Agnos already did the multi-arch split at v1.1.0 (`kernel/arch/x86_64/`, `kernel/arch/aarch64/`, `kernel/core/`, `kernel/user/`). The gap is that everything downstream of boot still carries x86_64/aarch64-shaped assumptions. Neutralizing during v5.11.x means v5.12.x RISC-V + bare-metal slot in as "add a target," not "rewrite the pipeline."

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

**Target**: complete during Cyrius v5.11.x stdlib annotation arc, before v5.12.x opens RISC-V + bare-metal. The optimization-arc baselines re-baselined across v5.6.x → v5.10.x; O5/O6 audit closed in v5.9.x.

### Phase 13C — Community & Documentation

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Video tutorials | Not started | Installation, usage, agent creation |
| 2 | Support portal | Not started | Discord + forum |
| 3 | Community testing program | Not started | Beta tester enrollment + LTT/Labs- or Level1Techs-style hardware submission requests for benchmarking on configurations outside the in-house matrix (long-tail coverage); Wendell Wilson's enterprise/server/ZFS/IOMMU depth aligns particularly well with AGNOS's technical audience |
| 5 | Hardware-access partnerships | Not started | Tiered outreach: (1) direct manufacturer relationships (NVIDIA/AMD/Intel partner programs) for eval silicon + early driver access; (2) fallback to reviewer/creator channels with existing card pipelines — Jay2Cents (SoCal-local; proximity = easier physical handoff for driver work and cross-checks), Wendell/Level1Techs (enterprise depth), LTT Labs (breadth). Reviewers are a fallback when direct manufacturer relationships aren't accessible, not a substitute |
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
| 11 | Gaming cabinet (GTX 1060 OC) | x86_64 | Desktop + kavach | Available — low-end NVIDIA / Pascal; dual-purpose: AGNOS host + Windows guest |
| 12 | Skytech Legacy 4 (Ultra 9 285K, RTX 5080, 64GB DDR5, 2TB NVMe) | x86_64 | Desktop / GPU+AI workload | **Available** (arrived 2026-05-04) — high-end NVIDIA bring-up: ai-hwaccel, hoosh, mabda, aethersafha. Secondary closed-beta hardware-matrix target (NUC row 14 is primary for first-boot install). Upgrade vectors: Intel Arc GPU swap, next-gen NVIDIA late-2026/early-2027, DDR5 capacity bump |
| 13 | Vaio all-in-one (older NVIDIA CUDA) | x86_64 | Desktop / legacy CUDA floor | Available — oldest CUDA-capable target, validates ai-hwaccel low-end fallback |
| 14 | AMD NUC devbox (Ryzen 7 5800H, Radeon Vega/Cezanne) | x86_64 | Primary dev environment | **Active** — daily-driver dev box; covers AMD CPU (Zen 3) + `amdgpu` driver stack (integrated GCN/Vega). **Closed-beta MVP first-hardware-boot target**: open 2TB SSD on this box gets AGNOS installed via GRUB-chain (per Phase 13A item 3.5; install.cyr provisions partition + initramfs + GRUB entry). |
| 15 | MacBook Pro 2018 (Intel + T2) | x86_64 | Laptop / Apple EFI | Available — laptop form factor (battery, lid-suspend, hybrid graphics); validates Apple EFI + T2 security chip quirks |
| 16 | MacBook Pro M5 | aarch64 | Laptop / Apple Silicon | Pending — blocked on Asahi-class reverse-engineered driver support for M5 generation |
| 17 | Mac Mini 2025 (Apple Silicon) | aarch64 | Desktop / Apple Silicon | Pending — same Asahi-driver dependency; closes aarch64 desktop-class coverage when ready |
| 18 | RISC-V dev boards (multiple) | riscv64 | IoT/Edge | Available — closes RISC-V architecture gap; validates rv64 toolchain path |
| 19 | Arduino Uno (ATmega328) | AVR 8-bit | Peripheral / sensor | Available — not an AGNOS host (8-bit, ~32KB flash); peripheral testbed for UART/I2C/SPI interaction from AGNOS edge nodes |

**NVIDIA mid-tier coverage (Ampere/Ada, 3000/4000-series):** physical bench coverage spans Pascal (1060 OC) → Blackwell (RTX 5080), skipping Turing/Ampere/Ada. Acquire a used 3060/3070 only if the resale market supplies one at reasonable cost for the validation window needed; otherwise, GPU rental (Lambda/RunPod/Vast.ai) covers the compute-side gap — CUDA arch validation, ai-hwaccel detection, hoosh inference paths. Rental does **not** cover physical-hardware behavior (power management, thermals, display/HDMI quirks, sleep/wake), but those generalize from the Pascal and Blackwell endpoints.

**Remaining gaps (acceptable for v1.0):** discrete AMD GPU (RDNA/RDNA2/RDNA3) — `amdgpu` kernel driver is validated daily on the NUC's integrated Vega, so the gap is RDNA-specific arch paths only. Same acquisition strategy as NVIDIA mid-tier: prefer rental for compute-side validation, fall back to used market only if cost/availability favors physical. Apple Silicon (M-series) bring-up — gated on Asahi-class driver work, not bench inventory.

**Long-tail coverage (post-public-launch):** community-submission program (see Phase 13C item 3) — solicit hardware-test requests in the LTT/Level1Techs (Wendell) mold to validate AGNOS on configurations outside the in-house matrix. Cheaper and broader than buying every gap; also doubles as marketing surface.

### Phase 13G — Consumer App Bundle Tests

All 19 apps released. Bundle tests (`ark-bundle.sh`) not yet run.

### Phase 13H — Driver Port Strategy

**Method**: sequential-focus port — pick one platform/device class, drive to solid before moving on. Mirrors the subsystem-porting approach (one Cyrius port at a time, no parallel half-finished ports). Sequence is driven by the Phase 13F hardware matrix — what's on the bench gets ported; everything else is "not supported" until a partnership or community submission moves it onto the bench.

**Workflow per target**:
1. Pick next driver from the sequence (informed by 13F priorities and partnership pipeline)
2. Port to solid — boots, stable, benchmarked, integrated with ai-hwaccel/aethersafha/etc. as relevant
3. Document and announce shipped support
4. Cross-target sweep — re-validate prior ports against any cross-cutting changes introduced during the new port
5. Move to next

**Public signal**: maintain a visible "Currently working on: X driver support" status (README, status page, or equivalent) so contributors know what's in flight, where to help, and what's intentionally on the back burner. Closes the gap between "we have a plan" and "we know what's actually being worked on right now."

**Shim-then-native pattern**: when a target sits on the matrix but native-port bandwidth isn't available yet, ship via a bounded shim layer (Linux DRM/KMS or amdgpu shim, à la FreeBSD `linuxkpi`; Linux net driver shim; etc.) so the hardware works *now* — then queue the native Cyrius port and retire the shim when it lands. Decouples "we support this hardware" from "we have a clean native driver." Constraints: the shim surface must be explicit and bounded (not creeping into pervasive Linux-API inheritance), each shimmed driver carries an explicit native-port queue entry, and retirement of the shim is a tracked deliverable — not a permanent compatibility layer. Keeps the "refuse dead legacy" stance honest while letting hardware support ship on a real timeline.

**Release cadence (mabda model)**: each major release focuses on one vendor's native driver port — same single-target, predictable-deprecation rhythm mabda uses. Per-vendor shim lifecycle is **three majors**: native ships in major N (shim still present alongside), deprecated with warnings in major N+1, removed entirely in major N+2. Proposed sequence:

| Major | Native focus | Grind tier | Concurrent shim deprecations | Shim removals |
|-------|--------------|------------|------------------------------|---------------|
| 3.0 | AMD GPU (RDNA discrete + iGPU native) | **Tractable** — open `amdgpu` kernel driver, public RDNA ISA, RADV/Mesa reference | — | — |
| 4.0 | NVIDIA (CUDA + display) | **Heavy lift** — closed-source stack; clean-room route (Nouveau/Nova-class) is multi-year; partnership path strongly preferred | AMD shim deprecated (warnings) | — |
| 5.0 | Intel Arc (Xe + media) | **Tractable** — open Xe driver, open documentation, Mesa stack | NVIDIA shim deprecated | AMD shim removed |
| 6.0 | (next vendor — TBD: Apple Silicon GPU pending Asahi work, or Mali/Adreno for ARM) | **Heavy lift** — Apple Silicon is reverse-engineering (Asahi-class); Mali/Adreno less brutal but still vendor-opaque | Intel Arc shim deprecated | NVIDIA shim removed |

Every shim has a known demolition date the moment it ships. No vendor's shim outlives two majors. Contributors and users can plan against the cadence: "if you're on AMD, the shim is supported through 3.x, deprecated in 4.x, gone in 5.x — port your tooling assumptions accordingly."

**Timing dependency (Cyrius 6.x)**: the AGNOS-3.0 AMD native port (and the rest of this cadence) is gated on Cyrius 6.x landing and stabilizing — toolchain/compiler bandwidth for serious native GPU driver work isn't available before that. Until Cyrius 6.x is ready, the entire driver story is *shim-only*; the native sequence above starts in the AGNOS major immediately following Cyrius-6.x stabilization. Don't promise native AMD ahead of that gate.

**mabda status (not on critical path)**: mabda is at **3.0.0-rc.2** — needs a soak period before the GA cut, then folds into the Cyrius stdlib. Expected to land before Cyrius 6.x stabilizes, so the GPU foundation layer is in place when the per-vendor native work starts. mabda is *not* the bottleneck on this cadence; Cyrius 6.x is.

**Honest grind expectation**: the **NVIDIA (4.0) and Apple GPU (6.0)** slots are the multi-major **tough-time** efforts — closed-source stacks where the bench/rental/partnership tooling above is necessary but not sufficient. AMD (3.0) and Intel Arc (5.0) are the tractable wins that keep the cadence moving while the heavy lifts grind. If a heavy-lift slot slips, expect it to slip into the *following* major rather than blocking the easier ports — preserve the rhythm, don't stall the train on one vendor.

**Front-load Intel Arc as the pressure-release valve**: a discrete Arc card runs **$300–500** — cheap enough to acquire ahead of its scheduled 5.0 slot. If NVIDIA (4.0) starts heading into multi-month grind territory, promote Intel Arc forward into that major and slot NVIDIA back. Cadence rhythm is preserved (a tractable native port still ships), the grind gets another major of bench time, and the cheap acquisition pays for itself by removing schedule risk on the heavy lift. Either buy a dedicated card or do the planned Arc swap on the Skytech (row 12, upgrade vectors) earlier than scheduled.

### Phase 16 — Desktop Completeness

Detailed items tracked in respective repos:
- **16B/D/E** — Input, polish, configurability → `MacCracken/aethersafha`
- **16F** — Media ingestion & compositing → `MacCracken/aethersafta`
- **Desktop recipes** (fonts, themes, icons) → zugot

### Phase 15 — Threat Detection & Scanning

**Subsystem**: **phylax** — standalone repo (`MacCracken/phylax`). Detailed roadmap tracked there.

### Phase 15A — Agent Injection Defense (post-closed-beta, cross-cutting)

**Spec**: [`planning/agent-injection-defense.md`](planning/agent-injection-defense.md) — full design spine.

**Problem**: encoded prompt injection — instructions hidden in representations the LLM decodes natively (Morse, Base64, Unicode tricks, homoglyphs, foreign-language smuggling) but pre-LLM safety filters don't recognize as instructions. **Trigger event**: 2026-05 third-party AI agent drained for $200K via Morse code embedded in a tweet. The attack class is general; defense must be structural.

**Approach**: six-layer defense across `phylax` (input scanning), `hoosh` (gateway pre-flight + provenance tagging), `t-ron` (capability-source policy at MCP boundary), `kavach` (irreversible-action capability gating + confirmation tokens), `libro` (audit-chain provenance), `agnostik` (`UntrustedInput<T>` shared type). L4 + L6 give **structural immunity at the agent layer** — same absence-by-design pattern as the kernel being immune to CVE-2026-31431, applied at a different boundary. Even if every detection layer misses the encoding, the wallet drain doesn't happen because the capability gate doesn't exist for unconfirmed external-input-origin calls.

**Phasing** (full detail in spec):
- **Phase 1 — Detection foundation** (post-closed-beta): phylax encoded-content scanner + hoosh middleware. Pure observability — no behavior change.
- **Phase 2 — Capability gating** (post-public-beta): t-ron + kavach + agnostik. Structural immunity layer comes online.
- **Phase 3 — Documentation + narrative** (parallel with Phase 2): design-patterns.md absence-by-design entry; *"Why AGNOS-native agents can't be drained by a tweet"* article paired with summer-2026-arc Beat 2 (Black Hat receipts).

**Key design questions open** (see spec): confirmation token mechanism, default `irreversible` set, L1 detection thresholds, backward-compatibility migration path, L6 type-adoption mandate level.

### Phase 20 — Cross-Platform Compat Subsystem (post-public-beta, foundational)

**Spec**: [`planning/cross-platform-compat-subsystem.md`](planning/cross-platform-compat-subsystem.md) — full design spine.

**Commitment**: the *agnosticism* in AGNOS's name. Foreign-platform work (starting with Linux) runs **transparently** — wrappers or native ports — without the user needing to make it viable. **It just works.** Native ports remain the preferred path; the compat subsystem is the bridge for software not yet ported and for software that will never be ported.

**Architecture (locked)**: sandboxed Linux subsystem via kavach container. Foreign binaries run inside a full Linux-personality root (their own `/lib`, `/usr`, libc, process tree); the AGNOS kernel never sees Linux syscalls directly. From outside, it's a kavach sandbox; from inside, it's Linux. **Two growth paths, never collapsed**: AGNOS kernel grows organically with native workloads (legitimate, audited, load-bearing), but never to mimic foreign-platform ABIs. The interpretive layer stays the interpretive layer — the boundary is permanent.

**Why this preserves the structural-immunity argument**: the CVE class that the 26-syscall sovereign surface excludes (e.g. CVE-2026-31431 Copy Fail) requires the vulnerable syscall to *exist in the kernel*. Since the kernel never absorbs foreign ABIs, the bug class stays unreachable for AGNOS-native processes. Foreign binaries run with Linux-grade risk, audibly tagged, sandboxed by default.

**Phasing** (full detail in spec):
- **Phase 1 — Foundation** ✅ Substrate (kavach 3.x shipped; `Subsystem<T>` agnostik type to add when active)
- **Phase 2 — Proof-of-concept**: boot a static busybox inside a kavach-isolated Linux personality root (post-public-beta)
- **Phase 3 — ark packaging**: `ark install linux-compat-env` provisions the personality root reproducibly
- **Phase 4 — Runtime UX**: `agnos run path/to/foo` auto-detects Linux binary, spawns subsystem, returns exit code — user never interacts with the subsystem directly
- **Phase 5 — Curated profiles**: workload-class variants (AI/Python, build, desktop) — each a curated capability surface smaller than full Linux
- **Phase 6 — Port pipeline feedback**: high-usage subsystem workloads surface as candidates for native ports

**Rejected alternatives** (see spec for full reasoning): in-kernel Linux ABI (erases structural immunity); per-process linux-personality flag (leaks ABI awareness into the sovereign surface); recompile-only without runtime compat (contradicts the "just works" commitment).

**Subsystem name**: TBD — Sanskrit convention applies when Phase 2 begins. "The compat subsystem" / "linux-compat-env" works as a placeholder.

### Phase 21 — DPI Resistance (post-public-beta, network-stack-foundational)

**Spec**: [`planning/dpi-resistance.md`](planning/dpi-resistance.md) — full design spine.

**Commitment**: the AGNOS network stack normalizes traffic to mainstream-browser fingerprints **by default**. Every AGNOS-native application gets DPI resistance for free; every `cyrius` TLS connection looks indistinguishable from current-stable Chrome by default. The empire cannot selectively throttle, block, or fingerprint AGNOS users without acting against Chrome-on-Windows users at scale.

**Six-layer defense** (mirrors agent-injection-defense pattern): L1 TLS fingerprint normalization (cyrius stdlib `tls.cyr`); L2 traffic shape normalization (agnosys + transport-policy crate); L3 pluggable transports (obfs4 / meek / snowflake); L4 domain fronting / decoy routing (opt-in advanced); L5 mesh fallback via `kula` (when fully censored); L6 steganographic channels (last-resort low-bandwidth). Failure of any single layer doesn't surface AGNOS to the network.

**Two principles, never collapsed**: AGNOS network normalization grows to match shifting mainstream browser fingerprints — never to become its own distinctive fingerprint. Pluggable transports are exceptional, not default. The wire-layer invisibility is paradoxical-but-durable sovereignty: AGNOS-at-the-OS-layer requires AGNOS-at-the-network-layer to be invisible.

**Phasing**: substrate (cyrius stdlib TLS) → L1 fingerprint normalization → L2 shape normalization → L3 transports → L5 mesh → L4/L6 advanced. Foundation already shipped in cyrius/agnosys; explicit fingerprint-target work begins post-public-beta.

### Phase 22 — Parallel PKI (parallel to closed beta, paper-rooted trust)

**Spec**: [`planning/parallel-pki.md`](planning/parallel-pki.md) — full design spine.

**Commitment**: AGNOS ships with a **parallel trust chain rooted in physical artifacts** — the 29KB seed + SHA-256 chain distributed on bumper stickers, SD cards, and QR-encoded paper. The physical artifact *is* the signing authority. Any AGNOS install can verify any AGNOS-signed thing against the root without internet, without commercial CA cooperation, without any rented infrastructure. The empire cannot revoke a sticker.

**Architecture**: 29KB seed + Ed25519 root pubkey + SHA-256 chain header on physical media. Sub-keys (per-project, per-build) chain forward to leaf signatures via sigil. Commercial CAs serve as **opportunistic cross-signing bridges** for browser compatibility — never as the load-bearing trust. Even if every commercial CA refused AGNOS tomorrow, AGNOS continues to verify its own artifacts.

**Two principles, never collapsed**: parallel PKI is always the load-bearing trust; commercial CA bridge is convenience layer. Even if 100% of users had commercial-CA-trusted browsers, AGNOS still verifies internally against the paper root. If the bridge ever becomes required, the empire wins by revoking the bridge.

**DEF CON August 2026 cadence beat depends on Phase 2** of this spec — the sticker distribution event is meaningful only if any AGNOS install can actually verify against the printed root. Phase 2 (verification path) must ship before the sticker print run is meaningful — that's the critical dependency.

**Phasing**: sigil substrate (✅ shipping) → parallel-PKI verification path (closed-beta scope) → cross-signing infrastructure → public artifact distribution (DEF CON Aug 2026) → print-at-home tooling → mirror network → key rotation ceremony.

### Phase 23 — Foundation Structure (governance meta-defense)

**Spec**: [`planning/foundation-structure.md`](planning/foundation-structure.md) — full design spine.

**Commitment**: the project evolves toward a **multi-jurisdictional, mission-locked, contributor-protecting Foundation** that holds project assets (trademarks, copyrights, signing-key custody) in a way no single state actor or commercial entity can coerce. The Foundation is the legal substrate that makes the parallel PKI, parallel distribution, and parallel finance *actually defensible*.

**Seven commitments** (full detail in spec): (1) multi-jurisdictional asset distribution; (2) license-as-shield (GPL-3.0-only, already locked); (3) contributor protection (DCO + pseudonymous contribution paths); (4) asset segregation (trademarks/copyrights/keys held by Foundation, not individuals); (5) funding diversity (no single source >25%); (6) succession planning (project survives Robert); (7) mission lock (bylaws prevent Mozilla-style drift).

**Two principles, never collapsed**: Foundation operates non-commercially; commercial activities live in separate entities that license / royalty back to the Foundation (the two-track outreach framework — NPO commons vs commercial equity). Foundation's jurisdictional footprint grows toward multi-jurisdiction; never centralizes to a single coercible legal system.

**Pre-Foundation immediate actions** (Robert can do now, no legal counsel needed): trademark filings (`AGNOS`, `Cyrius`, key subsystem names); DCO sign-off in contribution docs + CI; CONTRIBUTING.md IP model documentation; quiet outreach to 2-4 candidate founding board members; project bank account separate from personal finances; signing-key custody documentation. These six are time-sensitive — Phase 1 (trademark) should happen *before* public adoption, not after.

**Phasing**: pre-Foundation (current; Robert holds everything) → trademark filings + DCO + contributor docs (pre-closed-beta) → legal counsel engagement → primary Foundation formation (at v1.0) → asset transfer → secondary-jurisdiction mirror → mature governance (TSC elections, founder emeritus transition at v2.0).

### Phase 24 — Identity & Authorization Model (cross-cutting, fluid framework)

**Spec**: [`planning/identity-and-authorization-model.md`](planning/identity-and-authorization-model.md) — full design spine.

**Commitment**: AGNOS rejects the Unix-login-by-default + federated-IDP empire pattern. The user *owns* the device; proving identity to your own device is security theater. AGNOS's posture: **recognition over interrogation; authorization > authentication**. The device tries to *know* who's there (ambient, continuous); sensitive operations are gated by *capability-per-action* that fires regardless of who the system thinks is at the keyboard. Authentication is best-effort; authorization is rigorous.

**Four-layer model**: theft (encryption at rest), presence (auto-lock + re-presence), identity (multi-user differentiation), capability (per-action authorization). Each layer has its own threat model and its own pluggable mechanism stack. **Don't conflate them under a single "login."**

**Why this matters now (even though full implementation is post-MVP)**: closed-beta MVP is single-user no-auth (current behavior), which is compatible with this framework (Layers 1-3 deferred, Layer 4 nascent). What this doc *prevents* is anyone retrofitting `/etc/passwd` / `getty` / `login` into kybernet "because that's how Linux does it." Stop the empire-pattern import at the architectural commitment, *now*.

**Existing subsystem map**: `sigil` (cryptographic identity), `kavach` (capability sandboxing — primary authorization layer), `t-ron` (MCP-boundary policy), `avatara` (identity overlay → bonded recognition), `libro` (audit chain), `kula` (cross-device family/clan mesh — future), kybernet (PID 1 session setup), agnoshi (shell receiving bonded user). The architecture doesn't need new subsystems — it needs the *framework* across the existing ones to be made explicit (the planning doc).

**Two principles, never collapsed**: authentication never grants authorization (empire's failure mode); even with perfect authentication, every irreversible action gets a fresh capability gate. Recognition modes evolve (mechanisms get better) but the boundary stays permanent.

**Fluid-document caveat explicit**: mechanism choices per layer (biometric vs token vs behavioral vs password) are open research questions with no clean answer. The framework commits architectural shape — *layered concerns, pluggable mechanisms, recognition primary, capability-gates primary security* — and explicitly defers mechanism selection to "evolves with hardware and UX research." The planning doc updates as mechanisms mature.

**Phasing**: Phase 1 (framework documented) ✅ shipped 2026-05-12. Phase 2+ (encryption at rest, lock-screen mechanisms, multi-user via avatara, capability-gate UX) lands post-public-beta as the relevant subsystems and research mature.

---

## Ecosystem

### Named Subsystems (30+)

All subsystems are standalone repos at `/home/macro/Repos/{name}/`.

| Name | Role | Repo | Version | Cyrius Port |
|------|------|------|---------|-------------|
| **agnos** | AGNOS kernel | `MacCracken/agnos` | 1.29.0 | **Native** |
| **cyrius** | Sovereign compiler | `MacCracken/cyrius` | 5.11.24 | **Native** |
| **kybernet** | PID 1 binary | `MacCracken/kybernet` | 1.2.1 | **Done** |
| **argonaut** | Init system (library) | `MacCracken/argonaut` | 1.7.0 | **Done** |
| **agnosys** | Kernel interface | `MacCracken/agnosys` | 1.2.6 | **Done** |
| **agnostik** | Shared types library | `MacCracken/agnostik` | 1.2.2 | **Done** |
| **sigil** | Trust verification & crypto | `MacCracken/sigil` | 3.1.1 | **Done** |
| **libro** | Audit chain | `MacCracken/libro` | 2.6.3 | **Done** |
| **hoosh** | LLM inference gateway | `MacCracken/hoosh` | 2.0.0 | **Done** |
| **avatara** | Divine archetype overlay | `MacCracken/avatara` | 2.3.0 | **Done** |
| **ai-hwaccel** | GPU detection | `MacCracken/ai-hwaccel` | 2.2.2 | **Done** |
| **kavach** | Sandbox execution | `MacCracken/kavach` | 3.2.1 | **Done** |
| **abaco** | Math/number theory | `MacCracken/abaco` | 2.2.0 | **Done** |
| **bote** | MCP core | `MacCracken/bote` | 2.7.2 | **Done** |
| **t-ron** | MCP security monitor | `MacCracken/t-ron` | 2.1.4 | **Done** |
| **daimon** | Agent orchestrator | `MacCracken/daimon` | 1.2.3 | **Done** |
| **agnoshi** | AI shell | `MacCracken/agnoshi` | 1.3.2 | **Done** |
| **hadara** | Culture modeling | `MacCracken/hadara` | 1.0.0 | **Native** |
| **shravan** | Audio codecs | `MacCracken/shravan` | 2.3.2 | **Done** |
| **mabda** | GPU foundation | `MacCracken/mabda` | 3.0.0-rc.2 | **Done** — pre-GA soak before stdlib fold |
| **sankoch** | Lossless compression | `MacCracken/sankoch` | 2.2.5 | **Done** |
| **itihas** | History/versioning | `MacCracken/itihas` | 2.2.0 | **Done** |
| **bsp** | BSP geometry library | `MacCracken/bsp` | 1.1.2 | **Done** |
| **cyrius-doom** | DOOM engine | `MacCracken/cyrius-doom` | 0.26.2 | **Native** — held on 5.7.48 pin |
| **ark** | Unified package manager | `MacCracken/ark` | 0.8.0 | **Done** — extreme pin lag (5.1.10) |
| **nous** | Package resolver | `MacCracken/nous` | 1.1.2 | **Done** |
| **phylax** | Threat detection engine | `MacCracken/phylax` | 1.1.1 | **Done** |
| **shakti** | Privilege escalation | `MacCracken/shakti` | 0.3.0 | **Done** |
| **hisab** | Higher math | `MacCracken/hisab` | 2.2.2 | **Done** |
| **owl** | `cat`/`bat` replacement | `MacCracken/owl` | 1.3.6 | **Native** — M0–M5 shipped; M3b blocked on vyakarana |
| **vyakarana** | Source-code grammar / tokenizer | `MacCracken/vyakarana` | 2.2.1 | **Native** — M0 scaffold shipped 2026-04-23; M1 shell grammar in flight |
| **bhava** | Emotion/sentiment | `MacCracken/bhava` | 2.0.0 | Pending |
| **takumi** | Package build system | `MacCracken/takumi` | 0.8.0 | **In port** — pinned Cyrius 5.5.23, parity work in flight |
| **aegis** | System security daemon | `MacCracken/aegis` | 1.0.0 | **Done** — hit v1.0 in v5.10.x window |
| **aethersafha** | Desktop compositor | `MacCracken/aethersafha` | 0.1.0 | Pending |
| **mela** | Agent marketplace | `MacCracken/mela` | 0.1.0 | Pending |
| **agnova** | OS installer | `MacCracken/agnova` | 0.1.0 | Pending |
| **seema** | Edge fleet management | `MacCracken/seema` | 0.1.0 | Pending |
| **samay** | Task scheduler | `MacCracken/samay` | 0.1.0 | Pending |
| **cyim** | Sovereign text editor (VIM-inspired) | `MacCracken/cyim` | 1.7.0 | **Native** — vyakarana consumer; cyim-lsp 1.5.0 companion shipped |
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
| **sandhi** (सन्धि — *junction, connection, joining*) | Service-boundary layer — shared HTTP/TCP/TLS + service discovery. Like sakshi for services. Absorbs `lib/http_server.cyr` extraction; composes `lib/http.cyr`, `ws.cyr`, `tls.cyr`, `json.cyr`, `net.cyr` into full-featured client patterns. **Folded into Cyrius stdlib at v5.7.0 per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md); sandhi repo entered maintenance mode.** Pattern set the precedent for vani-fold (v5.8.0) and niyama-fold (v5.9.0). | vidya, hoosh, ifran, daimon, mela, yantra | **Done — shipped v5.7.0** |
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

- **Long-term vision**: [`vision/conscious-objects.md`](vision/conscious-objects.md) (quantum substrate / Layer 0), [`vision/creator-economy.md`](vision/creator-economy.md) (sovereign distribution), [`vision/maat-42.md`](vision/maat-42.md) (42-domain completeness mapping). Foundation governance moved to [`planning/foundation-structure.md`](planning/foundation-structure.md) 2026-05-12. v2.0/v3.0 release-ladder vision retired 2026-05-12 (those milestones happened ahead of schedule).
- **Sprint history**: [sprint-history.md](sprint-history.md)
- **App roadmap**: [applications/roadmap.md](applications/roadmap.md)
- **Changelog**: [CHANGELOG.md](/CHANGELOG.md)
- **Contributing**: [CONTRIBUTING.md](/CONTRIBUTING.md)
- **LFS Reference**: https://www.linuxfromscratch.org/lfs/view/stable/
- **BLFS Reference**: https://www.linuxfromscratch.org/blfs/view/stable/

---

*Last Updated: 2026-05-11 (Cyrius v5.11.0 cut day) | Next Review: closed-beta cut (~early June 2026)*
