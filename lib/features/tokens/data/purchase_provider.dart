import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Token-Menge pro Produkt-ID — muss exakt der Backend-Zuordnung in
/// backend/routers/purchases.py::_PRODUCT_TOKEN_AMOUNTS entsprechen. Nur für
/// die Anzeige (Preis kommt von RevenueCat/dem Store) — die tatsächliche
/// Gutschrift passiert serverseitig über den RevenueCat-Webhook, niemals
/// client-seitig.
const Map<String, int> kTokenPackageAmounts = {
  'tokens_pack_s': 10000,
  'tokens_pack_m': 50000,
  'tokens_pack_l': 150000,
};

/// Lädt die in RevenueCat konfigurierten Token-Pakete. Bleibt eine leere
/// Liste, solange RevenueCat nicht konfiguriert ist (kein API-Key, siehe
/// main.dart) oder noch keine Angebote geladen werden konnten — die UI zeigt
/// dann nur den bestehenden kostenlosen Test-Aufladeknopf.
class PurchaseNotifier extends StateNotifier<List<Package>> {
  PurchaseNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final offerings = await Purchases.getOfferings();
      state = offerings.current?.availablePackages ?? const [];
    } catch (_) {
      state = const [];
    }
  }

  Future<CustomerInfo> buy(Package package) => Purchases.purchasePackage(package);
}

final purchaseProvider = StateNotifierProvider<PurchaseNotifier, List<Package>>(
  (ref) => PurchaseNotifier(),
);

/// Anzeige-Label für ein Paket, z.B. "50000 Tokens".
String tokenLabelForProduct(String productId) {
  final amount = kTokenPackageAmounts[productId];
  return amount == null ? productId : '$amount Tokens';
}
