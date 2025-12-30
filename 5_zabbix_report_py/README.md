# Zabbix Reporting Scripts — Overview (EN) ✅

Short README describing what each script does, where outputs are saved, and how to run them.

---

## 🔧 Prerequisites
- Create and activate a Python virtual environment.
- Install dependencies:

```bash
pip install -r requirements.txt
```

- Obtain a Zabbix API token (use `utils/Set-Token.py` or `utils/Set-Token.ps1`). Scripts use `get_token()` from `modules.utils`.
- Ensure `PERIOD_DAYS` is set (e.g., `PERIOD_DAYS = 28`) in your environment or before running scripts.

All outputs are written to the `reports/` directory.

---

## 🧩 Scripts & Outputs

- `src/zbx_general.py` — collects trend metrics (CPU, RAM, processes, etc.), aggregates AVG and MAX values, and writes `reports/zbx_trends.csv`.

- `src/zbx_disks_util.py` — computes average disk utilization (trend-based) for physical disks (Linux / Windows). Writes `reports/zbx_disks.csv`.

- `src/zbx_disks_fs.py` — collects filesystem size/used/free metrics (vfs.fs.dependent.size) per host and writes `reports/zbx_disks_fs.csv`.

- `src/zbx_cpu.py` — analyzes CPU spikes (based on `system.cpu.util`) and produces:
  - `reports/zbx_cpu_spikes.csv` — summary per host
  - `reports/zbx_cpu_spikes_raw.csv` — raw time series (timestamped)

- `src/merge_all.py` — merges the CSVs into `reports/merged_all_<PERIOD_DAYS>d.xlsx`, adds aggregated disk totals and conditional highlighting (>80%).

---

## ▶️ How to run

From repository root:

```bash
python src/zbx_general.py
python src/zbx_disks_util.py
python src/zbx_disks_fs.py
python src/zbx_cpu.py
python src/merge_all.py
```

Run `merge_all.py` after CSV files are generated.

---

## ⚠️ Notes
- CSV uses `;` as delimiter. Some numeric fields use comma as decimal for Excel compatibility.
- Make sure Excel is not open on target files — scripts overwrite outputs.
- Scripts require a working Zabbix API token and access to the Zabbix server.

