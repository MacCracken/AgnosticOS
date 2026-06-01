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

Reviewed and judged **already adequately guarded** in pass 1 (no change needed): `dns_skip_name` (per-byte `p >= len` + 128-iter compression-loop cap), `dns_parse_answer` (`p+10`/`p+rdlen` bounds), `tcp_parse_mss` (`p+1 < hdr_len`, `olen < 2`, `p+4 <= hdr_len`), `net_handle_tcp` (`tcp_hdr_len` min/max), `ntp_parse_unix` (caller gates `n >= 48`).

---

## Pass 2 (staged on 1.35.7, version TBD) — TCP sequence-number wrap + RTC year bound

Worked the pass-1 candidate list. Two genuine gaps found and fixed; the rest reviewed clean.

### Finding 1 (correctness/robustness): two unmasked `seq + 1` RCV.NXT stores

A full sweep of every SND.NXT/RCV.NXT update (`store64(cb+32 / cb+40, ...)`) found that **all of them mask `& 0xFFFFFFFF` except two**: `net_handle_tcp` line ~1911 (SYN_SENT → ESTABLISHED, `store64(cb+40, seq+1)`) and line ~1994 (FIN_WAIT, same). TCP sequence numbers are 32-bit and wrap at 2³². The passive-open path already masks (`(seq+1) & 0xFFFFFFFF`); the active and FIN_WAIT paths didn't.

- **Line 1911 is a real (rare) bug**: a peer whose ISN is near 2³² (e.g. `0xFFFFFFFF`) makes RCV.NXT = `0x100000000` instead of `0`. The peer's first data segment carries the wrapped seq `0`, which never equals the unwrapped `expected`, so the in-order accept (`seq == expected`) silently rejects every segment → the connection stalls. Probability is ~1-in-2³² per connection (random ISN), but it's a clean correctness gap with a one-character fix.
- **Line 1994 is consistency**: FIN_WAIT is closing (next state CLOSED on the same path) so RCV.NXT isn't reused, but it should mask like every other update.

**Fix**: `(seq + 1) & 0xFFFFFFFF` at both sites — matching the established pattern at lines 1610/1697/1854/1874/1963/1975. No new helper (would create two ways to do the same masking); inline match keeps the file consistent.

### Finding 2 (defense): RTC has no upper-year bound

`rtc_read_unix` rejects `year < 1970` but not absurdly-high years. A corrupt century/year CMOS register (e.g. `rtc_bcd` of a garbage byte → up to 165) could yield `year` in the thousands, which `civil_to_unix` happily converts to a far-future Unix time and seeds as the wall clock until NTP corrects it. **Fix**: also reject `year > 2200` → `rtc_read_unix` returns 0 (clock unset, `date` says so) rather than seeding a nonsense year; NTP sets it on first sync. Bounded-wrong-but-honest beats bounded-wrong-and-asserted.

### Reviewed clean (no change)
- **`tcp_rx_append`**: flow-control-clamped (`take > free`), power-of-two ring mask (`rxw & (RING-1)`), both copy halves bounded to the ring — safe; the data length is `ip_payload_len`-derived (pass-1-clamped).
- **mmap arena exhaustion**: `sys_mmap` pre-counts free 2 MB regions (`pmm_count_2mb_free() < npages → 0`) before the alloc loop, so a mid-loop `pmm_alloc_2mb == 0` is unreachable in the single-core model. The partial-rollback path is therefore dead code today — **left as-is**, flagged for the future SMP arc ([[project_multithreading_future_arc]]) which must make the count→alloc atomic (a speculative rollback now would be untestable dead code).
- **`munmap` partial range**: already per-region present/absent (idempotent) — a partial range is handled.
- **DNS cache**: eviction is two bounded linear scans (empty/expired, else min-exp), no loop; name region `slot*64 + j` with `j < host_len ≤ 63 < 64` — no overflow; `len > 63` rejected. Safe.
- **UDP length field**: `net_handle_udp` derives its copy length from `ip_payload_len` (pass-1-clamped) and caps at 1016 into kmalloc(1024)/`var[256]` buffers — a UDP-header-length cross-check would be pure defense-in-depth; skipped.

### Validation

The two fixes are inline wrap/range guards on existing arithmetic — no new behavior on valid paths, so validated by **no-regression** rather than a new hermetic gate: `tcp-smoke` 4/4 + `tcp-listen-smoke` 2/2 (handshake/data/FIN unaffected), `rtc-smoke` green (live ~2026 CMOS read still seeds, not spuriously rejected), `test.sh` 4/4, `check.sh` 11/11. The wrap fix's correctness is established by the masked-pattern consistency (now uniform across all 8 seq-update sites).

---

## Pass-3+ candidates (none scheduled)

The pass-1/2 sweep covered the untrusted-ingress and new-arithmetic surfaces. No further hardening gaps identified in the 1.35.x additions. A future pass could revisit TCP under adversarial sequencing once a real remote peer (beyond SLIRP) exercises it, but nothing is outstanding. Structural cleanup of `net.cyr` is **1.36.x refactor** territory, not hardening.
