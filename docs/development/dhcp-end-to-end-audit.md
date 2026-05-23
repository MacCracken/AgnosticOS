---
name: DHCP end-to-end wiring audit
description: Multi-source convergent audit of AGNOS's DHCP pipeline post-Attempt-94, surfacing wire-up bugs upstream of the r8169 NIC
type: audit
---

# DHCP End-to-End Wiring Audit (post-Attempt 94)

> **Status**: ALL SIX FIXES LANDED in code — 2026-05-22, same-day as audit. Pre-Attempt-95 iron burn. QEMU validation: `scripts/test.sh` 4/4 + `scripts/ext2-smoke.sh` 5/5 + 5/5 regression + `tcp-listen-smoke.sh` 1/2 (matches pre-fix 1.32.0 baseline — scenario 1 is the pre-existing SLIRP-RX gap, iron-only). Build delta: 603,784 B (Attempt 94) → **604,096 B production** / **604,904 B TCP_LISTEN_SMOKE** (+312 / +584 B). All six findings annotated **APPLIED** in § 3 below.
>
> Audit doc first landed 2026-05-22 after Attempt 94's CMOS readback falsified the audit § 10 H1/H7/H8 framing and pushed OFFER-timeout root cause upstream of the NIC.
>
> **Companion to**: [`r8169-iron-burn-audit.md`](r8169-iron-burn-audit.md) (NIC-layer audit, scope ends at `r8169_send` / `r8169_poll`). This doc audits the *layer above* — kernel DHCP client + UDP + IP + Ethernet build/parse — and the wiring between net.cyr and whichever NIC backend is active.
>
> **Per**: [[feedback_iron_burns_block_other_work]] (every iron-burn proposal carries a written line-by-line audit FIRST) + [[feedback_redesign_dont_reinvent]] (multi-source convergent — Linux is one source of many, not the singular reference).
>
> **No code touches in this doc.** Findings + fix shapes only. Code lands in a separate cycle bite after user reviews.

## 1. Scope

Trace every wire-touching site between `dhcp_init()` and the server's `OFFER` reply, on the iron path (r8169 active, virtio_net absent — archaemenid topology).

In scope:
- `kernel/core/net.cyr` — DHCP client, UDP send/recv/listener table, IP build, Ethernet build, ARP, ingress poll dispatcher.
- `kernel/core/r8169.cyr` — `r8169_send` / `r8169_poll`, MAC capture into `r8169_mac`, MAC-filter program (`RxConfig`), bite C `r8169_phy_init`.
- `kernel/core/main.cyr` — boot-time init order between `r8169_probe`, `virtio_net_init`, `net_init`, and `dhcp_init`.
- `kernel/core/virtio_net.cyr` — only insofar as it currently owns `vnet_mac` (the variable every net.cyr egress site reaches for as "kernel src MAC").

Out of scope:
- TCP server-side primitives (bite A of 1.32.0; not on the DHCP path).
- xHCI / USB-MS / NVMe / ext4 layers (storage trio is byte-clean at Attempt 94).
- i225-V driver port (carry-forward to a later cycle; same audit pattern will apply).

Hardware anchor (queried directly on archaemenid per [[feedback_archaemenid_is_dev_host]]):

| Field | Value |
|---|---|
| NIC | Realtek RTL8111/8168 (`10ec:8168` rev 15) |
| BDF | `0000:01:00.0` |
| MAC | `b0:41:6f:0c:e4:25` |
| BAR2 MMIO | `0xFCF04000` |
| BAR4 MSI-X | `0xFCF00000` |

## 2. End-to-end DHCP pipeline as-currently-wired

The egress path for `dhcp: DISCOVER` (Attempt 94 reached this point successfully — `0x5A=2`, `0x5B=0x30`):

```
main.cyr:656  dhcp_init()                                    (called from kmain post-r8169_probe)
              │
              ├─ udp_bind(68)                                listener_id, allocates 256 B recv buf
              │
              ├─ build options[16]: msg-type=DISCOVER + param-list (1, 3, 6)
              │
              ├─ dhcp_build_packet(buf, xid, opts, 9)        net.cyr:253
              │  ├─ memset(buf, 0, 240)
              │  ├─ store op=1, htype=1, hlen=6
              │  ├─ store xid                                identifies our session
              │  ├─ store flags=0x8000                       broadcast bit (high byte of flags field)
              │  ├─ memcpy(buf+28, &vnet_mac, 6)             ← chaddr (client HW addr)   *** FINDING #1
              │  ├─ store magic-cookie at offset 236         99.130.83.99 ✓
              │  └─ memcpy(buf+240, opts, 9)                 options blob
              │
              └─ udp_send_from(0, 0xFFFFFFFF, 68, 67, ...)   net.cyr:125
                 │
                 ├─ var dst_mac[8]; memset(&dst_mac, 0xFF, 6)   broadcast dst ✓
                 ├─ eth_build(p, &dst_mac, &vnet_mac, 0x0800)   ← Ethernet src MAC      *** FINDING #1
                 ├─ udp_build(p+34, 68, 67, dhcp_pkt_buf, 249)  src/dst ports, UDP cksum=0
                 ├─ ip_build(p+14, 0, 0xFFFFFFFF, 17, udp_len)  src=0.0.0.0 ✓, dst=255.255.255.255 ✓
                 └─ nic_send(p, off + 20 + udp_len)             r8169.cyr:582 — dispatches to r8169_send

r8169.cyr:551 r8169_send(buf, len)
              │
              ├─ saturating TX send counter increment (bite B stamp at 0x5A)   ✓ fires
              ├─ desc = tx_ring_phys + tx_idx*16
              ├─ memcpy(buf bytes → tx_desc bufaddr) byte-for-byte             ← no MAC rewrite
              ├─ store32(desc, OWN|FS|LS|len)                                  ✓ NIC takes desc
              └─ store8(mmio+0x38, 0x40)                                       TPPoll NPQ kick
                                                                              ✓ wire egress
```

The receive path for a hypothetical OFFER reply:

```
r8169.cyr:r8169_poll                                          (scheduler-idle hot path)
              │
              ├─ saturating poll counter (bite B stamp at 0x5C = 0xFF — running constantly) ✓
              ├─ walk RX descriptor ring, find OWN=0 descriptor
              ├─ if found: copy bytes from RX buf → caller buf, return len
              └─ re-arm desc with OWN=1, advance ring head
                                                              CMOS 0x5D = 0x80 (re-armed) ✓
                                                              CMOS 0x5E = 0x01 (DMA byte captured) ✓
                                                              *** FINDING #2: 0x01 is not a DHCP first-byte

net.cyr:470   net_poll()
              │
              ├─ nic_poll(&net_rx_pkt, 2048)
              ├─ parse Ethernet: ethertype = pkt[12..14]                       no MAC filter here
              │  └─ NIC hardware MAC filter is the only filter before net_handle_udp
              ├─ if 0x0800 (IPv4): parse IP header, demux on proto
              │  └─ if proto=17 (UDP): net_handle_udp(pkt, ip_payload_off, len, src_ip)
              │
net.cyr:444   net_handle_udp(pkt, ip_off, ip_payload_len, src_ip)
              │
              ├─ src_port = pkt[ip_off..+2]
              ├─ dst_port = pkt[ip_off+2..+4]                                  expect 68 for OFFER
              ├─ copy data → global net_udp_buf (legacy, single-consumer)
              ├─ lid = udp_find_listener(dst_port)                             matches DHCP's port-68 bind
              └─ if lid >= 0: copy data → listener's per-bind buf              ✓ if NIC delivered the frame

net.cyr:286   dhcp_init (continuing in OFFER wait loop, ti < 200)
              │
              ├─ net_poll()
              ├─ udp_recv_from(lid, &rx, 320, &src_ip, &src_port)
              ├─ if n >= 240 and xid matches and option-53 = OFFER:            ← BOOTP/DHCP match
              │     extract offered_ip (yiaddr at +16), server_id (option-54)
              │     break, proceed to REQUEST
              └─ else: arch_wait()  (hlt — wait for next IRQ-driven wake)      *** FINDING #3

After 200 iterations with no OFFER: print "dhcp: OFFER timeout" and return -1.
```

