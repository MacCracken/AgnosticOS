# ext4 JBD2 Journaling — Design + Multi-Source Prior-Art Audit

> **Status**: design — drives the agnos **1.38.x** arc (the second of the heavy big-write cycles, opened 2026-05-28). 1.33.x added indirect-mapped WRITE, 1.37.x added extent-allocation WRITE, both gated on `e2fsck -fn` clean for the *committed* state. Neither protects against a yanked power **mid-update**: a multi-block metadata change (extent-tree split + inode update + bitmap update) can tear, leaving the FS inconsistent until `e2fsck` repairs it. ext4's answer is JBD2 — write the multi-block metadata change to a *separate log file* first, then apply once the log entry is durable; on mount, replay any committed-but-not-applied log entries. Companion to [`ext2-ext4-write-prior-art.md`](ext2-ext4-write-prior-art.md) (no-journal ordered-write story) + [`ext4-extent-alloc-prior-art.md`](ext4-extent-alloc-prior-art.md) (the extent path JBD2 will eventually wrap).
>
> **Created**: 2026-05-28.

## 1. Scope + the case that forces it

A default `mkfs.ext4` filesystem ships with `has_journal` (compat feature bit 0x0004) and a journal inode (typically inode 8) containing a 32 MiB journal file. Linux refuses to mount such a FS *read-write* without an active jbd2; if the journal has uncommitted entries (unclean shutdown), Linux replays them before honoring any new writes. **AGNOS currently ignores the journal entirely** — the W2 gate at 1.33.0 didn't check `has_journal`; 1.33.1's metadata_csum+64bit write lift didn't add journal awareness. So AGNOS's writes to a default partition land *outside* the journal model — fine when nothing crashes, but: (a) a yanked power mid-write tears, (b) a journal Linux left committed-but-not-checkpointed is silently ignored, potentially overwriting it, (c) Linux mounting after AGNOS sees a clean journal head over data Linux wrote, replays nothing, and the most recent Linux state is *gone*.

In scope (1.38.x narrow / writeback-mode): **metadata-only journaling** — journal the inode/bitmap/group-desc/extent-tree block writes that 1.33.x + 1.37.x produce; data writes go straight to disk *without* ordering against the metadata commit. Out of scope: `data=ordered` (force data to disk before the metadata commit referring to it) and `data=journal` (data ALSO in the log). Later arcs may widen; the user-directed opening posture is narrow.

The arc starts read-side (probe + replay) before write-side (transaction lifecycle + log write) — AGNOS must be able to replay a journal IT didn't write (Linux-left committed transactions) before it ever writes one itself. Mounting a Linux-written FS with unreplayed transactions and writing fresh data to it would corrupt the FS in a way `e2fsck` couldn't recover.

## 2. On-disk layout

The journal is a regular file referenced by `s_journal_inum` (superblock byte offset 224, u32). A typical 32 MiB journal at 4 KiB blocks = 8192 journal blocks. The first block is the **journal superblock**; the rest hold descriptor / commit / revoke / data blocks in transaction groups.

