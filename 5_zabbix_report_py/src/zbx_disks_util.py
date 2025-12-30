import csv
import time
import re
from datetime import datetime
from modules.api import *
from modules.utils import *

# ==========================
# ⚙️ Settings
# ==========================
OUT_FILE = f"reports/zbx_disks.csv"

# ==========================
# 🧭 Helper functions
# ==========================
def get_trend(headers, itemid, time_from, time_till):
    payload = {
        "jsonrpc": "2.0",
        "method": "trend.get",
        "params": {
            "itemids": [itemid],
            "time_from": time_from,
            "time_till": time_till,
            "output": ["value_avg"],
        },
        "id": 3,
    }
    return zbx_request(ZBX_URL, headers, payload)


def avg_trend_value(trend):
    if not trend:
        return None
    try:
        values = [float(v["value_avg"]) for v in trend if v.get("value_avg")]
        return round(sum(values) / len(values), 4) if values else None
    except Exception:
        return None


def detect_os(templates):
    """Simple check by template name"""
    text = ", ".join(t["name"] for t in templates)
    if any(x in text for x in ("Windows", "Win32")):
        return "Windows"
    if any(x in text for x in ("Linux", "Unix", "Ubuntu", "Debian", "CentOS")):
        return "Linux"
    return None


# ==========================
# 🚀 Main logic
# ==========================
def main():
    start = time.time()
    token = get_token()
    headers = make_headers(token)

    time_till = int(time.time())
    time_from = time_till - PERIOD_DAYS * 24 * 3600

    print(f"🕒 Period: {datetime.fromtimestamp(time_from)} → {datetime.fromtimestamp(time_till)}")
    print("\n📡 Fetching active hosts...")

    hosts = get_hosts(headers)
    if not hosts:
        print("❌ No hosts found.")
        return

    print(f"✅ Found {len(hosts)} hosts.\n")
    results = []

    # --- Main loop ---
    for i, h in enumerate(hosts, start=1):
        host_name = h.get("host") 
        host_id = h.get("hostid")
        visible_name = h.get("name") or ""


        templates = h.get("parentTemplates", []) or []
        template_names = [t.get("name", "") for t in templates if t.get("name")]
        templates_str = ", ".join(template_names)


        ip_list = [i["ip"] for i in h.get("interfaces", []) if i.get("ip")]
        ip = ",".join(ip_list) if ip_list else ""

        os_type = detect_os(templates)
        prefix = f"[{i:>2}/{len(hosts)}]"
        print(f"{prefix} 🖥️  {host_name}")

        if not os_type:
            print("   ⚠️  Unknown OS type, skipping.")
            continue

        # --- Determine search key ---
        search_key = "vfs.dev.util" if os_type == "Linux" else "perf_counter_en"

        items_payload = {
            "jsonrpc": "2.0",
            "method": "item.get",
            "params": {
                "hostids": host_id,
                "output": ["itemid", "key_"],
                "search": {"key_": search_key},
                "filter": {"status": 0},
            },
            "id": 2,
        }

        items = zbx_request(ZBX_URL, headers, items_payload)
        if not items:
            print("   ⚠️  No matching items found.")
            continue

        templates_str = ", ".join(t["name"] for t in templates)

        # --- Iterate over metrics ---
        for item in items:
            key = item.get("key_") or ""
            itemid = item.get("itemid")
            disk_name = None

            if os_type == "Linux":
                m = re.search(r"vfs\.dev\.util\[(.+?)\]", key)
                if m:
                    disk_name = m.group(1)
            else:
                m = re.search(r'PhysicalDisk\(([\d\sA-Z:]+)\).*Idle Time', key)
                if m:
                    disk_name = m.group(1)

            if not disk_name:
                continue

            trend = get_trend(headers, itemid, time_from, time_till)
            avg = avg_trend_value(trend)

            if avg is not None:

                # Format the value with a dot
                value_with_dot = f"{avg:.4f}"
                # 💡 Replace dot with comma for CSV export
                value_with_comma = value_with_dot.replace(".", ",")

                results.append({
                    "HostID": host_id,
                    "Host": host_name,
                    "VisibleName": visible_name,
                    "IP": ip,
                    "Templates": templates_str,
                    "Trend": PERIOD_DAYS,
                    "Disk": disk_name,
                    "Metric": f"Avg Utilization {PERIOD_DAYS}d (%)",
                    "Value": value_with_comma,
                    "ItemKey": key
                })
                print(f"   💽 {disk_name:<10} → {avg:.2f}%")
            else:
                print(f"   ⚠️  No trend data for {disk_name}")

    # --- Export ---
    print("\n📤 Exporting results...")
    if results:
        with open(OUT_FILE, "w", newline="", encoding="utf-8-sig") as f:
            writer = csv.DictWriter(f, fieldnames=results[0].keys(), delimiter=";")
            writer.writeheader()
            writer.writerows(sorted(results, key=lambda x: (x["Host"], x["Disk"])))
        print(f"✅ Report saved: {OUT_FILE}")
    else:
        print("❌ No metrics found.")

    print(f"⏱️  Done in {time.time() - start:.1f}s.")


# ==========================
# ▶️ Entry point
# ==========================
if __name__ == "__main__":
    main()
