# Networking Arc — Multi-Source Convergent Prior-Art Audit

> **Cycle**: agnos 1.32.x (OPEN 2026-05-22).
> **Discipline**: per [`feedback_redesign_dont_reinvent`](../../../.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_redesign_dont_reinvent.md) — port the converged shape from MULTI-SOURCE prior art (BSD + Linux + EDK2 + Haiku + specs/RFCs), redesign to Cyrius conventions, stack repairs into one burn. **Linux is one source of many, never the singular reference — AGNOS is not a Linux clone.**
> **Tracking discipline (user-stated 2026-05-22)**: *"we will track the items we still need to write work for but will wait until we are on that particular iron."* This doc IS the tracking surface. Code touches happen at iron time; this doc is durable across sessions and survives cold-boot context loss.

## 0. Cycle scope

Two device-class additions + one server-shape kernel primitive set + two userland consumer apps:

1. **r8169-family Ethernet driver** — Realtek RTL8111 / 8168 / 8169 1GbE (and adjacent variants). Iron target: archaemenid (Beelink SER, AMD Zen), presumed-r8169 family (verify via `lspci`-equivalent at iron session). Stationary multi-cycle work; smallest-first phases.
2. **i225-V Ethernet driver** — Intel I225-V 2.5GbE. Iron target: Beelink-SER Intel-variant boards + the i9 "Big boy" post-hardware-migration. Queued behind r8169 closeout.
3. **TCP server primitives in `kernel/core/net.cyr`** — `tcp_listen`/`tcp_bind`/`tcp_accept` + incoming-SYN passive-open handler. QEMU-validatable; iron-confirmable via VirtIO-net under archaemenid before any real-NIC driver lands.
4. **BBS server** — standalone userland repo, name TBD. Telnet-/raw-TCP-listener; user accounts, message boards, file areas, ANSI MOTD.
5. **MUD server** — standalone userland repo, name TBD. Same TCP listener substrate; room-based world model, character state persistence, combat / dialogue / inventory loops.

Items 1-3 are kernel scope; items 4-5 are userland scope and live in their own repos (parallel to agnoshi), opening their own cycles when the kernel surface they depend on lands.

