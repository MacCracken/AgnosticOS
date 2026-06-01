---
name: metadata_csum WRITE — iron-burn readiness audit
description: Pre-burn line-by-line readiness for the 1.33.1 W5 iron burn (write a real default-mkfs.ext4 agnos-fs partition on archaemenid)
type: audit
---

# metadata_csum WRITE — iron-burn readiness audit (agnos 1.33.1)

> **Status: NOT auto-proposed.** Per [[feedback_iron_burns_block_other_work]] this audit lands BEFORE any burn is suggested; the user drives the burn when ready. Burns block the user's other archaemenid work, so the bar is "QEMU has proven everything provable in QEMU first." It has — see § 2.

## 1. What changed since the last iron burn (1.33.0, photo `1330_failed_writes`)

That burn confirmed the W2 safety gate refusing write on the real default-`mkfs.ext4` agnos-fs (`ext2w: read-only FS -- write checks skipped`). 1.33.1 implements what a correct writer must maintain so the refusal lifts. **Zero new low-level I/O** — every write still goes through `blk_write` → `nvme_blk_write`/`ahci_blk_write`, iron-validated at USB-MS Attempt 87 + the AHCI demos. The new code is purely ext2 metadata derivation:

- **bite 1** — 64bit BGDT write (lift `incompat 0x80` refusal) + an **extent-write safety guard** (refuse mutating Linux-created extent files/dirs; new AGNOS files are indirect).
- **bites 2-6** — CRC32c (Castagnoli) maintained on every metadata write: superblock `s_checksum`, group-descriptor `bg_checksum`, block + inode bitmap csums, inode `i_checksum_lo/hi`, directory-leaf `det_checksum` + the 12-byte tail.
- **bite 7** — drop `metadata_csum` (0x400) from the refusal mask + the `bg_itable_unused` accounting fix.

## 2. Why it's ready (what QEMU proved, on the EXACT real-partition profile)

The smoke image profile `metadata_csum,64bit,extent` is byte-for-byte the feature set of the user's agnos-fs (default `mkfs.ext4`). Two independent QEMU validations:

1. **Compute-and-compare** (bites 2-6, write gated): every checksum routine reproduced the value `e2fsprogs` had already written on disk — SB, group-desc, block-bitmap, inode-bitmap, inode, dir-leaf all `match`, and the UUID-derived `csum_seed` matched the host. This proves the algorithm against the same code `e2fsck` runs, before a single byte was written.
2. **Full write smoke** (bite 7, write enabled): the complete mutation set — alloc/free, write/sparse/truncate, create/unlink, mkdir/rmdir, shell `echo>`/`touch`/`rm` — ran through the real write path on the checksummed image and the post-boot partition is **`e2fsck -fn` clean (exit 0)**; host `debugfs` reads every persisted file byte-correct. Full image matrix (stripped / 64bit / metadata_csum) all PASS.

**Risk delta QEMU→iron**: the metadata-mutation layer is backend-agnostic (operates on buffers, flushed via the already-iron-proven block writer). The read arc + 64bit BGDT stride were iron-validated on this exact partition at 1.31.7 (Attempt 91). So the residual iron risk is low and confined to "does the proven block writer carry these specific write patterns" — which Attempt 87 already answered for arbitrary LBAs.

## 3. Burn protocol (user-driven; kernel change → `install-usb.sh --update`)

This is a kernel change, so it needs an ESP kernel refresh (`install-usb.sh --update`, ESP-only — the agnos-fs partition is NOT touched by the installer, so the real partition survives), NOT a mount-modify ([[feedback_prefer_mount_modify_over_reflash]] reserves mount-modify for AGNOS-side seed/test edits). `build/agnos` is production (no `EXT2_WRITE_SELFTEST`), **675,152 B, rebuilt 2026-05-25 22:45 against HEAD** — reflects all 7 bites.

**Option A (recommended — minimal, real UX)**: production build, boot on archaemenid, at the shell:
```
echo agnos-1.33.1 > /persist.txt
cat /persist.txt          # expect: agnos-1.33.1
```
power-cycle, boot again:
```
cat /persist.txt          # expect: agnos-1.33.1  (survived the reboot)
```
then pull the drive and on Linux: `e2fsck -fn /dev/<agnos-fs>` → expect **exit 0, no FIXED**.

**Option B (automated, but litters the real partition)**: an `EXT2_WRITE_SELFTEST` build auto-runs the self-test at boot, creating `w3a.txt`/`w4keep.txt`/`w5keep`/`shdir` on the real partition; then host `e2fsck`. Avoid unless HID typing is uncooperative — it writes test files to the partition the user intends to keep.

## 4. Pass / falsification rubric

| Signal | 1.33.0 (last burn) | 1.33.1 PASS | Falsification → meaning |
|---|---|---|---|
| Mount gate | `read-only FS -- write checks skipped` | write self-test runs / verbs succeed | gate still 0 → a feature bit beyond metadata_csum/64bit set (uninit_bg/bigalloc); dump `ro_compat`/`incompat` |
| Create + persist | every verb `failed` | `echo … > /persist.txt` → reboot → `cat` returns it | gone/wrong after reboot → write didn't reach platter, or csum-rejected on remount |
| Host fsck | n/a (RO) | `e2fsck -fn` exit 0, no FIXED | "checksum invalid" on a structure → that class's CRC32c wrong (localize: SB/group-desc/bitmap/inode/dir); "unused inodes area" → itable_unused regression |
| mkdir/rmdir | n/a | `mkdir /d` → `echo x>/d/f` → reboot → intact + fsck clean | link/dir-tail accounting bug |

## 5. Out of scope (deferred, NOT blockers)

- **Overwriting Linux-created (extent-mapped) files** — refused by design (bite-1 guard); extent *allocation* is a later cycle. New files (the demo→base path) are indirect and fully work.
- **`uninit_bg` / `bigalloc`** — still refuse-write (not set by default `mkfs.ext4`).
- **Crash-consistency under power-loss mid-write** — ordered writes (no journal) leave fsck-reclaimable inconsistency, not dangling pointers (audit § 3); a deliberate yank-test is a separate hardening exercise.
