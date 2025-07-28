# PowerShell install script for cc-switch

$script = Join-Path (Get-Location) "cc_switch.py"
$targetDir = "$env:USERPROFILE\bin"
$target = Join-Path $targetDir "ccswitch.ps1"

# If not in the same directory, try to find or download cc_switch.py
if (!(Test-Path $script)) {
    if (Test-Path "$env:TEMP\cc_switch.py") {
        $script = "$env:TEMP\cc_switch.py"
    } else {
        Write-Host "cc_switch.py not found, downloading..."
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/HamGuy/cc-switch/main/cc_switch.py" -OutFile "$env:TEMP\cc_switch.py"
        } catch {
            irm https://raw.githubusercontent.com/HamGuy/cc-switch/main/cc_switch.py -OutFile "$env:TEMP\cc_switch.py"
        }
        $script = "$env:TEMP\cc_switch.py"
    }
}

if (!(Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
}

# Always overwrite
"#!/usr/bin/env python3" | Out-File -Encoding utf8 $target
Get-Content $script | Out-File -Encoding utf8 -Append $target

# Add user bin to PATH if not already
$profilePath = $PROFILE
$pathLine = "`$env:PATH = `"$env:USERPROFILE\bin;`$env:PATH`""
if (!(Get-Content $profilePath | Select-String -Pattern $pathLine)) {
    Add-Content -Path $profilePath -Value $pathLine
    Write-Host "Added $targetDir to PATH in $profilePath"
}

Write-Host "ccswitch command installed at $targetDir."
Write-Host "Usage examples:"
Write-Host "  ccswitch.ps1 --type kimi --token sk-xxx"
Write-Host "  ccswitch.ps1 --type custom --token sk-xxx --base_url https://your-url.com"
Write-Host "  ccswitch.ps1 --reset"
Write-Host "  ccswitch.ps1   # interactive mode"
Write-Host "If you just installed, restart PowerShell or run: . $PROFILE"
