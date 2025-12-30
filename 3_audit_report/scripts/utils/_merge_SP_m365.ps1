# ==========================================================
# Merge Exchange M365 Groups info into SP_Sites_WithCounts.csv
# For GROUP#0 sites only
# Converts ManagedBy list → AdminsCount (count of users)
# ==========================================================

# Загружаем файлы
$sites = Import-Csv "SP_Sites_WithCounts.csv" -Delimiter ";"
$m365  = Import-Csv "Exchange_m365Groups.csv" -Delimiter ";"

#  Проверим наличие нужных колонок
if (-not ($m365 | Get-Member -Name "MembersCount") -or -not ($m365 | Get-Member -Name "ManagedBy")) {
    Write-Warning "❌ В Exchange_m365Groups.csv нет колонок MembersCount или ManagedBy"
    return
}

# Обновляем только сайты с шаблоном GROUP#0
foreach ($s in $sites) {
    if ($s.Template -eq "GROUP#0") {
        # Ищем совпадение по URL (SharePointSiteUrl / SiteUrl)
        $match = $m365 | Where-Object { $_.SharePointSiteUrl -eq $s.Url -or $_.SiteUrl -eq $s.Url } | Select-Object -First 1

        if ($match) {
            # --- считаем количество администраторов ---
            $adminsRaw = ($match.ManagedBy -as [string]).Trim()
            if ($adminsRaw -and $adminsRaw -ne "") {
                # разбиваем по запятым и считаем уникальные e-mail адреса
                $adminsCount = ($adminsRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Select-Object -Unique).Count
            } else {
                $adminsCount = 0
            }

            # --- получаем MembersCount (число участников из Exchange) ---
            $membersCount = if ($match.MembersCount -match '^\d+$') {
                [int]$match.MembersCount
            } else {
                # если MembersCount пустое или текст — 0
                0
            }

            # --- записываем в сайт ---
            $s.AdminsCount  = $adminsCount
            $s.MembersCount = $membersCount

            Write-Host "$($s.Url) → Admins: $adminsCount | Members: $membersCount" -ForegroundColor Cyan
        }
        else {
            # нет совпадения
            $s.AdminsCount  = 0
            $s.MembersCount = 0
            Write-Host "$($s.Url) → no match in M365 file" -ForegroundColor DarkGray
        }
    }
    else {
        # Остальные сайты не трогаем
        $s.AdminsCount  = $s.AdminsCount
        $s.MembersCount = $s.MembersCount
    }
}

# Сохраняем результат
$sites | Export-Csv "SP_Sites_WithCounts_Final.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation

Write-Host "Done: SP_Sites_WithCounts_Final.csv (GROUP#0 updated from M365 data)" -ForegroundColor Green