"""
VectorService — RAG-Schicht zwischen dem Nutzeranfrage und Claude.
Sucht in der pgvector-DB nach relevanten PubMed-Studien und gibt
diese als Kontext-String für den Claude-Prompt zurück.
"""
import logging
import os
import re
from typing import Optional

try:
    import psycopg2
    _PSYCOPG2_AVAILABLE = True
except ImportError:
    psycopg2 = None
    _PSYCOPG2_AVAILABLE = False

logger = logging.getLogger(__name__)

# Optionaler Import — App startet auch wenn fastembed fehlt oder crasht
try:
    from fastembed import TextEmbedding
    _FASTEMBED_AVAILABLE = True
except Exception as e:
    logger.warning(f"fastembed nicht verfügbar: {e} — Vector-Suche deaktiviert")
    TextEmbedding = None
    _FASTEMBED_AVAILABLE = False

_model = None

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "stacksense-db.chym26e8iw2p.eu-central-1.rds.amazonaws.com"),
    "user": os.getenv("DB_USER", "stacksense"),
    "password": os.getenv("DB_PASS", "Jo790097"),
    "dbname": os.getenv("DB_NAME", "postgres"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "sslmode": "require",
}


def _get_model():
    """Lädt das Embedding-Modell einmalig beim ersten Aufruf (Singleton)."""
    global _model
    if not _FASTEMBED_AVAILABLE:
        return None
    if _model is None:
        logger.info("Lade fastembed Modell (BAAI/bge-small-en-v1.5, ONNX)...")
        _model = TextEmbedding("BAAI/bge-small-en-v1.5")
        logger.info("Embedding-Modell bereit.")
    return _model


def _get_conn():
    return psycopg2.connect(**DB_CONFIG)


