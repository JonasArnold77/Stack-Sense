/// Gemeinsamer Tages-Schlüssel für per-Tag gespeicherten Zustand
/// (z.B. TakenNotifier, RecipeOverrideNotifier) — Format "id_yyyy-MM-dd".
/// Extrahiert aus TakenNotifier, damit beide Provider exakt dasselbe
/// Schlüsselformat nutzen statt es zweimal zu duplizieren.
String dayKey(String id, DateTime date) =>
    '${id}_${date.year}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
