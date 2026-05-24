---
name: DHCP OFFER downstream-of-r8169_poll audit + next-cycle plan
description: Multi-source convergent audit + plan for closing the residual DHCP OFFER-timeout left at agnos 1.32.3 close; chip-level RX filter is unblocked, gate now lives in IP/UDP/DHCP receive path
type: audit
---

# DHCP OFFER downstream-of-`r8169_poll` audit + next-cycle plan

> **Date**: 2026-05-23 PM (post-Attempt-100, post-1.32.3 tag cut)
> **Auditor**: Claude (Opus 4.7, 1M ctx) with two parallel research agents (Explore + general-purpose multi-source)
> **Scope**: the residual DHCP OFFER-timeout left at agnos 1.32.3 close. Attempt 100 (BSD/iPXE-shape r8169 rewrite) unblocked the chip-level RX filter for broadcast frames; `dhcp: OFFER timeout` still persists in FB. This doc characterizes the surface from "broadcast frame admitted by `r8169_poll`" through "REQUEST emitted from `dhcp_init`" and proposes the next-cycle fix arc.
> **Predecessor docs**: [`dhcp-end-to-end-audit.md`](dhcp-end-to-end-audit.md) (660 lines, pre-Attempt-95 wire-up audit) + [`r8169-rx-path-audit.md`](r8169-rx-path-audit.md) (chip-side fix that landed at Attempt 97) + [`r8169-chip-init-audit.md`](r8169-chip-init-audit.md) § BSD + iPXE convergence (the rewrite that delivered Attempt 100). This doc picks up where those leave off.
> **Discipline**: per [[feedback_redesign_dont_reinvent]] — triangulated across RFC 2131 / 2132 / 768 + Linux `ic_bootp_recv` + OpenBSD `dhcpleased` + FreeBSD/ISC `dhclient` + iPXE `dhcp_deliver` + Plan 9 `dhcpclient`. **Linux is one source of many, never the singular reference.**
> **Discipline**: per [[feedback_iron_burns_block_other_work]] — NO iron burn proposed in this doc. Disambiguation is zero-burn from current Linux session on archaemenid + code audit; only then does a targeted-fix burn land.
> **Discipline**: per [[feedback_stop_letter_laddering]] — escape plan written UPFRONT in § 7 before the first repair bite, not after the first falsification.

---

## 1. Context — what Attempt 100 settled vs left open

**What's settled** (Attempt 100 evidence, see iron-nuc-zen-log § Attempt 100 for full receipt):

- **Chip-level RX filter UNBLOCKED for broadcast frames.** CMOS `[0x5E]=0xff` (broadcast first byte ≡ prep PASS target) + `[0x5D]=0x72` = EOR + FS + LS + **BAR** (BAR bit confirms chip flagged desc as broadcast). First iron evidence across the entire 1.32.x DHCP arc that a broadcast frame can be admitted by the chip at all. The BSD/iPXE-shape rewrite (`R8169_RXCFG_DEFAULTS = 0xEF00` per BSD 8168G_PLUS with EARLYOFFV2, iPXE 14-LOC probe-post-reset shape with RXDV gate clear + MAR all-1s, NetBSD `RTKQ_TXRXEN_LATER` deferred `CR=TE|RE`) is the load-bearing fix for the chip-level filter.
- **TX path healthy.** `[0x5B]=0x30` healthy (NIC processed our descriptors and cleared OWN), `[0x5A]=0x03` ≥ prep PASS target (3 r8169_send invocations).
- **Storage trio + GPT + ext2 mount + kybernet + shell all byte-clean.** Networking changes did not regress any other subsystem.
- **TCP listen smoke wires correctly.** FB shows `tcp_listen smoke: start / tcp_listen(8080) lid=0 / tcp_listen smoke: no connection within timeout / tcp_listen smoke: done` between DHCP block and kybernet — TCP listen plumbing reaches the boot path on real ethernet driver state, not just QEMU.

**What's open**: `dhcp: OFFER timeout` still in FB. With chip filter unblocked, the gate is strictly DOWNSTREAM of `r8169_poll`. Two macro-level candidates:

