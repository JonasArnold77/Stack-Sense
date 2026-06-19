# StackSense — Backend Deploy zu AWS App Runner (ohne git push)
# Kopiert backend/ direkt als ZIP und triggert Redeploy via AWS CLI
# Voraussetzung: aws cli installiert + konfiguriert (aws configure)
#
# Aufruf: powershell -ExecutionPolicy Bypass -File deploy_backend.ps1

$ErrorActionPreference = "Stop"

$src     = Join-Path $PSScriptRoot "backend"
$zipPath = Join-Path $env:TEMP "stacksense_backend.zip"

# ── App Runner Service ARN — einmalig anpassen ───────────────────────────────
# Findest du in AWS Console → App Runner → dein Service → Service ARN (oben rechts)
$SERVICE_ARN = "DEIN-APP-RUNNER-SERVICE-ARN-HIER-EINTRAGEN"
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   StackSense Backend Deploy          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 1. Prüfen ob aws cli da ist
try {
    $null = aws --version 2>&1
    Write-Host "✓ AWS CLI gefunden" -ForegroundColor Green
} catch {
    Write-Host "✗ AWS CLI nicht installiert." -ForegroundColor Red
    Write-Host "  → https://aws.amazon.com/cli/ installieren" -ForegroundColor Yellow
    exit 1
}

# 2. Prüfen ob Service ARN gesetzt
if ($SERVICE_ARN -eq "DEIN-APP-RUNNER-SERVICE-ARN-HIER-EINTRAGEN") {
    Write-Host ""
    Write-Host "✗ Service ARN fehlt!" -ForegroundColor Red
    Write-Host "  Öffne deploy_backend.ps1 und trage deinen App Runner ARN ein." -ForegroundColor Yellow
    Write-Host "  Zu finden: AWS Console → App Runner → dein Service → oben rechts" -ForegroundColor Yellow
    exit 1
}

# 3. Manuellen Redeploy triggern (App Runner deployed letzten git-Stand neu)
Write-Host "Starte manuellen App Runner Redeploy..." -ForegroundColor Cyan
$result = aws apprunner start-deployment --service-arn $SERVICE_ARN --output json 2>&1

if ($LASTEXITCODE -eq 0) {
    $json = $result | ConvertFrom-Json
    Write-Host ""
    Write-Host "✓ Redeploy gestartet!" -ForegroundColor Green
    Write-Host "  Operation ID: $($json.OperationId)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Status verfolgen:" -ForegroundColor Yellow
    Write-Host "  AWS Console → App Runner → dein Service → Activity" -ForegroundColor Gray
    Write-Host "  Dauert ca. 2-3 Minuten." -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "✗ Fehler beim Deploy:" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
}
