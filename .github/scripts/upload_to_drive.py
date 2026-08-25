"""
Lädt die gebaute Release-APK in einen Google-Drive-Ordner hoch — läuft
ausschließlich im GitHub-Actions-Workflow (.github/workflows/upgrade.yml),
nicht Teil der Backend-Runtime.

Auth: OAuth2 als echtes Google-Konto (GDRIVE_CLIENT_ID/GDRIVE_CLIENT_SECRET/
GDRIVE_REFRESH_TOKEN, siehe get_drive_refresh_token.py) — NICHT ein
Service-Account. Service-Accounts haben auf normalen (Nicht-Workspace)
Google-Konten kein eigenes Speicherkontingent und können auch in geteilte
Ordner keine eigenen Dateien anlegen (storageQuotaExceeded), deshalb läuft
der Upload hier als der echte Kontoinhaber.

Aufruf:
    python upload_to_drive.py <pfad-zur-apk>
"""
import os
import re
import sys
from datetime import date
from pathlib import Path

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/drive.file"]
TOKEN_URI = "https://oauth2.googleapis.com/token"


def _read_pubspec_version(repo_root: Path) -> str:
    pubspec = (repo_root / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\S+)", pubspec, re.MULTILINE)
    return match.group(1) if match else "unbekannt"


def main() -> None:
    if len(sys.argv) != 2:
        print("Nutzung: python upload_to_drive.py <pfad-zur-apk>", file=sys.stderr)
        sys.exit(1)

    apk_path = Path(sys.argv[1])
    if not apk_path.is_file():
        print(f"APK nicht gefunden: {apk_path}", file=sys.stderr)
        sys.exit(1)

    client_id = os.environ.get("GDRIVE_CLIENT_ID")
    client_secret = os.environ.get("GDRIVE_CLIENT_SECRET")
    refresh_token = os.environ.get("GDRIVE_REFRESH_TOKEN")
    folder_id = os.environ.get("GDRIVE_FOLDER_ID")
    if not all([client_id, client_secret, refresh_token, folder_id]):
        print(
            "GDRIVE_CLIENT_ID, GDRIVE_CLIENT_SECRET, GDRIVE_REFRESH_TOKEN und "
            "GDRIVE_FOLDER_ID müssen gesetzt sein.",
            file=sys.stderr,
        )
        sys.exit(1)

    repo_root = Path(__file__).resolve().parent.parent.parent
    version = _read_pubspec_version(repo_root)
    filename = f"LifeLab-{version}-{date.today().isoformat()}.apk"

    creds = Credentials(
        token=None,
        refresh_token=refresh_token,
        client_id=client_id,
        client_secret=client_secret,
        token_uri=TOKEN_URI,
        scopes=SCOPES,
    )
    drive = build("drive", "v3", credentials=creds)

    metadata = {"name": filename, "parents": [folder_id]}
    media = MediaFileUpload(str(apk_path), mimetype="application/vnd.android.package-archive")
    uploaded = drive.files().create(
        body=metadata, media_body=media, fields="id, webViewLink",
    ).execute()

    print(f"Hochgeladen: {filename}")
    print(f"Drive-Link: {uploaded.get('webViewLink')}")


if __name__ == "__main__":
    main()
