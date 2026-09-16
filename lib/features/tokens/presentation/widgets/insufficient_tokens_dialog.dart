import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/purchase_provider.dart';
import '../../data/token_balance_provider.dart';
import 'purchase_flow.dart';

/// Wird gezeigt, sobald der Server eine KI-Anfrage mit 402 (Guthaben leer)
/// ablehnt — an jeder der KI-Trigger-Stellen im Client (siehe
/// InsufficientTokensException in api_service.dart). Zeigt echte, über
/// RevenueCat geladene Token-Pakete (falls verfügbar) plus den weiterhin
/// vorhandenen kostenlosen Test-Aufladeknopf als Fallback.
Future<void> showInsufficientTokensDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (dialogContext, dialogRef, _) {
        final packages = dialogRef.watch(purchaseProvider);
        return AlertDialog(
          icon: const Icon(Icons.toll_outlined, color: AppColors.accent, size: 32),
          title: const Text('Keine Tokens mehr'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dein KI-Token-Guthaben ist aufgebraucht. Lade neue Tokens auf, '
                'um diese Funktion weiter zu nutzen.',
                style: AppTextStyles.bodyMedium,
              ),
              for (final package in packages) ...[
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await buyTokenPackage(context, ref, package);
                  },
                  child: Text(
                    '${tokenLabelForProduct(package.storeProduct.identifier)} — ${package.storeProduct.priceString}',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Schließen'),
            ),
            OutlinedButton(
              onPressed: () async {
                await ref.read(tokenBalanceProvider.notifier).purchase();
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Tokens aufladen (Test)'),
            ),
          ],
        );
      },
    ),
  );
}
