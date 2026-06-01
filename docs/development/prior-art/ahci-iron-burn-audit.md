---
name: AHCI Iron-Burn Audit (Phase 1-4)
description: Pre-burn safety review for the first AHCI/SATA iron exercise on archaemenid's sda 1.8 TB SSD
type: planning / audit
date: 2026-05-20
---

# AHCI Iron-Burn Audit — archaemenid `sda` (Phase 1-4)

> **Per [`feedback_iron_burns_block_other_work`](../../../.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_iron_burns_block_other_work.md)** — no burn proposed without a written, line-by-line audit FIRST. Burns hold up the user's unrelated work on archaemenid. This document is the audit; the burn itself is a separate user-driven action.

## 1. Goal

Validate the AHCI/SATA driver (agnos 1.31.1 `[Unreleased]`, Phases 1-4) against real silicon — the 2.5" SATA 1.8 TB SSD attached as `sda` on archaemenid (per `project_hardware_catalog`). The QEMU q35 ich9-ahci smoke validated the driver's behavior at AHCI 1.0; iron will exercise it at whichever AHCI version archaemenid's chipset reports (likely 1.2 or 1.3.1) on a real-PHY-handshake-validated SATA link.

## 2. Code surface that lands new on iron

The kernel artifact carries:

| Phase | Code path | Writes to disk? | Writes to controller? |
|---|---|---|---|
| **P1** `ahci_probe` + `ahci_enum_ports` | PCI config space writes (bus-master enable), BAR5 UC remap, controller register READs only | No | Bus-master enable + MMIO reads |
| **P2** `ahci_init_all` | Per-port `PxCMD` / `PxCLB` / `PxFB` / `PxSERR` writes, kernel page allocations for CL+FIS buffers | No | Yes (controller-level, no LBA touches) |
| **P3** `ahci_identify_all` | ATA `IDENTIFY DEVICE` (0xEC) — returns 512 bytes of device metadata, doesn't read/write any LBA | No | Command issue (PxCI), no disk LBAs |
| **P4** `ahci_rw_demo` | **DANGER**: reads LBA 0, **writes** `"AHCI-OK!"` sentinel to **LBA 5**, reads LBA 5 back to verify | **Yes — LBA 5, 1 sector** | Same as P3 |
| **P4** `ahci_register_block_dev` | One more IDENTIFY (capacity refresh), block-layer registration (secondary; NVMe stays primary) | No | Same as P3 |

The **only iron-write risk** is the LBA-5 sentinel write in `ahci_rw_demo`. Everything else is read-only against disk content (the controller-register writes in P1+P2+P3 are device-state, not disk-content).

## 3. The LBA-5 write danger — laid out byte-for-byte

`ahci_rw_demo` writes the following 512-byte payload to LBA 5 (= disk byte offset 2560–3071) on the lowest-numbered initialized SATA port:

| Bytes | Value | Origin |
|---|---|---|
| 0-7 | `"AHCI-OK!"` (ASCII 65 72 67 73 45 79 75 33) | `store8(buf+i, ...)` sentinel construction |
| 8-511 | All zeros | `store8(buf+i, 0)` zero-fill loop |

On archaemenid's `sda`, LBA 5 is **inside the GPT partition entry array** (assuming the drive has a standard GPT layout):

| LBA range | Standard GPT content |
|---|---|
| 0 | Protective MBR |
| 1 | GPT header (primary) |
| 2–33 | Partition entry array (32 LBAs × 512 B = 16 KB = 128 entries × 128 B) |
| 34–(end-34) | Partition data (consumer filesystems) |
| (end-33)–(end-1) | Backup partition entry array |
| end | GPT header (backup) |

**LBA 5 sits at partition entries 24-27** (since 4 entries fit per LBA at 128 B/entry; LBA 5 = `partition_entries_lba (=2) + 3` = 4th LBA of array = entries 12-15 if we count from 0... wait let me recompute).

`partition_entries_lba` per spec defaults to 2. So:
- LBA 2 = entries 0-3 (4 entries × 128 B = 512 B)
- LBA 3 = entries 4-7
- LBA 4 = entries 8-11
- LBA 5 = **entries 12-15** ← write target
- ...
- LBA 33 = entries 124-127

