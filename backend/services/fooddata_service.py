"""
FoodData Service — Lebensmittel-Nährwerte über USDA FoodData Central (FDC).
Kostenlose öffentliche API, Key: https://fdc.nal.usda.gov/api-key-signup.html

Liefert pro Zutat einen Dict nutrient_key -> Menge pro 100g, gecacht in Postgres
(fdc_ingredient_cache), damit nicht bei jeder Rezeptgenerierung erneut live
nachgefragt werden muss.
"""
import json
import logging

import httpx

from config.settings import settings
from database.db import get_conn

logger = logging.getLogger(__name__)

FDC_BASE = "https://api.nal.usda.gov/fdc/v1"

# Bevorzugte Datenquellen für generische Zutaten (Rohkost/Standardrezepte) vor
# Markenprodukten, die stark je nach Hersteller variieren.
_PREFERRED_DATA_TYPES = ["Foundation", "SR Legacy", "Survey (FNDDS)", "Branded"]

# FDC-Nährstoff-IDs (nutrient.id in der API-Antwort) -> kanonischer nutrient_key,
# der auch in supplement_nutrients verwendet wird. Analog zu GOAL_CATEGORY_MAP
# in claude_service.py — eine kleine, bewusst begrenzte Vokabelliste.
FDC_NUTRIENT_ID_TO_KEY: dict[int, str] = {
    1114: "vitamin_d",     # Vitamin D (D2 + D3), IU
    1109: "vitamin_e",     # Vitamin E (alpha-tocopherol), mg
    1185: "vitamin_k",     # Vitamin K (phylloquinone), mcg
    1162: "vitamin_c",     # Vitamin C, total ascorbic acid, mg
    1106: "vitamin_a",     # Vitamin A, RAE, mcg
    1178: "vitamin_b12",   # Vitamin B-12, mcg
    1177: "folate",        # Folate, total, mcg
    1090: "magnesium",     # Magnesium, mg
    1095: "zinc",          # Zinc, mg
    1089: "iron",          # Iron, mg
    1087: "calcium",       # Calcium, mg
    1092: "potassium",     # Potassium, mg
    1103: "selenium",      # Selenium, mcg
    1100: "iodine",        # Iodine, mcg — selten in FDC-Daten vorhanden
    1404: "omega_3",       # 18:3 n-3 (ALA, pflanzlich)
    1278: "omega_3",       # 20:5 n-3 (EPA, marin) — summiert mit ALA/DHA zu "omega_3"
    1272: "omega_3",       # 22:6 n-3 (DHA, marin)
    1003: "protein",       # Protein, g
    1079: "fiber",         # Fiber, total dietary, g
    1093: "sodium",        # Sodium, mg
    1175: "vitamin_b6",    # Vitamin B-6, mg
    1176: "biotin",        # Biotin, mcg
    1096: "chromium",      # Chromium — selten in FDC-Daten vorhanden
    1101: "manganese",     # Manganese, mg
    1338: "lutein_zeaxanthin",  # Lutein + zeaxanthin, mcg
    1122: "lycopene",      # Lycopene, mcg
}


def _normalize(name: str) -> str:
    return " ".join(name.strip().lower().split())


def _cache_get(query_norm: str) -> dict | None:
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT nutrients_json, source FROM fdc_ingredient_cache WHERE query_norm = %s",
                    (query_norm,),
                )
                row = cur.fetchone()
                if row is None:
                    return None
                nutrients_json, source = row
                return {} if source == "unmatched" else dict(nutrients_json)
    except Exception as e:
        logger.warning("FDC-Cache-Lookup fehlgeschlagen für '%s': %s", query_norm, e)
        return None


def _cache_put(query_norm: str, fdc_id: int | None, description: str | None,
               nutrients: dict, source: str) -> None:
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO fdc_ingredient_cache
                        (query_norm, fdc_id, fdc_description, nutrients_json, source)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (query_norm) DO UPDATE SET
                        fdc_id = EXCLUDED.fdc_id,
                        fdc_description = EXCLUDED.fdc_description,
                        nutrients_json = EXCLUDED.nutrients_json,
                        source = EXCLUDED.source,
                        fetched_at = NOW()
                    """,
                    (query_norm, fdc_id, description, json.dumps(nutrients), source),
                )
    except Exception as e:
        logger.warning("FDC-Cache-Schreiben fehlgeschlagen für '%s': %s", query_norm, e)


class FoodDataService:
    def __init__(self, api_key: str | None = None):
        self.api_key = api_key or settings.fdc_api_key
        self._client = httpx.AsyncClient(timeout=15.0)

    async def search_food(self, query: str) -> dict | None:
        """Sucht FDC nach `query`, gibt den am besten passenden Treffer zurück."""
        if not self.api_key:
            logger.warning("Kein FDC-API-Key konfiguriert — Lebensmittel-Lookup übersprungen.")
            return None
        try:
            resp = await self._client.get(
                f"{FDC_BASE}/foods/search",
                params={"api_key": self.api_key, "query": query, "pageSize": 10},
            )
            resp.raise_for_status()
            foods = resp.json().get("foods", [])
            if not foods:
                return None
            foods.sort(
                key=lambda f: _PREFERRED_DATA_TYPES.index(f.get("dataType", "Branded"))
                if f.get("dataType") in _PREFERRED_DATA_TYPES else len(_PREFERRED_DATA_TYPES)
            )
            return foods[0]
        except Exception as e:
            logger.warning("FDC-Suche fehlgeschlagen für '%s': %s", query, e)
            return None

    async def get_nutrients_per_100g(self, fdc_id: int) -> dict[str, float]:
        """Holt die vollen Nährwertdaten eines FDC-Lebensmittels, normalisiert auf 100g."""
        try:
            resp = await self._client.get(
                f"{FDC_BASE}/food/{fdc_id}",
                params={"api_key": self.api_key},
            )
            resp.raise_for_status()
            data = resp.json()
            result: dict[str, float] = {}
            for entry in data.get("foodNutrients", []):
                nutrient = entry.get("nutrient", {})
                nutrient_id = nutrient.get("id")
                key = FDC_NUTRIENT_ID_TO_KEY.get(nutrient_id)
                if key is None:
                    continue
                amount = entry.get("amount")
                if amount is None:
                    continue
                # FDC liefert Werte bereits pro 100g für Foundation/SR-Legacy-Einträge.
                result[key] = result.get(key, 0.0) + float(amount)
            return result
        except Exception as e:
            logger.warning("FDC-Nährwertabfrage fehlgeschlagen für FDC-ID %s: %s", fdc_id, e)
            return {}

    async def lookup_ingredient(self, name: str) -> dict[str, float]:
        """
        Öffentlicher Einstiegspunkt: Cache zuerst, sonst Live-Lookup + Cache-Schreiben.
        Gibt bei Fehltreffer ein leeres Dict zurück statt zu werfen — Rezeptgenerierung
        soll bei unbekannten Zutaten degradieren, nicht abbrechen.
        """
        query_norm = _normalize(name)
        cached = _cache_get(query_norm)
        if cached is not None:
            return cached

        food = await self.search_food(name)
        if food is None:
            _cache_put(query_norm, None, None, {}, source="unmatched")
            return {}

        fdc_id = food.get("fdcId")
        nutrients = await self.get_nutrients_per_100g(fdc_id)
        _cache_put(query_norm, fdc_id, food.get("description"), nutrients, source="fdc")
        return nutrients

    async def aclose(self) -> None:
        await self._client.aclose()


fooddata_service = FoodDataService()
