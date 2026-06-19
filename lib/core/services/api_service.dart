import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../services/url_config_service.dart';
import '../../features/onboarding/domain/models/user_profile.dart';
import '../../features/recommendations/domain/models/supplement.dart';
// ProductLink wird aus supplement.dart re-exportiert

/// Verbindet die Flutter App mit dem FastAPI Backend.
/// Alle Backend-Calls laufen hier durch — niemals http direkt in Widgets verwenden.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // URL wird zur Laufzeit aus UrlConfigService gelesen — kein Rebuild nötig.
  String get _baseUrl => UrlConfigService.current;

  /// Holt personalisierte Empfehlungen von Claude via Backend.
  /// [limit] — Anzahl Supplements pro Seite (Standard: 5).
  /// [excludeIds] — bereits geladene Supplement-IDs, werden übersprungen.
  Future<List<Supplement>> getRecommendations({
    required UserProfile profile,
    required String goal,
    int limit = 5,
    List<String> excludeIds = const [],
  }) async {
    final body = jsonEncode({
      'profile': _profileToJson(profile),
      'goal': goal,
      'limit': limit,
      'exclude_ids': excludeIds,
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/recommendations'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['recommendations'] as List<dynamic>;
        return list
            .map((e) => _supplementFromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('API Fehler ${response.statusCode}: ${response.body}');
        throw ApiException('Server-Fehler: ${response.statusCode}');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Netzwerk-Fehler: $e');
      throw ApiException(
          'Keine Verbindung zum Backend. Läuft start.ps1?');
    }
  }

  Map<String, dynamic> _profileToJson(UserProfile profile) => {
        'age': profile.age ?? 30,
        'gender': profile.gender?.name ?? 'diverse',
        'sport_level': profile.sportLevel?.name ?? 'none',
        'conditions': profile.conditions,
        'medications': profile.medications,
        'goals': profile.goals,
        'is_pregnant': profile.isPregnant,
      };

  /// Holt eine "Einfach erklärt" Erklärung für ein Supplement (on-demand, Sonnet).
  Future<String> explainSupplement({
    required String supplementName,
    String? substanceName,
  }) async {
    final body = jsonEncode({
      'supplement_name': supplementName,
      'substance_name': substanceName,
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/explain'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['explanation'] as String;
      } else {
        throw ApiException('Erklärung nicht verfügbar (${response.statusCode})');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Explain-Fehler: $e');
      throw ApiException('Erklärung konnte nicht geladen werden.');
    }
  }

  /// Lädt on-demand Kaufoptionen für ein Supplement via Claude.
  Future<List<ProductLink>> getProductSuggestions({
    required String supplementName,
    String? substanceName,
    List<String> categories = const [],
  }) async {
    final body = jsonEncode({
      'supplement_name': supplementName,
      'substance_name': substanceName,
      'categories': categories,
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/products'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['products'] as List<dynamic>? ?? [];
        return list
            .map((e) => ProductLink.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('Produkte nicht verfügbar (${response.statusCode})');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Produkt-Suche Fehler: $e');
      throw ApiException('Produkte konnten nicht geladen werden.');
    }
  }

  Supplement _supplementFromJson(Map<String, dynamic> json) {
    final rawLinks = json['product_links'] as List<dynamic>? ?? [];
    final productLinks = rawLinks
        .map((e) => ProductLink.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawCategories = json['categories'] as List<dynamic>? ?? [];
    final categories = rawCategories.map((e) => e as String).toList();

    final rawWirkstoffe = json['enthaltene_wirkstoffe'] as List<dynamic>? ?? [];
    final enthalteneWirkstoffe = rawWirkstoffe.map((e) => e as String).toList();

    final rawSecondary = json['secondary_benefit'] as Map<String, dynamic>?;
    final secondaryBenefit =
        rawSecondary != null ? SecondaryBenefit.fromJson(rawSecondary) : null;

    return Supplement(
      id: json['id'] as String,
      name: json['name'] as String,
      substanceName: json['substance_name'] as String?,
      evidenceLevel: _parseEvidenceLevel(json['evidence_level'] as String),
      evidenceReason: json['evidence_reason'] as String,
      dosage: json['dosage'] as String,
      intakeTime: json['intake_time'] as String,
      intakeHint: json['intake_hint'] as String?,
      drugInteraction: json['drug_interaction'] as String?,
      interactionSeverity: _parseSeverity(json['interaction_severity'] as String?),
      productLinks: productLinks,
      categories: categories,
      supplementType: _parseSupplementType(json['supplement_type'] as String?),
      enthalteneWirkstoffe: enthalteneWirkstoffe,
      secondaryBenefit: secondaryBenefit,
    );
  }

  EvidenceLevel _parseEvidenceLevel(String raw) => switch (raw) {
        'green' => EvidenceLevel.green,
        'yellow' => EvidenceLevel.yellow,
        _ => EvidenceLevel.red,
      };

  InteractionSeverity _parseSeverity(String? raw) => switch (raw) {
        'timing' => InteractionSeverity.timing,
        'moderate' => InteractionSeverity.moderate,
        'high' => InteractionSeverity.high,
        _ => InteractionSeverity.none,
      };

  SupplementType _parseSupplementType(String? raw) => switch (raw) {
        'group' => SupplementType.group,
        _ => SupplementType.single,
      };

  /// Prüft via Claude Haiku semantisch ob [newSupplement] Wirkstoffe enthält
  /// die bereits in [stack] vorhanden sind (z.B. B2 == Vitamin B2 == Riboflavin).
  /// Gibt die IDs der Duplikate und eine Begründung zurück.
  /// Bei Netzwerkfehler: leeres Ergebnis (kein False-Positive).
  Future<DuplicateCheckResult> checkDuplicates({
    required Supplement newSupplement,
    required List<Supplement> stack,
  }) async {
    if (stack.isEmpty) {
      return const DuplicateCheckResult(duplicateIds: [], reasoning: '');
    }

    Map<String, dynamic> toInfo(Supplement s) => {
          'id': s.id,
          'name': s.name,
          'substance_name': s.substanceName,
          'enthaltene_wirkstoffe': s.enthalteneWirkstoffe,
        };

    final body = jsonEncode({
      'new_supplement': toInfo(newSupplement),
      'stack': stack.map(toInfo).toList(),
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/check-duplicates'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final ids = (data['duplicates'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList();
        return DuplicateCheckResult(
          duplicateIds: ids,
          reasoning: data['reasoning'] as String? ?? '',
        );
      }
      return const DuplicateCheckResult(duplicateIds: [], reasoning: '');
    } catch (e) {
      debugPrint('Duplikat-Check Fehler: $e');
      return const DuplicateCheckResult(duplicateIds: [], reasoning: '');
    }
  }

  /// Lädt PubMed-Studien für ein Supplement (lazy, on-demand).
  Future<List<PubMedStudy>> getStudies({
    required String supplementName,
    String? substanceName,
    String? goal,
  }) async {
    final body = jsonEncode({
      'supplement_name': supplementName,
      'substance_name': substanceName,
      'goal': goal,
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/studies'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['studies'] as List<dynamic>? ?? [];
        return list
            .map((e) => PubMedStudy.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('Studien nicht verfügbar (${response.statusCode})');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Studies Fehler: $e');
      throw ApiException('Studien konnten nicht geladen werden.');
    }
  }

  /// Lädt natürliche Lebensmittelquellen für einen Nährstoff (lazy, on-demand).
  Future<List<FoodSource>> getFoodSources({
    required String supplementName,
    String? substanceName,
  }) async {
    final body = jsonEncode({
      'supplement_name': supplementName,
      'substance_name': substanceName,
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/food-sources'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['sources'] as List<dynamic>? ?? [];
        return list
            .map((e) => FoodSource.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('Quellen nicht verfügbar (${response.statusCode})');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Food-Sources Fehler: $e');
      throw ApiException('Lebensmittelquellen konnten nicht geladen werden.');
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// Ergebnis der KI-basierten Duplikatprüfung.
class DuplicateCheckResult {
  /// IDs der Stack-Einträge die denselben Wirkstoff enthalten.
  final List<String> duplicateIds;

  /// Claudes Begründung (für Debug / optionale Anzeige im Dialog).
  final String reasoning;

  const DuplicateCheckResult({
    required this.duplicateIds,
    required this.reasoning,
  });

  bool get hasDuplicates => duplicateIds.isNotEmpty;
}
