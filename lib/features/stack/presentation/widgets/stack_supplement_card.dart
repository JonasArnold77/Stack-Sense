import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/stack_entry.dart';
import '../../../recommendations/domain/models/supplement.dart';

/// Card für einen Eintrag im Stack des Nutzers.
///
/// Hintergrundfarbe = Evidenzstufe (grün/gelb/rot, dezent).
/// Warnfeld unten = Wechselwirkungsschwere (gelb/orange/rot, auffällig).
class StackSupplementCard extends StatelessWidget {
  final StackEntry entry;
  final VoidCallback onRemove;

  const StackSupplementCard({
    super.key,
    required this.entry,
    required this.onRemove,
  });

  // --- Evidenz-Hintergrundfarbe (dezent) ---
  Color _cardBg() => switch (entry.evidenceLevel) {
        EvidenceLevel.green => const Color(0xFFECF8F1), // sehr helles Grün
        EvidenceLevel.yellow => const Color(0xFFFFFBEB), // sehr helles Gelb
        EvidenceLevel.red => const Color(0xFFFEF0F0),   // sehr helles Rot
      };

  Color _cardBorder() => switch (entry.evidenceLevel) {
        EvidenceLevel.green => const Color(0xFFB8E8CC),
        EvidenceLevel.yellow => const Color(0xFFFFE08A),
        EvidenceLevel.red => const Color(0xFFFFB8B8),
      };

  Color _evidenceDot() => switch (entry.evidenceLevel) {
        EvidenceLevel.green => AppColors.evidenceGreen,
        EvidenceLevel.yellow => AppColors.evidenceYellow,
        EvidenceLevel.red => AppColors.evidenceRed,
      };

  String _evidenceLabel() => switch (entry.evidenceLevel) {
        EvidenceLevel.green => AppConstants.evidenceGreenLabel,
        EvidenceLevel.yellow => AppConstants.evidenceYellowLabel,
        EvidenceLevel.red => AppConstants.evidenceRedLabel,
      };

  // --- Warnfeld-Farben nach Schwere ---
  Color? _warnBg() => switch (entry.interactionSeverity) {
        InteractionSeverity.timing => const Color(0xFFFFFDE7),
        InteractionSeverity.moderate => const Color(0xFFFFF3E0),
        InteractionSeverity.high => const Color(0xFFFFEBEE),
        InteractionSeverity.none => null,
      };

  Color? _warnBorder() => switch (entry.interactionSeverity) {
        InteractionSeverity.timing => const Color(0xFFF9A825),
        InteractionSeverity.moderate => const Color(0xFFEF6C00),
        InteractionSeverity.high => const Color(0xFFC62828),
        InteractionSeverity.none => null,
      };

  Color? _warnIcon() => switch (entry.interactionSeverity) {
        InteractionSeverity.timing => const Color(0xFFF9A825),
        InteractionSeverity.moderate => const Color(0xFFEF6C00),
        InteractionSeverity.high => const Color(0xFFC62828),
        InteractionSeverity.none => null,
      };

  String? _warnTitle() => switch (entry.interactionSeverity) {
        InteractionSeverity.timing => 'Einnahme-Timing beachten',
        InteractionSeverity.moderate => 'Arzt-Rücksprache empfohlen',
        InteractionSeverity.high => 'Starke Wechselwirkung',
        InteractionSeverity.none => null,
      };