**Strategic destination**: AGNOS to **installable state on archaemenid** — the networking arc + the 1.33.x ext4 WRITE arc together enable [agnova](https://github.com/MacCracken/agnova) (OS installer) to fetch + lay-down system images onto the internal NVMe, after which the user's planned hardware migration kicks in (USB NVMe dev drive removed, internal NVMe becomes archaemenid's AGNOS primary, freed 2TB SATA consolidates with the existing 2TB in the i9 box). The networking cycle is not BBS/MUD for their own sake; those are the wire-end-to-end proof-of-life apps that validate the kernel surface needed for agnova.

## 1. r8169-family driver — convergent references

### 1.1 Sources surveyed

| Source | File / repo | Why it's load-bearing |
|--------|-------------|-----------------------|
| Linux | `drivers/net/ethernet/realtek/r8169_main.c` + `r8169.h` + `r8169_phy_config.c` | Largest historical scope (covers 8169 → 8125 spanning ~25 years of Realtek silicon); most chip-revision quirks; canonical PHY init sequences. **Caveat**: PCI suspend/resume complexity, ASPM workarounds, and the chip-revision dispatch table are heavy enough that lifting the Linux shape directly would import scope AGNOS doesn't need at v1. |
| FreeBSD | `sys/dev/re/if_re.c` + `if_revar.h` | Cleaner state-machine isolation than Linux; better separation between bus-attach, link-state polling, and TX/RX rings. Historically the BSD `re` driver was the second canonical implementation after Linux. |
| OpenBSD | `sys/dev/pci/if_re.c` (forked from FreeBSD pre-divergence) | Minimal-quirk subset; smaller line count, easier to read end-to-end. Diverged from FreeBSD ~2008; less chip-revision coverage but the shape is the same. |
| NetBSD | `sys/dev/pci/if_re.c` (also FreeBSD-derived) | Third converged reference for the BSD-style `re` shape; useful for cross-checking that a behavior is *intentional in the converged design* rather than a FreeBSD-specific workaround. |
| Haiku | `src/add-ons/kernel/drivers/network/ether/rtl8169/` | Independent fourth reference. Haiku is its own kernel — neither Linux nor BSD — so when Haiku's r8169 matches Linux + BSD on a behavior, that's strong "this is the converged shape, not a Unix-family idiom." |
| Realtek | RTL8111/8168 datasheets + programmer's reference (public PDFs) | Authoritative register layout, descriptor format, MAC address EEPROM location. The drivers are *informed by* the datasheet but each adds undocumented quirks; the datasheet is the floor of what's guaranteed. |
| OSDev wiki | [RTL8139](https://wiki.osdev.org/RTL8139) (older sibling; same architectural family) | Pedagogical reference for the descriptor-ring discipline; useful for understanding *why* the ring is shaped the way it is before reading the production drivers. |

### 1.2 Convergent shape (all sources agree)

1. **Bus attach via PCI device-ID match** — vendor `0x10EC` (Realtek), device IDs vary per chip revision (`0x8168`, `0x8169`, `0x8136`, `0x8125`, etc.). All four drivers maintain a dispatch table mapping device ID → chip-revision identifier. **AGNOS approach**: ship the v1 driver matching only the device ID(s) actually enumerated on archaemenid; grow the table as new iron surfaces.
2. **BAR0 = MMIO register block** (~256 bytes of mapped registers). Some chips also expose I/O-port BAR1; modern variants are MMIO-only. **AGNOS approach**: MMIO-only path; ignore I/O-port BAR.
3. **MAC address read at offset 0** of the MMIO region — six bytes, little-endian, no EEPROM transaction needed for the standard chip. **AGNOS approach**: matches the simplest possible path; no EEPROM-walk code at v1.
4. **Reset sequence**: write 0x10 to CR (Command Register, offset 0x37), poll until cleared (Linux uses ~100 loops; FreeBSD uses 10ms timeout; OpenBSD uses 1ms × 100). **AGNOS approach**: match OpenBSD timing (cheapest to implement; sufficient per spec).
5. **TX descriptor ring**: 64-256 entries (driver-configurable; all sources default 256); each descriptor = 16 bytes (status u32 + vlan u32 + addr_lo u32 + addr_hi u32); ring wraps via EOR (End-of-Ring) bit in the last descriptor's status. Ring must be 256-byte-aligned. **AGNOS approach**: 64 entries at v1 (plenty for BBS/MUD; can grow without ABI change since the count is a driver-private constant).
6. **RX descriptor ring**: same shape as TX; same alignment. Buffer per descriptor (Linux uses 2KB or 9KB jumbo; BSD uses 2KB strict). **AGNOS approach**: 2KB buffers, 64 entries; jumbo-frame support deferred.
7. **IRQ setup via MSI** (modern chips) or **legacy INT#** (8169 original). All four drivers prefer MSI when the chip supports it (capability bit in the PCI config). **AGNOS approach**: MSI-first per archaemenid's silicon era (RTL8111/8168+); legacy fallback deferred.
8. **TX flow**: write descriptor (status = OWN bit + length + addr), kick TX via TPPoll (Transmit Priority Poll register, offset 0x38, bit 6). **AGNOS approach**: matches the converged shape exactly.
9. **RX flow**: NIC writes incoming packets to OWN-cleared descriptors, raises IRQ; driver iterates descriptors with OWN cleared, processes packet, sets OWN back and increments ring tail. **AGNOS approach**: matches.
10. **MII PHY init via MDIO** through MMIO registers (offset 0x60 + 0x64). Chip-revision-specific PHY init sequences (Linux's `r8169_phy_config.c` is ~3000 lines for this alone). **AGNOS approach**: ship only the PHY init sequence for archaemenid's specific chip revision; defer the chip-rev dispatch table to when a second chip variant surfaces (mirrors `mihi → iam/chakshu` extract-on-2nd-consumer pattern).

### 1.3 Where the sources diverge (AGNOS choice notes)

- **Chip-revision dispatch**: Linux dispatches ~50 variants; BSD dispatches ~15; Haiku ~8. **AGNOS at v1**: dispatch 1 (archaemenid's specific revision). Add as new iron surfaces.
- **ASPM (PCIe power management) workarounds**: Linux has extensive ASPM-disable code for buggy silicon revisions; BSD has less; Haiku has none. **AGNOS at v1**: skip ASPM entirely (don't enable PCIe link power management). Revisit if a real ASPM-related bug surfaces.
- **Jumbo frame (>1500 MTU) support**: Linux ships; BSD ships behind a feature flag; Haiku partial. **AGNOS at v1**: 1500-byte MTU only.
- **RX checksum offload**: all sources ship; **AGNOS at v1**: skip — software checksum in `net.cyr` is already exercised, and offload adds a non-trivial code path. Add when a performance consumer surfaces.
- **VLAN tagging**: all sources ship; **AGNOS at v1**: skip — BBS/MUD don't need it.

### 1.4 Phase plan

| Phase | Scope | LOC est. | Iron-validatable | Gates |
|-------|-------|----------|-------------------|-------|
| 1 | PCI discovery + MAC address read + reset sequence + register MMIO setup. No TX/RX yet — just "we found the NIC, we know its MAC, the chip ack'd reset." | ~200 | `lspci`-equivalent shell command surface or kernel boot log; iron-only. | archaemenid time |
| 2 | RX descriptor ring + IRQ handler + packet reception. First packet received from the network. Validated by sending an ARP request from the gateway and observing the AGNOS log line for the response. | ~250 | Iron-only. | Phase 1 PASS |
| 3 | TX descriptor ring + send path. First packet sent from AGNOS. Validated by `yo`-style ICMP echo: send echo-request, gateway responds, AGNOS reads response. | ~250 | Iron-only. | Phase 2 PASS |
| 4 | Integration with `kernel/core/net.cyr`'s existing TCP/UDP layer — replace the VirtIO-net-only path with NIC-dispatch (`if backend == BLK_VIRTIO_NET → virtio_net.cyr ; else if r8169 → r8169.cyr`). | ~100 | Iron-only end-to-end (TCP connect to LAN host). | Phases 1-3 PASS |
| 5 | r8169-iron-burn-audit.md doc + Attempt 92+ iron burn (first AGNOS LAN packet). | ~200 prose | Iron-only. | Phases 1-4 PASS |

**Total**: ~800-1200 LOC kernel + ~200 prose audit. Stationary work spanning the 1.32.x minor.

## 2. i225-V driver — convergent references

### 2.1 Sources surveyed

| Source | File / repo | Notes |
|--------|-------------|-------|
| Linux | `drivers/net/ethernet/intel/igc/` (all files; `igc_main.c` is the entry, `igc_base.c` is the silicon-specific) | Newest Intel-NIC family (i225/i226 are 2.5GbE consumer-grade). igc is the Linux-newer driver; e1000e covers prior generations but not i225. |
| FreeBSD | `sys/dev/igc/` | Direct FreeBSD port of Linux igc (FreeBSD historically takes Intel drivers from Linux + adapts; reverse of the typical Linux-derived-from-BSD direction). Useful as a second reference but less independent than the BSD `re` for r8169. |
| Intel | I225/I226 datasheet (publicly published) | Authoritative reference. Same general shape as e1000e family: descriptor rings + MSI-X + advanced TX/RX features. |
| OpenBSD | `sys/dev/pci/if_igc.c` (recent addition) | Slimmer than Linux igc; useful for the "minimum viable i225 driver" shape. |

### 2.2 Convergent shape (where sources agree)

i225-V is **architecturally similar to e1000e** (Intel's prior consumer-NIC family) with 2.5GbE PHY changes; the descriptor-ring discipline and the MMIO register layout are e1000e-style with new bits for the 2.5G speed. Sources converge on:

1. PCI device ID `0x15F2` (i225-V), vendor `0x8086` (Intel).
2. MMIO BAR0 (no I/O-port path).
3. MSI-X required (no legacy INT# fallback on modern revisions).
4. Descriptor rings 16-byte (advanced descriptor format) — different shape from r8169's 16-byte simple descriptor; the advanced format embeds checksum offload + TSO + VLAN fields.
5. PHY via internal MDIO (no external MDIO bus to walk).
6. Multiple TX/RX queues supported (i225-V has 4 queues each direction); single-queue path is sufficient at v1.

### 2.3 Phase plan

Mirrors §1.4's r8169 phase plan; expected to land easier because the architectural pattern repeats. Queued behind r8169 closeout per the "stack into one burn" discipline — and ideally on the i9 "Big boy" Intel iron post-hardware-migration rather than dual-targeting archaemenid + Intel simultaneously.

**Total**: ~900-1300 LOC kernel + ~200 prose audit (separate `i225-v-iron-burn-audit.md` doc).

## 3. TCP server primitives — convergent references

### 3.1 Sources surveyed

| Source | File / shape | Why |
|--------|--------------|-----|
| Linux | `net/ipv4/tcp_ipv4.c` + `net/ipv4/inet_connection_sock.c` (`__inet_lookup_listener`, `inet_csk_accept`) | The canonical implementation; most behaviors documented in RFC quirks comments. **Caveat**: Linux's socket API is BSD-derived but accreted over decades; the listening-socket data structure (`request_sock_queue`) is more complex than AGNOS needs. |
| BSD | `sys/netinet/tcp_input.c` (`tcp_input`) + `sys/kern/uipc_socket2.c` (`solisten`, `soaccept`) | The original (4.3BSD-Reno) socket implementation; cleaner shape than Linux because less historical baggage. |
| xinu | `xinu/net/tcp_listen.c` + `tcp_accept.c` (Comer's pedagogical OS) | Smallest reasonable reference (~200 LOC for the full listen/accept path). Optimized for *understanding* not performance. Closest in spirit to what AGNOS wants at v1. |
| RFC 9293 | TCP specification (Aug 2022 supersedes RFC 793) | Authoritative state-machine reference. AGNOS net.cyr already implements the SYN/ACK/FIN states; the listen path adds the LISTEN state explicitly. |

### 3.2 Convergent shape

1. **Listening socket = a passive connection entry** in the connection table, distinguished by a flag (BSD: `SO_ACCEPTCONN`; AGNOS equivalent TBD — likely a bit on the conn struct). State = LISTEN.
2. **`tcp_listen(port)`**: allocate a conn entry, set state = LISTEN, set src_port = port, src_ip = 0 (wildcard) or specific bind addr, dst_port + dst_ip = 0 (not yet matched). Return listen_id (the conn-table index).
3. **`tcp_bind(port, ip)`**: optional pre-listen step; AGNOS can merge bind + listen into a single call at v1 (no separate bind-without-listen consumer yet).
4. **Incoming SYN arrives**: existing `tcp_find_conn` walks the table; if no exact-match active conn, scan for LISTEN entries with matching dst_port + (matching dst_ip OR wildcard). On match, allocate a new conn entry, set state = SYN_RCVD, send SYN+ACK; the new conn entry inherits the LISTEN's src_port but gets the actual peer's IP/port as dst.
5. **`tcp_accept(listen_id)`**: wait/poll until the LISTEN entry's "completed-handshake" queue has an entry; pop it, return its conn_id. The completed-handshake queue is the queue of conns that transitioned LISTEN → SYN_RCVD → ESTABLISHED.

### 3.3 AGNOS shape

`net.cyr` already has multi-conn dispatch via `tcp_find_conn`; the listen/accept addition is:

- **New state**: `TCP_LISTEN = ?` (assign next available state-id; the existing `tcp_state_name(state, buf)` function will need a new case).
- **New flag** on conn struct: `is_listening` (or reuse state == LISTEN).
- **New function**: `tcp_listen(port) → listen_id` — allocate conn, set state, return.
- **New function**: `tcp_accept(listen_id) → conn_id` — block/poll for completed handshake, pop, return.
- **`tcp_find_conn` extension**: on no-active-match, scan for LISTEN entries with matching dst_port (becomes our src_port) + wildcard-src-ip.
- **Completed-handshake queue**: small ring per LISTEN conn (~4-8 entries; BBS/MUD don't need deep accept queues).

~300-500 LOC delta to `net.cyr` per the bite (A) estimate.

### 3.4 QEMU-validatable

This bite is the **first** of the 1.32.x cycle that doesn't need a real-iron NIC driver — VirtIO-net under QEMU lets us validate the full listen/accept path end-to-end. Once a real-iron NIC driver lands (bite B / Phase 4), the same code paths work against the new NIC without modification.

Iron-confirmable on archaemenid via VirtIO-net through gnoboot + OVMF + qemu-system-x86_64 path that already gates CI today.

## 4. BBS / MUD wire protocols — convergent references

### 4.1 Sources surveyed

| Source | Reference | Why |
|--------|-----------|-----|
| RFC 854 | Telnet Protocol (1983) | Authoritative spec. Five-decade-stable protocol. |
| RFC 855 | Telnet Option Specifications (1983) | The negotiation framework (`IAC DO/DONT/WILL/WONT <option>`). |
| RFC 856-861 | Specific Telnet options (binary, echo, suppress-go-ahead, status, timing-mark, extended options) | Per-option specs. Most BBSes use a tiny subset (echo + suppress-GA + naws). |
| RFC 1184 | Telnet Linemode Option (1990) | The "line at a time vs character at a time" negotiation that affects how raw-vs-cooked the BBS server sees input. |
| RFC 1073 | Telnet Window Size Option (NAWS, 1988) | How the client tells the server its terminal dimensions. ANSI-art content rendering depends on this. |
| Linux `inetutils` | `telnetd.c` (the historical reference daemon) | Pedagogical implementation; ~3000 LOC for the full server, but the negotiation core is ~500 LOC of it. |
| DikuMUD (1991) | Original C source (publicly archived) | Canonical MUD-server reference. Plain-TCP listener, no telnet negotiation at all (clients tolerate the raw-text stream). |
| TinyMUD (1989) | Aspen / Lambda derivatives, public source | Adjacent reference — smaller protocol scope than DikuMUD. |

### 4.2 Convergent shape — BBS

1. Listening TCP socket on port **23** (telnet) or **2323** (unprivileged-port alternative; AGNOS likely runs on 23 from boot since there's no users/permissions layer to require non-root for low ports).
2. On accept: negotiate basic options (`IAC WILL ECHO`, `IAC WILL SUPPRESS-GO-AHEAD`, `IAC DO NAWS`) to put the client into character-at-a-time mode with the server doing the echo. This is what 90s BBSes ran. Three negotiation rounds at session-start are typical.
3. Strip embedded `IAC <cmd>` sequences from the input stream (option negotiation can occur mid-session).
4. ANSI escape sequence support is **client-side** — the server just emits ANSI; the client renders. BBS MOTD aesthetics use the existing `darshana` substrate (planned `cyrius-img-art` tool for image conversion → ANSI text).
5. User accounts / persistent state lives in ext2/4 (already iron-validated 1.31.7; READ-only at present, WRITE-cycle pinned to 1.33.x — BBS message-board persistence will need WRITE).

### 4.3 Convergent shape — MUD

DikuMUD-family (the dominant 90s MUD lineage):

1. Listening TCP socket on port **4000** (DikuMUD default) — convention, not standard; configurable.
2. **No telnet negotiation** at session start. Clients tolerate raw-text. Some modern MUD clients (Mudlet, TinTin++) negotiate optionally but the server doesn't initiate.
3. **Room-based world model**: room records linked by exit pointers (n/s/e/w/u/d + named exits); persistent in flat files (ext2/4-stored).
4. **Character state**: stats, inventory, location (current room), social state (groups, channels). Persistent.
5. **Game tick**: ~250ms-1s wall clock; the server iterates all online characters, applies regen/movement/combat/AI, broadcasts state changes to interested observers.
6. **Combat**: simple round-based "you swing, they swing" loop; broadcasts text-prose messages to room observers.
7. **Channel chat**: global "say" / "shout" / "tell <player>" message-routing layer; one-to-many message dispatch through the same TCP server.

MUD-server v1 LOC estimate: ~3000-5000 LOC in the standalone repo (substantial own-cycle; not 1.32.x kernel scope).

### 4.4 BBS / MUD as kernel-driver

Neither app drives kernel scope expansion beyond what BBS-MOTD ANSI rendering already needs:
- TCP listen/accept (bite A — kernel scope)
- ext2/4 WRITE (1.33.x — kernel scope)
- `darshana` ANSI primitives (userland already)
- `cyrius-img-art` image→ANSI (userland tool, separate idea-stable entry per `agnosticos/docs/development/planning/shared-crates.md` § Image-to-ANSI family)

The apps are out-of-cycle from 1.32.x agnos — they live as their own repos and open their own cycles when the kernel surface they depend on lands.

## 5. Tracking surface — PENDING IRON

Per user discipline 2026-05-22: *"we will track the items we still need to write work for but will wait until we are on that particular iron."*

| # | Item | Iron blocker | Status |
|---|------|-------------|--------|
| A | TCP server primitives (`tcp_listen`/`bind`/`accept` + SYN_RCVD + ARP REQUEST handler) | None for code; SLIRP-inbound delivery gap blocks scenario-1 smoke; bite B/C iron-NIC takes SLIRP out of the loop | ✅ **LANDED 2026-05-22** (4/4 test.sh + 1/2 smoke; accept-success scenario deferred to iron NIC) |
| F | UDP server-side (`udp_bind`/`udp_recv_from`/`udp_send_from` + listener table + dispatch) | None for code; iron-NIC validates end-to-end | ✅ **LANDED 2026-05-22** (4/4 test.sh; integrated smoke via bite G) |
| G | DHCP client (DISCOVER → OFFER → REQUEST → ACK) | DISCOVER egress works; SLIRP-RX gap blocks OFFER reception (same root cause as bite A scenario-1); iron-NIC validates full cycle | ✅ **LANDED 2026-05-22** (4/4 test.sh; OFFER timeout under SLIRP — same gap as bite A; iron-deferred) |
| B | r8169 driver Phases 1-4 (PCI + MAC + reset + RX ring + TX ring + NIC dispatcher + net.cyr migration) | NIC ID confirmed via `lspci`/sysfs on archaemenid (no burn needed): `10ec:8168` rev 15 at `0000:01:00.0`, MAC `b0:41:6f:0c:e4:25`, BAR2 `0xFCF04000`, BAR4 `0xFCF00000`. Phase 5 (iron-burn-audit doc + Attempt 92+) is the next item that genuinely needs iron — all code is ready. | ✅ **LANDED 2026-05-22** (~400 LOC in `kernel/core/r8169.cyr` + ~15 net.cyr call-site migrations + agnos.cyr include reorder; 4/4 test.sh PASS; QEMU boot-smoke clean with nic_send confirmed dispatching through virtio_net path; iron Attempt 92+ validates predicted boot prints + full RX/TX chain) |
| B | r8169 driver Phase 2 (RX) | archaemenid time + Phase 1 PASS | **PENDING Phase 1 closeout** |
| B | r8169 driver Phase 3 (TX) | archaemenid time + Phase 2 PASS | **PENDING Phase 2 closeout** |
| B | r8169 driver Phase 4 (integrate with net.cyr) | archaemenid time + Phase 3 PASS | **PENDING Phase 3 closeout** |
| B | r8169 driver Phase 5 (audit doc + Attempt 92+ burn) | archaemenid time + Phase 4 PASS | **PENDING Phase 4 closeout** |
| C | i225-V driver | dedicated Intel iron (ideally i9 post-migration) + r8169 closeout | **PENDING r8169 closeout + Intel iron** |
| D | First-LAN-packet iron-debut burn | archaemenid time + bites A + B closeout | **PENDING bite B Phase 5 closeout** |
| E | Cycle-close sweep + transcript | bite D PASS | **PENDING bite D PASS** |
| Userland | BBS server scaffold | bite A (tcp_listen) + 1.33.x WRITE for persistence | **DEFERRED to its own cycle** |
| Userland | MUD server scaffold | bite A (tcp_listen) + 1.33.x WRITE for persistence | **DEFERRED to its own cycle** |

## 6. Cyrius-conventions translation notes

When porting from the multi-source references above, the following Cyrius-specific patterns apply (saved here so the porter doesn't have to re-derive them):

- **`var X[N]` allocation unit differs by scope**: module-global `var X[N]` = N×u64 (8N bytes); function-local `var X[N]` = N bytes. Critical for descriptor-ring allocation: a 64-entry × 16-byte TX ring needs 1024 bytes total. As a **module-global** allocation that's `var tx_ring[128]` (128 × 8 = 1024). As a **function-local** it would be `var tx_ring[1024]`. Memory: [[feedback_cyrius_var_array_u64_units]] + canonical example at `agnos/kernel/core/ext2.cyr:28-44`.
- **No PS/2 path** — already encoded in [[feedback_no_ps2_suggestions]]. NIC drivers are PCI-only on AGNOS targets; no legacy bus paths.
- **Build flags** for compile-gated test surface (mirror `KTEST` / `XHCI_VERBOSE` / `RAMDISK_ENABLE`): use `NIC_VERBOSE=1` style flags for diagnostic logging that's compiled-out by default. Per [[feedback_no_serial_on_iron]] — serial-only diagnostics are INVISIBLE on archaemenid; use CMOS extended-bank stamps + visual FB lines for iron-readable diagnostics.
- **No first-principles repair-letter laddering** — per [[feedback_stop_letter_laddering]] + [[feedback_no_letter_codes_for_repairs]] + [[feedback_known_knowledge_first]]. Read the convergent prior art in §§ 1-3 BEFORE generating diagnostic letters from first principles. If a behavior is mysterious, grep this doc for the symptom first.
- **Multi-source convergent** — Linux is ONE source of four. The BSD `re` driver shape is the cleaner reference for the v1 driver; Linux is the source for the chip-revision-quirk dispatch table (deferred to post-v1 expansion).

## 7. Audit disposition

This doc is **durable across sessions** — survives Claude's cold-boot context loss and archaemenid's cold-boot CMOS resets. Re-grep before generating any r8169 / i225-V / TCP-server diagnostic from scratch.

Companion docs (planned, PENDING the matching code-bite landing):

- `r8169-iron-burn-audit.md` — written before Attempt 92's first r8169-on-iron burn (per [[feedback_iron_burns_block_other_work]] — no burn proposed without a written line-by-line audit FIRST).
- `i225-v-iron-burn-audit.md` — written before the Intel-iron i225-V debut burn.

This is the parent doc; the iron-burn audits are children. Same pattern as `ext2-ext4-extents-prior-art.md` (parent, 1.31.5 cycle-open) → `ext2-iron-burn-audit.md` (child, 1.31.6 cleanup-cycle bite E) for the storage arc.
