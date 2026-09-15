import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/token_balance_provider.dart';

/// Dauerhafter Hinweis auf dem Home-Screen, solange das Token-Guthaben leer
/// ist — ergänzt (ersetzt nicht) den sofortigen Dialog, der direkt nach einer
/// abgelehnten KI-Anfrage erscheint (siehe insufficient_tokens_dialog.dart).
class TokenBalanceBanner extends ConsumerWidget {
  const TokenBalanceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(tokenBalanceProvider);
    if (balance == null || balance > 0) return const SizedBox.shrink();

    const accent = Color(0xFFC62828);
    const bg = Color(0xFFFFEBEE);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppConstants.spaceL),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.toll_outlined, color: accent, size: 20),
              const SizedBox(width: AppConstants.spaceS),
              Expanded(
                child: Text(
                  'Du brauchst neue Tokens für weitere Nutzung',
                  style: AppTextStyles.labelLarge.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => ref.read(tokenBalanceProvider.notifier).purchase(),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Tokens aufladen (Test)'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusM)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
