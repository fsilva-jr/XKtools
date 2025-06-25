 # ============================================
# XKTools Main Menu Script
# Created by: Francisco Silva
# Updated for PS 5.1 & PS 7+ by PowerShell GPT
# ============================================ 

# Define the path
$path = "C:\Temp"

# Delete the XKTools folder if it exists
$folderToDelete = Join-Path $path "XKTools"
if (Test-Path $folderToDelete) {
    Remove-Item $folderToDelete -Recurse -Force
}

# Delete the SQLPackage file if it exists
$sqlPackage = Join-Path $path "SQLPackage"
if (Test-Path $sqlPackage) {
    Remove-Item $sqlPackage -Force
}

# Delete all .zip, .bacpac, and .exe files in the folder
Get-ChildItem -Path $path -Include *.zip, *.bacpac, *.exe -File -Recurse | Remove-Item -Force

# Notify user and wait before closing
Write-Host "✅ Cleanup completed successfully. This window will close in 2 seconds..." -ForegroundColor Green
Start-Sleep -Seconds 2
Stop-Process -Id $PID
