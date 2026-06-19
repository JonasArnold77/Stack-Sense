"""
StackSense Vektordatenbank — Population Script
Einmalig lokal ausführen. Befüllt die RDS-DB mit 200+ Supplements + PubMed-Studien.

Voraussetzungen:
    pip install fastembed psycopg2-binary httpx

Ausführen (aus dem backend/ Ordner):
    python populate_db.py
"""
import asyncio
import logging
import time
import psycopg2
from fastembed import TextEmbedding
from services.pubmed_service import PubMedService

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# ── Datenbankverbindung ──────────────────────────────────────────────────────
DB_CONFIG = {
    "host": "stacksense-db.chym26e8iw2p.eu-central-1.rds.amazonaws.com",
    "user": "stacksense",
    "password": "Jo790097",
    "dbname": "postgres",
    "port": 5432,
    "sslmode": "require",
}

# ── 200+ Supplements ─────────────────────────────────────────────────────────
SUPPLEMENTS = [
    # Vitamine
    {"name": "Vitamin D3", "slug": "vitamin-d3", "category": "Vitamine"},
    {"name": "Vitamin C", "slug": "vitamin-c", "category": "Vitamine"},
    {"name": "Vitamin B12", "slug": "vitamin-b12", "category": "Vitamine"},
    {"name": "Vitamin B6", "slug": "vitamin-b6", "category": "Vitamine"},
    {"name": "Vitamin B1 Thiamin", "slug": "vitamin-b1", "category": "Vitamine"},
    {"name": "Vitamin B2 Riboflavin", "slug": "vitamin-b2", "category": "Vitamine"},
    {"name": "Vitamin B3 Niacin", "slug": "vitamin-b3", "category": "Vitamine"},
    {"name": "Vitamin B5 Pantothensäure", "slug": "vitamin-b5", "category": "Vitamine"},
    {"name": "Biotin Vitamin B7", "slug": "biotin", "category": "Vitamine"},
    {"name": "Folsäure Vitamin B9", "slug": "folsaeure", "category": "Vitamine"},
    {"name": "Vitamin A Retinol", "slug": "vitamin-a", "category": "Vitamine"},
    {"name": "Vitamin E Tocopherol", "slug": "vitamin-e", "category": "Vitamine"},
    {"name": "Vitamin K2 Menaquinon", "slug": "vitamin-k2", "category": "Vitamine"},
    {"name": "Vitamin K1 Phylloquinon", "slug": "vitamin-k1", "category": "Vitamine"},
    # Mineralstoffe
    {"name": "Magnesium", "slug": "magnesium", "category": "Mineralstoffe"},
    {"name": "Magnesium Bisglycinat", "slug": "magnesium-bisglycinat", "category": "Mineralstoffe"},
    {"name": "Zink", "slug": "zink", "category": "Mineralstoffe"},
    {"name": "Eisen", "slug": "eisen", "category": "Mineralstoffe"},
    {"name": "Calcium", "slug": "calcium", "category": "Mineralstoffe"},
    {"name": "Selen", "slug": "selen", "category": "Mineralstoffe"},
    {"name": "Jod", "slug": "jod", "category": "Mineralstoffe"},
    {"name": "Kupfer", "slug": "kupfer", "category": "Mineralstoffe"},
    {"name": "Mangan", "slug": "mangan", "category": "Mineralstoffe"},
    {"name": "Chrom", "slug": "chrom", "category": "Mineralstoffe"},
    {"name": "Molybdän", "slug": "molybdaen", "category": "Mineralstoffe"},
    {"name": "Bor", "slug": "bor", "category": "Mineralstoffe"},
    {"name": "Silizium", "slug": "silizium", "category": "Mineralstoffe"},
    # Fettsäuren
    {"name": "Omega-3 EPA DHA", "slug": "omega-3", "category": "Fettsäuren"},
    {"name": "Fischöl", "slug": "fischoel", "category": "Fettsäuren"},
    {"name": "Krillöl", "slug": "krilloel", "category": "Fettsäuren"},
    {"name": "Algenöl DHA vegan", "slug": "algenoel-dha", "category": "Fettsäuren"},
    {"name": "CLA Konjugierte Linolsäure", "slug": "cla", "category": "Fettsäuren"},
    {"name": "GLA Gamma-Linolensäure", "slug": "gla", "category": "Fettsäuren"},
    # Adaptogene
    {"name": "Ashwagandha Withania somnifera", "slug": "ashwagandha", "category": "Adaptogene"},
    {"name": "Rhodiola Rosea", "slug": "rhodiola-rosea", "category": "Adaptogene"},
    {"name": "Ginseng Panax", "slug": "ginseng", "category": "Adaptogene"},
    {"name": "Maca Lepidium meyenii", "slug": "maca", "category": "Adaptogene"},
    {"name": "Eleuthero Sibirischer Ginseng", "slug": "eleuthero", "category": "Adaptogene"},
    {"name": "Schisandra Chinensis", "slug": "schisandra", "category": "Adaptogene"},
    {"name": "Tulsi Heiliges Basilikum", "slug": "tulsi", "category": "Adaptogene"},
    {"name": "Astragalus", "slug": "astragalus", "category": "Adaptogene"},
    # Aminosäuren
    {"name": "L-Glutamin", "slug": "l-glutamin", "category": "Aminosäuren"},
    {"name": "L-Arginin", "slug": "l-arginin", "category": "Aminosäuren"},
    {"name": "L-Citrullin", "slug": "l-citrullin", "category": "Aminosäuren"},
    {"name": "L-Carnitin", "slug": "l-carnitin", "category": "Aminosäuren"},
    {"name": "L-Theanin", "slug": "l-theanin", "category": "Aminosäuren"},
    {"name": "L-Tryptophan", "slug": "l-tryptophan", "category": "Aminosäuren"},
    {"name": "BCAA verzweigtkettige Aminosäuren", "slug": "bcaa", "category": "Aminosäuren"},
    {"name": "Kreatin Monohydrat", "slug": "kreatin", "category": "Aminosäuren"},
    {"name": "Beta-Alanin", "slug": "beta-alanin", "category": "Aminosäuren"},
    {"name": "Taurin", "slug": "taurin", "category": "Aminosäuren"},
    {"name": "5-HTP 5-Hydroxytryptophan", "slug": "5-htp", "category": "Aminosäuren"},
    {"name": "Glycin", "slug": "glycin", "category": "Aminosäuren"},
    {"name": "NAC N-Acetylcystein", "slug": "nac", "category": "Aminosäuren"},
    {"name": "Acetyl-L-Carnitin ALCAR", "slug": "alcar", "category": "Aminosäuren"},
    {"name": "Phenylalanin", "slug": "phenylalanin", "category": "Aminosäuren"},
    {"name": "Tyrosin", "slug": "tyrosin", "category": "Aminosäuren"},
    {"name": "Prolin", "slug": "prolin", "category": "Aminosäuren"},
    {"name": "HMB Beta-Hydroxy-Beta-Methylbutyrat", "slug": "hmb", "category": "Aminosäuren"},
    # Proteine
    {"name": "Whey Protein", "slug": "whey-protein", "category": "Protein"},
    {"name": "Casein Protein", "slug": "casein-protein", "category": "Protein"},
    {"name": "Pflanzenprotein Erbse Reis", "slug": "pflanzenprotein", "category": "Protein"},
    {"name": "Kollagen Hydrolysat", "slug": "kollagen", "category": "Protein"},
    {"name": "Kollagen Typ II Gelenke", "slug": "kollagen-typ-2", "category": "Protein"},
    # Probiotika / Darm
    {"name": "Probiotika allgemein", "slug": "probiotika", "category": "Darmgesundheit"},
    {"name": "Präbiotika", "slug": "praebiotika", "category": "Darmgesundheit"},
    {"name": "Lactobacillus acidophilus", "slug": "lactobacillus", "category": "Darmgesundheit"},
    {"name": "Bifidobacterium", "slug": "bifidobacterium", "category": "Darmgesundheit"},
    {"name": "Saccharomyces boulardii", "slug": "saccharomyces-boulardii", "category": "Darmgesundheit"},
    {"name": "Flohsamenschalen Psyllium", "slug": "psyllium", "category": "Darmgesundheit"},
    {"name": "Inulin", "slug": "inulin", "category": "Darmgesundheit"},
    {"name": "Apfelpektin", "slug": "apfelpektin", "category": "Darmgesundheit"},
    {"name": "Glutamin Darmgesundheit", "slug": "glutamin-darm", "category": "Darmgesundheit"},
    # Heilpilze
    {"name": "Reishi Ganoderma lucidum", "slug": "reishi", "category": "Heilpilze"},
    {"name": "Lions Mane Hericium erinaceus", "slug": "lions-mane", "category": "Heilpilze"},
    {"name": "Chaga Inonotus obliquus", "slug": "chaga", "category": "Heilpilze"},
    {"name": "Cordyceps", "slug": "cordyceps", "category": "Heilpilze"},
    {"name": "Shiitake", "slug": "shiitake", "category": "Heilpilze"},
    {"name": "Turkey Tail Trametes versicolor", "slug": "turkey-tail", "category": "Heilpilze"},
    {"name": "Maitake", "slug": "maitake", "category": "Heilpilze"},
    # Pflanzenextrakte
    {"name": "Curcumin Kurkuma", "slug": "curcumin", "category": "Pflanzenextrakte"},
    {"name": "Grüntee-Extrakt EGCG", "slug": "gruentee-extrakt", "category": "Pflanzenextrakte"},
    {"name": "Traubenkernextrakt OPC", "slug": "opc", "category": "Pflanzenextrakte"},
    {"name": "Resveratrol", "slug": "resveratrol", "category": "Pflanzenextrakte"},
    {"name": "Quercetin", "slug": "quercetin", "category": "Pflanzenextrakte"},
    {"name": "Berberin", "slug": "berberin", "category": "Pflanzenextrakte"},
    {"name": "Bockshornklee Trigonella", "slug": "bockshornklee", "category": "Pflanzenextrakte"},
    {"name": "Mariendistel Silymarin", "slug": "mariendistel", "category": "Pflanzenextrakte"},
    {"name": "Baldrian Valeriana", "slug": "baldrian", "category": "Pflanzenextrakte"},
    {"name": "Passionsblume Passiflora", "slug": "passionsblume", "category": "Pflanzenextrakte"},
    {"name": "Hopfen Humulus lupulus", "slug": "hopfen", "category": "Pflanzenextrakte"},
    {"name": "Melisse Melissa officinalis", "slug": "melisse", "category": "Pflanzenextrakte"},
    {"name": "Johanniskraut Hypericum", "slug": "johanniskraut", "category": "Pflanzenextrakte"},
    {"name": "Ginkgo Biloba", "slug": "ginkgo", "category": "Pflanzenextrakte"},
    {"name": "Bacopa Monnieri", "slug": "bacopa", "category": "Pflanzenextrakte"},
    {"name": "Echinacea", "slug": "echinacea", "category": "Pflanzenextrakte"},
    {"name": "Schwarzkümmelöl Nigella sativa", "slug": "schwarzkuemeloel", "category": "Pflanzenextrakte"},
    {"name": "Spirulina", "slug": "spirulina", "category": "Pflanzenextrakte"},
    {"name": "Chlorella", "slug": "chlorella", "category": "Pflanzenextrakte"},
    {"name": "Moringa", "slug": "moringa", "category": "Pflanzenextrakte"},
    {"name": "Brennnessel Urtica", "slug": "brennnessel", "category": "Pflanzenextrakte"},
    {"name": "Sägepalme Saw Palmetto", "slug": "saw-palmetto", "category": "Pflanzenextrakte"},
    {"name": "Tribulus Terrestris", "slug": "tribulus", "category": "Pflanzenextrakte"},
    {"name": "Mönchspfeffer Vitex", "slug": "moenchspfeffer", "category": "Pflanzenextrakte"},
    {"name": "Ingwer Zingiber", "slug": "ingwer", "category": "Pflanzenextrakte"},
    {"name": "Knoblauch Allicin", "slug": "knoblauch", "category": "Pflanzenextrakte"},
    {"name": "Artischockenextrakt", "slug": "artischocke", "category": "Pflanzenextrakte"},
    {"name": "Boswellia Weihrauch", "slug": "boswellia", "category": "Pflanzenextrakte"},
    {"name": "Teufelskralle Harpagophytum", "slug": "teufelskralle", "category": "Pflanzenextrakte"},
    {"name": "Holunderbeere Sambucus", "slug": "holunderbeere", "category": "Pflanzenextrakte"},
    {"name": "Rosmarin Rosmarinus", "slug": "rosmarin", "category": "Pflanzenextrakte"},
    {"name": "Thymian Thymus", "slug": "thymian", "category": "Pflanzenextrakte"},
    {"name": "Löwenzahn Taraxacum", "slug": "loewenzahn", "category": "Pflanzenextrakte"},
    {"name": "Bärlauch", "slug": "baerlauch", "category": "Pflanzenextrakte"},
    # Nootropics
    {"name": "Alpha-GPC Cholin", "slug": "alpha-gpc", "category": "Nootropics"},
    {"name": "CDP-Cholin Citicolin", "slug": "cdp-cholin", "category": "Nootropics"},
    {"name": "Phosphatidylserin", "slug": "phosphatidylserin", "category": "Nootropics"},
    {"name": "PQQ Pyrrolochinolinchinon", "slug": "pqq", "category": "Nootropics"},
    {"name": "Vinpocetin", "slug": "vinpocetin", "category": "Nootropics"},
    {"name": "Aniracetam", "slug": "aniracetam", "category": "Nootropics"},
    {"name": "Uridinmonophosphat", "slug": "uridin", "category": "Nootropics"},
    # Schlaf
    {"name": "Melatonin", "slug": "melatonin", "category": "Schlaf"},
    {"name": "GABA", "slug": "gaba", "category": "Schlaf"},
    {"name": "Magnesium Schlaf", "slug": "magnesium-schlaf", "category": "Schlaf"},
    {"name": "L-Theanin Schlaf", "slug": "theanin-schlaf", "category": "Schlaf"},
    # Antioxidantien
    {"name": "Coenzym Q10 Ubiquinol", "slug": "coq10", "category": "Antioxidantien"},
    {"name": "Alpha-Liponsäure ALA", "slug": "alpha-liponsaeure", "category": "Antioxidantien"},
    {"name": "Astaxanthin", "slug": "astaxanthin", "category": "Antioxidantien"},
    {"name": "Lycopin", "slug": "lycopin", "category": "Antioxidantien"},
    {"name": "Lutein Zeaxanthin Augen", "slug": "lutein-zeaxanthin", "category": "Antioxidantien"},
    {"name": "Glutathion", "slug": "glutathion", "category": "Antioxidantien"},
    # Herzgesundheit
    {"name": "Roter Reis Monacolin K", "slug": "roter-reis", "category": "Herzgesundheit"},
    {"name": "Policosanol", "slug": "policosanol", "category": "Herzgesundheit"},
    {"name": "Coenzym Q10 Herz", "slug": "coq10-herz", "category": "Herzgesundheit"},
    {"name": "L-Arginin Herzgesundheit", "slug": "arginin-herz", "category": "Herzgesundheit"},
    # Immunsystem
    {"name": "Vitamin C Immunsystem", "slug": "vitamin-c-immun", "category": "Immunsystem"},
    {"name": "Zink Immunsystem", "slug": "zink-immun", "category": "Immunsystem"},
    {"name": "Beta-Glucan", "slug": "beta-glucan", "category": "Immunsystem"},
    {"name": "Colostrum", "slug": "colostrum", "category": "Immunsystem"},
    {"name": "Propolis", "slug": "propolis", "category": "Immunsystem"},
    {"name": "Lactoferrin", "slug": "lactoferrin", "category": "Immunsystem"},
    # Gelenke / Knochen
    {"name": "Glucosamin Sulfat", "slug": "glucosamin", "category": "Gelenke"},
    {"name": "Chondroitin Sulfat", "slug": "chondroitin", "category": "Gelenke"},
    {"name": "MSM Methylsulfonylmethan", "slug": "msm", "category": "Gelenke"},
    {"name": "Hyaluronsäure", "slug": "hyaluronsaeure", "category": "Gelenke"},
    {"name": "Calcium Knochen", "slug": "calcium-knochen", "category": "Gelenke"},
    # Blutzucker / Stoffwechsel
    {"name": "Berberin Blutzucker", "slug": "berberin-blutzucker", "category": "Stoffwechsel"},
    {"name": "Chrom Picolinat", "slug": "chrom-picolinat", "category": "Stoffwechsel"},
    {"name": "Inositol Myo-Inositol", "slug": "inositol", "category": "Stoffwechsel"},
    {"name": "Bittermelone", "slug": "bittermelone", "category": "Stoffwechsel"},
    {"name": "Alpha-Liponsäure Insulin", "slug": "ala-insulin", "category": "Stoffwechsel"},
    # Schilddrüse
    {"name": "Selen Schilddrüse", "slug": "selen-schilddruese", "category": "Schilddrüse"},
    {"name": "Jod Schilddrüse", "slug": "jod-schilddruese", "category": "Schilddrüse"},
    {"name": "Ashwagandha Schilddrüse", "slug": "ashwagandha-schilddruese", "category": "Schilddrüse"},
    {"name": "L-Tyrosin Schilddrüse", "slug": "tyrosin-schilddruese", "category": "Schilddrüse"},
    # Haut / Haar / Nägel
    {"name": "Biotin Haare Nägel", "slug": "biotin-haare", "category": "Haut & Haar"},
    {"name": "Kollagen Haut", "slug": "kollagen-haut", "category": "Haut & Haar"},
    {"name": "Hyaluronsäure Haut", "slug": "hyaluron-haut", "category": "Haut & Haar"},
    {"name": "Silizium Haare", "slug": "silizium-haare", "category": "Haut & Haar"},
    {"name": "Zink Haut Akne", "slug": "zink-haut", "category": "Haut & Haar"},
    # Frauen
    {"name": "Folsäure Schwangerschaft", "slug": "folsaeure-schwangerschaft", "category": "Frauen"},
    {"name": "Eisen Frauen", "slug": "eisen-frauen", "category": "Frauen"},
    {"name": "Mönchspfeffer PMS", "slug": "moenchspfeffer-pms", "category": "Frauen"},
    {"name": "Magnesium PMS Krämpfe", "slug": "magnesium-pms", "category": "Frauen"},
    {"name": "Omega-3 Schwangerschaft", "slug": "omega3-schwangerschaft", "category": "Frauen"},
    # Männer
    {"name": "Zink Testosteron", "slug": "zink-testosteron", "category": "Männer"},
    {"name": "Vitamin D Testosteron", "slug": "vitamind-testosteron", "category": "Männer"},
    {"name": "Ashwagandha Testosteron", "slug": "ashwagandha-testosteron", "category": "Männer"},
    {"name": "Tribulus Testosteron", "slug": "tribulus-testosteron", "category": "Männer"},
    # Longevity
    {"name": "NMN Nicotinamidmononukleotid", "slug": "nmn", "category": "Longevity"},
    {"name": "NR Nicotinamidribosid", "slug": "nr", "category": "Longevity"},
    {"name": "Spermidin", "slug": "spermidin", "category": "Longevity"},
    {"name": "Fisetin Senolytikum", "slug": "fisetin", "category": "Longevity"},
    {"name": "Apigenin", "slug": "apigenin", "category": "Longevity"},
    {"name": "Resveratrol Longevity", "slug": "resveratrol-longevity", "category": "Longevity"},
    # Sport / Performance
    {"name": "Koffein Sport", "slug": "koffein", "category": "Sport"},
    {"name": "Beta-Alanin Ausdauer", "slug": "beta-alanin-sport", "category": "Sport"},
    {"name": "Kreatin Performance", "slug": "kreatin-sport", "category": "Sport"},
    {"name": "Citrullin Malat Pump", "slug": "citrullin-sport", "category": "Sport"},
    {"name": "Elektrolyte Natrium Kalium", "slug": "elektrolyte", "category": "Sport"},
    {"name": "Maltodextrin Energie", "slug": "maltodextrin", "category": "Sport"},
]


