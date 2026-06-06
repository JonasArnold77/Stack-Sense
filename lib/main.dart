import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Umgebungsvariablen laden (.env Datei)
  await dotenv.load(fileName: '.env');

  runApp(
    // ProviderScope ist der Root-Container für alle Riverpod-Provider
    const ProviderScope(
      child: StackSenseApp(),
    ),
  );
}

class StackSenseApp extends ConsumerWidget {
  const StackSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'StackSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
