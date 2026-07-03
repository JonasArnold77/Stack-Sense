import '../../domain/models/stack_entry.dart';

/// Abstrakte Schnittstelle für Lese- und Schreibzugriff auf den Supplement-Stack.
///
/// Ermöglicht Dependency Injection und einfaches Mocking in Tests.
/// Die konkrete Implementierung (SharedPreferences, Datenbank, API) ist der
/// Presentation-Schicht nicht bekannt.
abstract class StackRepository {
  /// Lädt alle Stack-Einträge aus der Persistenzschicht.
  Future<List<StackEntry>> getAll();

  /// Speichert die gesamte Liste (vollständige Überschreibung).
  Future<void> saveAll(List<StackEntry> entries);
}
