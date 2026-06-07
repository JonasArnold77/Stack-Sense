import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/models/checkin_entry.dart';
import '../../data/checkin_provider.dart';
import '../../../gamification/data/xp_provider.dart';

/// Täglicher Check-in — 4 Metriken mit Emoji-Skala 1–5.
/// Nutzt Riverpod für Persistenz und Streak-Berechnung.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  int _energy = 3;
  int _sleep = 3;
  int _focus = 3;
  int _mood = 3;
  bool _submitted = false;
  bool _loading = false;
  bool _forceEdit = false; // Ermöglicht Korrektur wenn heute schon eingecheckt

  Future<void> _submit() async {
    setState(() => _loading = true);
    final entry = CheckinEntry(
      date: DateTime.now(),
      energy: _energy,
      sleep: _sleep,
      focus: _focus,
      mood: _mood,
    );
    await ref.read(checkinProvider.notifier).submit(entry);
    await ref.read(xpProvider.notifier).addXp(AppConstants.xpCheckin);
    if (mounted) {
      setState(() {
        _submitted = true;
        _loading = false;
        _forceEdit = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(checkinProvider.notifier);
    final alreadyDone = notifier.hasCheckedInToday && !_submitted && !_forceEdit;

    if (_submitted) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: _SuccessView(onClose: () => context.go(AppRoutes.stack)),
      );
    }

    if (alreadyDone) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: _AlreadyDoneView(
          entry: notifier.todayEntry!,
          onEdit: () => setState(() => _forceEdit = true),
          onClose: () => context.go(AppRoutes.stack),
        ),
      );
    }

    final streak = notifier.currentStreak;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _FormView(
        streak: streak,
        energy: _energy,
        sleep: _sleep,
        focus: _focus,
        mood: _mood,
        loading: _loading,
        onEnergyChanged: (v) => setState(() => _energy = v),
        onSleepChanged: (v) => setState(() => _sleep = v),
        onFocusChanged: (v) => setState(() => _focus = v),
        onMoodChanged: (v) => setState(() => _mood = v),
        onSubmit: _submit,
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text('Tages-Check-in'),
    );
  }
}

// ---------------------------------------------------------------------------
// Formular
// ---------------------------------------------------------------------------

class _FormView extends StatelessWidget {
  final int energy, sleep, focus, mood, streak;
  final bool loading;
  final ValueChanged<int> onEnergyChanged, onSleepChanged, onFocusChanged, onMoodChanged;
  final VoidCallback onSubmit;

  const _FormView({
    required this.energy,
    required this.sleep,
    required this.focus,
    required this.mood,
    required this.streak,
    required this.loading,
    required this.onEnergyChanged,
    required this.onSleepChanged,
    required this.onFocusChanged,
    required this.onMoodChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingH,
        vertical: AppConstants.screenPaddingV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak-Banner (nur anzeigen wenn Streak > 0)
          if (streak > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
                vertical: AppConstants.spaceS,
              ),
              decoration: BoxDecoration(
                color: AppColors.xpGold.withAlpha(25),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                border: Border.all(color: AppColors.xpGold.withAlpha(70)),
              ),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: AppConstants.spaceS),
                  Text(
                    '$streak ${streak == 1 ? 'Tag' : 'Tage'} Streak — weiter so!',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.xpGold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spaceL),
          ],
          Text('Wie fühlst du dich heute?', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppConstants.spaceXS),
          Text(
            'Deine ehrliche Einschätzung hilft dir, Fortschritte zu erkennen.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppConstants.spaceXL),
          _MetricCard(
            label: 'Energie',
            icon: Icons.bolt_outlined,
            value: energy,
            onChanged: onEnergyChanged,
          ),
          const SizedBox(height: AppConstants.spaceM),
          _MetricCard(
            label: 'Schlaf',
            icon: Icons.bedtime_outlined,
            value: sleep,
            onChanged: onSleepChanged,
          ),
          const SizedBox(height: AppConstants.spaceM),
          _MetricCard(
            label: 'Fokus',
            icon: Icons.center_focus_strong_outlined,
            value: focus,
            onChanged: onFocusChanged,
          ),
          const SizedBox(height: AppConstants.spaceM),
          _MetricCard(
            label: 'Stimmung',
            icon: Icons.favorite_border,
            value: mood,
            onChanged: onMoodChanged,
          ),
          const SizedBox(height: AppConstants.spaceXXL),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                backgroundColor: AppColors.primary,
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textInverse,
                      ),
                    )
                  : const Text('Check-in abschließen'),
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          Center(
            child: Text(
              '+${AppConstants.xpCheckin} XP für diesen Check-in',
              style: AppTextStyles.caption,
            ),
          ),
          const SizedBox(height: AppConstants.spaceL),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Einzelne Metrik-Karte mit Emoji-Auswahl
