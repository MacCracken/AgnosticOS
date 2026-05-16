---
name: AGNOS Ecosystem State
description: Live cross-repo state — Cyrius cycle, pin-lag spectrum, active sweeps, carry-forward debt
type: state
---

# AGNOS Ecosystem — Current State

> **Cyrius toolchain**: 5.11.55 | **Cycle**: v5.11.x — stdlib annotation arc + consumer-issue closeout (active; **55 patches landed across 3 days** 2026-05-11/12/13 — 24 + 18 + 13)
> **Last refresh**: 2026-05-16 (captures iron-boot Attempts 4–34 + Phase 2.5 re-enable for Attempt 35 + GOP-rendering regression roadmap bullet + BIOS workaround documented + CI surface fixes (pci.cyr/shell.cyr fmt + size cap 300K→500K)). **Attempt 32 (2026-05-15)**: Phase 3 burn clean visually — `xhci: port 3 reset failed` rendered between `controller running` and `VFS initialized`. Triggered Phase 2.5 staging (USBLEGSUP claim, agnos `ec49e44` + agnosticos `d849e6d`). **Attempt 33 (2026-05-16)**: post-Phase-2.5 burn produced **framebuffer rendering corrupted** — every glyph row scrambled (regular grid intact, glyph-level corruption). CMOS post-mortem identical to clean burns (kcp=0x15, magics intact, CR4 SMEP+SMAP, PMM clean) → **kernel ran end-to-end, regression is purely in FB rendering**. Photo at repo root `Corrupted_Visual.jpg`. QEMU smoke passes (xhci not present → Phase 2.5 + 3 paths skipped → confirms new code is not the cause when bypassed). CI surface caught same session: `cyrius fmt --check` flagged `pci.cyr:119-120` (15-space → 4-space continuation indent) + `shell.cyr:330-332` (`#ifdef TEST`/`#endif` col 0 → 4-space indent), both fixed; `x86 size reasonable` cap raised `300000 → 500000` in `scripts/test.sh` to accommodate legitimate Phases 1–3 growth (266 KB → 340 KB). **Attempt 34 (2026-05-16) — bisection INCONCLUSIVE — quiet-boot identified as the actual regression variable**: burn with Phase 2.5 call disabled (matching Attempt 32 on-disk shape) showed garbled framebuffer **persists with BIOS quiet-boot ON**. Visual renders cleanly only with quiet-boot **OFF** (at lower VGA-style resolution, NOT GOP 1080p+). **Phase 2.5 is NOT the sole regression source — quiet-boot mode is the variable**; the kernel's `fb_console` against the GOP linear framebuffer regressed somewhere between Attempt 32 (clean) and Attempts 33/34 (garbled), unidentified root cause (candidates: BIOS settings drift across cold boots per `project_archaemenid_cmos_map`, gnoboot GOP capture path, MTRR/PAT FB cache attributes). **Phase 2.5 re-enabled (post-Attempt-34, pre-Attempt-35)**: single-line restore at `xhci.cyr:253`, stale bisection comment block (7 lines) replaced with xHCI 1.2 §4.22.1 one-line reference. Kernel `340,280 → 340,384 B` (+104, fn body was already in DCE pool). **Roadmap update**: new "Framebuffer — quiet-boot GOP rendering regression" bullet added to `roadmap.md` parallel-cycle-work section with BIOS workaround documented and real-fix paths (root-cause GOP OR land dual rendering paths legacy-VGA-text + linear-GOP). Not blocking 1.30.1. **Attempt 35 prep**: BIOS configured Quiet Boot **OFF** + USB Legacy Support **On/Auto** + XHCI **Enabled** + Mass Storage **Enabled** (Legacy Support needed for Phase 2.5 to do real work — if OFF, `xhci_usblegsup_claim()` hits "n/a" / "already OS-owned" and the test is a no-op). Primary signal channel is framebuffer at VGA-mode resolution (CMOS kcp single-byte last-write-wins; kybernet overwrites xhci stamps). Pre-bound outcomes: `USBLEGSUP: claimed from BIOS` + clean Phase 3 port enumeration with no reset-failed line = ✅ Phase 2.5 worked, unblocks Phase 4; claim + still-failing port reset = SMI-semaphore hypothesis falsified; FB corrupts in VGA mode too = Phase 2.5 introduces FB-rendering bug independent of GOP/VGA distinction. Full 7-row outcome table in [iron-nuc-zen-log § Attempt 35 prep](iron-nuc-zen-log.md). _Prior 2026-05-15 entries below preserved for narrative continuity._ Captures iron-boot Attempts 4–29 + post-Attempt-29 cleanup pass + **cleanup-pass burn verification (~16:45 PDT) + gnoboot 0.2.0 staging** on the **NUC AMD** primary target — Intel/Skytech queued post-AMD-proof, not concurrent. **Attempt 16 hit closed-beta gate (CP 0x11)**; Attempts 17–27 worked the mem-iso next-bug ladder; **Attempt 28 (2026-05-15) — MVP BOOT SPINE ALIVE ON IRON.** Repair (O) (mem-iso block deletion, 303 lines) was the right call: kernel completes its full init spine on archaemenid — GDT/TSS/IDT → APIC + timer → paging → PMM → heap → ACPI/PCI → VFS → initrd → SYSCALL → scheduler arming → idle survival → userland exec → kybernet-launch. Four checkpoints past closed-beta gate (cp_fb 0x12 / 0x14 / 0x15 all painted MAGENTA, then `arch_halt()` as designed). The initial "lockup" framing was a misread of stale read-boot-log verdict text — kcp=0xEA is the in-cp_fb internal stamp, not a stage marker; CMOS slots 0x62-0x6A hold stale values from earlier burns (writers deleted in Repair O). The screen photo is truth: every cp_fb cell painted; see [Attempt 28 entry](iron-nuc-zen-log.md#attempt-28--2026-05-15--mvp-boot-spine-alive-on-iron) + [photo](iron-nuc-zen-photos/attempt-28-mvp-spine-alive.jpg). One-line follow-up landed same-session: `main.cyr:415` `sh_cmd_bench()` → `kybernet()` (shell dispatch tree now reachable; kernel 253,496 → 253,768 B, +272). **Re-audit of "MVP-to-typeable-shell gap" found #1 (fb glyph renderer) and #2 (serial→fb mirror) were ALREADY IMPLEMENTED** — fb_console.cyr ships 8×8 CGA font + fb_putc/fb_print/fb_println/fb_scroll_up; kprint.cyr mirrors all output (`kputc`/`kprint`/`kprintln`/`kprint_num` → serial + fb); shell.cyr uses kprint exclusively (one stale `serial_putc` reference is only a string label in a benchmark). **Attempt 29 (2026-05-15) — visual regression decoded as Repair (P), shell VISIBLE on iron, USB-kbd blocked.** Kernel reached kybernet (CMOS kcp=0x15 MAGENTA); pre-Repair-P visual showed wiped cp_fb cells + invisible prompt. Root cause: `fb_console.cyr:187-189` `var FB_CONSOLE_Y0 = 80; var FB_FG = 0x00FFFFFF; var FB_BG = 0x00000000;` non-zero initializers not honored at runtime. **Repair (P) landed** as explicit `FB_CONSOLE_Y0 = 80; FB_FG = 0x00FFFFFF; FB_BG = 0x00000000;` assignment at top of `fb_console_init()` body. **Burn verification: ✅ shell rendered on iron** — `AGNOS shell v1.30.0 (type 'help')` + `agnos>` prompt painted, full cp_fb cell ladder visible above. **NEW BLOCKER: USB keyboard not delivering scancodes to `kb_buf`** — MVP-gap-#3 hypothesis falsified (UEFI legacy SMM PS/2-emulation NOT active on archaemenid post-ExitBootServices). Maps to sub-case (d) from kcp=0x15 verdict tree. Next-action triage: BIOS knob (Legacy USB / XHCI Hand-off) → port swap → native XHCI + USB-HID-boot driver as MVP-real-answer fallback. **Post-Attempt-29 cleanup pass landed same-session** (iron-nuc-zen log § "Post-Attempt-29 cleanup pass"): all 19 `cp_fb(...)` calls stripped from `main.cyr` (CMOS port-I/O stamps preserved); 85 `serial_print/serial_println` → `kprint/kprintln` (fixes the scrambled-digits fb-output bug — numbers were mirroring but labels weren't); `FB_CONSOLE_Y0 80 → 8` (canary stripe stays at y=0..7); `read-boot-log.cyr` verdict text refreshed against post-cleanup kernel (kcp=0x15 now reflects "shell alive, USB-kbd blocked, BIOS/port/native triage"). cp_fb() fn + color palette infrastructure preserved in fb.cyr for future bisection. Kernel: 266,712 → **266,312 bytes** (-400). Cyrius issue still queued for non-zero-gvar-init root cause (per cyrius-hands-off — surface only). **Cleanup-pass burn ~16:45 PDT: ✅ full kernel init log rendered on framebuffer in coherent text** — `AGNOS kernel v1.30.0` → 64-bit long mode → GDT/IDT/PIC/Timer/APIC/SMP → Keyboard ISR (full US QWERTY) → Page tables 1024MB → PMM/KASLR/UMM/Heap/Devices/ACPI/PCI/VFS → SYSCALL/SYSRET → Stack canary → HW syscall test → Process A/B → Scheduler armed → 153 ticks → initrd/VFS write/read → Userland exec (pid=3) → Launching kybernet → kybernet starting init → 3572 free pages → launching shell → `AGNOS shell v1.30.0 (type 'help')` → `agnos>`. Cosmetic only: gnoboot banner overlays top row (firmware-font row height vs kernel 8-pixel glyphs); kernel won the row, didn't fully erase pixels above. Not blocking. **USB-keyboard blocker triage complete**: BIOS knob toggled across available combinations + every USB-A port swapped → ❌ no scancodes delivered to `kb_buf`. Confirms post-EBS SMM PS/2 emulation is genuinely off on archaemenid. Real-answer fallback: native XHCI + USB-HID-boot driver (~1.5–2.5k Cyrius LOC, keyboard-only). Buffer code is correct — issue is no producer. See iron-nuc-zen log § *USB-keyboard blocker triage* + § *Cleanup-pass burn verification*. **gnoboot 0.2.0 shipped** (commit `529dfc1` on main, tag `v0.2.0`, pushed; VERSION + cyrius.cyml + src/main.cyr msg_pre banner + tests/ovmf_smoke.sh EXPECT + CHANGELOG all synced; rebuild verifies `OK`). **agnos 1.30.0 cycle closed + bumped to 1.30.1 staging** — CHANGELOG consolidated (the entire iron-validation work, Repair F→P + post-Attempt-29 cleanup pass + Attempts 4–29, folded into [1.30.0] retroactively under Added/Changed/Fixed; the cycle now reads as one cohesive narrative spanning 2026-05-13 initial cut → 2026-05-15 iron-validation), [Unreleased] reset to empty 1.30.1 staging area, VERSION 1.30.0 → 1.30.1, 4 kernel banner strings (`kernel/{agnos.cyr,core/main.cyr,user/shell.cyr,arch/aarch64/main.cyr}`) `v1.30.0` → `v1.30.1`, build verified `OK` (266,312 bytes unchanged from cleanup-pass result, multiboot2 ELF64 OK, entry `0x1000a8`). **xHCI Phase 1 landed same-session** (PCIe discovery + capability reads; `kernel/arch/x86_64/usb/xhci.cyr` + `xhci_regs.cyr`; `pci.cyr` extended with class-code capture + 64-bit BAR support via side arrays `pci_class[256]` + `pci_bar0_hi[256]` — preserves byte-compat with existing virtio_net/blk/iommu consumers). `xhci_probe()` wired after `pci_scan()` in `main.cyr`, stamps CMOS `kcp=0x30` on success. Iron-test gate: `xhci: found at <addr>, ver=1.X0, N slots, M ports` on framebuffer. Build verified `OK` (266,312 → 273,816 B, +7,504); entry `0x1000a8` unchanged. `agnosticos/scripts/src/read-boot-log.cyr` gains kcp=48 (0x30) verdict + softens kcp=21 verdict to reflect that Phase 1 has landed (Phases 2–5 still needed for keyboard input). 1.30.1 cycle target: full XHCI + USB-HID-boot driver per [`planning/usb-hid-keyboard-driver.md`](planning/usb-hid-keyboard-driver.md). **Attempt 30 (2026-05-15) — xHCI Phase 1 + halt/reset BURN VERIFIED on iron**: framebuffer rendered all four expected lines: `xhci: found at 4237295616, ver=272, 64 slots, 6 ports` / `caplen=32 csz=1 ac64=1 intrs=8` / `dboff=1440 rtsoff=1152 xecp=616` / `halted, reset clean`. Decoded: BAR `0xFC900000`, xHCI **1.10**, 64 slots, 6 ports, 64-byte contexts, AC64, 8 interrupters. Post-mortem CMOS read `kcp=0x15` is expected — single-byte slot, last-write-wins; xhci stamps were overwritten by kybernet. Framebuffer is the truth channel. **Phase 2 staging landed same-session** (post-Attempt-30, pre-Attempt-31). Files: `kernel/arch/x86_64/usb/xhci_regs.cyr` extended (XhciRtReg / XhciIrReg / XhciTrbType.LINK + CRCR/CONFIG bit-field comments); **NEW** `kernel/arch/x86_64/usb/xhci_ring.cyr` (`xhci_rings_init` allocates DCBAA + cmd ring [Link TRB at slot 255, TC=1, cycle=1] + event ring + ERST [entry 0 with seg base + size=256], plus PMM write-readback sanity check on first allocation); `kernel/arch/x86_64/usb/xhci.cyr` adds `xhci_rt_base` / `xhci_running` globals + `xhci_op_write64` / `xhci_rt_*` accessors, **moves kcp=0x31 stamp out of halt+reset** (was premature per plan), adds `xhci_start()` (rings_init → CONFIG.MaxSlotsEn → DCBAAP → CRCR(RCS=1) → IR0 ERSTSZ/ERSTBA/ERDP → USBCMD R/S+INTE → wait HCH=0 → kcp=0x31); `kernel/agnos.cyr` includes the new ring file. agnosticos-side: `scripts/src/read-boot-log.cyr` rewrites kcp=0x15/0x30/0x31 verdicts (0x15 explains last-write-wins overwrite mechanic; 0x30 enumerates start-step failure modes; 0x31 declares Phase 2 complete + Phase 3 next). Build: agnos `273,816 → **324,736 bytes**` (+50,920; heavy for ~300 LOC, mostly four 512-iteration zero-fill loops being unrolled — 7,460 bytes DCE-recoverable), multiboot2 OK, entry `0x1000a8` unchanged; read-boot-log 33,592 bytes OK. Cyrius and gnoboot untouched. **Attempt 31 (2026-05-15) — xHCI Phase 2 (controller-start) BURN VERIFIED on iron**: predicted line `xhci: controller running, HCH=0, ERDP=10256384` rendered exactly between `halted, reset clean` and `VFS initialized`; ERDP `0x9C8000` page-aligned inside the 0–16 MB identity-mapped band; no DMA sanity-check failure, no start timeout; PMM accounting clean (16 pages consumed during init, 4 of them XHCI's); full downstream stack still green (scheduler 153 ticks → VFS initrd → userland exec → kybernet → `agnos>` prompt). Zero diagnostic rounds, zero repair letters — plan-as-written first-shot. Photo: [`iron-nuc-zen-photos/attempt-31-xhci-phase-2.jpg`](iron-nuc-zen-photos/attempt-31-xhci-phase-2.jpg). **Phase 3 staging landed same-session** (post-Attempt-31, pre-Attempt-32): three new files in `kernel/arch/x86_64/usb/` (`xhci_cmd.cyr` 181 LOC — generic TRB submit + event-ring drain with cycle-bit + Link-TRB wrap handling; `xhci_ctx.cyr` 201 LOC — Input/Device context allocation for CSZ=1 64-byte layout + per-slot tracking tables with 8 parallel arrays packed into one PMM page; `xhci_port.cyr` 164 LOC — PORTSC W1C-safe RMW + xECP Supported Protocol walk at `mmio + 0x268` for USB2/USB3 classification + USB3-auto-reset / USB2-PR-write reset paths) + `xhci_regs.cyr` extended (+TRB types Setup/Data/Status/EnableSlot/AddressDevice/CmdCompletion/TransferEvent/PortStatusChange, +CompletionCode Success/StallError/SHORT_PACKET/ParameterError/ContextStateError, +PORTSC bit layout, +PortSpeed LS/FS/HS/SS/SS+, +xECP cap IDs USBLEGSUP/SupportedProtocol) + `xhci.cyr` extended (+`xhci_enable_slot`, +`xhci_address_device` BSR=0, +`xhci_control_in` Setup/Data/Status 3-TRB transfer, +`xhci_get_device_descriptor` 8-byte then 18-byte, +`xhci_enumerate_port` per-port driver, +`xhci_enumerate` root-hub walk with kcp=0x32 stamp on any-addressed) + `agnos.cyr` (3 new includes) + `main.cyr` (1 new `xhci_enumerate()` call). agnosticos-side: `scripts/src/read-boot-log.cyr` adds kcp=50 (0x32) verdict; kcp=0x31 verdict rewritten (now means "Phase 2 ran but Phase 3 addressed no device" with failure-line enumeration); kcp=0x15 verdict tweaked to mention Phase 3 in the last-write-wins overwrite story. Build: agnos `324,736 → **339,392 bytes**` (+14,656 for ~640 Cyrius LOC across all surface; reasonable density), multiboot2 ELF64 OK, entry `0x1000a8` unchanged, DCE-recoverable stable at 7,460 (Phase 3 code all reachable); read-boot-log `33,592 → 34,512 bytes` (+920). Cyrius and gnoboot untouched. **Attempt 32 burn pending** — USB re-provision then flash; verification gate (one `xhci: port N connected, SPEED, slot=X, VID=Y PID=Z, class=C [HID-kbd]` line per connected port between `xhci: controller running` and `VFS initialized`), 9-row failure-mode triage table (port reset failed / Enable Slot non-Success / Address Device ParameterError or ContextStateError / get-descriptor 8 or 18 failed / transfer event timeout / cmd completion timeout / no port lines at all / pre-kybernet regression / clean shell with no enumeration), and pre-bound outcomes captured in [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md) § *Attempt 31* + § *Phase 3 staging post-Attempt-31* + § *Attempt 32 prep*. **Diagnostic side-note**: ~3 min wasted on a 344-byte stub build before discovering that direct `cyrius build kernel/agnos.cyr` skips the `#define ARCH_X86_64` prep that `scripts/build.sh` prepends — without that define, the entire `#ifdef ARCH_X86_64` block (every x86_64 include) gets dropped. Documented in the Phase 3 staging block so the next bring-up doesn't burn the same minutes. **Phase 3 success unlocks no keyboard input yet** — typing on shell remains echo-less through Phase 4 (Configure Endpoint + Set Protocol=boot); closure is Phase 5's job (HID-boot translation + `kb_buf` feed). **QEMU pre-flight still permanently blocked** → iron remains the only test surface. Path A (GRUB MB2-EFI) blocked at OVMF strict-W^X; **Path C (sovereign UEFI / gnoboot)** is MVP. agnos 1.30.0 ships kernel ABI break (multiboot2 → sovereign boot-info struct). Both `agnos/cyrius.cyml` and `agnosticos/scripts/cyrius.cyml` pin **5.11.55**.) | **Refresh cadence**: bundle with each v5.11.x patch close, full sweep when minor cuts
> **Crate registries** (versions + roles): [`planning/shared-crates.md`](planning/shared-crates.md) is the full registry (incl. pre-1.0); [`docs/applications/libs/README.md`](../applications/libs/README.md) is the v1.0+ stable subset. This file holds cycle / pin / sweep state only.

