# Simple Download + Extract XKTools Script

$repoName = "XKtools"
$zipUrl = "https://codeload.github.com/fsilva-jr/$repoName/zip/refs/heads/main"
$tempRoot = "C:\Temp"
$zipFile = Join-Path $tempRoot "$repoName-main.zip"
$extractFolder = Join-Path $tempRoot "XKTools"
$mainScript = Join-Path $extractFolder "00 - Menu.ps1"

# Create folders
New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
New-Item -Path $extractFolder -ItemType Directory -Force | Out-Null

# Download the zip file
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

# Extract contents
Expand-Archive -Path $zipFile -DestinationPath $extractFolder -Force

# Move inner folder contents
$innerFolder = Join-Path $extractFolder "$repoName-main"
if (Test-Path $innerFolder) {
    Get-ChildItem -Path $innerFolder -Force | Move-Item -Destination $extractFolder -Force
    Remove-Item -Path $innerFolder -Recurse -Force
}

# Delete ZIP
Remove-Item -Path $zipFile -Force

# Launch the menu if found
if (Test-Path $mainScript) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$mainScript`"" -Verb RunAs
} else {
    Write-Host "Could not find 00 - Menu.ps1 in $extractFolder"
}
