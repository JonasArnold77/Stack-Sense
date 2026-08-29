import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/nutrient_mappable_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/slug_match.dart';

/// Kleines Badge für Supplements, deren Nährstoff über Lebensmittel abdeckbar
/// ist (siehe kuratierte supplement_nutrients-Tabelle, ~27 von 69 Supplements —
/// Vitamine/Mineralstoffe/Omega-3, nicht Aminosäuren/Kräuterextrakte). Zeigt
/// sich selbst nur an wenn zutreffend — einfach überall einbauen, kein
/// bedingtes Wrapping am Call-Site nötig.
class NutrientCoverableBadge extends ConsumerWidget {
  final String name;
  final String? substanceName;
  final List<String> enthalteneWirkstoffe;

  const NutrientCoverableBadge({
    super.key,
    required this.name,
    this.substanceName,
    this.enthalteneWirkstoffe = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curatedSlugs = ref.watch(nutrientMappableSlugsProvider).valueOrNull ?? {};
    final mappable = isNutrientMappable(
      name: name,
      substanceName: substanceName,
      enthalteneWirkstoffe: enthalteneWirkstoffe,
      curatedSlugs: curatedSlugs,
    );
    if (!mappable) return const SizedBox.shrink();

    return Tooltip(
      message: 'Der Nährstoff dieses Supplements lässt sich auch über Lebensmittel abdecken',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.eco_outlined, size: 11, color: AppColors.evidenceGreen),
          const SizedBox(width: 3),
          Text(
            'Durch Ernährung abdeckbar',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.evidenceGreen,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
