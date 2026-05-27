# TCP Hardening — Multi-Source Prior-Art Audit

> **Status**: audit complete, pre-implementation. Drives the agnos **1.35.1** cycle (TCP hardening). Per [[feedback_redesign_dont_reinvent]] — derive the converged shape from RFCs + multiple independent stacks, diff against AGNOS's actual code, then port in phased bites.
>
> **Goal**: make the minimal 1.32.0 TCP state machine carry a **sustained, reliable byte stream** — the precondition for `ark`/`nous` fetch (and any real HTTP-shaped traffic). Today's TCP does the handshake + single-shot request/reply fine (it's what DNS-over-TCP or a one-segment probe needs) but **silently loses data on any multi-segment transfer** and **never retransmits**.
>
> **Created**: 2026-05-27.

---

## 1. Sources surveyed

| Source | Contributes |
|---|---|
| **RFC 9293** (TCP, 2022 — obsoletes 793) | Canonical state machine, send/receive sequence variables (SND.UNA/NXT/WND, RCV.NXT/WND), the reassembly + ACK rules |
| **RFC 1122** §4.2 (Host Requirements) | MUST-level behaviors: delayed-ACK bound, retransmit, window handling, Karn's algorithm |
| **RFC 6298** (Computing TCP's RTO) | SRTT / RTTVAR estimation, RTO = SRTT + 4·RTTVAR, min 1 s, exponential backoff |
| **RFC 5681** (Congestion Control) | slow-start / congestion-avoidance / cwnd — surveyed for the *deferral* boundary |
| **lwIP** `tcp_in.c` / `tcp_out.c` / `tcp.c` | **The embedded reference.** `tcp_pcb` send/recv vars, `unsent`/`unacked` segment queues, `tcp_slowtmr` (500 ms) retransmit driver, MSS option parse/emit, sliding window |
| **FreeBSD** `tcp_input.c` / `tcp_output.c` | Production reassembly queue, RTT sampling, persist timer |
| **iPXE** `tcp.c` | Minimal fetch-only client TCP (one in-flight retransmit, no SACK) — closest to our scale |

**Convergence**: every stack carries the same six send/receive sequence variables and the same retransmit-on-RTO discipline. They differ in sophistication (SACK, window scaling, NewReno vs CUBIC) — none of which a kernel fetch-client needs in v1. lwIP and iPXE are the right scale models: one-in-flight or small-queue retransmit, fixed-ish RTO with backoff, MSS option, a real in-order receive buffer.

---

## 2. Current AGNOS TCP (`kernel/core/net.cyr`, 1.32.0 bite A)

What exists: an 8-entry conn table (80 B/entry), the full state set (CLOSED / SYN_SENT / ESTAB / FIN_WAIT / CLOSE_WAIT / LISTEN / SYN_RCVD), active open (`tcp_connect`), passive open (`tcp_listen`/`tcp_accept` + SYN_RCVD), `tcp_send`/`tcp_recv`/`tcp_close`, a correct pseudo-header checksum, and timer-randomized ISNs. The handshake is solid and iron-proven (1.32.x).

Conn struct (offsets into the 80-byte entry): `state`(0) `src_port`(8) `dst_port`(16) `dst_ip`(24) `seq_num`(32) `ack_num`(40) `rx_buf`(48) `rx_buf_len`(56) `rx_buf_head`(64) `flags/meta`(72). **All ten u64 slots are used — the struct is full; hardening must grow it.**

---

## 3. The gaps, ranked by impact on a fetch

### G1 — Receive path keeps only the *latest* segment (CORRECTNESS, #1)
`net_handle_tcp`'s ESTABLISHED data branch does `net_copy_buf(rx_buf, …, data_len); store64(cb+56, data_len)` — it **overwrites** the 256-byte buffer (capped at 248) with each segment and sets `rx_buf_len` to just that segment. A response that arrives as N segments leaves only the last-unread one; `tcp_recv` drains a single slot. **Any multi-segment transfer is silently truncated.** `rx_buf_head`(64) exists but is never used as a ring cursor. This is the dominant blocker — without it, retransmit and windows are moot because the bytes are dropped after arrival.

### G2 — No retransmission, no RTO (RELIABILITY, #2)
`tcp_send` sends once and advances `seq`; `tcp_connect` polls 200× for the SYN-ACK but **never resends the SYN**. There is no retransmit queue and no timer. A single lost segment (SYN, request, or FIN) hangs until the poll budget expires, then fails. RFC 9293/1122 MUST retransmit.

### G3 — Advertised window is a lie (CORRECTNESS/flow-control)
`tcp_send_pkt` hardcodes the advertised window to **8192** while the receive buffer holds **248** bytes. We tell the peer "send 8192" and drop everything past 248. The advertised window MUST reflect real free buffer space (RCV.WND), or the peer legitimately overruns us.

### G4 — No MSS option, no send segmentation
The SYN carries no MSS option (RFC 9293 §3.7.1, option kind 2), so we neither advertise our MSS nor parse the peer's; the implicit default is 536. And `tcp_send` emits the caller's entire `len` as **one segment** — a >MSS send produces an oversized segment (IP-fragmented or dropped). Sends must be split into ≤effective-MSS chunks.

### G5 — Peer's advertised window ignored (flow-control)
We never read the 16-bit window field from inbound segments, so `tcp_send` can overrun a slow peer's receive buffer. SND.WND must track the peer's last-advertised window; usable window = SND.UNA + SND.WND − SND.NXT.

### G6 — No congestion control (DEFERRED)
No cwnd / slow-start / congestion-avoidance (RFC 5681). On a LAN/local-gateway fetch this is not the gating correctness issue, and adding it well is a sub-arc of its own. **Deferred** — documented here so the boundary is explicit, not forgotten. Flow control (G3/G5) is the MUST; congestion control is the SHOULD that follows.

---

## 4. Converged shapes (what to port)

**Sequence variables** (RFC 9293 §3.3.1; every stack carries these): SND.UNA (oldest unACKed), SND.NXT (next to send), SND.WND (peer's advertised window), RCV.NXT (next expected = our `ack_num`, already have), RCV.WND (our free buffer = advertised window). AGNOS already has `seq_num`(≈SND.NXT) and `ack_num`(=RCV.NXT); needs SND.UNA + SND.WND added.

**Receive buffer** (lwIP/iPXE): an in-order byte ring. Accept a segment iff `seq == RCV.NXT` (in-order); append to the ring, advance RCV.NXT by data_len, ACK. Out-of-order segments (`seq > RCV.NXT`) → drop + re-ACK RCV.NXT (no SACK/reassembly queue in v1 — the simplest correct behavior; the peer retransmits the gap). Advertised window = ring free space.

**Retransmit** (lwIP `tcp_slowtmr` shape): keep the last unACKed outbound segment (seq + bytes + send-tick + retx-count). A periodic check (drive off `timer_ticks` in the poll loop) resends it when `now − send_tick > RTO`, doubling RTO each retx (RFC 6298 backoff), giving up after ~5 tries. On an inbound ACK with `ack > SND.UNA`, advance SND.UNA and clear the segment. v1 keeps **one segment in flight** (stop-and-wait-ish; iPXE-scale) — correct and simple; a multi-segment send queue is a later refinement.

**RTO**: v1 may use a **fixed RTO with backoff** (e.g., 1 s initial, ×2, cap ~8 s) — RFC 6298 §2.1 permits a fixed initial RTO; SRTT/RTTVAR estimation is a SHOULD-grade refinement that can land in a follow-on. Karn's algorithm (don't sample RTT from a retransmitted segment) applies once estimation lands.

**MSS**: emit the MSS option on SYN/SYN-ACK (kind 2, len 4, value = 1460 for Ethernet — or be conservative at 536); parse the peer's from their SYN; effective MSS = min(ours, peer's, 536-if-absent). Segment `tcp_send` into ≤effective-MSS chunks, advancing SND.NXT per chunk.

