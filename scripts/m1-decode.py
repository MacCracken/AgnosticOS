#!/usr/bin/env python3
"""M1·M2·M3 — decode + anchor-check the `/bin/modeset --dump` output from an iron boot.

The kernel dump prints `rd <off> <val>` (BASE_IDX 2) and `rd1 <off> <val>` (BASE_IDX 1), both DECIMAL, one
line per register. Decoding by eye is the exact trap that cost a burn (4294902881 misread as 0xFFFF0A61 when
it is 0xFFFF0461); this script maps each decimal offset to its NAME, prints the value in hex+decimal, and
checks the M1 anchors that must hold or the H7 transform is wrong and the ladder stops.

Usage:
    run /bin/klug > m1.txt           # on agnos, at the agnsh prompt
    # copy m1.txt out by mounting /dev/nvme0n1p2 ro from Linux, then:
    python3 scripts/m1-decode.py m1.txt

Exit 0 iff every anchor holds. The anchors (from gpu.md M1 card):
  H_TOTAL  0x1B2A = 2719   V_TOTAL 0x1B2F = 1480   V_TOTAL_MIN/_MAX 0x1B30/0x1B31 = 0 (GOP: DRR off)
  V_SYNC_A 0x1B37 = 0x00050000 (a 5-line pulse)    H_SYNC_A 0x1B2C = 0x00200000 (start 32)
  M3 scaler: SCL_MODE 0x0CEC != 6 (upscaling, not bypass) — SCL_MODE == 6 reopens P4's root cause.
  M2 phyid: needs the mdo_rd2a base-fix + re-burn (the 1.56.11 dump double-folded these); until then phyid=0
            rests on the VBIOS object-info derivation, not on M2.
"""
import re
import sys

