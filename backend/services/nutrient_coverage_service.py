"""
Nutrient Coverage Service — deterministische Berechnung, kein Claude-Aufruf.

compute_recipe_nutrients(): summiert die Nährstoffe eines Rezepts aus den
FoodData-Central-Lookups seiner Zutaten (fooddata_service).

compute_stack_coverage(): gleicht diese Nährstoffe gegen den aktuellen Stack
des Nutzers ab (supplement_nutrients-Referenztabelle) und berechnet, zu
wieviel Prozent das Rezept jeden gematchten Stack-Eintrag abdeckt.

Wird sowohl bei der Rezeptgenerierung (Nährstoff-Übersicht pro Karte) als
auch beim "Für heute aktivieren"-Flow verwendet (dort mit frisch geladenem
aktuellem Stack, nicht mit einem beim Speichern zwischengespeicherten Stand).
"""
import logging

from pydantic import BaseModel

from database.db import get_conn
from services.fooddata_service import fooddata_service

logger = logging.getLogger(__name__)

# Rezeptmengen werden ausschließlich in Gramm/Milliliter erwartet (Claude-Prompt-
# Regel in recipe_service.py) — beide werden 1:1 wie Gramm behandelt, da FDCs
# Nährwerte pro 100g vorliegen und eine Dichte-Umrechnung ml->g hier nicht nötig ist.
_SUPPORTED_UNITS = {"g", "ml"}

# Unterhalb dieser Schwelle wird eine Abdeckung als Rauschen ignoriert, damit
# der Aktivierungs-Dialog nicht mit trivialen 2%-Überschneidungen überflutet wird.
_MIN_COVERAGE_PCT = 15.0


class CoveredSupplement(BaseModel):
    stack_entry_id: str
    stack_entry_name: str
    nutrient_key: str
    coverage_pct: float
    recipe_amount: float
    stack_dose_amount: float
    unit: str


def _slugify(name: str) -> str:
    return name.lower().strip().replace(" ", "-").replace("_", "-")


async def compute_recipe_nutrients(ingredients: list[dict]) -> dict[str, float]:
    """
    ingredients: [{"name": str, "amount": float, "unit": "g"|"ml"}, ...]
    Gibt nutrient_key -> Gesamtmenge für das gesamte Rezept zurück.
    """
    totals: dict[str, float] = {}
    for ingredient in ingredients:
        unit = ingredient.get("unit", "g")
        if unit not in _SUPPORTED_UNITS:
            logger.warning("Unbekannte Zutateneinheit '%s' für '%s' — überspringe.",
                            unit, ingredient.get("name"))
            continue
        per_100g = await fooddata_service.lookup_ingredient(ingredient["name"])
        if not per_100g:
            continue
        factor = float(ingredient.get("amount", 0)) / 100.0
        for nutrient_key, amount_per_100g in per_100g.items():
            totals[nutrient_key] = totals.get(nutrient_key, 0.0) + amount_per_100g * factor
    return totals


def _fetch_nutrient_rows(slugs: set[str]) -> dict[str, list[dict]]:
    """supplement_slug -> Liste von {nutrient_key, amount, unit} aus supplement_nutrients."""
    if not slugs:
        return {}
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT supplement_slug, nutrient_key, amount, unit "
                    "FROM supplement_nutrients WHERE supplement_slug = ANY(%s)",
                    (list(slugs),),
                )
                rows: dict[str, list[dict]] = {}
                for slug, nutrient_key, amount, unit in cur.fetchall():
                    rows.setdefault(slug, []).append(
                        {"nutrient_key": nutrient_key, "amount": float(amount), "unit": unit}
                    )
                return rows
    except Exception as e:
        logger.warning("supplement_nutrients-Lookup fehlgeschlagen: %s", e)
        return {}


def _candidate_slugs(entry: dict) -> list[str]:
    """
    Kandidaten-Slugs für einen Stack-Eintrag, in Prioritätsreihenfolge:
    substance_name zuerst (pharmakologische Identität), dann name, dann bei
    Kombipräparaten jeder Wirkstoff aus enthaltene_wirkstoffe einzeln.
    """
    candidates = []
    if entry.get("substance_name"):
        candidates.append(_slugify(entry["substance_name"]))
    if entry.get("name"):
        candidates.append(_slugify(entry["name"]))
    for wirkstoff in entry.get("enthaltene_wirkstoffe") or []:
        candidates.append(_slugify(wirkstoff))
    return candidates


def compute_stack_coverage(
    recipe_nutrients: dict[str, float],
    stack: list[dict],
) -> list[CoveredSupplement]:
    """
    stack: [{"id", "name", "substance_name", "enthaltene_wirkstoffe": [...],
             "dosage_amount": float|None, "dosage_unit": str|None}, ...]

    Als Ziel-Dosis pro Nährstoff wird bevorzugt die eigene strukturierte Dosis
    des Stack-Eintrags (dosage_amount/dosage_unit) verwendet, sofern die
    Einheit zur supplement_nutrients-Zeile passt — sonst der kuratierte
    Referenzwert aus supplement_nutrients. So bekommen auch die meisten
    (noch) unstrukturierten Freitext-Einträge eine sinnvolle Abdeckungs-
    Schätzung über die generische Referenzdosis, nicht nur brandneue
    Empfehlungen mit eigener dosage_amount.

    Nicht zuordenbare Einträge (kein Treffer in supplement_nutrients) liefern
    schlicht keine Abdeckungs-Kandidatur — kein Fehler, keine Warnung an den
    Nutzer (siehe Plan Abschnitt A5).
    """
    all_candidate_slugs: set[str] = set()
    entry_candidates: dict[str, list[str]] = {}
    for entry in stack:
        candidates = _candidate_slugs(entry)
        entry_candidates[entry["id"]] = candidates
        all_candidate_slugs.update(candidates)

    nutrient_rows_by_slug = _fetch_nutrient_rows(all_candidate_slugs)

    results: list[CoveredSupplement] = []
    for entry in stack:
        matched_rows: list[dict] = []
        for slug in entry_candidates[entry["id"]]:
            if slug in nutrient_rows_by_slug:
                matched_rows.extend(nutrient_rows_by_slug[slug])
                break  # erster Treffer in Prioritätsreihenfolge gewinnt

        own_amount = entry.get("dosage_amount")
        own_unit = entry.get("dosage_unit")

        for row in matched_rows:
            recipe_amount = recipe_nutrients.get(row["nutrient_key"], 0.0)
            if recipe_amount <= 0:
                continue

            if own_amount and own_amount > 0 and own_unit == row["unit"]:
                target_dose = own_amount
            else:
                target_dose = row["amount"]

            coverage_pct = min(100.0, recipe_amount / target_dose * 100.0)
            if coverage_pct < _MIN_COVERAGE_PCT:
                continue
            results.append(CoveredSupplement(
                stack_entry_id=entry["id"],
                stack_entry_name=entry["name"],
                nutrient_key=row["nutrient_key"],
                coverage_pct=round(coverage_pct, 1),
                recipe_amount=round(recipe_amount, 2),
                stack_dose_amount=target_dose,
                unit=row["unit"],
            ))

    return results
