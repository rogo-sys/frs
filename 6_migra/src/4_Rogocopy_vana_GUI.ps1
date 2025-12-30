Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Robocopy GUI (Migration Ready)"
$form.Size = New-Object System.Drawing.Size(600, 300)
$form.StartPosition = "CenterScreen"

# -------------------------------------------
# GLOBAL: log file name
# -------------------------------------------
$global:LastLogFile = $null

function Get-Timestamp {
    return (Get-Date -Format "yyyy-MM-dd_HH-mm")
}

# -------------------------------------------
# Source folder
# -------------------------------------------
$lbl1 = New-Object System.Windows.Forms.Label
$lbl1.Text = "Source folder:"
$lbl1.Location = "10,10"
$form.Controls.Add($lbl1)

$txtSource = New-Object System.Windows.Forms.TextBox
$txtSource.Location = "10,30"
$txtSource.Width = 450
$form.Controls.Add($txtSource)


$btnSource = New-Object System.Windows.Forms.Button
$btnSource.Text = "Browse"
$btnSource.Location = "470,28"
$btnSource.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($dialog.ShowDialog() -eq "OK") {
            $txtSource.Text = $dialog.SelectedPath
        }
    })
$form.Controls.Add($btnSource)

# -------------------------------------------
# Destination folder
# -------------------------------------------
$lbl2 = New-Object System.Windows.Forms.Label
$lbl2.Text = "Destination folder:"
$lbl2.Location = "10,70"
$form.Controls.Add($lbl2)

$txtDest = New-Object System.Windows.Forms.TextBox
$txtDest.Location = "10,90"
$txtDest.Width = 450
$form.Controls.Add($txtDest)

$btnDest = New-Object System.Windows.Forms.Button
$btnDest.Text = "Browse"
$btnDest.Location = "470,88"
$btnDest.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($dialog.ShowDialog() -eq "OK") {
            $txtDest.Text = $dialog.SelectedPath
        }
    })
$form.Controls.Add($btnDest)


# -------------------------------------------
# Set default test values (correct place)
# -------------------------------------------

$txtSource.Text = "c:\temp"
$txtDest.Text = "d:\temp"

# -------------------------------------------
# ** NEW FUNCTION: Run Robocopy Core Logic **
# -------------------------------------------
function Run-Robocopy ($isTestRun) {
    $src = $txtSource.Text
    $dst = $txtDest.Text

    if (-not (Test-Path $src)) {
        [System.Windows.Forms.MessageBox]::Show("Source path does not exist.")
        return
    }

    # Destination folder must exist for Robocopy to run
    if (-not (Test-Path $dst -ErrorAction SilentlyContinue)) {
        [System.Windows.Forms.MessageBox]::Show("Destination path does not exist.")
        return
    }

    # create timestamped log file
    $ts = Get-Timestamp

    if ($isTestRun) {
        $logPrefix = "test"
    }

    else {
        $logPrefix = "full"
    }

    $global:LastLogFile = "robocopy_${ts}_${logPrefix}.log"
    
    # -------------------------------------------------------------------------
    # Определение параметров Robocopy
    # -------------------------------------------------------------------------
    
    # 1. Параметры для ТЕСТОВОГО ПРОГОНА (Listing Only): Быстрый, без реального копирования, без повторов.
    $testParams = "/E /R:0 /W:0 /NP /V /TEE /UNILOG:`"$LastLogFile`" /L" 
    
    # 2. Параметры для ПОЛНОГО КОПИРОВАНИЯ (Migration Ready): Копирует данные, атрибуты, таймстемпы.
    $fullCopyParams = "/E /COPY:DAT /DCOPY:DAT /Z /R:2 /W:2 /NP /UNILOG:`"$LastLogFile`""
    
    #/E /R:0 /W:0 /NP /V /TEE /UNILOG:`"$LastLogFile`""

    # Выбор параметров в зависимости от $isTestRun
    if ($isTestRun) {
        $finalRobocopyParams = $testParams
        $message = "Test Run (Listing Only) started. Check log file when finished.`nLog file: $LastLogFile"
        $title = "Robocopy Test Started"
    }
    else {
        $finalRobocopyParams = $fullCopyParams
        $message = "Full Copy started. Check log file when finished.`nLog file: $LastLogFile"
        $title = "Robocopy Full Copy Started"
    }


    $cmd = "robocopy `"$src`" `"$dst`" $finalRobocopyParams"

    $startMessage = "====================================== [ Working.. DONT CLOSE THIS WINDOW.. ] ================================" # Используем ваше тестовое сообщение
    $endMessage = "========================================= [ COMPLETED! You can close this window ] =============================="
    #$fullPowerShellCmd = "Write-Host ''; Write-Host '$startMessage'; $cmd;  Write-Host ''; Write-Host '$endMessage'"
    #Start-Process powershell.exe "-NoExit -Command $cmd"
    # run in external window

    Start-Process "cmd.exe" "/k echo $startMessage & $cmd & echo $endMessage"

    #Start-Process powershell.exe "-NoExit Write-Host 'fsdfdsf'; -Command $cmd"

    $finalMessageContent = "$message`n`ncommand: $cmd"
    [System.Windows.Forms.MessageBox]::Show($finalMessageContent, $title)
}

# -------------------------------------------
# Button: Run Full Robocopy
# -------------------------------------------
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run Copy"
$btnRun.Location = "135,140"
$btnRun.Width = 120
$btnRun.Add_Click({
        Run-Robocopy $false # $false indicates a full copy
    })
$form.Controls.Add($btnRun)

# -------------------------------------------
# Button: Run Test ( /L ) << NEW BUTTON
# -------------------------------------------
$btnTestRun = New-Object System.Windows.Forms.Button
$btnTestRun.Text = "Test Run ( /L )"
$btnTestRun.Location = "10,140"
$btnTestRun.Width = 120
$btnTestRun.Add_Click({
        Run-Robocopy $true # $true indicates a test run (adds /L)
    })
$form.Controls.Add($btnTestRun)

# -------------------------------------------
# Open Log Button (Adjusted position)
# -------------------------------------------
$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Text = "Open Log"
$btnOpenLog.Location = "260,140"
$btnOpenLog.Width = 100

$btnOpenLog.Add_Click({
        if ($global:LastLogFile -and (Test-Path $global:LastLogFile -ErrorAction SilentlyContinue)) {
            Start-Process "notepad.exe" $global:LastLogFile
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Log file not found yet.")
        }
    })

$form.Controls.Add($btnOpenLog)

# -------------------------------------------
# Open Destination Folder (Adjusted position)
# -------------------------------------------
$btnOpenFolder = New-Object System.Windows.Forms.Button
$btnOpenFolder.Text = "Open Folder"
$btnOpenFolder.Location = "365,140"
$btnOpenFolder.Width = 100

$btnOpenFolder.Add_Click({
        $dst = $txtDest.Text
        if (-not (Test-Path $dst)) {
            [System.Windows.Forms.MessageBox]::Show("Destination folder does not exist.")
            return
        }

        Start-Process "explorer.exe" $dst
    })

$form.Controls.Add($btnOpenFolder)

# -------------------------------------------
# SHOW GUI
# -------------------------------------------
$form.ShowDialog()