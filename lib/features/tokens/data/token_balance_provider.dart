import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../auth/data/auth_provider.dart';

/// Hält das aktuelle KI-Token-Guthaben. `null` = noch nicht geladen.
/// Lädt sich beim ersten Zugriff selbst (siehe Konstruktor) — kein separater
/// Login-Hook nötig, da der Home-Screen (wo Chip + Banner angezeigt werden)
/// nach dem Login ohnehin als erstes erreicht wird.
class TokenBalanceNotifier extends StateNotifier<int?> {
  final Ref ref;

  TokenBalanceNotifier(this.ref) : super(null) {
    refresh();
  }

  Future<void> refresh() async {
    final token = await ref.read(authProvider.notifier).getIdToken();
    if (token == null) return;
    final balance = await ApiService.instance.getTokenBalance(token);
    if (balance != null) state = balance;
  }

  /// Lädt sofort und kostenlos neue Tokens nach (Test-Stub, siehe Backend).
  Future<void> purchase() async {
    final token = await ref.read(authProvider.notifier).getIdToken();
    if (token == null) return;
    final balance = await ApiService.instance.purchaseTokens(token);
    if (balance != null) state = balance;
  }
}

final tokenBalanceProvider =
    StateNotifierProvider<TokenBalanceNotifier, int?>(
  (ref) => TokenBalanceNotifier(ref),
);
