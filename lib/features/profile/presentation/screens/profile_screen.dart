import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../onboarding/data/onboarding_provider.dart';
import '../../../onboarding/domain/models/user_profile.dart';
import '../../../checkin/data/checkin_provider.dart';
import '../../../gamification/data/xp_provider.dart';
import '../../../gamification/domain/models/xp_level.dart';

/// Profil-Screen — Level, XP, Streak, Profildaten, Einstellungen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);
    final xpLevel = ref.watch(xpLevelProvider);
    final checkins = ref.watch(checkinProvider);
    final checkinNotifier = ref.read(checkinProvider.notifier);
    final streak = checkinNotifier.currentStreak;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Profil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingH,
          vertical: AppConstants.screenPaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level & XP Card
            _LevelCard(xpLevel: xpLevel, streak: streak),

            const SizedBox(height: AppConstants.spaceM),

            // Streak & Stats
            _StatsRow(streak: streak, checkinCount: checkins.length),

            const SizedBox(height: AppConstants.spaceL),

            // XP-Quellen
            Text('XP verdienen', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppConstants.spaceS),
            _XpSourcesCard(),

            const SizedBox(height: AppConstants.spaceL),

            // Profil-Daten
            Text('Mein Profil', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppConstants.spaceS),
            _ProfileInfoCard(profile: profile),

            const SizedBox(height: AppConstants.spaceL),

            // Einstellungen
            Text('Einstellungen', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppConstants.spaceS),
            _SettingsCard(),

            const SizedBox(height: AppConstants.spaceXL),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level & XP Banner
// ---------------------------------------------------------------------------

class _LevelCard extends StatelessWidget {
  final XpLevel xpLevel;
  final int streak;

  const _LevelCard({required this.xpLevel, required this.streak});

  @override
  Widget build(BuildContext context) {
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
              // Level-Badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
                child: Center(
                  child: Text(
                    '${xpLevel.level}',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${xpLevel.level} · ${xpLevel.levelName}',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      xpLevel.isMaxLevel
                          ? '${xpLevel.totalXp} XP · Maximum erreicht 🏆'
                          : '${xpLevel.totalXp} XP · noch ${xpLevel.xpRemaining} bis Level ${xpLevel.level + 1}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.bolt, color: AppColors.xpGold, size: 28),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          // XP Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            child: LinearProgressIndicator(
              value: xpLevel.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withAlpha(50),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.xpGold),
            ),
          ),
          if (!xpLevel.isMaxLevel) ...[
            const SizedBox(height: AppConstants.spaceXS),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${xpLevel.xpInLevel} / ${xpLevel.xpForNextLevel} XP',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withAlpha(150),
                  ),
                ),
                if (streak > 0)
                  Text(
                    '🔥 $streak ${streak == 1 ? 'Tag' : 'Tage'} Streak',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.xpGold,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats-Zeile (Streak + Check-in-Anzahl)
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  final int streak;
  final int checkinCount;

  const _StatsRow({required this.streak, required this.checkinCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            emoji: '🔥',
            value: '$streak',
            label: streak == 1 ? 'Tag Streak' : 'Tage Streak',
          ),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          child: _StatBox(
            emoji: '✅',
            value: '$checkinCount',
            label: checkinCount == 1 ? 'Check-in' : 'Check-ins',
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatBox({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: AppConstants.spaceXS),
          Text(value, style: AppTextStyles.headlineMedium),
          Text(
            label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// XP-Quellen Card
// ---------------------------------------------------------------------------

class _XpSourcesCard extends StatelessWidget {
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
          _XpRow(
            icon: Icons.check_circle_outline,
            label: 'Täglicher Check-in',
            xp: AppConstants.xpCheckin,
          ),
          const Divider(height: AppConstants.spaceL),
          _XpRow(
            icon: Icons.layers_outlined,
            label: 'Stack aktualisieren',
            xp: AppConstants.xpStackUpdate,
          ),
          const Divider(height: AppConstants.spaceL),
          _XpRow(
            icon: Icons.menu_book_outlined,
            label: 'Evidenz lesen',
            xp: AppConstants.xpEvidenceRead,
          ),
          const Divider(height: AppConstants.spaceL),
          _XpRow(
            icon: Icons.share_outlined,
            label: 'Protokoll teilen',
            xp: AppConstants.xpProtocolShare,
          ),
          const Divider(height: AppConstants.spaceL),
          _XpRow(
            icon: Icons.biotech_outlined,
            label: 'Blutbild hochladen',
            xp: AppConstants.xpBloodworkUpload,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _XpRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int xp;
  final bool isLast;

  const _XpRow({
    required this.icon,
    required this.label,
    required this.xp,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          child: Text(label, style: AppTextStyles.bodyMedium),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceS,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: AppColors.xpGold.withAlpha(25),
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          ),
          child: Text(
            '+$xp XP',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.xpGold),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profil-Daten Card
// ---------------------------------------------------------------------------

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
          const Divider(height: 0),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Geschlecht',
            value: _genderLabel(profile.gender),
          ),
          const Divider(height: 0),
          _InfoTile(
            icon: Icons.fitness_center_outlined,
            label: 'Aktivität',
            value: _sportLabel(profile.sportLevel),
          ),
          if (profile.conditions.isNotEmpty) ...[
            const Divider(height: 0),
            _InfoTile(
              icon: Icons.medical_information_outlined,
              label: 'Erkrankungen',
              value: profile.conditions.join(', '),
            ),
          ],
          if (profile.medications.isNotEmpty) ...[
            const Divider(height: 0),
            _InfoTile(
              icon: Icons.medication_outlined,
              label: 'Medikamente',
              value: profile.medications.join(', '),
            ),
          ],
          const Divider(height: 0),
          _InfoTile(
            icon: Icons.flag_outlined,
            label: 'Ziele',
            value: profile.goals.isNotEmpty ? profile.goals.join(', ') : '–',
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

// ---------------------------------------------------------------------------
// Einstellungen Card
// ---------------------------------------------------------------------------

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
          const Divider(height: 0, indent: 52),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Datenschutz',
            onTap: () {},
          ),
          const Divider(height: 0, indent: 52),
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
