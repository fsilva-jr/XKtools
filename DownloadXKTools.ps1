 # ============================================
# Download XKTools (Self-Healing, Final Form)
# Created by: Francisco Silva
# Updated by: PowerShell GPT
# ============================================

$ErrorActionPreference = "Stop"

# --- Self-Healing UTF-8 Quote Fix ---
if (-not $env:XKTOOLS_SELF_HEALED) {
    $env:XKTOOLS_SELF_HEALED = "1"
    $thisScript = $MyInvocation.MyCommand.Path
    (Get-Content $thisScript -Raw) -replace '[“”]', '"' -replace '–', '-' | Set-Content -Encoding UTF8 -Path $thisScript

    # Re-run the script after fix
    powershell -ExecutionPolicy Bypass -File $thisScript
    exit
}

# --- Define Paths ---
$repoName = "XKtools"
$zipUrl = "https://codeload.github.com/fsilva-jr/$repoName/zip/refs/heads/main"
$tempRoot = "C:\Temp"
$zipFile = Join-Path $tempRoot "$repoName-main.zip"
$extractFolder = Join-Path $tempRoot "XKTools"
$logFolder = Join-Path $extractFolder "Logs"
$mainScript = Join-Path $extractFolder "00 - Menu.ps1"

# --- Create Necessary Folders ---
New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
New-Item -Path $extractFolder -ItemType Directory -Force | Out-Null
New-Item -Path $logFolder -ItemType Directory -Force | Out-Null

# --- Logging ---
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $logFolder "DownloadXKTools.log"
    Add-Content -Path $logFile -Value "$timestamp [INFO] $Message"
}

try {
    Write-Host "`n🌐 Downloading XKTools from GitHub..." -ForegroundColor Cyan
    Write-Log "Downloading ZIP from $zipUrl"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

    Write-Host "📦 Extracting contents..." -ForegroundColor Cyan
    Expand-Archive -Path $zipFile -DestinationPath $extractFolder -Force

    # Move inner folder contents
    $innerFolder = Join-Path $extractFolder "$repoName-main"
    if (Test-Path $innerFolder) {
        Get-ChildItem -Path $innerFolder -Force | Move-Item -Destination $extractFolder -Force
        Remove-Item -Path $innerFolder -Recurse -Force
        Write-Log "Moved contents from $innerFolder to $extractFolder"
    }

    # Cleanup
    Remove-Item -Path $zipFile -Force
    Write-Log "Deleted ZIP file"

    # Launch menu
    if (Test-Path $mainScript) {
        Write-Host "`n🚀 Launching XKTools Menu..." -ForegroundColor Green
        Write-Log "Launching $mainScript"
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$mainScript`"" -Verb RunAs
    } else {
        Write-Host "❌ Could not find main menu script: $mainScript" -ForegroundColor Red
        Write-Log "ERROR: Menu script not found at $mainScript"
    }

} catch {
    Write-Host "❌ An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "ERROR: $($_.Exception.Message)"
}
 
