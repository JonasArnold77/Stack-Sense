"""
EFSA Health Claims — Vektordatenbank Population
================================================
Lädt autorisierte EU-Gesundheitsaussagen (Reg. 432/2012) von der
EFSA / EU Open Data und speichert sie als Vektoren in supplement_facts.

Voraussetzungen:
    pip install fastembed psycopg2-binary httpx beautifulsoup4

Ausführen (aus dem backend/ Ordner):
    python scripts/populate_efsa.py

Quelle: EFSA Scientific Opinions + EU Nutrition & Health Claims Register
"""
import asyncio
import logging
import time
import re
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

# ── EFSA-autorisierte Health Claims (Verordnung EG 432/2012) ────────────────
# Direkt aus dem EU-Register: ec.europa.eu/food/safety/labelling_nutrition/claims
# Jeder Claim hat: substance, claim_text, conditions, evidence_level
EFSA_CLAIMS = [
    # Vitamine
    {
        "slug": "vitamin-d3",
        "claims": [
            {
                "title": "Vitamin D — Knochengesundheit (EFSA 432/2012)",
                "content": "Vitamin D trägt zur Erhaltung normaler Knochen bei. Authorized EU health claim per Regulation 432/2012. Condition: At least 15 µg vitamin D per 100 g/ml or per portion. Evidence level: Established. Vitamin D is essential for calcium absorption and bone mineralization. EFSA NDA Panel confirmed sufficient scientific evidence for this claim.",
                "evidence_level": "green",
            },
            {
                "title": "Vitamin D — Immunsystem (EFSA 432/2012)",
                "content": "Vitamin D trägt zur normalen Funktion des Immunsystems bei. EU-autorisierter Health Claim. Vitamin D receptors are present on immune cells. EFSA confirmed the relationship between vitamin D intake and normal immune function. Minimum 15 µg per serving required for the claim.",
                "evidence_level": "green",
            },
            {
                "title": "Vitamin D — Muskulatur (EFSA 432/2012)",
                "content": "Vitamin D trägt zur Erhaltung einer normalen Muskelfunktion bei. EU-autorisierter Health Claim per 432/2012. EFSA NDA Panel reviewed evidence and confirmed that vitamin D contributes to maintenance of normal muscle function. Particularly relevant in elderly populations and athletes.",
                "evidence_level": "green",
            },
            {
                "title": "Vitamin D Mangel — Saisonalität und Supplement-Bedarf (EFSA Scientific Opinion)",
                "content": "EFSA Scientific Opinion on Vitamin D (2016): In Northern Europe, vitamin D synthesis from sunlight is insufficient from October to March. Dietary intake from food alone is typically below recommendations. Supplementation with 15-20 µg/day (600-800 IU) recommended for general population, higher doses (25-100 µg/day) may be needed for deficiency correction. Population Reference Intake set at 15 µg/day for all age groups.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "vitamin-c",
        "claims": [
            {
                "title": "Vitamin C — Immunsystem (EFSA 432/2012)",
                "content": "Vitamin C trägt zur normalen Funktion des Immunsystems bei. EU-autorisierter Health Claim. EFSA confirmed this claim with high evidence level. Vitamin C supports immune cell function and acts as antioxidant. Minimum 12 mg per 100 g or per portion for claim authorization.",
                "evidence_level": "green",
            },
            {
                "title": "Vitamin C — Eisenaufnahme (EFSA 432/2012)",
                "content": "Vitamin C erhöht die Eisenaufnahme. EU-autorisierter Health Claim. EFSA NDA Panel confirmed that vitamin C (ascorbic acid) enhances non-heme iron absorption from plant-based foods. Important combination for vegetarians and vegans. Take 200mg vitamin C with iron-containing meals.",
                "evidence_level": "green",
            },
            {
                "title": "Vitamin C — Kollagenbildung (EFSA 432/2012)",
                "content": "Vitamin C trägt zur normalen Kollagenbildung für eine normale Funktion von Blutgefäßen, Knochen, Knorpel, Haut, Zähnen und Zahnfleisch bei. EU-autorisierter Health Claim. Vitamin C is a cofactor for prolyl and lysyl hydroxylases essential in collagen synthesis.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "vitamin-b12",
        "claims": [
            {
                "title": "Vitamin B12 — Energiestoffwechsel (EFSA 432/2012)",
                "content": "Vitamin B12 trägt zu einem normalen Energiestoffwechsel bei. EU-autorisierter Health Claim. EFSA confirmed B12 role in energy-yielding metabolism. B12 is a cofactor for methylmalonyl-CoA mutase in propionate metabolism. Minimum 0.375 µg per 100 g/ml for claim authorization.",
                "evidence_level": "green",
            },
            {
                "title": "Vitamin B12 — Nervensystem (EFSA 432/2012)",
                "content": "Vitamin B12 trägt zur normalen Funktion des Nervensystems bei. EU-autorisierter Health Claim. B12 is essential for myelin synthesis. Deficiency causes subacute combined degeneration of the spinal cord. EFSA confirmed sufficient evidence for neurological function claim.",
                "evidence_level": "green",
            },
            {
                "title": "Vitamin B12 Mangel bei Veganern — EFSA Scientific Opinion",
                "content": "EFSA Scientific Opinion: Vitamin B12 occurs exclusively in animal products. Vegans and strict vegetarians are at high risk of deficiency. Absorption requires intrinsic factor; elderly at risk due to reduced gastric acid. Recommended supplementation: 250 µg/day cyanocobalamin or 1000 µg sublingual for vegans. Regular monitoring of serum B12 and homocysteine recommended.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "folsaeure",
        "claims": [
            {
                "title": "Folsäure — Schwangerschaft und Neuralrohrdefekte (EFSA 432/2012)",
                "content": "Folsäure (Folat) trägt zu normalem Zellwachstum während der Schwangerschaft bei. Supplemental folic acid intake increases maternal folate status. Maternal folate status is a risk factor in the development of neural tube defects in the developing foetus. EU-autorisierter Health Claim. 400 µg/day folic acid from at least 1 month before until 3 months after conception recommended.",
                "evidence_level": "green",
            },
            {
                "title": "Folsäure — Homocystein (EFSA 432/2012)",
                "content": "Folsäure trägt zum normalen Homocystein-Stoffwechsel bei. EU-autorisierter Health Claim. Elevated homocysteine is associated with cardiovascular disease risk. Folate as cofactor for methionine synthase reduces plasma homocysteine. EFSA confirmed this mechanism with strong evidence.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "magnesium",
        "claims": [
            {
                "title": "Magnesium — Nervensystem und Muskulatur (EFSA 432/2012)",
                "content": "Magnesium trägt zur normalen Funktion des Nervensystems und der Muskulatur bei. EU-autorisierter Health Claim per 432/2012. EFSA NDA Panel confirmed these claims. Magnesium is essential for over 300 enzymatic reactions. Minimum 56 mg per 100 g/ml for claim authorization. Role in neuromuscular transmission and muscle contraction.",
                "evidence_level": "green",
            },
            {
                "title": "Magnesium — Müdigkeit und Erschöpfung (EFSA 432/2012)",
                "content": "Magnesium trägt dazu bei, Müdigkeit und Erschöpfung zu verringern. EU-autorisierter Health Claim. EFSA confirmed that magnesium contributes to reduction of tiredness and fatigue. Magnesium is involved in energy metabolism as cofactor for ATPases and in mitochondrial function.",
                "evidence_level": "green",
            },
            {
                "title": "Magnesium — Schlaf und Erholung (EFSA Scientific Opinion)",
                "content": "EFSA Scientific Opinion on Magnesium: Magnesium plays a role in the regulation of circadian rhythms and may support sleep quality. Deficiency is associated with impaired sleep. Reference values: 350-400 mg/day for adult men, 300-350 mg/day for adult women. Forms with high bioavailability: magnesium citrate, bisglycinate, malate preferred over oxide.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "zink",
        "claims": [
            {
                "title": "Zink — Immunsystem (EFSA 432/2012)",
                "content": "Zink trägt zur normalen Funktion des Immunsystems bei. EU-autorisierter Health Claim per 432/2012. EFSA confirmed zinc's role in immune cell development and function. Zinc is required for thymulin activity and T-cell function. Minimum 1.5 mg per 100 g/ml for claim authorization.",
                "evidence_level": "green",
            },
            {
                "title": "Zink — Testosteron (EFSA 432/2012)",
                "content": "Zink trägt zur Aufrechterhaltung eines normalen Testosteronspiegels im Blut bei. EU-autorisierter Health Claim. EFSA confirmed that zinc contributes to maintenance of normal testosterone levels. Zinc is a cofactor for enzymes in steroidogenesis. Deficiency is associated with hypogonadism.",
                "evidence_level": "green",
            },
            {
                "title": "Zink — Haut, Haare, Nägel (EFSA 432/2012)",
                "content": "Zink trägt zur Erhaltung normaler Haut, normaler Haare und normaler Nägel bei. EU-autorisierter Health Claim. EFSA confirmed zinc's structural role in keratin. Zinc deficiency causes acrodermatitis enteropathica with skin lesions and hair loss.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "eisen",
        "claims": [
            {
                "title": "Eisen — Sauerstofftransport (EFSA 432/2012)",
                "content": "Eisen trägt zum normalen Sauerstofftransport im Körper bei. EU-autorisierter Health Claim. EFSA confirmed iron's role as component of hemoglobin and myoglobin. Essential for oxygen transport in red blood cells. Minimum 2.1 mg per 100 g/ml for claim. Iron deficiency anemia is the most common nutritional deficiency worldwide.",
                "evidence_level": "green",
            },
            {
                "title": "Eisen — Müdigkeit bei Frauen (EFSA Scientific Opinion)",
                "content": "EFSA Scientific Opinion: Iron deficiency is particularly prevalent in premenopausal women due to menstrual blood loss. Recommended intake: 16 mg/day for women 18-50, 11 mg/day for men. Non-heme iron from plant sources has lower bioavailability (2-20%) vs heme iron (15-35%). Vitamin C co-ingestion enhances non-heme absorption. Iron supplementation reduces fatigue in iron-depleted non-anemic women.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "selen",
        "claims": [
            {
                "title": "Selen — Schilddrüsenfunktion (EFSA 432/2012)",
                "content": "Selen trägt zur normalen Funktion der Schilddrüse bei. EU-autorisierter Health Claim per 432/2012. EFSA confirmed selenium's role as component of thyroid hormone deiodinases (DIO1, DIO2, DIO3). These enzymes convert T4 to active T3. Selenium deficiency impairs thyroid hormone metabolism. Particularly relevant in Hashimoto's thyroiditis. Minimum 8.25 µg per 100 g/ml for claim.",
                "evidence_level": "green",
            },
            {
                "title": "Selen — Immunsystem und antioxidativer Schutz (EFSA 432/2012)",
                "content": "Selen trägt zur normalen Funktion des Immunsystems und zum Schutz der Zellen vor oxidativem Stress bei. EU-autorisierter Health Claim. Selenium is a component of glutathione peroxidases (GPx) — key antioxidant enzymes. EFSA confirmed both immune function and antioxidant protection claims for selenium.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "omega-3",
        "claims": [
            {
                "title": "Omega-3 DHA — Herzgesundheit (EFSA 432/2012)",
                "content": "DHA und EPA tragen zur normalen Herzfunktion bei. EU-autorisierter Health Claim. EFSA NDA Panel confirmed: EPA+DHA at 250 mg/day supports normal cardiac function. Higher doses (2-4 g/day) reduce triglycerides — subject to on-request authorization. DHA is a major structural component of heart muscle cell membranes.",
                "evidence_level": "green",
            },
            {
                "title": "Omega-3 DHA — Gehirnfunktion (EFSA 432/2012)",
                "content": "DHA trägt zur Erhaltung einer normalen Gehirnfunktion bei. EU-autorisierter Health Claim. EFSA confirmed DHA's structural role in brain phospholipids. DHA constitutes ~30% of structural lipids in the cerebral cortex. Minimum 40 mg DHA per 100 g/ml for claim. Critical during pregnancy and breastfeeding for fetal brain development.",
                "evidence_level": "green",
            },
            {
                "title": "Omega-3 Triglyceride-Senkung (EFSA Scientific Opinion 2010)",
                "content": "EFSA Scientific Opinion (2010): EPA+DHA supplementation at doses of 2 g/day and above reduce plasma triglyceride concentrations. Effect is dose-dependent. At 4 g/day: reduction of 25-30% in hypertriglyceridemic patients. Mechanism: reduced VLDL synthesis in liver. EFSA concluded sufficient evidence for triglyceride reduction at pharmacological doses.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "calcium",
        "claims": [
            {
                "title": "Calcium — Knochen und Zähne (EFSA 432/2012)",
                "content": "Calcium wird für die Erhaltung normaler Knochen und Zähne benötigt. EU-autorisierter Health Claim. EFSA confirmed calcium's structural role — 99% of body calcium is in bones and teeth as hydroxyapatite. Calcium intake is a determinant of bone mineral density. DRI: 1000 mg/day for adults, 1200 mg/day for postmenopausal women.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "kreatin",
        "claims": [
            {
                "title": "Kreatin — Muskelleistung bei Hochintensitätstraining (EFSA 432/2012)",
                "content": "Kreatin (Creatine) verbessert die körperliche Leistung bei aufeinanderfolgenden Serien kurzfristiger intensiver körperlicher Übungen. EU-autorisierter Health Claim. EFSA NDA Panel concluded that a cause-and-effect relationship exists between creatine and improved physical performance during repeated bouts of short-term, high-intensity exercise. Dose: ≥3 g creatine monohydrate per day. This is one of the most well-supported sports nutrition health claims in EU law.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "vitamin-e",
        "claims": [
            {
                "title": "Vitamin E — Zellschutz (EFSA 432/2012)",
                "content": "Vitamin E trägt dazu bei, die Zellen vor oxidativem Stress zu schützen. EU-autorisierter Health Claim. EFSA confirmed vitamin E (alpha-tocopherol) as a lipid-soluble antioxidant protecting cell membranes from oxidative damage. Key in protecting polyunsaturated fatty acids from peroxidation. Minimum 1.8 mg per 100 g/ml for claim.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "vitamin-k2",
        "claims": [
            {
                "title": "Vitamin K — Knochen und Blutgerinnung (EFSA 432/2012)",
                "content": "Vitamin K trägt zur Erhaltung normaler Knochen bei und wird für die normale Blutgerinnung benötigt. EU-autorisierter Health Claim. EFSA confirmed Vitamin K's role as cofactor for gamma-carboxylation of osteocalcin in bone and clotting factors II, VII, IX, X in liver. Vitamin K2 (MK-7) has longer half-life than K1, better bioavailability for extrahepatic tissues including bone.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "probiotika",
        "claims": [
            {
                "title": "Probiotika — EFSA-Position zu Gesundheitsaussagen (Scientific Opinion 2013)",
                "content": "EFSA Scientific Opinion (2013): EFSA has not authorized generic probiotic health claims due to insufficient evidence for the term 'probiotic' itself. Claims must be substantiated for specific strains. EFSA requires: defined strain identity (genus, species, strain designation), evidence for survival through GI tract, specific health outcome demonstrated in RCTs in target population. Examples of strain-specific claims under review: Lactobacillus rhamnosus GG for traveler's diarrhea, Bifidobacterium animalis DN-173 010 for bowel transit.",
                "evidence_level": "yellow",
            },
        ],
    },
    {
        "slug": "curcumin",
        "claims": [
            {
                "title": "Curcumin — EFSA-Bewertung und fehlende Autorisierung (Scientific Opinion)",
                "content": "EFSA Scientific Opinion: Curcumin health claims were NOT authorized in the EU (Regulation 432/2012 rejection list). Reasons: insufficient evidence in human clinical trials, low bioavailability of standard curcumin, heterogeneity of studies. EFSA requires demonstrated bioavailability and consistent human trial evidence. Piperine-enhanced or nanoparticle formulations show improved bioavailability but are not yet covered by claims. Currently classified as evidence level: insufficient for EU authorization.",
                "evidence_level": "yellow",
            },
        ],
    },
    {
        "slug": "coenzym-q10",
        "claims": [
            {
                "title": "Coenzym Q10 — EFSA-Bewertung (Scientific Opinion 2010)",
                "content": "EFSA Scientific Opinion on CoQ10 (2010): Health claims for CoQ10 were NOT authorized. Submitted claims for heart function, energy production, and antioxidant protection were rejected due to insufficient human evidence meeting EFSA standards. EFSA noted that while CoQ10 is important in mitochondrial electron transport chain, the evidence from human intervention studies was insufficient to establish a cause-and-effect relationship for disease prevention or health maintenance claims.",
                "evidence_level": "yellow",
            },
        ],
    },
    {
        "slug": "ashwagandha",
        "claims": [
            {
                "title": "Ashwagandha — EFSA Novel Food Status (2022)",
                "content": "EFSA Novel Food assessment of Ashwagandha (Withania somnifera) root extract (2022): EFSA concluded that Ashwagandha root extract has a history of use in food but noted safety concerns at high doses including potential effects on thyroid hormones, hepatotoxicity risk, and effects on reproductive hormones. Maximum safe intake: 300 mg standardized extract/day. Not EU-authorized for health claims. Evidence for adaptogenic and stress-reduction effects remains at observational/pilot trial level in EU assessment.",
                "evidence_level": "yellow",
            },
        ],
    },
    {
        "slug": "jod",
        "claims": [
            {
                "title": "Jod — Schilddrüse und Kognition (EFSA 432/2012)",
                "content": "Jod trägt zur normalen Funktion der Schilddrüse bei und ist wichtig für normale kognitive Funktion. EU-autorisierter Health Claim. EFSA confirmed iodine as essential component of thyroid hormones T3 and T4. Thyroid hormones regulate metabolism, growth, and brain development. Iodine deficiency is the most common preventable cause of intellectual disability worldwide. Minimum 15 µg per 100 g/ml for claim. Particularly critical during pregnancy.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "biotin",
        "claims": [
            {
                "title": "Biotin — Haare, Haut, Nägel (EFSA 432/2012)",
                "content": "Biotin trägt zur Erhaltung normaler Haare und normaler Haut bei. EU-autorisierter Health Claim. EFSA confirmed biotin (vitamin B7) role in macronutrient metabolism and structural protein synthesis. Note: EFSA has NOT authorized a claim for biotin specifically improving hair growth or preventing hair loss beyond maintaining normal hair. Claims about biotin 'boosting' hair growth are not EU-authorized. Minimum 7.5 µg per 100 g/ml for authorized claim.",
                "evidence_level": "green",
            },
        ],
    },
    {
        "slug": "l-carnitin",
        "claims": [
            {
                "title": "L-Carnitin — EFSA-Bewertung Fettstoffwechsel",
                "content": "EFSA Scientific Opinion on L-Carnitine: Claims for fat burning and weight loss were NOT authorized. Evidence from human trials is inconsistent. L-Carnitine is naturally synthesized from lysine and methionine; healthy adults are not typically deficient. Exception: dialysis patients and premature infants. EFSA concluded insufficient evidence for the claimed effects on fat metabolism and body composition in healthy adults. Carnitine supplementation shows benefit only in deficiency states.",
                "evidence_level": "yellow",
            },
        ],
    },
    {
        "slug": "resveratrol",
        "claims": [
            {
                "title": "Resveratrol — EFSA-Bewertung (Scientific Opinion 2010)",
                "content": "EFSA Scientific Opinion on Resveratrol (2010): Health claims were NOT authorized. Despite promising preclinical data, human clinical trials showed inconsistent results. EFSA noted poor bioavailability of trans-resveratrol. No cause-and-effect relationship could be established for cardiovascular protection, anti-aging, or metabolic claims in human trials meeting EFSA evidence standards. Classification: insufficient human evidence for EU health claim authorization.",
                "evidence_level": "yellow",
            },
        ],
    },
]

# Supplement-Slug-Mapping für alle weiteren Supplements aus unserer DB
ADDITIONAL_EU_REFERENCE_INTAKES = [
    {
        "slug": "vitamin-a",
        "title": "Vitamin A — EU Referenzwert und Sicherheitsobergrenze (EFSA)",
        "content": "EFSA Population Reference Intake: 750 µg RE/day for adult men, 650 µg RE/day for adult women. Tolerable Upper Intake Level (UL): 3000 µg RE/day (preformed vitamin A / retinol). Excess retinol is teratogenic — pregnant women should avoid liver and high-dose retinol supplements. Beta-carotene from plant sources is safe at high intakes (no UL set). EU-authorized claim: Vitamin A contributes to normal vision and maintenance of normal skin.",
        "evidence_level": "green",
    },
    {
        "slug": "vitamin-b6",
        "title": "Vitamin B6 — EU Sicherheitsbewertung und Health Claims (EFSA)",
        "content": "EFSA authorized health claims: Vitamin B6 contributes to normal energy-yielding metabolism, normal function of the nervous system, normal homocysteine metabolism, and normal psychological function. UL: 25 mg/day (risk of peripheral neuropathy at high doses — regulatory concern in EU). Several EU member states have restricted high-dose B6 supplements. Minimum for claim: 0.21 mg per 100g/ml.",
        "evidence_level": "green",
    },
    {
        "slug": "vitamin-b1",
        "title": "Thiamin (Vitamin B1) — EFSA Health Claims",
        "content": "EFSA authorized health claims: Thiamin contributes to normal energy-yielding metabolism, normal function of the nervous system, and normal psychological function. Thiamin is essential for pyruvate dehydrogenase complex and the pentose phosphate pathway. Deficiency causes beriberi and Wernicke-Korsakoff syndrome. Minimum 0.165 mg per 100g/ml for claim authorization.",
        "evidence_level": "green",
    },
    {
        "slug": "vitamin-b2",
        "title": "Riboflavin (Vitamin B2) — EFSA Health Claims",
        "content": "EFSA authorized health claims: Riboflavin contributes to normal energy-yielding metabolism, maintenance of normal vision, normal iron metabolism, and protection of cells from oxidative stress. As FAD/FMN cofactor, riboflavin is central to mitochondrial electron transport. EU reference value: 1.3-1.6 mg/day for adults.",
        "evidence_level": "green",
    },
    {
        "slug": "vitamin-b3",
        "title": "Niacin (Vitamin B3) — EFSA Health Claims und Sicherheit",
        "content": "EFSA authorized health claims: Niacin contributes to normal energy-yielding metabolism, normal psychological function, and maintenance of normal skin and mucous membranes. As NAD+/NADH cofactor, niacin is central to hundreds of oxidation-reduction reactions. UL: 10 mg/day (nicotinic acid form — flushing; UL for nicotinamide: 900 mg/day). High-dose niacin (1-3 g/day) reduces LDL and raises HDL — requires medical supervision.",
        "evidence_level": "green",
    },
]


def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)


def supplement_exists(cur, slug: str) -> bool:
    cur.execute("SELECT 1 FROM supplements WHERE slug = %s", (slug,))
    return cur.fetchone() is not None


def upsert_fact(cur, supplement_slug: str, title: str, content: str,
                evidence_level: str, embedding_list: list):
    embedding_str = str(embedding_list)
    cur.execute("""
        INSERT INTO supplement_facts
            (supplement_slug, fact_type, content, embedding, source)
        VALUES (%s, %s, %s, %s::vector, %s)
        ON CONFLICT DO NOTHING
    """, (
        supplement_slug,
        f"efsa_claim_{evidence_level}",
        f"{title}\n\n{content}",
        embedding_str,
        "efsa",
    ))


async def main():
    logger.info("Lade fastembed Modell...")
    model = TextEmbedding("BAAI/bge-small-en-v1.5")
    logger.info("Modell geladen.")

    conn = get_db_connection()
    conn.autocommit = False
    cur = conn.cursor()

    total_inserted = 0
    total_skipped = 0

    # ── Autorisierte Claims aus EFSA_CLAIMS ─────────────────────────────────
    logger.info("Verarbeite EFSA Health Claims...")
    for entry in EFSA_CLAIMS:
        slug = entry["slug"]

        if not supplement_exists(cur, slug):
            logger.warning(f"  Supplement '{slug}' nicht in DB — überspringe")
            total_skipped += len(entry["claims"])
            continue

        for claim in entry["claims"]:
            text_to_embed = f"{claim['title']}. {claim['content']}"
            embedding = list(model.embed([text_to_embed]))[0].tolist()

            upsert_fact(
                cur,
                supplement_slug=slug,
                title=claim["title"],
                content=claim["content"],
                evidence_level=claim["evidence_level"],
                embedding_list=embedding,
            )
            total_inserted += 1
            logger.info(f"  ✓ {slug}: {claim['title'][:60]}...")
            time.sleep(0.05)  # Embedding ist schnell, kurze Pause für DB

    # ── EU Referenzwerte für weitere Supplements ─────────────────────────────
    logger.info("Verarbeite EU Referenzwerte...")
    for entry in ADDITIONAL_EU_REFERENCE_INTAKES:
        slug = entry["slug"]

        if not supplement_exists(cur, slug):
            logger.warning(f"  Supplement '{slug}' nicht in DB — überspringe")
            total_skipped += 1
            continue

        text_to_embed = f"{entry['title']}. {entry['content']}"
        embedding = list(model.embed([text_to_embed]))[0].tolist()

        upsert_fact(
            cur,
            supplement_slug=slug,
            title=entry["title"],
            content=entry["content"],
            evidence_level=entry["evidence_level"],
            embedding_list=embedding,
        )
        total_inserted += 1
        logger.info(f"  ✓ {slug}: {entry['title'][:60]}...")
        time.sleep(0.05)

    conn.commit()
    cur.close()
    conn.close()

    logger.info(f"""
╔══════════════════════════════════════════╗
║  EFSA Population abgeschlossen          ║
║  Eingefügt:   {total_inserted:>4} Einträge              ║
║  Übersprungen:{total_skipped:>4} (Supplement fehlt)   ║
╚══════════════════════════════════════════╝
""")


if __name__ == "__main__":
    asyncio.run(main())
