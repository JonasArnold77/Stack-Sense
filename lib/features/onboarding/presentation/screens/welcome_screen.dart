import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';

/// Erster Screen — Willkommen bei StackSense.
/// Staggered Entrance-Animationen: Logo → Headline → Features → CTA
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Jedes Element hat seine eigene zeitversetzte Animation
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _headlineSlide;
  late Animation<double> _headlineOpacity;
  late Animation<double> _featuresOpacity;
  late Animation<Offset> _featuresSlide;
  late Animation<double> _ctaOpacity;
  late Animation<Offset> _ctaSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Logo: skaliert von 0.5 → 1.0, faded in
    _logoScale = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );

    // Headline: slide von unten
    _headlineSlide = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.55, curve: Curves.easeOutCubic),
    ));
    _headlineOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.45, curve: Curves.easeOut),
      ),
    );

    // Features: slide von unten, etwas später
    _featuresSlide = Tween(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
    ));
    _featuresOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.65, curve: Curves.easeOut),
      ),
    );

    // CTA: ganz am Ende
    _ctaSlide = Tween(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
    ));
    _ctaOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 0.9, curve: Curves.easeOut),
      ),
    );

    // Animation nach kurzem Delay starten
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingH,
              vertical: AppConstants.screenPaddingV,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // --- Logo mit Scale + Fade ---
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppConstants.radiusL),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.science_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.spaceL),

                // --- Headline mit Slide + Fade ---
                FadeTransition(
                  opacity: _headlineOpacity,
                  child: SlideTransition(
                    position: _headlineSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supplements,\ndie wirklich\nzu dir passen.',
                          style: AppTextStyles.displayLarge.copyWith(
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceM),
                        Text(
                          'Evidenzbasierte Empfehlungen — '
                          'personalisiert auf deinen Körper, '
                          'deine Ziele und deine Situation.',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.spaceXL),

                // --- Feature-Punkte mit Slide + Fade ---
                FadeTransition(
                  opacity: _featuresOpacity,
                  child: SlideTransition(
                    position: _featuresSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...[
                          (Icons.verified_outlined, 'Nur mit echter Evidenz',
                              'Grün = belegt, Gelb = Hinweise, Rot = unbewiesen'),
                          (Icons.person_outline, 'Personalisiert auf dich',
                              'Alter, Ziele, Erkrankungen, Jahreszeit'),
                          (Icons.notifications_none, 'Tägliche Begleitung',
                              'Einnahme-Kalender + Check-in'),
                        ].map((item) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppConstants.spaceM),
                              child: _FeatureRow(
                                icon: item.$1,
                                label: item.$2,
                                subtitle: item.$3,
                              ),
                            )),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // --- CTA mit Slide + Fade ---
                FadeTransition(
                  opacity: _ctaOpacity,
                  child: SlideTransition(
                    position: _ctaSlide,
                    child: Column(
                      children: [
                        FilledButton(
                          onPressed: () =>
                              context.go(AppRoutes.onboardingStep1),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text('Profil erstellen'),
                        ),
                        const SizedBox(height: AppConstants.spaceM),
                        Center(
                          child: Text(
                            'Deine Gesundheitsdaten bleiben auf deinem Gerät.',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceS),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
