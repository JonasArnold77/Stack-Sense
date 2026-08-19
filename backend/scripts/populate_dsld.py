"""
NIH DSLD (Dietary Supplement Label Database) — Vektordatenbank Population
============================================================================
Lädt reale Produktetiketten-Daten (tatsächlich verkaufte Dosierungen,
Warnhinweise) aus der NIH Dietary Supplement Label Database und speichert
eine Zusammenfassung pro Supplement als Vektor in supplement_facts.

Anders als die handkuratierten NIH-ODS/EFSA-Fakten sind das strukturierte,
maschinell aus echten Produktetiketten gelesene Daten — nützlich um
Claude-generierte Dosierungsangaben gegen reale Marktprodukte zu erden.

Quelle: https://api.ods.od.nih.gov/dsld/v9/ (Public Domain, US-Regierungswerk,
kein API-Key nötig).

Voraussetzungen:
    pip install fastembed psycopg2-binary httpx

Ausführen (aus dem backend/ Ordner):
    python scripts/populate_dsld.py
"""
import logging
import time

import httpx
import psycopg2
from fastembed import TextEmbedding

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

DB_CONFIG = {
    "host": "stacksense-db.chym26e8iw2p.eu-central-1.rds.amazonaws.com",
    "user": "stacksense",
    "password": "Jo790097",
    "dbname": "postgres",
    "port": 5432,
    "sslmode": "require",
}

DSLD_BASE = "https://api.ods.od.nih.gov/dsld/v9"
REQUEST_DELAY = 0.5


def search_products(client: httpx.Client, name: str, size: int = 5) -> list[dict]:
    try:
        resp = client.get(
            f"{DSLD_BASE}/search-filter",
            params={"q": name, "size": size},
            timeout=20.0,
        )
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        logger.warning(f"  DSLD-Suche fehlgeschlagen für '{name}': {e}")
        return []

    # DSLD-Response-Form ist nicht dokumentiert-stabil — robust gegen
    # ES-verschachtelt ({"hits": {"hits": [...]}}), flache Liste ({"hits": [...]})
    # oder ein "results"-Top-Level-Key.
    hits_obj = data.get("hits")
    if isinstance(hits_obj, dict):
        return hits_obj.get("hits") or []
    if isinstance(hits_obj, list):
        return hits_obj
    return data.get("results") or []


def fetch_label(client: httpx.Client, product_id) -> dict | None:
    try:
        resp = client.get(f"{DSLD_BASE}/label/{product_id}", timeout=20.0)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        logger.warning(f"  DSLD-Label {product_id} fehlgeschlagen: {e}")
        return None


def _pick_on_market_id(hits: list[dict]) -> tuple[str, str] | None:
    """Gibt (id, fullName) des ersten aktiven (nicht vom Markt genommenen) Treffers zurück."""
    for hit in hits:
        # search-filter kann rohe Dokumente oder ES-artige {_source: {...}} liefern
        source = hit.get("_source", hit)
        if source.get("offMarket") in (0, False, None):
            product_id = source.get("_id") or hit.get("_id") or source.get("id")
            full_name = source.get("fullName") or "Unbekanntes Produkt"
            if product_id:
                return str(product_id), full_name
    return None


def _extract_quantity(row: dict) -> str | None:
    """Formatiert die Mengenangabe einer Ingredient-Row, egal ob Liste oder Dict."""
    quantity = row.get("quantity")
    if isinstance(quantity, list) and quantity:
        entries = quantity
    elif isinstance(quantity, dict):
        entries = [quantity]
    else:
        return None

    parts = []
    for q in entries:
        amount = q.get("quantity") or q.get("amount")
        unit = q.get("unit") or ""
        if amount is not None:
            parts.append(f"{amount}{unit}")
    return ", ".join(parts) if parts else None


_WARNING_TYPE_KEYWORDS = ("warn", "caution", "allerg", "contraindic", "pregnan", "keep out")


