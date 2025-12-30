Import-Module ImportExcel

function getToken {
    if (-not $env:ZABBIX_TOKEN) {
        $secureToken = Read-Host "Enter the Zabbix token" -AsSecureString
        $ApiToken = [System.Net.NetworkCredential]::new("", $secureToken).Password
        $env:ZABBIX_TOKEN = $ApiToken
        Write-Host "✅ ok"
    }
    else {
        Write-Host "ℹ️ already on"
    }
}

getToken

$ZbxURL = "https://zabbix.forus.ee/api_jsonrpc.php"
$ApiToken = $env:ZABBIX_TOKEN
if (-not $ApiToken) { Write-Error "❌ no token"; exit }

$headers = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer $ApiToken"
}

Write-Host "📡 getting hosts..."
$hostsReq = @{
    jsonrpc = "2.0"
    method  = "host.get"
    params  = @{
        output           = @("hostid","host","name")
        selectInterfaces = @("ip")
        selectParentTemplates = @("name")
        filter           = @{ status = "0" } # only active
    }
    id = 1
}
$hosts = (Invoke-RestMethod -Uri $ZbxURL -Method POST -Headers $headers -Body ($hostsReq | ConvertTo-Json)).result

$result = @()

foreach ($h in $hosts) {
    Write-Host "👉 getting items for: $($h.host)" -ForegroundColor Cyan

    $templates = ($h.parentTemplates | ForEach-Object { $_.name } | Sort-Object) -join ", "

    $itemsReq = @{
        jsonrpc = "2.0"
        method  = "item.get"
        params  = @{
            output  = @("itemid","name","key_","value_type","units","lastvalue","lastclock","state","delay")
            hostids = $h.hostid
            sortfield = "name"
            limit = 5000
        }
        id = 2
    }

    $items = (Invoke-RestMethod -Uri $ZbxURL -Method POST -Headers $headers -Body ($itemsReq | ConvertTo-Json -Depth 4)).result

    foreach ($i in $items) {
        $result += [pscustomobject]@{
            HostID     = $h.hostid
            Host       = $h.host
            IP         = ($h.interfaces.ip -join ",")
            Templates  = $templates
            ItemID     = $i.itemid
            Name       = $i.name
            Key        = $i.key_
            Units      = $i.units
            Value_Type = $i.value_type
            LastValue  = $i.lastvalue
            LastClock  = if ($i.lastclock) { [datetime]::UnixEpoch.AddSeconds([double]$i.lastclock) }
            Delay      = $i.delay
            State      = switch ($i.state) {
                            0 { "OK" }
                            1 { "Not supported" }
                            default { $i.state }
                         }
        }
    }
}

$outFile = "zbx_allitems.xlsx"

Write-Host "📤 exporting Excel..."

if (Test-Path $outFile) {
    Remove-Item $outFile -Force
    Start-Sleep -Milliseconds 200
}

$result | Sort-Object Host, Name | Export-Excel -Path $outFile -WorksheetName "Zabbix_Items" -FreezeTopRow -TableName "allitems" -TableStyle "Medium2" -BoldTopRow -ErrorAction Stop

Write-Host "`n✅ ready: $outFile" -ForegroundColor Green
