import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../stack/data/foundation_optimization_provider.dart';
import 'foundation_optimization_levels.dart';

/// Läuft automatisch auf, sobald der Nutzer den Heute-Screen sieht während
/// sich der Foundation- oder Optimization-Stand seit dem letzten Anzeigen
/// verändert hat (z.B. weil er zuvor über "Problemfelder" ein Supplement
/// hinzugefügt hat) — dunkler Hintergrund, die betroffene(n) Kachel(n)
/// vergrößert, Balken zählt live vom alten zum neuen Stand hoch. Tippen
/// schließt sofort, sonst schließt es kurz nach Animationsende von selbst.
///
/// Als eigener Layer über dem Scroll-Inhalt eingebaut (siehe heute_screen.dart)
/// statt die Kacheln selbst animieren zu lassen — die Kacheln in der Liste
/// zeigen dadurch IMMER den schlicht aktuellen Stand, die Feier ist ein
/// bewusst separates, kurzes Ereignis beim Ankommen auf dem Screen.
class LevelUpOverlay extends ConsumerStatefulWidget {
  const LevelUpOverlay({super.key});

  @override
  ConsumerState<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends ConsumerState<LevelUpOverlay> {
  bool _dismissed = false;
  bool _autoDismissScheduled = false;

  static const _animDuration = Duration(milliseconds: 1400);
  static const _holdAfter = Duration(milliseconds: 900);

  void _dismiss(LevelSnapshot current) {
    if (_dismissed) return;
    setState(() => _dismissed = true);
    ref.read(lastShownLevelsProvider.notifier).markShown(current);
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(foundationOptimizationProvider);
    final lastShown = ref.watch(lastShownLevelsProvider);
    final optimizationCount = result.activeOptimizationEntries.length;
    final current = LevelSnapshot(
      foundationScorePct: result.foundationScorePct,
      optimizationCount: optimizationCount,
    );

    // Nichts zu feiern: entweder noch nie ein Stand gemerkt (App-Kaltstart —
    // dann erst mal nur den Ist-Stand als Basislinie setzen, ohne Feier),
    // oder unverändert seit dem letzten Anzeigen.
    if (lastShown == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(lastShownLevelsProvider.notifier).markShown(current);
      });
      return const SizedBox.shrink();
    }

    final foundationChanged = lastShown.foundationScorePct != current.foundationScorePct;
    final optimizationChanged = lastShown.optimizationCount != current.optimizationCount;

    if (_dismissed || (!foundationChanged && !optimizationChanged)) {
      return const SizedBox.shrink();
    }

    if (!_autoDismissScheduled) {
      _autoDismissScheduled = true;
      Future.delayed(_animDuration + _holdAfter, () {
        if (mounted) _dismiss(current);
      });
    }

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _dismiss(current),
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            color: Colors.black.withOpacity(0.72),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.spaceL),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (foundationChanged)
                        _AnimatedCelebrationCard(
                          icon: Icons.foundation,
                          categoryLabel: 'Foundation',
                          color: FoundationOptimizationLevels.foundationColor,
                          colorDark: FoundationOptimizationLevels.foundationColorDark,
                          fromRaw: lastShown.foundationScorePct,
                          toRaw: current.foundationScorePct,
                          levelFor: foundationLevelFor,
                          duration: _animDuration,
                        ),
                      if (foundationChanged && optimizationChanged)
                        const SizedBox(height: AppConstants.spaceM),
                      if (optimizationChanged)
                        _AnimatedCelebrationCard(
                          icon: Icons.trending_up_rounded,
                          categoryLabel: 'Optimization',
                          color: FoundationOptimizationLevels.optimizationColor,
                          colorDark: FoundationOptimizationLevels.optimizationColorDark,
                          fromRaw: lastShown.optimizationCount.toDouble(),
                          toRaw: current.optimizationCount.toDouble(),
                          levelFor: (v) => optimizationLevelFor(v.round()),
                          duration: _animDuration,
                        ),
                      const SizedBox(height: AppConstants.spaceL),
                      Text(
                        'Zum Schließen tippen',
                        style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.55)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCelebrationCard extends StatefulWidget {
  final IconData icon;
  final String categoryLabel;
  final Color color;
  final Color colorDark;
  final double fromRaw;
  final double toRaw;
  final LevelInfo Function(double raw) levelFor;
  final Duration duration;

  const _AnimatedCelebrationCard({
    required this.icon,
    required this.categoryLabel,
    required this.color,
    required this.colorDark,
    required this.fromRaw,
    required this.toRaw,
    required this.levelFor,
    required this.duration,
  });

  @override
  State<_AnimatedCelebrationCard> createState() => _AnimatedCelebrationCardState();
}

class _AnimatedCelebrationCardState extends State<_AnimatedCelebrationCard>
    with TickerProviderStateMixin {
  late final AnimationController _countController;
  late final Animation<double> _countAnimation;
  // Eigener, kurzer Controller fürs "Aufblitzen" bei einem Levelaufstieg —
  // läuft unabhängig vom Zähl-Fortschritt, startet bei jedem Levelsprung neu.
  late final AnimationController _flashController;
  late int _lastSeenLevel;

  @override
  void initState() {
    super.initState();
    _lastSeenLevel = widget.levelFor(widget.fromRaw).level;

    _countController = AnimationController(vsync: this, duration: widget.duration)..forward();
    _countAnimation = CurvedAnimation(parent: _countController, curve: Curves.easeOutCubic);

    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));

    _countController.addListener(_checkForLevelUp);
  }

  void _checkForLevelUp() {
    final raw = widget.fromRaw + (widget.toRaw - widget.fromRaw) * _countAnimation.value;
    final currentLevel = widget.levelFor(raw).level;
    if (currentLevel > _lastSeenLevel) {
      _lastSeenLevel = currentLevel;
      _flashController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _countController.removeListener(_checkForLevelUp);
    _countController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_countAnimation, _flashController]),
      builder: (context, _) {
        final raw = widget.fromRaw + (widget.toRaw - widget.fromRaw) * _countAnimation.value;
        // 0 -> 1 in den ersten 35% der Flash-Dauer, dann sanft wieder auf 0 —
        // ein kurzes, klares Aufblitzen statt eines trägen Ein-/Ausblendens.
        final f = _flashController.value;
        final flashOpacity = f <= 0
            ? 0.0
            : f < 0.35
                ? Curves.easeOut.transform(f / 0.35)
                : Curves.easeIn.transform(1 - (f - 0.35) / 0.65);

        return LevelCard(
          icon: widget.icon,
          categoryLabel: widget.categoryLabel,
          color: widget.color,
          colorDark: widget.colorDark,
          level: widget.levelFor(raw),
          scale: 1.12,
          overlayOpacity: flashOpacity.clamp(0.0, 1.0) * 0.6,
        );
      },
    );
  }
}
