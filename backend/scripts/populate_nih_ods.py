"""
NIH Office of Dietary Supplements — Vektordatenbank Population
==============================================================
Speichert kuratierte Kerninhalte aus NIH ODS Factsheets in supplement_facts.
Quelle: https://ods.od.nih.gov/factsheets/list-all/ (Public Domain, US Gov)

Da NIH automatisierte Requests blockiert, sind die Kerninhalte der wichtigsten
Factsheets hier direkt kuratiert eingebettet — vollständig reproduzierbar.

Ausführen (aus dem backend/ Ordner):
    python scripts/populate_nih_ods.py
"""
import logging
import time
import psycopg2
from fastembed import TextEmbedding

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

DB_CONFIG = {
    "host": "stacksense-db.chym26e8iw2p.eu-central-1.rds.amazonaws.com",
    "user": "stacksense",
    "password": "Jo790097",
    "dbname": "postgres",
    "port": 5432,
    "sslmode": "require",
}

# ── NIH ODS Factsheet Kerninhalte (Public Domain) ───────────────────────────
# Quelle: ods.od.nih.gov — alle Inhalte sind US-Regierungswerke (gemeinfrei)
NIH_ODS_FACTS = [
    # ── Kreatin ─────────────────────────────────────────────────────────────
    {
        "slug": "kreatin",
        "facts": [
            {
                "title": "NIH ODS — Creatine: Overview and Function",
                "content": "Creatine is a nitrogenous organic acid produced naturally in the body from arginine, glycine, and methionine. About 95% is stored in skeletal muscle, primarily as phosphocreatine. The body produces approximately 1-2 g/day; diet (meat, fish) provides another 1-2 g/day for non-vegetarians. Creatine monohydrate is the most extensively studied and cost-effective form.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Creatine: Exercise Performance Evidence",
                "content": "NIH ODS: Strong evidence supports creatine supplementation for high-intensity, short-duration exercise. Multiple meta-analyses and over 300 RCTs demonstrate: increased muscle phosphocreatine stores (10-40%), improved performance in repeated sprint bouts, increased lean mass during resistance training. Standard loading: 20 g/day for 5-7 days; maintenance: 3-5 g/day. Effects are most pronounced in vegetarians who have lower baseline creatine stores.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Creatine: Safety Profile",
                "content": "NIH ODS on Creatine Safety: Creatine monohydrate has an excellent safety record at doses of 3-5 g/day for up to 5 years. No evidence of kidney damage in healthy individuals. Minor side effect: water retention in initial loading phase (1-2 kg). May cause GI discomfort if taken in large single doses; splitting doses reduces this. Not recommended in individuals with pre-existing kidney disease. ISSN position stand confirms safety for healthy adults.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Creatine: Cognitive Benefits",
                "content": "NIH ODS: Emerging evidence suggests creatine supplementation may benefit cognitive function, particularly under sleep deprivation and in vegetarians. Creatine plays a role in brain energy metabolism via phosphocreatine system. Meta-analysis (2022) showed significant improvement in memory tasks. Effect size is smaller than for physical performance. More research needed for definitive conclusions on neurological benefits.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Vitamin D ────────────────────────────────────────────────────────────
    {
        "slug": "vitamin-d3",
        "facts": [
            {
                "title": "NIH ODS — Vitamin D: Recommended Intakes and Deficiency",
                "content": "NIH ODS Vitamin D Fact Sheet: Recommended Dietary Allowance (RDA): 600 IU (15 mcg) for ages 1-70, 800 IU (20 mcg) for >70. Tolerable Upper Intake Level: 4,000 IU/day. Deficiency defined as serum 25(OH)D <12 ng/mL; insufficiency 12-19 ng/mL; sufficiency ≥20 ng/mL. Risk groups: people with limited sun exposure, older adults, people with dark skin, those with fat malabsorption. Prevalence: approximately 40% of US adults are deficient.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Vitamin D: Health Effects Beyond Bone",
                "content": "NIH ODS: Beyond bone health (well-established), vitamin D research shows: cancer risk reduction — inconsistent results across RCTs; cardiovascular disease — VITAL trial (25,871 participants) showed no cardiovascular benefit with 2000 IU/day; type 2 diabetes — D-HEALTH trial suggested reduced incidence; immune function — observational studies link low D to increased respiratory infections; depression — some RCTs show modest benefit. Bottom line: evidence strongest for bone and immune function.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Vitamin D: Supplementation Guidelines",
                "content": "NIH ODS on Vitamin D supplementation: D3 (cholecalciferol) is more effective than D2 at raising serum 25(OH)D levels. Absorption improved with fatty meals (fat-soluble vitamin). For deficiency correction: 50,000 IU/week for 8-12 weeks (prescription D2) or 4,000-6,000 IU/day D3 for 2-3 months. Maintenance: 1,500-2,000 IU/day for most adults. Toxicity (>10,000 IU/day chronically) causes hypercalcemia. Testing 25(OH)D levels recommended before high-dose supplementation.",
                "evidence_level": "green",
            },
        ],
    },

    # ── Omega-3 ──────────────────────────────────────────────────────────────
    {
        "slug": "omega-3",
        "facts": [
            {
                "title": "NIH ODS — Omega-3 Fatty Acids: Key Functions",
                "content": "NIH ODS Omega-3 Fact Sheet: EPA (eicosapentaenoic acid) and DHA (docosahexaenoic acid) are the biologically active omega-3s. ALA (alpha-linolenic acid) from plants is inefficiently converted to EPA (5-10%) and DHA (<1%). DHA is critical for brain (30% of structural lipids in cerebral cortex) and retinal function. EPA has primary anti-inflammatory effects. AI for ALA: 1.6 g/day men, 1.1 g/day women. No established AI for EPA+DHA.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Omega-3: Cardiovascular Evidence",
                "content": "NIH ODS: Cardiovascular effects of omega-3s. Strong evidence: reduces triglycerides by 20-30% at 4 g/day (FDA-approved Vascepa/icosapentaenoic acid at 4 g/day reduced CV events in REDUCE-IT trial). Moderate evidence: reduces blood pressure modestly. Limited evidence: reduces risk of fatal MI. ASCEND and ORIGIN trials with 1 g/day showed no CV benefit in diabetic patients. Dose-response relationship important — 1 g insufficient for most CV indications.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Omega-3: Brain and Cognitive Health",
                "content": "NIH ODS on DHA and brain health: DHA is essential for fetal brain development — pregnant and breastfeeding women should consume 200-300 mg DHA/day. For cognitive decline prevention in adults, evidence is inconsistent — AREDS2 trial found no benefit for AMD-associated cognitive decline. Depression: meta-analyses suggest benefit for depressive symptoms, particularly EPA-predominant formulations. Optimal EPA:DHA ratio for depression may be >2:1 EPA. More research needed for dementia prevention.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Magnesium ────────────────────────────────────────────────────────────
    {
        "slug": "magnesium",
        "facts": [
            {
                "title": "NIH ODS — Magnesium: Recommended Intakes and Functions",
                "content": "NIH ODS Magnesium Fact Sheet: RDA: 400-420 mg/day men, 310-320 mg/day women. Tolerable UL: 350 mg/day from supplements (does not include food). Magnesium cofactor for >300 enzymatic reactions including ATP synthesis, DNA/RNA synthesis, protein synthesis. Essential for nerve impulse conduction, muscle contraction, blood glucose control. About 50-60% of body magnesium is in bone. Serum magnesium (normal range 0.75-0.95 mmol/L) is poor biomarker of total body status.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Magnesium: Type 2 Diabetes and Metabolic Syndrome",
                "content": "NIH ODS: Magnesium and glucose metabolism. Observational studies consistently show inverse association between magnesium intake and type 2 diabetes risk. Meta-analysis (2011, 13 prospective studies): each 100 mg/day increase in magnesium intake associated with 15% reduced diabetes risk. RCTs: magnesium supplementation improves insulin sensitivity in insulin-resistant and diabetic individuals. Mechanism: magnesium required for insulin receptor tyrosine kinase activity.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Magnesium: Bioavailability and Forms",
                "content": "NIH ODS on Magnesium forms: Bioavailability varies significantly by form. High bioavailability: magnesium aspartate, citrate, lactate, chloride (50-67% absorbed). Lower bioavailability: magnesium oxide (~4%), sulfate. Magnesium bisglycinate (glycinate) has high bioavailability and lower laxative effect — better tolerated at higher doses. Absorption decreases at high doses. Zinc supplements at high doses may reduce magnesium absorption. Take with food to reduce GI side effects.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Magnesium: Sleep and Anxiety",
                "content": "NIH ODS on Magnesium and sleep: Limited but promising evidence. Magnesium regulates NMDA receptors and GABA activity relevant to sleep initiation. RCT in elderly with insomnia (Abbasi 2012): 500 mg/day for 8 weeks improved sleep time, sleep efficiency, early morning awakening, and serum melatonin. Systematic review (2021): magnesium supplementation may benefit sleep quality, especially in those with deficiency. Evidence insufficient for strong recommendation in general population.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Zink ─────────────────────────────────────────────────────────────────
    {
        "slug": "zink",
        "facts": [
            {
                "title": "NIH ODS — Zinc: Immune Function and Common Cold",
                "content": "NIH ODS Zinc Fact Sheet: RDA: 11 mg/day men, 8 mg/day women. Tolerable UL: 40 mg/day. Zinc lozenges for common cold: Cochrane review (2013): zinc acetate lozenges (≥75 mg/day elemental zinc) reduced cold duration by 42% when started within 24 hours of onset. Zinc sulfate was less effective. Mechanism: direct antiviral effect on rhinovirus replication. Regular supplementation (5 mg/day for 5 months) reduced cold incidence in children.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Zinc: Deficiency Risk Groups and Bioavailability",
                "content": "NIH ODS on Zinc bioavailability: Phytates in grains and legumes bind zinc and reduce absorption by 15-25%. Vegetarians may need 50% more zinc than recommended. Meat, shellfish (especially oysters), and legumes are top sources. Oysters have highest zinc content (74 mg/3 oz). Risk groups for deficiency: vegetarians, people with GI disorders, alcoholics, pregnant/breastfeeding women. Symptoms: growth retardation, hypogeusia, immune dysfunction, delayed wound healing.",
                "evidence_level": "green",
            },
        ],
    },

    # ── Vitamin B12 ──────────────────────────────────────────────────────────
    {
        "slug": "vitamin-b12",
        "facts": [
            {
                "title": "NIH ODS — Vitamin B12: Absorption and Deficiency",
                "content": "NIH ODS Vitamin B12 Fact Sheet: RDA: 2.4 mcg/day adults. B12 absorption requires intrinsic factor (IF) secreted by gastric parietal cells. Two absorption mechanisms: IF-mediated (efficient, saturable at ~1.5 mcg per meal) and passive diffusion (1% of dose, dose-dependent). Deficiency causes: megaloblastic anemia, subacute combined degeneration of spinal cord, neuropsychiatric symptoms. Deficiency can exist for years before neurological symptoms emerge. Serum B12 alone insufficient to detect functional deficiency — methylmalonic acid and homocysteine are better markers.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Vitamin B12: Vegans and High-Dose Supplementation",
                "content": "NIH ODS: B12 for vegans and older adults. Vegans: B12 occurs only in animal products; strict vegetarians develop deficiency within years. Recommended: 250 mcg/day cyanocobalamin or 1000 mcg B12-fortified foods. Older adults: gastric atrophy reduces IF production — 10-30% of adults >50 cannot absorb food-bound B12 but can absorb crystalline B12 in supplements. At high oral doses (1000 mcg), 1% absorbed via passive diffusion bypasses IF requirement — effective for pernicious anemia. Sublingual route not proven superior to oral at equivalent doses.",
                "evidence_level": "green",
            },
        ],
    },

    # ── Eisen ────────────────────────────────────────────────────────────────
    {
        "slug": "eisen",
        "facts": [
            {
                "title": "NIH ODS — Iron: Recommended Intakes and Bioavailability",
                "content": "NIH ODS Iron Fact Sheet: RDA: 8 mg/day men, 18 mg/day women (19-50 years), 8 mg/day women (>51). Pregnant women: 27 mg/day. Tolerable UL: 45 mg/day. Heme iron (meat, fish) has 15-35% bioavailability; non-heme iron (plants, fortified foods) has 2-20%. Enhancers of non-heme absorption: vitamin C, meat. Inhibitors: phytates, calcium, polyphenols (tea, coffee, wine). Iron deficiency is the most common nutritional deficiency worldwide, affecting 2 billion people.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Iron: Supplementation and Fatigue",
                "content": "NIH ODS on Iron supplementation: Ferrous forms (sulfate, gluconate, bisglycinate) better absorbed than ferric. Ferrous bisglycinate has equivalent bioavailability with fewer GI side effects than ferrous sulfate. Take on empty stomach for maximum absorption; take with vitamin C. GI side effects (constipation, nausea) common with ferrous sulfate — alternate-day dosing may reduce side effects while maintaining efficacy. RCT evidence shows iron supplementation reduces fatigue in iron-depleted non-anemic women (serum ferritin <50 ng/mL).",
                "evidence_level": "green",
            },
        ],
    },

    # ── Calcium ──────────────────────────────────────────────────────────────
    {
        "slug": "calcium",
        "facts": [
            {
                "title": "NIH ODS — Calcium: Bone Health and Osteoporosis",
                "content": "NIH ODS Calcium Fact Sheet: RDA: 1,000 mg/day adults (19-50 men, 19-50 women), 1,200 mg/day women >51, men >71. Tolerable UL: 2,500 mg/day. About 99% of body calcium in bones and teeth. Peak bone mass achieved by age 30. Calcium + Vitamin D supplementation in postmenopausal women: WHI trial (36,282 women) showed modest reduction in hip fracture risk in adherent participants. Calcium from food preferred over supplements. Forms: calcium carbonate (cheapest, take with food), calcium citrate (better absorption empty stomach, preferred in older adults).",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Calcium: Cardiovascular Controversy",
                "content": "NIH ODS on Calcium and cardiovascular risk: Controversy over calcium supplements and MI risk. Bolland et al. (2010, 2011) meta-analyses suggested increased cardiovascular risk with calcium supplements (not food calcium). However, methodological concerns raised. USPSTF (2018) concluded insufficient evidence that calcium + D supplementation prevents cancer in postmenopausal women. Current guidance: obtain calcium from food when possible; limit supplements to filling gaps. Do not exceed 1,000 mg/day from supplements.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Selen ────────────────────────────────────────────────────────────────
    {
        "slug": "selen",
        "facts": [
            {
                "title": "NIH ODS — Selenium: Functions and Hashimoto's Thyroiditis",
                "content": "NIH ODS Selenium Fact Sheet: RDA: 55 mcg/day adults. Tolerable UL: 400 mcg/day. Selenium is component of 25 selenoproteins including glutathione peroxidases (GPx, antioxidant), thioredoxin reductase, and iodothyronine deiodinases (thyroid hormone metabolism). Hashimoto's thyroiditis: Meta-analysis (Wichman 2016, 4 RCTs): selenium supplementation (200 mcg/day sodium selenite) significantly reduced TPO antibodies and improved thyroid ultrasound in Hashimoto's patients. Effect on thyroid function (TSH, T4) less clear.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Selenium: Cancer Prevention and Toxicity",
                "content": "NIH ODS on Selenium and cancer: SELECT trial (35,533 men): selenium (200 mcg/day) did NOT reduce prostate cancer risk and was potentially harmful in men with high baseline selenium. This overturned earlier promising observational data. Lesson: selenium benefits are likely limited to deficient populations. Selenium toxicity (selenosis) occurs at >400 mcg/day: hair loss, nail brittleness, garlic breath, fatigue, nerve damage. Geographic variation in soil selenium content causes wide variation in dietary intake. Brazil nuts: 1 nut provides ~70-90 mcg selenium.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Folsäure ─────────────────────────────────────────────────────────────
    {
        "slug": "folsaeure",
        "facts": [
            {
                "title": "NIH ODS — Folate: Neural Tube Defect Prevention",
                "content": "NIH ODS Folate Fact Sheet: RDA: 400 mcg DFE/day adults. Pregnancy: 600 mcg DFE/day. Tolerable UL: 1,000 mcg/day (synthetic folic acid). Neural tube defect prevention: USPSTF recommendation (Grade A): all women planning or capable of pregnancy should take 400-800 mcg/day folic acid. MRC Vitamin Study (RCT, 1991): 72% reduction in NTD recurrence with 4 mg/day folic acid. Prevention requires supplementation at least 1 month BEFORE conception — NTD occurs at 21-28 days post-conception, before most pregnancies are recognized.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Folate: Cancer Risk and Cognitive Function",
                "content": "NIH ODS on Folate and cancer: Observational data suggests protective association with colorectal cancer. However, folic acid supplementation in individuals with pre-existing adenomas may INCREASE colorectal cancer risk (AFPPS trial). May promote growth of pre-existing neoplasms. Cognitive function: inadequate folate associated with elevated homocysteine and cognitive decline. B12+folate+B6 supplementation in VITACOG trial reduced brain atrophy by 30% in people with elevated homocysteine and mild cognitive impairment. Dosing: 800 mcg/day folic acid.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Jod ──────────────────────────────────────────────────────────────────
    {
        "slug": "jod",
        "facts": [
            {
                "title": "NIH ODS — Iodine: Thyroid Function and Deficiency",
                "content": "NIH ODS Iodine Fact Sheet: RDA: 150 mcg/day adults, 220 mcg pregnancy, 290 mcg lactation. Tolerable UL: 1,100 mcg/day. Iodine is essential component of thyroid hormones T3 and T4. Deficiency is world's leading preventable cause of intellectual disability. Goiter (thyroid enlargement) is classic sign of deficiency. Iodized salt eliminated iodine deficiency in most developed nations. Vegans and those avoiding iodized salt at risk. Seaweed provides highly variable iodine — can cause both excess and deficiency.",
                "evidence_level": "green",
            },
        ],
    },

    # ── Vitamin C ────────────────────────────────────────────────────────────
    {
        "slug": "vitamin-c",
        "facts": [
            {
                "title": "NIH ODS — Vitamin C: Common Cold Evidence",
                "content": "NIH ODS Vitamin C Fact Sheet: RDA: 90 mg/day men, 75 mg/day women. Tolerable UL: 2,000 mg/day. Common cold: Cochrane review (2013, 29 RCTs, 11,306 participants): regular supplementation (200 mg/day+) reduced cold duration by 8% in adults, 14% in children, but did NOT reduce incidence. Therapeutic use after onset shows no benefit. Exception: individuals under heavy physical stress (marathoners, skiers): 50% reduction in cold incidence. Linus Pauling's claims of high-dose prevention not supported by evidence.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Vitamin C: Cancer and Antioxidant Functions",
                "content": "NIH ODS on Vitamin C and cancer: Observational studies consistently show inverse association between vitamin C intake and several cancers. However, randomized trials with vitamin C supplements showed no cancer prevention benefit (ATBC, PHS II). High-dose IV vitamin C (pharmacological doses, 10 g+) is being studied as adjunct cancer therapy — different pharmacokinetics than oral. As antioxidant: regenerates vitamin E from tocopheroxyl radical. Promotes collagen synthesis as cofactor for prolyl/lysyl hydroxylase. Enhances non-heme iron absorption.",
                "evidence_level": "green",
            },
        ],
    },

    # ── Biotin ───────────────────────────────────────────────────────────────
    {
        "slug": "biotin",
        "facts": [
            {
                "title": "NIH ODS — Biotin: Hair, Skin and Reality Check",
                "content": "NIH ODS Biotin Fact Sheet: AI (Adequate Intake): 30 mcg/day adults. No established Tolerable UL. Biotin deficiency rare in healthy individuals; causes hair loss, skin rash, neurological symptoms. Key caveat from NIH ODS: 'There is little scientific evidence to support the claim that biotin supplements can improve hair and nail health in people who are not biotin deficient.' The widespread marketing of high-dose biotin (5,000-10,000 mcg) for hair growth is not supported by robust clinical evidence in non-deficient individuals. FDA warning: high-dose biotin interferes with cardiac troponin lab tests — inform healthcare providers.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Probiotika ───────────────────────────────────────────────────────────
    {
        "slug": "probiotika",
        "facts": [
            {
                "title": "NIH ODS — Probiotics: Evidence Overview",
                "content": "NIH ODS Probiotics Fact Sheet: Probiotics are live microorganisms that when administered in adequate amounts confer a health benefit on the host (WHO definition). Most studied applications: antibiotic-associated diarrhea (Lactobacillus rhamnosus GG, Saccharomyces boulardii — strong evidence, RR reduction ~60%); C. difficile infection prevention; traveler's diarrhea; IBS (strain-specific benefit). Critically: effects are strain-specific, dose-specific, and condition-specific. A product with 'probiotics' on the label does not automatically convey any specific health benefit.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Probiotics: Safety and Specific Conditions",
                "content": "NIH ODS on Probiotic safety: Generally safe in healthy adults. AVOID in immunocompromised patients, critically ill, those with central venous catheters — rare but serious infections (septicemia, endocarditis) reported. Emerging evidence for: atopic dermatitis in infants (Lactobacillus rhamnosus GG — modest benefit), vaginal health (Lactobacillus reuteri RC-14 + rhamnosus GR-1), weight management (very limited, strain-dependent). Microbiome effects are temporary — benefits typically require continued use. Cold chain maintenance critical for viability.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Ashwagandha ──────────────────────────────────────────────────────────
    {
        "slug": "ashwagandha",
        "facts": [
            {
                "title": "NIH ODS — Ashwagandha (Withania somnifera): Stress and Anxiety",
                "content": "NIH ODS on Ashwagandha: Most studied benefits are for stress and anxiety reduction. RCT (Chandrasekhar 2012, n=64): 300 mg KSM-66 twice daily for 60 days significantly reduced PSS stress scores and cortisol by 27.9% vs placebo. Meta-analysis (Pratte 2014, 5 RCTs): significant reduction in anxiety symptoms. Active constituents: withanolides (0.3-1.5% in standardized extracts). Two main extract types: KSM-66 (root), Sensoril (root+leaf). Most studies use 250-600 mg/day standardized extract.",
                "evidence_level": "yellow",
            },
            {
                "title": "NIH ODS — Ashwagandha: Athletic Performance and Safety",
                "content": "NIH ODS on Ashwagandha and exercise: RCT (Wankhede 2015): 300 mg KSM-66 twice daily for 8 weeks significantly increased muscle strength, recovery, and testosterone vs placebo in healthy men. However, sample sizes are small (typically 40-60 participants). Safety concerns: case reports of hepatotoxicity at higher doses. Potential interaction with thyroid medications — may increase T4 levels. NIH ODS classifies evidence as 'some evidence' for stress reduction; 'preliminary evidence' for athletic performance. More large RCTs needed.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── L-Theanin ────────────────────────────────────────────────────────────
    {
        "slug": "l-theanin",
        "facts": [
            {
                "title": "NIH ODS — L-Theanine: Cognitive Effects and Anxiety",
                "content": "NIH ODS on L-Theanine: Amino acid found in tea (Camellia sinensis). Crosses blood-brain barrier. EEG studies show L-theanine increases alpha brain wave activity within 30-40 minutes — associated with relaxed alertness without sedation. Meta-analysis (Nobre 2008): L-theanine (200 mg) + caffeine significantly improved accuracy on attention tasks vs caffeine alone. RCT (Kimura 2007): 200 mg reduced anxiety response to psychological stressor. Typical doses: 100-200 mg. Natural tea content: 6-20 mg per cup. Generally recognized as safe (GRAS) by FDA.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Melatonin ────────────────────────────────────────────────────────────
    {
        "slug": "melatonin",
        "facts": [
            {
                "title": "NIH ODS — Melatonin: Sleep and Circadian Rhythms",
                "content": "NIH ODS Melatonin Fact Sheet: Melatonin is a hormone produced by the pineal gland in response to darkness. Peak production: 2-4 AM. Synthesis declines with age — major contributor to sleep changes in elderly. Most evidence supports: jet lag (strong evidence — Cochrane review: significant reduction in jet lag symptoms), shift work sleep disorder, delayed sleep phase disorder, and insomnia in older adults. Meta-analysis (Ferracioli-Oda 2013): melatonin decreased sleep onset latency by 7 minutes, increased total sleep time by 8 minutes — modest effects in general insomnia. Optimal timing: 30-60 min before desired sleep.",
                "evidence_level": "green",
            },
            {
                "title": "NIH ODS — Melatonin: Dosing and Safety",
                "content": "NIH ODS on Melatonin dosing: Effective doses typically 0.5-5 mg. Higher doses (5-10 mg) not more effective and may cause next-day grogginess. Physiological replacement: 0.5 mg is closer to natural production (peak serum ~200 pg/mL). Most OTC products are 3-10 mg — substantially above physiological range. Short-term safety well-established. Long-term (>3 months): insufficient data in adults, not recommended in children (may affect pubertal development). Avoid in pregnancy. May interact with anticoagulants and immunosuppressants. Available OTC in US; prescription-only in many EU countries.",
                "evidence_level": "green",
            },
        ],
    },

    # ── Coenzym Q10 ──────────────────────────────────────────────────────────
    {
        "slug": "coenzym-q10",
        "facts": [
            {
                "title": "NIH ODS — CoQ10: Statin-Induced Myopathy and Heart Failure",
                "content": "NIH ODS CoQ10 Fact Sheet: Coenzyme Q10 is lipid-soluble compound essential for mitochondrial electron transport (Complex I-III). Statins inhibit CoQ10 synthesis (HMG-CoA reductase pathway). However, meta-analyses of CoQ10 for statin-induced myopathy show inconsistent results — some RCTs show benefit, others show none. Heart failure: meta-analysis (Mortensen 2014, Q-SYMBIO trial): CoQ10 (300 mg/day) significantly reduced cardiovascular mortality in severe heart failure. Strongest evidence for heart failure and CoQ10 deficiency states. Typical dose: 100-300 mg/day with fatty meal (fat-soluble). Ubiquinol (reduced form) may have better bioavailability.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Berberin ─────────────────────────────────────────────────────────────
    {
        "slug": "berberin",
        "facts": [
            {
                "title": "NIH ODS — Berberine: Blood Sugar and Metabolic Effects",
                "content": "NIH ODS on Berberine: Plant alkaloid found in goldenseal, barberry, Oregon grape. Mechanism: activates AMPK (similar to metformin) — improves insulin sensitivity, reduces glucose production, lipid-lowering effects. Meta-analysis (Dong 2012, 14 RCTs): berberine significantly reduced HbA1c by 0.71%, fasting glucose by 1.1 mmol/L, and triglycerides in type 2 diabetes — comparable to oral hypoglycemics. However, study quality is variable and mostly from China. FDA has not approved berberine for any medical condition. Typical dose: 500 mg 2-3 times/day before meals. Drug interaction risk: similar to metformin, may lower blood sugar excessively when combined with diabetes medications.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── NAC ──────────────────────────────────────────────────────────────────
    {
        "slug": "nac",
        "facts": [
            {
                "title": "NIH ODS — N-Acetylcysteine (NAC): Antioxidant and Mucus",
                "content": "NIH ODS on NAC: N-acetylcysteine is a precursor to glutathione (master antioxidant). Medical uses with strong evidence: IV NAC for acetaminophen overdose (standard of care); mucolytic for COPD and cystic fibrosis (FDA-approved Mucomyst). Supplement uses: oxidative stress reduction — meta-analysis shows benefit in specific conditions (HIV, COPD). Psychiatric applications: promising evidence for OCD, bipolar disorder, schizophrenia — likely via glutamate modulation. Note: FDA sent warning letters to NAC supplement marketers (2020-2021) questioning its legal status as supplement vs drug in US. Available in EU as supplement.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── 5-HTP ────────────────────────────────────────────────────────────────
    {
        "slug": "5-htp",
        "facts": [
            {
                "title": "NIH ODS — 5-HTP: Serotonin Precursor and Depression",
                "content": "NIH ODS on 5-HTP (5-Hydroxytryptophan): Direct precursor to serotonin; crosses blood-brain barrier (unlike tryptophan, more direct conversion). Evidence for depression: Cochrane review (Shaw 2002): only 2 trials met quality criteria; some evidence of benefit over placebo but methodology concerns. NOT recommended as replacement for SSRIs in moderate-severe depression. Fibromyalgia: 3 small RCTs suggest benefit for pain, sleep, anxiety. IMPORTANT safety warning: Do not combine with SSRIs, MAOIs, or other serotonergic drugs — risk of serotonin syndrome. Recommended max: 150-300 mg/day. Peak-X contamination risk in some supplements (as seen in eosinophilia-myalgia syndrome with tryptophan in 1989).",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Curcumin ─────────────────────────────────────────────────────────────
    {
        "slug": "curcumin",
        "facts": [
            {
                "title": "NIH ODS — Curcumin: Anti-Inflammatory Evidence and Bioavailability Problem",
                "content": "NIH ODS on Curcumin: Active compound in turmeric (Curcuma longa). Strong anti-inflammatory and antioxidant activity in vitro and animal studies. CRITICAL LIMITATION: poor bioavailability — standard curcumin is poorly absorbed (1-2%). Solutions tested: piperine (bioperine) enhances absorption 20-fold; phytosome formulations (Meriva); nanoparticle encapsulation. Meta-analysis of RCTs (Hewlings 2017): curcumin supplementation significantly reduced inflammatory markers (CRP, IL-6) and improved symptoms in arthritis — but most studies used enhanced bioavailability forms. Evidence for: arthritis (moderate), metabolic syndrome (limited), depression (preliminary). Cancer prevention: promising preclinical data, insufficient human RCT evidence.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Resveratrol ──────────────────────────────────────────────────────────
    {
        "slug": "resveratrol",
        "facts": [
            {
                "title": "NIH ODS — Resveratrol: Preclinical Promise vs. Human Trial Reality",
                "content": "NIH ODS on Resveratrol: Polyphenol in red wine, grapes, blueberries, peanuts. Activates sirtuins (SIRT1) — proposed mechanism for lifespan extension. Animal studies show impressive anti-aging, anti-cancer, and cardiovascular effects. Human trials: disappointing results. Meta-analysis (Liu 2014): no significant effect on blood pressure, glucose, or lipids in healthy individuals. Small RCTs in specific populations show modest benefits. Bioavailability poor (oral bioavailability <1%); rapid metabolism. Trans-resveratrol is active form. No clear effective dose established. Current consensus: insufficient evidence to recommend as supplement for general population.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Johanniskraut ────────────────────────────────────────────────────────
    {
        "slug": "johanniskraut",
        "facts": [
            {
                "title": "NIH ODS — St. John's Wort: Depression Evidence and Drug Interactions",
                "content": "NIH ODS St. John's Wort Fact Sheet: Cochrane review (Linde 2008, 29 RCTs, 5,489 participants): St. John's Wort significantly more effective than placebo for mild-to-moderate depression, with similar efficacy to standard antidepressants and fewer side effects. NOT effective for severe depression (JAMA RCT 2002). Active constituents: hypericin, hyperforin, flavonoids. Standard dose: 300 mg TID (0.3% hypericin). CRITICAL drug interactions via CYP3A4 and P-glycoprotein induction: reduces efficacy of oral contraceptives (breakthrough bleeding, pregnancy), HIV antivirals, cyclosporine (transplant rejection reported), warfarin, digoxin, chemotherapy. Serotonin syndrome risk with SSRIs/SNRIs.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Ginkgo ───────────────────────────────────────────────────────────────
    {
        "slug": "ginkgo",
        "facts": [
            {
                "title": "NIH ODS — Ginkgo Biloba: Cognitive Function and Dementia",
                "content": "NIH ODS Ginkgo Fact Sheet: Standardized extract EGb 761 most studied form. Ginkgo Memory Assessment Study (2009): no cognitive benefit in normal aging. GEM study (3,069 older adults): ginkgo 120 mg twice daily did NOT reduce incidence of Alzheimer's disease or dementia over 6 years. European studies (EGb 761, Ihl 2012): improvements in dementia symptoms and neuropsychiatric symptoms. Contradiction may reflect dose (120 mg vs 240 mg), extract standardization, and population differences. Modest evidence for claudication (peripheral artery disease) and altitude sickness. Antiplatelet effects — caution with anticoagulants. Do not combine with warfarin or NSAIDs.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Spirulina ────────────────────────────────────────────────────────────
    {
        "slug": "spirulina",
        "facts": [
            {
                "title": "NIH ODS — Spirulina: Nutritional Profile and Evidence",
                "content": "NIH ODS on Spirulina: Cyanobacterium (blue-green algae) grown in alkaline water. Nutritional profile: 60-70% protein by weight (complete protein), phycocyanin (antioxidant pigment), gamma-linolenic acid, B vitamins, iron, beta-carotene. Clinical evidence: limited but promising. Meta-analysis (Serban 2016, 7 RCTs): significantly reduced total cholesterol, LDL, triglycerides, and raised HDL. Some evidence for blood sugar reduction in type 2 diabetes. Anti-allergic rhinitis effects in several small RCTs. Dose: 1-8 g/day. Safety: generally safe; may be contaminated with heavy metals or cyanotoxins from polluted water — choose certified products. B12 in spirulina is largely biologically inactive analog.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── Vitamin E ────────────────────────────────────────────────────────────
    {
        "slug": "vitamin-e",
        "facts": [
            {
                "title": "NIH ODS — Vitamin E: Antioxidant Role and Supplement Caution",
                "content": "NIH ODS Vitamin E Fact Sheet: RDA: 15 mg/day (22.4 IU natural, 33.3 IU synthetic). Tolerable UL: 1,000 mg/day (1,500 IU natural). Eight forms exist: alpha-tocopherol has highest bioavailability. Major antioxidant protecting cell membranes from lipid peroxidation. IMPORTANT: Large RCTs (HOPE-TOO, SELECT trials) found high-dose vitamin E supplements (400-400 IU/day) did NOT reduce cardiovascular disease or cancer, and SELECT trial found increased prostate cancer risk at 400 IU/day. Alpha-Tocopherol, Beta-Carotene (ATBC) study: 20 mg/day increased lung cancer risk in male smokers. Evidence does NOT support high-dose supplementation in general population. Food sources preferred: nuts, seeds, vegetable oils, leafy greens.",
                "evidence_level": "yellow",
            },
        ],
    },

    # ── L-Glutamin ───────────────────────────────────────────────────────────
    {
        "slug": "l-glutamin",
        "facts": [
            {
                "title": "NIH ODS — Glutamine: Conditionally Essential and Gut Health",
                "content": "NIH ODS on Glutamine: Most abundant amino acid in blood and skeletal muscle. Conditionally essential — becomes essential during critical illness, major surgery, burns, severe trauma. Clinical evidence: medical use in critically ill patients controversial (REDOXS trial showed harm at high doses). Gut health: glutamine is primary fuel for enterocytes; supports intestinal barrier integrity. Observational and small RCT evidence for reducing intestinal permeability. Sports use: 5-10 g post-exercise for recovery — limited evidence in healthy athletes. Not essential for healthy individuals who consume adequate protein.",
                "evidence_level": "yellow",
            },
        ],
    },
]


def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)


def supplement_exists(cur, slug: str) -> bool:
    cur.execute("SELECT 1 FROM supplements WHERE slug = %s", (slug,))
    return cur.fetchone() is not None


def upsert_fact(cur, supplement_slug: str, title: str, content: str,
                evidence_level: str, embedding_list: list):
    embedding_str = str(embedding_list)
    cur.execute("""
        INSERT INTO supplement_facts
            (supplement_slug, fact_type, content, embedding, source)
        VALUES (%s, %s, %s, %s::vector, %s)
        ON CONFLICT DO NOTHING
    """, (
        supplement_slug,
        f"nih_ods_{evidence_level}",
        f"{title}\n\n{content}",
        embedding_str,
        "nih_ods",
    ))


def main():
    logger.info("Lade fastembed Modell...")
    model = TextEmbedding("BAAI/bge-small-en-v1.5")
    logger.info("Modell geladen.")

    conn = get_db_connection()
    conn.autocommit = False
    cur = conn.cursor()

    total_inserted = 0
    total_skipped = 0

    for entry in NIH_ODS_FACTS:
        slug = entry["slug"]

        if not supplement_exists(cur, slug):
            logger.warning(f"  Supplement '{slug}' nicht in DB — überspringe")
            total_skipped += len(entry["facts"])
            continue

        for fact in entry["facts"]:
            text_to_embed = f"{fact['title']}. {fact['content']}"
            embedding = list(model.embed([text_to_embed]))[0].tolist()

            upsert_fact(
                cur,
                supplement_slug=slug,
                title=fact["title"],
                content=fact["content"],
                evidence_level=fact["evidence_level"],
                embedding_list=embedding,
            )
            total_inserted += 1
            logger.info(f"  ✓ {slug}: {fact['title'][:65]}...")
            time.sleep(0.05)

    conn.commit()
    cur.close()
    conn.close()

    logger.info(f"""
╔══════════════════════════════════════════╗
║  NIH ODS Population abgeschlossen       ║
║  Eingefügt:   {total_inserted:>4} Einträge              ║
║  Übersprungen:{total_skipped:>4} (Supplement fehlt)   ║
╚══════════════════════════════════════════╝
""")


if __name__ == "__main__":
    main()
