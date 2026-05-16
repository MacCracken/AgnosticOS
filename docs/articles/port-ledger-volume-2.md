# Port Ledger Volume 2

> **Volume 2: Mid-Arc State of Things.** Cyrius v5.10/v5.11 era. Kernel iron-validated. Four new native subsystems shipped. Pin-cluster review across the ecosystem. Volume 1's "Where Rust Still Wins" gaps reviewed for *direction of motion* — no comprehensive re-measurement (that's Volume 3's scope). Captured 2026-05-15.

---

## What This Volume Is

Volume 1 was a frozen snapshot at Cyrius v5.5.4 — ten ports, 17-day-old language, pre-optimization-arc. Volume 3 will be the post-arc comparison against those numbers at end-of-5.x or v6.0, whichever lands first.

Volume 2 sits between those — a **mid-arc state-of-things**, captured at the point where the work has *clearly progressed* but *hasn't all been re-measured*. The optimization arc has shipped its early phases. The stdlib-fold pattern has compounded three times (sandhi v5.7.0, vani v5.8.0, niyama v5.9.0). A typed-simd ABI has landed. The REAL TYPE SYSTEM arc has closed at v5.10.x. **The kernel boots on iron.** Four native subsystems have shipped without Rust antecedents.

What Volume 2 is NOT: a full bench-history re-run. Most ports haven't been formally re-measured since their Volume 1 cut; doing all of them properly is Volume 3's job. Volume 2 captures **what's true right now** — pin states, kernel milestones, new native arrivals, direction-of-motion on the four Volume 1 gaps — without claiming closure where closure hasn't been measured.

The honest framing: the receipts that exist today are real and worth recording before they drift; the receipts that don't exist yet stay un-asserted. Two patterns the arc would otherwise violate.

---

## The State of the Language

