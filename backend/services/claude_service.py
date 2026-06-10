import json
import logging
import re
from datetime import datetime
from pathlib import Path

import anthropic

from config.settings import settings
from models.profile import UserProfile
from models.recommendation import RecommendationResponse, SupplementRecommendation, EvidenceLevel, InteractionSeverity, SupplementType, ProductLink
from data.products import get_products
from services.pubmed_service import PubMedService

logger = logging.getLogger(__name__)

# --- Supplement-Wissensdatenbank einmalig laden ---
_DB_PATH = Path(__file__).parent.parent / "data" / "supplement_knowledge.json"
try:
    with open(_DB_PATH, encoding="utf-8") as f:
        _SUPPLEMENT_DB: dict = json.load(f).get("supplements", {})
    logger.info(f"Supplement-DB geladen: {len(_SUPPLEMENT_DB)} Einträge")
except Exception as e:
    logger.error(f"Supplement-DB konnte nicht geladen werden: {e}")
    _SUPPLEMENT_DB = {}


# --- Fester Gruppen-Supplement Platzhalter (immer angehängt) ---
_BKOMPLEX = SupplementRecommendation(
    id="vitamin-b-komplex",
    name="Vitamin B-Komplex",
    substance_name="B1, B2, B3, B5, B6, B7, B9, B12",
    evidence_level=EvidenceLevel.green,
    evidence_reason="Alle B-Vitamine gut erforscht — sinnvoll wenn mehrere niedrig sind.",
    dosage="1 Kapsel täglich",
    intake_time="Morgens",
    intake_hint="Zum Frühstück — B-Vitamine wasserlöslich",
    drug_interaction=None,
    interaction_severity=InteractionSeverity.none,
    supplement_type=SupplementType.group,
    enthaltene_wirkstoffe=["B1", "B2", "B3", "B5", "B6", "B7", "B9", "B12"],
    categories=["Energie", "Nervensystem", "Immunsystem"],
)


def _get_season() -> str:
    month = datetime.now().month
    if month in (12, 1, 2):
        return "Winter"
    if month in (3, 4, 5):
        return "Frühling"
    if month in (6, 7, 8):
        return "Sommer"
    return "Herbst"


def _severity_from_db(supplement_id: str, medications: list[str]) -> tuple[InteractionSeverity, str | None]:
    """
    Sucht in der lokalen DB nach Wechselwirkungen zwischen dem Supplement
    und den Medikamenten des Nutzers. Gibt die schlimmste Severity + Text zurück.
    Mapping DB-Severity → InteractionSeverity:
      "gering"  → timing   (gelb — Zeitabstand genügt meist)
      "moderat" → moderate (orange — Arzt-Rücksprache)
      "hoch"    → high     (rot — starke Wechselwirkung)
    """
    if not medications or supplement_id not in _SUPPLEMENT_DB:
        return InteractionSeverity.none, None

    db_entry = _SUPPLEMENT_DB[supplement_id]
    severity_rank = {"gering": 1, "moderat": 2, "hoch": 3}
    severity_map = {
        "gering": InteractionSeverity.timing,
        "moderat": InteractionSeverity.moderate,
        "hoch": InteractionSeverity.high,
    }

    worst_severity = 0
    worst_text = None
    worst_level = InteractionSeverity.none

    for interaction in db_entry.get("drug_interactions", []):
        drug_lower = interaction["drug"].lower()
        for med in medications:
            if any(word in drug_lower for word in med.lower().split()):
                rank = severity_rank.get(interaction.get("severity", "gering"), 1)
                if rank > worst_severity:
                    worst_severity = rank
                    worst_text = interaction["effect"]
                    worst_level = severity_map.get(interaction.get("severity", "gering"), InteractionSeverity.timing)

    return worst_level, worst_text


