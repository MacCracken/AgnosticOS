# ext4 Extent ALLOCATION (write) — Design + Multi-Source Prior-Art Audit

> **Status**: design — drives the agnos **1.37.x** arc (the first of the heavy big-write cycles). The 1.33.x WRITE arc reached file-write by creating **indirect-mapped** inodes (no `EXTENTS_FL`) — legal on ext4, but it can't *grow an inode that already uses extents* (anything `mkfs.ext4`/Linux created). 1.37.x adds the extent write/allocation path. Companion to the read-side audit (`ext2-ext4-extents-prior-art.md`) and the write audit (`ext2-ext4-write-prior-art.md` § 11, which deferred this here).
>
> **Created**: 2026-05-27.

## 1. Scope + the case that forces it

AGNOS already **reads** extent inodes (`ext2_extent_logical_to_physical`, depth ≤ 5) and **allocates blocks** (`ext2_alloc_block`, bitmap + group/sb accounting). What's missing: when a file with `i_flags & EXTENTS_FL (0x80000)` grows, map the newly-allocated physical block by **extending or inserting an extent**, not by writing an indirect block (which would corrupt an extent inode — the same `i_block[]` 60 bytes mean *extent tree root*, not block pointers).

In scope: **append/grow an extent-mapped regular file** (the dominant base-stage case). The forward of the read-doc §5.4 48-bit trap: a physical block number splits into `ee_start_hi` (16) + `ee_start_lo` (32). Out of scope (later/deferred): `fallocate`/unwritten extents (`ee_len > 32768`), hole-punch, extent merging on delete, defrag.

## 2. On-disk layout (from the reader, confirmed)

```
ext4_extent_header (12B):  eh_magic(2)=0xF30A | eh_entries(2) | eh_max(2) | eh_depth(2) | eh_generation(4)
ext4_extent (12B, leaf):   ee_block(4) | ee_len(2) | ee_start_hi(2) | ee_start_lo(4)
ext4_extent_idx (12B, int):ei_block(4) | ei_leaf_lo(4) | ei_leaf_hi(2) | ei_unused(2)
```
- **Inline root**: bytes 0..59 of `inode.i_block[]` = one header + up to **4** entries (`eh_max` ≈ (60−12)/12 = 4). `eh_depth = 0` → entries are leaf extents; `> 0` → index entries pointing at tree blocks.
- **Tree block** (depth > 0 or overflow): a full filesystem block = header + up to `(blocksize−12)/12` entries.
- **`ee_len`**: 1..32768 initialized; `> 32768` = unwritten (`ee_len − 32768` blocks). We only ever write **initialized** (`≤ 32768`, and in practice ≤ a few).
- **physical block** = `(ee_start_hi << 32) | ee_start_lo`. Our images are < 2³² blocks, so `ee_start_hi = 0` in practice — but the accessor must still split correctly.

## 3. Multi-source prior art (the converged shape)

- **Linux `fs/ext4/extents.c`** (`ext4_ext_insert_extent`, `ext4_ext_create_new_leaf`, `ext4_ext_split`) — the full reference, but tangled with delayed allocation, `ext4_ext_try_to_merge`, journaling credits, and unwritten-extent conversion. We take the *shape* (find leaf → try-extend-last → else insert → else split), not the machinery.
- **FreeBSD `ext4_ext_*`** (`ext4_ext_insert_extent`, `ext4_ext_grow_indepth`) — the cleanest standalone reference (same one the read side ported from); read-mostly but the insert path is legible.
- **e2fsprogs `ext2fs_extent_insert` / `extent.c`** (libext2fs) — the *userspace* canonical extent-tree editor; `EXT2_EXTENT_INSERT_*` flags + `ext2fs_extent_fix_parents` are the model for "add an extent and fix the up-chain `ee_block`/`eh_entries`."

