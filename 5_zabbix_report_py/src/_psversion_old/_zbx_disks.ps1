# ------------------------------------------------------------------
# Linux: vfs.dev.util[*]
# Windows: perf_counter_en["\PhysicalDisk(...)\% Idle Time",60]
# ------------------------------------------------------------------

$ZbxURL = "https://zabbix.forus.ee/api_jsonrpc.php"
$CsvFilePath = "zbx_disks_7d.csv"

# --- 1. Get the token ---
function Get-ZabbixToken {
    if (-not $env:ZABBIX_TOKEN) {
        $secureToken = Read-Host "Enter Zabbix API Token" -AsSecureString
        $ApiToken = [System.Net.NetworkCredential]::new("", $secureToken).Password
        $env:ZABBIX_TOKEN = $ApiToken
        Write-Host "✅ Token set." -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Token already set in environment." -ForegroundColor Yellow
    }
}

Get-ZabbixToken
$ApiToken = $env:ZABBIX_TOKEN
if (-not $ApiToken) { Write-Error "❌ No token."; exit }

# --- 2. Universal API call ---
function Invoke-ZabbixApi {
    param(
        [Parameter(Mandatory)] [string]$method,
        [Parameter()] [Hashtable]$params = @{}
    )

    $headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $ApiToken"
    }

    $body = @{
        jsonrpc = "2.0"
        method  = $method
        params  = $params
        id      = (Get-Random)
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod -Uri $ZbxURL -Method Post -Headers $headers -Body $body
        if ($response.error) {
            Write-Error "❌ API Error ($method): $($response.error.message) - $($response.error.data)"
            return $null
        }
        return $response.result
    } catch {
        Write-Error "❌ Error calling Zabbix API: $($_.Exception.Message)"
        return $null
    }
}

# --- 3. Get the list of active hosts ---
Write-Host "`n-- Getting list of active hosts... --" -ForegroundColor Cyan

$hosts = Invoke-ZabbixApi -method "host.get" -params @{
    output                = @("hostid", "name")
    selectParentTemplates = @("name")
    filter = @{ status = 0 }
}

if (-not $hosts) { Write-Error "No available hosts."; exit }

Write-Host "Found $($hosts.Count) hosts." -ForegroundColor Green

# --- 4. Set trend range ---
$timeTo   = [int][DateTimeOffset]::Now.ToUnixTimeSeconds()
$timeFrom = [int][DateTimeOffset]::Now.AddDays(-7).ToUnixTimeSeconds()


# --- 5. Collect data ---
$allDiskUtil = @()

foreach ($h in $hosts) {
    $templates = ($h.parentTemplates.name) -join ", "
    Write-Host "▶ $($h.name) [$templates]" -ForegroundColor Yellow

    $isWinHost = $templates -match "(Windows|Win32)"
    $isLinHost = $templates -match "(Linux|Unix|CentOS|Ubuntu|Debian)"

    if (-not ($isWinHost -or $isLinHost)) {
        Write-Host "   ⚠️ Unknown OS type, skipping."
        continue
    }

    # ---------- Linux ----------
    if ($isLinHost) {
        $items = Invoke-ZabbixApi -method "item.get" -params @{
            hostids = $h.hostid
            output  = @("itemid", "key_")
            search  = @{ key_ = "vfs.dev.util" }
            filter  = @{ status = 0 }
        }

        if ($items) {
            foreach ($item in $items) {
                if ($item.key_ -match 'vfs\.dev\.util\[(?<dev>[^\]]+)\]') {
                    $dev = $matches['dev']

                    # Get trend for 7 days
                    $trend = Invoke-ZabbixApi -method "trend.get" -params @{
                        itemids  = $item.itemid
                        time_from = $timeFrom
                        time_till = $timeTo
                        output   = @("value_avg")
                    }

                    if ($trend) {
                        $avg = [math]::Round(($trend.value_avg | Measure-Object -Average).Average, 4)
                        $allDiskUtil += [PSCustomObject]@{
                            HostID  = $h.hostid
                            Host    = $h.name
                            OS      = "Linux"
                            Disk    = $dev
                            Metric  = "Avg Utilization 7d (%)"
                            Value   = "{0:N4} %" -f $avg
                            ItemKey = $item.key_
                        }
                    }
                }
            }
        }
    }

    # ---------- Windows ----------
    if ($isWinHost) {
        $items = Invoke-ZabbixApi -method "item.get" -params @{
            hostids = $h.hostid
            output  = @("itemid", "key_")
            search  = @{ key_ = "perf_counter_en" }
            filter  = @{ status = 0 }
        }

        if ($items) {
            foreach ($item in $items) {
                if ($item.key_ -match 'perf_counter_en\["\\PhysicalDisk\((?<disk>\d+ [A-Z]:)\)\\% Idle Time"') {
                    $disk = $matches["disk"]

                    # Get trend for 7 days
                    $trend = Invoke-ZabbixApi -method "trend.get" -params @{
                        itemids  = $item.itemid
                        time_from = $timeFrom
                        time_till = $timeTo
                        output   = @("value_avg")
                    }

                    if ($trend) {
                        $avg = [math]::Round(($trend.value_avg | Measure-Object -Average).Average, 4)
                        $allDiskUtil += [PSCustomObject]@{
                            HostID  = $h.hostid
                            Host    = $h.name
                            OS      = "Windows"
                            Disk    = $disk
                            Metric  = "Avg Utilization 7d (%)"
                            Value   = "{0:N4} %" -f $avg
                            ItemKey = $item.key_
                        }
                    }
                }
            }
        }
    }
}

# --- 6. Export ---
Write-Host "`n-- Exporting results... --" -ForegroundColor Cyan

if ($allDiskUtil.Count -gt 0) {
    $allDiskUtil | Sort-Object Host, Disk |
    Export-Csv -Path $CsvFilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
    Write-Host "✅ Report saved: $CsvFilePath" -ForegroundColor Green
}
else {
    Write-Host "❌ No metrics found." -ForegroundColor Red
}
