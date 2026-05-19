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

_(No photos yet — log opens 2026-05-19. First attempt will be Attempt 69 once a 1.30.10 framebuffer-refresh burn is proposed.)_

Anticipated photo themes for 1.30.10 / 1.30.11:

- **Framebuffer refresh — before/after scroll perf fix** — bench output capturing visible refresh quality before and after the chunked block-copy rewrite of `fb_scroll_up`.
- **Pitch-padding right-edge check** — full-screen view to disambiguate whether `ppl > hres` is leaking stale firmware paint into the right column band.
- **VGA-vs-HDMI handoff** — same kernel build photographed under each cable type on archaemenid to surface mode-reprogram-during-handoff effects (the open C3 hypothesis).
- **Glyph-to-font extraction** — pre-extraction baseline + first-render after externalizing CGA 8x8 glyphs from `fb_console.cyr` inline tables into a font-file format.

---

## Photo workflow conventions

- One-shot per attempt at attempt closeout. If exposure/focus is poor, add a `-reshot` sibling.
- Filename describes the attempt's signature (repair letter or symptom or milestone) so the catalog and log line up grep-wise.
- New photo lands → catalog entry follows in the same commit.
- Catalog is grouped by arc, not strictly chronological — easier to find "the photo of the Phase-3 closeout" than to scroll through 38 timestamps.
