import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../checkin/data/checkin_provider.dart';
import '../../../gamification/data/xp_provider.dart';
import '../../../onboarding/data/onboarding_provider.dart';
import '../widgets/backend_url_card.dart';
import '../widgets/profile_gradient_header.dart';
import '../widgets/profile_info_card.dart';
import '../widgets/profile_recommendations_card.dart';
import '../widgets/profile_settings_card.dart';
import '../widgets/profile_stats_row.dart';
import '../widgets/xp_sources_card.dart';

/// Profil-Screen — dünner Orchestrator, delegiert an Widgets.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);
    final xpLevel = ref.watch(xpLevelProvider);
    final checkins = ref.watch(checkinProvider);
    final streak = ref.read(checkinProvider.notifier).currentStreak;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileGradientHeader(xpLevel: xpLevel, streak: streak),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPaddingH,
                vertical: AppConstants.screenPaddingV,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProfileRecommendationsCard(),

                  const SizedBox(height: AppConstants.spaceL),

                  ProfileStatsRow(
                    streak: streak,
                    checkinCount: checkins.length,
                  ),

                  const SizedBox(height: AppConstants.spaceL),

                  Text('XP verdienen', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppConstants.spaceS),
                  const XpSourcesCard(),

                  const SizedBox(height: AppConstants.spaceL),

                  Text('Mein Profil', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppConstants.spaceS),
                  ProfileInfoCard(profile: profile),

                  const SizedBox(height: AppConstants.spaceL),

                  Text('Einstellungen', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppConstants.spaceS),
                  const ProfileSettingsCard(),

                  const SizedBox(height: AppConstants.spaceL),

                  Text('Backend-Verbindung',
                      style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppConstants.spaceS),
                  const BackendUrlCard(),

                  const SizedBox(height: AppConstants.spaceXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

