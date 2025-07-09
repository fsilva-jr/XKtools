 # ============================================
# XKTools - Restore BacPac with Full GUI
# Created by: Francisco Silva
# Updated by: PowerShell GPT
# ============================================

# Auto-elevate
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

Add-Type -AssemblyName System.Windows.Forms

# Setup log
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "RestoreBacPac.log"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

Write-Log -Message "======== Restore BacPac Script Started ========"

# Select BacPac file
$bacpacDialog = New-Object System.Windows.Forms.OpenFileDialog
$bacpacDialog.Title = "Select the BacPac File"
$bacpacDialog.Filter = "BacPac Files (*.bacpac)|*.bacpac"

if ($bacpacDialog.ShowDialog() -ne 'OK') {
    [System.Windows.Forms.MessageBox]::Show("No file selected. Operation canceled.","Canceled",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
    Write-Log -Message "User canceled BacPac selection." -Level "WARN"
    exit
}
$bacpacPath = $bacpacDialog.FileName
Write-Log -Message "Selected BacPac: $bacpacPath"

# Prompt for DB Name
$form = New-Object System.Windows.Forms.Form
$form.Text = "Target Database Name"
$form.Size = New-Object System.Drawing.Size(350,150)
$form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Text = "Enter the target database name:"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(10,20)
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Size = New-Object System.Drawing.Size(300,20)
$textBox.Location = New-Object System.Drawing.Point(10,45)
$form.Controls.Add($textBox)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Location = New-Object System.Drawing.Point(110,80)
$okButton.Add_Click({ $form.Tag = $textBox.Text; $form.Close() })
$form.Controls.Add($okButton)

$form.ShowDialog() | Out-Null
$targetDb = $form.Tag

if ([string]::IsNullOrWhiteSpace($targetDb)) {
    [System.Windows.Forms.MessageBox]::Show("No database name provided. Aborting.","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    Write-Log -Message "No target DB name entered." -Level "ERROR"
    exit
}
Write-Log -Message "Target DB Name: $targetDb"

# Confirm
$confirm = [System.Windows.Forms.MessageBox]::Show("Confirm restore of `"$bacpacPath`" to database `"$targetDb`"?","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
    Write-Log -Message "User aborted on confirmation dialog." -Level "WARN"
    exit
}

# Check sqlpackage
$sqlPackageExe = "C:\Temp\sqlpackage\sqlpackage.exe"
if (-not (Test-Path $sqlPackageExe)) {
    [System.Windows.Forms.MessageBox]::Show("sqlpackage.exe not found at $sqlPackageExe","Missing Tool",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    Write-Log -Message "sqlpackage.exe not found at $sqlPackageExe" -Level "ERROR"
    exit
}
Write-Log -Message "sqlpackage.exe located."

# Build args
$targetConn = "Server=localhost;Initial Catalog=$targetDb;Integrated Security=True;TrustServerCertificate=True"
$sqlArgs = "/a:Import /sf:`"$bacpacPath`" /TargetConnectionString:`"$targetConn`" /p:CommandTimeout=12000"

# Run sqlpackage
try {
    Write-Log -Message "Executing sqlpackage.exe for restore..."
    $proc = Start-Process -FilePath $sqlPackageExe -ArgumentList $sqlArgs -Wait -NoNewWindow -PassThru
    if ($proc.ExitCode -eq 0) {
        Write-Log -Message "sqlpackage.exe completed successfully."
        $success = $true
    } else {
        Write-Log -Message "sqlpackage.exe exited with code $($proc.ExitCode)" -Level "ERROR"
        $success = $false
    }
} catch {
    Write-Log -Message "Exception during sqlpackage execution: $_" -Level "ERROR"
    $success = $false
}

# Set recovery model
if ($success) {
    try {
        Write-Log -Message "Setting recovery model to SIMPLE..."
        $sql = "ALTER DATABASE [$targetDb] SET RECOVERY SIMPLE;"
        Invoke-Sqlcmd -ServerInstance "localhost" -Query $sql -ErrorAction Stop
        Write-Log -Message "Recovery model changed successfully."
    } catch {
        Write-Log -Message "Failed to set recovery model: $_" -Level "WARN"
    }
}

# Final popup
if ($success) {
    [System.Windows.Forms.MessageBox]::Show("✔️ BacPac restored successfully to $targetDb.","Success",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
} else {
    [System.Windows.Forms.MessageBox]::Show("❌ BacPac restore failed. See log for details.","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
}

Write-Log -Message "======== Restore BacPac Script Finished ========"
 