def search_studies(query: str, supplement_names: list[str], top_k: int = 8) -> str:
    """
    Sucht in der pgvector-DB nach Studien UND kuratierten Fakten die zum Query passen.
    Kombiniert Ergebnisse aus:
      - studies (PubMed-Studien)
      - supplement_facts (EFSA Health Claims + NIH ODS Factsheets)

    Args:
        query: Der Nutzer-Kontext (Ziel + Profil)
        supplement_names: Filter auf diese Supplements (leer = kein Filter)
        top_k: Wie viele Ergebnisse pro Quelle zurückgegeben werden

    Returns:
        Formatierter String mit Studientiteln, Abstracts und kuratierten Fakten
    """
    try:
        if not _PSYCOPG2_AVAILABLE or not _FASTEMBED_AVAILABLE:
            return ""
        model = _get_model()
        if model is None:
            return ""
        embedding = list(model.embed([query]))[0].tolist()
        embedding_str = str(embedding)

        conn = _get_conn()
        cur = conn.cursor()

        # ── 1. PubMed Studien ────────────────────────────────────────────────
        if supplement_names:
            placeholders = ", ".join(["%s"] * len(supplement_names))
            cur.execute(
                f"""
                SELECT s.supplement_slug, s.title, s.abstract, s.year, s.evidence_level,
                       1 - (s.embedding <=> %s::vector) AS similarity,
                       COALESCE(s.source, 'pubmed') AS source
                FROM studies s
                WHERE s.supplement_slug IN ({placeholders})
                  AND s.abstract IS NOT NULL
                ORDER BY s.embedding <=> %s::vector
                LIMIT %s
                """,
                (embedding_str, *supplement_names, embedding_str, top_k),
            )
        else:
            cur.execute(
                """
                SELECT supplement_slug, title, abstract, year, evidence_level,
                       1 - (embedding <=> %s::vector) AS similarity,
                       COALESCE(source, 'pubmed') AS source
                FROM studies
                WHERE abstract IS NOT NULL
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (embedding_str, embedding_str, top_k),
            )
        study_rows = cur.fetchall()

        # ── 2. Kuratierte Fakten (EFSA + NIH ODS) ───────────────────────────
        # Etwas weniger Ergebnisse als Studien — Kontext-Budget schonen
        facts_limit = max(4, top_k // 2)
        if supplement_names:
            placeholders = ", ".join(["%s"] * len(supplement_names))
            cur.execute(
                f"""
                SELECT f.supplement_slug, f.fact_type, f.content,
                       1 - (f.embedding <=> %s::vector) AS similarity,
                       COALESCE(f.source, 'manual') AS source
                FROM supplement_facts f
                WHERE f.supplement_slug IN ({placeholders})
                  AND f.content IS NOT NULL
                ORDER BY f.embedding <=> %s::vector
                LIMIT %s
                """,
                (embedding_str, *supplement_names, embedding_str, facts_limit),
            )
        else:
            cur.execute(
                """
                SELECT supplement_slug, fact_type, content,
                       1 - (embedding <=> %s::vector) AS similarity,
                       COALESCE(source, 'manual') AS source
                FROM supplement_facts
                WHERE content IS NOT NULL
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (embedding_str, embedding_str, facts_limit),
            )
        fact_rows = cur.fetchall()

        cur.close()
        conn.close()

        if not study_rows and not fact_rows:
            return ""

        parts = []

        # ── PubMed-Ergebnisse formatieren ────────────────────────────────────
        if study_rows:
            parts.append("=== PubMed Studienbasis ===")
            level_labels = {
                "green": "✅ RCT/Meta-Analyse",
                "yellow": "⚠️ Pilotstudie",
                "red": "❌ Keine starke Evidenz",
            }
            for slug, title, abstract, year, evidence, similarity, source in study_rows:
                level_label = level_labels.get(evidence, "?")
                parts.append(
                    f"\n[{level_label}] {title} ({year}) — {slug}\n"
                    f"Abstract: {abstract[:500]}..."
                )

        # ── EFSA/NIH ODS/openFDA/DSLD Fakten formatieren ────────────────────
        if fact_rows:
            parts.append("\n=== Kuratierte Datenbanken ===")
            source_labels = {
                "efsa": "🇪🇺 EFSA EU Health Claim",
                "nih_ods": "🏛️ NIH ODS Factsheet",
                "openfda_caers": "⚠️ openFDA CAERS (gemeldete unerwünschte Ereignisse, unvalidiert)",
                "nih_dsld": "🏷️ NIH DSLD (reales Marktprodukt-Etikett)",
                "manual": "📋 Kuratiert",
            }
            for slug, fact_type, content, similarity, source in fact_rows:
                source_label = source_labels.get(source, "📋 Quelle")
                # Nur ersten Absatz des Inhalts — Context-Budget schonen
                content_preview = content.split("\n\n")[1] if "\n\n" in content else content
                parts.append(
                    f"\n[{source_label}] {slug}\n"
                    f"{content_preview[:500]}..."
                )

        return "\n".join(parts)

    except Exception as e:
        logger.warning(f"Vector-Suche fehlgeschlagen (non-fatal): {e}")
        return ""  # Graceful degradation — Claude antwortet ohne DB-Kontext


def search_supplements(query: str, limit: int = 10) -> list[dict]:
    """
    Schnelle, tippfehler-/schreibweise-tolerante Suche gegen die `supplements`-
    Tabelle — kein LLM-Aufruf, nur ein SQL-Query. Normalisiert Leerzeichen und
    Bindestriche auf beiden Seiten weg, damit "Vitamin B", "Vitamin-B" und
    "VitaminB" alle z.B. "Vitamin B12" finden.

    Returns:
        Liste von {id, name, category}, Präfix-Treffer zuerst.
    """
    normalized = re.sub(r"[-\s]+", "", query.strip().lower())
    if not normalized:
        return []
    if not _PSYCOPG2_AVAILABLE:
        return []

    try:
        conn = _get_conn()
        cur = conn.cursor()
        # Wildcards werden in Python vorbereitet (nicht in der SQL-Vorlage) —
        # psycopg2 verwechselt sonst rohe '%'-Zeichen im Query-Text mit
        # %s-Platzhaltern.
        like_substr = f"%{normalized}%"
        like_prefix = f"{normalized}%"
        cur.execute(
            """
            SELECT slug, name, category
            FROM supplements
            WHERE regexp_replace(lower(name), '[-\\s]+', '', 'g') LIKE %s
            ORDER BY
                CASE WHEN regexp_replace(lower(name), '[-\\s]+', '', 'g') LIKE %s
                     THEN 0 ELSE 1 END,
                name
            LIMIT %s
            """,
            (like_substr, like_prefix, limit),
        )
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return [{"id": slug, "name": name, "category": category} for slug, name, category in rows]
    except Exception as e:
        logger.warning(f"Supplement-Suche fehlgeschlagen (non-fatal): {e}")
        return []


