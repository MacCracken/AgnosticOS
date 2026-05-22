---
name: ext2 + ext4 extents read-only — Prior-Art Audit + 1.31.5 Implementation Plan
description: Multi-source convergent audit + four-phase execution plan for the 1.31.5 storage-cycle bite (ext2 read-only driver + ext4 extents support for iron-validatable `ls` against the archaemenid root partition)
type: engineering-plan
---

# ext2 RO + ext4 Extents RO — 1.31.5 Implementation Plan

**Status:** Pre-implementation. 1.31.4 closed 2026-05-21 (RAM-disk + VirtIO 1.x modern, iron-validated as no-regression at Attempt 88). 1.31.5 opens with **ext2 read-only + ext4 extents** per `state.md` storage-target rankings — filesystem class, consumes GPT + block dispatch, lights up real `ls` / `cat` on iron against the archaemenid NVMe root partition. Per `feedback_redesign_dont_reinvent` (multi-source) + `feedback_known_knowledge_first` — this doc is the **convergent audit + fix plan** before code lands. Per `feedback_iron_burns_block_other_work` — phases land discretely with QEMU smoke between them; iron burn deferred until Phase 4 is QEMU-green.

**End-state user demo** (Phase 4 closeout, on archaemenid):
```
agnos> mount /dev/nvme0p2 /
agnos> ls /
bin/ boot/ etc/ home/ lib/ root/ tmp/ usr/ var/
agnos> cat /etc/hostname
archaemenid
```

That's the iron `ls` target. Phases 1-3 deliver a QEMU `ls` against an `mkfs.ext2` image; Phase 4 unlocks the ext4-extents path that real Linux root filesystems use.

---

## 1. Goals + scope

**1.31.5 cycle scope** (four phases, single cut at cycle close):

