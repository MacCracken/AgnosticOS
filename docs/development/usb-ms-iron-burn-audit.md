# USB Mass Storage — Pre-Iron-Burn Audit

> **Status**: Open | **Drafted**: 2026-05-20 PM | **Target burn**: TBD (user decides)
>
> Per `feedback_iron_burns_block_other_work` — every iron-burn proposal carries a written
> line-by-line audit FIRST. This is the gate for the first USB Mass Storage burn on
> archaemenid. Format mirrors [`ahci-iron-burn-audit.md`](ahci-iron-burn-audit.md) since
> that one called Attempt 81's partial-success path correctly.

---

## §1 Scope of the proposed burn

**One burn covers the full Phase 1-4 stack** — discovery + BBB transport + INQUIRY/READ
CAPACITY + READ(10)/WRITE(10). The driver compiled cleanly against cycc 6.0.1 and ran
first-try across all four phases in QEMU smoke (vendor/product decoded, capacity
reported, LBA-0 readback returned blank stick, LBA-100 write round-trip PASS under
`MSC_RW_DEMO=1`). No incremental partial-burn between phases is justified — the cost is
the same one re-cabling + boot cycle either way.

**Build under test:**

| Component | Version | Size | Notes |
|---|---|---|---|
| `agnos` | 1.31.2 `[Unreleased]` HEAD | 492,992 B (default) / 493,688 B (`MSC_RW_DEMO=1`) | Phase 1-4 + AHCI carry-forward + cycc 6.0.1 pin graduation |
| `gnoboot` | 0.4.2 (unchanged from Attempts 80/81/82) | — | Sovereign UEFI handoff, no bootloader-side change |
| `cyrius` | 6.0.1 toolchain | — | Same toolchain as Attempt 82's AHCI-carry-forward iron validation |

**Iron-target topology on archaemenid:**
- M.2 NVMe Crucial P3 2 TB (Attempt 80 baseline — `nvme0` primary block_dev)
- 2.5" SATA WD Blue SA510 2 TB (Attempt 81 baseline — secondary block_dev post-Attempt-82)
- USB MS device: TBD (user-selected scratch USB stick or HDD)

Expected USB MS behavior on the default build:
- xhci enumerates the USB device, addresses it via Phase 3 enumerate_port
- MSC class triple (0x08/0x06/0x50) matches on a USB Mass Storage interface
- Configure Endpoint succeeds for the bulk-IN + bulk-OUT pair
- TEST UNIT READY → Pass (or transient NOT_READY on freshly-inserted media — see §5)
- INQUIRY decodes the real vendor/product/revision/PDT
- READ CAPACITY(10) decodes real last_lba + lba_bytes (likely 512; 4Kn devices will report 4096)
- MSC registers as **tertiary** (NVMe + AHCI hold primary/secondary)
- `msc_read_demo` reads LBA 0 of the user's USB device and prints first 8 bytes

---

## §2 What this burn ADDS to the iron coverage matrix

After this burn lands, archaemenid will have **three** iron-validated block backends
through a single AGNOS kernel boot:

| Backend | Iron device | Attempt | Status |
|---|---|---|---|
| NVMe | Crucial P3 2 TB (M.2) | 80 | ✅ Validated 1.31.0 |
| AHCI/SATA | WD Blue SA510 2 TB | 81 → 82 | ✅ Validated 1.31.2 (post-carry-forward) |
| **USB MS (BBB+SCSI)** | TBD USB stick / HDD | **target burn** | ⏳ Pending |

This is the third class of block device. Phase 5 (optical via SCSI MMC profile —
non-512-B sectors) builds on the same MSC stack and remains in 1.31.2 cycle scope; iron
validation of the optical path on archaemenid's HP external USB Blu-ray is a separate
audit (different sector size + MMC opcode set + first non-512-B-LBA exercise of the
GPT/fatfs consumers).

---

## §3 Hypothesis ranking — what could go wrong on iron vs. QEMU

Per `feedback_redesign_dont_reinvent`, all four phases were ported from Linux
`drivers/usb/storage/usb.c` + `transport.c` + USB MSC BBB rev 1.0 spec. Iron-vs-QEMU
divergences ranked by likelihood:

1. **GET_MAX_LUN STALL.** Many real-vendor USB sticks STALL the class-specific
   `GET_MAX_LUN` request (`bmRequestType=0xA1, bRequest=0xFE`) rather than return
   MaxLUN=0. Linux's storage class treats STALL as "single-LUN, MaxLUN=0" and proceeds.
   **AGNOS already handles this** — `msc_get_max_lun` returns 0 on `xhci_control_in`
   failure (whatever the cause), and Phase 4 only uses LUN 0. Hypothesis: **no behavioral
   difference**.

