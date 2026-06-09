"""
Supplement-DB Generator
=======================
Generiert automatisch verifizierte Supplement-Einträge für supplement_knowledge.json.

Ablauf pro Supplement:
1. PubMed abfragen → aktuelle Studien + Abstracts laden
2. Abstracts + Supplement-Name an Claude übergeben
3. Claude generiert strukturierten DB-Eintrag auf Basis der Studien
4. Eintrag wird in supplement_knowledge.json geschrieben

Verwendung:
    cd backend
    python scripts/generate_supplement_db.py                    # Alle fehlenden generieren
    python scripts/generate_supplement_db.py --name "Rhodiola"  # Einzelnes Supplement
    python scripts/generate_supplement_db.py --list             # Zeigt Status aller Supplements
"""

import asyncio
import json
import re
import sys
import time
import argparse
import httpx
from pathlib import Path
from xml.etree import ElementTree

# Pfade
BACKEND_ROOT = Path(__file__).parent.parent
DB_PATH = BACKEND_ROOT / "data" / "supplement_knowledge.json"
ENV_PATH = BACKEND_ROOT / ".env"

# .env manuell laden (kein dotenv-Import nötig im Script)
def _load_env():
    if ENV_PATH.exists():
        for line in ENV_PATH.read_text().splitlines():
            if "=" in line and not line.startswith("#"):
                key, _, val = line.partition("=")
                import os
                os.environ.setdefault(key.strip(), val.strip())

_load_env()

import os
import anthropic

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
NCBI_BASE = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

# -----------------------------------------------------------------------
# Vollständige Liste aller Supplements die in die DB sollen
# -----------------------------------------------------------------------
ALL_SUPPLEMENTS = [
    # Bereits in DB (werden übersprungen wenn schon vorhanden)
    "Vitamin D3", "Magnesium", "Omega-3", "Zink", "Vitamin C", "Vitamin B12",
    "Eisen", "Selen", "Ashwagandha", "Melatonin", "Kreatin", "CoQ10",
    "Probiotika", "Curcumin", "NAC", "Vitamin K2", "L-Theanin", "B-Vitamine Komplex",

    # Neu zu generieren
    "Vitamin A", "Vitamin E", "Vitamin K1", "Folsäure", "Vitamin B6",
    "Biotin", "Calcium", "Kalium", "Jod", "Chrom", "Mangan",
    "L-Glutamin", "L-Arginin", "L-Carnitin", "Taurin", "BCAA", "Glycin",
    "Rhodiola Rosea", "Maca", "Ginseng", "Lion's Mane", "Reishi",
    "Beta-Alanin", "Citrullin Malat", "HMB", "Alpha-Liponsäure",
    "Resveratrol", "Spirulina", "Chlorella", "Hyaluronsäure", "Kollagen",
    "Glucosamin", "MSM", "Mariendistel", "Weißdorn", "Ingwer Extrakt",
    "Grüntee Extrakt", "Traubenkernextrakt", "Berberin", "Quercetin",
    "Lutein", "Zeaxanthin", "Astaxanthin", "Lycopin",
    "5-HTP", "GABA", "Phosphatidylserin", "Alpha-GPC",
    "Zink Carnosin", "Magnesium L-Threonat",
]


# -----------------------------------------------------------------------
# PubMed-Abruf
# -----------------------------------------------------------------------
async def fetch_pubmed_abstracts(supplement_name: str, max_results: int = 6) -> list[dict]:
    query = f"{supplement_name} supplementation humans randomized controlled trial"
    params = {
        "tool": "StackSense-DBGenerator",
        "email": "contact@stacksense.app",
        "db": "pubmed",
        "term": f"{query} AND 2015:3000[pdat]",
        "retmax": max_results,
        "retmode": "json",
        "sort": "relevance",
    }
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(f"{NCBI_BASE}/esearch.fcgi", params=params)
        resp.raise_for_status()
        pmids = resp.json().get("esearchresult", {}).get("idlist", [])

        if not pmids:
            return []

        fetch_params = {
            **{k: v for k, v in params.items() if k in ("tool", "email")},
            "db": "pubmed",
            "id": ",".join(pmids),
            "rettype": "abstract",
            "retmode": "xml",
        }
        fetch_resp = await client.get(f"{NCBI_BASE}/efetch.fcgi", params=fetch_params)
        fetch_resp.raise_for_status()

    results = []
    try:
        root = ElementTree.fromstring(fetch_resp.text)
        for article in root.findall(".//PubmedArticle"):
            pmid_el = article.find(".//PMID")
            title_el = article.find(".//ArticleTitle")
            abstract_el = article.find(".//AbstractText")
            year_el = article.find(".//PubDate/Year")

            abstract = abstract_el.text if abstract_el is not None else ""
            if abstract and len(abstract) > 800:
                abstract = abstract[:800] + "…"

            results.append({
                "pmid": pmid_el.text if pmid_el is not None else "",
                "title": title_el.text if title_el is not None else "",
                "abstract": abstract,
                "year": year_el.text if year_el is not None else "",
            })
    except ElementTree.ParseError:
        pass

    return results


