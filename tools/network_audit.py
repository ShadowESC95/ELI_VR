#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

RUNTIME_EXTS = {".gd", ".rs", ".json", ".tscn", ".gdshader"}
IGNORE_PARTS = {
    ".godot", "target", "build", "__pycache__"
}

remote_url = re.compile(r'\b(?:https?|wss?|ftp)://([^\s/"\'<>]+)', re.I)
network_tokens = re.compile(
    r'\b(?:HTTPClient|HTTPRequest|WebSocketPeer|TcpStream|TcpListener|UdpSocket|'
    r'StreamPeerTCP|PacketPeerUDP|socket\.|urllib|requests\.)\b'
)

loopback_host = re.compile(r"^(?:127\.0\.0\.1|localhost|\[::1\]|::1)(?::\d+)?$", re.I)
findings = []
remote_hosts = []

for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    if any(part in IGNORE_PARTS for part in path.parts):
        continue
    if path.suffix.lower() not in RUNTIME_EXTS:
        continue

    text = path.read_text(errors="ignore")
    rel = str(path.relative_to(ROOT))

    if network_tokens.search(text):
        findings.append({"file": rel, "kind": "network_primitive"})

    for m in remote_url.finditer(text):
        host = m.group(1).lower()
        if not loopback_host.match(host):
            remote_hosts.append({"file": rel, "host": host, "url": m.group(0)})

report = {
    "runtime_network_primitives": findings,
    "remote_runtime_urls": remote_hosts,
    "policy": {
        "runtime_remote_network_required": False,
        "sign_in_required": False,
        "telemetry": False,
        "analytics": False,
        "cloud_sync": False,
        "loopback_ipc": True,
    }
}

out = ROOT / "build" / "network-audit.json"
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(report, indent=2) + "\n")

print(json.dumps(report, indent=2))
print(f"\nReport: {out}")

if remote_hosts:
    print("\nFAILED: remote URL(s) present in runtime source.", file=sys.stderr)
    sys.exit(1)

print("\nPASS: no remote internet URL is present in runtime source.")
