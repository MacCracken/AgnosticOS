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

---

## §10 — Post-Attempt-93 audit extension (§5b — now-reachable H1/H7/H8 surface)

This section opens at agnos **1.32.1 cycle-open** (2026-05-22) per the user-stated discipline: *"track items we still need to write work for, wait until on that particular iron."* It extends § 3 + § 5 with the post-burn reality: Attempt 92 (PARTIAL — pre-fix) + Attempt 93 (PARTIAL — gate-fix verified) collapsed the 9-hypothesis pre-burn surface to **three now-reachable candidates** (H1 / H7 / H8). Bites A-D of the 1.32.1 cycle execute against this section's findings.

### §10.1 — What Attempt 93 changed about reachability

Pre-burn (§ 3) ranking treated H1-H9 as **independent unknowns** because no iron evidence existed. Attempts 92 + 93 collected evidence that **eliminates six of the nine hypotheses** as the proximate cause of `dhcp: OFFER timeout`:

| # | Pre-burn status | Post-93 status | Reason |
|---|-----------------|----------------|--------|
| H1 (PHY not configured) | HIGH risk | ⚠️ **REACHABLE — top candidate** | All six `r8169:` Phase 1-3 lines printed clean; ring init succeeded; the failure mode is *exactly* the "Phase 1-3 lines all print correctly; DHCP exits with OFFER timeout" outcome predicted in §5 *"Partial — Probe + reset OK, no link"*. |
| H2 (chip-revision reset quirk) | MEDIUM | ❌ falsified | `r8169: reset OK; Phase 1 complete` printed. Reset succeeded within the 1000-iteration poll. |
| H3 (MAC read garbage) | LOW | ❌ falsified | `r8169: MAC=176:65:111:12:228:37` = `b0:41:6f:0c:e4:25` byte-matches lspci. EEPROM auto-load worked. |
| H4 (BAR2 mapping wrong) | LOW | ❌ falsified | `r8169: found at 4243603456` = 0xFCF04000 byte-matches lspci BAR2. MMIO base correct. |
| H5 (bus master not enabled) | LOW | ⚠️ **REACHABLE — re-elevated** | Pre-burn this was LOW because the same call works for NVMe/AHCI/xHCI. Post-93 it stays viable as a secondary candidate for *both* H7 and H8: if the NIC has the bus-master enable bit cleared, RX descriptors stay OWN=1 (NIC can't DMA into them) and TX descriptors with OWN=1 stay set (NIC can't DMA out of them). Identical symptom shape to H1, distinguishable only by post-mortem CR / PCI cmd register read. |
| H6 (PAT/cache attribute) | LOW | ❌ falsified | If PAT was wrong, MMIO reads would have returned stale/cached values — MAC bytes would have read garbage on the second access pattern, or chip-rev would have been wrong. Both read clean. |
| H7 (TX OWN never clears) | MEDIUM-LOW | ⚠️ **REACHABLE** | DISCOVER was built + handed to `r8169_send` (gate-fix VERIFIED on iron — `dhcp: DISCOVER` egress line printed). The frame **reached** the driver; whether it left the NIC is unknown. Driver code has no TX OWN poll-back to disambiguate. |
| H8 (RX OWN never clears) | MEDIUM-LOW | ⚠️ **REACHABLE** | OFFER may have arrived but `r8169_poll` returned 0 every iteration. Distinguishable from "no OFFER on the wire" only by reading the RX ring head/tail and the buffer contents post-timeout. |
| H9 (cross-driver interaction) | LOW | ❌ falsified | Storage trio (NVMe/AHCI/USB-MS) + GPT + ext4 mount + shell launch all byte-clean across Attempts 92 + 93. No symptom of arbitration starvation. |

