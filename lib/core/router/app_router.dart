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

/// Alle Route-Namen als Konstanten — nie Strings direkt verwenden.
class AppRoutes {
  AppRoutes._();

  static const String welcome = '/';
  static const String onboardingStep1 = '/onboarding/step1';
  static const String onboardingStep2 = '/onboarding/step2';
  static const String onboardingStep3 = '/onboarding/step3';
  static const String home = '/home';
  static const String recommendations = '/recommendations';
  static const String stack = '/stack';
  static const String checkin = '/checkin';
  static const String profile = '/profile';
  static const String insights = '/insights';
}

/// Riverpod Provider für den Router.
/// Ermöglicht Redirect-Logik basierend auf Auth/Onboarding-Status.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.welcome,
    debugLogDiagnostics: true,
    routes: [
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

      // --- Haupt-App (Shell mit Bottom Navigation) ---
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
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

    // Fehlerseite bei ungültigem Pfad
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Seite nicht gefunden: ${state.error}'),
      ),
    ),
  );
});
