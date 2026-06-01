# NTP / SNTP Client — Multi-Source Prior-Art Audit

> **Status**: audit complete, pre-implementation. Drives the agnos **1.35.x** networking-comms continuation (the #3 item after DNS / ICMP / TCP-hardening). Per [[feedback_redesign_dont_reinvent]] — converge from the RFCs + multiple stacks, diff against AGNOS, port.
>
> **Scope**: a **unicast SNTP client** (RFC 4330 / RFC 5905 simple mode) — ask one NTP server over UDP/123 for the time and set a system wall clock. NOT a disciplined NTP daemon (no peer selection, no clock-slewing/drift loop, no stratum tree). It gives AGNOS its **first wall-clock time-of-day** — the kernel today has only `timer_ticks` (a 100 Hz counter) and never reads the RTC.
>
> **Created**: 2026-05-27.

---

## 1. Sources surveyed

| Source | Contributes |
|---|---|
| **RFC 5905** (NTPv4) | Packet format, the 64-bit NTP timestamp, the four-timestamp offset/delay math |
| **RFC 4330** (SNTPv4) | The **simple** client profile — a stateless one-shot query is explicitly blessed |
| **musl** / **OpenBSD `ntpd`** (client path) | Minimal request build + transmit-timestamp extraction |
| **chrony** (`SST_` simple path) / **lwIP** `apps/sntp/sntp.c` | The embedded shape: 48-byte packet, one in flight, `transmit timestamp` is the answer |
| **POSIX `gmtime`** (epoch math reference) | Unix-seconds → Y/M/D/H/M/S breakdown |

**Convergence**: every client sends the identical 48-byte UDP/123 packet and reads the server's **Transmit Timestamp** as "now." They differ only in accuracy refinement (offset/delay from all four timestamps, clock discipline) — none of which a one-shot kernel clock-set needs in v1.

---

## 2. Wire format (RFC 5905 §7.3) — 48-byte packet

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|LI | VN  |Mode |    Stratum    |     Poll      |   Precision   |   byte 0..3
+---------------------------------------------------------------+
|                          Root Delay                           |   4..7
|                       Root Dispersion                         |   8..11
|                       Reference ID                            |   12..15
|                  Reference Timestamp (64)                     |   16..23
|                  Origin Timestamp (64)                        |   24..31
|                  Receive Timestamp (64)                       |   32..39
|                  Transmit Timestamp (64)                      |   40..47  ← the answer
+---------------------------------------------------------------+
```

- **Byte 0** request = `0x1B` → LI 0, **VN 3**, **Mode 3 (client)**. (VN 4 / `0x23` works identically; servers answer both.) Response should have **Mode 4 (server)** in byte 0 (`& 0x07 == 4`).
- A simple client sends byte 0 = `0x1B` and the **other 47 bytes zero** (no need to fill the origin/transmit timestamps unless doing offset math).
- The **Transmit Timestamp** (offset 40, 8 bytes) is the server's clock at send: **32-bit seconds** (offset 40–43, big-endian) since the **NTP epoch 1900-01-01** + 32-bit fraction (44–47). v1 takes the integer seconds and ignores the fraction.

### NTP epoch → Unix epoch
`unix_seconds = ntp_seconds − 2208988800` (the seconds between 1900-01-01 and 1970-01-01). For 2026, `ntp_seconds ≈ 3.97e9` — fits a u32 (< 2³², the NTP **era 0** runs to 2036), and the Unix result (~1.77e9) fits an i64 trivially. **Era rollover (2036) is out of scope** for v1.

---

## 3. The simple client algorithm (converged)

```
ntp_sync(server):
  1. build req: 48 bytes, byte0 = 0x1B, rest 0
  2. udp_send_from(server, 123, req)
  3. poll (bounded) for the response; validate len ≥ 48 AND mode == 4
  4. ntp_secs = u32_be(resp, offset 40)
     if ntp_secs == 0: fail (server didn't set it)
     net_unix_time   = ntp_secs − 2208988800
     net_ntp_synctick = timer_ticks         # remember when we synced
     net_ntp_synced  = 1
```

**Reading the clock afterward** (the kernel's running wall clock):
```
ntp_now() = net_unix_time + (timer_ticks − net_ntp_synctick) / 100   # 100 Hz timer
```
This advances the synced base by elapsed ticks — a free-running clock disciplined only at sync time. Good enough for cert-validity windows + file/log timestamps; **no slewing/drift correction** (a daemon concern, deferred).

**Accuracy**: v1 uses the transmit timestamp directly, so the error is ≈ the one-way network delay (tens of ms on a LAN/Internet path) — fine for the use cases. The RFC offset calc `((T2−T1)+(T3−T4))/2` is a deferred refinement.

---

## 4. Diff against AGNOS

| Need | AGNOS today | Gap |
|---|---|---|
| UDP send/recv on a bound port | `udp_send_from` / `udp_bind` / `udp_recv_from` + ingress demux ✓ (DHCP/DNS) | none — reuse the DNS-style fixed-port lazy bind |
| Name resolution for `pool.ntp.org` | `dns_resolve` ✓ (1.35.0) | none — the `ntp` verb resolves like `ping` does |
| Wall clock / time-of-day | **none** — only `timer_ticks`; the RTC is never read | **the whole bite**: `net_unix_time` base + `ntp_now()` + NTP sync to set it |
| u32 big-endian read | `dhcp_load_u32_be` ✓ | reuse |
| Unix→calendar breakdown | none | small civil-time helper for the `date` verb (v1: UTC H:M:S; full Y/M/D optional) |

**Net**: the transport + DNS are done; the bite is the SNTP packet + the epoch conversion + introducing a wall clock. ~120–160 LOC, smaller than DNS.

---

## 5. Bite plan

- **Bite 1 — SNTP client + wall clock** (`net.cyr`): ✅ **LANDED (agnos 1.35.x, [Unreleased] → 1.35.2).** `net_unix_time` / `net_ntp_synctick` / `net_ntp_synced` globals; `NTP_UNIX_DELTA`; `ntp_parse_unix` (transmit-timestamp → Unix); `ntp_sync(server_ip)` (build/send/poll/parse, DNS-style fixed-port lazy bind); `ntp_now()` (free-running read). `ntp <server>` shell verb (dotted-quad or DNS-resolved, like `ping`) + `date` verb (Unix seconds + UTC H:M:S). **Validated**: `ntp-smoke.sh` `ntp: parse PASS` (hermetic epoch conversion + breakdown). Live sync via the `ntp <server>` verb (manual / iron — SLIRP has no NTP server).
- **Validation** — `NTP_SELFTEST` hermetic: a hand-built 48-byte response with a known transmit timestamp parses to the expected Unix seconds (epoch-delta check); the H:M:S breakdown of a known value is correct. `ntp-smoke.sh` gates `ntp: parse PASS`. A best-effort live sync (resolve an Internet NTP IP via SLIRP→host DNS) is informational, like the DNS/ICMP live paths.

---

## 6. Falsification / test rubric

1. **Hermetic parse (load-bearing)** — `ntp_parse_unix` on a synthetic response whose offset-40 u32 = `3913056000` (NTP) returns `1704067200` (Unix, 2024-01-01 00:00:00 UTC). A wrong epoch delta or byte order falsifies.
2. **Civil breakdown** — `1704067200` → `00:00:00` UTC (and a sane date if full breakdown lands).
3. **Live sync** (informational) — `ntp <ip>` against a reachable server returns a plausible 2026 Unix time; `date` then advances second-to-second.
4. **No regression** — `test.sh` 4/4, `check.sh` 11/11; the DNS/ICMP/TCP smokes stay green.

---

## 7. Out of scope (deferred)

- Offset/delay computation from all four timestamps (v1 uses the transmit timestamp directly).
- Clock discipline / slewing / drift estimation (a daemon's job, not a one-shot set).
- Peer selection, stratum tree, NTP authentication (MAC/MD5/AES).
- The 2036 era-0 rollover.
- DHCP option 42 (NTP servers) capture — v1 takes the server as an argument; option-42 capture can ride a later cut like DNS's option-6 did.
- A full Gregorian calendar breakdown with leap-year/month tables — v1 may ship UTC H:M:S only; full Y/M/D is a small follow-on if a consumer needs it.