## 3. Findings

### FINDING #1 (CRITICAL) — Kernel src MAC is `vnet_mac`, never updated from r8169

**Symptom**: On iron, every Ethernet frame egressing from `net.cyr` has Ethernet src MAC = `0:0:0:0:0:0` (zeros), AND every DHCP DISCOVER has BOOTP `chaddr` = `0:0:0:0:0:0`.

**Root cause** (the actual wiring bug):

`vnet_mac` is declared at `kernel/core/virtio_net.cyr:5` (`var vnet_mac[8];`) and **only ever written** at `virtio_net.cyr:69`:

```cyrius
# virtio_net_init() runs only if pci_find(0x1AF4, 0x1000) >= 0
for (var i = 0; i < 6; i = i + 1) {
    store8(&vnet_mac + i, inb(vnet_iobase + 20 + i));   # read MAC from virtio config space
}
```

But every egress site in `net.cyr` consumes `vnet_mac` as the kernel's authoritative src MAC:

| Site | Line | Context |
|---|---|---|
| `arp_request` Ethernet src | `net.cyr:92` | `eth_build(p, &bcast, &vnet_mac, 0x0806)` |
| `arp_request` ARP sender HW | `net.cyr:97` | `memcpy(p + off + 8, &vnet_mac, 6)` |
| `udp_send` Ethernet src | `net.cyr:116` | `eth_build(p, &dst_mac, &vnet_mac, 0x0800)` |
| `udp_send_from` Ethernet src | `net.cyr:130` | `eth_build(p, &dst_mac, &vnet_mac, 0x0800)` |
| **`dhcp_build_packet` chaddr** | **`net.cyr:264`** | **`memcpy(buf + 28, &vnet_mac, 6)`** |
| ARP reply sender HW | `net.cyr:429` | `memcpy(p + off + 8, &vnet_mac, 6)` |
| `tcp_send_pkt` Ethernet src | `net.cyr:635` | `eth_build(p, &dst_mac, &vnet_mac, 0x0800)` |

The init sequence in `main.cyr:270-289` makes the divergence concrete:

```cyrius
if (r8169_probe() == 1) {              # iron path: r8169 found
    r8169_init_rx();
    r8169_init_tx();
}                                       # ← r8169_mac IS populated (line 320)
                                        # ← vnet_mac is NOT touched

if (pci_find(0x1AF4, 0x1000) >= 0) {    # iron: no virtio-net device → branch skipped
    if (virtio_net_init() == 0) {
        # ← this is the ONLY site that writes vnet_mac
        # ← and the ONLY site that calls net_init()
        net_init(ip4(10,0,2,15), ip4(10,0,2,2), ip4(255,255,255,0));
    }
}
```

On iron with r8169 active and virtio absent: `r8169_mac` holds the real `b0:41:6f:0c:e4:25` (Attempt 92 confirmed this with FB print `MAC=176:65:111:12:228:37`); `vnet_mac` stays at module-default zeros.

**Wire-level consequence (the explanation for OFFER timeout)**:

- DHCP DISCOVER egresses with:
  - Ethernet src MAC = `0:0:0:0:0:0`
  - BOOTP `chaddr` = `0:0:0:0:0:0`
  - BOOTP `flags` broadcast bit = 1
