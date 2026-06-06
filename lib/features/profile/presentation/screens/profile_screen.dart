import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../onboarding/data/onboarding_provider.dart';
import '../../../onboarding/domain/models/user_profile.dart';

/// Profil-Screen — zeigt Nutzer-Level, XP, Profil-Daten und Einstellungen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Level / XP Card ---
            _LevelCard(),

            const SizedBox(height: AppConstants.spaceL),

            // --- Profil-Daten ---
            Text('Mein Profil', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppConstants.spaceM),
            _ProfileInfoCard(profile: profile),

            const SizedBox(height: AppConstants.spaceL),

            // --- Einstellungen ---
            Text('Einstellungen', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppConstants.spaceM),
            _SettingsCard(),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Echte XP/Level aus Provider
    const int currentXp = 45;
    const int xpToNextLevel = 100;
    const int currentLevel = 1;
    const String levelTitle = 'Einsteiger';

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusM),
                ),
                child: Center(
                  child: Text(
                    '$currentLevel',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $currentLevel · $levelTitle',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$currentXp / $xpToNextLevel XP',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.bolt, color: AppColors.xpGold, size: 28),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          // XP Progress Bar
          ClipRRect(
            borderRadius:
                BorderRadius.circular(AppConstants.radiusRound),
            child: LinearProgressIndicator(
              value: currentXp / xpToNextLevel,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.xpGold),
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          Text(
            '${xpToNextLevel - currentXp} XP bis Level ${currentLevel + 1}',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final UserProfile profile;
  const _ProfileInfoCard({required this.profile});

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
          _InfoTile(
            icon: Icons.cake_outlined,
            label: 'Alter',
            value: profile.age != null ? '${profile.age} Jahre' : '–',
          ),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Geschlecht',
            value: _genderLabel(profile.gender),
          ),
          _InfoTile(
            icon: Icons.fitness_center_outlined,
            label: 'Aktivität',
            value: _sportLabel(profile.sportLevel),
          ),
          if (profile.conditions.isNotEmpty)
            _InfoTile(
              icon: Icons.medical_information_outlined,
              label: 'Erkrankungen',
              value: profile.conditions.join(', '),
            ),
          _InfoTile(
            icon: Icons.flag_outlined,
            label: 'Ziele',
            value: profile.goals.isNotEmpty
                ? profile.goals.join(', ')
                : '–',
            isLast: true,
          ),
        ],
      ),
    );
  }

  String _genderLabel(Gender? g) => switch (g) {
        Gender.male => 'Männlich',
        Gender.female => 'Weiblich',
        Gender.diverse => 'Divers',
        null => '–',
      };

  String _sportLabel(SportLevel? s) => switch (s) {
        SportLevel.none => 'Kaum aktiv',
        SportLevel.light => 'Leicht aktiv',
        SportLevel.moderate => 'Moderat aktiv',
        SportLevel.intense => 'Sehr aktiv',
        null => '–',
      };
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppConstants.spaceM),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppConstants.spaceM),
              Text(label,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
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
        ),
        if (!isLast) const Divider(height: 0),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
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
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Benachrichtigungen',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Datenschutz',
            onTap: () {},
          ),
          _SettingsTile(
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppColors.textSecondary, size: 20),
          title: Text(label, style: AppTextStyles.bodyMedium),
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.textTertiary, size: 20),
          onTap: onTap,
          dense: true,
        ),
        if (!isLast)
          const Divider(height: 0, indent: 52),
      ],
    );
  }
}
