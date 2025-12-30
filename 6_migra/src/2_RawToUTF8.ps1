
$OutRAWFile = "list_raw.txt"
$OutFile= "list_utf.txt"



# =====================================================================
# UTF-16 → UTF-8 conversion
# =====================================================================


function Convert-Utf16ToUtf8 {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Destination
    )

    $reader = New-Object System.IO.StreamReader($Source, [System.Text.Encoding]::Unicode)
    $writer = New-Object System.IO.StreamWriter($Destination, $false, [System.Text.Encoding]::UTF8)

    try {
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            $writer.WriteLine($line)
        }
    }
    finally {
        if ($reader) { $reader.Close() }
        if ($writer) { $writer.Close() }
    }
}



$global:swTotal = [System.Diagnostics.Stopwatch]::StartNew()
Convert-Utf16ToUtf8 -Source $OutRAWFile -Destination $OutFile      
$swTotal.Stop()

Write-Host "-----------------------------"
Write-Host "Execution time:"
Write-Host ("TOTAL:        {0:N2} sec" -f $swTotal.Elapsed.TotalSeconds)
Write-Host "-----------------------------"
#Read-Host "Done. Press ENTER to exit..."