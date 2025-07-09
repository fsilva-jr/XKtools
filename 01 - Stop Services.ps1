 Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === Auto-elevate to admin ===
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# === Logging Setup ===
$scriptName = "StopServices"
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "$scriptName.log"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

Write-Log -Message "======== Stop Services GUI Script Started ========"

# === Services List ===
$services = @(
    "Management Reporter 2012 Process Service",
    "Microsoft Dynamics 365 Unified Operations: Batch Management Service",
    "Microsoft Dynamics 365 Unified Operations: Data Import Export Framework Service",
    "SQL Server Reporting Services",
    "World Wide Web Publishing Service"
) | Sort-Object -Unique

# === GUI Setup ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "Stop Services Tool"
$form.Size = New-Object System.Drawing.Size(500, 400)
$form.StartPosition = "CenterScreen"

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(20, 20)
$checkedListBox.Size = New-Object System.Drawing.Size(440, 250)
$checkedListBox.CheckOnClick = $true
$services | ForEach-Object { [void]$checkedListBox.Items.Add($_) }
$form.Controls.Add($checkedListBox)

$selectAllBtn = New-Object System.Windows.Forms.Button
$selectAllBtn.Text = "Select All"
$selectAllBtn.Size = New-Object System.Drawing.Size(100, 30)
$selectAllBtn.Location = New-Object System.Drawing.Point(20, 280)
$selectAllBtn.Add_Click({
    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
        $checkedListBox.SetItemChecked($i, $true)
    }
})
$form.Controls.Add($selectAllBtn)

$stopBtn = New-Object System.Windows.Forms.Button
$stopBtn.Text = "Stop Selected Services"
$stopBtn.Size = New-Object System.Drawing.Size(200, 30)
$stopBtn.Location = New-Object System.Drawing.Point(130, 280)
$stopBtn.BackColor = [System.Drawing.Color]::LightCoral
$form.Controls.Add($stopBtn)

$exitBtn = New-Object System.Windows.Forms.Button
$exitBtn.Text = "Exit"
$exitBtn.Size = New-Object System.Drawing.Size(80, 30)
$exitBtn.Location = New-Object System.Drawing.Point(350, 280)
$exitBtn.Add_Click({ $form.Close() })
$form.Controls.Add($exitBtn)

# === Event: Stop Services ===
$stopBtn.Add_Click({
    $selected = @()
    foreach ($index in $checkedListBox.CheckedIndices) {
        $selected += $checkedListBox.Items[$index]
    }

    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one service.", "No Services Selected", 'OK', 'Warning')
        return
    }

    Write-Log -Message "User selected $($selected.Count) service(s) to stop."

    $stopped = 0
    $failed  = 0
    foreach ($svc in $selected) {
        try {
            $serviceObj = Get-Service | Where-Object { $_.DisplayName -eq $svc }
            if (-not $serviceObj) {
                Write-Log -Message "WARN: Service not found: $svc" -Level "WARN"
                $failed++
                continue
            }

            if ($serviceObj.Status -ne 'Stopped') {
                Stop-Service -Name $serviceObj.Name -Force -ErrorAction Stop
                Write-Log -Message "SUCCESS: Stopped service: $svc"
                $stopped++
            } else {
                Write-Log -Message "SKIPPED (already stopped): $svc"
            }
        }
        catch {
            Write-Log -Message "ERROR: Failed to stop $svc - $_" -Level "ERROR"
            $failed++
        }
    }

    $msg = "✅ Services Stopped: $stopped`n❌ Failed: $failed"
    [System.Windows.Forms.MessageBox]::Show($msg, "Service Stop Result", 'OK', 'Information')
})

# === Run GUI ===
[void]$form.ShowDialog()

Write-Log -Message "======== Stop Services GUI Script Finished ========"
 
