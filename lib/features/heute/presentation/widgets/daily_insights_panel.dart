import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// Datenmodell für eine Insight-Card
// ---------------------------------------------------------------------------

class InsightCardData {
  final String tag;
  final String title;
  final String text;
  final IconData icon;
  final List<Color> gradient;

  const InsightCardData({
    required this.tag,
    required this.title,
    required this.text,
    required this.icon,
    required this.gradient,
  });
}

// ---------------------------------------------------------------------------
// Einzelne Insight-Card
// ---------------------------------------------------------------------------

class InsightCard extends StatelessWidget {
  final InsightCardData data;
  final double width;

  const InsightCard({super.key, required this.data, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.gradient,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: [
          BoxShadow(
            color: data.gradient.first.withOpacity(0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        child: Stack(
          children: [
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(data.icon, color: Colors.white.withOpacity(0.9), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        data.tag,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.title,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.text,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.82),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontale Scroll-Liste (rotiert täglich)
// ---------------------------------------------------------------------------

class DailyInsightsPanel extends StatelessWidget {
  const DailyInsightsPanel({super.key});

  static const _supplements = <InsightCardData>[
    InsightCardData(tag: 'Supplement', title: 'Magnesium Bisglycinat', text: 'Besonders gut bioverfügbar — unterstützt Schlaf, Muskeln und das Nervensystem.', icon: Icons.nights_stay_outlined, gradient: [Color(0xFF5E35B1), Color(0xFF3949AB)]),
    InsightCardData(tag: 'Supplement', title: 'Vitamin D3 + K2', text: 'D3 für Knochen und Immunsystem, K2 sorgt dafür dass Calcium dorthin gelangt wo es hingehört.', icon: Icons.wb_sunny_outlined, gradient: [Color(0xFFE65100), Color(0xFFF57C00)]),
    InsightCardData(tag: 'Supplement', title: 'Omega-3 EPA/DHA', text: 'Essentielle Fettsäuren für Gehirn, Herz und Entzündungsregulation — kaum durch Ernährung abdeckbar.', icon: Icons.water_drop_outlined, gradient: [Color(0xFF0277BD), Color(0xFF0288D1)]),
    InsightCardData(tag: 'Supplement', title: 'Ashwagandha KSM-66', text: 'Adaptogen aus der ayurvedischen Medizin — Studien zeigen Hinweise auf Cortisol-Modulation bei Stress.', icon: Icons.spa_outlined, gradient: [Color(0xFF2E7D32), Color(0xFF388E3C)]),
    InsightCardData(tag: 'Supplement', title: 'Zink Bisglycinat', text: 'Wichtig für Immunsystem, Hormonhaushalt und Wundheilung — häufig unterdosiert in der westlichen Ernährung.', icon: Icons.shield_outlined, gradient: [Color(0xFF00695C), Color(0xFF00897B)]),
    InsightCardData(tag: 'Supplement', title: 'L-Theanin', text: 'Aminosäure aus grünem Tee — fördert entspannte Wachheit und verstärkt die Fokus-Wirkung von Koffein.', icon: Icons.psychology_outlined, gradient: [Color(0xFF558B2F), Color(0xFF689F38)]),
    InsightCardData(tag: 'Supplement', title: 'Kreatin Monohydrat', text: 'Einer der bestuntersuchten Supplements überhaupt — steigert Kraft, Ausdauer und kognitive Leistung.', icon: Icons.fitness_center_outlined, gradient: [Color(0xFF6A1B9A), Color(0xFF7B1FA2)]),
    InsightCardData(tag: 'Supplement', title: 'Coenzym Q10', text: 'Kraftwerk der Mitochondrien. Besonders relevant ab 40 und bei Statin-Einnahme, die Q10 reduziert.', icon: Icons.bolt_outlined, gradient: [Color(0xFFC62828), Color(0xFFD32F2F)]),
    InsightCardData(tag: 'Supplement', title: 'B12 Methylcobalamin', text: 'Die bioverfügbarste Form von B12 — essenziell für Nerven, Blutbildung und Energiestoffwechsel.', icon: Icons.electric_bolt_outlined, gradient: [Color(0xFF1565C0), Color(0xFF1976D2)]),
    InsightCardData(tag: 'Supplement', title: 'Folsäure (Methylfolat)', text: 'Aktive Form der Folsäure — besonders wichtig in der Schwangerschaft und bei MTHFR-Genvariante.', icon: Icons.favorite_outline, gradient: [Color(0xFFAD1457), Color(0xFFC2185B)]),
  ];

  static const _trends = <InsightCardData>[
    InsightCardData(tag: 'Trend', title: 'Longevity-Stack 2025', text: 'NMN, Resveratrol und Spermidine gelten als vielversprechend für Zellerneuerung — Evidenz noch begrenzt.', icon: Icons.trending_up_outlined, gradient: [Color(0xFF00838F), Color(0xFF00ACC1)]),
    InsightCardData(tag: 'Trend', title: 'Adaptogene im Fokus', text: "Rhodiola, Ashwagandha und Lion's Mane gewinnen als stressreduzierende Naturmittel stark an Beliebtheit.", icon: Icons.eco_outlined, gradient: [Color(0xFF37474F), Color(0xFF455A64)]),
    InsightCardData(tag: 'Trend', title: 'Zirkadianer Rhythmus', text: 'Einnahmezeit macht den Unterschied — Forschung zeigt dass Timing die Wirkung vieler Supplements beeinflusst.', icon: Icons.schedule_outlined, gradient: [Color(0xFF4527A0), Color(0xFF512DA8)]),
    InsightCardData(tag: 'Trend', title: 'Mikrobiom & Probiotika', text: 'Darmgesundheit als Grundlage — Probiotika mit definierten Stämmen zeigen Wirkung auf Immunsystem und Stimmung.', icon: Icons.biotech_outlined, gradient: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
    InsightCardData(tag: 'Trend', title: 'Magnesium-Renaissance', text: 'Über 300 Enzymreaktionen benötigen Magnesium — L-Threonat gilt als beste Form für die Blut-Hirn-Schranke.', icon: Icons.auto_awesome_outlined, gradient: [Color(0xFF0D47A1), Color(0xFF1565C0)]),
    InsightCardData(tag: 'Trend', title: 'Personalisierung durch KI', text: 'Apps wie LifeLab kombinieren Blutbild, Profil und Studiendaten für individuell passende Empfehlungen.', icon: Icons.smart_toy_outlined, gradient: [Color(0xFF880E4F), Color(0xFFAD1457)]),
    InsightCardData(tag: 'Trend', title: 'Schlaf-Optimierung', text: 'Glycin, L-Theanin und Magnesium zeigen in Studien schlafverbessernde Effekte — ohne Abhängigkeitspotenzial.', icon: Icons.bedtime_outlined, gradient: [Color(0xFF1A237E), Color(0xFF283593)]),
  ];

  static const _superfoods = <InsightCardData>[
    InsightCardData(tag: 'Lebensmittel', title: 'Sardinen', text: 'Reich an Omega-3, Vitamin D, B12 und Calcium — eines der nährstoffdichtesten Lebensmittel überhaupt.', icon: Icons.set_meal_outlined, gradient: [Color(0xFF006064), Color(0xFF00838F)]),
    InsightCardData(tag: 'Lebensmittel', title: 'Leber (Rind)', text: "Natur's Multivitamin: extrem reich an B12, Eisen, Kupfer, Vitamin A und Folsäure — 1x pro Woche reicht.", icon: Icons.restaurant_outlined, gradient: [Color(0xFF8D1B1B), Color(0xFFB71C1C)]),
    InsightCardData(tag: 'Lebensmittel', title: 'Eier (Vollei)', text: 'Cholin für Gehirn, Lutein für Augen, hochwertiges Protein — Dotterphobien sind wissenschaftlich überholt.', icon: Icons.egg_outlined, gradient: [Color(0xFFF57F17), Color(0xFFF9A825)]),
    InsightCardData(tag: 'Lebensmittel', title: 'Blaubeeren', text: 'Anthocyane wirken antioxidativ und zeigen in Studien positive Effekte auf Gedächtnis und kognitive Funktion.', icon: Icons.grass_outlined, gradient: [Color(0xFF4527A0), Color(0xFF6A1B9A)]),
    InsightCardData(tag: 'Lebensmittel', title: 'Brokkoli', text: 'Sulforaphan aus Brokkoli aktiviert Entgiftungsenzyme — am stärksten in rohen oder leicht gedünsteten Sprossen.', icon: Icons.eco_outlined, gradient: [Color(0xFF2E7D32), Color(0xFF43A047)]),
    InsightCardData(tag: 'Lebensmittel', title: 'Walnüsse', text: 'Einzige Nuss mit relevanten Omega-3-Mengen (ALA) — plus Vitamin E und Polyphenole für Gefäßgesundheit.', icon: Icons.spa_outlined, gradient: [Color(0xFF4E342E), Color(0xFF6D4C41)]),
    InsightCardData(tag: 'Lebensmittel', title: 'Fermentierte Lebensmittel', text: 'Joghurt, Kefir, Kimchi und Sauerkraut liefern lebende Kulturen für ein diverses Mikrobiom.', icon: Icons.science_outlined, gradient: [Color(0xFF00695C), Color(0xFF00897B)]),
    InsightCardData(tag: 'Lebensmittel', title: 'Kurkuma + schwarzer Pfeffer', text: 'Curcumin allein schlecht bioverfügbar — Piperin aus Pfeffer erhöht die Aufnahme um bis zu 2000%.', icon: Icons.local_fire_department_outlined, gradient: [Color(0xFFE65100), Color(0xFFF57C00)]),
  ];

  int _dayIndex() {
    final now = DateTime.now();
    return now.difference(DateTime(now.year)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _dayIndex();
    final cards = [
      _supplements[idx % _supplements.length],
      _trends[idx % _trends.length],
      _superfoods[idx % _superfoods.length],
    ];

    final cardWidth = MediaQuery.of(context).size.width * 0.78;

    return SizedBox(
      height: 178,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          left: AppConstants.screenPaddingH,
          right: AppConstants.screenPaddingH,
          top: AppConstants.spaceM,
          bottom: AppConstants.spaceM,
        ),
        itemCount: cards.length,
        itemBuilder: (context, i) => Padding(
          padding:
              EdgeInsets.only(right: i < cards.length - 1 ? AppConstants.spaceM : 0),
          child: InsightCard(data: cards[i], width: cardWidth),
        ),
      ),
    );
  }
}
