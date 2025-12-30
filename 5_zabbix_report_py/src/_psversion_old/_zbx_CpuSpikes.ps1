function Get-ZabbixToken {
    # Check environment variable
    if (-not $env:ZABBIX_TOKEN) {
        Write-Host "🔑 Zabbix API Token not found in the environment variable ZABBIX_TOKEN." -ForegroundColor Yellow
        $secureToken = Read-Host "Enter Zabbix API Token" -AsSecureString

        # Check if the user entered something
        if (-not $secureToken) {
            Write-Error "❌ Token input was cancelled or empty."
            exit 1
        }
        
        # Convert and save in environment variable for the current session
        $ApiToken = [System.Net.NetworkCredential]::new("", $secureToken).Password
        $env:ZABBIX_TOKEN = $ApiToken
        Write-Host "✅ Token successfully set." -ForegroundColor Green
        return $ApiToken
    }
    else {
        Write-Host "ℹ️ Using token from environment variable ZABBIX_TOKEN." -ForegroundColor Cyan
        return $env:ZABBIX_TOKEN
    }
}

# --- Connection settings ---
$ZbxURL = "https://zabbix.forus.ee/api_jsonrpc.php"
$ApiToken = Get-ZabbixToken

# If token was not obtained (user canceled input), script will exit inside the function,
# but we double-check just in case:
if (-not $ApiToken) { Write-Error "❌ Failed to obtain token. Exiting."; exit 1 }

$headers = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer $ApiToken"
}

# --- Analysis settings ---
$threshold      = 80        # CPU threshold (%)
$minDuration    = 60        # minimum spike duration (sec)
$sampleInterval = 60        # default interval (sec). Script will try to detect dynamically.
$periodDays     = 7        # number of days to analyze

$timeTill = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$timeFrom = $timeTill - ($periodDays * 24 * 3600)

$fromDate = [DateTimeOffset]::FromUnixTimeSeconds($timeFrom).ToLocalTime()
$tillDate = [DateTimeOffset]::FromUnixTimeSeconds($timeTill).ToLocalTime()
Write-Host "Period:" $fromDate.ToString("yyyy-MM-dd HH:mm:ss") "→" $tillDate.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Yellow

# --- Helper function for API requests with error handling ---
function Invoke-ZabbixApi {
    param(
        [Parameter(Mandatory=$true)]
        [String]$Url,
        [Parameter(Mandatory=$true)]
        [Hashtable]$Headers,
        [Parameter(Mandatory=$true)]
        [PSObject]$Body
    )
    
    $jsonBody = $Body | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method POST -Body $jsonBody -ErrorAction Stop
        if ($response.error) {
            Write-Error "❌ Zabbix API error: $($response.error.message) - $($response.error.data)"
            return $null
        }
        return $response.result
    }
    catch {
        Write-Error "❌ Error executing request to Zabbix API: $($_.Exception.Message)"
        Write-Error "Possible issue with URL or authorization token."
        return $null
    }
}

# --- Get list of hosts ---
Write-Host "`n📡 Fetching list of active hosts..."
$hostsReq = @{
    jsonrpc = "2.0"
    method  = "host.get"
    params  = @{
        output = @("hostid","host")
        filter = @{ status = "0" }   # only active
    }
    id = 1
}
$hosts = Invoke-ZabbixApi -Url $ZbxURL -Headers $headers -Body $hostsReq

if (-not $hosts) { Write-Error "❌ No hosts found or API error. Exiting."; exit 1 }

# --- Initialize arrays (will be filled via pipeline) ---
$result  = @()
$rawData = @()

