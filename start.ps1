# StackSense Start-Script
# Startet Backend + Flutter App (WLAN, kein ngrok)

$projectRoot = "C:\Github\Stack Sense\Stack-Sense"
$appRoot     = "C:\Github\Stack Sense\stacksense_app"
$flutter     = "C:\Users\jonas\develop\flutter\bin\flutter.bat"

# --- 1. Lokale WLAN-IP ermitteln ---
$localIp = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*WLAN*" } |
    Select-Object -First 1).IPAddress

if (-not $localIp) {
    # Fallback: erste nicht-loopback IPv4
    $localIp = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" } |
        Select-Object -First 1).IPAddress
}

if (-not $localIp) {
    Write-Host "WLAN-IP konnte nicht ermittelt werden." -ForegroundColor Red
    exit 1
}

$backendUrl = "http://${localIp}:8000/api/v1"
Write-Host "Lokale IP: $localIp  →  $backendUrl" -ForegroundColor Green

# --- 2. app_constants.dart aktualisieren ---
$constantsFile = "$projectRoot\lib\core\constants\app_constants.dart"
$content = Get-Content $constantsFile -Raw
$content = $content -replace "defaultValue: '.*?'", "defaultValue: '$backendUrl'"
Set-Content $constantsFile $content -NoNewline
Write-Host "app_constants.dart aktualisiert." -ForegroundColor Green

# --- 3. Backend starten (neues Fenster) ---
Write-Host "Backend wird gestartet..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectRoot\backend'; uvicorn main:app --host 0.0.0.0 --reload --port 8000"
Start-Sleep -Seconds 3

# --- 4. Sync + Flutter run ---
Write-Host "Sync laeuft..." -ForegroundColor Cyan
Set-Location $projectRoot
powershell -ExecutionPolicy Bypass -File sync.ps1

Write-Host "Flutter App wird gestartet..." -ForegroundColor Cyan
Set-Location $appRoot
& $flutter run
