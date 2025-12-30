try {
    if (-not (Get-ConnectionInformation)) {
        Connect-ExchangeOnline
    }
} catch {
    Connect-ExchangeOnline
}


$sharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited

$results = foreach ($m in $sharedMailboxes) {
    $stats = Get-MailboxStatistics -Identity $m.PrimarySmtpAddress -ErrorAction SilentlyContinue
    $permissions = Get-MailboxPermission -Identity $m.PrimarySmtpAddress -ErrorAction SilentlyContinue |
        Where-Object { $_.User -notlike "NT AUTHORITY\SELF" -and $_.AccessRights -contains "FullAccess" } |
        Select-Object -ExpandProperty User
    
    if (-not $stats) {
        $lastLogon = ""
        $sizeMB = 0
    }
    else {
        $lastLogon = $stats.LastLogonTime
        $sizeText = $stats.TotalItemSize.Value.ToString()
        $sizeMB = if ($sizeText -match '([\d\.,]+)\s*MB') { 
            [double]($matches[1] -replace ',', '.') 
        } elseif ($sizeText -match '([\d\.,]+)\s*GB') {
            [double]($matches[1] -replace ',', '.') * 1024
        } else { 0 }
    }

    # Добавляем ProxyAddresses
    $proxyAddrs = ($m.EmailAddresses |
        ForEach-Object { $_.ToString() } |
        Where-Object { $_ -clike 'smtp:*' } |
        ForEach-Object { $_ -replace '^smtp:', '' }) -join ", "

    [PSCustomObject]@{
        DisplayName        = $m.DisplayName
        Alias              = $m.Alias
        PrimarySMTPAddress = $m.PrimarySmtpAddress
        'PrimarySMTPkasutus' = ' '
        ProxyAddresses     = $proxyAddrs
        'ProxyKasutus' = ' '
        WhenCreated        = $m.WhenCreated
        LastLogonTime      = $lastLogon
        TotalSizeMB        = [math]::Round($sizeMB, 2)
        AccessGrantedTo    = ($permissions -join ", ")
        SendAs             = (Get-RecipientPermission -Identity $m.PrimarySmtpAddress -ErrorAction SilentlyContinue |
                              Where-Object { $_.AccessRights -contains "SendAs" } |
                              Select-Object -ExpandProperty Trustee -Unique) -join ", "
        SendOnBehalf       = ($m.GrantSendOnBehalfTo -join ", ")
    }
}

$results | Export-Csv "Exchange_SharedMailboxes.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation
