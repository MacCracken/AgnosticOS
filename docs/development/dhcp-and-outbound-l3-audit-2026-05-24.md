---
name: DHCP end-to-end review + outbound L3 audit + 1.32.4 test-path reshape
description: Consolidated review of DHCP code vs RFCs and multi-source prior art; identifies outbound L3 next-hop routing gap; proposes ARP→1.1.1.1→outbound-TCP test ladder for the next 1.32.4 burn
type: audit
---

# DHCP review + outbound L3 audit + test-path reshape (2026-05-24)

> **Date**: 2026-05-24 AM (post-Attempt-101, pre-Attempt-102 reshape)
> **Auditor**: Claude (Opus 4.7, 1M ctx)
> **Scope**: (a) consolidated review of the DHCP code path against authoritative standards + multi-source prior art, (b) audit of the L3 outbound (off-LAN) data-path, (c) reshape of the iron-test ladder per user direction: keep ARP confirm, add 1.1.1.1 reachability test, add outbound TCP test, **remove the inbound TCP_LISTEN_SMOKE block** (incoming connectivity is not the proof we want right now).
> **Predecessor docs** (load-bearing):
> - [`dhcp-end-to-end-audit.md`](dhcp-end-to-end-audit.md) — pre-Attempt-95 wire-up audit. All 6 findings APPLIED at 1.32.1/1.32.2.
> - [`dhcp-offer-downstream-audit.md`](dhcp-offer-downstream-audit.md) — post-Attempt-100. 10-bundle of receive-path matcher fixes (BOOTP op, magic cookie, xid byte-order, chaddr discipline) APPLIED at 1.32.4 commit `43630fc`. **Never exercised** — Attempt 101 pivoted to STATIC-IP+ARP probe and the matcher fixes did not gate.
> - [`r8169-rx-path-audit.md`](r8169-rx-path-audit.md), [`r8169-chip-init-audit.md`](r8169-chip-init-audit.md) — BSD/iPXE rewrite delivered at Attempt 100. Chip-level RX filter unblocked for broadcast.
> **Discipline**:
> - [[feedback_redesign_dont_reinvent]] — multi-source convergent, Linux is one of many.
> - [[feedback_iron_burns_block_other_work]] — NO burn proposed in this doc.
> - [[feedback_known_knowledge_first]] — leans on the two predecessor audits; does NOT re-enumerate their findings.
> - [[feedback_per_action_consent]] — code edits proposed at the end; not applied until user says go.

---

## 1. What this doc adds vs the two predecessors

The predecessors covered DHCP **receive-path** + **protocol matcher** + **chip-level RX filter** end-to-end. The user's ask ("a full end-to-end audit") combined with Attempt 101's evidence ("ARP-to-gateway timed out under STATIC-IP DHCP-bypass") surfaces three things the predecessors did not need to settle:

1. **Outbound L3 routing**: how does AGNOS pick the L2 next-hop MAC for a packet whose destination is **off-LAN** (e.g., 1.1.1.1)? Current code answers "broadcast MAC, every time" — this is the load-bearing freshly-exposed gap.
2. **ARP cache lifecycle**: there is exactly one ARP slot (`arp_cache_ip` / `arp_cache_mac`). Adequate for our minimum case (cache one gateway MAC) but only if test sequencing doesn't clobber it.
3. **Test ladder shape**: the inbound TCP_LISTEN smoke is the wrong proof for "router connected." Outbound TCP success — peer SYN+ACK delivered to us — is the correct proof, and it exercises every layer below it in transit.

The two predecessor audits remain the source of truth for everything else in the DHCP pipeline. This doc treats their findings as **applied baseline**.

---

## 2. Standards referenced (the "should we be doing X this way?" anchors)

