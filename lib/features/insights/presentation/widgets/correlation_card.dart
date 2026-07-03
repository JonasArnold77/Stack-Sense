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

    final bgColor = isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final borderColor = isPositive ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80);
    final textColor = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: textColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.dimension == 'Gesamt'
                      ? 'Seit du ${insight.supplementName} nimmst...'
                      : '${insight.dimension} · ${insight.supplementName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPositive
                      ? '${insight.dimension} verbesserte sich um $absChange% '
                          '(${insight.scoreBefore} → ${insight.scoreAfter})'
                      : '${insight.dimension} sank um $absChange% '
                          '(${insight.scoreBefore} → ${insight.scoreAfter})',
                  style: TextStyle(
                      fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                ),
                if (insight.daysAfter < 7)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Noch ${insight.daysAfter} Tag${insight.daysAfter == 1 ? '' : 'e'} Daten — Ergebnis wird präziser',
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
