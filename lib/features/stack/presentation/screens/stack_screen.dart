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
import '../../../phase_goals/domain/models/phase_goal.dart';

// ---------------------------------------------------------------------------
// Sektions-Definitionen — Reihenfolge bestimmt die Anzeigereihenfolge
// ---------------------------------------------------------------------------

class _SectionDef {
  final String title;
  final IconData icon;
  final List<String> keywords; // Schlüsselwörter gegen categories matchen
  const _SectionDef(this.title, this.icon, this.keywords);
}

const _kSections = [
  _SectionDef('Basissupplementierung', Icons.foundation_outlined,
      ['basis', 'vitamin', 'mineral', 'mikronährstoff', 'allgemein', 'grundversorgung', 'vitamine', 'multivitamin']),
  _SectionDef('Schlaf & Entspannung', Icons.bedtime_outlined,
      ['schlaf', 'entspannung', 'ruhe', 'nacht', 'sleep', 'melatonin', 'relax']),
  _SectionDef('Fokus & Energie', Icons.bolt_outlined,
      ['fokus', 'energie', 'konzentration', 'kognition', 'mental', 'gehirn', 'brain']),
  _SectionDef('Sport & Regeneration', Icons.fitness_center_outlined,
      ['sport', 'regeneration', 'muskel', 'training', 'fitness', 'ausdauer', 'leistung', 'protein', 'kreatin']),
  _SectionDef('Immunsystem', Icons.shield_outlined,
      ['immun', 'abwehr', 'infekt', 'erkältung', 'immunsystem']),
  _SectionDef('Gelenke & Knochen', Icons.accessibility_new_outlined,
      ['gelenk', 'knochen', 'knorpel', 'arthrose', 'beweglichkeit', 'kollagen']),
  _SectionDef('Verdauung & Darm', Icons.eco_outlined,
      ['verdauung', 'darm', 'probiotik', 'prebiotik', 'mikrobiom', 'digestion']),
  _SectionDef('Hormonelles Wohlbefinden', Icons.balance_outlined,
      ['hormon', 'schilddrüse', 'zyklus', 'testosteron', 'östrogen', 'hashimoto']),
  _SectionDef('Stimmung & Psyche', Icons.self_improvement_outlined,
      ['stimmung', 'psyche', 'mood', 'angst', 'nerven', 'stress', 'burnout']),
];

/// Header-Typ für ein Phasenziel-Abschnitt in der flachen Item-Liste.
class _PhaseGoalHeader {
  final String name;
  final IconData icon;
  final Color accentColor;
  final DateTime endDate;
  const _PhaseGoalHeader({
    required this.name,
    required this.icon,
    required this.accentColor,
    required this.endDate,
  });
}

/// Gibt eine flache Liste aus Headern und StackEntry-Einträgen zurück:
/// - Reguläre Supplements → nach Sektions-Keywords gruppiert
/// - Unkategorisierte reguläre → "Basissupplementierung"
/// - Phase-Ziel-Supplements → eigene Gruppe pro Phasenziel am Ende
List<Object> _buildGroupedItems(List<StackEntry> stack) {
  // Phasenziel-Supplements separat herausziehen
  final phaseEntries = stack.where((e) => e.isTemporary).toList();
  final regularEntries = stack.where((e) => !e.isTemporary).toList();

  // Reguläre: nach Keywords zuordnen
  final assigned = <String, List<StackEntry>>{};
  final unassigned = <StackEntry>[];

  for (final entry in regularEntries) {
    bool found = false;
    for (final section in _kSections) {
      final matches = entry.categories.any((cat) =>
          section.keywords.any((kw) => cat.toLowerCase().contains(kw)));
      if (matches) {
        assigned.putIfAbsent(section.title, () => []).add(entry);
        found = true;
        break;
      }
    }
    if (!found) unassigned.add(entry);
  }

  final items = <Object>[];

  // Reguläre Sektionen in definierter Reihenfolge
  for (final section in _kSections) {
    final entries = assigned[section.title];
    if (entries != null && entries.isNotEmpty) {
      items.add(section);
      items.addAll(entries);
    }
  }

  // Unkategorisierte → Basissupplementierung (nicht "Sonstiges")
  if (unassigned.isNotEmpty) {
    items.add(const _SectionDef(
      'Basissupplementierung',
      Icons.foundation_outlined,
      [], // Keywords nicht nötig, wird direkt als Fallback gesetzt
    ));
    items.addAll(unassigned);
  }

  // Phasenziel-Supplements: gruppieren nach phaseGoalId
  if (phaseEntries.isNotEmpty) {
    final byGoal = <String, List<StackEntry>>{};
    for (final e in phaseEntries) {
      byGoal.putIfAbsent(e.phaseGoalId!, () => []).add(e);
    }
    for (final goalId in byGoal.keys) {
      final def = findDefinition(goalId);
      items.add(_PhaseGoalHeader(
        name: def?.name ?? 'Phasenziel',
        icon: def?.icon ?? Icons.flag_outlined,
        accentColor: def?.accentColor ?? AppColors.primary,
        endDate: byGoal[goalId]!
            .map((e) => e.phaseEndDate ?? DateTime.now())
            .reduce((a, b) => a.isAfter(b) ? a : b),
      ));
      items.addAll(byGoal[goalId]!);
    }
  }

  return items;
}

