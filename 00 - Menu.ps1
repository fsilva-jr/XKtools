 Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === Hide console window ===
Add-Type -Name Window -Namespace Win32 -MemberDefinition '
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
'
$consolePtr = [Win32.Window]::GetConsoleWindow()
[Win32.Window]::ShowWindowAsync($consolePtr, 0)

# === Globals ===
$scriptDir = "C:\Temp\XKTools"
$logDir = Join-Path $scriptDir "Logs"
$logFile = Join-Path $logDir "XKToolsGUI.log"

$scriptMap = @{
    "1"  = "01 - Stop Services.ps1"
    "2"  = "02 - AZCopy_SQLPackage.ps1"
    "3"  = "03 - DownloadBacPacFromLCS.ps1"
    "4"  = "04 - CleanBacpac.ps1"
    "5"  = "05 - RenameDatabase.ps1"
    "6"  = "06 - RestoreBacPac.ps1"
    "7"  = "07 - Start Services.ps1"
    "8"  = "08 - BuildModels.ps1"
    "9"  = "09 - Sync Database.ps1"
    "10" = "10 - Deploy reports.ps1"
    "11" = "11 - Reindex All Database.ps1"
    "12" = "12 - UpdateWebAndWifConfig.ps1"
}

$executedScripts = @{}
$buttons = @{}

# === Ensure Admin ===
function Ensure-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $currentUser
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell.exe "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# === Logging ===
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [$Level] $Message" | Out-File -Append -FilePath $logFile
}

# === Execute Script ===
function Execute-Script {
    param (
        [string]$key,
        [string]$file
    )

    $fullPath = Join-Path $scriptDir $file

    if (-not (Test-Path $fullPath)) {
        [System.Windows.Forms.MessageBox]::Show("Script not found: $file", "Error", 'OK', 'Error')
        Write-Log "❌ Script not found: $file" "ERROR"
        return
    }

    try {
        Write-Log "▶ Executing: $file"

        Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$fullPath`"" `
            -WindowStyle Normal

        $executedScripts[$key] = $true
        Update-Button-Colors
        Write-Log "✅ Launched: $file"
    } catch {
        Write-Log "❌ Failed to launch $file - $_" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Error: $file`n$_", "Execution Failed", 'OK', 'Error')
    }
}

# === Update Button Color ===
function Update-Button-Colors {
    foreach ($key in $buttons.Keys) {
        if ($executedScripts.ContainsKey($key)) {
            $buttons[$key].BackColor = [System.Drawing.Color]::LightGray
        }
    }
}

# === GUI ===
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "XKTools GUI Menu"
$Form.Size = New-Object System.Drawing.Size(500, 740)
$Form.StartPosition = "CenterScreen"
$Form.BackColor = 'White'

$y = 20

foreach ($key in $scriptMap.Keys | Sort-Object {[int]$_}) {
    $localKey = $key  # 🔐 Prevent closure issues

    $label = $scriptMap[$localKey] -replace '\.ps1$', ''
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "$localKey - $label"
    $btn.Size = New-Object System.Drawing.Size(440, 35)
    $btn.Location = New-Object System.Drawing.Point(20, $y)
    $btn.BackColor = [System.Drawing.Color]::LightGreen
    $btn.Tag = $localKey

    $buttons[$localKey] = $btn

    $btn.Add_Click({
        $btnKey = $this.Tag

        if ([string]::IsNullOrWhiteSpace($btnKey)) {
            [System.Windows.Forms.MessageBox]::Show("⚠ Button has no key.", "Error", 'OK', 'Warning')
            Write-Log "⚠ Button clicked with missing tag." "WARN"
            return
        }

        if ($scriptMap.ContainsKey($btnKey)) {
            Execute-Script -key $btnKey -file $scriptMap[$btnKey]
        } else {
            [System.Windows.Forms.MessageBox]::Show("❌ Unknown script key: $btnKey", "Error", 'OK', 'Error')
            Write-Log "❌ Unknown key: $btnKey" "ERROR"
        }
    })

    $Form.Controls.Add($btn)
    $y += 40
}

# === Exit Button ===
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Size = New-Object System.Drawing.Size(440, 35)
$exitButton.Location = New-Object System.Drawing.Point(20, $y)
$exitButton.BackColor = [System.Drawing.Color]::Tomato
$exitButton.Add_Click({ $Form.Close() })
$Form.Controls.Add($exitButton)

# === MAIN ===
Ensure-Admin
Write-Log "==== XKTools GUI Menu Launched ===="
[void]$Form.ShowDialog()
Write-Log "==== XKTools GUI Menu Closed ===="
 