- **(c1) The admitted broadcast was NOT the DHCP OFFER.** Could be ARP request from the switch, NetBIOS name announcement (UDP 137), mDNS query (UDP 5353), SSDP (UDP 1900), Linux dhclient broadcast on the same MAC (Linux holds an active lease at 192.168.1.124 on `b0:41:6f:0c:e4:25`), or LLDP/IGMP. **AGNOS code alone CANNOT decide this** — needs wire-side evidence (tcpdump from Linux session) OR finer instrumentation (ethertype/proto/port stamps to additional CMOS slots).
- **(c2) The OFFER was admitted by the chip but lost downstream** in AGNOS's IP/UDP/DHCP receive path. Multi-source convergence (§ 4 below) identifies ~16 validation gates; AGNOS audit (§ 3) shows 2 LOAD-BEARING gaps (missing BOOTP `op` check, missing magic-cookie validation) and one MEDIUM concern (xid byte-order discipline). Either gap would silently drop a real OFFER.

---

## 2. Data flow — `r8169_poll` arrival to `dhcp_init` REQUEST emission

```
Ethernet frame arrival (r8169_poll @ r8169.cyr)
  | OWN cleared, RES clear, FS|LS set (chip side — Attempt 100 validated)
  | Length extracted, frame copied into net_rx_pkt[2048]
  v
net_poll @ net.cyr:540
  | Ethertype demux (offset +12/+13)
  | 0x0806 -> net_handle_arp                      <- (c1) admitted broadcast might land here
  | 0x0800 -> IPv4 path:
  v
IP header parse (net.cyr:551+)
  | IHL extract (bits 3:0 × 4)
  | Total length (bytes 2-3)
  | Protocol (byte 9)
  | Source IP (bytes 12-15)
  | [NO dest IP validation]      <- gate gap (per Explore audit § 3); compensated by UDP port filter
  | [NO IP checksum validation]  <- chip HW-verified via RES bit
  v
net_handle_udp @ net.cyr:510 (proto == 17)
  | UDP src_port, dst_port, data length
  | [NO UDP checksum validation] <- actually correct per RFC 768 BOOTP convention (checksum=0 legal)
  | Cap data at 1016 bytes
  | Find listener on dst_port (must be port 68 for DHCP)
  | Store payload in listener.buf[1024] + src_ip + src_port
  v
dhcp_init OFFER wait loop @ net.cyr:354-376 (800 iterations)
  | net_poll (absorb pending frames)
  | udp_recv_from(listener_id, &rx[1024], ...)
  | Frame validation gates:
  |   n >= 240 (BOOTP header size)
  |   xid match @ offset +4 (dhcp_load_u32_be)
  |   chaddr match @ offset +28..+33 (6 bytes vs our MAC)   <- compares 6, not 16; correct
  |   message-type option (53) == OFFER (2)
  |   [MISSING: BOOTP op == 2 (REPLY)]                       <- BUG #1
  |   [MISSING: magic cookie 0x63825363 at offset +236]      <- BUG #2
  | On match: extract offered_ip (+16), server_id (option 54), break got=1
  v
REQUEST emission (only fires if got==1)
  | udp_send_from(0.0.0.0, 255.255.255.255, 68, 67, pkt with msg_type=REQUEST)
  v
ACK wait loop (same shape as OFFER)
```

---

## 3. AGNOS-side audit — gate-by-gate (`net.cyr` walk)

Per the Explore agent's full path-walk (saved here as reference; cross-reference `agnos/kernel/core/net.cyr` for line citations). Severities consolidated with the multi-source convergent spec from § 4 — some Explore-flagged gaps reclassified after triangulation showed they were NOT bugs (e.g., missing UDP checksum validation is CORRECT per RFC 768 + 4-of-5-source convergence).

