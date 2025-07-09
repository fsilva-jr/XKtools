 # ============================================
# XKTools - Rename SQL Database via GUI
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

# Add WinForms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Log Setup
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "RenameDatabaseGUI.log"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $entry
}

# SQL Server Connection
$server = "localhost"

# Rename Logic
function Rename-Database {
    param (
        [string]$OldName,
        [string]$NewName
    )

    $connectionString = "Server=$server;Database=master;Integrated Security=True;TrustServerCertificate=True"

    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection $connectionString
        $conn.Open()

        $checkQuery = "SELECT COUNT(*) FROM sys.databases WHERE name = '$OldName'"
        $checkCmd = $conn.CreateCommand()
        $checkCmd.CommandText = $checkQuery
        $exists = $checkCmd.ExecuteScalar()

        if ($exists -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Database '$OldName' does not exist.", "Error", "OK", "Error")
            Write-Log "Database '$OldName' does not exist." "ERROR"
            $conn.Close()
            return
        }

        $renameCmd = $conn.CreateCommand()
        $renameCmd.CommandText = "ALTER DATABASE [$OldName] MODIFY NAME = [$NewName]"
        $renameCmd.ExecuteNonQuery()

        $conn.Close()

        [System.Windows.Forms.MessageBox]::Show("Database renamed from '$OldName' to '$NewName' successfully.", "Success", "OK", "Information")
        Write-Log "Database renamed from '$OldName' to '$NewName'" "INFO"

    } catch {
        Write-Log "Rename failed: $_" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Rename failed:`n$($_.Exception.Message)", "Error", "OK", "Error")
    }
}

# GUI Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "XKTools - Rename SQL Database"
$form.Size = New-Object System.Drawing.Size(400, 220)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

# Label: Current DB
$lblOld = New-Object System.Windows.Forms.Label
$lblOld.Text = "Current DB Name:"
$lblOld.Location = New-Object System.Drawing.Point(20, 30)
$lblOld.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($lblOld)

# TextBox: Old DB Name
$txtOld = New-Object System.Windows.Forms.TextBox
$txtOld.Location = New-Object System.Drawing.Point(150, 27)
$txtOld.Width = 200
$txtOld.Font = New-Object System.Drawing.Font("Microsoft Sans Serif",10)
$txtOld.SelectionStart = 0
$form.Controls.Add($txtOld)

# Label: New DB
$lblNew = New-Object System.Windows.Forms.Label
$lblNew.Text = "New DB Name:"
$lblNew.Location = New-Object System.Drawing.Point(20, 70)
$lblNew.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($lblNew)

# TextBox: New DB Name
$txtNew = New-Object System.Windows.Forms.TextBox
$txtNew.Location = New-Object System.Drawing.Point(150, 67)
$txtNew.Width = 200
$txtNew.Font = New-Object System.Drawing.Font("Microsoft Sans Serif",10)
$txtNew.SelectionStart = 0
$form.Controls.Add($txtNew)

# Rename Button
$btnRename = New-Object System.Windows.Forms.Button
$btnRename.Text = "Rename Database"
$btnRename.Width = 200
$btnRename.Height = 30
$btnRename.Location = New-Object System.Drawing.Point(100, 120)
$btnRename.Add_Click({
    $oldName = $txtOld.Text.Trim()
    $newName = $txtNew.Text.Trim()

    if (-not $oldName -or -not $newName) {
        [System.Windows.Forms.MessageBox]::Show("Please enter both database names.", "Input Required", "OK", "Warning")
        return
    }

    Rename-Database -OldName $oldName -NewName $newName
})
$form.Controls.Add($btnRename)

# Run Form
[void]$form.ShowDialog()
 
