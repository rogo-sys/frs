# --- Начало ---
# ad , groups, users ; dg , dyn, m365, mailbox, shared, shp


# $usersFile = "AD_Groups.csv"
# $usersFile = "AD_Users.csv"
# $usersFile = "Exchange_DistributionGroups.csv"
# $usersFile = "Exchange_DynamicGroups.csv"
# $usersFile = "Exchange_M365Groups.csv"
# $usersFile = "Exchange_Mailboxes.csv"
$usersFile = "Exchange_SharedMailboxes.csv"

$mailsFile = "_mails.csv"
$outFile   = "$usersfile"

# Загружаем mails.csv
$mails = Import-Csv -Path $mailsFile -Delimiter ';' -Encoding UTF8

# Хэштаблица mail -> kasutus
$mailMap = @{}
foreach ($m in $mails) {
    $mail = ($m.mail -as [string]).Trim().Trim('"')
    if ($mail) {
        $mailMap[$mail.ToLower()] = ($m.kasutus -as [string]).Trim().Trim('"')
    }
}

# Загружаем users.csv
$users = Import-Csv -Path $usersFile -Delimiter ';' -Encoding UTF8

foreach ($u in $users) {
    $proxyField = ($u.ProxyAddresses -as [string]).Trim().Trim('"')
    $foundKasutus = $null
    $foundAnyMatch = $false

    if ($proxyField -and $proxyField -ne " ") {
        # Разделяем по & , ; и пробелам
        $proxies = $proxyField -split '\s*&\s*|,|;' |
            ForEach-Object { ($_ -as [string]).Trim().Trim('"') } |
            Where-Object { $_ -ne "" }

        foreach ($addr in $proxies) {
            $key = $addr.ToLower()
            if ($mailMap.ContainsKey($key)) {
                $foundAnyMatch = $true
                $val = $mailMap[$key]

                # Если в mails.csv пусто — пропускаем, не ставим ничего
                if (-not $val) { continue }

                # Если явно "not active" — тоже пропускаем
                if ($val.ToLower() -eq "not active") { continue }

                # Если ошибка — пропускаем
                if ($val.ToLower() -eq "error") { continue }

                # Если нашли дату — сохраняем и прекращаем цикл
                #$foundKasutus = $val убрал пока, будем просто acitve писать а не дату ставить
                $foundKasutus = "active"
                break
            }
        }
    }

    if ($foundKasutus) {
        $u.ProxyKasutus = $foundKasutus
    }
    elseif (-not $foundAnyMatch) {
        # если вообще ни один proxy не встретился в mails.csv — оставляем пустым
        $u.ProxyKasutus = ""
    }
    else {
        # если совпадения были, но все "not active" или пустые — пишем no activity
        $u.ProxyKasutus = "no activity"
    }
}

# Сохраняем результат
$users | Export-Csv -Path $outFile -Delimiter ';' -NoTypeInformation -Encoding UTF8

#Write-Host "Готово. Результат записан в $outFile (оригинал сохранён как $usersFile.bak)."
# --- Конец ---
