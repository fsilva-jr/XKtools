 # ============================================
# XKTools - Reindex All Database with GUI + Logging
# Author: Francisco Silva + PowerShell GPT
# ============================================

# --- Auto-elevate ---
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# --- Load required types ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Logging Setup ---
$logFolder = "C:\Temp\XKTools\Logs"
$logFile   = Join-Path $logFolder "Reindex-AllDatabase.log"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp [INFO] $Message" -Encoding UTF8
}

Write-Log "==== Reindex-AllDatabase Script Started ===="

# --- SQL Settings ---
$serverName = "localhost"
$databaseName = "AxDB"
$connectionString = "Server=$serverName;Database=$databaseName;Integrated Security=True;TrustServerCertificate=True"

Write-Log "Connecting to $serverName | Database: $databaseName"

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

# --- GUI Progress Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Reindex AxDB"
$form.Size = New-Object System.Drawing.Size(400,130)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Text = "Running AXPerf_IndexMaintenance..."
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(20,20)
$form.Controls.Add($label)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Style = 'Marquee'
$progressBar.MarqueeAnimationSpeed = 30
$progressBar.Size = New-Object System.Drawing.Size(340,20)
$progressBar.Location = New-Object System.Drawing.Point(20,50)
$form.Controls.Add($progressBar)

$formShown = $false
$job = Start-Job -ScriptBlock {
    param($conn, $query)
    Import-Module SqlServer -DisableNameChecking
    Invoke-Sqlcmd -ConnectionString $conn -Query $query -QueryTimeout 3600
} -ArgumentList $connectionString, $sqlCommand

# Timer to check completion
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    if ($job.State -ne 'Running') {
        $timer.Stop()
        $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job $job

        $returnVal = $null
        if ($result) {
            $returnVal = $result.'Return Value'
            Write-Log "Procedure executed. Return Value: $returnVal"
            [System.Windows.Forms.MessageBox]::Show("✅ Procedure completed.`nReturn Value: $returnVal", "Success", 'OK', 'Information')
        } else {
            Write-Log "⚠ No return value from procedure."
            [System.Windows.Forms.MessageBox]::Show("⚠ Procedure ran but returned no value.", "Warning", 'OK', 'Warning')
        }
        $form.Close()
    }
})

$form.Add_Shown({ if (-not $formShown) { $formShown = $true; $timer.Start() } })
[void]$form.ShowDialog()

Write-Log "==== Reindex-AllDatabase Script Completed ===="
 
