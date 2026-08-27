import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_screen_header.dart';
import '../../data/wearable_health_provider.dart';

/// Rohdaten-Ansicht aus Health Connect, tageweise mit Vor/Zurück-Navigation
/// — zum Testen der Wearable-Anbindung, nicht die endgültige
/// Insights-Darstellung. Rückwärts ist beliebig weit blätterbar (siehe
/// History-Berechtigung in WearableHealthNotifier.connectAndFetch).
class WearableDataScreen extends ConsumerWidget {
  const WearableDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wearableHealthProvider);
    final notifier = ref.read(wearableHealthProvider.notifier);
    final isLoading = state.status == WearableConnectionStatus.connecting;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientScreenHeader(
            title: 'Wearable-Daten',
            subtitle: 'Rohdaten aus Health Connect',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Aktualisieren',
                onPressed: isLoading ? null : notifier.refresh,
              ),
            ],
          ),
          _DayNavigator(state: state, notifier: notifier, isLoading: isLoading),
          Expanded(child: _Body(state: state, notifier: notifier)),
        ],
      ),
    );
  }
}

class _DayNavigator extends StatelessWidget {
  final WearableHealthState state;
  final WearableHealthNotifier notifier;
  final bool isLoading;

  const _DayNavigator({required this.state, required this.notifier, required this.isLoading});

  String _label(DateTime day) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (isSameDay(day, today)) return 'Heute';
    if (isSameDay(day, yesterday)) return 'Gestern';
    return DateFormat('dd.MM.yyyy').format(day);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceS, vertical: AppConstants.spaceS),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Vorheriger Tag',
            onPressed: isLoading ? null : notifier.goToPreviousDay,
          ),
          Text(_label(state.selectedDay),
              style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Nächster Tag',
            onPressed: (isLoading || state.isToday) ? null : notifier.goToNextDay,
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final WearableHealthState state;
  final WearableHealthNotifier notifier;

  const _Body({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case WearableConnectionStatus.connecting:
        return const Center(child: CircularProgressIndicator());

      case WearableConnectionStatus.healthConnectMissing:
        return _StatusMessage(
          icon: Icons.download_outlined,
          title: 'Health Connect fehlt',
          message:
              'Google Health Connect ist auf diesem Gerät nicht installiert oder muss aktualisiert werden.',
          actionLabel: 'Health Connect installieren',
          onAction: notifier.openHealthConnectInstall,
        );

      case WearableConnectionStatus.denied:
        return const _StatusMessage(
          icon: Icons.block_outlined,
          title: 'Zugriff verweigert',
          message:
              'Ohne Berechtigung können keine Gesundheitsdaten gelesen werden. Bitte in Health Connect erneut freigeben.',
        );

      case WearableConnectionStatus.error:
        return _StatusMessage(
          icon: Icons.error_outline,
          title: 'Fehler beim Laden',
          message: state.errorMessage ?? 'Unbekannter Fehler',
          actionLabel: 'Erneut versuchen',
          onAction: notifier.refresh,
        );

      case WearableConnectionStatus.idle:
        return const _StatusMessage(
          icon: Icons.watch_outlined,
          title: 'Nicht verbunden',
          message: 'Noch keine Wearable-Verbindung hergestellt.',
        );

      case WearableConnectionStatus.connected:
        if (state.dataPoints.isEmpty) {
          return const _StatusMessage(
            icon: Icons.inbox_outlined,
            title: 'Keine Daten',
            message:
                'Health Connect enthält für diesen Tag keine Werte in den unterstützten Kategorien. Mit den Pfeilen oben weiter zurückblättern.',
          );
        }
        return _DataList(dataPoints: state.dataPoints);
    }
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppConstants.spaceM),
            Text(title, style: AppTextStyles.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spaceS),
            Text(message,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: AppConstants.spaceL),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DataList extends StatelessWidget {
  final List<HealthDataPoint> dataPoints;

  const _DataList({required this.dataPoints});

  @override
  Widget build(BuildContext context) {
    final byType = <String, List<HealthDataPoint>>{};
    for (final p in dataPoints) {
      byType.putIfAbsent(p.typeString, () => []).add(p);
    }
    final types = byType.keys.toList()..sort();
    final dateFormat = DateFormat('dd.MM. HH:mm');

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      children: [
        Text(
          '${dataPoints.length} Datenpunkte in ${types.length} Kategorien',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppConstants.spaceM),
        for (final type in types) ...[
          Text(type, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ...byType[type]!.take(20).map((p) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceM, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p.value} ${p.unitString}',
                              style: AppTextStyles.labelMedium),
                          Text(
                            '${dateFormat.format(p.dateFrom)} · ${p.sourceName}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: AppConstants.spaceM),
        ],
      ],
    );
  }
}
