import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/recommendations/domain/models/supplement.dart';

/// Speichert bereits geladene Empfehlungslisten lokal (SharedPreferences),
/// damit ein erneutes Öffnen desselben Themenfelds/derselben Phase sofort
/// die zuletzt geladene Liste zeigt, statt erneut generieren zu lassen —
/// nur relevant im Live-Modus (Vorberechnet lädt ohnehin schon aus der
/// Backend-Vorberechnung, keine zusätzliche lokale Speicherung nötig).
///
/// Einzige automatische Invalidierung: die Jahreszeit. Profil-Änderungen
/// lösen bewusst KEIN Neu-Laden aus — das ist für ein späteres bezahlpflichtiges
/// Feature vorgesehen, um die Kosten für KI-Berechnungen im Rahmen zu halten.
/// Bis dahin ist der einzige Weg, eine gespeicherte Liste zu verwerfen, der
/// manuelle Reset-Button auf dem Home Screen ([clearAll]).
class RecommendationLocalCache {
  RecommendationLocalCache._();
  static final instance = RecommendationLocalCache._();

  static const _keyPrefix = 'local_rec_cache::';

  String _key(String goal, bool dbOnly) => '$_keyPrefix$goal::$dbOnly';

  /// Aktuelle Jahreszeit — dieselbe Monats-Einteilung wie das Backend
  /// (services/claude_service.py: _get_season()).
  static String currentSeason([DateTime? now]) {
    final month = (now ?? DateTime.now()).month;
    if (month == 12 || month <= 2) return 'Winter';
    if (month <= 5) return 'Frühling';
    if (month <= 8) return 'Sommer';
    return 'Herbst';
  }

  /// Gibt die gespeicherte Liste zurück, wenn vorhanden UND die Jahreszeit
  /// seit dem Speichern unverändert ist — sonst null (Cache-Miss).
  Future<List<Supplement>?> getCached(String goal, bool dbOnly) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(goal, dbOnly));
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['season'] != currentSeason()) return null;
      final items = decoded['supplements'] as List<dynamic>;
      return items
          .map((e) => Supplement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Beschädigter/veralteter Eintrag — als Cache-Miss behandeln.
      return null;
    }
  }

  Future<void> save(
    String goal,
    bool dbOnly,
    List<Supplement> supplements,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'season': currentSeason(),
      'supplements': supplements.map((s) => s.toJson()).toList(),
    });
    await prefs.setString(_key(goal, dbOnly), payload);
  }

  /// Löscht ALLE gespeicherten Empfehlungslisten — vom Reset-Button auf dem
  /// Home Screen aufgerufen, um wieder alles frisch generieren zu lassen.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
