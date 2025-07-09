 # ============================================
# XKTools - Compile All Models (GUI + Logging)
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# Updated for PS 5.1 & PS 7+ by PowerShell GPT
# ============================================

# Auto-elevate
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {

    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        $psPath = $pwshCmd.Source
    } else {
        $psPath = "powershell"
    }

    Write-Host "Restarting script as Administrator..." -ForegroundColor Yellow
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process $psPath -Verb RunAs -ArgumentList $args
    exit
}

# Load GUI support
Add-Type -AssemblyName System.Windows.Forms

# Setup log
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}
$logFile = Join-Path $logFolder "CompileAllModels.log"

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

# Confirm using GUI
$response = [System.Windows.Forms.MessageBox]::Show(
    "Do you want to compile ALL models now?",
    "XKTools - Compile Models",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
)

if ($response -ne [System.Windows.Forms.DialogResult]::Yes) {
    Write-Log -Message "User cancelled compilation." -Level "WARN"
    [System.Windows.Forms.MessageBox]::Show("Compilation cancelled by user.","XKTools", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    exit
}

# Ensure module
if (-not (Get-Module -ListAvailable -Name D365FO.Tools)) {
    Write-Log -Message "Installing D365FO.Tools module..." -Level "INFO"
    try {
        Install-Module -Name D365FO.Tools -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Log -Message "D365FO.Tools installed successfully." -Level "INFO"
    } catch {
        Write-Log -Message "❌ Failed to install D365FO.Tools: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Failed to install D365FO.Tools.`n$($_.Exception.Message)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
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
    Write-Log -Message "❌ Failed to import D365FO.Tools: $($_.Exception.Message)" -Level "ERROR"
    [System.Windows.Forms.MessageBox]::Show("Failed to import D365FO.Tools.`n$($_.Exception.Message)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

# Run full compilation
try {
    Write-Log -Message "🛠 Running full model compilation..." -Level "INFO"
    Get-D365Module -InDependencyOrder | Invoke-D365ModuleFullCompile -ErrorAction Stop -Verbose 4>&1 | ForEach-Object {
        Write-Log -Message $_ -Level "INFO"
    }
    Write-Log -Message "✅ Compilation finished successfully." -Level "INFO"
    [System.Windows.Forms.MessageBox]::Show("✔️ Compilation of all models completed successfully.","Success",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
} catch {
    Write-Log -Message "❌ Compilation failed: $($_.Exception.Message)" -Level "ERROR"
    [System.Windows.Forms.MessageBox]::Show("Compilation failed.`n$($_.Exception.Message)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

Write-Log -Message "======== Script Finished ========" -Level "INFO"
 
