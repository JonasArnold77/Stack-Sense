import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';

/// Täglicher Check-in — Nutzer bewertet Energie, Schlaf, Fokus, Stimmung.
/// Jede Bewertung gibt XP und trägt zur Wirksamkeitsvermutung bei.
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final Map<String, int> _scores = {
    'Energie': 0,
    'Schlaf': 0,
    'Fokus': 0,
    'Stimmung': 0,
  };

  bool get _isComplete => _scores.values.every((v) => v > 0);

  void _submit() {
    // TODO: Scores speichern, XP gutschreiben, Wirksamkeitsvermutung berechnen
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Check-in gespeichert!'),
        content: const Text(
            '+${AppConstants.xpCheckin} XP für deinen heutigen Eintrag.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Super!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tages-Check-in')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // XP-Hinweis
            Container(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              decoration: BoxDecoration(
                color: AppColors.xpGold.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusM),
                border: Border.all(
                    color: AppColors.xpGold.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.xpGold, size: 20),
                  const SizedBox(width: AppConstants.spaceS),
                  Text(
                    '+${AppConstants.xpCheckin} XP für deinen Check-in heute',
                    style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.xpGold.withOpacity(0.8)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spaceXL),

            Text('Wie fühlst du dich heute?',
                style: AppTextStyles.headlineLarge),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              'Ehrliche Antworten helfen uns zu verstehen, '
              'welche Supplements bei dir wirken.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),

            const SizedBox(height: AppConstants.spaceXL),

            // Bewertungs-Karten
            ..._scores.keys.map((category) => Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppConstants.spaceL),
                  child: _RatingCard(
                    category: category,
                    value: _scores[category]!,
                    onChanged: (v) =>
                        setState(() => _scores[category] = v),
                  ),
                )),

            const SizedBox(height: AppConstants.spaceM),

            FilledButton(
              onPressed: _isComplete ? _submit : null,
              child: const Text('Check-in speichern'),
            ),

            if (!_isComplete) ...[
              const SizedBox(height: AppConstants.spaceS),
              Center(
                child: Text(
                  'Bitte alle 4 Kategorien bewerten.',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final String category;
  final int value;
  final void Function(int) onChanged;

  const _RatingCard({
    required this.category,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
          color:
              value > 0 ? AppColors.primary.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category, style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppConstants.spaceM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (index) {
                final score = index + 1;
                final selected = value == score;
                return GestureDetector(
                  onTap: () => onChanged(score),
                  child: AnimatedContainer(
                    duration: AppConstants.animFast,
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusM),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: selected
                              ? AppColors.textInverse
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sehr schlecht',
                  style: AppTextStyles.caption),
              Text('Sehr gut', style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}
