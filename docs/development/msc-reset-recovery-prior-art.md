---
name: USB MSC Reset Recovery — Prior Art + Phase 2.6 Fix Plan
description: Linux + xHCI spec walk for the controller-side half of USB MS Reset Recovery, written after Attempt 84 iron evidence
type: engineering-diagnosis
---

# USB MSC Reset Recovery — Phase 2.6 Prior-Art Walk

**Status:** Phase 2.5 (device-side BBB Reset + host-side ring rewind) landed in `[Unreleased]` commits `90367d5` + `18bd2bd` and validated on iron at Attempt 84 2026-05-21. Iron evidence shows device-side recovery alone is insufficient on a commodity USB 2.0 stick (Silicon Motion / SMI controller, VID `0x090C`). Phase 2.6 adds the xHCI controller-side half: Reset Endpoint + Stop Endpoint + Set TR Dequeue Pointer commands.

This doc is the **prior-art audit + fix plan** for that touch. Per `feedback_redesign_dont_reinvent` — Linux and the xHCI 1.2 spec are canonical references; no first-principles diagnostic letters. Per `feedback_stop_letter_laddering` — single burn, stack all named patches.

---

## 1. Iron evidence (Attempt 84)

Three Reset Recovery cycles each completed (`Reset Recovery OK` printed) and the next bulk transfer wedged each time at a *different* step:

| Recovery cycle | Following wedge | xHC-side hypothesis |
|----------------|-----------------|---------------------|
| Initial probe (no recovery yet) | INQUIRY data phase (bulk-IN) timed out | Bulk-IN EP transitioned to Halted on the device's data-phase Stall; xHC reflected Halted in EP context |
| After Reset Recovery #1 | TUR retry 1 CSW receive (bulk-IN) timed out | xHC's bulk-IN EP context still Halted; CLEAR_FEATURE(HALT) cleared the *device-side* halt but xHC's EP state machine wasn't told |
| After Reset Recovery #2 | TUR retry 2 CBW issue (bulk-OUT) timed out | Bulk-OUT EP wedged too; CSW tag mismatch one transfer earlier proved device buffered stale CSW |
| After Reset Recovery #3 | TUR retry 3 CBW issue (bulk-OUT) timed out | Same as #2 — recovery not progressing |

