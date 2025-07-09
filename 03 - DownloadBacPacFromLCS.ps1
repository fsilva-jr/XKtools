 # ============================================
# XKTools - GUI BacPac Download via AzCopy
# Created by: Francisco Silva
# Updated by: PowerShell GPT
# ============================================

# === Auto-elevate and hide console ===
if (-not ([Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $args -WindowStyle Hidden
    exit
}

# === Load UI Assemblies ===
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === Logging Setup ===
$scriptName = "DownloadBacPacFromLCS"
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}
$logFile = Join-Path $logFolder "$scriptName.log"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp [$Level] $Message" -Encoding UTF8
}

function Show-InputBox($message, $title) {
    $form = New-Object Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object Drawing.Size(420,150)
    $form.StartPosition = 'CenterScreen'

    $label = New-Object Windows.Forms.Label
    $label.Text = $message
    $label.Size = New-Object Drawing.Size(380,20)
    $label.Location = New-Object Drawing.Point(10,10)
    $form.Controls.Add($label)

    $textbox = New-Object Windows.Forms.TextBox
    $textbox.Size = New-Object Drawing.Size(380,25)
    $textbox.Location = New-Object Drawing.Point(10,35)
    $form.Controls.Add($textbox)

    $okButton = New-Object Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object Drawing.Point(300,70)
    $okButton.Add_Click({ $form.Tag = $textbox.Text; $form.Close() })
    $form.Controls.Add($okButton)

    $form.TopMost = $true
    $form.ShowDialog() | Out-Null
    return $form.Tag
}

function Show-MessageBox($msg, $title="XKTools", $icon="Information") {
    [System.Windows.Forms.MessageBox]::Show($msg, $title, 'OK', $icon) | Out-Null
}

function Confirm-Overwrite($path) {
    $msg = "File already exists:`n$path`nOverwrite?"
    $result = [System.Windows.Forms.MessageBox]::Show($msg, "Overwrite?", 'YesNo', 'Question')
    return $result -eq 'Yes'
}

Write-Log "======== BacPac Download Script Started ========"

# === Step 1: Ask for download URL ===
$url = Show-InputBox -message "Enter the BacPac download URL:" -title "Download URL"
if (-not $url) {
    Write-Log "No download URL provided. Aborting." -Level "ERROR"
    Show-MessageBox "Download canceled. No URL provided." "Error" "Error"
    exit 1
}
Write-Log "Download URL: $url"

# === Step 2: Folder selection ===
$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$folderDialog.Description = "Choose destination folder for .bacpac"
if ($folderDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Log "Folder selection canceled by user." -Level "WARN"
    Show-MessageBox "Download canceled. No folder selected." "Canceled" "Warning"
    exit 1
}
$targetFolder = $folderDialog.SelectedPath
Write-Log "Destination folder: $targetFolder"

# === Step 3: Filename input ===
$fileName = Show-InputBox -message "Enter the file name (without .bacpac):" -title "Filename"
if (-not $fileName) {
    Write-Log "No filename provided. Aborting." -Level "ERROR"
    Show-MessageBox "Download canceled. No filename provided." "Error" "Error"
    exit 1
}
$fileName = "$([IO.Path]::GetFileNameWithoutExtension($fileName)).bacpac"
$targetPath = Join-Path $targetFolder $fileName
Write-Log "Final file path: $targetPath"

# === Step 4: Check for existing file ===
if (Test-Path $targetPath) {
    if (-not (Confirm-Overwrite -path $targetPath)) {
        Write-Log "User declined to overwrite existing file. Exiting." -Level "WARN"
        Show-MessageBox "Download canceled by user." "Canceled" "Warning"
        exit 0
    }
    Write-Log "User confirmed overwrite of $targetPath"
}

# === Step 5: Check AzCopy existence ===
$azcopyExe = "C:\Temp\azcopy.exe"
if (-not (Test-Path $azcopyExe)) {
    Write-Log "azcopy.exe not found at $azcopyExe" -Level "ERROR"
    Show-MessageBox "AzCopy not found at:`n$azcopyExe" "Missing Tool" "Error"
    exit 1
}
Write-Log "AzCopy found."

# === Step 6: Download with AzCopy ===
Write-Log "Starting AzCopy download..."
$progressForm = New-Object Windows.Forms.Form
$progressForm.Text = "Downloading BacPac..."
$progressForm.Size = New-Object Drawing.Size(350, 100)
$progressForm.StartPosition = "CenterScreen"
$progressForm.TopMost = $true

$label = New-Object Windows.Forms.Label
$label.Text = "Downloading... Please wait."
$label.AutoSize = $true
$label.Location = New-Object Drawing.Point(20,20)
$progressForm.Controls.Add($label)

$progressBar = New-Object Windows.Forms.ProgressBar
$progressBar.Style = "Marquee"
$progressBar.MarqueeAnimationSpeed = 30
$progressBar.Location = New-Object Drawing.Point(20, 45)
$progressBar.Size = New-Object Drawing.Size(300, 20)
$progressForm.Controls.Add($progressBar)

$progressForm.Show()

Start-Job -ScriptBlock {
    param($azcopyExe, $url, $targetPath)
    & $azcopyExe copy $url $targetPath --recursive=true | Out-Null
} -ArgumentList $azcopyExe, $url, $targetPath | Wait-Job | Receive-Job | Out-Null

$progressForm.Close()
Write-Log "Download completed: $targetPath"

Show-MessageBox "✔️ BacPac downloaded successfully to:`n$targetPath" "Download Complete"
Write-Log "======== Script Finished ========"
 
