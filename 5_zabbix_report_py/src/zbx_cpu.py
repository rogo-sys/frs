import csv
import time
from datetime import datetime, timezone
# Note: it is assumed that get_hosts in modules.api retrieves host interfaces,
# for example, get_hosts(headers, output=['hostid', 'host', 'name'], selectInterfaces=['ip'])
from modules.api import *
from modules.utils import * # ==========================
# 🧭 Analysis parameters
# ==========================
THRESHOLD = 80
MIN_DURATION = 60
SAMPLE_INTERVAL = 60
# PERIOD_DAYS = 28 # This variable should be defined somewhere above, e.g., in run arguments
# For correct f-string behavior, set a temporary value:
# try:
#     PERIOD_DAYS
# except NameError:
#     PERIOD_DAYS = 28 

OUT_FILE = f"reports/zbx_cpu_spikes.csv"
OUT_RAW = f"reports/zbx_cpu_spikes_raw.csv"

start = time.time()

# ==========================
# ⚙️ additional functions
# ==========================
def make_result(host_name, host_id, ip, visible_name, templates_str,  interval="-", count="-", max_dur="-", sum_dur="-",
                total_above="-", history_count="-", note=None):
    """
    Constructs the result dict for the summary report.
    'IP' field added.
    """
    return {
        "HostID": host_id,
        "Host": host_name,
        "VisibleName": visible_name,
        "IP": ip, # <-- Added IP field
        "Templates": templates_str,
        "Trend": PERIOD_DAYS,
        "Threshold_Percent": THRESHOLD,
        "Effective_Interval_s": interval,
        "CPU_Spikes_Count": count,
        "CPU_Spike_Max_s": max_dur,
        "CPU_Spikes_Total_s": sum_dur,
        "History_Records_Count": history_count,
        "Total_Samples_Above_Threshold": total_above,
        "Note": note or ""
    }


def get_history(headers, itemid, time_from, time_till):
    """Retrieves history for the specified itemid."""
    payload = {
        "jsonrpc": "2.0",
        "method": "history.get",
        "params": {
            "history": 0,
            "itemids": [itemid],
            "time_from": time_from,
            "time_till": time_till,
            "output": "extend",
            "sortfield": "clock",
            "sortorder": "ASC"
        },
        "id": 3
    }
    return zbx_request(ZBX_URL, headers, payload)


def detect_interval(history, default_interval=SAMPLE_INTERVAL):
    """Determines data collection interval from history."""
    if len(history) >= 2:
        try:
            diff = int(history[1]["clock"]) - int(history[0]["clock"])
            if diff > 0 and diff != default_interval:
                print(f"⚠️ Detected dynamic interval: {diff}s (instead of {default_interval}s)")
                return diff
        except Exception:
            pass
    return default_interval


def analyze_spikes(values, interval):
    """Analyzes a list of values for spikes."""
    spikes = []
    countable = []
    cur = 0
    total_above = 0

    for val in values:
        if val >= THRESHOLD:
            cur += 1
            total_above += 1
        else:
            dur = cur * interval
            if dur >= MIN_DURATION:
                # Include all exceedances in spikes, and only those lasting >= 2 intervals in countable
                spikes.append(dur)
                if cur >= 2: # Ensure the spike lasted at least two intervals; e.g., if interval is 60s, then 120s.
                    countable.append(dur)
            cur = 0

    # Check the final spike
    dur = cur * interval
    if dur >= MIN_DURATION:
        spikes.append(dur)
        if cur >= 2:
            countable.append(dur)

    count = len(countable)
    max_dur = max(countable) if countable else 0
    sum_dur = sum(countable) if countable else 0
    return count, max_dur, sum_dur, total_above


