 # ============================================
# XKTools - Deploy-D365Reports.ps1
# Author: Francisco Silva + PowerShell GPT
# Contact: francisco@mtxn.com.br
# Logs actions to: C:\Temp\XKTools\Logs\Deploy-D365Reports.log
# ============================================

# --- Auto-elevate to admin ---
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script as Administrator..." -ForegroundColor Yellow
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# --- Load WinForms ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Setup Logging ---
$logFolder = "C:\Temp\XKTools\Logs"
$logFile = Join-Path $logFolder "Deploy-D365Reports.log"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [INFO] $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Host $entry
}

Write-Log "==== Deploy-D365Reports.ps1 Execution Started ===="

# --- Select Available Drive ---
$driveOptions = Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path "$($_.Root)\AosService" } | Select-Object -ExpandProperty Name

if (-not $driveOptions) {
    Write-Host "❌ No drives with '\AosService' found." -ForegroundColor Red
    Write-Log "❌ No AosService directories found."
    exit 1
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Select AosService Drive"
$form.Size = New-Object System.Drawing.Size(400, 180)
$form.StartPosition = "CenterScreen"
$form.Topmost = $true

$label = New-Object System.Windows.Forms.Label
$label.Text = "Select the drive where AosService is installed:"
$label.Size = New-Object System.Drawing.Size(360, 20)
$label.Location = New-Object System.Drawing.Point(10, 20)
$form.Controls.Add($label)

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(10, 50)
$comboBox.Size = New-Object System.Drawing.Size(360, 20)
$comboBox.DropDownStyle = 'DropDownList'
$driveOptions | ForEach-Object { $comboBox.Items.Add("$($_):\AosService") }
$comboBox.SelectedIndex = 0
$form.Controls.Add($comboBox)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Location = New-Object System.Drawing.Point(280, 90)
$okButton.Add_Click({ $form.Close() })
$form.Controls.Add($okButton)

$form.ShowDialog() | Out-Null

$selectedDrive = $comboBox.SelectedItem.ToString().Substring(0,1)
$aosPath = "$selectedDrive`:\AosService"
$packagePath = "$aosPath\PackagesLocalDirectory"
$scriptBase = "$packagePath\Plugins\AxReportVmRoleStartupTask\DeployAllReportsToSSRS.ps1"

Write-Log "Validated AosService path: $aosPath"

# --- Ask what to deploy ---
$deployAll = [System.Windows.Forms.MessageBox]::Show(
    "Do you want to deploy ALL D365FO reports?",
    "Deploy All Reports?",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
)

if ($deployAll -eq [System.Windows.Forms.DialogResult]::Yes) {
    Write-Host "`n▶ Deploying ALL reports..." -ForegroundColor Yellow
    Write-Log "Deploying all reports using: $scriptBase -PackageInstallLocation $packagePath"

    try {
        & $scriptBase -PackageInstallLocation $packagePath
        Write-Host "`n✔️ All reports deployed successfully." -ForegroundColor Green
        Write-Log "✅ All reports deployed successfully."
    } catch {
        Write-Host "❌ Error deploying all reports: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "❌ ERROR: $($_.Exception.Message)"
        exit 1
    }
}
else {
    # Prompt for Model and Report
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Deploy Specific Report"
    $inputForm.Size = New-Object System.Drawing.Size(400, 250)
    $inputForm.StartPosition = "CenterScreen"
    $inputForm.TopMost = $true

    $labelModel = New-Object System.Windows.Forms.Label
    $labelModel.Text = "Model Name:"
    $labelModel.Location = New-Object System.Drawing.Point(10, 20)
    $labelModel.Size = New-Object System.Drawing.Size(100, 20)
    $inputForm.Controls.Add($labelModel)

    $textBoxModel = New-Object System.Windows.Forms.TextBox
    $textBoxModel.Location = New-Object System.Drawing.Point(120, 20)
    $textBoxModel.Size = New-Object System.Drawing.Size(250, 20)
    $inputForm.Controls.Add($textBoxModel)

    $labelReport = New-Object System.Windows.Forms.Label
    $labelReport.Text = "Report Name:"
    $labelReport.Location = New-Object System.Drawing.Point(10, 60)
    $labelReport.Size = New-Object System.Drawing.Size(100, 20)
    $inputForm.Controls.Add($labelReport)

    $textBoxReport = New-Object System.Windows.Forms.TextBox
    $textBoxReport.Location = New-Object System.Drawing.Point(120, 60)
    $textBoxReport.Size = New-Object System.Drawing.Size(250, 20)
    $inputForm.Controls.Add($textBoxReport)

    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = "Deploy"
    $okBtn.Location = New-Object System.Drawing.Point(280, 110)
    $okBtn.Add_Click({ $inputForm.Close() })
    $inputForm.Controls.Add($okBtn)

    $inputForm.ShowDialog() | Out-Null

    $modelName = $textBoxModel.Text.Trim()
    $reportName = $textBoxReport.Text.Trim()

    if (-not $modelName -or -not $reportName) {
        Write-Host "❌ Model name or report name is empty. Aborting." -ForegroundColor Red
        Write-Log "❌ Model name or report name was empty. Aborted."
        exit 1
    }

    $fullReport = "${reportName}.Report"
    Write-Host "`n▶ Deploying report: $fullReport from model: $modelName" -ForegroundColor Yellow
    Write-Log "Attempting deployment: $fullReport from $modelName"

    try {
        & $scriptBase -Module $modelName -ReportName $fullReport -PackageInstallLocation $packagePath
        Write-Host "`n✔️ Report '${fullReport}' deployed successfully." -ForegroundColor Green
        Write-Log "✅ Report '${fullReport}' from model '${modelName}' deployed successfully."
    }
    catch {
        Write-Host "❌ Error deploying ${fullReport}: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "❌ ERROR deploying ${fullReport}: $($_.Exception.Message)"
        exit 1
    }
}

Write-Log "==== Deploy-D365Reports.ps1 Execution Completed ===="
Write-Host "`n✔️ Done." -ForegroundColor Green
Write-Host "`nPress Enter to return to the menu..."
Read-Host
