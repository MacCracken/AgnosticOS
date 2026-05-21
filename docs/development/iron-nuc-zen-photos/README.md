# Iron Boot Photo Catalog

Photographic record of iron-boot test attempts on **archaemenid** (NUC AMD,
Beelink SER, Zen-class x86_64). Each photo captures the framebuffer state
at attempt closeout — visual canary cells, kernel banner, xhci status,
HID-enumeration output, shell prompt, or framebuffer noise.

**Companion logs**:
- [`iron-nuc-zen-log-mvp.md`](../iron-nuc-zen-log-mvp.md) — Attempts 1–68 (closed-beta MVP era, capped 2026-05-19)
- [`iron-nuc-zen-log.md`](../iron-nuc-zen-log.md) — Attempts 69+ (post-MVP, 1.30.10+)

**Photo naming convention**: `attempt-NN-<short-handle>[-reshot].jpg`. "reshot" suffix indicates the same attempt was photographed twice for clarity / focus / re-exposure — both retained.

**Source of truth for attempt narrative is the log file**, not the catalog entry. The catalog is a navigation aid keyed on filename, not a substitute for reading the attempt body.

---

## Visual canary era (Attempts 15–29)

Early boot bring-up before xhci work began. Goal: paint colored cells via `cp_fb` to confirm the kernel reached each subsystem-init stage, then graduate to text rendering via fb_console.cyr.

| Photo | Date | What it shows |
|-------|------|---------------|
| `attempt-15-boot-colors.jpg` | 2026-05-13 | First successful cp_fb cell paint on iron — boot_shim canary + early arch stages |
| `attempt-16-boot-colors.jpg` | 2026-05-14 | More cells reached; subsystem-init progress visible |
| `attempt-18-boot-colors-reset-only.jpg` | 2026-05-14 | Reset-only burn (no behavioral change) for baseline |
| `attempt-25-boot-colors-racy.jpg` | 2026-05-15 | Race-condition narrative — cell paint shows non-deterministic stop point |
| `attempt-28-mvp-spine-alive.jpg` | 2026-05-15 | MVP spine reached scheduler + userland; cell grid fully painted through scheduler color |
| `attempt-29-shell-logging-cleanup.jpg` | 2026-05-15 | Shell prompt visible on iron for the first time (text console live); pre-typeable |
| `attempt-29-shell-visible-no-keys.jpg` | 2026-05-15 | Same attempt, shell visible but no keyboard input — the seed of the xhci HID arc |

---

## xhci Phase 1: controller discovery (Attempts 30)

Locate the xHCI controller on the PCI bus; the first half is "did PCI enum find a USB 3.x controller class," the second is "is BAR 0 valid."

| Photo | Date | What it shows |
|-------|------|---------------|
| `attempt-30-xhci-phase1-no-controller-found.jpg` | 2026-05-15 | First Phase-1 burn — controller-not-found case |
| `attempt-30-xhci-phase1-controller-found.jpg` | 2026-05-15 | Phase-1 success — xHCI controller discovered on PCI |

---

## xhci Phase 2: initialization scaffolding (Attempts 31, 33)

USBSTS / USBCMD register I/O, command ring setup, event ring scaffolding.

| Photo | Date | What it shows |
|-------|------|---------------|
| `attempt-31-xhci-phase-2.jpg` | 2026-05-15 | Phase-2 controller-init scaffolding working |
| `attempt-33-phase-2-5-corrupted.jpg` | 2026-05-16 | Phase-2.5 — corrupted output indicates init-order bug |

---

## xhci Phase 3 silent-absorb arc (Attempts 38–55)

Port reset / PortSC silent-absorb — multi-letter repair ladder (Repair S → BB → CC → DD → EE) chasing what turned out to be `xhci_portsc_write`'s inner re-mask stripping the RW1S PR bit. Closed at Attempt 55 / Repair EE / agnos@41ee6dc with a one-line fix.

