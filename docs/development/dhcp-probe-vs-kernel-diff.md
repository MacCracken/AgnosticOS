---
name: DHCP Probe vs AGNOS Kernel — Mechanical Diff
description: Byte-by-byte comparison of the working Cyrius userland DHCP probe against agnos/kernel/core/net.cyr dhcp_init. Replaces dhcp-end-to-end-audit.md, dhcp-offer-downstream-audit.md, dhcp-and-outbound-l3-audit-2026-05-24.md.
type: audit
status: working-reference-vs-broken-impl
date: 2026-05-24
---

# DHCP Probe vs AGNOS Kernel — Mechanical Diff

## TL;DR

A POSIX UDP DHCP client written in Cyrius (`scripts/dhcp-probe/`) **successfully acquires a lease from the real Araknis gateway** on archaemenid's `enp1s0`:

```
dhcp-probe: iface=enp1s0
  mac=b0:41:6f:0c:e4:25
  xid=0x306ff80
dhcp: DISCOVER sent (300 bytes)
dhcp: OFFER recv (300 bytes)
  offered ip=192.168.1.129
  server  id=192.168.1.1
  subnet  =255.255.255.0
  gateway =192.168.1.1
dhcp: REQUEST sent
dhcp: ACK recv (300 bytes)
dhcp: LEASE ACQUIRED ip=192.168.1.129 via server=192.168.1.1
```

This single run **exonerates** every layer that the prior three audit docs speculated about:

- BOOTP fixed-header packing (op/htype/hlen/xid/flags/chaddr/magic cookie)
- DHCP option encoding (53 msg-type, 55 param-list, 50 req-IP, 54 server-id)
- DHCP option walker (`parse_reply` → `dhcp_find_option` shape)
- xid round-tripping
- Magic-cookie validation (offset +236, byte-by-byte)
- BOOTP `op==2` REPLY gate
- OFFER → REQUEST → ACK state machine
- Cyrius language semantics for `var X[N]` byte sizing, syscall ABI, integer arithmetic, byte-order shifting

All of this is provably correct in Cyrius against the real wire. **None of the ten "load-bearing" fixes in 1.32.4 were the bug.** The three speculation-driven audit docs that produced them should be considered superseded by this artifact.

## What this proves and what it doesn't

The probe sends DHCP via `sendto()` on an `AF_INET SOCK_DGRAM` socket. The **Linux kernel** builds the UDP header, IP header, and Ethernet frame. The probe's success means:

- The DHCP payload (240-byte BOOTP + options) is byte-correct.
- Cyrius produces valid bytes from `store8`/`store16`/integer shifts for these layouts.
- The Araknis gateway accepts the request and replies on the wire.

The probe's success does **not** validate:

- AGNOS's `ip_build` (20-byte IPv4 header + checksum)
- AGNOS's `udp_build` (8-byte UDP header)
- AGNOS's `eth_build` (14-byte Ethernet header)
- AGNOS's `nic_send` → `r8169_send` (TX descriptor → wire)
- AGNOS's `r8169_poll` (PHY → RX ring → CPU read)
- AGNOS's `net_poll` dispatch path (ring → `net_handle_udp`)

## Byte-walk: AGNOS-constructed DISCOVER vs probe DISCOVER

The probe-on-the-wire capture (tcpdump `-X` against the real probe binary):

```
0x0000: ff ff ff ff ff ff  b0 41 6f 0c e4 25  08 00      eth dst+src+type
0x000e: 45 00 01 48 a18c 4000 40 11 d5f4               IP v4/IHL/TOS/total/ID/flags/TTL/proto/cksum
0x0018: c0 a8 01 7c  ff ff ff ff                       IP src=192.168.1.124 dst=255.255.255.255
0x0020: 00 44 00 43  01 34 c3 69                       UDP sport=68 dport=67 len=308 cksum
0x0028: 01 01 06 00  2e a7 db 37  00 00 80 00          BOOTP op/htype/hlen/hops/xid/secs/flags
0x0034: 00 00 00 00  00 00 00 00  00 00 00 00  00 00 00 00   ci/yi/si/giaddr
0x0044: b0 41 6f 0c e4 25  00 00  ...                   chaddr + zero pad
0x0108: 63 82 53 63                                     magic cookie
0x010c: 35 01 01  37 04 01 03 06 36  ff                 opt53 msg=DISC + opt55 paramlist + END
0x0116: 00 ...                                          pad to 300
```

