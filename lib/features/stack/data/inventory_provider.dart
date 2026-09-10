import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/dose_parser.dart';
import '../domain/models/inventory_package.dart';
import 'stack_provider.dart';
import 'taken_provider.dart';

/// Ab wie vielen verbleibenden Tagesdosen eine Packung als "bald leer" gilt.
const int kInventoryLowStockDays = 7;

// ---------------------------------------------------------------------------
// Store — persistierte Packungsliste ("Lager")
// ---------------------------------------------------------------------------

class InventoryNotifier extends StateNotifier<List<InventoryPackage>> {
  InventoryNotifier() : super([]) {
    _load();
  }

  static const _prefsKey = AppConstants.keyStackInventory;

  List<InventoryPackage> packagesFor(String stackEntryId) =>
      state.where((p) => p.stackEntryId == stackEntryId).toList();

  Future<void> addPackage(InventoryPackage package) async {
    state = [...state, package];
    await _save();
  }

  Future<void> updatePackage(InventoryPackage package) async {
    state = [
      for (final p in state) if (p.id == package.id) package else p,
    ];
    await _save();
  }

  Future<void> removePackage(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        state = list
            .map((e) => InventoryPackage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      state = [];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.map((p) => p.toJson()).toList()));
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, List<InventoryPackage>>(
  (ref) => InventoryNotifier(),
);

// ---------------------------------------------------------------------------
// Abgeleiteter Verbrauchs-/Reststatus — NICHT gespeichert, rechnet bei jeder
// Änderung von Lager / Stack / Einnahmen neu. Dadurch driftet nichts, wenn
// im Kalender nachträglich korrigiert wird.
// ---------------------------------------------------------------------------

class PackageStatus {
  final double remaining; // in Packungs-/Dosis-Einheit
  final double? daysLeft; // null = Tagesdosis unbekannt
  final bool isLowStock;

  const PackageStatus({
    required this.remaining,
    required this.daysLeft,
    required this.isLowStock,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Parst das Datum aus einem dayKey ("<id>_yyyy-MM-dd") — die letzten 10
/// Zeichen sind das Datum, davor (minus dem "_") die Id. Robust auch wenn die
/// Id selbst "_" enthält.
({String id, DateTime date})? _splitDayKey(String key) {
  if (key.length < 12) return null;
  final datePart = key.substring(key.length - 10);
  final id = key.substring(0, key.length - 11);
  final date = DateTime.tryParse(datePart);
  if (date == null) return null;
  return (id: id, date: date);
}

final inventoryStatusProvider = Provider<Map<String, PackageStatus>>((ref) {
  final packages = ref.watch(inventoryProvider);
  final stack = ref.watch(stackProvider);
  final taken = ref.watch(takenProvider);

  if (packages.isEmpty) return const {};

  final entriesById = {for (final e in stack) e.id: e};

  // Packungen nach Stack-Eintrag gruppieren.
  final byEntry = <String, List<InventoryPackage>>{};
  for (final p in packages) {
    byEntry.putIfAbsent(p.stackEntryId, () => []).add(p);
  }

  final result = <String, PackageStatus>{};

  byEntry.forEach((entryId, list) {
    list.sort((a, b) => a.openedAt.compareTo(b.openedAt));
    final earliestOpened = _dateOnly(list.first.openedAt);

    // Verbrauch = Summe aller Einnahme-Mengen für diesen Eintrag ab dem
    // frühesten openedAt (Mengen stehen bereits in der Dosis-Einheit).
    var consumed = 0.0;
    taken.forEach((key, amount) {
      final parts = _splitDayKey(key);
      if (parts == null || parts.id != entryId) return;
      if (parts.date.isBefore(earliestOpened)) return;
      consumed += amount;
    });

    final entry = entriesById[entryId];
    final dose = entry == null ? null : trackableDoseFor(entry);
    final dailyDose = (dose != null && dose.amount > 0) ? dose.amount : null;

    // FIFO über die Packungen dieses Eintrags auffüllen.
    var consumedBefore = 0.0;
    for (final p in list) {
      final usedFromThis =
          (consumed - consumedBefore).clamp(0.0, p.totalUnits).toDouble();
      final remaining =
          (p.totalUnits - usedFromThis).clamp(0.0, p.totalUnits).toDouble();
      consumedBefore += p.totalUnits;

      final daysLeft = dailyDose == null ? null : remaining / dailyDose;
      final isLow = remaining <= 0 ||
          (daysLeft != null && daysLeft <= kInventoryLowStockDays);

      result[p.id] = PackageStatus(
        remaining: remaining,
        daysLeft: daysLeft,
        isLowStock: isLow,
      );
    }
  });

  return result;
});

/// Bequemer Zugriff: Status einer einzelnen Packung (oder Default 0-Verbrauch).
PackageStatus statusForPackage(Map<String, PackageStatus> map, InventoryPackage p) =>
    map[p.id] ??
    PackageStatus(remaining: p.totalUnits, daysLeft: null, isLowStock: false);
