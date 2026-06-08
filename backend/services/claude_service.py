import json
import logging
import re
from datetime import datetime

import anthropic

from config.settings import settings
from models.profile import UserProfile
from models.recommendation import RecommendationResponse, SupplementRecommendation, EvidenceLevel, ProductLink
from data.products import get_products

logger = logging.getLogger(__name__)


def _get_season() -> str:
    month = datetime.now().month
    if month in (12, 1, 2):
        return "Winter"
    if month in (3, 4, 5):
        return "Frühling"
    if month in (6, 7, 8):
        return "Sommer"
    return "Herbst"


# Haupt-Prompt: kein simple_explanation → Haiku bleibt schnell
SYSTEM_PROMPT = """Du bist StackSense, ein evidenzbasierter Supplement-Berater.

DEINE AUFGABE:
Analysiere das Nutzerprofil und erstelle personalisierte Supplement-Empfehlungen für das angegebene Ziel.

WICHTIGE REGELN:
1. Antworte AUSSCHLIESSLICH mit validem JSON — kein Text davor oder danach
2. Bewerte jeden Wirkstoff nach echter wissenschaftlicher Evidenz:
   - "green": Mehrere RCTs oder Meta-Analysen belegen die Wirkung klar
   - "yellow": Erste Studien zeigen Hinweise, aber Evidenz noch unvollständig
   - "red": Kaum oder keine belastbare Evidenz beim Menschen
3. Berücksichtige ALLE Profilparameter: Alter, Geschlecht, Erkrankungen, Medikamente, Jahreszeit, Sport
4. Weise explizit auf Wechselwirkungen mit genannten Medikamenten hin
5. Formuliere HWG-konform: keine Heilsversprechen, nur sachliche Informationen
6. Sortiere: Grün → Gelb → Rot
7. ZEICHENLIMITS — unbedingt einhalten:
   - evidence_reason: max 100 Zeichen
   - dosage: max 40 Zeichen
   - intake_time: max 40 Zeichen
   - intake_hint: max 80 Zeichen (oder null)
   - drug_interaction: max 80 Zeichen (oder null)
8. Liste ALLE relevanten Supplements auf — typisch 6–12 pro Ziel
   - Mindestens alle wichtigen grünen und gelben Supplements nennen
   - Rote nur wenn sie im Markt verbreitet aber unbegründet sind (zur Aufklärung)
   - Nicht künstlich kürzen: vollständigkeit ist wichtiger als Kürze

JSON-FORMAT (exakt einhalten):
{
  "recommendations": [
    {
      "id": "vitamin-d3",
      "name": "Vitamin D3",
      "substance_name": "Cholecalciferol",
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

# Produkt-Such-Prompt: findet passende Kaufoptionen on-demand
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

# Erklärungs-Prompt: on-demand, Sonnet für bessere Qualität
EXPLAIN_SYSTEM_PROMPT = """Du erklärst Nahrungsergänzungsmittel für absolute Laien.

REGELN:
- 2-3 kurze Sätze, max 300 Zeichen
- Keine Fachbegriffe
- Gerne eine einfache Analogie (Auto, Baukasten, Akku, etc.)
- Antworte NUR mit dem Erklärungstext — kein JSON, keine Formatierung"""


def _extract_json(raw: str) -> str:
    """Entfernt Markdown-Codeblöcke und extrahiert den JSON-String."""
    code_block_match = re.search(r"```(?:json)?\s*(\{.*\})\s*```", raw, re.DOTALL)
    if code_block_match:
        return code_block_match.group(1).strip()
    json_match = re.search(r"\{.*\}", raw, re.DOTALL)
    if json_match:
        return json_match.group(0).strip()
    return raw


def _build_user_message(profile: UserProfile, goal: str) -> str:
    season = _get_season()
    gender_map = {"male": "männlich", "female": "weiblich", "diverse": "divers"}
    sport_map = {
        "none": "kaum aktiv",
        "light": "leicht aktiv (1-2x/Woche)",
        "moderate": "moderat aktiv (3-4x/Woche)",
        "intense": "sehr aktiv (5+x/Woche)",
    }

    lines = [
        "NUTZERPROFIL:",
        f"- Alter: {profile.age} Jahre",
        f"- Geschlecht: {gender_map.get(profile.gender, profile.gender)}",
        f"- Aktivität: {sport_map.get(profile.sport_level, profile.sport_level)}",
        f"- Jahreszeit: {season}",
    ]
    if profile.conditions:
        lines.append(f"- Erkrankungen: {', '.join(profile.conditions)}")
    if profile.medications:
        lines.append(f"- Dauermedikamente: {', '.join(profile.medications)}")
    if profile.is_pregnant:
        lines.append("- Schwanger / stillend: ja")

    lines.append(f"\nGEWÜNSCHTES ZIEL: {goal}")
    lines.append("\nErstelle passende Supplement-Empfehlungen als JSON.")
    return "\n".join(lines)


class ClaudeService:
    def __init__(self):
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)

    async def get_recommendations(
        self, profile: UserProfile, goal: str
    ) -> RecommendationResponse:
        user_message = _build_user_message(profile, goal)
        logger.info(f"Claude Haiku-Anfrage für Ziel: {goal}, Alter: {profile.age}")

        message = self.client.messages.create(
            model=settings.claude_model,  # Haiku — schnell
            max_tokens=settings.claude_max_tokens,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )

        raw = _extract_json(message.content[0].text.strip())

        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error(f"Claude hat kein valides JSON geliefert: {e}\nRaw: {raw}")
            raise ValueError(f"Claude-Antwort ist kein valides JSON: {e}")

        recommendations = []
        for item in data.get("recommendations", []):
            supplement_id = item["id"]
            products = get_products(supplement_id)

            product_links = [
                ProductLink(
                    label=p["label"],
                    shop=p["shop"],
                    url=p["url"],
                    note=p.get("note"),
                )
                for p in products
            ]

            rec = SupplementRecommendation(
                id=supplement_id,
                name=item["name"],
                substance_name=item.get("substance_name"),
                evidence_level=EvidenceLevel(item["evidence_level"]),
                evidence_reason=item["evidence_reason"],
                dosage=item["dosage"],
                intake_time=item["intake_time"],
                intake_hint=item.get("intake_hint"),
                drug_interaction=item.get("drug_interaction"),
                simple_explanation=None,
                product_links=product_links,
                categories=item.get("categories", []),
            )
            recommendations.append(rec)
            if product_links:
                logger.info(f"{len(product_links)} Produkte verknüpft: {supplement_id}")

        logger.info(f"Claude lieferte {len(recommendations)} Empfehlungen")
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

    async def get_product_suggestions(
        self, supplement_name: str, substance_name: str | None, categories: list[str]
    ) -> list[ProductLink]:
        """Findet on-demand passende Kaufoptionen via Claude."""
        name = f"{supplement_name} ({substance_name})" if substance_name else supplement_name
        cats = ", ".join(categories) if categories else "allgemein"
        logger.info(f"Produkt-Suche für: {name}")

        user_msg = (
            f"Supplement: {name}\n"
            f"Anwendungsbereiche: {cats}\n"
            f"Finde passende Kaufoptionen bei Sunday Natural."
        )

        message = self.client.messages.create(
            model=settings.claude_model,  # Haiku — schnell genug
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
