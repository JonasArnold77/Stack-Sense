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
///
/// Steht dauerhaft im Stack-Screen (Tab "Supplements") — siehe auch
/// [showCombinationCheckPromptPopup] für die sofortige Variante direkt nach
/// dem Hinzufügen eines Supplements, egal auf welchem Screen.
class CombinationCheckBanner extends ConsumerWidget {
  const CombinationCheckBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShow = ref.watch(shouldShowCombinationCheckPromptProvider);
    if (!shouldShow) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: AppConstants.spaceM),
      child: _CombinationCheckPromptCard(),
    );
  }
}

/// Zeigt denselben Hinweis wie [CombinationCheckBanner], aber sofort als
/// Bottom-Sheet — aufgerufen direkt nachdem ein Supplement zum Stack
/// hinzugefügt wurde (siehe stack_add_warnings.dart), statt erst zu warten,
/// bis der Nutzer von sich aus den Stack-Screen besucht.
Future<void> showCombinationCheckPromptPopup(BuildContext context, WidgetRef ref) async {
  if (!ref.read(shouldShowCombinationCheckPromptProvider)) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusL)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      child: _CombinationCheckPromptCard(
        onHandled: () => Navigator.of(sheetContext).pop(),
      ),
    ),
  );
}

class _CombinationCheckPromptCard extends ConsumerStatefulWidget {
  /// Wird aufgerufen, sobald der Nutzer reagiert hat (geprüft ODER
  /// weggewischt) — im Popup-Kontext genutzt, um das Sheet danach zu
  /// schließen. Im dauerhaften Banner auf dem Stack-Screen null, weil dort
  /// nichts "geschlossen" werden muss.
  final VoidCallback? onHandled;

  const _CombinationCheckPromptCard({this.onHandled});

  @override
  ConsumerState<_CombinationCheckPromptCard> createState() => _CombinationCheckPromptCardState();
}

class _CombinationCheckPromptCardState extends ConsumerState<_CombinationCheckPromptCard> {
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
      widget.onHandled?.call();
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

  void _dismiss(String signature) {
    ref.read(combinationCheckPromptProvider.notifier).markHandled(signature);
    widget.onHandled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final stack = ref.watch(stackProvider);
    final signature = stackSignature(stack);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.primary.withOpacity(0.30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                onPressed: _checking ? null : () => _dismiss(signature),
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
