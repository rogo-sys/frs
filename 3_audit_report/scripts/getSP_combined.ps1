# ==========================================================
# SharePoint Online - Сводный отчёт по сайтам + активности
# ==========================================================

$tempUsageFile = "raw_sp_usage.csv"
$finalFile = "SP_Sites.csv"

# --- 1. Получаем usage данные через Microsoft Graph ---
Connect-MgGraph -Scopes "Reports.Read.All"

Get-MgReportSharePointSiteUsageDetail -Period D30 -OutFile $tempUsageFile

$usage = Import-Csv $tempUsageFile -Delimiter "," -Encoding UTF8 | ForEach-Object {
    [PSCustomObject]@{
        SiteId                = $_.'Site Id'
        SiteUrl               = $_.'Site URL'
        IsDeleted             = $_.'Is Deleted'
        LastActivityDate      = $_.'Last Activity Date'
        FileCount             = $_.'File Count'
        ActiveFileCount       = $_.'Active File Count'
        PageViewCount         = $_.'Page View Count'
        VisitedPageCount      = $_.'Visited Page Count'
        RootWebTemplate       = $_.'Root Web Template'
        OwnerPrincipalName    = $_.'Owner Principal Name'
    }
}

#Remove-Item $tempUsageFile -Force

# --- 2. Получаем список сайтов через SharePoint Online ---
Connect-SPOService -Url "https://ussee-admin.sharepoint.com"

$sites = Get-SPOSite -Limit All -IncludePersonalSite $false

# --- 3. Объединяем данные ---

$results = foreach ($s in $sites) {
    $guid = $s.SiteId.ToString().ToLower()
    $match = $usage | Where-Object { ($_.SiteId).ToLower() -eq $guid }

    if (-not $match) {
        Write-Warning "Не найдено совпадение для GUID: $($s.SiteId) ($($s.Url))"
    }

    [PSCustomObject]@{
        Title                   = $s.Title
        Url                     = $s.Url
        GUID                    = $s.SiteId
        Owner                   = $s.Owner
        OwnerKasutusMail        = " "
        AdminsCount             = " "
        MembersCount            = " "
        LastContentModifiedDate = $s.LastContentModifiedDate
        Template                = $s.Template
        StorageGB               = [math]::Round($s.StorageUsageCurrent / 1024, 2)
        SharingCapability       = $s.SharingCapability
        LockState               = $s.LockState
        IsTeamsConnected        = $s.IsTeamsConnected
        IsTeamsChannelConnected = $s.IsTeamsChannelConnected
        TeamsChannelType        = $s.TeamsChannelType
        GroupId                 = $s.GroupId
        IsHubSite               = $s.IsHubSite

        # --- добавленные поля из usage ---
        IsDeleted               = $match.IsDeleted
        LastActivityDate        = $match.LastActivityDate
        FileCount               = $match.FileCount
        ActiveFileCount         = $match.ActiveFileCount
        PageViewCount           = $match.PageViewCount
        VisitedPageCount        = $match.VisitedPageCount
        RootWebTemplate         = $match.RootWebTemplate
        OwnerPrincipalName   =      $match.OwnerPrincipalName
    }
}

$existingGuids = $results.GUID | ForEach-Object { $_.ToString().ToLower() }

# Добавляем сайты, которых нет в SPO
$missingUsageSites = $usage | Where-Object {
    ($_.SiteId) -and (-not ($existingGuids -contains ($_.SiteId.ToLower())))
}

foreach ($u in $missingUsageSites) {
    $results += [PSCustomObject]@{
        Title                   = "!!!!_not in SP - only in Activity log!!!"
        Url                     = $u.SiteUrl
        GUID                    = $u.SiteId
        Owner                   = ""
        OwnerKasutusMail        = ""
        AdminsCount             = " "
        MembersCount            = " "        
        LastContentModifiedDate = ""
        Template                = ""
        StorageGB               = ""
        SharingCapability       = ""
        LockState               = ""
        IsTeamsConnected        = ""
        IsTeamsChannelConnected = ""
        TeamsChannelType        = ""
        GroupId                 = ""
        IsHubSite               = ""

        # usage поля
        IsDeleted            = $u.IsDeleted
        LastActivityDate     = $u.LastActivityDate
        FileCount            = $u.FileCount
        ActiveFileCount      = $u.ActiveFileCount
        PageViewCount        = $u.PageViewCount
        VisitedPageCount     = $u.VisitedPageCount
        RootWebTemplate      = $u.RootWebTemplate
        OwnerPrincipalName   = $match.OwnerPrincipalName
    }
}

# --- 4. Экспортируем итог ---
$results | Export-Csv -Path $finalFile -NoTypeInformation -Encoding UTF8 -Delimiter ";"

