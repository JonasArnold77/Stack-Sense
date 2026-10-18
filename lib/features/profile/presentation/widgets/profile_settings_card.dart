import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/url_config_service.dart';
import '../../../../core/widgets/app_restart.dart';
import '../../../auth/data/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../settings/data/developer_mode_provider.dart';

/// Einstellungen-Card mit Benachrichtigungen, Datenschutz, Profil-Bearbeitung
/// und dem Developer-Mode-Schalter (blendet interne Test-/Debug-Einstellungen
/// wie Datenbank-/KI-Modus und Backend-URL ein/aus, siehe heute_screen.dart
/// und profile_screen.dart).
class ProfileSettingsCard extends ConsumerWidget {
  const ProfileSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDevMode = ref.watch(developerModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ProfileSettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Benachrichtigungen',
            onTap: () {},
          ),
          const Divider(height: 0, indent: 52),
          ProfileSettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Datenschutz',
            onTap: _openPrivacyPolicy,
          ),
          const Divider(height: 0, indent: 52),
          ProfileSettingsTile(
            icon: Icons.edit_outlined,
            label: 'Profil bearbeiten',
            onTap: () {},
          ),
          const Divider(height: 0, indent: 52),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: AppColors.error, size: 20),
            title: Text('Konto löschen',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
            onTap: () => _confirmDeleteAccount(context, ref),
            dense: true,
          ),
          const Divider(height: 0, indent: 52),
          SwitchListTile(
            secondary: const Icon(Icons.developer_mode_outlined,
                color: AppColors.textSecondary, size: 20),
            title: const Text('Developer Mode', style: AppTextStyles.bodyMedium),
            subtitle: Text(
              'Datenbank-/KI-Modus, Cache, Backend-URL u.a. einblenden',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
            value: isDevMode,
            onChanged: (value) =>
                ref.read(developerModeProvider.notifier).setEnabled(value),
            dense: true,
          ),
        ],
      ),
    );
  }
}

Future<void> _openPrivacyPolicy() {
  final origin = UrlConfigService.current.replaceFirst(RegExp(r'/api/v1$'), '');
  return launchUrl(Uri.parse('$origin/datenschutz'),
      mode: LaunchMode.externalApplication);
}

Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Konto löschen?'),
      content: const Text(
        'Dein Konto, dein Profil und alle gespeicherten Daten (Stack, '
        'Check-ins, Fortschritt) werden endgültig gelöscht. Das kann nicht '
        'rückgängig gemacht werden.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Endgültig löschen'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final error = await ref.read(authProvider.notifier).deleteAccount();
  if (!context.mounted) return;
  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  AppRestart.restart(context);
}

/// Einzelne Einstellungs-Zeile mit Chevron-Pfeil.
class ProfileSettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const ProfileSettingsTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(label, style: AppTextStyles.bodyMedium),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textTertiary,
        size: 20,
      ),
      onTap: onTap,
      dense: true,
    );
  }
}
