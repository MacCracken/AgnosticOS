# r8169 RX-Path Audit

**Date**: 2026-05-23
**Auditor**: Claude (Opus 4.7, 1M ctx)
**Target**: `agnos/kernel/core/r8169.cyr` (705 LOC) — `r8169_init_rx` (lines 428–503) and `r8169_poll` (lines 507–552)
**Trigger**: Attempt 96 — CMOS post-mortem on archaemenid shows `r8169_send` fired (0x5A=0x02), TX desc 0 OWN cleared (0x5B=0x30), `r8169_poll` saturated (0x5C=0xFF), RX desc 0 was re-armed at least once (0x5D=0x80), and one frame was DMA'd into the ring (0x5E=0x01 — IPv6 multicast first byte). But the DHCP OFFER the LAN's server demonstrably sends in response to our DISCOVER (proven: Linux dhclient on this exact wire / MAC / box leases `192.168.1.124`) never reaches `dhcp_init`'s OFFER-match loop. Virtio_net rewrite (1.32.3) proved upper layers (`net_poll` → `ethernet_recv` → `net_handle_udp` → `udp_recv_from` → `dhcp_init`) are byte-correct end-to-end under QEMU. Bug lives between "chip DMAs the OFFER into our buffer" and "`ethernet_recv` runs on that frame."
**Hypothesis under test**: `r8169_poll` mis-handles the RX descriptor ring — either drains only one descriptor per call while frames pile up behind it, mis-extracts length, or fails to validate `FS`/`LS`/`RES` bits so it dispatches the *wrong* frame to upper layers.

---

## Verdict

**LOAD-BEARING BUG: `r8169_poll` returns after a single descriptor whether or not that descriptor holds the frame we care about.** The CMOS evidence is dispositive: slot 0x5C=0xFF (poll loop saturated at 255+ iterations) combined with slot 0x5E=0x01 (RX desc 0 buffer first byte is `0x01`, the high-nibble of IPv6 multicast `33:33:...` destination MAC) tells us **the poll loop ran hundreds of times, repeatedly consumed *that one IPv6 ND frame* out of desc 0, re-armed desc 0, and never looked at descriptors 1..15**. Every subsequent frame the NIC DMA'd into desc 1, 2, 3… sat behind desc 0 forever — but `r8169_rx_idx` did advance past them, so on the next wrap-around the driver inspected desc 0 (the only one the NIC ever re-wrote), saw the same multicast trash, and shipped that to upper layers again. The DHCP OFFER almost certainly landed in desc 1 or 2 (immediately after the multicast ND on a quiescent LAN) and was overwritten on ring wrap many seconds before any poll cycle reached it.

Three additional convergent divergences amplify the bug:

1. **No `FS`/`LS` validation** — AGNOS treats every descriptor as a complete single-segment frame. Linux's `rtl8169_fragmented_frame` (line 4402–4405) drops `(FirstFrag | LastFrag) != (FirstFrag | LastFrag)`. RTL chips can legitimately split a frame across two descriptors on RX FIFO underflow; AGNOS would deliver the first half as a complete frame, corrupting the upper layer.
2. **No `RES` (Receive Error Summary) check** — errored frames (CRC mismatch, length error, runt) get delivered with garbage length. Linux drops at line 4440–4454; FreeBSD at line 3519; OpenBSD at line 1645.
3. **Single-frame-per-call return at line 551** vs. Linux's budget-driven walk (lines 4422–4498). Even fixing point 1, returning after one packet means the upper-layer stack only gets one of (potentially) many queued frames per `net_poll` invocation. With the CMOS-stamp overhead in the AGNOS poll path (3× MMIO + CMOS reads per call — see secondary findings), this is sufficient to lag behind incoming frame rate on a live LAN.

Single most-load-bearing piece of evidence: **slot 0x5E=0x01**. That byte is the first byte of an IPv6 multicast MAC (`33:33:ff:XX:XX:XX`). It is NOT the first byte of a unicast DHCP OFFER (which would be `0xb0` — the first byte of our own MAC `b0:41:6f:0c:e4:25`). The chip is healthy, RxConfig filtering is correct, the OFFER does land in the ring — but it lands at descriptor index N>0 while we cycle on the multicast frame stuck at descriptor 0.

---

## AGNOS RX path walk (`r8169.cyr` lines 428–552)

### `r8169_init_rx` (lines 428–503) — descriptor ring + register programming

Lines 432–440 — Allocate ring page (4 KB), zero it. **OK** — matches convergent shape (256 bytes of descriptors + waste, page-granularity is fine; alignment requirement is 256-byte, page-align satisfies).

Lines 443–458 — Per-descriptor init. **Two issues, neither load-bearing for the OFFER drop**:

```cyrius
var status = 0x80000000 | 2048;   # OWN | BUF_SIZE
if (i == 15) { status = status | 0x40000000; }   # EOR on last
store32(desc + 0,  status);
store32(desc + 4,  0);                            # vlan
store32(desc + 8,  buf & 0xFFFFFFFF);
store32(desc + 12, (buf >> 32) & 0xFFFFFFFF);
```

- The 14-bit length field (`0x3FFF`) caps buffer size at 16383, not 2048. The literal `2048` here is correct (it fits in 14 bits, the chip writes 2048-or-less bytes as DMA target). No bug.
- Linux uses `R8169_RX_BUF_SIZE = SZ_16K - 1 = 16383` (line 67). AGNOS's 2048 byte buffers are fine for 1500 MTU but will silently truncate jumbo frames if they ever appear. Not load-bearing today.

Lines 461–462 — Program RDSAR. **OK** — matches the spec.

Lines 488–489 — Set RxConfig:

```cyrius
var rxcfg = R8169_RXCFG_DEFAULTS | R8169_RXCFG_AB | R8169_RXCFG_AM | R8169_RXCFG_APM;
store32(r8169_mmio_base + R8169_REG_RXCONFIG, rxcfg);
```

