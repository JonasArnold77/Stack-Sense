# StackSense — Flutter Setup

## Schritt 1: Neues Flutter-Projekt anlegen

In Android Studio:

1. **File → New → New Project → Flutter**
2. Project name: `stacksense`
3. Project location: Wähle den Ordner `C:\Github\Stack Sense\` (NICHT in Stack-Sense selbst)
4. Organization: `com.stacksense`
5. Android language: **Kotlin**
6. iOS language: **Swift**
7. Platforms: **Android + iOS**
8. Klick **Create**

Danach alle Dateien aus diesem Repo (`lib/`, `pubspec.yaml`, `.env`) in das neue Flutter-Projekt-Verzeichnis kopieren.

---

## Schritt 2: Assets-Ordner anlegen

Im Flutter-Projektordner:
```
assets/
  images/   ← Bilder
  icons/    ← Icons
```

---

## Schritt 3: Dependencies installieren

Im Android Studio Terminal (unten):
```bash
flutter pub get
```

---

## Schritt 4: Code-Generierung ausführen

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Schritt 5: App starten

1. Emulator starten: **Device Manager → Play-Button**
2. Im Toolbar die App starten mit dem grünen **Run-Button**

Oder im Terminal:
```bash
flutter run
```

---

## Projektstruktur

```
lib/
├── main.dart                          # App-Einstieg
├── core/
│   ├── constants/app_constants.dart   # Alle Konstanten (Spacing, XP, etc.)
│   ├── router/app_router.dart         # Navigation (go_router)
│   └── theme/
│       ├── app_colors.dart            # Farben (Evidenzampel, Brand)
│       ├── app_text_styles.dart       # Typografie
│       └── app_theme.dart             # MaterialApp Theme
└── features/
    ├── onboarding/                    # Welcome + 3 Onboarding-Screens
    ├── home/                          # Shell mit Bottom Navigation
    ├── recommendations/               # Entdecken + Evidence Cards
    ├── stack/                         # Mein Stack
    ├── checkin/                       # Täglicher Check-in
    └── profile/                       # Profil + Level/XP
```

---

## Was kommt als nächstes (Phase 2)

- [ ] FastAPI Backend aufsetzen
- [ ] DSLD API Integration
- [ ] Claude API Anbindung für Empfehlungen
- [ ] Einnahme-Kalender implementieren
- [ ] Community-Daten (anonymisiert)
- [ ] Apple Health / Google Fit Integration
