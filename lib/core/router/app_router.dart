import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_step1_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_step2_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_step3_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/recommendations/presentation/screens/recommendations_screen.dart';
import '../../features/stack/presentation/screens/stack_screen.dart';
import '../../features/checkin/presentation/screens/checkin_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/heute/presentation/screens/heute_screen.dart';
import '../../features/profile_recommendations/presentation/screens/profile_recommendations_screen.dart';
import '../../features/phase_goals/presentation/screens/phase_goals_screen.dart';
import '../../features/phase_goals/presentation/screens/phase_goal_recommendations_screen.dart';
import '../../features/phase_goals/presentation/screens/phase_goal_detail_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/confirm_email_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/data/auth_provider.dart';
import '../../features/onboarding/data/onboarding_provider.dart';

/// Alle Route-Namen als Konstanten — nie Strings direkt verwenden.
class AppRoutes {
  AppRoutes._();

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String confirmEmail = '/confirm-email';
  static const String forgotPassword = '/forgot-password';

  // Onboarding
  static const String welcome = '/';
  static const String onboardingStep1 = '/onboarding/step1';
  static const String onboardingStep2 = '/onboarding/step2';
  static const String onboardingStep3 = '/onboarding/step3';

  // App
  static const String home = '/home';
  static const String heute = '/heute';
  static const String recommendations = '/recommendations';
  static const String stack = '/stack';
  static const String checkin = '/checkin';
  static const String profile = '/profile';
  static const String insights = '/insights';
  static const String profileRecommendations = '/profile-recommendations';
  static const String phaseGoals = '/phase-goals';
  static const String phaseGoalRecommendations = '/phase-goals/recommendations';
  static const String phaseGoalDetail = '/phase-goals/detail';
}

// Routen die ohne Login zugänglich sind
const _publicRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.confirmEmail,
  AppRoutes.forgotPassword,
  AppRoutes.welcome,
  AppRoutes.onboardingStep1,
  AppRoutes.onboardingStep2,
  AppRoutes.onboardingStep3,
};

/// Riverpod Provider für den Router mit Auth-Redirect.
final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<int>(0);

  // Router neu evaluieren wenn sich Auth-Status ändert
  ref.listen(authProvider, (_, __) {
    authListenable.value++;
  });

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    refreshListenable: authListenable,

    // ---------------------------------------------------------------------------
    // Auth-Redirect: nicht eingeloggte User zu Login schicken
    // ---------------------------------------------------------------------------
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.uri.path;
      final isPublic = _publicRoutes.any((r) => location.startsWith(r));

      // Noch nicht initialisiert — kurz warten
      if (authState.status == AuthStatus.unknown) return null;

      // Email-Bestätigung ausstehend
      if (authState.status == AuthStatus.confirmingEmail) {
        if (location != AppRoutes.confirmEmail) {
          return AppRoutes.confirmEmail;
        }
        return null;
      }

      // Nicht eingeloggt → Login
      if (authState.status == AuthStatus.unauthenticated && !isPublic) {
        return AppRoutes.login;
      }

      // Eingeloggt und auf Login/Register → App
      if (authState.isAuthenticated &&
          (location == AppRoutes.login || location == AppRoutes.register)) {
        // Onboarding abgeschlossen?
        final onboardingDone =
            ref.read(onboardingProvider).onboardingCompletedAt != null;
        return onboardingDone ? AppRoutes.heute : AppRoutes.welcome;
      }

      return null;
    },

    routes: [
      // --- Auth ---
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.confirmEmail,
        name: 'confirmEmail',
        builder: (context, state) {
          final email = state.extra as String? ??
              (ref.read(authProvider).email ?? '');
          return ConfirmEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // --- Onboarding ---
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStep1,
        name: 'onboardingStep1',
        builder: (context, state) => const OnboardingStep1Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStep2,
        name: 'onboardingStep2',
        builder: (context, state) => const OnboardingStep2Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStep3,
        name: 'onboardingStep3',
        builder: (context, state) => const OnboardingStep3Screen(),
      ),

      // --- Profil-Empfehlungen (kein Shell/Bottom-Nav) ---
      GoRoute(
        path: AppRoutes.profileRecommendations,
        name: 'profileRecommendations',
        builder: (context, state) {
          final fromOnboarding =
              state.uri.queryParameters['from'] == 'onboarding';
          return ProfileRecommendationsScreen(fromOnboarding: fromOnboarding);
        },
      ),

      // --- Phasenziele (kein Shell) ---
      GoRoute(
        path: AppRoutes.phaseGoals,
        name: 'phaseGoals',
        builder: (context, state) => const PhaseGoalsScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.phaseGoalRecommendations}/:goalId',
        name: 'phaseGoalRecommendations',
        builder: (context, state) {
          final goalId = state.pathParameters['goalId']!;
          return PhaseGoalRecommendationsScreen(goalId: goalId);
        },
      ),
      GoRoute(
        path: '${AppRoutes.phaseGoalDetail}/:goalId',
        name: 'phaseGoalDetail',
        builder: (context, state) {
          final goalId = state.pathParameters['goalId']!;
          return PhaseGoalDetailScreen(goalId: goalId);
        },
      ),

      // --- Haupt-App (Shell mit Bottom Navigation) ---
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.heute,
            name: 'heute',
            builder: (context, state) => const HeuteScreen(),
          ),
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const StackScreen(),
          ),
          GoRoute(
            path: AppRoutes.recommendations,
            name: 'recommendations',
            builder: (context, state) => const RecommendationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.stack,
            name: 'stack',
            builder: (context, state) => const StackScreen(),
          ),
          GoRoute(
            path: AppRoutes.checkin,
            name: 'checkin',
            builder: (context, state) => const CheckinScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.insights,
            name: 'insights',
            builder: (context, state) => const InsightsScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Seite nicht gefunden: ${state.error}'),
      ),
    ),
  );
});
