# 1.35.x Arc-Close Hardening — Audit + Pass Log

> **Status**: drives agnos **1.35.7** (pass 1). The 1.35.x line added a lot of *new untrusted-input surface* — DNS, ICMP, NTP, TCP all parse attacker-controllable bytes, plus new internal primitives (mmap/pmm-2mb arena, RTC, DNS cache). This is the arc-close hardening review: tighten/guard the code that landed, **without restructuring** (refactor ops are reserved for the separate 1.36.x cycle). Multi-pass — `p-N` sections below.
>
> **Created**: 2026-05-27.

---

## Pass 1 (1.35.7) — forged IP-length over-read at the ingress demux

### Finding (security: remote over-read / info-reflect)

`net_poll()` is the single IPv4 ingress demux. It read the IPv4 header's **total-length** field (`ip_total`, bytes 2–3 — fully attacker-controlled) and computed `ip_payload_len = ip_total - ip_ihl`, guarding only `ip_total >= ip_ihl` (underflow). It **never clamped `ip_total` to the bytes actually received** (`pkt_len`). So a frame that *claims* `ip_total = 65535` but is physically 60 bytes yields a ~65 KB `ip_payload_len`, handed to whichever handler the proto byte selects:

- **ICMP** (`net_handle_icmp` → `icmp_send_echo_reply`): copies `icmp_len` bytes of the "message" and **reflects them back to the sender** — an over-read of `net_rx_pkt`'s stale/adjacent bytes turned into a remote **info-leak** (a small Ping-of-Death-class echo-amplification). `icmp_send_echo_reply`'s own `> 1024` cap bounds it but doesn't stop reading past the real frame.
- **UDP** (`net_handle_udp`): `udp_data_len = ip_payload_len - 8`, capped at 1016, then `net_copy_buf`'d into the receive buffers — reads up to ~1 KB of stale post-frame bytes into the UDP recv path.
- **TCP** (`net_handle_tcp`): internally well-guarded (`tcp_hdr_len < 20` and `> ip_payload_len` both rejected) — but those guards only hold if `ip_payload_len` is honest. A forged length lets the data-segment length (`ip_payload_len - tcp_hdr_len`) over-read into the rx ring append.

The downstream handlers' internal bounds checks are all *relative to `ip_payload_len`* — so the one place the actual-received length must be enforced is the demux. Fixing it there closes all three at the root.

### Prior art — "never trust the length field"

Convergent across every mature IP stack: validate the IP total-length against the actually-received buffer before dispatch.
- **Linux** `ip_rcv` / `ip_rcv_core`: drops if `skb->len < iph->tot_len` (and `tot_len < ihl*4`, `ihl < 5`), then `pskb_trim` to `tot_len`.
- **lwIP** `ip4_input`: `if (iphdr_len > p->tot_len)` → drop; trims `p` to `iphdr_len`.
- **\*BSD** `ip_input`: `if (ip->ip_len > m->m_pkthdr.len)` → `ips_tooshort` drop; also `ip_len < hlen` and `hlen < sizeof(ip)` checks.

The shared shape: **header length ≥ minimum (20), total ≥ header, total ≤ received; otherwise drop/clamp.**

### Fix (1.35.7)

New guard primitive `ip_safe_payload_len(ip_total, ip_ihl, avail)` (`net.cyr`):
- reject `ip_ihl < 20` (IPv4 header minimum),
- reject `ip_total < ip_ihl`,
- **clamp `ip_total` to `avail`** (`pkt_len - 14`),
- reject if the clamp drops it below `ip_ihl` (truncated frame — claimed header doesn't fit),
- else return `ip_total - ip_ihl`.

`net_poll` calls it with `avail = pkt_len - 14` and dispatches only when the result is `>= 0`. For **valid** frames (`ip_total ≤ avail`, `ihl = 20`) the result is identical to the old `ip_total - ip_ihl` — including the Ethernet-min-padding case (`ip_total < avail` is left untouched), so no behavioral change for real traffic (verified: dns/icmp/tcp/ntp smokes stay green). Only forged/oversized lengths are now clamped/dropped.

### Validation

`HARDENING_SELFTEST` + `hardening-smoke.sh` → `hardening: ip-clamp PASS`: hermetic table over `ip_safe_payload_len` — valid pass-through, forged `total > avail` clamped, `ihl < 20` rejected, `total < ihl` rejected, truncated-frame (`ihl` claimed > received) rejected, exact-fit boundary. Plus the full net-ingress regression (dns/icmp/tcp/ntp smokes) to prove valid traffic is unaffected.

---

## Pass-2+ candidates (not yet scheduled — confirm before opening)

Reviewed and judged **already adequately guarded** in pass 1 (no change needed): `dns_skip_name` (per-byte `p >= len` + 128-iter compression-loop cap), `dns_parse_answer` (`p+10`/`p+rdlen` bounds), `tcp_parse_mss` (`p+1 < hdr_len`, `olen < 2`, `p+4 <= hdr_len`), `net_handle_tcp` (`tcp_hdr_len` min/max), `ntp_parse_unix` (caller gates `n >= 48`).

Remaining lower-priority hardening to consider in a later pass:
- **mmap arena**: behavior at arena exhaustion / `pmm_alloc_2mb` returning 0 mid-multi-page request (sys_mmap pre-counts, but re-confirm the partial-rollback path); `munmap` of a partially-mapped range.
- **RTC**: `rtc_read_unix` century-register garbage paths; `civil_to_unix` on absurd inputs (already sanity-rejects `< 1970`).
- **DNS cache**: confirm eviction can't loop; name-length edge at exactly 63/64.
- **TCP**: sequence-number wrap edges in the in-order ring / retransmit accounting (B1/B2).
- **UDP**: validate the UDP length field itself (currently derives length from the IP payload, which pass 1 made safe — a defense-in-depth check of the UDP length header is optional).