def _build_db_context(medications: list[str], conditions: list[str]) -> str:
    """
    Baut einen Kontext-Block aus der lokalen Supplement-DB.
    Fokussiert auf Wechselwirkungen mit den Medikamenten des Nutzers
    und Kontraindikationen für seine Erkrankungen.
    """
    if not _SUPPLEMENT_DB:
        return ""

    lines = ["=== VERIFIZIERTE SUPPLEMENT-DATENBANK ==="]
    lines.append("(Aus dieser Datenbank stammen Wechselwirkungen und Kontraindikationen)\n")

    for supp_id, data in _SUPPLEMENT_DB.items():
        relevant_interactions = []

        # Nur Wechselwirkungen die für diesen Nutzer relevant sind
        if medications:
            for interaction in data.get("drug_interactions", []):
                drug_lower = interaction["drug"].lower()
                for med in medications:
                    if any(word in drug_lower for word in med.lower().split()):
                        relevant_interactions.append(
                            f"  ⚠️ Mit {med}: {interaction['effect']} "
                            f"[Schweregrad: {interaction['severity']}]"
                        )

        # Kontraindikationen für Erkrankungen des Nutzers
        relevant_contraindications = []
        if conditions:
            for contra in data.get("contraindications", []):
                for cond in conditions:
                    if any(word in contra.lower() for word in cond.lower().split()):
                        relevant_contraindications.append(f"  ❌ Vorsicht bei {cond}: {contra}")

        # Nur Supplements mit relevanten Infos oder alle (für Vollständigkeit)
        entry_lines = [f"[{data['name']}]"]
        entry_lines.append(f"  Evidenz: {data['evidence_summary']}")
        entry_lines.append(f"  Beste Form: {', '.join(data.get('optimal_forms', []))}")
        entry_lines.append(f"  Einnahme: {data.get('intake_notes', '')}")

        if relevant_interactions:
            entry_lines.append("  WECHSELWIRKUNGEN (für diesen Nutzer):")
            entry_lines.extend(relevant_interactions)

        if relevant_contraindications:
            entry_lines.append("  KONTRAINDIKATIONEN:")
            entry_lines.extend(relevant_contraindications)

        lines.extend(entry_lines)
        lines.append("")

    return "\n".join(lines)


def _build_pubmed_context(studies: list[dict]) -> str:
    """Formatiert PubMed-Studien als lesbaren Kontext-Block."""
    if not studies:
        return ""

    lines = ["=== AKTUELLE PUBMED-STUDIEN ==="]
    for s in studies:
        if s.get("title"):
            lines.append(f"[PMID:{s['pmid']} | {s['year']}] {s['title']}")
        if s.get("abstract"):
            lines.append(f"  Abstract: {s['abstract']}")
        lines.append("")

    return "\n".join(lines)