This doc holds **volatile state** — what's currently true across the AGNOS dev surface. CLAUDE.md is preferences/process/procedures; this is the live picture. Per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md): rewrite in place when state changes; don't preserve historical snapshots — git history is authoritative.

**Drift caveat applies to this doc too** — always verify against actual `VERSION` + `cyrius.cyml`/`cyrius.toml` files before acting on any single item. Repo data refreshed 2026-05-11 eve from local clones across ~52 repos; pin-update sweep largely closed (kernel + most kernel-adjacent repos now on 5.10.44 or 5.11.4; agnosticos/scripts boot pipeline rebuilt against 5.10.44 same day). **2026-05-14 spot-update**: agnos pin moved 5.10.44 → **5.11.55**, agnosticos/scripts pin moved → **5.11.55**, agnos version 1.29.1 → **1.30.0** (sovereign boot-info ABI break). Pin-lag spectrum below reflects 2026-05-11 snapshot — agnos has since exited the 5.10.44 bedrock to the 5.11.55 leading edge.

---

## Cyrius cycle — v5.11.x (active)

**Stdlib annotation arc + consumer-issue closeout.** Cycle opened 2026-05-11 with v5.11.0 — kavach P1 sandbox syscall wrappers (`sys_fchmod`, `sys_setresuid/gid`, `sys_prctl`, `sys_seccomp`, `sys_execveat` — async-signal-safe, both x86_64 + aarch64 backends) plus roadmap restructure mapping the v5.11.x arc. The chapter-open lands real code, not bookkeeping (per `feedback_release_needs_code_not_just_docs`).

