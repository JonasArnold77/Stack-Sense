import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/repositories/xp_repository.dart';

/// SharedPreferences-Implementierung von [XpRepository].
class SharedPreferencesXpRepository implements XpRepository {
  @override
  Future<int> getXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyUserXp) ?? 0;
  }

  @override
  Future<void> saveXp(int xp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyUserXp, xp);
  }
}
