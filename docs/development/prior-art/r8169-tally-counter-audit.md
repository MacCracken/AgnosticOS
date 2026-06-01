# r8169 Tally Counter (DTCCR) — Multi-Source Convergent Audit

**Sources triangulated** (fetched 2026-05-24):
- FreeBSD `sys/dev/re/if_re.c` + `sys/dev/rl/if_rlreg.h` (HEAD/main)
- Linux `drivers/net/ethernet/realtek/r8169_main.c` (v6.7 stable)
- OpenBSD `sys/dev/ic/re.c` + `sys/dev/ic/rtl81x9reg.h` (master)

## Executive Summary

All three drivers agree byte-for-byte on the DTCCR mechanism: a 64-byte-aligned DMA buffer of **64 bytes** holds 13 little-endian counter fields; the CPU writes phys-addr high to **MMIO 0x14**, then low to **0x10** (twice — first plain, then OR'd with bit 3 `DumpCounter`), then polls 0x10 for bit 3 clear. FreeBSD and OpenBSD use identical struct layouts (FreeBSD `struct rl_stats`, OpenBSD `struct re_stats` — same field order, same widths, `__packed __aligned(8)` on OpenBSD); Linux's `struct rtl8169_counters` is the same shape with one extra trailing `__le16 tx_underun` not present in BSD names but at the same byte offset as OpenBSD's `re_tx_undrn`. AGNOS's working assumptions are correct on register offsets and the trigger bit; the alignment assumption ("page-aligned ≥256") is **over-tight but safe** — canonical alignment is **64 bytes**, total size **64 bytes**. The dump operation is read-only from the chip's perspective on already-accumulated tally registers — **does not stall or reset RX/TX queues** when invoked with `CounterDump` (bit 3); a separate `CounterReset` (bit 0) explicitly zeroes them and is what's used at open-time only on MAC_VER ≥ 19.

## Struct Layout (64 bytes total, little-endian)

| Offset | Size | Field | Meaning | Source citations |
|--------|------|-------|---------|------------------|
| 0x00 | 8 | TxOK / `tx_packets` / `rl_tx_pkts` / `re_tx_ok` | Frames transmitted OK | Linux `r8169_main.c:557`, FBSD `if_rlreg.h:738`, OBSD `rtl81x9reg.h:695` |
| 0x08 | 8 | RxOK / `rx_packets` / `rl_rx_pkts` / `re_rx_ok` | Frames received OK | L:558, F:739, O:696 |
| 0x10 | 8 | TxER / `tx_errors` / `rl_tx_errs` / `re_tx_er` | TX errors (aggregate) | L:559, F:740, O:697 |
| 0x18 | 4 | RxER / `rx_errors` / `rl_rx_errs` / `re_rx_er` | RX errors (CRC + length etc.) | L:560, F:741, O:698 |
| 0x1C | 2 | MissPkt / `rx_missed` / `rl_missed_pkts` / `re_miss_pkt` | RX dropped (no buffer / overflow) | L:561, F:742, O:699 |
| 0x1E | 2 | FAE / `align_errors` / `rl_rx_framealign_errs` / `re_fae` | Frame Alignment Errors | L:562, F:743, O:700 |
| 0x20 | 4 | Tx1Col / `tx_one_collision` / `rl_tx_onecoll` / `re_tx_1col` | TX OK after exactly 1 collision | L:563, F:744, O:701 |
| 0x24 | 4 | TxMCol / `tx_multi_collision` / `rl_tx_multicolls` / `re_tx_mcol` | TX OK after >1 collisions | L:564, F:745, O:702 |
| 0x28 | 8 | RxOKPhy / `rx_unicast` / `rl_rx_ucasts` / `re_rx_ok_phy` | RX OK unicast (matched our MAC) | L:565, F:746, O:703 |
| 0x30 | 8 | RxOKBrd / `rx_broadcast` / `rl_rx_bcasts` / `re_rx_ok_brd` | RX OK broadcast | L:566, F:747, O:704 |
| 0x38 | 4 | RxOKMul / `rx_multicast` / `rl_rx_mcasts` / `re_rx_ok_mul` | RX OK multicast | L:567, F:748, O:705 |
| 0x3C | 2 | TxAbort / `tx_aborted` / `rl_tx_aborts` / `re_tx_abt` | TX aborts (excessive collisions) | L:568, F:749, O:706 |
| 0x3E | 2 | TxUnderrun / `tx_underun` / `rl_rx_underruns` / `re_tx_undrn` | TX FIFO underrun (FreeBSD name is misleading; field is TX, confirmed by Linux + OpenBSD) | L:569, F:750, O:707 |

**Total: 0x40 (64) bytes.** OpenBSD declares `__packed __aligned(sizeof(uint64_t))` (`rtl81x9reg.h:708`). The struct is naturally 8-byte aligned and contains no implicit padding — the offsets above are byte-exact across all three drivers.

**Naming nit**: FreeBSD's field `rl_rx_underruns` at offset 0x3E is mis-named — Linux and OpenBSD both confirm this is **TX** underrun (chip side: TX FIFO emptied before frame completed transmission). AGNOS should follow Linux/OpenBSD nomenclature (`tx_underrun`).

## Canonical Procedure (8 steps)

1. **Allocate** a 64-byte DMA buffer, **64-byte aligned**, accessible to the chip in the 32/64-bit DMA window.
   - FreeBSD: `RL_DUMP_ALIGN 64` (`if_rlreg.h:782`), size `sizeof(struct rl_stats)` (`if_re.c:1181`).
   - OpenBSD: `RE_STATS_ALIGNMENT 64` (`rtl81x9reg.h:710`), size `sizeof(struct re_stats)` (`re.c:2581`).
   - Linux: `dmam_alloc_coherent(&pdev->dev, sizeof(*tp->counters), &tp->counters_phys_addr, GFP_KERNEL)` (`r8169_main.c:5370-5371`) — relies on `dma_alloc_coherent`'s natural alignment (page-aligned on Linux, but the chip only requires 64).
   - **AGNOS's "page-aligned ≥256"**: safe over-alignment; can stay or relax to 64 — chip silicon doesn't care above 64.

2. **Guard**: only dump when `ChipCmd & CmdRxEnb` and `ChipCmd != 0xFF`. Linux comment is explicit: *"Some chips are unable to dump tally counters when the receiver is disabled. If 0xff chip may be in a PCI power-save state."* (`r8169_main.c:1640-1647`). FreeBSD's `re_get_stats` sysctl gates on `IFF_DRV_RUNNING` (`if_re.c:4013`).

3. **Sync DMA pre-read** (CPU side flushes any cached writes to the buffer region; on x86 with coherent DMA this is a no-op but architecturally required). FreeBSD: `bus_dmamap_sync(..., BUS_DMASYNC_PREREAD)` (`if_re.c:4017-4018`).

4. **Write phys-addr high** to `CounterAddrHigh` / `RL_DUMPSTATS_HI` = **MMIO 0x14** (32-bit write, upper 32 bits of buffer phys-addr).
   - Linux `r8169_main.c:1630`: `RTL_W32(tp, CounterAddrHigh, upper_32_bits(tp->counters_phys_addr));`
   - FreeBSD `if_re.c:4019-4020`: `CSR_WRITE_4(sc, RL_DUMPSTATS_HI, RL_ADDR_HI(...));`
   - Register def: FreeBSD `if_rlreg.h:118`, OpenBSD `rtl81x9reg.h:125`, Linux `r8169_main.c:176`.

5. **PCI commit/flush** between writes — Linux explicitly inserts `rtl_pci_commit(tp)` (`r8169_main.c:1631`) to drain the posted write before touching the low register. This is the read-back-PCI flush pattern; matters on AGNOS x86 if writes are write-combining.

6. **Write phys-addr low (no start bit)** to `CounterAddrLow` / `RL_DUMPSTATS_LO` = **MMIO 0x10** — pure address load, bit 3 clear.
   - Linux `r8169_main.c:1632`: `RTL_W32(tp, CounterAddrLow, cmd);` (`cmd` = `lower_32_bits(phys)`, line 1628).
   - FreeBSD `if_re.c:4021-4022`: `CSR_WRITE_4(sc, RL_DUMPSTATS_LO, RL_ADDR_LO(...));`

7. **Write phys-addr low OR'd with `CounterDump` (bit 3 = 0x8)** — this is the actual dump trigger.
   - Linux `r8169_main.c:1633`: `RTL_W32(tp, CounterAddrLow, cmd | counter_cmd);` where `counter_cmd = CounterDump = 0x8` (`r8169_main.c:464`).
   - FreeBSD `if_re.c:4023-4025`: `CSR_WRITE_4(sc, RL_DUMPSTATS_LO, RL_ADDR_LO(addr | RL_DUMPSTATS_START))` where `RL_DUMPSTATS_START = 0x00000008` (`if_rlreg.h:479`).
   - **AGNOS's assumption confirmed**: write phys-addr-low with bit 3 set is the trigger; the two-write sequence (plain then OR-bit3) is canonical and is what Linux/FreeBSD both do.

8. **Poll** `CounterAddrLow` (0x10) for bit 3 clear. Chip clears bit 3 when DMA write of the 64-byte buffer is complete.
   - Linux: `rtl_loop_wait_low(tp, &rtl_counters_cond, 10, 1000)` — 10 µs sleep, **1000 iterations max ≈ 10 ms** (`r8169_main.c:1635`). Predicate at 1621-1624: `RTL_R32(tp, CounterAddrLow) & (CounterReset | CounterDump)`.
   - FreeBSD: `for (i = RL_TIMEOUT; i > 0; i--) { ... DELAY(1000); }` — `RL_TIMEOUT` is **1000** in `if_rlreg.h`, `DELAY(1000)` = 1 ms ⇒ **1000 ms max** (`if_re.c:4026-4031`).
   - **Convergent bound for AGNOS**: 10 ms is the tight Linux bound; FreeBSD's 1 s is paranoid. **Use 10 ms** with a 100 ms ceiling as a generous outer bound; emit a CMOS diagnostic stamp if poll exceeds 10 ms but completes before 100 ms.

9. **Sync DMA post-read** (`BUS_DMASYNC_POSTREAD`, FreeBSD `if_re.c:4032-4033`). On x86 coherent DMA: no-op architecturally; on AGNOS still a barrier point — issue an `mfence` / `dmb` here to ensure subsequent reads see chip writes.

10. **Read fields** from the buffer (CPU-side, byte-offset table above). All multi-byte fields are **little-endian on the wire**; AGNOS is LE so direct load is fine (`le64toh`/`le32toh`/`le16toh` are byte-swaps only on BE hosts — FreeBSD `if_re.c:4044-4068`, Linux `r8169_main.c:1694-1705`).

**Reset operation** (separate, NOT needed for diagnostic dump): write phys-addr-low with bit 0 (`CounterReset = 0x1`, Linux `r8169_main.c:461`) instead of bit 3. AGNOS should **NOT** issue reset during the ARP-debug session — leave accumulated counters intact across burns to compare deltas.

## Chip-Rev Caveats — RTL8168h / mac_version 46 / XID 0x541

- **Identification confirmed**: Linux maps XID `0x541` → `RTL_GIGA_MAC_VER_46 = "RTL8168h/8111h"` (`r8169_main.c:2067` + `:135`). AGNOS's `mac_version 46` reading is correct.
- **Tally dump works on this stepping** — no MAC_VER_46-specific workaround for the DTCCR path. Linux's only mac_version gate is at `r8169_main.c:1672`: `if (tp->mac_version >= RTL_GIGA_MAC_VER_19) rtl8169_do_counters(tp, CounterReset);` — MAC_VER_46 is well above 19, so the chip supports `CounterReset` (we won't use it). The dump operation itself has no MAC_VER gate anywhere in any of the three drivers.
- **Early Tally Counter — leave alone**: Linux's `MISC` register has an `EARLY_TALLY_EN` bit (1 << 16) at `r8169_main.c:329` that `rtl_hw_start_8106` *clears* at line 3557 — only for the RTL8106 path. The 8168h/MAC_VER_46 path (`rtl_hw_start_8168h_1`, dispatched at `r8169_main.c:3712`) does NOT touch `EARLY_TALLY_EN`. **AGNOS should not flip this bit** on MAC_VER_46.
- **8168h_1 hw-start does clear FuncEvent 0x010000** at `r8169_main.c:3508` ("Disable Early Tally Counter") — this is part of the standard 8168h init that AGNOS likely already mirrors; confirm `rtl_hw_start` writes this before any tally read attempt.
- **No errata** in any of the three drivers warning about MAC_VER_46-specific DTCCR bugs. RTL8168h is mature silicon (2014-era).

