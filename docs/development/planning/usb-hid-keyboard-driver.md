# USB-HID Keyboard Driver — Scoping & Roadmap

> **Status**: Scoping | **Drafted**: 2026-05-15 | **Target**: agnos kernel-side, in-tree
>
> Drives MVP gap #3 closeout. Real-answer fallback for Attempt 29's USB-keyboard blocker — BIOS legacy-USB knobs and every USB-A port swap have been exhausted on archaemenid; firmware genuinely does not emulate PS/2 post-`ExitBootServices`. The fix is a native XHCI + USB-HID-boot-protocol driver in the kernel.

## TL;DR

| | |
|---|---|
| Where it lives | `agnos/kernel/arch/x86_64/usb/` (new) |
| Why not a new repo | XHCI is a *bus driver*, HID is a *class driver* — both MMIO + IRQ + DMA. Kernel-only territory. Monolithic-in-kernel is the right call for MVP per `project_monolithic_by_design`. |
| Why not yukti | yukti is a Linux-userland device-abstraction lib (udev hotplug, `/proc/mounts`, sysfs ioctl). Wrong layer. |
| Scope estimate | **1.2k–2.1k LOC** total across 5 phases (revised down from initial 1.5–2.5k once the integration shape became clear) |
| Integration | New code feeds the **existing** `kb_buf` / `kb_head` / `kb_tail` ring in `kernel/arch/x86_64/boot_data.cyr`. `scancode_to_ascii()` in `kernel/arch/x86_64/keyboard.cyr` stays unchanged. The new HID path translates **HID usage codes → PS/2 set-1 scancodes** before writing into `kb_buf`. |

## Why not touch `keyboard.cyr` more than necessary

The existing scancode-to-ASCII path is good engineering: 128-entry tables, shift/caps/ctrl handling, modifier-key tracking, and a clean `kb_has_key()` / `kb_read_scancode()` API that `kernel/user/shell.cyr` already consumes. Replacing it would force a parallel re-implementation for the same problem (scancode → ASCII), and would break the moment a real PS/2 path comes back (legacy hardware, future ARM bring-up).

**Decision**: HID is a *new producer* feeding the *same buffer*. The HID interrupt handler translates HID → PS/2, writes into `kb_buf`, and the shell reads from the buffer the same way it does today. Zero churn outside the new `usb/` subtree.

## Integration surface (the only files we'll touch outside `usb/`)

| File | Change |
|---|---|
| `kernel/agnos.cyr` | Add `include "arch/x86_64/usb/xhci.cyr"` + `include "arch/x86_64/usb/hid.cyr"` |
| `kernel/core/main.cyr` | Add `xhci_init()` + `hid_kbd_init()` calls between PCI enumeration (CP 0x0B) and userland-exec. Add a CMOS checkpoint per phase landing. |
| `kernel/core/pci.cyr` | Minor: extend `pci_scan` to capture class code (offset 0x08); add `pci_read64_bar()` helper that returns the 64-bit BAR for memory-mapped BARs (XHCI BAR0 is 64-bit prefetchable). Currently `pci_devs` only stores `bar0` low-32; need bar0_hi too OR a per-call read helper. |
| `kernel/arch/x86_64/idt.cyr` (or wherever IDT gates land) | Allocate an IDT vector for the XHCI MSI/MSI-X interrupt (or fall back to legacy line, see Phase 4) |
| `kernel/arch/x86_64/boot_data.cyr` | No change — `kb_buf` / `kb_head` / `kb_tail` are the consumer-facing contract |

## Architectural choices (locked before Phase 1 starts)

