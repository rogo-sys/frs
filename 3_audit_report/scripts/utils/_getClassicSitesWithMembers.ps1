# Connect-SPOService -Url "https://ussee-admin.sharepoint.com"


## получаем только мемберов с классических сайтов

# === Получаем сайты ===
$allSites = Get-SPOSite -Limit All -IncludePersonalSite $false
$filteredSites = $allSites | Where-Object {
    $_.Template -in @("SITEPAGEPUBLISHING#0", "STS#0", "STS#3")
}
Write-Host "Найдено сайтов: $(@($filteredSites).Count)" -ForegroundColor Cyan

# === Основная логика ===
$results = @()

foreach ($s in $filteredSites) {
    Write-Host "site: $($s.Url)" -ForegroundColor Green

    try {
        $users = Get-SPOUser -Site $s.Url -Limit All -ErrorAction Stop

        # 🔹 фильтруем активных пользователей и группы
        # $activeUsers = $users | Where-Object {
        #     $_.IsSiteAdmin -eq $true -or 
        #     ($_.Groups -match 'administraatorid|redigeerijad|omanikud|owners')
        # }

        $activeUsers = $users | Where-Object {
            ($_.Groups -match 'külastajad|visitors|members|liikmed')
        }        

        # 🔹 (дополнительно фильтруем системных пользователей)
        $cleaned = $activeUsers | Where-Object {
            ($_.LoginName -notlike "*app@sharepoint*") -and
            ($_.LoginName -notlike "SHAREPOINT\system") -and
            ($_.LoginName -notlike "nt service*") -and
            ($_.LoginName -notlike "*spo-grid-all-users*") -and
            ($_.LoginName -notlike "*Everyone*") -and
            ($_.LoginName -notlike "*All Users*")
        }

        foreach ($u in $cleaned) {
            $results += [PSCustomObject]@{
                SiteUrl     = $s.Url
                Template    = $s.Template
                Owner       = $s.Owner
                DisplayName = $u.DisplayName
                LoginName   = $u.LoginName
                IsSiteAdmin = $u.IsSiteAdmin
                IsGroup     = $u.IsGroup
                Groups      = ($u.Groups -join ", ")
            }
        }

        if (-not $cleaned) {
            $results += [PSCustomObject]@{
                SiteUrl     = $s.Url
                Template    = $s.Template
                Owner       = $s.Owner
                DisplayName = "-"
                LoginName   = "-"
                IsSiteAdmin = "-"
                IsGroup     = "-"
                Groups      = "-"
            }
        }

    } catch {
        Write-Warning "Ошибка при $($s.Url): $_"
        $results += [PSCustomObject]@{
            SiteUrl     = $s.Url
            Template    = $s.Template
            Owner       = $s.Owner
            DisplayName = "Error"
            LoginName   = "-"
            IsSiteAdmin = "-"
            IsGroup     = "-"
            Groups      = "-"
        }
    }
}

# === Экспорт ===
$outfile = "SP_SiteUsers_Filtered.csv"

$results | Export-Csv $outfile -Delimiter ";" -Encoding UTF8 -NoTypeInformation
Write-Host "`n ready: $outfile" -ForegroundColor Cyan
