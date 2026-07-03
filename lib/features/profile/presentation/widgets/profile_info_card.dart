import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../onboarding/domain/models/user_profile.dart';

/// Zeigt Profil-Stammdaten (Alter, Geschlecht, Aktivität, Erkrankungen …).
class ProfileInfoCard extends StatelessWidget {
  final UserProfile profile;

  const ProfileInfoCard({super.key, required this.profile});

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
        children: [
          ProfileInfoTile(
            icon: Icons.cake_outlined,
            label: 'Alter',
            value: profile.age != null ? '${profile.age} Jahre' : '–',
          ),
          const Divider(height: 0),
          ProfileInfoTile(
            icon: Icons.person_outline,
            label: 'Geschlecht',
            value: _genderLabel(profile.gender),
          ),
          const Divider(height: 0),
          ProfileInfoTile(
            icon: Icons.fitness_center_outlined,
            label: 'Aktivität',
            value: _sportLabel(profile.sportLevel),
          ),
          if (profile.conditions.isNotEmpty) ...[
            const Divider(height: 0),
            ProfileInfoTile(
              icon: Icons.medical_information_outlined,
              label: 'Erkrankungen',
              value: profile.conditions.join(', '),
            ),
          ],
          if (profile.medications.isNotEmpty) ...[
            const Divider(height: 0),
            ProfileInfoTile(
              icon: Icons.medication_outlined,
              label: 'Medikamente',
              value: profile.medications.join(', '),
            ),
          ],
          const Divider(height: 0),
          ProfileInfoTile(
            icon: Icons.flag_outlined,
            label: 'Ziele',
            value: profile.goals.isNotEmpty ? profile.goals.join(', ') : '–',
            isLast: true,
          ),
        ],
      ),
    );
  }

  static String _genderLabel(Gender? g) => switch (g) {
        Gender.male => 'Männlich',
        Gender.female => 'Weiblich',
        Gender.diverse => 'Divers',
        null => '–',
      };

  static String _sportLabel(SportLevel? s) => switch (s) {
        SportLevel.none => 'Kaum aktiv',
        SportLevel.light => 'Leicht aktiv',
        SportLevel.moderate => 'Moderat aktiv',
        SportLevel.intense => 'Sehr aktiv',
        null => '–',
      };
}

/// Einzelne Zeile: Icon + Label + Wert.
class ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const ProfileInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceM),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppConstants.spaceM),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
