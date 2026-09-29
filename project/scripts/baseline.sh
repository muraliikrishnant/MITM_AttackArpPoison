#!/usr/bin/env bash
# Snapshot the pre-attack network state.
set -euo pipefail
source "$(dirname "$0")/lab.env"

echo "=== Attacker interface ==="
ip -4 addr show "$IFACE" | awk '/inet /{print $2}'
ip link show "$IFACE" | awk '/link\/ether/{print "MAC:", $2}'

echo
echo "=== ARP cache (attacker's view) ==="
ip neigh show dev "$IFACE" || arp -a

echo
echo "=== Reachability ==="
ping -c 2 -W 2 "$GATEWAY_IP" >/dev/null && echo "gateway $GATEWAY_IP: up" || echo "gateway $GATEWAY_IP: DOWN"
ping -c 2 -W 2 "$VICTIM_IP"  >/dev/null && echo "victim  $VICTIM_IP:  up" || echo "victim  $VICTIM_IP:  DOWN"

echo
echo "=== IP forwarding ==="
cat /proc/sys/net/ipv4/ip_forward | awk '{print "ip_forward =", $1}'

echo
echo "[i] On the victim, run one of:"
echo "    Windows:  arp -a"
echo "    Linux:    ip neigh"
echo "    macOS:    arp -a"
echo "    Save that output as the pre-attack baseline."
