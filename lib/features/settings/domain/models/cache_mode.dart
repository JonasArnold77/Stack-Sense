/// Steuert, ob der 6h-In-Memory-Cache des Backends für Live-Empfehlungen
/// genutzt wird. Reiner Testmodus — für den normalen Betrieb sollte der
/// Cache aktiv bleiben (spart Zeit/Kosten bei wiederholten Anfragen).
enum CacheMode {
  /// Standard: Backend darf gecachte Antworten zurückgeben (bis zu 6h alt).
  cached,

  /// Testmodus: jede Anfrage wird beim Backend als "immer frisch generieren"
  /// markiert — ignoriert vorhandene Cache-Einträge beim Lesen.
  noCache,
}
