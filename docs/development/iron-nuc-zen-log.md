> **Status**: ▶ **ACTIVE log — the BASE era** (base-hardening software maturity on archaemenid, agnos 1.37.x+). First of the planned **base → server → platforms** log split. Same primary target: NUC AMD **archaemenid** (Beelink SER).
>
> **Log chain**: [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) (MVP 1.0 — boot-to-shell, Attempts 1 – 68, agnos 1.30.9) → [`iron-nuc-zen-log-mvp2.md`](iron-nuc-zen-log-mvp2.md) (MVP 2.0 — networking + filesystem WRITE, 1.30.10 – 1.34.x; r8169 unicast-RX, DHCP, ext2/4 + FAT write burns) → **this file** (base). Consult the archives for any pre-existing root-cause shape recurrence; the **MVP2.0-era FAT/exFAT iron burn is still pending** in mvp2 ([`iron-nuc-zen-log-mvp2.md#tracker-1341-cycle`](iron-nuc-zen-log-mvp2.md#tracker-1341-cycle)).

# Iron Boot Test Log — Base Era

Append-only running log of AGNOS iron-boot work for the **base** phase of the
maturity arc ([[project_agnos_maturity_arc]]: demo → base → server → desktop →
swallow). The **MVP gate** (boot-to-shell with a typeable keyboard) closed at
Attempt 68 (1.30.9); the **MVP 2.0** networking + write era closed with the
1.32.x/1.33.x iron burns. This log covers the **base-hardening** software work
on archaemenid — filesystem depth + the slimming/perf runway:

- **big-write own-cycles** — ext4 **extent allocation** (1.37.x), **jbd2
  journaling** (1.38.x), the **VFS generic-write** lift (1.39.x);
- **kernel-slimming + perf** — font → `kashi`, shell → `agnoshi`, then the
  perf + agnos-2.0 runway (1.40.x – 1.45.x).

**Planned log separations** (user, 2026-05-27): the iron logs split along the
maturity arc — **base → server → platforms**. This is the **base** log; a
**server**-era log opens when server-grade work begins, and the **platform
decades** (1.5x Intel / 1.6x Pi-ARM / 1.7x radios / 1.8x RISC-V — a distinct
per-hardware-target testing surface) get their own **platforms** log(s) rather
than landing here.

**Format** (per [[feedback_retire_attempt_counter_post_mvp]]): new iron-burn
entries headline by **version + subsystem**, not an Attempt-N counter (the
counter is retired post-MVP; past `Attempt N` anchors live in the archives).
Never rewrite past entries; add a clarifying note to a later entry pointing
back. Status is one of `FAIL` / `PASS` / `PARTIAL` / `PENDING`.

---

## Hypothesis & Expectations Tracker — by version cycle

> **Purpose**: reduce session-restart context-reload cost. State.md's "current scope" pointer + this tracker = quick "where are we, what's the open hypothesis, what does the next burn need to show to confirm/falsify it." The chronological per-version narrative stays below in `## Burns`; this section is the **predictive layer**, not a duplicate changelog.
>
> Per [[feedback_iron_burns_block_other_work]] + [[feedback_known_knowledge_first]] + [[feedback_redesign_dont_reinvent]]: each open cycle's hypothesis lists the **falsification criteria** that govern what we do next — never propose a burn without an expected-vs-fallback rubric written here first.
>
> **State.md cycle headers link to these anchors via `iron-nuc-zen-log.md#tracker-1373-cycle` style.** Archived (MVP2.0-era) trackers live in [`iron-nuc-zen-log-mvp2.md`](iron-nuc-zen-log-mvp2.md).

### Tracker: 1.39.x cycle — VFS generic-write lift iron burn (PENDING — the FAT/exFAT shell verbs' first real-hardware touch; folds in the long-pending **1.34.x FAT/exFAT iron burn** carry-forward, [`iron-nuc-zen-log-mvp2.md#tracker-1341-cycle`](iron-nuc-zen-log-mvp2.md#tracker-1341-cycle). Code is QEMU-`fsck`-clean across all four FAT/exFAT read+write smokes; this tracker governs only the iron confirmation. NO auto-run per [[feedback_iron_burns_block_other_work]] — rubric below; the user flashes + burns.) {#tracker-139-cycle}

**Scope.** The 1.39.x arc lifted the shell write/dir verbs off the hardwired ext2 path onto a generic per-FS dispatch ([`vfs-generic-write-prior-art.md`](vfs-generic-write-prior-art.md)): `cat`/`ls`/`touch`/`echo >`/`rm`/`mkdir`/`rmdir`/`mv`/`sync` now reach **FAT32 + exFAT** through `vfs_*_secondary`. 1.39.8 (bite 8) consolidated the seven duplicated non-ESP-preference chains behind one `vfs_secondary_select()` and added the `vfs_sec_name_ok` ingress bound (1..255). This burn validates that the dispatch + both writable backends are byte-valid on real NAND, the same dispositive bar (host-`fsck` clean) as the 1.33.1 ext2 and 1.37.x extent burns. **Root-level verbs only** — FAT/exFAT subdir paths are deferred to 1.39.9, so the burn rubric is root-only.

**Hypothesis.** The FAT/exFAT shell verbs that are QEMU-`fsck`-clean across `fat-write-smoke` + `exfat-write-smoke` will (a) create/write/delete/mkdir/rmdir/rename a bare-named file+dir on a **real FAT32 and a real exFAT volume** on archaemenid, (b) print the `fatw:`/`exfatw:` PASS lines to the **FB** (iron-readable; the selftest uses `kprint`, no serial — [[feedback_no_serial_on_iron]]), (c) keep the writes across a power-cycle, and (d) be **host-`fsck.fat` / `fsck.exfat` clean** after the burn.

**Mechanism — and the test-surface fork (the user's call before the burn).** The shell's FAT/exFAT verbs only fire when `ext2_active == 0` (single-primary-FS: ext2 wins when present). archaemenid's internal agnos-fs **is** ext2, so the verbs are unreachable from a normal shell there. Two ways to exercise them on iron:

- **(a) Compile-gated self-driver (recommended, brick-safe).** Ship a `FATFS_WRITE_SELFTEST=1` (and a second `EXFAT_WRITE_SELFTEST=1`) kernel — the same auto-drivers the QEMU smokes use, which `kprint` `fatw:`/`exfatw:` PASS lines to the FB. The self-driver bypasses the ext2-first gate by calling the backend directly. **Target a separate USB FAT32 / exFAT *data* stick (non-ESP)** — `vfs_secondary_select`'s non-ESP preference picks the data stick over the boot ESP automatically, and the writes never touch the boot path. Two flashes (one per FS) or a combined selftest.
- **(b) Boot-ESP write (NOT recommended).** Writing to the gnoboot boot ESP needs `FAT_ALLOW_ESP_WRITE=1` and risks corrupting the boot volume. Reserve for a throwaway boot medium only.

**Pre-burn state (build is Claude's per [[feedback_build_freshness_is_mine]]; user flashes + tests):**
- The shipped **1.39.8 production kernel** is the plain `sh scripts/build.sh` build (selftest flags are dev-only) — **1,007,696 B**, banner `v1.39.x`, FAT/exFAT verbs present.
- The **burn kernel** is a `FATFS_WRITE_SELFTEST=1` / `EXFAT_WRITE_SELFTEST=1` build (Claude produces on the user's go, once the surface fork is chosen). All four FAT/exFAT smokes + the ext2-write regression are QEMU-green at this cut.
- User flashes `build/agnos` (`install-usb.sh --update`, ESP-only — agnos-fs untouched) + provides the FAT32/exFAT data stick per fork (a).

**Test-item rubric (root-only; per FS — run once on FAT32, once on exFAT):**

| # | Test item | Read-out (FB) | PASS | Falsifies if |
|---|-----------|---------------|------|--------------|
| 1 | Boot to shell on archaemenid | selftest kernel, FB | clean storage trio + GPT + the FAT/exFAT volume mounts (`fat: mounted …` / `exfat: mounted …`) → `AGNOS shell v1.39.x` | hang/panic before mount |
| 2 | `cat` / `ls` reach the volume | `fatr: chain-read OK` / `vfsls:` ls names; exFAT equivalents | read-back byte-exact + dir entry names print | `chain-read FAIL` / no names |
| 3 | `touch` + `echo >` create+write | `fatw: create … rc=0` / `fatw: write … rc=N`; exFAT `exfatw:` | both rc≥0, file present on readback | any `rc<0` / file absent |
| 4 | `rm` delete | `fatw: delete … wrc=0` | entry gone on readback | `wrc<0` / entry persists |
| 5 | `mkdir` / `rmdir` | `fatw: mdir …` descends; dir gone after rmdir | both succeed, empty-check enforced | dir not created / non-empty rmdir succeeds |
| 6 | `mv` rename | `fatw: rename …`; new name present, old gone | content-preserving rename | old persists / content lost |
| 7 | Power-cycle persistence | re-boot, re-read the written files | writes survive | data lost across cold boot |
| 8 | Host `fsck` after burn | `fsck.fat -n` / `fsck.exfat -n` on the stick from Linux | **clean** (no errors) | any fsck error → on-disk structures invalid |

**Falsification summary.** Any `rc<0` from a verb, a missing/extra dirent on readback, lost data across the power-cycle, or a non-clean host `fsck` falsifies "FAT/exFAT writes are byte-valid on real hardware." Test 8 (host `fsck` clean) is the dispositive bar, exactly as for the ext2 (1.33.1) and extent (1.37.x) burns.

**Combined with 1.40.x exec-from-disk.** This VFS burn now rides with the **exec-from-disk** iron burn (1.40.x) as one hardware session — both are base-era exit-leg validations. The full step-by-step manual checklist (FAT/exFAT verbs **and** `run /bin/prog2` in ring 3 on real Zen) lives in [`exec-iron-manual-tests.md`](exec-iron-manual-tests.md); the automated QEMU pre-check for both arcs is `agnos/scripts/sweep.sh` (must be all-green before burning).

### Tracker: 1.38.x cycle — JBD2 journaling iron burn (BURNED 2026-05-28 — read-side PASS @ 1.38.9; write-side commit + 100-tx stress + mid-cycle power-cut recovery all PASS @ 1.38.10 re-burn — **ARC IRON-COMPLETE**) {#tracker-138-cycle}

**Hypothesis (pre-burn).** The JBD2 stack that is QEMU-`e2fsck -fn`-clean across replay + crash smokes would mount-probe, replay, produce a journaled write, and survive power-loss on real NAND — all against the unmodified archaemenid agnos-fs.

**Outcome.** Read-side **CONFIRMED**; write-side **FALSIFIED-as-untestable** by a wrong premise, not a code bug. The real agnos-fs journal is **CSUM_V3 + 64BIT** (`incompat=0x12`, `csum_type=4`/CRC32C) — audit §6's "mkfs.ext4 doesn't enable CSUM_V2/V3 by default" was false (host e2fsprogs 1.47.4 enables `metadata_csum` → CSUM_V3 journal by default). The 1.38.7 narrow-scope guard refused every `commit_tx`, so integration (Test 4) and crash (Test 5) couldn't exercise the write path. **Probe + SB-csum-validate + read-side proven on a real CSUM_V3 journal; baseline e2fsck clean (`fsck_log_1.txt`); nothing corrupted.** Full burn entry below.

**Falsification criteria for the re-burn** (after CSUM_V2/V3 write support lands): integration must show `jbd2: commit_tx: COMMITTED seq=K n_blocks=N` (not the refusal line) + host `e2fsck -fn` clean; crash must show a real DIRTY→replay→clean cycle. Until then the write-side claim stays open. Disposition fork (implement CSUM_V3 write now vs. re-mkfs `-O ^metadata_csum` to validate the existing non-csum path) is the user's call.

**Disposition (2026-05-28): user chose "implement CSUM_V3 write." DONE at agnos 1.38.10** — CSUM_V2/V3 tag/descriptor/commit checksums on both write + replay sides, formats re-derived from `include/linux/jbd2.h` + `fs/jbd2/commit.c`. **Linux-`e2fsck` oracle-validated** (e2fsck replays an AGNOS-format CSUM_V3 journal clean; a corrupted commit csum → "transaction was corrupt"). All five jbd2 smokes re-run on a CSUM_V3 journal (stamped via `mk-dirty-journal-img.py --csum-v3`, mirroring Linux's first-RW-mount stamp): **integration now shows `commit_tx: COMMITTED` where iron showed the refusal**; writepath / tx / replay / crash(4/4) green; `test.sh` 4/4, `check.sh` 11/11. Also fixed a latent legacy-tag field swap (`t_flags`/`t_checksum` offsets) that made pre-1.38.10 AGNOS journals non-Linux-replayable. Detail → CHANGELOG `[1.38.10]` + [`ext4-jbd2-prior-art.md`](ext4-jbd2-prior-art.md) §8.

**Re-burn outcome (2026-05-28, the `13810_*` burn): WRITE-SIDE PASS — every falsification row cleared on real NAND.** Five-boot sequence on the unmodified archaemenid agnos-fs CSUM_V3 journal: boot-1 `production` clean baseline (`jbd2: clean journal ino=8 size=32760 seq=4`, e2fsck clean, journal SB `s_sequence=4` CLEAN); boot-2 `integration` flips the 1389 refusal to **`jbd2-int: commit_tx: COMMITTED seq=4 n_blocks=1 -- checkpoint applied + journal clean` → `integration selftest PASS`** (validate: e2fsck clean, SB `s_sequence=5` CLEAN); boot-3 `crash` runs the stress loop to **`100/100 done` → `stress loop PASS (clean shutdown)`**; boot-4 = the user starts a stress cycle then **cuts power mid-cycle** (the deliberate crash, unphotographed); boot-5 recovers clean — **`jbd2: clean journal ino=8 size=32760 seq=142`**, shell reached, host `e2fsck -fn` clean, journal SB `s_sequence=142` CLEAN. The journal advanced seq 4 → 142 across commit + stress + crash + recovery and landed clean every time. **Crash-safe journaling validated on iron — the 1.38.x arc is COMPLETE.** Photos `13810-agnos-1.38.10-boot{1,2,3,5}-*.jpg` + validate logs folded into the re-burn entry below. Cycle closes at 1.38.11 (cleanup + hardening).

### Tracker: 1.37.x cycle — ext4 extent-ALLOCATION iron burn (OPEN 2026-05-27 — **the extent-write arc's first real-hardware touch, and the first burn of the base era.** The MVP2.0 1.33.1 W5 burn proved *indirect*-mapped inode growth survives a power-cycle on the unmodified default `mkfs.ext4` agnos-fs (`persist.txt` survived). But anything `mkfs.ext4`/Linux creates is `EXTENTS_FL` — a *different* write path. The 1.37.x arc added it: depth-0 append (1.37.0), depth-0→1 grow (1.37.1), multi-leaf depth-1 sibling split (1.37.2), depth-1→2 index-block grow (1.37.3) — **all QEMU `e2fsck -fn`-clean** on default `mkfs.ext4` images. This burn confirms the extent metadata the kernel writes (extent records, `ee_len`/`ee_start_hi`, index entries, leaf+index node `metadata_csum` checksums, `i_blocks`) is valid on real NAND, the same dispositive bar as 1.33.1. **Mechanism: the compile-gated `EXT2_EXTENT_WRITE_SELFTEST` build self-seeds its own extent file** (`ext2_extent_seed_create` creates `/extseed.dat` as an empty `EXTENTS_FL` inode if absent), drives sparse extent writes through depth 0→1→2, and prints the tree shape + PASS to the **FB console** (no serial on iron per [[feedback_no_serial_on_iron]]; FB-readable, deterministic, mirrors the QEMU smoke). So this is **flash-and-test — no host-side mount/seed**. Depth-0/1 covers every realistic file; depth-2 is the completeness ceiling (≈ 1360 extents) the selftest forces. NO burn auto-run per [[feedback_iron_burns_block_other_work]] — rubric below; the user flashes + burns. The depth-2 *code* is done + QEMU-validated (self-seed smoke `e2fsck`-clean); this tracker governs only the iron confirmation.) {#tracker-1373-cycle}

**Hypothesis.** The extent-allocation write path that is QEMU-`e2fsck -fn`-clean via the self-seed smoke (depth 0→1→2) will (a) self-create + grow an `EXTENTS_FL` file on archaemenid's real NVMe NAND, (b) reach depth 2 with the selftest's PASS lines on the FB, (c) keep the written data + extent tree across a power-cycle, and (d) be **host-`e2fsck -fn` clean** after the burn — i.e. real-hardware extent writes are byte-valid, exactly as indirect writes were at 1.33.1.

**Pre-burn state (build is Claude's per [[feedback_build_freshness_is_mine]] — user only flashes + tests):**
- `agnos/build/agnos` is **already the flash-ready selftest kernel** — `EXT2_EXTENT_WRITE_SELFTEST=1` build, **843,624 B**, banner `v1.37.3`, contains `ext-ext: depth-2 PASS` + the self-seed path. Self-seed validated in QEMU (`ext-extent-smoke.sh` PASS: `seeded /extseed.dat` → `final depth=2 size≈11.1 MB` → `e2fsck -fn` clean).
- **No `/extseed.dat` seeding needed** — the kernel self-creates it. The user just flashes `build/agnos` (`install-usb.sh --update`, ESP-only, agnos-fs untouched) and boots.
- *(At tag time the shipped 1.37.3 kernel is the plain `sh scripts/build.sh` production build — the selftest flag is dev-only.)*

**Test-item rubric (one burn covers all):**

| # | Test item | Mechanism / read-out | PASS | Falsifies if |
|---|-----------|----------------------|------|--------------|
| 1 | Boot to shell on archaemenid | selftest kernel, FB | clean storage trio + GPT + `ext2: mounted (blocksize=4096 …)` → `AGNOS shell v1.37.3` | hang/panic before mount |
| 2 | Kernel self-seeds the extent file | FB `ext-ext: seeded /extseed.dat (empty extent file)` then `ext-ext: ino=… extent size0=0` | both lines print (file created `EXTENTS_FL`) | `seed create FAIL` / `seed not extent-mapped FAIL` |
| 3 | Depth-0 + depth-0→1 grow on iron | selftest sparse writes | no `write_at … FAIL`; tree climbs past the inline root | any `ext-ext: write_at lblk=… FAIL` |
| 4 | Multi-leaf + depth-1→2 grow on iron | selftest, FB | **`ext-ext: final depth=2 root_entries=1 size=…`** + **`ext-ext: depth-2 PASS`** + **`ext-ext: append PASS`** | `depth-2 not reached FAIL` / `no sibling leaf formed FAIL` |
| 5 | Persistence across power-cycle | reboot to Linux, `debugfs -R "dump /extseed.dat …"` | file ≈ 11 MB sparse; byte @ offset 8192 (logical block 2) = `0xAB` | data absent / wrong bytes / size collapsed |
| 6 | **Host `e2fsck -fn` clean** (load-bearing gate) | mount/pull agnos-fs on Linux, `e2fsck -fn <part>` | **clean** — real-NAND extent records + leaf/index checksums + `i_blocks` all valid | any e2fsck error (csum mismatch, bad extent, i_blocks off) |

Rows 2 + 4 are the in-system iron evidence; row 6 is dispositive (same as the 1.33.1 after-burn check). **Outcome (Attempt 1373, 2026-05-28): PASS on boot-1, all six rows green; boot-2 surfaced a selftest re-boot idempotency bug (NOT a FS bug — host `e2fsck -fn` clean across both boots). Tracker CLOSED at 1.37.4 (idempotency fix).**

## Burns

### 1.38.x JBD2 journaling iron burn (2026-05-28) — read-side PASS · write-side BLOCKED (real journal is CSUM_V3)

**Build flashed**: 1.38.9, automated 3-flash cadence (`iron-jbd2-prep.sh {production|integration|crash}` + `iron-jbd2-validate.sh`), `install-usb.sh --update` (ESP-only, agnos-fs untouched).

**Boot 1 — `production` (Tests 1 + 6)**: storage trio + GPT + `ext2: mounted (blocksize=4096, inode_size=256, inodes_per_group=8192)` + `ext2: clean journal ino=8 size=32768 seq=4` + `fat: mounted FAT32` clean → DHCP `.151` → `AGNOS shell v1.38.9`. `agnos> jbd2` info verb:
- `jbd2: ino=8 size=32768 blocks blocksize=4096`
- `jbd2: state=clean` · `start=0 first=1 seq=4` · `nr_users=1`
- **`jbd2: features compat=0 incompat=18 ro_compat=0`** ← `incompat=0x12` = `JBD2_FEATURE_INCOMPAT_64BIT (0x2)` + **`JBD2_FEATURE_INCOMPAT_CSUM_V3 (0x10)`**
- **`jbd2: csum_type=4 (validated at mount)`** ← CRC32C; the 1.38.1 SB-csum validation passed against a real CSUM_V3 journal

Host `e2fsck -fn /dev/nvme0n1p2` (`fsck_log_1.txt`): `agnos-fs: 22/1638400 files (4.5% non-contiguous), 148271/6553600 blocks` — **clean.** ✓ Tests 1 + 6 PASS: probe + SB-csum validate + read-side all correct on a real-NAND CSUM_V3 journal.

**Boot 2 — `integration` (Tests 1 + 4)**: clean mount + probe identical. Selftest:
- `jbd2-int: integration selftest begin`
- `jbd2-int: put_inode record through journal (logged 1 metadata blocks)` ← **routing works** (1.38.6 path live on iron)
- **`jbd2-int: commit_tx: CSUM_V2/V3 journal not yet supported (1.38.7) -- aborting`** ← the narrow-scope guard at `ext2.cyr:4247` fired
- `jbd2: abort_tx: dropping 1 pending entries` · `jbd2-int: commit_tx FAIL`

Write-side **never executed** — the guard refused cleanly. Shell still came up.

**Boot 3 — `crash` (Test 5)**: `jbd2-crash: stress loop begin (100 commits, ~3s window)` → first commit hit the same CSUM_V3 guard → `commit_tx FAIL`. Crash-recovery **not exercisable** (no journaled write ever lands to crash on).

**Finding — audit §6 premise FALSIFIED.** [`ext4-jbd2-iron-burn-audit.md`](ext4-jbd2-iron-burn-audit.md) §6 asserted "archaemenid's mkfs.ext4 doesn't enable CSUM_V2/V3 by default." **Wrong.** The real agnos-fs journal is **CSUM_V3 + 64BIT** — modern e2fsprogs (host runs 1.47.4) enables `metadata_csum` by default, which produces a CSUM_V3 journal. The QEMU smoke images used non-csum journals (the `jbd2-refusal-smoke.sh` "no SB csum to recompute" path), so the write-path gap was invisible in QEMU. **Write-side iron validation of the whole 1.38.x arc (commit / checkpoint / replay-of-own-tx) is BLOCKED until CSUM_V2/V3 commit-block + descriptor-tag + data-block checksums are implemented** in the write path.

**Safety win**: the 1.38.7 guard did exactly its job — refused rather than writing a journal that our (or Linux's) replay would reject. Baseline e2fsck stayed clean across the whole burn; nothing was corrupted. Read-side (probe + SB-csum validate + the `jbd2` info verb) is fully iron-proven on a real CSUM_V3 journal.

**Next**: implement CSUM_V2/V3 journal checksums in the write path (port from Linux jbd2 `jbd2_commit_block_csum_set` / `jbd2_descriptor_block_csum_set` / `jbd2_block_tag_csum_set` + e2fsprogs + the JBD2 on-disk-format spec, per [[feedback_redesign_dont_reinvent]]). Regenerate the QEMU smoke FS images with `metadata_csum` so the gap can never hide in QEMU again. Then re-burn integration + crash. Tracker → [`#tracker-138-cycle`](#tracker-138-cycle).

### 1.38.x JBD2 journaling re-burn (2026-05-28, `13810_*`) — WRITE-SIDE + CRASH-RECOVERY PASS 🎯

The dispositive re-burn after 1.38.10 added CSUM_V2/V3 tag/descriptor/commit checksums (write + replay). **Build flashed**: 1.38.10, automated cadence (`iron-jbd2-prep.sh {production|integration|crash}` + `iron-jbd2-validate.sh`), `install-usb.sh --update` (ESP-only, agnos-fs untouched). Five-boot sequence on the **unmodified** archaemenid agnos-fs CSUM_V3 + 64BIT journal:

**Boot 1 — `production`** (`13810_validate_boot1.txt`, photo `…boot1-clean-journal-seq4-e2fsck-clean.jpg`): storage trio + GPT + `ext2: mounted (blocksize=4096, inode_size=256, inodes_per_group=8192)` + **`jbd2: clean journal ino=8 size=32760 seq=4`** + `fat: mounted FAT32` → DHCP `.151` → `AGNOS shell v1.38.10`. Validate: host `e2fsck -fn /dev/nvme0n1p2` clean (`agnos-fs: 22/1638400 files (4.5% non-contiguous), 148271/6553600 blocks`); on-disk journal SB `magic=0xc03b3998 s_start=0 s_sequence=4` → **journal CLEAN**.

**Boot 2 — `integration`** (`13810_validate_boot2.txt`, photo `…boot2-integration-commit-tx-COMMITTED-write-side-pass.jpg`): the line that read the CSUM_V3 refusal at the 1389 burn now reads **`jbd2-int: commit_tx: COMMITTED seq=4 n_blocks=1 -- checkpoint applied + journal clean`** → **`jbd2-int: integration selftest PASS`**. `put_inode` routes, the tx commits to the real CSUM_V3 journal, checkpoint applies, journal returns clean. Validate: e2fsck clean; journal SB `s_sequence=5` CLEAN. ✓ **Write side proven on iron** — the exact falsification row from the 1389 tracker, cleared.

**Boot 3 — `crash`** (photo `…boot3-crash-stress-100-100-pass-clean-shutdown.jpg`): `jbd2-crash:` stress loop with `commit_tx: COMMITTED seq=78..104 n_blocks=1 -- checkpoint applied + journal clean` scrolling, closing on **`jbd2-crash: 100/100 done`** → **`jbd2-crash: stress loop PASS (clean shutdown)`** → `AGNOS shell v1.38.10`. The write path sustains a tight commit/checkpoint cadence against the real journal with no drift.

**Boot 4 — deliberate crash**: the user started a stress cycle, then **cut power mid-cycle** (the real power-loss event; no photo — the box was off).

**Boot 5 — recovery** (`13810_validate_boot5.txt`, photo `…boot5-recovery-journal-seq142-e2fsck-clean.jpg`): the post-crash boot comes up clean — storage trio → `ext2: mounted` → **`jbd2: clean journal ino=8 size=32760 seq=142`** → `AGNOS shell v1.38.10`. Validate: host `e2fsck -fn` clean; journal SB `s_sequence=142` CLEAN. The journal advanced seq 4 → 142 across commit + stress + crash + recovery and landed clean every time.

**Verdict — every tracker falsification row cleared on real NAND.** Read-side (1.38.9) + write-side commit + 100-tx stress + power-cut recovery (1.38.10) all PASS against the unmodified CSUM_V3 agnos-fs journal, host `e2fsck -fn` clean at every checkpoint. **Crash-safe journaling is iron-validated; the 1.38.x jbd2 arc is COMPLETE.** Cycle closes at 1.38.11 (cleanup + hardening). Loose burn artifacts (`13810_validate_*.txt`, `fsck_log_1.txt`) folded here and removed from the repo top level; photos catalogued under [`iron-nuc-zen-photos/`](iron-nuc-zen-photos/README.md#jbd2-journaling-arc-on-iron-1389--13810--crash-safe-journaling-validated-).

### Iron Attempt 1373 — 1.37.x extent-allocation iron burn (2026-05-28) — PASS

**Build flashed**: 1.37.3 selftest kernel (`EXT2_EXTENT_WRITE_SELFTEST=1`, 843,624 B), `install-usb.sh --update` (ESP-only, agnos-fs untouched).

**Boot 1 — fresh agnos-fs**: storage trio + GPT + `ext2: mounted (blocksize=4096, inode_size=256, inodes_per_group=8192)` + `fat: mounted FAT32` clean. FB:
- `ext-ext: seeded /extseed.dat (empty extent file)` ✓ row 2
- `ext-ext: ino=18 extent size0=0` ✓ row 2
- `ext-ext: final depth=2 root_entries=1 size=11149376` ✓ row 4
- `ext-ext: depth-2 PASS` ✓ row 4
- `ext-ext: append PASS` ✓ row 4
- → `Activating scheduler...` → `dhcp: DISCOVER` (boot continued normally) ✓ row 1

**Boot 2 — same NVMe, reboot**: storage + mount path identical. FB:
- `ext-ext: ino=18 extent size0=11149376` (file persisted from boot-1 ✓ rows 3/5)
- `ext-ext: final depth=2 root_entries=1 size=11149376` (tree persisted ✓ row 5)
- `ext-ext: no sibling leaf formed FAIL` ← test-not-idempotent bug

**Reset (cold)**: agnos-fs wiped (the user re-flashed the FS partition); boot-3 path equivalent to boot-1, PASS.

**Host verification (row 6, dispositive)** — pulled `/dev/nvme0n1p2` (agnos-fs) post-reboot:
```
$ sudo e2fsck -fn /dev/nvme0n1p2
e2fsck 1.47.4 (6-Mar-2025)
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
agnos-fs: 20/1638400 files (5.0% non-contiguous), 148269/6553600 blocks
```
**Clean.** ✓ row 6 — real-NAND extent records + leaf/index checksums + `i_blocks` all valid on archaemenid hardware, exactly as 1.33.1 was for indirect writes.

**Boot-2 FAIL diagnosis**: `ext2_extent_write_selftest` loops from `lblk=2` and sets `got_sibling` only when it observes `eh_depth==1` with `eh_entries>=2` *during* the loop. Boot-1's run persisted `/extseed.dat` at `eh_depth==2`; boot-2's first iteration overwrites lblk=2 in place, the post-write inode read reports `d==2` → `got_depth2=1`, `lblk=6002`, loop exits — `got_sibling` never flipped → false `no sibling leaf formed FAIL`. **The FS is healthy; only the selftest's PASS-detection rubric was non-idempotent.**

**Fix (1.37.4)**: `ext2_extent_write_selftest` now checks `eh_depth` after `ext2_get_inode`; if `==2`, emits `ext-ext: /extseed.dat already at depth=2 (prior boot) -- skip PASS` and returns 0. The persisted tree IS the durability proof — skip-with-PASS preserves the evidence rather than tearing it down. QEMU two-boot test confirms the new path.

**Network note (parked)**: DHCP / router association had minor flake on boot-2 + boot-3, eventually associated on the second reset. Not investigated this cycle — user-flagged for later review.

**Arc closure**: 1.37.x extent allocation is **iron-validated on archaemenid**. The boot-1 PASS + host e2fsck-clean reboot survival is the dispositive proof. 1.37.4 cleans up the boot-2 false-FAIL noise so re-runs against persisted state stay green.
