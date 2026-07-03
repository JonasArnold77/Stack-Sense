import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/skeleton_loader.dart';

// ---------------------------------------------------------------------------
// Lade-Zustand
// ---------------------------------------------------------------------------

class RecommendationsLoadingState extends StatelessWidget {
  const RecommendationsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Claude analysiert dein Profil…',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: SkeletonCardList(count: 4)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fehler-Zustand
// ---------------------------------------------------------------------------

class RecommendationsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const RecommendationsErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppConstants.spaceL),
            Text('Verbindungsfehler',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              message,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceXL),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Nochmal versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Load-More Indikator (am Ende der Liste)
// ---------------------------------------------------------------------------

class LoadMoreIndicator extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final VoidCallback onTap;

  const LoadMoreIndicator({
    super.key,
    required this.isLoading,
    required this.hasMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppConstants.spaceXL),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: AppConstants.spaceS),
              Text('Weitere Supplements laden…'),
            ],
          ),
        ),
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceM),
        child: Center(
          child: TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.expand_more),
            label: const Text('Mehr laden'),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Abschnitts-Überschrift in der Ergebnis-Liste
// ---------------------------------------------------------------------------

class RecommendationsSectionHeader extends StatelessWidget {
  final String label;
  const RecommendationsSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spaceM,
        bottom: AppConstants.spaceS,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: Container(height: 1, color: AppColors.border),
          ),
        ],
      ),
    );
  }
}
