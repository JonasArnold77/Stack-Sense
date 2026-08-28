import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_screen_header.dart';

/// Rezepte-Tab — Platzhalter für Phase A (Feature-Flag + Bottom-Nav-Grundgerüst).
/// Wird in Phase B durch die eigentliche Rezept-Bibliothek ersetzt.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientScreenHeader(
            title: 'Rezepte',
            subtitle: 'Personalisierte Rezepte für deinen Stack',
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Rezeptgenerierung folgt in Kürze.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