1. **Phase 1 — superblock + BGDT + inode-by-number + direct-block file read** (~300 LOC, new `kernel/core/ext2.cyr`). Validate magic `0xEF53`, decode blocksize via `1024 << s_log_block_size`, walk BGDT, look up inode by number (`(inode_num - 1) / s_inodes_per_group`), read a regular file's first 48 KB via `i_block[0..11]` direct blocks.
2. **Phase 2 — single/double/triple indirect blocks** (~150 LOC delta). Extend the file-data walker to `i_block[12]` single, `[13]` double, `[14]` triple. Lifts file-size cap from 48 KB to effectively 16 TB (with `i_size_high`).
3. **Phase 3 — directory walk + path resolution + `ls` + `cat` shell commands** (~300 LOC across `ext2.cyr` + shell). Linear dirent scan, path resolution from root inode `=2`, wire as VFS file ops. `ls` and `cat` shell commands light up.
4. **Phase 4 — ext4 extents header + leaf walker** (~250 LOC delta). Detect `EXT4_FEATURE_INCOMPAT_EXTENTS` in superblock; for inodes with `EXT4_EXTENTS_FL` (i_flags bit 0x80000), parse the 12-byte `ext4_extent_header` (magic `0xF30A`) embedded in `i_block[0..59]` and walk the extent tree (depth-first index entries → leaf entries → physical block #s). Iron-validate against archaemenid `/dev/nvme0p2`.

**Total: ~1,000 LOC across `ext2.cyr` (the bulk) + shell glue + small `vfs.cyr` extension.**

**Out of scope** (parked for later cycles):
- **Write paths** — file/block allocation, dirent insertion/removal, mkdir/unlink. ext2 doesn't have a journal (never did) — power-loss = fsck-required image. Roadmap-displaced to a later cycle.
- **64BIT feature** — `EXT4_FEATURE_INCOMPAT_64BIT` (bit `0x0080`). Changes BGDT entry size 32 → 64 bytes AND block# width 32 → 64. Significant rework; FreeBSD supports it for RO but the BGDT-size branching is non-trivial. Defer until iron filesystems require it (most consumer ext4 < 16 TB is 64BIT-clean, but the *feature bit is set anyway* on modern `mkfs.ext4` defaults — may force this earlier than expected; see § 6.1 risk).
- **HTREE indexed directories** — `EXT2_FEATURE_COMPAT_DIR_INDEX` (bit `0x0020`). HTREE is overlaid on a linear directory layout that still works for read; we use the linear scan. Performance loss on huge dirs (10k+ entries) — acceptable for an MVP read-only driver.
- **Journal replay (ext3/4)** — `EXT3_FEATURE_INCOMPAT_RECOVER` (bit `0x0004`). For RO mount we tolerate (read stale data; safer than refusing) per OpenBSD precedent. Replay is a write op.
- **Checksums** — `META_CSUM`, `GDT_CSUM`. RO driver doesn't verify; tolerate.
- **Inline data** — `EXT4_FEATURE_INCOMPAT_INLINE_DATA` (bit `0x8000`). File data stored in `i_block[]` / xattrs; our direct/extent walkers will return garbage. **Refuse** if encountered — most filesystems don't enable.
- **Encryption** — `EXT4_FEATURE_INCOMPAT_ENCRYPT` (bit `0x10000`). Returns ciphertext; `cat` would print garbage. **Refuse** rather than mislead.
- **BIGALLOC** — `EXT4_FEATURE_RO_COMPAT_BIGALLOC` (bit `0x0200`). Allocation in clusters, not blocks. Affects bitmap interpretation even for RO. **Refuse**.
- **xattr / ACL / Project quota** — orthogonal to file content; tolerate without supporting.
- **Symlinks** — fast-symlink (`i_size <= 60` → target in `i_block[]` as ASCII) is easy; slow-symlink (target in data blocks) requires Phase 1 path. Phase 3 should support fast at minimum.

---

## 2. What we have today

| File | LOC | Status | Disposition |
|---|---|---|---|
| `kernel/core/fatfs.cyr` | 222 | FAT16 read-only — superblock parse, root-dir walk, file open by name, cluster-chain read | **Reference shape** — ext2 mirrors the public-API style: `ext2_init`, `ext2_open(name, namelen)`, `ext2_read(inode, buf, maxlen)`, `ext2_ls`. No write paths. |
| `kernel/core/vfs.cyr` | 232 | Tag-based FD table (`VFS_DEVICE` / `VFS_MEMFILE` / `VFS_PIPE` / etc.); 32 slots × 32 bytes | **Extend** — add `VFS_EXT2_FILE = 7` tag with payload `{inode_num: u32, offset: u64, size: u64}`; `vfs_read` arm dispatches to `ext2_read_at(inode, offset, buf, count)`. |
| `kernel/core/block.cyr` | 133 | `blk_read(sector, buf)` dispatches to NVMe / AHCI / USB-MS / VirtIO / RAM-disk | **Consume directly** — ext2 only reads via `blk_read`. No new dispatch tag (ext2 is a filesystem, not a block backend). |
| `kernel/core/gpt.cyr` | 512 | Partition-table parser; `gpt_partition_info(idx)` returns `{type_guid, first_lba, last_lba, name}` | **Consume** — `ext2_mount(partition_idx)` calls `gpt_partition_info(idx)` to find the partition's LBA range, then reads superblock at byte offset 1024 from `first_lba`. |
| `kernel/core/main.cyr` | (relevant subset) | Boot-time init order: pmm → vmm → heap → ACPI → PCI → xhci → block backends → GPT → VFS → shell | **Extend** — after `vfs_init()`, call `ext2_try_mount_root()` which scans GPT for a Linux-FS partition (or first partition matching a default policy) and mounts it as `/`. |
| `kernel/user/shell.cyr` *(or wherever the shell verb table lives)* | — | `help` / `echo` / `parts` / etc. verbs | **Extend** — add `ls [path]` and `cat <path>` verbs that consume the ext2 API. |

**Existing precedent that defines integration shape (don't deviate):**
- **Public-API naming**: `ext2_init` / `ext2_open` / `ext2_read` / `ext2_ls` — mirrors `fatfs_*` exactly so future shell code can swap underlying FS transparently
- **Fixed-size global buffers**: `ext2_sb_buf[1024]`, `ext2_inode_buf[256]`, `ext2_block_buf[4096]`, `ext2_dirent_buf[4096]` — no `pmm_alloc` in the hot path
- **Sector-at-a-time reads via `blk_read`** — no caching, no readahead, no buffer pool
- **Build-flag plumbing**: `EXT2_VERBOSE=1` env var → prepended `#define` per the `KTEST` / `XHCI_VERBOSE` / `AHCI_RW_DEMO` pattern in `agnos/docs/development/build.md`

---

## 3. ext2 on-disk layout — convergent prior art

Sources read: Linux v6.6 `fs/ext2/ext2.h` + `inode.c` + `dir.c`, FreeBSD `sys/fs/ext2fs/ext2fs.h` + `ext2_dinode.h` + `ext2_lookup.c`, OpenBSD `sys/ufs/ext2fs/ext2fs.h` + `ext2fs_dinode.h`, Haiku `src/add-ons/kernel/file_systems/ext2/ext2.h`, ext4 wiki (https://archive.kernel.org/oldwiki/ext4.wiki.kernel.org/index.php/Ext4_Disk_Layout.html), nongnu ext2 spec (https://www.nongnu.org/ext2-doc/ext2.html).

**Convergent finding**: all four impls agree on the on-disk struct layouts; divergence is in *style* (Linux uses `__le16`/`__le32` typedefs; BSDs use host types with `le32toh()` accessors; Haiku uses accessor methods like `sb.Magic()`). AGNOS adopts the Haiku style — explicit reader functions that handle endian conversion at the boundary (`ext2_sb_magic(buf)`, `ext2_sb_log_block_size(buf)`).

### 3.1 Superblock (1024 bytes, on-disk @ byte offset 1024 of partition)

Only the fields Phase 1-4 actually need:

| Off | Size | Name | Use |
|-----|------|------|-----|
| 4   | 4 | `s_blocks_count`       | total block count (low 32; high 32 only with 64BIT, refused) |
| 20  | 4 | `s_first_data_block`   | **0 if blocksize > 1024, 1 if blocksize == 1024.** Never hard-code; always consult. (BGDT lives at block N+1.) |
| 24  | 4 | `s_log_block_size`     | blocksize = `1024 << s_log_block_size` (so values 0/1/2/3 → 1K/2K/4K/8K) |
| 32  | 4 | `s_blocks_per_group`   | for inode-num → block-group division |
| 40  | 4 | `s_inodes_per_group`   | same |
| 56  | 2 | `s_magic`              | **MUST be `0xEF53`** — first sanity gate |
| 76  | 4 | `s_rev_level`          | 0 = GOOD_OLD (128-byte inode, no DYNAMIC_REV fields); 1 = DYNAMIC |
| 88  | 2 | `s_inode_size`         | DYNAMIC_REV only; **128 for ext2, 256 for modern ext4** |
| 92  | 4 | `s_feature_compat`     | safe to ignore unknown bits |
| 96  | 4 | `s_feature_incompat`   | **refuse mount on unknown bits in our REQUIRED-UNKNOWN mask** |
| 100 | 4 | `s_feature_ro_compat`  | tolerate (we're RO) |

**Read mechanics**: `blk_read(partition_first_lba + 2, sb_buf)` + `blk_read(partition_first_lba + 3, sb_buf + 512)` — two 512-byte sector reads cover bytes 1024-2047. Validate magic before touching anything else.

### 3.2 Block Group Descriptor (32 bytes legacy; 64 bytes with 64BIT — refused)

Only field Phase 1-4 needs:

| Off | Size | Name | Use |
|-----|------|------|-----|
| 8   | 4 | `bg_inode_table` | block# of first block of this group's inode table |

**BGDT location**: block `s_first_data_block + 1`. So 4K-block FS → BGDT @ block 1 → byte offset 4096. 1K-block FS → BGDT @ block 2 → byte offset 2048. Compute via `s_first_data_block`, never assume.

### 3.3 Inode (128 bytes legacy; 256 bytes typical ext4 — read first 128 only for Phase 1-3)

Fields Phase 1-4 need:

| Off | Size | Name | Use |
|-----|------|------|-----|
| 0   | 2 | `i_mode`      | file type via `i_mode & 0xF000` (REG=0x8000, DIR=0x4000, LNK=0xA000) |
| 4   | 4 | `i_size`      | low 32 of file size |
| 28  | 4 | `i_blocks`    | 512-byte sectors used. **TOLERATE-IGNORE** in Phase 1-3 (we use `i_size` directly) |
| 32  | 4 | `i_flags`     | **bit 0x80000 = `EXT4_EXTENTS_FL`** (Phase 4 gate) |
| 40  | 60 | `i_block[15]` | **Phase 1-2: 12 direct + 1 single-ind + 1 double + 1 triple. Phase 4: ext4 extent root header + entries** |
| 108 | 4 | `i_size_high` | high 32 of file size for regular files when `LARGE_FILE` ro_compat set (Phase 1 SHOULD honor; cheap) |

**Inode-number → block math** (universally convergent — Linux/FreeBSD/OpenBSD/Haiku all identical):

```
inode_num -= 1                                      # inodes are 1-indexed!
block_group        = inode_num / s_inodes_per_group
index_in_group     = inode_num % s_inodes_per_group
inode_table_block  = bgdt[block_group].bg_inode_table
byte_offset        = index_in_group * s_inode_size
target_block       = inode_table_block + byte_offset / blocksize
offset_in_block    = byte_offset % blocksize
```

**Reserved inode numbers**: 1 = bad blocks list, 2 = root dir, 3 = ACL idx (obsolete), 4 = ACL data (obsolete), 5 = boot loader, 6 = undelete dir, 7 = reserved group descriptors, 8 = journal, 11 = lost+found (typical). **Root dir is always inode 2** — every path lookup starts there.

### 3.4 Directory entry v2 (variable length, 4-byte aligned)

| Off | Size | Name | Use |
|-----|------|------|-----|
| 0 | 4 | `inode`     | inode # (0 = unused/tombstone — skip but advance) |
| 4 | 2 | `rec_len`   | total entry length incl. header, **always multiple of 4, min 12** |
| 6 | 1 | `name_len`  | actual name length (0-255) |
| 7 | 1 | `file_type` | 0=UNK 1=REG 2=DIR 3=CHR 4=BLK 5=FIFO 6=SOCK 7=LNK — **only valid if `EXT2_FEATURE_INCOMPAT_FILETYPE` (0x0002) set, else byte is name_len high byte** |
| 8 | name_len | `name` | not NUL-terminated |

**Walk algorithm** (convergent BSD-style, validate per-entry inline — see § 4):

```
offset = 0
while offset < dir_inode.i_size:
    block_offset = offset % blocksize
    if block_offset == 0:
        load next block via inode → block walker
    e = (ext2_dirent*) (block_buf + block_offset)
    validate(e):
        if e.rec_len < 12:                                          ABORT "short rec_len"
        if e.rec_len & 3:                                           ABORT "unaligned rec_len"
        if e.rec_len < 8 + e.name_len:                              ABORT "rec_len too small for name_len"
        if (block_offset + e.rec_len) > blocksize:                  ABORT "entry spans block boundary"
        if e.inode > s_inodes_count:                                ABORT "inode out of bounds"
        if e.rec_len == 0:                                          ABORT "zero-length rec_len" (CRITICAL — else infinite loop)
    if e.inode != 0:
        yield (e.inode, e.name[0..name_len], e.file_type)
    offset += e.rec_len
```

**Directory size invariant**: `dir.i_size` is always a multiple of blocksize for valid dirs. The last entry's `rec_len` is inflated to consume the rest of the final block; no explicit terminator. The `block_offset + rec_len > blocksize` check catches overflow; the `rec_len == 0` check is the **single most important defense against malformed dirents** — without it, a corrupt FS infinite-loops the kernel.

### 3.5 The `s_first_data_block` gotcha

The one field everyone forgets. It is:
- **0** for blocksize >= 2048 (superblock at byte 1024 sits inside block 0)
- **1** for blocksize == 1024 (superblock IS block 1)

BGDT location depends on it: BGDT @ block `s_first_data_block + 1`. Inode-table location depends on it indirectly through BGDT. If we hard-code "BGDT at block 1" we'll read garbage on a 1024-byte-block filesystem.

---

## 4. ext2 indirect-block tree

Sources read: Linux `fs/ext2/inode.c` `ext2_block_to_path()`, FreeBSD `sys/ufs/ufs/ufs_bmap.c` `ufs_getlbns()` (shared with UFS — ext2's indirection scheme was borrowed from UFS), OpenBSD same path.

### 4.1 i_block layout

```
i_block[0..11]   12 direct block pointers
i_block[12]      single-indirect → block holding ptrs pointers
i_block[13]      double-indirect → block of ptrs ptrs to blocks of ptrs ptrs
i_block[14]      triple-indirect → 3 levels deep
```

Let `ptrs = blocksize / 4`. For a 4 KB blocksize, `ptrs = 1024`, `ptrs_bits = 10`.

### 4.2 Logical → physical mapping (Linux algorithm)

```
direct_blocks   = 12
indirect_blocks = ptrs                    // 1024 for 4K blocks
double_blocks   = ptrs * ptrs             // 1,048,576 for 4K blocks
                                          // (triple = ptrs^3)

if i_block < 12:
    offsets[0] = i_block                  // direct hit
    depth = 1
elif (i_block -= 12) < ptrs:
    offsets[0] = 12                       // EXT2_IND_BLOCK
    offsets[1] = i_block
    depth = 2
elif (i_block -= ptrs) < ptrs*ptrs:
    offsets[0] = 13                       // EXT2_DIND_BLOCK
    offsets[1] = i_block >> ptrs_bits
    offsets[2] = i_block & (ptrs - 1)
    depth = 3
elif (i_block -= ptrs*ptrs) < ptrs*ptrs*ptrs:
    offsets[0] = 14                       // EXT2_TIND_BLOCK
    offsets[1] = i_block >> (ptrs_bits*2)
    offsets[2] = (i_block >> ptrs_bits) & (ptrs - 1)
    offsets[3] = i_block & (ptrs - 1)
    depth = 4
else:
    ERROR "block too big"
```

Walk: load `i_block[offsets[0]]`; if `depth > 1`, load that block, index by `offsets[1]`; repeat to depth.

### 4.3 File-size limits (4K blocks)

- direct only: 48 KB
- + single-indirect: 4.05 MB
- + double-indirect: ~4 GB
- + triple-indirect: ~4 TB (theoretical; capped by 64-bit `i_size` to ~16 TB)

### 4.4 AGNOS Phase 2 implementation

No radix tree needed — algorithm is plain arithmetic. Required scratch: **three 4 KB pages** (single + double + triple levels) allocated once at mount, reused per read. No buffer cache; we re-read each walk because RO traffic is light and the dispatch layer handles caching at the block backend (NVMe doesn't have one but we're not optimizing for that path).

---

## 5. ext4 extents layer

Sources read: Linux `fs/ext4/ext4_extents.h` + `extents.c` `ext4_ext_find_extent()`, FreeBSD `sys/fs/ext2fs/ext2_extents.h` + `ext2_extents.c` (clean BSD port of the same algorithm — Zheng Liu, 2012), OpenBSD `sys/ufs/ext2fs/ext2fs_bmap.c` `ext4_bmapext`.

**Convergent shape**: Linux + FreeBSD agree on algorithm. OpenBSD inlines but matches. AGNOS adopts the **FreeBSD shape** — Linux's `extents.c` is tangled with delayed-allocation + holes write paths; FreeBSD's is the cleanest standalone RO reference.

### 5.1 Structures (all 12 bytes, packed)

**`ext4_extent_header`** at start of `i_block[]` (when `EXT4_EXTENTS_FL` set in `i_flags`) AND start of every internal-node block:

| Off | Size | Name | Use |
|-----|------|------|-----|
| 0 | 2 | `eh_magic`      | **MUST be `0xF30A`** |
| 2 | 2 | `eh_entries`    | valid entries following |
| 4 | 2 | `eh_max`        | capacity (validation: `eh_entries <= eh_max`) |
| 6 | 2 | `eh_depth`      | **0 = this block contains leaf entries; >0 = index entries pointing deeper** |
| 8 | 4 | `eh_generation` | tree mod counter — ignore for RO |

**`ext4_extent`** (leaf entry, depth==0):

| Off | Size | Name | Use |
|-----|------|------|-----|
| 0 | 4 | `ee_block`    | first logical block# covered by this extent |
| 4 | 2 | `ee_len`      | block count; **`> 32768` = unwritten extent (subtract 32768 for actual len); `<= 32768` = initialized** |
| 6 | 2 | `ee_start_hi` | high 16 of physical block# |
| 8 | 4 | `ee_start_lo` | low 32 of physical block# |

**`ext4_extent_idx`** (internal entry, depth>0):

| Off | Size | Name | Use |
|-----|------|------|-----|
| 0 | 4 | `ei_block`    | logical block covered "from here onward" |
| 4 | 4 | `ei_leaf_lo`  | low 32 of next-level block# |
| 8 | 2 | `ei_leaf_hi`  | high 16 of next-level block# |
| 10| 2 | `ei_unused`   | must ignore |

### 5.2 Inode-embedded root

When `inode.i_flags & EXT4_EXTENTS_FL` (bit 19 = `0x00080000`) is set:
- Bytes 0-11 of `inode.i_block[]` = `ext4_extent_header`
- Bytes 12-59 of `inode.i_block[]` = **4 × ext4_extent OR 4 × ext4_extent_idx** (12 bytes each, depending on `eh_depth`)

Root is special: `eh_max` is typically 4 (constrained by the 48 available bytes). Deeper blocks use the full blocksize.

### 5.3 Lookup algorithm (FreeBSD shape)

```
header = (ext4_extent_header*) &inode.i_block[0]
validate: header.eh_magic == 0xF30A
depth = header.eh_depth

while depth > 0:
    binary_search index entries by target_logical_block:
        find LARGEST ei_block <= target
    next_phys_block = (ei_leaf_hi << 32) | ei_leaf_lo
    blk_read(next_phys_block * blocksize / 512 .. , buf)
    header = (ext4_extent_header*) buf
    validate: header.eh_magic == 0xF30A
    validate: header.eh_depth == depth - 1
    depth = depth - 1

binary_search leaf entries:
    find ee_block <= target_logical_block < ee_block + actual_len
    if not found → sparse hole, return zeros for this block
    if ee_len > 32768:
        actual_len = ee_len - 32768
        # UNWRITTEN extent — physical blocks allocated, content undefined
        # RETURN ZEROS, do NOT blk_read (Linux's behavior; correctness-critical)
    else:
        actual_len = ee_len
    phys_start = (ee_start_hi << 32) | ee_start_lo
    target_phys = phys_start + (target_logical_block - ee_block)
    blk_read(target_phys * blocksize / 512 .. , buf)
```

`EXT4_MAX_EXTENT_DEPTH = 5` (Linux), so path arrays are bounded — 5 × pre-allocated pmm pages max.

### 5.4 The 48-bit shift trap

Linux's accessor:

```c
block |= ((ext4_fsblk_t) le16_to_cpu(ex->ee_start_hi) << 31) << 1;
```

The `<< 31 << 1` rather than `<< 32` defends against `ext4_fsblk_t` being conditionally `u32` (`x << 32` is undefined behavior in C when shift >= type width). **Trapped multiple BSD porters historically.**

**For AGNOS**: Cyrius `u64` is unambiguous, so `(u64)hi << 32 | lo` is safe. **But comment the source** because if Cyrius ever targets a 32-bit platform (RISC-V rv32, future ARMv7-M), the Linux idiom is the portable one. Silent failure mode of the wrong shift: extents past block# 2^32 read with low-32 only → corruption with no error indication.

### 5.5 Unwritten-extent semantics

`ee_len > 32768` means "physical blocks ARE allocated but content is undefined." A naive RO driver issuing `blk_read` for these returns disk garbage (whatever was on the drive before allocation).

**Correct behavior**: zero-fill the buffer; do NOT `blk_read`. Linux does this; FreeBSD does this; OpenBSD does this. AGNOS must too.

The math:
```
if (ee_len <= 0x8000):
    actual_len = ee_len               # initialized
    READ from phys_start..
else:
    actual_len = ee_len - 0x8000      # unwritten
    ZERO-FILL buf, return success
```

---

## 6. Feature flag triage — refuse-or-tolerate verdict

AGNOS is RO. `s_feature_ro_compat` flags are mostly TOLERATE (read-only is OK with these); `s_feature_incompat` flags need per-bit triage.

### 6.1 s_feature_incompat (mount-blocking)

| Bit | Name | Verdict | Reason |
|-----|------|---------|--------|
| 0x0001 | COMPRESSION   | **REFUSE** | Proprietary; data unreadable |
| 0x0002 | FILETYPE      | **TOLERATE** | Alters dirent byte 7 interpretation; AGNOS must check this bit when parsing |
| 0x0004 | RECOVER       | **TOLERATE** | Journal needs replay (ext3+); safe to read stale data RO |
| 0x0008 | JOURNAL_DEV   | **REFUSE** | Journal device, not filesystem |
| 0x0010 | META_BG       | **REFUSE-IN-PHASE-1-3, TOLERATE-LATER** | Alters BGDT placement; complicates inode-table math. Defer support. |
| 0x0040 | EXTENTS       | **REFUSE-IN-PHASE-1-3, TOLERATE-IN-PHASE-4** | Only safe once Phase 4 walker lands |
| 0x0080 | 64BIT         | **REFUSE** | BGDT becomes 64 bytes; block# widens to 64. Most consumer `mkfs.ext4` defaults set this even when unnecessary (filesystem < 16 TB doesn't need it). **RISK**: archaemenid's root partition may have this set despite being well under the 64BIT-required threshold. If iron mount fails on this flag at Phase 4, the unlock is a Phase 5 cycle (~200 LOC). Detect at Phase 1; surface as a clear refusal message; defer fix. |
| 0x0100 | MMP           | **TOLERATE** | Multi-mount protection — RO doesn't conflict |
| 0x0200 | FLEX_BG       | **TOLERATE** | Allocator placement only; doesn't change inode-num → group math |
| 0x0400 | EA_INODE      | **TOLERATE** | Xattr storage only |
| 0x1000 | DIRDATA       | **REFUSE** | Alters dirent layout (extra data after name); we don't parse correctly |
| 0x2000 | CSUM_SEED     | **TOLERATE** | We don't verify checksums |
| 0x4000 | LARGEDIR      | **TOLERATE** | Larger dir size limits; doesn't change parse format |
| 0x8000 | INLINE_DATA   | **REFUSE** | File data in `i_block[]` / xattrs; our walkers return garbage |
| 0x10000 | ENCRYPT      | **REFUSE** | Ciphertext; `cat` prints garbage. Refuse rather than mislead. |

**Supported-incompat mask (Phase 1-3)**: `FILETYPE | RECOVER | MMP | FLEX_BG | EA_INODE | CSUM_SEED | LARGEDIR` = `0x6502`
**Supported-incompat mask (Phase 4)**: `+ EXTENTS` = `0x6542`
**Required-supported check**: `(s_feature_incompat & ~SUPPORTED_MASK) == 0` → mount, else refuse with line `ext2: unsupported incompat bits: 0x<hex>`.

### 6.2 s_feature_ro_compat (RO-tolerable)

Per OpenBSD's `EXT4F_RO_INCOMPAT_SUPP` precedent — the cleanest RO-only profile. Tolerate all of: `SPARSE_SUPER | LARGE_FILE | BTREE_DIR | HUGE_FILE | GDT_CSUM | DIR_NLINK | EXTRA_ISIZE | QUOTA | METADATA_CSUM | READONLY | PROJECT`.

**Refuse**: `BIGALLOC` (bit `0x0200`) — allocation in clusters not blocks; alters bitmap interpretation even for RO. Rare in the wild.

### 6.3 Comparative landing

| OS | Read-only ext2/ext4 supported incompat |
|---|---|
| Linux ext2 driver | FILETYPE + META_BG (conservative — Linux has *separate* ext4 driver for everything else) |
| FreeBSD ext2fs | FILETYPE + META_BG + EXTENTS + 64BIT + FLEX_BG + CSUM_SEED |
| OpenBSD ext2fs | EXTENTS + FLEX_BG + META_BG + RECOVER |

AGNOS Phase 1-3 is between Linux-ext2-conservative and OpenBSD; Phase 4 reaches the OpenBSD level minus META_BG. Long-term parity with FreeBSD requires 64BIT support — punt to post-1.31.x.

---

## 7. Phased port plan

Each phase ends with a QEMU smoke gate + a build-size check; Phase 4 ends with an iron burn against archaemenid.

### Phase 1 — superblock + BGDT + inode-by-number + direct-block file read (~300 LOC)

**Files touched:** new `kernel/core/ext2.cyr`; ~10-line addition to `kernel/core/main.cyr`.

**Public surface added:**
```
ext2_init(partition_idx) -> 0 | -1                # mount the FS from a GPT partition
ext2_get_inode(inode_num, out_inode_buf) -> 0 | -1
ext2_read_file(inode_num, buf, maxlen) -> bytes_read | -1
                                                  # Phase 1: direct blocks only;
                                                  # caps at 48 KB on 4K-block FS
```

**Internal helpers:**
- `ext2_sb_magic(buf)`, `ext2_sb_blocksize(buf)`, `ext2_sb_blocks_per_group(buf)`, etc. (endian-aware readers)
- `ext2_bgdt_inode_table(group_num)` — reads BGDT entry to find inode table
- `ext2_block_to_sector(block_num)` — converts FS block# to LBA via `partition_first_lba + block_num * (blocksize / 512)`
- `ext2_feature_check(sb_buf)` — gates supported-incompat mask

**Init flow (`ext2_init`):**
1. `gpt_partition_info(idx)` → `{first_lba, last_lba}`
2. `blk_read(first_lba + 2, sb_buf); blk_read(first_lba + 3, sb_buf + 512)` — superblock @ byte 1024
3. Validate `s_magic == 0xEF53`
4. `ext2_feature_check(sb_buf)` — refuse on unsupported incompat
5. Cache `blocksize`, `inodes_per_group`, `inode_size`, `s_first_data_block`, `first_lba` in globals
6. Print `ext2: mounted partition %d (blocksize=%d, inodes_per_group=%d)`; return 0

**QEMU validation (one-shot smoke):**
```sh
# Build a 64 MB ext2 image with one known file
dd if=/dev/zero of=ext2-test.img bs=1M count=64
parted -s ext2-test.img mklabel gpt mkpart linux-test ext2 1MiB 100%
LOOP=$(sudo losetup --show -f -P ext2-test.img)
sudo mkfs.ext2 -L AGNOS-TEST -m 0 -O ^extents,^huge_file,^64bit,^metadata_csum ${LOOP}p1
sudo mount ${LOOP}p1 /mnt/test
sudo sh -c 'echo "Hello from ext2 Phase 1" > /mnt/test/hello.txt'
sudo umount /mnt/test
sudo losetup -d $LOOP

# Boot AGNOS with this image attached as the NVMe disk
qemu-system-x86_64 -drive file=ext2-test.img,if=none,id=blk0 -device nvme,drive=blk0,serial=test ...
```

**Acceptance criteria:** boot log shows `ext2: mounted partition 0 (blocksize=4096, inodes_per_group=8192)`. Shell command `cat /hello.txt` (added in Phase 3) returns `Hello from ext2 Phase 1`. Phase 1 acceptance is the BACKEND only — `ext2_read_file(inode_num=12, ...)` (hello.txt's typical inode) returns the right bytes when called from a debug hook in `main.cyr`.

**Build trajectory target:** `build/agnos` 520,920 B → ~528,000 B (+~7 KB).

### Phase 2 — single/double/triple indirect blocks (~150 LOC delta)

**Files touched:** `kernel/core/ext2.cyr`.

**Surface change:** none external. `ext2_read_file` now handles files > 48 KB.

**New internal helper:** `ext2_logical_to_physical(inode_buf, logical_block)` — implements the `offsets[4]` walk per § 4.2. Allocates three scratch pmm pages at module init (`ext2_indirect_buf[0..2]`); reuses per call.

**QEMU validation:**
```sh
# Extend the test image to include a large file forcing single-indirect
sudo dd if=/dev/urandom of=/mnt/test/big.bin bs=4K count=100   # ~400 KB
sha256sum /mnt/test/big.bin > /tmp/big.bin.sha
```

**Acceptance criteria:** `cat /big.bin | sha256sum` in agnos shell matches `/tmp/big.bin.sha` from host side. Validates single-indirect path. Optional: triple-test with a 16 MB file (forces double-indirect on 4K blocks).

**Build trajectory target:** `+~3 KB`.

### Phase 3 — directory walk + path resolution + `ls` + `cat` shell commands (~300 LOC)

**Files touched:** `kernel/core/ext2.cyr` (+dir walk, +path resolution), `kernel/core/vfs.cyr` (+`VFS_EXT2_FILE` tag), shell verb table (`+ls`, `+cat`).

**Public surface added:**
```
ext2_readdir(dir_inode_num, callback) -> count
                                                  # callback(inode_num, file_type, name, name_len)
ext2_path_lookup(path) -> inode_num | -1
                                                  # walks "/foo/bar/baz" from root inode (=2)
ext2_open(path) -> fd_idx | -1                    # VFS-integrated; allocates VFS slot
                                                  # returns FD usable with vfs_read / vfs_close
```

**VFS extension:** new `VFS_EXT2_FILE = 7` tag. Slot layout:
```
+0   tag = VFS_EXT2_FILE
+4   inode_num (u32)
+8   offset (u64)
+16  size (u64)
```

`vfs_read` arm for `VFS_EXT2_FILE`:
```
read ext2_inode at slot.inode_num
n = ext2_read_at(inode_buf, slot.offset, buf, count)
slot.offset += n
return n
```

**Shell verbs:**
- `ls [path]` — defaults to `/`. Calls `ext2_readdir(ext2_path_lookup(path))`; prints `name<TAB>name<TAB>...` with `/` suffix for dirs.
- `cat <path>` — `vfs_open(path)`, loops `vfs_read` into 256-byte chunks, `vfs_write` to stdout (fd 1), until EOF.

**QEMU validation:**
```sh
# Extend the test image with directory structure
sudo mkdir -p /mnt/test/etc /mnt/test/bin
sudo sh -c 'echo "qemu-test" > /mnt/test/etc/hostname'
```

```
agnos> ls /
hello.txt    big.bin    etc/    bin/
agnos> ls /etc
hostname
agnos> cat /etc/hostname
qemu-test
agnos> cat /hello.txt
Hello from ext2 Phase 1
```

**Acceptance criteria:** all four shell interactions above pass. Boot output shows `ext2: root inode 2 ready; / contains 4 entries`. **`ls` is alive.**

**Build trajectory target:** `+~5-7 KB`.

### Phase 4 — ext4 extents header + leaf walker (~250 LOC delta)

**Files touched:** `kernel/core/ext2.cyr` (extent walker), `kernel/core/main.cyr` (mount-time detection branch).

**Behavior change:** if `s_feature_incompat & EXT4_FEATURE_INCOMPAT_EXTENTS` set, supported-incompat mask flips to `0x6542`. For each inode loaded, if `i_flags & EXT4_EXTENTS_FL`, the file-data walker uses extent dispatch (`ext2_extent_logical_to_physical(inode_buf, logical_block)`) instead of the indirect-block walker.

**Internal helpers:**
- `ext2_extent_header_validate(buf)` — checks magic `0xF30A`, `eh_entries <= eh_max`
- `ext2_extent_walk(inode_buf, logical_block)` → physical block# (or 0 for sparse/unwritten zero-fill)
- `ext2_extent_idx_search(header, entries, target)` — linear (small N, max 4 at root) or binary (deeper blocks) search

**Path-array bound:** 5 levels deep max. Allocate 5 scratch pmm pages at init.

**Unwritten-extent handling:** when `ee_len > 32768`, zero-fill caller's buffer; do NOT `blk_read`. Critical for correctness against real-world filesystems.

**QEMU validation:**
```sh
# Build an ext4 image (not ext2!) with extents enabled
sudo mkfs.ext4 -L AGNOS-EXT4 -m 0 -O extents,^huge_file,^64bit,^metadata_csum ${LOOP}p1
# Same files as Phase 3 test
sudo mkdir -p /mnt/test/etc
sudo sh -c 'echo "qemu-ext4" > /mnt/test/etc/hostname'
```

QEMU end-state same as Phase 3 (`ls /` / `cat /etc/hostname`), but boot log now shows `ext2: mounted partition 0 (extents=yes, blocksize=4096)`.

**Iron validation (against archaemenid root partition):**

GPT Phase 3 already detects archaemenid's NVMe partition table; `parts` shell command shows `[1] (unknown type) LBA 2099200-3907026943 (1906703 MiB)` — the Linux root partition. After Phase 4 lands:

```
agnos> mount /dev/nvme0p2 /        # or auto-mount on first Linux-FS partition
agnos> ls /
bin/ boot/ etc/ home/ lib/ root/ tmp/ usr/ var/ ...
agnos> cat /etc/hostname
archaemenid
```

**Acceptance criteria for iron**: real root directory entries enumerated; at least one text file from the root partition readable byte-exact through `cat`. **Iron burn is Attempt 89 (or wherever the iron sequence sits when Phase 4 lands).**

**Build trajectory target:** `+~5 KB`. Final 1.31.5 cut estimate: **~540-545 KB** (from 520,920 B baseline).

---

## 8. Open questions / parked items

1. **archaemenid root partition 64BIT detection** — if `mkfs.ext4` on the user's Linux distro set `EXT4_FEATURE_INCOMPAT_64BIT` despite the partition being well under 16 TB, Phase 4 iron mount will refuse. **Mitigation**: ship Phase 4 with a clear `ext2: refuses 64BIT incompat (Phase 5 unlock)` log line so failure mode is unambiguous; queue 64BIT support as a 1.31.6 follow-up if it bites. Pre-check: user can `tune2fs -l /dev/nvme0p2 | grep 'Filesystem features'` on the Linux side to see if 64bit is in the list — if yes, scope Phase 4 expectations accordingly.

2. **Mount syntax** — `mount /dev/nvme0p2 /` is the textbook UNIX shape but requires a `/dev` device-file abstraction we don't have. **Default approach for 1.31.5**: auto-mount the first Linux-FS-GUID partition found at GPT parse time; `mount` shell verb deferred to a later cycle when device-file work happens. (User-facing impact: minimal — root just exists.)

3. **`ls` flags** — `ls -l` (long format with size/mtime/perms) is significantly more LOC than the basic verb. **Phase 3 ships `ls` with no flags**; columnar output, `/` suffix for dirs. `-l` queued for a later cycle.

4. **Symlinks** — fast-symlinks (target stored inline in `i_block[]` when `i_size <= 60`) are easy and should land in Phase 3. Slow-symlinks (target in data blocks) require the file-read path but no extra structure. **Phase 3 ships fast-symlinks at minimum**; slow-symlinks if not too disruptive, else queue.

5. **VFS path resolution** — `ext2_path_lookup` currently does it all internally. Should this be lifted to a generic `vfs_resolve(path)` so future filesystems (fat32, exFAT) can share? **Decision**: keep it ext2-internal for 1.31.5; lift when the second FS arrives (matches the `block.cyr` dispatch pattern — abstract on demand, not preemptively).

6. **Test image fixtures** — should the `ext2-test.img` build script live in `agnos/scripts/` or `agnos/tests/` so QEMU smoke runs reproducibly? **Decision**: add `scripts/build-ext2-test-image.sh` so it's discoverable; tests/ stays for Cyrius-language tests, not data fixtures.

---

## 9. Sources

**Linux v6.6:**
- `https://github.com/torvalds/linux/blob/v6.6/fs/ext2/ext2.h` — struct defs, feature bits
- `https://github.com/torvalds/linux/blob/v6.6/fs/ext2/inode.c` — `ext2_block_to_path()` indirect-tree math
- `https://github.com/torvalds/linux/blob/v6.6/fs/ext2/dir.c` — `ext2_check_page()` dirent validation predicates
- `https://github.com/torvalds/linux/blob/v6.6/fs/ext4/ext4_extents.h` — extent structs
- `https://github.com/torvalds/linux/blob/v6.6/fs/ext4/extents.c` — `ext4_ext_find_extent()` tree walk

**FreeBSD main:**
- `https://github.com/freebsd/freebsd-src/blob/main/sys/fs/ext2fs/ext2fs.h` — feature masks, conservative incompat support set
- `https://github.com/freebsd/freebsd-src/blob/main/sys/fs/ext2fs/ext2_dinode.h` — best annotated inode field offsets
- `https://github.com/freebsd/freebsd-src/blob/main/sys/fs/ext2fs/ext2_lookup.c` — single-pass dirent walk (BSD style AGNOS adopts)
- `https://github.com/freebsd/freebsd-src/blob/main/sys/fs/ext2fs/ext2_extents.c` — cleanest standalone RO extent walker

**OpenBSD master:**
- `https://github.com/openbsd/src/blob/master/sys/ufs/ext2fs/ext2fs.h`
- `https://github.com/openbsd/src/blob/master/sys/ufs/ext2fs/ext2fs_lookup.c`
- `https://github.com/openbsd/src/blob/master/sys/ufs/ext2fs/ext2fs_bmap.c` — `ext4_bmapext` extent walker

**Haiku master:**
- `https://github.com/haiku/haiku/blob/master/src/add-ons/kernel/file_systems/ext2/ext2.h` — accessor-method style AGNOS adopts

**Specs / docs:**
- `https://archive.kernel.org/oldwiki/ext4.wiki.kernel.org/index.php/Ext4_Disk_Layout.html` — primary spec reference
- `https://www.nongnu.org/ext2-doc/ext2.html` — Dave Poirier's ext2 spec (pre-extent era)

**Historical port gotchas:**
- `https://lists.openwall.net/linux-ext4/2008/12/30/1` — rec_len validation history
- `https://patchwork.ozlabs.org/project/linux-ext4/patch/20230801112337.1856215-1-zhangshida@kylinos.cn/` — recent rec_len verify fix
- `ext4_ext_pblock` `<< 31 << 1` idiom (see § 5.4)