**Net**: H1 + H5 + H7 + H8 stay open; H1 is the highest-probability *root* cause; H5 + H7 + H8 are *downstream* of an H1 failure (all three present identically when there's no link to clock the PHY). Discriminating between them requires post-mortem driver state — which the kernel currently has zero observability into. That's bite B (discriminator instrumentation) of the 1.32.1 cycle.

### §10.2 — H1 (PHY not configured) — line-by-line vs current `r8169.cyr` + multi-source convergence

**Current code (file: `agnos/kernel/core/r8169.cyr`)**:

- `r8169_probe()` at line 155-234 — does PCI probe (line 156), MMIO BAR discovery (167-176), bus-master enable (179), result cache (182-187), MAC read (190-192), chip-rev capture (198-199), **CR.RST=1 soft reset + 1000-iteration poll** (205-217), summary print (220-232). **Zero PHY-side register writes.**
- `r8169_init_rx()` at line 249 — programs RDSAR, RxConfig, RMS, sets CR.RE. **Zero PHY-side register writes.**
- `r8169_init_tx()` at line 336 — programs TNPDS, TxConfig, MTPS, sets CR.TE. **Zero PHY-side register writes.**

The chip's internal PHY (RTL8211B/C/D depending on chip-rev byte 0x87 = RTL8168f-vl or RTL8168g-vl family per Linux's `mac_version` table) reaches power-on default state, which **may or may not** be "autoneg-enabled + link-up-once-cable-detected." For some board EEPROM configurations the PHY comes up clean; for others it stays in power-down or with autoneg disabled. archaemenid's Beelink SER falls in the latter group per the Attempt 93 outcome — DISCOVER egress was attempted, no OFFER returned within the timeout window, no link-state transition fired.

**Multi-source convergence on minimum PHY init** (consulted per [[feedback_redesign_dont_reinvent]]):

| Source | PHY-init shape | Where |
|--------|----------------|-------|
| Linux `r8169_main.c` | Full per-mac_version dispatch table (`rtl_hw_phy_config_*` family, ~10-40 MDIO writes each, 50+ chip-rev branches) | `drivers/net/ethernet/realtek/r8169_phy_config.c` |
| FreeBSD `if_re.c` | `re_phy_power_up` (BMCR bit 11 = power-down → 0, then autoneg-restart) + `mii_attach`-based autoneg | `sys/dev/re/if_re.c` |
| OpenBSD `re.c` | `re_phy_init` — simplest converged form: write BMCR (reg 0) with autoneg-enable + restart-autoneg; poll BMSR (reg 1) bit 2 for link-up | `sys/dev/ic/re.c` |
| NetBSD `re.c` | Mirror of OpenBSD shape with explicit timeout (3000ms) | `sys/dev/ic/re.c` |
| Haiku | `RealtekRTL8169Family.cpp` mirrors OpenBSD shape | `src/add-ons/kernel/drivers/network/ether/rtl8169/` |
| RTL8168/8111 datasheet | §11 (PHYAR register at offset 0x60) + §13 (PHY register map: BMCR=0, BMSR=1, ANAR=4, GBCR=9, etc.) | RealTek RTL8168E-VL datasheet |

**Converged minimum PHY init** (OpenBSD `re_phy_init` shape; the simplest cross-validated form across all four BSD refs):

```
1. Write BMCR (PHY reg 0) = 0x1200 via MDIO
   (BIT 12 = autoneg-enable, BIT 9 = restart-autoneg; BIT 11 = power-down stays 0)
2. Poll BMSR (PHY reg 1) bit 2 (LinkStatus) with timeout (~3000ms typical;
   actual link establishment varies by switch — usually <1s on a hot cable)
3. Optionally read BMSR bit 5 (autoneg-complete) for explicit confirmation
4. Print link state (e.g., "r8169: link up (autoneg complete)")
```

**RTL811x MDIO interface** (RealTek datasheet §11 — PHYAR register at MMIO offset 0x60):

- **PHYAR layout**: bit 31 = Flag (write-direction trigger / read-direction completion); bits 25:21 = reserved; bits 20:16 = PHY register address (5 bits, 0-31); bits 15:0 = data.
- **Write protocol**: set bit 31 + reg-addr in bits 16:20 + data in bits 0:15; poll bit 31 until clear (chip clears on completion; typical 1-10 µs).
- **Read protocol**: clear bit 31 + reg-addr in bits 16:20; poll bit 31 until set (chip sets on read completion; data appears in bits 0:15).

