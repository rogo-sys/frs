import os
import csv
import time
from collections import defaultdict
from datetime import datetime

from modules.api import *
from modules.utils import *
from modules.metrics import METRIC_KEYS_MAP


# ==========================
# ⚙️ Parameters
# ==========================
OUT_FILE = f"reports/zbx_trends.csv"


FIELD_NAMES = [
    "HostID", "Host", "VisibleName", "IP", "Templates", "Trend",
    "CPU_Cores", "%_CPU_Util", "Processes",
    "RAM_Total_MB", "RAM_Used_MB", "RAM_Used_MB_MAX",
    "%_RAM_Util", "%_RAM_Util_MAX"
]


def main():
    start = time.time()

    # Check if output file is open in Excel
    os.makedirs("reports", exist_ok=True)
    if not check_output_file(OUT_FILE, retries=3):
        return

    # --- Token + headers ---
    token = get_token()
    headers = make_headers(token)

    time_till = int(time.time())
    time_from = time_till - PERIOD_DAYS * 24 * 3600

    print(f"🕒 Period: {datetime.fromtimestamp(time_from)} → {datetime.fromtimestamp(time_till)}")
    print("\n📡 Getting hosts...")

    hosts_raw = get_hosts(headers)
    if not hosts_raw:
        print("❌ No hosts found.")
        return

    print(f"✅ Found {len(hosts_raw)} hosts.\n")

    # ---------------------------------------------------------------
    # 1) Prepare host data structure
    # ---------------------------------------------------------------
    hosts_data = {}
    all_host_ids = []

    for h in hosts_raw:
        hid = h.get("hostid")
        host_name = h.get("host")
        visible_name = h.get("name") or ""
        if not hid or not host_name:
            continue

        all_host_ids.append(hid)

        # IP
        ip_list = [i.get("ip") for i in h.get("interfaces", []) if i.get("ip")]
        ip = ",".join(sorted(set(ip_list))) if ip_list else ""

        # Templates
        templates = h.get("parentTemplates", []) or []
        template_names = [t.get("name", "") for t in templates if t.get("name")]

        # Determine if host is Windows
        is_win = any("windows" in t.lower() for t in template_names)

        hosts_data[hid] = {
            "HostID": hid,
            "Host": host_name,
            "VisibleName": visible_name,
            "IP": ip,
            "Templates": sorted(template_names),
            "Is_Windows": is_win,
            "Metrics": {},  # itemid -> logical metric name from METRIC_KEYS_MAP
        }

    # ---------------------------------------------------------------
    # 2) Get itemid for all required keys
    # ---------------------------------------------------------------
    unique_keys = {key for keys in METRIC_KEYS_MAP.values() for key in keys}

    print("🔍 Getting item IDs for metrics...")
    items_by_host = get_itemids_for_keys(headers, all_host_ids, unique_keys)

    trend_ids = []

    for hostid, data in hosts_data.items():
        host_items = items_by_host.get(hostid, {})
        if not host_items:
            continue

        for csv_key, zbx_keys in METRIC_KEYS_MAP.items():
            for zkey in zbx_keys:
                itemid = host_items.get(zkey)
                if itemid:
                    # map itemid -> logical metric name
                    data["Metrics"][itemid] = csv_key
                    trend_ids.append(itemid)
                    break  # move to next csv_key

    print(f"📈 Getting trends for {len(trend_ids)} items...")

    if not trend_ids:
        print("❌ No items found for trends.")
        return

    # ---------------------------------------------------------------
    # 3) Get trends and aggregate AVG + MAX(value_max)
    # ---------------------------------------------------------------
    trends = get_trends_bulk(headers, trend_ids, time_from, time_till)

    sum_avg = defaultdict(float)
    count_avg = defaultdict(int)
    max_val = defaultdict(lambda: None)

    for t in trends:
        iid = t.get("itemid")
        if not iid:
            continue
        try:
            avg_v = float(t.get("value_avg", 0))
            max_v = float(t.get("value_max", 0))
        except (TypeError, ValueError):
            continue

        sum_avg[iid] += avg_v
        count_avg[iid] += 1

        if max_val[iid] is None or max_v > max_val[iid]:
            max_val[iid] = max_v

    final_avg = {
        iid: round(sum_avg[iid] / count_avg[iid], 2)
        for iid in count_avg if count_avg[iid] > 0
    }
    final_max = {iid: v for iid, v in max_val.items() if v is not None}

    # ---------------------------------------------------------------
    # 4) Build rows for CSV
    # ---------------------------------------------------------------
    rows = []

    for hid, data in hosts_data.items():
        row = {
            "HostID": data["HostID"],
            "Host": data["Host"],
            "VisibleName": data["VisibleName"],
            "IP": data["IP"],
            "Templates": ", ".join(data["Templates"]),
            "Trend": f"{PERIOD_DAYS}",
        }

        # tmp: logical metric name → avg + MAX
        tmp = {}
        for iid, csv_key in data["Metrics"].items():
            tmp[csv_key] = final_avg.get(iid)
            tmp[csv_key + "_MAX"] = final_max.get(iid)

        # --- RAM used AVG ---
        ram_total_b = tmp.get("RAM_Total_B")
        ram_avail_b = tmp.get("RAM_Avail_B")
        ram_used_direct_b = tmp.get("RAM_Used_Direct_B")

        if ram_used_direct_b is not None:
            ram_used_avg_b = ram_used_direct_b
        elif ram_total_b is not None and ram_avail_b is not None:
            ram_used_avg_b = ram_total_b - ram_avail_b
        else:
            ram_used_avg_b = None

        # --- RAM used MAX = (%_RAM_Util_MAX / 100) * RAM_Total_MB ---
        ram_total_mb = safe_mb(ram_total_b)
        ram_util_max = tmp.get("%_RAM_Util_MAX")

        if ram_total_mb is not None and ram_util_max is not None:
            ram_used_max_mb = round((ram_util_max / 100.0) * ram_total_mb, 2)
        else:
            ram_used_max_mb = None

        # CPU
        cpu_cores = tmp.get("CPU_Cores")
        row["CPU_Cores"] = int(cpu_cores) if cpu_cores is not None else None
        row["%_CPU_Util"] = tmp.get("%_CPU_Util")
        row["Processes"] = tmp.get("Processes")

        # RAM
        row["RAM_Total_MB"] = ram_total_mb
        row["RAM_Used_MB"] = safe_mb(ram_used_avg_b)
        row["RAM_Used_MB_MAX"] = ram_used_max_mb
        row["%_RAM_Util"] = tmp.get("%_RAM_Util")
        row["%_RAM_Util_MAX"] = ram_util_max

        # Round some fields to int before CSV
        for field in [
            "Processes",
            "RAM_Total_MB", "RAM_Used_MB", "RAM_Used_MB_MAX",
            "%_RAM_Util", "%_RAM_Util_MAX",
        ]:
            if row.get(field) is not None:
                try:
                    row[field] = int(float(row[field]))
                except Exception:
                    pass

        # Add only required fields
        rows.append({k: safe_comma(row.get(k)) for k in FIELD_NAMES})

    # ---------------------------------------------------------------
    # 5) Export CSV
    # ---------------------------------------------------------------
    if not rows:
        print("⚠️ No data to export.")
        return

    with open(OUT_FILE, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, FIELD_NAMES, delimiter=";", quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\n✅ Ready: {OUT_FILE}")
    print(f"⏱️ Done in {time.time() - start:.1f}s")


if __name__ == "__main__":
    main()
