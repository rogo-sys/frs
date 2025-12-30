#####
# Robocopy Multi-folder Migration Script (CSV by fields)
# nagu batch
#  
#  parameters
# .\script.ps1 -Mode List           - for listing only . by default
# .\script.ps1 -Mode Copy           - for copy
# .\script.ps1 -Mode Mirror         - for final 
# .\script.ps1 -Mode Move -Force    - ...Not used, but FFR...
#################################################################################

param(
    [ValidateSet('List', 'Copy', 'Mirror', 'MirrorList', 'Move')]
    [string]$Mode = 'List',

    [switch]$Force   # safety check for Move.. FFR 
)

# --- LOGS DIR ---
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$RunStamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$LogsDir = Join-Path $ScriptDir ("logs_{1}_{0}_after_migro" -f $Mode, $RunStamp)
New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null

$ListFile = Join-Path $ScriptDir "robocopy_jobs_after_migro.csv"
$GlobalLog = Join-Path $LogsDir "_yldine_log.txt"

# robocopy src dst /E /COPY:DAT DCOPY:DAT /Z /R:2 /W:2 /NP /XJ /L
$RobocopyParams = @(
    "/E",           # copies all subfolders, including empty ones.
    "/COPY:DAT",    # Files - copies only Data, Attributes, and Timestamps (no NTFS ACLs/owner/audit from L-Ketas. we don't need it).
    "/DCOPY:DAT",   # Directories - copies only Data, Attributes, and Timestamps (no NTFS ACLs/owner/audit from L-Ketas. we don't need it).
    "/Z",           # /Z — restartable mode (a bit slower, but more resilient to interruptions or netw.disconnects).
    "/R:2",         # Retries - up to 2 times
    "/W:2",         # Waiting 2 seconds between retries if an error occurs.
    "/NP",          # no progress output (suppresses % progress, less console/log spam).
    "/XJ"           # excludes junction points (reparse points). It prevents Robocopy from following directory links that can lead outside the expected folder tree or cause recursive/duplicate copying.
)

switch ($Mode) {
    'List' { $RobocopyParams += "/L" }          # "/L" for test run (no changes)
    'Copy' { }                                  # migra
    'Mirror' { $RobocopyParams += "/MIR" }        # "/MIR" only for final run (mirror). Lõppjooksu
    'MirrorList' { $RobocopyParams += "/MIR"; $RobocopyParams += "/L" }
    'Move' {
        # Not used, but for FFR...
        if (-not $Force) { throw "Mode=Move is destructive. Re-run with -Force." }
        $RobocopyParams += "/MOVE"
    }
}

# P.S:
# /MT:16 didn’t make much of a difference. /MT:32 and /MT:64 made it worse. (If /MT is omitted, the default is /MT:8.)
# /IO:1 ja /J — mixed results...; not enabled to keep the parameter string simple.
# /NFL /NDL /NJH /NJS — ma ei kasuta ; they reduce log output, but we want full copy details.


function Write-Log($msg) {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$ts  $msg" | Out-File -FilePath $GlobalLog -Encoding utf8 -Append
    Write-Host $msg
}

Write-Log "================================== .: STARTED =================================="
Write-Log " MODE: $Mode"
Write-Log ""


if (!(Test-Path -LiteralPath $ListFile)) {
    Write-Error "CSV file not found: $ListFile"
    exit
}

$rows = Import-Csv -Path $ListFile -Delimiter ';' -Encoding UTF8
$total = $rows.Count
$i = 0

foreach ($row in $rows) {
    $i++

    $src = $row.srcPath.Trim()
    $dst = $row.dstPath.Trim()
    if ($src.Length -gt 3) { $src = $src.TrimEnd('\', '/') }
    if ($dst.Length -gt 3) { $dst = $dst.TrimEnd('\', '/') }

    if ([string]::IsNullOrWhiteSpace($src) -or
        [string]::IsNullOrWhiteSpace($dst)) {
        Write-Log "[$i/$total] SKIPPED — empty src/dst"
        continue
    }

    # лог для папки
    $folderName = Split-Path -Path $src -Leaf
    $safeName = ($folderName -replace "[^a-zA-Z0-9-_]", "_")
    # $safeName = ($src -replace "[^a-zA-Z0-9-_]", "_")
    if ($safeName.Length -gt 80) { $safeName = $safeName.Substring(0, 80) }
    $tsRun = (Get-Date).ToString("yyyyMMdd_HHmmss")  
    $FolderLog = Join-Path $LogsDir ("log{0}-{1}-{2}.txt" -f $i, $safeName, $tsRun)
    # $FolderLog = ".\log_{0}_{1}.txt" -f $safeName, $tsRun

    Write-Log "[$i/$total]"
    Write-Log "  SRC: $src"
    Write-Log "  DST: $dst"
    Write-Log ("  PARAMS: {0}" -f ($RobocopyParams -join ' '))

    if (!(Test-Path -LiteralPath $src)) {
        Write-Log "  ERROR: Source not found"
        continue
    }

    # if ($Mode -ne 'List' -and !(Test-Path -LiteralPath $dst)) -  eemaldasin selle, sest List-režiimis kukub Robocopy läbi, kui sihtkausta (destination) veel ei ole olemas.
    if (!(Test-Path -LiteralPath $dst)) {
        Write-Log "  Creating destination"
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
    }

    Write-Log "  Log in: $FolderLog"
    Write-Log "  Running robocopy"

    & robocopy $src $dst @RobocopyParams "/UNILOG:$FolderLog" | Out-Null
    $RobocopyExitCode = $LASTEXITCODE
    
    if ($RobocopyExitCode -ge 8) {
        Write-Log "  !!! WARNING. Robocopy Exit Code: $RobocopyExitCode "
    }
    else {
        Write-Log "  SUCCESS/INFO. Robocopy Exit Code:  $RobocopyExitCode"
    }
    Write-Log ""
    Write-Host "----------------------------------"
}

Write-Log "================================== COMPLETED :. =================================="

# p.s
# With robocopy, the exit codes are not like typical programs where 0 = OK and anything else = error. Robocopy uses a bitmask to describe what happened.
# Robocopy exit codes (bitmask)
# Robocopy does NOT use the usual "0 = OK, anything else = error" scheme.
# The exit code is a bitmask, meaning one number can represent multiple results.
#
# Practical rule:
#   0–7   = OK / INFO (success, but may include non-critical differences)
#   >= 8  = FAIL / ERRORS (check the robocopy log)
#
# 0  = No files were copied. Source and destination are already identical. No errors.
# 1  = Files were copied successfully (new or changed files). No errors.
# 2  = Extra files/directories were detected on the destination (present on DST, not on SRC).
# 3  = (1 + 2) Files were copied and extra items exist on the destination.
# 4  = Mismatched files/directories were detected (attributes/timestamps/size differences; updates may be needed).
# 5  = (1 + 4) Files were copied and mismatches were detected.
# 6  = (2 + 4) Extra items on destination and mismatches were detected.
# 7  = (1 + 2 + 4) Files were copied, extra items exist on destination, and mismatches were detected.