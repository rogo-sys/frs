if (-not $env:ZABBIX_TOKEN) {
    $secureToken = Read-Host "Enter the Zabbix token" -AsSecureString
    $ApiToken = [System.Net.NetworkCredential]::new("", $secureToken).Password
    $env:ZABBIX_TOKEN = $ApiToken
    Write-Host "Token set for this session"
} else {
    Write-Host "Token already set"
}