---
name: exFAT filesystem — multi-source prior art
description: Offset-precise exFAT on-disk layout (boot region, allocation bitmap, upcase, FAT, typed dir-set + SetChecksum/NameHash) + the AGNOS exfat.cyr read→write bite plan for agnos 1.34.1
type: prior-art
---

# exFAT — prior art (read → write)

> **Cycle**: agnos **1.34.1** — the FAT-family sibling, split out of 1.34.0. Tracker: [`iron-nuc-zen-log.md#tracker-1341-cycle`](iron-nuc-zen-log.md#tracker-1341-cycle). This is **bite 1** (the audit). Multi-source per [[feedback_redesign_dont_reinvent]] — Microsoft exFAT specification + Linux `fs/exfat` + `exfatprogs` (`mkfs.exfat`/`fsck.exfat`, the host oracle). Builds on the overview in [`fat-family-prior-art.md`](fat-family-prior-art.md) § 4 with the offset-precise detail an implementation needs.

## 0. Why a new module, not a `fatfs` mode

exFAT shares **almost no on-disk structure** with FAT12/16/32: no BPB-shaped geometry, no 8.3/LFN, an allocation **bitmap** instead of a FAT free-scan, and a **typed directory-entry set** instead of one 32-byte record per file. So it lands as a **new `kernel/core/exfat.cyr`** with its own mount/probe, not a mode flag in `fatfs`. The `fatfs` probe already self-excludes exFAT (it reads `BytsPerSec`@11, which exFAT zeroes → `!= 512` → reject). "Done" per bite = **`fsck.exfat` clean** (write) / **host read-back byte-exact** (read), the exFAT analogue of the ext2/FAT `e2fsck`/`fsck.fat` gate.

## 1. Boot region (sector 0 = Main Boot Sector)

Offsets, little-endian:

| Off | Size | Field | Use |
|----|----|----|----|
| 0 | 3 | JumpBoot | `EB 76 90` |
| 3 | 8 | FileSystemName | **`"EXFAT   "`** (5 + 3 spaces) — the probe signature |
| 11 | 53 | MustBeZero | where a FAT BPB would be; all zero (this is what makes `fatfs` reject exFAT) |
| 64 | 8 | PartitionOffset | informational |
| 72 | 8 | VolumeLength | total sectors |
| **80** | 4 | **FatOffset** | sector offset (from volume start) of FAT #0 |
| **84** | 4 | **FatLength** | sectors per FAT |
| **88** | 4 | **ClusterHeapOffset** | sector offset of cluster 2 |
| **92** | 4 | **ClusterCount** | clusters in the heap |
| **96** | 4 | **FirstClusterOfRootDirectory** | root dir start cluster |
| 100 | 4 | VolumeSerialNumber | |
| 104 | 2 | FileSystemRevision | `0x0100` = 1.00 |
| 106 | 2 | VolumeFlags | bit1 = VolumeDirty; **mutable → excluded from boot checksum** |
| **108** | 1 | **BytesPerSectorShift** | log2(bytes/sector); 9 = 512 |
| **109** | 1 | **SectorsPerClusterShift** | log2(sectors/cluster) |
| **110** | 1 | **NumberOfFats** | 1 (2 only for TexFAT) |
| 111 | 1 | DriveSelect | |
| 112 | 1 | PercentInUse | mutable → **excluded from boot checksum** |
| 120 | 390 | BootCode | |
| 510 | 2 | BootSignature | **`0xAA55`** |

**Boot region = 12 sectors**: Main Boot Sector (0), Extended Boot (1–8), OEM Params (9), Reserved (10), **Boot Checksum (11)**, then a full **Backup Boot Region** (sectors 12–23). The checksum sector is the 4-byte checksum repeated to fill the sector, computed over sectors 0–10 with the **32-bit rotate-add** below, **skipping byte offsets 106, 107, 112** (VolumeFlags + PercentInUse). AGNOS **read** doesn't need to verify it; **write** that touches the boot sector must recompute it (we won't — write only touches FAT/bitmap/dir/heap, not the boot region, so the checksum stays valid).

```
geometry:  bytes_per_sector = 1 << BytesPerSectorShift
           sectors_per_cluster = 1 << SectorsPerClusterShift
cluster→sector(c) = ClusterHeapOffset + (c - 2) * sectors_per_cluster      # clusters number from 2
```

## 2. FAT, bitmap, upcase

