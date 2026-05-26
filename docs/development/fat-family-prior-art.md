---
name: FAT-family filesystems (FAT write + exFAT) — multi-source prior art
description: Convergent FAT12/16/32 + exFAT on-disk layout, the honest diff against AGNOS's minimal FAT16-RO fatfs.cyr, and the read-parity → write → exFAT bite scope for the agnos 1.34.x arc
type: prior-art
---

# FAT-family filesystems — prior art (FAT write → exFAT)

> **Cycle**: agnos **1.34.x** — opens the additional-filesystems arc (roadmap row 21). Tracker: [`iron-nuc-zen-log.md#tracker-1340-cycle`](iron-nuc-zen-log.md#tracker-1340-cycle). This is **bite 1** (the audit). Multi-source per [[feedback_redesign_dont_reinvent]] — derive the on-disk shape from the specs + multiple OSes first, then diff against AGNOS. FS-choice (2026-05-26): FAT-family first; NTFS + squashfs deferred to roadmap row 23.

## 0. Why this arc, and what "done" means

FAT write is the **first *second* writable filesystem** on AGNOS (ext2/4 is the first). That is the architectural payoff: a second writable FS is the concrete trigger for the **1.39.x VFS generic-write lift** (`ext2_*`→`vfs_*`), per the abstract-on-demand discipline (`block.cyr`'s dispatch table earned itself only once a second backend existed). Until then FAT write rides its own `fatfs_*` surface, exactly as ext2 write rode `ext2_*`.

"Done" per bite = **`fsck.fat -n` clean** (FAT) / **`fsck.exfat`** (exFAT) on the post-mutation image + host **`mtools`** (`mdir`/`mtype`/`mcopy`) confirming the change persisted — the FAT-family analogue of the ext2 arc's `e2fsck -fn` + `debugfs` gate. No iron burn until the final bite per [[feedback_iron_burns_block_other_work]].

## 1. The honest diff — what `kernel/core/fatfs.cyr` actually is today

Derived by reading the 249-line file, not its comments. It is a **toy FAT16 reader**, further from "a FAT driver" than the header (`# FAT16 Filesystem (Read-Only)`) implies. Five gaps, each a scope item:

| # | Current state | Gap |
|---|---|---|
| 1 | **Wired only inside the VirtIO-blk branch** (`main.cyr:306-315`: `if pci_find(virtio-blk) { virtio_blk_init(); fatfs_init(); }`) | On real iron (NVMe / AHCI / USB-MS, no virtio-blk) `fatfs_init()` **never runs**. Must be lifted to a backend-agnostic probe like ext2's. |
| 2 | **Whole-disk, absolute LBA 0** (`blk_read(0, …)` for the boot sector; `blk_read(fatfs_root_start + s, …)` etc.) — uses `blk_active`, no partition base | Can't mount a FAT *partition* (the ESP, a GPT-partitioned USB stick). On a GPT disk it reads the protective MBR at LBA 0, sees `0x55AA` but `BytsPerSec`@11 = 0 → bails. Needs partition-aware mount (`partition_lba + sector` via `blk_read_on(backend, …)`) — ext2's exact pattern (`ext2_partition_first_lba`, `ext2_blk_read`). |
| 3 | **No FAT-chain traversal.** `fatfs_fat_buf[64]` is **declared but never used**; `fatfs_open`/`fatfs_read` read only the **first** cluster, and `fatfs_open` caps the memfile at **512 bytes** | Any file > 1 cluster (or > 512 B) reads truncated/wrong. Following the cluster chain through the FAT is the core missing read primitive — needed before *any* write. |
| 4 | **FAT16 layout only.** `FATSz16`@22 (16-bit) is the only FAT-size read; region math assumes the fixed root-directory region (`root_start = reserved + numFATs*FATSz; data_start = root_start + rootSectors`) | FAT32 sets `FATSz16=0` (real size in `FATSz32`@36) and `RootEntCnt=0` (root is a **cluster chain** at `RootClus`@44, no fixed region). FAT32 — the format of the ESP and most USB sticks — mis-parses entirely. |
| 5 | **8.3 only, no LFN; read-only.** LFN entries (`attr==0x0F`) are skipped; no cluster allocation / FAT write / dirent create | LFN read+write and the entire write path are absent. |

**Conclusion**: 1.34.x is *mature the driver* (gaps 1–4: partition-aware multi-backend mount + FAT-chain traversal + FAT32 + LFN read) **then write** (gap 5) **then exFAT**. Gaps 2–3 are the precondition for everything — a write path on a driver that can't follow a chain or mount a partition is meaningless.

## 2. FAT on-disk layout (convergent: MS FAT spec / EFI FAT32 SPG · FreeBSD `msdosfs` · Linux `fs/fat` · ECMA-107)

### 2.1 BPB / EBPB (boot sector, the fields AGNOS must read)

Common BPB (offsets, little-endian): `BytsPerSec`@11(2), `SecPerClus`@13(1), `RsvdSecCnt`@14(2), `NumFATs`@16(1), `RootEntCnt`@17(2), `TotSec16`@19(2), `Media`@21(1), `FATSz16`@22(2), `HiddSec`@28(4), `TotSec32`@32(4).
**FAT32 EBPB** (offset ≥ 36): `FATSz32`@36(4), `ExtFlags`@40(2) (active-FAT / mirroring), `FSVer`@42(2), `RootClus`@44(4), `FSInfo`@48(2), `BkBootSec`@50(2), `BS_FilSysType`@82(8). (FAT12/16 EBPB instead has `BS_FilSysType`@54.)

### 2.2 Region geometry + the only correct FAT-type test

```
FATSz       = (FATSz16 != 0) ? FATSz16 : FATSz32
TotSec      = (TotSec16 != 0) ? TotSec16 : TotSec32
RootDirSecs = ((RootEntCnt * 32) + (BytsPerSec - 1)) / BytsPerSec     # 0 on FAT32
FirstDataSec= RsvdSecCnt + (NumFATs * FATSz) + RootDirSecs
DataSec     = TotSec - FirstDataSec
CountOfClus = DataSec / SecPerClus
```
**FAT type is determined ONLY by `CountOfClus`** (MS spec is emphatic — not by any other field): `< 4085` → FAT12; `< 65525` → FAT16; else FAT32. AGNOS must compute this, not guess from `RootEntCnt`.

### 2.3 The FAT (allocation table) + cluster chains

One entry per cluster, indexed by cluster number (clusters start at 2; 0/1 are reserved). Entry width by type: **FAT12** = 12 bits packed (1.5 bytes — odd/even nibble juggling), **FAT16** = 2 bytes, **FAT32** = 4 bytes (only low **28** bits used; top 4 reserved — mask on read, preserve on write). A file's data is the chain `clus → FAT[clus] → …` until an **EOC** marker: `≥0xFF8` (12) / `≥0xFFF8` (16) / `≥0x0FFFFFF8` (32). **Free** = 0; **bad** = `0xFF7`/`0xFFF7`/`0x0FFFFFF7`. Byte offset of entry *N*: FAT16 `FATStart*secsz + N*2`; FAT32 `… + N*4`; FAT12 `… + N + (N/2)`. `NumFATs` copies (usually 2) — reads use FAT #0; **writes must update all copies** unless `ExtFlags` mirroring is disabled (FAT32 only).

### 2.4 Directory entries (32 bytes)

8.3 short entry: name`@0`(11, space-padded, `0xE5`=deleted, `0x00`=end-of-dir, `0x05`=real-0xE5 kanji escape), `Attr`@11 (`0x01`RO `0x02`HID `0x04`SYS `0x08`VOL `0x10`DIR `0x20`ARC; **`0x0F`=LFN**), `NTRes`@12, time/date@13-25, `FstClusHI`@20(2, FAT32), `FstClusLO`@26(2), `FileSize`@28(4). Directories chain like files (FAT32 root included); FAT12/16 root is the fixed region (gap 4).

**LFN** (`Attr==0x0F`, stored *before* its 8.3 entry, in reverse order): `Ord`@0 (`0x40` bit = last/highest), UTF-16 name across `@1-10`(5) + `@14-25`(6) + `@28-31`(2) = 13 chars/entry, `Chksum`@13 = checksum of the **8.3** name: `for c in 11 name bytes: sum = (((sum & 1) << 7) | (sum >> 1)) + c` (8-bit wrap). Write must generate a unique 8.3 alias (`NAME~1.EXT` tail-numbering) + the LFN chain + matching checksum.

### 2.5 FAT32 FSInfo (sector `FSInfo`@48)

`LeadSig`@0 = `0x41615252`, `StrucSig`@484 = `0x61417272`, `Free_Count`@488(4), `Nxt_Free`@492(4) (next-free hint), `TrailSig`@508 = `0xAA550000`. Both counts are **hints** — `0xFFFFFFFF` = unknown. Write should maintain them (and may recompute on mount); never trust blindly.

## 3. The write design (convergent: FreeBSD `msdosfs_fat.c`/`msdosfs_vnops.c` · Linux `fs/fat/fatent.c`,`dir.c` · MS spec)

Ordered like the ext2 arc (allocate→link→account), FAT has **no journal** (crash-safety = fsck, exactly like ext2; § 1 of the ext2 prior-art applies):

1. **Cluster allocator** — scan the FAT from `FSInfo.Nxt_Free` (or cluster 2) for a `0` entry. Mark it EOC, write the FAT entry (**all copies**), decrement `Free_Count`. To grow a chain: allocate, then point the previous tail at it. (FreeBSD `clusteralloc`/`fatentry`; Linux `fat_alloc_clusters`.)
2. **File write / append / truncate** — write data into the cluster(s); extend the chain as needed; on truncate, walk-and-free the tail (write `0` to freed FAT entries, bump `Free_Count`), set the new tail EOC. Update `FileSize` + `WrtTime`/`WrtDate` in the dirent.
3. **dirent create** — find a free slot (`0x00`/`0xE5`) in the parent dir (extend the dir chain if full — dirs grow by clusters), write the 8.3 entry + LFN chain (with checksum), set `FstClusHI/LO` + size. **delete** = set name`[0]=0xE5` on the 8.3 entry **and all its LFN entries**, then free the cluster chain.
4. **Ordering / failure modes accepted** — same contract as ext2: a crash mid-write may leak clusters or a stale `Free_Count` (fsck-fixable); **forbidden** = a live dirent pointing at a chain the FAT marks free, or two dirents sharing a chain. Allocate-and-link-FAT before publishing the dirent's `FstClus`; free the dirent (or its `FstClus`) before freeing the FAT entries.

**No device writeback subtlety beyond 1.33.5** — FAT writes go through the same `blk_write_on` + the new `blk_flush_on` durability barrier; a FAT `sync` should call `blk_flush_on(fat_backend)` just as `ext2_sync` does.

## 4. exFAT layout overview (convergent: MS exFAT spec · Linux `fs/exfat` · `exfatprogs`)

Structurally **its own filesystem**, not "FAT with bigger numbers":
- **Boot region** (12 sectors, Main + Backup): `"EXFAT   "`@3, `FatOffset`/`FatLength`/`ClusterHeapOffset`/`ClusterCount`/`FirstClusterOfRootDirectory`@field, `BytesPerSectorShift`/`SectorsPerClusterShift` (log2), plus a **VBR checksum** sector.
- **Allocation Bitmap** — 1 bit/cluster (not a FAT free-scan); located via a root-dir entry type `0x81`. The **FAT exists but is used only for *fragmented* chains** — contiguous files set the `NoFatChain` flag and the FAT is ignored for them.
- **Up-case Table** — for case-insensitive Unicode compare; root entry type `0x82`.
- **Directory** — 32-byte **typed** entries (first byte = type): `0x83` volume label, `0x81` bitmap, `0x82` upcase, **`0x85` File**, **`0xC0` Stream Extension**, **`0xC1` File Name**. A file = a **set**: one `0x85` (attrs, timestamps, `SecondaryCount`, **SetChecksum**) + one `0xC0` (name length, name hash, `FirstCluster`, `DataLength`, `NoFatChain`) + ⌈NameLen/15⌉ `0xC1` (UTF-16, 15 chars each). No 8.3, no LFN-chain-of-the-FAT-kind.
- Read-first (boot region + bitmap + upcase + dir set walk), then write (bitmap allocator + dir-set create with correct SetChecksum + name hash).

exFAT shares almost no code with FAT12/16/32 — treat it as a sibling module, not a mode flag. It lands **after** FAT write proves the partition-aware mount + cluster/dir machinery patterns.

## 5. AGNOS mapping + bite decomposition

Each code bite = a QEMU smoke gate (`fsck.fat`/`exfatprogs` + `mtools` oracle); **NO iron burn until the final bite**.

1. **This audit** (doc).
2. **FAT read parity + partition-aware multi-backend mount** (closes gaps 1–4). Lift `fatfs_init` out of the virtio-only branch into a backend-agnostic probe mirroring ext2 (`fat_backend` + `fat_partition_first_lba`, reads via `blk_read_on`); add FAT32 BPB (`FATSz32`/`RootClus`/`FSInfo`) + the `CountOfClus` type test; add **FAT-chain traversal** (`fatfs_fat_buf` finally used) so multi-cluster files read whole; LFN **read**. Gate: mount + `cat` a multi-cluster FAT32 file from a GPT partition in QEMU, byte-exact vs `mtype`.
3. **FAT write** — cluster allocator + all-copies FAT write → file write/append/truncate (+ `FileSize`/time, `FSInfo`) → dirent create/delete (8.3 + LFN gen + checksum) → shell verbs. Each bite `fsck.fat -n` clean + `mdir`/`mtype` persistence-verified.
4. **exFAT** — read (boot region + bitmap + upcase + typed dir-set walk) then write (bitmap allocator + dir-set create w/ SetChecksum). Final-bite iron burn user-driven.

(2 and the early part of 3 likely fill 1.34.x; exFAT may roll into 1.35.x — sequencing firms up as bites land, same as the storage arc.)

## 6. Falsification rubric

- **PASS** = each read bite returns byte-exact data vs `mtype`/`mdir`; each write bite leaves the image **`fsck.fat -n` clean** (no FAT-chain inconsistency, lost cluster, cross-link, or bad dirent) and `mtools` confirms the mutation persisted; no regression to ext2 or to the existing FAT16 read path; build within the `test.sh` size ceiling.
- **FALSIFIED / rethink** = `fsck.fat` flags a structure (→ re-derive the ordering or the FAT/dirent layout from § 2–3, not by trial); a multi-cluster read truncates (→ chain traversal wrong); FAT32 mis-mounts (→ BPB/type test wrong); the partition probe regresses ext2's mount.

## 7. References

- **Microsoft FAT Specification** (`fatgen103`) + **UEFI/EFI FAT32 SPG**; **ECMA-107**.
- **Microsoft exFAT file system specification**; Linux `fs/exfat/*`; `exfatprogs`.
- **FreeBSD** `sys/fs/msdosfs/` (`msdosfs_fat.c` cluster alloc/free + chain walk, `msdosfs_vnops.c`, `denode.h`, `bpb.h`); `newfs_msdos`.
- **Linux** `fs/fat/` (`fatent.c` FAT entry I/O, `dir.c` dirent + LFN, `inode.c` BPB/type, `namei_vfat.c` LFN+8.3 alias gen).
- **`dosfstools`** (`fsck.fat` = the write oracle, `mkfs.fat`) + **`mtools`** (`mdir`/`mtype`/`mcopy` = host persistence check).
- AGNOS internal: `kernel/core/fatfs.cyr` (current FAT16-RO), `kernel/core/ext2.cyr` (the partition-aware multi-backend mount + write-ordering pattern to mirror), `kernel/core/block.cyr` (`blk_read_on`/`blk_write_on`/`blk_flush_on`), `kernel/core/gpt.cyr` (partition discovery).
