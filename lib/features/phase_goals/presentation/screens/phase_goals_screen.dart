import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/phase_goals_provider.dart';
import '../../domain/models/phase_goal.dart';

/// Auswahl-Screen für Phasenziele.
/// Zeigt alle vordefinierten Ziele als 2-spaltiges Grid.
/// Multi-Select mit Checkbox-Optik; Button unten öffnet Duration-Picker
/// für jedes gewählte Ziel und aktiviert es dann.
class PhaseGoalsScreen extends ConsumerStatefulWidget {
  const PhaseGoalsScreen({super.key});

  @override
  ConsumerState<PhaseGoalsScreen> createState() => _PhaseGoalsScreenState();
}

class _PhaseGoalsScreenState extends ConsumerState<PhaseGoalsScreen> {
  /// Ausgewählte Definition-IDs
  final Set<String> _selected = {};

  void _toggle(String defId) {
    setState(() {
      if (_selected.contains(defId)) {
        _selected.remove(defId);
      } else {
        _selected.add(defId);
      }
    });
  }

  Future<void> _proceed() async {
    if (_selected.isEmpty) return;

    // Für jedes gewählte Ziel Duration-Picker anzeigen (sequentiell)
    final results = <({String defId, int days})>[];

    for (final defId in _selected) {
      final def = findDefinition(defId);
      if (def == null) continue;

      final days = await _showDurationPicker(def);
      if (days == null) return; // Nutzer hat abgebrochen → ganzen Flow abbrechen

      results.add((defId: defId, days: days));
    }

    if (!mounted) return;

    // Alle Ziele aktivieren und zu Empfehlungen navigieren
    final notifier = ref.read(phaseGoalsProvider.notifier);
    final activatedGoals = <ActivePhaseGoal>[];
    for (final r in results) {
      final goal = await notifier.activate(
          definitionId: r.defId, durationDays: r.days);
      activatedGoals.add(goal);
    }

    if (!mounted) return;

    // Zu Empfehlungen für das erste Ziel navigieren (alle weiteren sind als active gesetzt)
    final firstGoal = activatedGoals.first;
    context.push(
      '${AppRoutes.phaseGoalRecommendations}/${firstGoal.id}',
    );
  }

