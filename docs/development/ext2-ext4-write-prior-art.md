<!--
Multi-source convergent prior-art audit for the 1.33.x ext2/ext4 WRITE arc.
Companion to ext2-ext4-extents-prior-art.md (the 1.31.5 READ arc) and
ext4-64bit-prior-art.md (the 1.31.7 Phase-5 arc). Written audit-first per
feedback_redesign_dont_reinvent: triangulate FreeBSD/Linux/specs, port the
converged shape, redesign to Cyrius conventions. Linux is one source of many.

Doc layer: kernel-internals implementation plan (lives in agnosticos per
project_agnosticos_role_meta_wrapper — iron-boot / testing-surface tracking
lives here; the ext2.cyr code lives in agnos/). state.md links the 1.33.x
cycle header to this doc.
-->

# ext2/ext4 WRITE — 1.33.x Implementation Plan & Multi-Source Convergent Prior Art

> **Status**: audit (pre-code). Opened 2026-05-25 alongside the 1.33.x WRITE cycle.
> **Predecessor**: the READ arc closed at 1.31.7 (ext2/4 read + indirect + extents + 64BIT, all iron-validated through Attempt 91). This doc is its mirror image: every read accessor gets a write-back sibling, every walker that *finds* a block gets an allocator that *creates* one.
> **Maturity gate**: per [`roadmap.md`](roadmap.md) the demo→base stage exit. ext4 read-only is the demo ceiling; ext4 read+write is the base floor (state persists across reboots → the box can be *lived in*, not just *shown*). See [[project_agnos_maturity_arc]].

---

## 1. Goals + scope

