"""
openFDA CAERS — Vektordatenbank Population (Sicherheits-/Gefahrensignale)
==========================================================================
Lädt reale, gemeldete unerwünschte Ereignisse (Adverse Events) zu
Nahrungsergänzungsmitteln aus dem CFSAN Adverse Event Reporting System
(CAERS) der FDA, bereitgestellt über die openFDA API, und speichert eine
aggregierte Zusammenfassung pro Supplement als Vektor in supplement_facts.

Das ist die einzige Quelle im System, die auf echten (unvalidierten)
Verdachtsmeldungen aus der Praxis basiert statt auf Studien oder
Fact-Sheets — deckt "was ist in der Praxis schiefgegangen" ab.

Quelle: https://open.fda.gov/apis/food/event/ (US-Regierungsdaten, quartalsweise
aktualisiert, Rohdaten seit 2004). openFDA selbst weist ausdrücklich darauf hin,
dass die Meldungen unvalidiert sind und keine Kausalität belegen — dieser
Hinweis wird in jeden gespeicherten Fakt übernommen.

Voraussetzungen:
    pip install fastembed psycopg2-binary httpx

Ausführen (aus dem backend/ Ordner):
    python scripts/populate_openfda_caers.py
"""
import logging
import time
from collections import Counter

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

OPENFDA_BASE = "https://api.fda.gov/food/event.json"

# openFDA CAERS "outcomes" Vokabular für schwerwiegende Verläufe
SERIOUS_OUTCOMES = {
    "HOSPITALIZATION",
    "DEATH",
    "LIFE THREATENING",
    "DISABILITY",
    "CONGENITAL ANOMALY",
    "REQUIRED INTERVENTION",
    "OTHER SERIOUS (IMPORTANT MEDICAL EVENTS)",
}

# openFDA Rate-Limit ohne API-Key: 40 Requests/Minute, 1000/Tag
REQUEST_DELAY = 1.6


def fetch_events(client: httpx.Client, product_name: str, limit: int = 100) -> list[dict]:
    """Fragt openFDA nach Events, deren Produktname den Supplement-Namen enthält."""
    params = {
        "search": f'products.name_brand:"{product_name}"',
        "limit": limit,
    }
    try:
        resp = client.get(OPENFDA_BASE, params=params, timeout=20.0)
        if resp.status_code == 404:
            # openFDA gibt 404 zurück wenn keine Treffer existieren — kein Fehler
            return []
        resp.raise_for_status()
        return resp.json().get("results", [])
    except Exception as e:
        logger.warning(f"  openFDA-Fehler für '{product_name}': {e}")
        return []


def summarize(events: list[dict]) -> dict | None:
    if not events:
        return None

    reaction_counter: Counter = Counter()
    serious_count = 0

    for event in events:
        for reaction in event.get("reactions") or []:
            reaction_counter[reaction.title()] += 1
        outcomes = event.get("outcomes") or []
        if any(o.upper() in SERIOUS_OUTCOMES for o in outcomes):
            serious_count += 1

    top_reactions = [r for r, _ in reaction_counter.most_common(6)]

    return {
        "total": len(events),
        "serious": serious_count,
        "top_reactions": top_reactions,
    }


def build_fact_text(supplement_name: str, summary: dict) -> str:
    reactions_str = ", ".join(summary["top_reactions"]) if summary["top_reactions"] else "keine dominanten Muster"
    return (
        f"openFDA CAERS (FDA CFSAN Adverse Event Reporting System): "
        f"{summary['total']} gemeldete unerwünschte Ereignisse zu Produkten mit "
        f"'{supplement_name}' im Namen (Datenbasis seit 2004). "
        f"Häufigste gemeldete Reaktionen: {reactions_str}. "
        f"{summary['serious']} von {summary['total']} Meldungen mit schwerwiegendem Ausgang "
        f"(Krankenhausaufenthalt, lebensbedrohlich, bleibende Behinderung o.ä.). "
        f"WICHTIG: Dies sind unvalidierte Verdachtsmeldungen (Spontanberichte) — "
        f"sie belegen KEINE Kausalität und keine Häufigkeit in der Gesamtbevölkerung, "
        f"sondern zeigen nur, welche Reaktionen im Zusammenhang mit dem Produkt gemeldet wurden."
    )


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
        "openfda_caers_safety",
        content,
        embedding_str,
        "openfda_caers",
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
    total_no_data = 0

    for i, (slug, name) in enumerate(supplements, 1):
        logger.info(f"[{i}/{len(supplements)}] {name} ({slug})")
        events = fetch_events(client, name)
        summary = summarize(events)

        if summary is None:
            total_no_data += 1
            time.sleep(REQUEST_DELAY)
            continue

        content = build_fact_text(name, summary)
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
        logger.info(f"  ✓ {summary['total']} Events, {summary['serious']} schwerwiegend")

        time.sleep(REQUEST_DELAY)

    client.close()
    cur.close()
    conn.close()

    logger.info(f"""
╔══════════════════════════════════════════╗
║  openFDA CAERS Population abgeschlossen  ║
║  Eingefügt:      {total_inserted:>4} Einträge          ║
║  Keine Daten:    {total_no_data:>4} Supplements        ║
╚══════════════════════════════════════════╝
""")


if __name__ == "__main__":
    main()
