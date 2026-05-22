# ext2 / ext4 Read-Only — Pre-Iron-Burn Audit (Attempt 90)

> **Status**: Open | **Drafted**: 2026-05-21 evening | **Target burn**: Attempt 90 — post-1.31.6 bite (G) + bite (H) landing
>
> Per `feedback_iron_burns_block_other_work` — every iron-burn proposal carries a written
> line-by-line audit FIRST. This is the gate for the ext2/4 victory-lap burn against the
> dual `agnos-fs` carves on archaemenid. Format mirrors [`ahci-iron-burn-audit.md`](ahci-iron-burn-audit.md)
> and [`usb-ms-iron-burn-audit.md`](usb-ms-iron-burn-audit.md) since both called their target
> attempt's success path correctly.
>
> **Companion audits**:
> - [`ext2-ext4-extents-prior-art.md`](ext2-ext4-extents-prior-art.md) — multi-source convergent port plan (Linux v6.6 + FreeBSD + OpenBSD + Haiku + spec)
> - [`msc-reset-recovery-prior-art.md`](msc-reset-recovery-prior-art.md) — the multi-source convergence pattern this doc follows
> - agnos CHANGELOG `[1.31.5]` § ext2 / ext4 — what landed in QEMU
> - agnos CHANGELOG `[1.31.6]` (in progress) — what will land before this burn

---

## §1 Scope of the proposed burn

**One burn covers the full ext2/4 Phase 1-4 stack against TWO iron surfaces simultaneously** —
the AHCI/SATA `agnos-fs` ext4 carve on `/dev/sda1` (1.31.1 iron-validated SATA backend) AND
the NVMe `agnos-fs` ext4 carve on `/dev/nvme0n1p3` (1.31.0 iron-validated NVMe backend).
Either surface alone would validate the driver; both together isolate per-backend behavior
from per-driver behavior. No incremental burn between the two is justified — the cost is
the same one re-cabling + boot cycle either way.

**Build under test (target — exact size pending bite landings):**

| Component | Version | Notes |
|---|---|---|
| `agnos` | 1.31.6 (post-bites A/B/C/D/G/H + audit doc E + sweep F) | Cleanup-cycle complete; multi-backend ext2 probe gates the burn |
| `gnoboot` | 0.4.2 (unchanged from Attempts 80-89) | Sovereign UEFI handoff, no bootloader-side change |
| `cyrius` | 6.0.1 toolchain (unchanged) | Same as Attempts 82-89 |

**Iron-target topology on archaemenid (post host-side prep, verified 2026-05-21 PM):**

| Backend | Device | Partition layout | ext4 surface |
|---|---|---|---|
| NVMe (BLK_NVME, primary) | Crucial P3 2 TB CT2000P3SSD8 | p1=ESP (1024 MiB) / p2=btrfs root (1902607 MiB, shrunk by 4 GiB online) / **p3=AGNOS-NVME-FS (4096 MiB, Linux-FS GUID)** | `/dev/nvme0n1p3` = ext4, `-O extents,^huge_file,^64bit,^metadata_csum,^has_journal,^orphan_file,^resize_inode`, incompat `0x242`, `hello.txt` seeded |
| AHCI/SATA (BLK_AHCI, secondary) | WD Blue SA510 2 TB | p1=**AGNOS-FS (4 GiB, Linux-FS GUID)** | `/dev/sda1` = ext4, `-O extents,^huge_file,^64bit,^metadata_csum`, incompat `0x242`, `hello.txt` seeded |
| USB MS (BLK_USB_MS, tertiary) | Silicon Motion 125 GB stick `VID=0x090C PID=0x1000` | unmodified | regression surface only (validates Phase 2.8 transport still holds) |

Both ext4 surfaces have:
- Incompat sum `0x242` (`extent | flex_bg | filetype`), well within AGNOS supported mask `0x6746`
- Block size 4096 (set explicitly with `-b 4096` for sda1; default for nvme0n1p3)
- Cleaner-than-default feature set (no journal, no orphan_file, no resize_inode where possible)
- 64bit feature **NOT** set — viable without 1.31.7 Phase 5 work
- Linux-FS partition type GUID `0FC63DAF-8483-4772-8E79-3D69D8477DE4`

**Expected ext2/4 boot behavior on archaemenid (post-bite-G+H build):**

1. Storage trio enumerates clean (per Attempt 89 byte-match): NVMe Crucial P3 + AHCI WD Blue + USB MS Silicon Motion.
2. GPT Phase 3 parses 3 partitions on NVMe (matches Attempt 89: p1 EFI / p2 unknown(btrfs) / p3 unknown agnos-fs) AND 1 partition on sda (new: p1 agnos-fs).
3. Multi-backend probe (bite G) iterates NVMe → AHCI → USB MS → VirtIO → RAMDISK looking for ext2 magic.
4. NVMe LBA 2-3 = inside btrfs root content → magic miss (silent).
5. **Partition-aware probe (bite H)** for NVMe iterates partitions via `gpt_partition_info(idx)`: p1 ESP (skip — not Linux-FS GUID), p2 btrfs (LBA 2-3 within partition = btrfs metadata, miss), **p3 agnos-fs (LBA 2-3 within partition = ext4 superblock at offset 1024 within block 0; magic hit `0xEF53`)** → MOUNT.
6. `ext2: mounted (blocksize=4096, inode_size=256, inodes_per_group=...)` prints with AGNOS-NVME-FS geometry.
7. `agnos> ls /` returns `./ ../ lost+found/ hello.txt`.
8. `agnos> cat /hello.txt` returns the seed content byte-exact.
9. AHCI/sda1 + USB-MS not mounted (probe stops at first match per spec); both surfaces validate the driver indirectly via the GPT-parses-3-partitions and `msc: 1 mass-storage device(s) detected` shapes from Attempts 87/88/89.

---

## §2 What this burn ADDS to the iron coverage matrix

After this burn lands, archaemenid will have:

- **Four** iron-validated block backends (NVMe + AHCI + USB MS + ext2/4 filesystem layer mounted on top).
- **First iron `ls`/`cat`** against a real Linux-compatible filesystem from AGNOS.
- **First iron partition-aware mount** — GPT consumption fed into a filesystem driver.
- **First iron exercise of the multi-backend probe** — `ext2_init` walks all registered backends instead of assuming `blk_active`.

This closes the 1.31.x storage + filesystem arc end-to-end on real hardware. The remaining
filesystem-side work (write paths, HTREE, symlinks, 64BIT) is pinned to later cycles per
roadmap rows 7b / 13 / 14 / 15.

---

## §3 Hypothesis ranking — what could go wrong on iron vs. QEMU

Sorted by descending iron-specific risk. Items 1-3 are the load-bearing concerns;
4-6 are second-order.

### H1 (HIGH) — Partition-aware probe order surprises

The probe could hit a non-target ext2/4 magic before the intended `agnos-fs` partition.
Specifically: if any unrelated partition on any backend has `0xEF53` at LBA-2 offset 1024
*by coincidence* (random data alignment), the probe mounts the wrong surface and the user
sees a successful-looking `ext2: mounted` line with garbage geometry.

**Mitigation**: probe gated on GPT partition-type-GUID being Linux-FS (`0FC63DAF-...`) OR
"unknown" with explicit user-labeled `agnos-fs` partition name. Verifies type-tag intent
before reading the superblock. Codified in bite H.

**Triage if hit**: boot log will show `ext2: mounted` with mismatched `blocksize` /
`inodes_per_group` / corrupted `ls /` output. Action: tighten partition gating to
Linux-FS GUID strict.

### H2 (HIGH) — Block-size mismatch between probe and superblock

Probe reads LBA 2-3 (two 512-B sectors = 1024 bytes covering offset 1024-2047 of the
partition, where the ext2 superblock lives by spec). If the underlying block backend
returns 4096-B sectors (the Crucial P3 advertises 512 but might serve 4096 internally
through NVMe LBA Format 1) the probe still reads the right bytes, BUT the **subsequent
mount** uses `1024 << s_log_block_size` for blocksize, and if the kernel's `blk_read`
helper assumes 512-B sectors, off-by-N reads land in the wrong physical place.

**Mitigation**: AGNOS's `blk_read` already abstracts sector size via `blk_lba_bytes`
(established 1.31.2 for the USB MS optical case). ext2 multi-backend probe must respect
`blk_lba_bytes(backend_tag)` when computing the byte-offset for the LBA-2 read.

**Triage if hit**: `ext2: bad magic` even though `tune2fs` shows the FS is healthy. Action:
recompute LBA from byte-offset via `blk_lba_bytes` and re-probe.

