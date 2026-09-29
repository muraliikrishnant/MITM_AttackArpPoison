# 01 · Lab setup

Recreates the paper's two environments on a single macOS / Linux host.

## Host prerequisites

- **UTM** (Apple silicon) or **VirtualBox / VMware** (x86 host).
- ~40 GB free disk, 8 GB free RAM (Kali + Windows can run side by side on 16 GB).
- **Android Studio** (Giraffe or newer) for the emulator setup.

## Setup A — Kali attacker + Windows 11 victim

1. **Kali VM**
   - Download the current Kali release for your architecture (`.utm` image on Apple silicon, `.iso` elsewhere).
   - Give it 4 GB RAM, 2 vCPU, 25 GB disk.
   - Network: **Bridged** to your host's Wi-Fi/Ethernet, or an isolated **Host-only** network shared with the Windows VM.
   - First boot: `sudo apt update && sudo apt full-upgrade -y`, then run
     `project/scripts/setup-attacker.sh`.

2. **Windows 11 VM**
   - Use a licensed Windows 11 evaluation ISO.
   - Same network mode as the Kali VM (both bridged, or both host-only).
   - Disable "Location-aware firewall on private networks" only if you need
     ICMP replies; leave the default otherwise.
   - Install a browser you're comfortable inspecting (Firefox is friendliest
     for HSTS overrides in a lab).

3. **Confirm same subnet**
   - Kali: `ip -4 addr` → note the address, e.g. `192.168.64.7/24`.
   - Windows: `ipconfig` → address should share the first three octets,
     e.g. `192.168.64.6`.
   - Both should ping the gateway (`192.168.64.1`).

## Setup B — Kali attacker + Android emulator victim

1. In Android Studio → **Device Manager**, create a **Pixel** virtual device
   with the default system image.
2. Launch it. The emulator uses the built-in `AndroidWifi` network with a NAT
   to the host, so its IP is on the emulator's own subnet, not your Kali
   subnet. Use `adb shell ip addr` to find it.
3. To bring the emulator onto the same subnet as Kali, either:
   - Run the emulator with `-net-tap` (Linux hosts), or
   - Point the Android browser at the Kali box directly and use HTTP proxy
     mode instead of ARP poisoning at the L2 layer.
4. For the paper's screenshots I used the browser-proxy path: set Wi-Fi →
   `AndroidWifi` → Modify → Advanced → Proxy = Manual, host = Kali IP,
   port = 8080, with Burp Suite listening on that port. That reproduces the
   "mobile MITM" case without needing Android to be on the same L2.

## Sanity check

On Kali:

```bash
source project/scripts/lab.env    # edit IPs first
project/scripts/baseline.sh
```

You should see the real MAC of the gateway and a `up` line for the victim.
Save the output — you'll diff against it later.