- **Cyrius v5.11.55** as of 2026-05-13 (the v5.11.0 → v5.11.55 burst landed **55 patches across 3 days**: 24 + 18 + 13 — a sustained ~18 patches/day exceeding v5.10.x's ~10/day baseline).
- **Self-hosting compiler, byte-identical reproduction** across the burst. `cc5` at **809,200 B** at the v5.11.24 snapshot baseline (the v5.11.25 → v5.11.55 size delta isn't snapshotted in `state.md`; live size in `cyrius/cc5`).
- **v5.10.x closed 2026-05-11** at .50 with **50 patches in 5 days** and three completed compiler arcs:
  - **Typed-simd ABI** (11 phases) — value-form `f64v2`/`f64v4` with parser-side `&IDENT → _ptr` overload routing; f64v2 args in XMM0/XMM1 (SysV) / V0/V1 (aarch64); PE-gated via `CYRIUS_HAS_VAL_SIMD_PARAMS`. This is the substrate for future Cyrius-native codec work.
  - **REAL TYPE SYSTEM** (5 phases) — per-fn param-type bitmasks, call-site type checking, cstring/Result/Option/Tagged vocabulary on stdlib.
  - **Struct-byval ABI** (3 phases) — cross-backend struct-byval return surface.
  - Plus 2.7× compile-time-perf miniarc (.40 + .41), TLS contract pin (.42), PE-format premise debunk (.49 — 15-slot phantom pin closed by empirical re-test).
- **v5.11.x in flight** — stdlib annotation arc + consumer-issue closeout. Includes the ELF section-header fix arc (.29/.30/.31 — fixed GRUB's `e_shoff=0` rejection on first iron-boot attempt) and Path-A→Path-C transition support (.43–.55 enabled the sovereign UEFI bootloader).
- **v5.12.x retired 2026-05-12.** v5.11.x is the FINAL 5.x minor. v6.x opens the platform-expansion arc (bare-metal target formalization, RISC-V rv64, PIE, closures, language-level async, Class B FFI fold). Framing: **v5.x = "what the language IS" (frozen feature set); v6.x = "what the language gains" (new capabilities).**

The optimization arc itself: O1 (instrumentation + FNV-1a) v5.6.0–v5.6.4; O2 (five peephole categories) v5.6.11; O3a IR instrumentation v5.6.12; linear-scan regalloc default-on v5.6.20–v5.6.24; O4a/b/c regalloc + Poletto-Sarkar linear-scan picker through v5.7.x–v5.8.x. **O5/O6 codebuf compaction (NOP harvest with jump+fixup) referenced through v5.8.x with status sweep still queued** for v5.11.x triage. The arc isn't fully closed; that's why Volume 2 isn't the comparison cut.

---

## The Kernel — agnos 1.30.1, Iron-Validated

The headline receipt Volume 2 carries that Volume 1 could not: **AGNOS reaches a shell prompt on real hardware.**

### What landed

- **agnos 1.30.0 cut 2026-05-13** as a kernel ABI break: entry contract switched from multiboot2 to AGNOS sovereign boot-info struct (Path C handoff). Boot-info source register `RBX → RDI`; magic `0x41474E4F = 'AGNO'`; layout spec in agnosticos's path-c plan.
- **Iron-validated 2026-05-15** on archaemenid (NUC AMD Beelink SER, Zen-class). Attempt 28 reached MVP spine alive on iron — full init sequence: GDT → TSS → IDT → APIC → timer → SMP → keyboard ISR → paging → PMM → KASLR → heap → ACPI → PCI → VFS → SYSCALL → stack canary → test procs → scheduler armed → idle loop survived → userland exec → kybernet-launch → shell. Attempt 29 (cleanup-pass burn ~16:45 PDT) rendered the full kernel log + `AGNOS shell v1.30.0` prompt on the framebuffer.
- **1.30.1 staging opened** the same session — xHCI Phase 1 (PCIe discovery + capability reads) landed in [Unreleased] as the first phase of the native USB-HID-boot keyboard driver work (scoped at [`planning/usb-hid-keyboard-driver.md`](../development/planning/usb-hid-keyboard-driver.md)).

### Size and structure

| Cut | Size | Notes |
|---|---|---|
| 1.26.1 (Volume 1 era anchor) | 248,000 B | 33 subsystems, 26 syscalls, three hardening passes |
| 1.29.0 (pre-iron) | 250,704 B | Boot-shim portability work |
| 1.30.0 (Path-C cut, 2026-05-13) | 251,040 B | RBX → RDI switch, multiboot2 → sovereign struct |
| 1.30.0 (iron-validated, 2026-05-15) | **266,312 B** | Across the cycle: visual canary, CMOS boot-log, Repair P, kprint mirror, cleanup pass |
| 1.30.1 (xHCI Phase 1, [Unreleased]) | **273,816 B** | +7,504 B for PCIe class lookup, 64-bit BAR support, xhci_probe + capability reads |

The +15 KB growth across the 1.30.x cycle is iron-validation infrastructure — visible at first instruction (visual canary), persistent across triple-fault reset (CMOS boot-log), mirrored to framebuffer (kprint everywhere). Plus the xHCI bus-driver foundation. Compare to the +82% growth across 1.11.0 → 1.22.0 documented in *the_143kb_lie* (the buffer-overflow audit era) — that growth was finding the truth; this growth is *handling the truth on hardware that doesn't lie*.

### The walk

29 iron attempts across 3 weeks. Two GRUB walls (multiboot2 strict-W^X kills the relocator under modern UEFI). One architectural pivot — Path A (GRUB MB2-EFI) abandoned for Path C (sovereign UEFI bootloader, gnoboot). 16 repair letters A–P; 11 of them (F–N + diagnostic-only stamps) deleted by Repair (O) when the premise-audit gate caught a rabbit hole sitting on disk for two weeks. Full arc captured in [`iron-nuc-zen-log.md`](../development/iron-nuc-zen-log.md); generic process pattern distilled in [`iron-bring-up-process.md`](../development/iron-bring-up-process.md). Field-notes for agents: vidya `kernel.cyml` entries `the_road_to_iron` (Attempts 1–8) + `shell_on_iron` (Attempts 9–29).

The walk's lessons are themselves a receipt — methodology bent without breaking, premise-audit gate codified, repair-letter discipline emerged, CMOS-as-post-mortem-channel solidified. Detailed in *Methodology is the Trap* § *Method Accretes Where Method Fails*.

### What gates closed-beta

The MVP "boot to shell" line was reached 2026-05-15. The remaining gate is keyboard input — modern UEFI doesn't emulate PS/2 over XHCI post-`ExitBootServices`; the legacy port 0x60 path is silent. Native XHCI + USB-HID-boot driver in `agnos/kernel/arch/x86_64/usb/` closes the typeable half. Phase 1 landed; Phases 2–5 (controller init, port enum, HID boot protocol, interrupt-driven feed) are the 1.30.1 cycle's work.

---

## New Native Subsystems (No Rust Antecedent)

Four subsystems shipped between Volume 1 and Volume 2 that have no Rust side to benchmark against. They're not "ports" in the Volume 1 sense — they're native-first work — so Volume 2 just inventories what arrived.

### aegis 1.0.0 — Security daemon

Graduated from pre-1.0 in the v5.10.x window. Was at 0.1.0 (scaffold) in Volume 1 framing. By v5.9.x had reached 0.8.2; in v5.10.x landed 1.0.0 — straight implementation closeout, no 0.9.x. Sigil + phylax dependencies. Now lives in the **OS & Infrastructure** v1.0+ band of shared-crates.md alongside its consumer-facing peers. The graduation is a Volume-2-eligible event because aegis qualifies for re-measurement against any future Rust-side security-daemon comparison (process-monitor / EDR class) — but no antecedent exists in the project, so its first measurements are Volume 3 territory (post-arc).

### gnoboot 0.2.0 — Sovereign UEFI bootloader

Cyrius-native PE32+ UEFI Application. ~35 KB. Replaces GRUB on the AGNOS boot path. Industry-converged architectural shape (Linux EFI stub / FreeBSD `loader.efi` / OpenBSD `BOOTX64.EFI` / Windows `winload.efi` / Limine all do variants of the same 80-byte-handoff-struct pattern). The novel piece is the Cyrius toolchain emitting PE32+ (landed cyrius v5.11.49 — UEFI Application emit + NX_COMPAT + .reloc); the architecture is 10+ years old and converged-on.

0.2.0 cleanup track: CMOS port-I/O blocks stripped (5 inline sites); 13 per-stage failure strings collapsed to a shared template + code table; `efi_clear` pre-banner. The boot path is now lean and load-bearing only; the diagnostic surface lives in the kernel via CMOS port-I/O writes that survive triple-fault reset.

Captured in [gnoboot ADR 0001 — Sovereign Struct over Multiboot2](https://github.com/MacCracken/gnoboot/blob/main/docs/adr/0001-sovereign-struct-over-multiboot2.md).

### commandress 0.1.0 — Shell prompt renderer

Scaffolded 2026-05-15. Sovereign-stack equivalent of [starship](https://starship.rs/) — a structured shell prompt renderer for agnoshi (and eventually bash/zsh). Binary name `cmdrs` (short for *commandress*). Stateless, segment-based, config-driven, zero non-stdlib deps. ADR 0001 captures the separate-repo-not-inside-agnoshi decision; the rationale is the same as starship's separate-binary pattern — couple the prompt's design surface to its own release cadence, not the shell's.

M1 scope (v0.2.0): config loader + cwd segment + exit-code segment + render pipeline. M9 = v1.0 freeze.

### kriya 0.1.0 — Coreutils-equivalent multi-tool

Scaffolded 2026-05-15. Sanskrit क्रिया (*action, operation, verb*). One repo for the small POSIX-style utilities (`cp`, `mv`, `rm`, `mkdir`, `echo`, `wc`, `find`, `grep`, …) — BusyBox-style dispatcher + symlinks per utility. ADR 0001 captures the dispatcher-vs-N-binaries decision. Sovereign-replacement boundaries explicit in CLAUDE.md: owl owns `cat`, cyim owns `vim`, sit owns `git`, chakshu owns `htop`, agnoshi owns shell builtins; kriya fills the gaps.

M1 scope (v0.2.0): dispatcher + simplest utilities (`echo`, `pwd`, `true`, `false`, `yes`, `sleep`). M5 onward includes the larger filtering/search utilities (`grep`, `find`, `xargs`) with explicit "split if it grows past ~400 LOC" policy.

---

## Pin-Cluster Review — Where Every Project Sits

The ecosystem now spans seven distinct Cyrius pin bands. Most projects didn't roll forward uniformly — they cluster at maturity points. The clusters are themselves a measurement: each represents a moment when the surface a project depended on was stable enough to lock against, and the gaps between clusters represent latent stdlib-breakage or held-out closeout decisions.

### Leading edge — v5.11.55 (2 repos)

| Repo | Version | Why here |
|---|---|---|
| agnos | 1.30.1 | Moved off 5.10.44 bedrock during the .29/.30/.31 ELF section-header fix arc (required for iron-boot) + Path-A→Path-C transition (required for sovereign UEFI emit) |
| agnosticos/scripts | 2026.5.13 | Boot pipeline rebuilt against the same 5.11.55 pin as agnos |

Both moved as forced consequences of iron-boot work, not for general optimization gain.

### Post-burst cluster — v5.11.4 / v5.11.8 (10 repos)

| Pin | Repos |
|---|---|
| v5.11.4 | agnosys, sigil, sankoch, sandhi, niyama, patra, sakshi, vani, yukti |
| v5.11.8 | ai-hwaccel |

Picked up the v5.11.0 → v5.11.4 burst surface (stdlib annotation arc Phase 1: alloc/vec/fmt/freelist/fnptr/result/tagged/assert). ai-hwaccel jumped to .8 to catch an additional annotation slot relevant to its hardware-probe path.

### Live bedrock — v5.10.44 (~15 repos, the closed-beta MVP path)

| Repo | Version | Role |
|---|---|---|
| agnoshi | 1.3.2 | AI shell |
| agnostik | 1.2.2 | Shared types & domain primitives |
| argonaut | 1.7.0 | Init system library (BOOT_MINIMAL agnoshi support) |
| bote | 2.7.2 | MCP core |
| daimon | 1.2.3 | Agent orchestrator |
| kavach | 3.2.1 | Sandbox execution |
| kybernet | 1.2.1 | PID 1 init binary |
| libro | 2.6.3 | Cryptographic audit chain (exited 5.4.x deep-lag) |
| majra | 2.4.4 | Queue/pub-sub (exited 5.4.x deep-lag) |
| nein | 1.5.1 | Programmatic nftables firewall |
| phylax | 1.1.1 | Threat detection (exited 5.7.48 held cluster) |
| t-ron | 2.1.4 | MCP security |

The 5.10.44 bedrock is where the closed-beta MVP boot path runs. Every repo here picked up the v5.10.x three-arc surface (typed-simd ABI + REAL TYPE SYSTEM + struct-byval ABI) plus the consumer-rollup that closed the 5.4.x and 5.7.48 deep-lag clusters.

### Warm cluster — v5.9.x / v5.10.x (~8 repos)

| Pin | Repos |
|---|---|
| v5.9.37 / v5.9.43 | sit, vidya |
| v5.10.5 / v5.10.10 | vyakarana, owl, cyim, cyim-lsp |
| v5.10.20 | chakshu, darshana, cyim-lsp |
| v5.10.34 | aegis (during graduation arc — now at 1.0.0) |

Warm — not stale, not leading-edge. These crates picked up enough of the optimization arc + type-system work to be functionally current, but haven't been re-pinned to chase the v5.11.x burst surface. Most don't need to.

### Held cluster — v5.7.48 (3 repos remaining)

| Repo | Version | Why held |
|---|---|---|
| mabda | 3.0.0-rc.2 | Soaking pre-GA stdlib fold (post-fold cut becomes 3.0.0) |
| cyrius-doom | 0.26.2 | Gated on Cyrius optimization-arc closeout retroactive verification |
| samvada | 0.2.2 | DBus client — pre-1.0, gated on logind-shim retirement plan |

Was 4 in earlier framings; phylax exited during v5.10.x. The remaining three each have specific gate conditions documented in their respective `state.md` files; none are dormant — all are *deliberately held*.

### Deep-lag tail (~10 repos)

| Pin | Repos | Status |
|---|---|---|
| v5.1.x | ark (5.1.10) | Extreme lag, port pre-dates pin convention |
| v5.6.x | yantra (5.6.17) | Pre-1.0; pin-bump opportunistic |
| v5.7.x | hisab (5.7.10), agnova (5.7.12), abaco (5.7.23), nous (5.7.29), bazaar (5.7.30), shakti (5.7.33) | All carry latent v5.7.x stdlib snapshot |

The deep-lag tail shrank significantly during v5.10.x (libro, majra, phylax all exited their lag bands). The remaining tail is mostly pre-1.0 work where re-pinning hasn't been worth the surface churn.

### Pre-CYML format tail

Only `hoosh` and `shravan` remain on `cyrius.toml` format (no `cyrius = "X.Y.Z"` pin field). The earlier 11-repo pre-CYML tail collapsed across v5.10–v5.11.

---

## Volume 1's "Where Rust Still Wins" — Direction of Motion

Volume 1 enumerated four categories. Volume 2 reviews each for **direction of motion** without claiming closure. Comprehensive re-measurement is Volume 3 scope; what follows is honest "what shipped that should affect this gap, and which way."

| Volume 1 Category | Volume 1 framing | What landed between V1 and V2 | Direction of motion |
|---|---|---|---|
| **1. Zero-copy micro-ops** | Cyrius bump allocator + `str_builder` loses on paths that barely touch memory (ark cmd_create 4×, agnostik sandbox_config 37×, kybernet seccomp_build 44×). | O2 peephole (v5.6.11): five categories shipped; aarch64 cc5 −17,672 B from combine-shuttle elim alone. O3a IR instrumentation (v5.6.12). | **Expected narrower** at the affected call sites — peephole compaction reduces the per-call overhead the gaps measured. Untested at Volume 2; needs Volume 3 re-bench. |
| **2. Constant folding on pure compute** | LLVM -O3 evaluates literal-input benchmarks at compile time; Cyrius computes them at runtime (2–19× gaps on classify_signal / notify_parse / sigset ops). | O1 closed at v5.6.4 with FNV-1a hashing + instrumentation; constant-folding pass design landed in the O3a IR instrumentation. | **Likely partial narrowing on integer-only paths**, no closure on float-fold (no compile-time float-eval pass yet planned). Volume 3 measurement target. |
| **3. Inlining on sub-nanosecond DSP** | LLVM inlines entire scalar DSP functions at -O3; Cyrius emits a call (300–700× gap on abaco DSP scalar; 4.4×–9.6× on `sanitize_4096`/`poly_blep` batch). | Linear-scan regalloc default-on v5.6.20–v5.6.24; O4a/b/c through v5.7.x–v5.8.x; **typed-simd ABI 11 phases v5.10.x** (substrate for handwritten-SIMD codec lanes, separate from inlining). O5/O6 codebuf compaction still triage. | **Mixed.** The batch numbers should narrow as regalloc reduces register pressure on per-element work. The 300–700× single-call gap is *call-overhead-dominated*; closing it needs an inliner pass that isn't yet on the v5.11.x slot list. Volume 3 target. |
| **4. serde string serialization** | agnostik 5.8–6.8× gaps on string roundtrip; Rust's serde is the most-optimized serialization path in any systems language. | Stdlib-fold pattern compounded three times (sandhi v5.7.0 / vani v5.8.0 / niyama v5.9.0). String surface didn't get a fold; serialization is still general-purpose. | **Probably unchanged.** No stdlib-fold targeted this surface. The gap is honest. Volume 3 measurement; possible v6.x stdlib-fold candidate ("serialization fold-in") if 3+ consumers compound. |

The above is *informed conjecture about direction*, not measurement. Three of the four had real engineering work shipped that should affect them; one didn't. Volume 3 is where the actual numbers land.

---

## Receipts Pending from Volume 1 — Status

Volume 1 named four ports pending for the near cut:

| Receipt | Volume 1 status | Volume 2 status |
|---|---|---|
| **bhava** (emotion/sentiment) | Rust side exists, port queued | Still queued. v5.10.x stdlib + math additions were the gating concern; both have shipped. Port can start. |
| **takumi** (build system) | 0.1.0 scaffold, port will be native-first | At 0.8.0; **Cyrius port in progress** with `rust-old/` authoritative until parity. Toolchain pinned 5.5.23. |
| **aegis** (security daemon) | 0.1.0 scaffold | **1.0.0 shipped** in v5.10.x window. No longer "pending" — graduated past the framing. |
| **aethersafha** (Wayland compositor) | 0.1.0 scaffold, biggest port on the schedule | Still 0.1.0 scaffold. The biggest port on the schedule is still the biggest port on the schedule. |

Plus three native subsystems that shipped in the window but had no Volume 1 receipt entry (because they didn't exist yet): **gnoboot 0.2.0** (sovereign UEFI bootloader), **commandress 0.1.0** (prompt renderer), **kriya 0.1.0** (coreutils-equivalent multi-tool). Inventoried above; first measurements are Volume 3+ territory.

---

## What Stays for Volume 3

The deliberate scope-line between Volume 2 and Volume 3:

- **Full re-measurement against Volume 1's port numbers.** Every Volume 1 deep-dive (agnosys, kybernet, agnostik, abaco) gets new CSV runs at the V3 measurement point.
- **The four "Where Rust Still Wins" categories** get either *closes*, *narrows to N× with specific bound*, or *persists with named reason*. Volume 2's direction-of-motion table becomes Volume 3's measurement table.
- **The optimization arc gets a closure verdict.** O5/O6 codebuf compaction sweep completes (or is explicitly retired). The arc has either delivered on its enumerated phases or hasn't.
- **The remaining held-cluster three** (mabda, cyrius-doom, samvada) resolve one way or another. Either they roll forward and pick up the v5.10.x → v5.11.x surface, or they enter Volume 3 with explicit "deliberately held" framing.
- **Cross-architecture comparison.** Volume 2 hasn't measured x86_64 vs aarch64 byte-identical-self-host divergence under the new typed-simd ABI; Volume 3 should.

Volume 3 is when the optimization arc gets its receipt. **Volume 2's job is not to anticipate that receipt — it's to capture what's true today so Volume 3 has a clean delta to measure against.**

---

## Audit Instructions

Same rule as Volume 1. Everything in this article is reproducible on commodity hardware.

```sh
# Pick any project named above. Example: agnos kernel.
git clone https://github.com/MacCracken/agnos.git
cd agnos
git checkout 1.30.0
./scripts/build.sh
# build/agnos = 266,312 bytes, multiboot2 (ELF64), entry 0x1000a8
```

For the iron-validation receipt specifically, the verification path requires hardware (an x86_64 UEFI machine; the canonical target is the Beelink SER NUC AMD documented as `archaemenid` in agnosticos memory). Photos of the iron boot at Attempts 28 + 29 + cleanup-pass burn are committed at [`iron-nuc-zen-photos/`](../development/iron-nuc-zen-photos/). The arc-of-attempts log is at [`iron-nuc-zen-log.md`](../development/iron-nuc-zen-log.md).

For pin-cluster verification, [`shared-crates.md`](../development/planning/shared-crates.md) and per-repo `state.md` files are authoritative — Volume 2 is a synthesis, not a primary source.

---

## Closing — The Shape of a Mid-Arc Volume

Volume 1 was a clean baseline because the language was 17 days old and there was nothing to compete with except its own bootstrap. Volume 3 will be a clean comparison because the arc will have closed and every Volume 1 number will have a Volume 3 counterpart.

Volume 2 is the awkward middle — half the work shipped, half the receipts pending, half the projects re-pinned and half still riding bedrock. The temptation is to either *promise* the Volume 3 numbers ahead of measurement or *suppress* the genuine receipts that exist today. Volume 2 does neither. **What shipped is recorded. What hasn't measured stays un-asserted.** The kernel boots on iron — that's a receipt. The serialization gap is probably unchanged — that's a direction. The four native subsystems exist — that's an inventory. The optimization arc isn't closed — that's a state.

The five-volume arc framing exists so this middle volume can be honest about its position. It's not a half-attempt at Volume 3; it's a *full attempt at Volume 2*.

---

*Related: [Port Ledger Volume 1](port-ledger-volume-1.md) | [Sovereign Compiler vs Brute Force](sovereign-compiler-vs-brute-force.md) | [Cyrius vs Rust Benchmarks](cyrius-vs-rust-benchmarks.md) | [iron-nuc-zen-log.md](../development/iron-nuc-zen-log.md) | [iron-bring-up-process.md](../development/iron-bring-up-process.md)*

*Robert MacCracken*
*AGNOS Project — [agnosticos.org](https://agnosticos.org)*
*May 2026 (mid-arc state snapshot, captured 2026-05-15)*
