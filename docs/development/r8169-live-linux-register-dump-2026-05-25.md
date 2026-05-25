---
name: r8169 live Linux register dump (working unicast RX) — ground truth
description: ethtool -d enp1s0 dump of the WORKING Linux r8169 on archaemenid's exact chip (RTL8168h/VER_46, XID 541), decoded + diffed vs AGNOS's r8169.cyr writes. Captured during the 1.32.6 unicast-RX isolate.
type: reference
---

# r8169 Live Linux Register Dump — Working Unicast-RX Ground Truth

**Captured** 2026-05-25 via `sudo ethtool -d enp1s0` on archaemenid, while Linux's
r8169 had **fully-working unicast RX** on the exact chip AGNOS targets
(`RTL8168h/8111h`, `RTL_GIGA_MAC_VER_46`, XID 541, MAC `b0:41:6f:0c:e4:25`).
ethtool header line: `Unknown RealTek chip (TxConfig: 0x57100f80)`.

This is the **ground truth** for the 1.32.6 unicast-RX isolate: Linux receives
every unicast frame on this chip; AGNOS does not. The working register state is
therefore the reference to match. Zero-burn, no VFIO (NIC stayed bound to Linux).

## Raw dump

```
Offset          Values
------          ------
0x0000:         b0 41 6f 0c e4 25 00 00 40 08 40 02 82 00 c1 00
0x0010:         00 f0 df fe 00 00 00 00 07 08 06 00 00 00 00 00
0x0020:         00 e0 df fe 00 00 00 00 00 00 00 00 00 00 00 00
0x0030:         00 00 00 00 00 00 00 0c 00 00 00 00 2f 00 00 00
0x0040:         80 0f 10 57 0e cf 02 00 00 c4 b9 79 00 00 00 00
0x0050:         10 00 cf bc 60 11 03 01 11 11 11 00 00 00 00 00
0x0060:         00 00 00 00 ec 10 23 01 2c f0 00 80 93 00 80 70
0x0070:         00 6f 01 c4 b0 f1 00 00 07 00 00 00 00 00 20 00
0x0080:         8b 06 01 00 00 00 00 00 00 00 00 00 00 00 00 00
0x00b0:         00 08 00 00 00 00 01 00 00 00 e9 d2 00 00 00 00
0x00d0:         21 00 00 32 0e 00 00 00 00 00 00 40 e7 aa 7d 00
0x00e0:         61 20 00 00 00 d0 df fe 00 00 00 00 27 00 00 00
0x00f0:         3f 00 00 00 00 00 00 00 03 00 00 00 00 00 00 00
```
(rows that are all-zero omitted)

## Decoded load-bearing registers (little-endian)

| Reg | Offset | Width | **Linux (working)** | AGNOS writes | Match? |
|-----|--------|-------|---------------------|--------------|--------|
| IDR0–5 (MAC) | 0x00 | 6 B | `b0:41:6f:0c:e4:25` | same (EEPROM) | ✅ |
| MAR (mcast hash) | 0x08 | 8 B | `40 08 40 02 82 00 c1 00` (computed hash) | `FF…FF` (all-1s) | ⚠ differs |
| ChipCmd (CR) | 0x37 | 1 B | `0x0C` (TE\|RE) | `0x0C` after CR.RE | ✅ |
| IMR | 0x3C | 2 B | `0x002F` (IRQs on) | `0x0000` (poll) | ⚠ by design |
| TxConfig | 0x40 | 4 B | `0x57100F80` | — | (ethtool header confirms offset map) |
| **RxConfig (RCR)** | **0x44** | **4 B** | **`0x0002CF0E`** | **`0x0000EF0F`** | ❌ **bit 17 + profile + AAP** |
| Cfg9346 (9346CR) | 0x50 | 1 B | `0x10` | lock/unlock dance | — |
| Config2 | 0x53 | 1 B | `0xBC` | — | — |
| **CPlusCmd** | **0xE0** | **2 B** | **`0x2061`** | **`0x0008`** | ❌ **never tried 0x2061** |
| MISC | 0xF0 | 4 B | `0x0000003F` | bit-19 RXDV gate clear | ✅ (gate clear both) |

## The divergences that matter