| Photo | Date | What it shows |
|-------|------|---------------|
| `attempt-38-xhci-phase-3-pp-asserted-reset-failed.jpg` | 2026-05-16 | Phase-3 entry — PP asserted, port reset failed |
| `attempt-39-xhci-r10-pls-polling-pr-still-absorbed.jpg` | 2026-05-16 | Repair R.10 — PLS polling; PR bit still absorbed |
| `attempt-40-xhci-repair-s-pp-collapse.jpg` | 2026-05-16 | Repair S — PP collapse signature |
| `attempt-43-xhci-repair-v-f5-confirmed-bar-wb-cached.jpg` | 2026-05-16 | Repair V (F5) — BAR memtype confirmed WB-cached (audit win) |
| `attempt-44-xhci-repair-x-uc-remap-still-absorbed.jpg` | 2026-05-17 | Repair X — UC-remap; symptom survives |
| `attempt-49-xhci-plumbing-bundle-msi-x-still-absorbed.jpg` | 2026-05-17 | Plumbing bundle + MSI-X — symptom survives |
| `attempt-50-xhci-repair-aa-scratchpad-installed-still-absorbed.jpg` | 2026-05-17 | Repair AA — scratchpad installed; symptom survives |
| `attempt-51-xhci-repair-bb-dnctrl-still-absorbed.jpg` | 2026-05-17 | Repair BB — DNCTRL; symptom survives |
| `attempt-52-xhci-repair-cc-dd-still-absorbed.jpg` | 2026-05-17 | Repair CC + DD bundled; symptom survives |
| `attempt-54-xhci-phase-4-5-iron-clean-still-absorbed.jpg` | 2026-05-17 | Phase 4–5 iron-clean; symptom survives |
| `attempt-55-xhci-reset-unblock-enable-slot-ccode-0.jpg` | 2026-05-17 | **Repair EE — Phase-3 unblocked** at agnos@41ee6dc (Enable Slot CCode=0 success); silent absorb closed |

---

## xhci Phase 4 cmd-path silent-absorb arc (Attempts 56–63)

10-letter repair ladder (FF → GG → HH → JJ → KK → LL → MM → NN → OO → QQ+QQ2) chasing what turned out to be a **Cyrius compiler bug**: gvar-init-order zero-reads at file scope. `XHCI_CMD_TIMEOUT_SPINS = 10000000` and `XHCI_EVT_RING_SEGMENT_SIZE = 256` read as 0 → spin loop never executed, ERST segment 0-sized. Root cause fixed in cyrius **v5.11.64** (issue `2026-05-18-gvar-init-order-zero-reads.md`); the entire 10-letter ladder was falsified silicon hypotheses chasing a compile-time bug.

| Photo | Date | What it shows |
|-------|------|---------------|
| `attempt-56-xhci-instrumentation-burn-events-seen-zero.jpg` | 2026-05-17 | Instrumentation burn — `events_seen=0` confirmed |
| `attempt-57-xhci-repair-ff-ie-set-events-seen-still-zero.jpg` | 2026-05-17 | Repair FF — IMAN.IE=1; events still 0 |
| `attempt-58-xhci-repair-gg-amdvi-disabled-events-seen-still-zero.jpg` | 2026-05-17 | Repair GG — AMD-Vi disabled; events still 0 |
| `attempt-58-xhci-repair-gg-amdvi-disabled-events-seen-still-zero-reshot.jpg` | 2026-05-17 | Same attempt — reshot for clarity |
| `attempt-59-xhci-edit-b-delivered-cycle-bit-clean-events-still-zero.jpg` | 2026-05-17 | Repair JJ/Edit-B — cycle bit clean; events still 0 |
| `attempt-60-stack-bundled-still-zero.jpg` | 2026-05-18 | Stack-bundled (KK/LL/MM); events still 0 |
| `attempt-60-stack-bundled-still-zero-reshot.jpg` | 2026-05-18 | Same attempt — reshot |
| `attempt-61-xhci-repair-nn-erdp-before-erstba-crcr-after-imod-events-still-zero.jpg` | 2026-05-18 | Repair NN — ERDP→ERSTBA reorder, CRCR after IMOD; events still 0 |
| `attempt-62-shell-visible-events-still-zero.jpg` | 2026-05-18 | Shell visible on iron (visual MVP); xhci events still 0 |
| `attempt-63-shell-visible-on-iron-events-still-zero.jpg` | 2026-05-18 | **Visual MVP gate hit** (agnos 1.30.7) — FB renders agnoshi banner; xhci events still 0 |
| `attempt-63-shell-visible-on-iron-events-still-zero-reshot.jpg` | 2026-05-18 | Same attempt — reshot |

---

## xhci Phase 4 root-cause + Phase 5: HID → MVP gate (Attempts 65–68)

Post-cyrius-v5.11.64 fix burns. Each Phase-4/5 milestone landed in a single audit-then-burn pass with zero letter ladder, per `feedback_known_knowledge_first` + `feedback_redesign_dont_reinvent`.

