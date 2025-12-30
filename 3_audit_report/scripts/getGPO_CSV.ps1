#Import-Module GroupPolicy -ErrorAction Stop

$outFile = "GPO_Report.csv"

$start = Get-Date
Write-Host "Starting GPO report generation at $start`n"

[xml]$xml = Get-GPOReport -All -ReportType Xml
$gpoBase = Get-GPO -All
$gpos = $xml.SelectNodes("//*[local-name()='GPO']")

$results = foreach ($g in $gpos) {
    # --- GUID ---
    $guidNode = $g.SelectSingleNode("*[local-name()='Identifier']/*[local-name()='Identifier']")
    $guid = if ($guidNode) { $guidNode.InnerText -replace '[{}]' } else { "" }

    # --- Get-GPO ---
    $gpoObj = $gpoBase | Where-Object { $_.Id.Guid -eq $guid }

    $name = $gpoObj.DisplayName
    $desc = ($gpoObj.Description -replace "`r?`n", " ").Trim()
    if ([string]::IsNullOrWhiteSpace($desc)) { $desc = "" }

    $modified = $gpoObj.ModificationTime.ToString("yyyy-MM-dd")
    $status   = $gpoObj.GpoStatus

    #
    $linkNodes = $g.SelectNodes("*[local-name()='LinksTo']/*[local-name()='SOMPath']")
    $links = @()
    foreach ($ln in $linkNodes) { $links += $ln.InnerText }

    $scope = if (-not $links) {
        "Unlinked"
    } elseif ($links -match "^Site:") {
        "Site"
    } elseif ($links -match "/") {
        "OU"
    } else {
        "Domain Root"
    }

    # --- 
    $settings = $g.SelectNodes(".//*[local-name()='ExtensionData']")
    $settingsCount = if ($settings) { $settings.Count } else { 0 }

    # --- Security Filtering ---
    $permNodes = $g.SelectNodes(".//*[local-name()='Permissions']/*[local-name()='TrusteePermissions']")
    $trustees = @()
    foreach ($p in $permNodes) {
        $perm = $p.SelectSingleNode(".//*[local-name()='GPOGroupedAccessEnum']")
        if ($perm -and $perm.InnerText -eq "Apply Group Policy") {
            $tname = $p.SelectSingleNode(".//*[local-name()='Trustee']/*[local-name()='Name']")
            if ($tname) { $trustees += $tname.InnerText }
        }
    }
    $securityFiltering = if ($trustees.Count -eq 0) {
        "Authenticated Users (default)"
    } else {
        ($trustees | Sort-Object -Unique) -join " & "
    }

    # --- 
    [PSCustomObject]@{
        Name              = $name
        GUID              = $guid
        Description       = $desc
        Modified          = $modified
        Status            = $status
        LinkCount         = $links.Count
        Links             = ($links -join " & ")
        Scope             = $scope
        SettingsCount     = $settingsCount
        SecurityFiltering = $securityFiltering
    }
}

# === 
$results | Sort-Object Name |
Export-Csv -Path $outFile -NoTypeInformation -Encoding UTF8 -Delimiter ";"

# ===
$end = Get-Date
$duration = $end - $start
Write-Host "`nReport saved: $outFile"
Write-Host "Completed at $end"
Write-Host "Duration: $($duration.ToString())"