**In scope (1.33.x):**
- Block allocator + inode allocator (bitmap walk + cursor + goal-block hint).
- Free-space accounting: superblock `s_free_blocks_count` / `s_free_inodes_count` + per-group BGDT `bg_free_blocks_count` / `bg_free_inodes_count` / `bg_used_dirs_count`.
- Inode write-back (`ext2_put_inode`): mode, size, links_count, blocks, timestamps, block-pointer array → persisted to the inode table.
- File data write (`ext2_write_at`): allocate data blocks on demand, allocate indirect blocks as the file grows, update `i_size` + `i_blocks`.
- Truncate-to-zero + truncate-smaller (free blocks, walk indirect tree, clear pointers).
- Directory entry insertion (rec_len split into a live entry + a free tail) and removal (tombstone + coalesce into the previous entry's rec_len).
- Composite mutations: `create` (regular file), `unlink`, `mkdir`, `rmdir`, `truncate`.
- VFS write arms: `vfs_write` for `VFS_EXT2_FILE`, plus new `vfs_create` / `vfs_unlink` / `vfs_mkdir` / `vfs_rmdir` dispatch.
- Shell verbs: `echo … > file` / `touch` (create), `rm`, `mkdir`, `rmdir`, `> file` truncate.
- Journal-less ordered-write commit discipline (the safe write order so a crash leaves an fsck-*repairable* image, never a silently-corrupt one).

**Out of scope (deferred, with the cycle that earns each):**
- **ext4 extent ALLOCATION** — new files are written ext2-style (indirect-mapped, `i_flags` *without* `EXTENTS_FL`); this is legal on an ext4 FS and e2fsck-clean. Allocating *extents* (extent-tree split, `ee_len` accounting) is a later cycle. § 11.
- **`metadata_csum` write** — CRC32c over SB / BGDT / bitmaps / inodes / dirents. The #1 write trap (§ 10). 1.33.x targets a `^metadata_csum` image and **refuses write** on a checksummed FS (mounts read-only). crc32c-on-write is its own sub-cycle.
- **Journaling (jbd2)** — ext2 has no journal *by design* (spec-defined); ext3/4's journal is a separate feature. AGNOS commits without one. Power-loss mid-write ⇒ fsck-required image. § 9. This is acceptable for the base stage (embedded, power-stable storage; user re-runs `e2fsck` if a burn is yanked).
- **`htree` (indexed directories)** — `dir_index` ro_compat. We insert into *linear* directory blocks; an htree dir is read fine but on insert we must either rebuild the index or clear the `INDEX_FL` flag (e2fsck then rebuilds it). § 7.4.
- **rename / link (hardlink) / symlink-create** — queued; `rename` especially wants the dirent-insert + dirent-remove primitives this cycle builds, so it's a cheap follow-on.

---

## 2. What we have today

The READ arc left an unusually complete foundation. **The single biggest finding of this audit: the block-device WRITE primitives already exist and are iron-validated.**

### 2.1 Block-device write — DONE (no new low-level I/O work)
`kernel/core/block.cyr:164` `blk_write(sector, buf)` dispatches to:
- `nvme_blk_write` (`nvme.cyr:960`) → `nvme_write_lba` (`:784`, NVMe opcode 0x01) — page-aligned scratch bounce, returns 0/-1.
- `ahci_blk_write` (`ahci.cyr:1142`) → `ahci_write_lba` (`:1003`, ATA WRITE_DMA_EXT 0x35).
- `msc_blk_write` (USB-MS, SCSI WRITE(10)) — **iron-validated** at Attempt 87 (the `MSC_RW_DEMO=1` LBA-100 sentinel round-trip).
- `vblk_blk_write` (VirtIO), `ramdisk_blk_write` (RAM-disk).

So `ext2_write_block(block_num, buf)` is a thin mirror of the existing `ext2_read_block` (`ext2.cyr:393`): `block→lba` via the existing `ext2_block_to_lba` (`:386`), then `blk_write` per sector instead of `blk_read`. **No driver work. No DMA work. The WRITE arc is purely the ext2 metadata layer above an already-working block writer.**

### 2.2 Read accessors that need write-back siblings
`ext2.cyr` has 35 functions, all read-only (full map in the 2026-05-25 reconnaissance; key ones):
- **Superblock readers** `ext2_sb_*` (`:79-88`) — *but `s_free_blocks_count` and `s_free_inodes_count` are NOT read* (read path never needed them). Write path needs both, read **and** store.
- **BGDT** — only `bg_inode_table` (offset +8) is read (`ext2_get_inode:423`). `bg_block_bitmap` (+0), `bg_inode_bitmap` (+4), `bg_free_blocks_count` (+12), `bg_free_inodes_count` (+14), `bg_used_dirs_count` (+16) are **never touched** — all needed for write.
- **Inode readers** `ext2_inode_*` (`:92-106`) — mode/size/flags/block_ptr. Need store siblings + a whole-inode write-back.
- **Block mapping** `ext2_logical_to_physical` (`:647`) returns 0 for a sparse hole. Write path needs the same walk but *allocating* the hole instead of reporting it.
- **Dirent** `ext2_dir_lookup` (`:896`), `ext2_print_dir` (`:828`), `ext2_dirent_valid` (`:817`) — parse only; no insert/remove.

### 2.3 What is entirely absent (build from prior art)
- Any bitmap read or scan. (Read path never reads a bitmap — reading existing data doesn't consume free space.)
- Any allocation cursor / goal logic.
- Any inode/superblock/BGDT *store*.
- VFS write entry points: `vfs_write` returns **-1** for `VFS_EXT2_FILE` (`vfs.cyr:190`); no `vfs_create`/`unlink`/`mkdir`/`rmdir`.

### 2.4 Scratch-buffer budget (Cyrius `var X[N]` units)
Per [[cyrius-var-array-u64-units]]: module-global `var X[N]` = N×u64 (8N bytes). The read path already owns module-scope `ext2_block_buf` (one FS block) + `ext2_indirect_buf_l1/l2/l3`. Write adds: `ext2_bitmap_buf` (one block — a block/inode bitmap is exactly ≤ one block for ≤ 32768 blocks/group at 4K) + `ext2_dir_scratch` (one block for dirent splice). A 4096-byte block = `var buf[512]` at module scope (512×8 = 4096). Reuse, don't re-alloc per call — same discipline as the read scratch pages.

---

## 3. The write-safety model — ordered writes without a journal

This is the load-bearing design decision and the section to get right; everything else is mechanics.

ext2 has **no journal**. ext3/4 add jbd2, but a freshly-`mkfs.ext2` (or `mkfs.ext4 -O ^has_journal`) image has none, and AGNOS will not implement jbd2 in 1.33.x (§ 1, deferred). Without a journal, crash-consistency comes from **write ordering** — the same discipline the original ext2 (and FFS/UFS "soft-ordering") used. The rule, converged across FreeBSD `ext2_alloc.c`, the original ext2 design papers, and the e2fsprogs fsck-recovery model:

> **Write the thing being *pointed to* before the *pointer*, and write the *allocation bit* before the *use*. Then a crash leaks resources (recoverable by fsck) but never dangles a pointer (unrecoverable / silent corruption).**

Concrete commit order for **append a block to a file**:
1. Read block bitmap, find a free bit, **set it, write the bitmap block.** *(Now the block is reserved; a crash here leaks one block — fsck reclaims it.)*
2. Write the **data** into the new block. *(Crash here: block is allocated but contains stale data; not yet linked — fsck reclaims it.)*
3. If an indirect block was needed, write the **indirect block** (pointing at the data block) before the inode points at the indirect block.
4. Update the **inode**'s `i_block[]` / `i_size` / `i_blocks`, **write the inode.** *(Now the file sees the data.)*
5. Decrement `bg_free_blocks_count` + `s_free_blocks_count`, **write BGDT, write superblock.** *(Accounting last — a stale-high free count is harmless; fsck corrects it.)*

The inverse for **free** (truncate / unlink): clear the *pointer* first (inode), then the *data/indirect blocks*, then the *bitmap bit*, then bump the *free count*. (Free the pointer before the bit, so a crash never has a live pointer to a block the bitmap says is free.)

**Failure mode we accept**: a crash mid-write leaves leaked blocks/inodes or a stale free-count — all **fsck-fixable** (`e2fsck -fy` reclaims). **Failure mode we forbid**: a live inode pointer to a block whose bitmap bit is clear, or two inodes pointing at one block. The ordering above makes both impossible. This is exactly why the QEMU smoke gate (§ 8) is **`e2fsck -fn` returns clean** after every write test — not just "the file reads back."

No `fsync`/barrier primitive exists (§ 2.3). For 1.33.x we issue writes synchronously through `blk_write` (which completes the NVMe/AHCI command before returning), so step-ordering at the kernel level *is* the on-disk ordering — there's no writeback cache layer in AGNOS to reorder behind us. (A real fsync/FLUSH-CACHE is a hardening item; the drives we burn on honor write-completion, and the smoke gate proves it.)

---

## 4. Block allocator — bitmap walk + accounting

**Convergent shape** (FreeBSD `ext2_alloc.c` `ext2_alloccg` / `ext2_mapsearch`; Linux `fs/ext2/balloc.c` `ext2_new_blocks`; ext2-doc § 4.1):

A block bitmap is one bit per block in the group, packed LSB-first into ≤ one FS block (4096 bytes = 32768 bits = 32768 blocks/group, the `mkfs` default — so one bitmap block per group, never spilling). Bit *b* of group *g* ⇒ block number `s_first_data_block + g*blocks_per_group + b`.

**Allocation algorithm (the "goal" heuristic, simplified from FFS):**
```
ext2_alloc_block(goal_block) -> block_num | 0(=ENOSPC) | -1(=IO error)
  g = group containing goal_block          # keep a file's blocks near its inode/data
  for each group starting at g, wrapping:
    if bg_free_blocks_count[group] == 0: continue
    read bg_block_bitmap[group] into ext2_bitmap_buf
    b = first 0-bit in the bitmap (byte scan, then bit scan within byte)
       # prefer the byte containing goal's bit first, then linear — FreeBSD ext2_mapsearch
    if found:
      set bit b; write bitmap block                       # commit order step 1 (§3)
      bg_free_blocks_count[group]-- ; write BGDT
      s_free_blocks_count-- ; write superblock
      return s_first_data_block + group*blocks_per_group + b
  return 0   # ENOSPC
```

**Gotchas the prior art flags:**
- **`s_first_data_block` skew** (read doc § 3.5): on 1024-byte-block FSes the superblock is in block 1, so group 0's data starts at block 1, and bit 0 of group 0's bitmap = block `s_first_data_block`. On our 4K-block images `s_first_data_block == 0`, so the arithmetic is clean — but the allocator must use `s_first_data_block`, not a literal 0, or it desyncs by one block on 1K images.
- **Reserved blocks at group start**: superblock backups + BGDT copies + the bitmaps + inode table occupy the first N blocks of each group (with `sparse_super`, only groups 0/1/powers-of-3/5/7 carry backups). Those bits are **already set** in the bitmap by `mkfs`, so a naive "first free bit" scan correctly skips them — *we never compute the reserved region ourselves*, we trust the bitmap. (This is the FreeBSD posture; Linux computes it for the goal hint only.)
- **`bg_block_bitmap` location is the bitmap's own block number** — read it from the BGDT (offset +0), don't compute it.
- **`uninit_bg` / `BLOCK_UNINIT`** (ro_compat `gdt_csum` 0x10): a group flagged `INODE_UNINIT`/`BLOCK_UNINIT` in `bg_flags` has a bitmap that `mkfs` *didn't write* (it's implied all-free-except-metadata). For 1.33.x we **refuse write** if a target group is uninit (or, simpler: target an image made with `^uninit_bg`). Materializing an uninit bitmap is a deferred sub-item. Flag at mount.

---

## 5. Inode allocator — inode bitmap + accounting

Mirror of § 4 against `bg_inode_bitmap` (BGDT +4) and `s_inodes_per_group`. Differences:

- **Inode numbers are 1-based**; inode *i* lives in group `(i-1)/inodes_per_group`, bitmap bit `(i-1)%inodes_per_group`.
- **First non-reserved inode** is `s_first_ino` (offset +84, =11 on dynamic-rev; inodes 1-10 reserved, root=2). The bitmap's low bits for reserved inodes are pre-set by `mkfs` — same "trust the bitmap" posture as blocks.
- **Directory allocation bumps `bg_used_dirs_count`** (BGDT +16). The Orlov allocator (Linux) spreads dirs across groups by this count; FreeBSD uses a simpler "group with most free inodes." **AGNOS 1.33.x uses the FreeBSD-simple policy**: allocate a new dir's inode in the group with the most free inodes; allocate a regular file's inode in its parent dir's group (locality). Don't port Orlov — it's a placement *optimization*, not a correctness requirement, and adds ~150 LOC for zero base-stage value.
- Commit order: set inode bitmap bit + write → (caller fills the inode) → `ext2_put_inode` → BGDT `bg_free_inodes_count--` (+ `bg_used_dirs_count++` if dir) → superblock `s_free_inodes_count--`.

---

## 6. Inode write-back — `ext2_put_inode`

The read path's `ext2_get_inode` (`:423`) already computes the exact byte location of an inode in the inode table (group → `bg_inode_table` → `byte_offset = ((i-1)%ipg) * inode_size`). `ext2_put_inode` is the inverse, with one wrinkle: **inodes are `inode_size` bytes (128 or 256) but the table is block-packed**, so a write must be **read-modify-write at block granularity** — read the inode-table block, splice the `inode_size` bytes for this inode at its offset, write the block back. (Never write a bare `inode_size` slice; you'd clobber adjacent inodes sharing the block.)

