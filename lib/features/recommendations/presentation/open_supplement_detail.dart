import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/services/api_service.dart';
import '../../settings/data/cache_mode_provider.dart';
import '../../settings/data/recommendation_mode_provider.dart';
import '../../settings/domain/models/cache_mode.dart';
import '../../settings/domain/models/recommendation_mode.dart';
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
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final supplement = await ApiService.instance.lookupSupplement(
      supplementId: supplementId,
      supplementName: supplementName,
      dbOnly: dbOnly,
      bypassCache: bypassCache,
    );
    navigator.pop(); // Spinner schließen
    if (!context.mounted) return;
    showSupplementDetail(context, supplement, goalContext: goalContext);
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