2. **TEST UNIT READY = NOT_READY on cold insertion.** Real removable media often returns
   `CSW.bCSWStatus = 1` (Command Failed) with sense data `0x02 / 0x04 / 0x01` ("Logical
   unit not ready, becoming ready"). QEMU's emulated `usb-storage` never reports this.
   **Current Phase 2 behavior**: prints "TEST UNIT READY -> not ready / failed (CSW
   status != 0)" and **continues to attempt Phase 3 INQUIRY anyway** — INQUIRY does not
   require ready state per SPC-4. So a NOT_READY response is not blocking; the user will
   see a "not ready" line but Phase 3 + 4 will still try. Phase 5+ will add REQUEST
   SENSE to decode + retry.

3. **Vendor-specific INQUIRY response shape.** Some sticks return < 36 bytes of INQUIRY
   data; the `AdditionalLength` field at INQUIRY byte 4 says how much they actually
   provided. AGNOS's Phase 3 reads exactly 36 bytes and trusts the response shape —
   bytes past `AdditionalLength` may be undefined. Decoded fields (vendor/product/
   revision/PDT) live at offsets 0-35 per SPC-4, so they're always populated on any
   compliant device. **Hypothesis: no behavioral difference for the common decoded
   fields; cosmetic risk only if a device returns < 36 bytes total.**

4. **2 TiB+ device → READ CAPACITY(10) saturates.** Real 4 TB / 8 TB USB HDDs will
   return `last_lba = 0xFFFFFFFF` from READ CAPACITY(10), indicating "use READ
   CAPACITY(16)." Phase 4 doesn't yet implement READ CAPACITY(16) (SBC-3 §5.11 service
   action 0x10) — the device will report capacity = 4 GiB (the u32 max × 512 B), which
   is wrong. **Mitigation for first burn**: use a USB stick / HDD ≤ 2 TiB. Phase 5+ will
   add the 16-byte fallback.

5. **Non-512-B sector device.** SCSI MMC optical drives report block_size = 2048. The
   `msc_read_demo` skips non-512-B sectors silently (early return); `msc_register_block_dev`
   passes the real lba_bytes through to `blk_register_usb_ms` which sets
   `blk_lba_bytes = 2048` correctly. **GPT/fatfs consumers downstream do not yet honor
   `blk_lba_bytes`** — they hardcode `* 512`. Iron burn against an optical drive WILL
   misinterpret the partition table because of this. **Mitigation for first burn**: use
   a 512-B sector device (any standard USB stick / SSD / HDD). Optical iron burn is a
   separate Phase 5 audit.

6. **SuperSpeed bulk MPS / Max Burst.** QEMU's `usb-storage` on `qemu-xhci` advertises
   SS (5 Gbps) with bulk MPS = 1024. Real USB 3 sticks should match; USB 2 sticks will
   report bulk MPS = 512 (HS) or 64 (FS — rare for storage). AGNOS's `add_bulk_pair`
   sets Max Burst = 0 (single-burst) on both EPs — works on every speed grade but
   doesn't optimize SS throughput. **Hypothesis: no failure; perf-only.**

7. **PortSC reset timing on real silicon.** xHCI port reset on physical USB devices
   takes longer than QEMU's emulated reset. The existing `xhci_port_reset` handles this;
   no MSC-specific change. **Carry-over risk from xHCI bring-up, not new.**

**Bottom line**: no high-likelihood hypothesis predicts a Phase 1-4 functional failure
on iron when the target is a 512-B-sector USB stick ≤ 2 TiB. The pattern that delivered
NVMe + AHCI first-iron-try success (Attempts 80 + 81-82) applies.

---

## §4 What to NOT do on this burn

- **No `MSC_RW_DEMO=1` on a user-owned USB device on the first burn.** LBA 100 may sit
  inside a filesystem; sentinel writes there are recoverable (overwrites 8 bytes of a
  random LBA 100) but not the right default posture. Use a **scratch USB stick** if
  `MSC_RW_DEMO=1` is wanted — preferably one that was just `dd if=/dev/zero` over the
  first MiB.
- **No 2 TiB+ device** on the first burn (READ CAPACITY(10) saturation — §3 hyp 4).
- **No optical device** on the first burn (non-512-B-sector + GPT/fatfs hardcoding —
  §3 hyp 5). Optical iron burn is a separate Phase 5 audit.
- **No multi-device USB topology** (hub + multiple sticks) on the first burn. The
  current code supports multiple slots but has only been QEMU-validated against a
  single device. Multi-slot iron validation is a Phase 5 nice-to-have.

---

## §5 Success rubric

