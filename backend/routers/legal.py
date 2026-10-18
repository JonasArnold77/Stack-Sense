"""Öffentliche Rechtstexte (Datenschutzerklärung) — von Google Play verlangt."""
from html import escape

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["Legal"])

# Angaben des Verantwortlichen (Pflicht nach Art. 13 DSGVO).
CONTROLLER_NAME = "Jonas Arnold"
CONTROLLER_ADDRESS = "Gehrenweg 1, 79576 Weil am Rhein, Deutschland"
CONTROLLER_EMAIL = "lynxian.gaming@gmail.com"
STAND = "18. Oktober 2026"

_PAGE = """<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Datenschutzerklärung – VitaShift</title>
<style>
  body {{ font: 16px/1.6 system-ui, sans-serif; max-width: 760px; margin: 0 auto; padding: 24px 16px 64px; color: #1b2a4a; }}
  h1 {{ font-size: 1.7rem; }} h2 {{ font-size: 1.15rem; margin-top: 2rem; }}
  a {{ color: #2c5ba2; }}
  @media (prefers-color-scheme: dark) {{ body {{ background: #10192b; color: #e6ecf7; }} a {{ color: #8fb4ee; }} }}
</style>
</head>
<body>
<h1>Datenschutzerklärung</h1>
<p>Stand: {stand}</p>

<h2>1. Verantwortlicher</h2>
<p>{name}<br>{address}<br>E-Mail: <a href="mailto:{email}">{email}</a></p>

<h2>2. Worum es in der App geht</h2>
<p>VitaShift gibt dir personalisierte, evidenzbasierte Hinweise zu Nahrungsergänzungsmitteln und
lässt dich deinen Stack und deine Check-ins verfolgen. Die App ersetzt keine ärztliche Beratung,
Diagnose oder Behandlung.</p>

<h2>3. Welche Daten wir verarbeiten</h2>
<ul>
  <li><strong>Konto:</strong> E-Mail-Adresse und Anmeldedaten (Registrierung per E-Mail/Passwort oder Google-Anmeldung), Zeitpunkt des letzten Logins.</li>
  <li><strong>Profil (Gesundheitsdaten):</strong> Alter, Geschlecht, Sportlevel, Vorerkrankungen, eingenommene Medikamente, Schwangerschaft – nur soweit du sie im Onboarding oder Profil angibst.</li>
  <li><strong>Nutzung:</strong> dein Supplement-Stack, Einnahmezeiten und Lagerbestand, Ziele, Check-in-Antworten (z. B. Schlaf, Energie, Fokus, Stimmung) sowie eine zufällige Geräte-Kennung für die Zuordnung der Check-ins.</li>
  <li><strong>Health Connect (optional):</strong> Wenn du es erlaubst, liest die App Schritte, Herzfrequenz, HRV, Schlaf, Training, Kalorien, Sauerstoffsättigung, Atemfrequenz, Körpertemperatur und Gewicht aus Android Health Connect. Diese Daten werden nur auf deinem Gerät ausgewertet und <strong>nicht an unsere Server übertragen</strong>. Du kannst den Zugriff jederzeit in Health Connect widerrufen.</li>
</ul>

<h2>4. Zwecke und Rechtsgrundlagen</h2>
<ul>
  <li>Bereitstellung von Konto und App-Funktionen: Art. 6 Abs. 1 lit. b DSGVO.</li>
  <li>Verarbeitung von Gesundheitsdaten (Profil, Medikamente, Vorerkrankungen) für personalisierte Empfehlungen und Wechselwirkungs-Hinweise: Deine ausdrückliche Einwilligung, Art. 9 Abs. 2 lit. a DSGVO. Du kannst sie jederzeit mit Wirkung für die Zukunft widerrufen.</li>
  <li>Auswertung der Health-Connect-Daten auf dem Gerät: Deine Einwilligung (Berechtigungsdialog), Art. 9 Abs. 2 lit. a DSGVO.</li>
  <li>Sicherheit und Fehlerbehebung: berechtigtes Interesse, Art. 6 Abs. 1 lit. f DSGVO.</li>
</ul>

<h2>5. Empfänger und Auftragsverarbeiter</h2>
<ul>
  <li><strong>Amazon Web Services (AWS):</strong> Hosting des Backends und der Datenbank sowie Anmeldung über Amazon Cognito.</li>
  <li><strong>Anthropic (Claude):</strong> Für Empfehlungen werden Teile deines Profils (z. B. Alter, Geschlecht, Vorerkrankungen, Medikamente) und deine gewählten Ziele an die KI von Anthropic gesendet. Dabei kann eine Übermittlung in die USA stattfinden; sie stützt sich auf Standardvertragsklauseln bzw. eine Zertifizierung unter dem EU-US Data Privacy Framework.</li>
  <li><strong>Google:</strong> nur wenn du die Google-Anmeldung nutzt.</li>
  <li><strong>PubMed (NCBI):</strong> Für Studienrecherchen werden ausschließlich Suchbegriffe zu Supplements abgefragt, keine personenbezogenen Daten.</li>
</ul>
<p>Eine Weitergabe zu Werbezwecken findet nicht statt. Wir verwenden keine Werbe- oder Tracking-Dienste.</p>

<h2>6. Community-Auswertungen</h2>
<p>Für Hinweise wie „X % der Nutzer berichten Verbesserung“ werden Check-in-Daten nur zusammengefasst und ohne Rückschluss auf einzelne Personen angezeigt.</p>

<h2>7. Speicherdauer und Löschung</h2>
<p>Wir speichern deine Daten, solange dein Konto besteht. Du kannst die Löschung deines Kontos und aller zugehörigen Daten jederzeit per E-Mail an <a href="mailto:{email}">{email}</a> verlangen.</p>

<h2>8. Deine Rechte</h2>
<p>Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch (Art. 15–21 DSGVO) sowie auf Widerruf erteilter Einwilligungen. Außerdem kannst du dich bei einer Datenschutz-Aufsichtsbehörde beschweren.</p>

<h2>9. Alter</h2>
<p>Die App richtet sich nicht an Personen unter 16 Jahren.</p>

<h2>10. Änderungen</h2>
<p>Wir passen diese Erklärung an, wenn sich die App oder die Rechtslage ändert. Es gilt die jeweils hier veröffentlichte Fassung.</p>
</body>
</html>
"""


@router.get("/datenschutz", response_class=HTMLResponse, include_in_schema=False)
async def datenschutz() -> HTMLResponse:
    return HTMLResponse(
        _PAGE.format(
            stand=escape(STAND),
            name=escape(CONTROLLER_NAME),
            address=escape(CONTROLLER_ADDRESS),
            email=escape(CONTROLLER_EMAIL),
        )
    )