---

## 5. Bite plan (phased — each QEMU-validatable, no iron required)

Ordered by the fetch-impact ranking. The conn struct grows from 80 B; bite B0 does that once.

- **B0 — struct growth + sequence vars.** Grow the conn entry (80 → 128 B; `tcp_conns[640]` → `[1024]`) and add SND.UNA, SND.WND, and the retransmit-segment slots (seg-seq, seg-len, seg-send-tick, retx-count). Pure plumbing; no behavior change, all existing offsets preserved.
- **B1 — in-order receive ring + honest window.** Replace the overwrite-latest rx path with an append ring (reuse `rx_buf_head` as the write cursor + a read cursor); accept only `seq == RCV.NXT`, drop+re-ACK out-of-order; advertise real free space. **The keystone — unblocks multi-segment receive.** Smoke: fetch a >1-segment payload and byte-verify.
- **B2 — retransmit + RTO/backoff.** One-in-flight retransmit of SYN / data / FIN driven off `timer_ticks`; advance SND.UNA on ACK; give up after ~5 tries. Smoke: drop the first reply (QEMU `netdev` with a loss filter, or a test hook) and confirm the resend recovers.
- **B3 — MSS option + send segmentation.** Emit/parse the MSS option; split large `tcp_send` into ≤MSS segments. Smoke: send >MSS and confirm multiple correctly-sized segments on the wire.
- **B4 — honor peer SND.WND.** Track the peer's advertised window; never send beyond the usable window; zero-window persist probe (small). Smoke: peer advertises a small window, confirm we throttle.
- **Deferred (own follow-on): congestion control** (G6, RFC 5681 slow-start/cong-avoid) + RTT-estimated RTO (RFC 6298 SRTT/RTTVAR) + SACK. Documented, not in this cycle.