// ---------------------------------------------------------------------------

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
                  // --- Tab 1: Supplement-Liste (nach Kategorie gruppiert) ---
                  stack.isEmpty
                      ? _EmptyStack()
                      : _GroupedSupplementList(
                          stack: stack,
                          warningCount: warningCount,
                          onRemove: (id) =>
                              ref.read(stackProvider.notifier).remove(id),
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

// ---------------------------------------------------------------------------
// Gruppierte Supplement-Liste
// ---------------------------------------------------------------------------

class _GroupedSupplementList extends StatelessWidget {
  final List<StackEntry> stack;
  final int warningCount;
  final void Function(String id) onRemove;

  const _GroupedSupplementList({
    required this.stack,
    required this.warningCount,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildGroupedItems(stack);

    return Column(
      children: [
        if (warningCount > 0) _AttentionHeader(count: warningCount),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH,
              AppConstants.spaceS,
              AppConstants.screenPaddingH,
              AppConstants.spaceXL,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is _SectionDef) {
                return _SectionHeader(section: item, isFirst: index == 0);
              }
              if (item is _PhaseGoalHeader) {
                return _PhaseGoalSectionHeader(header: item, isFirst: index == 0);
              }
              final entry = item as StackEntry;
              return StackSupplementCard(
                entry: entry,
                onRemove: () => onRemove(entry.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Sektion-Überschrift mit Icon, Titel und dezenter Trennlinie.
class _SectionHeader extends StatelessWidget {
  final _SectionDef section;
  final bool isFirst;

  const _SectionHeader({required this.section, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? AppConstants.spaceM : AppConstants.spaceXL,
        bottom: AppConstants.spaceS,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: Icon(section.icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: AppConstants.spaceS),
          Text(
            section.title,
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

/// Erkennbarer Phasenziel-Header mit Accent-Farbe, Icon und verbleibender Zeit.
class _PhaseGoalSectionHeader extends StatelessWidget {
  final _PhaseGoalHeader header;
  final bool isFirst;

  const _PhaseGoalSectionHeader({required this.header, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    final daysLeft = header.endDate.difference(DateTime.now()).inDays;
    final daysText = daysLeft > 0 ? 'noch $daysLeft Tag${daysLeft == 1 ? '' : 'e'}' : 'endet heute';

    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? AppConstants.spaceM : AppConstants.spaceXL,
        bottom: AppConstants.spaceS,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical: AppConstants.spaceS,
        ),
        decoration: BoxDecoration(
          color: header.accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(color: header.accentColor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: header.accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              child: Icon(header.icon, size: 17, color: header.accentColor),
            ),
            const SizedBox(width: AppConstants.spaceS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header.name,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: header.accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Phasenziel · $daysText',
                    style: AppTextStyles.caption.copyWith(
                      color: header.accentColor.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.flag_outlined, size: 16, color: header.accentColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

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