| Photo | Date | What it shows |
|-------|------|---------------|
| `attempt-65-xhci-silent-absorb-hurdled-hid-config-9-timeout.jpg` | 2026-05-18 ~19:07 PDT | Phase-3 cleared end-to-end on iron (Enable Slot + Address Device + GDD-8/18 all succeed); new blocker: `xhci_get_config_descriptor(slot, 0, 9)` timeout in `hid_kbd_configure` |
| `attempt-66-ep0-control-transfer-hardening-hid-config-9-still-timeout.jpg` | 2026-05-18 ~20:08 PDT | Repair RR (Linux-canonical EP0 control-transfer hardening) — falsified; GCD-9 still times out |
| `attempt-67-ep0-mps-reconciliation-hid-configured-typing-silent.jpg` | 2026-05-18 ~20:58 PDT | **Phase-4 cleared** — EP0 MPS reconciliation (xHCI 1.2 §4.6.7) lands; full HID enumeration succeeds; keyboard configured; FB shows `agnoshi shell v1.30.8`; new blocker: keypresses produce no characters (interrupt-IN silent) |
| `attempt-68-typeable-shell-on-iron.jpg` | 2026-05-18 ~21:30 PDT | **🎯 MVP GATE HIT** (agnos 1.30.9) — SET_CONFIGURATION + canonical FS interval + ISP bundle lands; `agnos> echo "Assembly Up!"` echoed back on iron Logitech (VID=1452 PID=591) |
| `attempt-68-bench-three-tier-on-iron.jpg` | 2026-05-18 ~21:30 PDT | 3-tier bench running on iron under typeable shell — fibonacci 133 c/op, syscall_write 31 c/op, open+read+close 256 c/op, serial putc ~11.6 c/op. **Pixel-pattern noise visible in lower FB region** → 1.30.10 framebuffer-refresh scope |

---

## Post-MVP era (Attempts 69+)

| Photo | Date | What it shows |
|-------|------|---------------|
| `attempt-70-help-me-build-an-entity-chart.jpg` | 2026-05-19 | **First natural-language user input on iron.** 3-tier bench output visible above (`syscall_write1: 31 c/op`, `vfs_open_read_close: 256 c/op`, `=== done ===`). Then `agnos> Help me build an entity chart` typed by a new user (Alicia), `unknown: Help` from the shell (bareword parser hit "Help" before the LLM lane exists), retry as `agnos> help` produces the 18-verb command list. Captures the gap between AI-native user intent and pre-userland kernel verbs — exactly what later phases (daimon/hadara/agnoshi LLM wiring) close. WB→WC residual pixel-pattern band visible in upper-middle FB region; lower half (shell list render) clean — 1.30.10 framebuffer-refresh signature post-Attempt-70 u64 block-copy. |
| `attempt-71-quickboot-vga-pass-reshot.jpg` | 2026-05-19 | Same attempt — reshot of the 1.30.11 VGA-spec PASS boot log with cleaner exposure; the original `13011_attempt_gnoboot_updated.jpg` filename reflected the gnoboot 0.3.0 → 0.4.x update milestone that landed in this same burn. |
| `attempt-71-quickboot-vga-pass.jpg` | 2026-05-19 | **1.30.11 hardening burn — QuickBoot ON + VGA-spec display path PASSES end-to-end.** Full boot log visible top-to-bottom: `AGNOS kernel v1.30.11`, ring-3 ready, US QWERTY installed, xHCI brings up 4 slots / 6 ports, USB keyboard enumerated (`slot=1 VID=1452 PID=591` — the Logitech from the MVP-era Attempt-68 gate-hit), `boot protocol on EP=129 polling 8-byte reports`, scheduler ticked 154 timer interrupts before sched arm, kybernet starting init with 354 free pages, `AGNOS shell v1.30.11 (type 'help')` prompt landed. Companion outcome — **Quiet Boot ON path still returns the Attempt-33 garbled-glyph signature** on the same kernel binary (BIOS toggle is the only variable) — falsifies the pf-aware-PixelFormat hypothesis that motivated 1.30.11's hardening (pf-guard would have produced a black screen if pf were ≥ 2; observed garble means BGRX branch took and paint fired against corrupted geometry). Drives the Attempt 72 diagnostic-extension cycle (gnoboot 0.3.0 + agnos working-tree FB-handoff observability — GOP `Mode->Mode`/`MaxMode` capture, serial `fb: mode=N/M …` diagnostic, CMOS extended-bank stamp at `0x90..0x9F` for archaemenid-no-serial read-back via `read-boot-log.sh`). |

