# StackSense — Schnell-Sync: Kopiert lib/ + pubspec.yaml ins Flutter-Projekt
# Aufruf: powershell -ExecutionPolicy Bypass -File sync.ps1

$src = $PSScriptRoot
$dst = Join-Path (Split-Path $src -Parent) "stacksense_app"
$flutter = "C:\Users\jonas\develop\flutter\bin\flutter.bat"

Write-Host "Sync: Stack-Sense -> stacksense_app..." -ForegroundColor Cyan

# lib/ kopieren
Remove-Item "$dst\lib" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "$src\lib" "$dst\lib" -Recurse -Force
Write-Host "  lib/ synced" -ForegroundColor Green

# pubspec.yaml kopieren
Copy-Item "$src\pubspec.yaml" "$dst\pubspec.yaml" -Force
Write-Host "  pubspec.yaml synced" -ForegroundColor Green

# .env kopieren (falls vorhanden)
if (Test-Path "$src\.env") {
    Copy-Item "$src\.env" "$dst\.env" -Force
    Write-Host "  .env synced" -ForegroundColor Green
}

Write-Host ""
Write-Host "Fertig! App neu starten:" -ForegroundColor Yellow
Write-Host "  cd `"$dst`"" -ForegroundColor Gray
Write-Host "  $flutter run -d adb-RFCY81KWGNM-t9SdO5._adb-tls-connect._tcp" -ForegroundColor Gray