| Decision | Pick | Rationale |
|---|---|---|
| Bus enumeration scope | Bus 0 only initially; widen to bus-range scan **only if** Phase 1 doesn't find XHCI on bus 0 | NUC AMD chipsets typically expose XHCI on bus 0. Defer multi-bus scan complexity. |
| BAR mapping | Identity-map (kernel is identity-mapped to 1024MB per `pt_init()`). XHCI MMIO on archaemenid will be in lower 4GB; if above 1GB we add a `vmm_alloc_at()` for the MMIO range | Already the kernel's convention; avoids inventing a new MMIO map abstraction for a one-device need |
| DMA address translation | virt == phys (kernel is identity-mapped). PMM `pmm_alloc()` returns page-aligned phys addresses directly usable by the XHCI controller | No IOMMU setup required for MVP. IOMMU comes later (`iommu.cyr` skeleton already exists). |
| Interrupt mode | **Polling first, MSI-X second.** Phase 5 ships polling-only (check event ring on every timer tick). MSI-X is a follow-up. | Polling is ~20 LOC; MSI-X is ~200 LOC. MVP doesn't need fast keypress response (60Hz is fine). Gets keyboard working end-to-end faster; MSI-X drops in cleanly later. |
| HID descriptor parsing | **Skip — use HID boot protocol exclusively.** | HID boot protocol returns a fixed 8-byte report: `[modifiers, reserved, keys[6]]`. No HID report-descriptor parsing required. ~200 LOC saved vs full-protocol. Trade-off: NKRO and exotic layouts won't work — fine for MVP (closed-beta is single-key + modifier). |
| USB device speed | **Both USB 2.0 (High Speed) and USB 3.0+ (Super Speed)** keyboards must work | Both go through the same xHCI control flow. Phase 3 port-reset has speed-specific gates but the rest is uniform. |
| Multi-keyboard support | **Single keyboard only for MVP.** First HID-boot keyboard wins; later additions ignored. | One-keyboard scope is enough to close MVP gap #3. Multi-kbd is a future capability extension. |
| Memory budget | Static allocation, ~24KB total: 4KB DCBAA + 4KB cmd ring + 4KB event ring + 16B ERST + 8KB device/input contexts + 4KB transfer ring | Page-granular, fits in PMM allocation pattern, no growth path needed for keyboard-only |

## Phasing — five gates, each iron-testable

Every phase MUST land a CMOS checkpoint + `kprintln` line so iron-burn behavior is bisectable from `read-boot-log.sh` if anything stalls.

### Phase 1 — PCIe discovery + MMIO map (~150–300 LOC)

**Goal**: Find the XHCI controller, identify-map its MMIO BAR, read capability registers, print version + slot/port counts.

| Component | LOC | Notes |
|---|---|---|
| `pci.cyr` extension: class-code capture + 64-bit BAR helper | ~40 | Modifies `PciDev` struct (+class, +bar0_hi); adds `pci_find_by_class(class, subclass, prog_if)` |
| `usb/xhci.cyr`: `xhci_probe()` | ~80 | Locates XHCI (class 0x0C, subclass 0x03, prog-if 0x30). Reads BAR0 (64-bit). Identity-maps if MMIO above 1GB. |
| `usb/xhci.cyr`: capability register reads | ~80 | `CAPLENGTH`, `HCIVERSION`, `HCSPARAMS1` (MaxSlots/MaxIntrs/MaxPorts), `HCCPARAMS1` (CSZ bit), `DBOFF`, `RTSOFF`. Store these as module globals — used by every later phase. |
| `kprintln` reporting | ~10 | `xhci: found at 0xXXXXXXXX, ver=1.10, N slots, M ports` |

**Iron-test gate**: Cold-boot archaemenid. Verify on framebuffer: `xhci: found at <addr>, ver=1.X0, N slots, M ports`. CMOS checkpoint `kcp=0x30`.

**Premise checks for Phase 1**:
- Does archaemenid expose XHCI on bus 0? (Will know in this phase.)
- Is BAR0 below 1GB? (Determines whether we need an explicit MMIO map.)

### Phase 2 — Controller init (~300–500 LOC)

**Goal**: Halt + reset the controller, allocate DMA structures (DCBAA, command ring, event ring, ERST), program operational registers, start the controller.

