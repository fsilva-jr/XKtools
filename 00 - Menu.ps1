# ============================================
# XKTools Main Menu Script
# Created by: Francisco Silva
# Updated by: PowerShell GPT
# Universal PowerShell Version + Upgrade Support 🔧
# ============================================

# --- Detect Shell Type ---
$hostIsPwsh = $PSVersionTable.PSEdition -eq "Core"
$elevationCommand = if ($hostIsPwsh) { "pwsh" } else { "powershell.exe" }

# --- Auto-elevate ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {

    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath $elevationCommand -Verb RunAs -ArgumentList $args
    exit
}

# --- Setup Paths ---
$scriptDir = "C:\Temp\XKTools"
$logFolder = Join-Path $scriptDir "Logs"
$logFile = Join-Path $logFolder "XKToolsMenu.log"

if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# --- Logging Function ---
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp [INFO] $Message"
}

Write-Log "==== XKTools Menu Execution Started ===="

# --- PowerShell Version Check and Upgrade ---
$currentVersion = $PSVersionTable.PSVersion
Write-Host "`n🔍 Detected PowerShell version: $currentVersion" -ForegroundColor Yellow

if ($currentVersion.Major -lt 7) {
    Write-Warning "⚠ Your current PowerShell version is older than 7. PowerShell 7+ is recommended."

    $upgrade = Read-Host "Do you want to upgrade PowerShell to the latest version now? (Y/N)"
    if ($upgrade.Trim().ToUpper() -eq "Y") {

        $wingetExists = Get-Command "winget.exe" -ErrorAction SilentlyContinue

        if ($wingetExists) {
            try {
                Write-Host "`n🚀 Using winget to install PowerShell 7..." -ForegroundColor Cyan
                Start-Process "winget" -ArgumentList "install --id Microsoft.Powershell --source winget --accept-package-agreements --accept-source-agreements" -Verb RunAs
                Write-Log "PowerShell upgrade started via winget."
                Write-Host "`n✅ Upgrade process started. Please relaunch this script using PowerShell 7 after install completes." -ForegroundColor Green
            }
            catch {
                Write-Warning "❌ Failed to start winget upgrade: $($_.Exception.Message)"
                Write-Log "❌ winget upgrade failed: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "⚠ winget is not available on this system."
            Write-Host "Opening download page instead..." -ForegroundColor Yellow
            Start-Process "https://aka.ms/powershell-release?tag=stable"
            Write-Log "winget missing. Opened browser for manual PowerShell 7 install."
        }

        exit
    } else {
        Write-Host "🆗 Continuing with current PowerShell version..." -ForegroundColor Gray
        Write-Log "User declined PowerShell upgrade. Proceeding..."
    }
}

# --- Menu Items Map ---
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

# --- Menu Loop ---
do {
    Clear-Host
    Write-Host "========== XKTools Main Menu ==========" -ForegroundColor Cyan

    foreach ($key in $scriptMap.Keys | Sort-Object {[int]$_}) {
        $label = switch ($key) {
            "1"  { "Stop Services" }
            "2"  { "AZCopy + SQLPackage Download" }
            "3"  { "Download BacPac from LCS" }
            "4"  { "Clean BacPac and Remove Tables" }
            "5"  { "Rename Database" }
            "6"  { "Restore BacPac" }
            "7"  { "Start Services" }
            "8"  { "Build Models" }
            "9"  { "Sync Database" }
            "10" { "Deploy D365 Reports" }
            "11" { "Reindex All Database" }
        }

        $color = if ($executedOptions -contains $key) { "DarkGray" } else { "Green" }
        Write-Host ("  {0,2} - {1}" -f $key, $label) -ForegroundColor $color
    }

    Write-Host "  X  - Exit" -ForegroundColor Red
    Write-Host "======================================="

    $choice = Read-Host "Enter an option number (1-11) or X to exit"
    $choice = $choice.Trim()

    if ($choice -eq 'X' -or $choice -eq 'x') {
        Write-Host "`nExiting XKTools. Goodbye!" -ForegroundColor Cyan
        Write-Log "==== XKTools Menu Execution Ended ===="
        break
    }

    if (-not $scriptMap.ContainsKey($choice)) {
        Write-Host "❌ Invalid option. Please select a valid number from the menu." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    $selectedScript = Join-Path $scriptDir $scriptMap[$choice]
    if (Test-Path $selectedScript) {
        Write-Host "`n▶ Running script: $selectedScript" -ForegroundColor Yellow
        Write-Log "Executing script: $selectedScript"

        try {
            & $elevationCommand -NoProfile -ExecutionPolicy Bypass -File "`"$selectedScript`""
            Write-Log "Finished script: $selectedScript"

            if (-not $executedOptions.Contains($choice)) {
                $executedOptions += $choice
            }
        }
        catch {
            Write-Warning "❌ Error while executing script."
            Write-Log "❌ ERROR: $($_.Exception.Message)"
        }

    } else {
        Write-Warning "⚠ Script file not found: $selectedScript"
        Write-Log "❌ ERROR: File not found - $selectedScript"
    }

    Write-Host "`nPress Enter to return to the menu..."
    Read-Host

} while ($true)
