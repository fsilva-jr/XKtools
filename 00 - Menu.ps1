# ============================================
# XKTools Main Menu Script
# Created by: Francisco Silva
# ============================================

# --- Auto-elevate ---
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# --- Setup paths ---
$scriptDir = "C:\Temp\XKTools"
$logFolder = Join-Path $scriptDir "Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "XKToolsMenu.log"

# --- Logging function ---
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp [INFO] $Message"
}

Write-Log "==== XKTools Menu Execution Started ===="

# --- Menu mapping ---
$scriptMap = @{
    "1" = "01 - Stop Services.ps1"
    "2" = "02 - AZCopy_SQLPackage.ps1"
    "3" = "03 - DownloadBacPacFromLCS.ps1"
    "4" = "04 - CleanBacpac.ps1"
    "5" = "05 - RenameDatabase.ps1"
    "6" = "06 - RestoreBacPac.ps1"
    "7" = "07 - Start Services.ps1"
    "8" = "08 - BuildModels.ps1"
    "9" = "09 - Sync Database.ps1"
}

# --- Menu loop ---
do {
    Clear-Host
    Write-Host "========== XKTools Main Menu ==========" -ForegroundColor Cyan
    Write-Host "  1 - Stop Services"
    Write-Host "  2 - AZCopy + SQLPackage Download"
    Write-Host "  3 - Download BacPac from LCS"
    Write-Host "  4 - Clean BacPac and Remove Tables"
    Write-Host "  5 - Rename Database"
    Write-Host "  6 - Restore BacPac"
    Write-Host "  7 - Start Services"
    Write-Host "  8 - Build Models"
    Write-Host "  9 - Sync Database"
    Write-Host " 10 - Exit"
    Write-Host "======================================="

    $choice = Read-Host "Enter an option number (1–10)"
    $valid = $scriptMap.ContainsKey($choice) -or $choice -eq "10"

    if (-not $valid) {
        Write-Host "❌ Invalid option. Please select a number from the menu." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    if ($choice -eq "10") {
        Write-Host "`nExiting XKTools. Goodbye!" -ForegroundColor Cyan
        Write-Log "==== XKTools Menu Execution Ended ===="
        break
    }

    # --- Run selected script ---
    $selectedScript = Join-Path $scriptDir $scriptMap[$choice]
    if (Test-Path $selectedScript) {
        $logEntry = "`n[$(Get-Date -Format 'HH:mm:ss')] Running: $selectedScript"
        Add-Content -Path $logFile -Value $logEntry
        Write-Host "`n▶ Running script: $selectedScript" -ForegroundColor Yellow

        try {
            & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $selectedScript
            Add-Content -Path $logFile -Value "[$(Get-Date -Format 'HH:mm:ss')] Finished: $selectedScript"
        }
        catch {
            Write-Warning "❌ Error while executing: $selectedScript"
            Write-Log ("❌ Error while executing ${selectedScript}: " + $_.Exception.Message)
        }

    } else {
        Write-Warning "⚠ Script file not found: $selectedScript"
        Add-Content -Path $logFile -Value "[$(Get-Date -Format 'HH:mm:ss')] ERROR: File not found - $selectedScript"
    }

    Write-Host "`nPress Enter to return to the menu..."
    Read-Host

} while ($true)