| Component | LOC | Notes |
|---|---|---|
| `usb/xhci_regs.cyr`: register offset constants | ~60 | Operational regs (`USBCMD`, `USBSTS`, `PAGESIZE`, `DNCTRL`, `CRCR`, `DCBAAP`, `CONFIG`, `PORTSC[N]`), runtime regs (`MFINDEX`, interrupter), doorbell array offsets |
| `usb/xhci.cyr`: halt + reset sequence | ~50 | Clear `USBCMD.R/S`, wait for `USBSTS.HCH`, set `USBCMD.HCRST`, wait for clear. Timeout via tick counter (no jiffies yet — use a simple loop bound). |
| `usb/xhci_ring.cyr`: DCBAA allocation | ~30 | One page from PMM, zero-fill, set `DCBAAP` to page phys |
| `usb/xhci_ring.cyr`: command ring init | ~80 | One page, 256 16-byte TRBs, last TRB is Link TRB pointing back to base, RCS=1. Set `CRCR` to ring base + RCS. |
| `usb/xhci_ring.cyr`: event ring + ERST init | ~80 | Event ring 1 page; ERST is one 16-byte entry pointing to event ring. Program interrupter 0: `ERSTSZ=1`, `ERSTBA=erst_phys`, `ERDP=event_ring_phys`. |
| `usb/xhci.cyr`: controller start | ~30 | `CONFIG.MaxSlotsEn = MaxSlots`. `USBCMD.R/S=1 | INTE=1`. Wait `USBSTS.HCH=0`. |

**Iron-test gate**: `xhci: controller running, HCH=0, ERDP=0xXXXXXXXX`. CMOS checkpoint `kcp=0x31`.

**Premise checks for Phase 2**:
- Does the controller reset cleanly? (Some controllers have known reset quirks — log timeout fallback path.)
- Does `pmm_alloc()` return pages we can safely DMA from? (It should — kernel is identity-mapped. Verify in Phase 2.)

### Phase 2.5 — USBLEGSUP BIOS hand-off (~55 LOC, landed)

**Goal**: Claim controller ownership from BIOS before halt/reset/operational writes. xHCI 1.2 §4.22.1: until SW writes `HC OS Owned` (bit 24) and observes `HC BIOS Owned` (bit 16) clear, SMI handlers wired for legacy USB emulation can silently absorb operational-register writes — including port `PR` writes, which is exactly the symptom Attempt 32 hit (`xhci: port 3 reset failed`).

**Trigger**: Attempt 32 (2026-05-15) — Phase 3 burn showed `port 3 reset failed` after `xhci: controller running`. Pre-bound failure mode from Phase 3 prep table. USB2 path `PR` write absorbed; `PRC` never set within 250 ms. Hypothesis: BIOS-owned USBLEGSUP semaphore still held.

| Component | LOC | Notes |
|---|---|---|
| `usb/xhci_port.cyr`: `xhci_usblegsup_claim()` | ~55 | Walk xECP chain at `mmio + xecp*4` for cap_id 1 (`XHCI_XECP_USBLEGSUP`). Set bit 24 unconditionally; poll bit 16 to clear with ~1s timeout. Prints one of four lines (`already OS-owned` / `claimed from BIOS` / `n/a (no xECP)` / `n/a (cap not present)` / `BIOS held (timeout)`). Best-effort — timeout does NOT abort init; the downstream halt/reset/start chain may still succeed on platforms whose BIOS doesn't actively interfere. |
| `usb/xhci.cyr`: call site | ~7 | At the top of `xhci_init`, right after the `xhci_present == 0` early-return and BEFORE the halt sequence. Spec-correct placement — must precede any operational-register writes. |

**Iron-test gate**: One new line above `xhci: halted, reset clean`:
- `xhci: USBLEGSUP claimed from BIOS` — **target case**. Port 3 reset should now succeed; Phase 3 enumerates.
- `xhci: USBLEGSUP already OS-owned` — BIOS hand-off was implicit on this platform. Falsifies hypothesis if port reset still fails.
- `xhci: USBLEGSUP n/a (...)` — no xECP or no USBLEGSUP cap. Falsifies hypothesis.
- `xhci: USBLEGSUP BIOS held (timeout)` — BIOS actively refuses release. Confirms hypothesis but escalates to BIOS firmware bug / wrong sequence.

### Phase 3 — Port enumeration + device address (~300–500 LOC)

**Goal**: Discover connected USB ports, reset them, assign device addresses, fetch device descriptors, identify HID keyboards.

