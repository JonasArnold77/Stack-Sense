import asyncio
import hashlib
import json
import logging
import re
import time
from datetime import datetime
from pathlib import Path

import anthropic

from config.settings import settings
from models.profile import UserProfile
from models.recommendation import RecommendationResponse, SupplementRecommendation, SecondaryBenefit, EvidenceLevel, InteractionSeverity, SupplementType, SubstanceCategory, ProductLink, SynergyRecommendation, SynergyResponse
from data.products import get_products
from services.pubmed_service import PubMedService
from services.vector_service import (
    search_studies as vector_search,
    get_precomputed_ranking,
    get_precomputed_supplement_info,
)
from services.rxnorm_service import RxNormService

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Einfacher In-Memory Cache für Empfehlungen
# Key = hash(goal + profil-relevante Felder), TTL = 6h
# ---------------------------------------------------------------------------
_recommendation_cache: dict[str, tuple[float, RecommendationResponse]] = {}
_CACHE_TTL = 6 * 3600  # 6 Stunden


def _cache_key(
    goal: str, profile: UserProfile, limit: int, exclude_ids: list[str],
    db_only: bool = False,
) -> str:
    """Erzeugt einen stabilen Cache-Key aus den relevanten Anfrage-Parametern.
    Für Basis-Supplementierung wird das vollständige Profil einbezogen;
    für alle anderen Ziele (Problemfelder / Phasenziele) zählt nur das Ziel selbst.
    db_only-Anfragen bekommen einen eigenen Cache-Namespace, da Kontext/Prompt
    grundlegend anders sind (kein Profil, kein LLM-synthetisierte Datenbank).
    """
    if db_only:
        relevant = {"goal": goal, "limit": limit, "exclude": sorted(exclude_ids), "db_only": True}
    elif goal == "Basis-Supplementierung":
        relevant = {
            "goal": goal,
            "age": profile.age,
            "sex": profile.gender,
            "conditions": sorted(profile.conditions or []),
            "medications": sorted(profile.medications or []),
            "sport": profile.sport_level,
            "limit": limit,
            "exclude": sorted(exclude_ids),
        }
    else:
        relevant = {
            "goal": goal,
            "limit": limit,
            "exclude": sorted(exclude_ids),
        }
    raw = json.dumps(relevant, ensure_ascii=False, sort_keys=True)
    return hashlib.md5(raw.encode()).hexdigest()


def _cache_get(key: str) -> RecommendationResponse | None:
    entry = _recommendation_cache.get(key)
    if entry and (time.time() - entry[0]) < _CACHE_TTL:
        return entry[1]
    if entry:
        del _recommendation_cache[key]   # abgelaufen → entfernen
    return None


def _cache_set(key: str, value: RecommendationResponse) -> None:
    # Max 50 Einträge im Cache (LRU-light)
    if len(_recommendation_cache) >= 50:
        oldest = min(_recommendation_cache, key=lambda k: _recommendation_cache[k][0])
        del _recommendation_cache[oldest]
    _recommendation_cache[key] = (time.time(), value)

# --- Supplement-Wissensdatenbank einmalig laden ---
_DB_PATH = Path(__file__).parent.parent / "data" / "supplement_knowledge.json"
try:
    with open(_DB_PATH, encoding="utf-8") as f:
        _SUPPLEMENT_DB: dict = json.load(f).get("supplements", {})
    logger.info(f"Supplement-DB geladen: {len(_SUPPLEMENT_DB)} Einträge")
except Exception as e:
    logger.error(f"Supplement-DB konnte nicht geladen werden: {e}")
    _SUPPLEMENT_DB = {}

# --- RxNorm Singleton (lazy) — Fallback-Normalisierung für Medikamentennamen ---
_rxnorm_service: RxNormService | None = None


def _get_rxnorm() -> RxNormService:
    global _rxnorm_service
    if _rxnorm_service is None:
        _rxnorm_service = RxNormService()
    return _rxnorm_service


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


async def _severity_from_db(supplement_id: str, medications: list[str]) -> tuple[InteractionSeverity, str | None]:
    """
    Sucht in der lokalen DB nach Wechselwirkungen zwischen dem Supplement
    und den Medikamenten des Nutzers. Gibt die schlimmste Severity + Text zurück.
    Mapping DB-Severity → InteractionSeverity:
      "gering"  → timing   (gelb — Zeitabstand genügt meist)
      "moderat" → moderate (orange — Arzt-Rücksprache)
      "hoch"    → high     (rot — starke Wechselwirkung)

    Matching läuft zweistufig:
      1. Einfacher Substring-Abgleich (schnell, deckt die meisten Fälle ab)
      2. Falls kein Treffer: RxNorm-Wirkstoffnamen-Fallback (fängt Marken-
         namen/Schreibvarianten ab, die Stufe 1 verpasst — siehe rxnorm_service.py
         für die Abdeckungs-Limitation bei deutschen Markennamen)
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

    if worst_severity == 0:
        try:
            rxnorm = _get_rxnorm()
            for med in medications:
                ingredient_names = await rxnorm.resolve_ingredient_names(med)
                if not ingredient_names:
                    continue
                for interaction in db_entry.get("drug_interactions", []):
                    drug_lower = interaction["drug"].lower()
                    if any(
                        name.lower() in drug_lower or drug_lower in name.lower()
                        for name in ingredient_names
                    ):
                        rank = severity_rank.get(interaction.get("severity", "gering"), 1)
                        if rank > worst_severity:
                            worst_severity = rank
                            worst_text = interaction["effect"]
                            worst_level = severity_map.get(
                                interaction.get("severity", "gering"), InteractionSeverity.timing
                            )
        except Exception as e:
            logger.warning(f"RxNorm-Fallback-Matching fehlgeschlagen (non-fatal): {e}")

    return worst_level, worst_text


def _build_db_context(medications: list[str], conditions: list[str]) -> str:
    """
    Baut einen Kontext-Block aus der lokalen Supplement-DB.
    Fokussiert auf Wechselwirkungen mit den Medikamenten des Nutzers
    und Kontraindikationen für seine Erkrankungen.
    """
    if not _SUPPLEMENT_DB:
        return ""

    lines = ["=== KURATIERTE SUPPLEMENT-DATENBANK (LLM-synthetisiert aus PubMed) ==="]
    lines.append("(Aus dieser Datenbank stammen Wechselwirkungen und Kontraindikationen. "
                  "Unabhängig extern verifizierte Fakten — EFSA, NIH ODS, openFDA CAERS, "
                  "NIH DSLD — stehen zusätzlich im Block 'Kuratierte Datenbanken' weiter unten.)\n")

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


_PITCH_MAX_CHARS = 320


def _truncate_pitch(text: str) -> str:
    """Kürzt den Pitch-Text an der letzten vollständigen Satzgrenze vor _PITCH_MAX_CHARS.
    Niemals mitten in einem Satz abschneiden."""
    if len(text) <= _PITCH_MAX_CHARS:
        return text
    window = text[:_PITCH_MAX_CHARS]
    # Letzte Satzgrenze (. ! ?) innerhalb des Fensters suchen
    for i in range(len(window) - 1, 40, -1):
        if window[i] in ".!?" and (i + 1 >= len(window) or window[i + 1] == " "):
            return window[:i + 1]
    # Fallback: letztes vollständiges Wort, kein harter Schnitt
    return window.rsplit(" ", 1)[0].rstrip(".,;:—–-") + "."


SYSTEM_PROMPT = """Du bist StackSense, ein evidenzbasierter Supplement-Berater.

DEINE AUFGABE:
Analysiere das Nutzerprofil und erstelle personalisierte Supplement-Empfehlungen für das angegebene Ziel.

