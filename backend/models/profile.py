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