| Component | LOC | Notes |
|---|---|---|
| `usb/xhci_port.cyr`: port-state polling | ~80 | Loop `PORTSC[0..MaxPorts]`, check `CCS` (Current Connect Status). For USB3 ports, port reset is automatic — wait for `PED` (Port Enabled). For USB2 ports, set `PR`, wait for `PRC`. |
| `usb/xhci_cmd.cyr`: command issue + completion | ~60 | Generic helper: write TRB to cmd ring, ring doorbell 0, poll event ring for `Command Completion Event`, return slot ID / completion code |
| `usb/xhci.cyr`: Enable Slot | ~30 | Command TRB type 9. Returns slot ID into `pci_dev_state[slot].slot_id`. |
| `usb/xhci_ctx.cyr`: Input Context + Device Context allocation | ~80 | 2 pages each (or 1 page if CSZ=0 in HCCPARAMS1). Zero-fill. Store DC phys in `DCBAA[slot_id]`. |
| `usb/xhci_ctx.cyr`: Slot Context + Endpoint Context 0 setup | ~80 | Slot context: root hub port, route string, speed. EP0 context: control endpoint, max packet size from speed (8 for LS, 64 for FS/HS, 512 for SS). |
| `usb/xhci.cyr`: Address Device command | ~40 | TRB type 11, input context phys, slot ID. |
| `usb/xhci.cyr`: Get Device Descriptor (control transfer) | ~80 | First fetch 8 bytes (max packet size known), then full 18. Three TRBs: Setup Stage + Data Stage + Status Stage. |
| HID keyboard predicate | ~20 | If `bInterfaceClass == 0x03` (HID) and `bInterfaceSubClass == 0x01` (boot) and `bInterfaceProtocol == 0x01` (keyboard), it's a kbd. |

**Iron-test gate**: `xhci: port N connected, slot=X, addr=Y, idVendor=0xXXXX idProduct=0xYYYY, HID-boot-kbd=yes/no`. CMOS checkpoint `kcp=0x32`.

### Phase 4 — HID boot protocol + interrupt endpoint (~200–400 LOC)

**Goal**: Configure the keyboard's interrupt-in endpoint, switch to boot protocol, allocate the transfer ring for IN reports.

| Component | LOC | Notes |
|---|---|---|
| `usb/xhci.cyr`: Get Configuration Descriptor + walk interfaces/endpoints | ~120 | Find the interrupt-IN endpoint for the keyboard interface. Record bEndpointAddress, wMaxPacketSize, bInterval. |
| `usb/xhci_ctx.cyr`: Configure Endpoint command | ~80 | Update Input Context with the interrupt-IN endpoint configured. Issue TRB type 12. |
| `usb/hid.cyr`: Set Protocol = boot (0) | ~40 | Class request: bmRequestType=0x21, bRequest=0x0B (SET_PROTOCOL), wValue=0 (boot), wIndex=interface_num, wLength=0. |
| `usb/xhci_ring.cyr`: transfer ring allocation for the kbd IN endpoint | ~40 | One page, Normal TRBs pre-filled pointing to a static 8-byte report buffer. Set EP context's `TR Dequeue Pointer`. |

**Iron-test gate**: `xhci: keyboard configured, boot protocol on, EP=0xXX, polling 8-byte reports`. CMOS checkpoint `kcp=0x33`.

### Phase 5 — Interrupt/poll-driven kb_buf feed (~200–400 LOC)

**Goal**: Process incoming HID boot reports, translate HID usage → PS/2 scancode, push into `kb_buf` so `kb_has_key()` / `kb_read_scancode()` / `scancode_to_ascii()` all light up.

