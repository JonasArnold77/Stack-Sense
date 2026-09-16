import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../data/purchase_provider.dart';
import '../../data/token_balance_provider.dart';

/// Wickelt einen echten Token-Kauf ab und hält den lokal angezeigten
/// Kontostand aktuell. Die eigentliche Gutschrift passiert serverseitig via
/// RevenueCat-Webhook (siehe backend/routers/purchases.py) — kann also kurz
/// NACH dem clientseitig abgeschlossenen Kauf ankommen, deshalb ein zweiter,
/// verzögerter Refresh als einfache Nachhol-Absicherung statt komplexem Polling.
Future<void> buyTokenPackage(BuildContext context, WidgetRef ref, Package package) async {
  try {
    await ref.read(purchaseProvider.notifier).buy(package);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kauf erfolgreich — Guthaben wird aktualisiert…'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    await ref.read(tokenBalanceProvider.notifier).refresh();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!context.mounted) return;
    await ref.read(tokenBalanceProvider.notifier).refresh();
  } catch (e) {
    // Nutzer-Abbruch ist kein Fehler — einfach still zurückkehren.
    if (e is PlatformException &&
        PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) {
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kauf fehlgeschlagen. Bitte später erneut versuchen.')),
      );
    }
  }
}
