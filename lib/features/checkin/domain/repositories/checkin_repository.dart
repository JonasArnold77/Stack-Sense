import '../../domain/models/checkin_entry.dart';

/// Abstrakte Schnittstelle für Check-in Persistenz.
abstract class CheckinRepository {
  Future<List<CheckinEntry>> getAll();
  Future<void> saveAll(List<CheckinEntry> entries);
}
