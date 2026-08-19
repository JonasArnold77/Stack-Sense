import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/insight_data.dart';

class InsightsCorrelationCard extends StatelessWidget {
  final CorrelationInsight insight;

  const InsightsCorrelationCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final isPositive = insight.isPositive;
    final absChange = insight.changePercent.abs().toStringAsFixed(0);
    final changeStr = '${isPositive ? '+' : '−'}$absChange%';

    final bgColor     = isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final borderColor = isPositive ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80);
    final textColor   = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final icon        = isPositive ? Icons.trending_up : Icons.trending_down;

    // Lesbarer Titel: Supplement-Name(n)
    final title = insight.supplementName; // "Melatonin" oder "Melatonin und Magnesium"

    // Hauptaussage: vollständiger natürlicher Satz
    final dim = insight.dimension == 'Gesamt' ? 'Deine Werte' : insight.dimension;
    final direction = isPositive ? 'verbessert' : 'verschlechtert';
    final mainText = '$dim hat sich seit $title um $changeStr $direction'
        ' (${insight.scoreBefore} → ${insight.scoreAfter})';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon ──
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: textColor),
          ),
          const SizedBox(width: 12),

          // ── Text ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Supplement-Name(n) als fetter Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // Badge wenn gruppiert
                    if (insight.isGrouped)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Kombi',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),

                // Hauptaussage
                Text(
                  mainText,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Hinweis wenn noch wenig Daten
                if (insight.daysAfter < 7)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Erst ${insight.daysAfter} Tag${insight.daysAfter == 1 ? '' : 'e'} Daten — wird präziser',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
