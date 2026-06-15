import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/phase_goals_provider.dart';
import '../../domain/models/phase_goal.dart';

/// Home-Screen Panel für aktive Phasenziele.
/// Nur angezeigt wenn mindestens ein Ziel aktiv ist.
/// - Tap auf Panel-Header → PhaseGoalsScreen
/// - Tap auf Einzelziel → PhaseGoalDetailScreen
class PhaseGoalsHomePanel extends ConsumerWidget {
  const PhaseGoalsHomePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGoals = ref.watch(phaseGoalsProvider);
    if (activeGoals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header ---
        GestureDetector(
          onTap: () => context.push(AppRoutes.phaseGoals),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Aktive Phasenziele',
                      style: AppTextStyles.headlineSmall),
                  const SizedBox(width: AppConstants.spaceS),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusRound),
                    ),
                    child: Text(
                      '${activeGoals.length}',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Text(
                'Alle →',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spaceS),

        // --- Goal Cards ---
        ...activeGoals.map((goal) => Padding(
              padding:
                  const EdgeInsets.only(bottom: AppConstants.spaceS),
              child: _ActiveGoalCard(goal: goal),
            )),
      ],
    );
  }
}

class _ActiveGoalCard extends StatelessWidget {
  final ActivePhaseGoal goal;

  const _ActiveGoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final def = goal.definition;
    final accent = def?.accentColor ?? AppColors.primary;

    return GestureDetector(
      onTap: () =>
          context.push('${AppRoutes.phaseGoalDetail}/${goal.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: Icon(
                def?.icon ?? Icons.flag_outlined,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: AppConstants.spaceM),

            // Name + Fortschritt
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          def?.name ?? goal.definitionId,
                          style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${goal.remainingDays}d',
                        style: AppTextStyles.caption.copyWith(
                            color: accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusRound),
                    child: LinearProgressIndicator(
                      value: goal.progress,
                      minHeight: 5,
                      backgroundColor: accent.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${goal.elapsedDays} von ${goal.totalDays} Tagen',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppConstants.spaceS),
            const Icon(Icons.chevron_right,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}
