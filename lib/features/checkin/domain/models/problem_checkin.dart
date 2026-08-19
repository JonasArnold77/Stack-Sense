/// Eine Frage für ein bestimmtes Problemfeld.
class ProblemCheckinQuestion {
  final int id;
  final String problemFieldId;
  final String questionText;
  final int sortOrder;

  const ProblemCheckinQuestion({
    required this.id,
    required this.problemFieldId,
    required this.questionText,
    required this.sortOrder,
  });
}

/// Eine Antwort auf eine Frage (score 1–5).
class ProblemCheckinAnswer {
  final int questionId;
  final int score; // 1–5

  const ProblemCheckinAnswer({
    required this.questionId,
    required this.score,
  });

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'score': score,
      };
}

/// Ein abgeschlossener Check-in für ein Problemfeld an einem Tag.
class ProblemCheckinEntry {
  final String problemFieldId;
  final DateTime date;
  final List<ProblemCheckinAnswer> answers;

  const ProblemCheckinEntry({
    required this.problemFieldId,
    required this.date,
    required this.answers,
  });

  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  /// Durchschnittsscore über alle Antworten (1.0–5.0).
  double get avgScore {
    if (answers.isEmpty) return 0;
    return answers.map((a) => a.score).reduce((a, b) => a + b) / answers.length;
  }

  Map<String, dynamic> toJson() => {
        'problemFieldId': problemFieldId,
        'date': date.toIso8601String(),
        'answers': answers.map((a) => a.toJson()).toList(),
      };

  factory ProblemCheckinEntry.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as List<dynamic>? ?? [];
    return ProblemCheckinEntry(
      problemFieldId: json['problemFieldId'] as String,
      date: DateTime.parse(json['date'] as String),
      answers: rawAnswers
          .map((a) => ProblemCheckinAnswer(
                questionId: (a as Map<String, dynamic>)['question_id'] as int,
                score: a['score'] as int,
              ))
          .toList(),
    );
  }
}

/// Status eines Problemfeld-Check-ins für heute.
enum DailyCheckinStatus {
  /// Kein aktives Supplement für dieses Problemfeld.
  inactive,

  /// Problemfeld ist aktiv, aber heute noch nicht eingecheckt.
  pending,

  /// Heute bereits eingecheckt.
  completed,
}

/// Zusammenfassung des Check-in-Status für ein Problemfeld.
class ProblemFieldCheckinSummary {
  final String problemFieldId;
  final DailyCheckinStatus status;
  final double? todayAvgScore; // null wenn noch kein Check-in heute

  const ProblemFieldCheckinSummary({
    required this.problemFieldId,
    required this.status,
    this.todayAvgScore,
  });
}

/// Mapping: Ziel-Label aus goalData → Problemfeld-ID für Check-ins.
///
/// Alle goalData-Labels sind erfasst. Ziele ohne eigene Fragen bekommen
/// generische Fragen (negative IDs, rein lokal, kein Backend-Sync).
const Map<String, String> kGoalLabelToProblemFieldId = {
  // ── Ziele mit dedizierten Fragen (Backend-Sync) ──────────────────────────
  'Besserer Schlaf':            'Schlaf',
  'Mehr Energie':               'Energie',
  'Fokus & Konzentration':      'Fokus',
  'Stimmung & Wohlbefinden':    'Stimmung',
  'Sport & Regeneration':       'Sport',
  'Immunsystem stärken':        'Immunsystem',
  'Verdauung':                  'Verdauung',
  'Frauengesundheit / Zyklus':  'Frauengesundheit',
  // ── Ziele mit generischen Fragen (nur lokal) ─────────────────────────────
  'Herzgesundheit':             'Herzgesundheit',
  'Haut & Haare':               'Haut',
  'Gewichtsmanagement':         'Gewicht',
  'Gelenkgesundheit':           'Gelenke',
  'Hormonbalance':              'Hormone',
  'Basis-Supplementierung':     'Basis',
};

/// Umgekehrtes Mapping: Problemfeld-ID → lesbarer Kurzname.
const Map<String, String> kProblemFieldLabel = {
  'Schlaf':           'Schlaf',
  'Energie':          'Energie',
  'Fokus':            'Fokus',
  'Stimmung':         'Stimmung',
  'Sport':            'Sport',
  'Immunsystem':      'Immunsystem',
  'Verdauung':        'Verdauung',
  'Frauengesundheit': 'Frauengesundheit',
  'Herzgesundheit':   'Herzgesundheit',
  'Haut':             'Haut & Haare',
  'Gewicht':          'Gewichtsmanagement',
  'Gelenke':          'Gelenkgesundheit',
  'Hormone':          'Hormonbalance',
  'Basis':            'Basis-Supplementierung',
};

/// Problemfelder mit dedizierten Backend-Fragen.
/// Nur diese werden ans Backend synchronisiert.
const Set<String> kBackendSyncedFields = {
  'Schlaf', 'Energie', 'Fokus', 'Stimmung',
  'Sport', 'Immunsystem', 'Verdauung', 'Frauengesundheit',
};