A write to LBA 5 corrupts partition entries 12-15. Whether those entries are populated on archaemenid's `sda` depends on the user's partitioning. If `sda` has ≤12 partitions (the common case), entries 12-15 are empty (all-zero per UEFI § 5.3.3), and the sentinel write **replaces empty entries with garbage** — which would then cause:

1. **GPT partition array CRC32 to fail** on next probe (the array's CRC field is in the header; the array content changed).
2. **Phase 3 (this audit's GPT side)** would print `arr-CRC-BAD` on next boot.
3. **Tools like `parted`, `sgdisk`, `lsblk`** may refuse to interact with the drive until the CRC is repaired (via `sgdisk --backup` / `sgdisk --load-backup` or `gdisk` "verify" → "rewrite headers").

If entries 12-15 ARE populated (drive has 13+ partitions), the sentinel **destroys 4 real partition entries**. Recovery requires the backup partition array at the disk's tail (UEFI § 5.3.4), which is intact (we don't touch it) — `sgdisk --backup` from another machine could reconstruct.

**In neither case does the sentinel touch partition DATA** (LBAs 34+). The user's files inside the partitions are safe.

But — **partition table corruption is still a real harm** the user shouldn't have to clean up. The QEMU smoke is OK with this because `sata1.img` is a throwaway; iron is not.

## 4. Mitigation: `AHCI_RW_DEMO` compile gate

Match the existing `KTEST` / `XHCI_VERBOSE` pattern (per `project_state_md_pattern`'s production-lean cycle-open at 1.31.0). The write portion of `ahci_rw_demo` ships compile-gated; iron burns build without it (default).

### 4a. Source change (proposed; not yet applied)

Split `ahci_rw_demo` into a read-only base + a compile-gated write extension. In `kernel/core/ahci.cyr`:

```cyrius
# Always-safe read demo: read LBA 0, print first 8 bytes. No disk
# writes. Mirrors the existing nvme: ns1 LBA0 first 8 bytes line.
fn ahci_read_demo() {
    if (ahci_present == 0) { return 0; }
    var port = 0;
    while (port < AHCI_MAX_PORTS) {
        if (load8(&ahci_port_inited + port) == 1) { port = port; break; }
        port = port + 1;
    }
    if (port >= AHCI_MAX_PORTS) { return 0; }
    if (load8(&ahci_port_inited + port) != 1) { return 0; }

    if (ahci_demo_buf == 0) {
        ahci_demo_buf = pmm_alloc();
        if (ahci_demo_buf == 0) { return 0; }
    }
    var i = 0;
    while (i < 512) { store8(ahci_demo_buf + i, 0); i = i + 1; }
    if (ahci_read_lba(port, 0, 1, ahci_demo_buf) == 0) {
        kprint("ahci: port ", 11);
        kprint_num(port);
        kprintln(" LBA0 read FAILED", 17);
        return 0;
    }
    kprint("ahci: port ", 11);
    kprint_num(port);
    kprint(" LBA0 first 8 bytes:", 20);
    i = 0;
    while (i < 8) {
        kprint(" ", 1);
        kprint_num(load8(ahci_demo_buf + i));
        i = i + 1;
    }
    kprintln("", 0);
    return 1;
}

#ifdef AHCI_RW_DEMO
# Write+read round-trip on LBA 5. Compile-gated — DO NOT enable for
# iron builds against production drives. Default off.
fn ahci_write_demo() {
    # ... existing LBA-5 sentinel write + read-back + verify path ...
}
#endif
```

And in `kernel/core/main.cyr` replace the `ahci_rw_demo()` call with:

```cyrius
ahci_read_demo();
#ifdef AHCI_RW_DEMO
ahci_write_demo();
#endif
```

Plus `scripts/build.sh` honors `AHCI_RW_DEMO=1` the same way it honors `KTEST=1` / `XHCI_VERBOSE=1`, and `docs/development/build.md` documents the new gate alongside the others.

### 4b. Verification of the mitigation

After the change lands, a clean build (no `AHCI_RW_DEMO`) should:
- Still print `ahci: port N LBA0 first 8 bytes: ...` (read demo runs unconditionally)
- **Not** print `ahci: port N LBA5 write-then-read round-trip ...` (write demo compiled out)
- Build size drops ~500-800 B (the write + verify path elided by DCE)

The QEMU smoke can be re-run with `AHCI_RW_DEMO=1 sh scripts/build.sh` to keep validating the write path post-change. Existing CHANGELOG `[Unreleased]` § AHCI Phase 4 already documents the round-trip; the post-change behavior matches that document when the gate is on.

## 5. Mitigated iron-burn artifact

Assuming the §4 change lands first:

| Component | Value |
|---|---|
| `agnos` | 1.31.1 `[Unreleased]` HEAD with §4 patch applied (no `AHCI_RW_DEMO`). Build size approx 474,300–474,600 B (current 475,096 minus ~500 B for elided write demo). |
| `gnoboot` | 0.4.2 (unchanged from Attempt 80) |
| `cyrius` | 6.0.1 toolchain post-cycle-open; kernel pin 5.11.x bedrock (no change) |
| Build flag | `KTEST` off, `XHCI_VERBOSE` off, `AHCI_RW_DEMO` off (defaults) |

USB media: produced via `scripts/install-usb.sh --update` per the established pattern (user owns the install; Claude owns the build per `feedback_build_freshness_is_mine` and `feedback_bootloader_kernel_ownership`).

## 6. Expected iron output (success path)

On boot, between NVMe registration and GPT init, the framebuffer should show:

```
ahci: found at <real-PCIe-BAR5-address>, version=<1.0 | 1.2 | 1.3.1>
ahci: NP=<probably 1-6> NCS=<probably 31> ISS=<probably 3 = 6 Gbps> SAM=<0 or 1> SSS=<0 or 1> SNCQ=1 S64A=1
ahci: GHC=<bit 31 set> PI=<bitmap, low bit(s) for connected ports>
ahci: port <N> DET=3 SPD=<2 or 3> SIG=257 (SATA)
ahci: port <N> initialized (CL @ <kernel-phys>, FIS @ <kernel-phys>)
ahci: port <N> model='<actual SSD model>' serial='<actual serial>' fw='<firmware>'
ahci: port <N> LBA48=<3500000000-ish for 1.8 TB> sectors (<1750000-ish> MiB)
ahci: port <N> LBA0 first 8 bytes: <8 numbers — first byte of the protective MBR>
ahci: registered as secondary block_dev (port <N>, <LBA count> LBAs x 512B; NVMe primary)
```

Then GPT (with the post-§4-change build):
- If `sda` has a GPT: `gpt: present, first=... last=... parts=N/128 hdr-CRC-OK arr-CRC-OK` (or appropriate trust posture)
- If `sda` is unpartitioned or LBA 1 doesn't have the `"EFI PART"` signature: GPT silently no-ops

Note that GPT will still run against **NVMe** (the NVMe-primary policy preserves `blk_active = BLK_NVME`). To exercise GPT against `sda`'s partition table, we'd need to force AHCI primary — out of scope for this burn.

## 7. Success / partial / failure rubrics

### Full success
- All AHCI lines print as expected (model + serial + firmware decoded as real-vendor strings, not zeros or QEMU-style placeholders)
- LBA48 capacity matches `sda` physical size
- LBA 0 first 8 bytes show whatever's actually on the drive (likely the `0xEB` x86 jump opcode at byte 0 if a protective MBR is present, or all zeros if blank)
- Kernel proceeds through GPT → VFS → shell unchanged
- No new diagnostic letters or hypotheses needed

### Partial — vendor-specific quirk
- AHCI probe finds the controller but enumeration drops a port (DET=1 instead of 3)
- IDENTIFY times out or returns garbage model strings
- Likely cause: AMD FCH AHCI controller's firmware-state differs from q35 ich9-ahci in some quirk-relevant way (analogous to xHCI's MSI-X table programming divergence on AMD FCH 1022:1639). Audit the AHCI 1.3.1 spec + Linux `drivers/ata/ahci.c` quirks table for AMD-specific paths.
- **Disposition**: capture serial output (per `feedback_no_serial_on_iron` — wait, serial is invisible on iron) → capture FB photo + read-boot-log CMOS dump, file an issue, no letter ladder per `feedback_no_letter_codes_for_repairs`.

### Failure — kernel hangs / triple-faults / no AHCI output at all
- BAR5 remap may fault if the controller advertises a 64-bit BAR with high half ≠ 0 and our `vmm_remap_uc_2mb` doesn't cover that range
- Per-port spin-up may wedge if firmware left a port in an unusual state (CR=1 with no CL, etc.)
- **Disposition**: revert to pre-AHCI agnos (1.31.0 NVMe-only tag), file an issue, plan a focused investigation. CMOS slot 0x50 will hold the last-stamped kcp value (0x4B / 0x4C / 0x4D / 0x4E / 0x4F / 0x50) → tells us where the kernel got before wedging.

### Rollback
- USB stick can be re-imaged from 1.31.0 NVMe-only build at any time
- archaemenid's `sda` content is unmodified (no writes per the §4 mitigation), so a rollback is purely software

## 8. CMOS checkpoint trail to look for

If the FB shows nothing AHCI-related but the kernel otherwise boots, dump CMOS slot 0x50 via `scripts/read-boot-log.sh` (Cyrius-based read path — `/dev/nvram` doesn't work on archaemenid per `project_archaemenid_cmos_map`). Expected values for a successful AHCI run, in order of last-written:

| Value | Meaning |
|---|---|
| 0x4B | AHCI HBA probe completed |
| 0x4C | Port enumeration done |
| 0x4E | Per-port init done (HBA reset is NOT in the default boot path; 0x4D won't appear) |
| 0x4F | First successful IDENTIFY |
| 0x50 | Block-layer registration done |
| 0x51 | GPT CRC validation done (Phase 3 — fires on NVMe disk, not on `sda` unless we force AHCI primary) |

If the highest value is < 0x50, the kernel wedged inside AHCI bring-up. < 0x4B means we didn't even start AHCI probe.

## 9. What this audit explicitly DOES NOT cover

- **`ahci_hba_reset()`** — not called by default. The function exists, has been built, but iron will never execute it under the proposed burn artifact.
- **Multi-port operation** — archaemenid has one SATA SSD on `sda`. If a second SATA drive shows up (legacy or future), this audit doesn't cover it.
- **ATAPI / port multiplier / SEMB** — Phase 2 explicitly skips non-SATA signatures. No-op on this iron.
- **Block-layer-active-path consumers** — NVMe stays primary; `blk_active` stays BLK_NVME. GPT runs against NVMe. fatfs runs against NVMe (or no-ops). The AHCI dispatch arms in `blk_read/write/read_sectors` won't be exercised by consumers, only by direct AHCI-internal callers (which don't exist post-§4 outside the read demo).
- **The `parts` shell command on AHCI** — won't print AHCI partitions because GPT runs on NVMe. Out of scope.
- **Writing partition data via the AHCI write path** — entirely out of scope. AGNOS doesn't have a partition writer, formatter, or filesystem mounter for AHCI yet.

## 10. References

- agnos CHANGELOG `[Unreleased]` § AHCI/SATA Phase 1-4 (engineering surface)
- agnos `kernel/core/ahci.cyr` (Phase 1-4 implementation; ~1,100 LOC)
- agnosticos `iron-nuc-zen-log.md` § Attempt 80 (the NVMe iron debut — structural template for this burn's narrative)
- AHCI 1.3.1 spec (Intel)
- Linux `drivers/ata/libahci.c` + `drivers/ata/ahci.c` (port-and-redesign reference per `feedback_redesign_dont_reinvent`)
- `feedback_iron_burns_block_other_work` — written audit gate this doc satisfies
- `feedback_bootloader_kernel_ownership` — Claude owns agnos + gnoboot build for iron-boot
- `feedback_build_freshness_is_mine` — kernel build is Claude's responsibility before install
- `project_hardware_catalog` — `sda` 1.8 TB SATA SSD on archaemenid (corrected 2026-05-20 from earlier M.2-only assumption)

## 11. Open questions for the user

1. **Confirm archaemenid `sda` partitioning shape.** Is it actively-used storage? GPT-formatted? If yes, the §4 mitigation (compile-gate the write demo) is essential. If `sda` is genuinely scratch space the user is okay with corrupting, we could skip §4 — but defaulting to safe is the right shape.

2. **Apply the §4 mitigation now?** A single `Edit` on `ahci.cyr` + `main.cyr` (~30 LOC delta), one-line addition in `scripts/build.sh` (KTEST/XHCI_VERBOSE pattern), one paragraph in `docs/development/build.md`. Estimated 5 minutes; build verifies clean against existing QEMU smoke with `AHCI_RW_DEMO=1`.

3. **Schedule the burn after §4 lands?** Per `feedback_iron_burns_block_other_work` the burn proposal here is the WRITTEN audit; the burn itself is the user-driven next step. Suggested batch: bundle with whichever other archaemenid work is queued so the re-cabling cost amortizes.
