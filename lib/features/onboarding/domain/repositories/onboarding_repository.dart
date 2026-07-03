import '../../domain/models/user_profile.dart';

/// Abstrakte Schnittstelle für Nutzer-Profil-Persistenz.
abstract class OnboardingRepository {
  /// Gibt das gespeicherte Profil zurück, oder null wenn noch keins existiert.
  Future<UserProfile?> getProfile();

  /// Speichert das Profil dauerhaft.
  Future<void> saveProfile(UserProfile profile);

  /// Gibt zurück ob das Onboarding abgeschlossen wurde.
  Future<bool> isOnboardingComplete();

  /// Markiert das Onboarding als abgeschlossen.
  Future<void> setOnboardingComplete();
}
