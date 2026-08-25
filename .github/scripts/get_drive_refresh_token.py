"""
EINMALIGES lokales Hilfsskript — läuft NICHT in GitHub Actions. Holt einen
OAuth2-Refresh-Token für dein eigenes Google-Konto, damit der Upload-Schritt
im "Upgrade"-Workflow als DU hochlädt (dein Speicherkontingent) statt als
Service-Account (hat keins, siehe storageQuotaExceeded-Fehler).

Voraussetzung: OAuth-Client-ID vom Typ "Desktop-App" in der Google Cloud
Console angelegt (selbes Projekt wie die Drive API), Client-ID + Secret
zur Hand.

Aufruf (aus dem Projekt-Root):
    pip install google-auth-oauthlib
    python .github/scripts/get_drive_refresh_token.py

Öffnet einen Browser zur Anmeldung/Freigabe, druckt danach den Refresh-Token.
"""
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ["https://www.googleapis.com/auth/drive.file"]


def main() -> None:
    client_id = input("OAuth Client-ID: ").strip()
    client_secret = input("OAuth Client-Secret: ").strip()

    client_config = {
        "installed": {
            "client_id": client_id,
            "client_secret": client_secret,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "redirect_uris": ["http://localhost"],
        }
    }

    flow = InstalledAppFlow.from_client_config(client_config, SCOPES)
    creds = flow.run_local_server(port=0)

    print("\n" + "=" * 60)
    print("Fertig! Trage diese drei Werte als GitHub-Secrets ein:")
    print("=" * 60)
    print(f"GDRIVE_CLIENT_ID={client_id}")
    print(f"GDRIVE_CLIENT_SECRET={client_secret}")
    print(f"GDRIVE_REFRESH_TOKEN={creds.refresh_token}")
    print("=" * 60)


if __name__ == "__main__":
    main()