## "Doesn't Mask The Bug" Justification

The ARP-timeout symptom AGNOS is chasing has three failure modes the tally dump will resolve **without perturbing**:

1. **TX never hit the wire** → `TxOK` will not increment between two snapshots taken before/after the ARP request burn. The DTCCR DMA write is a chip-internal copy of accumulator latches into our buffer; it does **not** touch the TX FIFO, TX descriptor ring, or the MAC transmitter state machine. Linux's gate at `r8169_main.c:1646` (`val & CmdRxEnb`) confirms the receiver must be **enabled** for dump to proceed — meaning the dump runs *with the live RX path intact*, not by quiescing it.

2. **RX dropped the gateway's reply silently** → `RxOK` increment + `MissPkt` increment + `RxER`/`FAE` deltas distinguish: (a) frame reached MAC but no descriptor available (`MissPkt++`), (b) frame had CRC/align error (`RxER++` / `FAE++`), (c) frame received OK but our descriptor handler ignored it (`RxOK++` but no SW counter movement — points squarely at our RX descriptor processing).

3. **Collisions / underruns on TX path** → `Tx1Col` / `TxMCol` / `TxAbort` / `TxUnderrun` deltas. A modern gigabit link in full-duplex should show **zero** collisions; any non-zero value here is a physical-layer or duplex-mismatch tell.