**Proposed Cyrius shape** (lands at bite C if discriminator confirms H1):

```
fn r8169_phy_read(reg) {
    var par = (reg & 0x1F) << 16;        # bit 31 = 0 (read direction)
    store32(r8169_mmio_base + 0x60, par);
    # Poll for completion (bit 31 set = chip wrote the result)
    for (var i = 0; i < 1000; i = i + 1) {
        var r = load32(r8169_mmio_base + 0x60);
        if ((r & 0x80000000) != 0) {
            return r & 0xFFFF;
        }
    }
    return 0xFFFF;                         # timeout sentinel
}

fn r8169_phy_write(reg, val) {
    var par = 0x80000000 | ((reg & 0x1F) << 16) | (val & 0xFFFF);
    store32(r8169_mmio_base + 0x60, par);
    # Poll for completion (bit 31 cleared = chip processed the write)
    for (var i = 0; i < 1000; i = i + 1) {
        var r = load32(r8169_mmio_base + 0x60);
        if ((r & 0x80000000) == 0) { return 1; }
    }
    return 0;                              # timeout
}

fn r8169_phy_init() {
    # Restart autonegotiation. BMCR bit 12 = autoneg-enable; bit 9 = restart-autoneg.
    var bmcr = r8169_phy_read(0x00);       # current BMCR
    bmcr = bmcr | 0x1200;                  # autoneg-enable | restart-autoneg
    bmcr = bmcr & 0xF7FF;                  # clear power-down (bit 11) just in case
    r8169_phy_write(0x00, bmcr);

    # Poll BMSR (reg 1) bit 2 for link-up. ~3 seconds at 1ms granularity
    # is the BSD-converged timeout; we use a busy-loop approximation.
    for (var i = 0; i < 300; i = i + 1) {
        var bmsr = r8169_phy_read(0x01);
        if ((bmsr & 0x0004) != 0) {        # bit 2 = link-up
            kprintln("r8169: link up", 13);
            return 1;
        }
        # ~10ms busy delay (TBD — could be a pmm_alloc-amount of cycles)
        for (var j = 0; j < 100000; j = j + 1) { }
    }
    kprintln("r8169: no link (autoneg timeout)", 32);
    return 0;
}
```

Call site: append to `r8169_probe()` after step 8 (reset OK), before step 9 (summary print) — so the new line "r8169: link up" or "r8169: no link (autoneg timeout)" prints in the existing six-line block.

**Estimated LOC**: ~80 LOC (~30 helper + ~30 init + comments). Minimum-viable form per BSD-converged shape; no per-chip-rev dispatch.

### §10.3 — H7 (TX OWN bit stuck after kick) — line-by-line vs `r8169_send`

**Current code (`r8169.cyr:390-415`)**:

```
fn r8169_send(buf, len) {
    ...
    var desc = r8169_tx_ring_phys + r8169_tx_idx * 16;
    var status = load32(desc);
    if ((status & 0x80000000) != 0) { return 0 - 1; }   # ring full

    var bufaddr = load64(&r8169_tx_bufs + r8169_tx_idx * 8);
    for (var i = 0; i < len; i = i + 1) {
        store8(bufaddr + i, load8(buf + i));
    }

    # Set OWN | FS | LS | length; preserve EOR on last descriptor.
    var new_status = 0x80000000 | 0x20000000 | 0x10000000 | len;
    if (r8169_tx_idx == 15) { new_status = new_status | 0x40000000; }
    store32(desc, new_status);

    # Kick TX engine: write NPQ bit (0x40) to TPPoll.
    store8(r8169_mmio_base + 0x38, 0x40);

    r8169_tx_idx = (r8169_tx_idx + 1) & 0x0F;
    return len;
}
```

**What current code does**: writes desc[idx] with `OWN=1 | FS=1 | LS=1 | length` (correct single-segment frame layout per § 8 datasheet convergence), kicks TPPoll NPQ, returns. **Crucially: no post-kick poll-back to verify TX OWN cleared.**

