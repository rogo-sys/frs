# Укажи имена файлов и итоговый файл
$csvFiles = @(
    "AD_Groups.csv",
    "AD_Users.csv",
    "GPO_Report.csv",
    "Exchange_DistributionGroups.csv",
    "Exchange_DynamicGroups.csv",
    "Exchange_M365Groups.csv",
    "Exchange_Mailboxes.csv",
    "Exchange_SharedMailboxes.csv",
    "SHP_Sites_Combined_.csv",
    "SHP_SitesPersonal.csv",
    "mails.csv"
)

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$outFile = "_FullView_$timestamp.xlsx"

# Загружаем модуль для работы с Excel
Import-Module ImportExcel -ErrorAction Stop

# Удалим старый файл, если есть
#if (Test-Path $outFile) { Remove-Item $outFile }

# Для каждого CSV создаем отдельный лист
foreach ($csv in $csvFiles) {
    $sheetName = [System.IO.Path]::GetFileNameWithoutExtension($csv)
    Import-Csv $csv -Delimiter ";" | Export-Excel `
                                    -Path $outFile `
                                    -WorksheetName $sheetName `
                                    -TableName $sheetName `
                                    -TableStyle "Medium2" `
                                    -Append
                                                    
}

Write-Host "ready $outFile"

# $excel = Open-ExcelPackage -Path $outFile
# $ws = $excel.Workbook.Worksheets["SP_Sites_Combined"]
# $ws.Cells["B2"].AddComment("test", "System")
# $ws.Cells["C2"].Formula = "azaza"
# $ws.Cells["Y1"].Value = "Updated Header"

# Close-ExcelPackage $excel