| `attempt-77-quiet-boot-true-font-lines-off.jpg` | 2026-05-20 | **1.30.12 true-font swap landed — VGA path confirmed by user (new font legible + slight scroll speed improvement); Quiet Boot path still has render-math misalignment** ("lines off" — horizontal banding cuts through glyphs, suggesting pitch/stride or row-stride math is wrong somewhere in the quiet-mode display path). Photo captures the quiet-mode failure mode; VGA-pass outcome reported in chat (paraphrase from user): *"can confirm the new font and slight speed improvements for VGA; quiet mode is still got some off math some where."* |
| `attempt-80-nvme-iron-debut-crucial-p3.jpg` | 2026-05-20 | **NVMe iron debut on archaemenid — Crucial P3 2 TB enumerated end-to-end.** VID=0xC0A9 (Micron), model `CT2000P3SSD8`, firmware `P9CR30A`, NSZE 3907029168 × 512B = 1.86 TB usable, LBA0 read returned 8 zeros (blank surface), registered as block_dev, kernel walked through VFS → scheduler → kybernet → `AGNOS shell v1.31.0`. First-iron-try success for the entire Phase 1-5 NVMe stack — contrast with the xHCI arc's 5-week 19-attempt 9-letter ladder. |
| `attempt-81-ahci-iron-debut-wd-blue-sa510.jpg` | 2026-05-20 | **AHCI/SATA iron debut on archaemenid — WD Blue SA510 2.5" 2 TB SATA SSD enumerated, IDENTIFY decoded, LBA-5 round-trip PASSED.** HBA at `0xFCDA0000`, version `0x10300` (1.769 → AHCI 1.3 rev), NP=1 NCS=32 ISS=3 (6 Gbps) SNCQ=1 S64A=1, GHC bit 31 set (AHCI enable), PI=1 → port 0 only. Port 0 DET=3 SPD=3 SIG=257 (SATA), CL @ 0x5B6800, FIS @ 0x5B7000. IDENTIFY: model `WD Blue SA510 2.5 2TB`, serial `24313QD00663`, fw `5304 00WD`, LBA48=3907029168 sectors (1907729 MiB ≈ 2 TB). LBA0 first 8 bytes `146 20 0 0 0 111 111 116` (real-disk content, not zeros — different surface than the NVMe). **LBA-5 write-then-read round-trip PASS** — full bidirectional DMA I/O working on real silicon. **§4 mitigation NOT applied** for this burn — the audit's compile-gated write-demo lever was deferred and the sentinel landed on the WD's GPT partition-entry array (entries 12-15, likely unused). Caveat captured for the attempt body. **Second IDENTIFY in `ahci_register_block_dev` timed out** (`PxCI stuck`) — registration silently bailed → AHCI did NOT register as a secondary block_dev. Boot continued cleanly: GPT parsed the NVMe (hdr-CRC-OK arr-CRC-OK, 2 partitions), VFS → kybernet → `AGNOS shell v1.31.1`. Second iron debut of the 1.31.x storage arc. |

Anticipated photo themes for 1.30.12+ (Attempt 72 forward):

- **Framebuffer refresh — before/after scroll perf fix** — bench output capturing visible refresh quality before and after the chunked block-copy rewrite of `fb_scroll_up`.
- **Pitch-padding right-edge check** — full-screen view to disambiguate whether `ppl > hres` is leaking stale firmware paint into the right column band.
- **VGA-spec vs Quiet Boot diff (Attempt 72 deliverable)** — two-boot diff under the new FB-handoff observability bundle. `attempt-72-vga-spec-baseline.jpg` + `attempt-72-quiet-boot-fail.jpg` photographed back-to-back, plus the `read-boot-log.sh` text capture for both CMOS post-mortems showing the GOP `mode#`, `w/h/pitch`, `pf`, `mode_max` values archaemenid's firmware exposed under each BIOS toggle. The actual diagnostic record is the two text dumps; the photos anchor the visual outcome to those numbers.
- **Glyph-to-font extraction** — pre-extraction baseline + first-render after externalizing CGA 8x8 glyphs from `fb_console.cyr` inline tables into a font-file format.

---

## Photo workflow conventions

- One-shot per attempt at attempt closeout. If exposure/focus is poor, add a `-reshot` sibling.
- Filename describes the attempt's signature (repair letter or symptom or milestone) so the catalog and log line up grep-wise.
- New photo lands → catalog entry follows in the same commit.
- Catalog is grouped by arc, not strictly chronological — easier to find "the photo of the Phase-3 closeout" than to scroll through 38 timestamps.
