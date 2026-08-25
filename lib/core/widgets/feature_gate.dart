import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/tenant_config_provider.dart';

/// Graut [child] aus und macht es nicht mehr antippbar, wenn das angegebene
/// Feature für die aktuelle Partei deaktiviert ist (siehe TenantConfig).
/// Ohne zugewiesene/aktive Partei sind laut TenantConfig.featureEnabled()
/// standardmäßig ALLE Features aktiv — u.a. genau der Fall bei `flutter run`
/// aus Android Studio ohne Tenant-Zuweisung.
class FeatureGate extends ConsumerWidget {
  final String featureKey;
  final Widget child;

  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(tenantConfigProvider).featureEnabled(featureKey);
    if (enabled) return child;

    return IgnorePointer(
      child: Opacity(opacity: 0.35, child: child),
    );
  }
}