**What Linux/FreeBSD do for the same primitive**:

- **Linux `r8169_main.c` `rtl8169_xmit`**: writes desc with `DescOwn | FirstFrag | LastFrag | size`, wmb() barrier, writes TX_POLL (= NPQ on the IO port form), schedules NAPI poll. Post-kick visibility comes from NAPI's `rtl8169_tx_interrupt` polling TX completions. Driver doesn't synchronously verify each descriptor's OWN-clear; relies on the interrupt/NAPI for batch reclaim.
- **FreeBSD `if_re.c` `re_encap`**: writes desc with own bit, calls bus_dmamap_sync, then `CSR_WRITE_1(sc, RE_TPPOLL, RE_NPQ)`. Same pattern — no synchronous poll-back; relies on `re_intr` for completion.
- **OpenBSD `re.c` `re_encap`**: identical shape.

**Verdict for H7 candidacy**: current `r8169_send` matches all three converged refs **structurally** — same write pattern + kick. The ONLY material difference is that all three refs run their drivers with TX completion interrupts; AGNOS polls. **For DHCP DISCOVER** specifically:

- AGNOS builds DISCOVER, calls `r8169_send` → write desc + kick → return len → DHCP state machine logs `dhcp: DISCOVER` → enters wait loop.
- Wait loop calls `net_poll` → `nic_poll` → `r8169_poll` (RX only).
- If TX completion didn't actually happen (PHY no-link, NIC won't push frame), descriptor stays OWN=1; next `r8169_send` call would return -1 (ring full at TX idx 0).
- We don't call `r8169_send` again during the DHCP timeout window, so the TX-side stuck-state is **invisible from the boot log** — same observable as H1 (PHY no-link) and H8 (RX never delivers).

**H7 as primary cause is unlikely** (no code shape difference from BSD-converged refs that would cause stuck-OWN by itself) — but H7 as **side effect of H1** is the actual mechanism. If PHY isn't configured, TX frames sit with OWN=1 forever even though the driver code is correct. Distinguishing H1-driven-H7 from H7-as-root requires post-mortem observability.

### §10.4 — H8 (RX OWN bit stuck) — line-by-line vs `r8169_poll`

**Current code (`r8169.cyr:306-334`)** (reproduced from grep + context — full read available):

```
fn r8169_poll(buf, maxlen) {
    ...
    var desc = r8169_rx_ring_phys + r8169_rx_idx * 16;
    var status = load32(desc);
    if ((status & 0x80000000) != 0) { return 0; }       # NIC still owns (empty)

    # OWN=0: NIC wrote a packet. Read length (strip 4-byte FCS).
    var len = (status & 0x3FFF) - 4;
    if (len > maxlen) { len = maxlen; }

    var bufaddr = load64(&r8169_rx_bufs + r8169_rx_idx * 8);
    for (var i = 0; i < len; i = i + 1) {
        store8(buf + i, load8(bufaddr + i));
    }

    # Re-arm descriptor: clear status, set OWN | BUF_SIZE, preserve EOR.
    var new_status = 0x80000000 | 2048;
    if (r8169_rx_idx == 15) { new_status = new_status | 0x40000000; }
    store32(desc, new_status);

    r8169_rx_idx = (r8169_rx_idx + 1) & 0x0F;
    return len;
}
```

**What current code does**: reads desc[idx] OWN bit; if OWN=1 (NIC owns, empty), return 0; if OWN=0 (NIC wrote a packet), copy buffer to caller, re-arm descriptor with OWN=1, advance.

**Multi-source convergence**: same primitive pattern in Linux `rtl8169_rx_interrupt`, FreeBSD `re_rxeof`, OpenBSD `re_rxeof`, NetBSD `re_rxeof`, Haiku. Driver code is **structurally correct**.

