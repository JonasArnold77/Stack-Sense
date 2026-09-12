import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/combination_check_provider.dart';
import '../../data/same_goal_repeat_provider.dart';
import 'combination_check_banner.dart' show showCombinationCheckPromptPopup;
import 'same_goal_repeat_banner.dart' show showSameGoalRepeatPopup;

/// Nach einem erfolgreichen "Zum Stack hinzufügen" aufrufen — zeigt die
/// relevanten Hinweise SOFORT (statt erst beim nächsten Besuch des
/// Stack-Screens), falls die neue Zusammensetzung eine der beiden Schwellen
/// erreicht. Beide Hinweise stehen zusätzlich dauerhaft im Stack-Screen
/// (CombinationCheckBanner / SameGoalRepeatBanner) — dieselbe "erledigt"-
/// Markierung wird von beiden Darstellungen geteilt, ein "Verstanden" hier
/// lässt den Hinweis also auch dort verschwinden (und umgekehrt).
///
/// [justAddedGoalContext] ist das Problemfeld/Phasenziel/"Basissupplementierung",
/// unter dem GERADE hinzugefügt wurde — für den "erst auf Wirkung warten"-
/// Hinweis (der für Basissupplementierung ohnehin nie anschlägt, siehe
/// same_goal_repeat_provider.dart).
Future<void> showStackWarningsAfterAdd(
  BuildContext context,
  WidgetRef ref, {
  String? justAddedGoalContext,
}) async {
  if (!context.mounted) return;

  // 1) Gleiches Problemfeld/Phasenziel wiederholt — keine KI nötig, rein
  // lokal aus dem Stack abgeleitet, deshalb zuerst (sofort verfügbar).
  if (justAddedGoalContext != null) {
    final pending = ref.read(pendingSameGoalRepeatsProvider);
    final match = pending.where((r) => r.goal == justAddedGoalContext).firstOrNull;
    if (match != null) {
      await showSameGoalRepeatPopup(context, ref, match);
      if (!context.mounted) return;
    }
  }

  // 2) Gesamtzahl-Schwelle — bietet den KI-Kombinationscheck an.
  if (ref.read(shouldShowCombinationCheckPromptProvider)) {
    await showCombinationCheckPromptPopup(context, ref);
  }
}
