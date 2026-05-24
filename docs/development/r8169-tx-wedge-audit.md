# r8169 TX-Wedge Multi-Source Audit — post-Iron-Attempt-101

> **Symptom** (Iron Attempt 101, 2026-05-23 ~22:27 PDT): static-IP path installed `192.168.1.222 / 192.168.1.1 / /24`, `arp_request(net_gateway)` fired, 5 s reply window elapsed with no ARP reply, FB printed `net: L1/L2/L3 FAILED — bug is BELOW DHCP (NIC/eth/IP/UDP)`. Bug is strictly in the r8169 driver TX or RX path (or both); not DHCP, not `udp_recv_from`, not the matcher.
>
> **Constraint**: archaemenid is a single-machine dev setup — Linux is NOT available during AGNOS burns. No concurrent host-side capture is possible. Diagnostics must come from AGNOS-side hardware-register reads. See [[project-single-machine-dev-setup]].
>
> **Multi-source convergence** per [[feedback_redesign_dont_reinvent]]:
>
> - **FreeBSD** `sys/dev/re/if_re.c` (HEAD) + `sys/dev/rl/if_rlreg.h`
> - **OpenBSD** `sys/dev/ic/re.c` + `sys/dev/ic/rtl81x9reg.h` + `sys/dev/ic/rtl8169.c`
> - **Linux v7.0** `drivers/net/ethernet/realtek/r8169_main.c`
> - **iPXE** `src/drivers/net/realtek.c` (PXE/UNDI pure-polling reference — closest behavioral analog to AGNOS)
> - **RTL8111B/8168B datasheet** §2.3/§2.7/§2.9/§4.6/§6.7

---

## §1 — Candidate ladder (eleven failure modes, convergent-evaluated)

| # | Candidate | Verdict | AGNOS site |
|---|-----------|---------|------------|
| A | CR.TE/RE latched after TCR write — wrong order on this stepping | **FALSIFIED** — FreeBSD 8168G+ branch + iPXE match AGNOS's TCR-then-CR.TE order; datasheet §2.7 "TCR only after CR.TE" is contradicted by every working driver | `r8169.cyr:665` → `:686` |
| B | TxConfig literal write clobbers chip-rev hint bits 31:24 | **SUSPECT** — Linux's `rtl_set_tx_config_registers` RMWs preserving chip-encoded mac_version; AGNOS literal-writes `0x03000700` zeroing them; chip silicon may rely on these post-init | `r8169.cyr:665` |
| C | MTPS (0xEC) value wrong for mac_version 46 | **FALSIFIED** — Linux skips MTPS for VER_46 (chip default holds); ARP at 42 B is far below any conceivable threshold | `r8169.cyr:654` |
| D | TPPoll NPQ kick silently no-ops if CR.TE didn't actually latch | **SUSPECT** — chip may eat NPQ writes if CR is in a wedge state; AGNOS never reads CR back to confirm TE\|RE actually set | `r8169.cyr:721` (kick site); `:686` (CR write site) |
| E | Descriptor format chip-rev quirk on G+ silicon | **FALSIFIED** — Linux + FreeBSD + iPXE all use the same 16-byte `opts1/opts2/addr_lo/addr_hi` C+ layout for all 8168 variants; AGNOS's layout at `:59-62` matches | n/a |
| F | **CPlusCmd missing TXENB \| RXENB bits** | **LOAD-BEARING SUSPECT** | `r8169.cyr:408-409` |
| G | GMII speed/duplex not latched after autoneg complete | **SUSPECT** — Linux per-mac_version `rtl_hw_start_8168h_1` writes MAC-OCP 0xd412 SAW-counter sync; AGNOS deleted MAC-OCP entirely; readback of PHYStatus (0x6C) would tell | `r8169.cyr:440-448` (post-`r8169_phy_init` site) |
| H | Cfg9346 unlock required around TxConfig writes | **FALSIFIED** — datasheet §2.9 explicit (Cfg9346 EEM=11 gates CONFIG0-5 only); zero drivers wrap TCR writes | n/a |
| I | MSI/MSI-X required for TX completion | **FALSIFIED** — iPXE proves pure-poll works on this chip family | n/a |
| J | ASPM L1 freezing chip between NPQ kick and DMA fetch | **SUSPECT** — Linux explicitly disables for VER_46 via Config5 + MAC-OCP 0xe092/0xe094; AGNOS deleted the helpers; archaemenid BIOS leaves ASPM=Auto | `r8169.cyr:385-423` (post-reset init site needs ASPM-disable insertion) |
| K | PCI Bus-Master bit not set | **FALSIFIED** — `r8169.cyr:345` calls `pci_enable_bus_master_idx`; same path NVMe/AHCI use | n/a |