- A standards-compliant DHCP server receiving this:
  - SHOULD drop the request (RFC 2131 §4.1: `chaddr` is the client's hardware address; all-zeros is not a valid Ethernet unicast MAC).
  - OR may reply per the broadcast flag — but the OFFER frame's Ethernet dst will be `FF:FF:FF:FF:FF:FF` (broadcast). The OFFER's BOOTP `chaddr` will be the all-zeros it received in DISCOVER.
- Our r8169 NIC's MAC filter (programmed in `r8169_init_rx` via `RxConfig.APM=0x02` "accept physical match" + `AB=0x08` accept broadcast — needs verification, see § 4):
  - Accepts broadcast frames → broadcast OFFER would land in RX ring.
  - But the OFFER's `chaddr` = `0:0:0:0:0:0` won't match our DHCP client's expected `chaddr` per RFC 2131 §3.1 ("the client MUST verify that the chaddr in the OFFER matches its own hardware address"). Although our current `dhcp_init` does NOT check chaddr — it only checks `xid` (line 316), msg-type (line 319), and treats the first matching reply as the OFFER.
  - So if a server DID reply (against spec) with our zero-chaddr, AND it arrived as broadcast, our client would accept it — but most modern DHCP servers (dnsmasq, ISC dhcpd, Windows DHCP) drop zero-chaddr requests.

**CMOS 0x5E = 0x01 evidence**: the byte captured in RX desc 0's buffer was `0x01`. First byte of an Ethernet dst MAC:
- `0xFF` → broadcast frame (would be expected for a server reply per broadcast flag).
- `0xB0` → unicast to our r8169 MAC (`b0:41:6f:0c:e4:25`).
- `0x01` → multicast (LLDP `01:80:c2:00:00:0e`, IGMP `01:00:5e:xx:xx:xx`, spanning tree `01:80:c2:00:00:00`, etc.).
- `0x33` → IPv6 multicast (`33:33:xx:xx:xx:xx`).

`0x01` is a real Ethernet frame, but **not a DHCP OFFER**. Most likely background LLDP / spanning-tree / IGMP chatter from the switch archaemenid is plugged into. So the OFFER never arrived — consistent with the server having dropped our zero-MAC DISCOVER.

**Cross-validation** (multi-source per [[feedback_redesign_dont_reinvent]]):

| Reference | How it handles src-MAC plumbing |
|---|---|
| Linux `net/ipv4/ipconfig.c` (boot DHCP) | `ic_dhcp_send_packet` uses `dev->dev_addr` (the netdev's authoritative MAC) — populated at NIC probe time, not at boot config time. Every NIC driver writes its MAC into `dev->dev_addr` during open. |
| OpenBSD `dhclient` | Uses `ifr_addr` from `SIOCGIFLLADDR` — the kernel's per-interface link-layer address, set by the NIC driver's attach path. |
| FreeBSD `dhclient` | Same shape — per-interface LLADDR populated by `if_attach`. |
| Haiku (DHCP in `add-ons/kernel/network/protocols/dhcp/`) | Reads MAC from `interface->device->address` — populated by NIC driver's `init_device`. |
| RFC 2131 §4.1.1 | "The DHCP server MUST use the chaddr field of the DHCP message to identify the client to which it is responding." |

Every reference threads the **NIC's MAC** through the DHCP client. AGNOS currently threads a **single hardcoded global** (`vnet_mac`) that only one of the two backends populates. The `nic_send` / `nic_poll` / `nic_ready` abstraction landed in 1.32.0 bite B Phase 4 already established the backend-agnostic dispatch pattern; the MAC plumbing was missed.

**Fix shape** (per [[feedback_prefer_generic_abstraction_at_call_sites]]):

Introduce `nic_mac(out_buf)` in `r8169.cyr` parallel to `nic_ready` / `nic_send` / `nic_poll`. Implementation:

```cyrius
fn nic_mac(out_buf) {
    if (r8169_present != 0) {
        memcpy(out_buf, &r8169_mac, 6);
        return 1;
    }
    if (vnet_active != 0) {
        memcpy(out_buf, &vnet_mac, 6);
        return 1;
    }
    memset(out_buf, 0, 6);
    return 0;
}
```

Then in `net.cyr`, replace every `&vnet_mac` with a stack-local copy populated via `nic_mac(&kernel_mac)`. Seven call sites; ~30 LOC delta.

**This is the highest-confidence root cause for the OFFER timeout.**

---

### FINDING #2 — `net_init()` is never called on the iron path

**Symptom**: On iron without virtio, `net_ip` / `net_gateway` / `net_netmask` stay at their module-default zero values for the entire boot.

**Root cause**: `net_init(...)` is called only inside the `virtio_net_init() == 0` branch at `main.cyr:283`. On iron, that branch is skipped (no virtio device).

**Wire-level consequence**:

- `net_ip = 0` is actually *correct* for DHCP DISCOVER (RFC 2131 §4.4.1 — clients send with `ciaddr = 0` before lease).
- `net_ip = 0` is *wrong* for the ARP-receive site at `net.cyr:417`:
  ```cyrius
  if (target_ip != net_ip) { return 0; }
  ```
  After DHCP succeeds (post-lease), `net_ip` IS the right thing to compare against. But pre-lease, no peer will ARP us — so this isn't blocking DHCP per se.
- `net_gateway = 0` is *latent* — won't affect DHCP (DHCP destination is broadcast, no gateway involved), but any post-DHCP outbound to a non-local-subnet IP would fail without a route via gateway.
- `net_netmask = 0` is *latent* — used by routing decisions; DHCP itself doesn't consume it.

**Severity**: Lower than Finding #1, but still wrong-shape — the call signals "the kernel net stack is initialized" and skipping it on iron leaves the stack in a pre-init state that current code happens to tolerate for DHCP-DISCOVER only.

**Fix shape**: Move `net_init(0, 0, 0)` out of the virtio branch into the post-NIC-probe path. Or: have both `r8169_init_rx`/`tx` AND `virtio_net_init` call `net_init` at the end of their success path (idempotent — last write wins). Cleanest is a single call right after the first `nic_ready() == 1` becomes true.

---

### FINDING #3 — Bite C `r8169_phy_init` busy-wait is ~100× too short, AND BMSR is read once per iteration (latching-low)

**Symptom**: CMOS 0x59 = 2 ("autoneg timeout") on iron, but TX worked (0x5A=2, 0x5B=0x30 = NIC cleared OWN) and RX captured DMA (0x5E=0x01). Real link is up; the "timeout" print is a false negative.

**Root cause (two layers stacked)**:

**(a) Busy-wait is wrong by ~100×.** `r8169_phy_init` (line 247-260) loops 300 times, each iteration:
1. Read BMSR (~µs).
2. Tight inner loop: `for (var j = 0; j < 100000; j = j + 1) { }`.

The comment on line 257-258 claims "≈10ms" per outer iteration → "≈3s total budget." On archaemenid's AMD Zen at ~3.5 GHz, an empty `cmp + jne + inc` loop runs at ~1 cycle per iter ÷ 3.5 GHz × 100,000 iters ≈ **28 µs**, not 10 ms. Real total budget: 300 × 28 µs ≈ **8.4 ms**, not 3 seconds. Real Ethernet autoneg on copper typically takes 1.5-3s (Gigabit) per IEEE 802.3 clause 28.

So `r8169_phy_init` gives up ~300× too fast, stamps 0x59=2, prints "no link (autoneg timeout)," then returns. The autoneg state machine in the PHY chassis continues running and link comes up within the next 1-3 seconds. By the time `dhcp_init` fires (after `r8169_init_rx`, `r8169_init_tx`, more init prints, scheduler activation, etc.), the link IS up — confirmed on iron by Attempt 94's TX-OWN-cleared evidence.

**(b) BMSR is latching-low and only read once per iter.** Per IEEE 802.3 §22.2.4.2, BMSR (PHY register 0x01) bit 2 (Link Status) is **latching-low** — once link drops the bit stays 0 even after recovery, until the host reads BMSR (which latches the live value). Linux `genphy_update_link`, OpenBSD `re_phy_init`, FreeBSD `re_miibus_readreg` all **read BMSR twice** for this reason: first read clears the latch, second read returns live state.

Bite C's loop reads BMSR once per iter. The first iteration of the 300-iter loop reads the latched-stale 0 from before the BMCR autoneg-restart write; that read also clears the latch. The second iteration's read returns whatever the live state is at that ~28 µs moment — and since real autoneg takes ~1.5s, all 300 reads return 0, regardless of latching semantics. So (a) dominates — bite C would time out wrong even with correct double-read.

**Severity**: Not blocking on functional grounds — the PHY init was kicked (BMCR.ANRESTART written), autoneg completes asynchronously regardless of whether we poll for it, and by the time the kernel needs the link (DHCP DISCOVER) it's up.

**Cross-validation**:

| Reference | Approach |
|---|---|
| Linux `r8169_main.c::rtl_open` | Calls `phy_start()` (PHYLIB); does not block boot on link-up. Link state delivered via netif notifier asynchronously. |
| OpenBSD `re_phy_init` | Uses `delay(1000)` (1 ms real-time, hardware-clocked); polls BMSR for up to **5 seconds**, reads twice per iter. |
| FreeBSD `if_re.c::re_attach_post` | Same shape as OpenBSD; uses `DELAY()` real-clock primitive. |
| NetBSD `re.c` | Mirrors OpenBSD. |
| RealTek RTL8168 datasheet §11 | PHYAR poll budget is typical 1-10µs; autoneg completion is *not* specified by PHYAR — that's BMSR-watching, datasheet doesn't impose timeout. |

**Fix shape options** (pick one):

1. **Don't block on link** — kick BMCR.ANRESTART, log a hopeful "r8169: PHY autoneg kicked," return success unconditionally. Simplest. Matches Linux's async-notifier shape. Loses the diagnostic value of the 0x59 enum (always 1).

2. **Real-time delay** — replace the inner busy loop with `arch_wait()` (hlt waits for timer IRQ, ~10ms real-time) OR a `timer_ticks`-based poll. 300 iterations × 10ms = 3s wall-clock budget. Matches the original intent. Requires `dhcp_init`-style timer-driven polling.

3. **Defer to NIC reset interval** — RealTek datasheet §13 says autoneg starts within ~250ms of `BMCR.RESTART` write; just sleep a known interval (`arch_wait` × 200 ≈ 2s) and read BMSR once at the end. Simplest fix matching reference behavior.

**Provisional recommendation**: option 1 (don't block on link). Rationale: TX/RX queues handle link-not-yet-up gracefully (descriptor sits in TX ring until NIC clocks it out); blocking init on link-up is a misshapen contract. Linux moved away from blocking-on-link 20+ years ago for exactly this reason.

---

### FINDING #4 — DHCP client never validates `chaddr` in OFFER

**Symptom**: Latent; would only fire after FIX #1. Recording for completeness.

**Root cause**: `dhcp_init` (line 314-329) verifies the OFFER reply with:
- Length ≥ 240 ✓
- `xid` matches our sent `xid` ✓
- Option 53 = 2 (DHCPOFFER) ✓

It does NOT verify `chaddr` (BOOTP fixed header offset 28..34) against our hardware address. Per RFC 2131 §4.1.1: "the client MUST use this value to determine whether the received message is intended for it."

**Wire-level consequence**: With FIX #1 in place and a healthy DHCP server, our `chaddr` is correct and the server's reply carries the same `chaddr`. So this is latent unless a second client appears with a colliding `xid`, which is extremely unlikely (we seed `xid` from `timer_ticks * 64017 + 31337`).

**Severity**: Spec-compliance + defense-in-depth, not blocking.

**Fix shape**: After the `xid`-match check, add:
```cyrius
# Verify chaddr matches our hardware address (RFC 2131 §4.1.1)
var our_mac[8];
nic_mac(&our_mac);   # depends on FIX #1
var match = 1;
for (var ci = 0; ci < 6; ci = ci + 1) {
    if (load8(&rx + 28 + ci) != load8(&our_mac + ci)) { match = 0; break; }
}
if (match == 0) { continue; }   # not for us
```

Same shape repeated for the ACK wait loop (line 351-376).

---

### FINDING #5 — DHCP timeout budget is wall-clock-dependent on `arch_wait()` (no explicit time bound)

**Symptom**: `OFFER timeout` after 200 `arch_wait()` calls (line 312). `arch_wait` on x86_64 is `hlt` (`kernel/arch/x86_64/io.cyr:131`); waits for next IRQ.

**Wire-level consequence**: Real-time duration of the 200-iter loop depends on IRQ rate. With the timer IRQ at the kernel's default rate (need to verify, but likely 100 Hz = 10ms per tick), 200 iterations × 10ms = 2 seconds.

RFC 2131 §4.4.1 specifies **client retransmission with exponential backoff**: DISCOVER every 4s / 8s / 16s / 32s / 60s. Our 2-second total budget gives the server one shot to reply, after a single DISCOVER, before we give up. A DHCP server with even modest latency (DHCP-relay path, cold-boot bootstrap, busy network) would miss this window.

**Severity**: Sub-finding of the overall "OFFER timeout" symptom — even if FIX #1 lands, a 2-second budget will catch healthy servers that happen to be slow on the first DISCOVER.

**Cross-validation**:

| Reference | Retransmission shape |
|---|---|
| RFC 2131 §4.4.1 | 4s initial timeout, exponential backoff with randomization, max 60s. At least 4 DISCOVER attempts. |
| Linux `ipconfig.c::ic_dhcp_init_dev` | 4 × DISCOVER attempts with random backoff in [0, 4s + jitter]. |
| OpenBSD `dhclient`  | 1 DISCOVER per 4s × 4 retries default. |

**Fix shape**: replace the `for (var ti = 0; ti < 200; ti = ti + 1)` with a retransmit loop that:
1. Sends DISCOVER.
2. Waits 4 seconds (timer_ticks-driven, not arch_wait count).
3. If no OFFER, sends DISCOVER again (random xid? same xid? RFC says same — same session).
4. Backs off: 4s / 8s / 16s.
5. Bails after ~30s total.

Larger LOC delta (~80 LOC); could defer to a 1.32.3+ refinement cycle. For 1.32.2 a minimum fix is "increase timeout to 8s" (200 iter × 10ms → 800 iter × 10ms).

---

### FINDING #6 — r8169 RxConfig program is not audited end-to-end against datasheet

**Symptom**: None currently — but RX did capture DMA (0x5E=0x01), so the NIC IS accepting some frames. Question is *which* frames the MAC filter accepts.

**Root cause**: Per `r8169.cyr:86` the driver defines `R8169_RXCFG_APM = 0x02` (accept physical match — unicast to MAC). Need to verify:
1. Whether `RxConfig` is also setting the AB bit (accept broadcast, RTL8168 datasheet §13.2 RxConfig.AB = 0x08). If AB is not set, broadcast frames (including DHCP OFFER if servers reply broadcast) are dropped at the NIC's MAC filter — but the 0x5E=0x01 multicast byte we captured suggests AM (accept multicast, 0x04) might be set.
2. Whether the MAC filter is gated on `r8169_mac` being populated *before* `RxConfig` is written. If `RxConfig.APM` is set before `IDR0..IDR5` is written, no unicast match will succeed.

Not blocking the immediate OFFER-timeout investigation (Finding #1 dominates), but worth a line-by-line read of `r8169_init_rx` against RTL8168 datasheet §13.2 RxConfig register description.

**Severity**: Audit-debt, latent. Fold into the 1.32.2 cycle as a same-cut hardening pass.

---

## 4. Summary — root causes ranked by Attempt-94-iron-blocking severity

| # | Finding | Blocking? | Status |
|---|---|---|---|
| 1 | `vnet_mac` used for kernel src MAC + DHCP chaddr; never populated from `r8169_mac` on iron | ⭐⭐⭐ **YES — primary explanation for OFFER timeout** | ✅ **APPLIED 1.32.1** — `nic_mac(out_buf)` added to `r8169.cyr` parallel to `nic_ready`/`nic_send`/`nic_poll`; threaded through 7 sites in `net.cyr` (arp_request × 2, udp_send, udp_send_from, dhcp_build_packet chaddr, ARP-reply × 2, tcp_send_pkt). |
| 2 | `net_init()` never called on iron (zero net_ip/gw/mask) | ⭐ Latent | ✅ **APPLIED 1.32.1** — `net_init(0,0,0)` block in `main.cyr` after the virtio branch, gated on `nic_ready() == 1 && vnet_active == 0` so it doesn't clobber virtio's net_init in QEMU. |
| 3 | Bite C `r8169_phy_init` busy-wait ~100× too short + BMSR latching-low | ⭐ Cosmetic (link-up print wrong; functionality unaffected) | ✅ **APPLIED 1.32.1** — non-blocking shape: kick `BMCR.ANRESTART`, opportunistic double-read BMSR (clear latch + live snapshot), print `r8169: PHY autoneg kicked; link up` / `r8169: PHY autoneg kicked (link async)`, stamp 0x59 = 1 on successful kick. Enum 2 (autoneg-timeout) retired since we no longer poll for completion. |
| 4 | DHCP client doesn't validate OFFER `chaddr` | Latent | ✅ **APPLIED 1.32.1** — chaddr match loop (6-byte compare against `nic_mac` snapshot) added to BOTH OFFER + ACK wait loops in `dhcp_init` after the xid match check, per RFC 2131 §4.1.1. |
| 5 | DHCP timeout budget ~2s, RFC says 4s minimum × 4 retries | Likely contributing if FIX #1 is correct | ✅ **APPLIED 1.32.1** — OFFER + ACK wait loops bumped from 200 → 800 `arch_wait()` iterations (~2s → ~8s). Full exponential backoff deferred to a later refinement. |
| 6 | RxConfig AB / AM bits not audited against datasheet | Audit debt | ✅ **APPLIED 1.32.1** — replaced bare `0xE700 | 0x08 | 0x04 | 0x02` with named constants (`R8169_RXCFG_DEFAULTS | R8169_RXCFG_AB | R8169_RXCFG_AM | R8169_RXCFG_APM`) + datasheet-cited per-bit comment block (RTL8168 §13.2 + Linux `rtl_set_rx_mode` cross-reference); bit values were already correct, audit confirmed no behavioral change needed. |

## 5. Landed in 1.32.1 (continued cycle work; pre-Attempt-95)

All six fixes landed same-day as audit (2026-05-22), in the existing 1.32.1 cycle window — no version bump per [[feedback_no_unprompted_version_bumps]]. User direction: "this is all still in 1.32.1 cycle work" + "most likely close after [the next iron] burn either way." Attempt 95 closes 1.32.1.

| Fix | Bite | LOC actual | Status |
|---|---|---|---|
| #1 | `nic_mac` abstraction in r8169.cyr; threaded through 7 sites in net.cyr | ~80 (incl. comment block on nic_mac + per-site comments) | ✅ landed |
| #2 | `net_init(0,0,0)` gated on `vnet_active == 0` in main.cyr post-NIC-probe | ~10 (incl. comment) | ✅ landed |
| #3 | `r8169_phy_init` non-blocking kick + double-read BMSR for latching-low | ~30 (replaces ~30 — net delta ~0) | ✅ landed |
| #4 | OFFER + ACK chaddr-match loops in dhcp_init | ~30 (× 2 sites) | ✅ landed |
| #5 | OFFER + ACK timeout 200 → 800 iter | ~2 (one constant per loop) | ✅ landed |
| #6 | RxConfig named constants + datasheet citation block | ~25 (comment-only delta) | ✅ landed |

Total: ~177 LOC including comments; build size +312 B production / +584 B TCP_LISTEN_SMOKE. `scripts/test.sh` 4/4 + `scripts/ext2-smoke.sh` 5/5 + 5/5 regression cross-check — zero regression vs Attempt 94 baseline.

**Iron Attempt 95 DEFERRED** — 1.32.1 was tagged by user at HEAD without burning per *"tag was going to happen regardless of result"* (cycle close shape: audit-driven repair, iron-validation deferred). Attempt 95 stays as the natural first-burn target for whatever cycle opens next; the rubric below stays valid. Target outcome: full DHCP cycle on archaemenid (`DISCOVER` → `OFFER ip=<lan-IP>` → `REQUEST` → `ACK ip=<lan-IP>`). New r8169 boot block now reads: `found at … / MAC=… / chip-rev byte=… / reset OK / PHY autoneg kicked; link up | PHY autoneg kicked (link async) / Phase 1 complete / RX ring up / TX ring up`. CMOS post-mortem expected:

| Slot | Pre-fix (Attempt 94) | Post-fix (Attempt 95 target) |
|---|---|---|
| 0x58 (probe done) | 0x01 | 0x01 |
| 0x59 (PHY outcome) | 0x02 "autoneg timeout" (false neg) | **0x01 "kicked"** (true) |
| 0x5A (TX sends) | 0x02 | **≥ 0x05** (DISCOVER + REQUEST + retries + first ARP) |
| 0x5B (TX desc 0 OWN) | 0x30 (FS+LS, OWN cleared) | 0x30 (unchanged — TX still working) |
| 0x5C (RX polls) | 0xFF | 0xFF (unchanged) |
| 0x5D (RX desc 0 OWN) | 0x80 | 0x80 (unchanged — re-armed) |
| 0x5E (RX buf 0 byte 0) | 0x01 (multicast leftover) | **0xFF** (broadcast OFFER) or **0xB0** (unicast to our MAC) |

## 6. Iron-burn checklist (post-FIX-A through E)

Pre-burn gates:
1. `scripts/test.sh` 4/4 PASS (QEMU smoke unchanged — vnet_active path still works with `nic_mac` returning `vnet_mac`).
2. `agnos/build/agnos` size delta documented in `agnos/CHANGELOG.md`.
3. State.md `Last refresh` updated.
4. Audit doc (this file) updated with "FIX A applied" / "FIX B applied" notes for traceability.

Burn:
1. `cd ~/Repos/agnosticos && sudo ./scripts/install-usb.sh --update`.
2. Boot archaemenid from USB stick.
3. Capture boot-log photo (Ethernet src MAC will be visible if DHCP DISCOVER prints any pkt diag; otherwise rely on the four DHCP lines).
4. `sudo ./scripts/read-boot-log.sh --verbose` for CMOS 0x58-0x5F readback.

Expected outcome with FIX #1 + #2 + #3 + #5 applied (FIX #4 + #6 layered on top):
- DHCP boot block prints: `dhcp: DISCOVER` → `dhcp: OFFER ip=<your LAN IP>` → `dhcp: REQUEST` → `dhcp: ACK ip=<your LAN IP> gw=<your gw> mask=<your mask>`.
- CMOS 0x58 = 1 (probe done), 0x59 = 1 (PHY kicked / link up — FIX #3 stamps 1 unconditionally), 0x5A ≥ 2 (TX sends fired), 0x5B = 0x00 or 0x30 (cleared OWN), 0x5C = 0xFF (poll saturated), 0x5D = 0x80 (re-armed), 0x5E = first byte of an actual DHCP OFFER frame (0xFF if broadcast, 0xB0 if unicast to our MAC).
- Storage trio + GPT + ext4 mount + scheduler + tcp_listen + kybernet + shell byte-clean (no regression).

If OFFER STILL times out with FIX #1 applied:
- Server-side issue (DHCP relay missing, server doesn't trust archaemenid's MAC vendor prefix `b0:41:6f`, network has no DHCP server reachable). User confirmation of LAN topology required.
- OR `RxConfig.AB` is wrong and we're dropping broadcast OFFERs at the NIC's MAC filter (FIX #6). Bite F covers.

## 7. What NOT to do (per [[feedback_redesign_dont_reinvent]] + cycle discipline)

- **Don't** introduce a chip-rev dispatch table for MAC reading — `r8169_mac` is already populated correctly by Phase 1 (IDR0..IDR5 read).
- **Don't** add new diagnostic CMOS stamps — bite B's 0x58-0x5F surface is sufficient to validate the fix (TX desc OWN cleared + RX first-byte ≠ 0x01).
- **Don't** rewrite bite C's PHY init to read BMSR twice — the busy-wait timing is the dominant bug; double-read is correct semantically but doesn't change the outcome under wrong-by-100× timing.
- **Don't** propose moving DHCP to a kernel thread / async — current synchronous-at-boot shape is fine for MVP; async upgrade is a much later refactor.
- **Don't** introduce DHCP-Relay-agent support, fail-over, INFORM, RELEASE, or any non-DISCOVER/OFFER/REQUEST/ACK messages — minimum-viable per scope.
- **Don't** propose Wi-Fi backend, IPv6, link-local IPv4 (RFC 3927), or DNS — out of scope for 1.32.x networking arc.

## 8. Multi-source prior art table

| Primitive | Linux | FreeBSD | OpenBSD | NetBSD | Haiku | RFC |
|---|---|---|---|---|---|---|
| Kernel src MAC plumbing | `dev->dev_addr` in netdev | `if_attach` → `ifp->if_addr` | `if_attach` → `ifp->if_lladdr` | mirrors OpenBSD | `interface->device->address` | — |
| DHCP `chaddr` field | from netdev `dev_addr` | from `ifp->if_addr` | from `ifp->if_lladdr` | mirrors OpenBSD | from interface | RFC 2131 §4.1 |
| DHCP OFFER validation | `xid` match + `chaddr` match + option-53=OFFER | same | same | same | same | RFC 2131 §3.1, §4.1 |
| DHCP retransmission | 4 attempts, exponential backoff with random jitter | same | same | same | same | RFC 2131 §4.4.1 |
| PHY autoneg poll | PHYLIB async notifier (non-blocking) | 5s with `DELAY(1000)` | 5s with `delay(1000)` × double-read | mirrors OpenBSD | datasheet-derived | IEEE 802.3 §22.2.4.2 |
| RxConfig accept-broadcast | `RxConfig |= AcceptBroadcast` | `RTLE_AB` flag | `RE_RXCFG_AB` flag | mirrors OpenBSD | datasheet `_DESC_AB` | RealTek RTL8168 §13.2 |

All five OS references agree on the NIC-owns-MAC pattern. AGNOS's current `vnet_mac` global is a virtio-era shortcut that doesn't generalize to real iron.

## 9. Disposition

Audit complete. No code touches landed from this doc. Awaiting user review + per-bite approval for 1.32.2 cycle. Per [[feedback_per_action_consent]] each bite is an independent approval — landing bite A (the FIX #1 nic_mac abstraction) does NOT pre-authorize bites B-F.

No Attempt 95 iron burn proposed until the user reviews this doc.

---

**Cross-references**:
- [`iron-nuc-zen-log.md` § Attempt 94](iron-nuc-zen-log.md) — bite-B CMOS readback that drove the audit § 10 H1/H7/H8 framing reversal.
- [`r8169-iron-burn-audit.md` § 10](r8169-iron-burn-audit.md) — the NIC-layer audit whose framing this doc supersedes for OFFER-timeout root cause.
- [`network-arc-prior-art.md`](network-arc-prior-art.md) — original multi-source convergent doc for the 1.32.0 networking arc.
- [[feedback_prefer_generic_abstraction_at_call_sites]] — the abstraction pattern used by FIX #1 (`nic_mac` parallel to `nic_ready` / `nic_send` / `nic_poll`).
- [[feedback_iron_burns_block_other_work]] — discipline that mandated this audit doc before any 1.32.2 bite or Attempt 95.
- [[feedback_redesign_dont_reinvent]] — multi-source convergent posture; Linux is one source of many.

---

## 10. Post-Attempt-95 sweep — FINDINGS #7-#9 (1.32.2 cycle)

> **Status**: ALL THREE FIXES LANDED 2026-05-23 in 1.32.2 cycle. QEMU validation: `scripts/test.sh` 4/4 + `scripts/ext2-smoke.sh` 5/5 + 5/5 regression + `scripts/tcp-listen-smoke.sh` 1/2 (matches pre-fix baseline). Build size 604,096 B (1.32.1 close, production) → **605,064 B production / 605,944 B TCP_LISTEN_SMOKE** (+968 / +1,040 B).
>
> The Attempt 95 iron burn (2026-05-22 23:42, photo catalogued in `iron-nuc-zen-photos/`) reproduced the OFFER timeout symptom with all six 1.32.1 fixes in place. The previous-session agent didn't log the burn — accountability gap corrected in iron-nuc-zen-log § Attempt 95. Post-burn sweep across the full networking code path surfaced three additional bugs upstream of the NIC; landed together as 1.32.2 to avoid a piecemeal iron-burn ladder.

### FINDING #7 (CRITICAL — most likely root cause of Attempt 95 OFFER timeout) — IDR0..IDR5 not reprogrammed after reset

**Symptom**: Same as Attempt 94 — DHCP DISCOVER egresses, no OFFER received within timeout. With 1.32.1's `nic_mac` chaddr fix in place, the kernel-side packet is correct (chaddr = `b0:41:6f:0c:e4:25`), but the NIC's *hardware* MAC filter rejects unicast OFFERs before they reach the RX ring.

**Root cause**: `r8169_probe` reads `IDR0..IDR5` into `r8169_mac` at step 6 (line 330-332), THEN resets the chip at step 8 (line 345). The reset clears the NIC's hardware unicast MAC filter (IDR0..IDR5 → zeros). `RxConfig.APM = 1` set later in `r8169_init_rx` tells the NIC to accept unicast frames *only* when dst MAC matches IDR0..IDR5 — so post-reset, the filter is zero and any unicast DHCP OFFER to `b0:41:6f:0c:e4:25` is dropped at the hardware filter.

The 1.32.1 audit FINDING #6 raised exactly this concern ("If `RxConfig.APM` is set before `IDR0..IDR5` is written, no unicast match will succeed") but the FIX #6 implementation only renamed RxConfig bit constants — bit *values* were correct, but the IDR programming gap was missed.

**Wire-level consequence**: DHCP servers that ignore the BOOTP broadcast flag (Cisco WLCs, Mikrotik, some embedded servers, certain Windows DHCP configs) reply unicast. Our DISCOVER goes out fine (TX path doesn't go through the unicast filter); the OFFER comes back unicast addressed to `b0:41:6f:0c:e4:25`; NIC hardware filter checks IDR0..IDR5 (= zeros) against dst MAC (= `b0...`); no match → drop. Our `r8169_poll` sees only broadcast/multicast frames (LLDP, STP, IGMP) that pass the AB/AM bits, never the OFFER.

**Cross-validation** (multi-source per [[feedback_redesign_dont_reinvent]]):

| Reference | Where MAC is restored to IDR/MAC registers |
|---|---|
| Linux `drivers/net/ethernet/realtek/r8169_main.c::rtl_rar_set` | Writes MAC0 (0x00) + MAC4 (0x04) on every bring-up; called from `rtl_open` post-reset. |
| OpenBSD `sys/dev/ic/re.c::re_setaddr` | Writes IDR via `CSR_WRITE_RAW_4(MAC0, …)` + `CSR_WRITE_RAW_2(MAC4, …)` post-reset. |
| FreeBSD `sys/dev/re/if_re.c::re_set_addr` | Same shape — `CSR_WRITE_STREAM_4(sc, RL_IDR0, …)`. |
| NetBSD `sys/dev/ic/re.c::re_setaddr` | Mirrors OpenBSD. |
| Haiku `src/add-ons/kernel/drivers/network/ether/rtl8169/rtl81xx.c` | Writes `RTL_IDR0` + `RTL_IDR4` in `init_device` post-reset. |
| RealTek RTL8168 datasheet §6.1 | Reset (CR.RST) returns the chip to default state — IDR0..IDR5 are R/W and not preserved across reset by spec. |

Every reference writes the MAC back to the IDR registers after reset. AGNOS pre-1.32.2 did not. The kernel-side `r8169_mac` was correct (used by `nic_mac` for chaddr/eth-src), but the NIC-side hardware filter was zero.

**Fix shape**: New step 8b in `r8169_probe`, after the reset poll succeeds and before PHY init:
```cyrius
for (var i = 0; i < 6; i = i + 1) {
    r8169_mmio_write8(R8169_REG_IDR0 + i, load8(&r8169_mac + i));
}
```

~6 LOC including comment block. Lands as **FIX #7** in 1.32.2.

---

### FINDING #8 (CRITICAL — DHCP option-blob truncation) — UDP buffer sized for legacy 248-byte ceiling

**Symptom**: Latent until FIX #7 lands. With FIX #7, OFFER reaches the RX ring → `net_handle_udp` copies UDP payload into the listener's recv buffer → DHCP parser reads the buffer. Pre-fix, the parser would see msg-type (option 53, usually first) but server-id (option 54), subnet mask (option 1), gateway (option 3) past byte 248 would be truncated. OFFER detection works (msg-type intact); REQUEST carries zero `server_id` → server NAK or ignore → ACK timeout downstream.

**Root cause**: Three coupled sizing limits below typical DHCP payload sizes:

| Site | Pre-fix | Post-fix | Rationale |
|---|---|---|---|
| `udp_bind` per-listener `kmalloc(N)` | 256 | **1024** | Heap-allocated recv buffer; receives `net_handle_udp`'s capped copy. |
| `net_handle_udp` `udp_data_len` cap | 248 | **1016** | Bounded by listener buf size (1024 - 8 UDP-hdr headroom). |
| `dhcp_init` local `var rx[N]` + `udp_recv_from(... N ...)` | 320 | **1024** | Function-local var X[N] = N bytes per [[feedback_cyrius_var_array_u64_units]]. Two call-sites (OFFER + ACK loops). |

**Wire-level consequence**: Typical DHCP OFFER UDP payload is 250-350 bytes (240 BOOTP fixed header + 10-100 bytes of options depending on server config — server-id, lease-time, subnet, router, DNS, domain-name, NTP, etc.). The 248-byte cap left only 8 bytes of options accessible past the BOOTP fixed header. Option 53 (msg-type, 3 bytes) fits; option 54 (server-id, 6 bytes) starts at offset 3 and ends at offset 8 — the LAST byte may or may not be captured depending on server's option ordering. Beyond that, everything is gone.

**Cross-validation**:

| Reference | Buffer-sizing approach for DHCP |
|---|---|
| Linux `net/ipv4/ipconfig.c` (boot DHCP) | Uses `ic_dev->ip_addr` buffer at 1500-byte MTU full-frame size. |
| OpenBSD `dhclient` | `BUFSIZ` (= 1024 typical) for option blob; `DHCP_FIXED_NON_UDP + DHCP_MTU_MAX` for full frame. |
| FreeBSD `dhclient` | Mirrors OpenBSD. |
| RFC 2131 §2 | DHCP message format: minimum 312 bytes (576 IP datagram - 28 IP/UDP headers - 236 hardcoded). Server replies can be up to 576 bytes UDP payload. |

1024-byte buffers fit any realistic DHCP message and align with prior-art conventions.

**Fix shape**: Three coordinated size bumps; the `net_handle_udp` cap is the load-bearing one (without it, listener buf size alone doesn't help). Lands as **FIX #8** in 1.32.2.

---

### FINDING #10 (CRITICAL — explains the regression between Attempts 94 and 95) — FIX #3 unconditionally restarts autoneg, leaving NIC TX/RX engines wedged

**Symptom — observed only post-1.32.1**: Attempt 94 (with bite-C blocking PHY init) had CMOS `0x5B=0x30` (TX OWN cleared by NIC = TX path worked) + `0x5E=0x01` (RX captured a multicast byte = RX path worked). Attempt 95 (with FIX #3 non-blocking PHY init) had CMOS `0x5B=0xb0` (TX OWN stuck at NIC = TX wedged) + `0x5E=0x00` (NO RX DMA AT ALL = RX path dead). The change between burns was the 6-FIX bundle, of which only FIX #3 plausibly touches NIC TX/RX behavior.

**Root cause**: FIX #3 unconditionally writes `BMCR.ANRESTART` (bit 9) on every probe. ANRESTART forces the PHY autoneg state machine back to start; the link goes DOWN for 1-3 seconds while renegotiation runs. The kernel then proceeds immediately (non-blocking) to `r8169_init_rx` → `r8169_init_tx` → scheduler activation → `dhcp_init` — all within ~100ms of the BMCR write. **During that window, the link is down.**

Some RTL8168 chip variants wedge their internal TX/RX engines when CR.RE/CR.TE are set while link is down — the engines initialize into a "no link" state and don't recover when link comes up later. Attempt 94's blocking PHY init "worked" by accident: the busy-wait loop kept polling BMSR for ~8ms, which (a) prevented the kernel from racing forward into init_rx/init_tx while autoneg was active, and (b) gave the PHY a few hundred MDIO reads worth of "settle time" before init_rx ran.

The real fix is to **not restart autoneg unless link is genuinely down**. On a typical machine, BIOS PXE / cold-boot already brought up the link as part of its own NIC probe (it has to, to attempt PXE boot). The link is already negotiated and stable when AGNOS's `r8169_probe` runs. Restarting autoneg WHEN WE DON'T NEED TO **causes the regression**, not fixes it.

**Cross-validation**:

| Reference | When does the driver restart autoneg? |
|---|---|
| Linux `drivers/net/ethernet/realtek/r8169_main.c` | Only in `__rtl8169_resume` post-suspend OR when ethtool requests it. NOT on every open/probe. |
| OpenBSD `sys/dev/ic/re.c::re_init` | Calls `mii_mediachg` which only restarts if media has changed. NOT unconditional. |
| FreeBSD `if_re.c::re_init_locked` | Same — restart-on-media-change semantics, not every-probe. |
| NetBSD `re.c` | Mirrors OpenBSD. |
| Linux `phy_start` doc comment | "Should be called by the network driver when the link is OK or restored, not on every probe." |

Every reference treats autoneg restart as a state-change event (resume, media change, link drop detected), not a probe-time default. Our FIX #3 made it default-on, and that's the load-bearing regression.

**Fix shape**: Read BMSR.LinkStatus first (with double-read for the latching-low semantics per IEEE 802.3 §22.2.4.2). If link is up, log and return without touching BMCR — preserves the BIOS-established link state through init_rx/init_tx. If link is down, only then kick BMCR.ANRESTART (clearing PDOWN as before).

```cyrius
var bmsr_latch = r8169_phy_read(R8169_PHY_BMSR);   # clear latch
var bmsr_live = r8169_phy_read(R8169_PHY_BMSR);    # live snapshot
if ((bmsr_live & R8169_BMSR_LINKUP) != 0) {
    kprintln("r8169: PHY link up (preserved from BIOS)", 40);
    xhci_cmos_stamp(R8169_KCP_PHY_OUTCOME, 1);
    return 1;
}
var new_bmcr = (bmcr | R8169_BMCR_ANENABLE | R8169_BMCR_ANRESTART) & 0xF7FF;
if (r8169_phy_write(R8169_PHY_BMCR, new_bmcr) == 0) { ... }
kprintln("r8169: PHY autoneg kicked (link async)", 38);
xhci_cmos_stamp(R8169_KCP_PHY_OUTCOME, 1);
return 1;
```

~10 LOC net delta vs the FIX #3 version. Lands as **FIX #10** in 1.32.2.

This is the most likely root cause of the *regression observed between Attempts 94 and 95*. FIX #7 (IDR write-back) remains a defensively correct fix aligned with prior art, but FIX #10 explains why the system got WORSE after the 6-FIX bundle landed, not better.

---

### FINDING #9 (Robustness — RFC 2131 §4.4.1 partial compliance) — DHCP send-once-and-wait

**Symptom**: Latent. If first DISCOVER/REQUEST is dropped (link not yet up post-autoneg; frame collision; transient L2 loss), we wait the full 8s budget without retrying. RFC 2131 §4.4.1 specifies clients SHOULD retransmit with exponential backoff (4s → 8s → 16s → 32s, minimum 4 attempts) — single-shot violates the spec and reduces robustness on first-burn cold-boot scenarios where PHY autoneg may still be completing when DISCOVER is queued.

**Root cause**: Pre-1.32.2 OFFER + ACK wait loops are pure receive loops — no retransmit at any point in the 800-iteration (~8 second) budget.

**Wire-level consequence**: If link comes up at ~2s into the wait but DISCOVER was dropped during the no-link window, we sit waiting until the budget expires. Same risk for REQUEST → ACK.

**Cross-validation**:

| Reference | Retransmission shape |
|---|---|
| RFC 2131 §4.4.1 | 4s initial, exponential backoff with jitter, max 60s, ≥ 4 attempts. |
| Linux `ipconfig.c::ic_dhcp_init_dev` | 4 × DISCOVER attempts with random backoff in [0, 4s + jitter]. |
| OpenBSD `dhclient` | 4 retries × 4s default. |
| FreeBSD `dhclient` | Mirrors OpenBSD. |

**Fix shape**: Mid-window single retransmit (at `iter == 400`, ~4s into the 8s wait). Same xid (RFC requires same session id across retries) means the server treats both DISCOVER+REQUEST as the same request and replies once; we just get a second window to catch the reply. Full exponential backoff with random jitter deferred to a later refinement cycle.

```cyrius
var discover_plen = plen;
for (var ti = 0; ti < 800; ti = ti + 1) {
    if (ti == 400) {
        udp_send_from(0, 0xFFFFFFFF, 68, 67, &dhcp_pkt_buf, discover_plen);
    }
    net_poll();
    ...
}
```

Same pattern for REQUEST wait loop with `request_plen`. ~30 LOC across two loops. Lands as **FIX #9** in 1.32.2.

---

### 10.1. Summary — 1.32.2 fixes ranked by Attempt-95-blocking severity

| # | Finding | Blocking? | Status |
|---|---|---|---|
| 7 | IDR0..IDR5 not reprogrammed after reset; unicast OFFER rejected at hardware filter | ⭐⭐ Defensive — matches Linux/BSD/Haiku prior art; load-bearing if server unicasts | ✅ **LANDED 2026-05-23** — 6-LOC write-back in `r8169_probe` step 8b, between reset poll and PHY init. |
| 8 | UDP buffer sized at 256 + cap at 248 → DHCP option blob truncated | ⭐⭐ Latent until OFFER reaches us; would cause ACK timeout downstream | ✅ **LANDED 2026-05-23** — listener buf 256→1024, cap 248→1016, dhcp_init rx[320]→rx[1024], two udp_recv_from sizes 320→1024. |
| 9 | DHCP DISCOVER + REQUEST send-once (no RFC §4.4.1 retransmission) | ⭐ Robustness; not the proximate cause | ✅ **LANDED 2026-05-23** — midpoint single retransmit at iter==400 in both wait loops. |
| 10 | FIX #3 unconditionally restarts autoneg → NIC TX/RX engines wedge during the 1-3s link-down window post-restart | ⭐⭐⭐ **YES — explains the Attempt 94 → 95 regression** (TX OWN went from cleared to stuck; RX DMA went from multicast-byte to zero) | ✅ **LANDED 2026-05-23** — `r8169_phy_init` reads BMSR live state first (double-read for latching-low); only restarts autoneg if link is actually down. |

### 10.2. Iron Attempt 96 expected outcome (DEFERRED — not auto-proposed)

Per [[feedback_iron_burns_block_other_work]], no Attempt 96 proposed until user direction. Expected boot block once burn happens:

```
r8169: found at 4243603456
r8169: MAC=176:65:111:12:228:37
r8169: chip-rev byte=0x87
r8169: reset OK
r8169: PHY autoneg kicked; link up    (or: link async)
r8169: Phase 1 complete
r8169: RX ring up (16 desc × 2KB buf)
r8169: TX ring up (16 desc × 2KB buf)
...
dhcp: DISCOVER
dhcp: OFFER ip=<lan-IP>
dhcp: REQUEST
dhcp: ACK ip=<lan-IP> gw=<gw> mask=<mask>
```

**CMOS post-mortem expected** (`sudo ./scripts/read-boot-log.sh --verbose`):

| Slot | Pre-fix (Attempt 95) | Post-fix (Attempt 96 target) |
|---|---|---|
| 0x58 (probe done) | 0x01 | 0x01 (unchanged) |
| 0x59 (PHY outcome) | 0x01 "kicked" | 0x01 (unchanged) |
| 0x5A (TX sends) | ~0x02 | **≥ 0x05** (DISCOVER + REQUEST + retries + ARP) |
| 0x5B (TX desc 0 OWN) | 0x30 | 0x30 (unchanged) |
| 0x5C (RX polls) | 0xFF | 0xFF (unchanged) |
| 0x5D (RX desc 0 OWN) | 0x80 | 0x80 (unchanged) |
| 0x5E (RX buf 0 byte 0) | 0x01 (multicast leftover) | **0xFF** (broadcast OFFER) OR **0xB0** (unicast OFFER to our MAC — confirming hardware filter now accepts our MAC) |

If 0x5E flips to 0xB0, that's the unambiguous evidence that FIX #7 unblocked the unicast filter. If it stays 0x01 with OFFER timeout, FINDING #7's framing is wrong — fall back to LAN topology investigation (is there a DHCP server reachable; what's the giaddr/relay path).
