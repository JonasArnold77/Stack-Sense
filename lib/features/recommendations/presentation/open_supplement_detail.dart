import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/services/api_service.dart';
import '../../auth/data/auth_provider.dart';
import '../../settings/data/cache_mode_provider.dart';
import '../../settings/data/recommendation_mode_provider.dart';
import '../../settings/domain/models/cache_mode.dart';
import '../../settings/domain/models/recommendation_mode.dart';
import '../../tokens/presentation/widgets/insufficient_tokens_dialog.dart';
import '../../tokens/presentation/widgets/token_spend_feedback.dart';
import 'screens/supplement_detail_screen.dart';

/// Öffnet dasselbe Detail-Fenster wie ein Tap auf eine Supplement-Karte unter
/// Problemfeldern / Phasenzielen / Basissupplementierung — von überall, wo nur
/// eine Supplement-Id + Name vorliegt (Stack, Kalender, Foundation-/
/// Optimization-Liste). Lädt zuerst die volle Karte nach (respektiert
/// KI-/Datenbank-Modus und Cache), zeigt währenddessen einen kurzen,
/// blockierenden Ladeindikator und bei Fehler eine SnackBar.
Future<void> openSupplementDetail(
  BuildContext context,
  WidgetRef ref, {
  required String supplementId,
  required String supplementName,
  String? goalContext,
}) async {
  final dbOnly =
      ref.read(recommendationModeProvider) == RecommendationMode.ragOnly;
  final bypassCache = ref.read(cacheModeProvider) == CacheMode.noCache;

  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final idToken = await ref.read(authProvider.notifier).getIdToken() ?? '';
    final lookup = ApiService.instance.lookupSupplement(
      supplementId: supplementId,
      supplementName: supplementName,
      idToken: idToken,
      dbOnly: dbOnly,
      bypassCache: bypassCache,
    );
    // Mindest-Anzeigedauer — damit der Ladekreis bei gecachten/schnellen
    // Antworten nicht nur kurz aufblitzt, sondern beim Öffnen jeder Karte
    // sichtbar bleibt, bis die Detailseite da ist.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final supplement = await lookup;
    navigator.pop(); // Spinner schließen
    if (!context.mounted) return;
    showSupplementDetail(context, supplement, goalContext: goalContext);
    unawaited(refreshTokenBalanceAndShowCost(context, ref));
  } on InsufficientTokensException {
    navigator.pop();
    if (context.mounted) await showInsufficientTokensDialog(context, ref);
    unawaited(refreshTokenBalanceAndShowCost(context, ref));
  } on AppFailure catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Detail-Karte konnte nicht geladen werden.')),
    );
  }
}