Verdict scoring: **FALSIFIED** = prior art contradicts the candidate; **SUSPECT** = code diverges from convergent shape without clear justification; **LOAD-BEARING SUSPECT** = highest-ranked candidate where the AGNOS code is uniquely wrong vs all four reference drivers.

---

## §2 — Top 3 ranked candidates (with fix sites)

### #1 — (F) CPlusCmd missing TXENB | RXENB bits

**Current AGNOS code** (`agnos/kernel/core/r8169.cyr:404-409`):

```cyrius
# 1. CPlusCmd |= PCIMulRW — iPXE realtek.c:1420-1424 writes
#    MULRW|CPRX|CPTX. PCIMulRW is the only bit needed for RX to
#    function on G/H+ silicon (CPRX|CPTX are the C+ mode bits, which
#    we don't use; AGNOS uses the classic descriptor ring).
var cpc = load16(r8169_mmio_base + R8169_REG_CPLUSCMD);
store16(r8169_mmio_base + R8169_REG_CPLUSCMD, cpc | R8169_CPLUSCMD_PCIMULRW);
```

**Bug**: the comment is **factually wrong**. The 16-byte descriptor layout AGNOS uses (`r8169.cyr:59-62`):

```
offset 0:  status (u32) — OWN[31] | EOR[30] | FS[29] | LS[28] | length[13:0]
offset 4:  vlan (u32)
offset 8:  buf_addr_lo (u32)
offset 12: buf_addr_hi (u32)
```

**IS the C+ mode descriptor ring layout.** The classic (non-C+) RTL8169 used a totally different 4 × u32 layout with separate per-buf TX status registers. AGNOS picked the C+ ring (correctly — every modern driver does) but didn't tell the chip it's in C+ mode.

**Convergent prior art** (cite-confirmed by sub-agent research):

- iPXE `src/drivers/net/realtek.c:1336-1342` — writes `MULRW | CPRX | CPTX` = `0x08 | 0x01 | 0x02 = 0x0B`
- FreeBSD `if_re.c` ~lines 4022-4033 — writes `cfg = RL_CPLUSCMD_PCI_MRW` then conditionally ORs `RL_CPLUSCMD_RXENB | RL_CPLUSCMD_TXENB`, substituting `RL_CPLUSCMD_MACSTAT_DIS` for the `RL_FLAG_MACSTAT` chips (8168 G/H+ included)
- FreeBSD `if_rlreg.h:754-767` — `RL_CPLUSCMD_TXENB = 0x0001`, `RL_CPLUSCMD_RXENB = 0x0002`, `RL_CPLUSCMD_PCI_MRW = 0x0008`

**Fix shape** (audit only — not a patch yet):

```cyrius
# CPlusCmd: MULRW | CPRX | CPTX — C+ ring layout demands C+ mode bits.
# iPXE realtek.c:1336-1342 (MULRW|CPRX|CPTX); FreeBSD if_re.c:4022-4033
# (PCI_MRW|RXENB|TXENB); FreeBSD if_rlreg.h:754-767 (constants).
var cpc = load16(r8169_mmio_base + R8169_REG_CPLUSCMD);
store16(r8169_mmio_base + R8169_REG_CPLUSCMD,
        cpc | R8169_CPLUSCMD_PCIMULRW | R8169_CPLUSCMD_CPRX | R8169_CPLUSCMD_CPTX);
```

