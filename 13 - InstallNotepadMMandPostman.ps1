# --- Check and elevate to admin ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Relaunching as admin..."
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- Set common temp directory ---
$tempDir = "$env:TEMP\AppInstall"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# --- Function to check Notepad++ installation ---
function Test-NotepadPPInstalled {
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($path in $regPaths) {
        Get-ChildItem $path | ForEach-Object {
            $displayName = ($_ | Get-ItemProperty).DisplayName
            if ($displayName -like "Notepad++*") {
                return $true
            }
        }
    }
    return $false
}

# --- Function to check Postman installation ---
function Test-PostmanInstalled {
    $postmanPath = "C:\Program Files\Postman\Postman.exe"
    return (Test-Path $postmanPath)
}

# --- Install Notepad++ if not present ---
if (-not (Test-NotepadPPInstalled)) {
    try {
        Write-Host "`nInstalling Notepad++..."
        $nppInstallerPath = "$tempDir\npp_installer.exe"
        $nppRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
        $nppAsset = $nppRelease.assets | Where-Object { $_.name -like "*Installer.x64.exe" }

        if ($nppAsset -and $nppAsset.browser_download_url) {
            Invoke-WebRequest -Uri $nppAsset.browser_download_url -OutFile $nppInstallerPath
            Start-Process -FilePath $nppInstallerPath -ArgumentList "/S" -Wait
            Remove-Item -Path $nppInstallerPath -Force
            Write-Host "Notepad++ installed."
        } else {
            Write-Warning "Could not find Notepad++ installer."
        }
    }
    catch {
        Write-Warning "Failed to install Notepad++: $_"
    }
} else {
    Write-Host "Notepad++ is already installed. Skipping."
}

# --- Install Postman if not present ---
if (-not (Test-PostmanInstalled)) {
    try {
        Write-Host "`nInstalling Postman..."
        $postmanInstallerPath = "$tempDir\Postman-x64-Setup.exe"
        $postmanUrl = "https://dl.pstmn.io/download/latest/win64"
        Invoke-WebRequest -Uri $postmanUrl -OutFile $postmanInstallerPath
        Start-Process -FilePath $postmanInstallerPath -ArgumentList "/S" -Wait
        Remove-Item -Path $postmanInstallerPath -Force
        Write-Host "Postman installed."
    }
    catch {
        Write-Warning "Failed to install Postman: $_"
    }
} else {
    Write-Host "Postman is already installed. Skipping."
}

# --- Cleanup ---
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
Write-Host "`nAll tasks completed."