### v5.11.x cycle theme

v5.10.x left three carry-forward classes that define the v5.11.x scope:

1. **Stdlib annotation arc** (pinned 2026-05-10) — 1,010 unannotated public fns across ~75 % stdlib coverage. 7-phase breakout: foundational core / I/O / strings / collections / big consumers / closeout / compiler internals. Phase 1 (alloc/vec/fmt/freelist/fnptr/result/tagged/assert) lands at **v5.11.1**.
2. **7 consumer-filed issues** (bote / daimon / kavach 2026-05-10 wave): P1 kavach sandbox wrappers ✅ landed v5.11.0; P2×4 daimon aarch64 epoll_wait, bote net recv_timeout + getaddrinfo, bote arena fl_free, bote streaming/async; Low×2 bote ws_server RFC 6455 key validation + parser assert/string-literal quirk.
3. **Held-forward items** — Class B FFI/wgpu fncall6, cyim regex, float.cyr peephole. Surface-on-ask.

Plus infrastructure carry-forward: `cyrius deps` symlink → file-copy (v5.10.37 pin), `tests/regression-*.sh` → cyrius port + Cyriusly cmdtools port (v5.10.36 pin), TS test harness program promotion.

### v5.11.x slot tracking

**Three-day burst: 55 patches v5.11.0 → v5.11.55 across 2026-05-11/12/13** (24 + 18 + 13). Sustained 18–24 patches/day exceeds the v5.10.x rate (50 patches in 5 days = 10/day) by ~2×. Individual slot resolution lags this doc; the headline counters move faster than the table. Refresh from `cyrius/CHANGELOG.md` for per-patch resolution.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | kavach P1 sandbox syscall wrappers | ✅ v5.11.0 | 6 wrappers, both backends, async-signal-safe; closes kavach 3.1.1 raw-syscall workaround |
| 2 | Stdlib annotation arc Phase 1 (alloc/vec/fmt/freelist/fnptr/result/tagged/assert) | 🔄 In-flight across v5.11.1–.24 | Lands cumulatively across the same-day burst — exact phase boundaries in cyrius CHANGELOG |
| 3 | Stdlib annotation arc Phases 2–7 | 🔄 In-flight | At burst rate, multiple phases likely landed in the .1–.24 window |
| 4 | Consumer-filed P2 wave (daimon/bote) | [ ] Queued | Interleave per slot-ordering heuristic |
| 5 | Infrastructure (deps copy fix, regression port, TS test harness) | [ ] Queued | Later in v5.11.x |
| 6 | **argonaut 1.7.0 + kybernet 1.2.1 (BOOT_MINIMAL agnoshi)** | ✅ Cut 2026-05-11 eve | Genesis-repo MVP path: adds agnoshi as a no-deps console service in BOOT_MINIMAL, unblocks boot-to-shell-on-iron without aethersafha. argonaut 1.7.0 = the feature; kybernet 1.2.1 = consumer pin bump. See respective CHANGELOGs. |
| 7 | **Cyrius 5.11.29/.30/.31 — ELF section-header fix arc** | ✅ Cut 2026-05-12 | GRUB `grub_elf32_get_shnum` rejection on first iron-boot attempt traced to `EMITELF_KERNEL`/`EMITELF`/`cyrld` emitting `e_shoff=0`. Three patch releases mirrored a 5-section table (.text/.rodata/.bss/.shstrtab) across x86 kernel emitter (.29), aarch64 kernel emitter (.30), cyrld ELF64 user-binary linker (.31). agnos 1.29.0 re-pinned to 5.11.29; USB refresh via new `install-usb.sh --update` mode. |
| 8 | **Iron-boot Attempts 4–27 (NUC AMD) → Attempt 16 hit closed-beta gate (CP 0x11) MAGENTA; Attempts 17–24 worked the page-table next-bug ladder closing with Repair (L) at paging.cyr:30-33 (explicit `store64(0x1000, 0x2007)` / `store64(0x2000, 0x3007)` replacing the Path-A-era OR-in-US pattern); **Attempt 25 (2026-05-15) confirmed Repair (L)** — mem-iso block fully clean, new bug downstream at main.cyr:640-660 with first racy outcome of the ladder. **Attempt 26 (2026-05-15) PEGGED kcp at 0x19** across multiple burns — none of the Repair (M) bisector stamps (0xE1..0xE4) fired. Death window collapsed from "21 lines main.cyr:640-660" to "one function: cp_fb in fb.cyr". PMM/CR4/PML4 all clean. The racy variation observed to only manifest after BIOS save-and-exit (cold POST + PCIe re-enum + DRAM retrain + fresh MTRR/PAT); warm save-and-reset reproduced kcp=0x19 deterministically. Repair (N) landed 2026-05-15 — (a) 6-stamp port-I/O bisector inside cp_fb (kcp 0xE5..0xEA), (b) `cmos_stamp_fb_phys()` helper in mbi.cyr that snapshots fb_phys bytes 2+3 to CMOS[0x69]/[0x6A], (c) call site at main.cyr:640 right before cp_fb(0x19), (d) read-boot-log gains 6 kcp verdict branches + CMOS[0x69]/[0x6A] decoder + cold-vs-warm interpretation. Pure diagnostic. Kernel: 254,832 → 255,048 bytes (+216). **Attempt 27 (2026-05-15) — Repair (N) BURNED — fb_phys = 0x00000000 CONFIRMED**: CMOS[0x69]=0x00, CMOS[0x6A]=0x00; kcp pegged at 0x19 again (cp_fb arg-stamp fired, in-prologue 0xE5 didn't). Per Repair-N interpretation block: snapshot asm executed (port-I/O writes to 0x69/0x6A are present), value at `boot_info+0x48` came back zero — fb_phys really IS 0. cp_fb died on first FB MMIO write with fb_phys=0 in hand. **Bug shifts from kernel-side to gnoboot/boot_info handoff.** All kernel layers provably clean (PMM 0x59/0x5a, PML4 0x07×7, CR4 0x30/0x30, CR3 dance intact). Three-way visual asymmetry recorded: cold-boot-with-USB-switchover AND BIOS-save-exit both show "25-racy" markers; fault-reset shows "normal" markers. Consistent with gnoboot re-running on cold+save-exit (fresh boot_info populate), not on fault-reset (preserved state). **Repair (O) proposed (gnoboot-side, pending)**: (1) gnoboot CMOS stamp at [0x6B]/[0x6C] capturing what gnoboot *thinks* it wrote into boot_info; gnoboot-vs-kernel divergence reveals struct-layout / population mismatch; (2) gnoboot source audit of GOP-probe → boot_info write path — verify fb_phys lives at offset +0x48 (agnos 1.30.0 was kernel-ABI break; gnoboot side may have drifted or never been wired). Pure diagnostic. agnos kernel unchanged at 255,048 bytes.** | 🔄 Attempt 28 pending Repair (O) gnoboot-side land | Target: NUC AMD (archaemenid, Zen-class, primary AND user's daily-driver — every attempt costs the dev machine). Intel/Skytech queued post-AMD-proof. **Path A (GRUB MB2-EFI) abandoned** — OVMF 2024+ strict-W^X faults in `grub_relocator64_efi_boot`. **Path C (sovereign UEFI / `gnoboot`)** is MVP. **agnos 1.30.0** ships the kernel-side ABI break (entry contract: multiboot2 → sovereign boot-info struct). **Attempt 14 hit CP `0x23`** (sub-case 3b hypothesis: sched_next starves proc 0). **Attempt 15 hit CP `0x23` AGAIN** despite repairs (A) unconditional state-ready post-save + (B) `sched_next` fallback to proc 0 — and visual CP ladder confirmed the new kernel ran on iron (eliminated "USB wasn't reflashed"). Static walkthrough of sched_next+do_context_switch after repairs A+B shows proc 0 *should* be re-selected on tick 3 — therefore bug is not in policy. **Root cause: `kernel/arch/x86_64/pic.cyr` `timer_isr_build()` only pushes 9 caller-saved GPRs** despite a stale comment claiming otherwise — rbx/rbp/r12-r15 leak between procs across every ctx switch. When proc 0 finally re-runs, its `[rbp - N]` access to `idle_count` reads test_proc_b's stack (rbp pointing into stack_b at 0x820000+) instead of the kernel stack → no progress past CP 0x23. **Repair (C) landed 2026-05-14 night** (per per-action-consent step-through, single coupled edit): (1) ISR pushes/pops all 15 GPRs (9 caller-saved + 6 callee-saved); (2) `proc_save_context`/`proc_restore_context` add 6 callee-saved load/store pairs at slot offsets {rbx:40, rbp:80, r12:120, r13:128, r14:136, r15:144}; (3) hardware-frame offsets shifted +48 (RIP +72→+120, etc.) because the deeper push set moves the hw frame up. Kernel **252,480 → 253,712 bytes** (+1,232). `timer_isr[]` buffer at 63/64 bytes — **1 byte headroom only**, future ISR additions must bump the buffer first. **QEMU pre-flight permanently blocked** for this kernel (multiboot2 ELF64 fails `qemu -kernel`; path A W^X-blocked on OVMF; path C/gnoboot QEMU+OVMF launch script doesn't exist yet). **Closed-beta gate is CP `0x11` MAGENTA on Attempt 16 iron burn.** Pre-bound outcomes in iron-nuc-zen log: 0x11=success (repair C sufficient), 0x12/0x13/0x14=partial (loop mid-cycle stall), still 0x23=repair C wrong/incomplete, 0x10 or lower=repair C regressed something. See [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md) § Attempt 15 + § Repairs landed for Attempt 16. |

