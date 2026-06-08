# StackSense Start-Script
# Startet Backend, ngrok und Flutter App in einem Schritt

$projectRoot = "C:\Github\Stack Sense\Stack-Sense"
$appRoot     = "C:\Github\Stack Sense\stacksense_app"
$flutter     = "C:\Users\jonas\develop\flutter\bin\flutter.bat"

# --- 1. Backend starten (neues Fenster) ---
Write-Host "Backend wird gestartet..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectRoot\backend'; uvicorn main:app --reload --port 8000"

# Kurz warten bis Backend hochgefahren ist
Start-Sleep -Seconds 3

# --- 2. ngrok starten und URL auslesen ---
Write-Host "ngrok wird gestartet..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "ngrok http 8000"

# Warten bis ngrok API verfügbar ist
Write-Host "Warte auf ngrok..." -ForegroundColor Yellow
$ngrokUrl = $null
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    try {
        $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -ErrorAction Stop
        $https = $tunnels.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1
        if ($https) {
            $ngrokUrl = $https.public_url
            break
        }
    } catch { }
}

if (-not $ngrokUrl) {
    Write-Host "ngrok URL konnte nicht automatisch ausgelesen werden." -ForegroundColor Red
    Write-Host "Bitte URL manuell in app_constants.dart eintragen und script neu starten." -ForegroundColor Red
    exit 1
}

Write-Host "ngrok URL: $ngrokUrl" -ForegroundColor Green

# --- 3. app_constants.dart automatisch aktualisieren ---
$constantsFile = "$projectRoot\lib\core\constants\app_constants.dart"
$content = Get-Content $constantsFile -Raw
$content = $content -replace "defaultValue: '.*?'", "defaultValue: '$ngrokUrl/api/v1'"
Set-Content $constantsFile $content -NoNewline
Write-Host "app_constants.dart aktualisiert." -ForegroundColor Green

# --- 4. Sync + Flutter run ---
Write-Host "Sync laeuft..." -ForegroundColor Cyan
Set-Location $projectRoot
powershell -ExecutionPolicy Bypass -File sync.ps1

Write-Host "Flutter App wird gestartet..." -ForegroundColor Cyan
Set-Location $appRoot
& $flutter run
