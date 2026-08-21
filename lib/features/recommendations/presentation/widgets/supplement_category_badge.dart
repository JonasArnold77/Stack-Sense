import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/supplement.dart';

/// Kompaktes Symbol für die Stoffklasse (Vitamine/Mineralstoffe/...) — wird
/// oben rechts auf der Supplement-Card gezeigt. Icon + kurzes Label in einem
/// Pill, damit die Bezeichnung erkennbar bleibt ohne viel Platz zu kosten.
class SupplementCategoryBadge extends StatelessWidget {
  final SubstanceCategory? category;

  const SupplementCategoryBadge({super.key, required this.category});

  static const Map<SubstanceCategory, Color> _colors = {
    SubstanceCategory.vitamine: Color(0xFFF59E0B),
    SubstanceCategory.mineralstoffe: Color(0xFF64748B),
    SubstanceCategory.omegaFettsaeuren: Color(0xFF0891B2),
    SubstanceCategory.aminosaeurenProtein: Color(0xFFDB2777),
    SubstanceCategory.pflanzlicheExtrakte: Color(0xFF16A34A),
    SubstanceCategory.darmVerdauung: Color(0xFF9333EA),
  };

  static const Map<SubstanceCategory, IconData> _icons = {
    SubstanceCategory.vitamine: Icons.wb_sunny_rounded,
    SubstanceCategory.mineralstoffe: Icons.diamond_rounded,
    SubstanceCategory.omegaFettsaeuren: Icons.opacity_rounded,
    SubstanceCategory.aminosaeurenProtein: Icons.fitness_center_rounded,
    SubstanceCategory.pflanzlicheExtrakte: Icons.spa_rounded,
    SubstanceCategory.darmVerdauung: Icons.bubble_chart_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cat = category;
    if (cat == null) return const SizedBox.shrink();

    final color = _colors[cat]!;
    final icon = _icons[cat]!;

    return Tooltip(
      message: cat.fullLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          border: Border.all(color: color.withOpacity(0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              cat.shortLabel,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 9,
                letterSpacing: 0.2,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
