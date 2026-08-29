import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

/// Kuratierte Supplement-Slugs mit Lebensmittel-Nährstoffdaten (siehe
/// backend supplement_nutrients) — fürs "Durch Ernährung abdeckbar"-Badge.
/// Ein FutureProvider reicht: die Liste ändert sich nur bei manueller
/// Kuration, ein einmaliger Fetch pro App-Sitzung ist ausreichend. Bei
/// Fehlschlag leeres Set statt Fehler — das Badge bleibt dann einfach aus.
final nutrientMappableSlugsProvider = FutureProvider<Set<String>>((ref) async {
  try {
    return await ApiService.instance.getNutrientMappableSlugs();
  } catch (_) {
    return <String>{};
  }
});
