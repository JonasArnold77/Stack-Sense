import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../recommendations/domain/models/supplement.dart';
import '../../data/stack_provider.dart';
import '../../domain/models/inventory_package.dart';
import 'inventory_package_sheet.dart';

/// "Bald leer" — Nachbestell-Fenster für eine (fast) leere Packung.
Future<void> showInventoryReorderSheet(
  BuildContext context,
  WidgetRef ref,
  InventoryPackage package,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusL)),
    ),
    builder: (_) => _ReorderSheet(package: package),
  );
}

class _ReorderSheet extends ConsumerStatefulWidget {
  final InventoryPackage package;
  const _ReorderSheet({required this.package});

  @override
  ConsumerState<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends ConsumerState<_ReorderSheet> {
  List<ProductLink>? _links;
  bool _loading = false;
  String? _error;

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final stack = ref.read(stackProvider);
    final entry = stack.where((e) => e.id == widget.package.stackEntryId).firstOrNull;
    try {
      final links = await ApiService.instance.getProductSuggestions(
        supplementName: entry?.name ?? widget.package.productName,
        substanceName: entry?.substanceName,
        categories: entry?.categories ?? const [],
      );
      if (mounted) setState(() => _links = links);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Kaufoptionen konnten nicht geladen werden.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.package;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppColors.evidenceRed),
                const SizedBox(width: AppConstants.spaceS),
                Expanded(
                  child: Text(
                    'Bald leer',
                    style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${p.productName} (${p.shop}) geht zur Neige.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppConstants.spaceL),

            if (p.reorderUrl != null && _links == null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _launch(p.reorderUrl!),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Jetzt nachbestellen'),
                ),
              ),
              const SizedBox(height: AppConstants.spaceS),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _loading ? null : _loadOptions,
                  child: const Text('Andere Kaufoptionen suchen'),
                ),
              ),
            ] else if (_links == null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _loadOptions,
                  icon: _loading
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search, size: 18),
                  label: Text(_loading ? 'Suche…' : 'Kaufoptionen laden'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppConstants.spaceS),
                Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.evidenceRed)),
              ],
            ] else ...[
              if (_links!.isEmpty)
                Text('Keine Produkte gefunden.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))
              else
                ..._links!.map((link) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.storefront_outlined, color: AppColors.primary),
                      title: Text(link.label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(link.note ?? link.shop, style: AppTextStyles.caption),
                      trailing: const Icon(Icons.open_in_new, size: 16),
                      onTap: () => _launch(link.url),
                    )),
            ],

            const SizedBox(height: AppConstants.spaceS),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openInventoryPackageSheet(context, ref, stackEntryId: p.stackEntryId);
                },
                child: const Text('Neue Packung eintragen'),
              ),
            ),
            const SizedBox(height: AppConstants.spaceXS),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Später'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
