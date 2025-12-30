Add-Type -AssemblyName System.Windows.Forms

# =====================================================================
# Folder selection dialog
# =====================================================================
function choicefolder {
    # folderchoice
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the folder to scan (robocopy /L):"

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Cancelled."
        exit
    }

    $global:Path = $dialog.SelectedPath

}

$OutDir = ""
# Autodetect directory if OutDir is empty
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$TmpRaw = "list_raw.txt"

$OutFile = Join-Path $OutDir $TmpRaw

$Path_Dummy = "E:\Dummy"
$Path = "E:\Avalik\"


$Params = @(
    "/L",                       # list only, do not copy
    "/S",                       # include all subfolders
    "/NJH",                     # no job header
    "/BYTES",                   # output file sizes in bytes
    # "/UNICODE",
    "/NJS",                     # no job summary
    "/unilog:$OutFile",      # write Unicode log directly to file
    "/FP",                      # show full file paths
    #"/NS",                     # no size (disabled because we need size)
    #"/TEE"                     # duplicate output to console
    "/NC"                       # no file class info
    #"/NDL"                     # no directory listing
    #"/NFL"                     # list files only (no directories)
)


choicefolder
$global:swTotal = [System.Diagnostics.Stopwatch]::StartNew()

robocopy $Path $Path_Dummy @Params

$swTotal.Stop()

Write-Host "-----------------------------"
Write-Host "Execution time:"
Write-Host ("Robocopy:        {0:N2} sec" -f $swTotal.Elapsed.TotalSeconds)
Write-Host "-----------------------------"
Read-Host "Done. Press ENTER to exit..."