B1 + B2 are the load-bearing correctness/reliability pair; B3/B4 complete flow-control hygiene. Each bite is its own `tcp-*-smoke.sh` gate, mirroring the DNS/ICMP pattern.

---

## 6. Falsification / test rubric

The existing `scripts/tcp-listen-smoke.sh` covers the handshake. New gates per bite:

1. **Multi-segment receive (B1)** — a loopback/SLIRP peer sends a payload larger than one segment (and larger than the old 248-byte cap); `tcp_recv` must return the **full** byte-exact stream across repeated drains. Pre-B1 this fails (truncates to the last segment) — that failure is the B1 falsification baseline.
2. **Loss recovery (B2)** — induce a single dropped segment; the connection must complete via retransmit rather than hang→timeout. A wrong RTO/no-retx leaves the transfer stalled.
3. **Segmentation (B3)** — a >MSS `tcp_send` must appear on the wire as multiple ≤MSS segments with contiguous seqs; an oversized single segment falsifies.
4. **No regression** — `tcp-listen-smoke.sh` + `test.sh` 4/4 + `check.sh` stay green; the handshake + DNS/ICMP paths unaffected.

Hermetic-where-possible (a self-test hook can feed synthetic segments into `net_handle_tcp` for B1 reassembly + B3 parse, mirroring the DNS parse selftest); live loss-recovery (B2) needs a QEMU netdev loss filter or a deterministic drop hook.

---

## 7. Out of scope (this cycle)

- **Congestion control** (cwnd / slow-start / NewReno / CUBIC) — RFC 5681; the explicit G6 deferral.
- **SACK** (RFC 2018), **window scaling** (RFC 7323), **timestamps** — performance/scale, not correctness for a kernel fetch client.
- **RTT-estimated RTO** (RFC 6298 SRTT/RTTVAR) — v1 uses fixed-RTO-with-backoff; estimation is a refinement.
- **TIME_WAIT / 2MSL** — the current FIN_WAIT→CLOSED shortcut is acceptable for a client; full TIME_WAIT is a correctness item only for high-rate reconnect.
- **Multi-segment send queue** — v1 keeps one segment in flight; a pipelined send window is a later refinement.
- **TLS / HTTP** — userland + the cyrius-stdlib TLS the user drives separately; this arc only makes the byte stream reliable underneath them.