**Verdict for H8 candidacy**: like H7, H8 as primary cause is unlikely (code shape converges with all five refs) — but H8 as **side effect of H1** is the actual mechanism. With no link, no frame ever arrives on the wire, no RX DMA ever happens, descriptors stay OWN=1 forever, `r8169_poll` returns 0 every call. Same observable as H1 and H7.

### §10.5 — Discriminator instrumentation (bite B — CMOS-bank stamps)

Per [[feedback_no_serial_on_iron]] + [[feedback_no_instrumentation_means_no_instrumentation]] (CMOS extended bank is the only iron-readable channel for non-`kprintln` state), the smallest discriminator set:

| CMOS slot | Stamp condition | Decodes which hypothesis |
|-----------|-----------------|--------------------------|
| 0x60 | written = 1 at end of `r8169_probe()` after reset OK | sanity (probe completed) |
| 0x61 | written = phy-init outcome: 0 = no PHY init done (current state), 1 = link up, 2 = autoneg timeout, 3 = PHY init code reached but BMCR write timed out | **H1 discriminator (after bite C's PHY init lands)** |
| 0x62 | written = `r8169_send` invocation count (high byte; capped at 255 = many sends) | TX-side activity counter |
| 0x63 | written = TX desc 0 OWN bit at moment of read-boot-log post-mortem: 0 = NIC cleared it (TX succeeded at least once), 1 = still NIC-owned (H7 fires) | **H7 discriminator** |
| 0x64 | written = `r8169_poll` invocation count (high byte; capped at 255) | RX-side activity counter |
| 0x65 | written = RX desc 0 OWN bit at post-mortem read: 0 = NIC wrote it (H8 falsified), 1 = NIC never wrote (H8 fires) | **H8 discriminator** |
| 0x66 | written = first 8 bytes of RX desc 0 buffer (high byte of length field) — proves whether DMA happened even if OWN walking is wrong | H8 secondary (DMA happened-but-bit-stuck case) |

Stamps written in two places:
- After `r8169_probe()` returns: stamps 0x60 + 0x61.
- Inside `r8169_send`: increment counter at 0x62; on first invocation after build, also stamp current TX desc state at 0x63.
- Inside `r8169_poll`: increment counter at 0x64; on first OWN=0 transition stamp 0x65; opportunistically stamp 0x66 on first DMA-detect.

Read path: after iron burn, `scripts/read-boot-log.sh` already reads CMOS extended bank — extend with parse rules for 0x60-0x66.

**Estimated LOC**: ~30-60 LOC across `r8169.cyr` (six stamp sites) + ~5 LOC CMOS helper extension if `kcp_write` shape already covers the slot range.

### §10.6 — Corrective-patch shape per hypothesis (bite C)

Order by probability + smallest-fix-first:

1. **H1 fix (primary candidate)**: port BSD-converged minimum PHY init per § 10.2. Adds `r8169_phy_read` / `r8169_phy_write` MDIO helpers + `r8169_phy_init` call hooked into `r8169_probe()` after reset OK. **~80 LOC.** Discriminator: stamp 0x61 transitions from 2 (current "no PHY init done") to 0 = success → 1 = link up. Iron Attempt 94 outcome on success: `r8169: link up` prints between reset OK and Phase 1 complete; DHCP cycle completes (`DISCOVER` → `OFFER ip=…` → `REQUEST` → `ACK ip=…`).

2. **H7 fix (only if discriminator stamp 0x63 = 1 after H1 fix lands)**: TX completion is genuinely stuck. Most likely culprits in order: (a) TPPoll write-width mismatch — currently `store8` to 0x38; verify against datasheet that this register is byte-writable vs requires `store16` / `store32`. (b) TX descriptor's buf_addr DMA mapping — verify the physical address survives translation. (c) NIC's TX TFA/TFD limits (TxConfig bits 10:8 = max DMA burst) — already programmed 0x03000700 = burst=7 (unlimited). **~10-30 LOC** depending on which culprit fires.

3. **H8 fix (only if discriminator stamp 0x65 = 1 after H1 fix lands)**: RX completion is genuinely stuck. Same shape as H7 fix but RX-side. Most likely culprits in order: (a) RxConfig `0xE700 | AB | AM | APM` — verify the four `RxConfig` bits 6:8 (RX FIFO threshold) and 12:8 (MAX_DMA_burst); currently magic constant 0xE700. (b) RDSAR write-width — currently `store32` to 0xE4/0xE8 as 32-bit halves; verify against Linux's `rtl_set_rx_descriptor_base`. **~10-30 LOC.**

If all three discriminators (0x61=success, 0x63=0, 0x65=0) and DHCP **still** times out: escalate to H5 (bus master not enabled correctly) or a deeper datasheet read of section 6.7 (RX/TX state machine semantics on this specific chip rev byte 0x87).

### §10.7 — Cycle ordering for 1.32.1

Per [[feedback_iron_burns_block_other_work]] — every iron burn requires a written audit FIRST. The bite sequence:

1. **bite A (this section)** ✅ in flight — extends audit; lands at 1.32.1 cycle-open.
2. **bite B** — discriminator instrumentation per § 10.5. ~30-60 LOC + smoke validation. Stacks WITH bite C into a single Attempt 94 burn per [[feedback_no_instrumentation_means_no_instrumentation]] (no instrumentation-only burns).
3. **bite C** — H1 fix per § 10.6 step 1 (PHY init, ~80 LOC). Stacks WITH bite B.
4. **bite D** — Iron Attempt 94 burn — validates B + C bundled. Expected outcome on H1 success: stamp 0x61 = 1 (link up); `r8169: link up` boot line; full DHCP cycle visible on FB; TCP_LISTEN_SMOKE 8080 reachable from LAN. Expected outcome on H1 failure: stamp 0x61 = 2 (autoneg timeout) + escalation to H7/H8 discriminator examination.
5. **bite E** — cycle-close sweep + Attempt 94 transcript per [[feedback_cycle_close_shape]].

**Pre-burn for Attempt 94**: bite A must close (this section's findings land). Bite B + C code must land + 4/4 test.sh + QEMU smoke green. Then iron burn with checklist similar to Attempt 93.

### §10.8 — Audit disposition for 1.32.1 cycle-open

**Bite A status**: ✅ landed (this § 10 extension). The cycle-open lean shape per [[feedback_changelog_captures_movement]] holds: no code touches, only the planning surface (audit + state + CHANGELOG).

**Bite B + C readiness**: blocked on bite A's audit landing (just happened) + per-edit user consent for the r8169.cyr modifications per [[feedback_per_action_consent]]. Estimated stacked LOC: ~80-140. No new audit doc needed for bite B + C themselves — they execute against this section's findings.

**Iron Attempt 94 readiness**: blocked on bite B + C landing + build green. Once landed: iron-burn checklist will mirror Attempt 93's, with one addition — user reads CMOS slots 0x60-0x66 via `scripts/read-boot-log.sh` post-burn for the discriminator data.

**Multi-source posture**: every hypothesis triage in §10.2-10.4 cited at least 3 of (Linux / FreeBSD / OpenBSD / NetBSD / Haiku / RTL811x datasheet) per [[feedback_redesign_dont_reinvent]]. Linux is one source of many — **not** the singular reference. The proposed PHY init in §10.2 is OpenBSD-converged shape (simplest cross-validated form) with cross-checks against FreeBSD / NetBSD / Haiku / RealTek datasheet §11/§13.

**Next document on PASS** (bite D Attempt 94 outcome: full DHCP cycle visible): cycle closes per § 10.7; agnos 1.32.1 CHANGELOG cycle-close summary mirrors 1.32.0's shape.

**Next document on Partial** (discriminator fires for H7 or H8 specifically): § 10.6 step 2 or 3 fix lands as bite F of 1.32.1 — no new audit doc, just an extension to this section with the discriminator readout + corrective patch shape.

**Next document on Falsified** (Attempt 94 boot doesn't reach shell, or storage regression): bisect via `KTEST` + `R8169_DISABLE` build flag to confirm causality, then write a new audit doc framed around the regression rather than the H1/H7/H8 surface.