# ── Embedding-Modell ─────────────────────────────────────────────────────────
def load_model():
    logger.info("Lade Embedding-Modell (BAAI/bge-small-en-v1.5, ONNX, 384 dim)...")
    # Selbes Modell wie vector_service.py → kompatible Vektoren
    return TextEmbedding("BAAI/bge-small-en-v1.5")


def embed(model: TextEmbedding, text: str) -> list[float]:
    return list(model.embed([text]))[0].tolist()


# ── Datenbank-Hilfsfunktionen ────────────────────────────────────────────────
def supplement_exists(cur, slug: str) -> bool:
    cur.execute("SELECT 1 FROM supplements WHERE slug = %s", (slug,))
    return cur.fetchone() is not None


def study_exists(cur, pmid: str) -> bool:
    cur.execute("SELECT 1 FROM studies WHERE pmid = %s", (pmid,))
    return cur.fetchone() is not None


def insert_supplement(cur, s: dict):
    cur.execute(
        "INSERT INTO supplements (name, slug, category) VALUES (%s, %s, %s) ON CONFLICT (slug) DO NOTHING",
        (s["name"], s["slug"], s["category"]),
    )


def insert_study(cur, slug: str, study: dict, evidence: str, embedding: list[float]):
    if study_exists(cur, study["pmid"]):
        return False
    cur.execute(
        """INSERT INTO studies (supplement_slug, pmid, title, abstract, year, evidence_level, embedding)
           VALUES (%s, %s, %s, %s, %s, %s, %s)""",
        (
            slug,
            study["pmid"],
            (study["title"] or "")[:500],
            (study["abstract"] or "")[:1000],
            int(study["year"]) if str(study["year"]).isdigit() else None,
            evidence,
            str(embedding),
        ),
    )
    return True


