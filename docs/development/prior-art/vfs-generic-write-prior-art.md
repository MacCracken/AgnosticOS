---
name: VFS generic-write lift — prior art + arc plan
description: Multi-source VFS design survey + AGNOS current-state asymmetry + the 1.39.x bite ladder for lifting the shell write/dir verbs off the hardcoded ext2 path onto a generic per-filesystem dispatch
type: prior-art
---

# VFS Generic-Write Lift — Prior Art + Arc Plan (1.39.x)

> Companion to [`ext4-jbd2-prior-art.md`](ext4-jbd2-prior-art.md), [`ext4-extent-alloc-prior-art.md`](ext4-extent-alloc-prior-art.md), [`fat-family-prior-art.md`](fat-family-prior-art.md). Same discipline: derive the converged shape from multiple sources, port to AGNOS conventions, ladder it into small QEMU-`fsck`-clean bites, then a user-driven iron burn. Per [[feedback_redesign_dont_reinvent]] Linux is **one source of many**, never the singular reference.

## 0. Why this arc (the base-maturity third leg)

The "base" maturity exit is **FS-crash-safe + exec-from-disk**. Two of the three crash-safety legs landed and are iron-validated:

- **1.37.x** ext4 extent allocation (iron Attempt 1373).
- **1.38.x** jbd2 journaling (iron `13810_*` re-burn — write + 100-tx stress + power-cut recovery clean).

Both made **ext2/4** durable. But AGNOS also carries a **second writable filesystem family — FAT/exFAT** (1.34.x arc, `fsck`-clean in QEMU). The shell can only *reach* one of them. The 1.39.x lift makes the shell's write/dir verbs filesystem-agnostic: the verb operates on whichever filesystem backs the target path, through one dispatch layer, instead of being hardwired to ext2.

This is the abstraction the two writable FS families "earn" by both existing — exactly the point where a generic VFS write path stops being premature and starts being justified (the [*what-justifies-a-stdlib-foldin*](../articles/what-justifies-a-stdlib-foldin.md) gate, applied to a kernel abstraction: ≥ 2 real consumers).

## 1. AGNOS current state (the asymmetry to remove)

Mapped from the kernel 2026-05-28 (agnos 1.39.0). Files: `kernel/core/vfs.cyr` (258 LOC), `kernel/core/ext2.cyr` (5,212), `kernel/core/fatfs.cyr` (1,560), `kernel/core/exfat.cyr` (1,231), `kernel/user/shell.cyr` (1,059).

**`vfs.cyr` is an fd-*type* dispatcher, not a filesystem abstraction.** `vfs_read`/`vfs_write` switch on a `VfsType` tag (`VFS_DEVICE` / `VFS_MEMFILE` / `VFS_PIPE` / `VFS_EXT2_FILE` / …). Only `VFS_EXT2_FILE` is tied to a real on-disk FS; **FAT files are slurped into a ≤4 KiB buffer and wrapped as `VFS_MEMFILE`** (`fatfs_open` → `vfs_create_memfile`), so they're read-once snapshots, not live files, and there is no `VFS_FAT_FILE` write arm.

**Mount model = independent globals, no table.** `ext2_active`/`ext2_backend`/`ext2_partition_first_lba`, `fatfs_active`/`fat_backend`/`fat_partition_first_lba`, `exfat_active`. If two mount, both are "active"; the shell just *always tries ext2 first*. There is no notion of "the FS that owns this path."

**The real seam is the shell verbs.** Every write/dir verb opens with `if (ext2_active == 0) { …error… }` then calls `ext2_*` directly:

