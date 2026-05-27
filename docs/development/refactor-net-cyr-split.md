# Refactor — `net.cyr` split (agnos 1.36.x)

> **Status**: in progress. **Part 1 (TCP) shipped at agnos 1.36.0**; part 2 (app-protocols) next. This is the 1.36.x refactor cycle's headline — structural cleanup ahead of the heavy big-write arcs (1.37.x+). Refactor only; the arc-close *hardening* (1.35.7) was kept deliberately separate.
>
> **Created**: 2026-05-27.

## Why

The 1.35.x arc grew `kernel/core/net.cyr` from a focused IP/UDP file into a **2019-LOC catch-all** spanning 10 protocol sections: Ethernet/ARP/IPv4/UDP core, UDP listener table, DHCP, ICMP, DNS, NTP, RTC, TCP stack, TCP retransmit, server-side TCP. Those `# === … ===` section headers are clean, dependency-light boundaries — natural split lines. Splitting improves navigability and sets up the file for future per-protocol work without a 2k-line scroll.

## The safety property that makes this low-risk

Cyrius `build` **concatenates includes into one compilation unit** before compiling. So moving a contiguous block of `net.cyr` into a new file that is `include`d *immediately after* `net.cyr` produces a **character-identical compilation unit** (comments are ignored by codegen). The compiled `build/agnos` is therefore **byte-for-byte identical** (same sha256) before and after the split — the strongest possible proof that behavior is unchanged. This is the same property exploited in the cyrius 6.0.1↔6.0.3 A/B. Every part is gated on: (1) byte-identical build vs the pre-split baseline, (2) the relevant smokes still green.

Forward references across the split are fine: `net_poll` (kept in `net.cyr`) already forward-referenced `net_handle_tcp` / `tcp_retx_tick` ~600 lines later in the same file; Cyrius resolves symbols across the whole unit, so the cross-include forward ref resolves identically.

## Plan (incremental — one block per cut)

| Part | Cut | Extract | `net.cyr` keeps |
|---|---|---|---|
| **1** | **1.36.0** ✅ | **TCP** — state machine + conn table, retransmit (B2), server-side listen/accept (~780 LOC, the largest + cleanest boundary) → `net_tcp.cyr` | L2/L3 core + all app-protocols (for now) |
| **2** | 1.36.x | **App-protocols** — DHCP / DNS / NTP / ICMP / RTC → per-protocol files (`net_dhcp.cyr`, `net_dns.cyr`, `net_ntp.cyr`, `net_icmp.cyr`, `net_rtc.cyr`) | Ethernet / ARP / IPv4 / UDP transport + the `net_poll` demux + shared helpers/globals |

Each part: extract verbatim → `include` right after `net.cyr` (order preserves the byte sequence) → build, assert byte-identical sha → run the affected smokes.

## Out of scope (own slots, not 1.36.x)
- **`ext2.cyr`** (3155 LOC, the biggest file) — defer to the **1.39.x VFS-write arc**, which restructures the FS layer anyway.
- **`shell.cyr`** (1026 LOC) — the **1.41.x** agnoshi shell-separation slot owns this.
- Driver files (`msc`/`xhci`/`ahci`/`nvme`) — cohesive single subsystems, not catch-alls; leave.

## Part 1 record (1.36.0)
- `net_tcp.cyr` created (785 LOC incl. header); `net.cyr` 2019 → 1244 LOC.
- `agnos.cyr`: `include "core/net_tcp.cyr"` added immediately after `core/net.cyr`.
- **Byte-identical**: baseline `637340698cbdaab4695f216ad00ae93c9e78ae2be6c95282b7470d1dad61afd3` (828,528 B) == post-split. `test.sh` 4/4, `check.sh` 11/11, `tcp-smoke` 4/4, `tcp-listen-smoke` 2/2.
