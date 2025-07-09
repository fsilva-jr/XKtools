 # ============================================
# XKTools - Sync Database with GUI & Real-Time Output
# Created by: Francisco Silva
# Updated by: PowerShell GPT
# ============================================

# Auto-elevate to admin
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Log Setup ---
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
    Add-Content -Path $logFile -Value $entry
}

Write-Log "======== Database Sync Script Started ========"

# --- GUI for Drive Letter Selection ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Select Service Drive"
$form.Size = New-Object System.Drawing.Size(400,160)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Text = "Select the drive letter for AOSService:"
$label.Location = New-Object System.Drawing.Point(20,20)
$label.Size = New-Object System.Drawing.Size(340,20)
$form.Controls.Add($label)

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(20,50)
$comboBox.Size = New-Object System.Drawing.Size(80,25)
$comboBox.DropDownStyle = 'DropDownList'
$comboBox.Items.AddRange([System.IO.DriveInfo]::GetDrives().Name)
$form.Controls.Add($comboBox)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "Start Sync"
$okButton.Location = New-Object System.Drawing.Point(120, 90)
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Location = New-Object System.Drawing.Point(220, 90)
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$dialogResult = $form.ShowDialog()

if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or -not $comboBox.SelectedItem) {
    Write-Log "User canceled drive selection. Aborting."
    exit
}

$driveLetter = $comboBox.SelectedItem.ToString().Substring(0,1).ToUpper()
Write-Log "Selected drive letter: $driveLetter"

# --- Paths ---
$syncExePath  = "${driveLetter}:\AOSService\PackagesLocalDirectory\bin\SyncEngine.exe"
$metadataPath = "${driveLetter}:\AOSService\PackagesLocalDirectory"

if (-not (Test-Path $syncExePath)) {
    [System.Windows.Forms.MessageBox]::Show("❌ SyncEngine.exe not found at:`n$syncExePath","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    Write-Log "SyncEngine.exe not found at: $syncExePath"
    exit
}

# --- Real-Time Output Form ---
$outputForm = New-Object System.Windows.Forms.Form
$outputForm.Text = "⏳ Syncing Database..."
$outputForm.Size = New-Object System.Drawing.Size(800,500)
$outputForm.StartPosition = "CenterScreen"
$outputForm.TopMost = $true

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.Location = New-Object System.Drawing.Point(10,10)
$outputBox.Size = New-Object System.Drawing.Size(765,420)
$outputBox.ReadOnly = $true
$outputForm.Controls.Add($outputBox)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "Close"
$closeBtn.Enabled = $false
$closeBtn.Location = New-Object System.Drawing.Point(650, 440)
$closeBtn.Add_Click({ $outputForm.Close() })
$outputForm.Controls.Add($closeBtn)

# --- Start Sync Process ---
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $syncExePath
$startInfo.Arguments = "-syncmode=fullall -metadatabinaries=`"$metadataPath`" -connect=`"Data Source=localhost;Initial Catalog=AxDB;Integrated Security=True;Enlist=True;Application Name=SyncEngine`" -fallbacktonative=False -raiseDataEntityViewSyncNotification"
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
$null = $process.Start()

# --- Async Monitoring Output ---
$stdoutReader = {
    while (-not $process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        Write-Log $line
        $syncOutputPath | Add-Content -Value $line
        $outputForm.Invoke([Action]{
            $outputBox.AppendText($line + "`r`n")
        })
    }
}
$stderrReader = {
    while (-not $process.StandardError.EndOfStream) {
        $line = $process.StandardError.ReadLine()
        Write-Log "STDERR: $line"
        $syncOutputPath | Add-Content -Value $line
        $outputForm.Invoke([Action]{
            $outputBox.AppendText("ERROR: $line`r`n")
        })
    }
}
Start-Job $stdoutReader | Out-Null
Start-Job $stderrReader | Out-Null

# --- Wait for Sync to Complete ---
Register-ObjectEvent -InputObject $process -EventName Exited -Action {
    $process.Dispose()
    $outputForm.Invoke([Action]{
        $outputBox.AppendText("`r`n✅ Sync completed.`r`n")
        $closeBtn.Enabled = $true
    })
} | Out-Null

$outputForm.ShowDialog()

Write-Log "======== Sync Script Finished ========"