# ==========================
# 🚀 Main logic
# ==========================
def main():
    token = get_token()
    headers = make_headers(token)

    time_till = int(time.time())
    time_from = time_till - PERIOD_DAYS * 24 * 3600

    print(f"🕒 Period: {datetime.fromtimestamp(time_from)} → {datetime.fromtimestamp(time_till)}")
    print("\n📡 Fetching active hosts...")
    # Requires get_hosts to return interface data (selectInterfaces=['ip'])
    hosts = get_hosts(headers) 

    if not hosts:
        print("❌ No hosts found.")
        return

    total_hosts = len(hosts)
    print(f"✅ Found {total_hosts} hosts.\n")

    results = []
    raw_data = []

    # --- Main loop over hosts ---
    for i, h in enumerate(hosts, start=1):
        host_name = h.get("host")
        host_id = h.get("hostid")
        visible_name = h.get("name") or ""
        
        
        templates = h.get("parentTemplates", []) or []
        template_names = [t.get("name", "") for t in templates if t.get("name")]
        templates_str = ", ".join(template_names)



        # 🆕 Extract IP address

        ip_list = [i["ip"] for i in h.get("interfaces", []) if i.get("ip")]
        ip = ",".join(ip_list) if ip_list else ""

        prefix = f"[{i:>2}/{total_hosts}]"

        print(f"{prefix} 🖥️  {host_name} ({ip})")

        item = get_cpu_item(headers, host_id)
        if not item:
            print(f"   ⛔ No 'system.cpu.util' item.")
            results.append(make_result(host_name, host_id, ip, visible_name, templates_str,  note="no item")) # <-- Passing ip
            continue

        itemid = item["itemid"]
        history = get_history(headers, itemid, time_from, time_till)
        interval = detect_interval(history)
        values = [float(rec["value"]) for rec in history] if history else []

        if not values:
            print(f"   ⚠️  No data for last {PERIOD_DAYS}d.")
            results.append(make_result(host_name, host_id, ip, visible_name, templates_str, note="no data")) # <-- Passing ip
            continue

        # --- Raw data ---
        for rec in history:
            raw_data.append({
                "HostID": host_id,
                "Host": host_name,
                "VisibleName": visible_name,
                "IP": ip, # <-- Added to raw data
                "Templates": templates_str,
                "Trend": PERIOD_DAYS,
                "Clock": datetime.fromtimestamp(int(rec["clock"])).strftime("%Y-%m-%d %H:%M:%S"),
                "Value": float(rec["value"]),
                "Threshold_Percent": THRESHOLD,
                "Effective_Interval_s": interval,
                "Over_Threshold": float(rec["value"]) >= THRESHOLD
            })

        # --- Analysis ---
        count, max_dur, sum_dur, total_above = analyze_spikes(values, interval)
        results.append(make_result(
            host_name, host_id, ip, visible_name, templates_str, interval, count, max_dur, sum_dur, total_above, len(values) # <-- Passing ip
        ))

        # --- Per-host result output ---
        print(
            f"   📊 {len(values):>4} rec | "
            f"spikes={count:<2} | "
            f"max={int(max_dur):>4}s | "
            f"sum={int(sum_dur):>5}s | "
            f"above={total_above}"
        )

    # ==========================
    # 📤 Export results
    # ==========================
    if results:
        # Fieldnames now include 'IP'
        with open(OUT_FILE, "w", newline="", encoding="utf-8-sig") as f:
            writer = csv.DictWriter(f, fieldnames=results[0].keys(), delimiter=";")
            writer.writeheader()
            writer.writerows(results)
        print(f"\n✅ Summary exported: {OUT_FILE}")

    if raw_data:
        # Fieldnames for raw data now include 'IP'
        with open(OUT_RAW, "w", newline="", encoding="utf-8-sig") as f:
            writer = csv.DictWriter(f, fieldnames=raw_data[0].keys(), delimiter=";")
            writer.writeheader()
            writer.writerows(raw_data)
        print(f"✅ Raw data exported: {OUT_RAW}")

    if not results and not raw_data:
        print("⚠️ No data collected.")

    # --- Summary ---
    ok_hosts = sum(1 for r in results if r["CPU_Spikes_Count"] not in ("-", "no data"))
    no_item = sum(1 for r in results if r["Note"] == "no item")
    no_data = sum(1 for r in results if r["Note"] == "no data")

    print(f"\n📈 Summary:")
    print(f"   ✅ Completed: {ok_hosts}")
    print(f"   ⚠️  No data:  {no_data}")
    print(f"   ⛔ No item:   {no_item}")
    print(f"   ⏱️  Duration: {time.time() - start:.1f}s")


# ==========================
# ▶️ Entry point
# ==========================
if __name__ == "__main__":
    main()