**Full success** (no carry-forward):
- xhci enumerates the USB device, addresses it (port-N connected + slot-M assigned).
- MSC class triple matches (interface 0x08/0x06/0x50).
- Phase 2 Configure Endpoint succeeds; CMOS kcp `0x53` set.
- TEST UNIT READY returns Pass OR NOT_READY (NOT_READY is acceptable — see §3 hyp 2).
- INQUIRY decodes plausible vendor/product/revision/PDT (CMOS kcp `0x55`).
- READ CAPACITY(10) decodes plausible last_lba + lba_bytes (CMOS kcp `0x56`).
- `msc: registered as tertiary block_dev (slot N, ...; NVMe primary)` (CMOS kcp `0x57`
  NOT set because we deferred to NVMe — that's correct).
- `msc: slot N LBA0 first 8 bytes: ...` prints something — zeros for a blank stick,
  actual content for a used stick.
- Boot continues through GPT + VFS + scheduler + kybernet + AGNOS shell as normal.

**Partial success — vendor-specific quirk** (acceptable; surfaces a carry-forward but
not a regression):
- TEST UNIT READY returns "not ready" but INQUIRY + READ CAPACITY still complete.
- INQUIRY data is < 36 bytes (cosmetic; printed fields still populated).
- GET_MAX_LUN STALLs (handled gracefully; MaxLUN=0 used).

**Failure rubric** (rolls back to carry-forward):
- xhci hangs during USB device enumeration (Phase 3 of xhci, not Phase 1 of MSC).
- Configure Endpoint command times out (Phase 2 Setup TRB ccode != Success).
- CBW transfer hangs (PxCI-equivalent stuck on bulk-OUT endpoint).
- CSW signature mismatch or persistent CSW Phase Error.
- Kernel hard-faults / triple-faults during MSC Phase 1-4 init.

---

## §6 Mitigations applied this burn

- **`MSC_RW_DEMO` compile gate**: WRITE(10) demo defaults OFF. Iron builds against
  user-owned drives don't ship sentinel writes. Same posture as `AHCI_RW_DEMO` after
  Attempt-81 audit.
- **Tertiary registration**: USB MS does NOT override NVMe or AHCI. The boot disk
  topology that worked for Attempts 80 + 81 + 82 is unchanged — GPT continues to parse
  NVMe, VFS / kybernet / shell wiring identical.
- **`msc_read_demo` skip on non-512-B**: avoids first-non-512 hazard. Optical iron is a
  separate audit.
- **No Phase 5 (optical) folded in**: clean Phase 1-4 only.

---

## §7 CMOS post-mortem checkpoints reserved for this burn

| Slot | Meaning |
|---|---|
| `0x52` | MSC Phase 1 — class triple match + bulk EP enumeration |
| `0x53` | MSC Phase 2 — Configure Endpoint succeeded |
| `0x54` | MSC Phase 2 — TEST UNIT READY → Pass |
| `0x55` | MSC Phase 3 — INQUIRY decoded |
| `0x56` | MSC Phase 3 — READ CAPACITY decoded |
| `0x57` | MSC Phase 4 — registered as `blk_active=BLK_USB_MS` (only when no NVMe/AHCI) |

Reading these via `scripts/build/read-boot-log` post-burn tells the user precisely how
far the MSC stack got even if the framebuffer console line wasn't captured visually.

---

## §8 Linux/EDK2 prior art consulted

Per `feedback_redesign_dont_reinvent` and `reference_xhci_prior_art`:

- **Linux `drivers/usb/storage/usb.c`** — `storage_probe` (class triple match shape),
  `usb_stor_acquire_resources` (bulk endpoint setup).
- **Linux `drivers/usb/storage/transport.c`** — `usb_stor_Bulk_transport` (CBW → data
  → CSW state machine), `usb_stor_clear_halt` (STALL recovery — deferred to Phase 5+).
- **Linux `drivers/scsi/sd.c`** — `sd_read_capacity_10` / `sd_read_capacity_16`
  (RC10/RC16 split — Phase 4 only ships RC10, RC16 deferred).
- **USB MSC BBB rev 1.0** (USB-IF, 1999) — §3.1 (CBI vs BBB classification), §3.2
  (GET_MAX_LUN), §5.1 (CBW layout), §5.2 (CSW layout), §6 (Bulk-Only Transport state
  machine).
- **SPC-4** (T10) — §6.6 (INQUIRY), §6.34 (TEST UNIT READY).
- **SBC-3** (T10) — §5.7 (READ(10)), §5.10 (READ CAPACITY(10)), §5.27 (WRITE(10)).

No first-principles diagnostic letters. Single-burn fix if any of §3's hypotheses
materialize.

---

## §9 Audit disposition

This audit recommends **proceeding with the burn** when the user is ready. No high-
likelihood hypothesis predicts failure; QEMU validation cleared all four phases first-
try; mitigations applied for the medium-likelihood risks (write demo gated, optical
deferred, > 2 TiB deferred); CMOS checkpoints provide post-mortem visibility independent
of the framebuffer console.

**Target USB device for first burn**: any 512-B-sector USB stick or external SSD/HDD
≤ 2 TiB. Scratch device preferred if `MSC_RW_DEMO=1` is wanted; otherwise any device is
safe (read-only by default).