### RxConfig: AGNOS `0x0000EF0F` vs Linux `0x0002CF0E`
- **accept byte (0–5):** AGNOS `0x0F` (AAP\|APM\|AM\|AB), Linux `0x0E` (APM\|AM\|AB).
  Linux receives unicast via plain **physical-match (APM, bit 1)** — no promiscuity.
  AGNOS additionally sets AAP (bit 0); the arc found AAP is **non-functional** on
  iron (if it engaged, AGNOS would see the whole LAN's unicast chatter — it sees none).
- **profile bit 13 (`0x2000`):** AGNOS sets it (`0xEF00`), Linux clears it (`0xCF00`).
- **bit 17 (`0x00020000`): Linux SET, AGNOS clears it.** AGNOS does a *blind* 32-bit
  write (`r8169.cyr:647` pre-CR.RE, `:695` post-CR.RE), whereas Linux's
  `rtl_set_rx_mode` does **read-modify-write** (`RTL_R32(RxConfig) | accept`) →
  Linux preserves bit 17, AGNOS zeroes it. **Identity of bit 17 to be verified
  from source before any code change** ([[feedback_audit_re_derive_dont_validate_comments]]).

### CPlusCmd: AGNOS `0x0008` vs Linux `0x2061`
- Linux `0x2061` ≈ bit13(`0x2000`) | RxVLAN(`0x40`) | RxChkSum(`0x20`) | bit0(`0x01`).
- AGNOS `0x0008` = PCIMulRW only.
- The arc's "CPlusCmd burned both ways and falsified" tested only `0x000B`/`0x0008` —
  **`0x2061` (the actual working value) was never burned.** Untested divergence.

## RESOLVED 2026-05-25 — root cause = CPlusCmd `Normal_mode` (bit 13, 0x2000)

A 3-source convergent audit (Linux v6.6 `r8169_main.c` + FreeBSD `if_rlreg.h`/`if_re.c`
+ decrypted RTL8111B/8168B datasheet §2.8, cross-checked vs this dump) resolved it:

- **RxConfig bit 17 — RULED OUT.** No Linux code path authors `0x20000`; it is a
  chip-set status bit (B-datasheet marks 31:16 reserved). FreeBSD `re_set_rxmode`
  **blind-writes** RxConfig without it and receives unicast fine → blind-write-vs-RMW
  is **not** load-bearing, and bit 17 is not required.
- **Root cause = CPlusCmd `Normal_mode` (bit 13).** Linux obtains CPlusCmd by
  PRESERVING the chip's power-on default (`tp->cp_cmd = RTL_R16(CPlusCmd)`, which
  carries Normal_mode on this silicon) then adding offloads → `0x2061`. AGNOS wrote a
  **bare `0x0008`** (MULRW only), which ZEROED Normal_mode. After the L2 accept filter
  was exonerated on iron (broadcast+multicast pass via the MAR hash, APM unicast dead
  even with AAP set), Normal_mode is the **lone source-confirmed, never-burned**
  divergence. The prior CPlusCmd (`0x000B`/`0x0008`) and RxConfig-profile (`0xCF00`/
  `0xEF00`) A/B burns were **CONFOUNDED** — every one ran with Normal_mode cleared.

**Fix landed in `r8169.cyr` (build-verified 622,560 B, burn-ready):**
- CPlusCmd `0x0008` → **`0x2061`** (`Normal_mode|RxVlan|RxChkSum|INTT0`, matched verbatim).
- RxConfig profile `0xEF00` → **`0xCF00`** (drop spurious RXFTH bit 13) and accept
  `0x0F` → **`0x0E`** (drop AAP — falsified on iron, never set by the working config).
- Net RxConfig `0x0000EF0F` → `0x0000CF0E`; bit 17 left unwritten (chip sets it).

Falsification rubric: FB reads `net: L3+TCP OK -- outbound TCP handshake established`
instead of `SYN sent but no SYN+ACK`. If still FAIL, Normal_mode is not the gate and the
drop is below CPlusCmd (RX descriptor OWN/DMA) — re-baseline against this dump. Receipt:
[`iron-nuc-zen-log.md#tracker-1326-cycle`](iron-nuc-zen-log.md#tracker-1326-cycle) bite 6.
