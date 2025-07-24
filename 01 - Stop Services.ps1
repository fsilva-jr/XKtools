# ============================================
# Stop Services Script - Versão com Logging Avançado
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# Updated for PS 5.1 & PS 7+ by PowerShell GPT
# ============================================

# Auto-elevate to admin
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# Setup de diretórios e log
$scriptName = "StopServices"
$logFolder = "C:\Temp\XKTools\Logs"

if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

$logFile = Join-Path $logFolder "$scriptName.log"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

Write-Log -Message "======== Stop Services Script Started ========" -Level "INFO"

# Lista de serviços a parar
$services = @(
    "Management Reporter 2012 Process Service",
    "Microsoft Dynamics 365 Unified Operations: Batch Management Service",
    "Microsoft Dynamics 365 Unified Operations: Data Import Export Framework Service",
    "SQL Server Reporting Services",
    "World Wide Web Publishing Service"
)

# Remover duplicados
$services = $services | Sort-Object -Unique

foreach ($svc in $services) {
    try {
        $serviceObj = Get-Service -Name $svc -ErrorAction Stop

        if ($serviceObj.Status -ne 'Stopped') {
            Write-Host "Stopping service: $svc" -ForegroundColor Yellow
            Write-Log -Message "Stopping service: $svc" -Level "INFO"

            Stop-Service -Name $svc -Force -ErrorAction Stop

            Write-Log -Message "SUCCESS: Service stopped - $svc" -Level "INFO"
        }
        else {
            Write-Log -Message "Service already stopped: $svc" -Level "WARN"
        }
    }
    catch {
        Write-Warning "❌ Failed to stop service: $svc"
        Write-Log -Message "ERROR stopping service: $svc - $_" -Level "ERROR"
    }
}

Write-Host "`n✔️ Service stop routine completed." -ForegroundColor Cyan
Write-Log -Message "======== Stop Services Script Finished ========" -Level "INFO"
