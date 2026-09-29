#!/usr/bin/env bash
# Stop the attack and restore honest ARP + IP-forward state.
set -euo pipefail
source "$(dirname "$0")/lab.env"

if [[ $EUID -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi

echo "[*] Killing ettercap, sslstrip, bettercap..."
pkill -f ettercap  2>/dev/null || true
pkill -f sslstrip  2>/dev/null || true
pkill -f bettercap 2>/dev/null || true

echo "[*] Flushing NAT rules..."
iptables -t nat -F || true

echo "[*] Sending corrective ARP replies so the victim's cache recovers..."
if command -v arping >/dev/null; then
  # tell the victim who really owns the gateway IP
  arping -c 3 -A -I "$IFACE" -s "$GATEWAY_IP" "$VICTIM_IP" >/dev/null 2>&1 || true
  # tell the gateway who really owns the victim IP
  arping -c 3 -A -I "$IFACE" -s "$VICTIM_IP" "$GATEWAY_IP" >/dev/null 2>&1 || true
else
  echo "[!] arping not installed; ARP caches will expire naturally in ~1-5 min."
fi

echo "[*] Disabling IPv4 forwarding..."
echo 0 > /proc/sys/net/ipv4/ip_forward

echo "[+] Cleanup complete. Verify on the victim: arp -a"