**Journal superblock** (`struct journal_superblock_s`, big-endian throughout — JBD inherited Tweedie's bigendian-on-disk choice from ext3):
```
0x00 h_magic       u32be = 0xC03B3998 (JFS_MAGIC_NUMBER)
0x04 h_blocktype   u32be = 4 (V2 superblock; 3 = V1)
0x08 h_sequence    u32be   transaction sequence number of this block

0x0C s_blocksize   u32be   journal block size (must match FS block size)
0x10 s_maxlen      u32be   total journal length in blocks
0x14 s_first       u32be   first block of the log (usually 1, skipping the superblock)
0x18 s_sequence    u32be   first commit ID expected on next mount
0x1C s_start       u32be   block where this transaction starts (0 = empty journal)

0x20 s_errno       u32be
0x24 s_feature_compat / incompat / ro_compat (each u32be)
0x30 s_uuid[16]
0x40 s_nr_users    u32be
0x44 s_dynsuper    u32be
0x48 s_max_transaction / s_max_trans_data (u32be each)
0x50 s_checksum_type u8 / 3 reserved
0x54 s_padding[42]  u32be
0xFC s_checksum    u32be   crc32c over [0..0xFC] when checksum_type=4
0x100..end_of_block: s_users[16][users]
```
**Empty journal** ⇒ `s_start = 0`; the entire log is consumed (cleanly unmounted). **Non-zero `s_start`** ⇒ there are committed-or-running transactions starting at that block, ending wherever the on-log walk hits a malformed descriptor or runs off the head.

**Descriptor block** (`h_blocktype = 1`, V2 has csum):
```
0x00 h_magic     u32be = 0xC03B3998
0x04 h_blocktype u32be = 1
0x08 h_sequence  u32be   transaction ID

0x0C tags[]      array of journal_block_tag_s entries until h_magic-tail or block end
```
Each tag (V3 with 64bit+csum, length depends on flags):
```
t_blocknr      u32be    low 32 bits of FS block this log entry will be written to
t_flags        u16be    bit 0=ESCAPE, bit 1=SAME_UUID, bit 3=LAST_TAG, bit 4=BLOCK_TAG_CSUM_V3
t_checksum     u16be    crc32c lo-16 of [seed=h_sequence][block_data], 0 if BLOCK_TAG_CSUM_V3 not set
t_blocknr_high u32be    high 32 bits (only if 64bit incompat feature set)
[16 bytes uuid if !SAME_UUID]
```
After the tags, the descriptor block is followed by **N data blocks** in order — one per non-LAST_TAG entry, each a full FS block being the new contents of `(t_blocknr_high << 32) | t_blocknr`. The block following the last data block can be another descriptor (chain continues) OR a commit block (transaction ends).

**Commit block** (`h_blocktype = 2`):
```
0x00 h_magic     u32be = 0xC03B3998
0x04 h_blocktype u32be = 2
0x08 h_sequence  u32be

0x0C h_chksum_type u8        1=CRC32, 4=CRC32C
0x0D h_chksum_size u8        4 for CRC32/CRC32C
0x0E h_padding[2]
0x10 h_chksum[8]   u32be[]   payload-chksum (first slot used, rest zero)
0x18 h_commit_sec  u64be
0x20 h_commit_nsec u32be
```
The commit block's presence + valid checksum is the *atomicity gate* — replay applies all data blocks for sequence `N` iff the commit block for `N` is found and its `h_chksum[0]` matches `crc32c(seed=uuid+sequence, descriptor+data_blocks)`. No commit block ⇒ transaction torn ⇒ skip + halt replay.

**Revoke block** (`h_blocktype = 5`): tells replay to NOT re-apply earlier transactions' writes to specific blocks. Used when ext4 frees + reuses a metadata block as data — the freed-block's old metadata content must not get replayed over the new data.

```
0x00 h_magic / h_blocktype=5 / h_sequence (same header)
0x0C r_count       u32be    total size including header
0x10 r_blocks[]    u64be[]  blocks to revoke (u32be if !64bit)
```

## 3. Multi-source prior art (the converged shape)

- **Linux `fs/jbd2/`** (canonical, ~10 KLOC): `transaction.c`, `commit.c`, `recovery.c`, `journal.c`, `revoke.c`, `checkpoint.c`. The reference for everything. Tangled with `kthreadd` (`jbd2/<dev>` kernel thread per FS), `wait_event`-based async commit, generic-block-layer barriers. **We take the SHAPE — descriptor → data → commit; replay state machine — not the thread/IO machinery.**
- **Stephen Tweedie's *Journaling the Linux ext2fs Filesystem*** (1998 LinuxExpo, [paper](http://e2fsprogs.sourceforge.net/journal-design.pdf)) — the original ext3 journaling design. Predates jbd2's V2/V3 evolutions but the on-disk grammar (descriptor / commit / revoke) and the atomicity argument are unchanged. **The design-rationale source** when Linux's code answers "what" but not "why."
- **e2fsprogs `e2fsck/recovery.c`** (`journal_recover()`, ~600 LOC): the *userspace* canonical replay. Reads the journal superblock, walks descriptor → data → commit chains, applies confirmed transactions, handles revokes. **The cleanest replay reference** — no kernel-thread / async-IO clutter, pure state-machine logic. AGNOS's replay path should mirror this almost line-for-line in Cyrius.
- **e2fsprogs `debugfs` `logdump` command** (`debugfs/logdump.c`): walks + prints a journal's contents block-by-block. **The reference for our "journal-show" diagnostic**.
- **ext4 wiki — Journal (jbd2) chapter** ([`Ext4_Disk_Layout#The_Journal`](https://ext4.wiki.kernel.org/index.php/Ext4_Disk_Layout#The_Journal)): the on-disk grammar + sequence semantics in one page. Authoritative cross-check against `journal_superblock_s` / `journal_header_t` / `journal_block_tag_s` source layouts.
- **FreeBSD `sys/fs/ext2fs/`** — *does NOT support jbd2*; if it sees `has_journal` + non-empty journal, the FS mounts read-only. Confirms: read-only consumers can ignore the journal *only if the journal is empty (cleanly unmounted)*. The AGNOS opening posture (1.38.1 probe) follows this pattern as a stop-gap before replay lands.
- **NetBSD `sys/ufs/ext2fs/`** — same posture as FreeBSD.
- **Haiku `src/add-ons/kernel/file_systems/ext2/`**: read-only, journal-aware *probe* but no replay. Another data point that probe-without-replay is a legitimate intermediate step.

**Converged replay algorithm** (from e2fsprogs `journal_recover()` + Tweedie §3.4):
1. Read the journal superblock from the journal inode block 0. Validate magic + version + blocksize.
2. If `s_start == 0` → journal is clean, no work to do; mark the FS as clean-mounted, done.
3. Else: walk forward from log block `s_start` reading descriptor → N data blocks → commit (in that grammar). For each complete (descriptor + matching commit) sequence:
   - Validate the commit block's checksum against the descriptor + data payload.
   - For each tag in the descriptor (skipping any block listed in a revoke block of *later* sequence): write the data block to `(t_blocknr_high << 32) | t_blocknr` on the FS device.
   - Advance the sequence counter.
4. On the first malformed sequence (no commit found, magic broken, checksum mismatch) **halt — that's the torn transaction**. Everything before it stays applied; everything from there is discarded.
5. Rewrite the journal superblock with `s_start = 0`, `s_sequence = N+1` (next expected). Issue a FLUSH-CACHE barrier (1.33.5's `ahci_flush_cache`) so the clean-journal state persists.
6. Only AFTER step 5 does the FS become mountable read-write.

**Converged commit algorithm** (the write-side, for later bites):
1. Caller calls `jbd2_log_metadata(blocknr, buf)` for each FS metadata block they want atomically grouped (extent-tree node, inode, bitmap, group desc). Entries accumulate in an in-memory transaction.
2. On `jbd2_commit_transaction()`:
   a. Allocate journal log space (advancing the head, wrapping circularly within `[s_first, s_maxlen)`).
   b. Write the **descriptor block** (sequence ID + tag list).
   c. Write all **data blocks** (copies of the metadata blocks being journaled).
   d. Issue a FLUSH-CACHE barrier — the descriptor + data must be durable before the commit block writes.
   e. Write the **commit block** (with payload checksum).
   f. Issue another FLUSH-CACHE barrier — the commit block must be durable before the in-place metadata writes start.
   g. Apply the metadata blocks to their final FS locations (the "checkpoint").
   h. Update the journal superblock `s_start` past this transaction.
3. The atomicity invariant: a crash between (b)–(e) leaves a torn transaction (replay finds no commit, discards). A crash between (e)–(g) leaves a committed transaction whose checkpoint didn't finish; replay re-applies. Either way, **the FS ends in a consistent state** post-replay.

The barriers in (d) and (f) are the load-bearing safety primitives. Without them, the SSD could reorder writes such that the commit block lands before the data blocks → on-replay the commit looks valid but the data is garbage → replay corrupts the FS. 1.33.5's FLUSH-CACHE work is the foundation that makes jbd2 possible on AGNOS.

## 4. Diff against AGNOS

| Need | Today | Gap |
|------|-------|-----|
| Read superblock | ext2 ✓ | parse `s_journal_inum` + `has_journal` compat feature |
| Read inode | `ext2_get_inode` ✓ | reuse for the journal inode |
| Read journal blocks (file content of journal inode) | `ext2_read_at` ✓ | reuse — the journal IS a regular file under the extent / indirect path |
| Parse journal superblock | none | new — magic 0xC03B3998, big-endian field decode, version/feature check |
| Walk journal log (descriptor → data → commit) | none | new — the on-log state machine |
| Validate commit block checksum (crc32c) | crc32c primitive exists ([from metadata_csum](https://github.com/MacCracken/agnos/blob/main/kernel/core/ext2.cyr)) ✓ | reuse, but with the jbd2-specific seed (uuid + sequence) |
| Replay journal on mount | none | new — applies committed transactions, halts on torn |
| Rewrite journal superblock as clean | `ext2_write_block` ✓ | reuse, after replay |
| FLUSH-CACHE barrier | `ahci_flush_cache` (1.33.5) ✓ | reuse at descriptor / commit / checkpoint boundaries |
| Transaction lifecycle (in-memory) | none | new — `jbd2_log_metadata` / `jbd2_commit_transaction` |
| Write descriptor block | none | new |
| Write commit block w/ payload checksum | none | new |
| Apply checkpoint (in-place metadata writes) | `ext2_write_block` ✓ | reuse |
| Revoke handling | none | new — track revoked blocks per transaction in a small in-memory set |
| Route `ext2_write_at` metadata through journal | direct writes today | new — the integration bite; behind a feature flag during ramp-up |
| Mount refusal on dirty journal w/o replay | none | new — pre-1.38.3, refuse mount RW if `s_start != 0` |

## 5. Version structure (Claude-determined per the 2026-05-27 delegation)

The arc breaks into byte-of-risk-sized bites; **the user calls releases/tags** — these are *open/cut* targets, not "released."

- **1.38.0 — cycle-open: this audit doc + journal-SB probe + dirty-mount refusal.** Land the audit doc in agnosticos. In agnos: `ext2_jbd2_probe()` at mount — read `s_journal_inum`, read journal block 0, validate magic `0xC03B3998` (BE) + V1/V2 blocktype + blocksize-matches-FS; parse `s_start`/`s_sequence`/`s_maxlen`. Clean (`s_start == 0`) → log + RW; dirty → log + downgrade `write_ok` (RO stays); malformed → refuse mount. Closes the silent-stomp risk on Linux-left journals BEFORE replay (1.38.3) lands. **Matches the FreeBSD/NetBSD/Haiku posture** as a permanent fallback — even after replay lands, the refusal stays as the wire that catches "journal in a corrupt state" cases the replayer can't handle. Smoke (`ext-extent-smoke.sh`): `jbd2: clean journal ino=8 size=1024 seq=1` line emitted; existing depth-2 extent test PASS unchanged. **(Bundled the originally-planned 1.38.0 mount-refusal with the 1.38.1 probe-creation since the refusal needs the probe to decide clean/dirty — split in the original doc was artificial.)**
- **1.38.1 — bite a: deepen the probe + `jbd2` diagnostic verb + dirty-image test infrastructure.** Expand the journal-SB read surface to cover the rest of the V2 layout (`s_first` / `s_feature_compat,incompat,ro_compat` / `s_nr_users` / `s_uuid` / `s_checksum_type,size,checksum`); add **conditional V2/V3 SB checksum validation** (gated on `JBD2_FEATURE_INCOMPAT_CSUM_V2/V3` so older journals still mount); add a `jbd2` shell verb showing the parsed state for diagnostic continuity. Host-side: `scripts/mk-dirty-journal-img.sh` — produces an ext4 image with `s_start != 0` via direct edit of the journal block (s_start field is at offset 28 of the journal-superblock block, big-endian). New `scripts/jbd2-refusal-smoke.sh` boots AGNOS against the dirty image and expects the refusal diagnostic + a successful RO mount. Closes the validation gap that 1.38.0 left (the refusal path was code-only, untested).
- **1.38.2 — bite b: journal-log reader.** Parse descriptor / commit / revoke blocks; walk `[s_start, head)` building an in-memory transaction list with their tag tables. Print a `debugfs logdump`-style trace under a compile gate. Non-mutating. Smoke: dirty an `mkfs.ext4` image via Linux (`echo > /mnt/x; sync`), kill Linux mid-flight, boot AGNOS, expect the dirty log to be parsed + traced correctly.
- **1.38.3 — bite c: replay-on-mount.** Walk the log, apply committed transactions to their FS positions (honoring revokes), halt on the first torn transaction, rewrite the journal superblock as clean, FLUSH-CACHE barrier. Promotes 1.38.0's mount refusal to a successful RW mount on dirty-but-recoverable journals. Smoke: dirty-image scenario → AGNOS mount → expect replay + final `e2fsck -fn` clean.
- **1.38.4 — bite d: transaction lifecycle (in-memory).** `jbd2_begin_transaction` / `jbd2_log_metadata(blocknr, buf)` / `jbd2_commit_transaction` — accumulate metadata blocks in a tx, serialize on commit. No on-disk writes yet; instead emit a trace. Lets the integration shape (bite f) settle without touching the disk.
- **1.38.5 — bite e: journal write path.** `jbd2_commit_transaction` actually writes descriptor + data + commit, with the FLUSH-CACHE barriers at the (d)→(e) and (e)→(g) boundaries. Checkpoints to FS positions, then advances the journal superblock. Validation: `e2fsck -fn` clean on a default `mkfs.ext4` image after a sequence of AGNOS metadata writes goes through the journal.
- **1.38.6 — bite f: integration.** Route the `ext2_write_at` extent-tree-update + inode-write + bitmap-update group through `jbd2_log_metadata` + `jbd2_commit_transaction` instead of direct writes. Behind a compile gate (`EXT2_JBD2_WRITE=1`) first; promote to default when smoke is green.
- **1.38.7 — bite g: crash-injection smoke.** New `scripts/jbd2-crash-smoke.sh`: kill the QEMU process mid-write, restart, expect AGNOS to replay + reach `e2fsck -fn` clean. Runs N=64 iterations across staggered crash points; clean rate = the gate.
- **1.38.8 — bite h: arc-close hardening pass (pre-iron).** Parallels the 1.35.7 arc-close hardening: ingress validation (bounds on `tag.t_blocknr` against FS size, descriptor-block tag-count bounds), csum-mismatch error paths exercised, log-wrap edge cases (a transaction spanning `[s_maxlen-K, s_first+K]` circularly), revoke-table set-cap bounds. NO new functional surface; review-and-stress only. Closes with the **iron-burn rubric doc** in agnosticos for the user-driven burn (per [[feedback_iron_burns_block_other_work]] — line-by-line audit before the burn is staged).

**Iron burn** (user-driven, post-1.38.8): real-NAND crash-safety validation on archaemenid — kill power mid-write → reboot → AGNOS replays → host `e2fsck -fn` clean. Parallel to 1.33.1's persist.txt-survives-reboot and 1.37.3's depth-2-survives-reboot. Not bundled into a Claude-determined cut; the burn cycle gets its own version when the user is ready.

(Boundaries will likely collapse/split as the work lands — historically 1.37.x's depth-1/multi-leaf/depth-2 split cleaner than the plan, networking's r8169 RX took 5 bites instead of the planned 2. The above is the floor, not the contract.)

## 6. Safety / commit order

The atomicity argument has three barriers (1.33.5 `ahci_flush_cache` is the primitive):
1. **Descriptor + data blocks → barrier → commit block** — guarantees the commit block can't outrun the data it commits.
2. **Commit block → barrier → in-place checkpoint** — guarantees a crash post-commit-pre-checkpoint leaves a replayable journal entry, never a half-applied checkpoint.
3. **Checkpoint complete → barrier → journal superblock `s_start` advance** — guarantees the journal-clean state doesn't outrun the writes it covers.

Without all three, an SSD's write reordering can leave the FS in a state where replay either misses or double-applies changes. The barriers are the load-bearing safety primitives; they were *prerequisite* work (1.33.5) before jbd2 became implementable.

A crash at any point yields one of three replay states:
- Pre-descriptor: no log entry exists; nothing to replay; FS state pre-transaction.
- Post-descriptor + data, pre-commit: torn transaction; replay halts at this sequence; FS state pre-transaction.
- Post-commit, pre-/mid-checkpoint: committed transaction; replay re-applies; FS state post-transaction.

`e2fsck -fn` clean post-replay is the gate at every bite.

## 7. Out of scope (deferred)

- **`data=ordered` mode** — force data blocks to disk before the metadata commit that references them. Default Linux ext4 mode; the user-directed *narrow* posture for 1.38.x is metadata-only. May open as 1.38.9+ or a later own-arc if dogfooding surfaces the need.
- **`data=journal` mode** — also log data blocks. Slowest, strongest. Niche.
- **Async commit / kernel-thread separation** — Linux runs `jbd2/<dev>` as a separate kthread; on AGNOS's single-threaded cooperative model, commit is synchronous in the calling context. Multi-threading is a future arc per [[project_multithreading_future_arc]]; the async-commit lift waits for it.
- **Checkpoint pressure / log-fill back-pressure** — Linux throttles dirtiers when the journal fills past a watermark. At AGNOS's size + workload, the 32 MiB default journal won't fill in any realistic scenario in the 1.38.x window. Defer until iron data justifies it.
- **Journal-superblock metadata_csum** — the V2 superblock has `s_checksum` (crc32c); we'll validate it on read but not necessarily recompute on every write (Linux only writes the superblock at clean-shutdown, mount, and growfs). Worth a bite if the validation gap shows up in practice.
- **External journal device** — Linux supports putting the journal on a separate block device. Single-disk AGNOS use cases don't need this; deferred indefinitely.
- **Online resize** — `resize2fs` on a journaled FS extends the journal in place. AGNOS doesn't grow filesystems online today; deferred.
