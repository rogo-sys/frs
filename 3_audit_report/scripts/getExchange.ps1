try {
    if (-not (Get-ConnectionInformation)) {
        Connect-ExchangeOnline
    }
} catch {
    Connect-ExchangeOnline
}


function Get-AliasAddresses {
    param($obj)
    if (-not $obj.EmailAddresses) { return "" }
    $aliases = @(
        $obj.EmailAddresses |
        ForEach-Object { $_.ToString() } |
        Where-Object { $_ -clike 'smtp:*' } |
        ForEach-Object { $_ -replace '^smtp:', '' }
    )
    return ($aliases -join ", ")
}

# 1. Distribution Groups
Write-Host "Exporting Distribution Groups..."
$distGroups = Get-DistributionGroup -ResultSize Unlimited
$distResults = foreach ($g in $distGroups) {
    $members = @()
    try { $members = @(Get-DistributionGroupMember -Identity $g.Identity -ErrorAction Stop) } catch {}

    $memberAddrs = foreach ($m in $members) {
        if ($null -ne $m) {
            $addr = $m.PrimarySmtpAddress
            if (-not $addr) { $addr = $m.ExternalEmailAddress }
            if (-not $addr) { $addr = $m.WindowsLiveID }
            if (-not $addr) { $addr = $m.Mail }
            if ($addr) { $addr.ToString() }
        }
    }

    $memberTypes = @($members | Where-Object { $_ } | Select-Object -ExpandProperty RecipientType -ErrorAction SilentlyContinue | Sort-Object -Unique)
    $memberAddrs = $memberAddrs | Where-Object { $_ } | Sort-Object -Unique
    $count = @($memberAddrs).Count

    [PSCustomObject]@{
        DisplayName        = $g.DisplayName
        Alias              = $g.Alias
        PrimarySMTPAddress = $g.PrimarySmtpAddress
        'PrimarySMTPkasutus'             = ' '
        ProxyAddresses     = (Get-AliasAddresses $g)
        'ProxyKasutus' = ' '
        IsDirSynced        = $g.IsDirSynced
        ManagedBy          = ($g.ManagedBy -join ", ")
        Members            = ($memberAddrs -join ", ")
        MembersCount       = $count
        MemberType         = ($memberTypes -join ", ")
        WhenCreated        = $g.WhenCreated
    }
}
$distResults | Export-Csv "Exchange_DistributionGroups.csv" -Delimiter ";" -NoTypeInformation -Encoding UTF8
Write-Host "Distribution Groups: $(@($distResults).Count)"

# 2. Microsoft 365 Groups
Write-Host "Exporting M365 Groups..."
$m365Groups = Get-UnifiedGroup -ResultSize Unlimited
$m365Results = foreach ($g in $m365Groups) {
    $members = @()
    $owners  = @()
    try { $members = @(Get-UnifiedGroupLinks -Identity $g.Identity -LinkType Members -ErrorAction Stop) } catch {}
    try { $owners  = @(Get-UnifiedGroupLinks -Identity $g.Identity -LinkType Owners  -ErrorAction Stop) } catch {}

    $memberAddrs = foreach ($m in $members) {
        if ($null -ne $m) {
            $addr = $m.PrimarySmtpAddress
            if (-not $addr) { $addr = $m.Mail }
            if ($addr) { $addr.ToString() }
        }
    }
    $ownerAddrs = foreach ($o in $owners) {
        if ($null -ne $o) {
            $addr = $o.PrimarySmtpAddress
            if (-not $addr) { $addr = $o.Mail }
            if ($addr) { $addr.ToString() }
        }
    }

    $memberTypes = @($members | Where-Object { $_ } | Select-Object -ExpandProperty RecipientType -ErrorAction SilentlyContinue | Sort-Object -Unique)
    $memberAddrs = $memberAddrs | Where-Object { $_ } | Sort-Object -Unique
    $ownerAddrs = $ownerAddrs | Where-Object { $_ } | Sort-Object -Unique
    $count = @($memberAddrs).Count

    [PSCustomObject]@{
        DisplayName        = $g.DisplayName
        Alias              = $g.Alias
        PrimarySmtpAddress = $g.PrimarySmtpAddress
        'PrimarySMTPkasutus'              = ' '     
        ProxyAddresses     = (Get-AliasAddresses $g)
        'ProxyKasutus' = ' '
        AccessType         = $g.AccessType
        ManagedBy          = ($ownerAddrs -join ", ")
        Members            = ($memberAddrs -join ", ")
        MembersCount       = $count
        MemberType         = ($memberTypes -join ", ")
        WhenCreated        = $g.WhenCreated
        SharePointSiteUrl = if ($g.SharePointSiteUrl) { $g.SharePointSiteUrl } else { " " }
        GroupGuid = $g.Guid
        ExternalDirectoryObjectId = $g.ExternalDirectoryObjectId
 
    }
}
$m365Results | Export-Csv "Exchange_M365Groups.csv" -Delimiter ";" -NoTypeInformation -Encoding UTF8
Write-Host "M365 Groups: $(@($m365Results).Count)"

# 3. Dynamic Distribution Groups
Write-Host "Exporting Dynamic Groups..."
$dynGroups = Get-DynamicDistributionGroup -ResultSize Unlimited
$dynResults = foreach ($g in $dynGroups) {
    [PSCustomObject]@{
        DisplayName        = $g.DisplayName
        Alias              = $g.Alias
        PrimarySmtpAddress = $g.PrimarySmtpAddress
        'PrimarySMTPkasutus' =             ' '
        ProxyAddresses     = (Get-AliasAddresses $g)
        'ProxyKasutus' = ' '
        RecipientFilter    = $g.RecipientFilter
        ManagedBy          = ($g.ManagedBy -join ", ")
        WhenCreated        = $g.WhenCreated
    }
}
$dynResults | Export-Csv "Exchange_DynamicGroups.csv" -Delimiter ";" -NoTypeInformation -Encoding UTF8
Write-Host "Dynamic Groups: $(@($dynResults).Count)"

# 4. Mailboxes (excluding Shared Mailboxes)
Write-Host "Exporting Mailboxes (excluding Shared)..."

$mailboxes = Get-Mailbox -ResultSize Unlimited |
    Where-Object { $_.RecipientTypeDetails -ne "SharedMailbox" } |
    Select-Object `
        DisplayName,
        PrimarySmtpAddress,
        @{Name="PrimarySMTPkasutus"; Expression={" "}},
        @{Name="ProxyAddresses"; Expression={
            ($_.EmailAddresses |
                ForEach-Object { $_.ToString() } |
                Where-Object { $_ -clike 'smtp:*' } |
                ForEach-Object { $_ -replace '^smtp:', '' }
            ) -join ' & '
        }},
         @{Name="ProxyKasutus"; Expression={" "}},
        RecipientTypeDetails,
        WhenCreated

$mailboxes | Export-Csv "Exchange_Mailboxes.csv" -Delimiter ";" -NoTypeInformation -Encoding UTF8
Write-Host "Mailboxes (excluding Shared): $(@($mailboxes).Count)"

