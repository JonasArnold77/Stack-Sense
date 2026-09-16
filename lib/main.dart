import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide LogLevel;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'amplifyconfiguration.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/widgets/xp_reward_overlay.dart';
import 'features/settings/data/tenant_config_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Umgebungsvariablen laden
  await dotenv.load(fileName: '.env');

  // Amplify / Cognito initialisieren
  await _configureAmplify();

  // RevenueCat (In-App-Käufe) — nur wenn ein Key hinterlegt ist, siehe .env
  await _configureRevenueCat();

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

/// Konfiguriert RevenueCat, falls ein API-Key hinterlegt ist. Ohne Key (z.B.
/// solange der RevenueCat-Account noch nicht eingerichtet ist) bleibt die App
/// voll nutzbar — echte Käufe sind dann einfach nicht verfügbar, der
/// kostenlose Test-Aufladeknopf funktioniert unabhängig davon weiter.
/// TODO iOS: sobald das ios/-Projekt existiert, hier nach Platform.isIOS
/// verzweigen und REVENUECAT_API_KEY_IOS verwenden.
Future<void> _configureRevenueCat() async {
  final apiKey = dotenv.env['REVENUECAT_API_KEY_ANDROID'];
  if (apiKey == null || apiKey.isEmpty) {
    safePrint('RevenueCat nicht konfiguriert (kein API-Key in .env) — echte Käufe deaktiviert.');
    return;
  }
  try {
    await Purchases.setLogLevel(LogLevel.info);
    await Purchases.configure(PurchasesConfiguration(apiKey));
  } catch (e) {
    safePrint('RevenueCat-Konfiguration fehlgeschlagen: $e');
  }
}

class StackSenseApp extends ConsumerWidget {
  const StackSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final tenantConfig = ref.watch(tenantConfigProvider);

    return XpRewardOverlay(
      child: MaterialApp.router(
        title: tenantConfig.appName ?? 'LifeLab',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }
}
