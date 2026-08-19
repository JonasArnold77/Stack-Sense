"""
Europe PMC — Vektordatenbank Population (Studien-Ergänzung)
==============================================================
Ergänzt die bestehenden PubMed-Studien in `studies` um Treffer aus der
Europe PMC REST API. Europe PMC deckt teils zusätzliche Preprints/Journale
ab und liefert bei Open-Access-Artikeln zuverlässiger echten Abstract-Text
als NCBI E-utilities — mehr/bessere Retrieval-Treffer fürs RAG.

Quelle: https://www.ebi.ac.uk/europepmc/webservices/rest/ (kostenlos, kein
API-Key nötig).

Voraussetzungen:
    pip install fastembed psycopg2-binary httpx

Ausführen (aus dem backend/ Ordner):
    python scripts/populate_europepmc.py
"""
import html
import logging
import re
import time

import httpx
import psycopg2
from fastembed import TextEmbedding

_HTML_TAG_RE = re.compile(r"<[^>]+>")


def _clean_text(text: str) -> str:
    """Europe PMC liefert Titel/Abstracts teils mit rohem oder HTML-entity-
    escapetem Markup (<i>, &lt;i&gt; etc.) — vor dem Speichern bereinigen,
    damit RAG-only-Rohdaten sauber sind."""
    if not text:
        return text
    return _HTML_TAG_RE.sub("", html.unescape(text))

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

EPMC_BASE = "https://www.ebi.ac.uk/europepmc/webservices/rest/search"
MIN_YEAR = 2018
REQUEST_DELAY = 0.4


def search_europepmc(client: httpx.Client, query: str, max_results: int = 5) -> list[dict]:
    # SRC:MED beschränkt auf MEDLINE-indexierte (biomedizinische) Literatur —
    # ohne das driftet Europe PMC in fachfremde Treffer ab (Agrarwissenschaft,
    # Chemie etc.), weil es eine viel breitere Quellenbasis als PubMed indexiert.
    # Sortierung nach Relevanz (Default) statt Datum — sonst dominieren neue,
    # nur lose passende Papers vor tatsächlich einschlägigen älteren Studien.
    params = {
        "query": f"({query}) AND SRC:MED AND PUB_YEAR:[{MIN_YEAR} TO 3000]",
        "format": "json",
        "resultType": "core",
        "pageSize": max_results,
    }
    try:
        resp = client.get(EPMC_BASE, params=params, timeout=20.0)
        resp.raise_for_status()
        return resp.json().get("resultList", {}).get("result", [])
    except Exception as e:
        logger.warning(f"  Europe PMC-Fehler für '{query}': {e}")
        return []


def classify_evidence(abstract: str, title: str) -> str:
    text = ((title or "") + " " + (abstract or "")).lower()
    if any(w in text for w in ["randomized controlled trial", "rct", "meta-analysis", "systematic review", "placebo-controlled"]):
        return "green"
    elif any(w in text for w in ["pilot study", "observational", "cohort", "preliminary", "suggests", "may"]):
        return "yellow"
    else:
        return "red"


def study_exists(cur, pmid: str) -> bool:
    cur.execute("SELECT 1 FROM studies WHERE pmid = %s", (pmid,))
    return cur.fetchone() is not None


def insert_study(cur, slug: str, pmid: str, title: str, abstract: str,
                  year: int | None, evidence: str, embedding: list[float]):
    if study_exists(cur, pmid):
        return False
    cur.execute(
        """INSERT INTO studies
               (supplement_slug, pmid, title, abstract, year, evidence_level, embedding, source)
           VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
        (slug, pmid, title[:500], abstract[:1000], year, evidence, str(embedding), "europepmc"),
    )
    return True


def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)


def get_supplements(cur) -> list[tuple[str, str]]:
    cur.execute("SELECT slug, name FROM supplements ORDER BY slug")
    return cur.fetchall()


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

    for i, (slug, name) in enumerate(supplements, 1):
        logger.info(f"[{i}/{len(supplements)}] {name} ({slug})")

        results = search_europepmc(client, f"{name} supplementation randomized controlled trial")
        time.sleep(REQUEST_DELAY)

        rows = []
        for item in results:
            title = _clean_text(item.get("title") or "")
            abstract = _clean_text(item.get("abstractText") or "")
            if not title and not abstract:
                continue

            raw_pmid = item.get("pmid")
            pmid = raw_pmid if raw_pmid else f"epmc-{item.get('id', 'unknown')}"

            try:
                year = int(item.get("pubYear") or 0) or None
            except (TypeError, ValueError):
                year = None

            evidence = classify_evidence(abstract, title)
            embedding = list(model.embed([f"{title} {abstract}"]))[0].tolist()
            rows.append((pmid, title, abstract, year, evidence, embedding))

        # RDS-Verbindung kann während der (mehrere Minuten langen) Laufzeit
        # idle-timeout-bedingt wegbrechen, v.a. wenn ein Europe-PMC-Request
        # lange braucht — bei Verbindungsverlust einmal neu verbinden und
        # diesen Supplement-Batch erneut einfügen (INSERT ist idempotent
        # dank study_exists()-Check).
        inserted_here = 0
        for attempt in range(2):
            try:
                inserted_here = 0
                for pmid, title, abstract, year, evidence, embedding in rows:
                    if insert_study(cur, slug, pmid, title, abstract, year, evidence, embedding):
                        inserted_here += 1
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

        total_inserted += inserted_here
        if inserted_here:
            logger.info(f"  ✓ {inserted_here} neue Studien")

    client.close()
    cur.close()
    conn.close()

    logger.info(f"""
╔══════════════════════════════════════════╗
║  Europe PMC Population abgeschlossen     ║
║  Eingefügt:  {total_inserted:>4} neue Studien           ║
╚══════════════════════════════════════════╝
""")


if __name__ == "__main__":
    main()
