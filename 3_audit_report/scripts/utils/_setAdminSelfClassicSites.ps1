# $sites = @(
#     "https://ussee.sharepoint.com/sites/AuditAdminsTempClassic",
#     "https://ussee.sharepoint.com/sites/EE_Tehno",
#     "https://ussee.sharepoint.com/sites/EE-IT",
#     "https://ussee.sharepoint.com/sites/LV_SOC",
#     "https://ussee.sharepoint.com/sites/EE-Personal",
#     "https://ussee.sharepoint.com/sites/EE_Kinnisvarahaldus",
#     "https://ussee.sharepoint.com/sites/EE_Heakord",
#     "https://ussee.sharepoint.com/sites/ForusHaldusOU",
#     "https://ussee.sharepoint.com/sites/EE-Finants"
# )



 # Получение всех сайтов
$allSites = Get-SPOSite -Limit All
# Фильтрация по шаблонам SITEPAGEPUBLISHING#0 и STS#3
$filteredSites = $allSites | Where-Object {
    $_.Template -eq "SITEPAGEPUBLISHING#0" -or $_.Template -eq "STS#3"
}
# Вывод результатов
$filteredSites | Select-Object Url, Template, Owner | Format-Table -AutoSize   

$results = @()

# Добавляем себя в SiteAdmins везде
# foreach ($s in $filteredSites)
#     {
#     Set-SPOUser -Site $s.Url -LoginName rogo.o-adm@ussee.onmicrosoft.com -IsSiteCollectionAdmin $true
#     }


# members, owners,
# omanikud, liikmed
# külastajad visitors
# redigeerijad administraatorid
# issiteadmin

foreach ($s in $filteredSites) {
    Write-Host "current: $s" -ForegroundColor Cyan

    try {
        $users = Get-SPOUser -Site $s.Url  #|
            #Where-Object { $_.Groups -match "Owners" -or $_.Groups -match "Members" -or $_.Groups -match "liikmed"}

        foreach ($u in $users) {
            $results += [PSCustomObject]@{
                SiteUrl    = $s.Url
                DisplayName = $u.DisplayName
                LoginName   = $u.LoginName
                isSiteAdmin = $u.IsSiteAdmin
                isGroup =     $u.IsGroup
                Groups      = ($u.Groups -join ", ")
            }
        }
    }
    catch {
        Write-Warning "error $s : $_"
        $results += [PSCustomObject]@{
            SiteUrl     = $s.Url
            DisplayName = "Error"
            LoginName   = "-"
            Groups      = "-"
        }
    }
}

$outfile = "SP_SiteUsers_allFull.csv"

$results | Export-Csv $outfile -Delimiter ";" -Encoding UTF8 -NoTypeInformation

Write-Host "`n ready in $outfile" -ForegroundColor Green