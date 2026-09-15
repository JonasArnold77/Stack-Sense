import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/token_balance_provider.dart';

/// Gemeinsamer Hook für ALLE KI-Trigger-Stellen: aktualisiert das Guthaben
/// nach einer KI-Anfrage und blendet kurz ein, wie viele Tokens sie gekostet
/// hat (Delta aus Guthaben vorher/nachher — der Server liefert den Preis
/// pro Anfrage nicht im Response mit, das wäre eine Änderung an jedem
/// einzelnen Response-Modell gewesen; die Differenz ist exakt genauso genau).
Future<void> refreshTokenBalanceAndShowCost(BuildContext context, WidgetRef ref) async {
  final before = ref.read(tokenBalanceProvider);
  await ref.read(tokenBalanceProvider.notifier).refresh();
  if (!context.mounted) return;
  final after = ref.read(tokenBalanceProvider);
  if (before == null || after == null) return;
  final spent = before - after;
  if (spent <= 0) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.toll_outlined, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text('$spent Tokens verbraucht'),
        ],
      ),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
