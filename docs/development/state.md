---
name: AGNOS Ecosystem State
description: Live cross-repo state — Cyrius cycle, pin-lag spectrum, active sweeps, carry-forward debt
type: state
---

# AGNOS Ecosystem — Current State

> **⚠ NOT A LOG.** This file is **live state with pointers** — current truth only, plus links to where the history lives. Iron attempt history → [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md). Per-repo release history → each repo's `CHANGELOG.md`. Crate versions → the two registry pointers below. If you find yourself writing prose narrative here, it belongs in one of those other files.

> **Cyrius toolchain**: 6.0.1 (v6.0.0 cycle opened 2026-05-19; same-day .1 patch fixed a UEFI-emit `fncallN` regression — see [`issues/2026-05-19-cycc-6.0.0-uefi-fncall-ud2-emit.md`](issues/2026-05-19-cycc-6.0.0-uefi-fncall-ud2-emit.md)). v5.11.x closed at **5.11.69** on 2026-05-19.
> **Last refresh**: 2026-05-26 (eve). **agnos kernel 1.34.0 OPEN 2026-05-26 — FAT-family filesystems arc (FAT write → exFAT); opens the additional-FS roadmap row 21. FS choice decided 2026-05-26: FAT-family first, NTFS + squashfs deferred to row 23. Lean cycle-open: VERSION 1.33.5 → 1.34.0, CHANGELOG header, tracker [`#tracker-1340-cycle`](iron-nuc-zen-log.md#tracker-1340-cycle); no code bites yet. **Bite 1 (multi-source audit, [`fat-family-prior-art.md`](fat-family-prior-art.md)) LANDED 2026-05-26** — the diff against `fatfs.cyr` found 5 gaps bigger than "no write": (1) wired only in the virtio-blk branch → never runs on iron; (2) whole-disk absolute LBA 0, not partition-aware; (3) no FAT-chain traversal (reads only the first cluster, ≤512 B); (4) FAT16-layout-only (FAT32 mis-parses); (5) 8.3-only, no LFN, no write. So the arc matures the driver — gaps 1–4 (partition-aware multi-backend mount + FAT-chain traversal + FAT32 + LFN read) are the **precondition** → FAT write (first *second* writable FS, the concrete trigger for the 1.39.x VFS generic-write lift) → exFAT (a sibling FS, not a mode flag). **Bite 2 (FAT32 read parity + partition-aware multi-backend mount + cluster-chain traversal) LANDED + QEMU-VALIDATED 2026-05-26** — `fatfs.cyr` rewritten to the ext2 mount pattern (`fat_blk_read`=`blk_read_on`, lifted out of the virtio-only branch), FAT32 BPB + `CountOfClus` type test, `fat_next_cluster` chain follow; new `fat-smoke.sh`/`FATFS_SELFTEST` gate PASSED (`fat: mounted FAT32 backend=2 partition_lba=2048` + `fatr: chain-read OK` on a 3000-B multi-cluster `FATTEST.BIN`, byte-exact past the old 512-B cap). Build 722,064 B; `test.sh` 4/4, `ext2-smoke` 5/5, `ext2-write-smoke` W1–W5 PASS (no regression). Residual read item: LFN reassembly (8.3 works today). **Bite 3 (FAT write) sub-divided; 3a (empty-file create — the dirent-write primitive: `fat_blk_write` + `fatfs_create`/`fatfs_emit_dirent` + `fatfs_build_83` refactor) LANDED + QEMU-VALIDATED 2026-05-26** — new `fat-write-smoke.sh`/`FATFS_WRITE_SELFTEST` creates NEWFILE.TXT in the FAT32 ESP (alongside the real boot files): `fatw: create NEWFILE.TXT rc=0` + `fsck.fat -n` clean + `mdir` confirms persistence. Build 724,048 B; test.sh 4/4, ext2-smoke 5/5, FAT read regression intact. **Bite 3b (cluster allocator + multi-cluster content write) LANDED + QEMU-VALIDATED 2026-05-26** — `fat_get_entry`/`fat_set_entry` (all FAT copies; FAT12 write refused) + `fat_alloc_cluster` + `fat_fsinfo_mark_unknown` + `fatfs_write_file` (ordered: alloc+link+write data before publishing the dirent). `fat-write-smoke.sh` extended: 3000-B multi-cluster `WTEST.BIN` → `rc=0` + `fsck.fat -n` clean + `mtype` byte-exact (`cmp`). Build 729,232 B; test.sh 4/4, ext2-smoke 5/5, FAT read regression intact. **Bite 3c (delete + truncate-to-zero) LANDED + QEMU-VALIDATED 2026-05-26** — `fat_free_chain` + `fatfs_delete` (dirent-`0xE5`-first then free chain) + `fatfs_truncate_zero` (clear dirent then free chain); `find_inner` records dirent loc. `fat-write-smoke.sh`: write+delete DELME.BIN + write+truncate TRUNC.BIN → `fsck.fat -n` clean after freeing both chains (no leaked clusters), DELME absent, TRUNC 0 bytes. Build 731,072 B; test.sh 4/4, ext2-smoke 5/5, FAT read intact. **Core FAT mutation set (create/write/delete/truncate) complete + all fsck-clean.** **NEXT = bite 3d: LFN write + shell verbs** (`touch`/`rm`/`echo>` on the FAT mount). Then bite 4 exFAT. Iron-safety follow-on still pending (prefer MSFT-Basic over ESP for the write mount, or write-guard the ESP) before the final iron burn; ENOSPC-rollback + overwrite-existing + arbitrary-length-truncate are noted follow-ons. 1.33.1–1.33.5 all RELEASED (1.33.5 tagged 2026-05-26: fsync/FLUSH-CACHE durability barrier — `blk_flush()` across all 5 block backends, `sync` now end-to-end durable; CLOSED the 1.33.x ext2/ext4 WRITE patch line — see [`#tracker-1335-cycle`](iron-nuc-zen-log.md#tracker-1335-cycle)).** (1.33.2 shipped standalone as a lockup-hardening cut; the WRITE follow-ons moved to 1.33.3.) 1.33.1 implemented real-`mkfs.ext4` WRITE (metadata_csum + 64bit) and the **W5 iron burn PASSED 2026-05-25** (the demo→base maturity exit, confirmed on iron: `echo > /persist.txt` → power-cycle → `agnos> ls` shows `persist.txt` on an UNMODIFIED default partition, no re-carve — photo [`1331-agnos-1.33.1-write-w5-persist-txt-survives-reboot-default-mkfs-ext4-shell-ls.jpg`](iron-nuc-zen-photos/1331-agnos-1.33.1-write-w5-persist-txt-survives-reboot-default-mkfs-ext4-shell-ls.jpg), phone-label `1331_After_Reboot`). **1.33.3 scope** (the WRITE follow-ons, moved from 1.33.2): `rename`/`mv`, hardlink/`ln`, symlink-create/`ln -s` (all ride W4's dirent insert/remove + inode primitives), plus `s_state` dirty/clean + a `sync` verb. Remaining 1.33.x follow-ons → **1.33.5** (fsync/FLUSH-CACHE barrier — uninit_bg materialization + symlink resolution LANDED in 1.33.4 alongside the lockup fix); the big own-cycle writes → **1.37.x** ext4 **extent allocation** / **1.38.x** jbd2 **journaling** / **1.39.x** VFS **generic-write layer**. Then a kernel-slimming separation arc: **1.40.x** console-font → **`kashi`** library; **1.41.x** emergency-shell / shell separation (agnoshi ingests the main-shell role, kernel keeps a minimal emergency shell). (1.40/1.41 are refactors, not write cycles.) Bite plan + falsification rubric: [`iron-nuc-zen-log.md#tracker-1333-cycle`](iron-nuc-zen-log.md#tracker-1333-cycle). Full mutation set — create / write (sparse + truncate) / unlink / mkdir / rmdir + the VFS `vfs_write` arm + shell `touch`/`rm`/`mkdir`/`rmdir`/`echo>` verbs — all `e2fsck -fn`-clean (incl. Pass-4 link accounting) and disk-persistence-verified via host `debugfs` (`scripts/ext2-write-smoke.sh` **22/22 PASS**). **`echo > /f` → reboot → `cat /f` works in QEMU.** Audit-first per [`ext2-ext4-write-prior-art.md`](ext2-ext4-write-prior-art.md); per-phase detail (W1-W5 + W4b, incl. 2 e2fsck-caught unlink bugs) in [`iron-nuc-zen-log.md#tracker-133-cycle`](iron-nuc-zen-log.md#tracker-133-cycle). Release-cleanup: 5 `kprint` byte-length fixes. Build **675,472 B** (1.33.1 was 675,152 B; +320 B for the three 1.33.2 lockup-hardening fixes — see below; the 1.33.2→1.33.3 cycle-open bump is zero structural delta, only `version_str` shifted); `test.sh` 4/4 + `ext2-smoke.sh` 5/5 + `ext2-write-smoke.sh` 22/22. cyrius 6.0.1 · gnoboot 0.4.2. **Lockup-hardening (1.33.2)**: a reported delayed-idle lockup (idle shell, seconds-to-a-minute *after* `bench`) prompted fixes for the three small unbounded/unguarded spots in the bench + serial path — **bounded `serial_putc` THR-empty poll** (was an uncapped `jz` spin; archaemenid has no serial cable per [[feedback_no_serial_on_iron]]), **`bench` memwrite guards `pmm_alloc()==0`** (unguarded deref would clobber physical 0–4095), **`bench` memfile guards the `vfs_create_memfile` fd** (`-1` → OOB `vfs_table` read). Defensive — root cause not yet iron-confirmed; prime remaining suspect is the per-tick `timer_handler`→`do_context_switch` path (documented prior delayed-idle lockup from a register-save bug). Tracker + falsification rubric: [`iron-nuc-zen-log.md#tracker-1332-lockup`](iron-nuc-zen-log.md#tracker-1332-lockup). **W5 close criterion MET** — the 1.33.0 burn (photo `1330_failed_writes`) confirmed the W2 gate refusing write on the default partition; rather than re-carve, 1.33.1 implemented real metadata_csum + 64bit write (7 bites, all `e2fsck -fn`-clean on the `metadata_csum,64bit,extent` profile) and the W5 iron burn (photo `1331_After_Reboot`) confirmed persistence across a power-cycle. Burn audit: [`metadata-csum-write-iron-burn-audit.md`](metadata-csum-write-iron-burn-audit.md). **🎯 1.33.3 CYCLE QEMU-COMPLETE 2026-05-25** — all four dirent-mutation bites LANDED + `e2fsck -fn`-clean on `metadata_csum,64bit,extent`: bite 1 `rename`/`mv` (cross-parent dir move `..`-repoint + link counts), bite 2 hardlink/`ln` (link-count-first, refuses dir hardlinks), bite 3 symlink-create/`ln -s` (fast inline / slow data-block), bite 4 `s_state` dirty/clean + `sync` verb (honest no-journal). Full regression green (W1–W5 + W4b). Build 692,112 B, fmt clean. **NEXT = user tag of 1.33.3** (optional iron burn `mv`/`ln`/`ln -s`/`sync` on the real partition is user-driven, NOT auto-proposed). **🎯 1.33.4 (interactive-lockup root-cause, RELEASED 2026-05-26)** — the iron freeze in photo `1333_issue_shown` (shell froze mid-keystroke on `echo hell`) was **REPRODUCED off-iron** by a new QEMU `usb-kbd`/`sendkey` harness ([`agnos/scripts/lockup-repro.sh`](../../../agnos/scripts/lockup-repro.sh)) — froze at `agnos> u`, tick ~600, with the vCPU still `running` (it's keyboard-input death, not a hard CPU lock). Root cause: the **HID keyboard transfer ring had no Link TRB**, so the controller ran off the 256-TRB page after ~255 reports and the IN endpoint stalled. **Two findings**: (1) the context-switch path is **inert in production** (`do_context_switch` early-returns on `proc_count < 2`; the test procs are `#ifdef KTEST`) — this RETIRES 1.33.2's "prime suspect"; (2) the missing Link TRB is the actual cause. **bite 1 fix applied** — mirror the command-ring Link-TRB + wrap pattern on the kbd transfer ring (`hid.cyr`); a 300 s QEMU run drove 828 commands with ticks rising to ~30,000 across ~45 ring wraps, zero stall (vs the ~600-tick / ~18-command pre-fix freeze). **Bites 2-3 (the planned FS items, folded back in): symlink resolution** (`ext2_path_lookup` follows symlinks — fast/slow + ELOOP cap; completes 1.33.3's create-only) **and uninit-group materialization** (`ext2_materialize_{inode,block}_bitmap` on first alloc into an `INODE_UNINIT`/`BLOCK_UNINIT` group — closes a latent corruption risk on the real iron partition the single-group write-smoke couldn't catch; legacy `uninit_bg`/GDT_CSUM ro_compat 0x10 stays refused). All verified in QEMU: `ext2w: Wsymres resolve OK` + `Wuninit materialize OK`, `e2fsck -fn` clean; new `ext2-uninit-smoke.sh` on a 1.1 GiB flex_bg image. Regression: `test.sh` 4/4 (size ceiling 700→800 KB), `ext2-smoke` 5/5, `ext2-write-smoke` 49/0. Production build 707,896 B. Tracker: [`iron-nuc-zen-log.md#tracker-1334-lockup`](iron-nuc-zen-log.md#tracker-1334-lockup). (Prior: 1.32.7/1.32.8/1.32.9 RELEASED — networking arc complete, DHCP lease iron-verified.)
>
> **Active iron work — r8169 RX of UNICAST frames on archaemenid (NUC AMD): 🎯 SOLVED 2026-05-25.** TX, broadcast/multicast RX, L2 gateway reachability, and now **unicast RX** are all PROVEN on iron. The unicast MAC filter was cleared at bite-3 (silicon `rx_uc`>0 — physical-match accepts unicast); the residual blocker was **RX ring DELIVERY CAPACITY** — clean unicast frames (`rx_err=0 align=0`) dropped for no free descriptor in a 16-deep ring. **bite-4 (whole-ring drain in `net_poll`, budget=64) FALSIFIED** (`missed` 158 → 176 — a drain budget can't exceed the 16 descriptors that physically exist) → **bite-5 (deepen RX ring 16 → 64, RX/TX `R8169_RING_MASK` split) BURNED → CONNECTED.** The bite-5 framebuffer (`…bite5-rx-ring-16-to-64-connected…jpg`) shows BOTH `net: LAN-TCP OK -- on-LAN unicast handshake established` (MBP peer `.121:80`) AND `net: L3+TCP OK -- outbound TCP handshake established` (`1.1.1.1:80` through the gateway), trailing `r8169: tx_ok=21 rx_ok=103 tx_err=0 rx_err=0 missed=0 align=0 rx_uc=10 rx_bc=47 rx_mc=46` — **`missed` collapsed 176 → 0**, the deeper ring absorbed the LAN-chatter burst and the unicast SYN+ACK (on-LAN *and* off-LAN) finally read. **The entire 1.32.x r8169 unicast-RX arc (1.32.0 → 1.32.7, opened 2026-05-22) is CLOSED — the MVP on-iron networking blocker is cleared.** **1.32.7 RELEASED 2026-05-25** (this victory). **1.32.8 (closeout cleanup, code-complete 2026-05-25)**: gated the `1.1.1.1:80` probe + r8169 silicon tally readback behind `NET_VERBOSE`, removed the `.121` on-LAN-peer discriminator scaffolding (`net_peer_*` slots, the `main.cyr` peer-wait + on-LAN `tcp_connect`, the MBP harness), and de-hardcoded the shell `net`/`send`/`recv`/`tcp` commands off QEMU SLIRP onto `nic_ready()` + the configured gateway (iron-verify the commands on next burn) — **RELEASED 2026-05-25**. **1.32.9 (DHCP re-enablement, code-complete 2026-05-25)**: the `main.cyr` STATIC bypass is removed and `dhcp_init()` re-attempted (STATIC .222 as iron fallback); the 1.32.3 OFFER-timeout was the now-fixed (1.32.7) unicast-RX drop, not a DHCP-layer bug. Also fixed all four MAC-octet prints (decimal → 2-digit hex via the new fb-visible `kprint_byte`; gateway MAC now reads `d4:6a:…` not `212:106:…`). QEMU/SLIRP DHCP exercised + `test.sh` 4/4 + `ext2-smoke` 5/5 green. **🎯 IRON DHCP VERIFIED 2026-05-25 ~17:50 PDT** (`1329-agnos-1.32.9-dhcp-re-enabled-…-lease-142-gw-mac-hex-l2-ok-shell.jpg`, phone-label `1329_DHCP`): every rubric row PASSED — `dhcp: DISCOVER → OFFER ip=192.168.1.142 → REQUEST → ACK ip=192.168.1.142 gw=192.168.1.1 mask=255.255.255.0` → `arp: REPLY gw_mac=d4:6a:91:ce:70:60` (HEX, logging fix confirmed) → `net: L2 OK` → `AGNOS shell v1.32.9`. Leased `.142` = a **real lease**, not the `.222` fallback, so the server's unicast OFFER+ACK both reached AGNOS; the 1.32.3 `OFFER timeout` WAS the now-fixed ring-depth unicast drop, not a DHCP-layer bug. **The 1.32.x networking arc is COMPLETE: L2 (1.32.6) → unicast TCP (1.32.7) → DHCP lease (1.32.9).** **(C) i225-V stays queued** for Intel iron post-migration — separate hardware line, not an AMD closeout blocker. Per-cycle trackers + per-attempt narrative live in the log: [`iron-nuc-zen-log.md#tracker-1329-cycle`](iron-nuc-zen-log.md#tracker-1329-cycle) (1.32.9 DHCP re-enablement — iron-verified PASS).
>
> MVP gate (boot-to-shell on iron) green since Attempt 68 / 1.30.9.
>
> **Crate registries**: [`planning/shared-crates.md`](planning/shared-crates.md) (full, incl. pre-1.0); [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ subset).

### Next storage targets after NVMe + AHCI iron debuts

Cycle theme stays **storage** through 1.31.x. archaemenid has **two** physical block surfaces — the M.2 NVMe Crucial P3 2 TB (iron-validated as `nvme0` at Attempt 80) AND a 2.5" SATA WD Blue SA510 2 TB (iron-validated at Attempt 81 — actual capacity is 2 TB, not 1.8 TB as the hardware-catalog earlier recorded). With NVMe Phase 1-5 + AHCI/SATA Phase 1-4 + GPT Phase 1-3 + both iron debuts closed under 1.31.x, the next moves down the device list — ranked by archaemenid iron-validatability + LOC cost:

| # | Target | Iron-validatable on archaemenid? | LOC estimate | Notes |
|---|--------|-----------------------------------|--------------|-------|
| ~~1~~ | ~~**GPT parser**~~ | ✅ DONE 1.31.1 (Phase 1-3 landed; NVMe iron-validated arr-CRC-OK at Attempt 81) | ~870 | `kernel/core/gpt.cyr` shipped; table-less CRC32 + backup-header recovery + 7-GUID type classifier + `parts` shell cmd. |
| ~~2~~ | ~~**AHCI/SATA driver**~~ | ✅ DONE 1.31.1 (Phase 1-4 landed; WD Blue SA510 iron-validated at Attempt 81 — PASS-WITH-CAVEAT) | ~1,100 | `kernel/core/ahci.cyr` shipped; three carry-forward patches landed in 1.31.2 `[Unreleased]` (see § AHCI iron carry-forward). |
| ~~3a~~ | ~~**USB Mass Storage (BBB + SCSI)**~~ | ✅ Phase 1-4 + 2.5 + 2.6 + 2.7 in agnos 1.31.2 (cut as-is); **Phase 2.8 eight-bug repair stack in agnos 1.31.3 (CUT 2026-05-21)**; iron Attempts 83/84/85/86 PARTIAL/FALSIFIED; **Attempt 87 PASS** (full INQUIRY/TUR/RC10 chain on real Silicon Motion silicon — `vendor='General' product='USB Flash Disk' rev='1100'`, last_lba=252051455 blk=512B → 123072 MiB) | ~990 | Phase 1: class-interface discovery + bulk-EP enumeration + GET_MAX_LUN. Phase 2: `xhci_input_ctx_add_bulk_pair` + Configure Endpoint + Normal-TRB bulk transfer + full CBW/CSW BBB transport + TEST UNIT READY. Phase 3: INQUIRY (vendor/product/rev/PDT decode with ASCII right-trim) + READ CAPACITY(10) (last_lba + lba_bytes). Phase 4: READ(10) / WRITE(10) + `msc_blk_read / msc_blk_write / msc_blk_read_sectors` block-layer wrappers + `blk_register_usb_ms` + tertiary registration policy (NVMe primary > AHCI secondary > USB MS tertiary > VIRTIO fallback) + dispatch arms for BLK_USB_MS=4 + `msc_read_demo` (unconditional LBA 0 readback) + `msc_write_demo` (gated `MSC_RW_DEMO=1`, LBA-100 sentinel write+readback). QEMU validation **all four phases first-try clean** against `-device qemu-xhci -device usb-storage,bus=xhci.0`: TUR → Pass, INQUIRY → `QEMU/QEMU HARDDISK/2.5+/block`, READ CAPACITY → 16384 LBAs × 512B = 8 MiB, READ(10) LBA0 = zeros (blank), WRITE(10) → LBA100 round-trip PASS. Build trajectory `474,600 → 478,440 → 484,992 → 488,984 → 493,688 B` (+19,088 total, +4.0%). Pre-burn audit: [`usb-ms-iron-burn-audit.md`](usb-ms-iron-burn-audit.md). **Iron debut PARTIAL at Attempt 83 (2026-05-21)**: real-vendor USB 2.0 stick (VID=`0x0936` PID=`0x13E8`) at xhci port 3 enumerated through MSC Phase 1 + Configure Endpoint; TUR returned NOT_READY / CSW status != 0 (spec-anticipated cold-insertion behavior — audit § 3 hyp 2 matched); existing TUR-pass gate at `msc.cyr:317-381` stopped Phase 3 INQUIRY / RC10 / tertiary registration from running. Carry-forward triage in § USB MS iron carry-forward below — Phase 2.5 TUR-hardening + Phase 3 hoist out of TUR gate. |
| 3b | **Optical via USB MS (SCSI MMC profile)** — *bundles with 3a* | Yes (HP external USB Blu-ray drive on archaemenid) | ~200 additional | 1.31.2 cycle scope. Promoted from previously-punted "1.32.x+ ATAPI/AHCI" slot. SCSI INQUIRY peripheral-device-type=0x05 + 2048-B sector handling through `blk_lba_bytes` parameter (currently always 512) + a couple MMC opcodes (TEST UNIT READY, READ CAPACITY(10)). **First non-512-B-sector device on AGNOS** — forces GPT/fatfs consumers to honor `lba_bytes` instead of hardcoding `* 512`. Iron canary: Pitch Black BD-25 disc. |
| 4 | **RAM-disk backend** | No (RAM-only — no iron variable) | ~150 | **1.31.4 cycle scope** (was 1.31.3 — USB-MS Phase 2.8 consumed that slot at Attempt 87 PASS). Pure-RAM `/dev/ram0`-equivalent over `pmm_alloc` + tag-dispatch. Useful for tests + initrd-style workflows. |
| 5 | **VirtIO-blk modern (1.x)** | QEMU only (VirtIO doesn't exist on bare metal) | ~600 delta | **1.31.4 cycle scope** (was 1.31.3 — displaced one slot with RAM-disk). Upgrade existing transitional 0.9.5 `virtio_blk.cyr` to MMIO + feature negotiation. Keeps QEMU first-class on modern machine types. |
| 6 | **ext2 read-only** | Yes (filesystem layer; consumes GPT + block) | ~1000+ | **1.31.5 cycle scope** (displaced twice — was 1.31.3, then 1.31.4, now 1.31.5; the USB-MS Phase 2.8 closeout consumed the 1.31.3 slot and RAM-disk + VirtIO took the 1.31.4 slot). Filesystem class, not device. FAT16 read-only is the floor; ext2 buys real Linux disk semantics (inodes, indirect blocks). |

**Order through 1.31.x**: ~~GPT~~ ✅ → ~~AHCI/SATA~~ ✅ → ~~**USB MS + Optical via USB MS**~~ ✅ (USB MS closed at agnos 1.31.3 / Attempt 87 PASS; USB optical pending) → ~~**RAM-disk + VirtIO-blk modern**~~ ✅ (1.31.4 / Attempt 88 PASS as no-regression) → ~~**ext2 read-only**~~ ✅ (1.31.5 Phase 1-4 / Attempt 89 PASS as no-regression; ext2-mount-on-iron gated on 1.31.6 bite G) → ~~**cleanup cycle**~~ ✅ **(1.31.6 CLOSED 2026-05-22 / Attempt 90 PASS — multi-backend probe + partition-aware mount + ext4 extent walker IRON-VALIDATED on NVMe `agnos-fs` p3)** → ~~**filesystem follow-ups + shell UX**~~ ✅ **(1.31.7 CLOSED 2026-05-22 / Attempt 91 PASS — ext4 64BIT Phase 5 BGDT-stride code + `cd`/`pwd`/CWD scoping + bare-name `cat` + `ls -la` flag dispatch IRON-VALIDATED on re-carved 64BIT-enabled `agnos-fs` p3).** **STORAGE + FS CYCLE CLOSED.**

**Iron-validation coverage at each cut**: 1.31.0 → NVMe iron debut (Crucial P3 / Attempt 80). 1.31.1 → NVMe + SATA iron debut (WD Blue SA510 / Attempt 81 PASS-WITH-CAVEAT). 1.31.2 → AHCI carry-forward triplet iron-PASS (Attempt 82) + USB MS iron progression (Attempts 83/84 PARTIAL → 85/86 FALSIFIED). **1.31.3 → USB MS iron debut PASS (Phase 2.8 eight-bug stack / Attempt 87 full INQUIRY+TUR+RC10 on Silicon Motion silicon).** 1.31.4 → RAM-disk + VirtIO (QEMU only) + iron no-regression burn (Attempt 88). **1.31.5 → ext2/4 Phase 1-4 (QEMU 5/5 green) + iron no-regression burn (Attempt 89; new NVMe `agnos-fs` carve enumerated through GPT Phase 3; ext2 mount silently misses as predicted, gated on 1.31.6 bite G).** **1.31.6 → ext4 victory lap iron-PASS (Attempt 90: `ext2: probe matched backend=2 partition_lba=3898638336` + `ext2: mounted (blocksize=4096, inode_size=256, inodes_per_group=8192)` + `agnos> ls /` returned `./ ../ lost+found/ hello.txt` byte-exact from real Linux ext4 dirent table on iron NAND; closes 1.31.x storage arc).** **1.31.7 → ext4 64BIT + shell-UX victory lap iron-PASS (Attempt 91: re-carved `agnos-fs` p3 with default `mkfs.ext4` 64BIT-enabled mounted cleanly through Phase 5 BGDT-stride code; `agnos> cd lost+found` traversed; `agnos> cat hello.txt` returned `agnos 1.31.7 iron Attempt 91   ext4 64BIT validated   2026-05-22` byte-exact; storage trio byte-matched Attempt 90).**

#### AHCI iron carry-forward — ✅ all three landed in 1.31.2 `[Unreleased]` 2026-05-20

| Item | Resolution | Mechanism |
|---|---|---|
| Post-RW IDENTIFY timeout in `ahci_register_block_dev` (`PxCI stuck`) | ✅ Fixed — root cause was missing pre-issue quiescence gate (not PxIS as initially hypothesized; both issuers already W1C-cleared PxIS before issuing) | New `ahci_port_wait_idle(port)` helper polls PxTFD.STS.BSY=0 + DRQ=0, PxCI=0, PxSACT=0 before issuing. Called at the top of both `ahci_identify_device` and `ahci_issue_rw`. Matches Linux's `ata_qc_issue` / `ahci_qc_issue` pattern (drivers/ata/libahci.c). |
| ATA-string trailing-space drag | ✅ Fixed | `ahci_print_id_string` rewritten to scan printed-char sequence back from the end to the last non-0x20 byte; honors the byte-swap (printed-char-index `k` maps to field-byte `k XOR 1`). Matches Linux's `ata_id_c_string`. |
| `AHCI_RW_DEMO` compile gate | ✅ Fixed | `ahci_rw_demo` split into always-on `ahci_read_demo` (LBA 0 readback, no writes) + `#ifdef AHCI_RW_DEMO`-gated `ahci_write_demo` (LBA-5 sentinel write + read-back). Plumbing in `scripts/build.sh` (`AHCI_RW_DEMO=1 ./scripts/build.sh`) + documented in `docs/development/build.md` alongside `KTEST` / `XHCI_VERBOSE`. |

**Validated on iron at Attempt 82 2026-05-20** — first iron burn of agnos 1.31.2 (built `474,600 B` on cycc 6.0.1, agnos's first burn on the v6.0.x toolchain post-pin-graduation) cleared all three patches in a single shot. Post-RW IDENTIFY no longer hangs (`ahci: registered as secondary block_dev (port 0, 3907029168 LBAs x 512B; NVMe primary)` follows the second IDENTIFY's model/serial/fw + LBA48 print); ATA-string trailing-space drag absent on iron (model prints flush against closing quote); `AHCI_RW_DEMO`-gated `ahci_write_demo` compiled out (LBA-5 sentinel write absent from boot output). The `ahci-iron-burn-audit.md` § 7 full-success rubric is now cleared — no new diagnostic letters, no new hypotheses, no carry-forward residue. Detail in [`iron-nuc-zen-log.md` § Attempt 82](iron-nuc-zen-log.md).

#### USB MS iron carry-forward — Phases 2.5 ✅ / 2.6 FALSIFIED@85 / 2.7 LANDED@86 (Reset Recovery worked, post-recovery TUR still failed) / **Phase 2.8 eight-bug repair stack in agnos 1.31.3 → ✅ Attempt 87 PASS 2026-05-21 (1.31.3 cut)**

Third storage-class iron debut (after NVMe at Attempt 80 + SATA at Attempt 81). Three iron burns 2026-05-21 (84/85/86) against a Silicon Motion / SMI commodity stick (`VID=0x090C PID=0x1000`, USB 2.0 / HS). Each burn advanced the failure deeper into the stack — no letter laddering per [`feedback_stop_letter_laddering`](../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_stop_letter_laddering.md).

**Attempt 84 (Phase 2.5)**: Device-side Reset Recovery (`msc_reset_recovery` per BBB §6.7.3) + 3-retry TUR loop + INQUIRY hoist + REQUEST SENSE all fired as designed on iron. Per-step diagnostics (`data phase timeout` / `CSW transfer timeout` / `CBW transfer timeout`) replaced Attempt 83's misleading "(CSW status != 0)". But the device transport stayed wedged across all three Reset Recovery cycles, and a CSW tag mismatch immediately before the first recovery proved the device's bulk-IN buffer was not drained. → Phase 2.6 controller-side commands justified.

**Attempt 85 (Phase 2.6) → FALSIFIED**: Three new xHCI commands shipped (`xhci_cmd_reset_endpoint` TRB 14 + `xhci_cmd_stop_endpoint` TRB 15 + `xhci_cmd_set_tr_dequeue` TRB 16) + event-ring drain (`xhci_drain_transfer_events`) + rewritten `msc_reset_recovery`. On iron: `msc: Reset Endpoint(bulk-IN) failed` × 2 aborted recovery before Set TR Dequeue Pointer could fire. **Root cause**: Reset Endpoint is only legal from Halted state per xHCI 1.2 §4.6.8, but the transfer-event-timeout wedge left the EP in Running, then Stop Endpoint moved it to Stopped — Reset Endpoint on Stopped returns Context State Error (CC=19), which `xhci_cmd_reset_endpoint` was treating as a failure → recovery aborted.

**Phase 2.7 (post-Attempt-85 carry-forward, agnos 1.31.2 `[Unreleased]`, Attempt 86 burn pending)**: per [`feedback_redesign_dont_reinvent`](../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_redesign_dont_reinvent.md) refreshed 2026-05-21 with hard "multi-source" rule (after user feedback "LINUX ISN'T THE ONLY RESOURCE OF PRIOR ART"), four-source convergent audit landed in [`msc-reset-recovery-prior-art.md` § 9](msc-reset-recovery-prior-art.md): FreeBSD `umass.c` + `xhci.c` + OpenBSD `umass.c` + EDK2 `UsbMassBot.c` + Linux confirmatory. Convergent findings: (1) device-side reset runs FIRST, before any host-controller resync; (2) Reset Endpoint must be gated on EP State == Halted (FreeBSD reads state explicitly via `xhci_get_endpoint_state`); (3) **100ms post-BOT-Reset device stall** is required (EDK2 explicit `gBS->Stall(USB_BOT_RESET_DEVICE_STALL)`; FreeBSD implicit 50ms `.interval`; Linux `msleep(100)`) — AGNOS Phase 2.5/2.6 had ZERO delay, the most likely contributor to Attempt 84's "Reset Recovery OK but transport stays wedged".

| Phase | Item | Status | Mechanism |
|---|---|---|---|
| 2.5 | Bulk-IN transport wedged: Step 4 CSW receive timeout | ✅ Iron-validated Attempt 84 (executes cleanly; insufficient alone) | `msc_reset_recovery` per BBB §6.7.3 + host-side ring rewind. |
| 2.5 | TUR retry loop | ✅ Iron-validated | 3-retry loop, `msc_reset_recovery` between failed attempts. |
| 2.5 | INQUIRY hoist out of TUR-pass gate | ✅ Iron-validated | `msc_inquiry` runs unconditionally after Configure Endpoint per SPC-4 §6.6. RC10 stays inside TUR-pass branch per SBC-3 §5.10. |
| 2.5 | REQUEST SENSE decoder | ✅ Landed; transport never recovered enough on iron for SENSE to issue | `msc_request_sense` helper. |
| 2.6 | Controller-side EP recovery (TRB 14/15/16) | ✅ Landed agnos 1.31.2; FALSIFIED Attempt 85 (Reset Endpoint dispatch wrong; corrected in 2.7) | Three new helpers in `xhci_cmd.cyr`. |
| 2.6 | Event-ring drain of stale Transfer Events | ✅ Landed agnos 1.31.2 | `xhci_drain_transfer_events(slot_id)`. |
| **2.7** | **Reset Endpoint CSE tolerance** | ✅ Landed agnos 1.31.2 `[Unreleased]`; pending Attempt 86 | `xhci_cmd_reset_endpoint` returns 1 on `XHCI_CC_CONTEXT_STATE_ERROR`. Defensive backstop. |
| **2.7** | **EP-state-aware Reset Endpoint dispatch** | ✅ Landed agnos 1.31.2 `[Unreleased]`; pending Attempt 86 | New `xhci_ep_state(slot_id, dci)` reads Output EP Context dword 0 bits 0-2 per xHCI 1.2 §6.2.3 (`XhciEpState` enum). `msc.cyr` step 7 gates Reset Endpoint on `XHCI_EP_STATE_HALTED`. Mirrors FreeBSD `xhci_configure_reset_endpoint`. |
| **2.7** | **100ms post-BOT-Reset device stall** | ✅ Landed agnos 1.31.2 `[Unreleased]`; pending Attempt 86 | 50M-iter busy-wait after `xhci_control_no_data(0x21/0xFF)`. Matches EDK2 explicit + FreeBSD implicit. **Highest-confidence fix in the 2.7 stack** for Attempt 84's wedge pattern. |
| **2.7** | **Reset Recovery step reorder: device-side first** | ✅ Iron-validated Attempt 86 (Reset Recovery executed correctly: `Reset Recovery OK` × 3 in transcript, no `Reset Endpoint failed`); orthogonal bug stack surfaced | Full `msc_reset_recovery` rewrite. New order: BOT Reset → 100ms stall → CLEAR_FEATURE×2 → drain events → Stop Endpoint×2 → Reset Endpoint×2 (Halted-gated) → ring rewind → Set TR Dequeue×2. Matches convergent reference ordering. |
| **2.8** | **Bulk timeout extension** | ✅ Landed agnos 1.31.3 | New `XHCI_BULK_TIMEOUT_SPINS = 200_000_000` (~1s wall) enum, bulk-specific. **Root cause of Attempt 86**: cmd-ring 10M (~25-50ms) was abandoning the INQUIRY data phase mid-flight against real Silicon Motion silicon. Linux `USB_CTRL_GET_TIMEOUT=5000ms`; FreeBSD comparable. |
| **2.8** | **Strict TRB-pointer matching** | ✅ Landed agnos 1.31.3 | New `xhci_wait_transfer_for_trb(slot_id, expected_trb_phys, expected_len)` + `xhci_last_xfer_bytes` global. Skips stale completion events for prior wedged TRBs (Attempt 86's "CSW tag mismatch" on TUR #0 was a late INQUIRY CSW attributed to TUR). Mirrors Linux `handle_tx_event`. |
| **2.8** | **SHORT_PACKET residue check** | ✅ Landed agnos 1.31.3 | `xhci_wait_transfer_for_trb` reads event dw2 bits 23:0 (residue). If residue ≥ expected_length → 0 bytes transferred → failure. **Direct cause of Attempt 86's repeating "CSW signature mismatch"**: device's ZLP-then-real-CSW pattern after Reset Recovery left csw_phys[0..3]=0. |
| **2.8** | **`msc_scsi_exec` unified retry+recover wrapper** | ✅ Landed agnos 1.31.3 | New wrapper around `msc_bbb_exec`; runs Reset Recovery between failed attempts AND at entry if transport_failed sticky already set. INQUIRY/TUR/RC10/RS/READ/WRITE all migrated. Subsumes the hand-rolled TUR retry loop in `msc_probe_slot`. Linux `usb_stor_invoke_transport` pattern. |
| **2.8** | **Drain reposition: AFTER Stop Endpoint** | ✅ Landed agnos 1.31.3 | `msc_reset_recovery` step 7 (was step 5). Stop Endpoint × 2 posts Transfer Events for pinned in-flight TRBs (xHCI 1.2 §4.6.9.1); pre-Stop drain (Phase 2.7) missed them. Linux drains in `handle_stopped_endpoint`. |
| **2.8** | **`xhci_cmd_set_tr_dequeue` full 64-bit phys** | ✅ Landed agnos 1.31.3 | `param_hi = (deq_ptr_phys >> 32) & 0xFFFFFFFF` (was hardcoded 0). Defensive — archaemenid PMM stays <4GB but malformed for future high-memory placement. |

**Attempt 87 outcome (2026-05-21) — ✅ FULL PASS against rubric (a)**: `xhci: bulk transfer event timeout` absent from the MSC chain; INQUIRY succeeds first try (`vendor='General' product='USB Flash Disk' rev='1100' type=block`); TUR Pass first try; RC10 prints `last_lba=252051455 blk=512B -> 123072 MiB` (252,051,456 LBAs × 512 B ≈ 120 GiB Silicon Motion stick); `1 mass-storage device(s) detected`. NVMe + AHCI bring-up continues clean below. Transcript photo: [`iron-nuc-zen-photos/attempt-87-usb-ms-phase-2-8-inquiry-tur-rc10-success.jpg`](iron-nuc-zen-photos/attempt-87-usb-ms-phase-2-8-inquiry-tur-rc10-success.jpg).

**MVP gate posture**: unaffected — `msc_probe_slot` already returns 1 even on transport failure, so MVP boot-to-shell stays green regardless of MSC outcome. USB MS arc was opportunistic; closed beta depends on kybernet + agnoshi + kernel-on-iron, not on a specific block backend.

**Storage + FS arc status — CLOSED 2026-05-22; 1.32.0 networking arc CLOSED 2026-05-22 (feature-complete); 1.32.1 networking-arc-continued cycle OPEN 2026-05-22:** ~~1.31.3~~ ✅ (USB MS Phase 2.8 / Attempt 87 PASS) → ~~1.31.4~~ ✅ (RAM-disk + VirtIO modern / Attempt 88 PASS no-regression) → ~~1.31.5~~ ✅ (ext2/4 Phase 1-4 / QEMU 5/5 green + Attempt 89 PASS no-regression) → ~~1.31.6~~ ✅ (cleanup + multi-backend probe + partition-aware mount / Attempt 90 PASS — ext4 mounted from NVMe `agnos-fs` p3 on iron) → ~~1.31.7~~ ✅ (ext4 64BIT Phase 5 + shell UX `cd`/`pwd`/bare-name `cat`/`ls -la` / Attempt 91 PASS — Phase 5 BGDT stride iron-validated on user's re-carved 64BIT-enabled NVMe `agnos-fs` p3) → ~~**1.32.0**~~ ✅ **CLOSED 2026-05-22** (networking arc feature-complete: TCP server primitives bite A + UDP server primitives bite F + DHCP client RFC 2131 bite G + r8169 driver Phases 1-4 bite B + DHCP gate fix `main.cyr:655` + Iron Attempts 92 + 93; **Attempt 93 PARTIAL VERIFIED gate fix on iron**) → **1.32.1 OPEN (networking-arc-continued; lean cycle-open per discipline — VERSION bump 1.32.0 → 1.32.1 + CHANGELOG `[1.32.1]` header + tracking surface; bites A-E PENDING IRON; theme: r8169 driver-level OFFER-timeout debug — H1/H7/H8 audit hypotheses now reachable)**.

**Out of cycle scope (parked):**
- AMD Zen scanout residue (Quiet Boot legibility) — separate cycle per [`project_amd_zen_scanout_residue`](../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_amd_zen_scanout_residue.md); HUBP `clear_tiling` port or shadow-buffer eval.
- SMP-AP wakeup on real hardware — carry-forward from earlier roadmap.
- Real-iron NIC (e1000e / I225-V / RTL8125) — different device class, separate arc when networking becomes the cycle theme.

This doc holds **volatile state** — what's currently true across the AGNOS dev surface. CLAUDE.md is preferences/process/procedures; this is the live picture. Per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md): rewrite in place when state changes; don't preserve historical snapshots — git history is authoritative.

**Drift caveat**: always verify against actual `VERSION` + `cyrius.cyml` files before acting on any single item in this doc.

---

## Cyrius cycle — v6.0.0 (open 2026-05-19)

**v6.x = "what the language GAINS."** v5.x was "what the language IS"; the v5.x→v6.x boundary marks the pivot from stabilization to expansion (RISC-V rv64, PIE, closures, Class-B FFI, bare-metal — slip path: v5.8.x → v5.10.x → v5.11.x → **v6.x**, per the boundary memory). First slot cut today, 2026-05-19.

### v6.0.0 cycle-open — two-binary rename ceremony

- `cyrc` → **`cybs`** (Cyrius Bootstrap) — the seed/bootstrap compiler in the chain
- `cc5`  → **`cycc`** (Cyrius Computer Compiler) — the self-hosted production compiler

Bootstrap chain is now `seed (asm) → cybs → cycc`. The "Version lives in `VERSION` + `--version`, never in binary names" Key Principle stays — but the names are *forever*. No `cycc6` at v7.0.0, no `cybs7` at v8.0.0; the cc3 → cc5 (v5.0.0) → cycc (v6.0.0) and cyrc → cybs (v6.0.0) sequence was the LAST name-change penalty paid.

**Rename surface**: ~2,100 occurrences across ~157 files. Categorized sed preserved historical anchor text (v5.x CHANGELOG entries, completed-phases.md, archives, audit date-stamps, vidya retros — those names were what the binaries were called at the time). Current-state code + canonical-current docs renamed. File renames via `git mv` (`bootstrap/cyrc.cyr` → `bootstrap/cybs.cyr`, `build/cc5*` → `build/cycc*`, scripts renamed in parallel).

**Back-compat (v6.0.x window)**: `scripts/install.sh` ships symlinks `cc5 → cycc`, `cyrc → cybs`, `cc5_aarch64 → cycc_aarch64`, `cc5_win → cycc_win` in `~/.cyrius/versions/<v>/bin/`. `cbt/core.cyr` compiler-lookup tries new name first then falls back to old. Both drop at **v6.1.0**.

**Mechanical gates at v6.0.0 cut**: cycc self-host byte-identical at **874,240 B** (+8 B vs cc5 at v5.11.69's 874,232 B, from the longer "cycc" binary-name strings). `check.sh` **76/76**. `cyrius test` **152/152**. 3-step bootstrap (old cc5 v5.11.69 → cycc_a → cycc_b byte-identical). Cross-arch: cycc_aarch64 564,456 B, cycc_win 686,632 B.

### v6.0.x carry-forward (from v5.x closeout)

Five accompanying-refactor items pulled forward — surface on next cyrius-side touch. Detail in `cyrius/docs/development/roadmap.md`. Beyond this: RISC-V rv64 backend, PIE, closures, Class-B FFI, bare-metal Cyrius — all v6.x slots, no firm sequencing yet.

### v5.11.x retrospective (closed 2026-05-19 at 5.11.69)

**70 patches across 11 days** (2026-05-09 → 2026-05-19) — the longest minor in Cyrius history. Three same-day bursts of 24/18/17 on 2026-05-11/12/13 carried the bulk; the .56–.69 tail spread across one patch/day cadence with the heavy engineering at .68 (heap-map reorg) and closeout housekeeping at .69.

- **Stdlib annotation arc** — 1,010 unannotated public fns annotated across the 7-phase breakout (foundational / I/O / strings / collections / big consumers / closeout / compiler internals); Phase 1 landed at v5.11.1, all phases closed in the .1–.55 burst.
- **Consumer-issue closeout** — kavach P1 sandbox wrappers (v5.11.0), daimon/bote P2 wave, low-priority cleanups.
- **ELF section-header fix arc** (.29/.30/.31) — GRUB `grub_elf32_get_shnum` rejection traced to `e_shoff=0` from x86 kernel / aarch64 kernel / cyrld emitters; mirrored 5-section table across all three.
- **gvar-init-order zero-reads fix** (v5.11.64) — module-top `var X = INT_LITERAL` read as 0 before init block ran (kmode==1 init-order: top-level asm → PARSE_PROG → EMIT_GVAR_INITS, with kernel's main body in PARSE_PROG never returning). Root cause of the 10-letter Phase-3 cmd-path silent-absorb arc on iron (FF→QQ+QQ2, falsified across Attempts 57-63 chasing what looked like silicon). Fixed via Option 1 — image-static init for literal-RHS gvars at file scope, every backend covered. Issue: [`2026-05-18-gvar-init-order-zero-reads.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-18-gvar-init-order-zero-reads.md).
- **Path A→Path C transition** (.43–.55) — diagnostic + sovereign UEFI-application emit support for the gnoboot lane after GRUB MB2-EFI W^X blocker (per `project_grub_mb2_efi_wx_blocker` memory).
- **Heap-map full reorganization** (v5.11.68) — the true v5.x closeout engineering work; ~9.06 MB reclaimed, 84 → 99 regions, brk-final 0x4E8C000 → 0x4D9D000. v5.11.69 was doc/scripts/vidya closeout sweep (the originally-conditional fold-applied slot — mabda 3.0 fold was dropped per user direction post-.67, so .69 absorbed pre-6.0 cleanup instead).

**v6.0.0 enabling consumers** (cut during v5.11.x):
- **argonaut 1.7.0 + kybernet 1.2.1** (2026-05-11 eve) — BOOT_MINIMAL agnoshi-as-console; unblocked the closed-beta MVP path without aethersafha.
- **kriya 1.0.0** (2026-05-18) — coreutils-equivalent dispatcher graduated to v1.0+.
- **commandress 1.0.0** (2026-05-18) — segment renderer + config layer stabilized; adapter-based for agnoshi/bash/zsh prompt-hook.

V1.0+ binaries cohort now **13**: agnos, agnoshi, argonaut, bannermanor, commandress, cyim, cyim-lsp, iam, kriya, kybernet, mihi, nous, owl. (iam + mihi added 2026-05-20 morning as the first v6.0.x graduations; bannermanor 0.5.0 → **1.0.0** later same day with CLI surface + CYML font format + default font set frozen as the v1.0 contract.)

### v5.10.x retrospective (closed 2026-05-11 at 5.10.50)

**50 patches in 5 days** (2026-05-06 → 2026-05-11). THREE completed arcs plus a compile-perf miniarc:

- **Typed-simd ABI arc — 11 phases** (closeout v5.10.39). `lib/simd.cyr` rewrite: every math op exists in value-form + pointer-form siblings with parser-side `&IDENT → _ptr` overload routing; f64v2 args in XMM0/XMM1 (SysV) / V0/V1 (aarch64), f64v4 in register pairs; PE-gated via `CYRIUS_HAS_VAL_SIMD_PARAMS`. **This is the substrate for Cyrius-native codec work long-term** — typed SIMD primitives + cross-platform ABI-aware register routing is the floor of any handwritten-SIMD codec port (tarang's current dav1d/openh264/libvpx C-FFI layer is the placeholder until that future arc opens).
- **REAL TYPE SYSTEM arc — 5 phases** (Phase 2 v5.10.24, Phase 3 v5.10.25 overload generalize). Per-fn param-type bitmasks, call-site type checking, cstring / Result / Option / Tagged vocabulary on stdlib.
- **Struct-byval ABI arc — 3 phases** (.45 + .46 + .47). Cross-backend struct-byval return surface.
- **Compile-time-perf miniarc** (.40 + .41) — **2.7× total compile speedup**.

Plus one TLS contract pin (.42), one PE premise debunk (.49 — 15-slot phantom pin closed by empirical re-test), 4 open issues closed (str_split, exec_*, parser cosmetics, kernel-reserved-word), and 9+ in-cycle pin re-scopings driven by premise-check discipline.

api-surface 2,769 → 2,876 (+107 public fns). cc5 (x86) 741,048 B → **804,472 B**. check.sh 66 gates stable. cyrius test count 132 → ~146.

### cycc cut state

cycc self-host **874,240 B** at v6.0.0 (was cc5 874,232 B at v5.11.69 close; +8 B for the longer "cycc" binary-name string in `version_str.cyr`). Self-host fixpoint clean. cc5 grew from **804,472 B at v5.11.0** baseline to **874,232 B at v5.11.69** across the 70-patch cycle (+69,760 B over 9 days). check.sh 66 → 76 gates; cyrius test 132 → 152 across the 5.10.x + 5.11.x cycles.

### Genuinely dangling — carry-forward into v6.x triage

| # | Item | Domain | Notes |
|---|------|--------|-------|
| 1 | `cyrlint` multi-line assert | Tooling | Investigated v5.8.41; couldn't reproduce on 4 synthetic tests. Decide: close as moot, or pin a real reproduction case |
| 2 | `ESTORESTACKPARM` stub | Language | Explicitly **held** — needs unhold-or-resolve decision |
| 3 | Optimization arc O3–O6 audit | Compiler | Partial follow-on shipped (O3a IR / O4a–c regalloc / O5 / O6 codebuf) — needs status sweep against v5.6.x deferral list |
| 4 | Consumer rollup — pre-CYML format tail | Ecosystem | `hoosh` and `shravan` only (down from 11 at v5.10) — format migration + pin bump |
| 5 | Consumer rollup — deep-lag tail | Ecosystem | ark (5.1.10), yantra (5.6.17); hisab/agnova/abaco/nous/bazaar/shakti in v5.7.x; libro/majra exited at v5.10.44 |
| 6 | Consumer rollup — v5.7.48 held cluster (3 repos remaining) | Ecosystem | mabda, cyrius-doom, samvada — phylax + agnosys both exited during v5.10.x/v5.11.x |
| 7 | RISC-V rv64 backend | Compiler/backend | Slipped 7+ times; first-class v6.x candidate. Substrate prereqs (typed-simd ABI / REAL TYPE SYSTEM / struct-byval) all landed v5.10.x |
| 8 | Bare-metal Cyrius target | Compiler/runtime | v6.x slot; substrate prereqs landed v5.10.x + v5.11.x stdlib annotation |
| 9 | PIE / closures / Class-B FFI | Language | Three v6.x feature slots per the v5.x→v6.x boundary; no firm sequencing |

---

## Pin-lag spectrum

Each repo's `cyrius = "X.Y.Z"` pin (verified 2026-05-11 eve from local clones, with leading-edge spot updates). **Most pre-CYML consumers migrated**: agnoshi, bote, t-ron, kavach, itihas, nein all moved from `cyrius.toml` v3.x/v4.x to `cyrius.cyml` 5.10.44+. Only `hoosh` and `shravan` remain on pre-CYML format in the local-verified set. **The v5.11.x leading-edge bedrock is now where consumers will pause** — back-compat symlinks (`cc5 → cycc`, `cyrc → cybs`) keep them building unchanged through the v6.0.x window; natural-next-touch will graduate each consumer to v6.0.x and re-pin then.

```
PRE-CYML format / no pin field (remaining tail):
  hoosh (cyrius.toml, no pin field visible in snapshot)
  shravan (cyrius.toml, no pin field visible in snapshot)

CYML format — DEEP LAG (didn't roll forward; may carry latent stdlib breakage):
  v5.1.x:  ark (5.1.10)                              ← extreme lag, port pre-dates pin convention
  v5.6.x:  yantra (5.6.17)
  v5.7.x:  hisab (5.7.10), agnova (5.7.12),
           abaco (5.7.23), nous (5.7.29),
           bazaar (5.7.30), shakti (5.7.33)
  v5.7.48: mabda (3.0.0-rc.2), cyrius-doom (0.26.2),
           samvada (0.2.2)                           ← held-cluster (was 4; phylax exited)

CYML format — WARM CLUSTERS:
  v5.9.x:  sit (5.9.37), vidya (5.9.43)
  v5.10.x: vyakarana (5.10.5), owl (5.10.10),
           cyim (5.10.10), cyim-lsp (5.10.10),
           cyim-lsp (5.10.20),
           aegis (5.10.34)
           — darshana graduated to v6.0.1 cluster 2026-05-20 (color primitives bump)

CYML format — LIVE 5.10.44 BEDROCK (~14 repos, the boot path minus agnos + agnoshi):
  v5.10.44: agnostik (1.2.2), argonaut (1.7.0),
            bote (2.7.2), daimon (1.2.3),
            kavach (3.2.1), kybernet (1.2.1),
            libro (2.6.3) — exited 5.4.x deep-lag,
            majra (2.4.4) — exited 5.4.x deep-lag,
            nein (1.5.1), phylax (1.1.1) — exited 5.7.48 held cluster,
            t-ron (2.1.4)
            — agnoshi graduated to v6.0.1 cluster 2026-05-20 (1.3.2 → 1.3.3)

CYML format — 5.11.x cluster (no leading-edge holdouts after agnos graduation):
  v5.11.59: agnosticos/scripts (genesis 0.1.0)
            — boot pipeline; pin sweep deferred to next boot-side touch
            — only 5.11.x leading-edge member remaining after agnos
              graduated to 6.0.1 mid-1.31.x cycle
  v5.11.4:  agnosys (1.2.6), sigil (3.1.1), sankoch (2.2.5),
            sandhi (1.3.4), niyama (1.0.2), patra (1.9.4),
            sakshi (2.2.4), vani (0.9.3), yukti (2.2.3)
  v5.11.8:  ai-hwaccel (2.2.2)

CYML format — LEADING-EDGE 6.0.x cluster (post-v5.11.x graduations):
  v6.0.1:  agnos (1.31.7), agnoshi (1.3.3), mihi (1.0.0), iam (1.0.0),
           chakshu (0.6.0), bannermanor (1.0.0), darshana (0.3.5),
           hapi (0.5.0)
           — eight repos on the v6.0.x lane. agnos graduated mid-1.31.x
             cycle for binary fixes in cycc 6.0.1 (was 5.11.64, the
             gvar-init-order anchor). The 2026-05-20 terminal-
             aesthetics burst brought six: mihi + iam cut as NEW 1.0.0
             repos straight on v6.0.1; chakshu jumped 0.3.0 → 0.6.0 +
             5.10.20 → 6.0.1; bannermanor (`bnrmr` figlet-equivalent) +
             hapi (stow-equivalent) cut at 0.5.0 straight on v6.0.1;
             darshana graduated from
             v5.10.20 → v6.0.1 with the 0.3.0 → 0.3.5 color-primitives
             bump that bannermanor's banner colors needed.

CYRIUS TOOLCHAIN itself: 6.0.1 (v6.0.0 cycle opened 2026-05-19, same-day .1 patch for UEFI fncall ud2 emit regression; v5.11.x closed at 5.11.69)

NOT VERIFIED LOCALLY (remote-only, presumed pre-CYML or scaffolded):
  avatara, hadara, itihas, takumi, aethersafha, aethersafta, mela,
  seema, samay, kiran, joshua, salai, murti, tanur, encom-hits,
  cyrius-{bb,brynns-tale,stellar-swarm,sunset-drive,super-plumber-twins,
  grapevine,chellys-beach-adventure,nba-jam}
```

**Bands of attention (2026-05-20 PM — post-MVP-gate, post-v6.0.0 cycle-open, agnos + agnoshi graduated mid-1.31.x storage cycle):**
- **6.0.1 leading-edge cluster** (2026-05-20 → -22, **9 repos**): **agnos (1.32.1)** + **agnoshi (1.3.3)** + mihi (1.0.0), iam (1.0.0), chakshu (0.6.0), bannermanor (1.0.0), darshana (0.3.5), hapi (0.5.0), **kii (0.1.0)** (added 2026-05-22 — Hawaiian Polynesian micro-cluster joins via image→ANSI/ASCII converter). The morning brought sys-info substrate (mihi/iam/chakshu) and afternoon brought terminal-aesthetics (bannermanor / hapi / darshana). The 2026-05-20 evening MVP-path graduation pair (agnos + agnoshi) onto cycc 6.0.1 was the load-bearing change; agnos has since rolled through the storage arc and ext2/4 cycle on the same pin: 1.31.2 → 1.31.3 (USB MS Phase 2.8) → 1.31.4 (RAM-disk + VirtIO modern) → 1.31.5 (ext2/4 Phase 1-4) → 1.31.6 (cleanup cycle close) → **1.31.7** (FS follow-ups + shell UX close). The darshana 0.3.0 → 0.3.5 bump was demand-driven (bannermanor needed color escape sequences) — same shared-lib-evolves-to-second-consumer pattern as mihi's cyim → chakshu extraction.
- **5.11.x cluster (no leading-edge holdouts)**: agnosticos/scripts (5.11.59 — boot pipeline; sweep deferred; genesis-repo VERSION flipped CalVer → SemVer at 0.1.0 cycle-open 2026-05-21). agnos vacated 5.11.64 mid-1.31.x cycle. Back-compat symlinks (`cc5 → cycc`, `cyrc → cybs`) keep this cluster building unchanged through the v6.0.x window.
- **5.11.x post-burst cluster** (~10 repos at .4/.8) — sandhi, niyama, patra, sakshi, vani, yukti, agnosys, sigil, sankoch, ai-hwaccel. Ahead of the bedrock but trailing the leading-edge.
- **5.10.44 live bedrock** (~14 repos: kybernet, argonaut, kavach, daimon, bote, t-ron, libro, etc.) — agnoshi exited 2026-05-20, narrowing the MVP-path holdouts to **kybernet + argonaut** (these still pin 5.10.44 and still boot AGNOS on iron). Rest of the bedrock graduates to v6.0.x on natural-next-touch.
- **Deep-lag tail** shrank but didn't vanish: ark (5.1.10) extreme, hisab/agnova/abaco/nous/bazaar/shakti in v5.7.x cluster, yantra (5.6.17). The 5.4.x cluster (libro, majra) FULLY EXITED at 5.10.44.
- **Held cluster at 5.7.48** now **3 repos** (mabda, cyrius-doom, samvada) — phylax exited during v5.10.x. mabda is at 3.0.0-rc.2 (soak before GA fold to Cyrius stdlib); cyrius-doom is at 0.26.2 (gated on Cyrius optimization-arc closeout retroactive verification).
- **Pre-CYML format tail**: only `hoosh` and `shravan` remain in the local-verified set. The previous 11-repo tail collapsed in the v5.10–v5.11 window.

### New repos / milestone bumps since last refresh

| Repo | Version | Pin | Notes |
|------|---------|-----|-------|
| **aegis** | **1.0.0** | 5.10.34 | **Hit v1.0** (was 0.8.2 in last refresh). Real system-security daemon now shipping. Skipped 0.9.x — straight implementation closeout to 1.0.0. |
| **agnos** | **1.32.1** | **6.0.1** | **1.31.x storage + FS arc CLOSED 2026-05-22 / 1.32.0 networking arc CLOSED 2026-05-22 / 1.32.1 networking-arc-continued cycle OPEN 2026-05-22.** Through-line: 1.31.2 → 1.31.3 (USB MS Phase 2.8 eight-bug repair stack / Attempt 87 iron PASS) → 1.31.4 (RAM-disk + VirtIO 1.x modern / Attempt 88 iron PASS no-regression) → 1.31.5 (ext2/4 Phase 1-4 / Attempt 89 iron PASS no-regression) → 1.31.6 cleanup cycle (8 bites + 2 smoke-surfaced fixes + Iron Attempt 90 ext4 victory lap PASS) → 1.31.7 filesystem follow-ups + shell UX CLOSED (ext4 64BIT Phase 5 + `cd`/`pwd`/CWD scoping + bare-name `cat` + `ls -la` flag dispatch + Iron Attempt 91 PASS) → **1.32.0 networking arc CLOSED 2026-05-22**: TCP server primitives + UDP server primitives + DHCP client RFC 2131 + r8169 driver Phases 1-4 + iron Attempts 92 + 93 on archaemenid + DHCP gate predicate fix at `main.cyr:655`. **Iron evidence**: Attempt 92 PARTIAL surfaced gate predicate bug → same-day fix `if (vnet_active != 0 || nic_ready() != 0)` → **Attempt 93 PARTIAL VERIFIED the fix on iron** (`dhcp: DISCOVER` egresses through r8169 path for the first time; new failure mode `dhcp: OFFER timeout`). → **1.32.1 OPEN 2026-05-22** networking-arc-continued cycle-open (lean: VERSION bump 1.32.0 → 1.32.1 via canonical `scripts/version-bump.sh` + CHANGELOG `[1.32.1]` header + tracking surface, no code touches yet). Cycle theme: **r8169 driver-level OFFER-timeout debug** (H1 PHY-not-configured / H7 TX OWN stuck / H8 RX OWN stuck — the now-reachable audit hypothesis surface from Attempt 93's pre-burn rubric). Opening move: §5b extension to [`r8169-iron-burn-audit.md`](r8169-iron-burn-audit.md) per [[feedback_iron_burns_block_other_work]] + [[feedback_redesign_dont_reinvent]]. Carry-forward still in flight: i225-V driver bite C (Intel iron pending, post-archaemenid-migration); BBS + MUD userland (out-of-cycle, separate repos). Strategic destination: AGNOS installable-state on archaemenid → user's planned **dual-boot migration**: 1TB ex-USB drive becomes Beelink internal NVMe + hosts AGNOS-primary; WD Blue SA510 SATA stays in chassis as Linux daily-driver root; 2TB Crucial P3 NVMe migrates to i9. See § *archaemenid migration* above and [[project_archaemenid_install_plan]]. Multi-cycle path: 1.32.x networking → 1.33.x ext4 WRITE → installable-state cycle slot TBD. See § *1.32.0 cycle* (CLOSED) + § *1.32.1 cycle* (OPEN). Pin stable on cycc 6.0.1. Build trajectory: 578,432 B (1.31.7 close) → 601,392 B (1.32.0 close) → **601,392 B (1.32.1 open, zero structural delta — only `version_str` literals shifted across the bump)**. |
| **agnoshi** | **1.3.3** | **6.0.1** | AI shell + closed-beta MVP boot-path console. Was 1.3.2 / pin 5.10.44 (live-bedrock cluster) in last refresh; graduated straight to 6.0.1, skipping the 5.11.x leading-edge tier. After this bump + agnos's 6.0.1 graduation, the MVP-path 5.10.44 holdouts narrow to **kybernet + argonaut** — the two repos still on 5.10.44 that need to graduate before the entire closed-beta MVP path runs on v6.0.x. |
| **chakshu** | **0.6.0** | **6.0.1** | AI-augmented system monitor (`shu` binary). Was 0.3.0 / pin 5.10.20 in last refresh — jumped three patch versions (0.3.0 → 0.6.0) AND graduated pin straight to 6.0.1 (one of the first three v6.0.x graduations). Started consuming mihi for its sys-info probe surface, which let the maturity arc compress. |
| **cyim-lsp** | 1.5.0 | 5.10.20 | LSP server companion to cyim. Pin moved 5.10.10 → 5.10.20. |
| **bannermanor** | **1.0.0** | **6.0.1** | **NEW + graduated to v1.0** (binary `bnrmr`). figlet-equivalent ASCII-art banner generator for login MOTDs / script intros / splash text. English wordplay (commandress/bannermanor naming lane); `bnrmr` vowel-dropped per the `commandress`→`cmdrs` compression pattern. Cut at 0.5.0 straight on v6.0.1 morning; jumped to **1.0.0** later 2026-05-20 — CLI flag surface, CYML font format (schema=1), and default in-tree font set (block / slim / big) all frozen as the v1.0 contract. Drove the darshana 0.3.0 → 0.3.5 color-primitives bump (banner colors). |
| **darshana** | **0.3.5** | **6.0.1** | TTY/raw-mode primitives library (दर्शन — viewing/showing). Extracted from cyim's `src/tty.cyr` once chakshu became a second consumer. Not a TUI framework — just termios + ANSI + cursor positioning. Was 0.3.0 / pin 5.10.20 in last refresh; 0.3.5 added ANSI color escape sequences so bannermanor's banners can render colored, AND graduated the pin straight from 5.10.20 → 6.0.1 in the same touch. |
| **hapi** | **0.5.0** | **6.0.1** | **NEW.** GNU `stow`-equivalent — dotfile / symlink farm manager. Hawaiian हपी (*happy*) + backronym **H**ome **A**sset **P**rovisioning **I**nterface — first Pacific Islands word in the AGNOS naming surface. CYML manifest per package, capability-bounded execution (touches `$HOME` only by default), lightweight audit trail. Cut at 0.5.0 straight on v6.0.1. |
| **kii** | **0.1.0** | **6.0.1** | **NEW 2026-05-22** — `chafa` / `jp2a` / `viu`-equivalent: image → ANSI/ASCII-art converter for terminal display. **Four-layered name** across three language families: (1) Hawaiian *image / picture / likeness* (what it produces); (2) East Asian *ki* (気) / *chi* (氣) — *life-force / vital energy* (kii is the *ki of the terminal*, the animating force that brings the screen to life via images); (3) English-phonetic back-half of **a-scii** (what it emits); (4) functional convergence — produces images via ASCII to animate the terminal, all three language angles describing the same operation. Triple-lane crossover (Polynesian + East Asian + English) is rare in the AGNOS naming surface — typical names sit in one lane. Polynesian Hawaiian micro-cluster with `hapi`, `anuenue`. Cut straight at 0.1.0 on cyrius 6.0.1; reads raster input (PNG, JPEG, GIF, BMP planned), quantizes to terminal-renderable color palette + glyph set, emits ANSI escape sequences sized to terminal cols × rows. |
| **iam** | **1.0.0** | **6.0.1** | **NEW.** fastfetch/neofetch-equivalent system-info display for login MOTD + screenshot flex. Pure inverse of `whoami` — whoami says who the user is, iam says what the system is. Thin presentation layer over the mihi probe library. Cut straight to 1.0.0 on cyrius 6.0.1 — second v6.0.x graduation. Lives in the English-wordplay/trickster naming lane per `feedback_naming_lanes`. |
| **mihi** | **1.0.0** | **6.0.1** | **NEW.** मिही / mihi — system-info probe library (CPU / RAM / GPU / kernel / uptime / distro / hostname). Substrate for iam, chakshu, and any tool that needs "tell me about this box." Maori: the formal self-introduction ceremony — Sanskrit-Hindi/Polynesian semantic naming lane per `feedback_naming_lanes`. First of the three v6.0.x graduations to be cut. |

---

## Active sweeps

### Niyama fold-in (v5.9.0 downstream sweep)

Fresh sibling-fold per niyama ADR 0011. Pattern parallels sandhi-fold (v5.7.0) and vani-fold (v5.8.0).

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (cyim is #1 multi-consumer gate; bare-metal kernel queued #2) | ✅ Done at v5.9.0 |
| 2 | In-tree fixture migration if needed | ✅ N/A — no fixtures touched |
| 3 | cyim → niyama integration verification (regex sweep) | ✅ Done — `cyim/src/main.cyr:51` includes `lib/niyama.cyr` directly |
| 4 | Document the niyama-fold pattern alongside sandhi/vani-fold in `design-patterns.md` | [ ] Pending |
| 5 | Niyama-fold-in article slot | [ ] Subsumed by [*What Justifies a Stdlib Foldin*](../articles/what-justifies-a-stdlib-foldin.md) — per-fold piece optional |

### gnoboot 0.2 merge + version bump (closed 2026-05-15)

Branch `0.2` merged to `main` (`529dfc1`) and tagged `v0.2.0`. Was one commit ahead at `d981fae` ("cleanup of canary and clear framebuffer for initial display"); structurally clean for merge after iron-boot ground truth landed.

| Action | Status |
|---|---|
| CMOS port-I/O blocks stripped (5 inline sites: entry / HandleProtocol / ELF-load / pre-EBS / post-EBS) | ✅ on branch — 0 CMOS refs in 0.2 vs 6 in main |
| UEFI-output collapse (`msg_li_f` … `msg_ebs_f` → shared `msg_fail` + `code_*` table + `efi_fail(st, code)` helper) | ✅ on branch |
| Banner tightened to `gnoboot v<VERSION>: handing off to kernel` (`tests/ovmf_smoke.sh` `EXPECT` synced) | ✅ on branch |
| `efi_clear(st)` called pre-banner so handoff line is the only thing on the framebuffer | ✅ on branch |
| Boot-info struct ABI preserved (magic `0x41474E4F`, RDI handoff, `fb_phys` at +0x48, GOP capture retained) | ✅ verified |
| CHANGELOG `[Unreleased]` section drafted | ✅ on branch |
| Bump `VERSION` 0.1.0 → 0.2.0 | ✅ shipped in 0.2.0 |
| Bump `cyrius.cyml` `version` field 0.1.0 → 0.2.0 | ✅ shipped in 0.2.0 |
| Sync `src/main.cyr` `msg_pre` banner UTF-16LE byte (`0x31` → `0x32`, `v0.1` → `v0.2`) | ✅ shipped in 0.2.0 |
| Sync `tests/ovmf_smoke.sh` default `EXPECT` (`gnoboot v0.1.0` → `gnoboot v0.2.0`, both literal + usage-example) | ✅ shipped in 0.2.0 |
| Rename `[Unreleased]` → `[0.2.0] — 2026-05-15` in `CHANGELOG.md` (Unreleased section preserved as empty placeholder for next cycle) | ✅ shipped in 0.2.0 |
| Rebuild verifies `OK` (`CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI`) | ✅ verified 2026-05-15 |
| Merge `0.2 → main` | ✅ landed (`529dfc1` on main) |
| Tag `v0.2.0` on `main` | ✅ tagged |
| Push branches + tag | ✅ pushed |

Sweep closed 2026-05-15. Per `feedback_bootloader_kernel_ownership` Claude owns gnoboot end-to-end during iron-boot bring-up; merge + tag were user-driven git ops per CLAUDE.md (user handles all git operations).

### Vani audio distlib fold-in (v5.8.0 downstream sweep)

Per [`vani/docs/development/cyrius-stdlib-fold-in.md`](https://github.com/MacCracken/vani/blob/main/docs/development/cyrius-stdlib-fold-in.md). Pattern parallels v5.7.0 sandhi fold.

| # | Action | Status |
|---|--------|--------|
| 1 | External consumer audit (`grep -rn "include.*lib/audio.cyr"` across ecosystem) | ✅ Done at v5.8.0 — zero hits |
| 2 | In-tree fixture migration (3 preprocessor-cap regression tests) | ✅ Done in cyrius repo at v5.8.0 |
| 3 | Document the fold-in pattern alongside sandhi-fold in `design-patterns.md` | ❌ Still pending (now subsumed by fold-in article) |
| 4 | Vani-fold-in article (parallels sandhi-fold article slot) | ❌ Still pending (now subsumed) |

### v5.7.x → v5.8.x → v5.9.x → v5.10.x → v5.11.x debt carry-forward

Status verified 2026-05-11 eve.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | yantra orphan `lib/http_server.cyr` delete | ❌ Pending | File still present at `yantra/lib/http_server.cyr`; cleanup-only, no callers. yantra still at 5.6.17 (deep-lag). |
| 2 | sit orphan `lib/http_server.cyr` delete | ✅ Done | Removed during v5.8.x; sit now at 5.9.37 |
| 3 | vyakarana grammar refresh — index 469 sandhi fns | ❓ Re-verify | vyakarana at 2.2.1 / 5.10.5 — version stable through v5.10–v5.11 burst, content reflection still unverified |
| 4 | vidya per-minor refresh (`language.toml` / `dependencies.toml` / `ecosystem.toml`) | ✅ Likely done | vidya at 2.7.0 / pin 5.9.43 — stable across two minors with active content tree |
| 5 | hoosh / ifran / daimon / mela / ark sandhi-fold audit-confirm | ✅ Confirmed clean | Zero `[deps.sandhi]` and zero include-sandhi refs in any (hoosh still on `cyrius.toml`; daimon now on .cyml 5.10.44; ark on .cyml 5.1.10 deep-lag) |
| 6 | **Boot-to-shell MVP enablement** | ✅ MVP GATE HIT 2026-05-18 (Iron Attempt 68) | argonaut 1.7.0 + kybernet 1.2.1 added agnoshi to BOOT_MINIMAL defaults 2026-05-11 eve. Closed-beta MVP definition (kernel + kybernet + agnoshi typeable on iron archaemenid) clears at agnos 1.30.9, cyrius pin 5.11.64. Active 1.30.x branch is now framebuffer refresh quality (1.30.10). |

### CVE-2026-31431 (Copy Fail) cleanup + audit

Linux kernel LPE in `algif_aead` (AF_ALG in-place AEAD + `splice()` → 4-byte page-cache write → root). Disclosed 2026-04-29; affects mainline kernels from 2017 onward. Roadmap item **S1**.

**AGNOS-native kernel** (`agnos` v1.30.9): structurally immune — verified at `kernel/core/syscall.cyr:32-36`, 26-syscall table contains no `socket`, no `splice`, no AF_ALG family. Bug class is unreachable. (Kernel has moved 1.26.1 → 1.30.9 since the original CVE audit across multiple bring-up cuts; syscall-surface unchanged. Syscall table verification is anchored on the syscall-table invariant, not the kernel patch level — re-verify only if the syscall surface grows.)

| # | Action | Status |
|---|--------|--------|
| 1 | Host defconfigs — pin `# CONFIG_CRYPTO_USER_API{,_HASH,_SKCIPHER,_AEAD,_RNG} is not set` in `agnosticos/kernel/{6.6-lts,6.x-stable,7.0-devel}/configs/*defconfig` and `kernel/configs/edge-{deeplens,nuc,rpi4,rpi5}.config` | ❌ Pending — re-verified 2026-05-09: zero `CRYPTO_USER_API` refs in any host defconfig |
| 2 | Audit local crypto-adjacent repos for `AF_ALG` / `algif_aead` refs: sigil, agnosys, phylax | ✅ Done 2026-05-03 — zero hits |
| 3 | Audit when next cloned: kybernet, libro, kavach, shakti, aegis, t-ron, argonaut, ark, agnostik, bote, daimon, hoosh | ❓ Deferred — repos not all local |
| 4 | Once defconfigs pinned, document the absence-by-design pattern alongside other AGNOS-vs-Linux structural-immunity examples in `design-patterns.md` | [ ] |

### Pending Cyrius ports

| Repo | Current state | Action |
|------|---------------|--------|
| **bhava** | 2.0.0 Rust (no `cyrius.cyml` on remote) | Port can start — v5.10.x stdlib + math additions are the gating concern |
| **goonj** | 1.4.3 Rust (Cargo.toml present locally) | Acoustics — port pending |
| **naad** | 1.2.5 Rust (Cargo.toml present locally) | Audio synthesis — port pending |
| **aethersafha** | 0.1.0 scaffold | Real implementation (Wayland compositor) |
| **aethersafta** | 0.50.0 (media compositing scene graph) | Distinct from aethersafha — not a Cyrius port target, near-stable lib |

### Per-repo housekeeping (P1/P2)

Carry-forward from v5.6.x → v5.7.x → v5.8.x → v5.9.x → v5.10.x. None blocking; bundle with each repo's next natural patch.

- **`docs/development/state.md` migration** (this pattern). **Done**: cyrius, owl (2026-04-23), agnosticos (this file), sandhi, sit, vidya. **Pending**: every other repo that still carries volatile state in CLAUDE.md (verified 2026-05-06: kybernet, daimon, agnos, abaco, hoosh, kavach, mabda, sigil all missing; presume similar for the unverified tail).
- **`cyrius.toml` → `cyrius.cyml` format migration**: tail collapsed v5.10–v5.11. **Migrated** (local-verified 5.10.44+): agnoshi, bote, t-ron, kavach, itihas (remote), nein. **Remaining** (local-verified pre-CYML / no pin): hoosh, shravan. **Remote-only — unverified**: avatara, ai-hwaccel, hadara — these likely migrated alongside the wave but need cloning to confirm.
- **`[build].modules` → `[lib] modules` migration**: sigil, agnosys, shakti pending. sakshi has `dist/sakshi.cyr` but no `modules` block — investigate generation mechanism.
- **`docs/adr/` scaffold** (12 repos still missing): agnosys, sigil, takumi, phylax, ark, nous, sakshi, yukti, bsp, owl, cyrius-doom, majra. Copy `README.md` + `template.md` from sit; don't back-fill historical decisions.
- **`docs/adrs/` → `docs/adr/` rename**: argonaut last offender.
- **kiran pin-field population** — kiran shipped 1.0.0 but `cyrius.cyml` still lacks `cyrius = "X.Y.Z"`. Worth populating now that it's stable.
- **Crate registry refresh** — ✅ swept 2026-05-20 PM (post-Attempt-82 drift sweep).
  - [`planning/shared-crates.md`](planning/shared-crates.md) (full registry, pre-1.0 + v1.0+): footer date now 2026-05-20 PM. All flagged bumps confirmed in-tree (agnostik 1.2.2, agnosys 1.2.6, sigil 3.1.1, sankoch 2.2.5, libro 2.6.3, sandhi 1.3.4, niyama 1.0.2, aegis 1.0.0, cyim 1.7.0, chakshu 0.6.0, darshana 0.3.5). v1.0+ graduations folded: **mihi 1.0.0** (OS & Infrastructure, +1 row), **iam 1.0.0** + **bannermanor 1.0.0** (Binaries & Tools, +2 rows). agnos 1.30.7 → 1.31.2 (pin 5.11.59 → 6.0.1) and agnoshi 1.3.2 → 1.3.3 (pin 5.10.44 → 6.0.1) rows refreshed to reflect storage-arc + iron-validation + mid-cycle pin graduations. gnoboot 0.4.1 → 0.4.2. Bannermanor moved from pre-1.0 to v1.0+ section; pre-1.0 binaries count 13 → 11. v1.0+ Stable Index header count 86 → 89.
  - [`docs/applications/libs/README.md`](../applications/libs/README.md) (v1.0+ stable subset): header date 2026-05-18 → 2026-05-20 PM, lib count 78 → 79 (mihi added to OS & Infrastructure), Binaries & Tools at v1.0+ list expanded to 12 (added bannermanor, commandress, iam alongside existing entries; pointer-link updated to `#binaries--tools-13-crates`).

### CLAUDE.md table refresh

Root [`CLAUDE.md`](../../CLAUDE.md) "Standalone Repos" table also drifted (same pattern as shared-crates.md). When refreshing, prefer pointing to this file or to shared-crates.md rather than re-duplicating versions in CLAUDE.md.

---

## Doc / article update queue

| File | Action |
|------|--------|
| [`roadmap.md`](roadmap.md) | v5.7.x / v5.8.x / v5.9.x / v5.10.x / v5.11.x phase definitions are now historical; v6.x = "what the language gains" (RISC-V rv64, PIE, closures, Class-B FFI, bare-metal). v5.12.x reservation rolled into v6.x. Re-touch on each v6.0.x ship. |
| [`summer-2026-arc.md`](summer-2026-arc.md) | Cycle-theme references need re-anchoring against v5.10.x three-arc retro + v5.11.x stdlib-annotation closeout + v6.0.0 rename-ceremony framing + closed-beta MVP gate hit on iron. |
| [`articles/cyrius-vs-rust-benchmarks.md`](../articles/cyrius-vs-rust-benchmarks.md) | Add v5.9.x / v5.10.x / v5.11.x / v6.0.0 rows; sweep "Pure compute gap" language for closed items |
| [`articles/port-ledger-volume-1.md`](../articles/port-ledger-volume-1.md) | ✅ Refreshed 2026-05-15 — locked to v5.5.4 baseline; accreted body updates stripped; *What Comes Next* expanded to 5-volume arc (V1 baseline → V2 mid-arc → V3 end-of-5.x/v6.0 → V4 post-v6.x → V5 synthesis). Where-Rust-Still-Wins markers point at Volume 2/3. |
| **NEW** [`articles/port-ledger-volume-2.md`](../articles/port-ledger-volume-2.md) | ✅ Shipped 2026-05-15 — mid-arc state-of-things snapshot. Kernel iron-validation receipt (the V2 headline); pin-cluster review across 5.10/5.11 ecosystem; four new native subsystems (aegis 1.0.0, gnoboot 0.2.0, commandress 0.1.0, kriya 0.2.0); V1's "Where Rust Still Wins" reviewed for direction-of-motion. Re-measurement comprehensive-cut deferred to V3. |
| [`articles/doom-in-cyrius.md`](../articles/doom-in-cyrius.md) | v5.11.x rebuild numbers when cyrius-doom ships an unblock release (still on pin 5.7.48) |
| [`articles/sovereign-compiler-vs-brute-force.md`](../articles/sovereign-compiler-vs-brute-force.md) | cycc self-host **874,240 B** at v6.0.0 (was cc5 741,048 B at v5.9.0; +133 KB across the v5.10.x three-arc cycle + v5.11.x 70-patch closeout; +8 B name-string delta at the rename ceremony). Pull current size from `cyrius/build/cycc` before publishing. |
| [`planning/shared-crates.md`](planning/shared-crates.md) | 🔄 Stale as of 2026-05-20 PM. Refresh queue: agnostik 1.2.2, agnosys 1.2.6, sigil 3.1.1, sankoch 2.2.5, libro 2.6.3, sandhi 1.3.4, niyama 1.0.2, aegis **1.0.0**, cyim 1.7.0, chakshu **0.6.0**, darshana **0.3.5**. New (graduated from planned → shipped): argonaut 1.7.0, kybernet 1.2.1, bannermanor 0.5.0, hapi 0.5.0, iam 1.0.0, mihi 1.0.0. |
| [`docs/applications/libs/README.md`](../applications/libs/README.md) | Bump versions for v1.0+ subset; "Last Updated 2026-04-15" predates three minors |
| [`first-party/first-party-documentation.md`](first-party/first-party-documentation.md) | Re-read at each v6.0.x patch — meta-irony from *Docs Go Stale Before the Commit* |
| [`first-party/first-party-standards.md`](first-party/first-party-standards.md) | ✅ Refreshed 2026-05-09 — full Cyrius-first rewrite; Rust-era archive at `docs/archive/first-party-standards-rust-era.md` |
| **NEW** ✅ [*What Justifies a Stdlib Foldin*](../articles/what-justifies-a-stdlib-foldin.md) | Shipped 2026-05-06 — meta-process article covering the gate framework, anti-criteria, mechanism, and three-instance pattern across sandhi/vani/niyama. Subsumes per-instance article slots. |
| **NEW** ✅ Phase-3-stdlib-foldin retrospective | Landed 2026-05-06 in vidya at `content/cyrius/field_notes/compiler/retros/foldin_arc_v57_v59.cyml`. Companion to *what-justifies-a-stdlib-foldin* (process) — the retro is the experiential ledger. |
| **NEW** [*v5.10.x: three arcs in five days*] (working title) | v5.10.x retro candidate — reframe past *REAL TYPE SYSTEM in 24 patches* working title. Cycle closed 2026-05-11 at .50 with three completed arcs (typed-simd ABI 11 phases, REAL TYPE SYSTEM 5 phases, struct-byval ABI 3 phases) + 2.7× compile-perf miniarc + PE premise debunk. Draftable now. |
| **NEW** [*Typed SIMD: the substrate for native codec ports*] (working title) | Companion to *port-ledger* — the typed-simd ABI arc (v5.10.28 → v5.10.39) is the foundation that turns tarang's "framework-only, codecs via C FFI" placeholder into an eventual handwritten-SIMD-codec lane (dav1d/FFmpeg territory). Frame as the *prerequisite landed; codec arc is future-arc work post-bare-metal*. Tarang competition framing piece. |
| **NEW** ✅ darshana extraction note | When darshana ships 1.0.0, document the cyim-private → shared-library extraction pattern (single-consumer-private → second-consumer-triggers-extraction) alongside other extraction examples. |
| **NEW** [*Why AGNOS-native agents can't be drained by a tweet*] (working title) | Black Hat / summer-2026-arc Beat 2 article — AGNOS agent-injection defense as second instance of the absence-by-design structural-immunity pattern (kernel CVE-2026-31431 was the first). Spec: [`planning/agent-injection-defense.md`](planning/agent-injection-defense.md). Roadmap: Phase 15A. Draft after Phase 1 ships (post-closed-beta). |

---

## Refresh procedure

When a v6.0.x patch closes:

1. Pull current `VERSION` + `cyrius.cyml`/`cyrius.toml` for affected repos
2. Update the pin-lag spectrum if any repo crossed a band (and exited the v5.11.x leading-edge bedrock by re-pinning to v6.0.x)
3. Tick off swept items
4. Re-anchor "Last refresh" date in the header
5. Re-anchor "Cyrius toolchain" if a new minor cut

When v6.0.x cycle closes:

1. Move v6.0.x slot list closeout summary into a brief retrospective (one paragraph)
2. Repoint all `6.0.x` references to whichever cycle is next (v6.1.x — back-compat symlinks drop here, plus whichever v6.x feature slot lands first)
3. Don't archive — rewrite in place. Git history is the snapshot.

---

## Related

- [`CLAUDE.md`](../../CLAUDE.md) — preferences/process/procedures (this doc holds the volatile state CLAUDE.md should NOT carry)
- [`applications/shared-crates.md`](applications/shared-crates.md) — authoritative crate registry (versions + roles)
- [`roadmap.md`](roadmap.md) — Cyrius milestone definitions and timeline
- [Cyrius CHANGELOG](https://github.com/MacCracken/cyrius/blob/main/CHANGELOG.md) — authoritative source for cycle status
- [Articles: *Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md) — the rationale for state.md as a pattern
- [Articles: *Your Docs Are About to Rot*](../articles/your-docs-are-about-to-rot.md) — the broader drift argument
- Per-repo `docs/development/state.md` (where it exists) — source of truth for that repo's local state; verify before acting

---

*Refresh in place per [*Docs Go Stale Before the Commit*](../articles/docs-go-stale-before-the-commit.md). Per-day refresh narratives previously accreted here have been pruned — git history is authoritative for prior-state recovery; CHANGELOGs + iron-nuc-zen-log are the canonical event ledgers.*