Field-store siblings to add (mirror `:92-106`):
- `ext2_inode_set_mode/size_lo/size_hi/links_count/blocks_lo/flags/block_ptr(i, val)` — little-endian stores.
- Timestamps: set `i_atime`/`i_ctime`/`i_mtime` (+8/+12/+16) to a monotonic-ish value. **AGNOS has no RTC wall-clock wired** at FS layer → use a fixed sentinel epoch (or the boot-tick counter as a fake monotonic). e2fsck does **not** care about timestamp *values*, only that the fields exist — so a constant is fine and honest. Flag in § 12.
- `i_blocks` is in **512-byte sectors**, not FS blocks (classic ext2 trap): a 4K block adds 8 to `i_blocks`. FreeBSD `ext2_dinode.h` documents this; getting it wrong makes `e2fsck` report "i_blocks wrong" on every file.
- `i_links_count` (+26, u16): regular file starts at 1; a dir starts at 2 (`.` + parent's entry) and its parent's link count goes +1 (the `..`).

---

## 7. Directory mutation

### 7.1 On-disk dirent (read doc § 3.4, unchanged)
`{ inode:u32, rec_len:u16, name_len:u8, file_type:u8, name[] }`, 4-byte aligned, `rec_len` spans to the next entry (the last entry's `rec_len` runs to end-of-block). A 0 inode = tombstone.

### 7.2 Insert (converged: FreeBSD `ext2_direnter` / Linux `ext2_add_link`)
The "find a gap by walking rec_len slack" algorithm:
```
needed = 8 + name_len, rounded up to 4
for each block in dir, for each entry:
  # an entry's "real" size is 8+name_len rounded to 4; the slack is rec_len - real
  if entry.inode == 0 and rec_len >= needed:                 # reuse a tombstone
      overwrite in place; done
  if rec_len - real >= needed:                               # split a live entry's slack
      new_entry at off + real;  new.rec_len = entry.rec_len - real
      entry.rec_len = real;     fill new_entry (inode,name,type)
      write block; done
if no gap in any existing block:
  alloc a new data block (§4); append it to the dir inode (§6, like a file grow)
  the whole new block is one entry: rec_len = blocksize, inode/name set
  i_size += blocksize; write inode
```
**Gotcha**: `mkfs`-created dirs have their last entry's `rec_len` padded to block end — so block 0 of every dir always has slack to split. The "alloc new block" path only triggers on a genuinely full dir block.

### 7.3 Remove (converged: FreeBSD `ext2_dirremove`)
Don't shift bytes. **Coalesce the victim's `rec_len` into the previous entry**:
```
walk to the target; track prev
if prev exists in same block: prev.rec_len += target.rec_len   # absorb the hole
else (target is first in block):  target.inode = 0             # tombstone the head
write block
```
e2fsck treats both forms as clean. (Tombstoning the block head is the one case you can't coalesce; ext2 leaves it as a 0-inode hole, reused on next insert per § 7.2.)

### 7.4 htree (`dir_index`, ro_compat) — refuse-or-clear
If the dir inode has `INDEX_FL` (`i_flags & 0x1000`), it's an htree. We can *read* it (the leaf blocks are normal dirents), but inserting without maintaining the hash index corrupts lookups. **1.33.x posture**: on first insert into an htree dir, **clear `INDEX_FL`** and treat it as linear (e2fsck rebuilds the index on next check, with a benign warning). Simpler than maintaining the index; correctness-safe. Target images: `mkfs.ext4 -O ^dir_index` avoids it entirely for the smoke gate.

---

## 8. Phased port plan

Each phase ends with a QEMU smoke gate. **The gate is two-part: (a) the data reads back inside AGNOS, AND (b) `e2fsck -fn` on the host image returns clean (exit 0, no "FIXED").** Part (b) is what proves the commit ordering and the accounting math — a file that reads back but leaves `e2fsck` screaming is a fail. The final phase ends with an iron burn on archaemenid.

Shared test-image builder (recommend `agnos/scripts/build-ext2-write-image.sh`):
```sh
dd if=/dev/zero of=ext2-w.img bs=1M count=64
mkfs.ext2 -F -b 4096 -m 0 \
  -O ^metadata_csum,^64bit,^dir_index,^uninit_bg,^has_journal,^resize_inode \
  -L AGNOS-WTEST ext2-w.img            # deliberately the most boring, write-friendly profile
debugfs -R 'stats' ext2-w.img | grep -i 'free\|inode'   # record baseline free counts
# (no GPT wrapper needed for the smoke — attach the bare FS image; iron uses the agnos-fs partition)
```

### Phase W1 — write primitives + metadata field stores + bitmap read (~250 LOC)
`ext2_write_block`; `ext2_put_inode` (RMW, § 6); superblock/BGDT field readers+stores for the free counts + bitmap-block pointers; `ext2_read_bitmap(block_or_inode, group)`. **No allocation yet** — a self-test hook in `main.cyr` reads the block bitmap of group 0 and prints `ext2: grp0 free_blocks=N free_inodes=M` matching `debugfs stats`.
**Gate**: numbers match host `debugfs`; image untouched (read-only still) → `e2fsck -fn` clean (trivially).
**Build target**: +~5 KB.

### Phase W2 — block + inode allocators (~300 LOC)
`ext2_alloc_block(goal)` (§4), `ext2_alloc_inode(is_dir)` (§5), `ext2_free_block(b)`, `ext2_free_inode(i)`, with full SB+BGDT accounting. Self-test hook: allocate 3 blocks + 1 inode, print their numbers, then free them; verify free counts return to baseline.
**Gate**: alloc/free round-trips to identical free counts; `e2fsck -fn` clean (alloc-then-free leaves the FS as found).
**Build target**: +~6 KB.

### Phase W3 — file data write + `ext2_write_at` (~300 LOC)
`ext2_write_at(inode_num, offset, buf, len)`: walk logical→physical *allocating holes* (extend `ext2_logical_to_physical` into an `alloc=1` variant, allocating indirect blocks as needed), `blk_write` the data, update `i_size`/`i_blocks`, `ext2_put_inode`. Truncate-to-zero (`ext2_truncate`) freeing the block tree. Self-test: write 200 bytes to a *pre-existing* file's inode, then read it back inside AGNOS.
**Gate**: in-AGNOS readback matches; **host `e2fsck -fn` clean**; host `mount` + `cat` shows the new bytes.
**Build target**: +~7 KB.

### Phase W4 — directory insert/remove + `create`/`unlink` (~350 LOC)
`ext2_dir_insert(dir, name, child_inode, ftype)` (§7.2), `ext2_dir_remove(dir, name)` (§7.3); `ext2_create(parent, name)` (alloc inode → init as regular → insert dirent), `ext2_unlink(parent, name)` (remove dirent → dec links → if 0, free inode + truncate). VFS arms: `vfs_write` for `VFS_EXT2_FILE` (was -1), `vfs_create`. Shell: `touch`, `echo … > f`, `rm`.
**Gate**: `agnos> echo hello > /new.txt` then reboot QEMU, `cat /new.txt` → `hello`; host `e2fsck -fn` clean; host sees `/new.txt`. `rm` round-trips free counts.
**Build target**: +~8 KB.

### Phase W5 — `mkdir`/`rmdir` + commit-order hardening + iron burn (~250 LOC)
`ext2_mkdir` (alloc inode → init dir with `.`/`..` → parent links_count++ → insert dirent → `bg_used_dirs_count++`), `ext2_rmdir` (empty-check → remove → parent links_count-- → free). Audit every mutation against the § 3 commit order. Shell: `mkdir`, `rmdir`.
**QEMU gate**: build a tree (`mkdir /a`, `echo x > /a/b`, `rm /a/b`, `rmdir /a`), reboot, verify; `e2fsck -fn` clean after each.
**Iron gate**: burn on archaemenid against the **agnos-fs partition** (mount-modify per [[feedback_prefer_mount_modify_over_reflash]] to seed a write-friendly FS first); create a file, reboot, confirm persistence across a real power cycle — *the demo→base proof*. Then pull the drive, `e2fsck -fn` on the host: clean.
**Build target**: +~6 KB. **1.33.x cut estimate**: +~32 KB over the 1.32.9 baseline.

---

## 9. Commit ordering & crash semantics (summary card)

| Operation | Write order (each step = one `blk_write`, completed before the next) |
|---|---|
| **Append block** | bitmap-set → data → (indirect) → inode → BGDT count → SB count |
| **Free block** | inode-clear-ptr → (indirect-clear) → bitmap-clear → BGDT count → SB count |
| **Create file** | inode-bitmap-set → inode-init(`ext2_put_inode`) → dirent-insert → BGDT/SB counts |
| **Unlink file** | dirent-remove → inode `links--` → (if 0) free blocks (above) → inode-bitmap-clear → counts |
| **mkdir** | inode-bitmap-set → alloc dir block (bitmap+data `.`/`..`) → inode-init → parent `links++`+put → dirent-insert → counts+`used_dirs++` |

**Crash invariant**: at every step boundary the on-disk image is e2fsck-*repairable* (leaked resource or stale count), never silently corrupt (dangling pointer / double-allocated block). **No journal** ⇒ a yanked burn = run `e2fsck -fy` before remount. Documented, accepted for base stage.

---

## 10. Feature-flag triage for WRITE (the metadata_csum trap)

Read tolerates `ro_compat` freely (an RO mount ignores it). **Write must HONOR `ro_compat` or refuse** — that's the whole point of the "read-only compatible" class. Per-bit verdict for the *write* path:

| ro_compat bit | Name | Write verdict | Reason |
|---|---|---|---|
| 0x0001 | SPARSE_SUPER | **TOLERATE** | Backup SB/BGDT placement; we trust the bitmap, never author backups (e2fsck syncs them) |
| 0x0002 | LARGE_FILE | **TOLERATE** | `i_size_hi` already handled (read doc §3.3) |
| 0x0008 | HUGE_FILE | **TOLERATE** | `i_blocks` in fs-blocks vs sectors; we write small files, never hit it |
| 0x0010 | GDT_CSUM (uninit_bg) | **REFUSE-WRITE** | Implies uninitialized bitmaps + BGDT checksums (§4). Target `^uninit_bg`. |
| 0x0020 | DIR_NLINK | **TOLERATE** | Dir link count > 64999 wraps to 1; our dirs are tiny |
| 0x0040 | EXTRA_ISIZE | **TOLERATE** | Uses `i_extra_isize`/`i_*_extra`; we write 128-byte core, leave extra zero (e2fsck-OK) |
| 0x0400 | **METADATA_CSUM** | **REFUSE-WRITE (1.33.x)** | **Every** SB/BGDT/bitmap/inode/dirent carries a CRC32c; writing without updating it ⇒ e2fsck "checksum invalid" on everything we touch, kernel remounts-RO. **Deferred sub-cycle.** `mkfs.ext4` default sets this — so the WRITE smoke image MUST be `-O ^metadata_csum`. |
| 0x8000 | PROJECT | **TOLERATE** | Project quota id; we leave it as found |

**incompat** bits that block *write* (beyond the read mask): `RECOVER` (0x4 — a dirty journal needing replay; we don't replay, so refuse write on a journal-dirty FS), `64BIT` (0x80 — write path must handle 64-bit BGDT entries + `bg_*_hi` count halves; the read path already tolerates 64BIT for *reading*, but write accounting must update the `_hi` halves too — **support if the agnos-fs image is 64BIT, else target `^64bit`**; decide at scaffold based on how the user re-carves the partition).

**Write supported-ro_compat mask (1.33.x)** = `SPARSE_SUPER | LARGE_FILE | HUGE_FILE | DIR_NLINK | EXTRA_ISIZE | PROJECT`. If `(s_feature_ro_compat & ~WRITE_RO_MASK) != 0` → **mount read-only**, log `ext2: ro_compat 0x<hex> unsupported for write — mounting read-only`. This is the honest posture: a checksummed/uninit FS still *reads* (the whole 1.31.x arc), it just won't *write* until the deferred sub-cycle.

**Comparative landing**: FreeBSD ext2fs writes ext2/3/4 *without* metadata_csum or 64bit-write for years (added 64bit-write only recently); it refuses write on metadata_csum until its csum layer landed. AGNOS 1.33.x = FreeBSD's pre-csum write posture exactly. Good company.

---

## 11. ext4 extents — write deferral rationale

Files we *create* get `i_flags` **without** `EXTENTS_FL` and use the ext2 indirect block map. This is **legal on an ext4 filesystem** — ext4 reads indirect-mapped inodes fine (the flag is per-inode), and e2fsck accepts a mixed FS. So the WRITE arc works on an ext4 image without writing a single extent. *Allocating* extents (splitting the extent tree, `ee_len`/`ee_start_hi` accounting, the `<<31<<1` 48-bit trap from read doc §5.4 but in reverse) is a clean follow-on cycle once the indirect-write path is iron-proven. **Do not** entangle extent-allocation into 1.33.x — it doubles the file-write surface for a path the indirect map already covers at base-stage file sizes.

---

## 12. Open questions / parked items

1. **agnos-fs image profile for the smoke + iron gate** — the cleanest WRITE target is `mkfs.ext2 -O ^metadata_csum,^64bit,^dir_index,^uninit_bg,^has_journal`. But the user's current agnos-fs partition (NVMe p2, re-carved at 1.31.7) was made with `mkfs.ext4` defaults → almost certainly has `metadata_csum` + `64bit`. **Decision needed at scaffold**: either (a) re-carve the agnos-fs partition write-friendly (mount-modify-friendly, loses nothing — it's a test partition), or (b) take on `64bit`-write + `metadata_csum`-write now (bigger cycle). Recommend (a) for 1.33.x; (b) as the deferred csum sub-cycle. *This is the one thing to confirm with the user before W2.*
2. **Timestamps without an RTC** — FS-layer has no wall clock. Use a fixed epoch or boot-ticks; e2fsck doesn't validate values. Wiring a real clock is orthogonal (RTC/CMOS or NTP-later). Parked.
3. **fsync / FLUSH CACHE** — no barrier primitive; synchronous `blk_write` + completion-before-return is our ordering guarantee (§3). A true cache-flush is a hardening item if a drive ever buffers; the smoke `e2fsck -fn` gate is the canary.
4. **`s_state` / `s_lastcheck` / mount-count** — a real driver clears `EXT2_VALID_FS` in `s_state` on mount and sets it on clean unmount (so fsck knows if the FS was dirty). 1.33.x **should** set `s_state` dirty-on-first-write and clean on a `sync` shell verb — cheap, and it makes the no-journal story honest (a yanked burn shows dirty → user knows to fsck). Add to W5.
5. **VFS generic write resolve** — keep `ext2_*` internal for 1.33.x (matches read-arc decision); lift to `vfs_*` generic when a second writable FS arrives. Abstract on demand (the `block.cyr` dispatch precedent).
6. **Reserved-blocks (`-m`)** — `mkfs -m 0` for test images so the allocator can use the whole FS; on a real partition the 5% reserve is fine (allocator just sees fewer free bits). No special handling.

---

## 13. Sources

**Linux v6.6 (ext2 — the no-journal cousin, closest to our model):**
- `https://github.com/torvalds/linux/blob/v6.6/fs/ext2/balloc.c` — `ext2_new_blocks`, bitmap scan, goal heuristic, group accounting
- `https://github.com/torvalds/linux/blob/v6.6/fs/ext2/ialloc.c` — `ext2_new_inode`, inode bitmap, `bg_used_dirs_count`, Orlov (which we deliberately *don't* port)
- `https://github.com/torvalds/linux/blob/v6.6/fs/ext2/inode.c` — `ext2_get_block` alloc path, indirect-block allocation, `ext2_truncate_blocks`
- `https://github.com/torvalds/linux/blob/v6.6/fs/ext2/dir.c` — `ext2_add_link` (rec_len split), `ext2_delete_entry` (coalesce into prev)

**FreeBSD main (clean-room write-capable ext2/3/4 — the primary convergent reference):**
- `https://github.com/freebsd/freebsd-src/blob/main/sys/fs/ext2fs/ext2_alloc.c` — `ext2_alloccg`, `ext2_mapsearch`, simple group-selection (the policy AGNOS adopts over Orlov)
- `https://github.com/freebsd/freebsd-src/blob/main/sys/fs/ext2fs/ext2_balloc.c` — `ext2_balloc` indirect-block allocation + the append commit order
- `https://github.com/freebsd/freebsd-src/blob/main/sys/fs/ext2fs/ext2_lookup.c` — `ext2_direnter` / `ext2_dirremove` (the dirent splice/coalesce AGNOS ports)
- `https://github.com/freebsd/freebsd-src/blob/main/sys/fs/ext2fs/ext2_inode.c` — `ext2_truncate`, `i_blocks` (512-byte-sector) accounting
- `https://github.com/freebsd/freebsd-src/blob/main/sys/fs/ext2fs/ext2_dinode.h` — best-annotated inode field offsets incl. the `i_blocks` units trap

**OpenBSD master (independent third reference, conservative no-csum write):**
- `https://github.com/openbsd/src/blob/master/sys/ufs/ext2fs/ext2fs_alloc.c`
- `https://github.com/openbsd/src/blob/master/sys/ufs/ext2fs/ext2fs_lookup.c` — `ext2fs_direnter`/`ext2fs_dirremove`

**Specs / tooling:**
- `https://archive.kernel.org/oldwiki/ext4.wiki.kernel.org/index.php/Ext4_Disk_Layout.html` — primary spec; bitmap/BGDT/inode layout, `bg_flags` (uninit), checksum rules
- `https://www.nongnu.org/ext2-doc/ext2.html` — Dave Poirier's ext2 spec (pre-csum era — *exactly* our write model: block/inode bitmap mechanics, allocation, directory ops, no journal)
- `https://e2fsprogs.sourceforge.net/` — `e2fsck` is the smoke oracle; `debugfs stats`/`dump`/`ncheck` for ground truth; `mke2fs.conf` feature defaults (why `metadata_csum`/`64bit` show up unbidden)

**Cross-references (this repo):**
- [`ext2-ext4-extents-prior-art.md`](ext2-ext4-extents-prior-art.md) — the READ arc; on-disk structures + accessor offsets reused verbatim
- [`ext4-64bit-prior-art.md`](ext4-64bit-prior-art.md) — 64BIT BGDT-64 + `bg_*_hi` halves (the write-side accounting if we take on 64bit-write per §10)
- ext2.cyr reconnaissance (2026-05-25) — current 35-function read-only map, the foundation every write sibling extends
