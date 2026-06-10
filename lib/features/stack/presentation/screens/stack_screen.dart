import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../recommendations/domain/models/supplement.dart';
import '../../data/stack_provider.dart';
import '../../domain/models/stack_entry.dart';
import '../widgets/stack_supplement_card.dart';
import '../widgets/intake_calendar.dart';

/// Mein Stack — zeigt alle aktiven Supplements und den Einnahme-Kalender.
/// Header zeigt Aufmerksamkeits-Count wenn Warnungen vorhanden.
class StackScreen extends ConsumerWidget {
  const StackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(stackProvider);

    // Zähle Supplements mit Wechselwirkungswarnung
    final warningCount = stack
        .where((e) =>
            e.interactionSeverity != InteractionSeverity.none &&
            e.drugInteraction != null)
        .length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mein Stack'),
          actions: [
            if (stack.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: AppConstants.spaceS),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusRound),
                    ),
                    child: Text(
                      '${stack.length} Supplements',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Supplement hinzufügen',
              onPressed: () => context.go(AppRoutes.recommendations),
            ),
          ],
          bottom: TabBar(
            labelStyle: AppTextStyles.labelMedium,
            unselectedLabelStyle: AppTextStyles.labelMedium
                .copyWith(color: AppColors.textSecondary),
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Supplements'),
              Tab(text: 'Kalender'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- Tab 1: Supplement-Liste ---
            stack.isEmpty
                ? _EmptyStack()
                : Column(
                    children: [
                      // Aufmerksamkeits-Header (nur wenn Warnungen vorhanden)
                      if (warningCount > 0)
                        _AttentionHeader(count: warningCount),

                      // Supplement-Cards
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(
                              AppConstants.screenPaddingH),
                          itemCount: stack.length,
                          itemBuilder: (context, index) {
                            final entry = stack[index];
                            return StackSupplementCard(
                              entry: entry,
                              onRemove: () => ref
                                  .read(stackProvider.notifier)
                                  .remove(entry.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

            // --- Tab 2: Kalender ---
            SingleChildScrollView(
              padding:
                  const EdgeInsets.all(AppConstants.screenPaddingH),
              child: const IntakeCalendar(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aufmerksamkeits-Header — zeigt wie viele Supplements Hinweise haben.
class _AttentionHeader extends StatelessWidget {
  final int count;
  const _AttentionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        AppConstants.screenPaddingV,
        AppConstants.screenPaddingH,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceM,
        vertical: AppConstants.spaceM,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: const Color(0xFFFFCC02), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: Color(0xFFF57F17)),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: Text(
              count == 1
                  ? '1 Supplement benötigt Aufmerksamkeit'
                  : '$count Supplements benötigen Aufmerksamkeit',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFFF57F17),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, size: 72, color: AppColors.border),
            const SizedBox(height: AppConstants.spaceL),
            Text('Dein Stack ist noch leer',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              'Gehe zu "Entdecken" um Supplements '
              'zu deinem Stack hinzuzufügen.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceXL),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.recommendations),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Entdecken'),
            ),
          ],
        ),
      ),
    );
  }
}
