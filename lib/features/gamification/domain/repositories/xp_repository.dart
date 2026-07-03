/// Abstrakte Schnittstelle für XP-Persistenz.
abstract class XpRepository {
  Future<int> getXp();
  Future<void> saveXp(int xp);
}
