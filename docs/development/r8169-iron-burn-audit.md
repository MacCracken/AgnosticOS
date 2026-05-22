# r8169 / RTL8111/8168 — Pre-Iron-Burn Audit (Attempt 92+)

> **Status**: Open | **Drafted**: 2026-05-22 | **Target burn**: Attempt 92+ — post-bite-B Phases 1-4 landing
>
> Per [[feedback_iron_burns_block_other_work]] — every iron-burn proposal carries a written
> line-by-line audit FIRST. This is the gate for the first real-iron NIC burn on archaemenid.
> Format mirrors [`ahci-iron-burn-audit.md`](ahci-iron-burn-audit.md), [`usb-ms-iron-burn-audit.md`](usb-ms-iron-burn-audit.md),
> and [`ext2-iron-burn-audit.md`](ext2-iron-burn-audit.md) — all three called their target attempt's
> success path correctly, so the format is load-bearing.
>
> **Companion audits**:
> - [`network-arc-prior-art.md`](network-arc-prior-art.md) — multi-source convergent port plan (Linux + FreeBSD + OpenBSD + NetBSD + Haiku + RTL8168 datasheet)
> - agnos CHANGELOG `[1.32.0]` § bite B Phases 1-4 — what landed in code

---

## §1 Scope of the proposed burn

**One burn covers the full r8169 Phase 1-4 stack on archaemenid's onboard NIC** —
PCI discovery + MAC read + reset (Phase 1) + RX ring init (Phase 2) + TX ring init
(Phase 3) + NIC-dispatcher routing through r8169 instead of virtio_net (Phase 4). All
four phases were authored from the convergent multi-source prior art (§ 8 below); none
of them individually justify a separate burn since each builds on the previous and the
information value of the boot log captures all four at once.

This is **also** the burn that retroactively iron-validates bites A (TCP server primitives),
F (UDP server-side), and G (DHCP client) which all landed in QEMU but had the SLIRP-inbound
gap blocking end-to-end smoke. Real-iron r8169 takes SLIRP out of the loop entirely, so the
accept-success TCP path + DHCP full-exchange path validate as side effects of the r8169
RX/TX rings working.

**Build under test (target):**

| Component | Version | Notes |
|---|---|---|
| `agnos` | 1.32.0 (post-bites A+F+G+B Phases 1-4) | First five bites of networking arc landed; r8169 driver complete |
| `gnoboot` | 0.4.2 (unchanged from Attempts 80-91) | Sovereign UEFI handoff, no bootloader-side change |
| `cyrius` | 6.0.1 toolchain (unchanged) | Same as the 1.31.x storage arc closeout |

**Iron-target topology on archaemenid (queried via `lspci`/sysfs 2026-05-22, no burn needed per [[feedback_archaemenid_is_dev_host]]):**

| PCI BDF | Vendor:Device | Rev | Class | Linux iface | Driver | MAC | BARs |
|---|---|---|---|---|---|---|---|
| `0000:01:00.0` | `10ec:8168` | 0x15 | `0x020000` (Ethernet) | `enp1s0` | `r8169` | `b0:41:6f:0c:e4:25` | BAR0 = I/O `0xF000` (256 B); **BAR2 = MMIO `0xFCF04000` (4 KB, 64-bit)** ← driver target; BAR4 = MMIO `0xFCF00000` (16 KB, MSI-X table region — Phase 2+ scope) |

**Subsystem ID**: `10ec:0123` (Realtek-branded subsystem; some Beelink SER variants use a custom subsystem ID, this board uses the vanilla Realtek one).

**Wi-Fi NIC also on archaemenid** (Intel AX200 at `0000:02:00.0`, `8086:2723`) — **out of scope** for this burn. AGNOS has no Wi-Fi stack and this driver doesn't touch it.

---

## §2 What this burn ADDS to the iron coverage matrix

