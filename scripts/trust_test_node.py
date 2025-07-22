#!/usr/bin/env python3
"""
trust_test_node.py

Scans WiFi, scores trust per network, logs to threat_journal.yaml,
and replicates results.
"""

import time
import subprocess
import yaml
import hashlib
import json
from datetime import datetime
from pathlib import Path
from scapy.all import sniff, Dot11Beacon

# ─── Paths & Config ────────────────────────────────────────────────────────────
BASE_DIR = Path(__file__).parent
CONFIG   = BASE_DIR / "trust_config.yaml"
JOURNAL  = Path("/opt/co-cloud/threat_journal.yaml")
REPLICANTS = Path("/data/the_unknown/replicants")

# ─── Load Settings ─────────────────────────────────────────────────────────────
cfg = yaml.safe_load(CONFIG.read_text())
sig_cfg = cfg["malicious_signatures"]
SCAN_INTERVAL = cfg["scan_interval"]
ENDPOINTS = cfg["replicate_to"]

# ─── Helpers ──────────────────────────────────────────────────────────────────
def hash_net(bssid, ssid):
    raw = f"{bssid}|{ssid}".encode()
    return hashlib.sha256(raw).hexdigest()

def append_journal(entry):
    data = yaml.safe_load(JOURNAL.read_text()) or []
    if entry not in data:
        data.append(entry)
        JOURNAL.write_text(yaml.safe_dump(data, sort_keys=False))

def detect_captive(ssid):
    # simple HTTP probe to check for captive portal redirect
    import requests
    try:
        r = requests.get("http://captive.apple.com/hotspot-detect.html", timeout=3)
        return r.status_code != 200
    except:
        return False

# ─── Core Scanning Loop ────────────────────────────────────────────────────────
def scan_networks():
    """Use iwlist to list WiFi networks."""
    out = subprocess.check_output(["iwlist", "wlan0", "scan"], text=True)
    nets = []
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("Cell "):
            bssid = line.split()[4]
        elif "ESSID:" in line:
            ssid = line.split("ESSID:")[1].strip('"')
            nets.append((bssid, ssid))
    return nets

def score_and_report():
    nets = scan_networks()
    seen_ssids = {}
    for bssid, ssid in nets:
        trust = 100
        reasons = []

        # open vs encryption
        if "open_encryption" in sig_cfg and "Encryption key:off" in subprocess.getoutput(f"iwlist wlan0 scan | grep -A5 {bssid}"):
            trust -= 30; reasons.append("Open network")

        # captive portal
        if "captive_portal" in sig_cfg and detect_captive(ssid):
            trust -= 20; reasons.append("Captive portal")

        # duplicate SSID
        count = seen_ssids.get(ssid, 0) + 1
        seen_ssids[ssid] = count
        if "duplicate_ssid" in sig_cfg and count > 1:
            trust -= 25; reasons.append("Evil twin detected")

        # weak cipher (scapy beacon parse)
        # omitted for brevity…

        vector = {
            "threat_vector": {
                "label": "WiFi Trust Test",
                "repo": ssid,
                "bssid": bssid,
                "date_detected": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
                "description": f"Trust score {trust}",
                "violation": {
                    "type": "WiFi Network Risk",
                    "severity": "Auto" if trust < 70 else "Low"
                },
                "response": {
                    "status": "Logged",
                    "recommendation": "Avoid" if trust < 50 else "Monitor"
                }
            }
        }

        # append to journal & replicate
        append_journal(vector)
        payload = json.dumps(vector)
        for url in ENDPOINTS:
            try:
                subprocess.run(
                    ["curl", "-X","POST","-H","Content-Type:application/json","-d",payload,url],
                    check=True
                )
            except:
                pass

if __name__ == "__main__":
    REPLICANTS.mkdir(parents=True, exist_ok=True)
    while True:
        score_and_report()
        time.sleep(SCAN_INTERVAL)