SYSTEM_PROMPT = """Du bist StackSense, ein evidenzbasierter Supplement-Berater.

DEINE AUFGABE:
Analysiere das Nutzerprofil und erstelle personalisierte Supplement-Empfehlungen für das angegebene Ziel.

DATENQUELLEN (Priorität absteigend):
1. Die VERIFIZIERTE SUPPLEMENT-DATENBANK im Kontext — diese hat Vorrang vor deinem Trainingswissen
2. Die PUBMED-STUDIEN im Kontext — aktuelle Forschung für dieses Ziel
3. Dein allgemeines Trainingswissen als Ergänzung

WICHTIGE REGELN:
1. Antworte AUSSCHLIESSLICH mit validem JSON — kein Text davor oder danach
2. Bewerte jeden Wirkstoff nach echter wissenschaftlicher Evidenz:
   - "green": Mehrere RCTs oder Meta-Analysen belegen die Wirkung klar
   - "yellow": Erste Studien zeigen Hinweise, aber Evidenz noch unvollständig
   - "red": Kaum oder keine belastbare Evidenz beim Menschen
3. Berücksichtige ALLE Profilparameter: Alter, Geschlecht, Erkrankungen, Medikamente, Jahreszeit, Sport
4. Wechselwirkungen: Nutze AUSSCHLIESSLICH die Daten aus der Supplement-DB — erfinde keine
5. Formuliere HWG-konform: keine Heilsversprechen, nur sachliche Informationen
6. Sortiere: Grün → Gelb → Rot
7. ZEICHENLIMITS — unbedingt einhalten:
   - evidence_reason: max 100 Zeichen
   - dosage: max 40 Zeichen
   - intake_time: max 40 Zeichen
   - intake_hint: max 80 Zeichen (oder null)
   - drug_interaction: max 80 Zeichen (oder null)
8. Generiere EXAKT so viele Supplements wie im LIMIT angegeben — nicht mehr, nicht weniger
9. Überspringe alle Supplements deren IDs in BEREITS GEZEIGT aufgeführt sind

SUPPLEMENT-TYPEN:
- "single": Enthält genau EINEN Wirkstoff (z.B. Vitamin D3, Magnesium, L-Glycin)
- "group": Enthält MEHRERE Wirkstoffe in einem Produkt (z.B. B-Komplex, Multivitamin, Omega-3+D3)
  → Bei "group": enthaltene_wirkstoffe als Liste angeben
  → Bei "single": enthaltene_wirkstoffe = []

JSON-FORMAT (exakt einhalten):
{
  "recommendations": [
    {
      "id": "vitamin-d3",
      "name": "Vitamin D3",
      "substance_name": "Cholecalciferol",
      "supplement_type": "single",
      "enthaltene_wirkstoffe": [],
      "evidence_level": "green",
      "evidence_reason": "Starke RCT-Evidenz bei Defizit — im Winter bei 70% der Deutschen zu niedrig.",
      "dosage": "2.000–4.000 IE täglich",
      "intake_time": "Morgens",
      "intake_hint": "Mit fetthaltiger Mahlzeit — fettlöslich",
      "drug_interaction": null,
      "categories": ["Immunsystem", "Energie", "Stimmung"]
    }
  ]
}

KATEGORIEN-REGELN:
- Wähle 1–3 passende Kategorien aus dieser Liste:
  Schlaf, Energie, Fokus, Stimmung, Stress, Immunsystem, Sport & Erholung,
  Herzgesundheit, Schilddrüse, Verdauung, Hormonbalance, Entzündung, Knochen & Gelenke
- Nur Kategorien die wirklich zutreffen — nicht alle auflisten"""


PRODUCTS_SYSTEM_PROMPT = """Du bist ein Supplement-Einkaufsberater für den deutschen Markt.

AUFGABE:
Finde 2–4 konkrete Produktoptionen für das angegebene Supplement bei Sunday Natural.

SUNDAY NATURAL URL-FORMAT:
- Basis-URL: https://www.sunday.de/en/[produkt-slug].html
- Slug ist kebab-case des Produktnamens auf Englisch
- Beispiele:
  * Magnesium Bisglycinat → magnesium-glycinate-pure-capsules.html
  * Vitamin D3 2000 IE → vitamin-d3-2000-ie-capsules.html
  * Ashwagandha KSM-66 → ashwagandha-ksm-66-root-extract.html
  * Omega-3 → omega-3-fish-oil-capsules.html
  * Zink → zinc-bisglycinate-capsules.html
  * Kreatin → creatine-monohydrate-powder.html

REGELN:
- Antworte AUSSCHLIESSLICH mit validem JSON
- Biete verschiedene Formen/Dosierungen an wenn sinnvoll (z.B. isoliert vs. Komplex)
- label: kurzer Produktname max 50 Zeichen
- note: kurzer Hinweis warum diese Option max 60 Zeichen (oder null)

JSON-FORMAT:
{
  "products": [
    {
      "label": "Magnesium Bisglycinat 120 Kapseln",
      "shop": "Sunday Natural",
      "url": "https://www.sunday.de/en/magnesium-glycinate-pure-capsules.html",
      "note": "Hochbioverfügbar, magenfreundlich"
    }
  ]
}"""

EXPLAIN_SYSTEM_PROMPT = """Du erklärst Nahrungsergänzungsmittel für absolute Laien.

REGELN:
- 2-3 kurze Sätze, max 300 Zeichen
- Keine Fachbegriffe
- Gerne eine einfache Analogie (Auto, Baukasten, Akku, etc.)
- Antworte NUR mit dem Erklärungstext — kein JSON, keine Formatierung"""


