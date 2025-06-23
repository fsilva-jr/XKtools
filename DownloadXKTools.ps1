# Set paths
$zipUrl = "https://codeload.github.com/fsilva-jr/XKtools/zip/refs/heads/main"
$downloadPath = "C:\temp\XKtools-main.zip"
$extractFolder = "C:\temp\XKTools"

# Create target folder if it doesn't exist
New-Item -Path "C:\temp" -ItemType Directory -Force | Out-Null

# Download the zip file
Invoke-WebRequest -Uri $zipUrl -OutFile $downloadPath

# Extract zip to temp location first
Expand-Archive -Path $downloadPath -DestinationPath $extractFolder -Force

# Move contents from inner folder (e.g., XKtools-main) if necessary
$innerFolder = Join-Path $extractFolder "XKtools-main"
if (Test-Path $innerFolder) {
    Get-ChildItem -Path $innerFolder | Move-Item -Destination $extractFolder -Force
    Remove-Item -Path $innerFolder -Recurse -Force
}

# Delete the zip file
Remove-Item -Path $downloadPath -Force