| Phase | Pre-burn coverage | This burn delivers |
|---|---|---|
| Phase 1 — PCI discovery + MMIO mapping + MAC read + reset | QEMU silent no-op (no Realtek device); pure-code-port from convergent refs + iron-anchored from `lspci`/sysfs | First execution of the discovery sequence on actual silicon; first MAC read from real EEPROM; first CR.RST=1 → poll-until-clear round-trip on real hardware |
| Phase 2 — RX descriptor ring + 16 buffer pages + r8169_poll | QEMU silent (no Realtek RX path); init code never runs in QEMU | First DMA-coherent descriptor ring on this driver; first RX-buffer-pool allocation via pmm_alloc; first RDSAR_LO/HI MMIO write |
| Phase 3 — TX descriptor ring + 16 buffer pages + r8169_send + TPPoll kick | Same QEMU silence | First TX descriptor ring; first TPPoll NPQ kick on real silicon |
| Phase 4 — NIC dispatcher (nic_ready / nic_send / nic_poll) | QEMU validates the dispatcher's virtio_net-fallback path (the **DHCP DISCOVER egress under boot smoke** confirmed nic_send correctly falls through to virtio_net when r8169 is absent) | First time the dispatcher's r8169 branch actually runs — egress via r8169_send, ingress via r8169_poll |
| Bite A scenario 1 — TCP accept-success | QEMU FAIL (SLIRP-inbound gap; bite A scenario 2 listen-no-connect passes) | Real-LAN TCP probe from another host validates the full passive-open SYN handler + SYN_RCVD→ESTABLISHED transition path end-to-end |
| Bite G — DHCP full cycle | QEMU FAIL (DISCOVER egress works, OFFER never arrives — same SLIRP-inbound gap) | Real-LAN DHCP server (the user's gateway) responds; full OFFER → REQUEST → ACK cycle; net_ip / net_gateway / net_netmask populated from the LAN's actual DHCP lease |

**Storage trio (NVMe / AHCI / USB-MS) regression check**: silent in this burn — no relevant storage code changed since Attempt 91. Boot log should byte-match the storage section of Attempt 91 below the agnos kernel banner.

---

## §3 Hypothesis ranking — what could go wrong on iron vs. QEMU

Ranked by iron-specific risk. Each row carries a likely-outcome label (Full PASS / Partial / Falsified) so the post-burn classifier has a defined target.

| # | Hypothesis | Risk | Likely-outcome if true | Mitigation already in code | Triage path |
|---|---|---|---|---|---|
| **H1** | **PHY not configured → link absent → RX/TX silent but probe lines correct.** RTL811x has an internal PHY that needs MDIO programming for autonegotiation. Linux's `r8169_phy_config_*` family writes ~10-40 MDIO registers per chip revision; AGNOS v1 driver writes **zero** MDIO. The chip may default to a working PHY config (most boards do post-EEPROM-load), or it may default to power-down. | **HIGH** | Partial — Phase 1-3 lines all print correctly; bite A scenario 1 + DHCP both fail (no inbound packets because no link). | None at v1 — explicit Phase 2+ deferral. | If observed: capture the Phase 1-3 print lines (proves driver shape); next burn writes a minimal PHY-init sequence ported from OpenBSD's `re_phy_init` (simplest converged ref). |
| **H2** | **Chip-revision-specific reset quirk → reset times out.** Some RTL811x revs need pre-reset steps (PHY power-down via 0x12 MDIO register, FLASH-control disable, …). The `rtl_hw_reset` in Linux's `r8169_main.c` does more than just `CR.RST=1`. Driver v1 does only the bare CR.RST=1 + poll. Rev 15 is RTL8168f-vl or RTL8168g-vl per the Linux mac_version table — likely needs no pre-reset. | MEDIUM | Falsified — `r8169: reset timeout (CR.RST stayed set)` prints; subsequent phases don't run; boot continues without NIC. | 1000-iteration poll timeout — won't hang. | If observed: port Linux's mac_version dispatch table for rev 15 specifically; one chip-rev entry, not the full ~50. |
| **H3** | **MAC read returns garbage** (e.g., all 0xFF, all 0x00, or a Realtek-default `52:54:00:…`). EEPROM auto-load may not have happened on cold boot, or this board's EEPROM is empty and the OS-visible MAC came from a Linux-side-set rather than the EEPROM. | LOW | Partial — Phase 1 line shows MAC mismatch with `b0:41:6f:0c:e4:25`. Other phases still run since MAC isn't load-bearing for ring setup. | None — read at MMIO offset 0 is the spec-canonical EEPROM-loaded path. | If observed: capture MAC bytes from boot log + `dmesg` from a Linux boot on the same iron right after; compare. If EEPROM is empty, Linux is probably reading from `/sys/class/net/.../address` which is sw-cached — note the gap, defer. |
| **H4** | **BAR2 mapping wrong** — `pci_bar_64(idx, 2)` returns a value that's not the actual MMIO base. Possible if `pci_record` (the PCI probe step) misparses 64-bit BARs and stuffs the high half into the wrong slot. | LOW | Falsified — any subsequent MMIO read returns garbage (0xFF or 0x00), most likely the MAC bytes will be all 0xFF (or all zero), reset times out, kernel may also fault if the address lands in an unmapped region. | Explicit BAR2 → BAR4 fallback in r8169_probe; refuses cleanly if both are zero. | If observed: read `r8169: found at <N>` line, compare against sysfs `resource` line for BAR2; if mismatch is in the high 32 bits → confirms a pci_record 64-bit-BAR parse bug. |
| **H5** | **Bus master not enabled correctly for r8169** — `pci_enable_bus_master_idx` works for nvme/xhci/ahci but its byte/bit pattern doesn't reach the right config-space register for this chip. | LOW | Partial — probe + MAC + reset all PASS (those use CPU-side MMIO, no bus mastering needed). RX/TX rings init lines also PASS (still CPU-side). But no DMA actually happens — RX descriptors stay OWN=1 (NIC never writes back), TX descriptors with OWN=1 stay set (NIC never reads). | Reuse of the call shape that works for nvme/ahci/xhci — three drivers validating the same primitive. | If observed: capture full boot log + post-mortem read CR (offset 0x37) on the NIC — RE + TE bits should be set; if they are, bus-master issue is upstream of the driver in the PCI config write. |
| **H6** | **vmm_remap_uc_2mb hits a different cache attr** for this BAR than for nvme/xhci/ahci BARs. Same `vmm_remap_uc_2mb` call shape, but PAT entry 1 (UC) might apply differently depending on PAT MSR state at the time of remap. | LOW | Falsified — MMIO reads return cached stale values; MAC read returns garbage on second read (cached); reset poll falsely sees CR.RST clear before it actually is. Likely cascades into a crashed driver. | Same call as nvme/xhci/ahci. | If observed: read the PAT MSR (0x277) and the relevant page table entry post-remap, confirm UC; if `fb_console.cyr` PAT entry 1 is still WC from FB-arc, vmm_remap_uc_2mb may need to track per-BAR PAT entry. |
| **H7** | **TX OWN never clears after kick** — descriptor written with OWN=1+FS+LS+len, TPPoll NPQ written, but NIC doesn't process. Most likely cause: TxConfig not written before CR.TE was set (driver writes them in the wrong order). | MEDIUM-LOW | Partial — TX ring init prints OK, but DHCP DISCOVER / ARP egress completes from the driver's POV (returns len) but no packet actually leaves the NIC. RX side may receive normally. | TxConfig is written **before** CR.TE in r8169_init_tx (verified at code-write time). | If observed: dump TX descriptor 0 status after first send attempt; if OWN=1 persisted → NIC didn't process → likely PHY-related (no link to send on, same as H1) OR TxConfig issue. |
| **H8** | **RX OWN never clears** — NIC doesn't receive packets despite RxConfig + CR.RE. Same root-cause shape as H7 in reverse. | MEDIUM-LOW | Partial — RX ring init prints OK; r8169_poll always returns 0; nic_poll falls through to virtio_net_poll which returns 0 too (no virtio device on iron); net_poll silent; DHCP OFFER never arrives. | RxConfig is written **before** CR.RE in r8169_init_rx. | If observed: same dump approach as H7 but RX side. If a packet WAS DMA'd into the buffer (read first ~64 bytes of `r8169_rx_bufs[0]`) but OWN bit still set → driver-side bit-decode issue. If buffer is empty + OWN=1 → DMA-coherency or bus-master issue (escalates to H5). |
| **H9** | **Spurious interaction with coexisting xhci / nvme / ahci on the PCIe bus** — these drivers have been iron-validated independently but never together with a sixth bus-mastering device added to the mix. PCIe arbitration is implicit-fair on the root complex but bursty MMIO writes during r8169 init might starve another driver's in-flight request. | LOW | Falsified — boot log shows storage trio (nvme/ahci/msc) starts failing where it succeeded at Attempt 91. Most likely symptom: AHCI port enumeration fails or NVMe command-ready times out. | None — kernel doesn't gate concurrent driver init. | If observed: post-mortem boot log should show WHERE the regression hit; bisect by guarding `r8169_probe()` behind a build flag to confirm causality. |

---

## §4 What to NOT do on this burn

Per [[feedback_no_instrumentation_means_no_instrumentation]] + [[feedback_iron_burns_block_other_work]]:

- **NO MSI / MSI-X interrupt configuration** — polling-only at v1 (matches virtio_net pattern); MSI-X programming is bite Phase 2+ scope.
- **NO chip-revision dispatch table** — single-rev driver targeting 0x8168 family broadly; if H2 fires, that's the next-burn fix.
- **NO ASPM workarounds** — Linux has extensive ASPM-disable code for buggy silicon; AGNOS skips it by default; only revisit if a specific symptom surfaces.
- **NO jumbo frame (MTU >1500) support** — RMS programmed for standard 1518 + headroom; jumbo is a perf concern, not a functional one.
- **NO RX checksum offload / VLAN tagging** — software checksum in net.cyr is already exercised; offload adds non-trivial code path with no BBS/MUD justification.
- **NO IRQ-driven RX** — net.cyr's `net_poll()` runs in the kernel idle loop; polling is the working pattern.
- **NO i225-V driver code in this burn** — bite C is a separate burn after r8169 closeout.
- **NO bundled non-r8169 instrumentation** — no CMOS stamps added beyond what's already in main.cyr; no extra kprintln noise; no "while we're at it" cleanups in storage drivers.
- **NO PHY init code** — explicit deferral per H1's mitigation column; if H1 fires, that's the next-burn fix.

---

## §5 Success rubric

The burn produces one of five outcomes. Classify by boot log + (if iron has Ethernet cable) network behavior.

### Full PASS

Required boot log lines (after the existing storage trio + ACPI/PCI banner):

```
r8169: found at 4243210240
r8169: MAC=176:65:111:12:228:37
r8169: chip-rev byte=0x<N> (Phase 2+ decodes the family)
r8169: reset OK; Phase 1 complete
r8169: RX ring up (16 desc × 2KB buf)
r8169: TX ring up (16 desc × 2KB buf)
```

Where:
- `4243210240` = decimal of `0xFCF04000` (BAR2 phys, confirmed via sysfs)
- `176:65:111:12:228:37` = decimal bytes of `b0:41:6f:0c:e4:25` (MAC from sysfs `ip link show enp1s0`)
- `<N>` is the TxConfig high byte; Linux's mac_version table maps `0x2C = MAC_VER_2C = RTL_GIGA_MAC_VER_35 (RTL8168f)` family — exact value to be captured at burn time

**AND** (Ethernet cable connected to LAN with DHCP server):

```
dhcp: DISCOVER
dhcp: OFFER ip=<lan IP>
dhcp: REQUEST
dhcp: ACK ip=<lan IP> gw=<lan gw> mask=<lan mask>
```

**AND** (if bite A scenario 1 host probe is run from another LAN machine to the AGNOS-assigned IP):

```
tcp_accept: conn_id=1
```

with the host-side seeing the `AGNOS 1.32.0 tcp_listen smoke` banner.

**AND** storage trio enumeration unchanged from Attempt 91 (NVMe / AHCI / USB MS lines byte-match).

### Partial — Probe + reset OK, no link (H1 — most likely if PHY init defaults wrong)

Phase 1+2+3 lines all print correctly; DHCP exits with `dhcp: OFFER timeout`; bite A scenario 1 fails. This is the "RX/TX rings work but there's nothing on the wire" outcome. Triage path: H1 mitigation column.

### Partial — MAC garbage (H3)

Phase 1 MAC line shows mismatch with `b0:41:6f:0c:e4:25`. Phase 2/3 lines still print. Triage: H3 mitigation column.

### Partial — RX works, TX doesn't (H7) OR TX works, RX doesn't (H8)

Asymmetric egress/ingress failure. Triage: H7 or H8 column.

### Falsified — kernel doesn't reach shell

Most severe. Boot log truncates before `kybernet: launching shell`. Triage paths: H2 (reset hang), H6 (PAT issue), H9 (cross-driver interaction). Bisect by guarding `r8169_probe()` behind a build flag → if boot recovers, r8169 driver IS causal.

---

## §6 Mitigations applied this burn (already in code, recap)

- **Page-aligned descriptor rings** — `pmm_alloc()` returns 4 KB pages = 256-byte-aligned ≫ spec requirement (16-byte aligned). No alignment fault possible.
- **BAR2 → BAR4 fallback** — covers both common RTL811x MMIO layouts.
- **Bounded reset poll** — 1000 iterations max; no infinite loop.
- **Descriptor format converged across 5 references** — Linux + FreeBSD + OpenBSD + NetBSD + Haiku all agree on OWN[31] / EOR[30] / FS[29] / LS[28] / len[13:0]. Bit positions are correct.
- **CRC strip on RX** — length field includes 4-byte FCS per RTL8168 datasheet §6.7; driver subtracts it before returning packet bytes.
- **Init order**: TxConfig written before CR.TE; RxConfig + RMS written before CR.RE. Linux/BSD ordering preserved.
- **`nic_send` / `nic_poll` graceful fallthrough** — if r8169 isn't initialized but virtio_net is, dispatcher routes through virtio_net. QEMU smoke confirmed this works (DHCP DISCOVER egress).
- **`nic_ready()` gate** — net.cyr's send paths refuse to even build packets if no NIC is up. Pre-existing `vnet_active == 0` gates all migrated to this.

---

## §7 CMOS post-mortem checkpoints — NOT reserved for this burn

Unlike prior driver iron debuts (NVMe Phase 1 used kcps 0x40-0x48; AHCI used 0x4B-0x50; MSC used 0x55-0x5A), **r8169 v1 does NOT add CMOS stamps**. Reasoning:

1. **Boot log is FB-visible**: `kprint`/`kprintln` write to both serial AND framebuffer per `kernel/core/kprint.cyr`. archaemenid's FB-console renders these on the monitor — they're iron-visible without CMOS extended-bank reads.
2. **No hang risk justifies stamps**: H2 (reset hang) is bounded by the 1000-iteration poll; the kernel won't actually hang in r8169_probe. The only Falsified outcome that loses boot output is H6 (PAT issue) or H9 (cross-driver), and those don't have a unique "stamp-this-bit-and-die" location either.
3. **Stamp budget reserved for harder-to-diagnose subsystems**. r8169 init prints ~6 lines; if any line is missing the post-mortem path is obvious.

If H1 fires and we add PHY init next-burn, **THEN** reserve kcp 0x60 = PHY power-down done, 0x61 = autoneg started, 0x62 = link detected — at that point the steps are dense enough to need atomic stamps. Not this burn.

---

## §8 Multi-source prior art consulted

See [`network-arc-prior-art.md`](network-arc-prior-art.md) § 1 for the full convergent-shape table and per-source citation map. Brief summary of where each piece came from:

| Driver primitive | Primary reference | Cross-validated against |
|---|---|---|
| PCI dev-ID table (0x8168 / 0x8169 / 0x8161 match priority) | Linux `drivers/net/ethernet/realtek/r8169_main.c` `rtl8169_pci_tbl` | FreeBSD `if_re.c` `re_devs` |
| BAR2 = MMIO; BAR0 = I/O fallback | RTL8168/8111 datasheet §3.2 | All four BSD/Linux/Haiku refs |
| Reset sequence (CR.RST=1, poll) | OpenBSD `re.c` `re_reset` (simplest converged form) | Linux + FreeBSD + Haiku |
| 16-byte descriptor format (OWN/EOR/FS/LS/len) | RTL8168 datasheet §6.7 | All four BSD/Linux/Haiku refs (byte-identical layout) |
| RxConfig defaults (`0xE700 \| AB \| AM \| APM`) | Linux `RTL_CFG_RX_DEFAULTS` macro | FreeBSD `re_rxcfg_defaults` |
| TxConfig defaults (`0x03000700`) | Linux `RTL_CFG_TX_DEFAULTS` macro | FreeBSD analogous |
| TPPoll NPQ kick (`bit 6 = 0x40`) | Datasheet §6.7 + Linux | FreeBSD + OpenBSD |
| 4-byte FCS strip in RX length | Datasheet §6.7 explicit | All BSD refs do the same subtraction |

**Linux is one of four refs**, not the singular reference, per [[feedback_redesign_dont_reinvent]]. The shape this driver implements is the **converged shape** across all four BSD/Linux/Haiku — Linux supplies the largest scope (most chip-rev variants in dispatch table) but BSD `re` is the cleaner reference for the init sequence.

---

## §9 Audit disposition

**Ready to burn.** The code is structurally complete and regression-clean (4/4 test.sh + QEMU boot smoke confirming nic_send dispatcher works on the no-r8169 path). The remaining unknowns are iron-specific (H1-H9 above) and each has a defined triage path.

**Iron-burn checklist for user**:

1. Confirm `agnos/build/agnos` is current: should show 600,432 B (post-Phases-2-4 production size; 600,520 B if last-built with TCP_LISTEN_SMOKE=1, which is harmless for this burn). Current mtime should be from today's session.
2. From the agnosticos repo root: `sh scripts/install-usb.sh --update` to flash the kernel onto the boot USB.
3. Connect Ethernet cable to archaemenid's onboard NIC (the back-port wired NIC, not Wi-Fi) **if you want full validation** including DHCP + LAN ICMP. Cable-optional if validating just Phase 1-3 init lines.
4. Boot archaemenid from the USB stick (existing dev surface).
5. Capture boot-log photo when the kernel reaches the shell prompt. Six `r8169:` lines should appear between `Net: 10.0.2.15/24 gw 10.0.2.2` (the net_init fallback) and `kybernet: starting init`.
6. If Ethernet was connected: observe whether `Net:` line gets overwritten by `dhcp: ACK ip=<lan-IP>` (LAN-assigned address); separate-machine TCP probe to the LAN-IP:8080 validates bite A scenario 1.

**Pass-by-pass success classification** (per § 5): photo capture first, classification post-photo. No "while you're up there" instrumentation requests per [[feedback_iron_burns_block_other_work]] — if H1 fires, the NEXT burn carries PHY-init code; this burn validates exactly what's in the build.

**Next document on PASS**: this audit closes; companion `r8169-iron-burn-receipt.md` (or section in `iron-nuc-zen-log.md`) records the captured boot lines + per-hypothesis outcome + photos. State.md bite B row flips to `Phase 5 ✅ CLOSED — iron-validated at Attempt 92+`.

**Next document on Partial/Falsified**: per § 3 triage columns, the relevant hypothesis-fix lands in code as the next bite (smallest-first; one hypothesis per repair to avoid bundling per [[feedback_stop_letter_laddering]]); audit doc closes with the partial outcome captured; new audit doc opens for the repair burn.
