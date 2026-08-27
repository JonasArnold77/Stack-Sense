import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/wearable_health_provider.dart';

/// Bottom-Sheet: Auswahl der Smartwatch-Marke. Garmin und Android/Wear OS
/// laufen beide über Google Health Connect (Garmin Connect synchronisiert
/// dorthin) — Apple Watch ist deaktiviert, da das Projekt keine iOS-
/// Plattform hat.
class WearableConnectSheet extends ConsumerWidget {
  /// Context der aufrufenden Seite (z.B. InsightsScreen) — NICHT der eigene
  /// Sheet-Context. Der Sheet-Context wird beim Schließen des Bottom-Sheets
  /// sofort unmounted, noch bevor der (potenziell lange) Health-Connect-
  /// Berechtigungsdialog durchlaufen ist — Navigation danach müsste sonst
  /// über einen bereits toten Context laufen und würde beim `mounted`-Check
  /// stillschweigend verworfen (Ursache für "Fenster öffnet sich nicht").
  final BuildContext parentContext;

  const WearableConnectSheet({super.key, required this.parentContext});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => WearableConnectSheet(parentContext: context),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    await ref.read(wearableHealthProvider.notifier).connectAndFetch();
    if (parentContext.mounted) parentContext.push(AppRoutes.wearableData);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppConstants.spaceL,
        AppConstants.spaceM,
        AppConstants.spaceL,
        MediaQuery.of(context).padding.bottom + AppConstants.spaceL,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusL)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Smartwatch verbinden', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Über Google Health Connect — deine Uhr muss dorthin synchronisieren.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppConstants.spaceL),
          _WearableOption(
            icon: Icons.watch_outlined,
            label: 'Garmin',
            subtitle: 'Über Garmin Connect → Health Connect',
            onTap: () => _connect(context, ref),
          ),
          const SizedBox(height: AppConstants.spaceS),
          _WearableOption(
            icon: Icons.android_outlined,
            label: 'Android / Wear OS',
            subtitle: 'Direkt über Health Connect',
            onTap: () => _connect(context, ref),
          ),
          const SizedBox(height: AppConstants.spaceS),
          const _WearableOption(
            icon: Icons.apple,
            label: 'Apple Watch',
            subtitle: 'Benötigt iOS-App (noch nicht verfügbar)',
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _WearableOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  const _WearableOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.textPrimary : AppColors.textTertiary;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spaceM),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: AppConstants.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: AppTextStyles.labelMedium
                              .copyWith(fontWeight: FontWeight.w700, color: color)),
                      Text(subtitle,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
