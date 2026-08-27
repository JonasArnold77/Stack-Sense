import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/wearable_badge.dart';

// ---------------------------------------------------------------------------
// Ziel-Daten (public — wird auch von GoalSelector genutzt)
// ---------------------------------------------------------------------------

class GoalData {
  final String label;
  final IconData icon;
  final bool wearableCompatible;
  const GoalData({
    required this.label,
    required this.icon,
    this.wearableCompatible = false,
  });
}

const goalData = [
  GoalData(label: 'Mehr Energie', icon: Icons.bolt_outlined, wearableCompatible: true),
  GoalData(label: 'Besserer Schlaf', icon: Icons.bedtime_outlined, wearableCompatible: true),
  GoalData(label: 'Fokus & Konzentration', icon: Icons.psychology_outlined),
  GoalData(label: 'Sport & Regeneration', icon: Icons.fitness_center_outlined, wearableCompatible: true),
  GoalData(label: 'Immunsystem stärken', icon: Icons.shield_outlined, wearableCompatible: true),
  GoalData(label: 'Stimmung & Wohlbefinden', icon: Icons.mood_outlined),
  GoalData(label: 'Herzgesundheit', icon: Icons.favorite_outline, wearableCompatible: true),
  GoalData(label: 'Haut & Haare', icon: Icons.spa_outlined),
  GoalData(label: 'Gewichtsmanagement', icon: Icons.scale_outlined),
  GoalData(label: 'Gelenkgesundheit', icon: Icons.elderly_outlined),
  GoalData(label: 'Frauengesundheit / Zyklus', icon: Icons.female, wearableCompatible: true),
  GoalData(label: 'Hormonbalance', icon: Icons.science_outlined),
];

// ---------------------------------------------------------------------------
// Kachelgitter — erscheint wenn noch kein Ziel gewählt ist
// ---------------------------------------------------------------------------

class GoalTileGrid extends StatelessWidget {
  final void Function(String) onSelect;
  const GoalTileGrid({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH,
              AppConstants.spaceL,
              AppConstants.screenPaddingH,
              AppConstants.spaceS,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Erklärungs-Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.07),
                        AppColors.primary.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      _HowItWorksStep(
                        number: '1',
                        icon: Icons.ads_click_outlined,
                        text: 'Wähle ein Thema das dich beschäftigt',
                      ),
                      const SizedBox(height: 8),
                      _HowItWorksStep(
                        number: '2',
                        icon: Icons.psychology_outlined,
                        text:
                            'KI analysiert dein Profil und liefert passende Supplements',
                      ),
                      const SizedBox(height: 8),
                      _HowItWorksStep(
                        number: '3',
                        icon: Icons.verified_outlined,
                        text:
                            'Grün = belegt · Gelb = Hinweise · Rot = unbewiesen',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spaceL),
                Text('Was beschäftigt dich?',
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppConstants.spaceXS),
                Text(
                  'Claude analysiert dein Profil und gibt personalisierte Empfehlungen.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),

        // Basis-Supplementierung — breite Kachel (nimmt 2 Tile-Breiten ein)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH,
              AppConstants.spaceS,
              AppConstants.screenPaddingH,
              0,
            ),
            child: BasisSupplementierungTile(
              onTap: () => onSelect('Basis-Supplementierung'),
            ),
          ),
        ),

        // Problemfelder-Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenPaddingH,
            vertical: AppConstants.spaceM,
          ),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: AppConstants.spaceM,
            crossAxisSpacing: AppConstants.spaceM,
            childAspectRatio: 1.15,
            children: goalData.map((goal) {
              return GoalTile(goal: goal, onTap: () => onSelect(goal.label));
            }).toList(),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppConstants.spaceXL)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Breite Basis-Supplementierung Kachel
// ---------------------------------------------------------------------------

class BasisSupplementierungTile extends StatelessWidget {
  final VoidCallback onTap;
  const BasisSupplementierungTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - AppConstants.spaceM) / 2;
        final tileHeight = tileWidth / 1.35;

        return SizedBox(
          height: tileHeight,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withBlue(
                      (AppColors.primary.blue + 40).clamp(0, 255),
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppConstants.radiusL),
                  splashColor: Colors.white.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spaceL,
                      vertical: AppConstants.spaceM,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusM),
                          ),
                          child: const Icon(
                            Icons.verified_outlined,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceM),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Basis-Supplementierung',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Personalisierte Basisempfehlung für dein Profil',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Einzelne normale Ziel-Kachel
// ---------------------------------------------------------------------------

class GoalTile extends StatelessWidget {
  final GoalData goal;
  final VoidCallback onTap;

  const GoalTile({super.key, required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusM),
                    ),
                    child: Icon(
                      goal.icon,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  Text(
                    goal.label,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (goal.wearableCompatible) ...[
                    const SizedBox(height: 4),
                    const WearableBadge(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Erklärungs-Schritt im Banner
// ---------------------------------------------------------------------------

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;

  const _HowItWorksStep({
    required this.number,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
