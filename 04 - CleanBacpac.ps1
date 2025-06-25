# ============================================
# XKTools - BacPac Cleanup Script with Logging and Error Handling
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

# Setup log folder and file
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "BacPacCleanup.log"
if (Test-Path $logFile) { Remove-Item $logFile -Force }

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

Write-Log -Message "======== BacPac Cleanup Script Started ========" -Level "INFO"

try {
    # Ensure D365FO.Tools module
    if (-not (Get-Module -ListAvailable -Name D365FO.Tools)) {
        Write-Log -Message "Installing D365FO.Tools module..." -Level "INFO"
        Install-Module -Name D365FO.Tools -Force -Scope CurrentUser
    }
    Import-Module D365FO.Tools -Force
    Write-Log -Message "D365FO.Tools module imported." -Level "INFO"

    # Add WinForms for dialogs
    Add-Type -AssemblyName System.Windows.Forms

    # Step 1: Select .bacpac file
    $bacpacDialog = New-Object System.Windows.Forms.OpenFileDialog
    $bacpacDialog.Title = "Select the .bacpac File"
    $bacpacDialog.Filter = "BACPAC Files (*.bacpac)|*.bacpac"

    if ($bacpacDialog.ShowDialog() -ne 'OK') {
        Write-Log -Message "No .bacpac file selected. Exiting..." -Level "WARN"
        exit
    }
    $bacpacFile = $bacpacDialog.FileName
    Write-Log -Message "Selected .bacpac: $bacpacFile" -Level "INFO"

    # Step 2: Select TXT file
    $txtDialog = New-Object System.Windows.Forms.OpenFileDialog
    $txtDialog.Title = "Select the TXT File with Tables to Clear"
    $txtDialog.Filter = "Text Files (*.txt)|*.txt"

    if ($txtDialog.ShowDialog() -ne 'OK') {
        Write-Log -Message "No TXT file selected. Exiting..." -Level "WARN"
        exit
    }
    $txtFile = $txtDialog.FileName
    Write-Log -Message "Selected table list TXT: $txtFile" -Level "INFO"

    # Step 3: Select Output Folder
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select Output Folder for the Modified Bacpac"

    if ($folderDialog.ShowDialog() -ne 'OK') {
        Write-Log -Message "No output folder selected. Exiting..." -Level "WARN"
        exit
    }
    $outputFolder = $folderDialog.SelectedPath
    Write-Log -Message "Selected output folder: $outputFolder" -Level "INFO"

    # Step 4: Build output path
    $originalFileName = [System.IO.Path]::GetFileNameWithoutExtension($bacpacFile)
    $outputBacpac = Join-Path $outputFolder "${originalFileName}_Modified.bacpac"
    Write-Log -Message "Output BacPac path: $outputBacpac" -Level "INFO"

    # Step 5: Check for existing output file
    if (Test-Path $outputBacpac) {
        $msgBox = [System.Windows.Forms.MessageBox]::Show(
            "The file `"$outputBacpac`" already exists.`nDo you want to overwrite it?",
            "Overwrite Confirmation",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($msgBox -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-Log -Message "User chose not to overwrite existing file. Exiting..." -Level "WARN"
            exit
        }
        else {
            Write-Log -Message "User confirmed overwrite. Deleting existing file." -Level "INFO"
            Remove-Item $outputBacpac -Force
        }
    }

    # Step 6: Read table list
    $tablesToClear = Get-Content $txtFile | Where-Object { $_.Trim() -ne "" }
    if (-not $tablesToClear) {
        Write-Log -Message "TXT file is empty. Exiting..." -Level "ERROR"
        exit
    }
    Write-Log -Message "Tables to clear:" -Level "INFO"
    $tablesToClear | ForEach-Object { Write-Log -Message " - $_" -Level "INFO" }

    # Step 7: Execute Clear-D365TableDataFromBacPac
    Write-Log -Message "Starting Clear-D365TableDataFromBacPac execution..." -Level "INFO"
    try {
        Clear-D365TableDataFromBacPac -Path $bacpacFile -Table $tablesToClear -OutputPath $outputBacpac -Verbose 4>&1 | ForEach-Object { Write-Log -Message $_ -Level "INFO" }
        Write-Log -Message "✅ Modified BacPac created at: $outputBacpac" -Level "INFO"
    }
    catch {
        Write-Log -Message "❌ Error during Clear-D365TableDataFromBacPac execution: $_" -Level "ERROR"
        exit
    }
}
catch {
    Write-Log -Message "❌ UNEXPECTED ERROR: $_" -Level "ERROR"
    exit
}

Write-Log -Message "======== Script Finished Successfully ========" -Level "INFO"
