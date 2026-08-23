"""
Einmaliges Hilfsskript: Für die ~76 Supplements ohne echte Datenbank-Abdeckung
(kein DSLD/NIH-ODS/EFSA-Fakt) erzeugt dieses Skript eine Zuordnung:

- "alias": Der Slug bezeichnet denselben Wirkstoff wie ein bereits abgedecktes
  Supplement (z.B. "zink-immun" -> "zink"), nur kontext-/ziel-gebrandet.
  populate_dsld.py kopiert dann dessen vorhandene Fakten statt neu zu suchen.
- "translate": Eigenständiger Wirkstoff, aber der deutsche Name ist für die
  DSLD-Volltextsuche ungeeignet (z.B. "Mangan" statt "Manganese"). Enthält
  den englischen/wissenschaftlichen Suchbegriff für DSLD.

Ergebnis wird nach data/dsld_alias_map.json geschrieben.

Ausführen (aus dem backend/ Ordner):
    python scripts/generate_dsld_alias_map.py
"""
import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import anthropic
from config.settings import settings

SYSTEM_PROMPT = """Du bekommst zwei Listen von Nahrungsergänzungsmitteln aus einer deutschen App:
1. "alle" — alle Supplements der App (slug, Name)
2. "luecken" — die Teilmenge davon, die noch keine echte Datenbank-Abdeckung hat
   (kein Fakt aus NIH DSLD, NIH ODS oder EFSA)

Für JEDEN Eintrag aus "luecken" entscheide:

a) ALIAS: Bezeichnet der Slug denselben Wirkstoff wie ein ANDERER Slug aus "alle",
   der NICHT selbst in "luecken" steht (also vermutlich schon abgedeckt ist) —
   nur kontext-/ziel-gebrandet (z.B. "zink-immun" ist einfach Zink, "arginin-herz"
   ist einfach L-Arginin)? Dann gib {"type": "alias", "base_slug": "<slug aus alle>"}.
   Der base_slug MUSS ein existierender Slug aus "alle" sein und NICHT in "luecken"
   vorkommen — sonst wäre nichts gewonnen.

b) TRANSLATE: Eigenständiger Wirkstoff ohne Alias-Basis. Gib den besten englischen
   ODER wissenschaftlichen Suchbegriff für die NIH DSLD-Produktdatenbank (US-Regierung,
   Volltextsuche über Produktnamen/Zutaten, englischsprachig) zurück:
   {"type": "translate", "query": "<englischer/wissenschaftlicher Begriff>"}.
   Beispiel: "Mangan" -> "Manganese", "Apfelpektin" -> "Apple Pectin",
   "Baldrian Valeriana" -> "Valerian Root", "Glutathion" -> "Glutathione".

Antworte NUR mit validem JSON: {"<slug>": {...}, ...} für jeden Slug aus "luecken".
Kein zusätzlicher Text, keine Markdown-Codeblöcke."""


async def main():
    all_supps = json.loads(Path("../scratch_supplements_all.json").read_text(encoding="utf-8"))
    gap_slugs = json.loads(Path("../scratch_gaps.json").read_text(encoding="utf-8"))
    gap_set = set(gap_slugs)
    all_map = {slug: name for slug, name in all_supps}

    user_message = json.dumps({
        "alle": [{"slug": s, "name": n} for s, n in all_supps],
        "luecken": [{"slug": s, "name": all_map[s]} for s in gap_slugs],
    }, ensure_ascii=False)

    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
    message = await client.messages.create(
        model=settings.claude_model,
        max_tokens=8000,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    )
    raw = message.content[0].text.strip()
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    mapping = json.loads(raw.strip())

    # Validierung: alle Lücken-Slugs abgedeckt, alias-Basen existieren und sind nicht selbst Lücken
    missing = gap_set - set(mapping.keys())
    if missing:
        print(f"WARNUNG: {len(missing)} Slugs fehlen in der Antwort: {missing}")

    bad_aliases = []
    for slug, entry in mapping.items():
        if entry.get("type") == "alias":
            base = entry.get("base_slug")
            if base not in all_map or base in gap_set:
                bad_aliases.append((slug, base))

    if bad_aliases:
        print(f"WARNUNG: {len(bad_aliases)} ungültige Alias-Zuordnungen (Basis existiert nicht oder ist selbst Lücke): {bad_aliases}")

    out_path = Path("data/dsld_alias_map.json")
    out_path.write_text(json.dumps(mapping, ensure_ascii=False, indent=2), encoding="utf-8")

    n_alias = sum(1 for e in mapping.values() if e.get("type") == "alias")
    n_translate = sum(1 for e in mapping.values() if e.get("type") == "translate")
    print(f"Fertig: {n_alias} Alias-Zuordnungen, {n_translate} Übersetzungen -> {out_path}")


if __name__ == "__main__":
    asyncio.run(main())
