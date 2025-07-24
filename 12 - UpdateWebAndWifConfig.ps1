Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security

# === Logging Setup ===
$logFolder = "C:\Temp\XKTools"
if (-not (Test-Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory | Out-Null
}
$logFile = Join-Path $logFolder "log.txt"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $logLine
    Write-Host $logLine
}
Write-Log "=== Script execution started ==="

# === Init Vars ===
$folderPath = "C:\Temp"
if (-not (Test-Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory | Out-Null
}
$thumbprintPath = Join-Path $folderPath "SelectedThumbprint.txt"
$selectedCert = $null
$selectedThumbprint = $null
$applicationId = $null

# === Cert Selection ===
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store('My','LocalMachine')
$store.Open('ReadOnly')
$certs = $store.Certificates | Where-Object { $_.HasPrivateKey -eq $true }

if ($certs.Count -eq 0) {
    Write-Log "No certificates with private key found." -Level "ERROR"
    [System.Windows.Forms.MessageBox]::Show("No certificates found.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    return
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Select a Certificate"
$form.Size = New-Object System.Drawing.Size(600,200)
$form.StartPosition = "CenterScreen"

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(20,30)
$comboBox.Size = New-Object System.Drawing.Size(540,25)
$comboBox.DropDownStyle = 'DropDownList'

$certMap = @{}
foreach ($cert in $certs) {
    $display = "$($cert.Subject) | Thumbprint: $($cert.Thumbprint)"
    $comboBox.Items.Add($display) | Out-Null
    $certMap[$display] = $cert
}
$form.Controls.Add($comboBox)

$thumbLabel = New-Object System.Windows.Forms.Label
$thumbLabel.Location = New-Object System.Drawing.Point(20,70)
$thumbLabel.Size = New-Object System.Drawing.Size(540,25)
$thumbLabel.Text = "Thumbprint: (not selected)"
$form.Controls.Add($thumbLabel)

$selectButton = New-Object System.Windows.Forms.Button
$selectButton.Text = "Select"
$selectButton.Location = New-Object System.Drawing.Point(460, 110)
$selectButton.Size = New-Object System.Drawing.Size(100,30)

$selectButton.Add_Click({
    if ($comboBox.SelectedItem -ne $null) {
        $certDisplay = $comboBox.SelectedItem
        Set-Variable -Name selectedCert -Value $certMap[$certDisplay] -Scope Global
        $thumbprint = $selectedCert.Thumbprint.Trim()
        Set-Variable -Name selectedThumbprint -Value $thumbprint -Scope Global
        $thumbLabel.Text = "Thumbprint: $thumbprint"
        Set-Content -Path $thumbprintPath -Value $thumbprint -Encoding UTF8
        Write-Log "Selected certificate: $certDisplay"
        Write-Log "Thumbprint saved: $thumbprint"
        [System.Windows.Forms.MessageBox]::Show("Thumbprint saved to:`n$thumbprintPath", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $form.Close()
    }
})
$form.Controls.Add($selectButton)
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

# === Drive Selection ===
$driveForm = New-Object System.Windows.Forms.Form
$driveForm.Text = "Select Drive"
$driveForm.Size = New-Object System.Drawing.Size(400,160)
$driveForm.StartPosition = "CenterScreen"

$driveLabel = New-Object System.Windows.Forms.Label
$driveLabel.Text = "Select the drive that contains '\AosService\WebRoot':"
$driveLabel.Location = New-Object System.Drawing.Point(20,20)
$driveLabel.Size = New-Object System.Drawing.Size(350,20)
$driveForm.Controls.Add($driveLabel)

$driveComboBox = New-Object System.Windows.Forms.ComboBox
$driveComboBox.Location = New-Object System.Drawing.Point(20,50)
$driveComboBox.Size = New-Object System.Drawing.Size(340,25)
$driveComboBox.DropDownStyle = 'DropDownList'

$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match "^[A-Z]:\\$" }
foreach ($drive in $drives) {
    $driveComboBox.Items.Add($drive.Root) | Out-Null
}
$driveForm.Controls.Add($driveComboBox)

$confirmDriveButton = New-Object System.Windows.Forms.Button
$confirmDriveButton.Text = "Confirm"
$confirmDriveButton.Location = New-Object System.Drawing.Point(260, 85)
$confirmDriveButton.Size = New-Object System.Drawing.Size(100,30)

$selectedDrive = $null
$confirmDriveButton.Add_Click({
    if ($driveComboBox.SelectedItem -ne $null) {
        Set-Variable -Name selectedDrive -Value $driveComboBox.SelectedItem -Scope Global
        Write-Log "Selected drive: $selectedDrive"
        $driveForm.Close()
    }
})
$driveForm.Controls.Add($confirmDriveButton)
$driveForm.Topmost = $true
$driveForm.Add_Shown({ $driveForm.Activate() })
[void]$driveForm.ShowDialog()

# Normalize drive
if ($selectedDrive -match '^[A-Z]:\\?$') {
    if ($selectedDrive -notlike '*\') {
        $selectedDrive = "${selectedDrive}\"
    }
} elseif ($selectedDrive -match '^[A-Z]$') {
    $selectedDrive = "${selectedDrive}:\"
}
$webRootPath = Join-Path $selectedDrive "AosService\WebRoot"

if (-not (Test-Path $webRootPath)) {
    Write-Log "WebRoot path not found: $webRootPath" -Level "ERROR"
    return
}

# === Backup Files ===
$filesToBackup = @("web.config", "wif.config", "wif.services.config")
foreach ($file in $filesToBackup) {
    $source = Join-Path $webRootPath $file
    $backup = "$source.bkp"
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $backup -Force
        Write-Log "Backup created: $backup"
    }
}
[System.Windows.Forms.MessageBox]::Show("Backup completed in:`n$webRootPath", "Backup Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

# === Application ID Input ===
$appIdForm = New-Object System.Windows.Forms.Form
$appIdForm.Text = "Enter Application ID"
$appIdForm.Size = New-Object System.Drawing.Size(400,160)
$appIdForm.StartPosition = "CenterScreen"

$appIdLabel = New-Object System.Windows.Forms.Label
$appIdLabel.Text = "Please enter the Application ID:"
$appIdLabel.Location = New-Object System.Drawing.Point(20,20)
$appIdLabel.Size = New-Object System.Drawing.Size(350,20)
$appIdForm.Controls.Add($appIdLabel)

$appIdTextBox = New-Object System.Windows.Forms.TextBox
$appIdTextBox.Location = New-Object System.Drawing.Point(20,50)
$appIdTextBox.Size = New-Object System.Drawing.Size(340,25)
$appIdForm.Controls.Add($appIdTextBox)

$appIdOkButton = New-Object System.Windows.Forms.Button
$appIdOkButton.Text = "OK"
$appIdOkButton.Location = New-Object System.Drawing.Point(260, 85)
$appIdOkButton.Size = New-Object System.Drawing.Size(100,30)

$appIdOkButton.Add_Click({
    if (![string]::IsNullOrWhiteSpace($appIdTextBox.Text)) {
        Set-Variable -Name applicationId -Value $appIdTextBox.Text.Trim() -Scope Global
        Write-Log "Application ID entered: $applicationId"
        $appIdForm.Close()
    }
})
$appIdForm.Controls.Add($appIdOkButton)
$appIdForm.Topmost = $true
$appIdForm.Add_Shown({ $appIdForm.Activate() })
[void]$appIdForm.ShowDialog()

# === Edit web.config ===
$webConfigPath = Join-Path $webRootPath "web.config"
if (Test-Path $webConfigPath) {
    [xml]$xml = Get-Content $webConfigPath
    $appSettings = $xml.configuration.appSettings
    $updates = @{
        "Aad.Realm" = "spn:$applicationId"
        "Infrastructure.S2SCertThumbprint" = $selectedThumbprint
        "GraphApi.GraphAPIServicePrincipalCert" = $selectedThumbprint
    }
    foreach ($key in $updates.Keys) {
        $entry = $appSettings.add | Where-Object { $_.key -eq $key }
        if ($entry) { $entry.value = $updates[$key] }
    }
    $xml.Save($webConfigPath)
    Write-Log "web.config updated with Application ID and thumbprint"
    [System.Windows.Forms.MessageBox]::Show("web.config updated.", "web.config", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# === Edit wif.config ===
$wifConfigPath = Join-Path $webRootPath "wif.config"
if (Test-Path $wifConfigPath) {
    [xml]$wifXml = Get-Content $wifConfigPath
    $root = $wifXml.SelectSingleNode("//securityTokenHandlerConfiguration")
    if (-not $root) {
        $root = $wifXml.CreateElement("securityTokenHandlerConfiguration")
        $wifXml.AppendChild($root) | Out-Null
    }
    $audienceUris = $root.SelectSingleNode("audienceUris")
    if (-not $audienceUris) {
        $audienceUris = $wifXml.CreateElement("audienceUris")
        $root.AppendChild($audienceUris) | Out-Null
        $defaultEntry = $wifXml.CreateElement("add")
        $defaultEntry.SetAttribute("value", "spn:00000015-0000-0000-c000-000000000000")
        $audienceUris.AppendChild($defaultEntry) | Out-Null
    }
    $newValue = "spn:$applicationId"
    $exists = $audienceUris.SelectNodes("add") | Where-Object { $_.value -eq $newValue }
    if (-not $exists) {
        $newEntry = $wifXml.CreateElement("add")
        $newEntry.SetAttribute("value", $newValue)
        $audienceUris.AppendChild($newEntry) | Out-Null
    }
    $wifXml.Save($wifConfigPath)
    Write-Log "wif.config updated with audienceUris"
    [System.Windows.Forms.MessageBox]::Show("wif.config updated.", "wif.config", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# === Export Certificate to .CER ===
try {
    if ($selectedCert -ne $null) {
        $certExportPath = Join-Path $folderPath "SelectedCertificate.cer"
        $bytes = $selectedCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        [System.IO.File]::WriteAllBytes($certExportPath, $bytes)
        Write-Log "Certificate exported to: $certExportPath"
        [System.Windows.Forms.MessageBox]::Show("Certificate exported to:`n$certExportPath", "Certificate Exported", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
} catch {
    Write-Log "Error exporting certificate: $_" -Level "ERROR"
    [System.Windows.Forms.MessageBox]::Show("Failed to export certificate.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

Write-Log "=== Script execution completed ==="
