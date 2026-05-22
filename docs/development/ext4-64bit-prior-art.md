# ext4 64BIT — Multi-Source Convergent Prior Art

**Status**: agnos 1.31.7 bite (A) implementation companion doc. Closes row 7b of `agnos/docs/development/roadmap.md`.

**Scope**: Phase 5 of the ext2/ext4 driver. Unlocks mounting of `mkfs.ext4`-default filesystems on iron (modern `mkfs.ext4` sets `EXT4_FEATURE_INCOMPAT_64BIT = 0x80` even on partitions well under the 16 TB threshold where the feature is actually needed — see [`ext2-ext4-extents-prior-art.md` § 6.1 risk row](ext2-ext4-extents-prior-art.md) for the discovery context).

**Companion doc**: this is the implementation-notes complement to [`ext2-ext4-extents-prior-art.md`](ext2-ext4-extents-prior-art.md), which already covers the multi-source survey of the ext2/ext4 superblock + BGDT + inode tree at depth. § 5 of that doc explicitly punted 64BIT as a "Phase 5 unlock" + ~200 LOC; this doc walks the small subset of those LOC that we actually need.

## 1. What 64BIT changes

Per the [ext4 kernel.org wiki](https://www.kernel.org/doc/html/latest/filesystems/ext4/overview.html#features) + Linux `fs/ext4/ext4.h` + FreeBSD `sys/fs/ext2fs/ext2fs.h`:

| Field | Legacy (32-bit) | With INCOMPAT_64BIT |
|-------|-----------------|---------------------|
| `s_desc_size` (sb +254, u16) | 0 or 32 | 32 or 64 |
| BGDT entry size | 32 bytes | `s_desc_size` (typically 64) |
| `bg_block_bitmap_hi` (BGDT +32, u32) | n/a | u32 high 32 bits of bitmap block# |
| `bg_inode_bitmap_hi` (BGDT +36, u32) | n/a | u32 high 32 bits of bitmap block# |
| `bg_inode_table_hi` (BGDT +40, u32) | n/a | u32 high 32 bits of inode table block# |
| Various `_hi` counts (BGDT +44..+58) | n/a | u16/u32 |
| `s_blocks_count_hi` (sb +0x150) | n/a | u32 high 32 bits of total block count |
| Indirect block pointers | u32 | u32 (no 64BIT extension — 64BIT mode requires extents for >16 TB FSes) |

Crucially: **the on-disk inode block-pointer formats don't widen.** ext4 `i_block[]` stays 60 bytes regardless. Indirect-tree files >16 TB aren't representable; for >16 TB you must use extents (whose `ee_start_hi` + `ee_start_lo` give 48-bit block#s already).

For AGNOS at Phase 5 the practical change is:
1. Read `s_desc_size` and use it as the BGDT stride (instead of hardcoded 32).
2. Bump supported_incompat mask from `0x6746` to `0x67C6` (add 0x80).
3. Guard against `bg_inode_table_hi != 0` — refuse with a clear "Phase 6 unlock" message; defer actual 64-bit block# math.

That's it. ~30 LOC of implementation. The "~200 LOC" estimate in the extents doc was a worst-case upper bound assuming we'd extend block# math throughout; we don't need that until a real consumer surfaces a >16 TB FS.

## 2. Multi-source convergent shape

| Source | desc_size handling | _hi guard / use |
|--------|--------------------|-----------------|
| **Linux `fs/ext4/super.c`** | `EXT4_DESC_SIZE(sb)` macro reads `s_desc_size` if `EXT4_HAS_INCOMPAT_FEATURE(sb, EXT4_FEATURE_INCOMPAT_64BIT)`, else defaults to `EXT4_MIN_DESC_SIZE = 32`. `ext4_group_desc()` strides by that. | Uses `_hi` fields throughout via `ext4_inode_table()` etc. helpers; supports full 64-bit block#s. |
| **FreeBSD `sys/fs/ext2fs/ext2_subr.c`** | `e2fs_desc_size` cached from sb; defaults to 32 unless 64BIT. RO mount supported. | `ext2_gd` struct carries `_hi` fields; readers combine `_hi << 32 \| _lo` only when 64BIT. |
| **OpenBSD `sys/ufs/ext2fs/ext2fs.h`** | Doesn't support 64BIT (RO ext2 only; no ext4 64BIT). Hardcoded 32 stride. | n/a — would need to extend. |
| **Haiku `src/add-ons/kernel/file_systems/ext2/`** | `Superblock::FreeBlockCount()` reads `s_free_blocks_count` + `s_free_blocks_count_hi`; BGDT readers handle desc_size. | Full 64BIT support; treats `_hi` as authoritative. |
| **ext4 kernel.org wiki** | Documents `s_desc_size` as "size of group descriptor, in bytes, if the 64bit incompat feature flag is set." Explicit. | All `_hi` fields documented with their offsets. |

**Convergent shape**: every reference reads `s_desc_size` only when 64BIT bit is set in `s_feature_incompat`; defaults to 32 otherwise. The BGDT stride is dynamic per the cached desc_size. `_hi` fields are read when desc_size==64; reads are skipped when desc_size==32 (the bytes wouldn't be allocated in the on-disk struct anyway).

This matches the Phase 1-4 AGNOS approach exactly — gate dynamic behavior on a feature bit, otherwise the legacy code path. No surprises.

## 3. AGNOS Phase 5 approach

**Module state:**

```cyrius
var ext2_desc_size = 32;   # 32 = legacy; 64 = ext4 64BIT mode
```

**Superblock accessor (new):**

```cyrius
fn ext2_sb_desc_size(sb) { return ext2_load16_le(sb, 254); }
```

**In `ext2_init` (after rev/inode_size decode, before mount complete):**

```cyrius
ext2_desc_size = 32;
if (rev >= 1) {
    if ((incompat & 0x80) != 0) {     # EXT4_FEATURE_INCOMPAT_64BIT
        var ds = ext2_sb_desc_size(&ext2_sb_buf);
        if (ds == 0) { ds = 32; }      # fall back if sb didn't fill it
        if (ds > 64) {
            kprint("ext2: s_desc_size > 64 unsupported: ", 36);
            kprint_num(ds);
            kprintln("", 0);
            return 0 - 1;
        }
        ext2_desc_size = ds;
    }
}
```

**Mask bump:**

```cyrius
var supported_mask = 0x67C6;   # was 0x6746; +0x80 = 64BIT
```

**In `ext2_get_inode`:**

```cyrius
var bgdt_entry_size = ext2_desc_size;   # was hardcoded 32
# … (existing block_group bounds check) …
var bgdt_off = &ext2_bgdt_buf + block_group * bgdt_entry_size;
var inode_table_block = ext2_load32_le(bgdt_off, 8);

# Phase 5: when desc_size==64, the BGDT entry has an `_hi` field for
# bg_inode_table at byte offset 40 (u32, the high 32 bits of the 64-bit
# block#). For FSes <= 16 TB this is always zero. AGNOS test surfaces
# (Attempt 90 NVMe agnos-fs p3 = 4 GiB; max realistic iron < 2 TB)
# never exceed this threshold. Guard:
if (ext2_desc_size == 64) {
    var inode_table_hi = ext2_load32_le(bgdt_off, 40);
    if (inode_table_hi != 0) {
        kprintln("ext2: bg_inode_table_hi != 0 (Phase 6 unlock)", 45);
        return 0 - 1;
    }
}
```

That's the whole implementation. ~25 LOC of actual code change.

## 4. Test surfaces

**QEMU smoke (added to `scripts/ext2-smoke.sh` as bite E):**

```sh
# 5-image: 64BIT-flagged ext4 partition. Distinct from current
# scenarios because mkfs.ext4 default (which sets 64BIT) must mount.
dd if=/dev/zero of=ext4-64bit.img bs=1M count=64
parted -s ext4-64bit.img mklabel gpt
parted -s ext4-64bit.img mkpart agnos-fs ext4 1MiB 100%
LOOP=$(sudo losetup -fP --show ext4-64bit.img)
sudo mkfs.ext4 -L AGNOS-64BIT -O 64bit,extents,^huge_file,^metadata_csum,^has_journal,^orphan_file,^resize_inode -d /tmp/ext4-seed ${LOOP}p1
sudo losetup -d "$LOOP"
```

Expected boot output:
```
ext2: probe matched backend=2 partition_lba=2048
ext2: mounted (blocksize=4096, inode_size=256, inodes_per_group=8192, desc_size=64)
```

**Iron Attempt 91 (cycle close)**: existing NVMe `agnos-fs` p3 was carved with `-O ^64bit` for Phase 4 validation. For Attempt 91 the user re-formats with default mkfs.ext4 (i.e. drops `-O ^64bit`) — fresh carve, ASCII `hello.txt` seed. No new iron surface vs Attempt 90; reuses [`ext2-iron-burn-audit.md`](ext2-iron-burn-audit.md).

## 5. Success rubric

- **Full PASS**: 64BIT-flagged ext4 image mounts (`ext2: mounted` with `desc_size=64`), `ls /` returns expected dirent list byte-exact, `cat /<seed>` returns seed content byte-exact. Storage trio unaffected.
- **Partial — _hi guard fires**: build runs `bg_inode_table_hi != 0 (Phase 6 unlock)` against a real iron FS. Means the test partition is > 16 TB OR the kernel-side image carving used non-zero high bits. Investigation: `dumpe2fs -h <image>` and check `Inode table` line of `Group 0`. Unlikely on archaemenid's 2 TB NVMe.
- **Partial — desc_size > 64**: refused with clear message. Means a forward-compat ext4 variant that AGNOS doesn't yet understand. Defer.
- **FALSIFIED**: kernel hangs / faults / can't reach shell. Triage per other iron arcs.

## 6. Out-of-scope for Phase 5 (Phase 6+ horizons)

- Real 64-bit block# math throughout (`_hi` fields combined into 64-bit values). Only needed for FSes > 16 TB; defer until a real iron consumer surfaces.
- HUGE_FILE feature (block-pointer interpretation as 512-byte sectors instead of blocks). Independent of 64BIT; not currently enabled by `mkfs.ext4` defaults.
- META_BG support (BGDT spread across non-contiguous blocks). Required for >256 TB FSes; effectively impossible on archaemenid silicon.

## 7. Audit disposition

- **Cyrius edits**: zero. The compiler / stdlib is untouched.
- **Cross-repo touches**: this doc + `agnos/kernel/core/ext2.cyr` + `agnos/scripts/ext2-smoke.sh` (bite E).
- **Iron burn**: Attempt 91 at cycle close, no new validation surface vs 1.31.6, reuses `ext2-iron-burn-audit.md`.

Per [`feedback_redesign_dont_reinvent`](../../../.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_redesign_dont_reinvent.md): four-source converged. Per [`feedback_iron_burns_block_other_work`](../../../.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_iron_burns_block_other_work.md): audit landed before code lands.
