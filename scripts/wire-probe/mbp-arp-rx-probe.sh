#!/usr/bin/env bash
#
# mbp-arp-rx-probe.sh — r8169 RX delivery probe (broadcast + unicast), run from a macOS MBP.
#
# WHY THIS EXISTS
#   AGNOS-on-archaemenid (r8169) TX is proven (1324/1325 pcaps show its broadcast
#   ARP egress byte-correct). The open question is RX: does the NIC deliver inbound
#   broadcast/unicast frames up to net_poll? A normal switched-port capture CANNOT
#   answer this — the gateway's unicast reply to AGNOS never floods to us.
#
#   This probe fires TWO independent RX-class tests in the same boot window:
#
#   (1) BROADCAST RX  — AGNOS's net.cyr has an ARP responder: net_handle_arp() replies
#       to any ARP request whose target IP == net_ip (192.168.1.222), with no
#       L2-destination gate. So if WE broadcast "who-has 192.168.1.222" and AGNOS's RX
#       delivers that broadcast, AGNOS replies "192.168.1.222 is-at b0:41:6f:0c:e4:25"
#       UNICAST straight to this MBP — which our own port sees. The reply ON THE WIRE
#       is the broadcast-RX proof. The MBP is both stimulus and observer; no SPAN port.
#
#   (2) UNICAST RX  — at boot AGNOS sends "who-has 192.168.1.1" (its gateway) and sets
#       arp_pending_ip=192.168.1.1, then polls ~5 s for a reply. net_handle_arp's reply
#       path (oper=2) accepts ANY reply whose sender_ip matches arp_pending_ip — no
#       L2/target gate (net.cyr:556-564). So we inject a UNICAST ARP reply addressed
#       only to AGNOS's MAC, claiming "192.168.1.1 is-at <this MBP>". If AGNOS's RX
#       delivers that unicast frame, net_handle_arp matches, caches our MAC as the
#       gateway, and the framebuffer prints  arp: REPLY gw_mac=<this-MBP-mac> / net: L2 OK.
#       That fb line (gw_mac == THIS MBP, not the real router) is the unicast-RX proof.
#       WIRE CORROBORATION: having cached us as "the gateway", AGNOS then routes its
#       boot TCP test (1.1.1.1:80) through our MAC — i.e. it sends a unicast frame
#       straight AT this MBP, which our tcpdump captures. So unicast RX has a fb signal
#       (primary) AND a wire signal (corroborating). The injected reply is switched
#       only to AGNOS's port and lives only in the boot window — it poisons no one else.
#
#   Expected result given the current bug (broadcast+unicast RX drop, multicast passes):
#     - We WILL see AGNOS's own boot ARP egress       -> TX confirmed (again).
#     - We will NOT see an AGNOS reply to our who-has  -> broadcast RX drop CONFIRMED.
#     - AGNOS will NOT print arp: REPLY gw_mac=<MBP>   -> unicast RX drop CONFIRMED,
#       and we will see NO AGNOS->MBP IP traffic on the wire.
#   If EITHER test fires, that's big news: that RX class actually works -> re-scope the
#   bug narrower (e.g. broadcast-only, or gateway/source-specific) than believed.
#
#   Channels per project rules: framebuffer boot log + this wire capture. No CMOS, no serial.
#
# TIMING
#   AGNOS only polls the NIC during its ~5 s boot ARP-wait window, then drops to a shell.
#   So the probe must land in that window. This script (a) blasts who-has continuously and
#   (b) fires an extra burst the instant it sees AGNOS's own boot ARP on the wire.
#
# USAGE
#   chmod +x mbp-arp-rx-probe.sh
#   sudo ./mbp-arp-rx-probe.sh                 # default 120 s capture
#   sudo ./mbp-arp-rx-probe.sh 180             # custom capture seconds
#   ...then power on / reboot archaemenid into AGNOS while it runs. Ctrl-C to stop early.
#
#   WI-FI IS FINE. The MBP is Wi-Fi-only and that's OK: this captures THIS interface's
#   own traffic (no monitor mode), and the 1325 capture already proved the MBP-on-Wi-Fi
#   (a) receives archaemenid's broadcasts and (b) has bidirectional unicast with it (SSH).
#   Those are exactly the two capabilities this probe needs. The probe makes the MBP the
#   ARP requester, so AGNOS's reply is addressed TO the MBP and comes straight back over
#   Wi-Fi. Same 192.168.1.0/24 broadcast domain; archaemenid is wired so any SSID
#   client-isolation (wireless<->wireless only) does not apply.

set -euo pipefail

