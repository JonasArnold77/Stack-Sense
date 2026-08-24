import 'package:flutter/material.dart';

/// Laufzeit-Konfiguration der aktuellen Partei (Multi-Tenancy) — kommt aus
/// GET /users/me (`AuthState`), niemals lokal gespeichert. [TenantConfig.none]
/// ist der Default für Nutzer ohne (oder mit inaktivem) Tenant — identisch
/// zum bisherigen LifeLab-Standardverhalten.
class TenantConfig {
  final String? tenantId;
  final String? tenantName;
  final String? appName;
  final Color? primaryColor;
  final Map<String, bool> features;

  const TenantConfig({
    this.tenantId,
    this.tenantName,
    this.appName,
    this.primaryColor,
    this.features = const {},
  });

  static const none = TenantConfig();

  bool get hasTenant => tenantId != null;

  bool featureEnabled(String key, {bool defaultValue = true}) =>
      features[key] ?? defaultValue;

  /// Zwei-Ton-Gradient aus der Partei-Primärfarbe — analog zu
  /// AppColors.primaryGradient (Grundfarbe → abgedunkelte Variante).
  LinearGradient? get primaryGradient {
    final color = primaryColor;
    if (color == null) return null;
    final hsl = HSLColor.fromColor(color);
    final darker = hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color, darker],
    );
  }

  factory TenantConfig.fromMe({
    required String? tenantId,
    required String? tenantName,
    required Map<String, dynamic> features,
    required Map<String, dynamic> branding,
  }) {
    if (tenantId == null) return TenantConfig.none;
    return TenantConfig(
      tenantId: tenantId,
      tenantName: tenantName,
      appName: branding['app_name'] as String?,
      primaryColor: _parseHexColor(branding['primary_color'] as String?),
      features: features.map((k, v) => MapEntry(k, v == true)),
    );
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