- **FAT** at `FatOffset`, `FatLength` sectors. **32-bit** entries. `EOC = 0xFFFFFFFF`, `bad = 0xFFFFFFF7`, `free = 0`. **Used only for fragmented files** — see `NoFatChain` below.
- **Allocation Bitmap** — a *system file* found by walking the **root directory** for a type-`0x81` entry (gives `FirstCluster` + `DataLength`). 1 bit/cluster, **LSB-first**, byte `b` bit `i` ⇒ cluster `2 + b*8 + i`; **set = allocated**. This is the allocator's free-map (no FAT free-scan).
- **Up-case Table** — root type-`0x82` entry (`FirstCluster` + `DataLength` + `TableChecksum`). Maps each UTF-16 unit to its upper-case form for case-insensitive compare **and** the NameHash. For **ASCII** names the standard table's upcase is identical to plain ASCII `a–z → A–Z`, so a read/write limited to ASCII names can use ASCII-upcase for the hash and skip loading the table (note the assumption; load the real table when non-ASCII names are supported).

## 3. Directory: typed 32-byte entries

`EntryType`@0; high bit `0x80` = **InUse**; `0x00` = end-of-directory; a type with the InUse bit cleared (e.g. `0x05` from `0x85`) = **deleted**. Relevant types:

- **`0x81` Allocation Bitmap**: `[1]`BitmapFlags, `[20:24]`FirstCluster, `[24:32]`DataLength.
- **`0x82` Up-case Table**: `[4:8]`TableChecksum, `[20:24]`FirstCluster, `[24:32]`DataLength.
- **`0x83` Volume Label**: `[1]`CharCount, `[2:24]`UTF-16 label.
- **`0x85` File** (set primary): `[1]`**SecondaryCount** (# entries that follow in this set), `[2:4]`**SetChecksum**, `[4:6]`FileAttributes, `[8:]`timestamps.
- **`0xC0` Stream Extension** (2nd in set): `[1]`GeneralSecondaryFlags (**bit0** AllocationPossible, **bit1** **NoFatChain**), `[3]`**NameLength** (chars), `[4:6]`**NameHash**, `[8:16]`ValidDataLength, `[20:24]`**FirstCluster**, `[24:32]`**DataLength**.
- **`0xC1` File Name** (3rd…N): `[2:32]` = 15 UTF-16 chars. ⌈NameLength/15⌉ of these.

**A file = a set**: one `0x85` + one `0xC0` + ⌈NameLen/15⌉ `0xC1`, contiguous, `SecondaryCount = 1 + ⌈NameLen/15⌉`.

**`NoFatChain` (0xC0 flag bit1)**: when set, the file's clusters are **contiguous** — `FirstCluster .. FirstCluster + ⌈DataLength/clusterbytes⌉ - 1`, the FAT is **not** consulted. When clear, follow the FAT chain from `FirstCluster`. (mkfs.exfat writes small files contiguous → NoFatChain=1; AGNOS write will always allocate contiguous and set NoFatChain=1, simplest + matches the common case.)

### SetChecksum (16-bit) — over the whole set, skipping its own 2 bytes
```
chk = 0
for each byte index i over all 32*(SecondaryCount+1) bytes of the set:
    if i == 2 or i == 3: continue          # the SetChecksum field in the 0x85 entry
    chk = ((chk << 15) | (chk >> 1)) & 0xFFFF + byte[i]   # 16-bit rotate-right + add
```

### NameHash (16-bit) — over the up-cased UTF-16 name
```
hash = 0
for each UTF-16 unit of upcase(name):                    # low byte then high byte
    hash = ((hash << 15) | (hash >> 1)) & 0xFFFF + low_byte
    hash = ((hash << 15) | (hash >> 1)) & 0xFFFF + high_byte
```
(Same rotate-add as SetChecksum, over the name bytes. NameHash lets a reader reject non-matching entries before a full name compare; a writer **must** compute it correctly or `fsck.exfat` flags the set.)

### Boot checksum (32-bit) — sectors 0..10, skipping offsets 106,107,112
```
chk = 0
for each byte index i over sectors 0..10:
    if i == 106 or i == 107 or i == 112: continue
    chk = ((chk << 31) | (chk >> 1)) & 0xFFFFFFFF + byte[i]
```
(Read: not required. Write: not touched — we don't modify the boot region.)

## 4. AGNOS mapping — `kernel/core/exfat.cyr`

Mirrors the `fatfs`/`ext2` mount + block-routing pattern: `exfat_backend` + `exfat_partition_first_lba` + `exfat_blk_read`/`exfat_blk_write` = `blk_{read,write}_on(...)`. Module-global scratch buffers (single-threaded, per [[project_multithreading_future_arc]]).

- **Mount/probe**: walk registered backends; on the `blk_active` backend with a GPT, the **Microsoft-Basic-Data** partitions; read sector 0, require `"EXFAT   "`@3; parse the § 1 geometry; walk the root dir for the `0x81` bitmap + `0x82` upcase locations. (`fatfs` already rejects exFAT, so the two coexist.)
- **Read**: dir-set walk (skip non-InUse; on `0x85` read SecondaryCount + its `0xC0`/`0xC1`s; reconstruct the UTF-16 name; match), then read `DataLength` bytes from `FirstCluster` — contiguous if `NoFatChain`, else FAT-chain.
- **Write**: bitmap allocator (find/set a free run of bits; prefer contiguous → `NoFatChain=1`) + dir-set create (`0x85`+`0xC0`+`0xC1`… with correct **SetChecksum** + **NameHash**) + data write + delete (clear InUse bits on the set + free the bitmap bits) + update `PercentInUse`/VolumeFlags as cheap correctness (or leave — `fsck.exfat` tolerates a stale PercentInUse; VolumeDirty is the analogue of ext2 `s_state`).

## 5. Bite plan

Each code bite = a QEMU smoke gate with **`mkfs.exfat`/`fsck.exfat`** (exfatprogs) as the host oracle; **NO iron burn until the final bite**.

1. **This audit** (doc).
2. **exFAT mount + read** — `exfat.cyr`: boot-region parse + MSFT-Basic probe + bitmap/upcase locate + dir-set walk + cluster read (NoFatChain + fragmented). Wire `exfat_init()` into `main.cyr` after `fatfs_init()`. Gate: a new `exfat-smoke.sh` mounts a `mkfs.exfat` image (multi-cluster file seeded via the loopback `mount -t exfat` or `exfatprogs`), `cat`s it back byte-exact (`EXFAT_SELFTEST`).
3. **exFAT write** — bitmap allocator + contiguous-cluster dir-set create (SetChecksum + NameHash) + content write + delete/truncate. Gate: `exfat-write-smoke.sh` (`EXFAT_WRITE_SELFTEST`) → `fsck.exfat` clean + host `mount`/`mtools`-equivalent read-back byte-exact. Final-bite optional iron burn user-driven (with the same partition-safety care as FAT).

## 6. Falsification rubric

- **PASS** = read bites return byte-exact data vs a host `mkfs.exfat`-seeded file; write bites leave the image **`fsck.exfat` clean** (no orphaned set, bad SetChecksum/NameHash, bitmap/length mismatch, or cross-linked cluster) + host read-back matches; no regression to ext2 / FAT / boot.
- **FALSIFIED / rethink** = `fsck.exfat` flags a structure (→ re-derive the offset/algorithm from § 1–3, not by trial); a multi-cluster read truncates (→ NoFatChain vs FAT-chain logic wrong); the NameHash/SetChecksum mismatch (→ the rotate-add or the byte-skip is wrong); or the MSFT-Basic probe regresses the FAT/ext2 mount.

## 7. Host-tooling note

The smoke needs **exfatprogs** (`mkfs.exfat`, `fsck.exfat`) — confirm present before bite 2 (the FAT arc used `dosfstools` + `mtools`; exFAT's analogue is exfatprogs; the Linux kernel `exfat` driver + `mount -t exfat` gives an alternate seed/verify path if mtools lacks exFAT).

## 8. References

- **Microsoft exFAT file system specification** (boot region, checksum algorithms, dir-entry types, SetChecksum/NameHash).
- **Linux `fs/exfat/`** (`super.c` boot parse, `balloc.c` bitmap, `dir.c`/`namei.c` dir-set + name, `fatent.c` chain, `nls.c` upcase).
- **exfatprogs** — `mkfs.exfat` (the seeder) + `fsck.exfat` (the write oracle).
- AGNOS internal: [`fat-family-prior-art.md`](fat-family-prior-art.md) § 4 (overview), `kernel/core/fatfs.cyr` (the mount + dir-write patterns to mirror), `kernel/core/block.cyr` (`blk_read_on`/`blk_write_on`), `kernel/core/gpt.cyr` (`GPT_TYPE_MSFT_BASIC_*`).
