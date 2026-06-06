import json
import logging
import re
from datetime import datetime

import anthropic

from config.settings import settings
from models.profile import UserProfile
from models.recommendation import RecommendationResponse, SupplementRecommendation, EvidenceLevel

logger = logging.getLogger(__name__)

# Aktueller Monat → Jahreszeit ableiten
def _get_season() -> str:
    month = datetime.now().month
    if month in (12, 1, 2):
        return "Winter"
    if month in (3, 4, 5):
        return "Frühling"
    if month in (6, 7, 8):
        return "Sommer"
    return "Herbst"


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
7. evidence_reason: max 120 Zeichen, prägnant und faktisch
8. Empfehle 3-6 Supplements — nicht mehr

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
      "drug_interaction": null
    }
  ]
}"""


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
        f"NUTZERPROFIL:",
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

        logger.info(f"Claude-Anfrage für Ziel: {goal}, Alter: {profile.age}")

        message = self.client.messages.create(
            model=settings.claude_model,
            max_tokens=settings.claude_max_tokens,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )

        raw = message.content[0].text.strip()
        logger.debug(f"Claude raw response (first 200 chars): {raw[:200]}")

        # Claude sometimes wraps JSON in markdown code blocks — extract JSON robustly
        # Handles: ```json\n{...}\n```, ```\n{...}\n```, or plain {…}
        code_block_match = re.search(r"```(?:json)?\s*(\{.*\})\s*```", raw, re.DOTALL)
        if code_block_match:
            raw = code_block_match.group(1).strip()
        else:
            # Try to extract the outermost JSON object directly
            json_match = re.search(r"\{.*\}", raw, re.DOTALL)
            if json_match:
                raw = json_match.group(0).strip()

        # JSON parsen — Fehler klar loggen
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error(f"Claude hat kein valides JSON geliefert: {e}\nRaw: {raw}")
            raise ValueError(f"Claude-Antwort ist kein valides JSON: {e}")

        # Pydantic-Modelle bauen
        recommendations = []
        for item in data.get("recommendations", []):
            rec = SupplementRecommendation(
                id=item["id"],
                name=item["name"],
                substance_name=item.get("substance_name"),
                evidence_level=EvidenceLevel(item["evidence_level"]),
                evidence_reason=item["evidence_reason"],
                dosage=item["dosage"],
                intake_time=item["intake_time"],
                intake_hint=item.get("intake_hint"),
                drug_interaction=item.get("drug_interaction"),
            )
            recommendations.append(rec)

        logger.info(f"Claude lieferte {len(recommendations)} Empfehlungen")

        return RecommendationResponse(goal=goal, recommendations=recommendations)
