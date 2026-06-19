# StackSense — AWS Cognito + RDS Setup

## Übersicht

| Dienst | Zweck |
|---|---|
| AWS Cognito User Pool | Login, Registrierung, Google OAuth, JWT-Token |
| AWS RDS PostgreSQL | users + user_profiles Tabellen |
| Elastic Beanstalk | FastAPI Backend (bereits vorhanden) |

---

## 1. Cognito User Pool erstellen

1. AWS Console → **Cognito** → **Create user pool**
2. Konfiguration:
   - **Sign-in options**: Email ✓
   - **Password policy**: Mindestlänge 8, Groß-/Kleinbuchstaben, Zahlen
   - **MFA**: Off
   - **Email**: Send email with Cognito (kostenlos bis 50 Mails/Tag)
3. **App client**:
   - Name: `stacksense-app`
   - **Auth flows**: `ALLOW_USER_SRP_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH`
   - **OAuth**: Aktivieren → Callback URL: `stacksense://callback`
   - Scopes: `email`, `openid`, `profile`
4. Pool erstellen → **Pool ID notieren** (z.B. `eu-central-1_AbCdEf`)
5. App client → **Client ID notieren**

---

## 2. Google OAuth einrichten (optional)

1. [Google Cloud Console](https://console.cloud.google.com) → **APIs & Services** → **Credentials**
2. **OAuth 2.0 Client ID erstellen** → Typ: Web Application
3. Authorized redirect URI:
   ```
   https://stacksense.auth.eu-central-1.amazoncognito.com/oauth2/idpresponse
   ```
4. **Client ID + Secret** kopieren
5. Cognito → User Pool → **Sign-in experience** → **Add identity provider**
   - Provider: Google
   - Client ID + Secret eintragen
   - Attribute mapping: `email → email`

---

## 3. Cognito Domain erstellen

1. Cognito → User Pool → **App integration** → **Domain**
2. **Cognito domain** wählen: `stacksense`
3. Resultat: `stacksense.auth.eu-central-1.amazoncognito.com`

---

## 4. Backend .env aktualisieren

```bash
# backend/.env
ANTHROPIC_API_KEY=sk-ant-...
DB_PASS=dein-rds-passwort

# NEU:
COGNITO_REGION=eu-central-1
COGNITO_USER_POOL_ID=eu-central-1_DEINE_POOL_ID
COGNITO_CLIENT_ID=DEIN_APP_CLIENT_ID
```

---

## 5. Flutter amplifyconfiguration.dart ausfüllen

`lib/amplifyconfiguration.dart` — folgende Platzhalter ersetzen:

| Platzhalter | Wert aus AWS Console |
|---|---|
| `DEINE_POOL_ID` | Pool ID (Schritt 1) |
| `DEIN_APP_CLIENT_ID` | App Client ID (Schritt 1) |
| `DEINE_COGNITO_DOMAIN` | Domain aus Schritt 3 |

---

## 6. Backend deployen

```bash
cd backend
eb deploy
```

Die DB-Tabellen werden beim ersten Start automatisch erstellt (`init_user_tables()`).

---

## 7. Erster Admin-Account

Nach dem ersten Login in der App, den User in der Datenbank zum Admin machen:

```sql
-- Direkt in RDS (über psql oder AWS Query Editor)
UPDATE users SET role = 'admin' WHERE email = 'deine@email.com';
```

Danach hat der User im Backend Zugriff auf `GET /api/v1/users/all` und `PUT /api/v1/users/{id}/role`.

---

## iOS: URL Scheme für Google OAuth

In Xcode → Info.plist → URL Types hinzufügen:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>stacksense</string>
      <string>com.googleusercontent.apps.DEIN_GOOGLE_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

## Android: URL Scheme für Google OAuth

`android/app/src/main/AndroidManifest.xml` — innerhalb von `<activity>`:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="stacksense" />
</intent-filter>
```
