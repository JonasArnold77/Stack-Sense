/// Hardcodierte Check-in-Fragen pro Problemfeld.
///
/// Diese Fragen entsprechen exakt den Einträgen in der DB-Tabelle
/// `checkin_questions` (befüllt via `init_checkin_tables` → seed_sql).
///
/// Die `id`-Felder müssen mit den DB-IDs übereinstimmen.
/// Da die DB per INSERT … WHERE NOT EXISTS befüllt wird und PostgreSQL
/// SERIAL von 1 hochzählt, sind die IDs deterministisch.
///
/// Reihenfolge in seed_sql:
///   Schlaf 1–4, Energie 5–8, Fokus 9–12, Stimmung 13–16,
///   Sport 17–20, Immunsystem 21–24, Verdauung 25–28

import '../domain/models/problem_checkin.dart';

const Map<String, List<ProblemCheckinQuestion>> kProblemCheckinQuestions = {
  'Schlaf': [
    ProblemCheckinQuestion(
      id: 1,
      problemFieldId: 'Schlaf',
      questionText: 'Wie gut hast du geschlafen?',
      sortOrder: 0,
    ),
    ProblemCheckinQuestion(
      id: 2,
      problemFieldId: 'Schlaf',
      questionText: 'Wie lange hat das Einschlafen gedauert?',
      sortOrder: 1,
    ),
    ProblemCheckinQuestion(
      id: 3,
      problemFieldId: 'Schlaf',
      questionText: 'Wie erholt hast du dich beim Aufwachen gefühlt?',
      sortOrder: 2,
    ),
    ProblemCheckinQuestion(
      id: 4,
      problemFieldId: 'Schlaf',
      questionText: 'Wie war deine Energie am Vormittag?',
      sortOrder: 3,
    ),
  ],
  'Energie': [
    ProblemCheckinQuestion(
      id: 5,
      problemFieldId: 'Energie',
      questionText: 'Wie war dein Energielevel heute?',
      sortOrder: 0,
    ),
    ProblemCheckinQuestion(
      id: 6,
      problemFieldId: 'Energie',
      questionText: 'Wie gut konntest du körperliche Aufgaben erfüllen?',
      sortOrder: 1,
    ),
    ProblemCheckinQuestion(
      id: 7,
      problemFieldId: 'Energie',
      questionText: 'Hattest du einen Nachmittagstief?',
      sortOrder: 2,
    ),
    ProblemCheckinQuestion(
      id: 8,
      problemFieldId: 'Energie',
      questionText: 'Wie erholt fühlst du dich insgesamt?',
      sortOrder: 3,
    ),
  ],
  'Fokus': [
    ProblemCheckinQuestion(
      id: 9,
      problemFieldId: 'Fokus',
      questionText: 'Wie gut konntest du dich konzentrieren?',
      sortOrder: 0,
    ),
    ProblemCheckinQuestion(
      id: 10,
      problemFieldId: 'Fokus',
      questionText: 'Wie klar war dein Denken heute?',
      sortOrder: 1,
    ),
    ProblemCheckinQuestion(
      id: 11,
      problemFieldId: 'Fokus',
      questionText: 'Wie gut hast du Aufgaben zu Ende gebracht?',
      sortOrder: 2,
    ),
    ProblemCheckinQuestion(
      id: 12,
      problemFieldId: 'Fokus',
      questionText: 'Wie war deine mentale Ausdauer?',
      sortOrder: 3,
    ),
  ],
  'Stimmung': [
    ProblemCheckinQuestion(
      id: 13,
      problemFieldId: 'Stimmung',
      questionText: 'Wie war deine allgemeine Stimmung heute?',
      sortOrder: 0,
    ),
    ProblemCheckinQuestion(
      id: 14,
      problemFieldId: 'Stimmung',
      questionText: 'Wie motiviert hast du dich gefühlt?',
      sortOrder: 1,
    ),
    ProblemCheckinQuestion(
      id: 15,
      problemFieldId: 'Stimmung',
      questionText: 'Wie gut konntest du mit Stress umgehen?',
      sortOrder: 2,
    ),
    ProblemCheckinQuestion(
      id: 16,
      problemFieldId: 'Stimmung',
      questionText: 'Wie positiv war dein Ausblick auf den Tag?',
      sortOrder: 3,
    ),
  ],
  'Sport': [
    ProblemCheckinQuestion(
      id: 17,
      problemFieldId: 'Sport',
      questionText: 'Wie war deine körperliche Leistung?',
      sortOrder: 0,
    ),
    ProblemCheckinQuestion(
      id: 18,
      problemFieldId: 'Sport',
      questionText: 'Wie gut war deine Ausdauer?',
      sortOrder: 1,
    ),
    ProblemCheckinQuestion(
      id: 19,
      problemFieldId: 'Sport',
      questionText: 'Wie schnell hast du dich erholt?',
      sortOrder: 2,
    ),
    ProblemCheckinQuestion(
      id: 20,
      problemFieldId: 'Sport',
      questionText: 'Wie hoch war deine Motivation?',
      sortOrder: 3,
    ),
  ],
  'Immunsystem': [
    ProblemCheckinQuestion(
      id: 21,
      problemFieldId: 'Immunsystem',
      questionText: 'Wie wohl hast du dich körperlich gefühlt?',
      sortOrder: 0,
    ),
    ProblemCheckinQuestion(
      id: 22,
      problemFieldId: 'Immunsystem',
      questionText: 'Hattest du Anzeichen von Erkältung oder Unwohlsein?',
      sortOrder: 1,
    ),
    ProblemCheckinQuestion(
      id: 23,
      problemFieldId: 'Immunsystem',
      questionText: 'Wie war deine allgemeine Widerstandsfähigkeit?',
      sortOrder: 2,
    ),
    ProblemCheckinQuestion(
      id: 24,
      problemFieldId: 'Immunsystem',
      questionText: 'Wie gut hast du auf Stress reagiert?',
      sortOrder: 3,
    ),
  ],
  'Verdauung': [
    ProblemCheckinQuestion(
      id: 25,
      problemFieldId: 'Verdauung',
      questionText: 'Wie gut war deine Verdauung heute?',
      sortOrder: 0,
    ),
    ProblemCheckinQuestion(
      id: 26,
      problemFieldId: 'Verdauung',
      questionText: 'Hattest du Beschwerden nach dem Essen?',
      sortOrder: 1,
    ),
    ProblemCheckinQuestion(
      id: 27,
      problemFieldId: 'Verdauung',
      questionText: 'Wie war dein Hunger- und Sättigungsgefühl?',
      sortOrder: 2,
    ),
    ProblemCheckinQuestion(
      id: 28,
      problemFieldId: 'Verdauung',
      questionText: 'Wie war dein Energielevel nach den Mahlzeiten?',
      sortOrder: 3,
    ),
  ],
};

