# ============================================
# 11 - Reindex All Database.ps1
# Description: Executes AXPerf_IndexMaintenance on AxDB (localhost)
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# Updated for PS 5.1 & PS 7+ by PowerShell GPT 
# Logs: C:\Temp\XKTools\Logs\Reindex-AllDatabase.log
# ============================================

# --- Auto-elevate ---
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "⚠ Relaunching script as Administrator..."
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# --- Logging setup ---
$logFolder = "C:\Temp\XKTools\Logs"
$logFile = Join-Path $logFolder "Reindex-AllDatabase.log"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp [INFO] $Message"
}

Write-Log "==== Reindex-AllDatabase Script Execution Started ===="

# --- Hardcoded for AxDB on localhost ---
$serverName = "localhost"
$databaseName = "AxDB"
$connectionString = "Server=$serverName;Database=$databaseName;Integrated Security=True;TrustServerCertificate=True"

Write-Log "Connecting to $serverName | Database: $databaseName"
Write-Log "Using Windows Authentication with trusted certificate"

# --- T-SQL Block ---
$sqlCommand = @"
DECLARE @return_value int;
EXEC @return_value = [dbo].[AXPerf_IndexMaintenance]
    @MAXDURATION = 10,
    @TOPLIMITOFINDEXES = 100,
    @ONLINEDEFRAG = 1,
    @MAXDOP = 1,
    @SCHEMA = N'dbo';
SELECT 'Return Value' = @return_value;
"@

# --- Simulate progress bar ---
function Show-ProgressInline {
    param (
        [int]$Duration = 30,
        [string]$Activity = "Running Index Maintenance"
    )

    $progressID = Get-Random
    for ($i = 1; $i -le $Duration; $i++) {
        $percent = [math]::Round(($i / $Duration) * 100)
        Write-Progress -Id $progressID -Activity $Activity -Status "$percent% Complete..." -PercentComplete $percent
        Start-Sleep -Seconds 1
    }
    Write-Progress -Id $progressID -Activity $Activity -Completed
}

# --- Execute SQL Command ---
try {
    Write-Host "`n⏳ Executing index maintenance on AxDB (timeout set to 60 minutes)..." -ForegroundColor Cyan
    Write-Log "Executing AXPerf_IndexMaintenance with 60-min timeout"

    Show-ProgressInline -Duration 30 -Activity "Preparing execution..."

    $result = Invoke-Sqlcmd -ConnectionString $connectionString -Query $sqlCommand -QueryTimeout 3600

    if ($result) {
        $returnVal = $result.'Return Value'
        Write-Host "`n✅ Procedure completed. Return Value: $returnVal" -ForegroundColor Green
        Write-Log "Stored procedure executed successfully. Return Value: $returnVal"
    } else {
        Write-Host "`n⚠ No return value captured." -ForegroundColor Yellow
        Write-Log "⚠ Procedure executed but returned no output."
    }
}
catch {
    Write-Warning "❌ Error executing stored procedure."
    Write-Log "❌ ERROR: $($_.Exception.Message)"
}

Write-Log "==== Reindex-AllDatabase Script Execution Completed ===="

# --- Return to menu ---
Write-Host "`nPress Enter to return to the menu..."
Read-Host
