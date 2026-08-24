import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_provider.dart';
import '../domain/models/tenant_config.dart';

/// Abgeleiteter Provider aus [authProvider] — kein eigener Netzwerk-Call
/// (die Tenant-Daten kommen bereits über GET /users/me beim Login mit,
/// siehe AuthNotifier._loadBackendProfile). Aktualisiert sich automatisch
/// wenn sich der Auth-Status ändert (Login/Logout/Tenant-Wechsel nach
/// erneutem Login).
final tenantConfigProvider = Provider<TenantConfig>((ref) {
  final auth = ref.watch(authProvider);
  return TenantConfig.fromMe(
    tenantId: auth.tenantId,
    tenantName: auth.tenantName,
    features: auth.features,
    branding: auth.branding,
  );
});
