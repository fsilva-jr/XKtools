# ===============================
# 13 - Install Notepad++ and Postman
# Author: Francisco Silva
# ===============================

function Install-NotepadPP {
    $tempPath = "$env:TEMP\NotepadPP-Installer.exe"

    Write-Host "`n=== Installing Notepad++ ===" -ForegroundColor Cyan

    # Check if Notepad++ is installed (registry check)
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($regPath in $regPaths) {
        $nppKey = Get-ChildItem $regPath -ErrorAction SilentlyContinue | Where-Object {
            ($_ | Get-ItemProperty -ErrorAction SilentlyContinue).DisplayName -like "Notepad++*"
        }

        if ($nppKey) {
            Write-Host "✅ Notepad++ is already installed." -ForegroundColor Green
            return
        }
    }

    # Download and install
    try {
        Write-Host "Downloading latest Notepad++ installer..." -ForegroundColor Cyan
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
        $asset = $release.assets | Where-Object { $_.name -like "*Installer.x64.exe" }

        if (-not $asset) {
            Write-Host "❌ Could not locate Notepad++ installer in GitHub release." -ForegroundColor Red
            return
        }

        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempPath
        Write-Host "Installing Notepad++ silently..." -ForegroundColor Cyan
        $install = Start-Process -FilePath $tempPath -ArgumentList "/S" -Wait -PassThru

        if ($install.ExitCode -eq 0) {
            Write-Host "✅ Notepad++ installed successfully." -ForegroundColor Green
        } else {
            Write-Host "❌ Installer exited with code $($install.ExitCode)." -ForegroundColor Red
        }

        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "❌ Failed to install Notepad++: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Install-Postman {
    $postmanExe = "$env:TEMP\Postman-x64-Setup.exe"
    $postmanUrl = "https://dl.pstmn.io/download/latest/win64"
    $userPostmanPath = Join-Path $env:LOCALAPPDATA "Postman\Postman.exe"

    Write-Host "`n=== Installing Postman ===" -ForegroundColor Cyan

    # Check if already installed
    if (Test-Path $userPostmanPath) {
        Write-Host "✅ Postman is already installed at: $userPostmanPath" -ForegroundColor Green
        return
    }

    # Try Winget first
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Winget detected. Installing Postman via Winget..." -ForegroundColor Cyan
            $wingetArgs = "install --id Postman.Postman --source winget --accept-package-agreements --accept-source-agreements --silent"
            $winget = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru

            if ($winget.ExitCode -eq 0 -and (Test-Path $userPostmanPath)) {
                Write-Host "✅ Postman installed via Winget." -ForegroundColor Green
                return
            } else {
                Write-Host "⚠ Winget finished but Postman not found in user profile. Falling back." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "⚠ Winget failed: $($_.Exception.Message). Falling back..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ Winget not available. Using manual installer..." -ForegroundColor Yellow
    }

    # Fallback: download EXE and install silently
    try {
        Write-Host "Downloading Postman installer..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $postmanUrl -OutFile $postmanExe -UseBasicParsing

        Write-Host "Installing Postman silently..." -ForegroundColor Cyan
        $install = Start-Process -FilePath $postmanExe -ArgumentList "/S" -Wait -PassThru

        if ($install.ExitCode -eq 0 -and (Test-Path $userPostmanPath)) {
            Write-Host "✅ Postman installed via direct download." -ForegroundColor Green
        } else {
            Write-Host "❌ Installer ran but Postman is still not found in AppData." -ForegroundColor Red
        }

        Remove-Item -Path $postmanExe -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "❌ Failed to install Postman: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Main Execution ---
Install-NotepadPP
Install-Postman