def get_precomputed_ranking(goal: str, db_only: bool) -> list[dict]:
    """Lädt die vorberechnete Grundrangliste für ein Themenfeld
    (siehe scripts/precompute_recommendations.py). Leere Liste = noch nicht
    vorberechnet oder DB nicht erreichbar."""
    try:
        conn = _get_conn()
        cur = conn.cursor()
        cur.execute(
            """
            SELECT supplement_id, name, base_relevance_score
            FROM precomputed_goal_ranking
            WHERE goal = %s AND db_only = %s
            ORDER BY base_relevance_score DESC
            """,
            (goal, db_only),
        )
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return [
            {"id": slug, "name": name, "base_relevance_score": score}
            for slug, name, score in rows
        ]
    except Exception as e:
        logger.warning(f"Precomputed-Ranking-Abruf fehlgeschlagen (non-fatal): {e}")
        return []


def get_precomputed_supplement_info(supplement_ids: list[str], db_only: bool) -> dict[str, dict]:
    """Lädt vorberechnete Zusatzfelder (Einfach erklärt/Lebensmittel/Einnahme)
    für mehrere Supplement-IDs auf einmal. Fehlende IDs tauchen im Ergebnis-Dict
    einfach nicht auf (Aufrufer muss Fallbacks bereitstellen)."""
    if not supplement_ids:
        return {}
    try:
        conn = _get_conn()
        cur = conn.cursor()
        placeholders = ", ".join(["%s"] * len(supplement_ids))
        cur.execute(
            f"""
            SELECT supplement_id, simple_explanation, food_sources, dosage, intake_time, intake_hint
            FROM precomputed_supplement_info
            WHERE db_only = %s AND supplement_id IN ({placeholders})
            """,
            (db_only, *supplement_ids),
        )
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return {
            slug: {
                "simple_explanation": explanation,
                "food_sources": food_sources,
                "dosage": dosage,
                "intake_time": intake_time,
                "intake_hint": intake_hint,
            }
            for slug, explanation, food_sources, dosage, intake_time, intake_hint in rows
        }
    except Exception as e:
        logger.warning(f"Precomputed-Supplement-Info-Abruf fehlgeschlagen (non-fatal): {e}")
        return {}


def get_precomputed_supplement_info_single(supplement_id: str) -> dict | None:
    """Wie get_precomputed_supplement_info, aber für einen einzelnen Supplement
    ohne bekannten db_only-Kontext (z.B. /explain, /food-sources — nehmen kein
    db_only entgegen). Bevorzugt die db_only=False-Zeile (allgemeiner/weniger
    restriktiv), fällt sonst auf db_only=True zurück."""
    try:
        conn = _get_conn()
        cur = conn.cursor()
        cur.execute(
            """
            SELECT simple_explanation, food_sources
            FROM precomputed_supplement_info
            WHERE supplement_id = %s
            ORDER BY db_only ASC
            LIMIT 1
            """,
            (supplement_id,),
        )
        row = cur.fetchone()
        cur.close()
        conn.close()
        if not row:
            return None
        return {"simple_explanation": row[0], "food_sources": row[1]}
    except Exception as e:
        logger.warning(f"Precomputed-Supplement-Info (single) fehlgeschlagen (non-fatal): {e}")
        return None


def get_supplement_count() -> int:
    """Gibt die Anzahl gespeicherter Supplements zurück (für Health-Check)."""
    try:
        conn = _get_conn()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM supplements")
        count = cur.fetchone()[0]
        cur.close()
        conn.close()
        return count
    except Exception:
        return -1


def get_study_count() -> int:
    """Gibt die Anzahl gespeicherter Studien zurück (für Health-Check)."""
    try:
        conn = _get_conn()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM studies")
        count = cur.fetchone()[0]
        cur.close()
        conn.close()
        return count
    except Exception:
        return -1
