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


$keys = @(

    ### General
    "system.uptime",
    "system.cpu.util",

    ### Cpu Cores windows  
    'wmi.get[root/cimv2,"Select NumberOfLogicalProcessors from Win32_ComputerSystem"]', ## for Windows hosts: get number of logical processors
    ### Cpu Cores Linux
    "system.cpu.num",

    ### Memory  gen
    'vm.memory.size[total]',

    # Memory windows 
    "vm.memory.size[used]",
    "vm.memory.util",

    ### Memory Linux
    "vm.memory.size[available]",
    "vm.memory.utilization",

    # Swap general
    "system.swap.size[,total]",

    ### Swap windows
    "system.swap.free",
    "system.swap.pfree",

    # Swap linux
    "system.swap.size[,free]",
    "system.swap.size[,pfree]",

    ### Disks Linux
    "vfs.fs.dependent.size[/,total]",
    "vfs.fs.dependent.size[/,used]",
    "vfs.fs.dependent.size[/,pused]",
    "vfs.dev.write.rate[sda]"
    "vfs.dev.read.rate[sda]"
    "vfs.dev.util[sda]"

    ### Disks Windows
    "vfs.fs.dependent.size[C:,total]",
    "vfs.fs.dependent.size[C:,used]",
    "vfs.fs.dependent.size[C:,pused]",
    'perf_counter_en["\PhysicalDisk(0 C:)\Disk Reads/sec",60]',
    'perf_counter_en["\PhysicalDisk(0 C:)\Disk Writes/sec",60]',
    'perf_counter_en["\PhysicalDisk(0 C:)\% Idle Time",60]',

    # Processes linux
    "proc.num",
    # Processes Windows
    "proc.num[]"

    # Reserved
    # "system.cpu.load[all,avg1]",
    # "system.cpu.load[all,avg15]",
    # "system.cpu.load[all,avg5]"
    
)

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
    id      = 1
}

$hosts = (Invoke-RestMethod -Uri $ZbxURL -Method POST -Headers $headers -Body ($hostsReq | ConvertTo-Json)).result

# =========== Helpers

function SafeMB($val) {
    if ($null -eq $val -or $val -eq "") { return $null }
    return [math]::Round(([double]$val / 1MB), 2)
}

function SafeGB($val) {
    if ($null -eq $val -or $val -eq "") {
        return $null
    }
    return [math]::Round(([double]$val / 1GB), 2)
}


function GetVal($key) {
    $item = $items | Where-Object { $_.key_ -eq $key }
    if ($item -and $item.lastvalue -ne "") { return $item.lastvalue }
    return $null
}

$result = @()

foreach ($h in $hosts) {

    Write-Host "👉 $($h.host)" -ForegroundColor Yellow

    $itemsReq = @{
        jsonrpc = "2.0"
        method  = "item.get"
        params  = @{
            output  = @("key_", "lastvalue")
            hostids = $h.hostid
            filter  = @{ key_ = $keys }
        }
        id      = 2
    }

    $items = (Invoke-RestMethod -Uri $ZbxURL -Method POST -Headers $headers -Body ($itemsReq | ConvertTo-Json -Depth 4)).result


    #################################################

    $ip = ($h.interfaces | ForEach-Object { $_.ip } | Where-Object { $_ } | Sort-Object -Unique) -join ","
    $templates = ($h.parentTemplates | ForEach-Object { $_.name } | Sort-Object) -join ", "

    $cpuCores = GetVal "system.cpu.num"
    if (-not $cpuCores) { $cpuCores = GetVal 'wmi.get[root/cimv2,"Select NumberOfLogicalProcessors from Win32_ComputerSystem"]' }
    $cpuUtil = GetVal "system.cpu.util"
    $ramTot = SafeMB (GetVal "vm.memory.size[total]")
       
    $ramUsed = SafeMB (GetVal "vm.memory.size[used]")
    if (-not $ramUsed) { $ramUsed = SafeMB ( (GetVal "vm.memory.size[total]") - (GetVal "vm.memory.size[available]")) }

    $ramPct = GetVal "vm.memory.util"
    if (-not $ramPct) { $ramPct = GetVal "vm.memory.utilization" }
    

    $swapTot = SafeMB (GetVal "system.swap.size[,total]")


    $swapFree = SafeMB (GetVal "system.swap.free")
    if (-not $swapFree) { $swapFree = SafeMB (GetVal "system.swap.size[,free]") }
    
    $swapPct = ( GetVal "system.swap.pfree" )
    if (-not $swapPct) { $swapPct = (GetVal "system.swap.size[,pfree]") }


    $uptimeSec = GetVal "system.uptime"
    $uptime = if ($uptimeSec) { [math]::Round($uptimeSec / 86400, 2) } 



    $proc_num = GetVal "proc.num"
    if (-not $proc_num) { $proc_num = GetVal "proc.num[]" }


    $totalspace = SafeGB (GetVal "vfs.fs.dependent.size[/,total]")
    $usedspace = SafeGB (GetVal "vfs.fs.dependent.size[/,used]")
    $pusedspace = GetVal "vfs.fs.dependent.size[/,pused]"

    $writerate = GetVal "vfs.dev.write.rate[sda]"
    $readrate = GetVal "vfs.dev.read.rate[sda]"
    $util = GetVal "vfs.dev.util[sda]"

    if ($templates -match "windows") {
        $totalspace = SafeGB (GetVal "vfs.fs.dependent.size[C:,total]")
        $usedspace = SafeGB (GetVal "vfs.fs.dependent.size[C:,used]")
        $pusedspace = GetVal "vfs.fs.dependent.size[C:,pused]"

        $writerate = GetVal 'perf_counter_en["\PhysicalDisk(0 C:)\Disk Reads/sec",60]'
        $readrate = GetVal 'perf_counter_en["\PhysicalDisk(0 C:)\Disk Writes/sec",60]'
        $util = GetVal 'perf_counter_en["\PhysicalDisk(0 C:)\% Idle Time",60]'
    } 


    $row = [ordered]@{
        HostID         = $h.hostid
        Host           = $h.host
        IP             = $ip
        Templates      = $templates
        CPU_Cores      = $cpuCores
        "%_CPU_Util"   = if ($cpuUtil) { [math]::Round([double]$cpuUtil, 2) }
        Processes      = $proc_num
        RAM_Total_MB   = $ramTot
        RAM_Used_MB    = $ramUsed
        "%_RAM_Util"   = if ($ramPct) { [math]::Round([double]$ramPct, 2) }
        
        Swap_Total_MB  = $swapTot
        Swap_Free_MB   = $swapFree
        "%_Swap_Free"  = if ($swapPct) { [math]::Round([double]$swapPct, 2) }

        Uptime_Days    = $uptime

        Disk_total     = $totalspace
        Disk_used      = $usedspace
        "%_Disk_used"  = if ($pusedspace) { [math]::Round([double]$pusedspace, 2) }

        Disk_IO_Writes = if ($writerate) { [math]::Round([double]$writerate, 2) }
        Disk_IO_Reads  = if ($readrate) { [math]::Round([double]$readrate, 2) }
        "%_Disk_Util"  = if ($util) { [math]::Round([double]$util, 2) }


    }

    $result += [pscustomobject]$row
}

$outFile = "zbx_lastvalues.csv"

$result | Sort-Object Host | Export-Csv $outFile -NoTypeInformation -Encoding UTF8 -Delimiter ";"

Write-Host "✅ ready: $outFile" -ForegroundColor Green
