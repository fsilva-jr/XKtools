# ============================================
# XKTools - Download AZCopy and SQLPackage
# Created by: Francisco Silva
# Contact: francisco@mtxn.com.br
# Updated for PS 5.1 & PS 7+ by PowerShell GPT
# ============================================

# Auto-elevate to admin (using pwsh if needed)
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script as Administrator with ExecutionPolicy Bypass..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`""
    Start-Process pwsh -Verb RunAs -ArgumentList $arguments
    exit
}

# Setup Log
$logFolder = "C:\Temp\XKTools\Logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$logFile = Join-Path $logFolder "AZCopy_SQLPackage.log"

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

Write-Log -Message "======== Script Started ========" -Level "INFO"

# HttpClient Setup
Add-Type -AssemblyName System.Net.Http
$http = [System.Net.Http.HttpClient]::new()

# Paths
$downloadFolder = "C:\Temp"
$azcopyZip = Join-Path $downloadFolder "azcopy.zip"
$sqlPackageZip = Join-Path $downloadFolder "sqlpackage.zip"
$azcopyExtractFolder = Join-Path $downloadFolder "azcopy"
$sqlPackageExtractFolder = Join-Path $downloadFolder "sqlpackage"
$azcopyExe = Join-Path $downloadFolder "azcopy.exe"

# Ensure download folder exists
if (-not (Test-Path -Path $downloadFolder)) {
    New-Item -ItemType Directory -Path $downloadFolder | Out-Null
}

function FastDownload ($url, $destination) {
    Write-Host "Downloading from $url..." -ForegroundColor Cyan
    Write-Log -Message "Starting download: $url -> $destination" -Level "INFO"
    try {
        $response = $http.GetAsync($url).Result
        [System.IO.File]::WriteAllBytes($destination, $response.Content.ReadAsByteArrayAsync().Result)
        Write-Host "Download completed: $destination" -ForegroundColor Green
        Write-Log -Message "Download successful: $destination" -Level "INFO"
    } catch {
        Write-Warning "Failed to download from ${url}: $_"
        Write-Log -Message "ERROR: Failed to download from ${url}: $_" -Level "ERROR"
        exit 1
    }
}

try {
    # Check AzCopy existence
    $downloadAzCopy = $true
    if (Test-Path $azcopyExe) {
        $response = Read-Host "azcopy.exe already exists at $azcopyExe. Download again? (Y/N)"
        if ($response.ToUpper() -ne "Y") {
            $downloadAzCopy = $false
            Write-Log -Message "User skipped AzCopy download." -Level "INFO"
        }
    }

    # Check SQLPackage folder existence
    $downloadSqlPackage = $true
    if (Test-Path $sqlPackageExtractFolder) {
        $response = Read-Host "sqlpackage folder exists at $sqlPackageExtractFolder. Download again? (Y/N)"
        if ($response.ToUpper() -ne "Y") {
            $downloadSqlPackage = $false
            Write-Log -Message "User skipped SQLPackage download." -Level "INFO"
        }
    }

    # Download and extract AzCopy
    if ($downloadAzCopy) {
        FastDownload "https://aka.ms/downloadazcopy-v10-windows" $azcopyZip

        if (Test-Path $azcopyExtractFolder) {
            Remove-Item -Recurse -Force $azcopyExtractFolder
            Write-Log -Message "Old AzCopy extraction folder deleted." -Level "INFO"
        }

        Expand-Archive -Path $azcopyZip -DestinationPath $azcopyExtractFolder -Force
        Remove-Item -Path $azcopyZip -Force
        Write-Log -Message "AzCopy archive extracted." -Level "INFO"

        $azcopyExePath = Get-ChildItem -Path $azcopyExtractFolder -Filter "azcopy.exe" -Recurse | Select-Object -First 1
        if ($azcopyExePath) {
            Copy-Item -Path $azcopyExePath.FullName -Destination $azcopyExe -Force
            Write-Log -Message "AzCopy executable copied to $downloadFolder" -Level "INFO"
        } else {
            Write-Warning "azcopy.exe not found after extraction."
            Write-Log -Message "ERROR: azcopy.exe not found after extraction." -Level "ERROR"
        }

        if (Test-Path $azcopyExtractFolder) {
            Remove-Item -Recurse -Force $azcopyExtractFolder
            Write-Log -Message "Temporary AzCopy extraction folder removed." -Level "INFO"
        }
    }

    # Download and extract SQLPackage
    if ($downloadSqlPackage) {
        FastDownload "https://aka.ms/sqlpackage-windows" $sqlPackageZip

        if (Test-Path $sqlPackageExtractFolder) {
            Remove-Item -Recurse -Force $sqlPackageExtractFolder
            Write-Log -Message "Old SQLPackage folder deleted." -Level "INFO"
        }

        Expand-Archive -Path $sqlPackageZip -DestinationPath $sqlPackageExtractFolder -Force
        Remove-Item -Path $sqlPackageZip -Force
        Write-Log -Message "SQLPackage archive extracted to $sqlPackageExtractFolder" -Level "INFO"
    }

    Write-Host "`n✔️ Download and setup completed." -ForegroundColor Green
    Write-Log -Message "Download and setup completed successfully." -Level "INFO"
}
catch {
    Write-Warning "❌ Unexpected error occurred: $_"
    Write-Log -Message "UNEXPECTED ERROR: $_" -Level "ERROR"
}

Write-Log -Message "======== Script Finished ========" -Level "INFO"