### H3 (MEDIUM) — Probe race / first-wins ordering bias

The probe is sequential (NVMe → AHCI → USB MS → ...). If we add new backends later
(network block device, second NVMe), the first-wins ordering could mount the wrong one
on a multi-FS system. Today this is purely theoretical — archaemenid has exactly one
backend per class — but the audit doc captures it so future-us doesn't get bitten.

**Mitigation**: document the ordering policy in `block.cyr` comments + add a `EXT2_MOUNT_HINT`
build flag for explicit selection if/when multi-FS systems become real.

**Triage if hit**: wrong-FS mount on a system with two ext2 backends. Action: prefer
later-registered (= more-specific) backends, or expose a `mount` shell command.

### H4 (LOW) — `agnos-fs` GPT partition name encoding

GPT partition names are UTF-16LE per spec; AGNOS's `gpt.cyr` Phase 1 decodes UTF-16LE
correctly (validated 1.31.1 QEMU smoke). But `parted`/`sgdisk` write partition names
differently (parted as UTF-8 → UTF-16LE conversion; sgdisk identical). The host-side prep
used both tools; if the recorded name mis-matches AGNOS's expected `agnos-fs` literal,
partition-name-based gating would miss.

**Mitigation**: use partition-type GUID (binary-stable) as the gate, not the human-readable
name. The host-side prep already set the Linux-FS GUID via `sgdisk -t`.

**Triage if hit**: GPT enumeration shows `(unknown type) <garbled name>` instead of
`(unknown type) agnos-fs`. Action: confirm GUID-based gating works regardless of name.

### H5 (LOW) — Btrfs subvolume on NVMe p2 interferes with probe

Probe iterates over GPT partitions including p2 (btrfs). Reading LBA 2-3 of p2 lands in
btrfs metadata. Btrfs uses magic `_BHRfS_M` at byte 65,536 (LBA 128), so LBA-2 of p2
won't accidentally match ext2's `0xEF53`. But if btrfs has *any* incidental `0xEF53`
short pattern at the right offset, probe could false-positive.

**Mitigation**: probe validates `s_magic == 0xEF53` AND `s_log_block_size <= 2` (covers
1K/2K/4K) AND `s_inodes_per_group > 0`. Three-check gate makes false-positive astronomically
unlikely.

**Triage if hit**: `ext2: mounted` from p2 with nonsense geometry, then immediate fault on
first inode read. Action: add `s_inodes_count` upper bound check.

### H6 (LOW) — IO error mid-probe leaves block layer in bad state

If `blk_read_on(BLK_AHCI, ...)` fails mid-probe (transient SATA glitch), does the probe
recover to try the next backend, or abort the boot? Per Attempt 81 the AHCI quiescence
gate makes mid-command IO errors rare on the SA510, but it's possible.

**Mitigation**: `blk_read_on` returns error code; probe loop catches and continues to next
backend. Already implemented in bite G.

**Triage if hit**: `ext2: backend N read failed, trying next` log line + clean continuation.

---

## §4 What to NOT do on this burn

- **NO instrumentation** beyond what's load-bearing. Per `feedback_no_instrumentation_means_no_instrumentation`. The CMOS kcps for ext2 init are already in place from 1.31.5 Phase 1.
- **NO write tests**. ext2/4 is read-only in 1.31.x. The WRITE cycle is pinned to 1.33.x and gets its own audit. Do NOT attempt `agnos> echo X > /file` even speculatively — there's no implementation.
- **NO format on the iron drives mid-burn**. Host-side prep is done; if a surface needs reformatting, that's a host-side action between burns, not during.
- **NO probe-on-USB-MS triggering**. The USB stick is unmodified Silicon Motion content (NTFS or similar). Probe will read its LBA 2-3, magic miss, move on — that's the expected path. Do NOT propose reformatting the USB stick as ext2 unless the user explicitly redirects.
- **NO `MSC_RW_DEMO=1` or `AHCI_RW_DEMO=1` build flags**. These trigger write demos on real silicon — out of scope for this read-only burn.
- **NO Quiet-Boot work**. The AMD Zen scanout residue is parked per memory `project_amd_zen_scanout_residue`.

---

## §5 Success rubric

### Full PASS (rubric a)

