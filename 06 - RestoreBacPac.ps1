 # ============================================
# XKTools - Rename SQL Database with Logging
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# Updated for PS 5.1 & PS 7+ by PowerShell GPT
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
$logFile = Join-Path $logFolder "RenameDatabase.log"

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

Write-Log -Message "======== Rename Database Script Started ========" -Level "INFO"

$server = "localhost"
$connectionString = "Server=$server;Database=master;Integrated Security=True;TrustServerCertificate=True"

# Check if AxDB exists
Write-Log -Message "Checking for AxDB existence..." -Level "INFO"
$axdbCheckQuery = "SELECT COUNT(*) FROM sys.databases WHERE name = 'AxDB'"

try {
    $conn = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $axdbCheckQuery
    $conn.Open()
    $axdbExists = $cmd.ExecuteScalar()
    $conn.Close()
} catch {
    Write-Log -Message ("Error checking AxDB existence: " + $_.Exception.Message) -Level "ERROR"
    exit 1
}

if ($axdbExists -eq 0) {
    Write-Log -Message "AxDB database does not exist." -Level "WARN"
    $continueWithoutAxDB = Read-Host "AxDB database was not found. Do you want to continue anyway? (Y/N)"
    if ($continueWithoutAxDB.ToUpper() -ne "Y") {
        Write-Log -Message "User chose to exit because AxDB does not exist." -Level "WARN"
        exit 0
    } else {
        Write-Log -Message "User chose to continue even without AxDB." -Level "INFO"
    }
}

Write-Log -Message "Proceeding with rename process." -Level "INFO"

# Get current database name
do {
    $oldDbName = Read-Host "Enter the name of the database you want to rename"
    $checkQuery = "SELECT COUNT(*) FROM sys.databases WHERE name = '$oldDbName'"

    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection $connectionString
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $checkQuery
        $conn.Open()
        $dbExists = $cmd.ExecuteScalar()
        $conn.Close()
    } catch {
        Write-Log -Message ("Error checking database existence: " + $_.Exception.Message) -Level "ERROR"
        exit 1
    }

    if ($dbExists -eq 0) {
        Write-Log -Message "Database '$oldDbName' does not exist. Asking user again..." -Level "WARN"
        Write-Host "Database '$oldDbName' does not exist. Please enter a valid database name." -ForegroundColor Yellow
    }
} until ($dbExists -ne 0)

# Get new database name
$newDbName = Read-Host "Enter the new name for the database"
if ([string]::IsNullOrWhiteSpace($newDbName)) {
    Write-Log -Message "No new name provided. Aborting." -Level "ERROR"
    exit 1
}
Write-Log -Message "Renaming database from '$oldDbName' to '$newDbName'" -Level "INFO"

$renameSql = "ALTER DATABASE [$oldDbName] MODIFY NAME = [$newDbName];"

function Try-RenameDatabase {
    try {
        Invoke-Sqlcmd -ServerInstance $server -Query $renameSql -ErrorAction Stop
        Write-Host "Database renamed from '$oldDbName' to '$newDbName' successfully." -ForegroundColor Green
        Write-Log -Message "Database renamed successfully." -Level "INFO"
        return $true
    } catch {
        Write-Host ("Rename failed: " + $_.Exception.Message) -ForegroundColor Red
        Write-Log -Message ("Rename failed: " + $_.Exception.Message) -Level "ERROR"
        return $false
    }
}

$renamed = Try-RenameDatabase

# If rename failed, suggest actions
if (-not $renamed) {
    $stopServicesScript = "C:\Temp\XKTools\01 - Stop Services.ps1"

    $runStop = Read-Host "Do you want to run the '01 - Stop Services.ps1' to release locks? (Y/N)"
    if ($runStop.ToUpper() -eq "Y" -and (Test-Path $stopServicesScript)) {
        Write-Log -Message "Running Stop Services script..." -Level "INFO"
        & $stopServicesScript
    }

    # List active sessions
    $sessionQuery = @"
SELECT session_id, login_name, host_name, program_name, status
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID('$oldDbName') AND session_id <> @@SPID
"@

    $runKill = Read-Host "Do you want to view and kill active sessions on '$oldDbName'? (Y/N)"
    if ($runKill.ToUpper() -eq "Y") {
        try {
            $sessions = Invoke-Sqlcmd -ServerInstance $server -Query $sessionQuery
            if ($sessions.Count -eq 0) {
                Write-Host "No active sessions found." -ForegroundColor Yellow
                Write-Log -Message "No active sessions found on '$oldDbName'." -Level "INFO"
            } else {
                Write-Host "`nActive sessions:" -ForegroundColor Cyan
                $sessions | Format-Table session_id, login_name, host_name, program_name, status

                $killAll = Read-Host "Do you want to kill all sessions? (Y/N)"
                if ($killAll.ToUpper() -eq "Y") {
                    foreach ($session in $sessions) {
                        $spid = $session.session_id
                        try {
                            Invoke-Sqlcmd -ServerInstance $server -Query "KILL $spid"
                            Write-Host "Killed session ID $spid" -ForegroundColor Green
                            Write-Log -Message "Killed session ID $spid" -Level "INFO"
                        } catch {
                            Write-Host ("Failed to kill session ID " + $spid + ": " + $_.Exception.Message) -ForegroundColor Red
                            Write-Log -Message ("Failed to kill session ID " + $spid + ": " + $_.Exception.Message) -Level "ERROR"
                        }
                    }
                } else {
                    $spid = Read-Host "Enter the SPID of the session you want to kill"
                    if ($spid -match '^\d+$') {
                        try {
                            Invoke-Sqlcmd -ServerInstance $server -Query "KILL $spid"
                            Write-Host "Killed session ID $spid" -ForegroundColor Green
                            Write-Log -Message "Killed session ID $spid" -Level "INFO"
                        } catch {
                            Write-Host ("Failed to kill session ID " + $spid + ": " + $_.Exception.Message) -ForegroundColor Red
                            Write-Log -Message ("Failed to kill session ID " + $spid + ": " + $_.Exception.Message) -Level "ERROR"
                        }
                    } else {
                        Write-Host "Invalid SPID." -ForegroundColor Yellow
                        Write-Log -Message "User entered invalid SPID: $spid" -Level "WARN"
                    }
                }
            }
        } catch {
            Write-Log -Message ("Error retrieving sessions: " + $_.Exception.Message) -Level "ERROR"
            Write-Host ("Error retrieving sessions: " + $_.Exception.Message) -ForegroundColor Red
        }
    }

    $retry = Read-Host "Do you want to retry renaming the database now? (Y/N)"
    if ($retry.ToUpper() -eq "Y") {
        Write-Log -Message "Retrying database rename..." -Level "INFO"
        $renamed = Try-RenameDatabase
        if (-not $renamed) {
            Write-Log -Message "Retry rename failed. User should check for locks." -Level "ERROR"
            Write-Host "Rename failed again. Please ensure the database is not in use." -ForegroundColor Red
        }
    } else {
        Write-Log -Message "User chose not to retry rename." -Level "WARN"
        Write-Host "Rename skipped by user." -ForegroundColor Yellow
    }
}

Write-Log -Message "======== Script Finished ========" -Level "INFO"
 