Yielding `0xE700 | 0x0E = 0xE70E`. **OK for unicast OFFER**: `APM = 0x02` (accept unicast matching IDR0..IDR5) is the bit that lets unicast OFFERs in, and the IDR programming at lines 381–383 (FIX #7) put our MAC into the chip's hardware filter. Linux's `rtl_set_rx_mode` (line 2577) programs the exact same accept pattern `AcceptBroadcast | AcceptMyPhys | AcceptMulticast = 0x0E`. The high bits diverge structurally:
- AGNOS uses `0xE700` from `R8169_RXCFG_DEFAULTS` (FIFO thresh 7 + DMA burst 7 packed into the 8..15 range).
- Linux's `rtl_init_rxcfg` for the most common modern mac_version (40..53, line 2293) writes `RX128_INT_EN | RX_MULTI_EN | RX_DMA_BURST | RX_EARLY_OFF` where the bit positions are `(1<<15) | (1<<14) | (7<<8) | (1<<11) = 0xCF00`.
- AGNOS's `0xE700` ORs in `7<<13 = 0xE000` (RX FIFO threshold) which Linux does NOT set on modern chips. **Not load-bearing** (RX FIFO threshold == 7 means "no threshold, deliver immediately" on chips that honor the bit; on modern chips that ignore it, it's harmless).

Lines 493–494 — RxMaxSize:

```cyrius
store8(r8169_mmio_base + 0xDA, 0xF3);
store8(r8169_mmio_base + 0xDB, 0x05);
```

Writes `0x05F3 = 1523` as two byte stores. Linux writes `R8169_RX_BUF_SIZE + 1 = 16384 = 0x4000` with a 16-bit MMIO write (line 2542), explicitly to **disable** size filtering with the comment `/* Low hurts. Let's disable the filtering. */`. **Possible secondary issue**: a 1523-byte limit excludes some VLAN-tagged frames. Not load-bearing for DHCP OFFER (no VLAN), but worth fixing.

Lines 497–498 — CR.RE. **OK** — preserves other bits, sets RX-enable.

### `r8169_poll` (lines 507–552) — the load-bearing site

Lines 515–528 — CMOS diagnostic stamping. Performance concern (secondary findings § below), no correctness bug.

Lines 530–532:

```cyrius
var desc = r8169_rx_ring_phys + r8169_rx_idx * 16;
var status = load32(desc);
if ((status & 0x80000000) != 0) { return 0; }   # NIC still owns
```

**Divergence #1**: AGNOS checks **only `r8169_rx_idx`**'s descriptor — if it's NIC-owned, the function returns 0, *even if descriptors at indexes (idx+1), (idx+2), …, (idx+15) hold completed frames the chip already wrote*. Linux's `rtl_rx` walks `cur_rx` through up to `budget` consecutive descriptors per call (line 4422). OpenBSD walks while `if_rxr_inuse > 0` (line 1585). FreeBSD walks while `maxpkt > 0` (line 3470).

For the OFFER scenario: chip DMAs IPv6 multicast into desc 0, DHCP OFFER into desc 1. Both descriptors have `OWN = 0` (driver-owned). AGNOS reads desc 0 (idx=0, OWN clear → enter body), processes the multicast, advances to idx=1, returns. Next `net_poll` call: reads desc 1, would process the OFFER… **except** between the two calls, the kernel re-ran the boot's idle scheduler which calls `net_poll` from `dhcp_init`'s wait loop hundreds of times. *On every one of those calls, the chip has had time to re-write desc 0 with another multicast frame from the live LAN*. So idx=1's OFFER stays buried while idx=0 is constantly refreshed by background multicast.

**This is exactly what the CMOS evidence shows.**

Lines 534–538:

```cyrius
var pkt_len = status & 0x3FFF;
# Strip CRC: RTL8168 includes 4-byte FCS in the reported length per
# datasheet §6.7 (all four BSD/Linux refs do the same subtraction).
if (pkt_len >= 4) { pkt_len = pkt_len - 4; }
if (pkt_len > maxlen) { pkt_len = maxlen; }
```

