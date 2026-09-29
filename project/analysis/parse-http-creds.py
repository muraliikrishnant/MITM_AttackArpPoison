#!/usr/bin/env python3
"""
Extract HTTP POST bodies (form credentials, cookies, auth headers) from a pcap.

Usage:
    python3 parse-http-creds.py <capture.pcap>

Requires: scapy  (pip install scapy)
"""
import re
import sys
from pathlib import Path

try:
    from scapy.all import rdpcap, Raw, TCP, IP
except ImportError:
    print("scapy not installed. Run: pip install scapy", file=sys.stderr)
    sys.exit(2)

INTERESTING_HEADERS = ("host", "cookie", "authorization", "user-agent", "referer")
BODY_HINTS = re.compile(r"(user(name)?|pass(word)?|email|login|token|sess(ion)?)", re.I)


def reassemble(pkts):
    streams = {}
    for p in pkts:
        if not (p.haslayer(TCP) and p.haslayer(Raw) and p.haslayer(IP)):
            continue
        key = (p[IP].src, p[TCP].sport, p[IP].dst, p[TCP].dport)
        streams.setdefault(key, bytearray()).extend(bytes(p[Raw].load))
    return streams


def parse_stream(data: bytes):
    text = data.decode("latin-1", errors="replace")
    for chunk in re.split(r"(?=^(?:GET|POST|PUT|PATCH|DELETE) )", text, flags=re.M):
        if not chunk.strip():
            continue
        head, _, body = chunk.partition("\r\n\r\n")
        first, *hdr_lines = head.split("\r\n")
        m = re.match(r"(GET|POST|PUT|PATCH|DELETE)\s+(\S+)\s+HTTP/", first)
        if not m:
            continue
        method, path = m.group(1), m.group(2)
        headers = {}
        for line in hdr_lines:
            if ":" in line:
                k, v = line.split(":", 1)
                headers[k.strip().lower()] = v.strip()
        host = headers.get("host", "?")
        body = body.strip()
        if method in ("POST", "PUT", "PATCH") or BODY_HINTS.search(path) or BODY_HINTS.search(body):
            yield method, host, path, headers, body


def main():
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(1)
    pcap = Path(sys.argv[1])
    if not pcap.exists():
        print(f"no such file: {pcap}", file=sys.stderr)
        sys.exit(1)

    print(f"[*] Reading {pcap} ...")
    pkts = rdpcap(str(pcap))
    streams = reassemble(pkts)
    print(f"[*] {len(streams)} TCP streams with payload.\n")

    hits = 0
    for stream in streams.values():
        for method, host, path, headers, body in parse_stream(bytes(stream)):
            hits += 1
            print("=" * 72)
            print(f"{method}  http://{host}{path}")
            for k in INTERESTING_HEADERS:
                if k in headers:
                    print(f"    {k}: {headers[k]}")
            if body:
                snippet = body[:400].replace("\n", " ")
                print(f"    body: {snippet}")
            print()
    print(f"[+] {hits} interesting request(s).")


if __name__ == "__main__":
    main()
