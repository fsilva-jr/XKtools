# ============================================
# XKTools - Start Services with Logging
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# ============================================

# Auto-elevate to admin
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script as Administrator with ExecutionPolicy Bypass..." -ForegroundColor Yellow
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# Setup log
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "StartServices.log"

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

Write-Log -Message "======== Start Services Script Started ========" -Level "INFO"

# List of services to start
$services = @(
    "Management Reporter 2012 Process Service",
    "Microsoft Dynamics 365 Unified Operations: Batch Management Service",
    "Microsoft Dynamics 365 Unified Operations: Data Import Export Framework Service",
    "SQL Server Reporting Services",
    "World Wide Web Publishing Service"
)

# Ensure no duplicate entries
$services = $services | Sort-Object -Unique

$failedServices = @()

foreach ($service in $services) {
    Write-Host "`nStarting service: $service" -ForegroundColor Cyan
    Write-Log -Message "Attempting to start service: $service" -Level "INFO"

    try {
        Start-Service -Name $service -ErrorAction Stop
        Start-Sleep -Seconds 2

        # Check status
        $status = (Get-Service -Name $service).Status
        if ($status -eq 'Running') {
            Write-Host "Service '$service' started successfully." -ForegroundColor Green
            Write-Log -Message "Service '$service' started successfully." -Level "INFO"
        } else {
            Write-Warning "Service '$service' did not reach Running state."
            Write-Log -Message "Service '$service' failed to reach Running state." -Level "WARN"
            $failedServices += $service
        }
    } catch {
        Write-Warning "Error starting service '$service': $($_.Exception.Message)"
        Write-Log -Message ("Error starting service '$service': " + $_.Exception.Message) -Level "ERROR"
        $failedServices += $service
    }
}

# Final summary
if ($failedServices.Count -eq 0) {
    Write-Host "`n✅ All services started successfully." -ForegroundColor Green
    Write-Log -Message "All services started successfully." -Level "INFO"
} else {
    Write-Host "`n❌ Some services failed to start:" -ForegroundColor Red
    Write-Log -Message "Some services failed to start." -Level "ERROR"
    foreach ($failed in $failedServices) {
        Write-Host "- $failed" -ForegroundColor Red
        Write-Log -Message "Service failed: $failed" -Level "ERROR"
    }
}

Write-Log -Message "======== Start Services Script Finished ========" -Level "INFO"