Need to add constants at `r8169.cyr:97-99`:

```cyrius
var R8169_CPLUSCMD_PCIMULRW = 0x08;  # bit 3 — PCI multiple read/write enable
var R8169_CPLUSCMD_CPRX     = 0x01;  # bit 0 — C+ RX mode (descriptor-ring fetch)
var R8169_CPLUSCMD_CPTX     = 0x02;  # bit 1 — C+ TX mode (descriptor-ring fetch)
```

**Why this is rank #1**: This is the ONE candidate where AGNOS is uniquely wrong vs all four reference drivers, AND the broken behavior matches the Attempt 101 symptom exactly. In legacy non-C+ mode, the chip ignores the C+ descriptor ring entirely → no TX descriptors fetched → no bytes emitted → OWN bit MAY clear via a stale-write retry path (datasheet ambiguous), but no actual frame goes out. Symmetrically: in non-C+ mode, the C+ RX ring isn't fetched → inbound frames go to a different (unallocated) buffer or are dropped → 100% RX silence. This single bug could explain BOTH the TX-not-on-wire AND the RX-unicast-silent symptoms.

### #2 — (J) ASPM L1 parking the chip mid-TX

**Current AGNOS code**: nothing — the ASPM-disable helpers were deleted post-Attempt-99 (see comment at `r8169.cyr:91-94`).

**Bug**: archaemenid BIOS leaves ASPM=Auto (typical Beelink firmware default). If the PCIe link enters L1 between AGNOS's NPQ-kick write and the chip's DMA-fetch of the TX descriptor, the chip parks; on wake, it may clear OWN without retrying the DMA, or stall indefinitely. Linux v7.0 `rtl_hw_aspm_clkreq_enable` (`r8169_main.c` ~lines 3970-4080) handles VER_46..VER_48 with `rtl_mod_config5(tp, 0, ASPM_en)` plus MAC-OCP modifications at 0xe092 / 0xe094.

**Confirmation step (read-only, no code change)**: read PCIe Capability Link Control register (PCI config space, capability offset + 0x10) bits [1:0] — if non-zero, BIOS has L0s/L1 enabled. Then read MAC Config5 (offset 0x56) bit 1 — if set, chip-side ASPM_en is on.

**Fix shape**: unlock Cfg9346 (write 0xC0 to 0x50), clear Config5 (offset 0x56) bit 1, lock Cfg9346 (write 0x00 to 0x50). Linux's mac_version-46 MAC-OCP writes at 0xe092/0xe094 are the chip-side ASPM gating — those may also be required (Linux does both; iPXE / BSDs rely on BIOS having ASPM off).

**Why this is rank #2**: SUSPECT but not LOAD-BEARING. iPXE works on consumer NICs in BIOS-PXE contexts where ASPM is often Auto, suggesting the chip can survive Auto-ASPM in some configs. But Linux's explicit-disable for VER_46 specifically indicates this stepping has known ASPM-related issues.

### #3 — (G) GMII speed/duplex not latched after autoneg

**Current AGNOS code** (`r8169.cyr:440-448`):

```cyrius
if (r8169_phy_init() != 0) {
    kprintln("r8169: link up", 14);
} else {
    kprintln("r8169: no link (autoneg timeout)", 32);
}
```

**Bug candidate**: `r8169_phy_init` reads BMSR (PHY register 0x01) bit 2 to determine link state. But BMSR.LinkStatus = 1 only means the PHY thinks the cable is up — it doesn't mean the chip's MAC-side GMII layer has latched the negotiated speed/duplex. Linux's per-mac_version `rtl_hw_start_8168h_1` writes MAC-OCP 0xd412 with the SAW-counter-derived 1ms tick, which IS the MAC-side clock-divider sync. Without that, the MAC may queue TX forever waiting for "link ready."

