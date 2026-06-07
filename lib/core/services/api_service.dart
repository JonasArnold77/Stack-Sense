import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../../features/onboarding/domain/models/user_profile.dart';
import '../../features/recommendations/domain/models/supplement.dart';
// ProductLink wird aus supplement.dart re-exportiert

/// Verbindet die Flutter App mit dem FastAPI Backend.
/// Alle Backend-Calls laufen hier durch — niemals http direkt in Widgets verwenden.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // Android-Emulator → 10.0.2.2 = localhost des PCs
  // Echtes Gerät im selben WLAN → IP-Adresse des PCs
  static const String _baseUrl = AppConstants.baseUrl;

  /// Holt personalisierte Empfehlungen von Claude via Backend.
  Future<List<Supplement>> getRecommendations({
    required UserProfile profile,
    required String goal,
  }) async {
    final body = jsonEncode({
      'profile': _profileToJson(profile),
      'goal': goal,
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

  Supplement _supplementFromJson(Map<String, dynamic> json) {
    final rawLinks = json['product_links'] as List<dynamic>? ?? [];
    final productLinks = rawLinks
        .map((e) => ProductLink.fromJson(e as Map<String, dynamic>))
        .toList();

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
      productLinks: productLinks,
    );
  }

  EvidenceLevel _parseEvidenceLevel(String raw) => switch (raw) {
        'green' => EvidenceLevel.green,
        'yellow' => EvidenceLevel.yellow,
        _ => EvidenceLevel.red,
      };
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
