# xHCI Prior-Art Audit — `events_seen=0` Escape Plan

**Status:** 2026-05-18 — written after the F→GG→edit-b→stack-bundled ladder hit thirteen+ letters on the same root symptom (`events_seen=0` after Enable Slot doorbell on AMD FCH 1022:1639). This doc replaces "stack the next letter" with "diff against four independent impls; bundle only what ≥2 of them agree on."

**Sources fetched 2026-05-18:**

| Impl | File | Function(s) |
|---|---|---|
| Linux v6.13 | `drivers/usb/host/xhci-mem.c` | `xhci_add_interrupter`, `xhci_set_hc_event_deq` |
| FreeBSD HEAD | `sys/dev/usb/controller/xhci.c` | `xhci_start_controller` |
| Haiku master | `src/add-ons/kernel/busses/usb/xhci.cpp` | `XHCI::Start` |
| EDK2 master | `MdeModulePkg/Bus/Pci/XhciDxe/XhciSched.c` | `CreateEventRing`, `XhcInitSched` |

The four-source net (vs. Linux-only) is the lesson from `feedback_redesign_dont_reinvent.md` + the user's correction 2026-05-18 ("Linux could be doing it half-ass"). Convergent ops across multiple impls = high confidence. Linux-only = could be Linux-architectural quirk.

---

## 1. The diff table — register-write order between reset-complete and R/S=1

| Op | Linux | FreeBSD | Haiku | EDK2 | **AGNOS** |
|---|---|---|---|---|---|
| CONFIG.MaxSlotsEn | (in mem_init) | line 1459 | line 1619 | ~1130 | `xhci.cyr:574` |
| DCBAAP | (mem_init) | 1480-1481 (×2!) | 1721-1722 | ~1165-1167 | `xhci.cyr:577` |
| ERSTSZ | (add_interrupter 2863) | 1487-1489 | 1741 | 2644 | `xhci.cyr:587` |
| ERDP (initial) | **after ERSTBA** (2871) | **before ERSTBA** (1505-6) | **before ERSTBA** (1744-5) | **before ERSTBA** (2651-9) | **after ERSTBA** (`xhci.cyr:589`) |
| ERSTBA | (add_interrupter 2867-72) | 1507-9 | 1748-9 | 2661-9 | `xhci.cyr:588` |
| IMOD | (run_finished) | 1491 | 1768-70 | (separate) | `xhci.cyr:607` |
| IMAN.IE | run_finished 1145 | 1512-5 | 1773 | 1184-6 | `xhci.cyr:602` |
| CRCR | (mem_init) | **after ERST** (1517-23) | **after ERST** (1756-7) | (separate) | **before ERST** (`xhci.cyr:582`) |
| Mem-flush before ERSTBA | no | **yes** (1506, PR 237666) | no | no | no |
| USBCMD R/S\|INTE\|HSEE | 1112 | 1525 | 1775 | (other) | `xhci.cyr:615` |

---

## 2. Convergent divergences (≥2-of-4 prior art agree, AGNOS does it differently)

### Divergence A — ERDP-before-ERSTBA

**Vote:** 3 of 4 (FreeBSD + Haiku + EDK2). Linux is the outlier.

**xHCI 1.2 §5.5.2.3.3 wording (paraphrased from impl comments):** ERDP should be valid before ERSTBA, because once ERSTBA is written the controller may begin posting events. An invalid ERDP at ERSTBA-write time is undefined behavior.

**Why it might still matter even with R/S=0:** AGNOS programs all interrupter registers while halted, but some controllers may latch ERSTBA → internal-state into a "ring is now armed" mode where ERDP=0 (HCRST default) is interpreted as "ring is empty AND dequeue is at address 0." When R/S goes 1, if the internal latched state still has ERDP=0, the controller's posting machinery may stall on the "ERDP outside ring" condition.

**Why it might NOT matter:** Linux works on AMD on millions of machines with the reverse order, and the controller is halted throughout. AGNOS-side argument: AMD FCH 1022:1639 may be stricter than Linux's test surface.

**Risk to flip:** Zero — moving a `xhci_rt_write64` call up one line. No behavioral change on Linux-compliant silicon; matches spec wording.

**Confidence this fixes `events_seen=0`:** Medium-low. The first event (Port Status Change) drained successfully, so the event ring is functionally posting *something*. CCEs not posting while PSC events do post is a different shape than "interrupter never armed."

### Divergence B — CRCR-after-interrupter-setup

**Vote:** 2 of 4 (FreeBSD + Haiku). Linux + EDK2 unclear from the fetches.

**Why it might matter:** Some controllers internally couple "command ring active" to "event ring armed" — if CRCR is written before ERSTBA, the cmd-ring state machine may initialize with no event-ring target and refuse to post CCEs even after ERSTBA lands later.

**Why it might NOT matter:** Spec §5.4.5 only constrains CRCR-write relative to R/S=0/1. AGNOS writes CRCR while halted, then ERST, then R/S=1. Controller has all state at R/S transition.

**Risk to flip:** Zero — moving a `xhci_op_write64` call past three sibling writes. No behavioral change on Linux-compliant silicon.

