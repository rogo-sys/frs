# Script 1 pulls items for each host (no filter by enabled/disabled).
# Many API calls — item.get per host. On large installations this may be slow and can stress the API.
# Fetches current lastvalue (plus units) for items.
# Output: CSV snapshot of 'current' values for all items.
#
import os
import json
import requests
from getpass import getpass


# ============================
# ⚙️ Settings
# ============================
ZBX_URL = "https://zabbix.forus.ee/api_jsonrpc.php"

# ============================
# 🔐 Get token
# ============================
def get_token():
    token = os.environ.get("ZABBIX_TOKEN")
    if not token:
        token = getpass("Enter Zabbix API Token: ")
        os.environ["ZABBIX_TOKEN"] = token
    return token

API_TOKEN = get_token()

headers = {
    "Content-Type": "application/json-rpc",
    "Authorization": f"Bearer {API_TOKEN}"
}

# ============================
# 🧩 API call
# ============================
def zbx(method, params):
    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": 1,
    }
    r = requests.post(ZBX_URL, headers=headers, data=json.dumps(payload))

    if r.status_code != 200:
        raise Exception(f"HTTP Error {r.status_code}: {r.text}")

    data = r.json()
    if "error" in data:
        raise Exception(f"Zabbix error: {data['error']}")
    return data["result"]

# ============================
# 📡 Fetch all hosts
# ============================
print("📡 Fetching hosts...")
hosts = zbx("host.get", {
    "output": ["hostid", "host", "name"]
})
print(f"✔ Found {len(hosts)} hosts")

# ============================
# 🧮 Fetch all items for all hosts
# ============================
all_items = []

print("📈 Fetching items with lastvalue...")

for h in hosts:
    hostid = h["hostid"]
    host_name = h["name"]

    items = zbx("item.get", {
        "hostids": hostid,
        "output": ["itemid", "name", "key_", "lastvalue", "units", "value_type"],
        "sortfield": "name"
    })

    for it in items:
        all_items.append({
            "hostid": hostid,
            "host": host_name,
            "itemid": it["itemid"],
            "name": it["name"],
            "key": it["key_"],
            "lastvalue": it.get("lastvalue", ""),
            "units": it.get("units", "")
        })

    print(f"[{host_name}] {len(items)} items")

print()
print(f"🎉 Total loaded items: {len(all_items)}")

# ============================
# 💾 Save to CSV
# ============================
import csv

outfile = "zbx_all_lastvalues.csv"
with open(outfile, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f, delimiter=";")
    writer.writerow(["hostid", "host", "itemid", "name", "key", "lastvalue", "units"])
    for row in all_items:
        writer.writerow(row.values())

print(f"💾 Saved to {outfile}")
