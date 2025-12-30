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

# === period: last 7 days ===
$days = 7
$time_till = [int][double]::Parse((Get-Date -UFormat %s))
$time_from = $time_till - ($days * 86400)

#
# $keys = @(
#
#     "system.uptime",
#     "system.cpu.util",
#     'wmi.get[root/cimv2,"Select NumberOfLogicalProcessors from Win32_ComputerSystem"]',
#     "system.cpu.num",
#
#     'vm.memory.size[total]',
#     "vm.memory.size[used]",
#     "vm.memory.util",
#     "vm.memory.size[available]",
#     "vm.memory.utilization",
#
#     "system.swap.size[,total]",
#     "system.swap.free",
#     "system.swap.pfree",
#     "system.swap.size[,free]",
#     "system.swap.size[,pfree]",
#
#     "vfs.fs.dependent.size[/,total]",
#     "vfs.fs.dependent.size[/,used]",
#     "vfs.fs.dependent.size[/,pused]",
#     "vfs.dev.write.rate[sda]",
#     "vfs.dev.read.rate[sda]",
#     "vfs.dev.util[sda]",
#
#     "vfs.fs.dependent.size[C:,total]",
#     "vfs.fs.dependent.size[C:,used]",
#     "vfs.fs.dependent.size[C:,pused]",
#     'perf_counter_en["\PhysicalDisk(0 C:)\Disk Reads/sec",60]',
#     'perf_counter_en["\PhysicalDisk(0 C:)\Disk Writes/sec",60]',
#     'perf_counter_en["\PhysicalDisk(0 C:)\% Idle Time",60]',
#
#     "proc.num",
#     "proc.num[]"
# )
#

Write-Host "📡 get hosts..."

$hostsReq = @{
    jsonrpc = "2.0"
    method  = "host.get"
    params  = @{
        output                = @("hostid", "host")
        selectInterfaces      = @("ip")
        selectParentTemplates = @("name")
        filter                = @{ status = "0" } # enabled only
    }
    id = 1
}
$hosts = (Invoke-RestMethod -Uri $ZbxURL -Method POST -Headers $headers -Body ($hostsReq | ConvertTo-Json)).result

# === helper functions ===

function SafeMB($val) {
    if ($null -eq $val -or $val -eq "") { return $null }
    return [math]::Round(([double]$val / 1MB), 2)
}

function SafeGB($val) {
    if ($null -eq $val -or $val -eq "") { return $null }
    return [math]::Round(([double]$val / 1GB), 2)
}

# get average trend value for given key and host
function GetAvgTrend($hostid, $key) {
    # find itemid
    $itemReq = @{
        jsonrpc = "2.0"
        method  = "item.get"
        params  = @{
            output  = "itemid"
            hostids = $hostid
            filter  = @{ key_ = $key }
        }
        id = 2
    }
    $item = (Invoke-RestMethod -Uri $ZbxURL -Method POST -Headers $headers -Body ($itemReq | ConvertTo-Json)).result
    if (-not $item) { return $null }

    $itemid = $item[0].itemid

    # get trends
    $trendReq = @{
        jsonrpc = "2.0"
        method  = "trend.get"
        params  = @{
            output     = @("value_avg")
            itemids    = $itemid
            time_from  = $time_from
            time_till  = $time_till
        }
        id = 3
    }
    $trend = (Invoke-RestMethod -Uri $ZbxURL -Method POST -Headers $headers -Body ($trendReq | ConvertTo-Json)).result
    if (-not $trend) { return $null }

    $avg = ($trend | Measure-Object -Property value_avg -Average).Average
    if ($avg) { return [math]::Round([double]$avg, 2) } else { return $null }
}

$result = @()

