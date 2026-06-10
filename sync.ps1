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

# main.dart patchen: UrlConfigService.init() vor runApp einfügen
$mainFile = "$dst\lib\main.dart"
if (Test-Path $mainFile) {
    $mainContent = Get-Content $mainFile -Raw
    # Nur patchen wenn noch nicht gepatcht
    if ($mainContent -notlike "*UrlConfigService*") {
        # Import hinzufügen (nach letztem import)
        $mainContent = $mainContent -replace "(import '[^']+';`r?`n)(?!import)", "`$1import 'package:stacksense/core/services/url_config_service.dart';`n"
        # UrlConfigService.init() vor runApp() einfügen
        $mainContent = $mainContent -replace "(\s+)(runApp\()", "`$1await UrlConfigService.init();`n`$1`$2"
        # void main() → Future<void> main() async falls nötig
        $mainContent = $mainContent -replace "void main\(\) \{", "Future<void> main() async {"
        # WidgetsFlutterBinding sicherstellen
        if ($mainContent -notlike "*WidgetsFlutterBinding.ensureInitialized*") {
            $mainContent = $mainContent -replace "(Future<void> main\(\) async \{)", "`$1`n  WidgetsFlutterBinding.ensureInitialized();"
        }
        Set-Content $mainFile $mainContent -NoNewline
        Write-Host "  main.dart: UrlConfigService.init() eingefuegt" -ForegroundColor Green
    } else {
        Write-Host "  main.dart: bereits gepatcht" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Fertig! App neu starten:" -ForegroundColor Yellow
Write-Host "  cd `"$dst`"" -ForegroundColor Gray
Write-Host "  $flutter run -d adb-RFCY81KWGNM-t9SdO5._adb-tls-connect._tcp" -ForegroundColor Gray
