/// Definiert alle möglichen Fehlertypen der App.
///
/// Statt roher Exceptions wird hier eine saubere Fehlerhierarchie genutzt,
/// damit UI-Schichten nie Exception-Details kennen müssen.
sealed class AppFailure {
  final String message;
  const AppFailure(this.message);
}

/// Persistenz-Fehler (SharedPreferences, Datei-IO)
class StorageFailure extends AppFailure {
  const StorageFailure([super.message = 'Daten konnten nicht gespeichert werden.']);
}

/// Netzwerk-/API-Fehler
class NetworkFailure extends AppFailure {
  final int? statusCode;
  const NetworkFailure({String message = 'Netzwerkfehler — bitte Verbindung prüfen.', this.statusCode})
      : super(message);
}

/// Timeout-Fehler
class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.message = 'Anfrage hat zu lange gedauert.']);
}

/// Validierungsfehler (ungültige Eingabe)
class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// Nicht gefunden
class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Eintrag nicht gefunden.']);
}

/// Unbekannter Fehler — Fallback
class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'Unbekannter Fehler aufgetreten.']);
}
