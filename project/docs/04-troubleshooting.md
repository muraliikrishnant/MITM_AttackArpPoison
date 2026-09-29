# 04 · Troubleshooting

Failure modes I hit while rebuilding this lab.

## Victim's internet dies as soon as poisoning starts

You forgot IP forwarding.

```bash
cat /proc/sys/net/ipv4/ip_forward   # should be 1
```

Enable it:

```bash
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```

`arp-poison.sh` sets this for you, but a reboot resets it. To make it
survive reboots on Kali:

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-mitm-lab.conf
sudo sysctl --system
```

## ARP cache on the victim doesn't change

- The two VMs are not on the same L2 segment. UTM's "Shared network" mode
  uses vmnet-shared, which isolates guests behind a NAT so ARP replies from
  Kali never reach Windows. Switch both VMs to **Bridged** or **Host-only**.
- `ettercap` is running but did not see the two targets. Add them
  explicitly: `-M arp:remote /VICTIM_IP// /GATEWAY_IP//` (the script does
  this).
- The switch or AP has Wireless Isolation Mode / Client Isolation enabled —
  common in corporate Wi-Fi. Use a lab AP or your own bridged VM network.

## Ettercap warns "Privileges dropped to EUID 65534"

You skipped `project/ettercap/etter.conf.patch`. Apply it or run ettercap
with `-p` (do not drop privileges) — but the patch is cleaner because it
also enables the `redir_command_on` iptables lines needed for SSLStrip.

## SSLStrip doesn't strip anything, even on http:// sites

- The victim already has an HSTS record for the site. Use a fresh private
  window.
- Modern browsers use HTTPS-Only Mode by default; disable it in the
  victim's browser settings for the test session.
- `iptables -t nat -L PREROUTING` should show the `REDIRECT 80 → 10000`
  rule. If not, re-run `sslstrip.sh` (its trap re-adds the rule).

## tshark has no permission to capture

```bash
sudo dpkg-reconfigure wireshark-common     # say Yes
sudo usermod -aG wireshark $USER
newgrp wireshark
```

Then re-run without `sudo`.

## Windows 11 blocks pings from Kali

The default Windows firewall drops ICMP echo on public networks. To allow
it just for the lab:

```powershell
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -Action Allow
```

Or set the lab network as "Private".

## Android emulator is on a different subnet

The default `AndroidWifi` NAT hides the emulator behind the host. Options:

1. Use the browser-proxy path (see `docs/01-lab-setup.md` Setup B step 4).
2. On Linux, launch with `emulator -avd Pixel_API_34 -net-tap` to expose it
   on the host bridge.

## After cleanup, victim still routes through the attacker

ARP caches take 1–5 minutes to expire naturally. Either wait, or run
`cleanup.sh` (which sends corrective `arping -A` replies), or on the victim:

```powershell
netsh interface ip delete arpcache
```

```bash
sudo ip -s -s neigh flush all
```