### v5.10.x retrospective (closed 2026-05-11 at 5.10.50)

**50 patches in 5 days** (2026-05-06 → 2026-05-11). THREE completed arcs plus a compile-perf miniarc:

- **Typed-simd ABI arc — 11 phases** (closeout v5.10.39). `lib/simd.cyr` rewrite: every math op exists in value-form + pointer-form siblings with parser-side `&IDENT → _ptr` overload routing; f64v2 args in XMM0/XMM1 (SysV) / V0/V1 (aarch64), f64v4 in register pairs; PE-gated via `CYRIUS_HAS_VAL_SIMD_PARAMS`. **This is the substrate for Cyrius-native codec work long-term** — typed SIMD primitives + cross-platform ABI-aware register routing is the floor of any handwritten-SIMD codec port (tarang's current dav1d/openh264/libvpx C-FFI layer is the placeholder until that future arc opens).
- **REAL TYPE SYSTEM arc — 5 phases** (Phase 2 v5.10.24, Phase 3 v5.10.25 overload generalize). Per-fn param-type bitmasks, call-site type checking, cstring / Result / Option / Tagged vocabulary on stdlib.
- **Struct-byval ABI arc — 3 phases** (.45 + .46 + .47). Cross-backend struct-byval return surface.
- **Compile-time-perf miniarc** (.40 + .41) — **2.7× total compile speedup**.

Plus one TLS contract pin (.42), one PE premise debunk (.49 — 15-slot phantom pin closed by empirical re-test), 4 open issues closed (str_split, exec_*, parser cosmetics, kernel-reserved-word), and 9+ in-cycle pin re-scopings driven by premise-check discipline.

api-surface 2,769 → 2,876 (+107 public fns). cc5 (x86) 741,048 B → **804,472 B**. check.sh 66 gates stable. cyrius test count 132 → ~146.

### cc5 cut state

cc5 at **809,200 B** at v5.11.24 (+4,728 B across the .0–.24 burst from v5.11.0's 804,472 B baseline). v5.11.0 was a stdlib-only addition (cc5 doesn't include `lib/syscalls_*_linux.cyr`); the .1–.24 burst added compiler-internal annotation surface that DOES land in cc5. Self-host fixpoint clean across the burst. **v5.11.25 → v5.11.55 cc5 delta**: not snapshotted in this doc — pull from `cyrius/cc5` if needed. Patches .29/.30/.31 (ELF section-header fix arc) and .43–.55 (Path A→Path C diagnostic + sovereign UEFI emit support) all landed here.

### v5.12.x reservation — bare-metal + RISC-V rv64

Bare-metal AGNOS target + RISC-V rv64 backend now slot at **v5.12.x**. Slip path: v5.8.x → v5.10.x → v5.11.x → **v5.12.x**. The v5.10.x typed-simd ABI + REAL TYPE SYSTEM + struct-byval ABI together form the substrate prerequisite (call-site checking catches ABI mismatches before they reach a foreign target; typed-simd primitives are needed for SIMD-aware backends); v5.11.x's stdlib annotation arc is the remaining prereq.

### Genuinely dangling — carry-forward into v5.11.x triage

| # | Item | Domain | Notes |
|---|------|--------|-------|
| 1 | `cyrlint` multi-line assert | Tooling | Investigated v5.8.41; couldn't reproduce on 4 synthetic tests. Decide: close as moot, or pin a real reproduction case |
| 2 | `ESTORESTACKPARM` stub | Language | Explicitly **held** ("TODOs in src/: 1, held") — needs unhold-or-resolve decision |
| 3 | Optimization arc O3–O6 audit | Compiler | Partial follow-on shipped (O3a IR / O4a–c regalloc / O5 / O6 codebuf) — needs status sweep against v5.6.x deferral list to identify what's still open |
| 4 | Consumer rollup — pre-CYML format tail | Ecosystem | 11 repos still on `cyrius.toml` at v3.x–v4.x (avatara, ai-hwaccel, hadara, itihas, hoosh, kavach, agnoshi, nein, bote, t-ron, shravan); format migration + pin bump |
| 5 | Consumer rollup — deep-lag tail | Ecosystem | ark (5.1.10), libro (5.4.7), majra (5.4.17), bsp (5.5.2), takumi (5.5.23), yantra (5.6.17) |
| 6 | Consumer rollup — v5.7.48 held cluster (4 repos remaining) | Ecosystem | phylax, mabda, cyrius-doom, samvada — agnosys exited at v5.10.19 |
| 7 | Bare-metal readiness — v5.12.x prereqs | Compiler/runtime | Surface what's needed for clean v5.12.0 bare-metal target open |
| 8 | RISC-V rv64 readiness — v5.12.x prereqs | Compiler/backend | rv64 backend slipped 7+ times; current minimum to land cleanly |

---

## Pin-lag spectrum

Each repo's `cyrius = "X.Y.Z"` pin (verified 2026-05-11 eve from local clones — pin sweep largely closed). **Most pre-CYML consumers migrated**: agnoshi, bote, t-ron, kavach, itihas, nein all moved from `cyrius.toml` v3.x/v4.x to `cyrius.cyml` 5.10.44+. Only `hoosh` and `shravan` remain on pre-CYML format in the local-verified set.

```
PRE-CYML format / no pin field (remaining tail):
  hoosh (cyrius.toml, no pin field visible in snapshot)
  shravan (cyrius.toml, no pin field visible in snapshot)

CYML format — DEEP LAG (didn't roll forward; may carry latent stdlib breakage):
  v5.1.x:  ark (5.1.10)                              ← extreme lag, port pre-dates pin convention
  v5.6.x:  yantra (5.6.17)
  v5.7.x:  hisab (5.7.10), agnova (5.7.12),
           abaco (5.7.23), nous (5.7.29),
           bazaar (5.7.30), shakti (5.7.33)
  v5.7.48: mabda (3.0.0-rc.2), cyrius-doom (0.26.2),
           samvada (0.2.2)                           ← held-cluster (was 4; phylax exited)

CYML format — WARM CLUSTERS:
  v5.9.x:  sit (5.9.37), vidya (5.9.43)
  v5.10.x: vyakarana (5.10.5), owl (5.10.10),
           cyim (5.10.10), cyim-lsp (5.10.10),
           chakshu (5.10.20), darshana (5.10.20),
           cyim-lsp (5.10.20),
           aegis (5.10.34)

CYML format — LIVE 5.10.44 BEDROCK (~15 repos, the boot path minus agnos):
  v5.10.44: agnoshi (1.3.2),
            agnostik (1.2.2), argonaut (1.7.0),
            bote (2.7.2), daimon (1.2.3),
            kavach (3.2.1), kybernet (1.2.1),
            libro (2.6.3) — exited 5.4.x deep-lag,
            majra (2.4.4) — exited 5.4.x deep-lag,
            nein (1.5.1), phylax (1.1.1) — exited 5.7.48 held cluster,
            t-ron (2.1.4)

CYML format — LEADING-EDGE 5.11.x post-burst cluster:
  v5.11.55: agnos (1.30.1), agnosticos/scripts (2026.5.13)
            — both moved to head during the .29/.30/.31 ELF fix arc
              and Path-A→Path-C transition
  v5.11.4:  agnosys (1.2.6), sigil (3.1.1), sankoch (2.2.5),
            sandhi (1.3.4), niyama (1.0.2), patra (1.9.4),
            sakshi (2.2.4), vani (0.9.3), yukti (2.2.3)
  v5.11.8:  ai-hwaccel (2.2.2)

CYRIUS TOOLCHAIN itself: 5.11.55 (after 55-patch 3-day burst 2026-05-11/12/13)

NOT VERIFIED LOCALLY (remote-only, presumed pre-CYML or scaffolded):
  avatara, hadara, itihas, takumi, aethersafha, aethersafta, mela,
  seema, samay, kiran, joshua, salai, murti, tanur, encom-hits,
  cyrius-{bb,brynns-tale,stellar-swarm,sunset-drive,super-plumber-twins,
  grapevine,chellys-beach-adventure,nba-jam}
```

**Bands of attention (2026-05-11 eve + 2026-05-14 spot-update for agnos/scripts):**
- **5.11.55 leading-edge boot-path pair**: agnos (1.30.0) + agnosticos/scripts. These moved off the 5.10.44 bedrock during the .29/.30/.31 ELF fix arc (forced) and the Path-A→Path-C transition (required sovereign UEFI emit support).
- **5.11.x post-burst cluster** (~10 repos at .4/.8) — ahead of the bedrock but trailing the leading-edge pair.
- **5.10.44 live bedrock** (~15 repos: kybernet, argonaut, agnoshi, kavach, daimon, bote, t-ron, libro, etc.) — still where the rest of the closed-beta MVP path runs.
- **Deep-lag tail** shrank but didn't vanish: ark (5.1.10) extreme, hisab/agnova/abaco/nous/bazaar/shakti in v5.7.x cluster, yantra (5.6.17). The 5.4.x cluster (libro, majra) FULLY EXITED at 5.10.44.
- **Held cluster at 5.7.48** now **3 repos** (mabda, cyrius-doom, samvada) — phylax exited during v5.10.x. mabda is at 3.0.0-rc.2 (soak before GA fold to Cyrius stdlib); cyrius-doom is at 0.26.2 (gated on Cyrius optimization-arc closeout retroactive verification).
- **Pre-CYML format tail**: only `hoosh` and `shravan` remain in the local-verified set. The previous 11-repo tail collapsed in the v5.10–v5.11 window.

### New repos / milestone bumps since last refresh

| Repo | Version | Pin | Notes |
|------|---------|-----|-------|
| **aegis** | **1.0.0** | 5.10.34 | **Hit v1.0** (was 0.8.2 in last refresh). Real system-security daemon now shipping. Skipped 0.9.x — straight implementation closeout to 1.0.0. |
| **chakshu** | 0.3.0 | 5.10.20 | AI-augmented system monitor (`shu` binary). Past initial scaffold; +0.0.1 from last refresh's 0.2.0. |
| **cyim-lsp** | 1.5.0 | 5.10.20 | LSP server companion to cyim. Pin moved 5.10.10 → 5.10.20. |
| **darshana** | 0.3.0 | 5.10.20 | TTY/raw-mode primitives library (दर्शन — viewing/showing). Extracted from cyim's `src/tty.cyr` once chakshu became a second consumer. Not a TUI framework — just termios + ANSI + cursor positioning. +0.0.1 from last refresh's 0.2.0. |

---

## Active sweeps

### Niyama fold-in (v5.9.0 downstream sweep)

Fresh sibling-fold per niyama ADR 0011. Pattern parallels sandhi-fold (v5.7.0) and vani-fold (v5.8.0).

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (cyim is #1 multi-consumer gate; bare-metal kernel queued #2) | ✅ Done at v5.9.0 |
| 2 | In-tree fixture migration if needed | ✅ N/A — no fixtures touched |
| 3 | cyim → niyama integration verification (regex sweep) | ✅ Done — `cyim/src/main.cyr:51` includes `lib/niyama.cyr` directly |
| 4 | Document the niyama-fold pattern alongside sandhi/vani-fold in `design-patterns.md` | [ ] Pending |
| 5 | Niyama-fold-in article slot | [ ] Subsumed by [*What Justifies a Stdlib Foldin*](../articles/what-justifies-a-stdlib-foldin.md) — per-fold piece optional |

### gnoboot 0.2 merge + version bump (queued for next gnoboot touch)

Branch `0.2` is one commit ahead of `main` (`d981fae` — "cleanup of canary and clear framebuffer for initial display", 2026-05-15). Structurally clean for merge; staged separately so the iron-boot ground truth (Attempt 29 → shell visible) lands first, then gnoboot rolls forward with the cleanup batched.

| Action | Status |
|---|---|
| CMOS port-I/O blocks stripped (5 inline sites: entry / HandleProtocol / ELF-load / pre-EBS / post-EBS) | ✅ on branch — 0 CMOS refs in 0.2 vs 6 in main |
| UEFI-output collapse (`msg_li_f` … `msg_ebs_f` → shared `msg_fail` + `code_*` table + `efi_fail(st, code)` helper) | ✅ on branch |
| Banner tightened to `gnoboot v<VERSION>: handing off to kernel` (`tests/ovmf_smoke.sh` `EXPECT` synced) | ✅ on branch |
| `efi_clear(st)` called pre-banner so handoff line is the only thing on the framebuffer | ✅ on branch |
| Boot-info struct ABI preserved (magic `0x41474E4F`, RDI handoff, `fb_phys` at +0x48, GOP capture retained) | ✅ verified |
| CHANGELOG `[Unreleased]` section drafted | ✅ on branch |
| Bump `VERSION` 0.1.0 → 0.2.0 | ✅ shipped in 0.2.0 |
| Bump `cyrius.cyml` `version` field 0.1.0 → 0.2.0 | ✅ shipped in 0.2.0 |
| Sync `src/main.cyr` `msg_pre` banner UTF-16LE byte (`0x31` → `0x32`, `v0.1` → `v0.2`) | ✅ shipped in 0.2.0 |
| Sync `tests/ovmf_smoke.sh` default `EXPECT` (`gnoboot v0.1.0` → `gnoboot v0.2.0`, both literal + usage-example) | ✅ shipped in 0.2.0 |
| Rename `[Unreleased]` → `[0.2.0] — 2026-05-15` in `CHANGELOG.md` (Unreleased section preserved as empty placeholder for next cycle) | ✅ shipped in 0.2.0 |
| Rebuild verifies `OK` (`CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI`) | ✅ verified 2026-05-15 |
| Merge `0.2 → main` | ✅ landed (`529dfc1` on main) |
| Tag `v0.2.0` on `main` | ✅ tagged |
| Push branches + tag | ✅ pushed |

Sweep closed 2026-05-15. Per `feedback_bootloader_kernel_ownership` Claude owns gnoboot end-to-end during iron-boot bring-up; merge + tag were user-driven git ops per CLAUDE.md (user handles all git operations).

### Vani audio distlib fold-in (v5.8.0 downstream sweep)

Per [`vani/docs/development/cyrius-stdlib-fold-in.md`](https://github.com/MacCracken/vani/blob/main/docs/development/cyrius-stdlib-fold-in.md). Pattern parallels v5.7.0 sandhi fold.

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (`grep -rn "include.*lib/audio.cyr"` across ecosystem) | ✅ Done at v5.8.0 — zero hits |
| 2 | In-tree fixture migration (3 preprocessor-cap regression tests) | ✅ Done in cyrius repo at v5.8.0 |
| 3 | Document the fold-in pattern alongside sandhi-fold in `design-patterns.md` | ❌ Still pending (now subsumed by fold-in article) |
| 4 | Vani-fold-in article (parallels sandhi-fold article slot) | ❌ Still pending (now subsumed) |

### v5.7.x → v5.8.x → v5.9.x → v5.10.x → v5.11.x debt carry-forward

Status verified 2026-05-11 eve.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | yantra orphan `lib/http_server.cyr` delete | ❌ Pending | File still present at `yantra/lib/http_server.cyr`; cleanup-only, no callers. yantra still at 5.6.17 (deep-lag). |
| 2 | sit orphan `lib/http_server.cyr` delete | ✅ Done | Removed during v5.8.x; sit now at 5.9.37 |
| 3 | vyakarana grammar refresh — index 469 sandhi fns | ❓ Re-verify | vyakarana at 2.2.1 / 5.10.5 — version stable through v5.10–v5.11 burst, content reflection still unverified |
| 4 | vidya per-minor refresh (`language.toml` / `dependencies.toml` / `ecosystem.toml`) | ✅ Likely done | vidya at 2.7.0 / pin 5.9.43 — stable across two minors with active content tree |
| 5 | hoosh / ifran / daimon / mela / ark sandhi-fold audit-confirm | ✅ Confirmed clean | Zero `[deps.sandhi]` and zero include-sandhi refs in any (hoosh still on `cyrius.toml`; daimon now on .cyml 5.10.44; ark on .cyml 5.1.10 deep-lag) |
| 6 | **Boot-to-shell MVP enablement** | ✅ Cut 2026-05-11 eve | argonaut 1.7.0 + kybernet 1.2.1 add agnoshi to BOOT_MINIMAL defaults (no aethersafha dep). Unblocks closed-beta MVP path. Genesis-repo `scripts/install.cyr` provisioner is next active work. |

### CVE-2026-31431 (Copy Fail) cleanup + audit

Linux kernel LPE in `algif_aead` (AF_ALG in-place AEAD + `splice()` → 4-byte page-cache write → root). Disclosed 2026-04-29; affects mainline kernels from 2017 onward. Roadmap item **S1**.

**AGNOS-native kernel** (`agnos` v1.30.0): structurally immune — verified at `kernel/core/syscall.cyr:32-36`, 26-syscall table contains no `socket`, no `splice`, no AF_ALG family. Bug class is unreachable. (Kernel has moved from 1.26.1 → 1.30.0 since the original CVE audit; the 1.30.0 cut is a kernel-ABI break for Path-C handoff, not a syscall-surface change. Syscall table verification is anchored on the syscall-table invariant, not the kernel patch level — re-verify only if the syscall surface grows.)

| # | Action | Status |
|---|--------|--------|
| 1 | Host defconfigs — pin `# CONFIG_CRYPTO_USER_API{,_HASH,_SKCIPHER,_AEAD,_RNG} is not set` in `agnosticos/kernel/{6.6-lts,6.x-stable,7.0-devel}/configs/*defconfig` and `kernel/configs/edge-{deeplens,nuc,rpi4,rpi5}.config` | ❌ Pending — re-verified 2026-05-09: zero `CRYPTO_USER_API` refs in any host defconfig |
| 2 | Audit local crypto-adjacent repos for `AF_ALG` / `algif_aead` refs: sigil, agnosys, phylax | ✅ Done 2026-05-03 — zero hits |
| 3 | Audit when next cloned: kybernet, libro, kavach, shakti, aegis, t-ron, argonaut, ark, agnostik, bote, daimon, hoosh | ❓ Deferred — repos not all local |
| 4 | Once defconfigs pinned, document the absence-by-design pattern alongside other AGNOS-vs-Linux structural-immunity examples in `design-patterns.md` | [ ] |

### Pending Cyrius ports

| Repo | Current state | Action |
|------|---------------|--------|
| **bhava** | 2.0.0 Rust (no `cyrius.cyml` on remote) | Port can start — v5.10.x stdlib + math additions are the gating concern |
| **goonj** | 1.4.3 Rust (Cargo.toml present locally) | Acoustics — port pending |
| **naad** | 1.2.5 Rust (Cargo.toml present locally) | Audio synthesis — port pending |
| **aethersafha** | 0.1.0 scaffold | Real implementation (Wayland compositor) |
| **aethersafta** | 0.50.0 (media compositing scene graph) | Distinct from aethersafha — not a Cyrius port target, near-stable lib |

### Per-repo housekeeping (P1/P2)

Carry-forward from v5.6.x → v5.7.x → v5.8.x → v5.9.x → v5.10.x. None blocking; bundle with each repo's next natural patch.

- **`docs/development/state.md` migration** (this pattern). **Done**: cyrius, owl (2026-04-23), agnosticos (this file), sandhi, sit, vidya. **Pending**: every other repo that still carries volatile state in CLAUDE.md (verified 2026-05-06: kybernet, daimon, agnos, abaco, hoosh, kavach, mabda, sigil all missing; presume similar for the unverified tail).
- **`cyrius.toml` → `cyrius.cyml` format migration**: tail collapsed v5.10–v5.11. **Migrated** (local-verified 5.10.44+): agnoshi, bote, t-ron, kavach, itihas (remote), nein. **Remaining** (local-verified pre-CYML / no pin): hoosh, shravan. **Remote-only — unverified**: avatara, ai-hwaccel, hadara — these likely migrated alongside the wave but need cloning to confirm.
- **`[build].modules` → `[lib] modules` migration**: sigil, agnosys, shakti pending. sakshi has `dist/sakshi.cyr` but no `modules` block — investigate generation mechanism.
- **`docs/adr/` scaffold** (12 repos still missing): agnosys, sigil, takumi, phylax, ark, nous, sakshi, yukti, bsp, owl, cyrius-doom, majra. Copy `README.md` + `template.md` from sit; don't back-fill historical decisions.
- **`docs/adrs/` → `docs/adr/` rename**: argonaut last offender.
- **kiran pin-field population** — kiran shipped 1.0.0 but `cyrius.cyml` still lacks `cyrius = "X.Y.Z"`. Worth populating now that it's stable.
- **Crate registry refresh** — both registries are stale against current state. Sweep when next touched.
  - [`planning/shared-crates.md`](planning/shared-crates.md) (full registry, pre-1.0 + v1.0+): bumped 2026-05-09; **now stale again against 2026-05-11 eve snapshot** — needs another sweep. Notable bumps to apply: agnostik 1.2.0→1.2.2, agnosys 1.2.1→1.2.6, sigil 3.1.0→3.1.1, sankoch 2.0.0→2.2.5, libro 2.0.5→2.6.3, sandhi 1.3.0→1.3.4, niyama 1.0.1→1.0.2, aegis 0.8.2→**1.0.0**, cyim 1.6.7→1.7.0, chakshu 0.2.0→0.3.0, darshana 0.2.0→0.3.0. New: argonaut 1.7.0, kybernet 1.2.1 (today's cuts).
  - [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ stable subset). Last updated 2026-04-15 — predates three full minors (v5.8 / v5.9 / v5.10).

### CLAUDE.md table refresh

Root [`CLAUDE.md`](../../CLAUDE.md) "Standalone Repos" table also drifted (same pattern as shared-crates.md). When refreshing, prefer pointing to this file or to shared-crates.md rather than re-duplicating versions in CLAUDE.md.

---

## Doc / article update queue

| File | Action |
|------|--------|
| [`roadmap.md`](roadmap.md) | v5.7.x / v5.8.x / v5.9.x / v5.10.x phase definitions are now historical; v5.11.x = stdlib annotation arc + consumer-issue closeout (active); v5.12.x = bare-metal + rv64. Re-touch on each v5.11.x ship. |
| [`summer-2026-arc.md`](summer-2026-arc.md) | Cycle-theme references need re-anchoring against v5.10.x three-arc retro + v5.11.x stdlib-annotation framing. |
| [`articles/cyrius-vs-rust-benchmarks.md`](../articles/cyrius-vs-rust-benchmarks.md) | Add v5.9.x / v5.10.x / v5.11.x rows; sweep "Pure compute gap" language for closed items |
| [`articles/port-ledger-volume-1.md`](../articles/port-ledger-volume-1.md) | ✅ Refreshed 2026-05-15 — locked to v5.5.4 baseline; accreted body updates stripped; *What Comes Next* expanded to 5-volume arc (V1 baseline → V2 mid-arc → V3 end-of-5.x/v6.0 → V4 post-v6.x → V5 synthesis). Where-Rust-Still-Wins markers point at Volume 2/3. |
| **NEW** [`articles/port-ledger-volume-2.md`](../articles/port-ledger-volume-2.md) | ✅ Shipped 2026-05-15 — mid-arc state-of-things snapshot. Kernel iron-validation receipt (the V2 headline); pin-cluster review across 5.10/5.11 ecosystem; four new native subsystems (aegis 1.0.0, gnoboot 0.2.0, commandress 0.1.0, kriya 0.1.0); V1's "Where Rust Still Wins" reviewed for direction-of-motion. Re-measurement comprehensive-cut deferred to V3. |
| [`articles/doom-in-cyrius.md`](../articles/doom-in-cyrius.md) | v5.11.x rebuild numbers when cyrius-doom ships an unblock release (still on pin 5.7.48) |
| [`articles/sovereign-compiler-vs-brute-force.md`](../articles/sovereign-compiler-vs-brute-force.md) | cc5 size at **809,200 B** at v5.11.24 baseline (was 741,048 B at v5.9.0; +68 KB across v5.10.x three-arc cycle + v5.11.x .0–.24 annotation burst). **v5.11.25 → v5.11.55 delta not snapshotted** — pull current size from `cyrius/cc5` before publishing. |
| [`planning/shared-crates.md`](planning/shared-crates.md) | 🔄 Stale again as of 2026-05-11 eve. Refresh queue: agnostik 1.2.2, agnosys 1.2.6, sigil 3.1.1, sankoch 2.2.5, libro 2.6.3, sandhi 1.3.4, niyama 1.0.2, aegis **1.0.0**, cyim 1.7.0, chakshu 0.3.0, darshana 0.3.0. New: argonaut 1.7.0, kybernet 1.2.1. |
| [`docs/applications/libs/README.md`](../applications/libs/README.md) | Bump versions for v1.0+ subset; "Last Updated 2026-04-15" predates three minors |
| [`planning/first-party-documentation.md`](planning/first-party-documentation.md) | Re-read at each v5.10.x patch — meta-irony from *Docs Go Stale Before the Commit* |
| [`planning/first-party-standards.md`](planning/first-party-standards.md) | ✅ Refreshed 2026-05-09 — full Cyrius-first rewrite; Rust-era archive at `docs/archive/first-party-standards-rust-era.md` |
| **NEW** ✅ [*What Justifies a Stdlib Foldin*](../articles/what-justifies-a-stdlib-foldin.md) | Shipped 2026-05-06 — meta-process article covering the gate framework, anti-criteria, mechanism, and three-instance pattern across sandhi/vani/niyama. Subsumes per-instance article slots. |
| **NEW** ✅ Phase-3-stdlib-foldin retrospective | Landed 2026-05-06 in vidya at `content/cyrius/field_notes/compiler/retros/foldin_arc_v57_v59.cyml`. Companion to *what-justifies-a-stdlib-foldin* (process) — the retro is the experiential ledger. |
| **NEW** [*v5.10.x: three arcs in five days*] (working title) | v5.10.x retro candidate — reframe past *REAL TYPE SYSTEM in 24 patches* working title. Cycle closed 2026-05-11 at .50 with three completed arcs (typed-simd ABI 11 phases, REAL TYPE SYSTEM 5 phases, struct-byval ABI 3 phases) + 2.7× compile-perf miniarc + PE premise debunk. Draftable now. |
| **NEW** [*Typed SIMD: the substrate for native codec ports*] (working title) | Companion to *port-ledger* — the typed-simd ABI arc (v5.10.28 → v5.10.39) is the foundation that turns tarang's "framework-only, codecs via C FFI" placeholder into an eventual handwritten-SIMD-codec lane (dav1d/FFmpeg territory). Frame as the *prerequisite landed; codec arc is future-arc work post-bare-metal*. Tarang competition framing piece. |
| **NEW** ✅ darshana extraction note | When darshana ships 1.0.0, document the cyim-private → shared-library extraction pattern (single-consumer-private → second-consumer-triggers-extraction) alongside other extraction examples. |
| **NEW** [*Why AGNOS-native agents can't be drained by a tweet*] (working title) | Black Hat / summer-2026-arc Beat 2 article — AGNOS agent-injection defense as second instance of the absence-by-design structural-immunity pattern (kernel CVE-2026-31431 was the first). Spec: [`planning/agent-injection-defense.md`](planning/agent-injection-defense.md). Roadmap: Phase 15A. Draft after Phase 1 ships (post-closed-beta). |

---

## Refresh procedure

When a v5.11.x patch closes:

1. Pull current `VERSION` + `cyrius.cyml`/`cyrius.toml` for affected repos
2. Update the pin-lag spectrum if any repo crossed a band
3. Tick off swept items
4. Re-anchor "Last refresh" date in the header
5. Re-anchor "Cyrius toolchain" if a new minor cut

When v5.11.x cycle closes:

1. Move v5.11.x slot list closeout summary into a brief retrospective (one paragraph)
2. Repoint all `5.10.x` / `5.11.x` references to whichever cycle is next (likely v5.12.x — bare-metal + rv64)
3. Don't archive — rewrite in place. Git history is the snapshot.

---

## Related

- [`CLAUDE.md`](../../CLAUDE.md) — preferences/process/procedures (this doc holds the volatile state CLAUDE.md should NOT carry)
- [`applications/shared-crates.md`](applications/shared-crates.md) — authoritative crate registry (versions + roles)
- [`roadmap.md`](roadmap.md) — Cyrius milestone definitions and timeline
- [Cyrius CHANGELOG](https://github.com/MacCracken/cyrius/blob/main/CHANGELOG.md) — authoritative source for cycle status
- [Articles: *Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md) — the rationale for state.md as a pattern
- [Articles: *Your Docs Are About to Rot*](../articles/your-docs-are-about-to-rot.md) — the broader drift argument
- Per-repo `docs/development/state.md` (where it exists) — source of truth for that repo's local state; verify before acting

---

*Refreshed 2026-05-15 (header + iron-boot row spot-updated for **Attempt 31 burn (xHCI Phase 2 / controller-start verified on iron, plan-as-written first-shot — `xhci: controller running, HCH=0, ERDP=10256384`) + Phase 3 staging (port enumeration + Enable Slot + Address Device + Get Device Descriptor + HID predicate, ~640 LOC across 3 NEW files + 3 extended)** — kernel `324,736 → 339,392 bytes`, multiboot2 OK; iron-nuc-zen log gains *Attempt 31* + *Phase 3 staging post-Attempt-31* + *Attempt 32 prep* sections. Earlier same-day: **Attempt 30 burn (xHCI Phase 1 + halt/reset verified on iron) + Phase 2 staging (rings + controller-start)** — kernel `273,816 → 324,736 bytes`, multiboot2 OK; iron-nuc-zen log gains *Attempt 30 burn result* + *Phase 2 staging post-Attempt-30* + *Attempt 31 prep* sections. Earlier same-day:**Attempt 29 + cleanup pass + cleanup-pass burn (~16:45 PDT) + gnoboot 0.2.0 release staging**: ✅ shell visible on iron (Repair P confirmed) AND coherent kernel log on framebuffer post-cleanup burn (Userland exec → kybernet → shell line all rendered with proper digit/label flow); new blocker = USB-keyboard scancodes not reaching `kb_buf` despite BIOS knob + port-swap sweep (UEFI legacy SMM PS/2-emulation not active on archaemenid). MVP gap #3 falsified — primary triage failed, real-answer fallback (native XHCI + USB-HID-boot driver, ~1.5–2.5k LOC) is now the path. Cleanup pass: all 19 cp_fb() call lines stripped from main.cyr (CMOS port-I/O stamps preserved as post-mortem channel); 85 serial_print/serial_println → kprint/kprintln (fixes scrambled-digits fb-output bug — verified on burn); FB_CONSOLE_Y0 80→8 (boot_shim canary preserved); read-boot-log.cyr verdict text refreshed for post-cleanup kernel + Attempt 29 ground truth. cp_fb() fn + color palette + boot-shim canary preserved (logging infrastructure intact for future regression bisection). Kernel 266,712 → 266,312 bytes. gnoboot 0.2.0 release staging: VERSION + cyrius.cyml + msg_pre banner byte + ovmf_smoke EXPECT + CHANGELOG `[Unreleased]→[0.2.0] — 2026-05-15` all staged on 0.2 branch (uncommitted, awaiting user-driven commit/merge/tag/push). Build verified `OK` post-edits.**. Earlier same-day Repair (O) entry: mem-iso test block deleted from main.cyr after re-reading uefi-boot-prior-art.md confirmed it was post-MVP work breaking pre-MVP boot. Kernel: 255,048 → 253,496 bytes (pre-Repair-P baseline). Earlier same-day spot-updates for Attempts 21–27 + Repairs (I)/(J)/(K)/(L)/(M)/(N)/(O) summarized in the iron-boot-row narrative — full per-attempt records live in [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md).

Earlier 2026-05-15 spot-updates (Attempt 21 result + Repair (I) landed. Attempt 21 confirmed Repair (H) clean: kcp advanced 0x18 → 0x1D, [0x54]=[0x55]=0x30, AS1 SMAP round-trip fully complete, visual silent through the deleted under-AS1 cp_fb sites as expected. Death window is main.cyr:538–559 (AS2 stac/store/load/clac + second AS1 round-trip + kernel-CR3 restore) with zero bisector resolution. Repair (I) = 9-stamp port-I/O bisector (kcp=0x61..0x69) — pure diagnostic, no behavior change. Kernel **253,936 → 254,000 bytes** (+64; 72 added asm bytes, 8 absorbed by alignment padding). read-boot-log gains 9 new verdicts + revised kcp=29 baseline; binary **32,376 → 36,280 bytes**. `timer_isr[]` headroom still 1 byte (unrelated; Repair I lives in main.cyr body, not the ISR buffer). QEMU pre-flight permanently blocked for this kernel — iron is the only test surface, every Attempt costs a reboot of archaemenid. Iron Attempt 22 burn pending — USB refresh is user's next step (`sudo install-usb.sh --update /dev/sdb`). Pin-lag spectrum body still reflects 2026-05-11 eve snapshot except where called out.) Rewrite-in-place as state changes. v5.10.x history captured here is closeout-context only — Cyrius CHANGELOG is the receipt.*
