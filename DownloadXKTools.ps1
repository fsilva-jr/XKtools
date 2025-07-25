# ============================================
# XKTools Bootstrap Installer + Desktop Shortcut
# ============================================

$repoName = "XKtools"
$zipUrl = "https://codeload.github.com/fsilva-jr/$repoName/zip/refs/heads/main"
$tempRoot = "C:\Temp"
$zipFile = Join-Path $tempRoot "$repoName-main.zip"
$extractFolder = Join-Path $tempRoot "XKTools"
$mainScript = Join-Path $extractFolder "00 - Menu.ps1"

# Desktop shortcut details
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "XKTools.lnk"
$powershellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

# Create working directories
if (-not (Test-Path $tempRoot)) {
    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $extractFolder)) {
    New-Item -Path $extractFolder -ItemType Directory -Force | Out-Null
}

# Download ZIP
Write-Host "Baixando XKTools do GitHub..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing
    Write-Host "Download concluído." -ForegroundColor Green
} catch {
    Write-Host "❌ Falha ao baixar o ZIP: $_" -ForegroundColor Red
    exit 1
}

# Extrair ZIP
Write-Host "Extraindo arquivos..." -ForegroundColor Cyan
try {
    Expand-Archive -Path $zipFile -DestinationPath $extractFolder -Force
} catch {
    Write-Host "❌ Falha ao extrair o ZIP: $_" -ForegroundColor Red
    exit 1
}

# Mover conteúdo da subpasta
$innerFolder = Join-Path $extractFolder "$repoName-main"
if (Test-Path $innerFolder) {
    Get-ChildItem -Path $innerFolder -Force | Move-Item -Destination $extractFolder -Force
    Remove-Item -Path $innerFolder -Recurse -Force
}

# Limpar arquivo ZIP
if (Test-Path $zipFile) {
    Remove-Item -Path $zipFile -Force
}

# Criar atalho na área de trabalho
if (Test-Path $mainScript) {
    Write-Host "Criando atalho na área de trabalho..." -ForegroundColor Cyan
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $powershellPath
        $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$mainScript`""
        $shortcut.WorkingDirectory = $extractFolder
        $shortcut.WindowStyle = 1
        $shortcut.IconLocation = "$powershellPath,0"
        $shortcut.Description = "XKTools Menu"
        $shortcut.Save()
        Write-Host "✅ Atalho criado em: $shortcutPath" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Falha ao criar o atalho: $_" -ForegroundColor Yellow
    }

    # Executar script
    Write-Host "Iniciando o menu XKTools..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$mainScript`"" -Verb RunAs
} else {
    Write-Host "❌ Arquivo '00 - Menu.ps1' não encontrado em $extractFolder" -ForegroundColor Red
    exit 1
}
