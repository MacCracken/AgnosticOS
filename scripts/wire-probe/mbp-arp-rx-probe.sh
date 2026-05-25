#!/usr/bin/env bash
#
# mbp-arp-rx-probe.sh — r8169 RX broadcast-delivery probe, run from a macOS MBP.
#
# WHY THIS EXISTS
#   AGNOS-on-archaemenid (r8169) TX is proven (1324/1325 pcaps show its broadcast
#   ARP egress byte-correct). The open question is RX: does the NIC deliver inbound
#   broadcast/unicast frames up to net_poll? A normal switched-port capture CANNOT
#   answer this — the gateway's unicast reply to AGNOS never floods to us.
#
#   But AGNOS's net.cyr has an ARP responder: net_handle_arp() replies to any ARP
#   request whose target IP == net_ip (192.168.1.222), with no L2-destination gate.
#   So if WE broadcast "who-has 192.168.1.222" and AGNOS's RX delivers that broadcast,
#   AGNOS replies "192.168.1.222 is-at b0:41:6f:0c:e4:25" UNICAST straight to this MBP —
#   which our own port sees. The MBP becomes both stimulus and observer; no SPAN/mirror
#   port required.
#
#   Expected result given the current bug (broadcast+unicast RX drop, multicast passes):
#     - We WILL see AGNOS's own boot ARP egress      -> TX confirmed (again).
#     - We will NOT see an AGNOS reply to our who-has -> broadcast RX drop CONFIRMED, controllably.
#   If we DO see a reply, that's big news: broadcast RX actually works -> the bug is
#   narrower than believed (re-scope to unicast-only / gateway-specific).
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
DURATION="${1:-120}"              # capture seconds

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

TS="$(date +%Y%m%d-%H%M%S)"
PCAP="agnos-rx-probe-${TS}.pcapng"
LIVELOG="agnos-rx-probe-${TS}.log"

echo "=============================================================="
echo " AGNOS r8169 RX broadcast-delivery probe (macOS)"
echo "   interface : $IFACE   (this MBP: ${MYIP:-unknown})"
echo "   target    : $AGNOS_IP @ $AGNOS_MAC"
echo "   capture   : $DURATION s  ->  $PCAP"
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
  # AGNOS just emitted its boot ARP -> its RX poll window is OPEN; hammer who-has now.
  if [[ "$line" == *"$AGNOS_MAC > ff:ff:ff:ff:ff:ff"* ]]; then
    echo "    [trigger] AGNOS boot ARP seen -> firing who-has $AGNOS_IP burst"
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      arp -d "$AGNOS_IP" >/dev/null 2>&1 || true
      ping -c 1 -t 1 "$AGNOS_IP" >/dev/null 2>&1 || true
    done
  fi
  # The smoking gun: AGNOS answered our who-has -> RX delivered a broadcast frame.
  if [[ "$line" == *"$AGNOS_MAC"* && "$line" == *"is-at $AGNOS_MAC"* ]]; then
    echo "    [!!] AGNOS REPLIED -> r8169 RX delivered a BROADCAST frame. RX (broadcast) WORKS."
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

echo "  AGNOS boot ARP egress (TX)        : $TX   $( ((TX>0)) && echo '-> TX confirmed' || echo '-> none seen (did AGNOS boot in-window?)')"
echo "  Our who-has $AGNOS_IP sent          : $MYREQ"
echo "  AGNOS ARP reply to us (RX gun)    : $RX"
echo "--------------------------------------------------------------"
if   ((RX>0)); then
  echo "  RESULT: r8169 RX DELIVERED a broadcast -> AGNOS replied. Broadcast RX WORKS."
  echo "          Re-scope the bug to unicast-only / gateway-specific."
elif ((TX>0 && MYREQ>0)); then
  echo "  RESULT: TX seen, our who-has went out, NO AGNOS reply."
  echo "          -> r8169 RX dropped the broadcast. Broadcast-RX-drop CONFIRMED (controllable)."
elif ((TX>0)); then
  echo "  RESULT: TX seen but our who-has did not leave this interface."
  echo "          Check IFACE=$IFACE is the Wi-Fi interface on the 192.168.1.0/24 net"
  echo "          (ifconfig $IFACE | grep 'inet '), then re-run."
else
  echo "  RESULT: inconclusive — no AGNOS traffic captured."
  echo "          AGNOS likely booted outside the capture window, or wrong interface."
  echo "          Re-run, and start capture BEFORE powering archaemenid."
fi
echo "=============================================================="
echo "Artifacts: $PCAP  (full frames),  $LIVELOG  (decoded stream)"
