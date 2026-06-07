/// App-weite Konstanten.
/// Niemals Magic Numbers oder hardcodierte Werte direkt im Widget-Code verwenden.
class AppConstants {
  AppConstants._();

  // --- Spacing ---
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // --- Border Radius ---
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusRound = 100.0;

  // --- Card ---
  static const double cardPadding = 16.0;
  static const double cardElevation = 0.0;

  // --- Screen Padding ---
  static const double screenPaddingH = 20.0;
  static const double screenPaddingV = 16.0;

  // --- Animation Durations ---
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);

  // --- API ---
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.178.186:8000/api/v1',
  );
  static const Duration apiTimeout = Duration(seconds: 30);

  // --- Onboarding ---
  static const int onboardingTotalSteps = 3;

  // --- Gamification ---
  static const int xpCheckin = 10;
  static const int xpStackUpdate = 15;
  static const int xpBloodworkUpload = 50;
  static const int xpEvidenceRead = 5;
  static const int xpProtocolShare = 20;

  // --- Evidence Level Labels ---
  static const String evidenceGreenLabel = 'Belegt';
  static const String evidenceYellowLabel = 'Hinweise';
  static const String evidenceRedLabel = 'Unbewiesen';

  // --- Storage Keys ---
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyUserProfile = 'user_profile';
  static const String keyUserStack = 'user_stack';
  static const String keyUserXp = 'user_xp';
  static const String keyUserLevel = 'user_level';
  static const String keyLastCheckin = 'last_checkin_date';
  static const String keyCheckinHistory = 'checkin_history';
}
