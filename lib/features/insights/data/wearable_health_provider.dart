import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

/// Health-Connect-Datentypen, für die in AndroidManifest.xml eine passende
/// `android.permission.health.READ_*`-Berechtigung deklariert ist. Nur Typen
/// mit deklarierter Berechtigung dürfen angefragt werden — Health Connect
/// lehnt sonst die gesamte Anfrage ab.
const kWearableHealthTypes = [
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_REM,
  HealthDataType.SLEEP_AWAKE,
  HealthDataType.WORKOUT,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.TOTAL_CALORIES_BURNED,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.RESPIRATORY_RATE,
  HealthDataType.BODY_TEMPERATURE,
  HealthDataType.WEIGHT,
];

enum WearableConnectionStatus {
  idle,
  connecting,
  healthConnectMissing,
  denied,
  connected,
  error,
}

class WearableHealthState {
  final WearableConnectionStatus status;
  final List<HealthDataPoint> dataPoints;
  final String? errorMessage;
  final DateTime selectedDay;

  WearableHealthState({
    this.status = WearableConnectionStatus.idle,
    this.dataPoints = const [],
    this.errorMessage,
    DateTime? selectedDay,
  }) : selectedDay = selectedDay ?? _startOfDay(DateTime.now());

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get isToday => selectedDay == _startOfDay(DateTime.now());

  WearableHealthState copyWith({
    WearableConnectionStatus? status,
    List<HealthDataPoint>? dataPoints,
    String? errorMessage,
    DateTime? selectedDay,
  }) {
    return WearableHealthState(
      status: status ?? this.status,
      dataPoints: dataPoints ?? this.dataPoints,
      errorMessage: errorMessage,
      selectedDay: selectedDay ?? this.selectedDay,
    );
  }
}

/// Verbindung zu Google Health Connect — liest Wearable-Daten (Garmin,
/// Samsung, Wear OS, … synchronisieren dorthin) tageweise aus, mit Blättern
/// beliebig weit in die Vergangenheit. Kein echtes Apple-HealthKit-Backend,
/// da das Projekt keine iOS-Plattform hat (siehe Feature-Entscheidung: "Nur
/// Health Connect").
///
/// Health Connect erlaubt standardmäßig nur Lesezugriff auf die letzten 30
/// Tage — für ältere Daten ist die separate "Health Data History"-
/// Berechtigung nötig, die [connectAndFetch] direkt mit anfragt (best-effort,
/// je nach Health-Connect-Version auf dem Gerät verfügbar).
class WearableHealthNotifier extends StateNotifier<WearableHealthState> {
  WearableHealthNotifier() : super(WearableHealthState()) {
    _health.configure();
  }

  final Health _health = Health();

  Future<void> connectAndFetch() async {
    state = state.copyWith(status: WearableConnectionStatus.connecting);

    final sdkStatus = await _health.getHealthConnectSdkStatus();
    if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
      state = state.copyWith(status: WearableConnectionStatus.healthConnectMissing);
      return;
    }

    try {
      final authorized = await _health.requestAuthorization(
        kWearableHealthTypes,
        permissions:
            kWearableHealthTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      if (authorized != true) {
        state = state.copyWith(status: WearableConnectionStatus.denied);
        return;
      }

      // Best-effort: ohne diese Zusatzberechtigung liefert Health Connect nur
      // die letzten 30 Tage zurück, egal wie weit man zurück blättert.
      try {
        if (await _health.isHealthDataHistoryAvailable() &&
            !await _health.isHealthDataHistoryAuthorized()) {
          await _health.requestHealthDataHistoryAuthorization();
        }
      } catch (_) {
        // Ältere Health-Connect-Version ohne History-Feature — ignorieren,
        // Abfragen bleiben dann auf die letzten 30 Tage begrenzt.
      }

      await fetchForDay(DateTime.now());
    } catch (e) {
      state = state.copyWith(
        status: WearableConnectionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> fetchForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    state = state.copyWith(
      status: WearableConnectionStatus.connecting,
      selectedDay: start,
    );
    try {
      final data = await _health.getHealthDataFromTypes(
        types: kWearableHealthTypes,
        startTime: start,
        endTime: end,
      );
      final deduped = _health.removeDuplicates(data)
        ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      state = state.copyWith(
        status: WearableConnectionStatus.connected,
        dataPoints: deduped,
      );
    } catch (e) {
      state = state.copyWith(
        status: WearableConnectionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Ein Tag zurück — keine untere Grenze, so weit wie Health Connect Daten
  /// zurückliefert (siehe History-Berechtigung oben).
  Future<void> goToPreviousDay() =>
      fetchForDay(state.selectedDay.subtract(const Duration(days: 1)));

  /// Ein Tag vor — nicht über heute hinaus.
  Future<void> goToNextDay() {
    if (state.isToday) return Future.value();
    return fetchForDay(state.selectedDay.add(const Duration(days: 1)));
  }

  Future<void> refresh() => fetchForDay(state.selectedDay);

  Future<void> openHealthConnectInstall() => _health.installHealthConnect();
}

final wearableHealthProvider =
    StateNotifierProvider<WearableHealthNotifier, WearableHealthState>(
  (ref) => WearableHealthNotifier(),
);
