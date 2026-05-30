---
name: Manual iron tests — VFS lift (1.39.x) + exec-from-disk (1.40.x)
description: The on-archaemenid manual test checklist for the two latest base-era arcs — what to flash, what to type/watch, and the pass/fail bar. Pairs with the automated scripts/sweep.sh (QEMU half).
type: manual-test-plan
---

# Manual iron tests — 1.39.x VFS lift + 1.40.x exec-from-disk

> **Automated half**: `agnos/scripts/sweep.sh` rebuilds + runs every QEMU smoke for both arcs (FAT/exFAT read+write+subdir, ext2-write regression, exec-from-disk) in one command — run that FIRST; it must be all-green before burning iron. **This doc is the MANUAL half** — the things only real hardware proves (real NVMe NAND, real Zen ring-3 + SMAP/SMEP, power-cycle persistence). Build freshness is Claude's ([[feedback_build_freshness_is_mine]]); you flash + watch + report.
>
> Target: **archaemenid** (NUC AMD / Beelink SER). No serial — read the **FB console** ([[feedback_no_serial_on_iron]]). Flash via `install-usb.sh --update` (ESP-only; agnos-fs survives) unless noted.
>
> The VFS FAT/exFAT iron rubric proper lives in [`iron-nuc-zen-log.md#tracker-139-cycle`](iron-nuc-zen-log.md#tracker-139-cycle); this is the consolidated step-by-step you work through.

## 0. Pre-flight (do once)

- [ ] On the dev box: `cd ~/Repos/agnos && sh scripts/burn-prep.sh` — runs the full sweep (**ARC SWEEP: PASS**, 6/6), then builds the iron EXEC selftest kernel as `build/agnos` and prints the flash + FB-watch steps. If the sweep is red it **ABORTS** — fix first, don't burn. (Plain `sh scripts/sweep.sh` is the sweep alone.)
- [ ] Decide the FAT/exFAT test surface (VFS burn): a **separate USB FAT32/exFAT data stick** (recommended, brick-safe — the non-ESP-preferring selector picks it over the boot ESP) vs. the boot ESP with `FAT_ALLOW_ESP_WRITE` (risky — can corrupt boot). Default: the data stick.

## A. exec-from-disk burn (1.40.x)

Mechanism: the `EXEC_SELFTEST` kernel writes a tiny static ELF to the ext2 agnos-fs (`/bin/prog2`), then `run`s it in ring 3 and prints to the FB. This proves real-NVMe load + real-Zen ring-3 transition (SMAP/SMEP, SYSCALL/SYSRET, iretq) + exit-code capture — none of which QEMU's `-cpu max` fully stands in for.

**Build (Claude):** `EXEC_SELFTEST=1 EXT2_WRITE_SELFTEST=1 sh scripts/build.sh` → flash `build/agnos`.

| # | Step | Watch the FB for | PASS | Falsifies if |
|---|------|------------------|------|--------------|
| A1 | Boot the EXEC_SELFTEST kernel | storage trio + GPT + `ext2: mounted …` → reaches the exec lines | clean mount, no hang/panic | hang/triple-fault before the exec lines |
| A2 | ENOEXEC refusal | `exec: running /notelf` then `run: not an executable` | the non-ELF is refused, NO hang | a crash/hang on the non-ELF |
| A3 | Load + run from subdir | `exec: running /bin/prog2` → **`EXEC-DISK-OK`** | the program ran in ring 3 on real Zen + its `write(1,…)` reached the console | no `EXEC-DISK-OK` (ring-3 / SMAP / SYSCALL failure on real silicon) |
| A4 | Exit code captured | **`run: exit 42`** | `exec_and_wait` resumed the kernel with the program's code | no `run: exit 42` |
| A4b | argv deref (1.40.8) | `exec: running /bin/argv Z` → **`run: exit 90`** (argv[1][0]='Z'=0x5A) | exec #2: `argc >= 2` AND the `argv[1]` *string bytes* reach ring 3 on the SysV init stack (exit 90 subsumes the argc-count check) | no `run: exit 90` (argv strings not in the user stack) |
| A5 | Clean return | **`exec: selftest done`** | `exec_and_wait` returned cleanly into its caller (shell-loop shape) | boot halts at the last `run: exit` |
| A6 | Post-burn FS intact | reboot a PLAIN kernel; `ls /bin` shows `prog2`; from Linux `e2fsck -fn` the agnos-fs | the `/bin/prog2` + `/notelf` writes are clean on NAND | e2fsck errors |

**Dispositive bar:** A3 + A4 (`EXEC-DISK-OK` + `run: exit 42`) on real Zen — that's exec-from-disk proven on iron. A6 confirms the writes didn't corrupt the FS.

*Note:* multi-`run` in one boot works as of 1.40.6 (`kernel_resume` restores the boot CR3; `proc_current` tracks the exit code) — but only for **2 real execs per boot** as of 1.40.8: each exec leaks its 2 MB pages (no process teardown yet), so a **3rd** `run` currently fails at load with `run: not an executable` (2 MB-page pool exhausted). Page reclaim on exit is the top exec follow-on. So on iron, expect prog2 + argv to both run; don't read a 3rd-program failure as a regression.

## B. VFS FAT/exFAT verb burn (1.39.x)

Per [`#tracker-139-cycle`](iron-nuc-zen-log.md#tracker-139-cycle). The shell FAT/exFAT verbs only fire when `ext2_active == 0`, so use the `FATFS_WRITE_SELFTEST` / `EXFAT_WRITE_SELFTEST` self-driver kernels against a **non-ESP USB FAT32 / exFAT data stick**; they print `fatw:` / `exfatw:` PASS lines to the FB.

**Build (Claude):** `FATFS_WRITE_SELFTEST=1 sh scripts/build.sh` (then a second flash with `EXFAT_WRITE_SELFTEST=1`).

| # | Step | Watch the FB for | PASS |
|---|------|------------------|------|
| B1 | Boot FAT-write kernel w/ the FAT32 stick | `fat: mounted …` + `fatw: … rc=0` lines incl. subdir (`SHSUB/…`) | all `rc=0`, no FAIL line |
| B2 | Boot exFAT-write kernel w/ the exFAT stick | `exfat: mounted …` + `exfatw: …` incl. `subdir find-back OK` | all OK, no FAIL line |
| B3 | Power-cycle persistence | re-boot, re-read | the written files/dirs survive |
| B4 | Host fsck | `fsck.fat -n` / `fsck.exfat -n` the stick from Linux | **clean** |

**Dispositive bar:** B4 (host `fsck` clean) — the FAT/exFAT writes are byte-valid on real media.

## C. Sign-off

- [ ] A1–A6 PASS → record under a `13xx_*` / exec entry in `iron-nuc-zen-log.md` + photos in `iron-nuc-zen-photos/`.
- [ ] B1–B4 PASS → fills the long-pending 1.34.x FAT/exFAT iron touch (folded into tracker-139).
- [ ] Both PASS → the **1.39.x + 1.40.x arcs are iron-validated**; the base maturity stage's two exit legs (FS-crash-safe + exec-from-disk) are both proven on hardware.

---

*Manual companion to `scripts/sweep.sh`. Update in place as the arcs add verbs/bites.*
