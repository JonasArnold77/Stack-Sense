import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../error/failures.dart';
import '../services/url_config_service.dart';
import '../../features/onboarding/domain/models/user_profile.dart';
import '../../features/recommendations/domain/models/supplement.dart';
import '../../features/community/domain/models/community_insight.dart';
import '../../features/recipes/domain/models/generated_recipe.dart';
import '../../features/stack/domain/models/stack_entry.dart';
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
  /// [dbOnly] — Datenbank-Modus: Claude nutzt ausschließlich echte externe
  /// Vektor-DB-Quellen (PubMed/Europe PMC/EFSA/NIH ODS/openFDA/DSLD) statt der
  /// kuratierten LLM-synthetisierten Datenbank oder Trainingswissen. Karten
  /// sehen identisch zum KI-Modus aus, Felder ohne DB-Beleg werden ehrlich
  /// als "nicht verfügbar" statt geraten dargestellt.
  Future<List<Supplement>> getRecommendations({
    required UserProfile profile,
    required String goal,
    int limit = 5,
    List<String> excludeIds = const [],
    bool dbOnly = false,
    bool bypassCache = false,
  }) async {
    final body = jsonEncode({
      'profile': _profileToJson(profile),
      'goal': goal,
      'limit': limit,
      'exclude_ids': excludeIds,
      'db_only': dbOnly,
      'bypass_cache': bypassCache,
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

  /// Vorberechnungs-Modus: nutzt die per precompute_recommendations.py
  /// vorab erzeugte Rangliste + Zusatzfelder statt bei jedem Öffnen alles
  /// neu zu generieren. [offset] paginiert durch die bereits umsortierte
  /// Liste (kein excludeIds-Muster nötig, die Reihenfolge steht ja schon fest).
  Future<List<Supplement>> getPrecomputedRecommendations({
    required UserProfile profile,
    required String goal,
    int limit = 4,
    int offset = 0,
    bool dbOnly = false,
  }) async {
    final body = jsonEncode({
      'profile': _profileToJson(profile),
      'goal': goal,
      'limit': limit,
      'offset': offset,
      'db_only': dbOnly,
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/recommendations/precomputed'),
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

  /// Schnelle, tippfehler-/schreibweise-tolerante Suche über die bekannten
  /// Supplements ("Vitamin B", "Vitamin-B", "VitaminB" finden alle dieselben
  /// Treffer) — kein LLM-Aufruf, für die Home-Screen-Suchleiste.
  /// Gibt bei Fehlern still eine leere Liste zurück (kein Suchfeld-Absturz).
  Future<List<SupplementSearchResult>> searchSupplements({
    required String query,
    int limit = 10,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/supplements/search'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({'q': query, 'limit': limit}),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['results'] as List<dynamic>? ?? [];
      return list
          .map((e) => SupplementSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supplement-Suche fehlgeschlagen: $e');
      return [];
    }
  }

  /// Generiert die volle Supplement-Karte für einen Such-Treffer (Direktsuche,
  /// kein Ziel/Profil) — respektiert den aktuellen KI-/Datenbank-Modus.
  Future<Supplement> lookupSupplement({
    required String supplementId,
    required String supplementName,
    bool dbOnly = false,
    bool bypassCache = false,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/recommendations/lookup'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({
              'supplement_id': supplementId,
              'supplement_name': supplementName,
              'db_only': dbOnly,
              'bypass_cache': bypassCache,
            }),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return _supplementFromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      debugPrint('API Fehler ${response.statusCode}: ${response.body}');
      throw ApiException('Server-Fehler: ${response.statusCode}');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Netzwerk-Fehler: $e');
      throw ApiException('Keine Verbindung zum Backend. Läuft start.ps1?');
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
      substanceCategory: parseSubstanceCategory(json['substance_category'] as String?),
      pitch: (json['pitch'] as String?) ?? '',
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
      foodCoverageScore: (json['food_coverage_score'] as num?)?.toInt() ?? 5,
      relevanceScore: (json['relevance_score'] as num?)?.toInt() ?? 75,
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

  // ---------------------------------------------------------------------------
  // Community Insights
  // ---------------------------------------------------------------------------

  /// Sendet Check-in-Daten anonym ans Backend für jeden Supplement im Stack.
  /// Scheitert still — Community-Feature ist nicht kritisch.
  Future<void> syncCheckin({
    required String deviceId,
    required String checkinDate,  // ISO "2025-06-20"
    required int sleep,
    required int energy,
    required int focus,
    required int mood,
    required List<String> supplementNames,
  }) async {
    if (supplementNames.isEmpty) return;

    final entries = supplementNames
        .map((name) => {
              'supplement_name': name,
              'checkin_date': checkinDate,
              'sleep_score': sleep,
              'energy_score': energy,
              'focus_score': focus,
              'mood_score': mood,
            })
        .toList();

    try {
      await http
          .post(
            Uri.parse('$_baseUrl/checkin-sync'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({'device_id': deviceId, 'entries': entries}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Check-in Sync fehlgeschlagen (ignoriert): $e');
    }
  }

  /// Sendet problemfeld-spezifische Check-in-Daten ans Backend.
  /// Scheitert still — Backend-Sync ist nicht kritisch (lokale Daten sind primär).
  Future<void> submitProblemCheckin({
    required String deviceId,
    required String problemFieldId,
    required DateTime date,
    required List<Map<String, int>> answers, // [{question_id: N, score: N}]
  }) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final body = jsonEncode({
      'device_id': deviceId,
      'problem_field_id': problemFieldId,
      'date': dateStr,
      'answers': answers,
    });

    try {
      await http
          .post(
            Uri.parse('$_baseUrl/api/v1/checkins/submit'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Problemfeld-Checkin Sync fehlgeschlagen (ignoriert): $e');
    }
  }

  /// Lädt aggregierte Community-Insights für eine Liste von Supplement-Namen.
  /// Gibt leere Map zurück wenn Backend nicht erreichbar.
  Future<Map<String, CommunityInsight>> getCommunityInsights(
      List<String> supplementNames) async {
    if (supplementNames.isEmpty) return {};

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/community-insights'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode(supplementNames),
          )
          .timeout(const Duration(seconds: 8));

      debugPrint('📊 Community Insights: HTTP ${response.statusCode}');
      debugPrint('📊 Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final map = data['insights'] as Map<String, dynamic>? ?? {};
        debugPrint('📊 Insights gefunden: ${map.keys.toList()}');
        return map.map((key, value) => MapEntry(
              key,
              CommunityInsight.fromJson(value as Map<String, dynamic>),
            ));
      }
    } catch (e) {
      debugPrint('Community Insights Fehler (ignoriert): $e');
    }
    return {};
  }

  /// Lädt Claude-generierte Synergie-Empfehlungen für ein Profil + Ziel.
  /// Gibt leere Liste zurück wenn Backend nicht erreichbar.
  Future<List<SupplementSynergy>> getSynergies({
    required UserProfile profile,
    required String goal,
  }) async {
    final body = jsonEncode({
      'profile': _profileToJson(profile),
      'goal': goal,
      'limit': 5,        // RecommendationRequest erwartet limit, Endpoint ignoriert es
      'exclude_ids': [],
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/synergies'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['synergies'] as List<dynamic>? ?? [];
        return list
            .map((e) => SupplementSynergy.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('Synergy API Fehler ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Synergy-Fehler (ignoriert): $e');
      return [];
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

  /// Eigene Account-Daten inkl. Tenant-Konfiguration (Multi-Tenancy) —
  /// [idToken] kommt von `AuthNotifier.getIdToken()`. Liefert null bei
  /// jedem Fehler statt zu werfen, damit ein Backend-Ausfall den Login-Flow
  /// nicht blockiert (Tenant-Konfiguration ist rein additiv/optional).
  Future<MeResponse?> getMe(String idToken) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/users/me'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(AppConstants.apiTimeout);
      if (response.statusCode != 200) return null;
      return MeResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('getMe Fehler: $e');
      return null;
    }
  }

  Map<String, dynamic> _stackEntrySummaryJson(StackEntry e) => {
        'id': e.id,
        'name': e.name,
        'substance_name': e.substanceName,
        'enthaltene_wirkstoffe': e.enthalteneWirkstoffe,
        'dosage_amount': e.dosageAmount,
        'dosage_unit': e.dosageUnit,
      };

  /// Generiert 3-5 personalisierte Rezepte via Claude (Backend berechnet die
  /// Nährstoff-Übersicht + Stack-Abdeckung danach deterministisch, nicht
  /// von Claude geschätzt). Der Stack wird nur als thematischer Kontext
  /// mitgeschickt — keine gespeicherten Standard-Präferenzen, jeder Abruf
  /// nutzt frisch eingegebene Filter-Werte.
  Future<List<GeneratedRecipe>> generateRecipes({
    required DietType dietType,
    required List<CarbBase> carbBases,
    required List<String> allergies,
    required int maxCookTimeMinutes,
    required List<StackEntry> stack,
  }) async {
    final body = jsonEncode({
      'diet_type': dietType.name,
      'carb_bases': carbBases.map((c) => c.name).toList(),
      'allergies': allergies,
      'max_cook_time_minutes': maxCookTimeMinutes,
      'stack': stack.map(_stackEntrySummaryJson).toList(),
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/recipes/generate'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['recipes'] as List<dynamic>;
        return list
            .map((e) => GeneratedRecipe.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('API Fehler ${response.statusCode}: ${response.body}');
        throw ApiException('Server-Fehler: ${response.statusCode}');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Netzwerk-Fehler: $e');
      throw ApiException('Keine Verbindung zum Backend. Läuft start.ps1?');
    }
  }

  /// Berechnet die Stack-Abdeckung eines gespeicherten Rezepts frisch gegen
  /// den AKTUELLEN Stack (für "Für heute aktivieren") — nicht gegen einen
  /// beim Speichern zwischengespeicherten Stand, der Stack kann sich seitdem
  /// geändert haben.
  Future<List<CoveredSupplement>> computeRecipeCoverage({
    required List<RecipeIngredient> ingredients,
    required List<StackEntry> stack,
  }) async {
    final body = jsonEncode({
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'stack': stack.map(_stackEntrySummaryJson).toList(),
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/recipes/coverage'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['covered_stack_supplements'] as List<dynamic>;
        return list
            .map((e) => CoveredSupplement.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('API Fehler ${response.statusCode}: ${response.body}');
        throw ApiException('Server-Fehler: ${response.statusCode}');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Netzwerk-Fehler: $e');
      throw ApiException('Keine Verbindung zum Backend. Läuft start.ps1?');
    }
  }

  /// Welche Supplement-Slugs kuratierte Nährstoffdaten haben (unabhängig vom
  /// Rezept-Feature) — fürs "Durch Ernährung abdeckbar"-Badge auf Supplement-
  /// Karten, siehe lib/core/utils/slug_match.dart. Ändert sich nur bei
  /// manueller Kuration, daher unkritisch bei Fehlschlag (Badge bleibt
  /// einfach aus statt die Karte zum Absturz zu bringen).
  Future<Set<String>> getNutrientMappableSlugs() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/recipes/nutrient-mappable-slugs'))
        .timeout(AppConstants.apiTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['slugs'] as List<dynamic>).cast<String>().toSet();
    }
    throw ApiException('Server-Fehler: ${response.statusCode}');
  }
}

/// Antwort von GET /users/me — Account-Rolle + optionale Tenant-Konfiguration
/// (nur befüllt wenn der Nutzer einem AKTIVEN Tenant zugewiesen ist).
class MeResponse {
  final String id;
  final String email;
  final String role;
  final String? tenantId;
  final String? tenantName;
  final Map<String, dynamic> features;
  final Map<String, dynamic> branding;

  const MeResponse({
    required this.id,
    required this.email,
    required this.role,
    this.tenantId,
    this.tenantName,
    this.features = const {},
    this.branding = const {},
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) => MeResponse(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        tenantId: json['tenant_id'] as String?,
        tenantName: json['tenant_name'] as String?,
        features: (json['features'] as Map<String, dynamic>?) ?? const {},
        branding: (json['branding'] as Map<String, dynamic>?) ?? const {},
      );
}

/// Netzwerk-/API-Fehler aus dem Backend.
/// Erweitert [NetworkFailure] aus der AppFailure-Hierarchie —
/// bestehende `on ApiException`-Catches funktionieren weiterhin,
/// neu geschriebener Code kann `on AppFailure` verwenden.
class ApiException extends NetworkFailure {
  const ApiException(String message) : super(message: message);
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