| RFC | Title | Relevance to AGNOS code |
|---|---|---|
| **RFC 2131** | Dynamic Host Configuration Protocol | DHCP packet layout, state machine, broadcast flag, xid discipline. Already converged in predecessors. |
| **RFC 2132** | DHCP Options + BOOTP Vendor Extensions | Option encoding, magic cookie 0x63825363, options 53 (msg-type), 54 (server-id), 50 (requested-IP), 51 (lease-time), 55 (param-list). Predecessor-applied. |
| **RFC 951** | Bootstrap Protocol (BOOTP) | BOOTP message structure DHCP inherits (op, htype, hlen, hops, xid, secs, flags, ciaddr, yiaddr, siaddr, giaddr, chaddr, sname, file). |
| **RFC 826** | An Ethernet Address Resolution Protocol | ARP packet layout, request/reply opcodes (1/2), broadcast for request, unicast for reply. **Load-bearing for §3 outbound routing.** |
| **RFC 1122** | Requirements for Internet Hosts — Communication Layers | §2.3.2 ARP cache management (timeouts, MUST-vs-SHOULD on cache replacement), §3.3.1 routing table requirements, §3.3.4 destination address determination. **Defines the on-LAN-vs-off-LAN decision.** |
| **RFC 791** | Internet Protocol | IP header structure, IHL, TTL, checksum. Already implemented. |
| **RFC 793** | Transmission Control Protocol | Three-way handshake, sequence-number management. Implemented for active connect (`tcp_connect`). |
| **RFC 768** | User Datagram Protocol | UDP header structure. Implemented. |
| **RFC 894** | A Standard for the Transmission of IP Datagrams over Ethernet | Frame format, ethertype 0x0800 (IPv4), 0x0806 (ARP). Implemented. |
| **RFC 5227** | IPv4 Address Conflict Detection | ARP probe + announce on a freshly-assigned IP. Not required for MVP but defines the well-known pattern. |

**Verdict on standards**: the protocol-level discipline is fine. Receive-path matcher is RFC-tight after the 1.32.4 10-bundle. The gap is at RFC 1122 §3.3.1 — destination-address determination / next-hop selection — which AGNOS does not implement.

---

## 3. Prior-art reference points (multi-source — per [[feedback_redesign_dont_reinvent]])

**DHCP clients** (already triangulated in predecessor audits; listed here for narrative completeness):

- **Linux** kernel: `net/ipv4/ipconfig.c` (`ic_bootp_recv`, BOOTP-on-boot), `drivers/net/dhcp/` (none in modern tree — user-space lives in `dhclient`/`dhcpcd`).
- **OpenBSD** `dhcpleased(8)` — modern privsep-respecting DHCP client, source: `sbin/dhcpleased/`.
- **FreeBSD** `dhclient(8)` (ISC fork), source: `sbin/dhclient/`.
- **NetBSD** `dhcpcd(8)` (Roy Marples), source: `external/bsd/dhcpcd/`.
- **iPXE** `src/net/udp/dhcp.c` — the embedded-firmware reference. Closest cousin to AGNOS's minimal kernel-DHCP.
- **U-Boot** `net/bootp.c` (DHCPv4) — the other embedded-firmware reference.
- **busybox** `networking/udhcpc/` — minimal user-space client, useful for option-parser convergence.
- **Plan 9** `cmd/ip/dhcpclient.c` — the cleanest small client.
- **ISC dhclient** — historic reference, mostly obsolete now.

**ARP + L3 next-hop selection** (the actual fresh subject):

- **Linux** kernel:
  - `net/ipv4/route.c` — FIB lookup, full routing table.
  - `net/ipv4/arp.c` — `arp_solicit()`, `arp_create()`, neighbor table.
  - `net/core/neighbour.c` — generic L3-to-L2 resolver, the "neigh subsystem."
- **FreeBSD** `sys/net/route.c` + `sys/netinet/if_ether.c` — radix-tree route table + `arpresolve()`.
- **OpenBSD** `sys/net/route.c` + `sys/netinet/if_ether.c` — same shape as FreeBSD.
- **NetBSD** — same family.
- **lwIP** `src/core/ipv4/ip4.c` (`ip4_route()`) + `src/core/ipv4/etharp.c` (`etharp_output()`). **Closest to AGNOS scale** — embedded TCP/IP, single-CPU, no full routing table.
- **iPXE** `src/net/ipv4.c` (`ipv4_tx`) — picks gateway when destination is off-LAN, calls ARP for the gateway.
- **U-Boot** `net/arp.c` + `net/net.c` (`net_send_ip_packet`) — embedded; same gateway-fallback pattern.
- **Plan 9** `ip/arp.c` — small, readable.
- **musl/glibc** + kernel — for the user-space TCP outbound reference (route lookup done by kernel, opaque to libc).

