#!/usr/bin/env bash
# read-boot-log-focused.sh — current-sweep view of the CMOS post-mortem.
#
# Strips the falsified-hypothesis chapters from read-boot-log.sh and
# prints only the slots relevant to the active sweep. Today's sweep
# (2026-05-18, Repair NN): events_seen=0 after Enable Slot doorbell.
#
# This is a SUPPLEMENT to read-boot-log.sh, not a replacement. The
# verbose version still exists with full interpretation chapters for
# when a slot's meaning is unclear or a falsified hypothesis needs to
# be re-evaluated. Run that one when you need the chapter; run this
# one to confirm "are we still chasing the same thing?".
#
# Usage: ./scripts/read-boot-log-focused.sh   (self-elevates via sudo)
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW=$("$SCRIPT_DIR/read-boot-log.sh" 2>&1 | grep -E '^CMOS\[0x[0-9A-Fa-f]+\]' || true)

slot() {
    # Extract hex value for the given CMOS address. Empty if not found.
    local addr="$1"
    echo "$RAW" | awk -v a="$addr" '
        $0 ~ "^CMOS\\["a"\\]" {
            for (i=1; i<=NF; i++) if ($i == "=") { print $(i+1); exit }
        }
    '
}

# Slot lookups (all hex, e.g. 0x15). Empty string if read-boot-log didn't print it.
kcp=$(slot 0x50)
kmagic=$(slot 0x51)
gcp=$(slot 0x52)
gmagic=$(slot 0x53)

hccp1=$(slot 0x6E)
hccp2=$(slot 0x6F)
maxsp=$(slot 0x80)
sp_byte2=$(slot 0x83)

usblegsup=$(slot 0x62)
ccs_bm=$(slot 0x63)
reset_bm=$(slot 0x64)
pp_bm=$(slot 0x6B)
psc_chg=$(slot 0x6C)
pls=$(slot 0x6D)

usbsts_b0=$(slot 0x77)
usbsts_b1=$(slot 0x78)
usbcmd_b0=$(slot 0x79)

aa_sentinel=$(slot 0x81)
bb_sentinel=$(slot 0x84)
cc_sentinel=$(slot 0x86)
dd_sentinel=$(slot 0x87)

# Helpers
ok_or_warn() {
    # echo "✓" if "$1" == "$2", "⚠ expected $2" otherwise.
    if [ "$1" = "$2" ]; then echo "✓"; else echo "⚠ expected $2 got $1"; fi
}

cat <<EOF

=== AGNOS xHCI current-sweep boot log ===
Repair (NN) — ERDP-before-ERSTBA + CRCR-after-IMOD
Reference: docs/development/xhci-prior-art-audit.md

Boot reached:
  kernel  checkpoint = $kcp     magic = $kmagic $(ok_or_warn "$kmagic" "0xab")
  gnoboot checkpoint = $gcp     magic = $gmagic $(ok_or_warn "$gmagic" "0xcd")

Controller capability:
  HCCPARAMS1 = $hccp1        HCCPARAMS2 = $hccp2
  MaxScratchpadBufs = $maxsp    sp_array phys byte 2 = $sp_byte2

Enumeration (Phase 3) — last completed port state:
  USBLEGSUP outcome      = $usblegsup        (0x01 = OS-owned)
  CCS bitmap             = $ccs_bm
  Reset OK bitmap        = $reset_bm
  PORTSC.PP bitmap       = $pp_bm
  PSC change byte (R4)   = $psc_chg
  PLS pre-PR     (R10)   = $pls         (0x07 = Polling)

Run-time @ silent-absorb fail:
  USBSTS byte 0 [0x77]   = $usbsts_b0   (HCH | HSE | EINT | PCD)
  USBSTS byte 1 [0x78]   = $usbsts_b1   (CNR | HCE | SRE)
  USBCMD byte 0 [0x79]   = $usbcmd_b0   (R/S | HCRST | INTE | HSEE)

Prior repairs — sentinels only (runlog; all falsified for events_seen=0):
  AA scratchpad install  [0x81]  = $aa_sentinel  $(ok_or_warn "$aa_sentinel" "0xaa")
  BB DNCTRL write        [0x84]  = $bb_sentinel  $(ok_or_warn "$bb_sentinel" "0xbb")
  CC extended-CMOS bank  [0x86]  = $cc_sentinel  $(ok_or_warn "$cc_sentinel" "0xcc")
  DD event-drain + PCD   [0x87]  = $dd_sentinel  $(ok_or_warn "$dd_sentinel" "0xdd")

Sweep symptom: events_seen=0 after Enable Slot doorbell.
Audit doc:     docs/development/xhci-prior-art-audit.md
Verbose log:   ./scripts/read-boot-log.sh    (full interpretation chapters)
EOF
