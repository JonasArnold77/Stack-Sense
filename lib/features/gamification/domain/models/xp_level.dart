/// XP-Level-System für StackSense.
///
/// Level steigen durch Interaktion — nicht durch Ergebnisse.
/// Jede ehrliche Nutzung zählt.
class XpLevel {
  final int totalXp;

  const XpLevel(this.totalXp);

  // --- Level-Definition ---
  // Schwelle = kumulierte XP um dieses Level zu erreichen
  static const List<_LevelDef> _levels = [
    _LevelDef(1, 'Einsteiger', 0, 100),
    _LevelDef(2, 'Informiert', 100, 250),
    _LevelDef(3, 'Bewusst', 250, 500),
    _LevelDef(4, 'Optimiert', 500, 1000),
    _LevelDef(5, 'Experte', 1000, 99999),
  ];

  /// Aktuelles Level (1–5)
  int get level => _current.level;

  /// Name des aktuellen Levels
  String get levelName => _current.name;

  /// XP-Fortschritt innerhalb des aktuellen Levels
  int get xpInLevel => totalXp - _current.xpStart;

  /// XP benötigt für nächstes Level (Breite des aktuellen Levels)
  int get xpForNextLevel => _current.xpEnd - _current.xpStart;

  /// Fortschrittsanteil 0.0–1.0 für ProgressBar
  double get progress {
    if (level >= 5) return 1.0;
    return (xpInLevel / xpForNextLevel).clamp(0.0, 1.0);
  }

  /// XP bis zum nächsten Level
  int get xpRemaining {
    if (level >= 5) return 0;
    return xpForNextLevel - xpInLevel;
  }

  /// Ist das maximale Level erreicht?
  bool get isMaxLevel => level >= 5;

  _LevelDef get _current {
    for (var i = _levels.length - 1; i >= 0; i--) {
      if (totalXp >= _levels[i].xpStart) return _levels[i];
    }
    return _levels.first;
  }
}

class _LevelDef {
  final int level;
  final String name;
  final int xpStart;
  final int xpEnd;

  const _LevelDef(this.level, this.name, this.xpStart, this.xpEnd);
}