# name table: (base, offset) -> name. base 2 = BASE_IDX 2 (rd), base 1 = BASE_IDX 1 (rd1).
NAMES = {
    (2, 0x1B2A): "OTG_H_TOTAL",           (2, 0x1B2B): "OTG_H_BLANK_START_END",
    (2, 0x1B2C): "OTG_H_SYNC_A",          (2, 0x1B2D): "OTG_H_SYNC_A_CNTL",
    (2, 0x1B2E): "OTG_H_TIMING_CNTL",     (2, 0x1B2F): "OTG_V_TOTAL",
    (2, 0x1B30): "OTG_V_TOTAL_MIN",       (2, 0x1B31): "OTG_V_TOTAL_MAX",
    (2, 0x1B33): "OTG_V_TOTAL_CONTROL",   (2, 0x1B36): "OTG_V_BLANK_START_END",
    (2, 0x1B37): "OTG_V_SYNC_A",          (2, 0x1B38): "OTG_V_SYNC_A_CNTL",
    (2, 0x1B39): "OTG_TRIGA_CNTL",        (2, 0x1B41): "OTG_CONTROL",
    (2, 0x1B44): "OTG_STATUS",            (2, 0x1B82): "OTG_STATIC_SCREEN_CONTROL",
    (2, 0x1B86): "OTG_CLOCK_CONTROL",     (2, 0x1B87): "OTG_VSTARTUP_PARAM",
    (2, 0x1B88): "OTG_VUPDATE_PARAM",     (2, 0x1B89): "OTG_VREADY_PARAM",
    (2, 0x1B8A): "OTG_MASTER_UPDATE_MODE",
    (2, 0x0528): "VTG0_CONTROL",
    (2, 0x1ACA): "OPTC_UNDERFLOW",        (2, 0x1ACB): "OPTC_DATA_SOURCE_SELECT",
    (2, 0x1ACC): "OPTC_DATA_FORMAT_CONTROL", (2, 0x1ACF): "OPTC_INPUT_CLOCK_CONTROL",
    (2, 0x1AD0): "OPTC_MEMORY_CONFIG",
    (2, 0x183F): "FMT_DYNAMIC_EXP_CNTL",  (2, 0x1840): "FMT_CONTROL",
    (2, 0x1841): "FMT_BIT_DEPTH_CONTROL", (2, 0x1845): "FMT_CLAMP_CNTL",
    (2, 0x1849): "FMT_422_CONTROL",       (2, 0x1854): "DPG_CONTROL",
    (2, 0x1884): "OPPBUF_CONTROL",        (2, 0x188C): "OPP_PIPE_CONTROL",
    (2, 0x1271): "MPCC0_TOP_SEL",         (2, 0x1272): "MPCC0_BOT_SEL",
    (2, 0x1273): "MPCC0_MPCC_CONTROL",    (2, 0x1274): "MPCC0_MPCC_STATUS",
    (2, 0x127F): "MPCC0_MPCC_MEM_PWR",    (2, 0x1385): "MPC_OUT0_MUX",
    (2, 0x05E5): "HUBP_SURFACE_PIXEL_FMT",(2, 0x05E7): "HUBP_SURFACE_CONFIG",
    (2, 0x05EA): "HUBP_VIEWPORT",         (2, 0x05F3): "DCHUBP_CNTL",
    (2, 0x05F4): "DCHUBP_CNTL2",          (2, 0x0607): "HUBP_SURFACE_PITCH",
    (2, 0x060A): "HUBP_SURF_ADDR",        (2, 0x060B): "HUBP_SURF_ADDR_HI",
    (2, 0x061A): "HUBP_DCSURF_FLIP_CTRL", (2, 0x066C): "HUBPRET0_CONTROL",
    (2, 0x0080): "DCPG_DOMAIN0_PG_CONFIG",(2, 0x0082): "DCPG_DOMAIN1_PG_CONFIG",
    (2, 0x00B2): "DC_IP_REQUEST_CNTL",
    (1, 0x40): "OTG_PIXEL_RATE_CNTL(b1)", (1, 0x41): "OTG_PIXEL_RATE_CNTL1(b1)",
    (1, 0x80): "DCCG_DEEP_COLOR_CNTL(b1)",(1, 0x81): "DCCG_DISP_CNTL(b1)",
    (1, 0x82): "DCCG_DISP_CNTL1(b1)",     (1, 0x99): "SYMCLK(b1)",
    (1, 0x9A): "SYMCLK1(b1)",             (1, 0x9B): "SYMCLK2(b1)",
    (1, 0x9C): "SYMCLK3(b1)",             (1, 0xB6): "DCCG_AUDIO_DTO(b1)",
    (1, 0xAB): "DCCG_AUDIO_DTO_SOURCE(b1)",(1, 0xAC): "DCCG_AUDIO_DTO0_PHASE(b1)",
    (1, 0xAD): "DCCG_AUDIO_DTO0_MODULE(b1)",
    # M2 PHY/RDPCS — ABSOLUTE dwords (the kernel reads them via mdo_rd2a, base subtracted). Names + expected
    # values from the 07-20 GOP-DVI capture (dcn-gop-dvi-readonly-0720.txt).
    (2, 0x5D2D): "UNIPHYA_LINK_CNTL",     (2, 0x5D2E): "UNIPHYA_CHANNEL_XBAR",
    (2, 0x5D2F): "UNIPHYB_LINK_CNTL",     (2, 0x5D30): "UNIPHYB_CHANNEL_XBAR",
    (2, 0x5DF0): "RDPCSTX0_RDPCSTX_CNTL", (2, 0x5E00): "RDPCSTX0_PHY_CNTL0",
    (2, 0x5E06): "RDPCSTX0_PHY_CNTL6",    (2, 0x5EC8): "RDPCSTX1_RDPCSTX_CNTL",
    (2, 0x5ED8): "RDPCSTX1_PHY_CNTL0",    (2, 0x5EDE): "RDPCSTX1_PHY_CNTL6",
    (2, 0x0CEC): "DSCL0_SCL_MODE",        (2, 0x0CF1): "SCL_HORZ_FILTER_SCALE_RATIO",
    (2, 0x0D03): "DSCL0_RECOUT_SIZE",     (2, 0x016B): "DPP_STRIDE",
    # M8b — the EXACT read-set ATOM #76 (DIG1TransmitterControl ENABLE) touches, from the
    # atom-interp.py oracle (21 reads / 17 writes / 5 delays over 16 distinct indices). These seed
    # the H5 snapshot-DRY so the interpreter takes the branches iron would take. ABSOLUTE dwords.
    (2, 0x5535): "UNIPHY_A_LINK?(76rd)",  (2, 0x556F): "UNIPHY_PHY_POWER(76rw)",
    (2, 0x5570): "UNIPHY_PHY_POWER1(76rw)", (2, 0x55A1): "UNIPHY_CTRL(76rw)",
    (2, 0x5DE9): "RDPCSTX0_?(76rw)",      (2, 0x5DF7): "RDPCSTX0_?(76rd)",
    (2, 0x5DFC): "RDPCSTX0_?(76rd)",      (2, 0x5E03): "RDPCSTX0_LANE_RESET(76rw)",
    (2, 0x5E0F): "RDPCSTX0_?(76rw)",      (2, 0x5E10): "RDPCSTX0_?(76rw)",
    (2, 0x5E11): "RDPCSTX0_?(76rw)",      (2, 0x5E12): "RDPCSTX0_?(76rw)",
    # The per-instance DIG BACK END — what ATOM's `phyid` indexes. DIG_BE_CNTL abs = 0x556F + N*0x100,
    # DIG_BE_EN_CNTL one dword higher. Instance 0 is in the 76readset group above.
    (2, 0x566F): "DIG_BE_CNTL[1]",        (2, 0x5670): "DIG_BE_EN_CNTL[1]",
    (2, 0x576F): "DIG_BE_CNTL[2]",        (2, 0x5770): "DIG_BE_EN_CNTL[2]",
    (2, 0x586F): "DIG_BE_CNTL[3]",        (2, 0x5870): "DIG_BE_EN_CNTL[3]",
    (2, 0x596F): "DIG_BE_CNTL[4]",        (2, 0x5970): "DIG_BE_EN_CNTL[4]",
}

