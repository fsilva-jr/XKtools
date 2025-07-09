 # ============================================
# XKTools - Restore BacPac with GUI Dialogs and Logging
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# Updated for PS 5.1 & PS 7+ by PowerShell GPT
# ============================================

# Auto-elevate to admin
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script as Administrator with ExecutionPolicy Bypass..." -ForegroundColor Yellow
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# Load WinForms assembly for dialogs
Add-Type -AssemblyName System.Windows.Forms

# Setup log
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "RestoreBacPac.log"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

Write-Log -Message "======== BacPac Restore Script Started ========" -Level "INFO"

# Ask user to select BacPac file
$bacpacDialog = New-Object System.Windows.Forms.OpenFileDialog
$bacpacDialog.Title = "Select the BacPac File to Restore"
$bacpacDialog.Filter = "BacPac Files (*.bacpac)|*.bacpac"

if ($bacpacDialog.ShowDialog() -ne 'OK') {
    Write-Log -Message "User canceled BacPac file selection." -Level "WARN"
    Write-Host "No BacPac file selected. Aborting." -ForegroundColor Red
    exit 1
}
$bacpacFullPath = $bacpacDialog.FileName
Write-Log -Message "User selected BacPac file: $bacpacFullPath" -Level "INFO"

# Extract folder and filename
$sourceFolder = [System.IO.Path]::GetDirectoryName($bacpacFullPath)
$bacpacFileName = [System.IO.Path]::GetFileName($bacpacFullPath)

# Ask for target database name
$targetDbName = Read-Host "Enter the target database name for the restore"
if ([string]::IsNullOrWhiteSpace($targetDbName)) {
    Write-Log -Message "No target database name provided. Aborting." -Level "ERROR"
    Write-Host "No target database name provided. Aborting." -ForegroundColor Red
    exit 1
}
Write-Log -Message "Target database name: $targetDbName" -Level "INFO"

# Confirm restore
$confirmation = [System.Windows.Forms.MessageBox]::Show(
    "Do you want to proceed with restoring:`n`n$bacpacFullPath`n`nTo database:`n$targetDbName?",
    "Confirm Restore",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
)

if ($confirmation -ne [System.Windows.Forms.DialogResult]::Yes) {
    Write-Log -Message "User canceled the restore confirmation." -Level "WARN"
    Write-Host "Restore canceled by user." -ForegroundColor Yellow
    exit 0
}
Write-Log -Message "User confirmed the restore operation." -Level "INFO"

# Verify sqlpackage.exe existence
$sqlPackageExe = "C:\Temp\sqlpackage\sqlpackage.exe"
if (-not (Test-Path $sqlPackageExe)) {
    Write-Log -Message "sqlpackage.exe not found at: $sqlPackageExe" -Level "ERROR"
    Write-Host "sqlpackage.exe not found at: $sqlPackageExe" -ForegroundColor Red
    exit 1
}
Write-Log -Message "sqlpackage.exe found at: $sqlPackageExe" -Level "INFO"

# Build target connection string
$targetConnString = "Server=localhost;Initial Catalog=$targetDbName;Integrated Security=True;TrustServerCertificate=True"
Write-Log -Message "Target connection string built for DB: $targetDbName" -Level "INFO"

# Run SQLPackage Import
Write-Host "`nStarting BacPac restore..." -ForegroundColor Cyan
Write-Log -Message "Starting SQLPackage Import..." -Level "INFO"

$restoreCommand = "& `"$sqlPackageExe`" /a:Import /sf:`"$bacpacFullPath`" /TargetConnectionString:`"$targetConnString`" /p:CommandTimeout=12000 /p:DisableIndexesForDataPhase=False"

try {
    Invoke-Expression $restoreCommand
    Write-Log -Message "SQLPackage Import completed successfully." -Level "INFO"
    Write-Host "`nRestore completed successfully." -ForegroundColor Green
} catch {
    Write-Log -Message ("SQLPackage Import failed: " + $_.Exception.Message) -Level "ERROR"
    Write-Host "Restore failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Set Recovery Model to SIMPLE
Write-Log -Message "Setting database recovery model to SIMPLE..." -Level "INFO"
try {
    $sql = "ALTER DATABASE [$targetDbName] SET RECOVERY SIMPLE;"
    Invoke-Sqlcmd -ServerInstance "localhost" -Query $sql -ErrorAction Stop
    Write-Log -Message "Database recovery model set to SIMPLE successfully." -Level "INFO"
    Write-Host "Database recovery model set to SIMPLE." -ForegroundColor Green
} catch {
    Write-Log -Message ("Failed to set recovery model: " + $_.Exception.Message) -Level "ERROR"
    Write-Host "Failed to set recovery model: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Log -Message "======== Script Finished Successfully ========" -Level "INFO"
 
