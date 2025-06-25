# ============================================
# Sync Database Script with Real-Time Logging
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# ============================================

# --- Auto-elevate if not running as admin ---
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script as Administrator..." -ForegroundColor Yellow
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# --- Setup Logging ---
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}
$logFile = Join-Path $logFolder "SyncDatabase.log"
$syncOutputPath = "C:\Temp\DatabaseSync.log"
if (Test-Path $syncOutputPath) { Remove-Item $syncOutputPath -Force }

function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [INFO] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

Write-Log "======== Database Sync Script Started ========"

# --- Ask user for drive letter ---
do {
    $driveLetter = Read-Host "What is the Service Directory Letter? (only 1 letter)"

    if ($driveLetter -notmatch '^[a-zA-Z]$') {
        Write-Host "❌ Invalid input. Please enter only a single letter." -ForegroundColor Red
        $isValid = $false
        continue
    }

    $driveLetter = $driveLetter.ToUpper()
    $driveExists = Test-Path "${driveLetter}:\"

    if (-not $driveExists) {
        Write-Host "❌ Drive '${driveLetter}:\' does not exist on this machine." -ForegroundColor Red
        $isValid = $false
    } else {
        $isValid = $true
        Write-Log "User selected valid drive: $driveLetter"
    }
} until ($isValid)

# --- Build paths ---
$syncExePath  = "${driveLetter}:\AOSService\PackagesLocalDirectory\bin\SyncEngine.exe"
$metadataPath = "${driveLetter}:\AOSService\PackagesLocalDirectory"

if (-not (Test-Path $syncExePath)) {
    Write-Log "❌ SyncEngine.exe not found at: $syncExePath"
    Write-Host "❌ SyncEngine.exe not found. Please check your input." -ForegroundColor Red
    exit 1
}

Write-Host "`n▶ Starting database sync..." -ForegroundColor Cyan
Write-Log "Launching SyncEngine: $syncExePath"

# --- Start SyncEngine process with monitoring ---
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $syncExePath
$startInfo.Arguments = "-syncmode=fullall -metadatabinaries=`"$metadataPath`" -connect=`"Data Source=localhost;Initial Catalog=AxDB;Integrated Security=True;Enlist=True;Application Name=SyncEngine`" -fallbacktonative=False -raiseDataEntityViewSyncNotification"
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError  = $true
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo

# --- Start process ---
$null = $process.Start()

# --- Monitor STDOUT ---
while (-not $process.StandardOutput.EndOfStream) {
    $line = $process.StandardOutput.ReadLine()
    Write-Host $line
    Add-Content -Path $syncOutputPath -Value $line
}

# --- Monitor STDERR ---
while (-not $process.StandardError.EndOfStream) {
    $errorLine = $process.StandardError.ReadLine()
    Write-Host $errorLine -ForegroundColor Red
    Add-Content -Path $syncOutputPath -Value $errorLine
}

$process.WaitForExit()

if ($process.ExitCode -eq 0) {
    Write-Log "✅ Sync completed successfully."
    Write-Host "✅ Sync finished without errors." -ForegroundColor Green
} else {
    Write-Log "❌ Sync failed with exit code: $($process.ExitCode)"
    Write-Host "❌ Sync failed. Exit code: $($process.ExitCode)" -ForegroundColor Red
}

Write-Log "======== Database Sync Script Finished ========"