  bool get _hasWarning =>
      entry.interactionSeverity != InteractionSeverity.none &&
      entry.drugInteraction != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      decoration: BoxDecoration(
        color: _cardBg(),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: _cardBorder()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header: Name + Badges + Remove ---
          Padding(
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Evidenz-Dot
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _evidenceDot(),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spaceS),

                // Name + Substanz + Evidenz-Label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name, style: AppTextStyles.headlineSmall),
                      if (entry.substanceName != null)
                        Text(entry.substanceName!,
                            style: AppTextStyles.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        _evidenceLabel(),
                        style: AppTextStyles.caption.copyWith(
                          color: _evidenceDot(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (entry.isTemporary && entry.phaseEndDate != null) ...[
                        const SizedBox(height: 4),
                        _TemporaryBadge(endDate: entry.phaseEndDate!),
                      ],
                    ],
                  ),
                ),

                // Slot Badge
                _SlotBadge(slot: entry.intakeSlot),

                const SizedBox(width: AppConstants.spaceXS),

                // Entfernen
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.textTertiary, size: 20),
                  tooltip: 'Aus Stack entfernen',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // --- Dosierung + Einnahme-Hinweis ---
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.cardPadding,
              0,
              AppConstants.cardPadding,
              AppConstants.cardPadding,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
                vertical: AppConstants.spaceS,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                border: Border.all(color: Colors.white.withOpacity(0.8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.scale_outlined,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: AppConstants.spaceS),
                  Expanded(
                    child: Text(
                      entry.dosage,
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (entry.intakeHint != null) ...[
                    const SizedBox(width: AppConstants.spaceS),
                    const Icon(Icons.info_outline,
                        size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: AppConstants.spaceXS),
                    Flexible(
                      child: Text(
                        entry.intakeHint!,
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // --- Wechselwirkungs-Warnfeld ---
          if (_hasWarning)
            _WarningField(
              title: _warnTitle()!,
              text: entry.drugInteraction!,
              bgColor: _warnBg()!,
              borderColor: _warnBorder()!,
              iconColor: _warnIcon()!,
              severity: entry.interactionSeverity,
            ),

          // --- Duplikat-Warnfeld (oranger Hinweis bei "Beides behalten") ---
          if (entry.hasDuplicateWarning)
            _WarningField(
              title: 'Wirkstoff doppelt vorhanden',
              text: 'Überdosierung möglich — überprüfe deinen Stack.',
              bgColor: const Color(0xFFFFF3E0),
              borderColor: const Color(0xFFEF6C00),
              iconColor: const Color(0xFFEF6C00),
              severity: InteractionSeverity.moderate,
            ),
        ],
      ),
    );
  }
}

/// Farbiges Warnfeld innerhalb der Card.
class _WarningField extends StatelessWidget {
  final String title;
  final String text;
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final InteractionSeverity severity;

  const _WarningField({
    required this.title,
    required this.text,
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.severity,
  });

  IconData get _icon => switch (severity) {
        InteractionSeverity.high => Icons.error_outline,
        InteractionSeverity.moderate => Icons.warning_amber_outlined,
        _ => Icons.access_time_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.cardPadding,
        0,
        AppConstants.cardPadding,
        AppConstants.cardPadding,
      ),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titel-Zeile mit Icon
          Row(
            children: [
              Icon(_icon, size: 16, color: iconColor),
              const SizedBox(width: AppConstants.spaceS),
              Text(
                title,
                style: AppTextStyles.bodySmall.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceXS),
          // Warn-Text
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: iconColor.withOpacity(0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotBadge extends StatelessWidget {
  final IntakeSlot slot;
  const _SlotBadge({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '${slot.emoji} ${slot.label}',
        style: AppTextStyles.caption,
      ),
    );
  }
}

/// Lila Badge für temporäre Phasenziel-Supplements.
class _TemporaryBadge extends StatelessWidget {
  final DateTime endDate;
  const _TemporaryBadge({required this.endDate});

  static const _accent = Color(0xFF5C35CC);

  String get _formatted =>
      '${endDate.day.toString().padLeft(2, '0')}.${endDate.month.toString().padLeft(2, '0')}.${endDate.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: _accent.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_outlined, size: 10, color: _accent),
          const SizedBox(width: 3),
          Text(
            'Temporär · bis $_formatted',
            style: AppTextStyles.caption.copyWith(
              color: _accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
