import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Auth-Status Enum
// ---------------------------------------------------------------------------

enum AuthStatus {
  unknown,       // Noch nicht geprüft
  authenticated, // Eingeloggt
  unauthenticated, // Nicht eingeloggt
  confirmingEmail, // Warte auf Email-Bestätigung
}

// ---------------------------------------------------------------------------
// Auth-State
// ---------------------------------------------------------------------------

class AuthState {
  final AuthStatus status;
  final String? email;        // Email des eingeloggten Users
  final String? userId;       // Cognito Sub (Backend user.id ist UUID, sub ist string)
  final String? role;         // 'user' | 'admin' (aus Backend /users/me)
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.email,
    this.userId,
    this.role,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isAdmin => role == 'admin';

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? userId,
    String? role,
    String? errorMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        email: email ?? this.email,
        userId: userId ?? this.userId,
        role: role ?? this.role,
        errorMessage: errorMessage,
      );
}

// ---------------------------------------------------------------------------
// Auth-Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _checkSession();
  }

  /// Prüft beim App-Start ob eine gültige Session vorhanden ist.
  Future<void> _checkSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        await _loadUserAttributes();
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _loadUserAttributes() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final email = attributes
          .firstWhere(
            (a) => a.userAttributeKey == CognitoUserAttributeKey.email,
            orElse: () => const AuthUserAttribute(
              userAttributeKey: CognitoUserAttributeKey.email,
              value: '',
            ),
          )
          .value;

      final sub = attributes
          .firstWhere(
            (a) => a.userAttributeKey == CognitoUserAttributeKey.sub,
            orElse: () => const AuthUserAttribute(
              userAttributeKey: CognitoUserAttributeKey.sub,
              value: '',
            ),
          )
          .value;

      state = state.copyWith(
        status: AuthStatus.authenticated,
        email: email,
        userId: sub,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  // --- Login mit Email + Passwort ---

  Future<bool> signIn(String email, String password) async {
    try {
      state = state.copyWith(errorMessage: null);
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        await _loadUserAttributes();
        return true;
      } else if (result.nextStep.signInStep ==
          AuthSignInStep.confirmSignUp) {
        state = state.copyWith(
          status: AuthStatus.confirmingEmail,
          email: email,
        );
        return false;
      }
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: _mapError(e));
      return false;
    }
  }

  // --- Registrierung ---

  Future<bool> signUp(String email, String password,
      {required String name, required String city}) async {
    try {
      state = state.copyWith(errorMessage: null);

      // Zeitzone automatisch vom Gerät ermitteln
      final timezone = DateTime.now().timeZoneName;

      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            CognitoUserAttributeKey.email: email,
            CognitoUserAttributeKey.name: name.trim(),
            CognitoUserAttributeKey.address: city.trim(),
            CognitoUserAttributeKey.zoneinfo: timezone,
          },
        ),
      );

      if (result.nextStep.signUpStep == AuthSignUpStep.confirmSignUp) {
        state = state.copyWith(
          status: AuthStatus.confirmingEmail,
          email: email,
        );
        return true;
      }
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: _mapError(e));
      return false;
    }
  }

  // --- Email-Bestätigung ---

  Future<bool> confirmSignUp(String email, String code) async {
    try {
      state = state.copyWith(errorMessage: null);
      final result = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: code,
      );
      if (result.isSignUpComplete) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return true;
      }
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: _mapError(e));
      return false;
    }
  }

  // --- Bestätigungs-Code erneut senden ---

  Future<void> resendConfirmationCode(String email) async {
    await Amplify.Auth.resendSignUpCode(username: email);
  }

  // --- Google Sign-In ---

  Future<bool> signInWithGoogle() async {
    try {
      state = state.copyWith(errorMessage: null);
      final result = await Amplify.Auth.signInWithWebUI(
        provider: AuthProvider.google,
      );
      if (result.isSignedIn) {
        await _loadUserAttributes();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: _mapError(e));
      return false;
    }
  }

  // --- Passwort vergessen ---

  Future<bool> resetPassword(String email) async {
    try {
      state = state.copyWith(errorMessage: null);
      await Amplify.Auth.resetPassword(username: email);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: _mapError(e));
      return false;
    }
  }

  Future<bool> confirmResetPassword(
      String email, String code, String newPassword) async {
    try {
      state = state.copyWith(errorMessage: null);
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: code,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: _mapError(e));
      return false;
    }
  }

  // --- Logout ---

  Future<void> signOut() async {
    await Amplify.Auth.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // --- ID-Token für API-Calls holen ---

  Future<String?> getIdToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      return session.userPoolTokensResult.value.idToken.raw;
    } catch (_) {
      return null;
    }
  }

  // --- Fehlermeldungen auf Deutsch ---

  String _mapError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('user does not exist') ||
        msg.contains('incorrect username or password')) {
      return 'Email oder Passwort ist falsch.';
    }
    if (msg.contains('user already exists')) {
      return 'Diese Email-Adresse ist bereits registriert.';
    }
    if (msg.contains('invalid verification code')) {
      return 'Der Bestätigungscode ist ungültig.';
    }
    if (msg.contains('expired')) {
      return 'Der Code ist abgelaufen. Bitte neu anfordern.';
    }
    if (msg.contains('password') && msg.contains('policy')) {
      return 'Passwort muss mind. 8 Zeichen, Groß-/Kleinbuchstaben und Zahlen enthalten.';
    }
    if (msg.contains('network')) {
      return 'Keine Internetverbindung.';
    }
    return e.message;
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// Gibt den ID-Token zurück — wird vom ApiService für Auth-Header genutzt.
final idTokenProvider = FutureProvider<String?>((ref) async {
  final notifier = ref.read(authProvider.notifier);
  return notifier.getIdToken();
});
