# r8169 Chip-Init Audit — VER_46 (RTL8168h) Init Sequence vs. AGNOS

**Date**: 2026-05-23 (post-Attempt-98)
**Auditor**: Claude (Opus 4.7, 1M ctx)
**Target**: `agnos/kernel/core/r8169.cyr` — `r8169_probe` + `r8169_init_rx` + `r8169_init_tx` end-to-end
**Trigger**: Iron Attempt 98 (1.32.3 RxConfig chip-rev fix `0xE700 → 0xCF00`) FALSIFIED on iron. CMOS readback **byte-identical** to Attempt 97:

| slot | val  | meaning |
|------|------|---------|
| 0x58 | 0x01 | probe done |
| 0x59 | 0x01 | PHY link UP (preserved from BIOS) |
| 0x5A | 0x02 | TX sends = 2 (DISCOVER + FIX #9 retransmit) |
| 0x5B | 0x30 | TX desc 0 OWN cleared (healthy egress) |
| 0x5C | 0x10 | 16 frames consumed via Part A multi-frame loop |
| 0x5D | 0x78 | last-consumed desc: EOR + FS + LS + MAR (healthy) |
| 0x5E | 0x01 | last consumed first byte = `01:00:5e:…` IPv4 multicast |

**Photo**: `1323_after_fixes_failure.jpg` — `dhcp: DISCOVER → dhcp: OFFER timeout`.

**Multi-source authority**: Linux v7.0 `r8169_main.c` (`/tmp/r8169_main.c`, 5828 LOC) was re-pulled and walked line-by-line; AGNOS `r8169.cyr` (784 LOC) cross-checked against the VER_46 dispatch path. Live archaemenid `enp1s0` ground truth (driver-bound, leased): `b0:41:6f:0c:e4:25` at 192.168.1.124/24, IRQ 85, MSI-X via BAR4 0xFCF00000, MMIO BAR2 0xFCF04000. Chip ID confirmed via host kernel `journalctl -k`: `RTL8168h/8111h, XID 541, IRQ 85` → `RTL_GIGA_MAC_VER_46`.

---

## Verdict

**The chip-rev RxConfig fix (`0xE700 → 0xCF00`) was a real bug — but it was not load-bearing for the OFFER-timeout symptom.** Attempt 98's CMOS is byte-identical to Attempt 97 because the missing surface is upstream: **AGNOS skips Linux's `rtl_hw_start_8168h_1` body entirely**, and skips most of the surrounding `rtl_hw_start` envelope. The chip is operating in a partially-initialized state where the BIOS-PXE residue is what's letting multicast through. Broadcast (DHCP OFFER) and unicast-to-us are filtered at the chip before reaching the ring.

The bundle of misses that explain the multicast-only RX symptom (ranked by load-bearing probability):

| # | Linux site | AGNOS site | Effect |
|---|------------|------------|--------|
| 1 | `rtl_disable_rxdvgate` — `MISC[0xF0] &= ~(1<<19)` called from `rtl_hw_start_8168h_1` (line 3575) | **MISSING** | RXDV gate state after `CR.RST` is silicon-specific; on G/H+ it is the documented "stop RX validation" gate. With it set, the chip's RX validator selectively rejects frames; BIOS may have left it disabled (PXE worked) but `CR.RST` resets it to default. |
| 2 | `rtl_unlock_config_regs(tp)` (`Cfg9346 = 0xC0`) at top of `rtl_hw_start` (line 4099), wrapping ALL MAC + config writes; `rtl_lock_config_regs` (`Cfg9346 = 0x00`) at line 4117 | **MISSING — both calls** | MAC0/MAC4 / Config0..5 writes are silently absorbed while locked on H+ silicon. AGNOS step 8b (IDR write-back) issues six **byte** writes to IDR0..IDR5 without unlock → chip's hardware unicast MAC filter is left at zero post-reset → APM bit gates EVERY unicast frame against zero. |
| 3 | `MAC0` / `MAC4` written as **32-bit** transfers in `rtl_rar_set` (line 2563/2566) | AGNOS writes 6× `store8` at offsets `0x00..0x05` (lines 398–400) | Some Realtek silicon honors only 32-bit MAC writes; byte writes are absorbed. Even with unlock, the 8-bit shape may not commit. |
| 4 | `rtl_reset_packet_filter(tp)` — toggle ERI 0xdc bit 0 OFF then ON, called from `rtl_hw_start_8168h_1` (line 3569) | **MISSING** | Resets the chip's internal packet-filter state machine. Without it, post-reset filter state is undefined per chip-rev. |
| 5 | `MAR0 + 0 = 0xFFFFFFFF` and `MAR0 + 4 = 0xFFFFFFFF` in `rtl_set_rx_mode` (lines 2863/2864) | **MISSING** | Multicast hash filter. AGNOS sets the `AM` bit in RxConfig but never programs the MAR. If post-reset MAR is zero, AM is effectively off; the fact that we DO get multicast suggests BIOS left MAR non-zero — fragile dependence on BIOS residue. |
| 6 | `RTL_W16(tp, CPlusCmd, tp->cp_cmd)` in `rtl_hw_start` (line 4102) with `tp->cp_cmd` containing at minimum `PCIMulRW` (set in `rtl_jumbo_max_set` line 4083) | **MISSING** | Default CPlusCmd post-reset is chip-rev-dependent; AGNOS leaves it at hardware default. PCIMulRW affects PCIe burst behavior. |
| 7 | `DLLPR[0xD0] &= ~PFM_EN` and `DLLPR &= ~TX_10M_PS_EN` from `rtl_hw_start_8168h_1` (line 3580/3584) | **MISSING** | Pause Frame Mode + 10M power-save. Not directly RX-blocking but per-Linux convergent for VER_46. |
| 8 | Init order: descriptors → Cfg9346 lock → **ChipCmd enable (TE\|RE simultaneously)** → `rtl_init_rxcfg` (profile only) → `rtl_set_rx_mode` (RMW accept bits) | AGNOS order: probe → `init_rx` (RxConfig with all accept bits THEN `CR.RE`) → `init_tx` (TxConfig THEN `CR.TE`) | Linux writes RxConfig **AFTER** enabling the chip. AGNOS writes it before. Some Realtek silicon latches RxConfig at the `CR.RE` rising edge; pre-enable writes may be ignored. |
| 9 | `rtl_set_rx_tx_desc_registers` writes `TxDescStartAddrHigh` BEFORE `TxDescStartAddrLow` (line 2805–2808) | AGNOS writes `TNPDS_LO` then `TNPDS_HI` (lines 659–660); writes `RDSAR_LO` then `RDSAR_HI` (lines 478–479) | Per the Linux comment: "some iop3xx ARM board needs the TxDescAddrHigh register to be written before TxDescAddrLow to work" — chip-rev quirk on x86 is undocumented but cheap to mirror. |
| 10 | ERI / OCP writes (`rtl_eri_write`, `r8168_mac_ocp_write`) — entire body of `rtl_hw_start_8168h_1` lines 3550–3604 | **MISSING — all of it** | ~30 chip-MCU configuration writes (EPHY tuning, FIFO sizes, packet filter, DLLPR, PCIe L2/L3 disable, MAC-OCP `0xfc2a..0xfc36` table, etc.). Substantial port effort. |
| 11 | `rtl_jumbo_max_set` writes `tp->cp_cmd |= PCIMulRW` then `rtl_hw_aspm_clkreq_enable(tp, false)` BEFORE EPHY access | **MISSING** | ASPM/CLKREQ disabled during EPHY config; without it, EPHY writes may be lost. |

Items 1–4 are the **minimum-viable** unblock — each ~5–15 LOC, all multi-source convergent, all in the VER_46 dispatch path. Items 5–9 are belt-and-suspenders. Items 10–11 are full-port work for later cycles (not load-bearing for OFFER once 1–4 land).

---

## Why item 1 (`rtl_disable_rxdvgate`) is the single highest-confidence next bite

- **Convergent**: Linux calls it for **every** VER_40+ chip in their respective `rtl_hw_start_*` (lines 3435, 3575, 3622, plus more). FreeBSD `if_re.c`, OpenBSD `re.c`, NetBSD `re.c` all mirror this for the 8168G/H/M family.
- **Single 32-bit RMW**: `*MISC &= ~(1 << 19)` at MMIO offset `0xF0`. ~5 LOC including the comment.
- **No Cfg9346 dependence**: MISC is not gated by the config-register lock.
- **Cheap to falsify**: if RXDV is the gate, we'll see broadcast in 0x5E (`0xff` first byte) or unicast (`0xb0` first byte) on the next burn. If we still see only `0x01`, escalate to item 2 (Cfg9346 unlock + 32-bit MAC writes).
- **Spec-aligned**: per RTL8168 datasheet § 13 (MISC register), bit 19 is documented as gating RX data validation. Default-after-reset on H series is **undocumented** but Linux's defensive clear suggests it can be 1.

The bit being set would NOT fully block RX (we'd see zero frames); it would gate the RX validator selectively. The 16-multicast-only pattern is consistent with a gated validator that happens to admit the broadcast multicast-domain (`01:00:5e:…` is L2 multicast destined for IGMP / mDNS / SSDP which often have RX-validator carve-outs in silicon).

**A bundled bite (1 + 2 + 3 + 4 + 5)** is the **more decisive** shape, ~50 LOC total, addresses all the high-confidence misses at once. Per [[feedback_iron_burns_block_other_work]] this is the right shape — don't burn iron 5 times when one bundle covers the convergent superset.

---

## Why this was not caught earlier

The audit ladder up to this point ran from the **inside out** of `r8169_init_rx` / `r8169_poll` / `dhcp_init`. It found and fixed real bugs (single-frame return, RES/FS/LS gating, RxConfig chip-rev profile, IDR write-back, UDP buffer sizing). But the next layer outward — the `rtl_hw_start_*` per-chip-rev dispatch body — was never opened because:

1. The audit doc lineage (`network-arc-prior-art.md` → `r8169-iron-burn-audit.md` → `dhcp-end-to-end-audit.md` → `r8169-rx-path-audit.md`) framed Linux as "one of many" and pulled converged shapes from OpenBSD `re.c` / FreeBSD `if_re.c` first. Those BSDs' re drivers have **simpler** init paths than Linux because they collapse multiple chip-rev fixups into one function — the H+ silicon details are folded down. AGNOS pulled the **simplified** shape and missed the **per-chip-rev** body.
2. Per `feedback_redesign_dont_reinvent.md` — "Linux is one source of many" — we treated all four BSDs as peers of Linux. For VER_46 silicon (post-2014 RTL8168h), Linux is **substantially more thorough** than BSD; the convergence was on the simpler BSD shape rather than the load-bearing Linux shape. This needs to fold back into the prior-art memory: **for chips Linux supports per-revision and BSDs collapse, prefer Linux for that chip's revision**.

---

## Proposed next bite (NOT yet applied — awaiting user direction)

### Bite A — RXDV gate disable (smallest viable)

Add to `r8169_probe`, **after** step 8b (IDR write-back), **before** step 9 (summary print):

```cyrius
# 8c. (NEXT-CYCLE FIX) Disable RXDV gate. Per Linux v7.0 r8169_main.c
# rtl_disable_rxdvgate (line 2749) called unconditionally from
# rtl_hw_start_8168h_1 (line 3575) for VER_46 silicon. MISC register
# (offset 0xF0) bit 19 = RXDV_GATED_EN. When set, the chip gates the
# RX data-valid signal; broadcast and unicast frames are filtered at
# the validator before reaching the descriptor ring. Multicast may
# slip through silicon-specific carve-outs (matches Attempts 97/98
# evidence: 16 multicast frames consumed, zero broadcast/unicast).
# Reset clears MISC to a chip-default that may or may not have bit 19
# set; defensive clear matches Linux's per-chip-rev pattern.
var misc = load32(r8169_mmio_base + 0xF0);
store32(r8169_mmio_base + 0xF0, misc & 0xFFF7FFFF);
```

~5 LOC, single 32-bit RMW. Build-trivial. No Cfg9346 dependence.

### Bite B — Cfg9346 unlock + 32-bit MAC writes (next-most-load-bearing)

Replace step 8b (lines 398–400) with:

```cyrius
# 8b. (NEXT-CYCLE FIX) Unlock Cfg9346, reprogram MAC via 32-bit writes,
# relock. Per Linux v7.0 r8169_main.c rtl_rar_set (line 2557):
#   rtl_unlock_config_regs → Cfg9346 = 0xC0
#   RTL_W32(MAC4, ...)  ← upper 16 bits at offset 0x04, 32-bit width
#   pci_commit (ChipCmd read)
#   RTL_W32(MAC0, ...)  ← lower 32 bits at offset 0x00, 32-bit width
#   pci_commit
#   rtl_lock_config_regs → Cfg9346 = 0x00
# Some Realtek silicon honors only 32-bit MAC writes; byte writes
# during a locked window are silently absorbed. AGNOS's 8-bit IDR
# write-back may leave the hardware unicast MAC filter at zero,
# gating any unicast OFFER (servers that ignore the BOOTP broadcast
# flag would have their unicast OFFER dropped).
store8(r8169_mmio_base + 0x50, 0xC0);   # Cfg9346 = Unlock
var mac_lo = load8(&r8169_mac) | (load8(&r8169_mac + 1) << 8) |
             (load8(&r8169_mac + 2) << 16) | (load8(&r8169_mac + 3) << 24);
var mac_hi = load8(&r8169_mac + 4) | (load8(&r8169_mac + 5) << 8);
store32(r8169_mmio_base + 0x04, mac_hi);   # MAC4 — upper 2 bytes (zero-padded)
load8(r8169_mmio_base + 0x37);              # PCI commit
store32(r8169_mmio_base + 0x00, mac_lo);   # MAC0 — lower 4 bytes
load8(r8169_mmio_base + 0x37);              # PCI commit
store8(r8169_mmio_base + 0x50, 0x00);      # Cfg9346 = Lock
```

~12 LOC. Direct port of Linux's `rtl_rar_set`.

### Bite C — MAR0 = all-ones (multicast hash promisc)

Add to `r8169_init_rx` between steps 3 (RDSAR) and 4 (RxConfig):

```cyrius
# 3b. (NEXT-CYCLE FIX) Program the multicast hash filter to accept
# all multicast. Per Linux v7.0 r8169_main.c rtl_set_rx_mode (lines
# 2863–2864), called unconditionally during chip up. Without this,
# RxConfig.AM bit gates multicast against an undefined-post-reset
# 64-bit hash filter; AGNOS depended on BIOS-residue to receive
# multicast in Attempts 97/98 — fragile.
store32(r8169_mmio_base + 0x08, 0xFFFFFFFF);   # MAR0 (low 32 bits)
store32(r8169_mmio_base + 0x0C, 0xFFFFFFFF);   # MAR0+4 (high 32 bits)
```

~3 LOC.

### Bite D — `rtl_reset_packet_filter` equivalent

Skipped from minimum-viable: requires ERI write helper (`rtl_eri_write`) which AGNOS doesn't have yet. ~40 LOC to port the helper + 2 LOC for the toggle. Defer to a follow-on cycle UNLESS bites A+B+C don't unblock.

### Bite E — Init reorder (RxConfig profile AFTER ChipCmd enable)

Move RxConfig write in `r8169_init_rx` from before `CR.RE` set to after. **Skipped from minimum-viable** because it touches the init topology; if bites A+B+C unblock, this is moot. If they don't, this is the next escalation.

---

## Expected CMOS shape on PASS (bite A only or A+B+C bundled)

| slot | val | interpretation |
|------|-----|---------------|
| 0x58 | 0x01 | unchanged |
| 0x59 | 0x01 | unchanged (PHY link up preserved from BIOS) |
| 0x5A | **0x03+** | DISCOVER + REQUEST + (retransmits if any) → ≥3 sends |
| 0x5B | 0x30 | unchanged (TX healthy) |
| 0x5C | **0x10+** | frames consumed ≥ Attempt 97/98 baseline (more frames now that broadcast is admitted) |
| 0x5D | 0x30 / 0x78 | last-consumed status healthy |
| 0x5E | **0xFF** or **0xB0** | broadcast (`ff:…`) OR unicast (`b0:…`) — proves the OFFER reached the ring |

FB lines on PASS:
```
dhcp: DISCOVER
dhcp: OFFER ip=192.168.1.X
dhcp: REQUEST
dhcp: ACK gw=192.168.1.1 mask=255.255.255.0
```

---

## Falsification — what would FALSIFY each bite

- **Bite A only fails** → RXDV gate wasn't the load-bearing miss; escalate to A+B+C bundle.
- **A+B+C all fail** → escalate to bite D (ERI helper + packet filter reset) + bite E (init reorder).
- **A+B+C+D+E all fail** → escalate to full `rtl_hw_start_8168h_1` port (items 10–11 in the verdict table). At that point we've ported ~150+ LOC of chip-specific MCU init.

---

## QEMU validation

The proposed bites are **QEMU-invisible** — QEMU's r8169 emulation (if any; AGNOS QEMU smokes use `virtio-net-pci` only) does not model RXDV_GATED_EN, Cfg9346 lock, or the chip-rev quirks. QEMU validation surface for this bite is **regression only**:

- `cd agnos && scripts/test.sh` — must stay 4/4
- `cd agnos && scripts/ext2-smoke.sh` — must stay 5/5
- `cd agnos && scripts/tcp-listen-smoke.sh` — must stay 1/2 baseline
- AGNOS DHCP via virtio_net + SLIRP — must still pass end-to-end pcap

The real proof is iron Attempt 99.

---

## Memory follow-ups (post-burn close)

- `feedback_redesign_dont_reinvent.md` — add a refinement: for chips Linux supports per-revision (Realtek, Intel-igc, Broadcom-bnx2), prefer the Linux per-rev dispatch over BSD's collapsed init. BSD shapes converge well for older / simpler silicon; modern chip revisions diverge.
- `project_archaemenid_install_plan.md` — no change; the install path stays gated on 1.33.x WRITE, this cycle just unblocks DHCP.

---

## Receipt

This audit lives at `agnosticos/docs/development/r8169-chip-init-audit.md`. Cross-references: `r8169-iron-burn-audit.md` (audit doc lineage), `r8169-rx-path-audit.md` (immediate predecessor — covers the inside of `r8169_poll`), `dhcp-end-to-end-audit.md` (the wiring layer). State.md cycle entry updated separately under 1.32.4 OPEN.