**Converged append algorithm** (the only path we need):
1. Walk to the **rightmost leaf** (for append, logical block is always past EOF → the last extent/leaf). Reader already does the descent; add a "descend to rightmost, remembering the path" variant.
2. **Try to extend the last extent**: if the new logical block == `last.ee_block + last.ee_len` *and* the new physical == `last_phys + last.ee_len` (contiguous) *and* `ee_len < 32768`, just `ee_len += 1`. No structural change — the cheap, common path (sequential append to a freshly-allocated contiguous run).
3. **Else insert a new extent** in the leaf: if the leaf has room (`eh_entries < eh_max`), append a new `{ee_block, ee_len=1, phys}` entry, bump `eh_entries`. Done.
4. **Else split** (leaf full): allocate a new tree block, move half the entries, add/extend an index entry in the parent; if the *root* is full, **grow depth** (move the inline root's entries into a new block, make the root a single index entry — `ext4_ext_grow_indepth`). Fix `ee_block`/`eh_entries` up the path.

To keep block allocation contiguous-friendly (so step 2 hits often), the block allocator should prefer the block right after `last_phys` — a goal-block hint, which `ext2_alloc_block` can take (Linux `ext4_ext_find_goal`).

## 4. Diff against AGNOS

| Need | Today | Gap |
|---|---|---|
| Read/resolve an extent inode | `ext2_extent_logical_to_physical` (depth ≤ 5) ✓ | reuse + a "descend-to-rightmost-with-path" variant |
| Allocate a physical block (+ accounting) | `ext2_alloc_block` ✓ | add an optional **goal hint** (prefer `last_phys+1`) for contiguity |
| Inode write-back | `ext2_put_inode` (1.33.x) ✓ | reuse (root extents live in the inode) |
| Block write-back of a tree node | `ext2_write_block` ✓ | reuse for leaf/index node writes |
| Extend last extent (`ee_len += 1`) | none | new — the cheap common path |
| Insert extent into a non-full leaf/root | none | new |
| Split leaf / grow depth + fix up-chain | none | new (the hard bite) |
| Route `ext2_write_at` by `EXTENTS_FL` | indirect-only today | add the extent-append branch |
| `ee_start_hi/lo` 48-bit split on write | reader splits on read | write-side split helper |

## 5. Version structure (Claude-determined, per the 2026-05-27 delegation)

The arc breaks into byte-of-risk-sized bites; **the user calls releases/tags** — these are *open/cut* targets, not "released."

- **1.37.0 — depth-0 append (the 80% path). ✅ RELEASED.** `ext2_extent_append_block`: extend-last-extent (contiguous), else insert into the inline root (≤ 4 entries). Goal-hinted block alloc. `ext2_write_at` routes by `EXTENTS_FL`. `ext-extent-smoke.sh` e2fsck-clean on a default `mkfs.ext4` image.
- **1.37.1 — depth-1: leaf overflow → first split. ✅ DONE (awaiting tag).** `ext2_extent_grow_indepth` spills the 4 root extents into a new leaf block (`eh_max` 340 at 4 KB) + rewrites the root as one index entry; appends descend to the leaf (`ext2_extent_leaf_place`). The leaf block carries the metadata_csum extent-node checksum (`ext2_extent_node_csum_stamp`; same seed as the inode csum, tail at `12 + eh_max*12`). Smoke forces the grow with sparse writes (2,4,6,8,10) → final `eh_depth==1`, `e2fsck -fn` clean.
- **1.37.2 — multi-leaf + deeper splits + hardening + iron burn.** Second leaf when the first fills (root gains a 2nd index entry), and depth-2 if the index node fills; up-chain `ee_block`/`eh_entries` fix; commit-order. The arc's iron touch.

(Boundaries are provisional — collapse 1.37.1/1.37.2 if the split code lands clean in one bite, or split further if tree-growth proves gnarly.)

## 6. Safety / commit order

Same no-journal ordered-write model as 1.33.x (§3 of the write doc): **data block → tree-node block(s) → inode** (so a yanked write never leaves the inode pointing at an extent whose backing block or leaf node isn't on disk). Block-bitmap + group/sb free-count accounting reuses the 1.33.x allocator. `e2fsck -fn` clean on a real `metadata_csum,64bit` `mkfs.ext4` image is the gate (extent inodes carry their own checks under `metadata_csum` — the leaf/index node checksum is a tail field; fold into the existing crc32c path from write-doc § 14).

## 7. Out of scope (deferred)
- Unwritten/preallocated extents (`fallocate`, `ee_len > 32768`), hole punch, extent **merge** on truncate/delete (truncate of extent files frees blocks but can leave adjacent extents un-merged — cosmetic, e2fsck-clean).
- Delayed allocation, multi-block-allocator (mballoc) goal heuristics beyond the simple `last_phys+1` hint.
- The VFS generic-write lift — that's 1.39.x (the second-writable-FS trigger is FAT, already shipped).