| Verb | Guard (shell.cyr) | Calls | Reaches |
|------|-------------------|-------|---------|
| `ls` | `ext2_active==0` (366) | `ext2_print_dir` | ext2 only |
| `cat` | tries ext2 (319) else initrd | `ext2_open`→VFS / `initrd_open` | ext2 + initrd; **FAT ignored** |
| `cd`/`pwd` | `ext2_active==0` (92) | `ext2_path_lookup` | ext2 only |
| `touch` | `ext2_active==0` (481) | `ext2_create` | ext2 only |
| `rm` | `ext2_active==0` (493) | `ext2_unlink` | ext2 only |
| `mkdir` | `ext2_active==0` (504) | `ext2_mkdir` | ext2 only |
| `rmdir` | `ext2_active==0` (515) | `ext2_rmdir` | ext2 only |
| `mv` | `ext2_active==0` (529) | `ext2_rename` | ext2 only |
| `echo >` | `ext2_active==0` (670) | `ext2_create`+`ext2_write_at` | ext2 only |
| `sync` | `ext2_active==0` (661) | `ext2_sync` | ext2 only |

**FAT/exFAT are unreachable from the shell** — not even `cat`. The 1.34.x write code (`fatfs_create`/`fatfs_write_file`/`fatfs_delete`/`fatfs_truncate`, `exfat_*` equivalents) exists and is `fsck`-clean in its own smokes, but nothing in the verb layer calls it.

### Per-FS backend op inventory (what the dispatch will sit on top of)

| Op | ext2 (`ext2.cyr`) | FAT (`fatfs.cyr`) | exFAT (`exfat.cyr`) |
|----|-------------------|-------------------|----------------------|
| path→handle | `ext2_path_lookup` (2717) → inode# | `fatfs_find_root` (name) | `exfat_find` (name) |
| open (read) | `ext2_open` (2806) → VFS_EXT2_FILE | `fatfs_open` (448) → VFS_MEMFILE | `exfat_open` (526) |
| read_at | `ext2_read_at` (1844) | `fatfs_read` (472, cluster) | `exfat_read` (253) |
| write_at | `ext2_write_at` (2916) | `fatfs_write_file` (697, by name) | `exfat_write_file` (919) |
| create | `ext2_create` (2247) | `fatfs_create` (679) | `exfat_create` (827) |
| unlink | `ext2_unlink` (2268) | `fatfs_delete` (790) | `exfat_delete` (1025) |
| mkdir | `ext2_mkdir` (2346) | *(dir-create — confirm)* | *(confirm)* |
| rmdir | `ext2_rmdir` (2389) | *(confirm)* | *(confirm)* |
| rename | `ext2_rename` (2500) | *(none — likely delete+create)* | *(none)* |
| truncate | `ext2_truncate_zero` (2995) | `fatfs_truncate` (842) | `exfat_truncate_zero` (1057) |
| readdir | `ext2_print_dir` | *(FAT root walk — confirm)* | *(confirm)* |

**Shape mismatch to bridge**: ext2 is **inode-handle based** (`(dir_ino, name)` → `ino`); FAT/exFAT are **name/cluster based** (most ops take a flat filename). The generic layer needs an **opaque file handle** = `(fs_id, ino_or_cluster, …)` and a generic `(parent_handle, name)` create/unlink contract that each backend satisfies — FAT's "by name in root" becomes "by name in parent-cluster."

## 2. Prior art (multi-source)

**Kleiman, "Vnodes: An Architecture for Multiple File System Types in Sun UNIX" (USENIX 1986)** — the founding design. Splits the FS-independent `vnode` (generic file handle) from FS-dependent private data, with a `vnodeops` op-vector. The `VFS` object represents a *mounted* filesystem with `vfsops` (mount/unmount/root/sync). **This is the canonical decomposition AGNOS is converging toward.** Two objects: *mount* (a mounted FS instance) and *vnode* (a file within it).

**4.4BSD / FreeBSD `vnode` + `VOP_*`** — `struct vnode` carries `v_mount` (back-pointer to mount) + `v_data` (FS-private) + `v_op` (op vector). Operations are `VOP_LOOKUP`, `VOP_CREATE`, `VOP_REMOVE`, `VOP_MKDIR`, `VOP_RMDIR`, `VOP_RENAME`, `VOP_READ`, `VOP_WRITE`. Namei (path resolution) is generic and calls `VOP_LOOKUP` per component. **Lesson**: path resolution belongs in the generic layer; each FS only resolves *one component within one directory*.