```
nvme: registered as block_dev (3907029168 LBAs x 512B)
ahci: registered as secondary block_dev (port 0, 3907029168 LBAs x 512B; NVMe primary)
msc: registered as tertiary block_dev (slot 2, 252051456 LBAs x 512B; NVMe primary)
gpt: present, first=34 last=3907029134 parts=3/128 hdr-CRC-OK arr-CRC-OK
 [0] EFI System    LBA 2048-2099199 (1024 MiB)
 [1] (unknown type) LBA 2099200-3898638335 (1902607 MiB)
 [2] (unknown type) agnos-fs LBA 3898638336-3907026943 (4096 MiB)
ext2: probing NVMe (BLK_NVME) ... partition 2 (Linux-FS GUID) ... magic OK
ext2: mounted /dev/nvme0n1p3 (blocksize=4096, inode_size=256, inodes_per_group=8192, total_inodes=N)
VFS initialized
... (rest of boot) ...
AGNOS shell v1.31.6 (type 'help')
agnos> ls /
./ ../ lost+found/ hello.txt
agnos> cat /hello.txt
Hello from ext2 on archaemenid SATA — iron burn 89 reads me byte-exact
```

(Or `Hello from ext2 on archaemenid NVMe — ...` depending on whether NVMe or AHCI wins
probe order. Both are PASS.)

### Partial — wrong-backend hit (rubric b)

Mount on AHCI sda1 before NVMe p3 (or vice versa). Action: confirm ordering matches
documented policy in bite-G comments; if order is intentional, update audit doc; if
unintentional, file bite for ordering fix in 1.31.7.

### Partial — wrong-FS hit (rubric c)

Mount on a non-Linux-FS GUID partition (H1 hypothesis hit). Action: tighten H4 gating
to require Linux-FS GUID strict (currently allows "unknown" too for the carve case).

### Partial — incompat miss (rubric d)

Boot log shows `ext2: unsupported incompat bits: <decimal>` on a surface we expected to
match the supported mask `0x6746`. Decode the decimal; if `0x80` (64bit), pin to 1.31.7
Phase 5 work. Other bits → audit triage per `ext2-ext4-extents-prior-art.md § 6.1`.

### Partial — multi-backend probe found nothing (rubric e)

No `ext2: mounted` line at all. Action: triage why — probe walked all backends but failed
to find magic. Possibilities: (1) GPT consumption broken (bite H regression); (2)
`blk_read_on` returning wrong data; (3) host-side prep ran wrong. Verify against host
`sudo dumpe2fs /dev/nvme0n1p3 | head` to confirm FS is real.

### FALSIFIED (rubric f)

Kernel hangs / faults / can't reach shell. Triage per other iron arcs: CMOS extended-bank
kcps for ext2 init checkpoints + visual FB readback. No serial on iron per
`feedback_no_serial_on_iron`.

---

## §6 Mitigations applied this burn

- **Probe magic strict-three-check** (H5): `0xEF53` magic + `s_log_block_size <= 2` + `s_inodes_per_group > 0`. Defended in bite G.
- **`blk_lba_bytes`-aware probe** (H2): byte-offset calc respects per-backend sector size. Defended in bite G.
- **Linux-FS GUID gating in partition-aware mount** (H1+H4): partition-type GUID is the gate, not name. Defended in bite H.
- **No instrumentation beyond load-bearing** (per memory): no CMOS-stamp / FB-readback specific to this burn.
- **No write tests, no `*_RW_DEMO` flags** (per §4).

---

## §7 CMOS post-mortem checkpoints reserved for this burn

ext2 layer's existing checkpoints from 1.31.5 Phase 1 stay in place:
- `0x52` — ext2_init entry
- `0x53` — superblock magic OK
- `0x54` — BGDT read OK
- `0x55` — Phase 3 path-lookup ready

New for 1.31.6:
- `0x56` — multi-backend probe entry (bite G)
- `0x57` — partition-aware probe entry (bite H)
- `0x58` — mount success (covers both whole-disk and partition-aware paths)

If the boot hangs, read these in order via `agnosticos/scripts/build/read-boot-log` to
identify the stage. Per `project_archaemenid_cmos_map`, 0x50-0x7F is virgin scratch on
this box; no BIOS collision risk.

---

## §8 Multi-source prior art consulted

Per `feedback_redesign_dont_reinvent` — Linux is one source of many:

