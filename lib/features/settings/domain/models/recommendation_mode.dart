/// Steuert, wie Supplement-Empfehlungen zustande kommen.
enum RecommendationMode {
  /// Aktueller Standard: Claude generiert personalisierte Empfehlungen,
  /// gestützt auf RAG-Kontext aus der Vektor-DB.
  llm,

  /// Nur Datenbankbezug: reine Vektor-DB-Rohdaten (Studien + kuratierte
  /// Fakten), kein LLM-Aufruf — kein Pitch-Text, keine Relevanz-Wertung.
  ragOnly,
}