  Future<int?> _showDurationPicker(PhaseGoalDefinition def) async {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DurationPickerSheet(definition: def),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeGoals = ref.watch(phaseGoalsProvider);
    final activeDefIds = activeGoals.map((g) => g.definitionId).toSet();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Header ---
          _PhaseGoalsHeader(onBack: () => context.pop()),

          // --- Grid ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.screenPaddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Erklärungs-Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4527A0).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF4527A0).withOpacity(0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flag_outlined,
                                size: 18, color: Color(0xFF4527A0)),
                            const SizedBox(width: 8),
                            const Text(
                              'Was sind Phasenziele?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4527A0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Phasenziele sind zeitlich begrenzte Programme — z.B. "Muskelaufbau für 8 Wochen". '
                          'Du bekommst passende Supplements und verfolgst deinen Fortschritt.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4527A0),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: const [
                            _PhaseStep(number: '1', text: 'Ziel wählen'),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward,
                                size: 12, color: Color(0xFF7E57C2)),
                            SizedBox(width: 6),
                            _PhaseStep(number: '2', text: 'Dauer festlegen'),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward,
                                size: 12, color: Color(0xFF7E57C2)),
                            SizedBox(width: 6),
                            _PhaseStep(number: '3', text: 'Supplements starten'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceL),

                  Text(
                    'Wähle deine aktuelle Lebensphase',
                    style: AppTextStyles.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Du kannst mehrere Ziele gleichzeitig aktivieren.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppConstants.spaceL),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppConstants.spaceS,
                    mainAxisSpacing: AppConstants.spaceS,
                    childAspectRatio: 0.9,
                    children: kPhaseGoalDefinitions.map((def) {
                      final isSelected = _selected.contains(def.id);
                      final isAlreadyActive = activeDefIds.contains(def.id);
                      return _GoalTile(
                        definition: def,
                        isSelected: isSelected,
                        isAlreadyActive: isAlreadyActive,
                        onTap: isAlreadyActive ? null : () => _toggle(def.id),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 100), // Platz für den Button
                ],
              ),
            ),
          ),
        ],
      ),

      // --- Floating Button ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AnimatedSwitcher(
        duration: AppConstants.animFast,
        child: _selected.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.screenPaddingH),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _proceed,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(
                      _selected.length == 1
                          ? '1 Ziel aktivieren →'
                          : '${_selected.length} Ziele aktivieren →',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _PhaseGoalsHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _PhaseGoalsHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: EdgeInsets.only(
        top: topPadding + AppConstants.spaceM,
        left: AppConstants.screenPaddingH,
        right: AppConstants.screenPaddingH,
        bottom: AppConstants.spaceXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text('Zurück',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text(
            'Phasenziele',
            style: AppTextStyles.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Temporäre Supplement-Anpassungen für deine aktuelle Lebensphase.',
            style:
                AppTextStyles.bodySmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kachel
// ---------------------------------------------------------------------------

class _PhaseStep extends StatelessWidget {
  final String number;
  final String text;
  const _PhaseStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF4527A0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4527A0))),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  final PhaseGoalDefinition definition;
  final bool isSelected;
  final bool isAlreadyActive;
  final VoidCallback? onTap;

  const _GoalTile({
    required this.definition,
    required this.isSelected,
    required this.isAlreadyActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = definition.accentColor;
    final effectiveSelected = isSelected || isAlreadyActive;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: effectiveSelected
              ? accent.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(
            color: effectiveSelected
                ? accent
                : AppColors.border,
            width: effectiveSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(effectiveSelected ? 0.18 : 0.1),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: Icon(
                    definition.icon,
                    color: accent,
                    size: 20,
                  ),
                ),
                const Spacer(),
                if (isAlreadyActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.evidenceGreen.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusRound),
                    ),
                    child: Text(
                      'Aktiv',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.evidenceGreen,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  AnimatedContainer(
                    duration: AppConstants.animFast,
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected ? accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: isSelected ? accent : AppColors.border,
                          width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
              ],
            ),

            const Spacer(),

            // Name
            Text(
              definition.name,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: effectiveSelected ? accent : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Beschreibung
            Text(
              definition.description,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Duration Picker BottomSheet
// ---------------------------------------------------------------------------

class _DurationPickerSheet extends StatefulWidget {
  final PhaseGoalDefinition definition;

  const _DurationPickerSheet({required this.definition});

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  static const _presets = [
    (label: '1 Woche', days: 7),
    (label: '2 Wochen', days: 14),
    (label: '3 Wochen', days: 21),
    (label: '4 Wochen', days: 28),
    (label: '6 Wochen', days: 42),
    (label: '3 Monate', days: 90),
  ];

  late int _selectedDays;

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.definition.defaultDurationDays;
  }

  String _formatDays(int d) {
    if (d % 7 == 0) {
      final w = d ~/ 7;
      return w == 1 ? '1 Woche' : '$w Wochen';
    }
    return '$d Tage';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.definition.accentColor;
    final endDate =
        DateTime.now().add(Duration(days: _selectedDays));
    final endStr =
        '${endDate.day}.${endDate.month}.${endDate.year}';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        AppConstants.spaceL,
        AppConstants.screenPaddingH,
        AppConstants.spaceL + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceL),

          // Titel
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
                child: Icon(widget.definition.icon, color: accent, size: 20),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.definition.name,
                        style: AppTextStyles.labelLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text('Wie lange soll dieses Ziel gelten?',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spaceL),

          // Preset-Chips
          Wrap(
            spacing: AppConstants.spaceS,
            runSpacing: AppConstants.spaceS,
            children: _presets.map((p) {
              final isSelected = p.days == _selectedDays;
              return GestureDetector(
                onTap: () => setState(() => _selectedDays = p.days),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withOpacity(0.1)
                        : AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusRound),
                    border: Border.all(
                      color: isSelected ? accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    p.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isSelected ? accent : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppConstants.spaceL),

          // Aktueller Zeitrahmen Anzeige
          Container(
            padding: const EdgeInsets.all(AppConstants.spaceM),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(color: accent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: accent),
                const SizedBox(width: AppConstants.spaceS),
                Expanded(
                  child: Text(
                    '${_formatDays(_selectedDays)} · endet am $endStr',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spaceL),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selectedDays),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Ziel für ${_formatDays(_selectedDays)} aktivieren'),
            ),
          ),
        ],
      ),
    );
  }
}
