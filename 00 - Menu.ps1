# ============================================
# XKTools Main Menu (Simplified Improved)
# Created by: Francisco Silva
# Updated by: PowerShell GPT
# ============================================

Add-Type -AssemblyName System.Windows.Forms

# === Globals ===
$scriptDir = "C:\Temp\XKTools"
$logFolder = Join-Path $scriptDir "Logs"
$logFile   = Join-Path $logFolder "XKToolsMenu.log"
$executedOptions = @()

# === Setup Directories ===
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# === Logger ===
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Host $entry
}

# === Elevate to Admin if Needed ===
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        Write-Log "Not running as administrator. Relaunching elevated..." -Level "WARN"
        Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit
    }
}

# === Check PowerShell Version and Offer Upgrade ===
function Check-PowerShellVersion {
    $psMajor = $PSVersionTable.PSVersion.Major
    if ($psMajor -lt 7) {
        Write-Host "⚠ PowerShell $psMajor detected. Recommended: PowerShell 7 or higher." -ForegroundColor Yellow
        $upgrade = Read-Host "Do you want to upgrade PowerShell now? (Y/N)"
        if ($upgrade -match '^[Yy]$') {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                try {
                    Write-Host "Upgrading via winget..." -ForegroundColor Cyan
                    Start-Process winget -ArgumentList "install --id Microsoft.Powershell --source winget --silent" -Wait -NoNewWindow
                    Write-Host "✅ Upgrade started. Please restart the session." -ForegroundColor Green
                    exit
                } catch {
                    Write-Log "Winget upgrade failed: $_" -Level "ERROR"
                    Start-Process "https://aka.ms/powershell"
                }
            } else {
                Write-Host "Winget not found. Opening download page..." -ForegroundColor Yellow
                Start-Process "https://aka.ms/powershell"
            }
        }
    }
}

# === Resolve PowerShell Engine ===
function Get-Engine {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    return $(if ($pwsh) { "pwsh" } else { "powershell" })
}

# === Run Script from Menu ===
function Execute-SelectedScript {
    param([string]$ScriptName, [string]$MenuKey)

    $fullPath = Join-Path $scriptDir $ScriptName

    if (-not (Test-Path $fullPath)) {
        Write-Log "Script file not found: $fullPath" -Level "ERROR"
        Write-Host "❌ Script not found: $ScriptName" -ForegroundColor Red
        return
    }

    Write-Log "Running: $fullPath"
    Write-Host "`n▶ Running script: $ScriptName" -ForegroundColor Yellow

    try {
        $engine = Get-Engine
        & $engine -ExecutionPolicy Bypass -NoProfile -File "`"$fullPath`""
        Write-Log "✅ Finished: $ScriptName"
        if (-not $executedOptions.Contains($MenuKey)) {
            $executedOptions += $MenuKey
        }
    } catch {
        Write-Log "❌ Error while executing: $ScriptName - $($_.Exception.Message)" -Level "ERROR"
        Write-Host "❌ Error during execution." -ForegroundColor Red
    }
}

# === Show Menu ===
function Show-Menu {
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
        "12" = "12 - UpdateWebAndWifConfig.ps1"  # ✅ NEW OPTION
    }

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

        $choice = Read-Host "Enter an option number (1/12) or X to exit"

        if ($choice -match '^[Xx]$') {
            Write-Host "`n👋 Exiting XKTools. Goodbye!" -ForegroundColor Cyan
            Write-Log "==== XKTools Menu Execution Ended ===="
            break
        }

        if (-not $scriptMap.ContainsKey($choice)) {
            Write-Host "⚠ Invalid option. Try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
            continue
        }

        Execute-SelectedScript -ScriptName $scriptMap[$choice] -MenuKey $choice

        Write-Host ""
        [void](Read-Host "Press Enter to return to the menu...")  # ✅ Corrigido aqui!

    } while ($true)
}

# === Main ===
Write-Log "==== XKTools Menu Execution Started ===="
Ensure-Admin
Check-PowerShellVersion
Show-Menu
