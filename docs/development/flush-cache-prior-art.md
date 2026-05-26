---
name: fsync / FLUSH-CACHE durability barrier — multi-source prior art
description: Convergent device cache-flush command shapes (NVMe / ATA / SCSI / VirtIO) + their map onto AGNOS's existing per-driver command paths, for the agnos 1.33.5 fsync barrier
type: prior-art
---

# `fsync` / FLUSH-CACHE durability barrier — prior art

> **Cycle**: agnos **1.33.5** — the last 1.33.x WRITE-arc follow-on. Tracker: [`iron-nuc-zen-log.md#tracker-1335-cycle`](iron-nuc-zen-log.md#tracker-1335-cycle). This is **bite 1** (the audit). Multi-source per [[feedback_redesign_dont_reinvent]] — Linux is one source of many; derive the command shape from the specs first, then diff against AGNOS.

## 0. Scope honesty — this is a HARDENING item, not a bug fix

State it up front so we don't over-invest. The 1.33.1 **W5 iron burn persisted `persist.txt` across a real power-cycle** on archaemenid's Crucial P3 NVMe with **no explicit flush** ([`ext2-ext4-write-prior-art.md`](ext2-ext4-write-prior-art.md) § 3, § 14 item 3). So there is **no reproducible data-loss symptom to chase**. AGNOS issues every write synchronously through `blk_write`, which *completes the controller command* before returning — kernel step-ordering already equals on-disk ordering, and there is no AGNOS writeback cache to reorder behind us (§ 2.3 of that doc).

What this cycle closes is the **contract**: `sync` should *mean* durable on **any** drive, including one with an aggressive volatile write cache that ACKs a command before the data reaches NAND/platter. A power-cycle in that window can lose acknowledged data on such a drive even though AGNOS did everything right. FLUSH-CACHE is the barrier that forces the drive to commit. The W5 burn proves our burn-drives honor write-completion; it does *not* prove every drive does, and "make it right" (per the user, same spirit as the 1.33.4 HID Link-TRB fix) means closing the gap rather than relying on that.

**The falsification corollary** (in the tracker, repeated here): if a backend's flush turns out to be a genuine no-op under our synchronous-completion model — e.g. VirtIO without `VIRTIO_BLK_F_FLUSH`, or RAM-disk — **document it and return success; do not manufacture a writeback-cache layer AGNOS doesn't have** ([[feedback_no_instrumentation_means_no_instrumentation]] in spirit: don't build machinery to justify the cycle).

## 1. The convergent operation

Every block transport exposes one primitive: *"commit everything you've cached for this device to non-volatile media, and don't return until it's done."* It is **non-data** (no payload transferred), **device-wide** (not per-LBA in the form we need), and **blocking** (the caller waits for completion = the durability point). The only per-transport differences are the opcode and how a non-data command rides that transport's command path.

| Transport | Command | Opcode / type | Spec |
|---|---|---|---|
| NVMe | FLUSH | NVM cmd **0x00** | NVM Express Base, NVM Command Set — Flush |
| ATA (via AHCI) | FLUSH CACHE EXT | **0xEA** (48-bit; `0xE7` is the 28-bit FLUSH CACHE) | ATA8-ACS §7.10 / ACS-2+ |
| SCSI (via USB-MS BBB) | SYNCHRONIZE CACHE(10) | **0x35** (`0x91` = the 16-bit variant) | SBC-3 §5.20 |
| VirtIO-blk | FLUSH | `VIRTIO_BLK_T_FLUSH` = **4** (gated on `VIRTIO_BLK_F_FLUSH`, feature bit 9) | VirtIO 1.x §5.2 |
| RAM-disk | — | n/a (volatile by definition) | — |

**Cross-reference — the host-OS shape we mirror** (so the *call-site* contract is right, not just the opcode):
- **Linux** `blkdev_issue_flush()` → `submit_bio_wait(REQ_OP_FLUSH)`; the per-driver handlers are `nvme_setup_flush()` (sets `cmnd->common.opcode = nvme_cmd_flush`, NSID, nothing else), libata `ATA_CMD_FLUSH_EXT` issued as a non-data taskfile, and `sd_sync_cache()` → SYNCHRONIZE CACHE(10/16).
- **FreeBSD** `BIO_FLUSH` → CAM `XPT_SCSI_IO` with `SYNCHRONIZE CACHE`, `nvme` `NVME_OPC_FLUSH`, `ahci`/`ada` `ATA_FLUSHCACHE48`.
- Convergent invariants from both: **(a)** a flush is issued *after* the writes it is meant to make durable have themselves completed (which, for AGNOS, they always have — synchronous `blk_write`); **(b)** the caller blocks on flush completion; **(c)** flush can legitimately take **much longer than a normal I/O** — the drive may be committing its entire cache (ATA spec permits up to ~30 s; Linux uses a long/no timeout on flush). This last point is the one real implementation gotcha → see § 7.

## 2. Per-backend command shape + AGNOS mapping

Each subsection: the spec shape, then the diff against the **existing** AGNOS command path (so each flush helper is "mirror the read/write path, swap the opcode/drop the data").

### 2.1 NVMe FLUSH — trivial, the path already generalizes

**Spec.** Submission Queue Entry: CDW0 opcode = `0x00`, NSID = the namespace (1 for us). No PRP, no data, CDW10–15 = 0. Completion is an ordinary CQE; status 0 = success.

**AGNOS.** `nvme_io_submit(opcode, nsid, prp1, prp2, cdw10, cdw11, cdw12)` + `nvme_io_poll(cid)` (`core/nvme.cyr:672,696`) is *already* the generic non-data-capable path — `nvme_rw_internal` is just a PRP-builder wrapper around it. FLUSH is the degenerate case:

```cyrius
fn nvme_blk_flush() {
    if (nvme_io_ready == 0) { return 0 - 1; }
    var cid = nvme_io_submit(0x00, 1, 0, 0, 0, 0, 0);   # FLUSH, NSID 1, no PRP, no CDWs
    var st  = nvme_io_poll(cid);
    if (st != 0) { return 0 - 1; }
    return 0;
}
```
Caveat: `nvme_io_poll` has a 10M-iter ceiling tuned for transfers; a cache flush can exceed it on a busy drive (§ 7). The primary archaemenid backend is NVMe, so this is the one that matters most on iron.

### 2.2 ATA FLUSH CACHE EXT (0xEA) via AHCI — needs a non-data sibling

**Spec.** A non-data ATA command. H2D Register FIS with command = `0xEA`; LBA/count/features are N/A (FLUSH CACHE EXT flushes the whole device cache). Completion = `PxCI` bit clears with no `PxTFD.STS.ERR`.

**AGNOS.** `ahci_issue_rw` (`core/ahci.cyr:922`) is **data-only** — it requires `count > 0`, builds one PRDT entry, and sets `PRDTL=1`. FLUSH has no data, so we can't reuse it as-is. Add a sibling that reuses `ahci_build_rw_fis`'s FIS scaffolding (or a trimmed inline FIS) with **`PRDTL = 0`** in the command header:

```cyrius
fn ahci_issue_nodata(port, opcode) {        # mirrors ahci_issue_rw, no PRDT
    # ... same present/inited/wait-idle guards ...
    # build H2D FIS: byte0=0x27, byte1=0x80, byte2=opcode, byte7=0x40 (LBA bit); rest 0
    # command header word0 = CFL(5) | PRDTL(0<<16); W=0 (non-data)
    # clear PxIS/PxSERR, set PxCI=1, poll CI→0 with PxTFD.ERR escape
}
fn ahci_blk_flush() {
    if (ahci_present == 0) { return 0 - 1; }
    if (ahci_issue_nodata(ahci_block_port, 0xEA) == 1) { return 0; }
    return 0 - 1;
}
```
The existing `ahci_port_wait_idle` quiescence gate (1.31.2 carry-forward) and `PxTFD.STS.ERR` escape apply unchanged. Secondary backend on archaemenid (WD Blue SA510 SATA).

### 2.3 SCSI SYNCHRONIZE CACHE(10) (0x35) over USB-MS BBB — no-data CBW

**Spec.** 10-byte CDB, **no data phase** (`dCBWDataTransferLength = 0`). To flush the whole device: LBA = 0, Number-of-blocks = 0 (0 ⇒ "from the specified LBA to the last LBA"). IMMED bit (byte 1, bit 1) = **0** so the device completes the flush before returning a good CSW.

```
CDB[0]   = 0x35      opcode
CDB[1]   = 0x00      flags (IMMED=0 — wait for completion)
CDB[2..5]= 0         LBA (big-endian u32) — flush from LBA 0
CDB[6]   = 0x00      group number
CDB[7..8]= 0         number of blocks (0 = all)
CDB[9]   = 0x00      control
```

**AGNOS.** `msc_scsi_exec(slot_id, lun, cdb_phys, cdb_len, data_phys, data_len, dir_in, max_retries)` (`msc.cyr:757`) already handles `data_len == 0` (TEST UNIT READY uses it). So `msc_blk_flush` mirrors `msc_blk_write` but with a no-data CDB:

```cyrius
fn msc_blk_flush() {
    if (msc_first_slot == 0) { return 0 - 1; }
    var cdb_buf[2];                          # 16 bytes (function-local: N bytes)
    var cdb_p = &cdb_buf;
    var k = 0; while (k < 16) { store8(cdb_p + k, 0); k = k + 1; }
    store8(cdb_p + 0, 0x35);                 # SYNCHRONIZE CACHE(10), all-zero operands = flush all
    if (msc_scsi_exec(msc_first_slot, 0, cdb_p, 10, 0, 0, 0, 1) == 0) { return 0 - 1; }
    return 0;
}
```
A device that lacks a writeback cache may return `CHECK CONDITION` with `INVALID COMMAND OPCODE` — treat that as benign (nothing to flush) rather than a hard error; the `msc_scsi_exec` retry/recover wrapper already surfaces sense. Tertiary backend; not on the archaemenid FS partition, so QEMU `usb-storage` is the validation surface.

### 2.4 VirtIO-blk FLUSH (type 4) — feature-gated, no-data 2-desc chain

**Spec.** `VIRTIO_BLK_T_FLUSH` = 4 in the request header; `sector` field reserved (0); **no data buffer** — the descriptor chain is just header (device-readable) + status (device-writable), a **2-descriptor** chain, not the 3-descriptor read/write chain. Only valid if `VIRTIO_BLK_F_FLUSH` (bit 9) was negotiated; if not negotiated the device is write-through and flush is a no-op by definition.

**AGNOS.** Two changes in `core/virtio_blk.cyr`:
1. **Negotiate the feature.** `vblk_negotiate_features` (`:232`) today accepts `VIRTIO_F_VERSION_1` + opportunistic `VIRTIO_BLK_F_RO`. Add opportunistic `VIRTIO_BLK_F_FLUSH` (bit 9) and latch `vblk_flush_supported`.
2. **Issue a no-data request.** `vblk_do_request` (`:395`) hardcodes the 3-descriptor chain (header + 512 B data + status). Add a `vblk_do_flush` (or a `has_data` param) that builds the **2-descriptor** chain: desc0 = header (`F_NEXT`→1), desc1 = status (`F_WRITE`, terminal). type=4, sector=0. Same avail-ring/wmb/doorbell/used-poll machinery.

```cyrius
fn vblk_blk_flush() {
    if (vblk_active == 0) { return 0 - 1; }
    if (vblk_flush_supported == 0) { return 0; }   # write-through device: nothing to flush, success
    return vblk_do_flush();
}
```
QEMU offers `VIRTIO_BLK_F_FLUSH` under the default `cache=writeback`, so this path is exercisable in the smoke harness. QEMU-only backend (no bare-metal VirtIO).

### 2.5 RAM-disk — honest no-op

`/dev/ram0`-equivalent is `pmm_alloc`-backed volatile memory. There is no non-volatile medium and no cache layer; "flush to stable storage" is vacuous. `ramdisk_blk_flush()` returns `0` (success) unconditionally. Documenting this is the deliverable — not code machinery.

## 3. Dispatch + FS hook

**`core/block.cyr`** — add `blk_flush()` / `blk_flush_on(tag)` mirroring the `blk_write` / `blk_write_on` precedent (`:164`, `:178`), same `blk_registered`-bit gate:

```cyrius
fn blk_flush_on(tag) {
    if ((blk_registered & (1 << tag)) == 0) { return 0 - 1; }
    if (tag == BLK_VIRTIO)  { return vblk_blk_flush(); }
    if (tag == BLK_NVME)    { return nvme_blk_flush(); }
    if (tag == BLK_AHCI)    { return ahci_blk_flush(); }
    if (tag == BLK_USB_MS)  { return msc_blk_flush(); }
    if (tag == BLK_RAMDISK) { return ramdisk_blk_flush(); }
    return 0 - 1;
}
fn blk_flush() { return blk_flush_on(blk_active); }
```

**`core/ext2.cyr` `ext2_sync()`** (`:598`) — today it sets `EXT2_VALID_FS` and writes the superblock. Add the barrier **after** the SB write completes (so the clean-state SB is itself made durable):

```cyrius
fn ext2_sync() {
    if (ext2_active == 0) { return 0 - 1; }
    if (ext2_write_ok == 0) { return 0 - 1; }
    # ... set EXT2_VALID_FS, ext2_fs_dirty = 0, ext2_write_superblock() ...
    blk_flush_on(ext2_backend);          # NEW: force the drive to commit cache
    return 0;
}
```
This is what makes the `sync` shell verb an end-to-end durability barrier. (Ordering note from § 1: the flush goes last because every preceding `blk_write_on` already completed at the controller; flush then pushes the controller-acked data through the drive's own cache.)

## 4. Failure modes — accept vs forbid

- **Accept**: a flush that the device reports unsupported (USB stick with no writeback cache → `INVALID COMMAND OPCODE`; VirtIO without `F_FLUSH`; RAM-disk). These return success — the durability contract is already satisfied by write-through behavior.
- **Accept**: flush takes seconds. Expected on a drive committing a large cache (§ 7).
- **Forbid**: silently skipping the flush on a backend that *does* have a cache and *does* support the command (NVMe/AHCI on real drives). That's the gap this cycle exists to close.
- **Forbid**: a flush that corrupts or reorders the write path. The e2fsck-clean smoke gate is the oracle here exactly as in the write bites.

## 5. Bite decomposition (matches the tracker)

1. **This audit** (doc).
2. **`blk_flush()`/`blk_flush_on` + iron backends**: `nvme_blk_flush` + `ahci_issue_nodata`/`ahci_blk_flush`, wired into `ext2_sync()`. QEMU smoke on the NVMe-backed write-smoke image: `sync` issues FLUSH, completes status-OK, `e2fsck -fn` clean, W1–W5 + rename/ln/sym regression green.
3. **Remaining backends + close**: `msc_blk_flush` + VirtIO feature-negotiate + `vblk_do_flush`/`vblk_blk_flush` + `ramdisk_blk_flush` no-op. QEMU smoke against `usb-storage` + `virtio-blk`. Final-bite optional iron burn user-driven ([[feedback_iron_burns_block_other_work]]).

## 6. Falsification rubric

- **PASS** = each registered backend's flush issues the device's flush command and the device returns success (NVMe CQE status 0 / AHCI `PxCI` clear, no `PxTFD.ERR` / USB-MS good CSW / VirtIO used-ring status 0); `ext2_sync()` calls it; `ext2-write-smoke.sh` stays `e2fsck -fn` clean with no regression; build within the 800 KB `test.sh` ceiling.
- **FALSIFIED / rethink** = a backend's flush hangs or errors in QEMU (→ wrong opcode/FIS/descriptor shape — re-derive from § 2, not by trial); or flush perturbs the write path (e2fsck regression); or a backend has provably no cache/feature (→ document the no-op per § 0 and close, don't build machinery).

## 7. The one real gotcha — flush timeout

A cache flush is **not** bounded by the normal-I/O timeout. ATA8-ACS permits FLUSH CACHE EXT to take tens of seconds; NVMe FLUSH similarly when a large cache is dirty. The existing poll ceilings (`nvme_io_poll` 10M iters; `AHCI_TIMEOUT_SPINS`) are tuned for single-sector transfers and may be too tight. Bite 2 must either bump the flush-path ceiling specifically (a dedicated `*_FLUSH_TIMEOUT_SPINS`, the way USB-MS got `XHCI_BULK_TIMEOUT_SPINS` in 1.31.3) or accept a longer spin on the flush path only. Don't reuse the transfer timeout blindly — a flush that returns "timeout" when the drive simply needed 3 s would be a false durability failure. **No serial/iron instrumentation** to observe this ([[feedback_no_serial_on_iron]]); QEMU smoke + a single bounded smoke-only print is the channel.

## 8. References

- **NVM Express Base Specification** + **NVM Command Set** — Flush (opcode 0x00).
- **ATA8-ACS / ACS-2+** §7.10 — FLUSH CACHE EXT (0xEA) vs FLUSH CACHE (0xE7).
- **SBC-3** §5.20 — SYNCHRONIZE CACHE(10) (0x35); SAM/SPC for CHECK CONDITION on unsupported.
- **VirtIO 1.x** §5.2 — block device, `VIRTIO_BLK_T_FLUSH`, `VIRTIO_BLK_F_FLUSH`.
- **Linux** `block/blk-flush.c` `blkdev_issue_flush`, `drivers/nvme/host/core.c` `nvme_setup_flush`, `drivers/scsi/sd.c` `sd_sync_cache`, libata `ata_do_dev_read_id`/flush taskfile.
- **FreeBSD** `BIO_FLUSH` handling in `cam/`, `nvme/`, `ata`/`ada`.
- AGNOS internal: [`ext2-ext4-write-prior-art.md`](ext2-ext4-write-prior-art.md) § 2.3/§ 3/§ 14, the four drivers `core/nvme.cyr` `core/ahci.cyr` `core/virtio_blk.cyr` `arch/x86_64/usb/msc.cyr`, dispatch `core/block.cyr`.
