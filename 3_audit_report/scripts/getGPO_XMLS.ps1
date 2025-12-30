# Output folder (in the same directory as the script)
$outDir = Join-Path $PSScriptRoot "GPO_XML"
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# Import GroupPolicy module
Import-Module GroupPolicy -ErrorAction Stop

# Get all GPOs
$gpos = Get-GPO -All

foreach ($gpo in $gpos) {
    $name = $gpo.DisplayName
    # Replace invalid filename characters
    $safeName = ($name -replace '[\\/:*?"<>|]', '_')

    # Output file path
    $outFile = Join-Path $outDir "$safeName.xml"

    try {
        # Export GPO to XML
        Get-GPOReport -Name $name -ReportType Xml -Path $outFile
        Write-Host "Exported: $name"
    }
    catch {
        Write-Warning "Error exporting: $name"
    }
}

Write-Host "`nDone! All files saved to: $outDir"
