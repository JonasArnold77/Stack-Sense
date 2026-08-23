from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum


class Gender(str, Enum):
    male = "male"
    female = "female"
    diverse = "diverse"


class SportLevel(str, Enum):
    none = "none"
    light = "light"
    moderate = "moderate"
    intense = "intense"


class UserProfile(BaseModel):
    age: int = Field(..., ge=16, le=100)
    gender: Gender
    sport_level: SportLevel
    conditions: list[str] = []       # z.B. ["Hashimoto", "Bluthochdruck"]
    medications: list[str] = []      # z.B. ["Levothyroxin"]
    goals: list[str] = []            # z.B. ["Mehr Energie", "Besserer Schlaf"]
    is_pregnant: bool = False
    season: Optional[str] = None     # Wird vom Server automatisch gesetzt


class RecommendationRequest(BaseModel):
    profile: UserProfile
    goal: str = Field(..., description="Aktuell ausgewähltes Ziel/Problemfeld")
    limit: int = Field(default=5, ge=1, le=20, description="Anzahl Supplements pro Seite")
    exclude_ids: list[str] = Field(default=[], description="Bereits gezeigte Supplement-IDs")
    db_only: bool = Field(
        default=False,
        description=(
            "Datenbank-Modus: Claude nutzt ausschließlich Rohdaten aus der Vektor-DB "
            "(PubMed/Europe PMC/EFSA/NIH ODS/openFDA/DSLD) statt der kuratierten "
            "LLM-synthetisierten Datenbank oder Trainingswissen — kein Nutzerprofil."
        ),
    )
    bypass_cache: bool = Field(
        default=False,
        description="Testmodus: 6h-In-Memory-Cache ignorieren, immer frisch generieren.",
    )
