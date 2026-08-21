from pydantic import BaseModel
from typing import Optional
from enum import Enum


class EvidenceLevel(str, Enum):
    green = "green"
    yellow = "yellow"
    red = "red"


class InteractionSeverity(str, Enum):
    none = "none"         # Keine Wechselwirkung
    timing = "timing"     # Zeitabstand ausreichend → gelbes Feld
    moderate = "moderate" # Arzt-Rücksprache empfohlen → oranges Feld
    high = "high"         # Starke bekannte Wechselwirkung → rotes Feld


class SupplementType(str, Enum):
    single = "single"   # Einzelner Wirkstoff (z.B. Magnesium Bisglycinat)
    group = "group"     # Kombipräparat (z.B. Vitamin B-Komplex)


class SubstanceCategory(str, Enum):
    """Stoffklasse des Supplements — für das Kategorie-Symbol auf der Card.
    Unabhängig von `categories` (zielbezogene Tags wie "Schlaf", "Energie")."""
    vitamine = "Vitamine"
    mineralstoffe = "Mineralstoffe"
    omega_fettsaeuren = "Omega & Fettsäuren"
    aminosaeuren_protein = "Aminosäuren & Protein"
    pflanzliche_extrakte = "Pflanzliche Extrakte"
    darm_verdauung = "Darm & Verdauung"


class ProductLink(BaseModel):
    label: str
    shop: str
    url: str
    note: Optional[str] = None


class SecondaryBenefit(BaseModel):
    """Profilrelevanter Zusatznutzen — nicht durch das aktuelle Ziel getrieben,
    sondern durch Erkrankungen / Zustände im Nutzerprofil."""
    text: str
    evidence_level: EvidenceLevel
    condition: str  # Die Erkrankung / der Kontext aus dem Profil


class SupplementRecommendation(BaseModel):
    id: str
    name: str
    substance_name: Optional[str]
    evidence_level: EvidenceLevel
    substance_category: Optional[SubstanceCategory] = None  # Stoffklasse fürs Karten-Symbol
    pitch: str = ""              # Kurzer Nutzen-Text für die Card (1 Satz, persönlich, kein Werbejargon)
    evidence_reason: str
    secondary_benefit: Optional[SecondaryBenefit] = None
    dosage: str
    intake_time: str
    intake_hint: Optional[str]
    drug_interaction: Optional[str]
    interaction_severity: InteractionSeverity = InteractionSeverity.none
    simple_explanation: Optional[str] = None
    product_links: list[ProductLink] = []
    categories: list[str] = []
    supplement_type: SupplementType = SupplementType.single
    enthaltene_wirkstoffe: list[str] = []  # Nur für Kombipräparate befüllt
    food_coverage_score: int = 5           # 1–10: wie gut durch Ernährung abdeckbar
    relevance_score: int = 75              # 0–100: Passgenauigkeit für aktuelles Ziel/Kontext


class RecommendationResponse(BaseModel):
    goal: str
    recommendations: list[SupplementRecommendation]
    disclaimer: str = (
        "Diese Informationen ersetzen keine medizinische Beratung. "
        "Bitte sprich mit einem Arzt oder Apotheker."
    )


class SynergyRecommendation(BaseModel):
    """Eine Synergie zwischen zwei oder mehr Wirkstoffen."""
    id: str                          # z.B. "magnesium-b6"
    substances: list[str]            # z.B. ["Magnesium Bisglycinat", "Vitamin B6"]
    evidence_level: EvidenceLevel    # Grün/Gelb/Rot für die Synergie selbst
    synergy_score: int               # 0–100: Passgenauigkeit für aktuelles Ziel
    synergy_explanation: str         # Warum diese Kombination wirkt (2–3 Sätze)
    dosage_hint: Optional[str] = None  # Kombinierter Einnahmehinweis


class SynergyResponse(BaseModel):
    goal: str
    synergies: list[SynergyRecommendation]