| # | Gate | Location | Status | Severity | Notes |
|---|------|----------|--------|----------|-------|
| 1 | r8169_poll entry guards | `r8169.cyr:589-590` | OK | — | `r8169_present != 0 && r8169_rx_ring_phys != 0` |
| 2 | RX desc OWN check | `r8169.cyr:609` | OK | — | Return 0 if NIC still owns slot |
| 3 | RX desc RES check | `r8169.cyr:613` | OK | — | Skip + re-arm on error |
| 4 | FS+LS frame-complete gate | `r8169.cyr:621` | OK | — | Both bits set required |
| 5 | Frame length valid (>=14) | `net.cyr:543` | OK | — | Minimum Ethernet header |
| 6 | Ethertype match (0x0800 = IPv4) | `net.cyr:551` | OK | — | ARP routed to `net_handle_arp`; IPv6/others ignored |
| 7 | IPv4 minimum size (>=34) | `net.cyr:553` | OK | — | 14 Eth + 20 IP min |
| 8 | IP total >= IHL (underflow) | `net.cyr:560` | OK | — | Security check |
| 9 | Protocol == 17 (UDP) | `net.cyr:562` | OK | — | TCP/ICMP routed elsewhere |
| 10 | **IP dest address filter** | `net.cyr:551+` | **ABSENT** | COSMETIC | Per multi-source spec § 4 gate #5 — the four reference DHCP clients also do NOT filter at L3 (the lower IP layer handles `255.255.255.255` admission). AGNOS's "no IP-dst filter at all" is actually safer for DHCP than a buggy "must match my_ip" filter. **Not a bug**; do not add a filter here. |
| 11 | IP header checksum | (absent) | ABSENT | COSMETIC | Frame integrity already HW-verified by r8169 RES bit |
| 12 | UDP minimum size (>=8) | `net.cyr:512` | OK | — | UDP header |
| 13 | **UDP checksum validation** | (absent) | ABSENT | **CORRECT** | Per RFC 768 + multi-source spec § 6 — checksum=0 is legal BOOTP convention; many servers emit 0. Linux ic_bootp_recv also skips validation. AGNOS's "skip checksum" is correct. |
| 14 | UDP dst_port listener match | `net.cyr:526` | OK | — | DHCP listener must be bound on port 68 before OFFER arrives |
| 15 | UDP src_port filter | (absent) | ABSENT | OK | Multi-source spec is split; some check src==67, some don't. AGNOS not filtering by src is safer. |
| 16 | Listener.state == 1 (bound) | `net.cyr:162` | OK | — | Slot not freed/reused |
| 17 | Listener.buf_ptr != 0 | `net.cyr:530` | OK | — | Buffer allocated by udp_bind |
| 18 | Frame size >= 240 (BOOTP min) | `net.cyr:354` | OK | — | |
| 19 | **xid match (offset +4)** | `net.cyr:355` (`dhcp_load_u32_be`) | NEEDS VERIFICATION | MEDIUM | Uses `dhcp_load_u32_be` for RX-side read; verify the TX-side build in `dhcp_init` uses **the same byte-order discipline** (`dhcp_store_u32_be` or equivalent on DISCOVER xid emission). Per multi-source spec § 2: mixing wire-order TX + host-order RX is 100% silent-drop. |
| 20 | chaddr 6-byte match (offset +28) | `net.cyr:360-363` | OK | — | Compares 6 bytes, not 16 — correct per multi-source spec § 3 |
| 21 | **Magic cookie (offset +236)** | (absent on RX) | **ABSENT** | **LOAD-BEARING** | Constants defined at `net.cyr:227-230`, written on TX at `net.cyr:286-289`, **never validated on RX**. 4-of-5 reference sources validate this (Linux / OpenBSD / FreeBSD / Plan 9). iPXE relies on packet-construction symmetry. The compare must be a **byte-array `memcmp` against `{0x63,0x82,0x53,0x63}`** — comparing as a `u32` literal is endianness-buggy (silent drop on x86) per multi-source spec § 7. |
| 22 | **BOOTP op == 2 (BOOTREPLY)** | (absent) | **ABSENT** | **LOAD-BEARING** | All 5 reference sources validate `op == BOOTREPLY` (2) on RX. AGNOS only checks msg_type option (53) but not the BOOTP header op field. A looped-back DISCOVER, a non-DHCP BOOTP server reply, or a corrupt frame with the right xid+chaddr would pass the current matcher despite being structurally wrong. RFC 2131 § 4.1 mandates this check. |
| 23 | Options walker Pad/End handling | `net.cyr:dhcp_find_option` | NEEDS VERIFICATION | MEDIUM | Per multi-source spec § 7 — walker must: tag 0 (Pad) → skip 1 byte no length follows; tag 255 (End) → terminate; any other → read 1-byte length then `length` bytes value, advance `2 + length`; bounds-check `ext + 2 + len <= end` at each step. Off-by-one here is both a silent-drop site AND a memory-safety vulnerability. |
| 24 | Message type option (53) == OFFER (2) | `net.cyr:367-368` | OK | — | All sources converge |
| 25 | Server identifier option (54) | `net.cyr:370` | OK | — | Extracted (warning if absent per OpenBSD; not strictly required for OFFER acceptance) |

---

## 4. Multi-source convergent OFFER-reception spec (condensed)

Triangulated across **6 sources**: RFC 2131 + RFC 2132 + RFC 768 + Linux `ic_bootp_recv` (`net/ipv4/ipconfig.c`) + OpenBSD `dhcpleased` + FreeBSD/ISC `dhclient` + iPXE `dhcp_deliver` + Plan 9 `dhcpclient`. Full agent report folded into the gate table at § 3.

