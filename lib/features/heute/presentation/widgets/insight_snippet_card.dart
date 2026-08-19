import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../checkin/data/problem_checkin_provider.dart';
import '../../../insights/domain/models/insight_data.dart';

// ---------------------------------------------------------------------------
// Mapping: Problemfeld → Korrelations-Dimensions-Label
// ---------------------------------------------------------------------------

String _fieldToDimLabel(String fieldId) => switch (fieldId) {
  'Schlaf'   => 'Schlaf',
  'Energie'  => 'Energie',
  'Sport'    => 'Energie',
  'Fokus'    => 'Fokus',
  'Stimmung' => 'Stimmung',
  _          => 'Gesamt',
};

// ---------------------------------------------------------------------------
// Multi-Insight Widget (Home Screen)
// ---------------------------------------------------------------------------

/// Zeigt pro aktivem Problemfeld den besten Korrelations-Insight.
/// Maximal 3 Einträge — eines pro Zielbereich des Nutzers.
class MultiInsightSnippets extends ConsumerWidget {
  final InsightsData insights;

  const MultiInsightSnippets({super.key, required this.insights});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFields = ref.watch(activeProblemFieldsProvider);

    // Distinct dimension labels in Reihenfolge der aktiven Felder ableiten
    final seen = <String>{};
    final dimLabels = <String>[];
    for (final f in activeFields) {
      final dim = _fieldToDimLabel(f);
      if (seen.add(dim)) dimLabels.add(dim);
    }
    if (dimLabels.isEmpty) dimLabels.add('Gesamt');

    // Beste positive, signifikante Korrelation pro Dimension
    final snippets = <CorrelationInsight>[];
    for (final dim in dimLabels) {
      final candidates = insights.correlations
          .where((c) => c.dimension == dim && c.isPositive && c.isSignificant)
          .toList()
        ..sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));
      if (candidates.isNotEmpty) snippets.add(candidates.first);
      if (snippets.length >= 3) break;
    }

    // Fallback: alle positiven Korrelationen wenn kein Dim-Treffer
    if (snippets.isEmpty) {
      final fallback = insights.correlations
          .where((c) => c.isPositive && c.isSignificant)
          .toList()
        ..sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));
      snippets.addAll(fallback.take(2));
    }

    if (snippets.isEmpty) return const SizedBox.shrink();

    return Column(
      children: snippets
          .map((c) => _InsightSnippetRow(insight: c))
          .toList(),
    );
  }
}

class _InsightSnippetRow extends StatelessWidget {
  final CorrelationInsight insight;
  const _InsightSnippetRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    final dimLabel = switch (insight.dimension) {
      'Energie'  => 'Energie ⚡',
      'Schlaf'   => 'Schlaf 😴',
      'Fokus'    => 'Fokus 🧠',
      'Stimmung' => 'Stimmung 😊',
      _          => insight.dimension,
    };
    final changeStr =
        '+${insight.changePercent.toStringAsFixed(0)}%';
    final titleText = insight.isGrouped
        ? '${insight.supplementName} wirken'
        : '${insight.supplementName} wirkt';

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.evidenceGreenLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.evidenceGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.evidenceGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
            child: const Center(
              child: Text('📈', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: AppTextStyles.labelMedium
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dimLabel hat sich um $changeStr verbessert.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spaceS),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.evidenceGreen.withOpacity(0.15),
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusRound),
            ),
            child: Text(
              changeStr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.evidenceGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single-Insight Card (Legacy, bleibt für mögliche Wiederverwendung)
// ---------------------------------------------------------------------------

/// Zeigt die stärkste positive Korrelation als kompakten Insight-Hinweis.
class InsightSnippetCard extends StatelessWidget {
  final InsightsData insights;

  const InsightSnippetCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final positives = insights.correlations
        .where((c) => c.isPositive && c.isSignificant)
        .toList()
      ..sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));

    if (positives.isEmpty) return const SizedBox.shrink();

    final best = positives.first;
    final dimLabel = switch (best.dimension) {
      'Energie'  => 'Energie ⚡',
      'Schlaf'   => 'Schlaf 😴',
      'Fokus'    => 'Fokus 🧠',
      'Stimmung' => 'Stimmung 😊',
      _          => best.dimension,
    };
    final changeStr =
        '${best.changePercent >= 0 ? '+' : ''}${best.changePercent.toStringAsFixed(0)}%';

    // Plural-korrekte Formulierung für Gruppen
    final titleText = best.isGrouped
        ? '${best.supplementName} wirken'
        : '${best.supplementName} wirkt';

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: AppColors.evidenceGreenLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.evidenceGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.evidenceGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
            child: const Center(
              child: Text('📈', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: AppTextStyles.labelLarge
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '$dimLabel hat sich um $changeStr verbessert.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
