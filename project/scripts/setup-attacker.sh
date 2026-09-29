#!/usr/bin/env bash
# Install tools on a fresh Kali VM. Run once.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi

echo "[*] Updating apt index..."
apt-get update -y

echo "[*] Installing MITM lab tools..."
apt-get install -y \
  ettercap-graphical \
  ettercap-text-only \
  wireshark \
  tshark \
  dsniff \
  sslstrip \
  bettercap \
  net-tools \
  iproute2 \
  iptables \
  arp-scan \
  python3-scapy \
  python3-pip

echo "[*] Enabling IPv4 forwarding (runtime)..."
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo "[*] Making tshark usable without root..."
if command -v dpkg-reconfigure >/dev/null; then
  echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive wireshark-common || true
  usermod -aG wireshark "${SUDO_USER:-$USER}" || true
fi

echo "[+] Setup complete. Log out/in for the wireshark group to take effect."
