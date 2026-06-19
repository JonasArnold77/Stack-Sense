import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/gradient_screen_header.dart';
import '../../../../core/widgets/empty_state.dart';
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientScreenHeader(
              title: 'Mein Stack',
              subtitle: stack.isEmpty
                  ? 'Noch keine Supplements hinzugefügt'
                  : '${stack.length} Supplement${stack.length == 1 ? '' : 's'} aktiv',
              actions: [
                if (warningCount > 0)
                  GradientHeaderBadge(
                    label: '$warningCount Warnung${warningCount == 1 ? '' : 'en'}',
                    icon: Icons.warning_amber_rounded,
                  ),
                const SizedBox(width: AppConstants.spaceXS),
                GradientHeaderAction(
                  icon: Icons.add,
                  tooltip: 'Supplement hinzufügen',
                  onPressed: () => context.go(AppRoutes.recommendations),
                ),
              ],
              bottomPadding: 0,
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Color(0x99FFFFFF),
                indicatorColor: Colors.white,
                indicatorWeight: 2.5,
                dividerColor: Colors.transparent,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                tabs: [
                  Tab(text: 'Supplements'),
                  Tab(text: 'Kalender'),
                ],
              ),
            ),
            // TabBarView als Expanded in der Column
            Expanded(
              child: TabBarView(
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
    return EmptyState(
      icon: Icons.layers_outlined,
      iconColor: AppColors.primary,
      title: 'Dein Stack ist leer',
      subtitle:
          'Dein Stack sind alle Supplements die du täglich nimmst — '
          'übersichtlich mit Einnahmezeiten und Wirkungsanalyse.',
      steps: [
        emptyStateStep(
          icon: Icons.search_outlined,
          label: 'Wähle ein Ziel im Entdecken-Tab',
        ),
        emptyStateStep(
          icon: Icons.verified_outlined,
          label: 'Prüfe die Evidenz: Grün = belegt, Gelb = Hinweise, Rot = unbewiesen',
        ),
        emptyStateStep(
          icon: Icons.add_circle_outline,
          label: 'Füge passende Supplements zu deinem Stack hinzu',
        ),
      ],
      buttonLabel: 'Supplements entdecken',
      onButton: () => context.go(AppRoutes.recommendations),
    );
  }
}
