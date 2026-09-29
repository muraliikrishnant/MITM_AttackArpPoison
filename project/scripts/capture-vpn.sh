#!/usr/bin/env bash
# Capture QUIC/TLS payloads from the victim while a VPN is active.
set -euo pipefail
source "$(dirname "$0")/lab.env"
mkdir -p "$CAPTURE_DIR"
OUT="$CAPTURE_DIR/vpn-$(date +%Y%m%d-%H%M%S).pcap"

echo "[*] Writing pcap: $OUT"
echo "[*] Filter: host $VICTIM_IP"
echo "[*] You should see QUIC / TLSv1.3 records only, no HTTP layer."
echo

exec tshark -i "$IFACE" \
  -f "host $VICTIM_IP and (udp port 443 or tcp port 443)" \
  -w "$OUT" \
  -P -Y "quic or tls"
