"""
Europe PMC Service — fragt die Europe PMC REST API nach Studien.
Ergänzt PubMedService: Europe PMC deckt zusätzlich PMC-Preprints, einige
Nicht-PubMed-Quellen ab und liefert bei Open-Access-Artikeln oft den
vollen Abstract-Text zuverlässiger als NCBI E-utilities.
Kostenlos, kein API-Key nötig.
"""
import logging
import httpx

logger = logging.getLogger(__name__)

EPMC_BASE = "https://www.ebi.ac.uk/europepmc/webservices/rest"


class EuropePMCService:
    def __init__(self):
        self._client = httpx.AsyncClient(timeout=15.0)

    async def search_abstracts(
        self,
        query: str,
        max_results: int = 5,
        min_year: int = 2018,
    ) -> list[dict]:
        """
        Sucht Europe PMC nach `query` und gibt Abstracts zurück.
        Gibt eine Liste von Dicts zurück: {pmid, title, abstract, year, is_open_access}
        """
        try:
            # SRC:MED beschränkt auf MEDLINE-indexierte (biomedizinische) Literatur —
            # sonst driftet Europe PMC in fachfremde Treffer ab (Agrarwissenschaft,
            # Chemie etc.), da es eine viel breitere Quellenbasis als PubMed indexiert.
            params = {
                "query": f"({query}) AND SRC:MED",
                "format": "json",
                "resultType": "core",
                "pageSize": max_results,
            }
            resp = await self._client.get(f"{EPMC_BASE}/search", params=params)
            resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            logger.warning(f"Europe PMC-Fehler für '{query}': {e}")
            return []

        results = []
        for item in data.get("resultList", {}).get("result", []):
            try:
                year = int(item.get("pubYear") or 0)
            except (TypeError, ValueError):
                year = 0
            if year and year < min_year:
                continue

            abstract = item.get("abstractText") or ""
            if abstract and len(abstract) > 600:
                abstract = abstract[:600] + "…"

            title = item.get("title") or ""
            if not title and not abstract:
                continue

            results.append({
                "pmid": item.get("pmid") or item.get("id") or "unknown",
                "title": title,
                "abstract": abstract,
                "year": str(item.get("pubYear") or ""),
                "is_open_access": item.get("isOpenAccess") == "Y",
            })

        return results

    async def close(self):
        await self._client.aclose()
