# 02 · Attack walkthrough

This is Section IV / V of the paper, as commands. Everything below runs on
the **Kali attacker**. Have a shell open on the **victim** for verification.

## 1. Load lab variables

```bash
cd MITM_AttackArpPoison
source project/scripts/lab.env
```

Edit the file first so `GATEWAY_IP`, `VICTIM_IP`, and `IFACE` match your VMs.

## 2. Baseline

```bash
project/scripts/baseline.sh
```

On the victim, in another shell, save the ARP table:

```powershell
# Windows
arp -a > baseline-arp.txt
```

```bash
# Linux / Android (via adb)
ip neigh > baseline-arp.txt
```

## 3. Poison

```bash
sudo -E project/scripts/arp-poison.sh
```

Leave this running. On the victim, re-check:

```powershell
arp -a
```

Both `192.168.64.1` (gateway) and `192.168.64.7` (attacker) should now
resolve to the same MAC — that is the attacker's NIC. Compare against
`baseline-arp.txt`; the diff is the attack.

## 4. Capture HTTP

In another Kali shell:

```bash
sudo -E project/scripts/capture-http.sh
```

On the victim, visit an HTTP-only test app:

- Login form: <http://testphp.vulnweb.com/login.php>
- Any username/password (`test` / `test` is the canonical pair).

The tshark window should print the `POST` line, `Host:`, and the form body
containing `uname=test&pass=test`. The full pcap goes to
`project/captures/http-<timestamp>.pcap`.

Offline reprocess:

```bash
python3 project/analysis/parse-http-creds.py project/captures/http-*.pcap
```

## 5. Try to strip HTTPS

Stop the HTTP capture (Ctrl-C), keep poisoning running, then:

```bash
sudo -E project/scripts/sslstrip.sh
```

On the victim:

- Open a browser private window (so no HSTS memory).
- Type `example.com` (no scheme). SSLStrip rewrites the redirect and you
  will stay on HTTP.
- Now try `github.com` or `google.com`. The browser refuses to downgrade —
  HSTS preload list — and the padlock stays intact.

## 6. Turn a VPN on at the victim

Any commercial VPN client is fine (WireGuard config, Mullvad, ProtonVPN,
Cloudflare WARP). With poisoning still active, on Kali:

```bash
sudo -E project/scripts/capture-vpn.sh
```

Browse anywhere on the victim. Every packet in the capture should be QUIC
or TLS to the VPN endpoint, with no HTTP layer visible.

## 7. Clean up

```bash
sudo -E project/scripts/cleanup.sh
```

Verify on the victim that `arp -a` shows the real gateway MAC again.