**Linux VFS** — three op-vectors: `file_operations` (read/write/llseek on an open file), `inode_operations` (create/link/unlink/mkdir/rename on a directory inode), `dentry`/dcache (path-component cache). `super_block` = mounted FS. Heavier than AGNOS needs (no dcache, no negative dentries at this stage). **Lesson**: separate the *open-file* ops (read/write/seek) from the *directory/namespace* ops (create/unlink/mkdir/rename) — they have different lifetimes.

**Plan 9 9P** — every FS is a server speaking one protocol (`Twalk`/`Topen`/`Tcreate`/`Tread`/`Twrite`/`Tremove`). Radically uniform; the "op vector" is the wire protocol. **Lesson (aspirational, not now)**: a single narrow op set can cover every FS; resist per-FS special-case verbs.

**xv6 / teaching kernels** — confirm the *minimum viable* set: `namei`, `dirlookup`, `ialloc`/`iupdate`, `writei`/`readi`, `dirlink`. Useful as the floor: AGNOS doesn't need the full BSD VOP surface to lift the shell verbs.

### Converged shape

Two generic objects + a small op set dispatched by **filesystem tag** (not function-pointer vtable — see §3):

- **mount** = `(fs_id, backend, partition_first_lba, write_ok)` — replaces the scattered `*_active` globals with one small table.
- **vfile handle** = `(fs_id, ino_or_cluster, pos, size, parent_hint)` — the generic open-file/dirent handle.
- **generic ops** (each a `vfs_*` that switches on `fs_id`): `vfs_path_lookup`, `vfs_open`, `vfs_read_at`, `vfs_write_at`, `vfs_create`, `vfs_unlink`, `vfs_mkdir`, `vfs_rmdir`, `vfs_rename`, `vfs_readdir`, `vfs_sync`.
- **generic path resolution** owns the component walk; each backend only resolves one component in one directory.

## 3. AGNOS design decisions (proposed)