| Component | LOC | Notes |
|---|---|---|
| `usb/hid_translate.cyr`: HID usage → PS/2 set-1 scancode table | ~150 | 256-entry table. HID `0x04..0x1D` (A..Z) → PS/2 `0x1E..0x10` (using set-1 ordering). HID `0x1E..0x27` (1..0) → PS/2 `0x02..0x0B`. Enter/Esc/Backspace/Tab/Space/punctuation as appropriate. **Modifier byte** in HID report (bit 0-7 = lctrl/lshift/lalt/lgui/rctrl/rshift/ralt/rgui) generates synthetic make/break PS/2 scancodes (0x2A=lshift, 0x36=rshift, 0x1D=lctrl, etc.). |
| `usb/hid.cyr`: report differ + make/break emission | ~120 | Compare current 8-byte report against previous. Keys appearing → make scancodes pushed. Keys disappearing → break scancodes pushed (high bit set). Modifier-bit changes → modifier make/break. |
| `usb/xhci_event.cyr`: event ring drain | ~80 | Poll-mode: on every timer-tick check ERDP. Process `Transfer Event` TRBs from the kbd endpoint, re-arm Normal TRB on the transfer ring. Update ERDP. |
| `core/main.cyr` hook | ~20 | Call `xhci_poll()` from the existing timer ISR path or scheduler tick. (One call site; trivial.) |
| `usb/hid.cyr`: `kb_buf` writer | ~30 | Push scancode bytes into `kb_buf` at `kb_head`, advance head wrap-at-256. Same convention as `kb_isr_build()` writes today — just from a different producer. |

**Iron-test gate**: Boot archaemenid. Press 'a' — `agnos>` shows `a`. Press shift+B — `B`. Press Enter — newline + shell prompt re-paints. CMOS checkpoint `kcp=0x34`.

## File layout

```
agnos/kernel/arch/x86_64/usb/
├── xhci.cyr           # Top-level: probe, init, port enum, address device
├── xhci_regs.cyr      # Capability + operational + runtime register offset constants
├── xhci_ring.cyr      # Command ring, event ring, ERST, transfer ring allocation + drain
├── xhci_cmd.cyr       # Command issue + completion polling helper
├── xhci_ctx.cyr       # Input Context, Device Context, Slot Context, Endpoint Context
├── xhci_port.cyr      # Port reset, port-state polling
├── xhci_event.cyr     # Event ring drain (used by both cmd completion + transfer events)
├── hid.cyr            # HID boot-protocol report parse, report differ, make/break emission
└── hid_translate.cyr  # HID usage code → PS/2 set-1 scancode table
```

`agnos.cyr` adds two `include` lines (xhci.cyr + hid.cyr; each pulls its siblings via project includes).

## CMOS checkpoint allocation

| `kcp` | Stage | Source |
|---|---|---|
| `0x30` | xHCI probed (Phase 1 gate) | `xhci_probe()` exit |
| `0x31` | xHCI controller running (Phase 2 gate) | `xhci_init()` exit |
| `0x32` | First HID keyboard addressed (Phase 3 gate) | `xhci_address_device()` exit on first kbd |
| `0x33` | Keyboard boot protocol active (Phase 4 gate) | `hid_kbd_configure()` exit |
| `0x34` | First keypress in `kb_buf` (Phase 5 gate) | First successful `hid_emit_scancode()` |

Update `agnosticos/scripts/src/read-boot-log.cyr` verdict table when each phase lands.

## What this driver explicitly does NOT do (deferred / out-of-scope)

| Feature | Why deferred |
|---|---|
| HID report-descriptor parsing | Boot protocol is fixed-format; no parser needed for MVP. Full HID parser is a separate ~500 LOC project for non-keyboard devices later. |
| USB hubs (multi-tier) | Hubs are a class driver of their own (~300 LOC). Single-tier (root-hub-only) covers every direct keyboard plug. |
| Mass storage / generic USB | Different class, different transfer patterns (bulk-only transport). Storage-class driver is a future arc once VFS is solid. |
| Mice / gamepads / non-keyboard HID | Same class (HID) but different boot-protocol report shape (mouse is 3-byte). Add when we have a use case. |
| MSI-X interrupts | Phase 5 ships poll-mode; MSI-X is a clean drop-in later. |
| USB2 / USB3 hot-plug | Initial enumeration only. Hotplug means responding to `Port Status Change` events — comes free with MSI-X enablement, ~50 LOC. |
| IOMMU / DMA remapping | Identity-map suffices for MVP. `iommu.cyr` skeleton exists; full activation is a separate hardening pass. |
| Power management (USB suspend/resume) | Not needed for closed-beta. |

## Risk register