| Source | Filepath | What it informed |
|---|---|---|
| Linux v6.6 | `fs/ext2/super.c::ext2_fill_super` | Magic check sequence, supported_compat mask shape |
| Linux v6.6 | `fs/ext4/super.c::ext4_fill_super` | Extents-feature gate, incompat strictness |
| Linux v6.6 | `fs/ext4/extents.c::ext4_ext_find_extent` | Extent tree walk shape (Phase 4) |
| FreeBSD `main` | `sys/fs/ext2fs/ext2_subr.c::ext2_compute_sb_data` | Cleanest standalone RO superblock decoder |
| OpenBSD `master` | `sys/ufs/ext2fs/ext2fs_vfsops.c::ext2fs_reload` | Multi-backend mount precedent |
| Haiku `master` | `src/add-ons/kernel/file_systems/ext2/Volume.cpp` | Accessor-method byte-order pattern |
| ext4 wiki | https://ext4.wiki.kernel.org/ | Extent format binary layout |
| nongnu spec | https://www.nongnu.org/ext2-doc/ext2.html | ext2 baseline reference |

Cross-source convergence: all four implementations (Linux, FreeBSD, OpenBSD, Haiku) do
magic-check + size-check + sanity-check at mount in roughly the order AGNOS does. None
attempt mount without first reading the superblock — confirming AGNOS's "probe-then-mount"
split is the canonical shape.

---

## §9 Audit disposition

**Approved for burn AFTER:**

1. ✅ Bite (G) multi-backend probe landed in `block.cyr` + `ext2.cyr`
2. ✅ Bite (H) partition-aware mount landed in `ext2.cyr`
3. ✅ Bite (A) ext2 input validation hardening landed (defense-in-depth for H5 + H6)
4. ✅ Bite (E) audit doc (this file) committed
5. ✅ Bite (F) state.md / roadmap / iron-log sweep landed (so the burn fires against a documented baseline)
6. ✅ Build verified post-bites (per `feedback_build_freshness_is_mine`)
7. ✅ QEMU re-validation across all backends post-bites — **4/4 smoke scenarios PASS + 4/4 regression cross-check PASS** via `agnos/scripts/ext2-smoke.sh` (now a permanent tracked test in agnos):
   - Baseline (virtio-blk ESP only, no ext2): silent miss as expected, shell reached
   - Bite-G test (ESP-on-NVMe + ext4 whole-disk on AHCI): `ext2: probe matched backend=3 whole-disk` + `ext2: mounted (4096 / 256 / 4096)` ✓
   - Bite-H test (ESP + Linux-FS partition both on NVMe): `ext2: probe matched backend=2 partition_lba=67584` + `ext2: mounted (4096 / 256 / 17152)` ✓
   - Combined NVMe+AHCI: NVMe partition-aware wins probe order ✓
   - All four reach `AGNOS shell v1.31.6` cleanly (no storage-trio regression)
   - Re-runnable on any kernel touch in the filesystem layer; rebuilds disk images each invocation.
8. ✅ Host-side `tune2fs -l` re-confirmed on BOTH `/dev/sda1` AND `/dev/nvme0n1p3` (features within `0x6746` mask — incompat sum `0x242`, no 64bit)

**Smoke-surfaced adjacent fixes (now in 1.31.6 cut):**

- `blk_mark_registered(tag)` helper closes the bypass where AHCI/USB-MS secondary/tertiary paths weren't setting the `blk_registered` bit. Bite G is functional only with this fix.
- `GPT_TYPE_LINUX_FS_LO` constant byte-typo (`0xC663AF` → `0xC63DAF`) corrected. Bite H's GUID gate now matches valid Linux-FS partitions. Linux-FS partitions previously displayed as `(unknown type)` in GPT enumeration; now correctly tagged.

**Disposition: approved for burn queue.** Per `feedback_per_action_consent`: the burn itself
needs an explicit user approval at the moment of firing, separate from this audit's
approval. The smokes simulate the iron path closely enough that the iron burn risk is
predominantly hardware-specific (Crucial P3 vs QEMU NVMe, WD Blue SA510 vs ich9-ahci); no
behavioral surprises from the driver are expected.

---

*Audit pattern lifted from `usb-ms-iron-burn-audit.md` (which called Attempt 87 correctly)
and `ahci-iron-burn-audit.md` (which called Attempt 81 correctly). This is the third
storage-class audit doc in the 1.31.x arc; the pattern is established.*
