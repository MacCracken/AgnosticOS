# AGNOS Development Roadmap

> **Status**: Pre-Beta — Closed Beta targeting **Late June / Early July 2026** (gated on reaching **server base work**) · Desktop **mid-to-late summer 2026** | **Last Updated**: 2026-06-18 (per the detailed footer log; body verified current through agnos 1.45.10 / the agnodrm decomposition on the 2026-06-19 state-sync). This roadmap is **forward-facing** — shipped arcs live in [`state.md`](state.md) + the per-repo CHANGELOGs, not re-narrated here. Refer to state.md for current kernel / Cyrius / per-repo versions.
>
> 🔴 **BETA RESCOPED (2026-06-14)**: the whole **summer-2026 arc stays CLOSED beta**, in two phases, with the kernel arcs accelerating the timeline hard. **Phase 1 — closed beta opens Late June / Early July 2026** gated on reaching **server base work**: founder-driven — stand up **Docker AGNOS builds running the server-stage services** (BBS / MUD / remote-shell / web / `ark`+`nous` server-side) and **sweep-test them myself to find the weak points** (server workloads need no humans-at-a-screen). **Phase 2 — Desktop, mid-to-late summer 2026** (pulled forward from the old v1.0 Q2 2027): brings in **external testers** because GUI / daily-driver workloads genuinely need humans at the screen — but the program **stays invite-only / closed, NOT public**. **Public beta is DEFERRED to post-summer** (the original ~Q4 2026 window holds): formal public enrollment + third-party security audit + community program open only after the closed desktop phase proves out. *(Supersedes the 2026-05-06 rescope, which had closed beta early June + public beta Q4 2026 with no desktop-in-summer track.)*
>
> 🟢 **MVP GATE CLEARED on iron** — Attempt 68 / agnos 1.30.9 / 2026-05-15: kernel + kybernet (PID 1) + agnoshi reach a **typeable shell** on archaemenid (NUC AMD Beelink SER). Since then the kernel shipped the storage stack (NVMe / AHCI / USB-MS / RAM-disk / GPT), the **r8169 networking stack** (iron-COMPLETE — DHCP real lease), **ext2/4 + FAT-family read+write** + the crash-safe FS stack (extent→jbd2→VFS), **exec-from-disk + VFS routing** (1.40), the **shell→userland-agnsh separation** (1.41, iron burn `14115`), **graphics + DOOM** (1.43, in-game on iron, burn `1439`), **multi-threading / preemptive scheduling** (1.44 — schedulable `&` jobs, SMP-AP wake), and is now in the **1.45.x TLS → HTTPS → `ark`-fetch** arc (ring-3 net + socket syscalls #45-#57 — client + server `sock_listen`/`accept`). **Iron (2026-06-13/14): boot-to-shell with a live multi-command keyboard on real Zen.** Current kernel + active cycle: [`state.md`](state.md).
>
> 🟡 **Iron-boot running log**: [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md) (active, post-MVP) + [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) (Attempts 1–68, capped at the MVP gate). Append-only per-attempt log (symptom / root cause / repair / verification).
>
> 🔴 **NEXT distribution gate**: ISO Stage-4-only first cut — see [`iso-stage4-plan.md`](iso-stage4-plan.md), **rebaselined 2026-06-01** to the gnoboot + agnos + ext4 model (the old GRUB/`vmlinuz`/`pivot_root`/squashfs framing is obsolete). D1/D2/D4 are resolved by the iron-boot arc; the live decisions are now **N1–N3** (artifact format `.img` vs `.iso` / rootfs writability / rootfs FS — recommended first cut: writable `.img` mirroring `install-usb.sh`). Packages kernel + gnoboot + userland into a distributable image. The kernel already boots iron-direct via gnoboot + USB stick today; the ISO is the *distribution* path, not a boot blocker. Closed-beta first-tester sessions run on the NUC AMD (primary); Intel (Skytech) + Pi 4 queued after AMD proves out.

---

## Maturity Arc

AGNOS capability follows a **5-stage arc** that anchors what "the next stage" means at any cycle. Orthogonal to the [Strategic Vision](#strategic-vision) (release-milestone framing) and the [Phase 13A / 13C / 16 numbering](#critical-path-to-beta) (work-area framing) — the arc is the *capability lens* above both. User-defined 2026-05-22.

| Stage | Capability content | Status (2026-06-14) | Exit trigger |
|---|---|---|---|
| **demo** | Boots to shell on iron, ext4 read-only, networking client-side. Can be *shown* working but not lived in — no state persistence across reboots. | ✅ **Exited.** MVP gate (Attempt 68 / 1.30.9 / 2026-05-15) was the demo entry; the demo→base exit trigger (1.33.x ext2/4 **WRITE**, persist-across-reboot iron-validated) fired 2026-05-25. | 1.33.x ext4 WRITE landing — **fired**. |
| **base** | Kernel solid; ext4 read+write; ark/nous package manager working end-to-end (resolve / fetch / install / remove) **on the *sovereign* path** (zugot→takumi→native `.ark`); AGNOS-side update mechanism; enough soak surface for real-workload exposure without weekly showstoppers. **⚠ ark caveat:** ark 1.0.0 is Cyrius-*ported* but its `SOURCE_SYSTEM` leg still wraps `apt-get` (Linux-host transitional, "a product of the switch") — and apt doesn't exist on agnos, so genuine on-agnos package mgmt ≡ **sovereign ark**, a **v2 long-horizon goal** that's gated on agnos first exposing the surface it binds to (FS-write ✅ / exec ✅ / HTTPS-fetch 1.45.x / the takumi self-host build surface = server-stage). Without that kernel surface, sovereign ark has nothing to run on. The 1.45.x "ark-fetch" milestone = fetch-of-native-`.ark`-over-HTTPS, not full package-mgmt-on-agnos. | **Current.** The base-defining kernel work is **iron-validated**: ext2/4 + FAT-family read+write (1.33.x/1.34.x), the FS-crash-safe stack (extent→jbd2→VFS, 1.37–1.39), and **exec-from-disk** (1.40.x through 1.40.13, iron-validated 2026-05-31 — ring-3 exec + FAT verbs with ext2 at `/`). **Shell separation** (1.41.x — recovery-only kernel REPL, agnsh runs in ring 3 from disk) is **iron-complete** (burn `14115`, 2026-06-06 — agnsh types/echoes/dispatches on archaemenid); the **1.42.x** perf+hardening arc + the **1.43.x** graphics/userland arc (execwait #37 → userland `run`; FB-console ANSI/SGR color; `fbinfo`#38/`blit`#39 framebuffer; `uptime_ms`#40/`sleep_ms`#41 timing — culminating in **DOOM rendering on AGNOS at 1.43.6**, the first real userland app: cyrius-doom 0.28.2 blits the title screen in ring 3) have landed (QEMU-validated via `doom-smoke.sh`, ride the next iron burn), with the first AGNOS-tic userland tools (`bnrmr`/`cmdrs`/`klug`/`anuenue`) on `/bin` and **agnoshi 1.4.5** (`verb_abspath` — `ls`/`ls .` see the FS) ([`iron-nuc-zen-log.md`](iron-nuc-zen-log.md) #tracker-143x-cycle). **1.44.x** (multi-threading / preemptive scheduling — schedulable agnsh `&` jobs, SMP-AP wake+park, per-proc env) is **ARC COMPLETE**, and on iron (2026-06-13/14) AGNOS reached **boot-to-shell with a live multi-command keyboard on real Zen** (xHCI keyboard-ring fix); **1.45.x** (TLS → HTTPS → `ark`-fetch) is **OPEN** — ring-3 net/entropy/clock + socket syscalls #45-#57 landed (incl. server `sock_listen#56`/`sock_accept#57`; the `ark`-fetch / package-pull foundation, a concrete step toward server maturity). Maturing over the ark/nous client cycles + AGNOS-side update. Triggers archaemenid dual-boot migration (AGNOS-primary on internal NVMe + Linux on SATA — see [`state.md`](state.md) § *archaemenid migration*). | Native installer + server ecosystem landing. |
| **server** | **agnova native installer** (AGNOS installs itself onto target hardware; install-usb.sh host-side script retires); non-desktop subsystem suite (BBS, MUD, sovereign remote-shell, web server, ark+nous server-side) + the libs they consume. **Most of "Linux's purpose" gets absorbed at this stage** — archaemenid Linux usage is predominantly server-flavored (build hosting, file serving, CLI dev, network services), so server-stage AGNOS replaces it without needing GUI work. Archaemenid Linux eviction lands at **server**, not "swallow." | **Foundation materializing.** 1.32.x server-side TCP primitives (bite A: `tcp_listen`/`tcp_bind`/`tcp_accept`) are the kernel base; **1.45.x** added the ring-3 net/socket syscall surface (#45-#57 — client TCP/UDP/ICMP **and** server `sock_listen#56`/`sock_accept#57`, the kernel inbound-TCP unlock, landed 1.45.5/.6) that userland servers consume, and the server-app tier is already real on the Cyrius side — **`agora`** (telnet BBS, 1.4.2, iron-validated) + **`cyrius-yeomans-descent`** (MUD, 1.0.1) + the network-tools family (`yo`/`dig` scaffolded). What's NOT started: the **`agnova` native installer** (the stage-defining deliverable — AGNOS installs itself, retiring `install-usb.sh`) + the **cyrius server-socket peer** (the kernel exposes `#56`/`#57`, but the cyrius stdlib `sock_listen`/`sock_accept` still fail-loud on the agnos target — the gate before any Cyrius service can `accept()`; request filed `agnos/docs/development/issues/2026-06-18-cyrius-agnos-server-socket-peer.md` + `cyrius/docs/development/issues/2026-06-18-agnos-server-socket-peer.md`) + `ark`/`nous` server-side. | aethersafha + GUI userland landing. |
| **desktop** | aethersafha (Wayland compositor — currently Pending in CLAUDE.md table) + display drivers (mabda + iGPU/dGPU) + user-facing app ports + GUI userland. Absorbs the daily-driver / GUI / browser workloads that server stage couldn't. | **Not started.** | Compat sandbox + non-native-workload absorption. |
| **swallow** | **Compat sandbox layer** — AGNOS hosts non-AGNOS-native apps (Windows binaries, Linux binaries, web apps) inside a sovereign sandbox so endusers can move to AGNOS without giving up their existing app ecosystem. Connects directly to **Phase 20 — Cross-Platform Compat Subsystem** below. Sovereignty via **universal hosting**, not eviction — AGNOS becomes the host that can run anything, removing the last reason anyone would keep a separate non-AGNOS install. | **End-state.** No fixed date; trigger is final-workload capability parity. | (Terminal — no exit.) |

**The arc is sequential.** Don't skip stages: desktop work doesn't open before server lands; swallow doesn't open before desktop lands. Stage exits map to release milestones — **rescoped 2026-06-14 to a compressed summer-2026 track** as the kernel arcs accelerated: demo→base ≈ MVP entry (✅ 2026-05-15), **reaching server base work ≈ Closed Beta (Late June / Early July 2026)**, **server→desktop ≈ Desktop completeness (mid-to-late summer 2026)**, desktop→swallow ≈ post-desktop horizon. (Was: base→server ≈ Public Beta / server→desktop ≈ v1.0 Q2 2027 — superseded; public beta now slots between the closed-beta cohort and desktop.)

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

**Opening gate** (target **Late June / Early July 2026** — rescoped 2026-06-14, gated on reaching **server base work** so the cohort lands on a server-capable base, not a bare shell):
- [x] **Boot-to-Shell MVP (13A items 1–3.5)** — ✅ Iron-validated 2026-05-15 on archaemenid (NUC AMD Beelink SER). Kernel completes full init spine → kybernet (PID 1) launches → agnoshi (`AGNOS shell v1.30.0`) prompt rendered on framebuffer. Twenty-nine attempts across three weeks of bring-up; full arc in [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md); generic process pattern in [`iron-bring-up-process.md`](iron-bring-up-process.md). **The shell prompt is visible. The base OS is real.**
- [x] **USB-keyboard input** — ✅ **typeable on iron at Attempt 68** (agnos 1.30.9). Native XHCI + USB-HID-boot driver, all 5 phases shipped across agnos 1.30.0 → 1.30.5. Root cause of the long silent-absorb arc was a cyrius-side kmode gvar-init-order bug (fixed cyrius v5.11.64), not an AGNOS-side spec gap. Historical detail: [`../archive/usb-hid-keyboard-driver-shipped.md`](../archive/usb-hid-keyboard-driver-shipped.md).
- [ ] First hardware boot session — **non-founder tester sits at the prompt**. Kernel is typeable on the NUC AMD; awaits the ISO Stage-4 cut + tester schedule.

**Phase 1 — founder sweep-test (Late June / Early July, server base):**
- [ ] **Docker AGNOS service-sweep harness** — stand up the server-stage workload suite (agora BBS / descent MUD / remote-shell / web server / `ark`+`nous` server-side) in Docker AGNOS containers and **sweep-test them myself to find the weak points** (connection floods, fuzzed input, auth-boundary, soak/leak, resource-exhaustion incl. the kernel's 8-conn TCP / 8-listener UDP caps, lock contention on agora's flock'd shared-world). Automated/founder-driven — server workloads exercise without humans at a screen, so this phase needs no external cohort. The "where are we weak" pass that hardens the server base before anyone else sits down; surfaces the P1 list. **Socket-gated — ✅ the gate is now CLEARED:** "sockets are the major hurdle to container usage" — AGNOS can only *host* networked services in a container once it can `accept()`. The client surface (#47-55) landed 1.45.0-4, and **the Phase-B server sockets `sock_listen`#56 + `sock_accept`#57 landed at agnos 1.45.5** (`tcp-listen-smoke` 2/2 host→AGNOS) — AGNOS is now container-network-capable. Plan doc: [`planning/docker-service-sweep-harness.md`](planning/docker-service-sweep-harness.md). Remaining build steps (per the plan): cyrius `CYRIUS_TARGET_AGNOS` peer for #56/#57 (hands-off, in flight) → AGNOS-in-QEMU-in-Docker boot container → harness drivers + per-service sweep matrix → findings ledger.
  > **Strategic weight — the validation surface climbs the ladder of realism: iron → QEMU → containers.** *Iron* answered "does it boot on bare metal?"; *QEMU* answered "does it run portably under virtualization?"; **containers answer "does it run where the majority of modern services actually live?"** Docker/OCI/K8s is the dominant deployment substrate in 2026 — a sovereign OS that only runs on bare metal is a curiosity; one that drops into the container ecosystem is a **participant**. Container-capability (the moment AGNOS can `accept()` over its own sockets) is therefore both the **biggest, most-realistic test surface the project has had** *and* a real **deployment path**, not just a test path. This is the strategic payoff behind the socket arc.

**Phase 2 — external testers (mid-to-late summer, at Desktop, STILL CLOSED):**
- [ ] Initial cohort: friend-network, 5–15 **external** testers — brought in at the **desktop** phase, where GUI / daily-driver workloads genuinely need humans at the screen (unlike the server sweep above)
- [ ] Selective expansion: invites only, **no public enrollment, no marketing campaign** — public beta stays deferred (see *Public Beta — DEFERRED* below)
- [ ] Cohort feedback drives hardening: bug reports, hardware-matrix gap-fill, kybernet/argonaut/agnoshi P1 issue closeout
- [ ] **DEF CON — targeting August 2027** (moved off the Aug-2026 contingency 2026-06-14): **~2 months from a summer-2026 closed beta is not enough lead time to be prepped for that crowd.** DEF CON is an expert/adversarial security audience that will hammer the sovereignty + Phase-22 parallel-PKI claims hard — showing up under-hardened is worse than not showing up. **Aug 2027 gives a full year of closed-beta hardening receipts + paper-PKI maturity before facing them.** When it lands it's the *credible introduction event* — stickers as cryptographic root-of-trust distribution, not marketing.

**Closeout** (early fall 2026):
- [ ] Cohort report consolidated; critical-bug list cleared
- [ ] Hardware matrix coverage: at least 3 different architectures booted (x86_64 NUC, aarch64 Pi 4, plus one more — Skytech or laptop)
- [ ] Public beta criteria met (or explicitly carried as known-gap)

**Gate philosophy**: closed beta is the honest "the kernel + init + shell stack runs on real iron, and humans other than the founder have sat at the prompt over a sustained selective program" milestone. Self-hosting, audit, and broad community testing are deliberately deferred to public beta — a cleaner, smaller line that ships when ready. The MVP entry proves the *base* OS is real; the summer-long program proves it's *durable* across diverse hardware and use; sovereignty of the rest of the userland against the AGNOS-kernel ABI is the next milestone.

**Cadence dependency**: opening gate is **toolchain-independent** — the kernel already builds and boots against the current Cyrius pin (in [`state.md`](state.md); held deliberately on a known-working version). The dependency reduces to *agnosticos-side work* (ISO Stage-4 cut via `iso.cyr` + first hardware boot session). The earlier framing that gated MVP on the Cyrius v6.0.x bare-metal target was conceptual residue from pre-monolith-extraction days; corrected 2026-05-12. Opening slips by week, not by month. **The summer-long program then runs independently of Cyrius cycles** — it's hardware-and-cohort-paced, not toolchain-paced. Cyrius work continues in parallel (v6.0.x active — bare-metal target + RISC-V rv64 among its gains) but does not gate the MVP ship.

### Desktop — Mid-to-Late Summer 2026 (external testers, STILL CLOSED) *(rescoped 2026-06-14; was v1.0 Q2 2027)*

The whole summer-2026 arc **stays closed beta** — public enrollment does **not** open here. Desktop is the phase that needs **a bunch of external testers** (GUI / daily-driver workloads can't be swept by automated services the way server workloads can — they need humans at the screen), but the program remains **invite-only / closed**, not public. This is the v1.0 / Phase-16 desktop-completeness content, pulled forward as the kernel arcs accelerated.

- [ ] aethersafha + display drivers + GUI userland landed (the desktop maturity stage)
- [ ] External-tester cohort expanded (still invite-only — closed, not public)
- [ ] Phase 13C — Documentation, community (closed-cohort scope)
- [ ] Consumer apps published to mela
- [ ] Sustained soak with no critical bugs

### Public Demonstrations — the base OS goes PUBLIC (games + server), while the beta program stays closed

**Public *demonstration* ≠ public *beta*.** The hands-on beta program stays closed through summer (founder sweep → external desktop testers), but the **base OS itself — with games + server functionality — can be shown PUBLICLY as demonstrations** well before public enrollment opens. Demonstrating capability is a proof / introduction move; it doesn't hand anyone a daily-driver install. The demo content is real and already shipping:

- **"It runs DOOM."** cyrius-doom renders **in-game on real Zen** (iron burn `1439`) — the visceral, universally-legible proof that a from-scratch sovereign OS is a real machine, not a slide deck. (Plus the wider games stable: encom-hits, cyrius-bb, the cyrius-* catalog.)
- **A sovereign language built from assembly up.** Cyrius — a **29 KB assembly seed** that bootstraps to a self-hosting compiler — **produced both the AGNOS kernel AND an entire ecosystem of ~100+ projects** (compiler, stdlib, libs, tools, games, servers).
- **The ecosystem is portable to any system — *save the kernel itself*.** Every Cyrius project runs cross-platform byte-identical (x86_64 / aarch64 / Apple Silicon Mach-O / Windows PE32+); only the AGNOS **kernel** is platform-bound (it boots bare metal). So the public story isn't "a toy OS" — it's "a sovereign toolchain + 100-project ecosystem that runs *anywhere*, plus a kernel it can also boot natively."
- **Server functionality demonstrates headless.** agora (telnet BBS, iron-validated) + cyrius-yeomans-descent (MUD) + a web server run as **publicly-reachable services** — a live, pokeable demonstration that needs no desktop and no tester at a screen.

This is what justifies a **public face during the closed beta**: the demonstrations *are* the public introduction; the formal public-beta enrollment (below) still trails post-summer. Aligns with the **base+server maturity stage** (summer 2026) — the games + server are demonstrable the moment the server base is swept.

> **🎯 The headline (a REAL one — true today, not aspirational; dig into it in parallel while the next engineering efforts run):**
> *"It runs DOOM — on a sovereign OS built from a 29 KB assembly seed. That seed bootstraps to a self-hosting language, which produced not just the kernel but a ~100-project ecosystem that runs byte-identical on every platform. Only the kernel is bound to the metal; everything else is portable."*
>
> **And the pace is part of the story:** ~**5–6 months** from the Cyrius kernel (2026-04-04) → boot-to-shell on iron (2026-05-15) → a server-capable, DOOM-running base with GA targeted Late Fall / Early Winter 2026. A *functional sovereign OS* — kernel + language + ecosystem, assembly-up — in roughly half a year. That's fast even **with** AI in the loop (AI accelerated it; it didn't write a sovereign OS by itself — the architecture, the from-assembly bootstrap, the sovereignty discipline are the human spine). The velocity is a legitimate, defensible headline element, not hype.
>
> This is the **public-demonstration narrative / launch headline** — a parallel **content deliverable** (feeds the agnosticos.org DOOM article + Cyrius mention in the website P0 list, the articles queue, and the eventual public introduction). Develop it alongside, not instead of, the next engineering efforts. The proof points are all shipped + verifiable (DOOM iron burn `1439`; the 29 KB seed → self-host; the cross-platform byte-identical cadence beat; the ~129-entry shared-crates registry; the ~5–6-month arc itself).

### Public Beta — DEFERRED (post-summer; formal enrollment, distinct from the public demos above)

**Public enrollment is NOT a summer-2026 milestone.** It comes *after* the closed desktop phase has proven out across the external-tester cohort. Until then the program is closed end-to-end: founder Docker-service sweep (closed-beta open) → external desktop testers (still closed). Public beta + third-party security audit + formal community enrollment slot here, post-desktop. *No fixed date — gated on the closed desktop phase clearing.*

- [ ] Closed (founder-sweep + external-desktop) phases exited cleanly
- [ ] Third-party security audit complete
- [ ] Community testing program active (formal public enrollment — the line where it stops being closed)

### True Open Public OS (General Availability) — Late Fall / Early Winter 2026 (gated on Desktop + most of the porting)

**The real public release — AGNOS as an open OS anyone runs as their actual machine — is the *furthest* milestone, NOT summer 2026.** Target: **Late Fall / Early Winter 2026** (user, 2026-06-14 — "still fast"; was v1.0 Q2 2027, pulled in ~2 quarters by the current pace). Date-targeted but still **capability-gated** on two fronts — **(1) desktop is worked out AND (2) most of the porting backlog is cleared**:

- **Desktop worked out** — the desktop maturity stage complete (aethersafha + display drivers + GUI userland), proven across the closed external-tester cohort.
- **Most of the porting done** — the Rust→Cyrius port backlog mostly cleared. This is the registry's deep-lag / pending-port tail: the newest port graduations were `ark` / `mela` / `takumi` / `yantra` (all → 1.0.0, 2026-06-18) on top of `szal` 2.0.0; **`agnova`, `hoosh`, the pre-CYML holdouts, and the rest of the not-yet-native crates** still need a "bring-down + port." (Live port status: [`planning/shared-crates.md`](planning/shared-crates.md) + the [Named Subsystems](#named-subsystems-30) Port column.) A *true* sovereign public OS can't ship a half-Rust ecosystem — GA is when the stack is overwhelmingly Cyrius-native.

So the ladder is: **public demonstrations** (base+server showcase — leads, summer) → **closed beta** (founder sweep → external desktop testers, summer, closed) → **public beta** (formal enrollment, post-summer) → **true open public OS / GA** (desktop done + porting mostly done — the open-to-everyone release, **Late Fall / Early Winter 2026**). Date-targeted but capability-gated on those two fronts.

Long-term vision: [`vision/conscious-objects.md`](vision/conscious-objects.md) — the quantum-substrate / Layer-0 horizon (post-v3.0, multi-year). Foundation governance is now [`planning/foundation-structure.md`](planning/foundation-structure.md) (promoted from vision → planning 2026-05-12). v2.0 Rust-kernel and v3.0 Cyrius-pivot vision sections were retired 2026-05-12 — both happened ahead of schedule (Cyrius kernel shipped 2026-04-04; Cyrius language already well into the v6.x line).
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
| **August 2027** *(target; moved off Aug-2026 on 2026-06-14)* | **DEF CON / Black Hat distribution.** ~$5K budget: 10K stickers + 500 SD cards + 1K quick-start cards. **Bumper-sticker-as-cryptographic-root-of-trust** — QR-encoded 29KB seed + SHA-256 chain + URL = paper signing authority. **Critical dependency**: [`Phase 22 paper-PKI verification path`](planning/parallel-pki.md) must ship before the print run is meaningful. **Aug 2027, not 2026** — ~2 months from a summer-2026 closed beta is not enough hardening lead time for an adversarial DEF CON audience; a full year of closed-beta receipts + paper-PKI maturity is the right prep window. | `agnosticos` |

**Cadence discipline (revised)**: dates are *target windows*, not strict biweekly slots. Each beat ships running software when ready. If a beat misses its target window, it goes to "next window" — not "next biweekly." The list tightens (drop beats that become irrelevant) and the windows move, but the *beats themselves* are the right work and stay on the roadmap until shipped or explicitly retired.

**Not in the cadence** (deliberately): Beta, v1.0, SY redesign, Phase 17–19 work, **Phase 20–23 empire-defense planning work** (each has its own spec, see [Strategic Vision](#strategic-vision)). Those remain on the Beta Q4 2026 / v1.0 Q2 2027 / post-public-beta track above. (Polymorphic codegen previously listed here; slotted to Cyrius v5.13.x as of 2026-04-25 — see `cyrius/docs/development/roadmap.md`.)

**Honesty note**: the rust/linux-era cadence assumed the project would be near-shipping in May-August 2026. The cyrius/agnos-era reality is that the MVP (boot-to-shell on iron) is what closed-beta gates on, and the cadence beats above are *public-beta-era ship work* — they ride on top of a working MVP, not in parallel with one. The fall 2026 anchor is what reflects that sequencing honestly.

---

## Status

Shipped state is **not tracked here** — this roadmap is forward-facing. Current truth:

- **Kernel / Cyrius / per-repo versions + cycle state** → [`state.md`](state.md)
- **Cyrius language milestone history** → `cyrius/CLAUDE.md` + `cyrius/CHANGELOG.md`
- **Port dependency chain** → all critical-path ports (agnostik → agnosys → libro → argonaut → kybernet → kernel) are **Done**; the live per-repo port-status table is the [Named Subsystems](#named-subsystems-30) table below + [`state.md`](state.md). Monolith extraction completed 2026-04-01 ([sprint-history.md](sprint-history.md)).

**Open KPIs** (the forward ones):

| Metric | Target | Status |
|--------|--------|--------|
| Boot-to-Shell on Hardware (MVP) | Yes | ✅ **Achieved** — Attempt 68 / agnos 1.30.9 / 2026-05-15 |
| OS Independence (full self-hosting) | Yes | Pending — Public Beta scope (Phase 13A items 4–7) |
| Boot Time | <10s | ✅ **3.2s** kernel+init, ~80ms init→event loop |

---

## Active Work

### Phase 13A — OS Independence (Public Beta scope)

The MVP half of this phase — **boot → typeable shell on iron** — is **done** (Attempt 68 / agnos 1.30.9 / 2026-05-15; full arc in [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md)). The immediate next gate is the **ISO Stage-4 cut** (top-matter + [`iso-stage4-plan.md`](iso-stage4-plan.md)), then the first non-founder tester session. The remaining, forward half is **OS Independence** (Public Beta) — self-hosting:

| # | Item | Status | Notes |
|---|------|--------|-------|
| 4 | LFS Stage 1: bootstrap-toolchain end-to-end | Deferred (Public Beta) | Build cross-compiler from source tarballs. Not MVP — pre-built binaries ship in the Stage-4 ISO. |
| 5 | LFS Stage 2: build base system in chroot | Deferred (Public Beta) | ark-build the base recipes. |
| 6 | LFS Stage 3: build AGNOS userland on target | Deferred (Public Beta) | Cyrius-compiled binaries inside AGNOS; exercises the userland ↔ AGNOS-kernel ABI bridge end-to-end. |
| 7 | Selfhost-validate passes all phases | Deferred (Public Beta) | `selfhost-validate --phase all` on the booted ISO. |
| 8 | CI automation | In progress | GitHub Actions — supports MVP and beyond. |

Self-hosting (items 4–7) is explicitly post-MVP — see [Public-Beta path](#public-beta-path-q4-2026--phase-13a-items-4-7). **NOT a gate**: the Cyrius v6.0.x bare-metal target — the kernel already builds + boots against the current Cyrius pin ([`state.md`](state.md)); language and kernel are separately-releasable subsystems.

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

**1.41.x userland-agnsh on iron — ✅ RESOLVED (burn `14115`, 2026-06-06)**
The 1.41.x shell-separation arc moved the interactive shell to userland `/bin/agnsh` (ring 3); the native in-kernel shell is now a recovery REPL. Burn `14115` typed `help`/`mode`/`version` with echo + correct dispatch on archaemenid past a real DHCP lease — the arc is iron-complete.
- [x] **Iron-validated the PMM fix** — `14115` reached `[ASSIST] >` and typed cleanly (the 1.41.12 top-down `pmm_alloc` cleared the ~50%-of-boots banner freeze; 1.41.15 line-disciplined `read(0)` fixed the typing).
- [x] **Deeper page-mapping fix** — landed at **1.42.2** (direction B: `proc_create_address_space` leaves the mmap arena not-present instead of present-supervisor; QEMU repro 0 ring-3 `#PF`/20). The rare SYSCALL-path RBP smash was fixed at **1.42.3** (0 smash/40). → [issue](issue/2026-06-04-agnsh-ring3-pf-pmm-fragmentation.md)
- [x] **Syscall-path RBP frame-smash** — ✅ fixed at **1.42.3** (0 smash/40; see the prior line). No longer a separate open bite.
- [x] **USB-HID keyboard input on iron** — ✅ **RESOLVED on real Zen (2026-06-13/14).** Not "prompt but no echo" — archaemenid types a **live multi-command keyboard** at the agnsh prompt. archaemenid is USB-keyboard-only (no PS/2, IRQ1 is dead code); the bug was an xHCI keyboard transfer-ring **EP stall** (the ring was armed 1-TRB-deep, emptied during the IF=0 command-execution gap, and the controller stalled the EP). Fixed at **agnos 1.44.25** (ring armed 16-deep + `hid_kbd_kick()` read-entry doorbell restart). The earlier IRQ1/PIC/SMM theories (burns 3-5) chased dead code. → [[project_archaemenid_keystroke_path_usb_only]].

### Engineering Backlog

*Completed items archived in [sprint-history.md](sprint-history.md).*

| # | Priority | Item | Notes |
|---|----------|------|-------|
| B1 | High | Self-hosted CI runners on AGNOS | Replace Arch/Ubuntu runners with AGNOS itself |
| B2 | High | RPi4 hardware boot test | Firmware blobs added, needs physical validation |
| S1 | High | CVE-2026-31431 (Copy Fail) — host kernel cleanup + cross-repo audit | AF_ALG `algif_aead` + `splice()` LPE in mainline Linux 2017→. AGNOS-native kernel **structurally immune** (no socket/splice surface; verified against the syscall-table invariant — anchored on the absent socket/splice surface, not table size or patch level). Local repos clean: sigil, agnodrm, phylax — no AF_ALG refs. **Do**: (a) host bootstrap defconfigs in `agnosticos/kernel/{6.6-lts,6.x-stable,7.0-devel,configs}` — pin `# CONFIG_CRYPTO_USER_API* is not set` (HASH/SKCIPHER/AEAD/RNG); (b) audit when cloned: kybernet, libro, kavach, shakti, aegis, t-ron, argonaut, ark, agnostik, bote, daimon, hoosh. Live tracking in [`state.md`](state.md#cve-2026-31431-copy-fail-cleanup--audit). |
| R2 | High | Update scripts/CI for zugot | 16 scripts/CI/config files still reference local `recipes/` paths |
| C1 | ✅ Done 2026-06-06 | De-Linux the boot pipeline (sovereign initramfs / retire cpio) | Boot is gnoboot → sovereign agnos kernel (no Linux); the GRUB/multiboot2/Linux-initramfs cruft is now retired. **Done**: (i) `install-media.sh` ships sovereign `\boot\initramfs` only if present (purges any stale Linux `cpio.gz` off the ESP; gnoboot makes it optional — the kernel mounts agnos-fs off NVMe directly). (ii) **Deleted** `scripts/src/install.cyr` (a Linux `cpio.gz` + GRUB-menuentry installer, fully orphaned — never a build target, no CI ref, output consumed by nobody; provisioning is owned end-to-end by `install-media.sh` + gnoboot, so the kernel needs no initramfs and there is nothing for a sovereign rewrite to emit). (iii) **Deleted** `scripts/test-uefi-qemu.sh` (pre-gnoboot GRUB `module2 /boot/initramfs.cpio.gz` harness) — its intended sovereign replacement already exists: `gnoboot/tests/ovmf_smoke.sh` (gnoboot EFI under OVMF) + `scripts/qemu-fb-smoke.sh` (full gnoboot→kernel Path-C handoff under OVMF). (iv) Purged the stale `scripts/build/` Linux artifacts (`initramfs.cpio.gz`, the GRUB `stage/` tree, `test-uefi*.img`/`.fd`, the Linux `rootfs/` skeleton). (v) `scripts/src/boot.cyr`'s `grub-mkrescue`/`xorriso` checks are **kept** — those are forward Phase-13A ISO-assembly tools, not boot-path cruft. |
| E1 | Medium | ESP32 agent source repo | Recipe done, MQTT bridge done. Pending: source repo + firmware |
| V1 | Stretch | t-ron voice — contract Bruce Boxleitner | Direct voice-synthesis contract with the actor *infamous* for the role; permanently hardens t-ron's character identity to its namesake. **The play — the argument is the asset**: AGNOS ships a Tron that actually *exists* — t-ron is a living, executing MCP security monitor that demonstrably fights for users in the real tool layer. Disney's Tron is fiction; t-ron is shipped software. The substantive argument that move makes in public: *"the real version of this is now working software, not a 1982 film."* That argument is the asset — it lands the moment the cultural shift starts, and Disney litigating against it is them defending fiction against a working artifact (i.e. losing the argument). Disney's natural incentive then flips to **alignment** ("Tron is real"), not litigation. Boxleitner's voice/likeness is licensed directly (his to grant). Any litigation pressure is downstream noise, not the substance of the move. **Core idiom** — *"We fight for the users"* is t-ron's operating ethic, the line *made real*: it ties directly to the subsystem's job (MCP security monitor — protect the user from bad actors in the tool layer). **Capture corpus**: the core idiom is the non-negotiable seed; targeted phrase-set captured for inference seeding; everything else naturally generated by the model, no script-reading sessions. Iterative — once natural cadence locks, additional phrases / word recitations can be captured to refine the synthesis. **Reach goal**: Boxleitner's sign-off and active participation — the actor publicly endorsing the subsystem named in his role's honor, on par with the back-pocket-ally tier. **Sequencing**: post-V1, after first-tier ally relationships land. Outreach rides the public AGNOS news cycle (booted OS + DEF CON receipts + articles in circulation) so the conversation isn't cold — momentum opens the door. Budget + outreach path TBD. |

Repo-specific backlog items tracked in their respective repos.

---

## Post-MVP — forward queue

> MVP iron-validated 2026-05-15; the kernel boots to a **typeable** shell on real hardware. The post-MVP hardening arcs — **1.30.x** keyboard, **1.31.x** storage (NVMe / AHCI / USB-MS / RAM-disk / GPT + ext2/4 read), **1.32.x** networking (r8169 + DHCP, iron-COMPLETE), **1.33.x** ext2/4 WRITE, **1.34.x** FAT-family, **1.35.x** comms-substrate (DNS/ICMP/TCP-hardening/NTP/mmap/RTC), **1.36.x** byte-identical refactor, **1.37.x** ext4 extent-allocation, **1.38.x** jbd2 journaling, **1.39.x** VFS generic-write lift, **1.40.x** exec-from-disk + VFS mount routing — are all **shipped + (mostly) iron-validated** (the 1.37–1.40 crash-safe + exec arc iron-validated on the `13810`/`1409`/`14013` burns through 1.40.13). The **1.41.x — shell separation** arc (agnos roadmap § *Shell Separation Arc*) is **iron-complete** — burn `14115` (2026-06-06) typed `help`/`mode`/`version` with echo + correct dispatch on archaemenid (the kernel shell is now a recovery-only REPL; agnsh runs in ring 3 from disk). The **1.42.x** cycle landed on top: kernel perf (heap-zeroing −50%) + the three carry-forward hardening fixes (page-map / RBP-smash / reap) + the userland **FS-verb environment** (agnoshi 1.4.2 — `ls`/`cat`/`cp`/`mv`/`rm`/… as builtins, verb→ext2 roundtrip iron-path-validated). The **1.43.x** arc then added the **graphics/userland path**: `execwait` #37 (ring-3 blocking exec → un-gated the agnsh `run` builtin), the **FB-console ANSI/SGR/CSI interpreter** (`fb_ansi_feed` in `fb_console.cyr` → 16/256/24-bit color incl. the anuenue rainbow), and a kernel line-discipline **EOF/Ctrl-D** path so stdin filters can terminate; the first AGNOS-tic userland tools (`bnrmr`/`cmdrs`/`klug`/`anuenue`) bank onto `/bin`, **agnoshi 1.4.5** lands `verb_abspath` (`ls`/`ls .` resolve against the agnos VFS — QEMU-validated), and **anuenue 1.1.1** gains a positional-text mode (`run /bin/anuenue AGNOS`); the graphics path then completed — `fbinfo`#38/`blit`#39 (kernel-mediated ring-3→FB) + `uptime_ms`#40/`sleep_ms`#41 (frame clock) — and **DOOM renders on AGNOS** (agnos 1.43.6 / cyrius-doom 0.28.2): the first real userland app, exec'd from disk in ring 3, blitting the title screen. All QEMU-validated (`doom-smoke.sh` PASS) — and **DOOM now renders in-game on real Zen** (iron burn `1439`). The **1.44.x — multi-threading / preemptive scheduling** arc then landed (schedulable agnsh `&` background jobs, `sched_yield`#44 + idle-deprioritization for bg ×2.3, SMP-AP wake+park keeping the single-core invariant, per-process env, kernel-scaled blit) — **ARC COMPLETE** (the namesake IF=1-preemptive-agnsh-on-iron deferred to 1.46.x pending per-process kernel stacks). **On iron (2026-06-13/14): boot-to-shell with a live multi-command keyboard on real Zen** — the xHCI keyboard-ring fix held; SMP-AP wake confirmed; r8169 warm-reboot DHCP fixed. The **1.45.x — TLS → HTTPS → `ark`-fetch** arc is **OPEN** (cycle-opened 2026-06-14): the kernel exposed the ring-3 net/entropy/clock syscalls **#45-#57** (`getrandom`, `time_unix`, TCP sockets `sock_connect`/`send`/`recv`/`close`, UDP `udp_bind`/`send`/`recv`/`unbind`, `icmp_echo`, **+ server `sock_listen#56`/`sock_accept#57`** — Phase B inbound-TCP, landed 1.45.5/.6) that cyrius `tls_native` + the network-tools family bind to — **all of Phase A (`yo`/`dig`/`whirl`) is kernel-unblocked**; the cyrius **client-band** peer landed (v6.2.3 — `dig` resolves a real domain on AGNOS), while the **server-socket peer** (cyrius `sock_listen`/`sock_accept` still fail-loud on the agnos target) is the open request — `agnos/docs/development/issues/2026-06-18-cyrius-agnos-server-socket-peer.md` + `cyrius/docs/development/issues/2026-06-18-agnos-server-socket-peer.md`. Per-cut detail lives in the agnos CHANGELOG + [`state.md`](state.md) + the iron logs, not here. What remains forward in this queue:

### ISO Stage-4 cut + distribution (queued)

The boot pipeline currently flashes via `install-usb.sh` directly. ISO Stage-4 cut packages the kernel + gnoboot + userland into a distributable live image (per [`iso-stage4-plan.md`](iso-stage4-plan.md)). Was a pre-MVP gate; now the *distribution* gate — the typeable shell + networking + storage trio + read+write filesystems are all in place, so the ISO is the remaining step before the first non-founder boot session. (No fixed version label — the original `1.33.x` slot was reabsorbed by the ext2/4-WRITE arc; this lands when the cut is scheduled.)

### Device-layer carry-forwards (deferred — no active slot)

The 1.35.x comms-substrate cycle (DNS / ICMP / TCP-hardening / NTP / `mmap` / RTC) is **shipped + QEMU-validated** — detail in the agnos CHANGELOG, not here. The cyrius-side destinations it feeds (**TLS** → HTTP client, **PIE** → full-binary KASLR) are driven with the cyrius agent. What stayed deferred out of that cycle:

- **Legacy virtio-net interface** — **BACK-BURNERED**. A cap-list-absent BAR0-I/O + `QUEUE_PFN` 0.9.5 fallback only triggers under non-default `disable-modern=on` (default QEMU `0x1000`/`0x1041` is already covered by the modern driver), and [`virtio-net-legacy-layout-audit.md`](prior-art/virtio-net-legacy-layout-audit.md) § "Post-implementation update" documents an **unidentified TX-handler failure** on the legacy path that was never root-caused (the modern rewrite was the workaround). Not iron-relevant (archaemenid uses r8169); QEMU-completeness only — diagnose when the networking surface is exercised more.
- **Plug-and-play / hot-add device support** — USB hub topology + hot-add; also fixes the archaemenid USB-optical cold-boot quirk ([[project_archaemenid_usb_optical_pre_boot_quirk]]) and unblocks optical-via-USB-MS (SCSI MMC profile). See the "deferred to plug-and-play cycle" note in the 1.31.x storage history.

### Parallel cycle work (no version pin — opportunistic)

These can land in any patch without blocking a gated cycle:

- **agnos kernel hardening** — single-line correctness fixes surfaced during iron burns; SMP AP-wakeup IPI gating remains hardware-in-the-loop-gated.
- **gnoboot** — touched only as iron burns surface bootloader-side bugs; otherwise stable per the "lean is good" stance.
- **Cyrius bugs filed during iron work** — surfaced to the user / cyrius repo, which handles its own cycle (per [[feedback_cyrius_hands_off]]).
- **AMD Zen Quiet-Boot scanout residue** *(parked)* — `fb_console` renders cleanly when BIOS quiet-boot is **OFF** (VGA-spec fallback) but bands glyphs when **ON** (GOP framebuffer at native res). MVP-unblocked via the VGA-spec path; closed-out 2026-05-20 with the bug surviving (both GOP SetMode lever forms falsified). Resumption options: HUBP `clear_tiling` port OR a shadow-buffer FB-console eval. Pin: [[project_amd_zen_scanout_residue]].
- **kii → chitra adoption** — kii 1.0.1 still ships its own 813-line `src/png.cyr`; the **chitra** 0.1.0 decoder (forked out of that core 2026-06-19 so **mabda** could consume it for `gpu_texture_load_png`) is the shared image-decode home now. Adapt kii to a `[deps.chitra]` dep and drop the in-repo decoder, closing the second-consumer loop (mabda→chitra is already live). **Verify capability parity before cutover**: chitra 0.1.0 is PNG depth-8 / non-interlaced only (0.2 adds depth 1/2/4/16 + Adam7) — kii must not regress what its own decoder already handles. Opportunistic; no cycle gate.

### Public-Beta path (Q4 2026 — Phase 13A items 4-7)

Self-hosting LFS-style work moves from "Phase 13A future" to "Public Beta scope" once the closed-beta cohort program has produced hardening receipts across multi-architecture hardware. **Items 4–7 of Phase 13A** below remain the public-beta deliverable; the iron-validated MVP doesn't shift that scope — it just clears the runway for the program that justifies running it.

---

## Pre-Beta

### Phase 13B — Arch-Neutral Boot Pipeline

**Gate**: v5.6.x optimization arc closed through v5.8.x; O5/O6 audit closed in v5.9.x.
**Precedes**: Cyrius v6.0.x RISC-V rv64 + bare-metal — this neutralization landed *during* the v5.11.x stdlib annotation arc so v6.0.x opened clean.
**Rationale**: Cyrius sequencing settled to v5.6.x (optimization arc) → v5.7.x (sandhi-fold + cyrius-ts) → v5.8.x (audit closeout + language vocabulary + stdlib foldins) → v5.9.x (catchup + O5/O6 close) → v5.10.x (typed-simd ABI + REAL TYPE SYSTEM + struct-byval ABI — three completed arcs in 5 days) → **v5.11.x (stdlib annotation arc + consumer-issue closeout, closed at 5.11.69)** → **v6.0.x (RISC-V + bare-metal — active)**. Agnos already did the multi-arch split at v1.1.0 (`kernel/arch/x86_64/`, `kernel/arch/aarch64/`, `kernel/core/`, `kernel/user/`). The gap is that everything downstream of boot still carries x86_64/aarch64-shaped assumptions. Neutralizing during v5.11.x meant v6.0.x RISC-V + bare-metal slot in as "add a target," not "rewrite the pipeline."

**Genesis-repo items (owned here):**

| # | Item | Notes |
|---|------|-------|
| 1 | `scripts/boot.cyr` arch detection + per-arch branch tables | Cross-compilation flag routing |
| 2 | ISO pipeline Stages 1–4 arch-aware | Stage output keyed on target triple |
| 3 | `bootstrap-toolchain.sh` cross-arch | x86_64 / aarch64 / riscv64 / bare-metal source tarball builds |
| 4 | `build-order.txt` per-arch gates | Failing arch doesn't block others |

**Downstream sweep (tracked in respective repos):**
- **Must-touch (boot path)**: agnos, kybernet, argonaut, agnodrm (was agnosys), sigil
- **Should-touch (build/packaging)**: ark, nous, zugot, agnova, takumi
- **May-touch**: phylax, shakti, ai-hwaccel, seema

**Target**: complete during the Cyrius v5.11.x stdlib annotation arc, before v6.0.x opened RISC-V + bare-metal. The optimization-arc baselines re-baselined across v5.6.x → v5.10.x; O5/O6 audit closed in v5.9.x.

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
| 14 | AMD NUC devbox (Ryzen 7 5800H, Radeon Vega/Cezanne) | x86_64 | Primary dev environment | **Active** — daily-driver dev box; covers AMD CPU (Zen 3) + `amdgpu` driver stack (integrated GCN/Vega). **Closed-beta MVP first-hardware-boot target**: open 2TB SSD on this box gets AGNOS installed via the sovereign chain — gnoboot (ESP `BOOTX64.EFI`) + agnos kernel + ext4 agnos-fs on NVMe, staged by `install-media.sh` (USB) today, native `agnova` installer later. No GRUB, no Linux initramfs (per Phase 13A item 3.5). |
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

**mabda status (not on critical path)**: mabda is at **3.4.0** — past GA and actively exposing the GPU surface attn11 consumes (see the Phase 17 note below), with the stdlib fold still pending. The GPU foundation layer is in place ahead of the per-vendor native work. mabda is *not* the bottleneck on this cadence; Cyrius 6.x is.

**Honest grind expectation**: the **NVIDIA (4.0) and Apple GPU (6.0)** slots are the multi-major **tough-time** efforts — closed-source stacks where the bench/rental/partnership tooling above is necessary but not sufficient. AMD (3.0) and Intel Arc (5.0) are the tractable wins that keep the cadence moving while the heavy lifts grind. If a heavy-lift slot slips, expect it to slip into the *following* major rather than blocking the easier ports — preserve the rhythm, don't stall the train on one vendor.

**Front-load Intel Arc as the pressure-release valve**: a discrete Arc card runs **$300–500** — cheap enough to acquire ahead of its scheduled 5.0 slot. If NVIDIA (4.0) starts heading into multi-month grind territory, promote Intel Arc forward into that major and slot NVIDIA back. Cadence rhythm is preserved (a tractable native port still ships), the grind gets another major of bench time, and the cheap acquisition pays for itself by removing schedule risk on the heavy lift. Either buy a dedicated card or do the planned Arc swap on the Skytech (row 12, upgrade vectors) earlier than scheduled.

**NVIDIA via PTX-direct — investigate as the compute-side wedge (post-Cyrius-6.x)**: the NVIDIA (4.0) heavy lift splits into two surfaces — **display** (closed-source mode-setting, the genuinely multi-year clean-room/partnership problem) and **compute** (running kernels on the GPU for inference/training). The compute surface has a documented escape hatch: **PTX (Parallel Thread Execution)**, NVIDIA's virtual-ISA / IR layer that sits below CUDA-C and above the per-architecture SASS the driver JITs. PTX is **publicly specified** (NVIDIA's own ISA — *not* the CUDA-C frontend), which means a sovereign Cyrius backend could emit PTX directly and hand it to the GPU through the userspace driver/`ptxas` path **without inheriting the CUDA-C/cuDNN closed stack**. Prior art: **DeepSeek** (the Chinese lab, early 2025) hand-wrote PTX to bypass CUDA-C overhead for training — concrete evidence the layer is a viable, performance-positive target, not just a fallback. This aligns directly with the **mabda native theme** — mabda is the sovereign GPU foundation; a PTX emit path is the NVIDIA-compute leg of it, parallel to RDNA ISA emit for AMD (3.0) and Xe for Intel (5.0). **The attn11 payoff**: attn11 is already a from-scratch trainer on raw `f64` arrays (forward + backprop + Adam, no BLAS/autodiff) — giving it a **PTX codegen target** would move its training/inference loops onto NVIDIA silicon natively, turning it into the reference proof that the sovereign stack can train *on the GPU*, not just CPU. That feeds straight into **Phase 17 (Local inference optimization)** — a PTX backend is the highest-leverage path to real local inference/training throughput on the most-common consumer accelerator. **Scope honesty**: PTX-direct solves *compute*, not *display* — it does not retire the NVIDIA display grind, and it still rides the userspace-driver/kernel-module boundary (the kernel-side NVIDIA module remains the hard, partnership-gated part). But it lets the AI workload land on NVIDIA hardware **before** the full native display port, which is the order that matters for inference/training users. Gated on Cyrius 6.x (codegen-backend bandwidth) like the rest of the native sequence; investigate the PTX spec + `ptxas`/driver-API surface during the AMD-3.0 window so the path is scoped when the NVIDIA major opens. Cross-ref: `mabda`, `attn11`, `hoosh`, `ai-hwaccel`, Phase 17.

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

**Why this preserves the structural-immunity argument**: the CVE class that the sovereign syscall surface excludes (e.g. CVE-2026-31431 Copy Fail) requires the vulnerable syscall to *exist in the kernel*. Since the kernel never absorbs foreign ABIs, the bug class stays unreachable for AGNOS-native processes. Foreign binaries run with Linux-grade risk, audibly tagged, sandboxed by default.

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

**Six-layer defense** (mirrors agent-injection-defense pattern): L1 TLS fingerprint normalization (cyrius stdlib `tls.cyr`); L2 traffic shape normalization (transport-policy crate — home TBD; the netns/transport bits formerly imagined in `agnosys` were parked post-v1 in the 2026-06-19 agnodrm decomposition, so this layer needs a re-homed owner when Phase 21 opens); L3 pluggable transports (obfs4 / meek / snowflake); L4 domain fronting / decoy routing (opt-in advanced); L5 mesh fallback via `kula` (when fully censored); L6 steganographic channels (last-resort low-bandwidth). Failure of any single layer doesn't surface AGNOS to the network.

**Two principles, never collapsed**: AGNOS network normalization grows to match shifting mainstream browser fingerprints — never to become its own distinctive fingerprint. Pluggable transports are exceptional, not default. The wire-layer invisibility is paradoxical-but-durable sovereignty: AGNOS-at-the-OS-layer requires AGNOS-at-the-network-layer to be invisible.

**Phasing**: substrate (cyrius stdlib TLS) → L1 fingerprint normalization → L2 shape normalization → L3 transports → L5 mesh → L4/L6 advanced. Foundation already shipped in cyrius (stdlib TLS); the agnosys-side network bits were parked in the 2026-06-19 agnodrm decomposition (re-home TBD per the L2 note above). Explicit fingerprint-target work begins post-public-beta.

### Phase 22 — Parallel PKI (parallel to closed beta, paper-rooted trust)

**Spec**: [`planning/parallel-pki.md`](planning/parallel-pki.md) — full design spine.

**Commitment**: AGNOS ships with a **parallel trust chain rooted in physical artifacts** — the 29KB seed + SHA-256 chain distributed on bumper stickers, SD cards, and QR-encoded paper. The physical artifact *is* the signing authority. Any AGNOS install can verify any AGNOS-signed thing against the root without internet, without commercial CA cooperation, without any rented infrastructure. The empire cannot revoke a sticker.

**Architecture**: 29KB seed + Ed25519 root pubkey + SHA-256 chain header on physical media. Sub-keys (per-project, per-build) chain forward to leaf signatures via sigil. Commercial CAs serve as **opportunistic cross-signing bridges** for browser compatibility — never as the load-bearing trust. Even if every commercial CA refused AGNOS tomorrow, AGNOS continues to verify its own artifacts.

**Two principles, never collapsed**: parallel PKI is always the load-bearing trust; commercial CA bridge is convenience layer. Even if 100% of users had commercial-CA-trusted browsers, AGNOS still verifies internally against the paper root. If the bridge ever becomes required, the empire wins by revoking the bridge.

**DEF CON (now targeting Aug 2027) cadence beat depends on Phase 2** of this spec — the sticker distribution event is meaningful only if any AGNOS install can actually verify against the printed root. Phase 2 (verification path) must ship before the sticker print run is meaningful — that's the critical dependency. (The Aug-2026 slot was dropped 2026-06-14: ~2 months from the summer closed beta is not enough prep for the DEF CON crowd.)

**Phasing**: sigil substrate (✅ shipping) → parallel-PKI verification path (closed-beta scope) → cross-signing infrastructure → public artifact distribution (DEF CON **Aug 2027**) → print-at-home tooling → mirror network → key rotation ceremony.

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

All subsystems are standalone repos at `/home/macro/Repos/{name}/`. **Versions intentionally omitted** — they drift fast; live per-repo versions + Cyrius pins live in [`state.md`](state.md) + [`planning/shared-crates.md`](planning/shared-crates.md). The Port column flags only what is **not yet** Cyrius-native (the forward signal); everything else is ported (✅) or Cyrius-native.

| Name | Role | Repo | Port |
|------|------|------|------|
| **agnos** | AGNOS kernel | `MacCracken/agnos` | Native |
| **cyrius** | Sovereign compiler | `MacCracken/cyrius` | Native |
| **kybernet** | PID 1 binary | `MacCracken/kybernet` | ✅ |
| **argonaut** | Init system (library) | `MacCracken/argonaut` | ✅ |
| **agnodrm** | Device / DRM model (udev + DRM/KMS) | `MacCracken/agnodrm` | ✅ — was `agnosys`, decomposed 2026-06-19 (trust→sigil, security/mac/audit→kavach, pam→aegis, logging→sakshi, syscall layer→cyrius) |
| **agnostik** | Shared types library | `MacCracken/agnostik` | ✅ |
| **sigil** | Trust verification & crypto | `MacCracken/sigil` | ✅ |
| **libro** | Audit chain | `MacCracken/libro` | ✅ |
| **hoosh** | LLM inference gateway | `MacCracken/hoosh` | ✅ |
| **avatara** | Divine archetype overlay | `MacCracken/avatara` | ✅ |
| **ai-hwaccel** | GPU detection | `MacCracken/ai-hwaccel` | ✅ |
| **kavach** | Sandbox execution | `MacCracken/kavach` | ✅ |
| **abaco** | Math/number theory | `MacCracken/abaco` | ✅ |
| **bote** | MCP core | `MacCracken/bote` | ✅ |
| **t-ron** | MCP security monitor | `MacCracken/t-ron` | ✅ |
| **daimon** | Agent orchestrator | `MacCracken/daimon` | ✅ |
| **agnoshi** | AI shell | `MacCracken/agnoshi` | ✅ |
| **hadara** | Culture modeling | `MacCracken/hadara` | Native |
| **shravan** | Audio codecs | `MacCracken/shravan` | ✅ |
| **mabda** | GPU foundation | `MacCracken/mabda` | ✅ — pre-GA soak before stdlib fold |
| **sankoch** | Lossless compression | `MacCracken/sankoch` | ✅ |
| **itihas** | History/versioning | `MacCracken/itihas` | ✅ |
| **bsp** | BSP geometry library | `MacCracken/bsp` | ✅ |
| **cyrius-doom** | DOOM engine | `MacCracken/cyrius-doom` | Native |
| **ark** | Unified package manager | `MacCracken/ark` | ✅ |
| **nous** | Package resolver | `MacCracken/nous` | ✅ |
| **phylax** | Threat detection engine | `MacCracken/phylax` | ✅ |
| **shakti** | Privilege escalation | `MacCracken/shakti` | ✅ |
| **hisab** | Higher math | `MacCracken/hisab` | ✅ |
| **owl** | `cat`/`bat` replacement | `MacCracken/owl` | Native |
| **vyakarana** | Source-code grammar / tokenizer | `MacCracken/vyakarana` | Native |
| **bhava** | Emotion/sentiment | `MacCracken/bhava` | **Pending** |
| **takumi** | Package build system | `MacCracken/takumi` | ✅ (1.0.0 — Rust→Cyrius port parity reached 2026-06; `rust-old/` now reference-benchmark only) |
| **aegis** | System security daemon | `MacCracken/aegis` | ✅ |
| **aethersafha** | Desktop compositor | `MacCracken/aethersafha` | **Pending** |
| **mela** | Agent marketplace | `MacCracken/mela` | ✅ (1.0.0 — full Rust→Cyrius port 2026-06-17, 492 parity tests; ark consumes `dist/mela.cyr`) |
| **agnova** | OS installer | `MacCracken/agnova` | **Pending** |
| **seema** | Edge fleet management | `MacCracken/seema` | **Pending** |
| **samay** | Task scheduler | `MacCracken/samay` | **Pending** |
| **cyim** | Sovereign text editor (VIM-inspired) | `MacCracken/cyim` | Native |
| **bazaar** | Community package repo | `MacCracken/bazaar` | — |

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
| **19** | Computational architecture | `MacCracken/murti`, `MacCracken/agnodrm`, `MacCracken/ai-hwaccel` |

**Multimodal ML substrate** (vision + audio model frontends built on the attn11 transformer core) underpins Phases 17–18 — forward design + reference map in [`planning/multimodal-substrate.md`](planning/multimodal-substrate.md). attn11 reaching v1.0 fired the attn11→libs extraction trigger; the gating new primitives are `conv2d`/`conv1d` fwd+bwd and a sovereign FFT/mel frontend.

> **GPU unblocked (2026-06-19): mabda 3.4.0 now exposes the GPU surface attn11 needs** to move its training/inference loops off CPU — the near-term realization of the mabda-native-compute theme (the PTX-direct NVIDIA leg below stays Cyrius-6.x-gated). The GPU move is **build-first**: attn11 consumes mabda's surface **directly**; a rosnet GPU-backend — or any new GPU/tensor lib — is **deferred** until the path is proven AND a 2nd consumer surfaces (the prove-inline-then-extract doctrine that produced chitra←kii / darshana←cyim / the rosnet+tyche CPU extraction). Don't pre-scaffold a rosnet-GPU-backend or route attn11's GPU work through rosnet first.

### Future Shared Crates — Demand-Gated

| Domain | Trigger | Likely Consumers | Priority |
|--------|---------|------------------|----------|
| **sandhi** (सन्धि — *junction, connection, joining*) | Service-boundary layer — shared HTTP/TCP/TLS + service discovery. Like sakshi for services. Absorbs `lib/http_server.cyr` extraction; composes `lib/http.cyr`, `ws.cyr`, `tls.cyr`, `json.cyr`, `net.cyr` into full-featured client patterns. **Folded into Cyrius stdlib at v5.7.0 per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md); sandhi repo entered maintenance mode.** Pattern set the precedent for vani-fold (v5.8.0) and niyama-fold (v5.9.0). | vidya, hoosh, ifran, daimon, mela, yantra | **Done — shipped v5.7.0** |
| **kula** (कुल) | Family/clan mesh — peer-to-peer identity, contact sharing, device fleet, shared storage. Depends on: sigil, bote, patra, seema, kavach. | Every family running AGNOS | High (post-beta) |
| ~~**sit** (smriti / स्मृति — memory)~~ | ~~Sovereign version control — git replacement. Deps: sankoch (compression), sigil (crypto), patra (storage).~~ **Shipped v1.0.1** — graduated to v1.0+ Binaries (see [`shared-crates.md`](planning/shared-crates.md)); consumed by owl's VCS gutter (1.4.0). | AGNOS-wide | **Done — shipped v1.0.1** |
| **Geography / GIS** | joshua terrain, edge fleet, raasta pathfinding | joshua, kiran, raasta, nazar | Medium |
| **Music theory** | shruti or 3rd consumer needs shared scales/rhythm | shruti, naad, jalwa, kiran | Medium |
| **Multimodal ML substrate** (sight + hearing) | attn11 v1.0 fired the attn11→libs extraction trigger; `conv2d`/`conv1d` fwd+bwd + a sovereign FFT/mel frontend are the gating primitives. Design + references: [`planning/multimodal-substrate.md`](planning/multimodal-substrate.md). | attn11→libs, hoosh, murti, daimon, mela; drishti, shravan/naad/dhvani | Medium (post-beta; substrate-gated) |
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

*Last Updated: 2026-06-19 (ark-sovereignty caveat added to the base maturity row — ark 1.0.0 is Cyrius-ported but its `SOURCE_SYSTEM` leg still wraps apt-get (Linux-host transitional); apt is structurally dead on agnos, so on-agnos package mgmt ≡ sovereign ark = a v2 long-horizon goal gated on agnos exposing the surface it needs (rides the kernel-works path). Also: drift sweep — `agnosys`→`agnodrm 1.4.4` in Named Subsystems table + Phase 13B boot-path sweep + Phase 19 + Phase 21 L2/phasing notes, reflecting the 2026-06-19 decomposition; mabda `3.0.0-rc.2`/`3.3.0`→`3.4.0` in Phase 13H + Phase 17 note; header date synced to footer. Historical port-chain refs (agnostik→agnosys→… extraction order) left as-is — accurate as history). Earlier 2026-06-18 (graduation + syscall-status sync — Named Subsystems: `takumi` (was In-port) + `mela` (was Pending) → ✅ native, both 1.0.0 (joining `ark`/`yantra`; matches the 2026-06-18 shared-crates graduation); server-stage row corrected — the kernel exposes `sock_listen#56`/`sock_accept#57` (1.45.5/.6), so "Phase-B server syscalls not started" was wrong; the real open gate is the **cyrius server-socket peer** (stdlib `sock_listen`/`sock_accept` fail-loud on the agnos target — requests filed `agnos/docs/development/issues/2026-06-18-cyrius-agnos-server-socket-peer.md` + `cyrius/docs/development/issues/2026-06-18-agnos-server-socket-peer.md`); net-range refs #45-#55 → #45-#57; agnos version refs → 1.45.10). Earlier 2026-06-14 (list-review sweep — refreshed the stale active-work items + maturity arc + post-MVP queue through the 1.44.x/1.45.x arcs: **USB-HID keyboard on iron RESOLVED** (live multi-command keyboard on real Zen, 2026-06-13/14, xHCI keyboard-ring fix at 1.44.25) + RBP-smash closed (1.42.3); **1.44.x multi-threading/preemptive ARC COMPLETE**; **1.45.x TLS→HTTPS→ark-fetch OPEN** (ring-3 net syscalls #45-#55); maturity `server` stage reclassed "Foundation materializing" (agora 1.4.2 + descent MUD 1.0.1 + net-tools); `sit` 1.0.1 demand-gated→shipped. agnos 1.45.4 / agnoshi 1.7.0 / owl 1.4.0. **BETA RESCOPED**: summer-2026 stays CLOSED in two phases — closed beta opens **Late June / Early July** (founder Docker-AGNOS-service sweep at server base) → **Desktop mid-to-late summer** (external testers, still invite-only/closed); **public beta DEFERRED post-summer**; **DEF CON moved to Aug 2027** (2 months isn't enough prep for that crowd). Earlier 2026-06-07: 1.41.x shell-separation iron-complete burn `14115`; 1.42.x/1.43.x perf + graphics/DOOM path.) | Next Review: closed-beta open (Late June / Early July 2026)*
