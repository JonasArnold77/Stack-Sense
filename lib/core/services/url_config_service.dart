import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Verwaltet die Backend-URL zur Laufzeit.
/// URL wird in SharedPreferences gespeichert — kein Rebuild nötig bei Änderungen.
class UrlConfigService {
  UrlConfigService._();

  static const String _key = 'backend_url';

  static const String _productionUrl =
      'http://stacksense-production.eba-3kgatrmy.eu-central-1.elasticbeanstalk.com/api/v1';

  /// Aktuell gecachte URL — nach init() immer gesetzt.
  static String _current = _productionUrl;

  static String get current => _current;

  /// Beim App-Start aufrufen — lädt gespeicherte URL aus SharedPreferences.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _current = prefs.getString(_key) ?? _productionUrl;
  }

  /// URL speichern und sofort aktiv setzen.
  static Future<void> setUrl(String url) async {
    // Trailing Slash entfernen, /api/v1 sicherstellen
    var clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!clean.endsWith('/api/v1')) clean = '$clean/api/v1';
    _current = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, clean);
  }

  /// Auf Default zurücksetzen.
  static Future<void> reset() async {
    _current = AppConstants.baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
