import asyncio
from services.pubmed_service import PubMedService

async def test():
    p = PubMedService()
    results = await p.search_abstracts('Vitamin D supplementation RCT', max_results=3)
    print('PubMed Ergebnis:', len(results), 'Studien')
    for r in results:
        print(' -', r.get('pmid'), r.get('title', '')[:60])
    await p.close()

asyncio.run(test())
