# --- Function: Install Postman using Winget or fallback ---
function Install-Postman {
    $postmanExe = "$env:TEMP\Postman-x64-Setup.exe"
    $postmanUrl = "https://dl.pstmn.io/download/latest/win64"

    Write-Host "`n=== Installing Postman ===" -ForegroundColor Cyan

    # Try Winget first
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Winget detected. Installing Postman via Winget..." -ForegroundColor Cyan
            $wingetArgs = "install --id Postman.Postman --source winget --accept-package-agreements --accept-source-agreements --silent"
            $winget = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru

            if ($winget.ExitCode -eq 0) {
                Write-Host "✅ Postman installed via Winget." -ForegroundColor Green
                return
            } else {
                Write-Host "⚠ Winget returned non-zero exit code ($($winget.ExitCode)). Will use fallback." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "⚠ Winget failed: $($_.Exception.Message). Falling back..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ Winget not available. Falling back to manual download." -ForegroundColor Yellow
    }

    # Manual fallback
    try {
        Write-Host "Downloading Postman installer..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $postmanUrl -OutFile $postmanExe -UseBasicParsing

        Write-Host "Installing Postman silently..." -ForegroundColor Cyan
        $install = Start-Process -FilePath $postmanExe -ArgumentList "/S" -Wait -PassThru

        if ($install.ExitCode -eq 0) {
            Write-Host "✅ Postman installed via direct download." -ForegroundColor Green
        } else {
            Write-Host "❌ Installer exited with code $($install.ExitCode)" -ForegroundColor Red
        }

        Remove-Item -Path $postmanExe -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "❌ Failed to install Postman: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Call the function explicitly ---
Install-Postman
