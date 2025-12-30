# =======================================================
# Active Directory - Groups and Users Analysis

if (-not (Get-Module -ListAvailable ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found (RSAT)."
    exit 1
}
Import-Module ActiveDirectory -ErrorAction Stop


function GetSMTPAddress {
    param($obj)
    if (-not $obj.proxyAddresses) { return "" }
    $aliases = @(
        $obj.proxyAddresses |
        ForEach-Object { $_.ToString() } |
        Where-Object { $_ -clike 'SMTP:*' } |
        ForEach-Object { $_ -replace '^SMTP:', '' }
    )
    return ($aliases -join " & ")
}

function Get-AliasAddresses {
    param($obj)
    if (-not $obj.proxyAddresses) { return "" }
    $aliases = @(
        $obj.proxyAddresses |
        ForEach-Object { $_.ToString() } |
        Where-Object { $_ -clike 'smtp:*' } |
        ForEach-Object { $_ -replace '^smtp:', '' }
    )
    return ($aliases -join " & ")
}

$startTime = Get-Date
Write-Host "`n=== Active Directory analysis started ===`n" -ForegroundColor Cyan

# Output paths
$groupsFile = "AD_Groups.csv"
$usersFile = "AD_Users.csv"

# ------------------------------
# 1. GROUPS
# ------------------------------
Write-Host "Processing groups..." -ForegroundColor Yellow

$groups = Get-ADGroup -Filter * -Properties GroupCategory, GroupScope, mail, proxyAddresses, description, member, CanonicalName

$groupsResult = foreach ($g in $groups) {
    # Members
    $members = @()
    if ($g.member) {
        try {
            $members = $g.member | ForEach-Object {
                try { (Get-ADObject $_ -ErrorAction Stop).Name } catch { $_ }
            }
        }
        catch { $members = @() }
    }

    # OU
    $ou = ''
    if ($g.DistinguishedName) {
        $ou = ($g.DistinguishedName -split ',' | Where-Object { $_ -like 'OU=*' }) -join ','
    }

    [PSCustomObject]@{
        Grupp                = $g.Name
        'Grupi skoop'        = $g.GroupScope
        emaildescription     = if ($g.mail) { $g.mail } else { " " }
        'Grupi liik'         = $g.GroupCategory 
        'PrimarySMTPAddress' = (GetSMTPAddress $g)
        'PrimarySMTPKasutus' = ' '
        'Liikmete arv'       = $members.Count
        'Liikmed'            = if ($members.Count -gt 0) { $members -join ' | ' } else { ' ' }
        OU                   = $ou
        Description          = if ($g.Description) { $g.Description } else { " " }
        'ProxyAddresses'     = (Get-AliasAddresses $g)
        'ProxyKasutus'       = ' '
        CanonicalName        = $g.CanonicalName
    }
}

$groupsResult | Export-Csv -Path $groupsFile -NoTypeInformation -Encoding UTF8 -Delimiter ";"
Write-Host "Groups report saved: $groupsFile" -ForegroundColor Green


# ------------------------------
# 2. USERS
# ------------------------------
Write-Host "`nProcessing users..." -ForegroundColor Yellow

$users = Get-ADUser -Filter * -Properties SamAccountName, LastLogonDate, mail, proxyAddresses, Description, DistinguishedName, CanonicalName, UserPrincipalName, Enabled

$usersResult = foreach ($u in $users) {
    # OU
    $ou = ''
    if ($u.DistinguishedName) {
        $ou = ($u.DistinguishedName -split ',' | Where-Object { $_ -like 'OU=*' }) -join ','
    }

    # Groups
    $groups = @()
    try {
        $groups = Get-ADPrincipalGroupMembership $u | Select-Object -ExpandProperty Name
    }
    catch { $groups = @() }

    [PSCustomObject]@{
        Name                 = $u.Name
        SamAccountName       = $u.SamAccountName
        emaildescription     = if ($u.mail) { $u.mail } else { " " }
        LastLogonDate        = if ($u.LastLogonDate) { $u.LastLogonDate } else { " " }
        'PrimarySMTPAddress' = (GetSMTPAddress $u)
        'PrimarySMTPkasutus' = ' '
        OU                   = $ou
        Description          = $u.Description
        'ProxyAddresses'     = (Get-AliasAddresses $u)
        'ProxyKasutus'       = ' '
        Grupid               = if ($groups.Count -gt 0) { $groups -join ' | ' } else { ' ' }
        'Gruppe kokku'       = $groups.Count
        UserPrincipalName    = $u.UserPrincipalName
        Enabled              = $u.Enabled
        CanonicalName        = $u.CanonicalName
    }
}

$usersResult | Export-Csv -Path $usersFile -NoTypeInformation -Encoding UTF8 -Delimiter ";"
Write-Host "Users report saved: $usersFile" -ForegroundColor Green


# ------------------------------
# 3. SUMMARY
# ------------------------------
$endTime = Get-Date
$duration = ($endTime - $startTime).ToString("hh\:mm\:ss")

Write-Host "`nAll reports completed successfully. Total time: $duration" -ForegroundColor Cyan