**TCP outbound** (active connect path):

- **lwIP** `src/core/tcp_out.c` + `src/core/tcp.c` — `tcp_connect()` issues SYN, the close embedded reference.
- **iPXE** `src/net/tcp.c` — embedded TCP outbound.
- **Linux** `net/ipv4/tcp_ipv4.c` (`tcp_v4_connect`).
- **FreeBSD/OpenBSD/NetBSD** `sys/netinet/tcp_input.c`, `tcp_output.c` — full reference.

**Convergent pattern** for L3 next-hop selection (all sources agree):

```
fn ip_output(dst_ip, ...):
    if (dst_ip & netmask) == (my_ip & netmask):
        # On-LAN — destination is directly reachable
        next_hop_ip = dst_ip
    else:
        # Off-LAN — route via default gateway
        next_hop_ip = gateway_ip
    next_hop_mac = arp_resolve(next_hop_ip)        # ARP, with cache + timeout
    frame.dst_mac = next_hop_mac
    nic_send(frame)
```

Every one of the listed sources implements this same shape. The variations are in the route table (full vs default-only), the ARP cache (full neighbor table vs single slot), and the timeouts.

---

## 4. Audit of AGNOS's outbound data path (the fresh finding)

### 4.1 Current `udp_send` — `kernel/core/net.cyr:112-124`

```cyrius
fn udp_send(dst_ip, src_port, dst_port, data, data_len) {
    if (nic_ready() == 0) { return 0 - 1; }
    # For now, use broadcast MAC (QEMU user-mode handles it)
    var dst_mac[8];
    memset(&dst_mac, 0xFF, 6);
    var kmac[8];
    nic_mac(&kmac);
    var p = &net_pkt;
    var off = eth_build(p, &dst_mac, &kmac, 0x0800);
    var udp_len = udp_build(p + off + 20, src_port, dst_port, data, data_len);
    ip_build(p + off, net_ip, dst_ip, 17, udp_len);
    return nic_send(p, off + 20 + udp_len);
}
```

**Finding**: `dst_mac` is **always** `ff:ff:ff:ff:ff:ff`. The function-level comment acknowledges this (`# For now, use broadcast MAC (QEMU user-mode handles it)`). Works for:

- DHCP DISCOVER / REQUEST (which RFC 2131 mandates as broadcast anyway — destination IP is `255.255.255.255`).
- QEMU SLIRP (host-mode NAT will route the broadcast frame correctly).

Fails for:

- **Off-LAN unicast destinations on iron**. The 1.1.1.1 test the user is asking for goes to a real Internet router. The gateway expects the L2 destination of off-LAN traffic to be the **gateway's MAC**, not broadcast. Some consumer routers will forward a broadcast frame anyway (sniffing the L3 dst IP), but it's wrong shape and unreliable — exactly the kind of thing that "works in QEMU, fails on iron."

### 4.2 Current `tcp_send_pkt` — `kernel/core/net.cyr:731-758`

Same shape. Hardcoded broadcast MAC at line 740:

```cyrius
var dst_mac[8];
memset(&dst_mac, 0xFF, 6);
```

`tcp_connect(1.1.1.1, 80, ...)` will issue a SYN with L2-broadcast destination. Likely silently dropped by the gateway, or routed inconsistently — definitely not the protocol shape the gateway expects.

### 4.3 Current ARP cache — `kernel/core/net.cyr:6-8, 501-549`

Single-slot cache:

```cyrius
var arp_cache_ip = 0;
var arp_cache_mac[8];
var arp_pending_ip = 0;
```

Populated by `net_handle_arp` only when an ARP REPLY arrives whose `sender_ip` matches `arp_pending_ip`. Cleared on each new request. No timeout, no replacement policy beyond "last reply wins." **For our test ladder this is adequate** — we only need to cache the gateway MAC, and we don't ARP for anything else.

### 4.4 No `arp_resolve(ip)` helper

No function exists that says "give me the MAC for IP X; ARP for it if not cached." Each call site has to manually `arp_request()` then poll until `arp_pending_ip == 0` and use `arp_cache_mac` directly. Acceptable for the test ladder (one gateway resolution). Worth a follow-up cycle, but **not load-bearing for the next burn**.

### 4.5 No IP-routing decision in `udp_send` / `tcp_send_pkt`

