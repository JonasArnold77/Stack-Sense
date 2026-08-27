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

  const WearableHealthState({
    this.status = WearableConnectionStatus.idle,
    this.dataPoints = const [],
    this.errorMessage,
  });

  WearableHealthState copyWith({
    WearableConnectionStatus? status,
    List<HealthDataPoint>? dataPoints,
    String? errorMessage,
  }) {
    return WearableHealthState(
      status: status ?? this.status,
      dataPoints: dataPoints ?? this.dataPoints,
      errorMessage: errorMessage,
    );
  }
}

/// Verbindung zu Google Health Connect — liest Wearable-Daten (Garmin,
/// Samsung, Wear OS, … synchronisieren dorthin) für Testzwecke aus.
/// Kein echtes Apple-HealthKit-Backend, da das Projekt keine iOS-Plattform
/// hat (siehe Feature-Entscheidung: "Nur Health Connect").
class WearableHealthNotifier extends StateNotifier<WearableHealthState> {
  WearableHealthNotifier() : super(const WearableHealthState()) {
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
      await fetchLatest();
    } catch (e) {
      state = state.copyWith(
        status: WearableConnectionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> fetchLatest() async {
    state = state.copyWith(status: WearableConnectionStatus.connecting);
    try {
      final now = DateTime.now();
      final data = await _health.getHealthDataFromTypes(
        types: kWearableHealthTypes,
        startTime: now.subtract(const Duration(days: 7)),
        endTime: now,
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

  Future<void> openHealthConnectInstall() => _health.installHealthConnect();
}

final wearableHealthProvider =
    StateNotifierProvider<WearableHealthNotifier, WearableHealthState>(
  (ref) => WearableHealthNotifier(),
);
