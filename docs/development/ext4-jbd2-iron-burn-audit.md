# JBD2 1.38.x — Iron-Burn Pre-Audit + Test Rubric

> **Status**: pre-burn audit. Closes the 1.38.x JBD2 arc (1.38.0 → 1.38.8); the
> user-driven burn is the first real-NAND validation of the journaling stack on
> archaemenid (Beelink SER, AMD Zen, Crucial P3 NVMe + WD Blue SA510 SATA).
>
> **Created**: 2026-05-28. **Companion to**: [`ext4-jbd2-prior-art.md`](ext4-jbd2-prior-art.md)
> (design + multi-source audit) + agnos `CHANGELOG.md` `[1.38.0]`–`[1.38.8]`.
>
> **Memory pin**: [[feedback_iron_burns_block_other_work]] — every iron-burn
> proposal must come with a written line-by-line audit BEFORE the burn is
> staged. This is that audit.

## 1. What this burn proves

The 1.38.x arc shipped through eight Claude-determined bites; every one closed
QEMU-green (`test.sh` 4/4, `check.sh` 11/11, plus per-bite smoke). The iron
burn closes the loop with **real-NAND validation**, the same dispositive bar
as 1.33.1 (indirect WRITE) and 1.37.3 (extent WRITE):

| # | Bite | QEMU validation that lands here on iron |
|---|------|-----------------------------------------|
| 1 | 1.38.0 probe | `jbd2: clean journal ino=N size=M seq=K` line on `ext-extent-smoke.sh` |
| 2 | 1.38.1 probe-deepen | `jbd2-refusal-smoke.sh` (dirty-journal RW refusal) |
| 3 | 1.38.2 log reader | `jbd2-logdump-smoke.sh` (synth 1-tx parsed) |
| 4 | 1.38.3 replay | `jbd2-replay-smoke.sh` (5 gates incl. e2fsck-clean) |
| 5 | 1.38.4 lifecycle | `jbd2-tx-smoke.sh` (begin/log/commit + negatives) |
| 6 | 1.38.5 write path | `jbd2-writepath-smoke.sh` (7 gates incl. journal-SB on disk) |
| 7 | 1.38.6 integration | `jbd2-integration-smoke.sh` (put_inode routes through journal) |
| 8 | 1.38.7 crash smoke | `jbd2-crash-smoke.sh` 4/4 (every SIGKILL → e2fsck-clean reboot) |

Iron tests **whether the same code reaches the same outcomes against real
NVMe controller behavior** — DMA, queue depths, FLUSH-CACHE timing, write-
ordering nuances that QEMU's idealized NVMe model can't fully expose.

## 2. Hypothesis

The journal code that is QEMU-`e2fsck -fn`-clean across `jbd2-replay-smoke.sh`
(replay applies, SB cleans, FS clean) and `jbd2-crash-smoke.sh` (4/4 kill-points
all clean) will:

(a) **Mount**: probe the journal on the archaemenid agnos-fs partition (25 GiB,
    32 MiB journal = 8192 blocks); emit `jbd2: clean journal ino=8 size=8192 seq=K`.

(b) **Read-side**: an externally-prepared dirty journal (via Linux: mount the
    partition, `echo > /mnt/x; sync; pkill -9 -f qemu` mid-write — alternatively
    use the same mutator the QEMU smokes use, `mk-dirty-journal-img.py --synth-tx`,
    against the real partition) will be **detected** by the probe AND **replayed**
    by `ext2_jbd2_replay` to host-e2fsck-clean state.

(c) **Write-side**: a synthetic AGNOS commit (via `JBD2_INT_SELFTEST=1` build
    of the kernel against the real partition) will produce on disk:
    - journal SB with `s_start = 0`, `s_sequence` advanced
    - the target FS block byte-identical to the source buffer
    - host `e2fsck -fn` clean

(d) **Crash-recovery**: power-cycle mid-write (with selftest looping) leaves
    the disk in a state recoverable to host-e2fsck-clean on next AGNOS boot.

All four are byte-for-byte the same code paths the QEMU smokes exercised.

## 3. Pre-burn state (Claude-owned per [[feedback_build_freshness_is_mine]])

- `agnos/build/agnos` = production build at 1.38.8 (no env-var flags set).
- Production build size: **986,656 B**. Banner `v1.38.8`.
- Includes the full JBD2 stack: probe + log reader + replay + lifecycle + write
  path + integration + crash-stress selftest + 1.38.8 hardening bounds checks.
- Compile gates intentionally NOT set in the iron-flash build:
  - No `JBD2_LOGDUMP` (replay still runs; just no auto-mount logdump trace).
  - No `JBD2_TX_SELFTEST`, `JBD2_WP_SELFTEST`, `JBD2_INT_SELFTEST`, `JBD2_CRASH_SELFTEST`
    (no selftest auto-runs at boot — clean production behavior).
  - No `JBD2_NO_REPLAY` (replay is the ON path).
