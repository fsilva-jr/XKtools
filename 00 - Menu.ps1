# ============================================
# XKTools Main Menu (Simplified + PS Upgrade Safe)
# Created by: Francisco Silva
# Updated by: PowerShell GPT
# ============================================

# --- PowerShell version check and upgrade ---
$psMajor = $PSVersionTable.PSVersion.Major

if ($psMajor -lt 7) {
    Write-Host "Your current PowerShell version is $psMajor. It is recommended to upgrade to PowerShell 7 or higher." -ForegroundColor Yellow
    $upgradeChoice = Read-Host "Do you want to upgrade PowerShell now? (Y/N)"

    if ($upgradeChoice -match '^[Yy]$') {

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                Write-Host "Upgrading PowerShell using winget..." -ForegroundColor Cyan
                Start-Process winget -ArgumentList "install --id Microsoft.Powershell --source winget --silent" -Wait -NoNewWindow
                Write-Host "✅ PowerShell upgrade initiated. Please restart your session to use the new version." -ForegroundColor Green
                exit
            } catch {
                Write-Host "⚠ Winget failed to upgrade PowerShell." -ForegroundColor Red
                Start-Process "https://aka.ms/powershell"
            }
        } else {
            Write-Host "⚠ Winget is not installed on this system." -ForegroundColor Yellow
            $manualChoice = Read-Host "Do you want to open the PowerShell download page now? (Y/N)"
            if ($manualChoice -match '^[Yy]$') {
                Start-Process "https://aka.ms/powershell"
            }
            Write-Host "Continuing to menu without upgrading PowerShell..." -ForegroundColor Cyan
        }
    } else {
        Write-Host "Continuing to menu without upgrading PowerShell." -ForegroundColor Yellow
    }
}

# --- Auto-elevate ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# --- Setup paths ---
$scriptDir = "C:\Temp\XKTools"
$logFolder = Join-Path $scriptDir "Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "XKToolsMenu.log"

function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp [INFO] $Message"
}

Write-Log "==== XKTools Menu Execution Started ===="

# --- Menu mapping ---
$scriptMap = @{
    "1"  = "01 - Stop Services.ps1"
    "2"  = "02 - AZCopy_SQLPackage.ps1"
    "3"  = "03 - DownloadBacPacFromLCS.ps1"
    "4"  = "04 - CleanBacpac.ps1"
    "5"  = "05 - RenameDatabase.ps1"
    "6"  = "06 - RestoreBacPac.ps1"
    "7"  = "07 - Start Services.ps1"
    "8"  = "08 - BuildModels.ps1"
    "9"  = "09 - Sync Database.ps1"
    "10" = "10 - Deploy reports.ps1"
    "11" = "11 - Reindex All Database.ps1"
}

$executedOptions = @()

# --- Menu loop ---
do {
    Clear-Host
    Write-Host "========== XKTools Main Menu ==========" -ForegroundColor Cyan

    foreach ($key in $scriptMap.Keys | Sort-Object {[int]$_}) {
        $label = $scriptMap[$key] -replace '\.ps1$', ''
        $color = if ($executedOptions -contains $key) { "DarkGray" } else { "Green" }
        Write-Host ("  {0} - {1}" -f $key, $label) -ForegroundColor $color
    }

    Write-Host "  X - Exit" -ForegroundColor Red
    Write-Host "======================================="

    $choice = Read-Host "Enter an option number (from 1 to 11) or X to exit"

    if ($choice -eq "X" -or $choice -eq "x") {
        Write-Host "`nExiting XKTools. Goodbye!" -ForegroundColor Cyan
        Write-Log "==== XKTools Menu Execution Ended ===="
        break
    }

    if (-not $scriptMap.ContainsKey($choice)) {
        Write-Host "Invalid option. Please select a number from the menu." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    $selectedScript = Join-Path $scriptDir $scriptMap[$choice]
    if (Test-Path $selectedScript) {
        Write-Log "Running: $selectedScript"
        Write-Host "`nRunning script: $selectedScript" -ForegroundColor Yellow

        try {
            powershell.exe -ExecutionPolicy Bypass -NoProfile -File "`"$selectedScript`""
            Write-Log "Finished: $selectedScript"
            if (-not $executedOptions.Contains($choice)) {
                $executedOptions += $choice
            }
        } catch {
            Write-Host "Error while executing: $selectedScript" -ForegroundColor Red
            Write-Log "Error while executing ${selectedScript}: $($_.Exception.Message)"
        }
    } else {
        Write-Host "Script file not found: $selectedScript" -ForegroundColor Red
        Write-Log "File not found: $selectedScript"
    }

    Write-Host "`nPress Enter to return to the menu..."
    Read-Host

} while ($true)
