import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/dose_parser.dart';
import '../../data/inventory_provider.dart';
import '../../data/stack_provider.dart';
import '../../domain/models/inventory_package.dart';
import 'inventory_package_sheet.dart';
import 'inventory_reorder_sheet.dart';

/// "Lager" — dritter Tab im Stack-Screen. Zeigt die real gekauften Packungen
/// mit Restmenge (aus den Kalender-Einnahmen abgeleitet, siehe
/// inventoryStatusProvider) und einem Nachbestell-Zugang bei "bald leer".
class InventoryTab extends ConsumerWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(inventoryProvider);
    final status = ref.watch(inventoryStatusProvider);
    final stack = ref.watch(stackProvider);
    final entryName = {for (final e in stack) e.id: e.name};

    final hasEligible = stack.any((e) => trackableDoseFor(e) != null);

    if (packages.isEmpty) {
      return _Empty(
        canAdd: hasEligible,
        onAdd: () => openInventoryPackageSheet(context, ref),
      );
    }

    final sorted = [...packages]..sort((a, b) {
        final la = status[a.id]?.isLowStock ?? false;
        final lb = status[b.id]?.isLowStock ?? false;
        if (la != lb) return la ? -1 : 1; // bald leer zuerst
        return a.productName.toLowerCase().compareTo(b.productName.toLowerCase());
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH, AppConstants.spaceM, AppConstants.screenPaddingH, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${packages.length} Packung${packages.length == 1 ? '' : 'en'} im Lager',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
              TextButton.icon(
                onPressed: () => openInventoryPackageSheet(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Packung'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(AppConstants.screenPaddingH, AppConstants.spaceS,
                AppConstants.screenPaddingH, AppConstants.spaceXL),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final p = sorted[i];
              return _PackageRow(
                package: p,
                status: statusForPackage(status, p),
                supplementName: entryName[p.stackEntryId] ?? p.productName,
                onEdit: () => openInventoryPackageSheet(context, ref, existing: p),
                onDelete: () => ref.read(inventoryProvider.notifier).removePackage(p.id),
                onReorder: () => showInventoryReorderSheet(context, ref, p),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PackageRow extends StatelessWidget {
  final InventoryPackage package;
  final PackageStatus status;
  final String supplementName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReorder;

  const _PackageRow({
    required this.package,
    required this.status,
    required this.supplementName,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final frac = package.totalUnits <= 0
        ? 0.0
        : (status.remaining / package.totalUnits).clamp(0.0, 1.0);
    final low = status.isLowStock;
    final barColor = low ? AppColors.evidenceRed : AppColors.primary;

    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(color: low ? AppColors.evidenceRed.withOpacity(0.5) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(package.productName,
                          style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '$supplementName · ${package.shop}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textTertiary),
                  tooltip: 'Packung entfernen',
                  style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spaceS),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 8,
                backgroundColor: AppColors.border.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${_fmt(status.remaining)} / ${_fmt(package.totalUnits)} ${package.unit}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  status.remaining <= 0
                      ? 'leer'
                      : status.daysLeft == null
                          ? ''
                          : 'noch ~${status.daysLeft!.floor()} Tage',
                  style: AppTextStyles.caption.copyWith(
                    color: low ? AppColors.evidenceRed : AppColors.textTertiary,
                    fontWeight: low ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            if (low) ...[
              const SizedBox(height: AppConstants.spaceS),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onReorder,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Bald leer – nachbestellen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.evidenceRed,
                    side: const BorderSide(color: AppColors.evidenceRed),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool canAdd;
  final VoidCallback onAdd;
  const _Empty({required this.canAdd, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 44, color: AppColors.textTertiary),
            const SizedBox(height: AppConstants.spaceM),
            Text(
              'Noch keine Packungen im Lager',
              style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              'Trage deine gekauften Packungen (z.B. von Sunday Naturals) mit '
              'Inhalt ein — Einnahmen im Kalender ziehen davon ab, und bei "bald '
              'leer" kannst du direkt nachbestellen.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceL),
            if (canAdd)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Packung hinzufügen'),
              )
            else
              Text(
                'Füge zuerst ein Supplement mit erkennbarer Dosis zu deinem Stack hinzu.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
