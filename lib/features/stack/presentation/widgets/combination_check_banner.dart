import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../onboarding/data/onboarding_provider.dart';
import '../../data/combination_check_provider.dart';
import '../../data/stack_provider.dart';
import '../../domain/models/stack_entry.dart';
import 'combination_check_result_sheet.dart';

/// Sanfter, wegwischbarer Hinweis ab [kCombinationCheckThreshold] gleichzeitig
/// aktiven Supplements — bewusst als hilfreiches Angebot formuliert, nicht
/// als Warnung/Bevormundung: viele NEMs sind für sich genommen kein Problem,
/// aber ab einer gewissen Anzahl lohnt sich ein Blick auf die Kombination als
/// Ganzes (Wechselwirkungen/Überdosierung/Duplikate — siehe
/// combination_check_result_sheet.dart).
class CombinationCheckBanner extends ConsumerStatefulWidget {
  const CombinationCheckBanner({super.key});

  @override
  ConsumerState<CombinationCheckBanner> createState() => _CombinationCheckBannerState();
}

class _CombinationCheckBannerState extends ConsumerState<CombinationCheckBanner> {
  bool _checking = false;

  Future<void> _check(List<StackEntry> stack, String signature) async {
    setState(() => _checking = true);
    final medications = ref.read(onboardingProvider).medications;
    try {
      final result = await ApiService.instance.checkStackCombination(
        supplements: stack,
        medications: medications,
      );
      if (!mounted) return;
      await ref.read(combinationCheckPromptProvider.notifier).markHandled(signature);
      if (!mounted) return;
      showCombinationCheckResultSheet(context, result);
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kombinationscheck konnte nicht durchgeführt werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldShow = ref.watch(shouldShowCombinationCheckPromptProvider);
    if (!shouldShow) return const SizedBox.shrink();

    final stack = ref.watch(stackProvider);
    final signature = stackSignature(stack);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.primary.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: AppConstants.spaceS),
              Expanded(
                child: Text(
                  '${stack.length} Supplements gleichzeitig im Einsatz',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _checking
                    ? null
                    : () => ref.read(combinationCheckPromptProvider.notifier).markHandled(signature),
                icon: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
                tooltip: 'Nicht jetzt',
                style: IconButton.styleFrom(minimumSize: const Size(28, 28), padding: EdgeInsets.zero),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mit steigender Anzahl gleichzeitiger Supplements lohnt sich ab und zu ein Blick auf mögliche '
            'Wechselwirkungen oder Überdosierung. Möchtest du deine aktuelle Kombination checken lassen?',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppConstants.spaceM),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _checking ? null : () => _check(stack, signature),
              icon: _checking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(_checking ? 'Prüfe Kombination…' : 'Ja, Kombination checken'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