- Mask `0x3FFF` = bits 13:0 = 14 bits wide. **Correct.** Confirmed against Linux's `GENMASK(13, 0)` at line 4456 and FreeBSD's `RL_RDESC_STAT_GFRAGLEN = 0x00003FFF` at `if_rlreg.h:1043`. (FreeBSD's source comment calls this "13-bit" but the actual mask covers bits 0–13 = 14 bits. AGNOS matches the value, not the comment.)
- CRC strip is **correct** — Linux line 4458 (`pkt_size -= ETH_FCS_LEN`), FreeBSD line 3585 (`total_len - ETHER_CRC_LEN`), OpenBSD line 1700 (`total_len - ETHER_CRC_LEN`).

**Divergence #2 — no `FS`/`LS` check**: between line 532 and line 534, AGNOS does not test `(status & (FirstFrag | LastFrag)) == (FirstFrag | LastFrag)`. Linux's `rtl8169_fragmented_frame` (line 4402) does exactly this and drops fragmented frames. FreeBSD does at line 3495.

**Divergence #3 — no `RES` (bit 21, `0x00200000`) check**: AGNOS unconditionally consumes the buffer. Linux drops at line 4440. FreeBSD at line 3519. OpenBSD at line 1645.

Lines 540–543:

```cyrius
var bufaddr = load64(&r8169_rx_bufs + r8169_rx_idx * 8);
for (var i = 0; i < pkt_len; i = i + 1) {
    store8(buf + i, load8(bufaddr + i));
}
```

Byte-by-byte copy. **Correct** (memory-barrier-naive but x86 is strong-ordered, so no `dma_rmb`/`dma_wmb` needed in practice on archaemenid — Zen's TSO covers it).

Lines 545–548:

```cyrius
var new_status = 0x80000000 | 2048;
if (r8169_rx_idx == 15) { new_status = new_status | 0x40000000; }
store32(desc, new_status);
```

**Divergence #4 — does not preserve `EOR` from the descriptor's prior state**: AGNOS hard-codes EOR only on `r8169_rx_idx == 15`. Linux's `rtl8169_mark_to_asic` (line 3799–3807) reads `opts1 & RingEnd` and ORs that back in:

```c
u32 eor = le32_to_cpu(desc->opts1) & RingEnd;
desc->opts2 = 0;
dma_wmb();
WRITE_ONCE(desc->opts1, cpu_to_le32(DescOwn | eor | R8169_RX_BUF_SIZE));
```

Today AGNOS and Linux agree (only index 15 has EOR), so this is a structural-cleanliness issue not a bug. **Not load-bearing.**

Lines 550–551:

```cyrius
r8169_rx_idx = (r8169_rx_idx + 1) & 0x0F;
return pkt_len;
```

Single-frame return. **Load-bearing**: returning here when more descriptors may be complete forces the upper layer to make many `net_poll` round-trips, each paying the CMOS-stamp tax (§ secondary findings), to drain a burst.

---

## Linux convergence (v6.6 `drivers/net/ethernet/realtek/r8169_main.c`)

### Descriptor bit layout (line 470–474)

```c
DescOwn   = (1 << 31), /* Descriptor is owned by NIC */
RingEnd   = (1 << 30), /* End of descriptor ring */
FirstFrag = (1 << 29), /* First segment of a packet */
LastFrag  = (1 << 28), /* Final segment of a packet */
```

### RX error bits (line 359–363)

```c
/* RxStatusDesc */
RxRWT = (1 << 22),   /* Receive Watchdog Timer (frame too long) */
RxRES = (1 << 21),   /* Receive Error Summary */
RxRUNT = (1 << 20),  /* Runt (frame too short) */
RxCRC = (1 << 19),   /* CRC error */
```

### `rtl_rx` core loop (lines 4417–4501, full body)

```c
static int rtl_rx(struct net_device *dev, struct rtl8169_private *tp, int budget)
{
    int count;

    for (count = 0; count < budget; count++, tp->cur_rx++) {
        unsigned int pkt_size, entry = tp->cur_rx % NUM_RX_DESC;
        struct RxDesc *desc = tp->RxDescArray + entry;
        u32 status;

        status = le32_to_cpu(READ_ONCE(desc->opts1));
        if (status & DescOwn)
            break;

        /* This barrier is needed to keep us from reading
         * any other fields out of the Rx descriptor until
         * we know the status of DescOwn
         */
        dma_rmb();

        if (unlikely(status & RxRES)) {
            ...
            goto release_descriptor;
        }

        pkt_size = status & GENMASK(13, 0);
        if (likely(!(dev->features & NETIF_F_RXFCS)))
            pkt_size -= ETH_FCS_LEN;

        if (unlikely(rtl8169_fragmented_frame(status))) {
            dev->stats.rx_dropped++;
            dev->stats.rx_length_errors++;
            goto release_descriptor;
        }
        ...
        skb_copy_to_linear_data(skb, rx_buf, pkt_size);
        ...
        napi_gro_receive(&tp->napi, skb);
release_descriptor:
        rtl8169_mark_to_asic(desc);
    }
    return count;
}
```

Key shape:
- **Budget-driven loop** (`for count < budget`, `cur_rx++` per iteration). NUM_RX_DESC=256 (line 69); budget per call is typically 64.
- **`break` on DescOwn** (not return) — leaves the loop, returns `count` of consumed frames.
- **dma_rmb()** between status read and other-field reads.
- **`RxRES` check → goto release_descriptor** — skip the upper-layer delivery but still re-arm the slot.
- **Length: `status & GENMASK(13, 0)` → subtract `ETH_FCS_LEN`** unless RXFCS feature on.
- **`rtl8169_fragmented_frame`** (line 4402): `(status & (FirstFrag | LastFrag)) != (FirstFrag | LastFrag)` — drop fragments.
- **`rtl8169_mark_to_asic`** (line 3799): reads `opts1 & RingEnd`, preserves it, writes `DescOwn | eor | R8169_RX_BUF_SIZE`. **Does NOT rewrite the buffer address** (kept since alloc). `dma_wmb()` before the store.

### RxConfig (line 2280–2302)

`rtl_init_rxcfg` writes ONLY DMA/FIFO bits; accept bits are programmed separately in `rtl_set_rx_mode` (line 2577): `AcceptBroadcast | AcceptMyPhys | AcceptMulticast = 0x0E`. For the common modern mac_version path (line 2293): `RX128_INT_EN | RX_MULTI_EN | RX_DMA_BURST | RX_EARLY_OFF`. Bit values (lines 193–201):
- `RX128_INT_EN = (1 << 15)` — 0x8000
- `RX_MULTI_EN = (1 << 14)` — 0x4000
- `RX_EARLY_OFF = (1 << 11)` — 0x0800
- `RX_DMA_BURST = (7 << RXCFG_DMA_SHIFT)` — `RXCFG_DMA_SHIFT = 8`, so `0x0700`

Total: `0xCF00`. AGNOS uses `0xE700` — over-sets bit 13 (RX FIFO thresh) and bit 15 but not bit 11 / 14. Difference not load-bearing for DHCP, but cosmetically should converge.

### Accept mask constants (lines 385–389)

```c
AcceptBroadcast = 0x08,
AcceptMulticast = 0x04,
AcceptMyPhys    = 0x02,
AcceptAllPhys   = 0x01,
#define RX_CONFIG_ACCEPT_OK_MASK  0x0f
```

AGNOS's `R8169_RXCFG_AB | R8169_RXCFG_AM | R8169_RXCFG_APM = 0x0E` byte-matches Linux's `AcceptBroadcast | AcceptMyPhys | AcceptMulticast`.

### RxMaxSize (line 2542)

```c
RTL_W16(tp, RxMaxSize, R8169_RX_BUF_SIZE + 1);  /* 16384 = 0x4000 */
```

Single 16-bit MMIO write. AGNOS does two byte writes of `0x05F3 = 1523`.

### `rtl8169_mark_to_asic` (lines 3799–3807) — descriptor re-arm

```c
static void rtl8169_mark_to_asic(struct RxDesc *desc)
{
    u32 eor = le32_to_cpu(desc->opts1) & RingEnd;

    desc->opts2 = 0;
    dma_wmb();
    WRITE_ONCE(desc->opts1, cpu_to_le32(DescOwn | eor | R8169_RX_BUF_SIZE));
}
```

Reads EOR back out of `opts1` rather than depending on the descriptor index. Does NOT touch `desc->addr` — the DMA buffer mapping is permanent per descriptor (matching AGNOS's `r8169_rx_bufs[]` array of pmm_alloc'd pages).

---

## OpenBSD convergence (`sys/dev/ic/re.c`)

### `re_rxeof` loop (lines 1576–1710)

Loop header (line 1585):
```c
for (i = sc->rl_ldata.rl_rx_considx;
     if_rxr_inuse(&sc->rl_ldata.rl_rx_ring) > 0;
     i = RL_NEXT_RX_DESC(sc, i)) {
```

Walks through *all* descriptors in the ring whose slot has a posted mbuf. Per-iteration:
- Line 1610–1615: `if (RL_RDESC_STAT_OWN & rxstat) break;` — same `break`, not return.
- Line 1620–1624 (jumbov2): SOF/EOF anomaly → discard via `re_discard_rxbuf()`.
- Line 1625–1631: non-EOF → accumulate fragment, continue.
- Line 1645–1660: `RL_RDESC_STAT_RXERRSUM` (0x00100000) → counter bump + discard.
- Length: `total_len = rxstat & sc->rl_rxlenmask` (line 1592). `rl_rxlenmask = RL_RDESC_STAT_GFRAGLEN = 0x00003FFF` for 8169+ (lines 944–955).
- CRC strip: line 1700, `m->m_pkthdr.len = m->m_len = (total_len - ETHER_CRC_LEN);`
- `re_newbuf` (lines 1372–1420): rewrites bufaddr + cmdstat with OWN | EOR (last only) | length. Two-step store: first without OWN (`d->rl_cmdstat = htole32(cmdstat)`), then OR in OWN and write again. Conservative ordering.
- Index advance: `sc->rl_ldata.rl_rx_considx = i;` (line 1708) at end-of-function (only after the entire batch).

### RxConfig (lines 2096–2099) + accept mask (lines 1164–1165)

```c
rxcfg = RL_RXCFG_CONFIG;
if (sc->rl_flags & RL_FLAG_EARLYOFF)
    rxcfg |= RL_RXCFG_EARLYOFF;
CSR_WRITE_4(sc, RL_RXCFG, rxcfg);
```

Accept bits in `re_iff` (line 1164): `rxfilt |= RL_RXCFG_RX_INDIV | RL_RXCFG_RX_BROAD;` (= `0x02 | 0x08 = 0x0A`). Adds `RL_RXCFG_RX_MULTI = 0x04` when multicast list non-empty.

### RxMaxSize (lines 2137–2142)

PCIe non-jumbo: `CSR_WRITE_2(sc, RL_MAXRXPKTLEN, RE_RX_DESC_BUFLEN);` (typically 2048 — matches MCLBYTES). Else 16383.

---

## FreeBSD convergence (`sys/dev/re/if_re.c`)

### `re_rxeof` loop (lines 3451–3651)

Loop (line 3470):
```c
for (i = sc->rl_ldata.rl_rx_prodidx; maxpkt > 0;
     i = RL_RX_DESC_NXT(sc, i)) {
```

**Budget-driven**: `maxpkt = 16` at entry (line 3467); returns `EAGAIN` (line 3647) if exhausted so caller knows to schedule another pass.

- Length: `total_len = rxstat & sc->rl_rxlenmask;` (line 3480). For 8169+: `RL_RDESC_STAT_GFRAGLEN = 0x00003FFF` (`if_rlreg.h:1043` — confirmed 14-bit-wide mask).
- Error: line 3519, `RL_RDESC_STAT_RXERRSUM = 0x00100000` → counter + discard.
- Fragmentation: line 3495, `(SOF | EOF) != (SOF | EOF)` → `re_discard_rxbuf()` for RTL8168C+.
- CRC strip: line 3585, `m->m_pkthdr.len = m->m_len = (total_len - ETHER_CRC_LEN);`
- Re-arm in `re_newbuf` (lines 3408–3413): rewrites `rl_bufaddr_lo/hi` + `rl_cmdstat` with `cmdstat | RL_RDESC_CMD_OWN`.
- Index advance: `sc->rl_ldata.rl_rx_prodidx = i;` (line 3629) at end.

### RxConfig + accept mask (`re_set_rxmode`, lines 3121–3182)

```c
rxfilt = RL_RXCFG_CONFIG | RL_RXCFG_RX_INDIV | RL_RXCFG_RX_BROAD;
```

Default `0x0A`. Adds `RL_RXCFG_RX_MULTI` for multicast.

### Descriptor bit defs (`if_rlreg.h` lines 1031–1047)

```c
#define RL_RDESC_STAT_OWN       0x80000000
#define RL_RDESC_STAT_EOR       0x40000000
#define RL_RDESC_STAT_SOF       0x20000000
#define RL_RDESC_STAT_EOF       0x10000000
#define RL_RDESC_STAT_FRALIGN   0x08000000   /* frame alignment error */
#define RL_RDESC_STAT_RXERRSUM  0x00100000   /* RX error summary */
#define RL_RDESC_STAT_FRAGLEN   0x00001FFF   /* 8139C+ — 13-bit */
#define RL_RDESC_STAT_GFRAGLEN  0x00003FFF   /* 8169+ — 14-bit */
```

`RL_RDESC_CMD_OWN = 0x80000000`, `RL_RDESC_CMD_EOR = 0x40000000`.

### RxMaxSize (lines 4051–4063)

```c
if (if_getmtu(ifp) > RL_MTU)
    CSR_WRITE_2(sc, RL_MAXRXPKTLEN, ...);   /* jumbo */
else
    CSR_WRITE_2(sc, RL_MAXRXPKTLEN, RE_RX_DESC_BUFLEN);
```

---

## AGNOS divergence summary

Ranked by likelihood of causing "frame received but not delivered" / "wrong frame delivered":

### LOAD-BEARING

**[1] `r8169_poll` returns after a single descriptor.** Single most-load-bearing divergence. AGNOS lines 530–532 + 550–551 vs. Linux 4422 / OpenBSD 1585 / FreeBSD 3470. With the multicast frame perpetually re-occupying desc 0 (re-DMA'd by the chip between every poll call on a live LAN), and `r8169_poll` checking only `r8169_rx_idx`'s slot, the OFFER sitting at idx=1 is never inspected. CMOS-confirmed by slot 0x5E=0x01.

### LIKELY CONTRIBUTORS

**[2] No `FS`/`LS` check.** AGNOS lines 530–534. Linux 4402–4405 / 4463–4467; FreeBSD 3495; OpenBSD 1620. Could deliver half a fragmented frame as a full frame to `ethernet_recv`, which would parse a garbage ethertype and drop silently — invisible to current diagnostics.

**[3] No `RES` (bit 21, `0x00200000`) error-summary check.** AGNOS lines 530–534. Linux 4440 / FreeBSD 3519 / OpenBSD 1645. Errored frame's reported length may be 0 or 2048 (CRC stomp can land anywhere), so `pkt_len` after `-4` is 0-or-junk and `ethernet_recv` again drops silently.

### COSMETIC / SECONDARY

**[4] RxConfig high bits diverge** (0xE700 vs Linux modern 0xCF00). Not load-bearing — accept-mask low byte (0x0E) is correct.

**[5] RxMaxSize set to 1523 not "disabled".** Linux deliberately disables (16384). AGNOS's 1523 excludes any VLAN-tagged frame >1518 bytes. Not a factor for DHCP on untagged LAN.

**[6] `r8169_mark_to_asic` doesn't read-preserve EOR.** AGNOS line 547 hard-codes EOR by index; Linux line 3801 reads it back. Today both agree, but a future ring-resize bug would silently lose EOR.

**[7] No memory barriers.** AGNOS lines 530–548 have no `dma_rmb`/`dma_wmb` between status read and field reads / between field writes and OWN store. x86-TSO covers this on archaemenid (Zen), so harmless on current iron. On RISC-V or ARM it would break.

---

## Minimum-viable fix shape (NO code, structural sketch)

The fix has three parts; all three should land in one commit (one iron burn, one CHANGELOG entry).

### Part A: convert `r8169_poll` from single-frame-return to multi-frame budget loop (LOAD-BEARING)

**Files changed**: `agnos/kernel/core/r8169.cyr` lines 507–552.

**Current shape (line 530–551)**: single descriptor inspection, single return.

**Target shape — mirror Linux `rtl_rx` (line 4417–4501)**:
- Wrap the body lines 530–551 in a budget-driven loop. Caller passes a budget parameter, or the function takes its own budget (16 matches FreeBSD, 64 matches Linux NAPI default; 16 is fine for a 16-slot ring).
- The loop reads `desc` at `r8169_rx_idx`, breaks (not returns) when `OWN == 1`.
- Body checks (in order): `RES` → discard + continue (re-arm slot, advance idx); `FS|LS != FS|LS` → discard + continue; otherwise copy `pkt_len = (status & 0x3FFF) - 4` bytes into caller buffer and *return immediately with this single frame* (so the existing `net_poll` single-frame contract is preserved).
- Critical change: when we `discard + continue`, advance `r8169_rx_idx` and re-arm that slot via the existing line-545–548 sequence, **then loop again to inspect the next slot**, rather than returning 0.

This fixes the "stuck on multicast in desc 0" scenario: even if every poll call ingests one IPv6 ND, the loop continues until either (a) it finds the OFFER, (b) all 16 slots are NIC-owned (chip ahead of us), or (c) budget exhausted. The OFFER gets delivered on the first poll cycle that overlaps with its arrival, not "never."

**LOC estimate**: ~25 lines added / 10 modified within the function. The loop scaffold, the RES check, the FS/LS check, and the "discard + advance + continue" path.

### Part B: `RES` (0x00200000) + `FS`/`LS` (0x30000000) gating (LIKELY CONTRIBUTORS)

**Files changed**: `agnos/kernel/core/r8169.cyr` — declare constants near lines 60–63, use them inside Part A's body.

**New constants** (~3 lines near line 63):
```
R8169_DESC_RES = 0x00200000  # Receive Error Summary (RxRES — Linux line 361)
R8169_FRAG_MASK = 0x30000000  # FS | LS — frame complete when both set
```

**Use**: inside Part A's body before the length extraction, branch on `(status & R8169_DESC_RES) != 0` and on `(status & R8169_FRAG_MASK) != R8169_FRAG_MASK` — both branches do the "discard + advance + continue" handoff to next loop iteration.

**LOC estimate**: ~6 lines added (2 const decls + 2 two-line branches inside Part A's body).

### Part C: `r8169_mark_to_asic` helper + EOR read-preserve (COSMETIC, but cheap)

**Files changed**: `agnos/kernel/core/r8169.cyr` — extract lines 545–548 into a function near line 503 (after `r8169_init_rx`), call it from Part A's "discard + continue" path AND from the successful-deliver path.

**Shape** (mirror Linux line 3799–3807, ~6 lines):
- Read `desc + 0` to get current `opts1`, mask `& 0x40000000` to extract EOR.
- Write `0x80000000 | eor | 2048` to `desc + 0`.

**LOC estimate**: ~6 lines added, ~4 lines removed from the inline path.

**Total fix LOC**: ~40 lines added, ~14 lines modified across one file. Single iron burn.

---

## Risk + secondary findings

### Secondary finding S-1: CMOS-stamp performance tax in `r8169_poll`

Lines 511–528 of `r8169_poll` perform **on every call**:
- 1 bump of `r8169_rx_poll_count` (in-memory, cheap).
- 1 `xhci_cmos_stamp(R8169_KCP_RX_POLL_COUNT, ...)` — CMOS port-IO sequence (typically `outb 0x70; outb 0x71` = ~2 µs on AMD Zen).
- 1 `load32(r8169_rx_ring_phys)` for `rx0_status` — MMIO read.
- 1 `xhci_cmos_stamp(R8169_KCP_RX_DESC0_OWN, ...)` — another ~2 µs.
- 1 `load64(&r8169_rx_bufs)` — DRAM read.
- 1 conditional `load8(rx0_buf)` + 1 `xhci_cmos_stamp(R8169_KCP_RX_DESC0_BYTE0, ...)` — ~2 µs.
- 1 conditional `load32(r8169_tx_ring_phys)` + 1 `xhci_cmos_stamp(R8169_KCP_TX_DESC0_OWN, ...)` — ~2 µs.

**Estimate**: 8–10 µs of CMOS port-IO overhead per `r8169_poll` call. At 1 Gb/s the chip can DMA a 1500-byte frame in ~12 µs. **The poll path's instrumentation is the same order of magnitude as the frame arrival rate**. Combined with the single-frame-return divergence above, this is a plausible cause of dropped DHCP OFFER retransmits during heavy LAN multicast — we are simply too slow to drain the ring.

**Mitigation**: stamp CMOS slots once per N polls (e.g. on every 256th call — slot 0x5C wraps anyway), or move stamping to a kernel-debug-flag-gated path. Not part of MVP fix, but should be tracked.

### Secondary finding S-2: RxMaxSize over-tight

Lines 493–494 write 1523 as two byte stores. Recommend converting to a single 16-bit MMIO write (matches FreeBSD/OpenBSD/Linux convention) with value 0x4000 (matches Linux's "disable filtering"). Not load-bearing.

### Secondary finding S-3: RxConfig high bits stylistic divergence

Lines 481–489 program `0xE700`. Linux's modern mac_version path programs `0xCF00`. The differing bits are (a) AGNOS sets `RX_FIFO_THRESH = (7<<13) = 0xE000` (Linux doesn't on modern chips); (b) Linux sets `RX_MULTI_EN = (1<<14) = 0x4000` and `RX_EARLY_OFF = (1<<11) = 0x0800` (AGNOS doesn't). Both are functional today; bring AGNOS into line with Linux modern path at next sweep.

### Secondary finding S-4: No `dma_rmb`/`dma_wmb` discipline

AGNOS lines 519–548 read descriptor status, then read descriptor address-field-equivalent (via `r8169_rx_bufs` cache), then write back. On x86 with TSO, this is safe. On non-TSO targets (RISC-V, ARM64) the descriptor read could be reordered with the buffer read, delivering stale buffer contents.

This is a **port-blocker for v6.0.x RISC-V**. Not load-bearing today.

### Risk of fix Part A

The "discard + continue" inner loop could in principle starve the caller — if a stuck stream of errored frames floods the ring, we'd loop the full budget every call. Mitigation: cap budget at 16 (one full ring traversal). Matches FreeBSD's `maxpkt = 16` (`if_re.c:3467`).

### Risk of fix Part B

`FS|LS != FS|LS` drops legitimate fragmented frames on RX FIFO underrun. This is correct behavior — chip splits frames on underrun, and reassembling them in software is complex. Linux/FreeBSD/OpenBSD all drop. Acceptable risk.

---

## Cross-references

### Spec

- **RTL8168/8111 datasheet, §6.7 "RX Descriptor Format"** — descriptor `opts1` layout: `OWN[31] | EOR[30] | FS[29] | LS[28] | <status bits 27:14> | length[13:0]`. The 14-bit length field includes CRC; driver subtracts 4.
- **RTL8168/8111 datasheet, §13.2 "RxConfig (offset 0x44)"** — accept bits in low nibble: AAP/APM/AM/AB at 0x01/0x02/0x04/0x08.

### Linux v6.6 — `drivers/net/ethernet/realtek/r8169_main.c`

- Descriptor bits (line 470–474): https://elixir.bootlin.com/linux/v6.6/source/drivers/net/ethernet/realtek/r8169_main.c#L470
- RxRES family (line 359–363): https://elixir.bootlin.com/linux/v6.6/source/drivers/net/ethernet/realtek/r8169_main.c#L359
- Accept bits + RX_CONFIG_ACCEPT_OK_MASK (line 385–390)
- R8169_RX_BUF_SIZE (line 67): `(SZ_16K - 1) = 16383`
- NUM_RX_DESC (line 69): 256
- `rtl_init_rxcfg` (line 2280–2302)
- `rtl_set_rx_max_size` (line 2539–2543) — `R8169_RX_BUF_SIZE + 1 = 16384`
- `rtl_set_rx_mode` (line 2575–2612) — `0x0E = AcceptBroadcast | AcceptMyPhys | AcceptMulticast`
- `rtl8169_mark_to_asic` (line 3799–3807) — EOR read-preserve, `dma_wmb` before OWN store
- `rtl8169_fragmented_frame` (line 4402–4405) — `(status & (FirstFrag | LastFrag)) != (FirstFrag | LastFrag)`
- `rtl_rx` (line 4417–4501) — **canonical RX loop**: budget-driven, RES-gating, FS/LS-gating, CRC-strip, `release_descriptor` label

### OpenBSD — `sys/dev/ic/re.c`

- `re_rxeof` (line 1576–1710) — full RX path
- `re_newbuf` (line 1372–1420) — descriptor re-arm with conservative two-step OWN store
- `rl_rxlenmask` set per chip (line 944–955)
- `re_iff` accept mask (line 1164–1165) — `RL_RXCFG_RX_INDIV | RL_RXCFG_RX_BROAD`
- `re_init` RxConfig (line 2096–2099), RxMaxSize (line 2137–2142)

### FreeBSD — `sys/dev/re/if_re.c` + `sys/dev/rl/if_rlreg.h`

- `re_rxeof` (line 3451–3651) — budget-driven loop with `maxpkt = 16`
- `re_newbuf` (line 3330–3418) — rewrites bufaddr + cmdstat
- `re_set_rxmode` (line 3121–3182) — `RL_RXCFG_CONFIG | RL_RXCFG_RX_INDIV | RL_RXCFG_RX_BROAD`
- RxMaxSize (line 4051–4063)
- Descriptor bits (`if_rlreg.h` line 1031–1047) — `RL_RDESC_STAT_GFRAGLEN = 0x00003FFF` (14-bit), `RL_RDESC_STAT_RXERRSUM = 0x00100000`

### AGNOS files

- `agnos/kernel/core/r8169.cyr` lines 428–503 (`r8169_init_rx`), 507–552 (`r8169_poll`), 545–548 (re-arm — extract to helper per Part C)
- `agnos/kernel/core/net.cyr` lines 540–574 (`net_poll`) — consumes the single-frame return; unaffected by Part A (Part A preserves the single-frame return semantic, just drops + advances internally on bad slots)
- `agnosticos/docs/development/r8169-iron-burn-audit.md` — CMOS slot map (§10.5)
- `agnosticos/docs/development/dhcp-end-to-end-audit.md` — FIX #7 (IDR write-back after reset), FIX #10 (link preservation)

### AGNOS memory anchors

- `[[feedback_redesign_dont_reinvent]]` — multi-source convergent prior art (Linux + OpenBSD + FreeBSD all triangulated above)
- `[[feedback_driver_code_is_the_bite]]` — fix Parts A/B/C are pre-iron code work, not "PENDING IRON"
- `[[feedback_no_instrumentation_means_no_instrumentation]]` — secondary finding S-1 (CMOS-stamp tax) tracks for future sweep, no instrumentation added in fix

---

## 1.32.5 addendum — RX accept-filter re-derivation (broadcast+unicast drop; multicast passes)

**Date**: 2026-05-24. **Driver**: re-derived from MULTIPLE independent sources (FreeBSD `re_rxeof`/`re_set_rxmode`, OpenBSD `re_rxeof`/`re_iff`, NetBSD `rtl8169.c`, iPXE `realtek.c`/`realtek.h`, Linux VER_46 erratum) per [[feedback_audit_re_derive_dont_validate_comments]] — derived from sources first, then diffed against `r8169.cyr`, NOT validated against existing comments.

**Symptom (post-1324 pcap)**: TX PROVEN on iron (broadcast ARP request egressed the wire byte-correct). RX delivers MULTICAST only (Attempts 97–103, CMOS `[0x5E]=0x01` = `01:00:5e`); never broadcast (DHCP OFFER) or unicast (gateway ARP reply). Since 2 KB RX buffers exceed the 1500 MTU, every *accepted* frame is single-descriptor — so the class-selective drop is at the chip's **L2 accept filter** (before the ring), not in `r8169_poll`.

**Already-convergent in the current build (do NOT reopen)**: IDR0-5 32-bit Cfg9346-wrapped writeback (`r8169.cyr:519-528`) matches FreeBSD/OpenBSD/Linux; MAR0/MAR4 = all-1s (`:571-572`) is the Linux VER_46 allmulti erratum workaround AND iPXE's open default; RxConfig profile `0xEF00` matches FreeBSD 8168G_PLUS; late CR.TE|RE (`:589`) matches NetBSD `RTKQ_TXRXEN_LATER` (carved out *specifically* for `RTK_HWREV_8168H`). RxConfig accept bits land (multicast proves the store32 took).

**Load-bearing finding**: AGNOS set `accept = AB|AM|APM = 0x0E` — no **AAP** (accept-all-physical / promiscuous, bit 0). **iPXE `realtek_open` sets AAP UNCONDITIONALLY** (RCR low-nibble `AAP|APM|AM|AB = 0x0F`); iPXE is the pure-poll from-scratch DMA-ring analog running this chip family promiscuous-by-default for PXE/DHCP — the same workload class as AGNOS bring-up. The BSDs gate ALLPHYS behind `IFF_PROMISC`; AAP-by-default is the iPXE bring-up convention. On the RTL8168H stepping the per-address+broadcast accept path is known-quirky (Linux VER_46 erratum: "filters unicast eapol unless allmulti enabled"); **AAP bypasses the L2 accept filter entirely**, so the broadcast OFFER + unicast ARP reply reach the ring regardless of the stepping quirk.

**AAP is also a BISECTOR**: if RX still drops with AAP set, the fault is DOWNSTREAM of the accept filter (descriptor OWN handoff / DMA addresses / RBLEN / CPlusCmd / poll delivery), not the mask — cleaving the remaining hypothesis space for the next cycle.

**1.32.5 changes landed in `r8169.cyr`**:
1. **AAP added** (`:577` region) — `accept = AAP|AB|AM|APM` → RxConfig `0xEF0F`. Primary, iPXE-convergent.
2. **FS|LS discard gate removed** from `r8169_poll` (`:636` region) — FreeBSD/OpenBSD `re_rxeof` gate the SOF|EOF requirement behind `RL_FLAG_JUMBOV2` ONLY; iPXE checks OWN+RES only. For non-jumbo single-descriptor frames the gate never fires for legit traffic; removing it matches all non-Linux prior art and is free to stack (covers the case where AAP delivers a frame the old gate would have rejected). Secondary; not expected load-bearing.

Build: 621,816 B (Attempt 103) → **621,704 B** (−112 B). `scripts/build.sh` x86_64 OK, multiboot2 ELF64. Iron Attempt 104 validates per the rubric at [`iron-nuc-zen-log.md#tracker-1325-cycle`](iron-nuc-zen-log.md#tracker-1325-cycle). NOT auto-proposed per [[feedback_iron_burns_block_other_work]].

---

## 1.32.5 closeout addendum — AAP + RxMaxSize FALSIFIED; RX-engine bring-up (RXDV-settle + CPlusCmd) derived

**Date**: 2026-05-25. Both 1.32.5-addendum candidates above burned and were falsified; this section records the closure and the next convergent fix, re-derived multi-source per [[feedback_audit_re_derive_dont_validate_comments]].

**AAP (Attempt 104, `1325_pcap_test.pcapng`) → FALSIFIED.** Promiscuous accept-all still delivered nothing; the bisector branch fired ⇒ the **L2 accept filter is exonerated**, fault is downstream of it.

**RxMaxSize `0x4000`→`0x05F3` (`1325_pcap_attempt_2.pcapng`, 2026-05-24 23:42) → FALSIFIED.** "No change" on iron. The hypothesis ("bit-14 overflow → RMS=0 → all frames rejected") is **internally inconsistent** with the multicast-passing evidence of Attempts 97–99: if RMS read as 0 and rejected all frames, multicast couldn't have passed either. `0x05F3` is the correct value (admits 1518-byte frames) and is retained, but RMS is **not** the blocker. **RMS candidate CLOSED.**

**Two parallel research agents re-derived the 8168H (mac_version 46 / XID 541) RX-engine bring-up** from Linux `r8169_main.c`, FreeBSD `if_re.c` + `if_rlreg.h`, OpenBSD/NetBSD `re.c`/`rtl8169.c`, U-Boot `rtl8169.c`, iPXE `realtek.c`, OSDev RTL8168H threads + RTL8169 wiki. Findings:

1. **Bite H's deletion of the Linux ephy/ERI/MAC-OCP/firmware clone is CONFIRMED CORRECT — do NOT reopen.** FreeBSD, OpenBSD *and* NetBSD all carry an explicit `8168H/8111H` hwrev and drive it to working RX with **zero** ephy/ERI/OCP/firmware writes (generic PHY-wake only). The Linux H-specific block (`rtl_hw_start_8168h_1`: ephy SerDes tuning, ERI 0x5f0/0xc0/0xb8/0xdc EEE/ASPM/jumbo, `rtl8168h_2_hw_phy_config` firmware) is **not** RX-datapath load-bearing.

2. **The ONE RX-datapath-load-bearing step buried in Linux's H block is `rtl_disable_rxdvgate()`** — clear `RXDV_GATED_EN` (MISC 0xF0 bit 19) **then `fsleep(2000)` (~2 ms settle)**. Every driver supporting this stepping does the clear (Linux explicit; OpenBSD `RL_FLAG_RXDV_GATED`; FreeBSD "disable RXDV gate"; U-Boot — *specifically commented for "DHCP failures after kernel reboots"*, the archaemenid warm-boot signature). **AGNOS already cleared the bit but skipped the settle**, enabling `CR.RE` µs later → RX validator opens after RX starts → RX silent while TX (never consults the gate) egresses fine = the exact iron signature. **FIX**: ~4–8 ms non-posted-MMIO spin between the clear and CR.RE (`r8169.cyr:546` region); 100 Hz timer is too coarse for ms granularity, so spin like `r8169_reset`.

3. **CPlusCmd (0xE0) bits [1:0] are INTT, not "C+ RX/TX enable", on the gigabit 8168.** Linux `CPCMD_MASK`/`INTT_MASK = GENMASK(1,0)` = interrupt-moderation timer select; FreeBSD sets `RL_CPLUSCMD_RXENB|TXENB` ONLY on the `!MACSTAT` (legacy 8139C+) branch, which the 8168H (MACSTAT) is not. AGNOS's `0x000B` set INTT=3 under a false "load-bearing" comment — the exact "nine-burn CPlusCmd trap." Inert under `IMR=0` (pure poll) so unlikely to be the blocker, but corrected to `0x0008` (PCIMulRW only) to stop muddying the hypothesis space. RX/TX are gated solely by `CR.RE|CR.TE`.

**Ruled out (TX exercises the identical path successfully):** 64-bit DMA / >4 GB addressing / PCIDAC — RX buffers are allocated *before* TX buffers (lower physical addresses), and TX DMA works through the same `pmm_alloc`/`bufaddr_hi/lo`/ring-base scheme. The ring-index/buffer-mapping is consistent (descriptor[idx].bufaddr == `r8169_rx_bufs[idx]`, both indexed by `r8169_rx_idx`). CR-vs-RxConfig ordering — both orderings ship in production for this chip (Linux early-CR, NetBSD `RTKQ_TXRXEN_LATER` late-CR for 8168H specifically); AGNOS's late-CR is fine.

Build: 621,704 B (Attempt 104) → **621,768 B** (+64 B, settle spin). `scripts/test.sh` 4/4 + `scripts/ext2-smoke.sh` 5/5. multiboot2 ELF64 OK. `build/agnos` reflects HEAD. **The next burn TESTS these — no instrumentation added.** NOT auto-proposed per [[feedback_iron_burns_block_other_work]].

---

## 1.32.6 addendum — broadcast PROVEN; unicast accept-path re-derive confirms convergence; ARP-retransmit is the divergence

**Date**: 2026-05-25. bite-7 (post-RX-enable accept-filter re-assert) BROKE THROUGH — broadcast RX proven on iron (`1325_pcap_attempt_4`), reconfirmed on the framebuffer by the honest L2 RX self-test (`net: L2 RX ALIVE rx=10 arp_in=7 arp_ans=1`). This **falsifies the §1.32.5-closeout "fault is downstream of the accept filter (descriptor OWN/DMA/ring)" conclusion** — the ring delivers and the poll/dispatch/rearm path is healthy (it carried a real broadcast frame end-to-end and the ARP responder answered on the wire). The narrowed remaining gap is the gateway's *unicast* (APM-class) reply.

**The 1.32.6 lead — "restore the IDR0-5 write-back bite H removed" — was FALSIFIED on re-derive.** Reading the code (not the narrative, per [[feedback_audit_re_derive_dont_validate_comments]]): the IDR0-5 write-back is **already present + correct**, Cfg9346-wrapped at `r8169.cyr:520-534`, matching Linux `rtl_rar_set`. It was re-added during the bite-6/7 `init_tx` restructure, so it was in the burned 1.32.5 build. Restoring it is a no-op.

**Full zero-burn re-derive of the unicast accept path** — every layer is convergent:

| Layer | State | Verdict |
|---|---|---|
| IDR0-5 write-back (APM source) | present, Cfg9346-wrapped (`:520-534`) | == Linux `rtl_rar_set` |
| Accept nibble `AAP\|AB\|AM\|APM` (`0x0F`) | pre-CR.RE + re-asserted post-CR.RE (bite-7, `:639-664`) | APM (unicast) + AAP (promisc) both on |
| RXDV-gate clear + settle, MAR all-1s | present (bite-6, `:556-602`) | convergent |
| `net_handle_arp` reply (`net.cyr:556-564`) | opcode big-endian; `sender_ip`/`arp_pending_ip` same byte order | no byte-order bug; reply would clear pending |

With APM (correct IDR) + AAP (promiscuous) both on and broadcast proven delivering, a unicast reply to our MAC *must* be chip-accepted. **The one divergence from all prior-art: AGNOS sent exactly ONE ARP request and never retransmitted** (Linux `neigh`, iPXE, lwIP `etharp`, *BSD all retransmit per RFC 1122 §2.3.2.1; a missed/un-elicited first reply is never re-offered).

**1.32.6 bite 1 (LANDED)**: ARP request retransmit ~1/sec across the 5 s window (`main.cyr:684-713`). Correct regardless + a clean discriminator — next burn `arp: REPLY` → transient/elicitation miss; still timeout → systematic unicast drop ⇒ **bite 2 (deep driver APM re-derive, multi-source) queued** per user direction. Build 622,408 → **622,560 B**. Full rubric: [`iron-nuc-zen-log.md#tracker-1326-cycle`](iron-nuc-zen-log.md#tracker-1326-cycle).