def build_fact_text(supplement_name: str, label: dict, ingredient_line: str | None) -> str:
    full_name = label.get("fullName", "Unbekanntes Produkt")
    brand_name = label.get("brandName", "")
    serving_sizes = label.get("servingSizes") or []
    serving_desc = ""
    if serving_sizes:
        s = serving_sizes[0]
        qty = s.get("maxQuantity") or s.get("minQuantity") or s.get("quantity") or ""
        serving_desc = f"{qty} {s.get('unit', '')}".strip()

    # Nur Statements mit sicherheitsrelevantem Typ als "Warnhinweis" labeln —
    # DSLD-Statements enthalten sonst auch reine Marketing-Texte ("General Statements").
    statements = label.get("statements") or []
    warning_texts = []
    for s in statements:
        if not isinstance(s, dict):
            continue
        stype = (s.get("type") or "").lower()
        notes = s.get("notes") or ""
        if notes and any(kw in stype or kw in notes.lower() for kw in _WARNING_TYPE_KEYWORDS):
            warning_texts.append(notes)

    lines = [
        f"NIH DSLD Marktprodukt-Beispiel für {supplement_name}: '{full_name}'"
        + (f" (Marke: {brand_name})" if brand_name else "") + ".",
    ]
    if ingredient_line:
        lines.append(f"Enthält laut Etikett: {ingredient_line}"
                      + (f" pro Portion ({serving_desc})" if serving_desc else "") + ".")
    if warning_texts:
        lines.append("Warnhinweise auf dem Etikett: " + " | ".join(warning_texts[:3]))

    lines.append(
        "Hinweis: Dies ist ein einzelnes reales Marktprodukt aus der NIH DSLD-Datenbank, "
        "keine allgemeine Dosierungsempfehlung — Produkte variieren stark in Dosierung und Form."
    )
    return " ".join(lines)


def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)


def get_supplements(cur) -> list[tuple[str, str]]:
    cur.execute("SELECT slug, name FROM supplements ORDER BY slug")
    return cur.fetchall()


def upsert_fact(cur, supplement_slug: str, content: str, embedding_list: list):
    embedding_str = str(embedding_list)
    cur.execute("""
        INSERT INTO supplement_facts
            (supplement_slug, fact_type, content, embedding, source)
        VALUES (%s, %s, %s, %s::vector, %s)
        ON CONFLICT DO NOTHING
    """, (
        supplement_slug,
        "nih_dsld_label",
        content,
        embedding_str,
        "nih_dsld",
    ))


def main():
    logger.info("Lade fastembed Modell...")
    model = TextEmbedding("BAAI/bge-small-en-v1.5")
    logger.info("Modell geladen.")

    conn = get_db_connection()
    conn.autocommit = False
    cur = conn.cursor()

    supplements = get_supplements(cur)
    logger.info(f"{len(supplements)} Supplements in DB gefunden.")

    client = httpx.Client()
    total_inserted = 0
    total_skipped = 0

    for i, (slug, name) in enumerate(supplements, 1):
        logger.info(f"[{i}/{len(supplements)}] {name} ({slug})")

        hits = search_products(client, name)
        time.sleep(REQUEST_DELAY)
        picked = _pick_on_market_id(hits)
        if not picked:
            total_skipped += 1
            continue

        product_id, _ = picked
        label = fetch_label(client, product_id)
        time.sleep(REQUEST_DELAY)
        if not label:
            total_skipped += 1
            continue

        ingredient_line = None
        for row in label.get("ingredientRows") or []:
            row_name = (row.get("name") or "").lower()
            name_words = [w for w in name.lower().split() if len(w) > 2]
            if any(w in row_name for w in name_words):
                qty = _extract_quantity(row)
                if qty:
                    ingredient_line = f"{row.get('name')}: {qty}"
                    break

        if not ingredient_line:
            # Kein eindeutiger Dosierungs-Treffer — keinen unsicheren Fakt speichern
            total_skipped += 1
            continue

        content = build_fact_text(name, label, ingredient_line)
        embedding = list(model.embed([content]))[0].tolist()

        # RDS-Verbindung kann während der mehrminütigen Laufzeit idle-timeout-
        # bedingt wegbrechen — bei Verbindungsverlust einmal neu verbinden und
        # den Insert wiederholen (upsert_fact ist dank ON CONFLICT idempotent).
        for attempt in range(2):
            try:
                upsert_fact(cur, slug, content, embedding)
                conn.commit()
                break
            except psycopg2.OperationalError as e:
                logger.warning(f"  DB-Verbindung verloren, reconnect... ({e})")
                try:
                    conn.close()
                except Exception:
                    pass
                conn = get_db_connection()
                conn.autocommit = False
                cur = conn.cursor()

        total_inserted += 1
        logger.info(f"  ✓ {ingredient_line}")

    client.close()
    cur.close()
    conn.close()

    logger.info(f"""
╔══════════════════════════════════════════╗
║  NIH DSLD Population abgeschlossen       ║
║  Eingefügt:  {total_inserted:>4} Einträge              ║
║  Übersprungen:{total_skipped:>4} (kein sicherer Treffer)  ║
╚══════════════════════════════════════════╝
""")


if __name__ == "__main__":
    main()
