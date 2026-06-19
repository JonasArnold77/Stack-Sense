import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'amplifyconfiguration.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/widgets/xp_reward_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Umgebungsvariablen laden
  await dotenv.load(fileName: '.env');

  // Amplify / Cognito initialisieren
  await _configureAmplify();

  runApp(
    const ProviderScope(
      child: StackSenseApp(),
    ),
  );
}

Future<void> _configureAmplify() async {
  // Verhindert doppeltes Konfigurieren (z.B. bei Hot Reload)
  if (Amplify.isConfigured) return;

  try {
    await Amplify.addPlugin(AmplifyAuthCognito());
    await Amplify.configure(amplifyconfig);
    safePrint('Amplify konfiguriert.');
  } on AmplifyAlreadyConfiguredException {
    safePrint('Amplify war bereits konfiguriert.');
  } catch (e) {
    safePrint('Amplify-Konfiguration fehlgeschlagen: $e');
    // App startet trotzdem — Auth-Screens zeigen entsprechende Fehlermeldung
  }
}

class StackSenseApp extends ConsumerWidget {
  const StackSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return XpRewardOverlay(
      child: MaterialApp.router(
        title: 'StackSense',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }
}
