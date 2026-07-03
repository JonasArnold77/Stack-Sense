import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// Milestone-Definitionen
// ---------------------------------------------------------------------------

const _kMilestones = [
  _Milestone(label: 'Start', emoji: '🌱', threshold: 0.0),
  _Milestone(label: 'Erste Zeichen', emoji: '✨', threshold: 0.25),
  _Milestone(label: 'Spürbar', emoji: '📈', threshold: 0.50),
  _Milestone(label: 'Optimiert', emoji: '🏆', threshold: 0.75),
];

class _Milestone {
  final String label;
  final String emoji;

  /// Ab welchem Fortschritts-Anteil gilt dieser Meilenstein als erreicht.
  final double threshold;

  const _Milestone({
    required this.label,
    required this.emoji,
    required this.threshold,
  });
}

// ---------------------------------------------------------------------------
// Öffentliches Widget
// ---------------------------------------------------------------------------

/// 4 Milestone-Dots die den Fortschritt eines Phasenziels ohne Zahlen
/// visualisieren. Der aktuelle Milestone ist hervorgehoben (größerer Dot
/// mit Glüh-Effekt), erledigte Dots sind gefüllt, zukünftige leer.
///
/// [progress] ist ein Wert zwischen 0.0 und 1.0.
/// [accent] ist die Akzentfarbe des Phasenziels.
class MilestoneDots extends StatelessWidget {
  final double progress;
  final Color accent;

  /// Ob die Labels unterhalb der Dots angezeigt werden sollen.
  final bool showLabels;

  /// Auf dunklem Hintergrund (z.B. Gradient-Header): weiße Labels + helle Linie.
  /// Auf hellem Hintergrund (z.B. Home-Panel Card): Accent-Labels + graue Linie.
  final bool onDark;

  const MilestoneDots({
    super.key,
    required this.progress,
    required this.accent,
    this.showLabels = true,
    this.onDark = true,
  });

  /// Index des aktuell aktiven Meilensteins (0–3).
  int get _activeMilestoneIndex {
    for (var i = _kMilestones.length - 1; i >= 0; i--) {
      if (progress >= _kMilestones[i].threshold) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeMilestoneIndex;

    return Row(
      children: List.generate(_kMilestones.length, (i) {
        final m = _kMilestones[i];
        final isDone = i <= active;
        final isCurrent = i == active;
        final isLast = i == _kMilestones.length - 1;

        final emptyLineColor = onDark
            ? Colors.white.withOpacity(0.2)
            : Colors.black.withOpacity(0.1);

        return Expanded(
          child: Row(
            children: [
              // Connector-Linie (links vom Dot, außer beim ersten)
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isDone ? accent.withOpacity(0.6) : emptyLineColor,
                  ),
                ),

              // Dot
              _MilestoneDot(
                milestone: m,
                isDone: isDone,
                isCurrent: isCurrent,
                accent: accent,
                showLabel: showLabels,
                onDark: onDark,
              ),

              // Connector-Linie (rechts vom Dot, außer beim letzten)
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: (i < active) ? accent.withOpacity(0.6) : emptyLineColor,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Einzelner Dot
// ---------------------------------------------------------------------------

class _MilestoneDot extends StatelessWidget {
  final _Milestone milestone;
  final bool isDone;
  final bool isCurrent;
  final Color accent;
  final bool showLabel;
  final bool onDark;

  const _MilestoneDot({
    required this.milestone,
    required this.isDone,
    required this.isCurrent,
    required this.accent,
    required this.showLabel,
    required this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    final dotSize = isCurrent ? 30.0 : 22.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glüh-Ring um den aktuellen Dot
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? dotSize + 8 : dotSize,
          height: isCurrent ? dotSize + 8 : dotSize,
          decoration: isCurrent
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.25),
                  border: Border.all(
                    color: accent.withOpacity(0.5),
                    width: 1.5,
                  ),
                )
              : null,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? (isCurrent ? accent : accent.withOpacity(0.6))
                    : (onDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.06)),
                border: Border.all(
                  color: isDone
                      ? (isCurrent
                          ? (onDark ? Colors.white.withOpacity(0.6) : Colors.white)
                          : accent.withOpacity(0.4))
                      : (onDark
                          ? Colors.white.withOpacity(0.3)
                          : Colors.black.withOpacity(0.15)),
                  width: isCurrent ? 2 : 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  milestone.emoji,
                  style: TextStyle(fontSize: isCurrent ? 14 : 10),
                ),
              ),
            ),
          ),
        ),

        // Label
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            milestone.label,
            style: AppTextStyles.caption.copyWith(
              color: onDark
                  ? (isDone
                      ? Colors.white.withOpacity(0.9)
                      : Colors.white.withOpacity(0.35))
                  : (isDone
                      ? accent
                      : Colors.black.withOpacity(0.3)),
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
