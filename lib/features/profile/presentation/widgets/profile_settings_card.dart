import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Einstellungen-Card mit Benachrichtigungen, Datenschutz und Profil-Bearbeitung.
class ProfileSettingsCard extends StatelessWidget {
  const ProfileSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
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
            onTap: () {},
          ),
          const Divider(height: 0, indent: 52),
          ProfileSettingsTile(
            icon: Icons.edit_outlined,
            label: 'Profil bearbeiten',
            onTap: () {},
            isLast: true,
          ),
        ],
      ),
    );
  }
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