# --- Main loop over hosts ---
$result = foreach ($h in $hosts) {
    Write-Host "`n👉 $($h.host)" -ForegroundColor Cyan
    
    # --- Get item system.cpu.util ---
    $itemReq = @{
        jsonrpc = "2.0"
        method  = "item.get"
        params  = @{
            hostids = $h.hostid
            filter  = @{ key_ = "system.cpu.util" }
            output  = @("itemid","name","key_")
        }
        id = 2
    }
    $item = (Invoke-ZabbixApi -Url $ZbxURL -Headers $headers -Body $itemReq) | Select-Object -First 1

    if (-not $item) {
        Write-Warning "⛔ item 'system.cpu.util' not found on $($h.host) or API error. Skipping."
        # Host is skipped without adding to $result
    [PSCustomObject]@{
        Host                           = $h.host
        HostId                         = $h.hostid
        Threshold_Percent              = $threshold
        Effective_Interval_s           = $sampleInterval
        CPU_Spikes_Count               = "-"
        CPU_Spike_Max_s                = "-"
        CPU_Spikes_Total_s             = "-"
        History_Records_Count          = "-"
        Total_Samples_Above_Threshold  = "-"
    }        
        continue
    }

    $cpuItemId = $item.itemid

    # --- Get CPU history ---
    $histReq = @{
        jsonrpc = "2.0"
        method  = "history.get"
        params  = @{
            history   = 0       # 0 for float (usually system.cpu.util)
            itemids   = $cpuItemId
            time_from = $timeFrom
            time_till = $timeTill
            output    = "extend"
            sortfield = "clock"
            sortorder = "ASC"
        }
        id = 3
    }

    $history = Invoke-ZabbixApi -Url $ZbxURL -Headers $headers -Body $histReq
    Write-Host "History count:" $history.Count -ForegroundColor White

    # --- Dynamic detection of data collection interval (CRITICAL FIX) ---
    $effectiveSampleInterval = $sampleInterval # fallback
    if ($history -and $history.Count -ge 2) {
        # Calculate difference between first two measurements
        $clock1 = [int]$history[0].clock
        $clock2 = [int]$history[1].clock
        $calculatedInterval = $clock2 - $clock1
        
        # Check that the interval is positive and differs from default
        if ($calculatedInterval -gt 0 -and $calculatedInterval -ne $sampleInterval) {
            $effectiveSampleInterval = $calculatedInterval
            Write-Host "⚠️ Detected dynamic interval: $($effectiveSampleInterval)s (instead of $($sampleInterval)s)" -ForegroundColor Yellow
        }
    }
    # Use $effectiveSampleInterval for all subsequent analysis.

    # --- 1. Save "raw" data (efficiently) ---
    # Collect data into a local variable to avoid += in loop
    $hostRawData = foreach ($rec in $history) {
        [PSCustomObject]@{
            Host              = $h.host
            HostId            = $h.hostid
            Effective_Interval_s = $effectiveSampleInterval # <-- Added to raw data
            Clock             = [DateTimeOffset]::FromUnixTimeSeconds([int]$rec.clock).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
            Value             = [double]$rec.value
            Threshold_Percent = $threshold
        }
    }
    # Add to global $rawData
    $rawData += $hostRawData


    if (-not $history -or $history.Count -eq 0) {
        # Return empty result for host (item exists but no data for period)
        [PSCustomObject]@{
            Host                           = $h.host
            HostId                         = $h.hostid
            Threshold_Percent              = $threshold
            Effective_Interval_s           = $effectiveSampleInterval
            CPU_Spikes_Count               = "no data"
            CPU_Spike_Max_s                = "no data"
            CPU_Spikes_Total_s             = "no data"
            History_Records_Count          = "0"
            Total_Samples_Above_Threshold  = ""
        }
        continue
    }

    # --- 2. Spike analysis ---
    $allSpikes = @()         # All spikes with duration >= $minDuration
    $countableSpikes = @()   # Spikes with duration >= $minDuration and >= 2 samples
    $currentSpikeCount = 0   # Number of consecutive samples above threshold
    $totalSamplesAboveThreshold = 0 # Total number of samples above threshold

    foreach ($rec in $history) {
        $value = [double]$rec.value
        
        if ($value -ge $threshold) {
            $currentSpikeCount++
            $totalSamplesAboveThreshold++ # <-- Increment: each value >= threshold
        } else {
            # Spike ended, check minimum duration
            $spikeDuration = $currentSpikeCount * $effectiveSampleInterval
            
            if ($spikeDuration -ge $minDuration) {
                # Save spike duration
                $allSpikes += $spikeDuration
                
                # Check if spike consists of 2+ samples
                if ($currentSpikeCount -ge 2) {
                    $countableSpikes += $spikeDuration
                }
            }
            $currentSpikeCount = 0
        }
    }
    # Check last spike if not closed by 'else'
    $spikeDuration = $currentSpikeCount * $effectiveSampleInterval
    if ($spikeDuration -ge $minDuration) {
        $allSpikes += $spikeDuration
        if ($currentSpikeCount -ge 2) { 
            $countableSpikes += $spikeDuration
        }
    }

    # --- 3. Aggregate results for current host ---
    # Check if at least one "series" (2+ samples matching minDuration)
    if ($countableSpikes.Count -gt 0) {
        
        # Use $countableSpikes for count (only 2+ sample spikes)
        $count  = $countableSpikes.Count
        
        # Use $countableSpikes for Max
        $maxDur = ($countableSpikes | Measure-Object -Maximum).Maximum
        
        # Use $countableSpikes for Sum
        $sumDur = ($countableSpikes | Measure-Object -Sum).Sum 
    } else {
        $count = 0; $maxDur = 0; $sumDur = 0
    }

    # Return object to pipeline
    [PSCustomObject]@{
        Host                           = $h.host
        HostId                         = $h.hostid
        Threshold_Percent              = $threshold
        Effective_Interval_s           = $effectiveSampleInterval
        CPU_Spikes_Count               = $count                   
        CPU_Spike_Max_s                = $maxDur                  
        CPU_Spikes_Total_s             = $sumDur                  
        History_Records_Count          = $history.Count
        Total_Samples_Above_Threshold  = $totalSamplesAboveThreshold
    }
}

# --- Export to CSV ---
$outSummary = "zbx_cpu_spikes_${periodDays}d.csv" # Renamed for clarity
$outRaw     = "zbx_cpu_spikes_raw_${periodDays}d.csv"

# Use "Cultures" to ensure correct CSV format
$result  | Export-Csv -Path $outSummary -Delimiter ";" -Encoding UTF8 -NoTypeInformation -Force
#$rawData | Export-Csv -Path $outRaw     -Delimiter ";" -Encoding UTF8 -NoTypeInformation -Force

Write-Host "`n✅ Done! Results exported to:`n- $outSummary`n- $outRaw" -ForegroundColor Green