The DTCCR operation is a **one-way DMA write from chip to host**. No descriptor rings are touched, no interrupt mask is altered, no MAC/PHY register is touched, no link state is renegotiated. The only chip-side state change is the `CounterAddrLow` register transitioning bit 3 from 1→0 when the DMA write completes — a private status flag, not visible to either the TX or RX datapath. The polling loop reads only `CounterAddrLow`; it does not poll any TX/RX status register. **The diagnostic is causally orthogonal to the bug.**

The only weak edge: if `ChipCmd & CmdRxEnb == 0` at the moment we attempt the dump, Linux's guard (`r8169_main.c:1646`) silently skips the operation. AGNOS should **assert** `CmdRxEnb` is set before dumping and log a CMOS-stamp if it isn't — that itself is a bug signal (RX disabled mid-ARP-wait).

## Convergence Table

| Question | AGNOS assumption | Convergent answer | Status |
|---|---|---|---|
| DTCCR offsets | 0x10 / 0x14 | 0x10 (low+trigger) / 0x14 (high) | **Correct** |
| Trigger bit | bit 3 on low after addr write | bit 3 (`0x8`) on low; two-write sequence (plain, then OR'd) | **Correct, refine to two-write** |
| Buffer alignment | page-aligned ≥256 | 64-byte alignment, 64-byte size | **Over-tight but safe** |
| Struct layout | (unknown) | 13 fields, 64 bytes, LE, table above | **Newly resolved** |
| MAC_VER 46 caveat | (unknown) | None — works on 8168h directly | **No workaround needed** |
| Poll timeout | (unknown) | 10 ms (Linux tight) … 1 s (FreeBSD paranoid); use 10 ms with 100 ms ceiling | **Newly resolved** |
| RX/TX side effects | (unknown) | None — DMA-write only, no datapath touch | **Safe** |
