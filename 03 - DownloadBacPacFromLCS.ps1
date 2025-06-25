# ============================================
# XKTools - Download BacPac from LCS with Folder Dialog and Logging
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

# Load WinForms for FolderBrowserDialog
Add-Type -AssemblyName System.Windows.Forms

# Setup log
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "DownloadBacPacFromLCS.log"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

Write-Log -Message "======== Download BacPac Script Started ========" -Level "INFO"

# Prompt user for download URL
$downloadUrl = Read-Host "Enter the download URL for the BacPac file"
if ([string]::IsNullOrWhiteSpace($downloadUrl)) {
    Write-Log -Message "No download URL provided. Aborting." -Level "ERROR"
    Write-Host "No download URL provided. Aborting." -ForegroundColor Red
    exit 1
}
Write-Log -Message "User provided download URL: $downloadUrl" -Level "INFO"

# Open FolderBrowserDialog for target folder
$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$folderDialog.Description = "Select the folder where the BacPac will be saved"

if ($folderDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Log -Message "User canceled folder selection. Exiting." -Level "WARN"
    Write-Host "No target folder selected. Aborting." -ForegroundColor Red
    exit 1
}
$targetFolder = $folderDialog.SelectedPath
Write-Log -Message "User selected target folder: $targetFolder" -Level "INFO"

# Ask user for filename (force .bacpac)
$fileName = Read-Host "Enter the desired filename (without extension)"
if ([string]::IsNullOrWhiteSpace($fileName)) {
    Write-Log -Message "No filename provided. Aborting." -Level "ERROR"
    Write-Host "No filename provided. Aborting." -ForegroundColor Red
    exit 1
}

$fileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
$fileNameFinal = "$fileBaseName.bacpac"
$targetFilePath = Join-Path $targetFolder $fileNameFinal
Write-Log -Message "Final target file path: $targetFilePath" -Level "INFO"

# Check for existing file
if (Test-Path $targetFilePath) {
    $overwrite = Read-Host "File '$targetFilePath' already exists. Overwrite? (Y/N)"
    if ($overwrite.ToUpper() -ne "Y") {
        Write-Log -Message "User chose not to overwrite existing file. Exiting." -Level "WARN"
        Write-Host "Download canceled by user." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Log -Message "User chose to overwrite existing file: $targetFilePath" -Level "INFO"
    }
}

# Verify azcopy.exe existence
$azcopyExe = "C:\Temp\azcopy.exe"
if (-not (Test-Path $azcopyExe)) {
    Write-Log -Message "azcopy.exe not found at: $azcopyExe" -Level "ERROR"
    Write-Host "azcopy.exe not found at: $azcopyExe" -ForegroundColor Red
    exit 1
}
Write-Log -Message "azcopy.exe found at: $azcopyExe" -Level "INFO"

# Run AzCopy download
Write-Host "`nStarting download using AzCopy..." -ForegroundColor Cyan
Write-Log -Message "Starting AzCopy download: $downloadUrl -> $targetFilePath" -Level "INFO"

$azcopyCommand = "& `"$azcopyExe`" copy `"$downloadUrl`" `"$targetFilePath`" --recursive=true"

try {
    Invoke-Expression $azcopyCommand
    Write-Host "`n✔️ Download completed. File saved to: $targetFilePath" -ForegroundColor Green
    Write-Log -Message "Download completed successfully: $targetFilePath" -Level "INFO"
} catch {
    Write-Log -Message ("AzCopy failed: " + $_.Exception.Message) -Level "ERROR"
    Write-Host "❌ AzCopy failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Log -Message "======== Script Finished ========" -Level "INFO"