- `install-usb.sh --update` (ESP-only) flashes the new kernel; agnos-fs partition
  is preserved across the flash (per [[feedback_prefer_mount_modify_over_reflash]]).

## 4. Test-item rubric

One burn covers all items via the existing shell verbs + (optional) a one-off
selftest-enabled re-flash for the crash-recovery test. **The user flashes +
burns; Claude does NOT auto-propose a burn** per [[feedback_iron_burns_block_other_work]].

### Test 1 — Mount + clean-journal probe

| | |
|---|---|
| **What** | First boot of 1.38.8 against the unmodified archaemenid agnos-fs. |
| **Mechanism** | The probe runs automatically at mount; emits `jbd2: clean journal …` if `s_start == 0`, the expected steady-state after a graceful prior unmount. |
| **PASS** | FB shows `jbd2: clean journal ino=8 size=8192 seq=K` (K = whatever the prior session left). Subsequent boot lines match 1.37.x's: `Activating scheduler...` → DHCP → `AGNOS shell v1.38.8`. |
| **Falsifies** | `jbd2: bad magic`, `jbd2: SB csum mismatch`, `jbd2: DIRTY journal …` on a partition that was cleanly unmounted last time, or no `jbd2:` line at all. |

### Test 2 — Dirty-journal mount refusal (no replay built in)

| | |
|---|---|
| **What** | Force `s_start != 0` on the agnos-fs journal (host-side: `python3 scripts/mk-dirty-journal-img.py /dev/nvme0n1p2 0 1`), then reboot agnos WITHOUT the 1.38.3 replay path (`JBD2_NO_REPLAY=1 sh scripts/build.sh` + install-usb.sh --update). |
| **Mechanism** | 1.38.0 stop-gap — dirty journal detected, RW mount refused, RO mount allowed. |
| **PASS** | FB shows `jbd2: DIRTY journal ino=8 start=1 seq=K -- refusing RW mount (replay lands at 1.38.2)`; shell still comes up; shell write verbs (`echo > /foo`, `mkdir`, etc.) all fail with the W2 gate. |
| **Falsifies** | Successful RW mount + writes land on disk, OR kernel hangs/panics. |

### Test 3 — Replay-on-mount (the unlock)

| | |
|---|---|
| **What** | Same dirty image as Test 2, but boot the PRODUCTION 1.38.8 kernel (no `JBD2_NO_REPLAY`). |
| **Mechanism** | 1.38.3 replay — descriptor → data → commit walk, validate-first, apply-second, then SB-clean + FLUSH-CACHE + sync. |
| **PASS** | FB shows `jbd2: DIRTY journal …` → `jbd2: replay: walk start=1 seq=N` → `jbd2: replay: APPLIED 1 tx; SB now clean (next seq=N+1) -- RW mount LIFTED`. Shell verbs work. Post-shutdown host `e2fsck -fn /dev/nvme0n1p2` clean. |
| **Falsifies** | Replay halts with `torn` / `malformed`, OR `e2fsck` reports errors. |

### Test 4 — AGNOS produces a journaled write (integration)

| | |
|---|---|
| **What** | Flash a `JBD2_INT_SELFTEST=1` build (one-off; for verification). Selftest opens tx, calls `put_inode(2)`, commits + syncs. |
| **Mechanism** | 1.38.6 routing — `put_inode`'s inode-table write goes through `ext2_jbd2_log_metadata` because the tx is active; 1.38.5 write path lays down descriptor + data + commit; sync-checkpoint cleans the journal. |
| **PASS** | FB shows `jbd2-int: put_inode routed through journal (logged 1 metadata blocks)` + `jbd2: commit_tx: COMMITTED seq=1 n_blocks=1 -- checkpoint applied + journal clean` + `jbd2-int: integration selftest PASS`. Post-shutdown host `e2fsck -fn` clean. Journal SB on disk shows `s_start = 0`, `s_sequence` advanced. |
| **Falsifies** | `tx_count == 0` (routing broken), commit failure, e2fsck errors, journal still dirty. |

### Test 5 — Crash-recovery (power-cycle mid-write)

| | |
|---|---|
| **What** | Flash a `JBD2_CRASH_SELFTEST=1` build. Stress loop runs (~3 s of `put_inode` commits). User pulls power partway through. Re-boot with PRODUCTION 1.38.8 kernel. |
| **Mechanism** | The kill leaves the journal in some state — clean (kill landed between commits) or dirty (kill landed mid-commit). 1.38.3 replay handles either; 1.38.7 QEMU smoke validated 4/4 clean across varied kill points. |
| **PASS** | Re-boot reaches shell; FB shows either `jbd2: clean journal …` (kill was between commits) or `jbd2: DIRTY journal … -> replay: APPLIED N tx … RW mount LIFTED` (kill was mid-commit). Post-shutdown host `e2fsck -fn` clean. |
| **Falsifies** | `e2fsck` reports errors AGNOS's replay didn't catch, OR kernel hangs/panics on dirty-journal mount, OR shell never comes up. |