1. **Tag-dispatch, not function-pointer vtables.** Cyrius v6.x has closures, but the existing `vfs.cyr` already dispatches by enum if-chain, and AGNOS idiom prefers explicit enum dispatch over fn-ptr tables (cf. [[feedback_language_extension_invasiveness]] — keep the language surface small; an indirect-call vtable in a freestanding kernel is more failure surface than a `if (fs_id == FS_EXT2) …` chain). Each `vfs_*` op is a thin switch over `FsId { FS_EXT2, FS_FAT, FS_EXFAT }`.
2. **Opaque file handle bridges the inode/cluster mismatch.** A `vfile` packs `(fs_id, primary_id, pos, size, parent_id)` where `primary_id` is an ext2 inode# OR a FAT/exFAT first-cluster. Backends interpret their own field. This subsumes today's `VFS_EXT2_FILE` and retires the FAT-as-`VFS_MEMFILE` hack (FAT files become live, streamable, writable).
3. **Generic path resolution; per-component backend lookup.** `vfs_path_lookup` splits the path and calls a per-FS *one-component* resolver, so multi-component `cd a/b/c` works uniformly and FAT subdirectories become reachable.
4. **Single mounted FS per arc-start; multi-mount namespace deferred.** Today both can mount but the shell assumes one. The lift keeps a **primary FS** (the one the shell's CWD lives on) and routes verbs to it; a real mount-point namespace (`/mnt/usb`) is a *later* bite, not the kickoff — the immediate win is "every verb works on whichever single FS is mounted," not multi-FS mountpoints.
5. **Preserve the iron-validated ext2 path byte-for-byte where possible.** The dispatch wraps the existing `ext2_*` calls; the ext2 write/journal path is not re-touched. Regression bar: ext2-write + ext-extent + jbd2 smokes stay green and byte-identical behavior.

## 4. Bite ladder (Claude-determined structure per the standing delegation; user tags each cut)

**Read-first, single-primary-FS** — user-chosen at the 1.39.x kickoff (2026-05-28). Read-side leads because it's additive and zero-risk to the iron-validated ext2 write/journal path, and it establishes the dispatch idiom the write bites reuse — mirroring how 1.38.x went probe/read before write. The mount-registry refactor is **not** its own bite; it folds in incrementally as bites need it.

| Bite | Cut | Scope | Smoke gate | Status |
|------|-----|-------|------------|--------|
| **1** | 1.39.1 | **Generic read dispatch — `cat` reaches FAT/exFAT.** `vfs_open_secondary` tries fat → exfat → initrd; `sh_cmd_cat` routes its ext2-miss fallback through it. | `fat-smoke` drives `cat CATTEST.TXT` via `sh_exec` → content in log; ext2 `cat` (W4b) no-regression | ✅ **DONE** — `VFS-CAT-FAT-OK` gate green; build 993,088 B; check 11/11 / test 4/4 |
| **2** | 1.39.2 | **Generic `ls`/readdir.** `vfs_print_dir_secondary` dispatch; `ls` lists FAT/exFAT root. Converted `fatfs_ls` serial→FB; added `exfat_print_dir` with name reconstruction (mirror of `exfat_find`). | `fat-smoke` `ls` → `CATTEST.TXT` name; `exfat-smoke` dispatch-clean (+ name under `EXFAT_SEED`) | ✅ **DONE** — both gates green; build 994,824 B; check 11/11 / test 4/4 |
| **3** | 1.39.3 | **Generic create/write.** `vfs_create_secondary`+`vfs_write_secondary`; `touch` + `echo >` reach FAT/exFAT. Added non-ESP-preferring secondary selection (boot ESP vs data partition). | per-FS `fsck`-clean after write | ✅ **DONE** — fat-write + exfat-write shell gates green, `fsck` clean both; build 997,560 B; check 11/11 / test 4/4 |
| **4** | 1.39.4 | **Generic delete — `rm` across FSes.** `vfs_delete_secondary` over `fatfs_delete`/`exfat_delete`. **Confirmed**: FAT/exFAT have `delete` but **no `mkdir`/`rmdir`** → `rm` ships here, dir-create splits to bite 5. | per-FS `fsck`-clean after rm | ✅ **DONE** — fat-write + exfat-write `rm` gates green, `fsck` clean; build 998,312 B; check 11/11 / test 4/4 |
| **5** | 1.39.5 | **FAT `mkdir`/`rmdir` — new backend capability.** `fatfs_mkdir` (alloc cluster, init `.`/`..`, publish `0x10` dirent), `fatfs_rmdir` (dir + empty check, reuse `fatfs_delete` teardown), `fatfs_dir_is_empty` + `vfs_mkdir_secondary`/`vfs_rmdir_secondary`. First bite that *adds* capability, not just dispatch. | `fat-write` `mdir` descends `SHKEEP`, `SHRMD` gone, `fsck` clean | ✅ **DONE** — 31/31 fat-write gates green; build 1,002,800 B; check 11/11 / test 4/4 |
| **6** | 1.39.6 | **exFAT `mkdir`/`rmdir`.** `exfat_mkdir` (alloc+zero cluster, emit Directory dir-set, NoFatChain), `exfat_rmdir` (dir+empty check, reuse `exfat_delete`); `exfat_emit_set` gained a `fattr` param; `vfs_*_secondary` exFAT arm. | `exfat-write` mkdir find-back + rmdir gone + `fsck.exfat` clean | ✅ **DONE** — exfat-write gates green; build 1,005,184 B; check 11/11 / test 4/4 |
| **7** | 1.39.7 | **`mv` (rename) + `sync` on FAT/exFAT.** `fatfs_rename` (in-place dirent rewrite), `exfat_rename` (re-emit dir-set at same clusters + soft-delete old), `vfs_rename_secondary`/`vfs_sync_secondary` (sync = `blk_flush`). Neither FS has atomic rename; both content-preserving (no copy). | `fat-write`/`exfat-write` rename + `fsck` clean | ✅ **DONE** — both gates green; build 1,008,816 B; check 11/11 / test 4/4. **Full verb set now works on FAT+exFAT.** |
| **8** | 1.39.8 | **Mount-registry consolidation + arc-close hardening + iron pre-audit.** (8a) Folded the seven duplicated non-ESP-preference chains behind one `vfs_secondary_select()` — the policy now lives once. (8c) Bounds/ingress review: re-derived clean on every backend buffer (`exfat_set_buf[80]`=640 B ≥ 608 B max set; dir buffers = one sector; `exfat_name_buf` 256 B w/ `<255` guards); added `vfs_sec_name_ok` (1..255) at the generic seam, bounding `fatfs_build_83`'s unbounded dot-scan + backstopping the exFAT create/mkdir entries that carried no namelen guard. (8d) Iron pre-audit rubric written → [`iron-nuc-zen-log.md#tracker-139-cycle`](iron-nuc-zen-log.md#tracker-139-cycle). **Subdir paths split out to bite 9** (Large effort, ~14 fns; user-chosen split 2026-05-28). | all smokes green (check 11/11, test 4/4, fat/exfat read+write + ext2-write regression all PASS, `fsck` clean) | ✅ **DONE** — build 1,008,816 → 1,007,696 B |
| **9** | 1.39.9 | **FAT/exFAT subdir paths in the verbs.** Removed the last FAT/exFAT-vs-ext2 asymmetry. Pure backend work — the shell already passes full paths, the backends just ignored the slashes. **9a (FAT)**: `fatfs_resolve_parent` path-walk + `fatfs_find_in_dir`/`fatfs_find_free_slot_in_dir` (sentinel `dir_clus==0`=root → delegates to the existing root finders, so bare names stay byte-identical); wired open/create/write/delete/mkdir/rmdir/rename; `..` now points at the real parent. **9b (exFAT)**: same via `exfat_resolve_parent` + `_in(start_clus,…)` wrappers over find / dir-end-index / cluster-for-index / append-set / emit-set (root-named fns kept as thin wrappers). `mv` bounded to **same-parent** (cross-directory move is a follow-on — both backends reject differing parents). | per-FS `fsck`-clean after subdir create/write/cat/rm/mkdir/mv | ✅ **DONE** — subdir scenarios added to both write smokes (FAT 4 new gates, exFAT 4 new gates); all green + `fsck` clean; ext2 regression PASS; build 1,007,696 → 1,014,528 B. **Functional verb surface complete on FAT+exFAT incl. subdirs.** |
| **iron** | — | User-driven burn: every verb against the real agnos-fs (ext2) **and** a FAT/exFAT volume on archaemenid; host `fsck` clean both. **Rubric written at 8d** → [`#tracker-139-cycle`](iron-nuc-zen-log.md#tracker-139-cycle); test-surface fork (brick-safe USB data stick vs. boot-ESP write) is the user's call. | per the tracker-139 rubric | pending user burn |

Backend-surface confirmed (2026-05-28): FAT/exFAT have open/read/write/create/delete/truncate but **no dir-create** (`mkdir`/`rmdir`) — bite 5 adds it. Readdir was added at bite 2 (`fatfs_ls` FB + `exfat_print_dir`).

## 5. Non-goals (this arc)

- Multi-mountpoint namespace (`/mnt/...`), mount/umount verbs — deferred; single primary FS for now.
- dcache / dentry caching — premature (single-threaded, small FS).
- NTFS / squashfs read backends — separate roadmap rows.
- exec-from-disk — the *other* base-exit leg, its own arc.

---

*Drafted 2026-05-28 at the 1.39.x kickoff. Bite structure is Claude-determined per the standing delegation; releases are user-tagged. Update in place as bites land.*
