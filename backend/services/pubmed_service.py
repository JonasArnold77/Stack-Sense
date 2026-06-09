"""
PubMed Service — fragt NCBI E-utilities API nach aktuellen Studien.
Kostenlos, kein API-Key für geringe Nutzung nötig (< 3 Req/s).
Mit API-Key: bis zu 10 Req/s möglich.
"""
import asyncio
import logging
import httpx
from xml.etree import ElementTree

logger = logging.getLogger(__name__)

NCBI_BASE = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
# Optional: NCBI_API_KEY in settings eintragen für höheres Rate-Limit
NCBI_TOOL = "StackSense"
NCBI_EMAIL = "contact@stacksense.app"


class PubMedService:
    def __init__(self, api_key: str | None = None):
        self.api_key = api_key
        self._client = httpx.AsyncClient(timeout=15.0)

    def _base_params(self) -> dict:
        params = {"tool": NCBI_TOOL, "email": NCBI_EMAIL}
        if self.api_key:
            params["api_key"] = self.api_key
        return params

    async def search_abstracts(
        self,
        query: str,
        max_results: int = 5,
        min_year: int = 2018,
    ) -> list[dict]:
        """
        Sucht PubMed nach `query` und gibt Abstracts zurück.
        Gibt eine Liste von Dicts zurück: {pmid, title, abstract, year}
        """
        try:
            pmids = await self._esearch(query, max_results, min_year)
            if not pmids:
                return []
            abstracts = await self._efetch(pmids)
            return abstracts
        except Exception as e:
            logger.warning(f"PubMed-Fehler für '{query}': {e}")
            return []

    async def get_supplement_evidence(
        self,
        supplement_name: str,
        goal: str,
        max_results: int = 4,
    ) -> list[dict]:
        """
        Holt Studien speziell für ein Supplement + Ziel-Kombination.
        z.B. supplement_name="Magnesium", goal="Schlaf"
        """
        query = f"{supplement_name} supplementation {goal} randomized controlled trial"
        return await self.search_abstracts(query, max_results=max_results)

    async def get_goal_evidence(
        self,
        goal: str,
        max_results: int = 6,
    ) -> list[dict]:
        """
        Holt allgemeine Studienlage für ein Ziel/Problem.
        z.B. goal="Schlafprobleme"
        """
        query = f"dietary supplement {goal} randomized controlled trial meta-analysis"
        return await self.search_abstracts(query, max_results=max_results)

    # --- Interne NCBI-Methoden ---

    async def _esearch(
        self, query: str, max_results: int, min_year: int
    ) -> list[str]:
        """Sucht PMIDs zu einem Query-String."""
        params = {
            **self._base_params(),
            "db": "pubmed",
            "term": f"{query} AND {min_year}:3000[pdat]",
            "retmax": max_results,
            "retmode": "json",
            "sort": "relevance",
        }
        resp = await self._client.get(f"{NCBI_BASE}/esearch.fcgi", params=params)
        resp.raise_for_status()
        data = resp.json()
        return data.get("esearchresult", {}).get("idlist", [])

    async def _efetch(self, pmids: list[str]) -> list[dict]:
        """Lädt Titel + Abstract für eine Liste von PMIDs."""
        params = {
            **self._base_params(),
            "db": "pubmed",
            "id": ",".join(pmids),
            "rettype": "abstract",
            "retmode": "xml",
        }
        resp = await self._client.get(f"{NCBI_BASE}/efetch.fcgi", params=params)
        resp.raise_for_status()
        return self._parse_xml(resp.text)

    def _parse_xml(self, xml_text: str) -> list[dict]:
        """Parst PubMed-XML und extrahiert Titel, Abstract, Jahr, PMID."""
        results = []
        try:
            root = ElementTree.fromstring(xml_text)
            for article in root.findall(".//PubmedArticle"):
                pmid_el = article.find(".//PMID")
                title_el = article.find(".//ArticleTitle")
                abstract_el = article.find(".//AbstractText")
                year_el = article.find(".//PubDate/Year")

                pmid = pmid_el.text if pmid_el is not None else "unknown"
                title = title_el.text if title_el is not None else ""
                abstract = abstract_el.text if abstract_el is not None else ""
                year = year_el.text if year_el is not None else ""

                # Abstracts kürzen — zu lange Abstracts verschwenden Tokens
                if abstract and len(abstract) > 600:
                    abstract = abstract[:600] + "…"

                if title or abstract:
                    results.append({
                        "pmid": pmid,
                        "title": title,
                        "abstract": abstract,
                        "year": year,
                    })
        except ElementTree.ParseError as e:
            logger.error(f"XML-Parse-Fehler: {e}")

        return results

    async def close(self):
        await self._client.aclose()
