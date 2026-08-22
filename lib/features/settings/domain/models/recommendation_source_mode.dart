/// Steuert, ob Empfehlungen live bei jedem Öffnen neu generiert werden,
/// oder aus vorberechneten Ranglisten (siehe backend/scripts/precompute_recommendations.py)
/// geladen und nur profilgewichtet umsortiert werden.
enum RecommendationSourceMode {
  /// Bisheriges Verhalten: komplette Auswahl + Reihenfolge wird bei jedem
  /// Öffnen frisch von Claude generiert. Unverändert, Standard.
  live,

  /// Grundreihenfolge + "Einfach erklärt"/"In Lebensmitteln"/"Einnahmehinweise"
  /// kommen aus der Vorberechnung — beim Öffnen wird nur noch profilgewichtet
  /// umsortiert und die individuelle Karten-Beschreibung frisch generiert.
  precomputed,
}