foreach ($h in $hosts) {

    Write-Host "👉 $($h.host)" -ForegroundColor Yellow

    $ip = ($h.interfaces | ForEach-Object { $_.ip } | Where-Object { $_ } | Sort-Object -Unique) -join ","
    $templates = ($h.parentTemplates | ForEach-Object { $_.name } | Sort-Object) -join ", "

    # CPU
    $cpuCores = GetAvgTrend $h.hostid "system.cpu.num"
    if (-not $cpuCores) { $cpuCores = GetAvgTrend $h.hostid 'wmi.get[root/cimv2,"Select NumberOfLogicalProcessors from Win32_ComputerSystem"]' }
    $cpuUtil = GetAvgTrend $h.hostid "system.cpu.util"

    # RAM
    $ramTot = SafeMB (GetAvgTrend $h.hostid "vm.memory.size[total]")
    $ramUsed = SafeMB (GetAvgTrend $h.hostid "vm.memory.size[used]")
    if (-not $ramUsed) {
        $ramUsed = SafeMB ((GetAvgTrend $h.hostid "vm.memory.size[total]") - (GetAvgTrend $h.hostid "vm.memory.size[available]"))
    }
    $ramPct = GetAvgTrend $h.hostid "vm.memory.util"
    if (-not $ramPct) { $ramPct = GetAvgTrend $h.hostid "vm.memory.utilization" }

    # Swap
    $swapTot = SafeMB (GetAvgTrend $h.hostid "system.swap.size[,total]")
    $swapFree = SafeMB (GetAvgTrend $h.hostid "system.swap.free")
    if (-not $swapFree) { $swapFree = SafeMB (GetAvgTrend $h.hostid "system.swap.size[,free]") }
    $swapPct = GetAvgTrend $h.hostid "system.swap.pfree"
    if (-not $swapPct) { $swapPct = GetAvgTrend $h.hostid "system.swap.size[,pfree]" }

    # Uptime
    $uptimeSec = GetAvgTrend $h.hostid "system.uptime"
    $uptime = if ($uptimeSec) { [math]::Round($uptimeSec / 86400, 2) }

    # Processes
    $proc_num = GetAvgTrend $h.hostid "proc.num"
    if (-not $proc_num) { $proc_num = GetAvgTrend $h.hostid "proc.num[]" }

    # Disks Linux
    $totalspace = SafeGB (GetAvgTrend $h.hostid "vfs.fs.dependent.size[/,total]")
    $usedspace = SafeGB (GetAvgTrend $h.hostid "vfs.fs.dependent.size[/,used]")
    $pusedspace = GetAvgTrend $h.hostid "vfs.fs.dependent.size[/,pused]"
    $writerate = GetAvgTrend $h.hostid "vfs.dev.write.rate[sda]"
    $readrate = GetAvgTrend $h.hostid "vfs.dev.read.rate[sda]"
    $util = GetAvgTrend $h.hostid "vfs.dev.util[sda]"

    # Windows override
    if ($templates -match "windows") {
        $totalspace = SafeGB (GetAvgTrend $h.hostid "vfs.fs.dependent.size[C:,total]")
        $usedspace = SafeGB (GetAvgTrend $h.hostid "vfs.fs.dependent.size[C:,used]")
        $pusedspace = GetAvgTrend $h.hostid "vfs.fs.dependent.size[C:,pused]"
        $writerate = GetAvgTrend $h.hostid 'perf_counter_en["\PhysicalDisk(0 C:)\Disk Reads/sec",60]'
        $readrate = GetAvgTrend $h.hostid 'perf_counter_en["\PhysicalDisk(0 C:)\Disk Writes/sec",60]'
        $util = GetAvgTrend $h.hostid 'perf_counter_en["\PhysicalDisk(0 C:)\% Idle Time",60]'
    }

    $row = [ordered]@{
        HostID         = $h.hostid
        Host           = $h.host
        IP             = $ip
        Templates      = $templates
        CPU_Cores      = $cpuCores
        "%_CPU_Util"   = $cpuUtil
        Processes      = $proc_num
        RAM_Total_MB   = $ramTot
        RAM_Used_MB    = $ramUsed
        "%_RAM_Util"   = $ramPct
        Swap_Total_MB  = $swapTot
        Swap_Free_MB   = $swapFree
        "%_Swap_Free"  = $swapPct
        Uptime_Days    = $uptime
        Disk_total     = $totalspace
        Disk_used      = $usedspace
        "%_Disk_used"  = $pusedspace
        Disk_IO_Writes = $writerate
        Disk_IO_Reads  = $readrate
        "%_Disk_Util"  = $util
    }

    $result += [pscustomobject]$row
}

$outFile = "zbx_trends_avg_${days}d.csv"
$result | Sort-Object Host | Export-Csv $outFile -NoTypeInformation -Encoding utf8 -Delimiter ";"
Write-Host "`n✅ ready (7-day average trends): $outFile" -ForegroundColor Green
