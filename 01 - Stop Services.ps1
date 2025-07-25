# ============================================
# Stop Services Script - Versão com Logging Avançado
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# Updated for PS 5.1 & PS 7+ by PowerShell GPT
# ============================================

# Auto-elevate to admin if needed
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# Setup
$scriptName = "StopServices"
$scriptVersion = "1.1.0"
$logFolder = "C:\Temp\XKTools\Logs"

if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

$logFile = Join-Path $logFolder "$scriptName.log"

# Optional log rotation (if over 5MB)
$maxLogSizeMB = 5
if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt ($maxLogSizeMB * 1MB))) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Rename-Item -Path $logFile -NewName "$scriptName-$timestamp.log"
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8NoBOM
}

Write-Log -Message "======== Stop Services Script Started ========" -Level "INFO"
Write-Log -Message "Script Version: $scriptVersion" -Level "INFO"

# Services to stop
$services = @(
    "Management Reporter 2012 Process Service",
    "Microsoft Dynamics 365 Unified Operations: Batch Management Service",
    "Microsoft Dynamics 365 Unified Operations: Data Import Export Framework Service",
    "SQL Server Reporting Services",
    "World Wide Web Publishing Service"
) | Sort-Object -Unique

$failedServices = @()

foreach ($svc in $services) {
    $serviceObj = Get-Service -Name $svc -ErrorAction SilentlyContinue

    if ($null -eq $serviceObj) {
        Write-Warning "⚠️ Service not found: $svc"
        Write-Log -Message "WARN: Service not found - $svc" -Level "WARN"
        continue
    }

    try {
        if ($serviceObj.Status -ne 'Stopped') {
            Write-Host "Stopping service: $svc" -ForegroundColor Yellow
            Write-Log -Message "Stopping service: $svc" -Level "INFO"

            Stop-Service -Name $svc -Force -ErrorAction Stop

            Write-Log -Message "SUCCESS: Service stopped - $svc" -Level "INFO"
        } else {
            Write-Log -Message "Service already stopped: $svc" -Level "WARN"
        }
    }
    catch {
        $failedServices += $svc
        Write-Warning "❌ Failed to stop service: $svc"
        Write-Log -Message "ERROR stopping service: $svc - $_" -Level "ERROR"
    }
}

# Final summary
if ($failedServices.Count -gt 0) {
    Write-Host "`nSome services failed to stop:" -ForegroundColor Red
    foreach ($svc in $failedServices) {
        Write-Host " - $svc" -ForegroundColor Red
    }
    Write-Log -Message "Some services failed to stop." -Level "ERROR"
} else {
    Write-Host "`n✔️ All services stopped successfully." -ForegroundColor Green
    Write-Log -Message "All services stopped successfully." -Level "INFO"
}

Write-Log -Message "======== Stop Services Script Finished ========" -Level "INFO"
