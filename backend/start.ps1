# StackSense Backend starten
# Einmalig: pip install -r requirements.txt
# Dann: powershell -ExecutionPolicy Bypass -File start.ps1

$backendDir = $PSScriptRoot

# .env prüfen
if (-not (Test-Path "$backendDir\.env")) {
    Write-Host "FEHLER: .env Datei fehlt!" -ForegroundColor Red
    Write-Host "Erstelle sie:" -ForegroundColor Yellow
    Write-Host "  Copy-Item '$backendDir\.env.example' '$backendDir\.env'" -ForegroundColor Cyan
    Write-Host "  Dann ANTHROPIC_API_KEY eintragen." -ForegroundColor Cyan
    exit 1
}

Set-Location $backendDir

Write-Host "StackSense Backend startet..." -ForegroundColor Cyan
Write-Host "API Docs: http://localhost:8000/docs" -ForegroundColor Green
Write-Host "Stoppen: Ctrl+C" -ForegroundColor Gray
Write-Host ""

python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