// ---------------------------------------------------------------------------

class _MetricCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value; // 1–5
  final ValueChanged<int> onChanged;

  const _MetricCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  static const _emojis = ['😞', '😕', '😐', '🙂', '😄'];
  static const _descriptions = ['Schlecht', 'Nicht gut', 'Ok', 'Gut', 'Super'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kopfzeile: Label + aktuelle Auswahl
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppConstants.spaceS),
              Text(label, style: AppTextStyles.labelLarge),
              const Spacer(),
              Text(
                '${_emojis[value - 1]}  ${_descriptions[value - 1]}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          // 5 Emoji-Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final score = index + 1;
              final selected = value == score;
              return GestureDetector(
                onTap: () => onChanged(score),
                child: AnimatedContainer(
                  duration: AppConstants.animFast,
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withAlpha(28)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: AppConstants.animFast,
                      style: TextStyle(fontSize: selected ? 28 : 22),
                      child: Text(_emojis[index]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Erfolgs-View nach dem Absenden
// ---------------------------------------------------------------------------

class _SuccessView extends StatelessWidget {
  final VoidCallback onClose;

  const _SuccessView({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 72)),
            const SizedBox(height: AppConstants.spaceL),
            Text('Check-in abgeschlossen!', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppConstants.spaceM),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceL,
                vertical: AppConstants.spaceS,
              ),
              decoration: BoxDecoration(
                color: AppColors.xpGold.withAlpha(30),
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                border: Border.all(color: AppColors.xpGold.withAlpha(80)),
              ),
              child: Text(
                '+${AppConstants.xpCheckin} XP verdient 🎉',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.xpGold),
              ),
            ),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              'Morgen wieder einchecken um deinen Streak zu halten.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceXL),
            FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Fertig'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// View wenn heute schon eingecheckt wurde
// ---------------------------------------------------------------------------

class _AlreadyDoneView extends StatelessWidget {
  final CheckinEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  const _AlreadyDoneView({
    required this.entry,
    required this.onEdit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spaceXL),
      child: Column(
        children: [
          const SizedBox(height: AppConstants.spaceL),
          const Text('📋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: AppConstants.spaceL),
          Text('Heute bereits eingecheckt', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppConstants.spaceXS),
          Text(
            'Du hast deinen Check-in für heute schon abgeschlossen.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spaceXL),
          // Zusammenfassung der heutigen Werte
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusL),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _SummaryTile('Energie', entry.energy, Icons.bolt_outlined),
                const Divider(height: AppConstants.spaceL),
                _SummaryTile('Schlaf', entry.sleep, Icons.bedtime_outlined),
                const Divider(height: AppConstants.spaceL),
                _SummaryTile('Fokus', entry.focus, Icons.center_focus_strong_outlined),
                const Divider(height: AppConstants.spaceL),
                _SummaryTile('Stimmung', entry.mood, Icons.favorite_border),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceXL),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Werte korrigieren'),
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Zurück'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  static const _emojis = ['😞', '😕', '😐', '🙂', '😄'];

  const _SummaryTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppConstants.spaceS),
        Text(label, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Text(_emojis[value - 1], style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppConstants.spaceS),
        Text(
          '$value/5',
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
