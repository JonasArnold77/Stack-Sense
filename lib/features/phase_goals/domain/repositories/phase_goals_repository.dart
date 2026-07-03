import '../../domain/models/phase_goal.dart';

/// Abstrakte Schnittstelle für Phasenziel-Persistenz.
abstract class PhaseGoalsRepository {
  Future<List<ActivePhaseGoal>> getAll();
  Future<void> saveAll(List<ActivePhaseGoal> goals);
}
