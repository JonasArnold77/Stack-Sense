import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/url_config_service.dart';
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient-Header mit Level & XP
          _ProfileGradientHeader(xpLevel: xpLevel, streak: streak),

          // Scrollbarer Inhalt
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPaddingH,
                vertical: AppConstants.screenPaddingV,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profil-Empfehlungen Karte
                  _ProfileRecommendationsCard(),

                  const SizedBox(height: AppConstants.spaceL),

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

                  const SizedBox(height: AppConstants.spaceL),

                  // Backend-Verbindung
                  Text('Backend-Verbindung', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppConstants.spaceS),
                  const _BackendUrlCard(),

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

// ---------------------------------------------------------------------------
// Profil Gradient-Header
// ---------------------------------------------------------------------------

class _ProfileGradientHeader extends StatelessWidget {
  final XpLevel xpLevel;
  final int streak;

  const _ProfileGradientHeader({required this.xpLevel, required this.streak});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final xpFraction = xpLevel.isMaxLevel
        ? 1.0
        : xpLevel.xpInLevel / xpLevel.xpForNextLevel;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        padding: EdgeInsets.only(
          top: topPadding + AppConstants.spaceM,
          left: AppConstants.screenPaddingH,
          right: AppConstants.screenPaddingH,
          bottom: AppConstants.spaceL,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zeile: Level-Badge + Info
            Row(
              children: [
                // Level-Nummer im Kreis
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 2,
                    ),
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
                        xpLevel.levelName,
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        xpLevel.isMaxLevel
                            ? '${xpLevel.totalXp} XP · Maximum erreicht 🏆'
                            : '${xpLevel.totalXp} XP · noch ${xpLevel.xpRemaining} bis Level ${xpLevel.level + 1}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                // Streak Badge
                if (streak > 0) ...[
                  Column(
                    children: [
                      Icon(Icons.local_fire_department,
                          color: AppColors.xpGold, size: 22),
                      const SizedBox(height: 2),
                      Text(
                        '$streak',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Tage',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppConstants.spaceM),

            // XP-Fortschrittsbalken
            if (!xpLevel.isMaxLevel) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level ${xpLevel.level}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    'Level ${xpLevel.level + 1}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: xpFraction.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.xpGold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level & XP Banner (wird nicht mehr als eigenständige Card verwendet)
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

// ---------------------------------------------------------------------------
// Backend-URL Card — Runtime-Konfiguration ohne Rebuild
// ---------------------------------------------------------------------------

class _BackendUrlCard extends StatefulWidget {
  const _BackendUrlCard();

  @override
  State<_BackendUrlCard> createState() => _BackendUrlCardState();
}

class _BackendUrlCardState extends State<_BackendUrlCard> {
  late TextEditingController _controller;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: UrlConfigService.current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    await UrlConfigService.setUrl(url);
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  Future<void> _reset() async {
    await UrlConfigService.reset();
    setState(() {
      _controller.text = UrlConfigService.current;
      _saved = false;
    });
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppConstants.spaceS),
              Text(
                'Backend URL',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceS),
          TextField(
            controller: _controller,
            style: AppTextStyles.bodySmall,
            decoration: InputDecoration(
              hintText: 'https://xxx.ngrok-free.dev  oder  http://192.168.x.x:8000',
              hintStyle:
                  AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceM,
                  vertical: AppConstants.spaceS),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: AppConstants.spaceS),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.spaceS),
                  ),
                  child: Text(
                    _saved ? '\u2713 Gespeichert' : 'Speichern',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceS),
              OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spaceS,
                      horizontal: AppConstants.spaceM),
                ),
                child: Text('Reset', style: AppTextStyles.labelMedium),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceXS),
          Text(
            'Ohne Neustart sofort aktiv. /api/v1 wird automatisch ergänzt.',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profil-Empfehlungen Karte
// ---------------------------------------------------------------------------

class _ProfileRecommendationsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.profileRecommendations),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.08),
              AppColors.accent.withOpacity(0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Icon-Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppConstants.spaceM),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Empfehlungen für dein Profil',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Personalisiert nach deinen Zielen & Gesundheitsdaten',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spaceS),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
