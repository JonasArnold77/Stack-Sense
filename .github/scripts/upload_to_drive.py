"""
Lädt die gebaute Release-APK in einen Google-Drive-Ordner hoch — läuft
ausschließlich im GitHub-Actions-Workflow (.github/workflows/upgrade.yml),
nicht Teil der Backend-Runtime.

Auth: Service-Account-JSON aus GDRIVE_SERVICE_ACCOUNT_JSON (Secret, kompletter
JSON-Inhalt als String). Der Ziel-Ordner (GDRIVE_FOLDER_ID) muss vorher mit der
`client_email` des Service-Accounts geteilt worden sein (Editor-Rechte) —
ein Service-Account hat kein eigenes Speicherkontingent, kann aber in
geteilte Ordner schreiben.

Aufruf:
    python upload_to_drive.py <pfad-zur-apk>
"""
import json
import os
import re
import sys
from datetime import date
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/drive.file"]


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

    service_account_json = os.environ.get("GDRIVE_SERVICE_ACCOUNT_JSON")
    folder_id = os.environ.get("GDRIVE_FOLDER_ID")
    if not service_account_json or not folder_id:
        print("GDRIVE_SERVICE_ACCOUNT_JSON und GDRIVE_FOLDER_ID müssen gesetzt sein.", file=sys.stderr)
        sys.exit(1)

    repo_root = Path(__file__).resolve().parent.parent.parent
    version = _read_pubspec_version(repo_root)
    filename = f"LifeLab-{version}-{date.today().isoformat()}.apk"

    creds = service_account.Credentials.from_service_account_info(
        json.loads(service_account_json), scopes=SCOPES,
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