FOOD_SOURCES_SYSTEM_PROMPT = """Du bist ein Ernährungsexperte und nennst die besten natürlichen Lebensmittelquellen für Nährstoffe.

AUFGABE:
Nenne 4–6 Lebensmittel die besonders reich an dem angegebenen Nährstoff sind.

REGELN:
- Antworte AUSSCHLIESSLICH mit validem JSON
- Sortiere nach Gehalt (höchster Gehalt zuerst)
- food: Name des Lebensmittels, max 35 Zeichen
- note: kurze Mengenangabe oder Kontext, max 50 Zeichen (z.B. "100g ≈ 600 IE", "nur wenn fettreich")
- Realistische, alltagstaugliche Lebensmittel bevorzugen
- Keine Supplements — nur echte Lebensmittel

JSON-FORMAT (exakt einhalten):
{
  "sources": [
    {"food": "Lachs", "note": "100g ≈ 600 IE Vitamin D"},
    {"food": "Hühnerei (Eigelb)", "note": "2 Stück ≈ 80 IE"}
  ]
}"""


DUPLICATE_CHECK_PROMPT = """Du prüfst ob ein neues Supplement Wirkstoffe enthält die bereits im Stack des Nutzers vorhanden sind.

REGELN:
- Erkenne semantisch gleiche Wirkstoffe unabhängig von Schreibweise oder Abkürzung:
  B2 = Vitamin B2 = Riboflavin, B12 = Vitamin B12 = Cobalamin, Vit. D = Vitamin D3 = Cholecalciferol usw.
- Kombipräparate überlappen wenn mindestens EIN enthaltener Wirkstoff bereits im Stack ist
- Antworte AUSSCHLIESSLICH mit validem JSON — kein Text davor oder danach

JSON-FORMAT:
{
  "duplicates": ["id-des-stack-eintrags-1", "id-des-stack-eintrags-2"],
  "reasoning": "Kurze Begründung auf Deutsch, max 100 Zeichen"
}

Falls keine Duplikate: { "duplicates": [], "reasoning": "Keine Wirkstoffüberschneidung gefunden." }"""


def _extract_json(raw: str) -> str:
    code_block_match = re.search(r"```(?:json)?\s*(\{.*\})\s*```", raw, re.DOTALL)
    if code_block_match:
        return code_block_match.group(1).strip()
    json_match = re.search(r"\{.*\}", raw, re.DOTALL)
    if json_match:
        return json_match.group(0).strip()
    return raw


def _build_user_message(
    profile: UserProfile,
    goal: str,
    db_context: str,
    pubmed_context: str,
    limit: int = 5,
    exclude_ids: list[str] | None = None,
) -> str:
    season = _get_season()
    gender_map = {"male": "männlich", "female": "weiblich", "diverse": "divers"}
    sport_map = {
        "none": "kaum aktiv",
        "light": "leicht aktiv (1-2x/Woche)",
        "moderate": "moderat aktiv (3-4x/Woche)",
        "intense": "sehr aktiv (5+x/Woche)",
    }

    lines = ["NUTZERPROFIL:"]
    lines.append(f"- Alter: {profile.age} Jahre")
    lines.append(f"- Geschlecht: {gender_map.get(profile.gender, profile.gender)}")
    lines.append(f"- Aktivität: {sport_map.get(profile.sport_level, profile.sport_level)}")
    lines.append(f"- Jahreszeit: {season}")

    if profile.conditions:
        lines.append(f"- Erkrankungen: {', '.join(profile.conditions)}")
    if profile.medications:
        lines.append(f"- Dauermedikamente: {', '.join(profile.medications)}")
    if profile.is_pregnant:
        lines.append("- Schwanger / stillend: ja")

    lines.append(f"\nGEWÜNSCHTES ZIEL: {goal}")
    lines.append(f"\nLIMIT: Generiere exakt {limit} Supplements.")

    if exclude_ids:
        lines.append(f"BEREITS GEZEIGT (überspringen): {', '.join(exclude_ids)}")

    if db_context:
        lines.append(f"\n{db_context}")

    if pubmed_context:
        lines.append(f"\n{pubmed_context}")

    lines.append("\nErstelle passende Supplement-Empfehlungen als JSON.")
    return "\n".join(lines)


