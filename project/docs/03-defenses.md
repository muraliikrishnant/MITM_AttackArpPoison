# 03 · Defenses

For each defense in Section VII of the paper, one command to try it in the
same lab. Every command is run on the **victim** unless noted.

## Static ARP entry

```powershell
# Windows (admin PowerShell). MAC must be the real gateway MAC from baseline.
netsh interface ipv4 set neighbors "Ethernet" "192.168.64.1" "82-a9-97-34-af-64"
```

```bash
# Linux
sudo ip neigh replace 192.168.64.1 lladdr 82:a9:97:34:af:64 dev eth0 nud permanent
```

Now start `arp-poison.sh` on the attacker. The victim's ARP entry is pinned,
so its packets keep going to the real gateway. Traffic from the gateway
back to the victim, however, still traverses the attacker unless the
gateway is also pinned — which is why static ARP only works when *both*
sides can be locked.

## HSTS preload

Firefox and Chrome both honor the [HSTS preload list](https://hstspreload.org/).
Nothing to configure — visit `https://github.com/` in a private window with
`sslstrip` active and observe that no downgrade happens.

To confirm a domain is preloaded, on the victim:

```
chrome://net-internals/#hsts
```

Query the domain; a "found dynamic_sts_domain" line means the browser will
refuse HTTP.

## VPN

Any WireGuard config works. Minimal one for testing:

```ini
# /etc/wireguard/wg0.conf
[Interface]
PrivateKey = <yours>
Address    = 10.66.66.2/32
DNS        = 1.1.1.1

[Peer]
PublicKey  = <server>
Endpoint   = <server-ip>:51820
AllowedIPs = 0.0.0.0/0
```

```bash
sudo wg-quick up wg0
```

Re-run the attacker's `capture-http.sh`; nothing HTTP appears. Only the
tunnel endpoint shows up.

## Dynamic ARP Inspection (DAI)

This is a switch-side control, so it doesn't apply to a home lab. Reference
config for Cisco IOS:

```
ip dhcp snooping
ip dhcp snooping vlan 10
ip arp inspection vlan 10
interface GigabitEthernet0/1
  ip dhcp snooping trust
  ip arp inspection trust
```

Every non-trust port then has ARP replies checked against the DHCP snooping
binding table. Forged replies from a client port are dropped.

## Intrusion detection (Suricata, on the attacker for lab)

```bash
sudo apt install -y suricata
sudo suricata -i eth0 -S /etc/suricata/rules/arp.rules
```

A minimal rule to alert on ARP reply floods:

```
alert arp any any -> any any (msg:"ARP reply flood"; \
  detection_filter: track by_src, count 20, seconds 5; sid:100001;)
```

Run `arp-poison.sh` — the alert fires in Suricata's `fast.log`.
