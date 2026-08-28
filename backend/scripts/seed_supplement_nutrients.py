"""
Lädt die kuratierten Nährstoff-Referenzwerte aus
data/supplement_nutrients_seed.json idempotent in die supplement_nutrients-
Tabelle (Rezept-Feature, Nährstoffabdeckungs-Berechnung).

Manuell ausführen (aus dem backend/ Ordner), einmalig oder nach Änderungen an
der Seed-Datei:

    python scripts/seed_supplement_nutrients.py
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from database.db import get_conn, init_recipe_tables  # noqa: E402

SEED_FILE = Path(__file__).resolve().parent.parent / "data" / "supplement_nutrients_seed.json"


def main() -> None:
    init_recipe_tables()

    data = json.loads(SEED_FILE.read_text(encoding="utf-8"))
    entries = data["entries"]

    with get_conn() as conn:
        with conn.cursor() as cur:
            for entry in entries:
                cur.execute(
                    """
                    INSERT INTO supplement_nutrients
                        (supplement_slug, nutrient_key, amount, unit, source_note)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (supplement_slug, nutrient_key) DO UPDATE SET
                        amount = EXCLUDED.amount,
                        unit = EXCLUDED.unit,
                        source_note = EXCLUDED.source_note
                    """,
                    (
                        entry["supplement_slug"],
                        entry["nutrient_key"],
                        entry["amount"],
                        entry["unit"],
                        entry.get("source_note"),
                    ),
                )

    print(f"{len(entries)} Nährstoff-Referenzzeilen geladen/aktualisiert.")


if __name__ == "__main__":
    main()
