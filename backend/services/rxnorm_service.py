"""
RxNorm Service — normalisiert Medikamentennamen über die RxNav REST API
(NLM RxNorm), um Wechselwirkungs-Matching robuster gegen Schreibvarianten
und Marken-/Wirkstoffname-Unterschiede zu machen.

WICHTIG — Abdeckungs-Limitation: RxNorm ist primär auf den US-Markt
ausgelegt. Internationale Wirkstoffnamen (INN) und viele US-Markennamen
werden zuverlässig erkannt, spezifisch deutsche Markennamen (z.B.
"Marcumar", "Falithrom") dagegen oft NICHT. Das Matching hier ist daher
ein zusätzlicher Fallback, kein Ersatz für die bestehende Freitext-Suche
in claude_service.py — beide werden kombiniert.

Kostenlos, kein API-Key nötig: https://rxnav.nlm.nih.gov/REST/
"""
import logging
import httpx

logger = logging.getLogger(__name__)

RXNAV_BASE = "https://rxnav.nlm.nih.gov/REST"

# Einfacher In-Memory-Cache — Medikamentennamen wiederholen sich stark
# über Nutzer hinweg (z.B. "Marcumar", "Metformin", "Ibuprofen").
_cache: dict[str, list[str]] = {}


class RxNormService:
    def __init__(self, timeout: float = 3.0):
        self._client = httpx.AsyncClient(timeout=timeout)

    async def resolve_ingredient_names(self, drug_name: str) -> list[str]:
        """
        Löst einen (ggf. ungenauen/Marken-)Medikamentennamen zu seinen
        RxNorm-Wirkstoffnamen (Ingredient/IN) auf.

        Gibt eine Liste von Wirkstoffnamen zurück (kann leer sein, wenn
        RxNorm den Namen nicht kennt — z.B. bei rein deutschen Marken).
        Fehler werden nie geworfen (graceful degradation), nur geloggt.
        """
        key = drug_name.strip().lower()
        if not key:
            return []
        if key in _cache:
            return _cache[key]

        try:
            rxcui = await self._find_rxcui(drug_name)
            if not rxcui:
                _cache[key] = []
                return []

            names = await self._related_ingredient_names(rxcui)
            if not names:
                # Konzept war evtl. schon selbst ein Wirkstoff (Ingredient)
                own_name = await self._concept_name(rxcui)
                names = [own_name] if own_name else []

            _cache[key] = names
            return names
        except Exception as e:
            logger.warning(f"RxNorm-Auflösung fehlgeschlagen für '{drug_name}': {e}")
            _cache[key] = []
            return []

    async def _find_rxcui(self, drug_name: str) -> str | None:
        # 1. Exakte Übereinstimmung
        resp = await self._client.get(f"{RXNAV_BASE}/rxcui.json", params={"name": drug_name})
        resp.raise_for_status()
        ids = resp.json().get("idGroup", {}).get("rxnormId") or []
        if ids:
            return ids[0]

        # 2. Fallback: ungefähre Übereinstimmung (Tippfehler, Teilnamen)
        resp = await self._client.get(
            f"{RXNAV_BASE}/approximateTerm.json",
            params={"term": drug_name, "maxEntries": 1},
        )
        resp.raise_for_status()
        candidates = resp.json().get("approximateGroup", {}).get("candidate") or []
        if candidates and candidates[0].get("rxcui"):
            return candidates[0]["rxcui"]

        return None

    async def _related_ingredient_names(self, rxcui: str) -> list[str]:
        resp = await self._client.get(
            f"{RXNAV_BASE}/rxcui/{rxcui}/related.json", params={"tty": "IN"}
        )
        resp.raise_for_status()
        groups = resp.json().get("relatedGroup", {}).get("conceptGroup") or []
        names = []
        for group in groups:
            for concept in group.get("conceptProperties") or []:
                if concept.get("name"):
                    names.append(concept["name"])
        return names

    async def _concept_name(self, rxcui: str) -> str | None:
        resp = await self._client.get(f"{RXNAV_BASE}/rxcui/{rxcui}/property.json", params={"propName": "RxNorm Name"})
        resp.raise_for_status()
        props = resp.json().get("propConceptGroup", {}).get("propConcept") or []
        return props[0]["propValue"] if props else None

    async def close(self):
        await self._client.aclose()