# The 16 distinct indices ATOM #76 READS. A snapshot-seeded DRY (H5) is only meaningful once every one of
# these has a real captured value — with no seed they read 0 and the interpreter may branch differently
# than it will on iron. m1-decode reports coverage so the M8b gate is mechanical, not a judgement call.
#
# ⚠⚠ THE SEEDED DRY IS DIAGNOSTIC — AND ON 2026-07-24 IT OVERTURNED MD-2. Four runs of ATOM #76:
#     no seed,        phyid=0 -> reads=21      writes=17  delays=5
#     placeholders,   phyid=0 -> reads=87804   writes=20  delays=43895
#     REAL iron seed, phyid=0 -> reads=87292   writes=20  delays=43639   <- POLL STORM
#     REAL iron seed, phyid=1 -> reads=21      writes=17  delays=5       <- CLEAN
# The storm is NOT an artifact of static snapshots (that was the first, wrong reading — phyid=1 falsifies
# it: a frozen snapshot satisfies the polls perfectly well when the values are the LIVE ones). It is the
# signal that phyid=0 targets an INACTIVE PHY whose status bits never read ready. With real values the
# correct phyid completes and the wrong one hangs, which is exactly what makes this test worth running.
# So: read the WRITE LIST, and treat a storm as "wrong target", not "bad decoder".
# (agnos's own interpreter is bounded by a 1,000,000-step cap, so neither case can wedge the kernel.)
ATOM76_READS = [0x5535, 0x556F, 0x5570, 0x55A1, 0x5D2D, 0x5D2E, 0x5DE9, 0x5DF0,
                0x5DF7, 0x5DFC, 0x5E03, 0x5E06, 0x5E0F, 0x5E10, 0x5E11, 0x5E12]

