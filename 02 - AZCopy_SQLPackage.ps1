 # ============================================
# XKTools - Download AZCopy and SQLPackage (GUI Version)
# Created by: Francisco Silva
# Updated by: PowerShell GPT
# ============================================

# === Auto-elevate and hide original console ===
if (-not ([Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psCommand = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $psCommand -WindowStyle Hidden
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

# === Setup Logging ===
$scriptName = "AZCopy_SQLPackage"
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

Write-Log "======== [START] AZCopy_SQLPackage Script ========"
Write-Log "PowerShell version: $($PSVersionTable.PSVersion.ToString())"

# === Paths ===
$downloadFolder = "C:\Temp"
$azcopyZip = Join-Path $downloadFolder "azcopy.zip"
$sqlPackageZip = Join-Path $downloadFolder "sqlpackage.zip"
$azcopyExtractFolder = Join-Path $downloadFolder "azcopy"
$sqlPackageExtractFolder = Join-Path $downloadFolder "sqlpackage"
$azcopyExe = Join-Path $downloadFolder "azcopy.exe"

$http = [System.Net.Http.HttpClient]::new()

function Show-YesNoBox($message, $title) {
    return [System.Windows.Forms.MessageBox]::Show($message, $title, 'YesNo', 'Question') -eq 'Yes'
}

function Show-Message($msg, $title = "XKTools") {
    [System.Windows.Forms.MessageBox]::Show($msg, $title, 'OK', 'Information') | Out-Null
}

# === Download Progress GUI ===
function Show-ProgressForm {
    param (
        [string]$title,
        [string]$text
    )
    $form = New-Object Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object Drawing.Size(400,120)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.ControlBox = $false
    $form.TopMost = $true

    $label = New-Object Windows.Forms.Label
    $label.Text = $text
    $label.AutoSize = $true
    $label.Location = New-Object Drawing.Point(20,20)
    $form.Controls.Add($label)

    $progress = New-Object Windows.Forms.ProgressBar
    $progress.Style = "Marquee"
    $progress.MarqueeAnimationSpeed = 25
    $progress.Size = New-Object Drawing.Size(340,20)
    $progress.Location = New-Object Drawing.Point(20,50)
    $form.Controls.Add($progress)

    $form.Show()
    return $form
}

function FastDownload ($url, $destination, $labelText) {
    $progressForm = Show-ProgressForm -title "Downloading" -text $labelText
    Write-Log "Downloading from $url to $destination"
    try {
        $response = $http.GetAsync($url).Result
        [System.IO.File]::WriteAllBytes($destination, $response.Content.ReadAsByteArrayAsync().Result)
        Write-Log "✅ Downloaded $destination"
    } catch {
        Write-Log "❌ Failed to download from $url - $_" -Level "ERROR"
        $progressForm.Close()
        Show-Message "Failed to download from:`n$url`n`n$_" "Download Error"
        exit 1
    }
    $progressForm.Close()
}

# === Confirm re-downloads ===
$downloadAzCopy = $true
if (Test-Path $azcopyExe) {
    if (-not (Show-YesNoBox "azcopy.exe already exists. Download again?" "AzCopy")) {
        $downloadAzCopy = $false
        Write-Log "Skipped AzCopy re-download."
    }
}

$downloadSqlPackage = $true
if (Test-Path $sqlPackageExtractFolder) {
    if (-not (Show-YesNoBox "SQLPackage already exists. Download again?" "SQLPackage")) {
        $downloadSqlPackage = $false
        Write-Log "Skipped SQLPackage re-download."
    }
}

# === Download and extract AzCopy ===
if ($downloadAzCopy) {
    if (Test-Path $azcopyExtractFolder) {
        Remove-Item -Recurse -Force $azcopyExtractFolder
        Write-Log "Removed old AzCopy folder."
    }

    FastDownload "https://aka.ms/downloadazcopy-v10-windows" $azcopyZip "Downloading AzCopy..."
    Expand-Archive -Path $azcopyZip -DestinationPath $azcopyExtractFolder -Force
    Remove-Item $azcopyZip -Force
    Write-Log "AzCopy extracted."

    $azcopyPath = Get-ChildItem -Path $azcopyExtractFolder -Filter "azcopy.exe" -Recurse | Select-Object -First 1
    if ($azcopyPath) {
        Copy-Item -Path $azcopyPath.FullName -Destination $azcopyExe -Force
        Write-Log "Copied AzCopy to $azcopyExe"
    } else {
        Write-Log "azcopy.exe not found after extraction." -Level "ERROR"
        Show-Message "azcopy.exe not found in extracted folder." "Error"
    }

    Remove-Item -Recurse -Force $azcopyExtractFolder
    Write-Log "Cleaned AzCopy temp folder."
}

# === Download and extract SQLPackage ===
if ($downloadSqlPackage) {
    if (Test-Path $sqlPackageExtractFolder) {
        Remove-Item -Recurse -Force $sqlPackageExtractFolder
        Write-Log "Removed old SQLPackage folder."
    }

    FastDownload "https://aka.ms/sqlpackage-windows" $sqlPackageZip "Downloading SQLPackage..."
    Expand-Archive -Path $sqlPackageZip -DestinationPath $sqlPackageExtractFolder -Force
    Remove-Item $sqlPackageZip -Force
    Write-Log "SQLPackage extracted to $sqlPackageExtractFolder"
}

Show-Message "✅ Download and setup completed successfully." "XKTools"
Write-Log "✅ Script completed successfully."
Write-Log "======== [END] AZCopy_SQLPackage Script ========"
 