def classify_evidence(abstract: str, title: str) -> str:
    """Einfache regelbasierte Evidenzklassifikation."""
    text = ((title or "") + " " + (abstract or "")).lower()
    if any(w in text for w in ["randomized controlled trial", "rct", "meta-analysis", "systematic review", "placebo-controlled"]):
        return "green"
    elif any(w in text for w in ["pilot study", "observational", "cohort", "preliminary", "suggests", "may"]):
        return "yellow"
    else:
        return "red"


# ── Hauptprozess ─────────────────────────────────────────────────────────────
async def populate():
    model = load_model()
    pubmed = PubMedService()
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    total = len(SUPPLEMENTS)
    for i, supp in enumerate(SUPPLEMENTS, 1):
        logger.info(f"[{i}/{total}] {supp['name']} ({supp['slug']})")

        # Supplement einfügen
        insert_supplement(cur, supp)
        conn.commit()

        if supplement_exists(cur, supp["slug"]):
            # Studien holen — pro Supplement 2 Queries
            queries = [
                f"{supp['name']} supplementation randomized controlled trial",
                f"{supp['name']} health benefits meta-analysis",
            ]
            studies_inserted = 0
            for query in queries:
                studies = await pubmed.search_abstracts(query, max_results=5, min_year=2015)
                for study in studies:
                    if not study.get("title") and not study.get("abstract"):
                        continue
                    text = f"{study['title']} {study['abstract']}"
                    embedding = embed(model, text)
                    evidence = classify_evidence(study["abstract"], study["title"])
                    inserted = insert_study(cur, supp["slug"], study, evidence, embedding)
                    if inserted:
                        studies_inserted += 1
                conn.commit()
                time.sleep(0.4)  # PubMed Rate Limit: max 3 req/s

            logger.info(f"  → {studies_inserted} neue Studien gespeichert")

        time.sleep(0.2)

    cur.close()
    conn.close()
    await pubmed.close()
    logger.info(f"✅ Fertig! {total} Supplements verarbeitet.")


if __name__ == "__main__":
    asyncio.run(populate())