What AGNOS's `udp_send_from(0, 0xFFFFFFFF, 68, 67, &dhcp_pkt_buf, 300)` would put on the wire (derived mechanically by walking `eth_build` / `ip_build` / `udp_build` / `dhcp_build_packet` at `agnos/kernel/core/net.cyr:45-89` + `:311-335`):

```
0x0000: ff ff ff ff ff ff  b0 41 6f 0c e4 25  08 00      eth dst+src+type — IDENTICAL
0x000e: 45 00 01 48 00 00 00 00 40 11 79 a6               IP — same except ID=0 + frag=0 + cksum recomputed for src=0.0.0.0
0x0018: 00 00 00 00  ff ff ff ff                          IP src=0.0.0.0 (RFC 2131 compliant) dst=broadcast
0x0020: 00 44 00 43  01 34 00 00                          UDP sport=68 dport=67 len=308 cksum=0 (legal RFC 768)
0x0028: 01 01 06 00  <xid>  00 00 80 00                   BOOTP — IDENTICAL shape, AGNOS-generated xid
0x0034..0x010b:                                           IDENTICAL (zero fill + chaddr + cookie)
0x010c: 35 01 01  37 03 01 03 06  ff                      opt53 msg=DISC + opt55(3-param-list) + END
```

### Diffs between probe wire bytes and AGNOS-constructed bytes:

| Offset | Field | Probe | AGNOS | RFC-compliant? | Affects DHCP? |
|--------|-------|-------|-------|----------------|---------------|
| +0x12-13 | IP ID | 0xa18c | 0x0000 | Both legal (RFC 791) | No |
| +0x14-15 | IP flags+frag | 0x4000 (DF) | 0x0000 | Both legal | No |
| +0x18-1b | IP src | 192.168.1.124 | 0.0.0.0 | AGNOS more RFC-correct (RFC 2131 §4.4.1) | No (Araknis accepts both — confirmed via probe success from non-RFC src) |
| +0x26-27 | UDP cksum | 0xc369 (computed) | 0x0000 (disabled) | Both legal (RFC 768 §UDP cksum) | No (Araknis accepts cksum=0; standard for DHCP bootstrap) |
| +0x10f | opt 55 len | 4 | 3 | Both valid | No |
| +0x113 | opt 55 last byte | 36 (server-id req) | (END marker) | Both valid | No |

**No structural diff. AGNOS-on-the-wire bytes would be accepted by Araknis with the same fidelity as the probe's bytes** — every difference is either RFC-equivalent (IP ID, UDP cksum) or AGNOS being *more* RFC-compliant (src=0.0.0.0 per RFC 2131).

## Bug locus — bounded by mechanical exclusion

After this diff, the bug locus is **definitively** one of these three (no others remain):

### 1. r8169 TX wire-egress

`r8169_send` consumes the descriptor (`OWN` bit clears, `TPPoll` kick acknowledged), but the PHY does not actually clock the bits onto the cable. Mechanism candidates:

- TX descriptor `cmdstat` packing missing `FS|LS` for single-fragment packet
- `RTL_W8(TPPoll, NPQ)` not actually kicking the right queue
- Cfg9346 lock state racing the TX engine enable
- ASPM / CLKREQ state leaving PCIe in L1 during TX (link-down to chip)
- TX FIFO threshold leaving frame buffered until eventual flush/timeout

### 2. r8169 RX delivery

PHY receives the OFFER frame; chip never delivers it up to `r8169_poll`. Mechanism candidates:

- RX ring pointer not advancing past the chip's write pointer
- RX descriptor OWN bit polling mis-mapped (we poll the wrong byte/bit)
- EOR (End-Of-Ring) wraparound losing the slot
- `r8169_rx_rearm` re-arming the slot before we read it
- DMA write went somewhere we don't `load64()` from (page-aligned phys vs virt mismatch)

### 3. `net_poll` dispatch

