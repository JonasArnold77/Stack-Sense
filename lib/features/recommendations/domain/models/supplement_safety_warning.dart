/// Statische Sicherheitswarnungen für Supplements mit Überdosierungsrisiko.
///
/// Anders als [InteractionSeverity]/`drugInteraction` (Wechselwirkung mit
/// einem konkreten Medikament) geht es hier um ein generelles Risiko der
/// Substanz selbst — unabhängig davon, welche Medikamente der Nutzer nimmt.
class SupplementSafetyWarning {
  final String message;

  const SupplementSafetyWarning({required this.message});
}

/// Schlüssel = `Supplement.id` (kebab-case Slug, siehe backend/populate_db.py).
const Map<String, SupplementSafetyWarning> kSupplementSafetyWarnings = {
  'vitamin-d3': SupplementSafetyWarning(
    message:
        'Vitamin D reichert sich im Körper an — bei dauerhaft hoher Dosierung '
        'drohen ein zu hoher Calciumspiegel im Blut und Nierenschäden. '
        'Lass vorher per Bluttest beim Arzt prüfen, ob dein Bedarf überhaupt '
        'gedeckt werden muss, und sprich die Dosierung ärztlich ab.',
  ),
  'vitamin-a': SupplementSafetyWarning(
    message:
        'Vitamin A ist fettlöslich und wird in der Leber gespeichert — bei '
        'dauerhaft hoher Dosierung drohen Leberschäden. Lass deinen Bedarf '
        'vorher per Bluttest ärztlich abklären, besonders bei Schwangerschaft.',
  ),
  'vitamin-e': SupplementSafetyWarning(
    message:
        'Vitamin E kann in hoher Dosierung über längere Zeit das Blutungsrisiko '
        'erhöhen. Sprich die Einnahme vorab mit deinem Arzt ab, besonders bei '
        'blutverdünnenden Medikamenten.',
  ),
  'eisen': SupplementSafetyWarning(
    message:
        'Eisen sollte nur bei nachgewiesenem Mangel eingenommen werden — ohne '
        'Mangel drohen Eisenüberladung und Organschäden. Lass deinen '
        'Eisenspiegel vorher per Bluttest beim Arzt prüfen.',
  ),
  'selen': SupplementSafetyWarning(
    message:
        'Selen hat eine enge Sicherheitsspanne — bereits moderat erhöhte Dosen '
        'über längere Zeit können zu einer Selenose führen. Lass deinen Bedarf '
        'vorher per Bluttest ärztlich abklären.',
  ),
  'jod': SupplementSafetyWarning(
    message:
        'Zu viel Jod kann die Schilddrüsenfunktion aus dem Gleichgewicht '
        'bringen. Lass deinen Jodstatus und deine Schilddrüsenwerte vorher '
        'beim Arzt prüfen, besonders bei bestehenden Schilddrüsenerkrankungen.',
  ),
  'zink': SupplementSafetyWarning(
    message:
        'Zink in hoher Dosierung über längere Zeit kann zu einem '
        'Kupfermangel und einer geschwächten Immunfunktion führen. Lass deinen '
        'Bedarf vorher per Bluttest ärztlich abklären.',
  ),
  'calcium': SupplementSafetyWarning(
    message:
        'Zusätzliches Calcium ohne nachgewiesenen Mangel steht im Verdacht, '
        'das Risiko für Nierensteine und Gefäßverkalkung zu erhöhen. Lass '
        'deinen Bedarf vorher per Bluttest beim Arzt prüfen.',
  ),
};

SupplementSafetyWarning? getSupplementSafetyWarning(String supplementId) =>
    kSupplementSafetyWarnings[supplementId];
