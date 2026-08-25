"""
Admin-Seite — internes Tool zur Multi-Tenancy-Verwaltung.

Eine einzelne, in sich geschlossene HTML-Seite (kein Build-Step, kein
Static-File-Mount nötig). Login läuft über dieselbe Cognito User-Pool wie
die Flutter-App (USER_SRP_AUTH, siehe lib/amplifyconfiguration.dart) via
`amazon-cognito-identity-js` per CDN — keine eigene Auth-Logik, kein SRP
von Hand implementiert. Nach Login werden alle Admin-Calls mit dem
Cognito-ID-Token (Bearer) an die bestehende `require_admin`-Prüfung
gesendet — exakt dieselbe Autorisierung wie in der App.
"""
from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["Admin — Seite"])

# Dieselbe Cognito User Pool wie lib/amplifyconfiguration.dart
_COGNITO_POOL_ID = "eu-central-1_3otc0Dnsl"
_COGNITO_CLIENT_ID = "7pgjnt7eortngc3nkki8c6oa3p"

_HTML = """<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LifeLab Admin — Parteien-Verwaltung</title>
<script src="https://unpkg.com/amazon-cognito-identity-js@6/dist/amazon-cognito-identity.min.js"></script>
<style>
  :root { color-scheme: light dark; }
  body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; max-width: 960px;
         margin: 40px auto; padding: 0 20px; line-height: 1.5; }
  h1 { font-size: 1.4rem; }
  h2 { font-size: 1.1rem; margin-top: 2.5rem; }
  #login-box { max-width: 360px; margin: 80px auto; }
  input, select { display: block; width: 100%; padding: 8px; margin: 6px 0 14px;
                  box-sizing: border-box; font-size: 1rem; }
  button { padding: 8px 16px; cursor: pointer; font-size: 0.95rem; margin-right: 6px; }
  button.primary { background: #4f46e5; color: white; border: none; border-radius: 6px; }
  button.danger { background: #dc2626; color: white; border: none; border-radius: 6px; }
  button.ghost { background: transparent; border: 1px solid #999; border-radius: 6px; }
  table { width: 100%; border-collapse: collapse; margin-top: 10px; }
  th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; font-size: 0.9rem; }
  .badge { padding: 2px 8px; border-radius: 10px; font-size: 0.75rem; }
  .badge.on { background: #16a34a; color: white; }
  .badge.off { background: #9ca3af; color: white; }
  #app { display: none; }
  #error { color: #dc2626; margin: 10px 0; }
  dialog { border-radius: 8px; border: none; padding: 20px; min-width: 340px; }
  label.feat { display: inline-block; margin-right: 14px; font-size: 0.9rem; font-weight: normal; }
  code { font-size: 0.85rem; }
</style>
</head>
<body>

<div id="login-box">
  <h1>LifeLab Admin</h1>
  <p>Login mit deinem bestehenden Admin-Account.</p>
  <input id="login-email" type="email" placeholder="E-Mail">
  <input id="login-password" type="password" placeholder="Passwort">
  <button class="primary" onclick="doLogin()">Login</button>
  <div id="error"></div>
</div>

<div id="app">
  <h1>LifeLab Admin — Parteien-Verwaltung</h1>

  <h2>Upgrade</h2>
  <p>Baut eine neue Release-APK, lädt sie nach Google Drive hoch und deployt
     das Backend — läuft als GitHub-Actions-Workflow im Hintergrund (einige
     Minuten), diese Seite wartet nicht darauf.</p>
  <button class="primary" onclick="triggerUpgrade()">🚀 Upgrade auslösen</button>
  <span id="upgrade-status"></span>

  <h2>Parteien</h2>
  <button class="primary" onclick="openTenantDialog()">+ Neue Partei</button>
  <table id="tenant-table">
    <thead><tr><th>ID</th><th>Name</th><th>Status</th><th>Features</th><th>Farbe</th><th></th></tr></thead>
    <tbody></tbody>
  </table>

  <h2>Nutzer</h2>
  <table id="user-table">
    <thead><tr><th>E-Mail</th><th>Rolle</th><th>Partei</th><th></th></tr></thead>
    <tbody></tbody>
  </table>
</div>

<dialog id="tenant-dialog">
  <h2 id="tenant-dialog-title">Neue Partei</h2>
  <input type="hidden" id="td-editing-id">
  <label>ID (Slug, z.B. "acme-corp")</label>
  <input id="td-id" placeholder="acme-corp">
  <label>Name der Partei</label>
  <input id="td-name" placeholder="Acme Corp">
  <label>App-Anzeigename (optional, sonst "LifeLab")</label>
  <input id="td-appname" placeholder="Acme Health">
  <label>Primärfarbe (optional)</label>
  <input id="td-color" type="color" value="#4f46e5">
  <label>Features</label>
  <div id="td-features">
    <label class="feat"><input type="checkbox" value="basis_supplementierung"> Basis-Supplementierung</label>
    <label class="feat"><input type="checkbox" value="phasenziele"> Phasenziele</label>
    <label class="feat"><input type="checkbox" value="problemfelder"> Problemfelder</label>
    <label class="feat"><input type="checkbox" value="insights"> Insights</label>
  </div>
  <div style="margin-top:16px">
    <button class="primary" onclick="saveTenant()">Speichern</button>
    <button class="ghost" onclick="document.getElementById('tenant-dialog').close()">Abbrechen</button>
  </div>
</dialog>

<script>
const POOL_ID = "__POOL_ID__";
const CLIENT_ID = "__CLIENT_ID__";
const API_BASE = window.location.origin + "/api/v1";

const userPool = new AmazonCognitoIdentity.CognitoUserPool({
  UserPoolId: POOL_ID, ClientId: CLIENT_ID,
});

let idToken = null;
let tenantsCache = [];

function doLogin() {
  const email = document.getElementById("login-email").value.trim();
  const password = document.getElementById("login-password").value;
  document.getElementById("error").textContent = "";

  const authDetails = new AmazonCognitoIdentity.AuthenticationDetails({
    Username: email, Password: password,
  });
  const cognitoUser = new AmazonCognitoIdentity.CognitoUser({
    Username: email, Pool: userPool,
  });
  cognitoUser.authenticateUser(authDetails, {
    onSuccess: (session) => {
      idToken = session.getIdToken().getJwtToken();
      document.getElementById("login-box").style.display = "none";
      document.getElementById("app").style.display = "block";
      loadTenants();
      loadUsers();
    },
    onFailure: (err) => {
      document.getElementById("error").textContent = err.message || "Login fehlgeschlagen.";
    },
  });
}

async function api(path, options) {
  options = options || {};
  options.headers = Object.assign({
    "Content-Type": "application/json",
    "Authorization": "Bearer " + idToken,
  }, options.headers || {});
  const res = await fetch(API_BASE + path, options);
  if (!res.ok) {
    const body = await res.text();
    throw new Error("HTTP " + res.status + ": " + body);
  }
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

async function triggerUpgrade() {
  const status = document.getElementById("upgrade-status");
  status.textContent = " Wird ausgelöst…";
  try {
    const result = await api("/admin/upgrade", { method: "POST" });
    status.innerHTML = ` ✓ Gestartet — <a href="${result.actions_url}" target="_blank">Status auf GitHub verfolgen</a>`;
  } catch (e) {
    status.textContent = " Fehler: " + e.message;
  }
}

async function loadTenants() {
  tenantsCache = await api("/admin/tenants");
  const tbody = document.querySelector("#tenant-table tbody");
  tbody.innerHTML = "";
  for (const t of tenantsCache) {
    const tr = document.createElement("tr");
    const featureList = Object.keys(t.features || {}).filter(k => t.features[k]).join(", ") || "—";
    const color = (t.branding && t.branding.primary_color) || "—";
    tr.innerHTML = `
      <td><code>${t.id}</code></td>
      <td>${t.name}</td>
      <td><span class="badge ${t.is_active ? 'on' : 'off'}">${t.is_active ? 'aktiv' : 'inaktiv'}</span></td>
      <td>${featureList}</td>
      <td>${color}</td>
      <td>
        <button class="ghost" onclick="editTenant('${t.id}')">Bearbeiten</button>
        ${t.is_active
          ? `<button class="ghost" onclick="unpublishTenant('${t.id}')">Deaktivieren</button>`
          : `<button class="primary" onclick="publishTenant('${t.id}')">Veröffentlichen</button>`}
      </td>`;
    tbody.appendChild(tr);
  }
  // Partei-Dropdown in der Nutzer-Tabelle mitaktualisieren
  loadUsers();
}

function openTenantDialog() {
  document.getElementById("tenant-dialog-title").textContent = "Neue Partei";
  document.getElementById("td-editing-id").value = "";
  document.getElementById("td-id").value = "";
  document.getElementById("td-id").disabled = false;
  document.getElementById("td-name").value = "";
  document.getElementById("td-appname").value = "";
  document.getElementById("td-color").value = "#4f46e5";
  document.querySelectorAll("#td-features input").forEach(cb => cb.checked = false);
  document.getElementById("tenant-dialog").showModal();
}

function editTenant(id) {
  const t = tenantsCache.find(x => x.id === id);
  if (!t) return;
  document.getElementById("tenant-dialog-title").textContent = "Partei bearbeiten";
  document.getElementById("td-editing-id").value = id;
  document.getElementById("td-id").value = id;
  document.getElementById("td-id").disabled = true;
  document.getElementById("td-name").value = t.name;
  document.getElementById("td-appname").value = (t.branding && t.branding.app_name) || "";
  document.getElementById("td-color").value = (t.branding && t.branding.primary_color) || "#4f46e5";
  document.querySelectorAll("#td-features input").forEach(cb => {
    cb.checked = !!(t.features && t.features[cb.value]);
  });
  document.getElementById("tenant-dialog").showModal();
}

async function saveTenant() {
  const editingId = document.getElementById("td-editing-id").value;
  const id = document.getElementById("td-id").value.trim();
  const name = document.getElementById("td-name").value.trim();
  const appName = document.getElementById("td-appname").value.trim();
  const color = document.getElementById("td-color").value;
  if (!id || !name) { alert("ID und Name sind Pflichtfelder."); return; }

  const features = {};
  document.querySelectorAll("#td-features input").forEach(cb => {
    features[cb.value] = cb.checked;
  });
  const branding = {};
  if (appName) branding.app_name = appName;
  if (color) branding.primary_color = color;

  try {
    if (editingId) {
      await api("/admin/tenants/" + editingId, {
        method: "PUT", body: JSON.stringify({ name, features, branding }),
      });
    } else {
      await api("/admin/tenants", {
        method: "POST", body: JSON.stringify({ id, name, features, branding }),
      });
    }
    document.getElementById("tenant-dialog").close();
    await loadTenants();
  } catch (e) {
    alert("Fehler: " + e.message);
  }
}

async function publishTenant(id) {
  await api("/admin/tenants/" + id + "/publish", { method: "POST" });
  await loadTenants();
}

async function unpublishTenant(id) {
  await api("/admin/tenants/" + id + "/unpublish", { method: "POST" });
  await loadTenants();
}

async function loadUsers() {
  const users = await api("/users/all");
  const tbody = document.querySelector("#user-table tbody");
  tbody.innerHTML = "";
  for (const u of users) {
    const tr = document.createElement("tr");
    const options = ['<option value="">— keine —</option>']
      .concat(tenantsCache.map(t =>
        `<option value="${t.id}" ${u.tenant_id === t.id ? "selected" : ""}>${t.name}</option>`));
    tr.innerHTML = `
      <td>${u.email}</td>
      <td>${u.role}</td>
      <td><select onchange="assignTenant('${u.id}', this.value)">${options.join("")}</select></td>
      <td></td>`;
    tbody.appendChild(tr);
  }
}

async function assignTenant(userId, tenantId) {
  try {
    await api("/users/" + userId + "/tenant", {
      method: "PUT", body: JSON.stringify({ tenant_id: tenantId || null }),
    });
  } catch (e) {
    alert("Fehler: " + e.message);
  }
}
</script>
</body>
</html>
"""


@router.get("/admin", response_class=HTMLResponse, summary="Admin-Tool (Multi-Tenancy)")
async def admin_page():
    html = _HTML.replace("__POOL_ID__", _COGNITO_POOL_ID).replace("__CLIENT_ID__", _COGNITO_CLIENT_ID)
    return HTMLResponse(content=html)
