# ==========================================================
# SharePoint site audit enrichment: MembersCount + AdminsCount
# ----------------------------------------------------------
# Input files:
#   SP_Sites.csv                 ← основной отчёт по сайтам
#   SP_SiteUsers_Filtered.csv    ← пользователи
#   SP_SiteAdmins_Filtered.csv   ← админы/владельцы
# Output file:
#   SP_Sites_WithCounts.csv
# ==========================================================

# === 1️⃣ Загружаем CSV с пользователями ===
$users = Import-Csv "SP_SiteUsers_Filtered.csv" -Delimiter ";"

# Убираем строки-заглушки
$realUsers = $users | Where-Object {
    $_.DisplayName -ne "-" -and $_.LoginName -ne "-"
}

# Группируем по сайту
$userCounts = $realUsers | Group-Object SiteUrl | ForEach-Object {
    [PSCustomObject]@{
        SiteUrl      = $_.Name
        MembersCount = $_.Count
    }
}

# === 2️⃣ Загружаем CSV с администраторами ===
$admins = Import-Csv "SP_SiteAdmins_Filtered.csv" -Delimiter ";"

# Убираем строки-заглушки
$realAdmins = $admins | Where-Object {
    $_.DisplayName -ne "-" -and $_.LoginName -ne "-"
}

# Группируем по сайту
$adminCounts = $realAdmins | Group-Object SiteUrl | ForEach-Object {
    [PSCustomObject]@{
        SiteUrl     = $_.Name
        AdminsCount = $_.Count
    }
}

# === 3️⃣ Загружаем основной CSV (по сайтам) ===
$sites = Import-Csv "SP_Sites.csv" -Delimiter ";"

# === 4️⃣ Обновляем оба поля (MembersCount и AdminsCount) ===
foreach ($s in $sites) {
    if ($s.Template -in @("SITEPAGEPUBLISHING#0", "STS#3")) {

        # MembersCount
        $m = $userCounts | Where-Object { $_.SiteUrl -eq $s.Url } | Select-Object -First 1
        $s.MembersCount = if ($m) { [int]$m.MembersCount } else { 0 }

        # AdminsCount
        $a = $adminCounts | Where-Object { $_.SiteUrl -eq $s.Url } | Select-Object -First 1
        $s.AdminsCount = if ($a) { [int]$a.AdminsCount } else { 0 }

        Write-Host "$($s.Url) → Members: $($s.MembersCount), Admins: $($s.AdminsCount)" -ForegroundColor Cyan
    }
    else {
        Write-Host "$($s.Url) → skipped ($($s.Template))" -ForegroundColor DarkGray
    }
}

# === 5️⃣ Сохраняем итоговый отчёт ===
$sites | Export-Csv "SP_Sites_WithCounts.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation
