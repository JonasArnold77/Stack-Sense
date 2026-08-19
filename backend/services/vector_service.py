"""
VectorService — RAG-Schicht zwischen dem Nutzeranfrage und Claude.
Sucht in der pgvector-DB nach relevanten PubMed-Studien und gibt
diese als Kontext-String für den Claude-Prompt zurück.
"""
import html
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


_SOURCE_LABELS = {
    "pubmed": "PubMed",
    "europepmc": "Europe PMC",
    "efsa": "EFSA EU Health Claim",
    "nih_ods": "NIH ODS Factsheet",
    "openfda_caers": "openFDA CAERS (unvalidiert)",
    "nih_dsld": "NIH DSLD Marktprodukt",
    "manual": "Kuratiert",
}

_EVIDENCE_RANK = {"green": 3, "yellow": 2, "red": 1}

_HTML_TAG_RE = re.compile(r"<[^>]+>")


def _strip_html(text: str) -> str:
    """Europe-PMC-Titel/Abstracts enthalten teils rohes oder HTML-entity-
    escapetes Markup (<i>, &lt;i&gt;, <h4> etc.) — das darf nicht ungefiltert
    im RAG-only-UI landen, das keine LLM-Nachbearbeitung mehr durchläuft."""
    if not text:
        return text
    return _HTML_TAG_RE.sub("", html.unescape(text))


def search_structured(query: str, limit: int = 6, snippets_per_supplement: int = 3) -> list[dict]:
    """
    RAG-only Modus: liefert strukturierte, nach Supplement gruppierte Treffer
    direkt aus der Vektor-DB — ohne LLM-Aufruf dazwischen. Für die "Nur
    Datenbankbezug"-Ansicht in der App (im Gegensatz zu search_studies(),
    das einen fertig formatierten Prompt-Kontext-String für Claude baut).

    Returns:
        Liste von Dicts {slug, name, evidence_level, snippets: [...]},
        absteigend nach bester Similarity sortiert. Leere Liste bei Fehlern
        oder wenn DB/Embedding-Modell nicht verfügbar sind.
    """
    try:
        if not _PSYCOPG2_AVAILABLE or not _FASTEMBED_AVAILABLE:
            return []
        model = _get_model()
        if model is None:
            return []
        embedding = list(model.embed([query]))[0].tolist()
        embedding_str = str(embedding)

        conn = _get_conn()
        cur = conn.cursor()

        raw_rows = []

        # Genug Rohzeilen holen, um nach dem Gruppieren pro Slug noch `limit`
        # unterschiedliche Supplements mit mehreren Snippets übrig zu haben.
        cur.execute(
            """
            SELECT supplement_slug, COALESCE(source, 'pubmed'), title, abstract, year,
                   evidence_level, 1 - (embedding <=> %s::vector) AS similarity
            FROM studies
            WHERE abstract IS NOT NULL
            ORDER BY embedding <=> %s::vector
            LIMIT %s
            """,
            (embedding_str, embedding_str, limit * 8),
        )
        for slug, source, title, abstract, year, evidence_level, similarity in cur.fetchall():
            raw_rows.append({
                "slug": slug, "source": source, "title": _strip_html(title),
                "content": _strip_html((abstract or "")[:400]), "year": year,
                "similarity": float(similarity), "evidence_level": evidence_level,
            })

        cur.execute(
            """
            SELECT supplement_slug, COALESCE(source, 'manual'), content,
                   1 - (embedding <=> %s::vector) AS similarity
            FROM supplement_facts
            WHERE content IS NOT NULL
            ORDER BY embedding <=> %s::vector
            LIMIT %s
            """,
            (embedding_str, embedding_str, limit * 6),
        )
        for slug, source, content, similarity in cur.fetchall():
            has_title = "\n\n" in content
            title = content.split("\n\n")[0][:150] if has_title else None
            body = content.split("\n\n", 1)[1] if has_title else content
            raw_rows.append({
                "slug": slug, "source": source, "title": title,
                "content": body[:400], "year": None,
                "similarity": float(similarity), "evidence_level": None,
            })

        if not raw_rows:
            cur.close()
            conn.close()
            return []

        by_slug: dict[str, list[dict]] = {}
        for row in raw_rows:
            by_slug.setdefault(row["slug"], []).append(row)

        slugs = list(by_slug.keys())
        placeholders = ", ".join(["%s"] * len(slugs))
        cur.execute(f"SELECT slug, name FROM supplements WHERE slug IN ({placeholders})", slugs)
        names = dict(cur.fetchall())

        cur.close()
        conn.close()

        results = []
        for slug, rows in by_slug.items():
            rows.sort(key=lambda r: r["similarity"], reverse=True)

            best_evidence = None
            best_rank = 0
            for r in rows:
                rank = _EVIDENCE_RANK.get(r["evidence_level"], 0)
                if rank > best_rank:
                    best_rank = rank
                    best_evidence = r["evidence_level"]

            snippets = [
                {
                    "source": r["source"],
                    "source_label": _SOURCE_LABELS.get(r["source"], r["source"]),
                    "title": r["title"],
                    "content": r["content"],
                    "year": r["year"],
                    "similarity": round(r["similarity"], 3),
                }
                for r in rows[:snippets_per_supplement]
            ]

            results.append({
                "slug": slug,
                "name": names.get(slug, slug),
                "evidence_level": best_evidence,
                "best_similarity": rows[0]["similarity"],
                "snippets": snippets,
            })

        results.sort(key=lambda r: r["best_similarity"], reverse=True)
        return results[:limit]

    except Exception as e:
        logger.warning(f"Strukturierte Vector-Suche fehlgeschlagen (non-fatal): {e}")
        return []


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