// ---------------------------------------------------------------------------
// Generische Fallback-Fragen (negative IDs → rein lokal, kein Backend-Sync)
// ---------------------------------------------------------------------------

/// Generische Fragen für Ziele ohne dedizierte Backend-Fragen.
/// IDs sind negativ damit sie niemals mit Backend-IDs kollidieren.
const _kGenericQuestions = [
  ProblemCheckinQuestion(
    id: -1,
    problemFieldId: '__generic__',
    questionText: 'Wie geht es dir heute mit diesem Ziel?',
    sortOrder: 0,
  ),
  ProblemCheckinQuestion(
    id: -2,
    problemFieldId: '__generic__',
    questionText: 'Hast du heute Fortschritte bemerkt?',
    sortOrder: 1,
  ),
  ProblemCheckinQuestion(
    id: -3,
    problemFieldId: '__generic__',
    questionText: 'Wie war dein allgemeines Wohlbefinden?',
    sortOrder: 2,
  ),
];

/// Gibt die Fragen für ein Problemfeld zurück (offline-first).
///
/// Für Felder mit dedizierten Fragen (Schlaf, Energie etc.) werden diese
/// zurückgegeben. Für alle anderen Felder gibt es generische Fallback-Fragen
/// mit negativen IDs, die rein lokal gespeichert und NICHT ans Backend
/// synchronisiert werden.
List<ProblemCheckinQuestion> getQuestionsForField(String problemFieldId) {
  final specific = kProblemCheckinQuestions[problemFieldId];
  if (specific != null && specific.isNotEmpty) return specific;

  // Generische Fragen mit dem konkreten fieldId als problemFieldId
  return _kGenericQuestions
      .map((q) => ProblemCheckinQuestion(
            id: q.id,
            problemFieldId: problemFieldId,
            questionText: q.questionText,
            sortOrder: q.sortOrder,
          ))
      .toList();
}
