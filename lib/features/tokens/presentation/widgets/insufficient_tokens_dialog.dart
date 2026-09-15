import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/token_balance_provider.dart';

/// Wird gezeigt, sobald der Server eine KI-Anfrage mit 402 (Guthaben leer)
/// ablehnt — an jeder der KI-Trigger-Stellen im Client (siehe
/// InsufficientTokensException in api_service.dart).
Future<void> showInsufficientTokensDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.toll_outlined, color: AppColors.accent, size: 32),
      title: const Text('Keine Tokens mehr'),
      content: const Text(
        'Dein KI-Token-Guthaben ist aufgebraucht. Lade neue Tokens auf, '
        'um diese Funktion weiter zu nutzen.',
        style: AppTextStyles.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
        FilledButton(
          onPressed: () async {
            await ref.read(tokenBalanceProvider.notifier).purchase();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Tokens aufladen (Test)'),
        ),
      ],
    ),
  );
}