class ClaudeService:
    def __init__(self):
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.pubmed = PubMedService()

    async def get_recommendations(
        self, profile: UserProfile, goal: str,
        limit: int = 5, exclude_ids: list[str] | None = None,
    ) -> RecommendationResponse:
        logger.info(f"Empfehlungsanfrage: Ziel='{goal}', Alter={profile.age}")

        # --- Kontext aufbauen: DB + PubMed ---
        db_context = _build_db_context(
            medications=profile.medications or [],
            conditions=profile.conditions or [],
        )

        # PubMed-Studien für das gewählte Ziel holen
        try:
            pubmed_studies = await self.pubmed.get_goal_evidence(goal=goal, max_results=5)
            pubmed_context = _build_pubmed_context(pubmed_studies)
            logger.info(f"PubMed: {len(pubmed_studies)} Studien geladen für '{goal}'")
        except Exception as e:
            logger.warning(f"PubMed nicht verfügbar: {e}")
            pubmed_context = ""

        user_message = _build_user_message(
            profile, goal, db_context, pubmed_context,
            limit=limit, exclude_ids=exclude_ids or [],
        )

        message = self.client.messages.create(
            model=settings.claude_model,
            max_tokens=settings.claude_max_tokens,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )

        raw = _extract_json(message.content[0].text.strip())

        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error(f"Claude JSON-Fehler: {e}\nRaw: {raw[:500]}")
            raise ValueError(f"Claude-Antwort ist kein valides JSON: {e}")

        recommendations = []
        for item in data.get("recommendations", []):
            supplement_id = item["id"]
            products = get_products(supplement_id)
            product_links = [
                ProductLink(label=p["label"], shop=p["shop"], url=p["url"], note=p.get("note"))
                for p in products
            ]

            # Wechselwirkung + Severity aus DB (verifiziert) — überschreibt Claude
            db_severity, db_interaction_text = _severity_from_db(
                supplement_id, profile.medications or []
            )
            # Falls DB nichts kennt, Claudes Hinweis als Fallback (timing-Level)
            if db_severity == InteractionSeverity.none and item.get("drug_interaction"):
                final_interaction = item.get("drug_interaction")
                final_severity = InteractionSeverity.timing
            else:
                final_interaction = db_interaction_text or item.get("drug_interaction")
                final_severity = db_severity

            # supplement_type aus Claude-Antwort lesen — Default: single
            raw_type = item.get("supplement_type", "single")
            try:
                supp_type = SupplementType(raw_type)
            except ValueError:
                supp_type = SupplementType.single

            rec = SupplementRecommendation(
                id=supplement_id,
                name=item["name"],
                substance_name=item.get("substance_name"),
                evidence_level=EvidenceLevel(item["evidence_level"]),
                evidence_reason=item["evidence_reason"],
                dosage=item["dosage"],
                intake_time=item["intake_time"],
                intake_hint=item.get("intake_hint"),
                drug_interaction=final_interaction,
                interaction_severity=final_severity,
                simple_explanation=None,
                product_links=product_links,
                categories=item.get("categories", []),
                supplement_type=supp_type,
                enthaltene_wirkstoffe=item.get("enthaltene_wirkstoffe", []),
            )
            recommendations.append(rec)

        # B-Komplex anhängen — außer er ist bereits in exclude_ids (wurde schon gezeigt)
        if _BKOMPLEX.id not in (exclude_ids or []):
            recommendations.append(_BKOMPLEX)

        logger.info(f"Claude lieferte {len(recommendations)} Empfehlungen + Gruppen-Platzhalter (mit DB+PubMed Kontext)")
        return RecommendationResponse(goal=goal, recommendations=recommendations)

    async def get_simple_explanation(
        self, supplement_name: str, substance_name: str | None
    ) -> str:
        name = f"{supplement_name} ({substance_name})" if substance_name else supplement_name
        logger.info(f"Sonnet-Erklärung für: {name}")

        message = self.client.messages.create(
            model=settings.claude_explain_model,
            max_tokens=256,
            system=EXPLAIN_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f"Erkläre mir {name} wie ich 5 Jahre alt bin."}],
        )
        return message.content[0].text.strip()

    async def get_food_sources(
        self, supplement_name: str, substance_name: str | None
    ) -> list[dict]:
        name = f"{supplement_name} ({substance_name})" if substance_name else supplement_name
        logger.info(f"Lebensmittelquellen für: {name}")

        message = self.client.messages.create(
            model=settings.claude_explain_model,
            max_tokens=512,
            system=FOOD_SOURCES_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f"Nährstoff: {name}"}],
        )

        raw = _extract_json(message.content[0].text.strip())
        try:
            data = json.loads(raw)
            return data.get("sources", [])
        except (json.JSONDecodeError, KeyError) as e:
            logger.error(f"Food-Sources JSON Fehler: {e}\nRaw: {raw}")
            return []

    async def check_duplicates(
        self,
        new_supplement: dict,
        stack: list[dict],
    ) -> dict:
        """
        Prüft semantisch ob das neue Supplement Wirkstoffe enthält die bereits im Stack sind.
        Gibt { "duplicates": [ids...], "reasoning": "..." } zurück.
        Nutzt Haiku — schnell und günstig für diese einfache Klassifikation.
        """
        if not stack:
            return {"duplicates": [], "reasoning": "Stack ist leer."}

        def _fmt(s: dict) -> str:
            parts = [f"Name: {s['name']}"]
            if s.get("substance_name"):
                parts.append(f"Wirkstoff: {s['substance_name']}")
            if s.get("enthaltene_wirkstoffe"):
                parts.append(f"Enthält: {', '.join(s['enthaltene_wirkstoffe'])}")
            return " | ".join(parts)

        stack_lines = "\n".join(
            f"- ID={e['id']} | {_fmt(e)}" for e in stack
        )

        user_msg = (
            f"NEUES SUPPLEMENT:\n{_fmt(new_supplement)}\n\n"
            f"AKTUELLER STACK:\n{stack_lines}\n\n"
            "Welche Stack-Einträge enthalten denselben Wirkstoff wie das neue Supplement?"
        )

        message = self.client.messages.create(
            model=settings.claude_model,
            max_tokens=256,
            system=DUPLICATE_CHECK_PROMPT,
            messages=[{"role": "user", "content": user_msg}],
        )

        raw = _extract_json(message.content[0].text.strip())
        try:
            return json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error(f"Duplikat-Check JSON Fehler: {e}\nRaw: {raw}")
            return {"duplicates": [], "reasoning": "Fehler bei der Prüfung."}

    async def get_product_suggestions(
        self, supplement_name: str, substance_name: str | None, categories: list[str]
    ) -> list[ProductLink]:
        name = f"{supplement_name} ({substance_name})" if substance_name else supplement_name
        cats = ", ".join(categories) if categories else "allgemein"
        logger.info(f"Produkt-Suche für: {name}")

        user_msg = (
            f"Supplement: {name}\n"
            f"Anwendungsbereiche: {cats}\n"
            f"Finde passende Kaufoptionen bei Sunday Natural."
        )

        message = self.client.messages.create(
            model=settings.claude_model,
            max_tokens=512,
            system=PRODUCTS_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_msg}],
        )

        raw = _extract_json(message.content[0].text.strip())
        try:
            data = json.loads(raw)
            return [
                ProductLink(
                    label=p["label"],
                    shop=p.get("shop", "Sunday Natural"),
                    url=p["url"],
                    note=p.get("note"),
                )
                for p in data.get("products", [])
            ]
        except (json.JSONDecodeError, KeyError) as e:
            logger.error(f"Produkt-JSON Fehler: {e}\nRaw: {raw}")
            return []
