## тоже самое что и прошлый по скорости. пустые папки не включает
#
#
#  исключить папки:
#   if ($path.EndsWith("\")) { continue }
#
#  
#
#

$global:sb = New-Object System.Text.StringBuilder

# =============================
# Convert-Bytes (должна быть первой!)
# =============================
function Convert-Bytes {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

function Escape-Csv-Fast {
    param([string]$v)

    # Return empty quoted if null
    if ($null -eq $v) { return '""' }

    $containsQuote = $v.Contains('"')
    if (-not $containsQuote) {
        # Fast path — no escaping needed
        return '"' + $v + '"'
    }

    # Slow path — escape quotes ONLY IF THEY EXIST
    $sb.Clear() | Out-Null
    $sb.Append('"') | Out-Null

    foreach ($ch in $v.ToCharArray()) {
        if ($ch -eq '"') {
            $sb.Append('""') | Out-Null
        } else {
            $sb.Append($ch) | Out-Null
        }
    }

    $sb.Append('"') | Out-Null
    return $sb.ToString()
}


# =====================================================================
# MAIN PARSER — 
# =====================================================================
function csvpars_ultra_fast {

    # BUFFERS: 64 KB = VERY FAST
    $reader = New-Object System.IO.StreamReader($OutFile, [System.Text.Encoding]::UTF8)
    $writer = New-Object System.IO.StreamWriter($OutCsvFile, $false, [System.Text.Encoding]::UTF8, 65536)

    $writer.WriteLine('"SizeBytes";"SizeHuman";"Path";"Length"')

    while (-not $reader.EndOfStream) {

        $line = $reader.ReadLine()
        if ($null -eq $line) { continue }

        $line = $line.Trim()
        if ($line.Length -eq 0) { continue }

        $parts = $line -split "\s+", 2
        if ($parts.Count -lt 2) { continue }

        $size = $parts[0]
        $path = $parts[1]

        #if ($path.EndsWith("\")) { continue }

        $sizeHuman = Convert-Bytes([int64]$size)

        # BUILD LINE — VERY FAST
        $csvLine =
            (Escape-Csv-Fast $size)      + ";" +
            (Escape-Csv-Fast $sizeHuman) + ";" +
            (Escape-Csv-Fast $path)      + ";" +
            (Escape-Csv-Fast $path.Length)

        $writer.WriteLine($csvLine)
    }

    $reader.Close()
    $writer.Close()
}



$OutFile= "list_utf.txt"
$OutCsvFile = "list_csvfin.csv"






$global:swTotal = [System.Diagnostics.Stopwatch]::StartNew()


csvpars_ultra_fast



$swTotal.Stop()



Write-Host "-----------------------------"
Write-Host "Execution time:"
Write-Host ("TOTAL:        {0:N2} sec" -f $swTotal.Elapsed.TotalSeconds)
Write-Host "-----------------------------"


Read-Host "Done. Press ENTER to exit..."