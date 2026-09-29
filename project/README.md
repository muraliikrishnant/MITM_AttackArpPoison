# MITM via ARP Spoofing — Lab

Reproducible lab that recreates the experiments in
[`../assets/MitM_Attack_Arp_Poisoning_FinalReport.pdf`](../assets/MitM_Attack_Arp_Poisoning_FinalReport.pdf).

> **Legal & ethical use only.** Run this only against machines you own or have
> written permission to test. Everything here assumes an isolated virtual lab
> — bridged VMs on your own host, or an Android emulator. Never run against
> real public Wi-Fi you don't operate, and never against traffic that isn't
> yours. The paper's experiments were done in a UTM sandbox on the author's
> laptop; recreate the same conditions.

---

## What this lab reproduces

1. **Baseline** — verify normal ARP resolution between victim and gateway.
2. **ARP poisoning** — attacker forges ARP replies so both endpoints route
   through the attacker.
3. **HTTP capture** — read plaintext credentials from an unencrypted login
   form (`testphp.vulnweb.com` is the reference).
4. **HTTPS + HSTS** — attempt SSLStrip, observe that HSTS-enforced sites
   don't downgrade.
5. **VPN** — turn a VPN on at the victim and observe that all payloads become
   opaque TLS/QUIC.
6. **Cleanup** — stop poisoning, restore ARP caches and IP-forward state.

---

## Topology

```
+---------------------+          +----------------------+
|  Victim  (Win 11    |          |  Attacker (Kali)     |
|  or Android emu)    |          |  ettercap, wireshark |
|  192.168.64.6       |          |  192.168.64.7        |
+----------+----------+          +----------+-----------+
           \                                /
            \                              /
             \        Bridged L2          /
              +--------+----+------------+
                       |    |
                    +--+----+--+
                    | Gateway  |
                    | .64.1    |
                    +----------+
```

Two setups, matching the paper:

| # | Attacker         | Victim                    | Notes                        |
|---|------------------|---------------------------|------------------------------|
| 1 | Kali (UTM VM)    | Windows 11 (UTM VM)       | Both bridged, same subnet    |
| 2 | Kali (UTM VM)    | Android Studio emulator   | Default `AndroidWifi` NIC    |

---

## Prerequisites

Host: macOS (Apple silicon works) or Linux with a hypervisor.
Attacker VM: **Kali Linux** (current rolling release).
Victim: **Windows 11** VM or the **Android Studio** emulator.

Install on the Kali VM:

```bash
project/scripts/setup-attacker.sh
```

This installs `ettercap-graphical`, `wireshark`, `dsniff`, `sslstrip`,
`bettercap`, `net-tools`, and enables IPv4 forwarding.

---

## Run the lab

Everything below runs on the **Kali attacker VM**. Set the two target IPs
first (edit `project/scripts/lab.env` or export inline):

```bash
export GATEWAY_IP=192.168.64.1
export VICTIM_IP=192.168.64.6
export IFACE=eth0
```

### 1. Baseline

```bash
project/scripts/baseline.sh
```
Prints the attacker's IP, the observed MAC for the gateway and victim, and
pings both. Save this output; the "after" ARP table should differ only in
that the gateway's MAC has become the attacker's.

### 2. Poison

```bash
sudo -E project/scripts/arp-poison.sh
```
Starts `ettercap` in text mode against the two targets and keeps replaying
ARP replies until you Ctrl-C. Leaves IP forwarding on so the victim keeps
working.

### 3. Capture HTTP

In another Kali shell:

```bash
sudo -E project/scripts/capture-http.sh
```
Runs `tshark` on the attacker interface with `http.request or http.response`,
writes a pcap to `project/captures/http-<timestamp>.pcap`, and tails
`POST` bodies to the terminal.

### 4. Try SSLStrip

```bash
sudo -E project/scripts/sslstrip.sh
```
Redirects HTTP traffic through `sslstrip` on port 10000 via an
`iptables PREROUTING` rule. On HSTS-enforced sites the browser will refuse
the downgrade — that's the point.

### 5. VPN check (from the victim)

Turn on a VPN client on the victim. On the attacker, re-run the capture:

```bash
sudo -E project/scripts/capture-vpn.sh
```
Filters for QUIC/TLS records to the VPN endpoint. Observe that payloads are
labeled `Protected Payload` and no HTTP layer appears.

### 6. Cleanup

```bash
sudo -E project/scripts/cleanup.sh
```
Kills ettercap and sslstrip, flushes the iptables redirect, disables
`ip_forward`, and sends corrective ARP replies so the victim's cache
converges back to the real gateway.

---

## Analysis helpers

- `project/analysis/parse-http-creds.py` — reads a pcap, prints
  `host / path / form-body` for every HTTP POST it finds.
- `project/analysis/arp-diff.sh` — snapshots the victim's ARP table over
  SSH and diffs against baseline (needs SSH on the victim, optional).

---

## Docs

- [`docs/01-lab-setup.md`](docs/01-lab-setup.md) — UTM + Kali + Windows 11 + Android emulator setup, step by step.
- [`docs/02-attack-walkthrough.md`](docs/02-attack-walkthrough.md) — the paper's Section IV/V, as commands.
- [`docs/03-defenses.md`](docs/03-defenses.md) — the mitigations from Section VII, with commands to try them.
- [`docs/04-troubleshooting.md`](docs/04-troubleshooting.md) — the failure modes I hit while rebuilding this.

---

## Layout

```
project/
├── README.md                    (this file)
├── scripts/
│   ├── lab.env                  environment variables (edit before running)
│   ├── setup-attacker.sh        install tools on Kali
│   ├── baseline.sh              snapshot pre-attack state
│   ├── arp-poison.sh            start ettercap ARP poisoning
│   ├── capture-http.sh          tshark HTTP capture on attacker
│   ├── capture-vpn.sh           tshark QUIC/TLS capture
│   ├── sslstrip.sh              SSLStrip pipeline
│   └── cleanup.sh               restore state
├── ettercap/
│   └── etter.conf.patch         changes to /etc/ettercap/etter.conf
├── analysis/
│   ├── parse-http-creds.py      pcap -> POST body extractor
│   └── arp-diff.sh              ARP table snapshot/diff
├── captures/                    pcaps land here (gitignored)
└── docs/
    ├── 01-lab-setup.md
    ├── 02-attack-walkthrough.md
    ├── 03-defenses.md
    └── 04-troubleshooting.md
```