**Top 8 silent-drop failure modes** (ranked by real-world bug-history frequency from the general-purpose agent's research):

| Rank | Failure mode | Convergent gate | AGNOS status | Maps to |
|------|--------------|-----------------|--------------|---------|
| 1 | L3 dst filter rejecting `255.255.255.255` (interface IP == 0 during SELECTING) | #5 IP dst admission | **OK** (no L3 filter — safer) | § 3 row 10 |
| 2 | UDP checksum verified, server emitted 0 | #7 UDP csum-zero convention | **OK** (no UDP csum validation) | § 3 row 13 |
| 3 | xid byte-order mismatch between TX-build and RX-compare | #9 xid match discipline | **NEEDS VERIFY** | § 3 row 19 |
| 4 | chaddr compared as 16 bytes instead of 6 (`hlen`) | #11 chaddr match | **OK** (compares 6) | § 3 row 20 |
| 5 | Magic cookie compared as `u32` literal (endianness flip) | #12 cookie validation | **ABSENT** (not validated at all on RX) | § 3 row 21 |
| 6 | Options walker mishandles Pad (0) / End (255) | #13 walker invariants | **NEEDS VERIFY** | § 3 row 23 |
| 7 | Filter on `src == 68` instead of `src == 67` | #6 UDP port filter | **OK** (no src filter) | § 3 row 15 |
| 8 | chaddr enforced on OFFER (problematic when multiple DHCP clients share a MAC, e.g. Linux dhclient + AGNOS on same box) | #11 OFFER-vs-ACK enforcement | **ENFORCED on OFFER** — this is the iPXE/FreeBSD/ISC choice (Linux skips on OFFER) | § 3 row 20; **note for archaemenid context**: Linux dhclient holds the lease for `b0:41:6f:0c:e4:25` while AGNOS boots, so chaddr-on-OFFER could in principle drop a Linux-bound OFFER. But: server uses chaddr from DISCOVER to address the OFFER's chaddr field; if AGNOS's DISCOVER xid is unique, the server won't address the OFFER to Linux's xid even on same MAC. Re-evaluate after instrumentation in § 5 narrows the cause. |

**Net AGNOS-side prognosis**: of the 8 known silent-drop modes, AGNOS is correctly clear on 4 (#1, #2, #4, #7), has **2 LOAD-BEARING absent validations** (#5, plus the BOOTP `op` gap from § 3 row 22), and **2 MEDIUM verifications outstanding** (#3 xid byte-order, #6 options walker invariants). The two LOAD-BEARING gaps alone are sufficient to explain a silent OFFER drop in the (c2) path.

---

## 5. Plan — zero-burn disambiguation FIRST, then targeted fix

Per [[feedback_iron_burns_block_other_work]] + [[feedback_stop_letter_laddering]]: no burn proposed until the (c1) vs (c2) split is decided. Three zero-burn options (cheapest first):

### Bite 1 — `tcpdump` wire capture from Linux side

**Goal**: decide (c1) "admitted broadcast was NOT the OFFER" vs (c2) "OFFER was admitted but lost downstream" empirically without writing code OR burning iron.

**Execution** (user runs from Linux session on archaemenid while next AGNOS burn happens):

```sh
sudo tcpdump -i enp1s0 -nn -X -s 0 'port 67 or port 68' -w /tmp/dhcp-capture-attempt-101.pcap
# Reboot to AGNOS USB; let it run through DHCP DISCOVER + OFFER-wait window
# Power-cycle back to Linux; ctrl-C the tcpdump
tcpdump -nn -X -r /tmp/dhcp-capture-attempt-101.pcap
```

**Outcome decoding**:
- **OFFER frame appears in capture** (`192.168.1.1.67 > 255.255.255.255.68: BOOTP/DHCP, Reply, length 300+`): (c2) confirmed. The OFFER was on the wire; AGNOS's downstream path dropped it. Proceed to Bite 3 (LOAD-BEARING code-audit fixes).
- **OFFER frame absent; only DISCOVER from AGNOS**: (c1) confirmed in part — server didn't reply (or replied unicast to a different MAC). Possible reasons: server saw two DISCOVERs in quick succession (Linux dhclient + AGNOS, same MAC), responded only once with a renewal of Linux's lease silently. Mitigation = stop dhclient on the Linux side before AGNOS burn OR change AGNOS MAC for testing.
- **OFFER present + unicast to AGNOS MAC, AGNOS still times out**: (c2) confirmed AND chip is admitting unicast too — proceed to Bite 3.
- **Other broadcast traffic visible (ARP / mDNS / NetBIOS) at AGNOS boot time, no DHCP OFFER**: (c1) confirmed — explains the admitted-broadcast CMOS evidence without invoking a DHCP-specific bug.

**Cost**: zero code, zero burn, ~5 min. Pure observability win.

### Bite 2 — finer CMOS instrumentation (frame ethertype + IP proto + UDP dst port)

**Goal**: pre-emptively answer the (c1) vs (c2) question from the next burn's CMOS readback without depending on the user running tcpdump.

**Execution**: stamp 3 additional CMOS slots in `net_poll` / `net_handle_udp` on the LAST-CONSUMED frame's identifying bytes. Per [[feedback_no_serial_on_iron]] + [[feedback_iron_burns_block_other_work]] this is instrumentation-only; pair with the code fix in Bite 3 so this isn't a "just-testing burn" per the user's instrumentation-budget discipline.

| Slot | Stamp | Decode |
|------|-------|--------|
| `0x60` | last frame ethertype byte 0 (offset +12) | `0x08` = IPv4 or ARP; other = uncommon |
| `0x61` | last frame ethertype byte 1 (offset +13) | `0x00` = IPv4 → DHCP-plausible; `0x06` = ARP → (c1); `0xDD` IPv6 / other |
| `0x62` | if IPv4: IP proto (offset +14 + IHL_byte) | `0x11` = UDP → DHCP-plausible; `0x01` = ICMP; `0x06` = TCP |
| `0x63` | if UDP: dst port low byte (offset +14 + IHL + 2) | `0x44` = 68 → DHCP-bound; `0x89` = 137 NetBIOS; `0xE9` = 5353 mDNS; `0x6C` = 1900 SSDP |

NOTE: CMOS slot 0x60 is already in use (`xhci PORTPMSC of failed port`). Slots `0x88..0x8F` are free in the extended-CMOS bank (per `results.txt` cataloguing, the extended bank at `[0x86]=0xCC` is live). Use `0x88..0x8B` instead. Pre-burn instrumentation audit per [[feedback_iron_burns_block_other_work]]:

```
[0x88] = ethertype hi (offset +12)
[0x89] = ethertype lo (offset +13)
[0x8A] = IP proto (offset +14 + IHL_byte; 0 if not IPv4)
[0x8B] = UDP dst port lo (offset +14 + IHL + 3; 0 if not UDP)
```

Stamp fires on the LAST consumed frame at `r8169_poll` return — single state-transition stamp per frame (no hot-path tax). Add 2 declarations + 4 lines in `r8169_poll`'s return-with-length path + 2 reader rows in `read-boot-log.cyr`.

**Bundle this with Bite 3's fix** so a single burn produces both: instrumentation evidence + fix attempt.

### Bite 3 — LOAD-BEARING code fixes (bundle into next burn)

Stack the two LOAD-BEARING fixes into ONE bundle. Per [[feedback_redesign_dont_reinvent]] both are multi-source convergent (4-of-5 reference sources enforce each).

#### Fix A — BOOTP op == 2 (REPLY) gate in `dhcp_init` OFFER matcher

**Location**: `agnos/kernel/core/net.cyr:354-376` (OFFER match loop, inserted as first sanity check before xid extraction).

**Shape** (per Explore agent's proposal):

```cyrius
# In dhcp_init OFFER wait loop, immediately after udp_recv_from returns n >= 240:
if (load8(&rx + 0) != 2) { continue; }    # BOOTP op must be 2 (BOOTREPLY) — RFC 2131 §4.1
```

**Source convergence**: Linux `b->op != BOOTP_REPLY` (`net/ipv4/ipconfig.c:ic_bootp_recv`); OpenBSD parse_dhcp implicit via `parse_dhcp`; FreeBSD/ISC explicit gate; iPXE explicit; Plan 9 covered via msg type. 5-of-5.

**Falsification rubric**: if Bite 3 lands and OFFER timeout persists with `[0x5E]=0xff` + `[0x88-0x8B]=08,00,11,44` (Bite 2's stamps showing the admitted broadcast WAS a DHCP frame to port 68), then op-check was not the gate — escalate to Fix C (xid byte-order verification) or Fix D (magic cookie validation, if not already bundled).

#### Fix B — Magic cookie validation in `dhcp_init` OFFER matcher

**Location**: `agnos/kernel/core/net.cyr:354-376` (OFFER match loop, inserted after Fix A's op check, before xid extraction).

**Shape** (per Explore agent's proposal, with multi-source-correct discipline):

```cyrius
# In dhcp_init OFFER wait loop, after op check:
# Validate magic cookie 0x63,0x82,0x53,0x63 at offset 236 (immediately before options blob).
# CRITICAL: byte-by-byte compare (NOT a u32 literal compare — endianness bug per multi-source spec § 7).
if (load8(&rx + 236) != 0x63) { continue; }
if (load8(&rx + 237) != 0x82) { continue; }
if (load8(&rx + 238) != 0x53) { continue; }
if (load8(&rx + 239) != 0x63) { continue; }
```

(Alternative: extend `dhcp_find_option` to validate the cookie before walking; whichever fits AGNOS conventions better.)

**Source convergence**: Linux byte-array `ic_bootp_cookie` `memcmp`; OpenBSD byte-array `memcmp`; Plan 9 byte-array `memcmp(optmagic, p, 4)`; iPXE relies on TX-symmetry only (NOT validated on RX — outlier). 4-of-5.

**Falsification rubric**: if both Fix A + Fix B land and OFFER timeout persists with `[0x88-0x8B]=08,00,11,44`, escalate to Fix C (xid byte-order audit).

#### Fix C (HELD pending Bite 1 or Bite 2 evidence) — xid byte-order discipline verification

Not landed in this round. Audit-only this cycle:

```sh
# In agnos repo:
grep -n -E "dhcp_xid|xid" kernel/core/net.cyr | head -30
# Trace: where is dhcp_xid generated? rdrand_u64 host-order? written via store32 host-order or store32_be (network-order)?
# Where is OFFER's xid read? dhcp_load_u32_be (BE) per the Explore audit.
# If TX is host-order + RX is BE → mismatch on multi-byte; this is a 100% silent-drop site.
```

If audit shows a discipline mismatch, Fix C lands in the NEXT bundle with a one-line discipline alignment (`store32_be` on TX or `load32_le` on RX, whichever matches the wire format).

#### Fix D (HELD) — Options walker Pad/End invariant verification

Not landed in this round. Audit-only:

```sh
# In agnos repo:
grep -n -E "dhcp_find_option|options" kernel/core/net.cyr | head -30
# Check: does the walker special-case tag 0 (Pad) → skip 1 byte no length?
# Tag 255 (End) → terminate?
# Bounds-check ext + 2 + len <= end at each step?
# If any of these is missing or off-by-one → silent drop AND memory-safety risk.
```

---

## 6. Bundle plan for the next burn (NOT auto-proposed)

Per [[feedback_iron_burns_block_other_work]] + [[feedback_no_instrumentation_means_no_instrumentation]] no burn proposed until user direction. When the user authorizes the next burn, the bundle is:

| Bite | Type | Code touch | Risk |
|------|------|-----------|------|
| **1** | Wire observability (Linux-side, no burn) | None on AGNOS | Zero |
| **2** | CMOS instrumentation: `[0x88..0x8B]` ethertype/proto/port stamps in `r8169_poll` + `read-boot-log.cyr` reader rows | ~6 LOC in `r8169.cyr`, ~8 LOC in `read-boot-log.cyr` | Low — single state-transition stamp per frame, no hot-path tax |
| **3A** | Fix: BOOTP op == 2 check in `dhcp_init` OFFER matcher | 1 line in `net.cyr:354-376` | Low — multi-source convergent, RFC-mandatory |
| **3B** | Fix: Magic cookie validation in `dhcp_init` OFFER matcher | 4 lines in `net.cyr:354-376` | Low — multi-source convergent, RFC-mandatory; byte-array compare avoids endianness trap |

**Build size estimate**: ~12-18 B in `r8169.cyr` (CMOS stamps), ~5-15 B in `net.cyr` (5 validation lines), ~30-40 B in `read-boot-log.cyr` (4 new slot reader rows). Net <100 B vs 1.32.3's 617,984 B `TCP_LISTEN_SMOKE=1` baseline.

**Pre-burn rubric** (to be pinned in iron-nuc-zen-log § "Next-cycle bundle prep" when the user authorizes the burn):

| Signal | 1.32.3 / Attempt 100 baseline | Next-burn PASS target | Falsification |
|--------|--------------------------------|----------------------|----------------|
| `dhcp:` block in FB | `DISCOVER → OFFER timeout` | `DISCOVER → OFFER ip=192.168.1.X → REQUEST → ACK ip=192.168.1.X gw=192.168.1.1 mask=255.255.255.0` | Still `OFFER timeout` — see decision tree below |
| `[0x5A]` TX sends | 0x03 | **≥ 0x04** (DISCOVER + REQUEST + retransmits) if OFFER matched | 0x03 unchanged → REQUEST never fired → OFFER still not matched |
| `[0x5E]` last RX first byte | 0xff (broadcast) | 0xff (broadcast OFFER) OR 0xb0 (unicast OFFER) | 0xff persists + 0x88-0x8B reveal non-DHCP frame → (c1) confirmed |
| **NEW `[0x88]`** ethertype hi | (uninstrumented) | 0x08 (IPv4) | 0x08 missing → admitted broadcast was non-IP (ARP / LLDP / etc.) → (c1) confirmed |
| **NEW `[0x89]`** ethertype lo | (uninstrumented) | 0x00 (IPv4) | 0x06 → ARP → (c1); 0xDD → IPv6 → (c1) |
| **NEW `[0x8A]`** IP proto | (uninstrumented) | 0x11 (UDP=17) | other → non-UDP IPv4 → (c1) |
| **NEW `[0x8B]`** UDP dst port lo | (uninstrumented) | 0x44 (port 68) | 0x89=137 NetBIOS, 0xE9=5353 mDNS, 0x6C=1900 SSDP → (c1) |

**Decision tree after burn**:

- **PASS**: full DHCP cycle on iron. Close next-cycle DHCP arc; pivot per user direction.
- **PARTIAL (OFFER matched, ACK times out)**: Fixes A + B were load-bearing for OFFER; ACK matcher has the same gaps. Mirror A + B in the ACK match loop.
- **FALSIFIED + `[0x88-0x8B]=08,00,11,44`**: admitted broadcast WAS DHCP to port 68, AGNOS still dropped it. Fix C (xid byte-order) + Fix D (options walker) escalate in the NEXT bundle.
- **FALSIFIED + `[0x88-0x8B]` shows non-DHCP**: (c1) confirmed. The chip is admitting some non-DHCP broadcast (most likely candidate: ARP from the switch responding to AGNOS's own DISCOVER, or Linux dhclient broadcast on same MAC). Mitigation = stop Linux dhclient OR change AGNOS test MAC OR audit server-side (does Araknis 210 actually emit an OFFER in response to AGNOS's DISCOVER? `dhcp-end-to-end-audit.md` § "Wire-side baseline" already validated YES for synthetic + real MAC via Python AF_PACKET probe).

---

## 7. Escape plan — what we do if Fixes A + B + C + D all falsify

Per [[feedback_stop_letter_laddering]] — written UPFRONT, not after another falsification cycle.

If after the next 1-2 burns the OFFER-timeout symptom persists with `[0x88-0x8B]=08,00,11,44` (proving the admitted broadcast IS a DHCP frame to port 68 AND all four downstream code fixes have landed without effect):

1. **Stop iterating on `dhcp_init`**. The gate is not in `dhcp_init`'s match loop.
2. **Trace listener-binding race**: instrument `net.cyr:udp_bind` + `dhcp_init`'s `udp_bind(68)` call to confirm listener.state == 1 at the moment the OFFER frame arrives. CMOS stamp: `[0x8C]` = listener.state at first frame post-DISCOVER.
3. **If listener is bound**: dump the full received frame's first 64 bytes to CMOS extended bank (`[0x90..0xCF]` = 64 bytes) on the FIRST UDP/68 frame consumed post-DISCOVER. Cross-reference with `tcpdump` from Bite 1's wire capture to confirm the frame on the ring IS the OFFER as emitted by the server.
4. **If frames match byte-for-byte and AGNOS still drops**: the bug is in `udp_recv_from` consumer-side queueing — buffer copy + listener.buf rotation has a race or off-by-one. Audit `net_handle_udp` → listener.buf write vs `udp_recv_from` listener.buf read for: (a) buffer-length mismatch, (b) double-consume, (c) listener.buf overwrite by a second frame before `udp_recv_from` reads.
5. **If frames don't match**: the admitted frame is NOT the wire OFFER even though headers say "UDP to port 68." Investigation broadens to: r8169 DMA misalignment, descriptor write-protect leakage, or BAR-side memory corruption. Drop a 2nd memory snapshot CMOS at frame-offset +256 to confirm payload integrity.
6. **As LAST resort** (after exhausting the above): pivot to network bring-up against a different DHCP server (USB-tether to phone hotspot, or a `dnsmasq` on the Linux host bridged to AGNOS's NIC) to rule out the Araknis 210 having a quirk that the multi-source convergent client doesn't handle. Per [[feedback_no_hardware_purchase_suggestions]] — no buying anything; use the iron in hand.

**Cycle-cap discipline**: if this escape plan reaches step 6 without resolution, stop the DHCP arc entirely and re-evaluate scope. Static IP fallback in `dhcp_init` (set `net_ip`/`net_gw`/`net_netmask` via a kernel cmdline arg or hardcoded boot-time constant) lets the network stack reach `tcp_listen smoke: PASS` without depending on DHCP at all — unblocks every downstream networking validation (TCP server reachability, REST endpoint testing, etc.) while DHCP root-cause investigation continues in parallel without blocking other 1.33.x work.

---

## 8. Out-of-scope (deliberately deferred)

- **AGNOS sending REQUEST and getting no ACK**: only audit ACK matcher once OFFER matcher is unblocked. Likely the same gates (op, magic cookie, xid, chaddr, msg_type) but for `DHCPACK (5)`.
- **DHCP retransmit / backoff tuning**: 800-iter wait is fine for now. Tuning is a UX improvement, not a correctness fix.
- **DHCP RENEW / REBIND lifecycle**: deferred to post-MVP. Initial lease acquisition is the only thing in scope for 1.32.x → 1.33.x.
- **DHCP options beyond 51 (lease) / 53 (msg type) / 54 (server-id)**: option 1 (subnet mask) + option 3 (router) + option 6 (DNS) extraction is already in `dhcp_init` or will be follow-up; this audit doesn't change that surface.
- **virtio_net legacy interface revival**: per CHANGELOG [1.32.3] § "Deferred", legacy is 1.34.x cleanup.
- **r8169 chip-side audit continuation**: Attempt 100 unblocked the chip filter. Further chip-side work (MAR0/MAR4 hash, AspmL1L2Latency timing, vendor cap reads) is OUT OF SCOPE until evidence points back to the chip.

---

## 9. Cross-references

- [`dhcp-end-to-end-audit.md`](dhcp-end-to-end-audit.md) — predecessor doc, pre-Attempt-95 wire-up audit (660 lines)
- [`r8169-rx-path-audit.md`](r8169-rx-path-audit.md) — chip-side RX-path audit (drove the Attempt 97 5-part bundle)
- [`r8169-chip-init-audit.md`](r8169-chip-init-audit.md) § BSD + iPXE convergence — the audit behind Attempt 100's rewrite
- [`network-arc-prior-art.md`](network-arc-prior-art.md) — broader 1.32.x networking arc prior art
- [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md) § Attempt 100 — the iron evidence base for "broadcast admitted, OFFER lost"
- [`iron-nuc-zen-photos/attempt-100-cmos-readback.txt`](iron-nuc-zen-photos/attempt-100-cmos-readback.txt) — full CMOS slot dump
- `agnos/CHANGELOG.md` § [1.32.3] § "Iron-side outcomes" — the receipt that opens this carry-forward
- `agnos/docs/development/state.md` § "Open investigations — DHCP OFFER-timeout downstream of r8169_poll" — the live-state pointer back here

## 10. Memory follow-ups

None of the new findings warrant a new memory file. Existing relevant memories that govern this work:

- [[feedback_redesign_dont_reinvent]] — six-source triangulation discipline (followed)
- [[feedback_iron_burns_block_other_work]] — no burn auto-proposed; audit lands first (followed)
- [[feedback_stop_letter_laddering]] — escape plan written UPFRONT (§ 7) (followed)
- [[feedback_no_letter_codes_for_repairs]] — fixes named for what they do (A=op-check, B=magic-cookie, C=xid-byte-order, D=options-walker), not lettered (followed; letters here are just bundle indices for this single doc, not arc-spanning identifiers)
- [[feedback_no_serial_on_iron]] — Bite 2 instrumentation is CMOS only, FB also acceptable (followed)
- [[feedback_no_instrumentation_means_no_instrumentation]] — Bite 2 bundled with Bite 3 fix to avoid a "just-testing burn" (followed)
- [[feedback_known_knowledge_first]] — existing audit docs surveyed before researching (followed; this doc extends, doesn't duplicate)
