import csv
import time
import re
from datetime import datetime

from modules.api import *
from modules.utils import *


# ==========================
# ⚙️ Settings
# ==========================
OUT_FILE = "reports/zbx_disks_fs.csv"


# ==========================
# Utils
# ==========================
def detect_os(templates):
    txt = ", ".join(t.get("name", "").lower() for t in templates)
    if "windows" in txt or "win32" in txt:
        return "Windows"
    if any(x in txt for x in ("linux", "ubuntu", "centos", "debian", "unix")):
        return "Linux"
    return None


# ==========================
# Main
# ==========================
def main():
    start = time.time()
    os.makedirs("reports", exist_ok=True)

    if not check_output_file(OUT_FILE, retries=2):
        return

    token = get_token()
    headers = make_headers(token)

    print("📡 Fetching hosts...")

    hosts = get_hosts(headers)
    if not hosts:
        print("❌ No hosts")
        return

    print(f"✅ {len(hosts)} hosts loaded.\n")

    rows = []

    # ======================================================
    # 🔁 Process each host
    # ======================================================
    for idx, h in enumerate(hosts, start=1):
        hostid = h["hostid"]
        hostname = h["host"]
        visible_name = h.get("name") or ""
        templates = h.get("parentTemplates", [])

        template_names = [t.get("name", "") for t in templates if t.get("name")]
        templates_str = ", ".join(template_names)
        

        ip_list = [i.get("ip") for i in h.get("interfaces", []) if i.get("ip")]
        ip = ",".join(ip_list) if ip_list else ""

        os_type = detect_os(templates)

        print(f"[{idx:>2}/{len(hosts)}] 🖥️ {hostname}")

        if not os_type:
            print("   ⚠ Unknown OS, skipping")
            continue

        # ======================================================
        # 📌 FILESYSTEMS (Linux + Windows)
        #     → vfs.fs.dependent.size[*] via lastvalue
        # ======================================================
        size_payload = {
            "jsonrpc": "2.0",
            "method": "item.get",
            "params": {
                "hostids": hostid,
                "output": ["itemid", "key_", "lastvalue"],
                "search": {"key_": "vfs.fs.dependent.size"},
                "filter": {"status": 0},
            },
            "id": 200,
        }

        size_items = zbx_request(ZBX_URL, headers, size_payload)
        fs_map = {}  # { "FS": {"total": X, "used": Y, "free": Z, "pused": N} }

        for it in size_items:
            key = it["key_"]
            raw = it["lastvalue"]

            if raw in (None, ""):
                continue

            # Linux:   vfs.fs.dependent.size[/var,used]
            # Windows: vfs.fs.dependent.size[C:,total]
            m = re.match(r"vfs\.fs\.dependent\.size\[(.+?),(.+?)\]", key)
            if not m:
                continue

            fsname = m.group(1)
            metric = m.group(2).lower()

            if metric not in ("total", "used", "free", "pused"):
                continue

            try:
                val = float(raw)
            except:
                continue

            fs_map.setdefault(fsname, {})
            fs_map[fsname][metric] = val

        # ------------------------------------------------------
        # Save FS rows
        # ------------------------------------------------------
        for fs, data in fs_map.items():
            if "total" not in data or "used" not in data:
                continue

            total = data["total"]
            used = data["used"]
            free = data.get("free", total - used)
            pused = data.get("pused", used / total * 100 if total else 0)

            total_gb = round(total / 1024**3, 2)
            used_gb = round(used / 1024**3, 2)
            free_gb = round(free / 1024**3, 2)

            print(f"   📁 FS {fs:<10} → {used_gb}/{total_gb} GB ({pused:.2f}%)")

            rows.append({
                "HostID": hostid,
                "Host": hostname,
                "VisibleName": visible_name,
                "IP": ip,
                "Templates": templates_str,
                "Trend": PERIOD_DAYS,
                "Filesystem": fs,
                "Metric": "Size",
                "Total_GB": total_gb,
                "Used_GB": used_gb,
                "Free_GB": free_gb,
                "UsedPercent": round(pused, 2),
            })

    # ======================================================
    # 📤 Export CSV
    # ======================================================
    print("\n📤 Exporting CSV...")

    fieldnames = [
        "HostID", "Host", "VisibleName", "IP", "Templates", "Trend",
        "Filesystem",
        "Metric",
        "Total_GB", "Used_GB", "Free_GB", "UsedPercent",
    ]

    # 1. Sort source rows (so numeric sorting behaves correctly)
    sorted_rows = sorted(rows, key=lambda x: (x["Host"], x["Filesystem"]))

    # 2. Conversion: dot to comma using the safe_comma helper
    transformed_rows = []
    for row in sorted_rows:
        # Apply safe_comma to each value in the row
        transformed_rows.append({k: safe_comma(v) for k, v in row.items()})


    with open(OUT_FILE, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, delimiter=";")
        w.writeheader()
        w.writerows(transformed_rows) # write transformed rows
        
    print(f"✅ Saved: {OUT_FILE}")
    print(f"⏱ Done in {time.time() - start:.1f}s")


if __name__ == "__main__":
    main()