⛔ HARDREGEL — KEIN TRAININGSWISSEN:
Du darfst AUSSCHLIESSLICH Supplements empfehlen, die in der KURATIERTEN SUPPLEMENT-DATENBANK, den PUBMED-STUDIEN oder dem Block "Kuratierte Datenbanken" (EFSA/NIH ODS/openFDA/DSLD) im Kontext explizit erwähnt werden.
Wenn ein Supplement NICHT im bereitgestellten Kontext vorkommt, empfiehl es NICHT — auch wenn du aus deinem Training weißt dass es wirksam sein könnte.
Erfinde keine Evidenz. Verwende KEIN Wissen aus deinem Training außer zur Formatierung der JSON-Antwort.
Falls der Kontext für das angegebene Ziel zu wenig Supplements enthält, gib weniger als das Limit zurück — aber fülle nie mit Trainingswissen auf.
Warnhinweise aus dem Block "openFDA CAERS" (gemeldete unerwünschte Ereignisse) sind unvalidierte Verdachtsmeldungen — stelle sie nie als bewiesene Kausalität dar, sondern als "in Einzelfällen berichtet".

DATENQUELLEN (Priorität absteigend):
1. Die KURATIERTE SUPPLEMENT-DATENBANK im Kontext — primäre Grundlage für Wechselwirkungen/Kontraindikationen
2. Der Block "Kuratierte Datenbanken" (EFSA, NIH ODS, openFDA CAERS, NIH DSLD) — unabhängig verifizierte externe Fakten, bei Widerspruch zur DB aus 1. vorrangig
3. Die PUBMED-STUDIEN im Kontext — bestätigen oder erhöhen die Priorität von Einträgen aus 1./2.

WICHTIGE REGELN:
1. Antworte AUSSCHLIESSLICH mit validem JSON — kein Text davor oder danach
2. Bewerte jeden Wirkstoff nach echter wissenschaftlicher Evidenz:
   - "green": Mehrere RCTs oder Meta-Analysen belegen die Wirkung klar
   - "yellow": Erste Studien zeigen Hinweise, aber Evidenz noch unvollständig
   - "red": Kaum oder keine belastbare Evidenz beim Menschen
3. Berücksichtige ALLE Profilparameter: Alter, Geschlecht, Erkrankungen, Medikamente, Jahreszeit, Sport
4. Wechselwirkungen: Nutze AUSSCHLIESSLICH die Daten aus der Supplement-DB — erfinde keine
5. FORMULIERUNGSREGELN (HWG-konform — sehr wichtig):
   - Keine direkten Wirkungsbehauptungen ("senkt Cortisol", "stärkt das Immunsystem", "verbessert den Schlaf")
   - Beschreibe stattdessen was Studien beobachtet haben: "In Studien berichteten Teilnehmer von...", "RCTs zeigen...", "Studien deuten auf... hin"
   - Persönlich und verständlich formulieren — aber immer aus Studienperspektive: "In Studien mit Schlafschwierigkeiten zeigte Magnesium in mehreren RCTs messbare Verbesserungen"
   - Kein Imperativ der Wirkungen verspricht ("schläfst du besser", "wachst erholt auf")
   - Erlaubt: Mangelaussagen ("Im Winter haben 70% der Deutschen zu wenig Vitamin D") und neutrale Studienbeschreibungen
6. Sortiere STRIKT nach relevance_score absteigend — das Supplement mit dem höchsten relevance_score kommt zuerst in der Liste. WICHTIG: Reihenfolge und Score müssen übereinstimmen: Platz 1 = höchster Score, Platz 2 = zweithöchster usw. Grüne Supplements erhalten tendenziell höhere Scores als gelbe oder rote, da starke Evidenz die Zielpassung erhöht. Die ersten 3 in der Liste sind die absolut besten Empfehlungen — sie werden dem Nutzer als "Beste Wahl", "2. Wahl" und "3. Wahl" hervorgehoben angezeigt.
7. ZEICHENLIMITS — unbedingt einhalten:
   - pitch: 3–4 vollständige Sätze, zusammen 200–300 Zeichen. Jeder Satz endet mit einem Punkt.
       Satz 1: Warum ist dieses Supplement für den Nutzer jetzt relevant? (Profil, Jahreszeit, Ziel)
       Satz 2–3: Was zeigen Studien konkret? (Studientyp, beobachteter Effekt — keine direkte Wirkungsbehauptung)
       Satz 4 (optional): Besonderheit für dieses Profil oder Hinweis der Mehrwert schafft.
       Fließend und informativ — kein Aufzählungsstil, kein Fachjargon.
       ✅ "Im Winter hat fast jeder zu wenig Vitamin D. Mehrere große RCTs zeigen, dass Menschen mit ausreichendem Spiegel seltener krank werden. Für dein Immunsystem ist das gerade besonders relevant."
       ✅ "Magnesium wird bei Stress besonders schnell verbraucht. Mehrere RCTs berichten von ruhigerem Schlaf bei Menschen mit niedrigem Spiegel. Da du viel Sport machst, ist dein Bedarf zusätzlich erhöht."
   - evidence_reason: max 90 Zeichen — Studienlage präzise, Effekt als Beobachtung nicht als Tatsache
   - secondary_benefit.text: max 100 Zeichen (oder null)
   - dosage: max 40 Zeichen
   - intake_time: max 40 Zeichen
   - intake_hint: max 80 Zeichen (oder null)
   - drug_interaction: max 80 Zeichen (oder null)
   - food_coverage_score: Ganzzahl 1–10 (siehe ERNÄHRUNGSABDECKUNG weiter unten)
   - relevance_score: Ganzzahl 0–100 (siehe PASSGENAUIGKEIT weiter unten)
8. Generiere EXAKT so viele Supplements wie im LIMIT angegeben — nicht mehr, nicht weniger
9. Überspringe alle Supplements deren IDs in BEREITS GEZEIGT aufgeführt sind

ZWEISTUFIGE BEGRÜNDUNG — SEHR WICHTIG:
- evidence_reason: NUR der Grund der direkt zum gewünschten ZIEL passt (z.B. bei Ziel "Sport": Regeneration, Kraftleistung, Ausdauer). KEINE anderen Effekte hier.
- secondary_benefit: Falls das Supplement ZUSÄTZLICH für eine Erkrankung oder Eigenschaft aus dem Profil des Nutzers relevant ist (z.B. Zyklus, Hashimoto, Schwangerschaft, Diabetes), trage das hier ein — mit eigenem evidence_level und condition-Label.
  → Beispiel: Nutzer hat Ziel "Energie", aber Profil-Erkrankung "Hashimoto": Magnesium evidence_reason erklärt Energie-Wirkung, secondary_benefit erklärt Schilddrüsen-Relevanz.
  → Falls kein profilrelevanter Zusatznutzen existiert: secondary_benefit = null

SUPPLEMENT-TYPEN:
- "single": Enthält genau EINEN Wirkstoff (z.B. Vitamin D3, Magnesium, L-Glycin)
- "group": Enthält MEHRERE Wirkstoffe in einem Produkt (z.B. B-Komplex, Multivitamin, Omega-3+D3)
  → Bei "group": enthaltene_wirkstoffe als Liste angeben
  → Bei "single": enthaltene_wirkstoffe = []

STOFFKLASSE (substance_category) — GENAU EINEN der folgenden 6 Werte wählen, exakt so geschrieben:
- "Vitamine" (z.B. Vitamin D, Vitamin C, B-Komplex)
- "Mineralstoffe" (z.B. Magnesium, Zink, Eisen, Calcium)
- "Omega & Fettsäuren" (z.B. Omega-3, MCT-Öl)
- "Aminosäuren & Protein" (z.B. BCAA, L-Glutamin, Whey, Kreatin)
- "Pflanzliche Extrakte" (z.B. Ashwagandha, Kurkuma, Ginseng)
- "Darm & Verdauung" (z.B. Probiotika, Verdauungsenzyme)
Wähle die inhaltlich am besten passende Kategorie auch bei Grenzfällen (z.B. Melatonin/Coenzym Q10 → am ehesten "Vitamine" wenn vitaminähnlich, sonst die nächstpassende der 6 Kategorien). Kein 7. Wert, keine Erfindungen.

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
      "substance_category": "Vitamine",
      "pitch": "Im Winter hat fast jeder zu wenig Vitamin D. Mehrere große RCTs zeigen, dass Menschen mit ausreichendem Spiegel seltener krank werden. Für dein Immunsystem ist das gerade besonders relevant.",
      "evidence_reason": "Mehrere Meta-Analysen (>10.000 Teilnehmer) belegen: Mangel erhöht Infektrisiko messbar.",
      "secondary_benefit": {
        "text": "Bei Hashimoto: Studien zeigen Zusammenhang mit niedrigeren TPO-Antikörperwerten.",
        "evidence_level": "green",
        "condition": "Hashimoto"
      },
      "dosage": "2.000–4.000 IE täglich",
      "intake_time": "Morgens",
      "intake_hint": "Mit fetthaltiger Mahlzeit — fettlöslich",
      "drug_interaction": null,
      "food_coverage_score": 2,
      "relevance_score": 91,
      "categories": ["Immunsystem", "Energie", "Stimmung"]
    }
  ]
}