No on-LAN-vs-off-LAN check via netmask. Every dst_ip is treated identically (broadcast L2). To fix the 1.1.1.1 test we need a minimal route helper:

```cyrius
fn route_next_hop_mac(dst_ip, out_mac):
    # Returns 0 on success (out_mac populated), -1 if no MAC available.
    if ((dst_ip & net_netmask) == (net_ip & net_netmask)):
        # On-LAN — caller should ARP for dst_ip.
        # For MVP: only one on-LAN destination we care about is the gateway.
        # If dst_ip == net_gateway and arp_cache_ip == net_gateway, use cache.
        ...
    else:
        # Off-LAN — use gateway MAC.
        if arp_cache_ip == net_gateway:
            memcpy(out_mac, &arp_cache_mac, 6)
            return 0
        return -1   # Caller must ARP for gateway first.
```

For the MVP test ladder, the simpler shape is: the boot test runs ARP-for-gateway first, captures the MAC into a dedicated `net_gateway_mac[8]` slot, then `udp_send` / `tcp_send_pkt` consult `net_gateway_mac` for off-LAN destinations.

---

## 5. Audit of DHCP state vs predecessors

Spot-checks against `kernel/core/net.cyr:309-494` and the two predecessor audits — confirming all applied fixes are still in place:

| Finding from predecessor audit | Status (2026-05-24) | Anchor |
|---|---|---|
| Use `nic_mac` not `vnet_mac` (dhcp-end-to-end #1) | APPLIED | `net.cyr:286, 346` |
| Broadcast flag 0x8000 in BOOTP flags | APPLIED | `net.cyr:280` |
| 1024-byte recv buffer (dhcp-end-to-end #8) | APPLIED | `net.cyr:184, 352` |
| 1016-byte UDP data cap in `net_handle_udp` (#8) | APPLIED | `net.cyr:562` |
| 800-iter wait + midpoint retransmit (#5, #9) | APPLIED | `net.cyr:367, 437` |
| BOOTP op == 2 check (downstream #1) | APPLIED | `net.cyr:378, 447` |
| Magic cookie byte-by-byte at +236 (downstream #2) | APPLIED | `net.cyr:384-387, 448-451` |
| xid byte-order via `dhcp_load_u32_be` (downstream MEDIUM) | APPLIED | `net.cyr:388, 452` |
| chaddr 6-byte match (#4) | APPLIED | `net.cyr:393-397, 453-457` |
| `DHCP_STATIC_IP` build-time fallback | APPLIED | `net.cyr:316-325` |

**Verdict on DHCP code**: the protocol-level state is RFC-tight relative to the predecessor framing. **No fresh DHCP-protocol findings** in this pass — the bug is not in matcher logic that has already been audited from RFC 2131 + 5 reference implementations.

**One open observation** (does not require code change for MVP, just noting): the param-list (option 55) requests only options 1, 3, 6 (subnet, router, DNS). Convergent practice (Linux ipconfig, iPXE, OpenBSD dhcpleased) also requests option 51 (lease-time), 28 (broadcast), 15 (domain). For a server-replying-correctly diagnosis, the current minimal list is fine. Future minor: add 51 so we know the lease-time the server granted.

---

## 6. Proposed test ladder (per user direction)

### 6.1 Test sequence on iron (1.32.4 next burn)

```
[1] r8169_probe + init                       (already in place)
[2] net_init(192.168.1.222, 192.168.1.1, /24) (already in place)
[3] arp_request(net_gateway)                  (already in place)
    Wait ~5s for ARP REPLY.
[4] On ARP REPLY:
    - Copy arp_cache_mac → net_gateway_mac (new persistent slot)
    - Print "arp: REPLY gw_mac=XX:XX:..." (already in place, length-fixed)
    - Continue to [5].
    On ARP TIMEOUT:
    - Print failure + halt the network test (no [5], no [6]).
[5] L3 reachability test — 1.1.1.1
    - Option A (preferred minimum): TCP SYN to 1.1.1.1:80 using gateway-MAC routing.
      Wait for SYN+ACK. Sufficient L3-routing proof + first half of [6].
    - Option B (more complete): minimal ICMP echo. Requires ~30 LOC ICMP module.
[6] Outbound TCP — 1.1.1.1:80 full handshake
    - Continue from [5] Option A: complete the handshake (we sent SYN, peer ACK'd, we ACK).
    - Print "tcp_connect 1.1.1.1:80 PASS" if state reaches ESTABLISHED, else FAIL.
    - Optionally `tcp_close(conn)`.
[7] Comment out / build-gate off the inbound `TCP_LISTEN_SMOKE` block.
```

### 6.2 Why TCP-SYN to 1.1.1.1:80 is the right "router connected" proof

Per user's note: "outgoing TCP is the proof that the router connected." Concretely, what each layer proves:

- **SYN sent successfully** → r8169 TX wire-egress works for unicast frames addressed to gateway MAC. (Attempt 101 left this open.)
- **SYN+ACK received** → router accepts off-LAN traffic from us, forwards to 1.1.1.1, brings the reply back, our chip admits unicast frames to our MAC. (Attempt 101's open question about RX-of-unicast resolves here.)
- **ACK sent + ESTABLISHED reached** → full TCP three-way handshake works. Sequence-number tracking sane. State machine correct.

This is strictly more proof than ICMP echo (which only validates IP-level routing) and strictly less effort than dragging DHCP back into the picture for the same proof.

### 6.3 Why ICMP echo is not in scope right now

Adding ICMP is a fresh net-stack subsystem (~30-50 LOC for echo request + reply parse + identifier/sequence tracking). Not zero work. Not needed for the proof we want. Defer to a later cycle.

---

## 7. Proposed code changes (line numbers as of HEAD)

**All changes in `agnos/kernel/core/`. No changes to cyrius repo per [[feedback_cyrius_hands_off]]. No version bump per [[feedback_no_unprompted_version_bumps]] unless user explicitly says cut.**

### 7.1 `net.cyr` — add gateway-MAC slot + off-LAN routing helper

```cyrius
# New module globals near line 8
var net_gateway_mac[8];        # populated after first successful ARP-to-gateway
var net_gateway_mac_valid = 0; # 0 = unresolved, 1 = populated

# New function — minimal route lookup. Returns 0 on success (out_mac filled),
# -1 if no MAC is available for this destination.
fn route_next_hop_mac(dst_ip, out_mac) {
    if (net_netmask != 0) {
        if ((dst_ip & net_netmask) == (net_ip & net_netmask)) {
            # On-LAN. For MVP, the only on-LAN dst we send to outside
            # the broadcast DHCP path is the gateway itself. If a future
            # test sends to other on-LAN peers, this needs a real ARP cache.
            if (net_gateway_mac_valid == 1) {
                if (dst_ip == net_gateway) {
                    memcpy(out_mac, &net_gateway_mac, 6);
                    return 0;
                }
            }
            return 0 - 1;
        }
    }
    # Off-LAN — use gateway MAC.
    if (net_gateway_mac_valid == 1) {
        memcpy(out_mac, &net_gateway_mac, 6);
        return 0;
    }
    return 0 - 1;
}
```

### 7.2 `net.cyr` — `udp_send` / `tcp_send_pkt` consult `route_next_hop_mac`

For non-broadcast destinations, prefer the resolved gateway MAC; fall back to broadcast (preserves QEMU SLIRP path + the broadcast-DHCP path which calls `udp_send_from` separately).

```cyrius
fn udp_send(dst_ip, src_port, dst_port, data, data_len) {
    if (nic_ready() == 0) { return 0 - 1; }
    var dst_mac[8];
    memset(&dst_mac, 0xFF, 6);
    # If we have a resolved next-hop MAC for this dst_ip, use it. Else fall
    # back to broadcast (works for QEMU SLIRP + actual broadcast destinations
    # like DHCP DISCOVER which calls udp_send_from with dst=255.255.255.255).
    if (dst_ip != 0xFFFFFFFF) {
        route_next_hop_mac(dst_ip, &dst_mac);
    }
    # ... rest unchanged
}
```

`tcp_send_pkt`: same pattern.

`udp_send_from`: **leave as broadcast** — DHCP's the only caller, RFC requires broadcast.

### 7.3 `main.cyr` — wire ARP reply → `net_gateway_mac`, then run the test ladder

Replace the existing `if (arp_got == 1) { ... }` block (currently just prints the gateway MAC + a PROVEN line) with:

```cyrius
if (arp_got == 1) {
    # Persist the gateway MAC for the route helper.
    memcpy(&net_gateway_mac, &arp_cache_mac, 6);
    net_gateway_mac_valid = 1;
    kprint("arp: REPLY gw_mac=", 18);
    # ... existing MAC print ...
    kprintln("net: L2 OK -- gateway MAC cached", 32);

    # Outbound TCP test: 1.1.1.1:80
    kprintln("tcp: connect 1.1.1.1:80", 23);
    var conn = tcp_connect(ip4(1,1,1,1), 80, 49152);
    if (conn >= 0) {
        kprintln("net: L3+TCP OK -- outbound TCP handshake established", 52);
        tcp_close(conn);
    } else {
        kprintln("net: L3+TCP FAIL -- SYN sent but no SYN+ACK", 43);
    }
} else {
    kprintln("arp: TIMEOUT -- gateway did not reply within ~5s", 48);
    kprintln("net: L1/L2 FAILED -- cannot reach gateway, skipping L3 test", 59);
}
```

(Byte counts re-verified for ASCII — `→` and `—` purged in this revision.)

### 7.4 `main.cyr` — neutralize the inbound TCP_LISTEN_SMOKE block

Two options, user's call:

- **(option A — soft)**: leave `#ifdef TCP_LISTEN_SMOKE` block in place; just stop defining the build flag. Code stays, no production-boot impact. Reversal is one flag flip.
- **(option B — hard delete)**: remove the entire `#ifdef TCP_LISTEN_SMOKE ... #endif` block (`main.cyr:703-752`). Cleanest for "we're not coming back to inbound for the MVP arc."

Recommended: **option A**. The code is small, the test is useful later (post-MVP for binding sshd-equivalent or HTTP server), and removing it leaves a deletion-shaped hole in the boot flow. Just confirm the build script (`scripts/build.sh` or `cyrius.cyml`) is not defining `TCP_LISTEN_SMOKE=1` for the iron path. If it is, drop the define.

### 7.5 `dhcp_init` — no changes

Predecessor 10-bundle is fully landed and matches RFC 2131 + 5 references. No fresh findings. The static-IP DHCP-bypass path is **left in place** (`DHCP_STATIC_IP` block in `dhcp_init`) so that once L3+TCP is proven outbound, re-running with DHCP enabled is a one-flag flip with the matcher already vetted.

---

## 8. What this audit deliberately does NOT propose

- **NO iron burn**. Per [[feedback_iron_burns_block_other_work]], the user owns burn timing. This doc is the line-by-line audit that earns the right to burn when the user picks.
- **NO instrumentation**. Per [[feedback_no_instrumentation_means_no_instrumentation]] — the test ladder's PASS/FAIL prints are functional output, not diagnostic stamps.
- **NO version bump**. 1.32.4 is open; the code edits land at the current minor.
- **NO hardware-side proposal**. Per [[feedback_primary_target_focus]] + the user's direct request, the audit stays at the network-stack code layer.
- **NO change to r8169.cyr**. The BSD/iPXE rewrite stands. If Attempt 102 shows ARP still times out on the new test path, *that* re-opens the chip-side question, but only with photo-confirmed iron evidence first.

---

## 9. Open questions for the user before code lands

1. **Inbound TCP_LISTEN_SMOKE — soft-disable (option A) or hard-delete (option B)?** Recommendation: A.
2. **Outbound test target — 1.1.1.1:80 the right pick?** Public anycast, no auth, reliable SYN+ACK, no TLS in the way. Alternatives: 1.1.1.1:53 (DNS over TCP, also reliable), 8.8.8.8:80 (Google anycast, equally fine). 1.1.1.1:80 is the user's stated pick.
3. **Add ICMP echo as a separate L3 reachability step before TCP?** Recommendation: no, defer. TCP SYN+ACK is strictly more proof.
4. **Reflect updated wiring in `state.md` + `iron-nuc-zen-log.md` "carry-forward" tracker?** Yes once code is applied.

---

## 10. Receipt for next session

If picked up cold: this doc documents the audit that closed the framing for Attempt 102's iron-test reshape. Its successor will be the iron-nuc-zen-log entry for Attempt 102 (whenever it burns), which should reference this doc + the photo + the boot-block transcript.
