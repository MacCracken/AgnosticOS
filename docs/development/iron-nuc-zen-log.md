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