The CSW tag mismatch (immediately *before* the first Reset Recovery) is the load-bearing clue. The signature dword `0x53425355` ('USBS') validated, but the tag echo didn't match the CBW just issued — meaning the device had a leftover CSW from the aborted INQUIRY queued in its bulk-IN endpoint buffer, and the host's CSW-receive TRB picked that up instead of a fresh one. Commodity USB 2.0 sticks frequently fail to drain bulk-IN buffers on Bulk-Only Reset (BBB §6.7.3 says they *should*; many don't).

---

## 2. What `msc_reset_recovery` does today (Phase 2.5)

`msc.cyr:764-820`:

```
1. xhci_control_no_data(slot, 0x21, 0xFF, 0, intf)     # Bulk-Only MS Reset (class CTRL)
2. xhci_control_no_data(slot, 0x02, 0x01, 0, ep_in)    # CLEAR_FEATURE(HALT) bulk-IN
3. xhci_control_no_data(slot, 0x02, 0x01, 0, ep_out)   # CLEAR_FEATURE(HALT) bulk-OUT
4. Re-zero bulk-IN ring page + rewrite Link TRB at slot 63
5. Re-zero bulk-OUT ring page + rewrite Link TRB at slot 63
6. row[bulk_in_cycle]=1, row[bulk_out_cycle]=1, row[bulk_in_idx]=0, row[bulk_out_idx]=0
7. row[transport_failed]=0
```

All four "device-side" steps land cleanly on iron (we see `Reset Recovery OK`). The host-side ring rewind also runs unconditionally — `row` fields are reset, ring memory is zeroed, Link TRBs are rewritten.

**What's missing: nothing in this sequence touches the xHC's per-endpoint state.** The xHC maintains its own copy of the TR Dequeue Pointer (TRDP) and an endpoint state machine (Disabled / Running / Halted / Stopped / Error per xHCI 1.2 §4.8.3) in the Device Context. Software cannot mutate either by writing to host memory — both are owned by the controller. Software changes them by issuing xHCI commands.

---

## 3. xHCI spec: endpoint state machine + recovery sequence

### 3.1 EP state transitions on Halt (xHCI 1.2 §4.10.2.1)

> When the xHC encounters a Stall PID on a transfer, the affected endpoint transitions to the **Halted** state and the xHC stops fetching TRBs from that endpoint's Transfer Ring. The xHC posts a Transfer Event with Completion Code = **STALL_ERROR (6)** and updates the EP Context's TR Dequeue Pointer field to point at the TRB that halted.

What this means for AGNOS at Attempt 84:
- INQUIRY data-phase Stall → bulk-IN EP context → Halted
- xHC will not process any further enqueues on bulk-IN until software issues **Reset Endpoint**
- The doorbell ring at `xhci_mmio_base + db_off + slot*4` becomes a no-op for that DCI
- This explains *every* subsequent `transfer event timeout` on bulk-IN

### 3.2 Canonical recovery (xHCI 1.2 §4.6.8 Reset Endpoint Command)

> Software must clear a Halted endpoint by issuing the **Reset Endpoint Command** (TRB type 14). This transitions the endpoint from Halted to Stopped. **Following the Reset Endpoint Command, software must issue a Set TR Dequeue Pointer Command** (TRB type 16) to indicate where the xHC should resume fetching TRBs. After the Set TR Dequeue Pointer Command completes, the endpoint transitions from Stopped to Running on the next Doorbell.

### 3.3 Set TR Dequeue Pointer (xHCI 1.2 §4.6.10)

> The TR Dequeue Pointer field of the Endpoint Context **may only be modified by the xHC** during normal operation. Software changes the TR Dequeue Pointer by issuing this command. The new TRDP is given as `dequeue_ptr | DCS` where DCS is the Dequeue Cycle State the xHC should expect on the next TRB.

For AGNOS post-recovery: `dequeue_ptr = ring_phys`, `DCS = 1` (because the host-side rewind set producer cycle to 1 and re-zeroed the ring, so the next TRB written will have cycle=1).

### 3.4 Stop Endpoint (xHCI 1.2 §4.6.9) — for Running-but-stuck case

If an endpoint is in Running state but a transfer never completes (e.g., CSW receive timeout where device just doesn't send the CSW, *without* halting), software issues **Stop Endpoint** (TRB type 15) to force the EP into Stopped state. Then the Reset Endpoint / Set TR Dequeue Pointer pair runs as above.

For Attempt 84 we can't distinguish Halted from Running-but-stuck without reading the EP Context (which would need MMIO into the Device Context Base Address Array — possible but more invasive). The safe path: issue Stop Endpoint first; the command is idempotent on already-Stopped EPs (returns Context State Error on Halted, which is fine — we proceed to Reset Endpoint anyway).

---

## 4. Linux's recovery sequence — file:function refs

### 4.1 USB-storage class layer (`drivers/usb/storage/transport.c`)

- **`usb_stor_invoke_transport`** (lines ~530–650): the per-command driver loop. Issues Bulk-Only Transport (`usb_stor_Bulk_transport`); on error, dispatches to `usb_stor_invoke_transport`'s recovery branch which calls `usb_stor_Bulk_reset`.
- **`usb_stor_Bulk_transport`** (~330–490): the function AGNOS's `msc_bbb_exec` mirrors. Issues CBW → data phase → CSW. On CSW signature/tag mismatch, calls `usb_stor_clear_halt` on bulk-IN and tries to read another 13 bytes (the "stale CSW drain" pattern). If the second read also fails, falls through to full reset.
- **`usb_stor_Bulk_reset`** (~700): issues Bulk-Only Mass Storage Reset class request, then calls `usb_stor_clear_halt` on bulk-IN and bulk-OUT. **This is what Phase 2.5 ports.** Crucially: USB-storage at this layer does NOT know about xHCI EP context — it trusts the HCD (host controller driver) to do controller-side recovery transparently.
- **`usb_stor_clear_halt`** (~770): issues the standard CLEAR_FEATURE(ENDPOINT_HALT) control transfer, **then calls `usb_clear_halt`** from `drivers/usb/core/message.c` which calls **`usb_reset_endpoint`** which fans out to `hcd->driver->endpoint_reset`. For xHCI HCDs this dispatches to:

### 4.2 xHCI HCD layer (`drivers/usb/host/xhci.c` + `xhci-ring.c`)

- **`xhci_endpoint_reset`** (`xhci.c` ~3550): the xHCI HCD's `endpoint_reset` callback. Wraps the Reset Endpoint command + the Set TR Dequeue Pointer command into a single recovery primitive. **This is the function AGNOS's Phase 2.5 doesn't have any analog of.** Called automatically by the USB core after `usb_clear_halt`.
- **`xhci_queue_reset_ep`** (`xhci-ring.c` ~4280): builds the Reset Endpoint command TRB and submits to the command ring. TRB layout:
  ```
  dword 0:  0  (reserved)
  dword 1:  0  (reserved)
  dword 2:  0  (reserved)
  dword 3:  (slot_id << 24) | (ep_index << 16) | (TSP << 9) | (14 << 10) | cycle
  ```
  where `TSP` (Transfer State Preserve) bit 9 is normally 0 (clears EP state fully).
- **`xhci_queue_new_dequeue_state`** (`xhci-ring.c` ~4220): builds the Set TR Dequeue Pointer command TRB. Format:
  ```
  dword 0:  (deq_ptr_lo & ~0xF) | DCS    # DCS in bit 0
  dword 1:  deq_ptr_hi
  dword 2:  (stream_id << 16)            # 0 for non-stream EPs
  dword 3:  (slot_id << 24) | (ep_index << 16) | (16 << 10) | cycle
  ```
- **`xhci_handle_cmd_reset_ep` / `xhci_handle_cmd_set_deq`** (`xhci-ring.c` ~1700, ~1620): the completion-event handlers. Re-arm the endpoint by ringing the doorbell after Set TR Dequeue completes.
- **`xhci_handle_halted_endpoint`** (`xhci-ring.c` ~3500 in 6.x): driver-internal helper that bundles Stop Endpoint + Reset Endpoint + Set TR Dequeue Pointer into a single call. Used when the HCD itself notices a TRB completed with STALL_ERROR.

### 4.3 EP DCI computation

`drivers/usb/host/xhci.c` has the standard formula USB-3 capable HCDs use:
- Bulk-IN at endpoint number `N`: `DCI = 2*N + 1`
- Bulk-OUT at endpoint number `N`: `DCI = 2*N`
- Control EP0 = DCI 1

AGNOS already stores the precomputed DCI per direction at `row + 40` (in) and `row + 41` (out). These are populated by `msc_configure_endpoints` and `xhci_input_ctx_add_bulk_pair`. **The Phase 2.6 commands can read these directly — no need to recompute from endpoint addresses.**

---

## 5. Bug surface beyond the missing commands

Code-reading `msc.cyr` + `xhci.cyr` post-burn surfaced three issues. Only #1 is load-bearing for Attempt 84; #2 and #3 are latent and worth folding into the Phase 2.6 burn while the surface is open.

### 5.1 (Load-bearing) Stale Transfer Events on the event ring after timeout

`xhci_wait_transfer_event` (`xhci.cyr:762-812`) spins XHCI_CMD_TIMEOUT_SPINS iterations waiting for a Transfer Event whose slot_id matches `slot_id`. On timeout it returns 0 — but **does not flush the event ring**. The next call to `xhci_wait_transfer_event` may consume an event posted *after* the timeout (e.g., the device finally responded 100 ms late, after the host already gave up).

This is what's behind the CSW tag mismatch:
1. INQUIRY data-phase TRB times out (Attempt 84 line 2)
2. `msc_bbb_exec` returns 0 with `transport_failed=1`
3. Some time later the device DMA's the 36-byte INQUIRY response into the data buffer + completes the TRB; xHC posts a Transfer Event onto the event ring
4. INQUIRY-path bails to `INQUIRY failed`
5. Next call: TUR retry 1 enqueues CBW → ring doorbell → `xhci_wait_transfer_event` immediately picks up the stale INQUIRY-completion event (matches slot 2), interprets it as the CBW completion, returns 1
6. TUR CSW receive enqueues bulk-IN → ring doorbell → `xhci_wait_transfer_event` picks up an event for either the original CBW (still queued device-side) or the CSW from the bailed INQUIRY → tag echo doesn't match what TUR's CBW expected → `CSW tag mismatch` print

**Fix:** in `msc_reset_recovery`, before any new transfer, drain the event ring of all stale events for this slot. Walk the event ring while the cycle bit matches `xhci_evt_ring_cycle`, consume every Transfer Event regardless of completion code, advance ERDP. Stop when we see a stale-cycle entry (= ring empty from xHC's perspective). Linux does this implicitly because Stop Endpoint generates a "Stopped" Transfer Event that flushes the EP's in-flight TD.

### 5.2 (Latent) `msc_bulk_enqueue` doesn't write back cycle on wraparound

`msc.cyr:526-532`:
```
if (idx == MSC_TRB_RING_TRBS - 1) {
    if (cycle == 1) { cycle = 0; } else { cycle = 1; }
    idx = 0;
}
```

`idx` is later written back to `row + idx_off`. **`cycle` is not.** On the second pass through the ring, `cycle` is re-loaded from row state and is wrong.

Won't fire in steady-state Phase 2 / 2.5 / 2.6 testing (64-TRB rings, 3 TRBs per CBW round-trip → ~21 round-trips per wrap; Reset Recovery rewinds idx to 0 way before then). But REQUEST SENSE retries on a chatty device could conceivably reach it. One-line fix while the file is open.

### 5.3 (Latent) Link TRB cycle never updates

`msc.cyr:484-487` (`msc_alloc_bulk_ring`) writes the Link TRB with cycle=1 at allocation and never touches it again. Per xHCI 1.2 §4.9.2 the Link TRB's cycle bit needs to flip in sync with the producer cycle each time the producer crosses it (otherwise consumer mis-detects ring state). Same "rings don't wrap in test" reasoning — defensive bug. Fold the fix into `msc_bulk_enqueue`'s wraparound branch: rewrite the Link TRB's cycle to the *outgoing* producer cycle right before flipping it.

---

## 6. Phase 2.6 fix stack — one burn

Per `feedback_redesign_dont_reinvent` + `feedback_no_letter_codes_for_repairs`: name each patch for what it does, stack all into one burn, audit before going to iron.

### 6.1 New TRB type constants (`xhci_regs.cyr`)

```
XHCI_TRB_RESET_ENDPOINT  = 14;
XHCI_TRB_STOP_ENDPOINT   = 15;
XHCI_TRB_SET_TR_DEQUEUE  = 16;
```

### 6.2 New xHCI command helpers (`xhci_cmd.cyr`)

Three thin wrappers around `xhci_cmd_issue`:

- `xhci_cmd_reset_endpoint(slot_id, dci)` — issues TRB type 14, ctrl = `(slot_id << 24) | (dci << 16) | (XHCI_TRB_RESET_ENDPOINT << 10)`. TSP bit cleared (full state clear).
- `xhci_cmd_stop_endpoint(slot_id, dci)` — issues TRB type 15, ctrl = `(slot_id << 24) | (dci << 16) | (XHCI_TRB_STOP_ENDPOINT << 10)`. Tolerates Context State Error completion (already Stopped/Halted) — return 1 for both Success and Context State Error.
- `xhci_cmd_set_tr_dequeue(slot_id, dci, deq_ptr_phys, dcs)` — issues TRB type 16, parameter = `(deq_ptr_phys & ~0xF) | (dcs & 0x1)`, ctrl = `(slot_id << 24) | (dci << 16) | (XHCI_TRB_SET_TR_DEQUEUE << 10)`.

`xhci_cmd_issue(p_lo, p_hi, status, ctrl_partial)` is general enough — caller composes all four dwords. No change to the dispatcher.

### 6.3 Event-ring drain helper (`xhci.cyr`)

`xhci_drain_transfer_events(slot_id)` — walk event ring consuming every Transfer Event for `slot_id` until ring tail. Used in `msc_reset_recovery` before re-arming.

### 6.4 Rewritten `msc_reset_recovery` (`msc.cyr`)

Canonical sequence — controller-side first (commands need to land before device-side recovery to prevent races where a partially-recovered device sends data that lands on a still-Halted EP context):

```
fn msc_reset_recovery(slot_id):
    intf, ep_in, ep_out, dci_in, dci_out, ring_in, ring_out = load row fields

    # 1. Stop Endpoint (in case Running-but-stuck). Tolerates already-Stopped.
    xhci_cmd_stop_endpoint(slot_id, dci_in)
    xhci_cmd_stop_endpoint(slot_id, dci_out)

    # 2. Reset Endpoint — Halted/Stopped → Stopped (clears Halted).
    xhci_cmd_reset_endpoint(slot_id, dci_in)
    xhci_cmd_reset_endpoint(slot_id, dci_out)

    # 3. Drain any stale Transfer Events posted between timeout and now.
    xhci_drain_transfer_events(slot_id)

    # 4. Device-side BBB Reset (existing Phase 2.5 code).
    xhci_control_no_data(slot_id, 0x21, 0xFF, 0, intf)
    xhci_control_no_data(slot_id, 0x02, 0x01, 0, ep_in)
    xhci_control_no_data(slot_id, 0x02, 0x01, 0, ep_out)

    # 5. Host-side ring rewind (existing Phase 2.5 code).
    zero ring_in, rewrite Link TRB, idx=0, cycle=1
    zero ring_out, rewrite Link TRB, idx=0, cycle=1

    # 6. Set TR Dequeue Pointer — tell xHC where the new ring base is.
    xhci_cmd_set_tr_dequeue(slot_id, dci_in,  ring_in,  1)   # DCS=1 matches host cycle
    xhci_cmd_set_tr_dequeue(slot_id, dci_out, ring_out, 1)

    # 7. Clear sticky.
    row[transport_failed] = 0
    print "Reset Recovery OK"
```

### 6.5 Latent fixes folded in while file is open

- `msc_bulk_enqueue` wraparound — store `cycle` back to `row + cycle_off` after toggling.
- `msc_bulk_enqueue` wraparound — rewrite Link TRB's cycle bit to outgoing producer cycle before the cycle flip.

(Both one-line fixes. Could be deferred to a separate cycle, but they're cheap and on-surface.)

### 6.6 QEMU smoke test

Existing QEMU `qemu-xhci` + `usb-storage` smoke needs an artificial Stall-injection path to exercise the recovery sequence. Two options:
- `usbredir`-based fault injection (complex).
- **Preferred**: short-form regression test that simply calls `msc_reset_recovery` from a debug shell command on a known-good QEMU stick and asserts that subsequent `msc_blk_read(0)` still works. Validates the commands don't *break* the working path. Iron is where the recovery-from-broken-state validation lands.

### 6.7 Audit gates before burn

- [ ] All three new TRB types have constant defs and are referenced by their constant, not magic number.
- [ ] `xhci_cmd_stop_endpoint` tolerates `XHCI_CC_CONTEXT_STATE_ERROR` (= 19) as success.
- [ ] `xhci_cmd_set_tr_dequeue` parameter dword has DCS in bit 0 and ring_phys masked to 16-byte alignment (`& ~0xF`).
- [ ] Rewritten `msc_reset_recovery` issues controller-side commands *before* device-side control transfers.
- [ ] Event ring drain handles ring wraparound (cycle bit flip).
- [ ] No new iron-invisible diagnostics (per `feedback_no_serial_on_iron` + `feedback_no_instrumentation_means_no_instrumentation`). Existing `kprintln` lines are FB-rendered; new commands are silent on success and surface ccode on failure same as Address Device.
- [ ] `cyrius fmt --check` clean on all touched files.

### 6.8 Held for Phase 2.7 (only if Phase 2.6 iron evidence shows it's needed)

- Multi-iteration drain pattern (Linux's "read another 13 bytes for stale CSW" — call this only after Phase 2.6 if CSW tag mismatch still surfaces).
- Per-vendor quirk table (Linux's `unusual_devs.h`) — only when a second commodity stick exhibits a *new* failure mode.

---

## 7. Linux quirk table — what we'd inherit

`drivers/usb/storage/unusual_devs.h` has ~200 entries for commodity USB sticks. Silicon Motion (`0x090C`) appears for several PIDs with `US_FL_NO_WP_DETECT`, `US_FL_NEEDS_CAP16`, but **no flags relevant to Phase 2.6's bring-up surface**. The Attempt 84 stick's PID `0x1000` does not have a quirks entry — meaning Linux handles it with the default `usb-storage` flow, which is exactly what Phase 2.6 implements. No quirk-table investment is justified yet; revisit if/when a second stick surfaces a Phase 2.6-resistant failure mode.

---

## 8. Sources

- xHCI Specification, rev 1.2 (May 2019): §4.6.8 Reset Endpoint, §4.6.9 Stop Endpoint, §4.6.10 Set TR Dequeue Pointer, §4.8.3 EP State Machine, §4.10.2.1 Halted Endpoint Recovery, §4.9.2 Transfer Ring Management, §6.4.3.7-9 Command TRB formats.
- USB Mass Storage Bulk-Only Transport, rev 1.0 (1999): §6.7.3 Reset Recovery.
- Linux 6.x `drivers/usb/storage/transport.c` — `usb_stor_invoke_transport`, `usb_stor_Bulk_transport`, `usb_stor_Bulk_reset`, `usb_stor_clear_halt`.
- Linux 6.x `drivers/usb/host/xhci.c` — `xhci_endpoint_reset`.
- Linux 6.x `drivers/usb/host/xhci-ring.c` — `xhci_queue_reset_ep`, `xhci_queue_new_dequeue_state`, `xhci_handle_cmd_reset_ep`, `xhci_handle_cmd_set_deq`, `xhci_handle_halted_endpoint`.
- Linux 6.x `drivers/usb/core/message.c` — `usb_clear_halt`, `usb_reset_endpoint`.
- agnos `kernel/arch/x86_64/usb/msc.cyr` — `msc_reset_recovery` (Phase 2.5), `msc_bbb_exec`, `msc_bulk_enqueue`.
- agnos `kernel/arch/x86_64/usb/xhci.cyr` — `xhci_wait_transfer_event` (event-ring drain surface).
- agnos `kernel/arch/x86_64/usb/xhci_cmd.cyr` — `xhci_cmd_issue` (general command dispatcher; no change needed for Phase 2.6).
- agnos `kernel/arch/x86_64/usb/xhci_regs.cyr` — XHCI_TRB_* constants (three to add).
- Iron evidence: [`iron-nuc-zen-log.md` § Attempt 84](iron-nuc-zen-log.md), `1312_USB_MASS_Log.jpg`.
- Phase 2.5 reference: [`usb-ms-iron-burn-audit.md`](usb-ms-iron-burn-audit.md) §3 (hypothesis ladder), §5 (success rubric).