**Confirmation step (read-only, no code change)**: after `r8169_phy_init` returns success, read MAC register PHYStatus (MMIO offset 0x6C):

```
bits [3:2] = speed (00=10M, 01=100M, 10=1000M, 11=reserved)
bit [4]    = full-duplex
bit [1]    = LinkSts (separate from PHY BMSR.LinkStatus — this is the MAC's view)
```

If `BMSR.LinkStatus = 1` but `PHYStatus.LinkSts = 0` or `PHYStatus.speed = 0`, the GMII layer hasn't latched — TX won't transmit.

**Why this is rank #3**: SUSPECT but speculative. iPXE works on this chip family without MAC-OCP 0xd412 sync, so the GMII may auto-latch on most steppings; VER_46 may or may not need explicit sync.

---

## §3 — Recommended action ladder (audit-only — burns require explicit user authorization per [[feedback_iron_burns_block_other_work]] + [[feedback_per_action_consent]])

1. **Land #1 alone as a one-line change** — add two constants + change the OR in `store16(...CPLUSCMD)` at `r8169.cyr:408-409`. Smallest possible blast radius. If this is the bug, Attempt 102 produces ARP reply. If still wedged, the candidate is falsified by single-variable evidence.

2. **If #1 falsified**, layer #2 (ASPM-disable via Config5) and #3 (PHYStatus readback as a confirm-only print, no behavioral change). The Config5 unlock requires a Cfg9346 envelope around exactly the Config5 write; do not re-introduce the broader Cfg9346 wrapping that was deleted post-Attempt-99.

3. **Diagnostic backstop** — port the tally-counter dump per the sibling audit `r8169-tally-counter-audit.md` (next section). This is a read-only chip-statistics probe that disambiguates TX-wedge vs RX-filter on every burn going forward, single-machine compatible.

**Build budget**: #1 = +3 LOC (two constants + one OR). #2 = ~15 LOC (Config5 RMW with Cfg9346 envelope). #3 confirm-only = ~5 LOC (one `load32` + one print). Tally counter = ~80 LOC per sibling audit.

---

## §4 — Why this audit doesn't propose a burn

Per [[feedback_iron_burns_block_other_work]]: every diagnostic/instrumentation proposal comes with a written line-by-line audit BEFORE a burn is proposed. This document IS the audit. The fix shape for candidate #1 is a one-line code change (`store16(...CPLUSCMD, cpc | PCIMULRW | CPRX | CPTX)`); user authorizes when ready to write + burn.

Per [[feedback_per_action_consent]]: user just authorized "start the audit and review" — that's authorization for THIS document. Code changes + burns are separate authorizations.

---

## §5 — Cross-references

- Iron Attempt 101 entry: [`iron-nuc-zen-log.md § Attempt 101`](iron-nuc-zen-log.md)
- Attempt 101 catalog: [`iron-nuc-zen-photos/attempt-101-agnos-1.32.4-arp-timeout-bug-below-dhcp.jpg`](iron-nuc-zen-photos/attempt-101-agnos-1.32.4-arp-timeout-bug-below-dhcp.jpg)
- Sibling: [`r8169-tally-counter-audit.md`](r8169-tally-counter-audit.md) — read-only chip-statistics dump for ongoing TX/RX disambiguation
- Predecessor audit: [`r8169-chip-init-audit.md`](r8169-chip-init-audit.md) § "BSD + iPXE convergence" — the BSD/iPXE rewrite that landed at Attempt 100
- Predecessor diagnosis: [`r8169-rx-path-audit.md`](r8169-rx-path-audit.md) — pre-Attempt-97 RX-side multi-source
- Source files: `agnos/kernel/core/r8169.cyr` (788 LOC, post-Attempt-100 BSD/iPXE shape + Attempt-101 instrumentation removal)
