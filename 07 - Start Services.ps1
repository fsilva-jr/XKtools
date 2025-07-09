 # ============================================
# XKTools - Start Selected Services (GUI)
# Created by: Francisco Silva
# Updated for PS 5.1 & PS 7+ by PowerShell GPT
# ============================================

# --- Auto-elevate to admin ---
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting as Administrator..." -ForegroundColor Yellow
    $args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

# --- Load required assemblies ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Logging Setup ---
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "StartServices.log"

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

Write-Log -Message "======== Start Services Script Started ========" -Level "INFO"

# --- Services List ---
$services = @(
    "Management Reporter 2012 Process Service",
    "Microsoft Dynamics 365 Unified Operations: Batch Management Service",
    "Microsoft Dynamics 365 Unified Operations: Data Import Export Framework Service",
    "SQL Server Reporting Services",
    "World Wide Web Publishing Service"
)

# --- GUI Form Setup ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "XKTools - Start Services"
$form.Size = New-Object System.Drawing.Size(500, 400)
$form.StartPosition = "CenterScreen"
$form.Topmost = $true

$y = 20
$checkboxes = @()

# --- Label ---
$label = New-Object System.Windows.Forms.Label
$label.Text = "Select services to start:"
$label.Location = New-Object System.Drawing.Point(20, $y)
$label.AutoSize = $true
$form.Controls.Add($label)
$y += 30

# --- Checkboxes ---
foreach ($svc in $services) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $svc
    $cb.Location = New-Object System.Drawing.Point(20, $y)
    $cb.AutoSize = $true
    $form.Controls.Add($cb)
    $checkboxes += $cb
    $y += 30
}

# --- Button ---
$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Start Selected Services"
$startButton.Size = New-Object System.Drawing.Size(200, 30)
$startButton.Location = New-Object System.Drawing.Point(140, ($y + 10))  # ✅ Fixed Point
$form.Controls.Add($startButton)

# --- Button Click Event ---
$startButton.Add_Click({
    $selected = $checkboxes | Where-Object { $_.Checked } | ForEach-Object { $_.Text }

    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one service.", "No Services Selected", 'OK', 'Warning')
        return
    }

    foreach ($svc in $selected) {
        try {
            $service = Get-Service -Name $svc -ErrorAction Stop
            if ($service.Status -ne 'Running') {
                Write-Log -Message "Starting: $svc"
                Start-Service -Name $svc -ErrorAction Stop
                Write-Log -Message "Started: $svc"
            } else {
                Write-Log -Message "Already running: $svc"
            }
        } catch {
            Write-Log -Message ("ERROR starting ${svc}: " + $_.Exception.Message) -Level "ERROR"
        }
    }

    [System.Windows.Forms.MessageBox]::Show("Selected services have been started.", "Done", 'OK', 'Information')
})

# --- Show Form ---
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

Write-Log -Message "======== Start Services Script Finished ========" -Level "INFO"
 