**Confidence this fixes events_seen=0:** Low-medium. Same logic as A — the controller is halted, so order pre-R/S shouldn't matter unless this specific silicon is strict.

### Divergence C — Explicit mem-flush before ERSTBA

**Vote:** 1 of 4 (FreeBSD only, PR 237666). Probably not load-bearing on x86.

FreeBSD's `usb_bus_mem_flush_all` exists because FreeBSD runs on weakly-ordered archs (ARM/MIPS). x86 TSO + AMD coherent DMA snoop should make this a no-op on AMD.

**Risk to add:** Zero — but it's redundant on x86. Skip unless A+B don't unblock.

---

## 3. Confidence assessment — does flipping A+B fix `events_seen=0`?

**Honest read:** Lower than I want it to be. The symptom shape — first PSC event posts, subsequent CCE doesn't — is not what "interrupter never armed" looks like. "Never armed" would mean drained=0 too.

**The drained-1 + CCE-0 split suggests:** the event ring posting machinery works for *some* event types but not all. Candidate causes that A/B don't address:

- **Command ring fetch broken**: controller doesn't DMA-read the cmd ring TRB (CRCR pointer programmed wrong? Cache coherence on cmd ring? — but x86 snoop should handle it)
- **Internal slot/scratchpad gating**: Enable Slot specifically requires scratchpad-backed state on this silicon, and our scratchpad install has a subtle bug (Repair AA — DCBAA[0] = sp_array_phys is checked at `xhci_ring.cyr:144`)
- **CCE-specific posting path different from PSC posting path**: some controllers route different TRB types through different internal queues, and our IMAN/IMOD may gate the CCE path specifically

**Honest recommendation:** A+B are zero-risk hygiene. Worth bundling. But I'd be *guessing* if I claimed they're the fix.

---

## 4. The escape plan — what I recommend bundling, ranked

### Tier 1 — zero-risk hygiene (do regardless)

1. **Swap ERDP / ERSTBA order** (Divergence A): move `xhci.cyr:589` above `xhci.cyr:588`. Spec-strict + 3-of-4 prior art.
2. **Move CRCR write to after IMAN/IMOD** (Divergence B): `xhci.cyr:582` → after line 607. 2-of-4 prior art.

Both are LOC-trivial edits. No new state, no new instrumentation, no new CMOS slots.

### Tier 2 — investigate before bundling

3. **Verify DCBAA[0] scratchpad install actually landed in DMA-visible RAM**: re-read `xhci_ring.cyr:144` (`store64(dcbaa, sp_array)`). On AMD with WB-cached identity map, the store should be snoop-visible to the controller, but worth a `load64(dcbaa)` readback in `xhci_rings_init` to confirm the store didn't get DCE'd or coalesced. Read-only audit, no burn needed.

4. **Verify cmd ring TRB DMA visibility**: same shape as #3 — after `xhci_cmd_submit`'s `store32(trb + 12, ...)`, can we add a `load32(trb + 12)` readback to confirm the store is in cache? No iron burn — this is a code-read question (compile a build, `strings` the binary to confirm the load survived; OR `cyrius compile` and `objdump` the function).

### Tier 3 — DO NOT bundle yet

5. Anything that adds new CMOS stamps, new diagnostic prints, new repair letters. The ladder is the bug; don't extend it.

---

## 5. Why this doc exists

The CMOS cheat-sheet at the top of `read-boot-log.sh` describes **symptoms** (what each slot's value means). It's a great symptom dictionary. It is **not** a baseline-diff doc.

What was missing all along: "here's what Linux/FreeBSD/Haiku/EDK2 do, here's what AGNOS does, here are the divergences." Every reboot reset the agent to "look at symptoms, propose a letter" because the only persistent artifact was symptom-shaped.

This file is the missing baseline-diff. **Next session:** read this BEFORE the read-boot-log output. Then symptoms are checked against the diff, not derived from first principles.

---

## 6. Open questions / what I didn't audit

- **Linux's xhci-mem.c `xhci_add_interrupter` write order** — confirmed Linux is the outlier on ERDP/ERSTBA but didn't trace the full surrounding sequence. Worth a follow-up read.
- **EDK2's full XhcRunHC** — fetch only got `CreateEventRing` and a partial `XhcInitSched`. The R/S=1 site itself wasn't located in the fetched window.
- **MSI-X function-mask interaction with internal state machine** — Repair MM disabled function-mask in Attempt 60. The CMOS confirms `0x80=02` (MaxScratchpadBufs) is sane. Whether the controller silicon truly honors function-mask=0 as "post events normally" needs a vendor-doc check or a USB analyzer — out of scope for a four-source code audit.
- **The "drained 1 event" — what type was it?** If it was a Port Status Change Event (HW-generated on connection), that confirms the event ring posting works for HW-initiated events. If it was a stale event from prior boot, that's a different question. Worth checking `evt_type` from the existing instrumentation (already prints `type=` per event).

---

**Owner:** Claude
**Next decision point:** User reviews. If A+B greenlit, single behavioral bundle, one burn, no instrumentation, no new CMOS slots. If not greenlit, audit goes deeper (Linux xhci_add_interrupter full trace; EDK2 XhcRunHC trace).
