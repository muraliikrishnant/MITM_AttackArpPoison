#!/usr/bin/env bash
# Snapshot the victim's ARP table over SSH and diff against baseline.
# Usage:
#   arp-diff.sh baseline    # save baseline snapshot
#   arp-diff.sh check       # diff current state against baseline
#
# Requires: SSH to the victim as $VICTIM_USER. Windows victims can use OpenSSH.
set -euo pipefail
source "$(dirname "$0")/../scripts/lab.env"

VICTIM_USER="${VICTIM_USER:-user}"
STATE_DIR="$(dirname "$0")/state"
mkdir -p "$STATE_DIR"
BASE="$STATE_DIR/arp-baseline.txt"

snapshot() {
  ssh "${VICTIM_USER}@${VICTIM_IP}" 'arp -a' | tr -d '\r' | sort
}

case "${1:-}" in
  baseline)
    snapshot > "$BASE"
    echo "[+] Baseline saved to $BASE"
    ;;
  check)
    if [[ ! -f "$BASE" ]]; then
      echo "[!] No baseline. Run: $0 baseline"; exit 1
    fi
    diff -u "$BASE" <(snapshot) || {
      echo
      echo "[!] ARP table has drifted from baseline (see diff above)."
      exit 3
    }
    echo "[+] No drift."
    ;;
  *)
    echo "usage: $0 {baseline|check}"; exit 2 ;;
esac