### Test 6 — Host `e2fsck -fn` clean (dispositive)

| | |
|---|---|
| **What** | After Tests 1, 3, 4, 5 each: shut down agnos gracefully (or pull power, in Test 5's case), boot Linux on the host, run `e2fsck -fn /dev/nvme0n1p2`. |
| **Mechanism** | The load-bearing gate — proves the journal SB + replayed data + FS metadata are all byte-valid on real NAND, exactly as the QEMU smokes proved on the QEMU NVMe model. |
| **PASS** | `e2fsck` exits 0 with the standard 5-pass summary; no `Filesystem was not cleanly unmounted` warning (because `ext2_sync` runs at end of `replay` and at end of integration selftest), no orphan blocks, no inode-bitmap mismatch. |
| **Falsifies** | Any error exit (1+). Look at the specific complaint — most likely category would be inode-table block content mismatch (suggesting `metadata_csum` recompute failed for the journaled inode write). |

## 5. Diff against QEMU (where iron could surface what QEMU couldn't)

| Surface | QEMU exposed | Iron might expose |
|---------|--------------|-------------------|
| **NVMe DMA scatter-gather** | yes (single-block writes only) | multi-block batching reordering |
| **Write-cache flush latency** | instant in QEMU model | real ~10-100 µs on NVMe NAND → could expose missing `blk_flush_on` between barriers |
| **PCIe completion order** | strict in-order in QEMU | could be reordered if our barrier discipline has a gap |
| **Power-loss durability** | not testable in QEMU | real test of FLUSH-CACHE landing on platter (power-cycle mid-commit) |
| **Controller state recovery** | none in QEMU | NVMe controller may need re-init after power-cycle (already handled by 1.31.x storage stack) |

The barriers in 1.38.5's commit_tx (3 × `blk_flush_on` between descriptor+data /
commit / checkpoint stages) are the load-bearing primitive iron will pressure-test.

## 6. Out of scope for this burn

- **i225-V NIC** (still queued for Intel iron post-archaemenid migration).
- **CSUM_V2/V3 journals** — our write path refuses these (1.38.5 narrow scope).
  archaemenid's mkfs.ext4 doesn't enable CSUM_V2/V3 by default (verified via the
  `jbd2-refusal-smoke.sh` Python helper's "no SB csum to recompute" path).
- **Block-bitmap / group-descriptor / extent-tree node journaling** (1.38.6
  narrow scope only routed `put_inode`'s inode-table write; allocator writes
  stay direct → grow-then-crash can leave e2fsck-fixable orphan blocks).
- **Async checkpoint / log fill / back-pressure** — sync-checkpoint model
  always resets `log_head = 1` after each commit; no fill scenario reachable.
- **Multi-tx pipelining** — single-threaded synchronous commit_tx; no
  concurrent transactions.

## 7. Burn-day flow (user-driven)

1. Plug archaemenid; cable monitor + power; ensure NVMe (Crucial P3) is the
   AGNOS-EXT primary, SATA (WD Blue) is secondary.
2. From Linux: `python3 scripts/mk-dirty-journal-img.py /dev/nvme0n1p2 0 1`
   (prepares dirty journal for Tests 2 & 3 — if Test 1 should run first, skip
   this step until after Test 1 completes).
3. Flash production 1.38.8: `cd agnos && sh scripts/install-usb.sh --update`.
4. Power-cycle archaemenid (read Test 1 FB).
5. Run Tests 2/3 (one-off flashes for `JBD2_NO_REPLAY=1` then production).
6. Re-flash production. Boot. Confirm Test 4 needs the selftest flash; reflash
   `JBD2_INT_SELFTEST=1` build.
7. Test 5: re-flash `JBD2_CRASH_SELFTEST=1`. Boot. Pull power at ~3-5 s into
   boot. Re-flash production. Boot — read FB for replay trace.
8. Boot Linux. Run `e2fsck -fn /dev/nvme0n1p2` post each test.
9. Update `agnosticos/docs/development/iron-nuc-zen-log.md` with the tracker
   entry per [[feedback_iron_log_tracker_pattern]].

Photo expected to be labelled `13MN_jbd2_*.jpg` (phone-label sequence) — the
catalog convention from [[feedback_top_level_photos_are_fresh_iron]] applies.

---

*The user calls the burn. This doc is the pre-audit per
[[feedback_iron_burns_block_other_work]]; "every future instrumentation /
diagnostic proposal must come with a written line-by-line audit BEFORE a burn
is proposed."*
