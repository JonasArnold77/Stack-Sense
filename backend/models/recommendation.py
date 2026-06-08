from pydantic import BaseModel
from typing import Optional
from enum import Enum


class EvidenceLevel(str, Enum):
    green = "green"
    yellow = "yellow"
    red = "red"


class ProductLink(BaseModel):
    """Eine einzelne Kaufoption für ein Supplement."""
    label: str       # z.B. "Melatonin 0,5mg (isoliert)"
    shop: str        # z.B. "Sunday Natural"
    url: str
    note: Optional[str] = None  # z.B. "Mit Vitamin B6"


class SupplementRecommendation(BaseModel):
    id: str                          # Eindeutiger Slug z.B. "vitamin-d3"
    name: str                        # Anzeigename z.B. "Vitamin D3"
    substance_name: Optional[str]    # Wirkstoffname z.B. "Cholecalciferol"
    evidence_level: EvidenceLevel
    evidence_reason: str             # Max ~120 Zeichen, HWG-konform
    dosage: str                      # z.B. "2.000–4.000 IE täglich"
    intake_time: str                 # z.B. "Morgens"
    intake_hint: Optional[str]       # z.B. "Mit fetthaltiger Mahlzeit"
    drug_interaction: Optional[str]  # Wechselwirkungshinweis falls relevant
    simple_explanation: Optional[str] = None
    product_links: list[ProductLink] = []   # Mehrere Kaufoptionen
    categories: list[str] = []             # Problemfelder z.B. ["Schlaf", "Stressabbau"]


class RecommendationResponse(BaseModel):
    goal: str
    recommendations: list[SupplementRecommendation]
    disclaimer: str = (
        "Diese Informationen ersetzen keine medizinische Beratung. "
        "Bitte sprich mit einem Arzt oder Apotheker."
    )