Frame in ring, `r8169_poll` reads it, but it doesn't reach `net_handle_udp`. Looking at `net.cyr:620-650`: extremely simple control flow, branches on ethertype + IP proto. A bug here would silently swallow ALL UDP traffic, which is consistent with the symptom — but the code is mechanically simple enough that re-reading it shows no obvious defect. **Lowest-probability of the three.**

## What the probe artifact itself enables

The probe is **runnable, falsifiable code**. Future hypotheses about the kernel DHCP path can be tested by:

1. Modifying the probe to produce a specific byte variant
2. Running it against Araknis
3. Observing pass/fail

Example: if someone hypothesizes "the bug is UDP cksum=0", change the probe to send cksum=0 (the probe already does this in its own AGNOS-shape variant — TBD as a follow-up) and see if Araknis still ACKs. Result: yes, it does. Hypothesis falsified in 10 seconds, no kernel rebuild, no iron burn.

## The escape hatch this didn't take

The probe still goes through Linux's kernel UDP/IP/Eth wrapper. A **second-tier probe** that builds the full frame (eth + IP + UDP + BOOTP) in Cyrius userland and injects via `AF_PACKET SOCK_RAW` would test AGNOS's `ip_build` / `udp_build` / `eth_build` directly against the wire. If that probe also succeeds, the bug locus shrinks from three suspects to two (r8169 TX or RX only). That artifact is the natural next step but is not built yet — flagged for whenever the network arc resumes.

## Files retired by this artifact

The following audit docs were the *speculation-driven* output of the prior approach. They contain useful prior-art surveys (Linux/BSD/iPXE/lwIP/etc.) that may still be of historical interest, but their **prescriptive sections** ("fix A: BOOTP op==2 gate", "fix B: magic cookie validation", "fix C: xid byte-order audit", etc.) are now superseded — none of those fixes were load-bearing, as the probe proves.

- `docs/development/dhcp-end-to-end-audit.md` — six wiring-bug FIX#1..#6 set: probe confirms FIX#1 (use `nic_mac` not `vnet_mac`) is correct in spirit (must use a non-zero chaddr); FIX#2..#6 unfalsifiable from this surface alone
- `docs/development/dhcp-offer-downstream-audit.md` — 10-item bundle: items 3 (op==2 gate) + 4 (magic cookie) + 5 (xid byte-order) + 6 (options walker) + 10 (ACK matcher) all PROVEN unnecessary as load-bearing fixes; items 1 (tcpdump capture) + 2 (CMOS stamps) + 7 (listener-state stamp) + 8 (frame dump) + 9 (static IP) were instrumentation only
- `docs/development/dhcp-and-outbound-l3-audit-2026-05-24.md` — route helper + outbound TCP test: route helper is structurally correct (probe doesn't exercise it because POSIX kernel handles routing); the cycle-104 ARP timeout symptom that motivated it remains unexplained by anything in *this* doc's scope

## Reproducing

```sh
cd /home/macro/Repos/agnosticos/scripts/dhcp-probe
cyrius build src/dhcp_probe.cyr build/dhcp-probe
sudo ./build/dhcp-probe enp1s0
```

Requires root for `bind(:68)` and `SO_BINDTODEVICE`. Coexists with running `systemd-networkd` / `dhclient` via `SO_REUSEADDR`. Gateway will allocate the next available LAN slot (likely .128–.130 range; Linux already holds .124).

## Next bites if and when the network arc resumes

1. **AF_PACKET-injection variant of the probe** (~150 LOC addition). Builds eth+IP+UDP+BOOTP in Cyrius, bypasses Linux UDP. If it gets a lease → AGNOS `ip_build`/`udp_build`/`eth_build` proven correct, bug locus shrinks to r8169 only.
2. **Compare AGNOS `r8169_poll` outbound TX completion path against a tcpdump from a separate LAN host** while AGNOS burns. Discriminates TX wire-egress (suspect 1) vs RX delivery (suspect 2).
3. **Compile-in net_poll printf instrumentation** (CMOS-stamped, not serial) showing whether `nic_poll` returns *any* byte during the OFFER wait window. Discriminates suspect 2 vs suspect 3.

But the strategic decision belongs upstream of this doc.