LINE = re.compile(r"^\s*(rd1?)\s+(\d+)\s+(\d+)\s*$")


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: m1-decode.py <m1.txt>")
    vals = {}      # (base, off) -> value
    with open(sys.argv[1], errors="replace") as f:
        for ln in f:
            m = LINE.match(ln)
            if not m:
                continue
            base = 1 if m.group(1) == "rd1" else 2
            vals[(base, int(m.group(2)))] = int(m.group(3))

    print(f"parsed {len(vals)} register reads\n")
    print(f"{'reg':<32} {'off':>7}  {'hex':>10}  {'dec':>12}")
    for (base, off) in sorted(vals, key=lambda k: (k[0], k[1])):
        v = vals[(base, off)]
        nm = NAMES.get((base, off), f"?base{base}?")
        tag = f"0x{off:04X}" if base == 2 else f"b1:0x{off:02X}"
        print(f"{nm:<32} {tag:>7}  0x{v & 0xFFFFFFFF:08X}  {v:>12}")

    print("\n=== ANCHORS (M1 card — all must hold, or the H7 transform is wrong) ===")
    fails = 0

    def chk(cond, label, got):
        nonlocal fails
        if cond:
            print(f"  OK    {label}  (got {got})")
        else:
            print(f"  FAIL  {label}  (got {got})")
            fails += 1

    def g(base, off):
        return vals.get((base, off))

    chk(g(2, 0x1B2A) == 2719, "H_TOTAL 0x1B2A == 2719", g(2, 0x1B2A))
    chk(g(2, 0x1B2F) == 1480, "V_TOTAL 0x1B2F == 1480", g(2, 0x1B2F))
    chk(g(2, 0x1B37) == 0x00050000, "V_SYNC_A 0x1B37 == 0x00050000 (5-line pulse)", g(2, 0x1B37))
    chk(g(2, 0x1B2C) == 0x00200000, "H_SYNC_A 0x1B2C == 0x00200000 (start 32)", g(2, 0x1B2C))
    # DRR clamps: GOP does a fixed-mode set and leaves these 0 (amdgpu programs 1480). V_TOTAL_CONTROL=0
    # means the OTG ignores MIN/MAX and rasters off V_TOTAL. A GOP-vs-amdgpu delta, NOT a transform gate.
    chk(g(2, 0x1B30) == 0, "V_TOTAL_MIN 0x1B30 == 0 (GOP: DRR off)", g(2, 0x1B30))
    chk(g(2, 0x1B31) == 0, "V_TOTAL_MAX 0x1B31 == 0 (GOP: DRR off)", g(2, 0x1B31))
    scl = g(2, 0x0CEC)
    chk(scl is not None and (scl & 0x7) != 6, "M3 SCL_MODE[2:0] 0x0CEC != 6 (upscaling, not bypass)", scl)
    # ⚠ M2 phyid cross-check requires the mdo_rd2a base-fix (fixed 2026-07-24; the 1.56.11 dump double-folded
    # the M2 offsets and read garbage). On a re-burn, the check is: UNIPHYA_LINK_CNTL 0x5D2D reads the 07-20
    # value 0x01000100 (not 0/0xFFFFFFFF). Until re-burned, phyid=0 rests on the VBIOS object-info derivation.
    uni = g(2, 0x5D2D)
    if uni == 0x01000100:
        print(f"  OK    M2 UNIPHYA_LINK_CNTL 0x5D2D == 0x01000100 (base-fix landed, PHY read valid)  (got {uni})")
    else:
        print(f"  NOTE  M2 0x5D2D = {uni} (not the 07-20 0x01000100) — needs the mdo_rd2a base-fix + re-burn; not a gate")

    # === M8b: ATOM #76 read-set coverage + the H5 snapshot seed ===
    # The snapshot-seeded DRY is only meaningful when every index #76 reads has a REAL captured value.
    # Report coverage mechanically, and emit the seed file atom-interp.py --regsnapshot consumes.
    print("\n=== M8b: ATOM #76 read-set coverage (H5 snapshot seed) ===")
    have = [o for o in ATOM76_READS if (2, o) in vals]
    miss = [o for o in ATOM76_READS if (2, o) not in vals]
    print(f"  captured {len(have)}/{len(ATOM76_READS)} of the indices #76 reads")
    if miss:
        print("  MISSING: " + " ".join(f"0x{o:04X}" for o in miss))
        print("  => the H5 snapshot-DRY of #76 is NOT yet meaningful; those reads would return 0.")
    else:
        print("  => full coverage: the snapshot-DRY of #76 can take iron's branches.")

    # === MD-2: which link encoder does ATOM's `phyid` have to name? ===
    # Mirrors kernel gpu_phy_discover() and atom-interp.py's derive_phyid_from_snapshot(): the live
    # instance is ENABLED, has a front end routed, and carries a real signalling mode. Reported here so a
    # capture ANSWERS the question instead of leaving it to a VBIOS enum guess — the guess said 0, the
    # answer is 1, and #76 at 0 would have power-cycled a dead PHY.
    print("\n=== MD-2: phyid, derived from the live DIG back end ===")
    phy = None
    for i in range(5):
        be = vals.get((2, 0x556F + i * 0x100))
        en = vals.get((2, 0x5570 + i * 0x100))
        if be is None or en is None:
            print(f"  inst {i}: not captured")
            continue
        mode = (be >> 16) & 0x7
        fesel = (be >> 8) & 0xFF
        live = bool(en & 1) and fesel != 0 and mode in (2, 3)
        tag = "  <== LIVE" if live else ""
        print(f"  inst {i}: BE=0x{be:08X} mode={mode} FE_SOURCE=0x{fesel:02X} "
              f"EN=0x{en:08X} enable={en & 1}{tag}")
        if live and phy is None:
            phy = i
    if phy is None:
        print("  => phyid UNDETERMINED from this capture (missing DIG_BE regs, or nothing live).")
        print("     ⛔ Do NOT run ATOM #76 on a guess — it power-cycles whichever PHY it is told to.")
    else:
        print(f"  => phyid = {phy}")

    if len(sys.argv) > 2:
        seed_path = sys.argv[2]
        with open(seed_path, "w") as sf:
            sf.write("# H5 snapshot seed for atom-interp.py --regsnapshot\n")
            sf.write("# Captured from an agnos iron dump (`run /bin/modeset --dump`), decoded by m1-decode.py.\n")
            sf.write("# Format: IDX VALUE (both hex). IDX is the ABSOLUTE BASE_IDX-2 dword the ATOM tables use.\n")
            for (base, off) in sorted(vals, key=lambda k: (k[0], k[1])):
                if base == 2:
                    sf.write(f"0x{off:04X} 0x{vals[(base, off)] & 0xFFFFFFFF:08X}\n")
        print(f"  wrote snapshot seed -> {seed_path}")

    print()
    if fails == 0:
        print("=== M1 decode: ALL ANCHORS HOLD — the H7 transform is iron-attested (M2 phyid rides a re-burn) ===")
        return 0
    print(f"=== M1 decode: {fails} ANCHOR(S) FAILED — do not proceed to the write bites ===")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
