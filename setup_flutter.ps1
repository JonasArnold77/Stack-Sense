# StackSense — Flutter Projekt Setup
# Dieses Script ausfuehren in: Android Studio Terminal ODER PowerShell
# Sicherstellen dass Flutter installiert ist: flutter --version

# Nur echte PowerShell-Fehler stoppen — keine nativen Programm-Outputs (flutter schreibt auf stderr beim ersten Start)
$ErrorActionPreference = "Continue"

$repoDir    = $PSScriptRoot                          # Ordner dieses Scripts
$parentDir  = Split-Path $repoDir -Parent            # C:\Github\Stack Sense\
$flutterDir = Join-Path $parentDir "stacksense_app"  # Neues Flutter-Projekt

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  StackSense Flutter Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- 0. Flutter-Pfad automatisch finden ---
Write-Host "[0/5] Suche Flutter-Installation..." -ForegroundColor Yellow

$flutterExe = $null

# Haeufige Installationsorte (Android Studio bundled + manuelle Installationen)
$searchPaths = @(
    "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
    "$env:LOCALAPPDATA\Programs\flutter\bin\flutter.bat",
    "C:\flutter\bin\flutter.bat",
    "C:\src\flutter\bin\flutter.bat",
    "C:\development\flutter\bin\flutter.bat",
    "$env:USERPROFILE\flutter\bin\flutter.bat",
    "$env:USERPROFILE\development\flutter\bin\flutter.bat",
    "C:\tools\flutter\bin\flutter.bat"
)

# Zuerst: Ist flutter schon im PATH?
$inPath = Get-Command flutter -ErrorAction SilentlyContinue
if ($inPath) {
    $flutterExe = "flutter"
    Write-Host "      Flutter im PATH gefunden." -ForegroundColor Green
} else {
    # Bekannte Pfade durchsuchen
    foreach ($p in $searchPaths) {
        if (Test-Path $p) { $flutterExe = $p; break }
    }

    # Notfall: Breit suchen (dauert laenger)
    if (-not $flutterExe) {
        Write-Host "      Suche tiefer (kann 10-30 Sek dauern)..." -ForegroundColor Gray
        $found = Get-ChildItem -Path "C:\", "$env:LOCALAPPDATA", "$env:USERPROFILE" `
            -Filter "flutter.bat" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like "*flutter\bin\flutter.bat" } |
            Select-Object -First 1
        if ($found) { $flutterExe = $found.FullName }
    }
}

if (-not $flutterExe) {
    Write-Host ""
    Write-Host "  FEHLER: Flutter nicht gefunden!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Bitte den Flutter-Pfad manuell angeben:" -ForegroundColor Yellow
    Write-Host "  In Android Studio: Preferences -> Languages & Frameworks -> Flutter" -ForegroundColor Yellow
    Write-Host "  Dann diesen Wert oben in das Script eintragen:" -ForegroundColor Yellow
    Write-Host '  $flutterExe = "C:\dein\pfad\zu\flutter\bin\flutter.bat"' -ForegroundColor Cyan
    exit 1
}

# Ab jetzt: flutter-Aufrufe ueber $flutterExe
# 2>&1 verhindert dass Flutter-stderr-Outputs PowerShell stoppen
function Invoke-Flutter { & $flutterExe @args 2>&1 | ForEach-Object { Write-Host $_ } }

# --- 1. Flutter-Version pruefen ---
Write-Host "[1/5] Pruefe Flutter..." -ForegroundColor Yellow
$flutterVersion = Invoke-Flutter --version 2>&1 | Select-Object -First 1
Write-Host "      $flutterVersion" -ForegroundColor Gray

# --- 2. Altes Projekt loeschen falls vorhanden ---
if (Test-Path $flutterDir) {
    Write-Host "[2/5] Loesche altes Projekt in $flutterDir..." -ForegroundColor Yellow
    Remove-Item $flutterDir -Recurse -Force
}

# --- 3. Flutter-Projekt erstellen ---
Write-Host "[3/5] Erstelle Flutter-Projekt (dauert ~30 Sekunden)..." -ForegroundColor Yellow
Set-Location $parentDir
Invoke-Flutter create `
    --org com.stacksense `
    --project-name stacksense `
    --platforms android,ios `
    stacksense_app

Write-Host "      Flutter-Projekt erstellt." -ForegroundColor Green

# --- 4. Code aus Stack-Sense kopieren ---
Write-Host "[4/5] Kopiere App-Code..." -ForegroundColor Yellow

# lib/ ersetzen
$libSrc = Join-Path $repoDir "lib"
$libDst = Join-Path $flutterDir "lib"
if (Test-Path $libDst) { Remove-Item $libDst -Recurse -Force }
Copy-Item $libSrc $libDst -Recurse
Write-Host "      lib/ kopiert." -ForegroundColor Gray

# pubspec.yaml ersetzen
Copy-Item (Join-Path $repoDir "pubspec.yaml") (Join-Path $flutterDir "pubspec.yaml") -Force
Write-Host "      pubspec.yaml kopiert." -ForegroundColor Gray

# .env kopieren
Copy-Item (Join-Path $repoDir ".env") (Join-Path $flutterDir ".env") -Force
Write-Host "      .env kopiert." -ForegroundColor Gray

# assets/ kopieren
$assetsSrc = Join-Path $repoDir "assets"
$assetsDst = Join-Path $flutterDir "assets"
if (Test-Path $assetsSrc) {
    if (Test-Path $assetsDst) { Remove-Item $assetsDst -Recurse -Force }
    Copy-Item $assetsSrc $assetsDst -Recurse
    Write-Host "      assets/ kopiert." -ForegroundColor Gray
} else {
    # assets-Ordner anlegen damit Flutter nicht klagt
    New-Item -ItemType Directory -Path "$flutterDir\assets\images" -Force | Out-Null
    New-Item -ItemType Directory -Path "$flutterDir\assets\icons"  -Force | Out-Null
}

# --- 5. App-Name in AndroidManifest setzen ---
Write-Host "[4b] Setze App-Namen..." -ForegroundColor Yellow
$manifestPath = Join-Path $flutterDir "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw
    $manifest = $manifest -replace 'android:label="[^"]*"', 'android:label="StackSense"'
    Set-Content $manifestPath $manifest -Encoding UTF8
    Write-Host "      App-Name gesetzt." -ForegroundColor Gray
}

# --- 5. Dependencies installieren ---
Write-Host "[5/5] Installiere Dependencies (flutter pub get)..." -ForegroundColor Yellow
Set-Location $flutterDir
Invoke-Flutter pub get

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup abgeschlossen!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Naechste Schritte:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Projekt in Android Studio oeffnen:" -ForegroundColor Gray
Write-Host "     File -> Open -> $flutterDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Code-Generierung ausfuehren:" -ForegroundColor Gray
Write-Host "     dart run build_runner build --delete-conflicting-outputs" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. App starten:" -ForegroundColor Gray
Write-Host "     flutter run    (oder gruener Run-Button in Android Studio)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Flutter-Pfad gefunden unter:" -ForegroundColor Gray
Write-Host "     $flutterExe" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Tipp: Android-Handy per USB anschliessen und USB-Debugging" -ForegroundColor Yellow
Write-Host "  aktivieren (Einstellungen -> Entwickleroptionen)" -ForegroundColor Yellow
Write-Host ""