# -----------------------------------------------------------------------
# Claude-Generierung eines DB-Eintrags
# -----------------------------------------------------------------------
GENERATOR_PROMPT = """Du bist ein medizinischer Datenbank-Redakteur für StackSense.

AUFGABE:
Erstelle einen strukturierten, faktisch korrekten Datenbankeintrag für das angegebene Supplement.
Basiere dich auf den mitgelieferten PubMed-Studien UND deinem medizinischen Fachwissen.

QUALITÄTSANFORDERUNGEN:
- Keine Heilsversprechen — sachliche, evidenzbasierte Sprache
- Wechselwirkungen nur wenn klinisch relevant und bekannt
- Kontraindikationen konservativ — lieber zu vorsichtig als zu wenig
- Optimale Formen basierend auf Bioverfügbarkeitsstudien
- Kategorien nur aus der erlaubten Liste wählen

ERLAUBTE KATEGORIEN:
Schlaf, Energie, Fokus, Stimmung, Stress, Immunsystem, Sport & Erholung,
Herzgesundheit, Schilddrüse, Verdauung, Hormonbalance, Entzündung, Knochen & Gelenke

EVIDENZLEVEL:
- "green": Mehrere RCTs / Meta-Analysen mit klarem Ergebnis
- "yellow": Erste positive Studien, aber Evidenz noch lückenhaft
- "red": Kaum belastbare Humanstudien

ANTWORTE NUR MIT VALIDEM JSON — kein Text davor oder danach:

{
  "id": "kebab-case-id",
  "name": "Anzeigename",
  "substance": "Wirkstoffname / IUPAC oder Trivialname",
  "evidence_summary": "2-3 Sätze sachliche Zusammenfassung der Evidenzlage",
  "evidence_level": "green|yellow|red",
  "sources": ["PMID:XXXXXXXX", "PMID:XXXXXXXX"],
  "drug_interactions": [
    {
      "drug": "Medikamentenname (Wirkstoff oder Handelsname)",
      "effect": "Beschreibung der Wechselwirkung max 120 Zeichen",
      "severity": "gering|moderat|hoch"
    }
  ],
  "contraindications": ["Kontraindikation 1", "Kontraindikation 2"],
  "optimal_forms": ["Form 1 (Begründung)", "Form 2"],
  "intake_notes": "Praktische Einnahmehinweise max 150 Zeichen",
  "categories": ["Kategorie1", "Kategorie2"]
}"""


def _extract_json(raw: str) -> str:
    match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", raw, re.DOTALL)
    if match:
        return match.group(1).strip()
    match = re.search(r"\{.*\}", raw, re.DOTALL)
    if match:
        return match.group(0).strip()
    return raw


async def generate_entry(supplement_name: str, studies: list[dict]) -> dict | None:
    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

    study_text = ""
    if studies:
        lines = [f"PUBMED-STUDIEN FÜR {supplement_name.upper()}:"]
        for s in studies:
            lines.append(f"[PMID:{s['pmid']} | {s['year']}] {s['title']}")
            if s["abstract"]:
                lines.append(f"  {s['abstract']}")
        study_text = "\n".join(lines)

    user_msg = f"Erstelle den Datenbankeintrag für: {supplement_name}\n\n{study_text}"

    try:
        message = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=1500,
            system=GENERATOR_PROMPT,
            messages=[{"role": "user", "content": user_msg}],
        )
        raw = _extract_json(message.content[0].text.strip())
        entry = json.loads(raw)
        return entry
    except Exception as e:
        print(f"  ❌ Claude-Fehler: {e}")
        return None


# -----------------------------------------------------------------------
# Hauptlogik
# -----------------------------------------------------------------------
def load_db() -> dict:
    if DB_PATH.exists():
        with open(DB_PATH, encoding="utf-8") as f:
            return json.load(f)
    return {"version": "1.0", "source": "Auto-generiert via PubMed + Claude", "supplements": {}}