# ---- target constants (from the burn under test) ---------------------------
AGNOS_MAC="b0:41:6f:0c:e4:25"     # archaemenid r8169 EEPROM MAC
AGNOS_IP="192.168.1.222"          # AGNOS static IP (net.cyr net_ip)
GW_IP="192.168.1.1"               # gateway AGNOS ARP-probes at boot (arp_pending_ip)
DURATION="${1:-120}"              # capture seconds

# dotted-quad -> 8 hex chars (e.g. 192.168.1.1 -> c0a80101). IFS-split on dots.
ip_to_hex() { printf '%02x%02x%02x%02x' ${1//./ }; }

# ---- must be root (tcpdump needs it; arp -d / low-interval ping too) -------
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-run with sudo:  sudo $0 ${1:-}" >&2
  exit 1
fi

# ---- pick the interface that routes to AGNOS's subnet ----------------------
IFACE="$(route -n get "$AGNOS_IP" 2>/dev/null | awk '/interface:/{print $2}')"
if [[ -z "${IFACE:-}" ]]; then
  echo "Could not determine egress interface for $AGNOS_IP." >&2
  echo "List interfaces with:  ifconfig -a   then set IFACE manually." >&2
  exit 1
fi
MYIP="$(ipconfig getifaddr "$IFACE" 2>/dev/null || true)"
MYMAC="$(ifconfig "$IFACE" 2>/dev/null | awk '/^[[:space:]]*ether /{print $2; exit}')"

# ---- unicast-RX path capability check --------------------------------------
# macOS ships no raw-ARP injector (no arping/nping), so the spoofed unicast
# reply goes out via /dev/bpf from an embedded python3 helper. If either the
# MBP MAC or python3 is unavailable, the unicast test self-disables and the
# broadcast test still runs unchanged.
UNICAST_OK=1
if [[ -z "${MYMAC:-}" ]]; then
  echo "WARN: could not read this MBP's MAC for $IFACE — unicast RX test disabled." >&2
  UNICAST_OK=0
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "WARN: python3 not found — unicast RX test disabled (broadcast test still runs)." >&2
  echo "      (install Command Line Tools: xcode-select --install)" >&2
  UNICAST_OK=0
fi

# Inject a raw L2 frame (hex string) on $IFACE via a free /dev/bpf device.
# BIOCSHDRCMPLT=1 tells BPF we supply the complete link header (keep our src MAC).
inject_frame() {  # $1 = frame as hex (no separators)
  python3 - "$IFACE" "$1" <<'PY'
import sys, os, fcntl, struct
iface = sys.argv[1].encode()
frame = bytes.fromhex(sys.argv[2])
BIOCSETIF     = 0x8020426c   # _IOW('B',108,struct ifreq)  (ifreq = 32 bytes)
BIOCSHDRCMPLT = 0x80044275   # _IOW('B',117,u_int)
fd = -1
for i in range(256):
    try:
        fd = os.open(b"/dev/bpf%d" % i, os.O_RDWR); break
    except OSError:
        continue
if fd < 0:
    sys.exit("inject: no free /dev/bpf device")
fcntl.ioctl(fd, BIOCSETIF, struct.pack("16s16x", iface))
fcntl.ioctl(fd, BIOCSHDRCMPLT, struct.pack("I", 1))
os.write(fd, frame)
os.close(fd)
PY
}

# Spoofed unicast ARP reply: "GW_IP is-at MYMAC", addressed ONLY to AGNOS's MAC.
# eth[ dst=AGNOS src=MBP 0806 ] + arp[ htype=1 ptype=0800 hln=6 pln=4 op=2
#   sender_hw=MBP sender_ip=GW  target_hw=AGNOS target_ip=AGNOS ].
ARP_REPLY_HEX=""
if [[ "$UNICAST_OK" -eq 1 ]]; then
  _dst="${AGNOS_MAC//:/}"                          # eth dst / arp target HW = AGNOS
  _src="${MYMAC//:/}"                              # eth src / arp sender HW = this MBP
  ARP_REPLY_HEX="${_dst}${_src}0806"               # ethernet header (ethertype 0x0806)
  ARP_REPLY_HEX+="0001080006040002"                # htype=1 ptype=0x0800 hln=6 pln=4 oper=2(reply)
  ARP_REPLY_HEX+="${_src}$(ip_to_hex "$GW_IP")"    # sender HW = MBP, sender IP = gateway (spoof)
  ARP_REPLY_HEX+="${_dst}$(ip_to_hex "$AGNOS_IP")" # target HW = AGNOS, target IP = AGNOS
fi

TS="$(date +%Y%m%d-%H%M%S)"
PCAP="agnos-rx-probe-${TS}.pcapng"
LIVELOG="agnos-rx-probe-${TS}.log"

echo "=============================================================="
echo " AGNOS r8169 RX delivery probe — broadcast + unicast (macOS)"
echo "   interface : $IFACE   (this MBP: ${MYIP:-unknown} @ ${MYMAC:-unknown})"
echo "   target    : $AGNOS_IP @ $AGNOS_MAC"
echo "   capture   : $DURATION s  ->  $PCAP"
if [[ "$UNICAST_OK" -eq 1 ]]; then
  echo "   unicast   : ENABLED — will inject \"$GW_IP is-at $MYMAC\" -> $AGNOS_MAC"
  echo "               watch AGNOS's framebuffer for:  arp: REPLY gw_mac=$MYMAC"
else
  echo "   unicast   : DISABLED (broadcast test only — see WARN above)"
fi
echo "=============================================================="
echo
echo ">>> POWER ON / REBOOT archaemenid into AGNOS NOW. <<<"
echo "    (Ctrl-C to stop early; the pcap + verdict are still produced.)"
echo

# ---- background stimulus: keep broadcasting who-has 192.168.1.222 ----------
# arp -d before each ping forces a fresh broadcast (defeats macOS ARP throttle).
stimulus() {
  while :; do
    arp -d "$AGNOS_IP" >/dev/null 2>&1 || true
    ping -c 1 -t 1 "$AGNOS_IP" >/dev/null 2>&1 || true
    sleep 0.3
  done
}

# ---- capture + live trigger ------------------------------------------------
# Writes the full pcap (-w) AND a parallel text stream we watch live. When AGNOS's
# own boot ARP appears, fire an extra burst so the probe is guaranteed in-window.
cleanup() {
  [[ -n "${STIM_PID:-}" ]] && kill "$STIM_PID" 2>/dev/null || true
  [[ -n "${TCPD_PID:-}" ]] && kill "$TCPD_PID" 2>/dev/null || true
  [[ -n "${TCPDW_PID:-}" ]] && kill "$TCPDW_PID" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# raw pcap to disk (full frames) for the durable record / later audit
tcpdump -i "$IFACE" -w "$PCAP" -U "arp or ether host $AGNOS_MAC" >/dev/null 2>&1 &
TCPDW_PID=$!

# live decoded stream we both show and react to
stimulus & STIM_PID=$!
tcpdump -i "$IFACE" -nn -e -l "arp or ether host $AGNOS_MAC" 2>/dev/null | tee "$LIVELOG" | \
while IFS= read -r line; do
  echo "$line"
  # AGNOS just emitted its boot ARP -> its RX poll window is OPEN AND arp_pending_ip is
  # freshly set to the gateway. Fire BOTH RX-class tests now, broadcast first so AGNOS
  # can reply on the wire before our unicast reply clears its pending state and breaks
  # the wait loop.
  if [[ "$line" == *"$AGNOS_MAC > ff:ff:ff:ff:ff:ff"* ]]; then
    echo "    [trigger] AGNOS boot ARP seen -> firing broadcast who-has $AGNOS_IP burst"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      arp -d "$AGNOS_IP" >/dev/null 2>&1 || true
      ping -c 1 -t 1 "$AGNOS_IP" >/dev/null 2>&1 || true
    done
    if [[ "$UNICAST_OK" -eq 1 ]]; then
      echo "    [trigger] injecting unicast spoofed reply: $GW_IP is-at $MYMAC -> $AGNOS_MAC"
      for _ in 1 2 3 4 5; do
        inject_frame "$ARP_REPLY_HEX" 2>/dev/null || \
          echo "    [warn] unicast inject failed (bpf write) — fb/wire signal may be absent"
      done
    fi
  fi
  # Broadcast smoking gun: AGNOS answered our who-has -> RX delivered a BROADCAST frame.
  if [[ "$line" == *"$AGNOS_MAC"* && "$line" == *"is-at $AGNOS_MAC"* ]]; then
    echo "    [!!] AGNOS REPLIED -> r8169 RX delivered a BROADCAST frame. RX (broadcast) WORKS."
  fi
  # Unicast wire corroboration: AGNOS now thinks WE are the gateway, so any IP frame it
  # sends to us (its TCP test to 1.1.1.1, routed via our MAC) proves it took our unicast
  # reply -> unicast RX delivered. (Primary proof is still the framebuffer arp: REPLY line.)
  if [[ -n "${MYMAC:-}" && "$line" == *"$AGNOS_MAC > $MYMAC"* && "$line" != *"ARP"* ]]; then
    echo "    [!!] AGNOS sent an IP frame straight to this MBP -> it cached our spoofed"
    echo "         gateway. r8169 RX delivered a UNICAST frame. RX (unicast) WORKS."
  fi
done &
TCPD_PID=$!

# ---- run for the window ----------------------------------------------------
sleep "$DURATION" &
SLEEP_PID=$!
wait "$SLEEP_PID" 2>/dev/null || true   # interruptible by Ctrl-C (trap cleans up)

cleanup
trap - EXIT INT TERM
sleep 0.5   # let tcpdump flush the pcap

# ---- verdict from the pcap -------------------------------------------------
echo
echo "=============================================================="
echo " VERDICT  (pcap: $PCAP)"
echo "--------------------------------------------------------------"

TX=$(tcpdump -nn -e -r "$PCAP" "arp" 2>/dev/null \
      | grep -F "$AGNOS_MAC > ff:ff:ff:ff:ff:ff" | grep -c "tell $AGNOS_IP" || true)
RX=$(tcpdump -nn -e -r "$PCAP" "arp" 2>/dev/null \
      | grep -F "is-at $AGNOS_MAC" | grep -c . || true)
MYREQ=$(tcpdump -nn -e -r "$PCAP" "arp" 2>/dev/null \
      | grep -c "who-has $AGNOS_IP" || true)
# unicast-path counters (only meaningful when the unicast test ran)
UNI_SENT=0; UNI_RX_WIRE=0
if [[ "$UNICAST_OK" -eq 1 && -n "${MYMAC:-}" ]]; then
  UNI_SENT=$(tcpdump -nn -e -r "$PCAP" "arp" 2>/dev/null \
        | grep -F "is-at $MYMAC" | grep -c . || true)
  UNI_RX_WIRE=$(tcpdump -nn -e -r "$PCAP" "ip" 2>/dev/null \
        | grep -cF "$AGNOS_MAC > $MYMAC" || true)
fi

echo "  AGNOS boot ARP egress (TX)            : $TX   $( ((TX>0)) && echo '-> TX confirmed' || echo '-> none seen (did AGNOS boot in-window?)')"
echo "  [bcast] our who-has $AGNOS_IP sent      : $MYREQ"
echo "  [bcast] AGNOS ARP reply to us         : $RX"
echo "  [unicast] spoofed replies we injected : $UNI_SENT"
echo "  [unicast] AGNOS IP frames sent to us  : $UNI_RX_WIRE"
echo "--------------------------------------------------------------"
echo "  BROADCAST RX"
if   ((RX>0)); then
  echo "    -> r8169 RX DELIVERED a broadcast; AGNOS replied. Broadcast RX WORKS."
elif ((TX>0 && MYREQ>0)); then
  echo "    -> TX seen, our who-has went out, NO AGNOS reply."
  echo "       r8169 dropped the inbound broadcast. Broadcast-RX-drop CONFIRMED."
elif ((TX>0)); then
  echo "    -> TX seen but our who-has did not leave this interface."
  echo "       Check IFACE=$IFACE is on the 192.168.1.0/24 net, then re-run."
else
  echo "    -> inconclusive (no AGNOS traffic — see overall note below)."
fi
echo "--------------------------------------------------------------"
echo "  UNICAST RX   (primary proof is on AGNOS's FRAMEBUFFER, not the wire)"
if [[ "$UNICAST_OK" -ne 1 ]]; then
  echo "    -> test DISABLED this run (no MBP MAC or no python3). Broadcast result stands."
elif ((UNI_RX_WIRE>0)); then
  echo "    -> AGNOS sent IP traffic straight to this MBP after our spoofed reply."
  echo "       It cached us as the gateway -> r8169 RX DELIVERED a unicast frame."
  echo "       Unicast RX WORKS. (Confirm on screen: arp: REPLY gw_mac=$MYMAC / net: L2 OK.)"
elif ((UNI_SENT>0 && TX>0)); then
  echo "    -> our unicast reply left the wire ($UNI_SENT frames) but AGNOS sent us nothing back."
  echo "       CHECK THE FRAMEBUFFER:"
  echo "         * arp: REPLY gw_mac=$MYMAC  -> unicast RX WORKS (kernel took it; wire-quiet"
  echo "           just means the TCP test didn't egress). Re-scope the bug narrower."
  echo "         * NO such line / still 'arp: request' timing out -> unicast RX DROP CONFIRMED."
elif ((UNI_SENT==0)); then
  echo "    -> our unicast reply never hit the wire (inject didn't fire / AGNOS booted"
  echo "       outside the window). Re-run; start the capture BEFORE powering archaemenid."
else
  echo "    -> inconclusive — check the framebuffer for the arp: REPLY line."
fi
echo "--------------------------------------------------------------"
if ((TX==0)); then
  echo "  NOTE: no AGNOS traffic captured at all — it likely booted outside the capture"
  echo "        window, or this is the wrong interface. Re-run; start capture BEFORE boot."
fi
echo "=============================================================="
echo "Artifacts: $PCAP  (full frames),  $LIVELOG  (decoded stream)"
