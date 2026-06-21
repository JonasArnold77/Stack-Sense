import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../domain/models/community_insight.dart';

/// Lädt Community-Insights für eine Liste von Supplement-Namen.
/// Family-Provider: Parameter = Liste der Supplement-Namen (kommagetrennt als Key).
///
/// Verwendung:
/// ```dart
/// final insights = ref.watch(communityInsightsProvider(['Melatonin', 'Magnesium']));
/// ```
final communityInsightsProvider = FutureProvider.family<
    Map<String, CommunityInsight>,
    List<String>>(
  (ref, names) async {
    if (names.isEmpty) return {};
    return ApiService.instance.getCommunityInsights(names);
  },
);
