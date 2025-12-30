# Robocopy Migration Scripts — README (English)

## 🔧 Overview
A small collection of PowerShell helper scripts to list files/folders with Robocopy, convert and parse the listing into CSV, and run multi-folder Robocopy jobs (including a simple GUI).

## ✅ Prerequisites
- Windows
- PowerShell (5.x or later)
- Robocopy (bundled with Windows)

## 📁 Main scripts (in `src/`)
- `1_GetRawList.ps1` — Launches a folder picker and runs `robocopy /L /S` to produce a Unicode file list (`list_raw.txt`). Includes file sizes (bytes).
- `1_GetRawListDirsOnly.ps1` — Same as above but lists directories only (`/NFL`).
- `2_RawToUTF8.ps1` — Converts `list_raw.txt` (UTF-16) to UTF-8 `list_utf.txt`.
- `3_ParseToCsv.ps1` — Parses `list_utf.txt` into `list_csvfin.csv` with columns: `SizeBytes;SizeHuman;Path;Length`.
- `4_Rogocopy_CSV.ps1` — Reads `robocopy_jobs.csv` and executes per-row Robocopy jobs. Supports `-Mode` parameter: `List`, `Copy`, `Mirror`, `MirrorList`, `Move`. Creates per-folder logs and a summary log.
- `4_Rogocopy_CSV_after_migro.ps1` — Variant that uses `robocopy_jobs_after_migro.csv` (same behavior but different default logging folder/name).
- `4_Rogocopy_vana_GUI.ps1` — Small GUI for manual Robocopy runs (Test Run / Full Copy) with simple timestamped logs.

## 📝 Typical workflow
1. Run `1_GetRawList.ps1` to produce `list_raw.txt` (or `1_GetRawListDirsOnly.ps1` for directories).  
2. Convert encoding: `2_RawToUTF8.ps1` → `list_utf.txt`.  
3. Parse: `3_ParseToCsv.ps1` → `list_csvfin.csv`.  
4. Prepare `robocopy_jobs.csv` (src/dst rows) and run `4_Rogocopy_CSV.ps1 -Mode List` to test, then `-Mode Copy` or `-Mode Mirror` to perform copy.

## ⚠️ Notes
- Robocopy exit codes are bitmasks. Practical rule: 0–7 = OK/info, >=8 = errors. Check per-folder logs on failures.
- `4_Rogocopy_CSV*.ps1` will create destination folders if they do not exist.
- Logs are UTF-8 and stored under `logs_*` directories next to the script.

## ℹ️ Tips
- Use `-Mode List` first to perform dry-runs (adds `/L` to Robocopy).
- Edit `robocopy_jobs.csv` with `;` as delimiter and `srcPath;dstPath` columns.

---

Use these scripts carefully (especially `-Mode Move` / `-Mode Mirror` — destructive modes). No warranty offered.