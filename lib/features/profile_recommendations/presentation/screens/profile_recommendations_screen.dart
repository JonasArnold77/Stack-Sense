import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../onboarding/data/onboarding_provider.dart';
import '../../../onboarding/domain/models/user_profile.dart';
import '../../../recommendations/domain/models/supplement.dart';
import '../../../recommendations/presentation/widgets/evidence_card.dart';
import '../../../stack/data/stack_provider.dart';

/// Profil-Empfehlungen Screen — Basis-Supplementierung.
/// Zeigt evidenzbasierte Grundversorgung basierend auf Alter, Geschlecht,
/// Erkrankungen, Sport und Jahreszeit — NICHT basierend auf Problemfeldern.
///
/// Query-Parameter: ?from=onboarding → zeigt CTA "App starten" statt Back-Button
class ProfileRecommendationsScreen extends ConsumerStatefulWidget {
  /// Wenn true: wurde direkt nach dem Onboarding aufgerufen → CTA statt Back
  final bool fromOnboarding;

  const ProfileRecommendationsScreen({
    super.key,
    this.fromOnboarding = false,
  });

  @override
  ConsumerState<ProfileRecommendationsScreen> createState() =>
      _ProfileRecommendationsScreenState();
}

class _ProfileRecommendationsScreenState
    extends ConsumerState<ProfileRecommendationsScreen> {
  List<Supplement> _supplements = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _supplements = [];
    });

    final profile = ref.read(onboardingProvider);

    try {
      // Einziger Call: "Basis-Supplementierung" — Claude entscheidet
      // rein auf Basis von Alter, Geschlecht, Erkrankungen, Sport, Jahreszeit.
      final results = await ApiService.instance.getRecommendations(
        profile: profile,
        goal: 'Basis-Supplementierung',
        limit: 6,
      );
      if (mounted) setState(() => _supplements = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addToStack(Supplement supplement) {
    final stackNotifier = ref.read(stackProvider.notifier);
    final existing = ref.read(stackProvider);
    if (existing.any((e) => e.id == supplement.id)) return;

    stackNotifier.add(supplement);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${supplement.name} zum Stack hinzugefügt'),
        backgroundColor: AppColors.evidenceGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingProvider);
    final existingStack = ref.watch(stackProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient Header
          _RecoGradientHeader(
            profile: profile,
            fromOnboarding: widget.fromOnboarding,
            onBack: () => context.pop(),
          ),

          // Scrollbarer Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPaddingH,
                vertical: AppConstants.spaceL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Abschnitt-Header
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Deine Basis-Supplementierung',
                        style: AppTextStyles.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Basierend auf deinem Profil — unabhängig von deinen Zielen',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                  ),

                  const SizedBox(height: AppConstants.spaceL),

                  // Inhalt: Loading / Error / Liste
                  if (_isLoading)
                    _LoadingList()
                  else if (_error != null)
                    _ErrorCard(error: _error!, onRetry: _load)
                  else if (_supplements.isEmpty)
                    _EmptyResult()
                  else
                    ...List.generate(_supplements.length, (i) {
                      final s = _supplements[i];
                      final alreadyInStack =
                          existingStack.any((e) => e.id == s.id);
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppConstants.spaceS),
                        child: EvidenceCard(
                          supplement: s,
                          isInStack: alreadyInStack,
                          onAddToStack: alreadyInStack ? null : () => _addToStack(s),
                        ),
                      );
                    }),

                  const SizedBox(height: AppConstants.spaceL),

                  // CTA: Entdecken-Screen oder App starten
                  _DiscoverMoreButton(
                    fromOnboarding: widget.fromOnboarding,
                    onTap: () {
                      if (widget.fromOnboarding) {
                        context.go(AppRoutes.heute);
                      } else {
                        context.pop();
                        context.go(AppRoutes.recommendations);
                      }
                    },
                  ),

                  SizedBox(
                    height: AppConstants.spaceXL +
                        MediaQuery.of(context).padding.bottom,
                  ),
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
// Gradient Header
// ---------------------------------------------------------------------------

class _RecoGradientHeader extends StatelessWidget {
  final UserProfile profile;
  final bool fromOnboarding;
  final VoidCallback onBack;

  const _RecoGradientHeader({
    required this.profile,
    required this.fromOnboarding,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    final subtitle = _buildSubtitle(profile);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: EdgeInsets.only(
        top: topPadding + AppConstants.spaceM,
        left: AppConstants.screenPaddingH,
        right: AppConstants.screenPaddingH,
        bottom: AppConstants.spaceXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back-Button (nur wenn nicht Onboarding)
          if (!fromOnboarding)
            Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spaceS),
              child: GestureDetector(
                onTap: onBack,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_new,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      'Zurück',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          // Titel
          Text(
            'Für dein Profil',
            style: AppTextStyles.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall
                .copyWith(color: Colors.white.withOpacity(0.68)),
          ),

          const SizedBox(height: AppConstants.spaceM),

          // Profil-Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (profile.age != null)
                _ProfileChip(
                    icon: Icons.person_outline,
                    label: '${profile.age} Jahre'),
              if (profile.gender != null)
                _ProfileChip(
                    icon: Icons.wc,
                    label: _genderLabel(profile.gender!)),
              if (profile.sportLevel != null)
                _ProfileChip(
                    icon: Icons.fitness_center_outlined,
                    label: _sportLabel(profile.sportLevel!)),
              if (profile.conditions.isNotEmpty)
                _ProfileChip(
                    icon: Icons.health_and_safety_outlined,
                    label: '${profile.conditions.length} Erkrankung(en)'),
            ],
          ),
        ],
      ),
    );
  }

  String _buildSubtitle(UserProfile profile) {
    final parts = <String>[];
    if (profile.conditions.isNotEmpty) parts.add(profile.conditions.first);
    if (profile.sportLevel != null && profile.sportLevel != SportLevel.none) {
      parts.add(_sportLabel(profile.sportLevel!));
    }
    if (parts.isNotEmpty) return parts.join(' · ');
    return 'Evidenzbasierte Grundversorgung für dich';
  }

  String _genderLabel(Gender g) => switch (g) {
        Gender.male => 'Männlich',
        Gender.female => 'Weiblich',
        Gender.diverse => 'Divers',
      };

  String _sportLabel(SportLevel s) => switch (s) {
        SportLevel.none => 'Kein Sport',
        SportLevel.light => 'Wenig Sport',
        SportLevel.moderate => 'Moderat aktiv',
        SportLevel.intense => 'Sehr aktiv',
      };
}

class _ProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / Error / Empty States
// ---------------------------------------------------------------------------

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => Container(
          height: 96,
          margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.evidenceRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.evidenceRed.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_outlined,
              size: 18, color: AppColors.evidenceRed),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: Text(
              'Backend nicht erreichbar — bitte Backend starten',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.evidenceRed),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Text(
        'Keine Basis-Empfehlungen verfügbar.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA am Ende
// ---------------------------------------------------------------------------

class _DiscoverMoreButton extends StatelessWidget {
  final bool fromOnboarding;
  final VoidCallback onTap;

  const _DiscoverMoreButton(
      {required this.fromOnboarding, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (fromOnboarding) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.rocket_launch_outlined, size: 18),
            label: const Text('App starten'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          Text(
            'Du kannst jederzeit weitere Empfehlungen über "Entdecken" abrufen.',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.explore_outlined, size: 18),
      label: const Text('Weitere Empfehlungen im Entdecken-Screen'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: AppColors.primary),
        foregroundColor: AppColors.primary,
      ),
    );
  }
}

