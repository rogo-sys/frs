# This script fetches historical trend aggregates from Zabbix for all enabled items.
# It performs a single item.get to retrieve items (no host iteration), then loads trend data
# (avg/max per time) for the last 7 days in batches of 200 items to avoid huge single requests.
# Result: a CSV of trend aggregates with multiple rows per item (by time periods).
#
#
import os
import json
import time
import requests
from getpass import getpass

ZBX_URL = "https://zabbix.forus.ee/api_jsonrpc.php"

# ============================
# 🔐 Token
# ============================
def get_token():
    token = os.environ.get("ZABBIX_TOKEN")
    if not token:
        token = getpass("Enter Zabbix API Token: ").strip()
        os.environ["ZABBIX_TOKEN"] = token
    return token

API_TOKEN = get_token()

headers = {
    "Content-Type": "application/json-rpc",
    "Authorization": f"Bearer {API_TOKEN}"
}

def zbx(method, params):
    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": 1
    }
    r = requests.post(ZBX_URL, headers=headers, data=json.dumps(payload))

    if r.status_code != 200:
        raise Exception(f"HTTP {r.status_code}: {r.text}")

    data = r.json()
    if "error" in data:
        raise Exception(data["error"])
    return data["result"]

# ============================
# 📡 Step 1: get ALL items
# ============================
print("📡 Fetching all items...")

items = zbx("item.get", {
    "output": ["itemid", "hostid", "name", "key_"],
    "selectHosts": ["host"],
    "filter": {"status": 0},      # enabled items only
    "sortfield": "itemid"
})

print(f"✔ Found {len(items)} items")

# ============================
# ⏱ Step 2: time range
# ============================
DAYS = 7
time_till = int(time.time())
time_from = time_till - DAYS * 86400

# ============================
# 📈 Step 3: Load trends in batches
# ============================
BATCH = 200
all_trends = []

print("📈 Fetching trends...")

for i in range(0, len(items), BATCH):
    batch = items[i:i+BATCH]
    batch_ids = [it["itemid"] for it in batch]

    trends = zbx("trend.get", {
        "output": ["itemid", "value_avg", "value_max", "clock"],
        "itemids": batch_ids,
        "time_from": time_from,
        "time_till": time_till
    })

    for tr in trends:
        all_trends.append(tr)

    print(f"  → batch {i//BATCH+1}: {len(batch)} items, got {len(trends)} trend rows")

print()
print(f"🎉 TOTAL trend rows: {len(all_trends)}")

# ============================
# 💾 Save CSV
# ============================
import csv

outfile = "zbx_all_trends.csv"

with open(outfile, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f, delimiter=";")
    writer.writerow(["itemid", "clock", "value_avg", "value_max"])
    for tr in all_trends:
        writer.writerow([
            tr["itemid"],
            tr["clock"],
            tr["value_avg"],
            tr["value_max"]
        ])

print(f"💾 Saved to {outfile}")