ERNÄHRUNGSABDECKUNG (food_coverage_score):
- Ganzzahl 1–10: Wie realistisch lässt sich der Tagesbedarf durch Lebensmittel decken?
- Bewerte NUR danach ob die benötigte Dosis durch Essen erreichbar ist — nicht danach ob es ein "klassisches" Lebensmittel ist
- WICHTIG: Wenn das Supplement selbst ein Lebensmittel oder Lebensmittelextrakt ist (z.B. Pilze, Wurzeln, Gewürze), und die wirksame Tagesdosis durch normale Portionen dieses Lebensmittels erreichbar ist, dann HOCH bewerten (6–9) — auch wenn es kein Supermarkt-Standardprodukt ist
- 1–2 = Kaum möglich (z.B. Vitamin D, Melatonin, Q10 — kein Lebensmittel liefert ausreichend)
- 3–4 = Schwer (z.B. Omega-3 EPA/DHA — nur durch täglich fetten Fisch in großen Mengen)
- 5–6 = Bedingt möglich (z.B. Magnesium — mit gezielter Ernährung aus Nüssen/Hülsenfrüchten; Lion's Mane — frischer Pilz deckt Dosis, aber Verfügbarkeit begrenzt)
- 7–8 = Gut möglich (z.B. Vitamin C — durch täglich Obst/Gemüse; Curcuma — durch regelmäßiges Kochen)
- 9–10 = Sehr leicht (z.B. Kalium, Biotin — in vielen alltäglichen Lebensmitteln reichlich vorhanden)

PASSGENAUIGKEIT (relevance_score):
- Ganzzahl 0–100: Wie gut erfüllt dieses Supplement den ausgewählten Zweck?
- Der Score ist die EINZIGE Grundlage für die Sortierung — höchster Score = erste Position. Vergib keine gleichen Scores für verschiedene Positionen.

Scoreberechnung je nach Kontext:

Bei PROBLEMFELDERN und PHASENZIELEN:
- 85% des Scores: Wie direkt und stark wirkt das Supplement auf genau dieses Ziel? (unabhängig vom Profil)
- 15% des Scores: Evidenzstärke (grün = Bonus, rot = Abzug) — Profil nur bei Kontraindikationen relevant (senkt Score wenn Profil eine Einschränkung zeigt, z.B. Ashwagandha bei Hashimoto)

Bei BASIS-SUPPLEMENTIERUNG:
- 50% des Scores: Wie gut passt das Supplement zum individuellen Profil? (Alter, Geschlecht, Jahreszeit, Erkrankungen bestimmen hier den Grundbedarf)
- 35% des Scores: Stärke der wissenschaftlichen Evidenz für den allgemeinen Nutzen
- 15% des Scores: Breite des Nutzens (wirkt auf mehrere relevante Bereiche des Profils)

Skala (gilt für alle Kontexte):
- 90–100 = Erstlinien-Supplement für genau diesen Zweck, starke Evidenz (z.B. Melatonin bei Schlaf, Kreatin bei Sport, Folat bei Schwangerschaft)
- 70–89 = Sehr wichtig für den Zweck, gute Evidenz (z.B. Magnesium bei Schlaf, B12 bei Energie)
- 50–69 = Unterstützend, moderate Evidenz oder indirekter Wirkmechanismus
- 30–49 = Schwacher Zweckbezug, als Ergänzung sinnvoll
- 0–29 = Kaum Bezug — nur listen wenn Limit sonst nicht erfüllbar

KATEGORIEN-REGELN:
- Wähle 1–3 passende Kategorien aus dieser Liste:
  Schlaf, Energie, Fokus, Stimmung, Stress, Immunsystem, Sport & Erholung,
  Herzgesundheit, Schilddrüse, Verdauung, Hormonbalance, Entzündung, Knochen & Gelenke
- Nur Kategorien die wirklich zutreffen — nicht alle auflisten"""


# ---------------------------------------------------------------------------
# Datenbank-Modus — dieselbe Card-Generierung wie im LLM-Modus (siehe
# SYSTEM_PROMPT oben, insb. JSON-Format/Formulierungsregeln), aber mit
# verschärfter Grounding-Regel: kein Nutzerprofil, keine kuratierte
# LLM-synthetisierte Datenbank — nur die echten externen Rohdaten
# (PubMed/Europe PMC/EFSA/NIH ODS/openFDA CAERS/NIH DSLD) aus dem Kontext.
# ---------------------------------------------------------------------------
_DB_ONLY_PREFIX = """⛔ DATENBANK-MODUS — ZUSÄTZLICHE HARDREGEL (gilt zusätzlich zu allem Folgenden):
In diesem Modus gibt es KEINE kuratierte Supplement-Datenbank im Kontext und KEIN Nutzerprofil.
Die EINZIGE erlaubte Grundlage sind die Blöcke "PubMed Studienbasis" und "Kuratierte Datenbanken"
(EFSA/NIH ODS/openFDA CAERS/NIH DSLD) weiter unten im Kontext — echte externe Quellen, keine LLM-Synthese.
Verwende STRIKT NICHTS aus deinem Trainingswissen, auch nicht für Dosierung oder Einnahmezeitpunkt:
- dosage/intake_time/intake_hint: NUR befüllen wenn eine konkrete Angabe im Kontext steht (z.B. aus einem
  NIH-DSLD-Marktprodukt-Fakt oder einer NIH-ODS-Angabe). Steht nichts im Kontext, schreibe exakt
  "Siehe Herstellerangabe" (dosage) bzw. "Nicht in Datenbank" (intake_time) — rate NICHT.
- pitch/evidence_reason: Fasse NUR zusammen was in den Kontext-Snippets tatsächlich steht — keine
  Ausschmückung, keine allgemeinen Fakten über das Supplement, die dort nicht belegt sind.
- secondary_benefit: immer null (kein Nutzerprofil vorhanden).
- relevance_score: leite ihn NUR aus Menge und Stärke der im Kontext gefundenen Belege für dieses
  Supplement ab — nicht aus persönlicher Einschätzung, da kein Nutzerprofil existiert.
- Empfehle NUR Supplements, die im Kontext unten mit Namen vorkommen.

"""

SYSTEM_PROMPT_DB_ONLY = _DB_ONLY_PREFIX + SYSTEM_PROMPT


# ---------------------------------------------------------------------------
# Vorberechnungs-Modus — schlanke Rangliste (nur id/name/relevance_score),
# kein Nutzerprofil. Wird nur vom Precompute-Skript aufgerufen, nie zur
# Laufzeit. Die eigentliche Kartengenerierung passiert später beim Laden
# (siehe get_recommendations_from_precomputed / SYSTEM_PROMPT weiter oben).
# ---------------------------------------------------------------------------
RANKING_SYSTEM_PROMPT = """Du bewertest Supplements für ein Themenfeld — OHNE Nutzerprofil, rein nach
grundsätzlicher fachlicher Eignung. Das Ergebnis wird später pro Nutzer anhand des Profils
umsortiert; deine Aufgabe ist nur die GRUNDREIHENFOLGE.

HARDREGEL — KEIN TRAININGSWISSEN:
Du darfst AUSSCHLIESSLICH Supplements empfehlen, die im bereitgestellten Kontext explizit erwähnt
werden. Erfinde keine Evidenz.

AUFGABE:
Liste bis zu LIMIT Supplements für das angegebene Themenfeld, sortiert nach Passgenauigkeit.

BEWERTUNG (relevance_score, 0-100):
- Wie direkt und stark wirkt das Supplement auf genau dieses Themenfeld — unabhängig von jedem
  individuellen Nutzerprofil (das kommt erst in einem späteren Schritt dazu)?
- Evidenzstärke fließt mit ein (starke RCT-/Meta-Analyse-Lage = Bonus, kaum Evidenz = Abzug).
- 90–100 = Erstlinien-Supplement für genau dieses Themenfeld, starke Evidenz
- 70–89 = Sehr wichtig, gute Evidenz
- 50–69 = Unterstützend, moderate Evidenz
- 30–49 = Schwacher Bezug
- 0–29 = Kaum Bezug — nur falls Limit sonst nicht erfüllbar

Bei "Basis-Supplementierung": bewerte generische, altersunabhängige Grundrelevanz für einen
durchschnittlichen Erwachsenen (Vitamin D, Magnesium, Omega-3 etc. typischerweise hoch) — die
tatsächliche individuelle Profil-Passung kommt im späteren Umsortier-Schritt hinzu.

JSON-FORMAT (exakt einhalten, keine weiteren Felder):
{"ranking": [{"id": "vitamin-d3", "name": "Vitamin D3", "relevance_score": 95}]}

Sortiere absteigend nach relevance_score. Keine doppelten IDs. Generiere höchstens LIMIT Einträge."""

_RANKING_DB_ONLY_PREFIX = """⛔ DATENBANK-MODUS — ZUSÄTZLICHE HARDREGEL:
Die EINZIGE erlaubte Grundlage ist der Kontext unten (PubMed/Europe PMC/EFSA/NIH ODS/openFDA/DSLD) —
kein Trainingswissen. relevance_score nur aus Menge/Stärke der im Kontext gefundenen Belege ableiten.
Liste nur Supplements die im Kontext mit Namen vorkommen.

"""

RANKING_SYSTEM_PROMPT_DB_ONLY = _RANKING_DB_ONLY_PREFIX + RANKING_SYSTEM_PROMPT


RESORT_SYSTEM_PROMPT = """Du bekommst eine bereits erstellte, themenfeld-bezogene Rangliste von
Supplements (id, name, base_relevance_score) sowie ein vollständiges Nutzerprofil. Deine einzige
Aufgabe: die Liste anhand ALLER relevanten Profil-Fakten neu bewerten — Alter, Geschlecht,
Erkrankungen, Dauermedikamente, Schwangerschaft, Aktivitätslevel, Jahreszeit, und alles sonst was
du für relevant hältst.

WICHTIG:
- Passt ein Supplement laut Profil GAR NICHT (z.B. klare Kontraindikation, Schwangerschaft bei
  einem in der Schwangerschaft abzuratenden Stoff, bekannte Wechselwirkung mit einem
  Dauermedikament) → Score DEUTLICH absenken (mindestens -30 bis -60 Punkte), damit es weit nach
  unten rutscht.
- Passt ein Supplement besonders gut zum Profil zusätzlich zum Themenfeld → Score leicht anheben.
- Verändere NICHT die Supplement-Auswahl selbst (keine IDs hinzufügen/entfernen) — nur die Scores.
- Erfinde keine Wechselwirkungen/Kontraindikationen die nicht plausibel/bekannt sind.

Antworte AUSSCHLIESSLICH mit validem JSON, keine Erklärtexte:
{"ranking": [{"id": "vitamin-d3", "relevance_score": 62}]}

Gib für JEDE gegebene ID genau einen Eintrag zurück, in neuer absteigender Reihenfolge nach Score."""


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

EXPLAIN_SYSTEM_PROMPT = """Du erklärst Supplements einfach und verständlich — wie einem interessierten Laien
ohne biochemisches Vorwissen.

AUFGABE:
Erkläre in 3–5 kurzen Sätzen: Was ist dieser Stoff (Herkunft/Funktion im Körper in einfachen
Worten), und wofür wird er allgemein eingesetzt.

REGELN:
- Antworte AUSSCHLIESSLICH mit validem JSON, kein Text davor oder danach
- Einfache Sprache, keine Fachbegriffe ohne Erklärung, keine Studienzitate
- Reine Begriffserklärung — keine Wirksamkeitsbehauptungen ("hilft garantiert bei..."),
  stattdessen neutral beschreiben wofür es typischerweise verwendet wird
- max. 400 Zeichen insgesamt

JSON-FORMAT (exakt einhalten):
{"explanation": "Vitamin D ist eigentlich ein Hormon, das deine Haut bei Sonnenlicht selbst herstellt. Es hilft deinem Körper, Kalzium aus der Nahrung aufzunehmen — wichtig für Knochen. Im Winter, wenn wenig Sonne da ist, wird es oft als Supplement genommen."}"""


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


SYNERGY_SYSTEM_PROMPT = """Du bist ein Supplement-Experte. Deine Aufgabe: Synergie-Kombinationen empfehlen.

WICHTIG: Antworte NUR mit dem JSON-Objekt. Kein Text davor, kein Text danach, keine Erklärung.

JSON-FORMAT (exakt so):
{"synergies":[{"id":"magnesium-b6","substances":["Magnesium Bisglycinat","Vitamin B6"],"evidence_level":"green","synergy_score":85,"synergy_explanation":"Vitamin B6 erhöht die intrazelluläre Magnesiumkonzentration um bis zu 40%. Klinisch besonders relevant bei Stress und Schlaf.","dosage_hint":"Zusammen abends zum Essen nehmen"}]}

REGELN:
- evidence_level muss exakt "green", "yellow" oder "red" sein
- synergy_score: 0-100 (Passgenauigkeit zum Ziel)
- 3-4 Synergien ausgeben
- Nur wissenschaftlich belegte Kombinationen"""


# ---------------------------------------------------------------------------
# Kuratierter Fallback — greift wenn Claude-Call fehlschlägt oder 0 Synergien liefert
# Key = Keyword im Ziel (lowercase), Value = Liste von SynergyRecommendation-Dicts
# ---------------------------------------------------------------------------
_SYNERGY_FALLBACKS: list[dict] = [
    {
        "id": "vitamin-d3-k2",
        "substances": ["Vitamin D3", "Vitamin K2"],
        "evidence_level": "green",
        "synergy_score": 88,
        "synergy_explanation": (
            "Vitamin D3 erhöht die Calciumaufnahme — K2 (MK-7) sorgt dafür dass das Calcium "
            "in den Knochen landet und nicht in Arterien. Ohne K2 kann hochdosiertes D3 "
            "langfristig zu Verkalkungen führen. Die Kombination ist bei nahezu jedem Profil sinnvoll."
        ),
        "dosage_hint": "Beide fettlöslich — zusammen zur fetthaltigen Mahlzeit nehmen",
    },
    {
        "id": "magnesium-b6",
        "substances": ["Magnesium Bisglycinat", "Vitamin B6"],
        "evidence_level": "green",
        "synergy_score": 82,
        "synergy_explanation": (
            "Vitamin B6 (Pyridoxin) erhöht die intrazelluläre Magnesiumkonzentration um bis zu 40% "
            "und verbessert so die Aufnahme in die Zellen. Klinisch besonders wirksam bei Stress, "
            "Muskelkrämpfen und Schlafproblemen."
        ),
        "dosage_hint": "Zusammen abends zum Essen — ideal vor dem Schlafen",
    },
    {
        "id": "omega3-vitamin-d3",
        "substances": ["Omega-3 (EPA/DHA)", "Vitamin D3"],
        "evidence_level": "green",
        "synergy_score": 79,
        "synergy_explanation": (
            "Omega-3-Fettsäuren verbessern die Bioverfügbarkeit von Vitamin D3 erheblich, "
            "da D3 fettlöslich ist und Fischöl als optimales Lösungsmittel wirkt. "
            "Beide haben zudem synergistische entzündungshemmende Effekte."
        ),
        "dosage_hint": "Zusammen zur fetthaltigen Mahlzeit — maximale D3-Aufnahme",
    },
    {
        "id": "eisen-vitamin-c",
        "substances": ["Eisen (Bisglycinate)", "Vitamin C"],
        "evidence_level": "green",
        "synergy_score": 91,
        "synergy_explanation": (
            "Vitamin C (Ascorbinsäure) reduziert dreiwertiges Eisen zu zweiwertigem Eisen, "
            "das vom Darm wesentlich besser aufgenommen wird. Studien zeigen eine 2-3-fach "
            "höhere Absorptionsrate wenn beide zusammen eingenommen werden."
        ),
        "dosage_hint": "Zusammen auf nüchternen Magen — kein Kaffee/Tee dabei",
    },
    {
        "id": "zink-selen",
        "substances": ["Zink (Bisglycinat)", "Selen"],
        "evidence_level": "yellow",
        "synergy_score": 74,
        "synergy_explanation": (
            "Zink und Selen sind beides essenzielle Spurenelemente für das Immunsystem "
            "und wirken synergistisch als Antioxidantien. Beide aktivieren verschiedene "
            "Enzyme der Immunabwehr und ergänzen sich ohne gegenseitige Hemmung."
        ),
        "dosage_hint": "Morgens zum Frühstück — nicht mit Milchprodukten",
    },
    {
        "id": "ashwagandha-magnesium",
        "substances": ["Ashwagandha (KSM-66)", "Magnesium Bisglycinat"],
        "evidence_level": "yellow",
        "synergy_score": 80,
        "synergy_explanation": (
            "Ashwagandha senkt den Cortisolspiegel über die HPA-Achse, "
            "während Magnesium direkt das Nervensystem beruhigt und die Schlafqualität verbessert. "
            "Die Kombination adressiert Stress auf zwei verschiedenen Wegen gleichzeitig."
        ),
        "dosage_hint": "Beide abends 1h vor dem Schlafen nehmen",
    },
    {
        "id": "coq10-omega3",
        "substances": ["Coenzym Q10", "Omega-3 (EPA/DHA)"],
        "evidence_level": "yellow",
        "synergy_score": 76,
        "synergy_explanation": (
            "CoQ10 verbessert die mitochondriale Energieproduktion, "
            "Omega-3 reduziert die Entzündungslast die Mitochondrien belastet. "
            "Zusammen zeigen Studien positive Effekte auf kardiovaskuläre Gesundheit und Energie."
        ),
        "dosage_hint": "Beide fettlöslich — zum Mittagessen für beste Aufnahme",
    },
]


def _get_fallback_synergies(goal: str, n: int = 3) -> list[dict]:
    """
    Wählt n Fallback-Synergien aus basierend auf Keyword-Matching mit dem Ziel.
    Gibt immer mindestens die n besten Synergien zurück.
    """
    goal_lower = goal.lower()

    # Ziel-spezifische Gewichtung
    boost = {
        "schlaf": ["magnesium-b6", "ashwagandha-magnesium"],
        "stress": ["ashwagandha-magnesium", "magnesium-b6"],
        "energie": ["coq10-omega3", "omega3-vitamin-d3"],
        "immunsystem": ["zink-selen", "vitamin-d3-k2", "omega3-vitamin-d3"],
        "immun": ["zink-selen", "vitamin-d3-k2"],
        "knochen": ["vitamin-d3-k2", "eisen-vitamin-c"],
        "basis": ["vitamin-d3-k2", "omega3-vitamin-d3", "magnesium-b6"],
        "eisen": ["eisen-vitamin-c"],
        "erschöpf": ["coq10-omega3", "eisen-vitamin-c", "magnesium-b6"],
        "müd": ["coq10-omega3", "eisen-vitamin-c"],
        "fokus": ["omega3-vitamin-d3", "magnesium-b6"],
        "sport": ["magnesium-b6", "coq10-omega3"],
    }

    priority_ids: list[str] = []
    for keyword, ids in boost.items():
        if keyword in goal_lower:
            for sid in ids:
                if sid not in priority_ids:
                    priority_ids.append(sid)

    # Synergien nach Priorität sortieren
    id_index = {s["id"]: s for s in _SYNERGY_FALLBACKS}
    result = [id_index[sid] for sid in priority_ids if sid in id_index]

    # Auffüllen mit restlichen bis n erreicht
    for s in _SYNERGY_FALLBACKS:
        if len(result) >= n:
            break
        if s not in result:
            result.append(s)

    # Score leicht anpassen damit Ziel-relevante Synergien oben stehen
    adjusted = []
    for i, s in enumerate(result[:n]):
        adjusted.append({**s, "synergy_score": max(0, s["synergy_score"] - i * 3)})
    return adjusted


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
    db_only: bool = False,
) -> str:
    season = _get_season()
    gender_map = {"male": "männlich", "female": "weiblich", "diverse": "divers"}
    sport_map = {
        "none": "kaum aktiv",
        "light": "leicht aktiv (1-2x/Woche)",
        "moderate": "moderat aktiv (3-4x/Woche)",
        "intense": "sehr aktiv (5+x/Woche)",
    }

    if db_only:
        # Datenbank-Modus: kein Profil — reine Datenlage zum Ziel.
        lines = [f"GEWÜNSCHTES ZIEL: {goal}", "(Datenbank-Modus — kein Nutzerprofil)"]
    elif goal == "Basis-Supplementierung":
        # Basis: vollständiges Profil einbeziehen — die Empfehlung soll
        # individuell auf Alter, Geschlecht, Erkrankungen usw. abgestimmt sein.
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

        lines.append(
            "\nGEWÜNSCHTES ZIEL: Basis-Supplementierung\n"
            "Empfehle alle Supplements die für dieses Profil grundsätzlich sinnvoll sind — "
            "unabhängig von einem spezifischen Ziel. Berücksichtige Mikronährstoff-Lücken "
            "die für dieses Alter, Geschlecht, Jahreszeit und die genannten Erkrankungen "
            "typisch sind. Beginne mit den wichtigsten Basis-Supplements (Vitamin D, Magnesium, "
            "Omega-3 etc.) und sortiere nach klinischer Relevanz für dieses konkrete Profil.\n"
            "WICHTIG für dieses Ziel:\n"
            "- Schreibe in evidence_reason ALLE relevanten Gründe auf einmal — "
            "Profil-Erkrankungen, Jahreszeit, Alter, Sport — alles in einem Satz.\n"
            "- secondary_benefit = null bei ALLEN Supplements. Es gibt keine zweite Ebene."
        )
    else:
        # Problemfelder & Phasenziele: kein Profil — Empfehlung gilt allgemein
        # für das Ziel, unabhängig von individuellen Nutzerdaten.
        lines = [f"GEWÜNSCHTES ZIEL: {goal}"]
    lines.append(f"\nLIMIT: Generiere exakt {limit} Supplements.")

    if exclude_ids:
        lines.append(f"BEREITS GEZEIGT (überspringen): {', '.join(exclude_ids)}")

    if db_context:
        lines.append(f"\n{db_context}")

    if pubmed_context:
        lines.append(f"\n{pubmed_context}")

    lines.append("\nErstelle passende Supplement-Empfehlungen als JSON.")
    return "\n".join(lines)


async def _parse_recommendation_item(item: dict, medications: list[str]) -> SupplementRecommendation:
    """Baut ein SupplementRecommendation aus einem einzelnen Claude-JSON-Item —
    gemeinsam genutzt von get_recommendations() (mehrere Items pro Anfrage)
    und get_supplement_detail() (ein Item pro Such-Treffer)."""
    supplement_id = item["id"]
    products = get_products(supplement_id)
    product_links = [
        ProductLink(label=p["label"], shop=p["shop"], url=p["url"], note=p.get("note"))
        for p in products
    ]

    # Wechselwirkung + Severity aus DB (verifiziert) — überschreibt Claude
    db_severity, db_interaction_text = await _severity_from_db(supplement_id, medications)
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

    # substance_category aus Claude-Antwort lesen — None falls unbekannt/fehlt
    try:
        substance_category = SubstanceCategory(item.get("substance_category"))
    except ValueError:
        substance_category = None

    # secondary_benefit aus Claude-JSON parsen (optional)
    raw_secondary = item.get("secondary_benefit")
    secondary_benefit = None
    if raw_secondary and isinstance(raw_secondary, dict):
        try:
            secondary_benefit = SecondaryBenefit(
                text=raw_secondary.get("text", ""),
                evidence_level=EvidenceLevel(raw_secondary.get("evidence_level", "yellow")),
                condition=raw_secondary.get("condition", ""),
            )
        except (ValueError, KeyError) as e:
            logger.warning(f"secondary_benefit Parse-Fehler für {supplement_id}: {e}")

    return SupplementRecommendation(
        id=supplement_id,
        name=item["name"],
        substance_name=item.get("substance_name"),
        evidence_level=EvidenceLevel(item["evidence_level"]),
        substance_category=substance_category,
        pitch=_truncate_pitch(item.get("pitch", "")),
        evidence_reason=item["evidence_reason"],
        secondary_benefit=secondary_benefit,
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
        food_coverage_score=max(1, min(10, int(item.get("food_coverage_score", 5)))),
        relevance_score=max(0, min(100, int(item.get("relevance_score", 75)))),
    )


def _build_single_db_context(supplement_id: str) -> str:
    """Scoped db_context für die Einzel-Supplement-Suche — nur der eine
    Eintrag statt der gesamten kuratierten Datenbank (spart Tokens/Kosten)."""
    entry = _SUPPLEMENT_DB.get(supplement_id)
    if not entry:
        return ""
    lines = [
        "=== KURATIERTE SUPPLEMENT-DATENBANK (LLM-synthetisiert aus PubMed) ===",
        f"[{entry['name']}]",
        f"  Evidenz: {entry.get('evidence_summary', '')}",
        f"  Beste Form: {', '.join(entry.get('optimal_forms', []))}",
        f"  Einnahme: {entry.get('intake_notes', '')}",
    ]
    if entry.get("contraindications"):
        lines.append(f"  Kontraindikationen: {', '.join(entry['contraindications'])}")
    return "\n".join(lines)


def _build_lookup_message(supplement_name: str, db_context: str, pubmed_context: str) -> str:
    """User-Message für die Direktsuche nach einem bestimmten Supplement —
    anders als _build_user_message() geht es hier nicht um mehrere nach Ziel
    sortierte Empfehlungen, sondern um GENAU EINE Karte für einen Suchtreffer."""
    lines = [
        f'NUTZER-SUCHE: "{supplement_name}"',
        "Der Nutzer hat direkt nach diesem Supplement gesucht — nicht zielbasiert. "
        "Erstelle GENAU EINE Karte für dieses Supplement mit einer allgemeinen, "
        "evidenzbasierten Beschreibung seines Hauptnutzens (nicht auf ein bestimmtes "
        "Ziel bezogen). pitch und evidence_reason beschreiben den generellen "
        "wissenschaftlichen Nutzen. secondary_benefit = null (kein Nutzerprofil). "
        "relevance_score = 100 (Direkttreffer, keine Sortierung nötig).",
    ]
    if db_context:
        lines.append(f"\n{db_context}")
    if pubmed_context:
        lines.append(f"\n{pubmed_context}")
    lines.append(
        '\nErstelle die Supplement-Karte als JSON: {"recommendations": [<genau ein Element>]}'
    )
    return "\n".join(lines)


def _build_ranking_message(goal: str, db_context: str, pubmed_context: str, limit: int) -> str:
    lines = [f"THEMENFELD: {goal}", f"LIMIT: {limit}"]
    if db_context:
        lines.append(f"\n{db_context}")
    if pubmed_context:
        lines.append(f"\n{pubmed_context}")
    lines.append(f"\nErstelle die Rangliste als JSON (max. {limit} Einträge).")
    return "\n".join(lines)


def _build_resort_message(items: list[dict], profile: UserProfile) -> str:
    gender_map = {"male": "männlich", "female": "weiblich", "diverse": "divers"}
    sport_map = {
        "none": "kaum aktiv", "light": "leicht aktiv",
        "moderate": "moderat aktiv", "intense": "sehr aktiv",
    }
    profile_lines = [
        f"Alter: {profile.age} Jahre",
        f"Geschlecht: {gender_map.get(profile.gender, profile.gender)}",
        f"Aktivität: {sport_map.get(profile.sport_level, profile.sport_level)}",
        f"Jahreszeit: {_get_season()}",
    ]
    if profile.conditions:
        profile_lines.append(f"Erkrankungen: {', '.join(profile.conditions)}")
    if profile.medications:
        profile_lines.append(f"Dauermedikamente: {', '.join(profile.medications)}")
    if profile.is_pregnant:
        profile_lines.append("Schwanger / stillend: ja")

    ranking_lines = "\n".join(
        f"- id={i['id']} | {i['name']} | Score={i['base_relevance_score']}" for i in items
    )

    return (
        "NUTZERPROFIL:\n" + "\n".join(f"- {l}" for l in profile_lines) +
        f"\n\nAKTUELLE RANGLISTE:\n{ranking_lines}\n\n"
        "Bewerte diese Liste anhand des Profils neu."
    )


def _build_fresh_fields_message(
    profile: UserProfile, goal: str, page_items: list[dict],
    db_context: str, pubmed_context: str, db_only: bool,
) -> str:
    """User-Message für den letzten Schritt im Vorberechnungs-Modus: die
    Supplement-Auswahl UND Reihenfolge stehen schon fest (vorberechnet +
    umsortiert) — hier werden nur noch die individuellen Kartenfelder
    (Pitch, Begründung etc.) für genau diese Supplements generiert."""
    gender_map = {"male": "männlich", "female": "weiblich", "diverse": "divers"}
    sport_map = {
        "none": "kaum aktiv", "light": "leicht aktiv (1-2x/Woche)",
        "moderate": "moderat aktiv (3-4x/Woche)", "intense": "sehr aktiv (5+x/Woche)",
    }
    lines = [f"GEWÜNSCHTES ZIEL: {goal}"]
    if not db_only:
        lines.append(
            f"NUTZERPROFIL — Alter: {profile.age}, "
            f"Geschlecht: {gender_map.get(profile.gender, profile.gender)}, "
            f"Aktivität: {sport_map.get(profile.sport_level, profile.sport_level)}, "
            f"Jahreszeit: {_get_season()}"
        )
        if profile.conditions:
            lines.append(f"Erkrankungen: {', '.join(profile.conditions)}")
        if profile.medications:
            lines.append(f"Dauermedikamente: {', '.join(profile.medications)}")
        if profile.is_pregnant:
            lines.append("Schwanger / stillend: ja")

    supplement_list = "\n".join(f"- id={i['id']} | {i['name']}" for i in page_items)
    lines.append(
        "\nDIESE SUPPLEMENTS SIND BEREITS AUSGEWÄHLT UND SORTIERT (nicht verändern, keine "
        "weiteren hinzufügen, keine weglassen) — erstelle NUR die Kartenfelder dafür:\n"
        f"{supplement_list}"
    )
    if db_context:
        lines.append(f"\n{db_context}")
    if pubmed_context:
        lines.append(f"\n{pubmed_context}")
    lines.append(
        f"\nErstelle die Kartenfelder für GENAU diese {len(page_items)} Supplements als JSON "
        "(recommendations-Array, gleiche Reihenfolge wie oben)."
    )
    return "\n".join(lines)


class ClaudeService:
    def __init__(self):
        self.client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
        self.pubmed = PubMedService()

    async def get_recommendations(
        self, profile: UserProfile, goal: str,
        limit: int = 5, exclude_ids: list[str] | None = None,
        db_only: bool = False,
    ) -> RecommendationResponse:
        logger.info(
            f"Empfehlungsanfrage: Ziel='{goal}', Alter={profile.age}, db_only={db_only}"
        )

        # --- Cache prüfen ---
        cache_key = _cache_key(goal, profile, limit, exclude_ids or [], db_only=db_only)
        cached = _cache_get(cache_key)
        if cached:
            logger.info(f"Cache-Hit für '{goal}' (limit={limit}) — Claude-Aufruf übersprungen")
            return cached

        # --- Kontext aufbauen: DB + PubMed + Vector parallel ---
        # Datenbank-Modus: kein Profil, keine kuratierte (LLM-synthetisierte) DB —
        # nur echte externe Vektor-DB-Quellen. Für Problemfelder/Phasenziele: kein
        # Profilbezug — rein zielbasiert. Für Basis-Supplementierung: volles Profil.
        is_basis = goal == "Basis-Supplementierung"
        db_context = (
            "" if db_only else _build_db_context(
                medications=profile.medications or [] if is_basis else [],
                conditions=profile.conditions or [] if is_basis else [],
            )
        )

        query_text = (
            f"{goal} supplement {profile.conditions or ''} {profile.medications or ''}"
            if is_basis and not db_only
            else f"{goal} supplement"
        )

        # Nur Vector-DB — kein PubMed live fetch (zu langsam, Daten bereits in Vector-DB)
        # Im db_only-Modus mehr Treffer holen, da keine kuratierte DB als Rückgrat dient.
        vector_context = vector_search(query_text, supplement_names=[], top_k=12 if db_only else 8) or ""
        if vector_context:
            logger.info("Vector-DB: Kontext geladen.")
        combined_study_context = vector_context

        user_message = _build_user_message(
            profile, goal, db_context, combined_study_context,
            limit=limit, exclude_ids=exclude_ids or [], db_only=db_only,
        )

        message = await self.client.messages.create(
            model=settings.claude_model,
            max_tokens=settings.claude_max_tokens,
            system=SYSTEM_PROMPT_DB_ONLY if db_only else SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )

        raw = _extract_json(message.content[0].text.strip())

        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error(f"Claude JSON-Fehler: {e}\nRaw: {raw[:500]}")
            raise ValueError(f"Claude-Antwort ist kein valides JSON: {e}")

        recommendations = [
            await _parse_recommendation_item(item, profile.medications or [])
            for item in data.get("recommendations", [])
        ]

        result = RecommendationResponse(goal=goal, recommendations=recommendations)
        _cache_set(cache_key, result)
        return result

    async def get_goal_ranking(
        self, goal: str, db_only: bool = False, limit: int = 20,
    ) -> list[dict]:
        """Schlanke Grundrangliste (id/name/score) für ein Themenfeld — kein
        Nutzerprofil, keine Kartenfelder. Wird NUR vom Precompute-Skript
        aufgerufen (scripts/precompute_recommendations.py), nie zur Laufzeit."""
        logger.info(f"Ranking-Anfrage: Ziel='{goal}', db_only={db_only}, limit={limit}")

        db_context = "" if db_only else _build_db_context(medications=[], conditions=[])
        vector_context = vector_search(
            f"{goal} supplement", supplement_names=[], top_k=15 if db_only else 10,
        ) or ""

        user_message = _build_ranking_message(goal, db_context, vector_context, limit)

        message = await self.client.messages.create(
            model=settings.claude_model,
            max_tokens=2048,
            system=RANKING_SYSTEM_PROMPT_DB_ONLY if db_only else RANKING_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )

        raw = _extract_json(message.content[0].text.strip())
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error(f"Ranking-JSON-Fehler: {e}\nRaw: {raw[:500]}")
            raise ValueError(f"Claude-Antwort ist kein valides JSON: {e}")

        seen: set[str] = set()
        results = []
        for item in data.get("ranking", []):
            sid = item.get("id")
            if not sid or sid in seen:
                continue
            seen.add(sid)
            results.append({
                "id": sid,
                "name": item.get("name", sid),
                "base_relevance_score": max(0, min(100, int(item.get("relevance_score", 50)))),
            })
        results.sort(key=lambda r: r["base_relevance_score"], reverse=True)
        return results[:limit]

    async def resort_by_profile(
        self, ranked_items: list[dict], profile: UserProfile, db_only: bool = False,
    ) -> list[dict]:
        """Sortiert eine vorberechnete Rangliste anhand des Nutzerprofils um —
        OHNE die Grundauswahl zu verändern. Datenbank-Modus: rein rechnerisch
        anhand supplement_knowledge.json (kein LLM-Call). KI-Modus: Claude
        entscheidet anhand aller Profil-Fakten (siehe RESORT_SYSTEM_PROMPT)."""
        if not ranked_items:
            return []

        if db_only:
            adjusted = []
            for item in ranked_items:
                entry = _SUPPLEMENT_DB.get(item["id"])
                penalty = 0
                if entry:
                    for contra in entry.get("contraindications", []):
                        contra_lower = contra.lower()
                        for cond in profile.conditions or []:
                            if any(w in contra_lower for w in cond.lower().split() if len(w) > 3):
                                penalty = max(penalty, 45)
                        if profile.is_pregnant and any(
                            w in contra_lower for w in ("schwanger", "stillend", "pregnan")
                        ):
                            penalty = max(penalty, 45)
                    for interaction in entry.get("drug_interactions", []):
                        drug_lower = interaction.get("drug", "").lower()
                        for med in profile.medications or []:
                            if any(w in drug_lower for w in med.lower().split() if len(w) > 3):
                                sev = interaction.get("severity", "gering")
                                penalty = max(
                                    penalty,
                                    {"hoch": 50, "moderat": 30, "gering": 12}.get(sev, 12),
                                )
                adjusted.append({
                    **item,
                    "relevance_score": max(0, item["base_relevance_score"] - penalty),
                })
            adjusted.sort(key=lambda r: r["relevance_score"], reverse=True)
            return adjusted

        # KI-Modus: Claude entscheidet die Umsortierung anhand aller Profil-Fakten.
        try:
            user_message = _build_resort_message(ranked_items, profile)
            message = await self.client.messages.create(
                model=settings.claude_model,
                max_tokens=1024,
                system=RESORT_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_message}],
            )
            raw = _extract_json(message.content[0].text.strip())
            data = json.loads(raw)
            score_map = {
                r["id"]: max(0, min(100, int(r.get("relevance_score", 50))))
                for r in data.get("ranking", [])
            }
            adjusted = [
                {**item, "relevance_score": score_map.get(item["id"], item["base_relevance_score"])}
                for item in ranked_items
            ]
            adjusted.sort(key=lambda r: r["relevance_score"], reverse=True)
            return adjusted
        except Exception as e:
            logger.warning(f"Umsortierung fehlgeschlagen ({e}) — verwende Grundreihenfolge")
            return [
                {**item, "relevance_score": item["base_relevance_score"]}
                for item in ranked_items
            ]

    async def get_recommendations_from_precomputed(
        self, profile: UserProfile, goal: str, db_only: bool = False,
        limit: int = 4, offset: int = 0,
    ) -> RecommendationResponse:
        """Vorberechnungs-Modus: lädt die vorberechnete Rangliste, sortiert sie
        anhand des Profils um, und generiert nur für die angeforderte Seite die
        individuellen Kartenfelder frisch. dosage/intake_time/intake_hint und
        simple_explanation kommen direkt aus der Vorberechnung, nicht von Claude."""
        logger.info(
            f"Precomputed-Anfrage: Ziel='{goal}', offset={offset}, limit={limit}, db_only={db_only}"
        )

        ranking = get_precomputed_ranking(goal, db_only)
        if not ranking:
            raise ValueError(
                f"Keine vorberechneten Daten für '{goal}' (db_only={db_only}) gefunden — "
                "scripts/precompute_recommendations.py ausführen."
            )

        resorted = await self.resort_by_profile(ranking, profile, db_only)
        page = resorted[offset:offset + limit]
        if not page:
            return RecommendationResponse(goal=goal, recommendations=[])

        info_map = get_precomputed_supplement_info([item["id"] for item in page], db_only)

        db_context = "" if db_only else _build_db_context(medications=[], conditions=[])
        vector_context = vector_search(
            f"{goal} supplement", supplement_names=[item["id"] for item in page], top_k=12,
        ) or ""
        user_message = _build_fresh_fields_message(
            profile, goal, page, db_context, vector_context, db_only,
        )

        message = await self.client.messages.create(
            model=settings.claude_model,
            max_tokens=settings.claude_max_tokens,
            system=SYSTEM_PROMPT_DB_ONLY if db_only else SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )

        raw = _extract_json(message.content[0].text.strip())
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error(f"Precomputed-Fresh-Fields-JSON-Fehler: {e}\nRaw: {raw[:500]}")
            raise ValueError(f"Claude-Antwort ist kein valides JSON: {e}")

        recommendations = []
        for item in data.get("recommendations", []):
            supplement_id = item.get("id")
            precomputed = info_map.get(supplement_id, {})
            item["dosage"] = precomputed.get("dosage") or item.get("dosage") or "Siehe Herstellerangabe"
            item["intake_time"] = (
                precomputed.get("intake_time") or item.get("intake_time") or "Siehe Herstellerangabe"
            )
            item["intake_hint"] = precomputed.get("intake_hint") or item.get("intake_hint")
            rec = await _parse_recommendation_item(item, profile.medications or [])
            rec.simple_explanation = precomputed.get("simple_explanation")
            recommendations.append(rec)

        return RecommendationResponse(goal=goal, recommendations=recommendations)

    async def get_supplement_detail(
        self, supplement_id: str, supplement_name: str, db_only: bool = False,
    ) -> SupplementRecommendation:
        """Generiert GENAU EINE volle Karte für einen direkten Such-Treffer —
        kein Ziel, kein Nutzerprofil, respektiert aber den KI-/Datenbank-Modus."""
        logger.info(
            f"Supplement-Detailsuche: '{supplement_name}' (id={supplement_id}, db_only={db_only})"
        )

        cache_key = f"detail::{supplement_id}::{db_only}"
        cached = _cache_get(cache_key)
        if cached and cached.recommendations:
            return cached.recommendations[0]

        db_context = "" if db_only else _build_single_db_context(supplement_id)
        vector_context = vector_search(
            f"{supplement_name} supplement", supplement_names=[supplement_id], top_k=10,
        ) or ""

        user_message = _build_lookup_message(supplement_name, db_context, vector_context)

        message = await self.client.messages.create(
            model=settings.claude_model,
            max_tokens=settings.claude_max_tokens,
            system=SYSTEM_PROMPT_DB_ONLY if db_only else SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )

        raw = _extract_json(message.content[0].text.strip())
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error(f"Claude JSON-Fehler (Detailsuche): {e}\nRaw: {raw[:500]}")
            raise ValueError(f"Claude-Antwort ist kein valides JSON: {e}")

        items = data.get("recommendations", [])
        if not items:
            raise ValueError(f"Claude hat keine Karte für '{supplement_name}' erzeugt.")

        rec = await _parse_recommendation_item(items[0], [])
        _cache_set(cache_key, RecommendationResponse(goal=supplement_name, recommendations=[rec]))
        return rec

    async def check_duplicate_in_stack(
        self,
        new_supplement: "SupplementInfo",
        stack: "list[SupplementInfo]",
    ) -> dict:
        if not stack:
            return {"duplicates": [], "reasoning": "Stack ist leer."}

        def _fmt(e: dict) -> str:
            wirkstoffe = ", ".join(e.get("enthaltene_wirkstoffe", []))
            return (
                f"Name={e['name']} | Wirkstoff={e.get('substance_name', '-')} "
                f"| Enthält: {wirkstoffe or '-'}"
            )

        stack_lines = "\n".join(
            f"- ID={e['id']} | {_fmt(e)}" for e in stack
        )

        user_msg = (
            f"NEUES SUPPLEMENT:\n{_fmt(new_supplement)}\n\n"
            f"AKTUELLER STACK:\n{stack_lines}\n\n"
            "Welche Stack-Einträge enthalten denselben Wirkstoff wie das neue Supplement?"
        )

        message = await self.client.messages.create(
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

        message = await self.client.messages.create(
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

    async def get_simple_explanation(
        self, supplement_name: str, substance_name: str | None
    ) -> str:
        """Kurze Laienerklärung was ein Supplement ist — für "Einfach erklärt"."""
        name = f"{supplement_name} ({substance_name})" if substance_name else supplement_name
        logger.info(f"Einfach-erklärt für: {name}")

        message = await self.client.messages.create(
            model=settings.claude_model,
            max_tokens=400,
            system=EXPLAIN_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f"Supplement: {name}"}],
        )

        raw = _extract_json(message.content[0].text.strip())
        try:
            data = json.loads(raw)
            return data.get("explanation", "")
        except (json.JSONDecodeError, KeyError) as e:
            logger.error(f"Explain-JSON Fehler: {e}\nRaw: {raw}")
            return ""

    async def get_food_sources(
        self, supplement_name: str, substance_name: str | None
    ) -> list[dict]:
        name = f"{supplement_name} ({substance_name})" if substance_name else supplement_name
        logger.info(f"Food-Sources für: {name}")

        message = await self.client.messages.create(
            model=settings.claude_model,
            max_tokens=512,
            system=FOOD_SOURCES_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f"Supplement: {name}"}],
        )

        raw = _extract_json(message.content[0].text.strip())
        try:
            data = json.loads(raw)
            return data.get("sources", [])
        except (json.JSONDecodeError, KeyError) as e:
            logger.error(f"Food-Sources JSON Fehler: {e}\nRaw: {raw}")
            return []

    async def get_synergies(
        self, profile: UserProfile, goal: str,
    ) -> SynergyResponse:
        """
        Generiert Claude-basierte Synergie-Empfehlungen für ein Nutzerprofil + Ziel.
        Gibt 3–4 Wirkstoff-Kombinationen zurück die sich nachweislich gegenseitig verstärken.
        """
        season = _get_season()
        gender_map = {"male": "männlich", "female": "weiblich", "diverse": "divers"}
        sport_map = {
            "none": "kaum aktiv",
            "light": "leicht aktiv (1-2x/Woche)",
            "moderate": "moderat aktiv (3-4x/Woche)",
            "intense": "sehr aktiv (5+x/Woche)",
        }

        profile_lines = [
            f"Alter: {profile.age} Jahre",
            f"Geschlecht: {gender_map.get(profile.gender, profile.gender)}",
            f"Aktivität: {sport_map.get(profile.sport_level, profile.sport_level)}",
            f"Jahreszeit: {season}",
        ]
        if profile.conditions:
            profile_lines.append(f"Erkrankungen: {', '.join(profile.conditions)}")
        if profile.medications:
            profile_lines.append(f"Dauermedikamente: {', '.join(profile.medications)}")
        if profile.is_pregnant:
            profile_lines.append("Schwanger / stillend: ja")

        user_msg = (
            f"NUTZERPROFIL:\n" + "\n".join(f"- {l}" for l in profile_lines) +
            f"\n\nZIEL: {goal}\n\n"
            "Empfehle 3–4 Supplement-Synergien die für dieses Profil und Ziel besonders relevant sind."
        )

        logger.info(f"Synergy-Anfrage: Ziel='{goal}', Alter={profile.age}")

        synergies: list[SynergyRecommendation] = []
        try:
            message = await self.client.messages.create(
                model=settings.claude_model,
                max_tokens=1024,
                system=SYNERGY_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_msg}],
            )

            raw = _extract_json(message.content[0].text.strip())
            logger.debug(f"Synergy raw response: {raw[:300]}")
            data = json.loads(raw)
            for item in data.get("synergies", []):
                synergies.append(SynergyRecommendation(
                    id=item["id"],
                    substances=item["substances"],
                    evidence_level=EvidenceLevel(item["evidence_level"]),
                    synergy_score=max(0, min(100, int(item.get("synergy_score", 70)))),
                    synergy_explanation=item["synergy_explanation"],
                    dosage_hint=item.get("dosage_hint"),
                ))
            logger.info(f"Synergy Claude: {len(synergies)} Synergien für Ziel='{goal}'")
        except Exception as e:
            logger.warning(f"Synergy Claude-Call fehlgeschlagen ({e}) — verwende Fallback")

        # Fallback wenn Claude 0 Synergien liefert oder fehlschlägt
        if not synergies:
            logger.info(f"Synergy Fallback aktiv für Ziel='{goal}'")
            for item in _get_fallback_synergies(goal, n=3):
                synergies.append(SynergyRecommendation(
                    id=item["id"],
                    substances=item["substances"],
                    evidence_level=EvidenceLevel(item["evidence_level"]),
                    synergy_score=item["synergy_score"],
                    synergy_explanation=item["synergy_explanation"],
                    dosage_hint=item.get("dosage_hint"),
                ))

        return SynergyResponse(goal=goal, synergies=synergies)
