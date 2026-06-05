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

### Tracker: 1.41.x shell-separation arc burn (RE-BURN PENDING at 1.41.12 — **burn #1 (`14111`, 2026-06-04) cleared A4 (no exec/storage/net regression; real DHCP lease) but A1 was unobservable: ring-3 stdout was serial-only, so the agnsh banner was invisible on the serial-less box and the boot *looked* hung at `kybernet: exec /bin/agnsh`. Fixed at 1.41.12 (`serial_dev_write`→`kprint`, serial+fb mirror); re-burn flashes the 1.41.12 build to confirm A1 on the FB. See the `14111` sub-entry below.** Staged at 1.41.11; the arc's first full hardware validation. agnsh is the interactive shell exec'd from disk in ring 3; the in-kernel shell is a recovery REPL; FAT/exFAT content-write reaches the syscall ABI; the post-1.41.5 write-fd surface is hardened. All QEMU-green: agnsh-smoke PASS, sweep 7/7, fssys/shsys PASS. NO auto-run per [[feedback_iron_burns_block_other_work]] — rubric below; the user flashes + burns.) {#tracker-141x-cycle}

**Scope.** The 1.41.x arc moved the interactive shell out of the kernel: **1.41.4** PID-1 `kybernet` execs `/bin/agnsh` (the `cyrius build --agnos` agnoshi binary) in ring 3 off the ext2 root, with the in-kernel `shell()` as the fallback; **1.41.7** added the `VFS_SEC_WFILE` write-fd so agnsh can write FAT/exFAT data partitions via `open(AO_WRONLY)`+`write`+`close`; **1.41.8/1.41.9** shrank the in-kernel shell to a recovery REPL (`shell.cyr` 1149→813 LOC); **1.41.5/1.41.6/1.41.10** hardened the ring-3→ring-0 surface (epoll/timerfd type-confusion, the 1 GB user-VA ceiling, ELF/mmap/spawn bounds, the write-fd pool-leak DoS + write-cap spin + directory-overwrite corruption). This burn validates the whole arc is byte-valid on real Zen, the same dispositive bar (boot-to-prompt + host-`fsck` clean) as the 1.40.x exec burn.

**Hypothesis.** On archaemenid, the production kernel (1.41.11) with `/bin/agnsh` seeded on the ext2 root will (a) reach the **agnsh prompt in ring 3** — `kybernet: exec /bin/agnsh` → `agnoshi 1.3.x / AI-native shell…` to the **FB** (iron-readable `kprint`; no serial — [[feedback_no_serial_on_iron]]), no `#UD`, no emergency-shell fallback; (b) fall back to the **in-kernel recovery `agnos>`** shell (with `cat`/`ls`/`run` working) if `/bin/agnsh` is renamed/absent; (c) **write a FAT/exFAT data-partition file** from agnsh that survives a power-cycle and is **host-`fsck` clean**; (d) show **no regression** in the exec/storage/net stack (the box still rides past `Activating scheduler...` → kybernet, as the 1.40.x arc is iron-validated).

**Falsification criteria.** `#UD`/`#PF` at agnsh startup or a fallback to the emergency shell when `/bin/agnsh` is present → the cyrius `CYRIUS_TARGET_AGNOS` stdlib peer or the kernel exec path differs on Zen vs QEMU (re-check `args_agnos` init-stack capture, the ring-3 enter path). Recovery `agnos>` not reachable with `/bin/agnsh` absent → the shrunk shell's fallback path regressed. FAT/exFAT write not `fsck`-clean → the write-fd flush (`vfs_write_on` → `fatfs_write_file`/`exfat_write_file`) writes differently on real NAND. A reset before kybernet → an exec/scheduler regression vs the iron-validated 1.40.x baseline.

**Test-item rubric (one burn; flash the production 1.41.11 `build/agnos` via `install-usb.sh --update`, with `/bin/agnsh` = `agnoshi/build/agnsh_agnos` on the ext2 root + an empty FAT/exFAT data partition for A3):**

| # | Test item | Read-out (FB) | PASS | Falsifies if |
|---|-----------|---------------|------|--------------|
| A1 | Boot-to-agnsh (★ dispositive) | `kybernet: exec /bin/agnsh` → `agnoshi 1.3.x` shell banner | agnsh launches in ring 3, no `#UD`, no emergency fallback | `#UD`/`#PF` at startup, or `kybernet: emergency shell` |
| A2 | Recovery-shell fallback | (rename `/bin/agnsh`, re-boot) → `kybernet: emergency shell` → `agnos>`; `ls /` + `cat <file>` work | in-kernel recovery REPL reachable + functional | no `agnos>` prompt, or `ls`/`cat` fail |
| A3 | FAT/exFAT write via agnsh | agnsh writes a file to the data partition; host `fsck.fat`/`fsck.exfat -n` clean post-burn; content survives power-cycle | the write-fd lands valid content on real NAND | content absent / `fsck` dirty / corruption |
| A4 | No exec/storage/net regression | boot rides `Activating scheduler...` → DHCP (ACK or static) → `Launching kybernet...` | 1.40.x-baseline boot intact | reset/hang before kybernet |

**Expected, not a falsification:** the DHCP outcome (real ACK vs static fallback) depends on the LAN; the AMD Zen FB scanout banding is the parked cosmetic residue ([[project_amd_zen_scanout_residue]]). The FAT/exFAT write fd has a known 4 KB whole-file cap (1.41.7 follow-on) — A3 uses a small file.

#### 1.41.12 ring-3 stdout FB-mirror — burn `14111_stallout` diagnosed + fixed (2026-06-04)

