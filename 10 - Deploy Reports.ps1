 # ============================================
# Deploy-D365Reports.ps1
# Author: Francisco Silva + PowerShell GPT
# Contact: francisco@mtxn.com.br
# Logs actions to: C:\Temp\XKTools\Logs\Deploy-D365Reports.log
# ============================================

# --- Ensure script is running as Administrator ---
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "❗ This script must be run as Administrator. Relaunching..."
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# --- Setup logging ---
$logFolder = "C:\Temp\XKTools\Logs"
$logFile   = Join-Path $logFolder "Deploy-D365Reports.log"

if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp [INFO] $Message"
}

Write-Log "==== Deploy-D365Reports.ps1 Execution Started ===="

# --- Ask for AosService drive letter and validate ---
do {
    $driveLetter = Read-Host "Enter the drive letter where AosService is mounted (e.g. J)"
    $driveLetter = $driveLetter.ToUpper()
    $aosPath = "$driveLetter`:\AosService"

    if (-not $driveLetter -or $driveLetter.Length -ne 1) {
        Write-Host "❌ Invalid input. Please enter a single drive letter (A–Z)." -ForegroundColor Red
        continue
    }

    if (-not (Test-Path $aosPath)) {
        Write-Host "❌ Folder '$aosPath' does not exist. Please enter the correct drive letter." -ForegroundColor Red
    }
} while (-not (Test-Path $aosPath))

Write-Log "Validated AosService path: $aosPath"

# --- Ask user what to deploy ---
$deployAll = Read-Host "Do you want to deploy ALL D365F&O reports? (Y/N)"
Write-Log "User chose to deploy all: $deployAll"

$scriptBase = "$driveLetter`:\AosService\PackagesLocalDirectory\Plugins\AxReportVmRoleStartupTask\DeployAllReportsToSSRS.ps1"
$packagePath = "$driveLetter`:\AosService\PackagesLocalDirectory"

if ($deployAll -match '^(Y|YES)$') {
    # --- Deploy all reports ---
    Write-Host "`n▶ Deploying ALL reports..." -ForegroundColor Yellow
    Write-Log "Executing full report deployment:"
    Write-Log "Command: `"$scriptBase`" -PackageInstallLocation `"$packagePath`""

    try {
        & $scriptBase -PackageInstallLocation $packagePath
        Write-Log "✅ Deployment completed successfully."
    }
    catch {
        Write-Warning "❌ Error during deployment."
        Write-Log "❌ ERROR: $($_.Exception.Message)"
    }
}
elseif ($deployAll -match '^(N|NO)$') {
    # --- Deploy specific report with retry ---
    do {
        $modelName = Read-Host "Enter the model name that contains the report (e.g. ApplicationSuite, MyCustomModel)"
        Write-Log "User entered model name: $modelName"

        if (-not $modelName) {
            Write-Host "❌ Model name cannot be empty. Please try again." -ForegroundColor Red
            Write-Log "Model name was empty. Retrying..."
            $success = $false
            continue
        }

        $reportName = Read-Host "Enter the name of the report to deploy (e.g. EDCLedgerJournalCollectionReport)"
        Write-Log "User entered report name: $reportName"

        if (-not $reportName) {
            Write-Host "❌ Report name cannot be empty. Please try again." -ForegroundColor Red
            Write-Log "Report name was empty. Retrying..."
            $success = $false
            continue
        }

        $fullReport = "$reportName.Report"
        Write-Host "`n▶ Deploying report: $fullReport from model: $modelName" -ForegroundColor Yellow
        Write-Log "Attempting deployment:"
        Write-Log "Command: `"$scriptBase`" -Module `"$modelName`" -ReportName `"$fullReport`" -PackageInstallLocation `"$packagePath`""

        try {
            & $scriptBase -Module $modelName -ReportName $fullReport -PackageInstallLocation $packagePath
            Write-Log "✅ Report '$fullReport' from model '$modelName' deployed successfully."
            $success = $true
        }
        catch {
            Write-Warning "❌ Error deploying '$fullReport' from model '$modelName'. Try again."
            Write-Log "❌ ERROR deploying '$fullReport' from '$modelName': $($_.Exception.Message)"
            $success = $false
        }

    } while (-not $success)
}
else {
    Write-Host "❌ Invalid choice. Please answer Y or N. Exiting..." -ForegroundColor Red
    Write-Log "Invalid response to deploy all question. Script terminated."
    exit
}

Write-Host "`n✅ Done." -ForegroundColor Green
Write-Log "==== Deploy-D365Reports.ps1 Execution Completed ===="

# --- Wait for user before returning to menu ---
Write-Host "`nPress Enter to return to the menu..."
Read-Host
