#Connect-SPOService -Url "https://ussee-admin.sharepoint.com"

$sites = Get-SPOSite -Limit All -IncludePersonalSite $true

$personalSites = $sites | Where-Object {
    $_.Template -eq "SPSPERS*" -or $_.Url -like "*-my.sharepoint.com*"
}

$results = foreach ($s in $personalSites) {

    [PSCustomObject]@{
        Title                   = $s.Title
        Url                     = $s.Url
        GUID                    = $s.SiteId
        Owner                   = $s.Owner
        OwnerKasutusMail        = " "
        LastActivityDate        = $s.LastContentModifiedDate
        Template                = $s.Template
        StorageGB               = [math]::Round($s.StorageUsageCurrent / 1024, 2)
        SharingCapability       = $s.SharingCapability
        LockState               = $s.LockState
        IsTeamsConnected        = $s.IsTeamsConnected
        IsTeamsChannelConnected = $s.IsTeamsChannelConnected
        TeamsChannelType        = $s.TeamsChannelType
        GroupId                 = $s.GroupId
        IsHubSite               = $s.IsHubSite

    }
}

$results | Export-Csv -Path "SP_SitesPersonal.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ";"
