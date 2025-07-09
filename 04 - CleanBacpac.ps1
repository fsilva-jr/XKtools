 # ===============================
# XKTools - Clean BacPac Utility
# Created by: Francisco Silva
# Updated by: PowerShell GPT
# ===============================

# === Hide Console Window ===
$hwnd = Get-Process -Id $PID | ForEach-Object { $_.MainWindowHandle }
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
[Win32]::ShowWindow($hwnd, 0)  # 0 = Hide, 1 = Show

# === Auto-elevate to Admin ===
if (-not ([Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $script = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $script -WindowStyle Hidden
    exit
}

# === Add GUI support ===
Add-Type -AssemblyName System.Windows.Forms

# === Logging Setup ===
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory | Out-Null }
$logFile = Join-Path $logFolder "CleanBacPac.log"
if (Test-Path $logFile) { Remove-Item $logFile -Force }

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $line
}

Write-Log "=== BacPac Cleanup Script Started ==="

try {
    # === Ensure D365FO.Tools module ===
    if (-not (Get-Module -ListAvailable -Name D365FO.Tools)) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Module 'D365FO.Tools' is required. Install now?",
            "Module Required",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($result -eq 'Yes') {
            try {
                Install-Module -Name D365FO.Tools -Scope CurrentUser -Force -AllowClobber
                Write-Log "D365FO.Tools module installed."
            } catch {
                Write-Log "Failed to install D365FO.Tools: $_" -Level "ERROR"
                [System.Windows.Forms.MessageBox]::Show("Error installing D365FO.Tools.`n$_", "ERROR")
                exit
            }
        } else {
            Write-Log "User declined to install module." -Level "ERROR"
            exit
        }
    }
    Import-Module D365FO.Tools -Force
    Write-Log "D365FO.Tools module imported."

    # === Step 1: BacPac file ===
    $bacpacDialog = New-Object System.Windows.Forms.OpenFileDialog
    $bacpacDialog.Title = "Select the BacPac File"
    $bacpacDialog.Filter = "BACPAC Files (*.bacpac)|*.bacpac"
    if ($bacpacDialog.ShowDialog() -ne 'OK') {
        Write-Log "No BacPac selected." -Level "WARN"
        exit
    }
    $bacpacFile = $bacpacDialog.FileName
    Write-Log "Selected BacPac: $bacpacFile"

    # === Step 2: TXT with table names ===
    $txtDialog = New-Object System.Windows.Forms.OpenFileDialog
    $txtDialog.Title = "Select TXT with Table Names to Clear"
    $txtDialog.Filter = "TXT Files (*.txt)|*.txt"
    if ($txtDialog.ShowDialog() -ne 'OK') {
        Write-Log "No TXT file selected." -Level "WARN"
        exit
    }
    $txtFile = $txtDialog.FileName
    Write-Log "Selected TXT: $txtFile"

    # === Step 3: Output Folder ===
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select Output Folder for Modified BacPac"
    if ($folderDialog.ShowDialog() -ne 'OK') {
        Write-Log "No output folder selected." -Level "WARN"
        exit
    }
    $outputFolder = $folderDialog.SelectedPath
    Write-Log "Output folder: $outputFolder"

    # === Step 4: Define Output File ===
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($bacpacFile)
    $outputFile = Join-Path $outputFolder "${baseName}_Modified.bacpac"
    Write-Log "Output BacPac: $outputFile"

    # === Step 5: File Overwrite Confirm ===
    if (Test-Path $outputFile) {
        $overwrite = [System.Windows.Forms.MessageBox]::Show(
            "The file already exists:`n$outputFile`nOverwrite?",
            "Confirm Overwrite",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($overwrite -ne "Yes") {
            Write-Log "User canceled overwrite." -Level "WARN"
            exit
        } else {
            Remove-Item $outputFile -Force
            Write-Log "Old file removed."
        }
    }

    # === Step 6: Read TXT contents ===
    $tables = Get-Content $txtFile | Where-Object { $_.Trim() -ne "" }
    if (-not $tables) {
        Write-Log "TXT is empty or invalid." -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show("The TXT file is empty. Aborting.", "Invalid TXT", "OK", "Error")
        exit
    }
    Write-Log "Tables to clear:"
    $tables | ForEach-Object { Write-Log " - $_" }

    # === Step 7: Run Clear-D365TableDataFromBacPac ===
    Write-Log "Starting Clear-D365TableDataFromBacPac..."
    try {
        Clear-D365TableDataFromBacPac -Path $bacpacFile -Table $tables -OutputPath $outputFile -Verbose 4>&1 | ForEach-Object {
            Write-Log $_
        }
        Write-Log "✅ Cleaned BacPac saved at: $outputFile"
        [System.Windows.Forms.MessageBox]::Show("✅ Modified BacPac created successfully!`nPath: $outputFile", "Success", "OK", "Information")
    } catch {
        Write-Log "ERROR running Clear-D365TableDataFromBacPac: $_" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show("❌ Failed to process BacPac.`n$_", "ERROR", "OK", "Error")
        exit
    }

} catch {
    Write-Log "❌ UNHANDLED ERROR: $_" -Level "ERROR"
    [System.Windows.Forms.MessageBox]::Show("Unexpected error occurred.`n$_", "FATAL ERROR", "OK", "Error")
    exit
}

Write-Log "=== Script Finished Successfully ==="
 