**Burn `14111_stallout` (the arc's first hardware touch).** Boot rode clean: AHCI WD Blue + GPT (3 parts: ESP / agnos-fs / `fstest`) → `VFS initialized` → `ext2: mounted` (blocksize=4096) + `jbd2: clean journal seq=10` + `fat: mounted FAT32` → `SYSCALL/SYSRET` + stack-canary + `Interrupts enabled` → `Activating scheduler...` → DHCP **real lease** (`ACK ip=192.168.1.159 gw=192.168.1.1`, `arp REPLY gw d4:6a:91:ce:70:60`, `net: L2 OK`) → `Launching kybernet` → `kybernet: 2 processes` / `2950 free pages` → **`kybernet: exec /bin/agnsh`** — then the FB froze. **A4 (no exec/storage/net regression) ✓** — rides past `Activating scheduler` intact (the 1.40.10 scheduler-reset baseline holds). **No `#UD`, no reset, no `emergency shell`.**

**Diagnosis — NOT a hang; ring-3 stdout was serial-only.** The user's read ("interesting it didn't fault and drop to emergency") trisected it: a clean exec-failure return → `emergency shell` (didn't fire); a bad-ELF jump → `#PF`→triple-fault→reset (would've rebooted, didn't); ⇒ silent. A 6-reader parallel audit + the QEMU `agnsh-smoke` **serial** log (which prints the full `agnoshi 1.3.5` banner right after the exec line) proved agnsh **loads** (69-block ext2 single-indirect read ✓), **enters ring 3** ✓, and **prints its banner** ✓ — but `write(1,…)` → `vfs_write` → `dev_write(0)` → `serial_dev_write` → `serial_print` **only, no fb**. Serial-less archaemenid ([[feedback_no_serial_on_iron]]) → banner invisible → FB frozen at the last `kprint` line. **Regression** from the 1.41.x write-surface refactor (1.40.9 had ring-3 `write(1)`→`kputc/fb`, iron-visible — see the 1.40.x tracker `EXEC-DISK-OK`/`run: exit 42/90`). Exonerated by the QEMU banner: ext2 indirect read, KPTI page-map, `mmap`.

**Fix (1.41.12, behavioral).** `serial_dev_write` → `kprint` (serial+fb mirror, `core/devs.cyr`). agnsh-smoke **PASS**, banner retained on serial, build **1,070,704 B**. **Next-burn A1 is now OBSERVABLE** — expect the agnsh banner on the **FB**, then agnsh blocks on `read(fd 0)`→`kbd_read_blocking`. (The original note here predicted "no keystrokes, next blocker = a separate xhci USB-HID arc." That framing was WRONG — see the typing sub-entry below; the keyboard works on iron via IRQ1/i8042, the xHCI ring being empty is a red herring.)

#### agnsh typing on iron — `kbd_read_blocking` ran interrupts-masked (burn `14112` @ 1.41.12 → fix @ 1.41.13, 2026-06-05)

**Burn `14112_140_boot_no_typing` result.** agnsh reached the `[ASSIST] >` prompt on the FB (the 1.41.12 PMM top-down fix cleared the ring-3 `#PF`, so A1 is now FB-confirmed: `agnoshi 1.4.0` banner + prompt). **But typing produced nothing** at the prompt — the open item the previous note mis-attributed to "USB-HID never worked on iron."

**Diagnosis (corrected — the earlier "empty kbd ring" comment was the misdirection).** The keyboard works on archaemenid: the in-kernel recovery shell types fine on iron. There is no PS/2 hardware; keystrokes arrive as **i8042 scancodes from the firmware's UEFI USB-legacy emulation**, delivered via **IRQ1** to `kb_isr`. The xHCI USB-HID event ring that `hid_poll()` drains stays empty on this box (firmware owns the device) — but that is NOT "keyboard broken." The agnsh path failed for a different reason: `read(fd 0)`→`kbd_read_blocking` runs **with interrupts masked** (SYSCALL clears IF via SFMASK=0x200, `syscall_hw.cyr:98`), so the IRQ1 ISR could never fire, and it only polled the (empty) xHCI ring → hung at a visible prompt. The in-kernel shell typed fine because it runs with IF=1, letting IRQ1 deliver.

**Fix (1.41.13, behavioral, `kbd_read_blocking` + new `kb_poll_i8042`).** Keep interrupts masked (an `sti` here lets the xHCI raise an interrupt the kernel only polls — a QEMU **baseline regression** confirmed this), and instead **poll the i8042 data port directly** (ports 0x60/0x64, bounded ≤16, AUXB-skip) alongside the existing `hid_poll()`. On a given box exactly one source has data, so draining both is race-free. **QEMU-validated:** `agnsh-type-test.py` (xHCI usb-kbd) PASS — `help`/`version`/`mode` register cleanly, no regression, no doubling (the i8042 poll is a no-op in QEMU since `sendkey` targets the usb-kbd). Build **1,070,976 B**.

**Hypothesis (this burn).** At the `[ASSIST] >` prompt, typing now echoes and commands run — the firmware's USB-legacy i8042 emulation answers polled reads of port 0x60 (standard behavior; it is how a bootloader reads a USB keyboard), so `kb_poll_i8042()` retrieves scancodes with IF masked.

**Falsification criteria.** Still no keystrokes at the prompt → the firmware emulation presents scancodes ONLY on IRQ1 (not on polled OBF), OR it withholds the byte until the IRQ is ack'd. Fallback: **selectively unmask IRQ1 at the PIC** (mask everything else, no broad `sti`) so the proven ISR path fires without enabling the xHCI interrupt that broke QEMU; if that also fails, mask the LAPIC timer + `sti` (IRQ1-only wake) as the next step. A stray/garbage char after a line → the pending-IRQ1-latched-during-IF=0 edge (a known minor; mask IRQ1 at the PIC during the read to close it). **QEMU cannot exercise this path** (it uses a real usb-kbd → hid_poll), so this burn is the only validation.

**Read-out (FB):** type `help` at `[ASSIST] >`. PASS = the help text prints. Falsifies = no echo, nothing.

### Tracker: 1.40.10 cycle — scheduler-reset-at-DHCP fix (OPEN 2026-05-31 — **the 1409 final burn cleared the exec dispositive bar (A1–A7 PASS on real Zen) but reset right after `Activating scheduler...` → `dhcp: DISCOVER`.** Root cause is NOT DHCP (user: "nothing got changed there", correct): the now-*working* exec selftest leaves `proc_count≥2` + `proc_current` on a dead exec proc, so the first timer tick after `sched_active=1` (the DHCP hlt-wait) makes `do_context_switch` clear its old `proc_count<2` early-return, fall back to a dead exec proc, `cr3_load` its stale per-process CR3 + iretq into a ring-3 RIP in ring 0 → triple-fault reset. **Fix (user chose "real kernel idle proc 0"): register proc 0 = kernel main thread + proc 1 = hlt idle thread, both on boot CR3 `0x1000`, before `sched_active=1` — equal-CR3 guard skips `cr3_load`, preemption becomes pure register save/restore in one address space.** Behavioral, not instrumentation. NO burn auto-run per [[feedback_iron_burns_block_other_work]].) {#tracker-14010-cycle}

**Hypothesis.** With proc 0 (kmain) + proc 1 (idle) registered as real same-CR3 procs before scheduler activation, the timer-driven `do_context_switch` will ping-pong kmain↔idle without ever loading a bad CR3 or iretq-ing into a dead exec proc — so the boot survives the DHCP hlt-wait, completes the DHCP/ARP exchange (or static fallback), and reaches the shell, with the exec selftest (A1–A7) still PASS.

**Falsification criteria.** A reset/halt at or after `dhcp: DISCOVER` again → the idle-proc setup doesn't cover the path (e.g. CR3 still mismatches, or a later tick lands while `proc_current` is a dead exec proc). Exec selftest regressing (no `run: exit 42`/`exit 90`/`selftest done`) → the `#ifndef KTEST` proc setup perturbed the exec path. **Dispositive bar: boot reaches the AGNOS shell past `Activating scheduler...` on real Zen** — scheduler activation is crash-safe with live exec procs in the table.

**Test-item rubric (one burn, rides the EXEC_SELFTEST kernel):**

| # | Test item | Read-out (FB) | PASS | Falsifies if |
|---|-----------|---------------|------|--------------|
| S0 | Exec selftest still green | `run: exit 42` + `run: exit 90` + `exec: selftest done` | A1–A7 unregressed | any exec line missing |
| S1 | Scheduler activates | `Activating scheduler...` then boot continues | no reset at/after this line | reset right after activation |
| S2 | DHCP hlt-wait survives (★ dispositive) | `dhcp: DISCOVER` → `dhcp: ACK ip=…` *or* `DHCP failed -- using static fallback` | timer ticks ping-pong kmain↔idle without faulting | reset/halt at `dhcp: DISCOVER` |
| S3 | Reaches shell | `arp: request -> gateway` → `Launching kybernet...` → AGNOS shell prompt | full boot completes on iron | hang/reset before the prompt |

**Expected, not a falsification:** the DHCP outcome itself (real ACK vs static fallback) depends on the LAN, not the fix — either is a PASS for S2. The AMD Zen FB scanout banding is the parked cosmetic residue ([[project_amd_zen_scanout_residue]]).

### Tracker: 1.39.x cycle — VFS generic-write lift iron burn (PENDING — the FAT/exFAT shell verbs' first real-hardware touch; folds in the long-pending **1.34.x FAT/exFAT iron burn** carry-forward, [`iron-nuc-zen-log-mvp2.md#tracker-1341-cycle`](iron-nuc-zen-log-mvp2.md#tracker-1341-cycle). Code is QEMU-`fsck`-clean across all four FAT/exFAT read+write smokes; this tracker governs only the iron confirmation. NO auto-run per [[feedback_iron_burns_block_other_work]] — rubric below; the user flashes + burns.) {#tracker-139-cycle}

**Scope.** The 1.39.x arc lifted the shell write/dir verbs off the hardwired ext2 path onto a generic per-FS dispatch ([`vfs-generic-write-prior-art.md`](prior-art/vfs-generic-write-prior-art.md)): `cat`/`ls`/`touch`/`echo >`/`rm`/`mkdir`/`rmdir`/`mv`/`sync` now reach **FAT32 + exFAT** through `vfs_*_secondary`. 1.39.8 (bite 8) consolidated the seven duplicated non-ESP-preference chains behind one `vfs_secondary_select()` and added the `vfs_sec_name_ok` ingress bound (1..255). This burn validates that the dispatch + both writable backends are byte-valid on real NAND, the same dispositive bar (host-`fsck` clean) as the 1.33.1 ext2 and 1.37.x extent burns. **Root-level verbs only** — FAT/exFAT subdir paths are deferred to 1.39.9, so the burn rubric is root-only.

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

**Combined with 1.40.x exec-from-disk.** This VFS burn now rides with the **exec-from-disk** iron burn (1.40.x) as one hardware session — both are base-era exit-leg validations. The full step-by-step manual checklist (FAT/exFAT verbs **and** `run /bin/prog2` in ring 3 on real Zen) lives in [`exec-iron-manual-tests.md`](exec-iron-manual-tests.md); the automated QEMU pre-check for both arcs is `agnos/scripts/sweep.sh` (must be all-green before burning). **The two arcs are the two TRACKS of this one session — Track A = exec (this is the primary/dispositive new-work track); Track B = the FAT/exFAT verbs (above). See [`#tracker-140-cycle`](#tracker-140-cycle) for the exec hypothesis + rubric.**

### Tracker: 1.40.x cycle — exec-from-disk iron burn (STAGED 2026-05-30, PENDING — **the base-maturity SECOND exit leg's first real-hardware touch: a program loaded from the filesystem, run in ring 3 on real Zen.** The 1.40.x arc built it end-to-end — streaming ELF64 loader (1.40.2) → ring-3 execution + exit-code capture (1.40.3) → ENOEXEC/E2BIG (1.40.4) → subdir/CWD paths + sweep + manual plan (1.40.5) → 2-exec multi-run (1.40.6) → argv passing (1.40.7) → argv-deref harden + burn-prep (1.40.8), **all QEMU-green** (`exec-smoke.sh` 7/7, `sweep.sh` 7/7). This burn confirms the ring-3 transition (SYSCALL/SYSRET, iretq, SMAP STAC/CLAC, SMEP, EFER.SCE) + the streaming load off real NVMe NAND work on real silicon — none of which QEMU `-cpu max` fully stands in for. **Mechanism: the `EXEC_SELFTEST` kernel self-seeds `/bin/prog2` + `/notelf` + `/bin/argv` into the ext2 agnos-fs, runs them, and prints to the FB** (no serial — [[feedback_no_serial_on_iron]]; flash-and-test, no host-side seeding). NO burn auto-run per [[feedback_iron_burns_block_other_work]] — rubric below; the user flashes + burns.) {#tracker-140-cycle}

**Hypothesis.** The exec path that is QEMU-green via `exec-smoke.sh` (7/7) will, on archaemenid's real Zen silicon + NVMe NAND: (a) stream-load a static ELF64 off the ext2 agnos-fs and **run it in ring 3** — `/bin/prog2`'s `write(1,…)` reaches the FB (**`EXEC-DISK-OK`**) and its `exit(42)` is captured (**`run: exit 42`**); (b) refuse a non-ELF cleanly (`/notelf` → `run: not an executable`, no hang); (c) deliver argv on the SysV init stack — `/bin/argv Z` dereferences `argv[1][0]='Z'` and exits **90**; (d) return cleanly into the kernel after each run (`exec: selftest done`); (e) leave the agnos-fs **host-`e2fsck -fn` clean** after the self-seed writes.

**Falsification criteria.** No `EXEC-DISK-OK` or no `run: exit 42` → the ring-3 / SYSCALL / SMAP path fails on real Zen (the ten QEMU-resolved bring-up bugs would have an iron-only sibling). A hang/triple-fault on `/notelf` → the ENOEXEC refusal is unsafe on iron. No `run: exit 90` → argv strings don't reach the user stack on real hardware. No `exec: selftest done` → `exec_and_wait` doesn't return cleanly into its caller frame. Any host `e2fsck` error → the self-seed writes corrupt the FS on real NAND. **Dispositive bar: `EXEC-DISK-OK` + `run: exit 42` on real Zen** — that's exec-from-disk proven on iron, the second base-maturity exit leg.

**Test-item rubric (Track A — one burn):**

| # | Test item | Read-out (FB) | PASS | Falsifies if |
|---|-----------|---------------|------|--------------|
| A1 | Boot the `EXEC_SELFTEST` kernel | storage trio + GPT + `ext2: mounted …` → reaches the `exec:` lines | clean mount, no hang/panic | hang/triple-fault before the exec lines |
| A2 | ENOEXEC refusal | `exec: running /notelf` → `run: not an executable` | non-ELF refused, no hang | crash/hang on the non-ELF |
| A3 | Load + run from subdir (★ dispositive) | `exec: running /bin/prog2` → **`EXEC-DISK-OK`** | the program ran in ring 3 on real Zen; its `write(1,…)` reached the FB | no `EXEC-DISK-OK` (ring-3 / SMAP / SYSCALL failure on silicon) |
| A4 | Exit code captured (★ dispositive) | **`run: exit 42`** | `exec_and_wait` resumed the kernel with the program's code | no `run: exit 42` |
| A5 | argv[1] deref (1.40.8) | `exec: running /bin/argv Z` → **`run: exit 90`** | `argc≥2` AND `argv[1]` points at the real `"Z"` in the user stack | no `run: exit 90` |
| A6 | Clean return | **`exec: selftest done`** | `exec_and_wait` returned cleanly into its caller (shell-loop shape) | boot halts at the last `run: exit` |
| A7 | Post-burn FS intact | from Linux, `e2fsck -fn` the agnos-fs | the prog2/notelf/argv writes are clean on NAND | any e2fsck error |

**Expected, not a falsification:** only **2** programs run per boot (prog2 + argv) — a 3rd exec exhausts the 2 MB-page pool (no process teardown yet; that's the next exec bite). The AMD Zen FB scanout banding is the known parked cosmetic residue ([[project_amd_zen_scanout_residue]]), not a regression.

### Tracker: 1.38.x cycle — JBD2 journaling iron burn (BURNED 2026-05-28 — read-side PASS @ 1.38.9; write-side commit + 100-tx stress + mid-cycle power-cut recovery all PASS @ 1.38.10 re-burn — **ARC IRON-COMPLETE**) {#tracker-138-cycle}

**Hypothesis (pre-burn).** The JBD2 stack that is QEMU-`e2fsck -fn`-clean across replay + crash smokes would mount-probe, replay, produce a journaled write, and survive power-loss on real NAND — all against the unmodified archaemenid agnos-fs.

**Outcome.** Read-side **CONFIRMED**; write-side **FALSIFIED-as-untestable** by a wrong premise, not a code bug. The real agnos-fs journal is **CSUM_V3 + 64BIT** (`incompat=0x12`, `csum_type=4`/CRC32C) — audit §6's "mkfs.ext4 doesn't enable CSUM_V2/V3 by default" was false (host e2fsprogs 1.47.4 enables `metadata_csum` → CSUM_V3 journal by default). The 1.38.7 narrow-scope guard refused every `commit_tx`, so integration (Test 4) and crash (Test 5) couldn't exercise the write path. **Probe + SB-csum-validate + read-side proven on a real CSUM_V3 journal; baseline e2fsck clean (`fsck_log_1.txt`); nothing corrupted.** Full burn entry below.

**Falsification criteria for the re-burn** (after CSUM_V2/V3 write support lands): integration must show `jbd2: commit_tx: COMMITTED seq=K n_blocks=N` (not the refusal line) + host `e2fsck -fn` clean; crash must show a real DIRTY→replay→clean cycle. Until then the write-side claim stays open. Disposition fork (implement CSUM_V3 write now vs. re-mkfs `-O ^metadata_csum` to validate the existing non-csum path) is the user's call.

**Disposition (2026-05-28): user chose "implement CSUM_V3 write." DONE at agnos 1.38.10** — CSUM_V2/V3 tag/descriptor/commit checksums on both write + replay sides, formats re-derived from `include/linux/jbd2.h` + `fs/jbd2/commit.c`. **Linux-`e2fsck` oracle-validated** (e2fsck replays an AGNOS-format CSUM_V3 journal clean; a corrupted commit csum → "transaction was corrupt"). All five jbd2 smokes re-run on a CSUM_V3 journal (stamped via `mk-dirty-journal-img.py --csum-v3`, mirroring Linux's first-RW-mount stamp): **integration now shows `commit_tx: COMMITTED` where iron showed the refusal**; writepath / tx / replay / crash(4/4) green; `test.sh` 4/4, `check.sh` 11/11. Also fixed a latent legacy-tag field swap (`t_flags`/`t_checksum` offsets) that made pre-1.38.10 AGNOS journals non-Linux-replayable. Detail → CHANGELOG `[1.38.10]` + [`ext4-jbd2-prior-art.md`](prior-art/ext4-jbd2-prior-art.md) §8.

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

<!-- ============================================================
     PRE-STAGED SKELETON — combined 1.39.x VFS + 1.40.x exec burn
     Fill in after the burn (the user will return with FB photos +
     host e2fsck/fsck output). Track A (exec) is the primary/dispositive
     new-work track; Track B (FAT/exFAT verbs) folds the long-pending
     1.34.x carry-forward. Delete this comment when the entry is filled.
     Trackers: #tracker-140-cycle (exec) + #tracker-139-cycle (VFS).
     ============================================================ -->
### 1.39.x VFS + 1.40.x exec-from-disk combined iron burn (2026-05-30, boots `1408_*`) — PARTIAL (Track A 3/4; A3 ring-3 run RESETS)

**One hardware session.** Staged via `agnos/scripts/burn-prep.sh`; FAT/ext2-write + exec smokes QEMU-green at agnos **1.40.8** (`EXEC_SELFTEST=1 EXT2_WRITE_SELFTEST=1`, self-seeds `/bin/prog2` + `/notelf` + `/bin/av`).

**Track A — exec-from-disk (primary/dispositive; [`#tracker-140-cycle`](#tracker-140-cycle)). 3/4 first try.**
- **A1 boot/mount**: **PASS** — `1408_boot1.jpg`: full storage trio, `jbd2: clean journal seq=142`, FAT32 mount, the complete `ext2w:` W2–W5 write suite (`Wsync state OK`), `shtest: SHELL-WROTE-IT`.
- **A2 ENOEXEC**: **PASS** — `1408_boot2_crash.jpg`: `exec: running /notelf` → `run: not an executable`.
- **A3 `EXEC-DISK-OK`** (ring-3 run on real Zen) ★: **FAIL — spontaneous reset.** Last FB line `exec: running /bin/prog2`; box resets before `EXEC-DISK-OK`. No panic — a triple-fault → CPU reset.
- A4–A7: not reached.

**CMOS bisection (`read-boot-log.sh`): `CMOS[0x50]=0x20`, magic 0x51=0xAB.** 0x20 is stamped only at `ring3.cyr` immediately before the `iretq` into ring 3 (1.40.3+ exec path only). So the **entire load path succeeded** (`elf_load_from_file` + `proc_create_address_space` + `pmm_alloc_2mb` + argv-stack + page maps); **the fault IS the ring-3 transition** (iretq / first instruction / first SYSCALL) on real Zen — QEMU `-cpu max` passes the identical binary 7/7. (Stale xhci/FB/gnoboot slots + the script's stale r8169-era "expected" comparisons in that dump are noise; only 0x50/0x51 load-bearing.)

**Ruled out (re-derived from source):** CS/SS iretq selectors (0x23/0x1B correct for this GDT's non-standard uDS@0x18/uCS@0x20 order, confirmed by SYSRET STAR base); SMEP/SMAP (smoke is `-cpu max` + boot_shim enables CR4.SMEP/SMAP on the Path-C handoff); 2 MB alloc>4 GB (pmm pool is fixed 16 MB, regions 1–7); boot-path divergence (smoke boots gnoboot+OVMF, same Path C as iron).

**Disposition → agnos 1.40.9 (the silent reset is its own bug).** The IDT pointed all 256 vectors at a bare `iretq`, so ANY transition fault → mis-return → #DF → #TF → reset. 1.40.9 installs real #UD/#DF/#TS/#NP/#SS/#GP/#PF handlers that stamp the fault vector to **`CMOS[0x54]`** + magic `0xE5` to **`CMOS[0x55]`**, then `cli;hlt`. QEMU exec-smoke 7/7 + check 11/11 (handlers dormant when nothing faults). Iron kernel built (1,040,464 B EXEC selftest — the flashed artifact; the plain production 1.40.9 build is 1,036,592 B). *(exFAT-write sweep row is red on the clean baseline too — host `mkfs.exfat` 1.3.2 format drift, orthogonal; filed `agnos/docs/development/issue/2026-05-31-exfat-write-mkfs-1.3.2-drift.md`.)*

**1.40.9 RE-BURN RUBRIC (user-driven; no auto-run).** Flash the 1.40.9 EXEC selftest kernel, reproduce A3. Expected: instead of a reset, the box **HALTS** at `exec: running /bin/prog2`. Then `sudo agnosticos/scripts/read-boot-log.sh --verbose`:
| `CMOS[0x55]` | `CMOS[0x54]` | Means | Points at |
|---|---|---|---|
| 0xE5 | 0x0D | #GP | bad CS/SS descriptor type at iretq/sysret |
| 0xE5 | 0x0E | #PF | unmapped entry/stack VA (CR2 = the addr) — entry-page perms |
| 0xE5 | 0x06 | #UD | bad opcode — e.g. SYSCALL with EFER.SCE clear |
| 0xE5 | 0x08 | #DF | fault during fault delivery — TSS RSP0 (0x200000) reachability |
| (no 0xE5) | — | still reset | the fault is a vector we didn't arm, OR pre-iretq — re-audit |

That vector is the actual root cause; it drives the 1.40.9 follow-on fix (folded into the still-open .9).

**Photos**: `1408_boot1.jpg` (A1 pass), `1408_boot2_crash.jpg` (A2 pass + A3 last-line-before-reset) at agnosticos top level — catalogue under [`iron-nuc-zen-photos/`](iron-nuc-zen-photos/README.md).

### 1.40.9 exec re-burn (2026-05-31, boot `1409_boot_lock.jpeg`) — **THE 1.40.9 HANDLER WORKED: silent reset → readable #PF.**

**Dispositive datum (rubric [row 159](#tracker-140-cycle)):** `read-boot-log.sh --verbose` reads **`CMOS[0x55]=0xE5`** (the new fault-handler magic — a real exception was caught this boot) + **`CMOS[0x54]=0x0E`** → **vector 14 = #PF**. The box **HALTED** at `exec: running /bin/prog2` (the `1409_boot_lock` photo = the handler's `cli;hlt`) instead of spontaneously resetting — **the 1.40.9 disposition is validated: the IDT now catches the transition fault instead of triple-faulting into a CPU reset.** (Script preamble still prints the stale r8169-era "CR4 byte 2 / expected 0x30" labels for 0x54/0x55 — [[feedback_script_preambles_are_forward_looking]]; the live semantics are idt.cyr's fault-vector stamp. `read-boot-log.sh` should be re-labelled to the 1.40.9 fault-stamp meaning.)

**What #PF means here.** `CMOS[0x50]=0x20` (the pre-`iretq` stamp at `ring3.cyr:115`) confirms — as on 1408 — the entire load path succeeded and the box reached the ring-3 `iretq`. The #PF fires on the **first user VA touched after the transition** (instruction fetch at `entry`, or first stack access at `rsp`). The fault is a **paging** fault (a VA access), NOT a selector fault — so CS/SS/iretq-frame are confirmed sound (a bad descriptor would be #GP=0x0D, not #PF).

**Static audit (no-burn, source-re-derived) — the textbook cause is RULED OUT.** The classic real-AMD-vs-QEMU #PF (intermediate page-table levels missing U/S, so the per-level AND demotes the leaf to supervisor) does **not** apply: `paging.cyr:39-40` boot CR3 = `PML4[0]=0x2007 / PDPT[0]=0x3007` (U/S set); `proc.cyr:195-197` per-process CR3 = `PML4[0]/PDPT[0] | 0x07` (U/S set); the exec code+stack pages map via `proc_map_page` → `0x87` (P\|W\|U\|PS) on 2 MB-aligned `pmm_alloc_2mb` frames (`elf.cyr:202-205,232-235`); `rsp = stack_base+0x3000` sits inside the mapped 2 MB page, guard page below is the intended unmap. **All four levels carry U/S; entry+stack are mapped user-executable/user-writable.** So the #PF is a real-silicon condition the static mapping does not explain — it needs **CR2 (the faulting VA) + the #PF error-code** (I/D, U/S, P, RSVD bits) to localize. Any behavioral repair before that is a guess ([[feedback_audit_re_derive_dont_validate_comments]]).

**Secondary anomaly — ext2w write suite regressed vs 1408.** The `1409` photo shows **MISMATCH** on `W4 create+write`, `W5 mkdir`, `Wren file`, `Whard link`, `Wsym fast`, `Wsym slow`, `Wsymres resolve` — every subtest that **allocates a new inode then reads its content/linkage back**; the round-trip / removal / refusal / existing-inode subtests (`W2`, `W3 ×3`, `W4 unlink`, `W5 rmdir`, `Wren xdir/refuse`, `Whard refuse-dir`, `Wuninit`, `Wsync`) all PASS. The same suite was **all-OK on 1408** (entry above, A1). 1.40.9 only added IDT handlers — it does not touch ext2 — so this is **almost certainly selftest non-idempotency on the now-polluted persistent NVMe FS** (the 1.37.4-class re-boot bug: a fixed-name create collides with residue the 1408 run + this run's exec self-seed left on disk), **not FS corruption**. **Confirm: `sudo e2fsck -fn /dev/nvme0n1p2` from Linux** — clean ⇒ selftest-idempotency (harden the ext2w seed to delete-before-create like the 1.37.4 extent fix); any error ⇒ real write regression (escalate).

**Next step is a fork (user's call — burns block other work, [[feedback_iron_burns_block_other_work]]).** (A) **CR2 + err-code capture** — the 1.40.9 #PF handler is one `mov rax,cr2` + a two-byte CMOS stamp away from the faulting VA + error-code; the rubric (row 159) already names CR2 as the needed datum, so this is the pre-agreed continuation of the approved diagnostic, not a new ladder. It turns the next burn from a guess into a localization. (B) **behavioral-audit-stack** — multi-source re-derive (APM Vol 2 §5.4 page-walk + iretq-CPL-change, xv6/Linux ring-3 entry) of every remaining real-only divergence and stack the repairs into one burn. Recommend **(A)** — with U/S already exonerated, CR2 is the only thing that tells us *which* page, and (B) without it risks another wasted re-cable.

**Fixes shipped 2026-05-31 (user picked path A; both QEMU-green, fold into the open 1.40.9).**
1. **CR2 + #PF error-code capture** (`idt.cyr` `exc_handlers_init`, v==14 only). The #PF stub now also stamps, via the *proven* low CMOS bank (0x70/0x71 — the extended 0x72/0x73 bank read back noise at 1409: `CMOS[0x86]=0x5A`, not the 0xCC sentinel): `[0x5C]`=CR2 bits 23:16 (the code-vs-stack discriminator — 0x40 = code `~0x4xxxxx`, 0x80/0xC0 = user stack), `[0x5D]`=CR2 15:8, `[0x5E]`=CR2 7:0, `[0x5F]`=#PF error code (bit0 P, bit1 W/R, bit2 U/S, bit3 RSVD, bit4 I/D). These overload the r8169 RX slots (r8169 runs at boot, long before exec → last-writer-wins on a #PF-halt boot; `read-boot-log` decodes the dual meaning). Register-only except `[rsp]`=the CPU-pushed error code. Per [[feedback_no_instrumentation_means_no_instrumentation]] this is the **pre-agreed continuation of the approved 1.40.9 diagnostic** (rubric row 159 already named CR2), not a new ladder — the handler exists; this completes it.
2. **ext2 duplicate-dirent guard** (`ext2_create` + `ext2_mkdir`). **The 1409 e2fsck came back DIRTY, not clean** — "Duplicate entry 'w3a.txt'/'prog2'", ~5 copies of every selftest name, "Filesystem still has errors." Root cause: `ext2_create`/`ext2_mkdir` called `ext2_dir_insert` **unconditionally** (no existence check — unlike `ext2_link`/`ext2_rename` which already refuse), so each boot appended another dirent with the same name. Fix: lookup-first → create returns the existing inode (POSIX `O_CREAT`-no-`O_EXCL`), mkdir returns it if a dir / refuses on a file conflict. Makes the selftest seed idempotent across reboots **and** closes a real base-FS correctness gap. *This also reframes the "secondary anomaly" above: the ext2w MISMATCHes were the symptom of duplicate dirents (readback resolved to a stale duplicate inode), and the corruption was real — the earlier "almost certainly not corruption" hedge was wrong; e2fsck settled it.*

**User iron note: "first boot reset, then each attempt after locked up."** The reset-vs-halt non-determinism tracks the corrupted FS. A *halt* = the #PF handler caught it (gave us `0x54=0x0E`); a *reset* = an **uncatchable** path — a fault during fault delivery (#DF whose own push also faults → triple-fault), or a fault on a vector we don't arm. As the duplicate-dirent state shifted boot-to-boot, the fault landed differently. **Caution:** a duplicate/garbage `/bin/prog2` dirent can make the exec path stream-load the *wrong* blocks → a corrupt ELF → a #PF that is a corruption artifact, **not** the pure ring-3-transition bug. So the captured `0x54=0x0E` may be partly FS-noise.

**∴ CLEAN THE FS BEFORE the CR2 re-burn** so we localize the *real* fault, not corruption. The dedup fix prevents re-accumulation but can't undo existing dupes — re-mkfs the agnos-fs partition + re-seed (cleanest), or `sudo e2fsck -fy /dev/nvme0n1p2` (repairs in place). Then flash the new selftest kernel + reproduce A3; on the halt, `read-boot-log --verbose` → `[0x5C]` says code (0x40) vs stack (0x80/0xC0), `[0x5F]` says fetch-vs-data + present-vs-perms. **Flash-ready artifact: `agnos/build/agnos` = 1,042,176 B EXEC selftest, 1.40.9, CR2-capture + dedup in** (exec-smoke 7/7 · ext2-write 19/19 · check 11/11). `read-boot-log` rebuilt (97,352 B) with the fault/CR2 decode.

### 1.40.9 CR2 + RIP capture burns (2026-05-31, boots `1409_second_attempt_*` / `1409_fourthboot` / RIP burn) — **ROOT CAUSE FOUND: kernel crossed 2 MB + non-deterministic syscall kstack**

The staged diagnostics fired in sequence and the RIP capture was dispositive.

- **CR2 + errcode** (`1409_second_attempt`, then `1409_fourthboot` with the full 48-bit stamp): **`CR2 = 0x000140006190`** (≈5 GB), err `0x00` = not-present · read · **SUPERVISOR (CPL0)** · data. A kernel-mode read of a wild ≥4 GB address — DISPROVED the "first user VA after the iretq" theory (that would be `U/S=1`). A `read-boot-log` **decoder bug** was found + fixed along the way (the #PF/CR2 decode was gated behind a stale gnoboot-magic heuristic that bailed even with the fault stamps present).
- **Faulting RIP** (this burn): **`RIP(low32) = 0x22220202`**, **`CR2 = 0x010140006190`**. CR2's low 32 bits are **identical** to the prior burn (`0x40006190`); only the bits-40-47 byte differs (`0x00`→`0x01`) — a stable low pointer with **uninitialized high garbage** (zeroed on QEMU, random on Zen). `0x22220202` (~572 MB) is OUTSIDE the kernel image (1–2 MB) and the err code has **no I/D bit**, so that page is mapped+executing: **the kernel transferred control to garbage RAM** (a corrupted `ret`/`jmp` target), then a random byte-stream there read a wild address.

**Static-disassembly audit EXONERATES the exec/resume logic (the state.md leading hypothesis is FALSIFIED).** Disassembled `build/agnos`:
- `exec_and_wait` (`0x10d8af`): standard `push rbp; mov rbp,rsp` prologue; the save writes `[rbp+0]`→exec_ctx[5] (caller rbp), `lea [rbp+0x10]`→exec_ctx[6] (return rsp), `[rbp+0x8]`→exec_ctx[7] (return rip). Correct.
- `kernel_resume` (`0x183746`): `movabs rax,0x1ad370` (=&exec_ctx) then restores rbx/r12-r15/rbp + rsp(exec_ctx[6]) + rdx(exec_ctx[7]) and `jmp rdx`. Correct — `jmp rdx` targets the real `call exec_and_wait` return site (`0x11ae17` in `sh_cmd_run`), not garbage.
- `sh_cmd_run` continuation (`0x11ae17`): `pid` is in **r14** (callee-saved, restored by kernel_resume); the rest is plain direct calls + `leave;ret`. Correct.
  ⟹ the longjmp is a faithful, deterministic round-trip; it cannot be the source of a garbage RIP. The fault is **memory corruption fed into a `ret`**, and the only QEMU-vs-Zen non-determinism in the path is uninitialized RAM.

**Root cause (confirmed in source).** `pmm_init` (`pmm.cyr`) reserved only the **first 2 MB** (pages 0-511) for the kernel — *"kernel + page tables + stack"* — but the kernel's **LOAD MemSiz now reaches `0x20F4E0`** (it crossed 2 MB; `.bss` is ~463 KB). Pages 512-527 (`0x200000-0x210000`) are live kernel `.bss` the PMM treated as free. The syscall kstack (`syscall_kstack_reserve` → `pmm_alloc_2mb`) only landed at the safe `0x200000` (→ top `0x3F0000`) when **region 1 happened to be entirely free** at that point in boot — but the **KASLR-seeded `pmm_next_free` (RDRAND) + the boot allocs before it** (`main.cyr:150-163`: pmm test, `vmm_alloc_at`, `heap_init`) **differ between QEMU and real Zen**. On iron, region 1 could be disturbed first → the kstack **relocated to `0x400000`**, which is the **user-code VA base**: the per-process CR3 maps `0x400000` to the user code page, **overriding** the identity mapping the kstack needs. The first syscall then pushed onto a stack not present under the user CR3 → the syscall call-chain `ret`'d through corruption → **wild #PF at `0x22220202` / `CR2 ≥ 4 GB`**. (This is the same mechanism behind the earlier "~17% exec flake.")

**Fix folded into the open (untagged) 1.40.9 — behavioral; QEMU-validated** (1.40.9 was never tagged, so this rides in it alongside the CR2-capture + dedup fixes; tag .9 after the re-burn confirms, new fixes ride the next build):
1. `pmm_init` reserves the **first 4 MB** (pages 0-1023 = regions 0+1, `0xFF×128` bitmap, `pmm_used=1024`, KASLR hint `1024 + seed%3072`) — covers the >2 MB kernel image AND region 1, which holds the kstack.
2. `syscall_kstack_reserve` pins the kstack to a **FIXED `0x3F0000`** (top of the now-reserved region 1) — no `pmm_alloc_2mb`, no boot-order/KASLR dependency. `0x3F0000` is in the boot 0–1 GB identity 2 MB-page map (P|RW, mirrored into every per-process CR3) and **below** the `0x400000` user-VA base, so no per-process mapping overrides it.
3. Comments at `pmm_alloc_2mb` + the `main.cyr` call site updated. `pmm_alloc_2mb` auto-skips the reserved region 1.

QEMU: **exec-smoke 7/7** (prog2 + argv both run in ring 3, exit codes 42/90 captured, `e2fsck -fn` clean). EXEC-selftest build **1,046,080 B** (MemSiz `0x20F4E0`). **NEXT: dispositive re-burn** — flash this kernel + reproduce A3; expected `EXEC-DISK-OK` + `run: exit 42` on real Zen instead of the #PF halt. Per [[feedback_no_instrumentation_means_no_instrumentation]] this is a behavioral fix, not instrumentation. *(NOTE: bump the `pmm_init` reservation if the kernel image ever crosses 4 MB.)*

### 1.40.9 dispositive re-burn (2026-05-31) — **ROOT CAUSE LOCALIZED: `fb_fb_phys` reads gnoboot's `boot_info` at its ≥4 GB UEFI load address. REAL FIX SHIPPED.**

The kstack/pmm fix held (no reset, no garbage RIP) and the burn was dispositive in a new way. `read-boot-log`: `CR2 = 0x000140006190`, err `0x00` = not-present·read·**SUPERVISOR**·data, **`RIP(low32) = 0x00104fc8`**. Unlike the prior burn's `0x22220202`, this RIP is **inside the kernel image** (1 MB base) — a legitimate kernel instruction doing a wild **data** read.

- **`objdump build/agnos` maps `0x104fc8` → `fb_fb_phys()`** (`kernel/arch/x86_64/fb_console.cyr`): `var bi = load64(&boot_info_ptr); if (bi == 0) return 0; return load64(bi + 0x48);`. The disasm matches byte-for-byte (`movabs $0x1a20b0; mov (%rax),%rax` = the `boot_info_ptr` global load; null-guard; `mov $0x48; add; mov (%rax),%rax` = the faulting deref). So `boot_info_ptr = 0x140006190 − 0x48 = 0x140006148` (~5 GB) and the `== 0` guard passed (garbage ≠ 0). The original truncated `0x6190` was exactly `boot_info + 0x48`.
- **Root cause — NOT a stomp, NOT a wild pointer: gnoboot's *legitimate* load address.** gnoboot is a UEFI PE app; firmware loads it at an arbitrary base, and on archaemenid (RAM-rich Zen) that base is **≥4 GB**. `&boot_info` (passed in RDI, captured into `boot_info_ptr`) is therefore ≈`0x140006148` — low 32 `0x40006148` is the constant offset of `boot_info` inside gnoboot's image; the high bits are the load base. The kernel reads `boot_info` **in place**, which works for the entire boot because **Path C runs on UEFI's all-RAM identity map** (`pt_init` does `mov cr3,cr3` — a TLB flush of the *live UEFI* CR3, never a switch to its own 0x1000 tables). FB works right up to `exec: running /bin/prog2`. Then `exec_and_wait` loads the **per-process CR3, which maps only 0–4 GB** (`pt_init`'s ceiling; the kernel's own tables never mapped ≥4 GB, so the 1.40.9 superset-mirror had *nothing to mirror*). prog2's first `write(1,…)` → console → `kputc`/`fb_putc` → `fb_fb_phys` reads `boot_info` ≥4 GB under that CR3 → unmapped → #PF. QEMU/OVMF loads gnoboot <4 GB, so it never reproduces — the precise QEMU-vs-Zen divergence. Same *class* as the 1.40.6 NVMe-BAR fault, for an address no kernel table ever held.
- The earlier "uninitialized high garbage / wild pointer" read was close but wrong on mechanism: the low 32 bits (`0x40006148`) are a stable real offset, and bit 32 is the (deterministic) load base — not garbage. The byte-5 variation across burns is just the load base's high bits.

**Fix (folded into open/untagged 1.40.9; QEMU-validated):** `boot_info_capture_rdi` (`mbi.cyr`) now `memcpy`s gnoboot's 120 B `boot_info` struct into a new **low (<4 GB) kernel buffer `boot_info_copy[16]`** (`boot_data.cyr`) and repoints `boot_info_ptr` at the copy. The copy runs at the existing top-level capture call — first thing after the boot shim, while UEFI's all-RAM map is the live CR3, long before any per-process CR3 — so the high-source read is safe; every later `fb_fb_phys`/`fb_pitch`/`fb_width`/`fb_height` read is now **CR3-independent**. (`lspci` confirmed the GOP FB BAR is `0xd0000000` = 3.49 GB < 4 GB, already mirrored into the per-process CR3, so pixel writes were never the fault — *reading `boot_info` to find the FB* was.)

QEMU: **exec-smoke 7/7**, **sweep 6/7** (the red row is the pre-existing FAT-write `mkfs`/LFN drift, red on a clean tree; ext2-write + exFAT-write + exec all green). No-op on QEMU (gnoboot loads low) ⇒ zero regression by construction. EXEC-selftest flash artifact **1,046,320 B**, burn-ready. **NEXT: dispositive re-burn — expect `EXEC-DISK-OK` + `run: exit 42` on real Zen → then tag 1.40.9 for release** (closes the base-maturity exec-from-disk leg on iron). Per [[feedback_no_instrumentation_means_no_instrumentation]] this is a behavioral fix, not instrumentation.

### 1.40.9 final exec re-burn (2026-05-31, `1409_final_pass_test_reset_back.jpeg`) — **EXEC-FROM-DISK PASSES ON IRON 🎯 → new reset at DHCP localized to the scheduler (→ 1.40.10)**

**The `boot_info_copy` fix was it — the dispositive bar is cleared on real Zen.** The FB shows the full exec selftest succeeding: the complete `ext2w:` write suite (W2–W5, `Wsync state OK`, all idempotent), `shtest: SHELL-WROTE-IT`, then **`exec: running /bin/prog2` → `run: exit 42`**, **`exec: running /bin/argv Z` → `run: exit 90`**, **`exec: selftest done`**. Rubric [#tracker-140-cycle](#tracker-140-cycle) rows **A1–A7 all green** — exec-from-disk runs in ring 3 on real silicon, the second base-maturity exit leg. The 1.40.x exec arc is **iron-complete**; user tags **1.40.9**.

**New frontier reset (the photo's last line).** With exec done the boot continued — `Heap`, `SYSCALL/SYSRET initialized`, `Stack canary`, `Interrupts enabled`, `Timer ticks before sched: 7`, **`Activating scheduler...`**, then **`dhcp: DISCOVER`** — and the box **reset** (the overlapping `scheduler...` redraw = reboot loop). The user's read ("nothing got changed there") is correct: **DHCP is innocent.** This is a long-latent scheduler bug the *working* exec selftest exposed for the first time.

**Root cause (traced from source, not iron — QEMU can't reproduce it; SLIRP answers DISCOVER before a timer tick lands in the hlt-wait):**
- The flash build is **KTEST-off**, so every `proc_create`/`proc_current` setup in `main.cyr` (lines 1228–1297) is compiled out — **proc 0 is never built in production.** But `exec_disk_selftest()` *does* run: each `run` does `elf_load_from_file → proc_create_full` (bumps `proc_count`) and `sh_cmd_run` sets `proc_current = pid` (`shell.cyr:762`). After the selftest: **`proc_count ≥ 2`, `proc_current` = the last (dead, `state=0`) exec proc**, and `kernel_resume` left CR3 = `0x1000`.
- `sched_active = 1` (`main.cyr:1316`) → `dhcp_init()` prints `DISCOVER` → `arch_wait()` (hlt) → timer IRQ → `do_context_switch` (`sched.cyr:133`): the `proc_count < 2` gate (line 135) — **the gate that used to early-return and let DHCP work at 1.32.9** — now *passes* (selftest created 2 procs). `sched_next()` finds no `state==1` proc (both exec procs dead) → **falls back to `return 0`** (line 27). It then `cr3_load`s that dead exec proc's stale **per-process CR3** and `proc_restore_context` iretqs into a ring-3 user RIP under **CS=0x08 (ring 0)** → triple-fault → **silent reset** (the #PF handler can't run — wrong CR3/CS). That's why it resets instead of halting with a CMOS stamp like 1.40.9's faults did.

**Fix → 1.40.10 (user chose "build a real kernel idle proc 0").** Before `sched_active=1` in the production path, register **proc 0 = the kernel main thread** (running now; context saved on the first switch-away) + **proc 1 = a hlt idle thread** (`sched.cyr` `kernel_idle_loop` + a 4 KB module-scope stack), **both carrying the boot CR3 `0x1000`** (where `kernel_resume` left us post-exec). Because both schedulable procs share one CR3, `do_context_switch`'s `new_cr3 != old_cr3` guard never fires → `cr3_load` is never invoked → preemption is pure register save/restore in a single shared address space (a kernel-threads model; per-process-AS preemption is the future multi-threading arc, [[project_multithreading_future_arc]]). `#ifndef KTEST`-gated so the KTEST proc_a/proc_b test is untouched.

**Validation (QEMU — regression gate only; the reset is iron-timing-specific so QEMU can't confirm the *fix*):** build clean; `exec-smoke.sh` **7/7**; boot now advances `Activating scheduler...` → `Launching kybernet...` with no fault (no NIC attached in that config, so the DHCP block is skipped — exactly why QEMU never caught the iron reset). `sweep.sh` **6/7**, **byte-identical to the clean-tree baseline** — the one red is **pre-existing exFAT-*read*** (`upcase-checksum` chain read), reproduced after `git stash`-ing this change (note: the red row has *moved* from the FAT-write drift state.md documented — FAT-write now passes; the exFAT-read red is a separate pre-existing issue). EXEC-selftest burn artifact **1,050,592 B** (`burn-prep.sh`, exit 0), burn-ready.

**1.40.10 RE-BURN RUBRIC (user-driven; behavioral fix, not instrumentation — [[feedback_no_instrumentation_means_no_instrumentation]]).** Flash the 1.40.10 EXEC selftest kernel; reproduce through `exec: selftest done` (should still PASS A1–A7), then watch past `Activating scheduler...`:
| Read-out (FB) | Means | Verdict |
|---|---|---|
| `dhcp: DISCOVER` → `dhcp: ACK ip=…` (or `DHCP failed -- using static fallback`) → `arp: request -> gateway` → reaches shell | scheduler ping-pongs kmain↔idle through the DHCP hlt-wait without faulting | **PASS — DHCP reset fixed** |
| reset/halt at/after `dhcp: DISCOVER` again | the idle-proc setup didn't cover the path (CR3 mismatch? proc_current still a dead exec proc on a later tick?) | re-audit; `read-boot-log --verbose` for a #PF stamp |

**1.40.10 bite 2 — LANDED (rides this same burn).** Interactive `run <prog>` post-boot left `proc_current` on the dead exec proc; the next timer tick's unconditional `proc_set_state(old,1)` (`sched.cyr:150`) resurrected it → it'd later be scheduled → ring-0 user-code switch. Fix: `kernel_resume` now resets `proc_current = 0` (the kmain thread) after clearing the return-point globals, so every post-exit tick switches kmain↔idle only. Exit-code attribution safe (`sh_cmd_run` reads the local `pid`, `shell.cyr:765`; code stamped before `kernel_resume`). QEMU exec-smoke 7/7 (multi-run selftest exercises `kernel_resume` twice — both exit codes 42/90 still attribute) + sweep 6/7 (same pre-existing exFAT-read red). Bite 1 makes scheduler *activation* crash-safe; bite 2 makes interactive `run` crash-safe — both ride this burn. (Remaining follow-on, NOT a crash: no process teardown — ~14 runs exhaust `proc_table`; a later exec bite.)

**Photo**: [`iron-nuc-zen-photos/1409-agnos-1.40.9-exec-from-disk-pass-exit-42-90-then-dhcp-discover-reset.jpg`](iron-nuc-zen-photos/1409-agnos-1.40.9-exec-from-disk-pass-exit-42-90-then-dhcp-discover-reset.jpg) (phone-label `1409_final_pass_test_reset_back`) — catalogued in [`iron-nuc-zen-photos/README.md`](iron-nuc-zen-photos/README.md). The other four 1409 boots (`1409_boot_lock`, `1409_second_attempt_boot1/boot2`, `1409_fourthboot_idempotent`) are filed there too.

### 1.40.13 mount-routing + 1.40.10 scheduler + 1.40.12 boot-stack combined iron burn (2026-05-31, boots `14013_*`) — **WHOLE 1.40.x ARC IRON-VALIDATED 🎯**

**Build flashed**: 1.40.13 (`EXEC_SELFTEST` + `FATFS_WRITE_SELFTEST` + `EXT2_WRITE_SELFTEST`), `install-usb.sh --update`. One bug-capture boot then a routing-fixed re-burn (3 shots).

**Bug boot — `14013_boot_cmd_fails`** (Track B, the mount-routing failure that 1.40.13 was cut to fix): raw `fatw:` backend tests all PASS, but the shell-routed pass fails wholesale — `vfsw: shell touch+echo over FAT ->` → `touch: no such directory` / `mkdir: no such parent` / `rmdir: no such path` / `rm: no such path` / `mv: no such src directory` / `echo: no such directory` (strings that ONLY come from the ext2 branch ⇒ every verb routed to ext2 while FAT owned the path). The `ext2_active`-flag routing, exactly as diagnosed. Motivated the `{prefix→backend}` mount-registry rewrite.

**Routing-fixed re-burn — `14013_final1/2/3`** (the dispositive PASS; one boot, three shots):
- **pt1 (`14013_final1`)**: `ext2:` mounted at `/` (clean journal `seq=4`) + `fat: mounted FAT32`, both live. `fatw:` suite green, then the previously-failing shell pass succeeds — `vfsw: shell touch+echo over FAT ->` → `sync: clean` → `vfsw: subdir paths over FAT done` → **`SUBDIR-FAT-OK`** → `vfsrf: FAT whole-file read past 4KB OK`. **FAT-through-shell while ext2 owns `/` — the exact iron config the bare-name version couldn't reach. Mount-namespace routing (1.40.13) iron-validated.**
- **pt2 (`14013_final2`)**: ext2w csum-match chain + full write suite (W2 alloc/free, W3 write/read/sparse/truncate, W4 create+write/unlink, W5 mkdir/rmdir, Wren) — no regression from the routing change.
- **pt3 (`14013_final3`)**: ext2w tail (Wsym/Wsymres/Wuninit/Wsync), `shtest cat: SHELL-WROTE-IT`, then the boot completes **clean through** SYSCALL/SYSRET → canary → interrupts → `Timer ticks before sched: 6` → `Activating scheduler...` → **`dhcp: DISCOVER` → `OFFER ip=192.168.1.157` → `REQUEST` → `ACK ip=192.168.1.157 gw=192.168.1.1 mask=255.255.255.0 dns=192.168.1.1`** → `arp REPLY gw_mac=d4:6a:91:ce:70:60` → `net: L2 OK — gateway MAC cached` → **`Launching kybernet...`** — **NO RESET.**

**What this burn validated (four cuts in one boot):**
- **1.40.13 mount-namespace routing** — FAT shell verbs reachable while ext2 owns `/` (pt1). Track B of [`#tracker-139-cycle`](#tracker-139-cycle) ✓.
- **1.40.10 scheduler-reset fix** — the box rides cleanly through `Activating scheduler...` and the DHCP hlt-wait that reset it at the 1.40.9 final burn (pt3). [`#tracker-14010-cycle`](#tracker-14010-cycle) ✓.
- **1.40.12 boot-stack relocation to `0x380000`** — no rodata-corruption symptoms; full clean boot (pt2/pt3). ✓.
- **1.40.9 exec-from-disk** — already validated at the 1409 burn; the exec selftest ran clean again here.

**Net: the entire 1.40.x exec-from-disk + VFS-routing arc is iron-validated.** Base maturity (FS-crash-safe + exec-from-disk + scheduler-past-activation) is closed on hardware. **Open: only the 1.40.14 closeout re-burn** (process teardown/reaping — `proc_reap`/`proc_free_address_space`, QEMU exec-smoke 7/7 + sweep functional 6/6 + reap-stability assertions green; rides the next Track-B FAT/exFAT verbs burn, which can now collapse to one boot since both backends mount at once).

**Photos**: [`14013-agnos-1.40.13-mount-routing-bug-fat-shell-verbs-fail-vfsw-no-such-dir.jpg`](iron-nuc-zen-photos/14013-agnos-1.40.13-mount-routing-bug-fat-shell-verbs-fail-vfsw-no-such-dir.jpg) + the three `14013-agnos-1.40.13-mount-routing-fixed-pt{1,2,3}-*.jpg` shots — catalogued in [`iron-nuc-zen-photos/README.md`](iron-nuc-zen-photos/README.md).

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

**Finding — audit §6 premise FALSIFIED.** [`ext4-jbd2-iron-burn-audit.md`](prior-art/ext4-jbd2-iron-burn-audit.md) §6 asserted "archaemenid's mkfs.ext4 doesn't enable CSUM_V2/V3 by default." **Wrong.** The real agnos-fs journal is **CSUM_V3 + 64BIT** — modern e2fsprogs (host runs 1.47.4) enables `metadata_csum` by default, which produces a CSUM_V3 journal. The QEMU smoke images used non-csum journals (the `jbd2-refusal-smoke.sh` "no SB csum to recompute" path), so the write-path gap was invisible in QEMU. **Write-side iron validation of the whole 1.38.x arc (commit / checkpoint / replay-of-own-tx) is BLOCKED until CSUM_V2/V3 commit-block + descriptor-tag + data-block checksums are implemented** in the write path.

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