def save_db(db: dict):
    with open(DB_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=False, indent=2)


async def process_supplement(name: str, db: dict, force: bool = False) -> bool:
    """Generiert einen Eintrag für ein Supplement und fügt ihn in die DB ein."""
    # ID aus Name ableiten
    entry_id = name.lower().replace(" ", "-").replace("'", "").replace("ä", "ae").replace("ö", "oe").replace("ü", "ue")

    if entry_id in db["supplements"] and not force:
        print(f"  ⏭️  {name} — bereits in DB, übersprungen")
        return False

    print(f"  🔍 PubMed-Suche für: {name}")
    studies = await fetch_pubmed_abstracts(name, max_results=5)
    print(f"     → {len(studies)} Studien gefunden")

    # Rate-Limit NCBI: max 3 Req/s ohne API-Key
    await asyncio.sleep(0.5)

    print(f"  🤖 Claude generiert Eintrag...")
    entry = await generate_entry(name, studies)

    if entry is None:
        print(f"  ❌ Fehlgeschlagen: {name}")
        return False

    # ID aus dem Entry übernehmen oder aus Name ableiten
    final_id = entry.get("id", entry_id)
    db["supplements"][final_id] = entry
    save_db(db)
    print(f"  ✅ {name} → gespeichert als '{final_id}'")
    return True


async def run_all(force: bool = False):
    """Generiert alle fehlenden Supplements."""
    if not ANTHROPIC_API_KEY:
        print("❌ ANTHROPIC_API_KEY nicht gefunden. Bitte .env prüfen.")
        sys.exit(1)

    db = load_db()
    existing = len(db["supplements"])
    print(f"\n📦 Supplement-DB: {existing} Einträge vorhanden")
    print(f"🎯 Ziel: {len(ALL_SUPPLEMENTS)} Supplements gesamt\n")

    to_generate = [
        name for name in ALL_SUPPLEMENTS
        if name.lower().replace(" ", "-").replace("'", "").replace("ä", "ae").replace("ö", "oe").replace("ü", "ue")
        not in db["supplements"] or force
    ]

    if not to_generate:
        print("✅ Alle Supplements bereits in der DB!")
        return

    print(f"🚀 Generiere {len(to_generate)} neue Einträge...\n")

    success = 0
    for i, name in enumerate(to_generate, 1):
        print(f"[{i}/{len(to_generate)}] {name}")
        ok = await process_supplement(name, db, force=force)
        if ok:
            success += 1
        # Kurze Pause zwischen Supplements (Claude Rate-Limit)
        if i < len(to_generate):
            await asyncio.sleep(1.5)

    print(f"\n✅ Fertig: {success}/{len(to_generate)} neue Einträge generiert")
    print(f"📦 DB enthält jetzt {len(db['supplements'])} Supplements")


async def run_single(name: str, force: bool = False):
    """Generiert einen einzelnen Eintrag."""
    if not ANTHROPIC_API_KEY:
        print("❌ ANTHROPIC_API_KEY nicht gefunden.")
        sys.exit(1)

    db = load_db()
    print(f"\n🚀 Generiere Eintrag für: {name}\n")
    await process_supplement(name, db, force=force)


def show_list():
    """Zeigt Status aller Supplements."""
    db = load_db()
    existing = set(db["supplements"].keys())

    print(f"\n{'Supplement':<35} {'Status'}")
    print("-" * 50)
    for name in ALL_SUPPLEMENTS:
        entry_id = name.lower().replace(" ", "-").replace("'", "").replace("ä", "ae").replace("ö", "oe").replace("ü", "ue")
        status = "✅ vorhanden" if entry_id in existing else "❌ fehlt"
        print(f"{name:<35} {status}")

    print(f"\nGesamt: {len(existing)}/{len(ALL_SUPPLEMENTS)} in DB")


# -----------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="StackSense Supplement-DB Generator")
    parser.add_argument("--name", type=str, help="Einzelnes Supplement generieren")
    parser.add_argument("--list", action="store_true", help="Status aller Supplements anzeigen")
    parser.add_argument("--force", action="store_true", help="Bereits vorhandene Einträge überschreiben")
    args = parser.parse_args()

    if args.list:
        show_list()
    elif args.name:
        asyncio.run(run_single(args.name, force=args.force))
    else:
        asyncio.run(run_all(force=args.force))
