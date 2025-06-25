# ============================================
# XKTools - Compile All Models (Simplified)
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# ============================================

# Auto-elevate if not administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script as Administrator..." -ForegroundColor Yellow
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# Setup log
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}
$logFile = Join-Path $logFolder "CompileAllModels.log"

# Logging function
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Level] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry -Encoding UTF8
}

Write-Log -Message "======== Compile Models Script Started ========" -Level "INFO"

# Ensure d365fo.tools is installed
if (-not (Get-Module -ListAvailable -Name D365FO.Tools)) {
    Write-Log -Message "Installing D365FO.Tools module..." -Level "INFO"
    try {
        Install-Module -Name D365FO.Tools -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Log -Message "D365FO.Tools installed successfully." -Level "INFO"
    } catch {
        Write-Log -Message "Failed to install D365FO.Tools: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
} else {
    Write-Log -Message "D365FO.Tools already available." -Level "INFO"
}

# Import module
try {
    Import-Module D365FO.Tools -Force -ErrorAction Stop
    Write-Log -Message "D365FO.Tools imported successfully." -Level "INFO"
} catch {
    Write-Log -Message "Failed to import D365FO.Tools: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# Ask user
$confirmation = Read-Host "Do you want to compile ALL models now? (Y/N)"
if ($confirmation.ToUpper() -ne "Y") {
    Write-Log -Message "User declined compilation. Exiting..." -Level "WARN"
    Write-Host "Compilation cancelled by user." -ForegroundColor Yellow
    exit 0
}

# Run full compilation by dependency order
try {
    Write-Log -Message "Starting full compile using Get-D365Module -InDependencyOrder..." -Level "INFO"
    Get-D365Module -InDependencyOrder | Invoke-D365ModuleFullCompile -ErrorAction Stop -Verbose 4>&1 | ForEach-Object {
        Write-Log -Message $_ -Level "INFO"
    }
    Write-Log -Message "✅ Full compile completed successfully." -Level "INFO"
    Write-Host "`n✔️ Full compile completed!" -ForegroundColor Green
} catch {
    Write-Log -Message "❌ Compile failed: $($_.Exception.Message)" -Level "ERROR"
    Write-Host "❌ Compile failed. See log for details." -ForegroundColor Red
    exit 1
}

Write-Log -Message "======== Script Finished ========" -Level "INFO"
