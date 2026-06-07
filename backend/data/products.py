"""
Produkt-Mapping: Supplement-ID → Liste von Kaufoptionen.
Mehrere Varianten pro Supplement (isoliert, kombiniert, verschiedene Dosierungen).
"""

# Jede Option: label, shop, url, note (optional)
PRODUCT_MAP: dict[str, list[dict]] = {
    "vitamin-d3": [
        {
            "label": "Vitamin D3 Tropfen (2.500 IE)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/vitamin-d/",
            "note": "Einfachste tägliche Dosierung",
        },
        {
            "label": "Vegan D3 + K2 + B12 + Omega-3 Set",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/vegan-d3-k2-b12-omega-3-set.html",
            "note": "Kombination für Veganer",
        },
        {
            "label": "Omega-3 + D3 + K2 + E Softgels",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/omega-3-plus-vitamin-d3-k2-e-vegan.html",
            "note": "All-in-one fettlösliche Vitamine",
        },
    ],
    "vitamin-d3-k2": [
        {
            "label": "Omega-3 + D3 + K2 + E (vegan)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/omega-3-plus-vitamin-d3-k2-e-vegan.html",
            "note": "Optimale Kombination",
        },
        {
            "label": "Vegan Set D3 + K2 + B12 + Omega-3",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/vegan-d3-k2-b12-omega-3-set.html",
            "note": "Komplett-Set für Veganer",
        },
    ],
    "magnesium": [
        {
            "label": "Magnesium Glycinat Pure 750mg",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/magnesium-glycinate-pure-capsules.html",
            "note": "Hochdosiert, reines Bisglycinat",
        },
        {
            "label": "Magnesium Glycinat Slow Release 150mg",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/magnesium-glycinate-capsules.html",
            "note": "Sanfte Langzeitfreisetzung",
        },
        {
            "label": "Magnesium Komplex Ultra (9 Formen)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/mg-complex-9-ultra-capsules.html",
            "note": "Breites Spektrum verschiedener Magnesiumformen",
        },
    ],
    "magnesium-bisglycinat": [
        {
            "label": "Magnesium Glycinat Pure 750mg",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/magnesium-glycinate-pure-capsules.html",
            "note": "Hochdosiert, reines Bisglycinat",
        },
        {
            "label": "Magnesium Glycinat Slow Release",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/magnesium-glycinate-capsules.html",
            "note": "Sanfte Langzeitfreisetzung",
        },
    ],
    "omega-3": [
        {
            "label": "Omega-3 + D3 + K2 + E (vegan)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/omega-3-plus-vitamin-d3-k2-e-vegan.html",
            "note": "Vegan, mit fettlöslichen Vitaminen",
        },
        {
            "label": "Omega-3 + D3 + K2 + E XL (240 Kapseln)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/omega-3-plus-vitamin-d3-k2-e-vegan-xl.html",
            "note": "Großpackung, günstiger pro Kapsel",
        },
        {
            "label": "Vegan Set D3 + K2 + B12 + Omega-3",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/vegan-d3-k2-b12-omega-3-set.html",
            "note": "Komplett-Set",
        },
    ],
    "epa-dha": [
        {
            "label": "Omega-3 + D3 + K2 + E (vegan)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/omega-3-plus-vitamin-d3-k2-e-vegan.html",
            "note": "EPA & DHA aus Algenöl",
        },
    ],
    "zink": [
        {
            "label": "Zink & Selen Plus Kofaktoren",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/zinc-selenium-sodium-selenite-plus-cofactors.html",
            "note": "Mit Selen, Vitamin B6 & C",
        },
        {
            "label": "Zink (isoliert)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/zinc/",
            "note": "Reines Zink, verschiedene Dosierungen",
        },
        {
            "label": "Immun-Kit (Vitamin D, C, Zink, Selen)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/immunity-kit.html",
            "note": "Vollständiges Immunpaket",
        },
    ],
    "selen": [
        {
            "label": "Zink & Selen Plus Kofaktoren",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/zinc-selenium-sodium-selenite-plus-cofactors.html",
            "note": "Mit Zink, Vitamin B6 & C",
        },
        {
            "label": "Selen (Kategorie)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/selenium/",
            "note": "Alle Selen-Produkte im Überblick",
        },
    ],
    "eisen": [
        {
            "label": "Eisen (alle Varianten)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/iron/",
            "note": "Bisglycinat, liposomal, pflanzlich",
        },
    ],
    "vitamin-b12": [
        {
            "label": "Vitamin B12 Rapid Spray 1000µg",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/b12-1000-methylcobalamin-rapid-spray.html",
            "note": "Methylcobalamin — schnelle Aufnahme",
        },
        {
            "label": "Vitamin B Komplex Bioaktiv Forte",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/b-complex-bioactive-high-dose-cofactors.html",
            "note": "B12 + alle B-Vitamine kombiniert",
        },
        {
            "label": "Vegan Set D3 + K2 + B12 + Omega-3",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/vegan-d3-k2-b12-omega-3-set.html",
            "note": "B12 im Komplett-Set",
        },
    ],
    "vitamin-b-komplex": [
        {
            "label": "Vitamin B Komplex Bioaktiv Forte",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/b-complex-bioactive-high-dose-cofactors.html",
            "note": "Hochdosiert, alle B-Vitamine",
        },
        {
            "label": "Vitamin B Komplex Sensitive",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/bioactive-b-complex-sensitive.html",
            "note": "Sanfte Dosierung für Empfindliche",
        },
        {
            "label": "B-Komplex mit Buchweizen & B12 MH3A",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/b-complex-buckwheat-b12-mh3a-formula-bioactive-capsules.html",
            "note": "Natürliche Nahrungsmatrix",
        },
    ],
    "vitamin-c": [
        {
            "label": "Vitamin C (alle Varianten)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/vitamin-c/",
            "note": "1000mg, liposomal, Pulver, Gummies",
        },
        {
            "label": "Immun-Kit (D, C, Zink, Selen)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/immunity-kit.html",
            "note": "Komplettes Immunpaket",
        },
    ],
    "ashwagandha": [
        {
            "label": "Sleep Complex Ultra (mit Ashwagandha)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/sleep-essentials-plus.html",
            "note": "Ashwagandha + Melatonin + Lemon Balm",
        },
        {
            "label": "Adaptogene (alle Ashwagandha-Produkte)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/adaptogen-complexes/",
            "note": "Verschiedene Ashwagandha-Varianten",
        },
    ],
    "melatonin": [
        {
            "label": "Sleep Complex Ultra (Melatonin + Ashwagandha)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/sleep-essentials-plus.html",
            "note": "Melatonin + Kräuter-Komplex für Schlaf",
        },
        {
            "label": "Alle Schlaf-Produkte",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/sleep-inner-peace/",
            "note": "Melatonin isoliert & Kombinationen",
        },
    ],
    "l-theanin": [
        {
            "label": "L-Theanin 100mg (Grüntee-Extrakt)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/theanine-capsules-100mg-green-tea-extract.html",
            "note": "Reines L-Theanin, 99% Reinheit",
        },
        {
            "label": "Koffein 100mg + L-Theanin 100mg",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/caffeine-100mg-l-theanine-100mg.html",
            "note": "Klassische Fokus-Kombination",
        },
    ],
    "coenzym-q10": [
        {
            "label": "Q10 PQQ Komplex + B6 + Vitamin C",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/q10-pqq-complex-plus-b6-p5p-vitamin-c.html",
            "note": "Premium Q10-Komplex",
        },
        {
            "label": "Q10 + D-Ribose + Vitamin B1 (Herz-Bundle)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/coenzyme-q10-b1-d-ribose.html",
            "note": "Speziell für Herzfunktion",
        },
        {
            "label": "Alle CoQ10-Produkte",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/coenzyme-q10/",
            "note": "Übersicht aller Varianten",
        },
    ],
    "folsaeure": [
        {
            "label": "Vegan Set D3 + K2 + B12 + Omega-3",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/vegan-d3-k2-b12-omega-3-set.html",
            "note": "Enthält bioaktives Folat",
        },
        {
            "label": "Vitamin B Komplex Bioaktiv Forte",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/b-complex-bioactive-high-dose-cofactors.html",
            "note": "Folsäure + alle B-Vitamine",
        },
    ],
    "probiotika": [
        {
            "label": "Fermentierte Pflanzenstoffe & Paraprobiotika",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/fermented/",
            "note": "10 Mrd. CFU, hitzeresistente Stämme",
        },
    ],
    "curcumin": [
        {
            "label": "Fermentiertes Kurkuma (93x höhere Bioverfügbarkeit)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/fermented/",
            "note": "Cureit® + Turmacin® + CurcuRouge®",
        },
    ],
    "kreatin": [
        {
            "label": "Kreatin Monohydrat Pulver 1kg",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/creatine-monohydrate-powder.html",
            "note": "Creapure® — geprüfte Qualität",
        },
        {
            "label": "Alle Kreatin-Produkte",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/creatine/",
            "note": "Pulver, Kapseln & mehr",
        },
    ],
    "l-carnitin": [
        {
            "label": "Vegane Aminosäuren (Sport Line)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/sport-line-amino-acids/",
            "note": "L-Carnitin & weitere Aminosäuren",
        },
    ],
    "beta-glucan": [
        {
            "label": "Fermentierte Pflanzenstoffe & Paraprobiotika",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/fermented/",
            "note": "Beta-Glucan mit 10 Mrd. CFU",
        },
        {
            "label": "Immun-Kit",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/immunity-kit.html",
            "note": "Komplettes Immunpaket",
        },
    ],
    "rhodiola": [
        {
            "label": "Fermentierte Pflanzenstoffe (mit Rhodiola)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/fermented/",
            "note": "Rhodiola Rosea + Paraprobiotika",
        },
        {
            "label": "Adaptogene (Übersicht)",
            "shop": "Sunday Natural",
            "url": "https://www.sunday.de/en/adaptogen-complexes/",
            "note": "Alle Adaptogen-Produkte",
        },
    ],
}


def get_products(supplement_id: str) -> list[dict]:
    """
    Gibt alle Kaufoptionen für eine Supplement-ID zurück.
    Sucht exakt, dann normalisiert, dann als Teilstring.
    """
    if supplement_id in PRODUCT_MAP:
        return PRODUCT_MAP[supplement_id]

    normalized = supplement_id.lower().replace("_", "-")
    if normalized in PRODUCT_MAP:
        return PRODUCT_MAP[normalized]

    for key, value in PRODUCT_MAP.items():
        if key in normalized or normalized in key:
            return value

    return []