| Risk | Mitigation |
|---|---|
| archaemenid XHCI BAR0 above 1GB | Phase 1 detects this; `vmm_alloc_at()` extends mapping. Cost: ~10 LOC. |
| XHCI controller doesn't reset cleanly | Add timeout fallback in Phase 2; fall back to "reset retry × 3" pattern. Cost: ~20 LOC. |
| Some keyboards don't expose boot protocol | All HID-class keyboards must support boot per USB-HID spec § 7.2.5. If a kbd violates this, it's a hardware bug — skip and try next port. Cost: zero LOC, just a class check. |
| HID interrupt endpoint polling rate too slow | bInterval in HID descriptor (typically 8–10ms = 100Hz). Poll loop runs on timer tick at 100Hz — match. If keypresses miss, bump timer rate; that's a follow-up tune. |
| DMA isn't coherent | x86_64 is cache-coherent for normal MMIO + DMA on contemporary hardware; no manual flushing required. If we ever port this to ARM, that changes — flag in the doc. |
| MMIO mapped as cacheable (write-back) | UEFI sets MTRR/PAT for the firmware-described memory; XHCI MMIO ranges are typically pre-set to uncacheable. If not, we'd need to mark the BAR as UC- ourselves. Defer until Phase 1 surfaces the problem. |

## Out-of-band: gnoboot capture-and-handoff (alternative discarded)

We could ask gnoboot to use UEFI `SimpleTextInputProtocol` to read keystrokes pre-`ExitBootServices` and pass them through the boot-info struct. **Rejected**: works for one prompt at boot time, not for a running shell. Solves the wrong problem.

## Schedule estimate

Each phase is 1–2 iron burns (one for the build + initial print, one for any visual regression) + 0.5–1 day of coding. End-to-end estimate: **~5–8 working days** for keyboard-only, including the integration test (typing the alphabet + a shell command on iron).

Phases 1 + 2 are the highest-uncertainty (XHCI register dance + controller bring-up); Phases 3–5 follow well-trodden USB-HID territory and should slip less.

## Acceptance criteria

Closed-beta keyboard-on-iron is satisfied when:

1. Cold-boot archaemenid lands at `agnos>` prompt (already true post-Repair P).
2. Typing `help` on a USB keyboard plugged into any USB-A port produces visible characters on the framebuffer.
3. `Enter` submits the command; `help` (or whatever's wired in agnoshi) prints output.
4. Caps Lock + Shift + Ctrl modifier handling matches existing PS/2 behavior (validated against `kb_caps` / `kb_shift` / `kb_ctrl` already-tested paths via `scancode_to_ascii`).
5. CMOS `kcp` checkpoint reaches `0x34` post-handshake on every boot.

Stretch: Backspace + line-editing work in agnoshi (depends on shell's input loop, not the driver — verified incidentally).

## Open questions to resolve before Phase 1 code lands

1. **PCI bus range** — confirm XHCI is on bus 0 by booting current kernel and inspecting `pci_count` output. If XHCI isn't found by Phase 1's `pci_find_by_class(0x0C, 0x03, 0x30)`, widen the scan in `pci.cyr` to multi-bus.
2. **MMIO mapping above 1GB** — Phase 1's first burn answers this. If BAR0 ≥ `0x40000000` (1GB), we need a one-line `vmm_alloc_at(bar0_addr)` extension before any register read.
3. **Page-table mapping of allocator-returned pages** — verify `pmm_alloc()`-returned pages are present in the current page table AND readable from kernel CR3. Should be true (kernel is identity-mapped) but a Phase 2 sanity check (write-then-read a known pattern) is worth the 5 LOC.

## Related

- [`iron-nuc-zen-log.md`](../iron-nuc-zen-log.md) § *USB-keyboard blocker triage* — origin of the problem
- `agnos/kernel/arch/x86_64/keyboard.cyr` — existing scancode → ASCII path the new producer feeds
- `agnos/kernel/core/pci.cyr` — PCI enumeration surface to extend
- USB-HID spec §7 (boot protocol report format) — primary reference
- xHCI spec §4 (initialization), §6 (data structures), §7 (command + event TRBs) — primary reference
