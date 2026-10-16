import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../shared/state/safe_change_notifier.dart';
import '../api/utility_dashboard_overview_api.dart';
import '../models/energy_monthly_summary.dart';

typedef MonthlySummaryKey = ({String facId, String month});

/// Cache dung chung cho GET /api/utility/monthly-summary giua panel SUMMARY
/// (UtilityMonthlySummaryProvider) va 3 o Fac_A/B/C tren MAP.
///
/// - Cache theo (facId, month), TTL [ttl].
/// - Request dang chay cho cung key duoc dung chung (dedupe).
/// - Loading / error theo tung key; loi khong xoa rows cu.
/// - [watch] / [unwatch]: cac key dang hien thi, polling MAP chi lam moi
///   nhung key nay qua [refreshWatched].
class MonthlySummaryStore extends ChangeNotifier with SafeChangeNotifier {
  MonthlySummaryStore(this.api);

  final UtilityDashboardOverviewApi api;

  static const Duration ttl = Duration(minutes: 10);

  static const Duration requestTimeout = Duration(seconds: 45);

  final Map<MonthlySummaryKey, _Entry> _entries = {};
  final Map<MonthlySummaryKey, int> _watchers = {};

  bool _disposed = false;

  // ============================================================
  // KEY
  // ============================================================

  static MonthlySummaryKey keyOf(String facId, String month) {
    final fac = facId.trim();
    return (facId: fac.isEmpty ? 'KVH' : fac, month: month.trim());
  }

  // ============================================================
  // READ
  // ============================================================

  /// Rows moi nhat cua key (list moi sau moi lan tai, Selector so identical).
  List<EnergyMonthlySummary> rowsOf(String facId, String month) {
    return _entries[keyOf(facId, month)]?.rows ??
        const <EnergyMonthlySummary>[];
  }

  /// Da co it nhat mot lan tai thanh cong.
  bool hasLoaded(String facId, String month) {
    return _entries[keyOf(facId, month)]?.fetchedAt != null;
  }

  bool isLoading(String facId, String month) {
    return _entries[keyOf(facId, month)]?.inFlight != null;
  }

  Object? errorOf(String facId, String month) {
    return _entries[keyOf(facId, month)]?.error;
  }

  // ============================================================
  // GET
  // ============================================================

  /// Tra ve cache neu con han (tru khi [force]); neu key dang tai thi dung
  /// chung request do. Khong nem loi: loi duoc ghi vao [errorOf].
  Future<void> get(String facId, String month, {bool force = false}) {
    if (_disposed) return Future<void>.value();

    final key = keyOf(facId, month);
    final entry = _entries.putIfAbsent(key, _Entry.new);

    final inFlight = entry.inFlight;
    if (inFlight != null) return inFlight;

    if (!force && entry.isFresh) return Future<void>.value();

    final future = _fetch(key, entry, entry.generation);
    entry.inFlight = future;
    safeNotify();

    return future;
  }

  Future<void> _fetch(
    MonthlySummaryKey key,
    _Entry entry,
    int generation,
  ) async {
    try {
      final data = await api
          .getMonthlySummary(facId: key.facId, month: key.month)
          .timeout(requestTimeout);

      if (!_isCurrent(key, entry, generation)) return;

      entry
        ..rows = List<EnergyMonthlySummary>.unmodifiable(data)
        ..fetchedAt = DateTime.now()
        ..error = null;
    } catch (error, stackTrace) {
      if (!_isCurrent(key, entry, generation)) return;

      entry.error = error;

      debugPrint('[MONTHLY STORE ${key.facId} ${key.month}] $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (_isCurrent(key, entry, generation)) {
        entry.inFlight = null;
        safeNotify();
      }
    }
  }

  bool _isCurrent(MonthlySummaryKey key, _Entry entry, int generation) {
    return !_disposed &&
        identical(_entries[key], entry) &&
        entry.generation == generation;
  }

  // ============================================================
  // INVALIDATE
  // ============================================================

  /// Xoa cache cua key (vd sau POST /monthly-summary/refresh). Request GET
  /// dang chay bi bo qua ket qua. Rows cu van giu de UI khong nhay ve
  /// loading, cho den khi lan tai tiep theo ghi de.
  void invalidate(String facId, String month) {
    final entry = _entries[keyOf(facId, month)];
    if (entry == null) return;

    entry
      ..generation += 1
      ..inFlight = null
      ..fetchedAt = null
      ..error = null;

    safeNotify();
  }

  // ============================================================
  // WATCH (POLLING)
  // ============================================================

  void watch(String facId, String month) {
    final key = keyOf(facId, month);
    _watchers[key] = (_watchers[key] ?? 0) + 1;
  }

  void unwatch(String facId, String month) {
    final key = keyOf(facId, month);
    final count = (_watchers[key] ?? 0) - 1;

    if (count > 0) {
      _watchers[key] = count;
    } else {
      _watchers.remove(key);
    }
  }

  /// Action cua polling MAP: lam moi cac key dang hien thi (bo qua key con
  /// han TTL). Nem loi dau tien de PollingCoordinator khong tinh la thanh cong.
  Future<void> refreshWatched() async {
    final keys = _watchers.keys.toList(growable: false);

    await Future.wait(keys.map((key) => get(key.facId, key.month)));

    for (final key in keys) {
      final error = _entries[key]?.error;
      if (error != null) throw error;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;
    _entries.clear();
    _watchers.clear();
    super.dispose();
  }
}

class _Entry {
  List<EnergyMonthlySummary> rows = const <EnergyMonthlySummary>[];

  DateTime? fetchedAt;

  Object? error;

  Future<void>? inFlight;

  /// Tang khi invalidate: ket qua cua request cu bi bo qua.
  int generation = 0;

  bool get isFresh {
    final at = fetchedAt;
    return at != null &&
        DateTime.now().difference(at) < MonthlySummaryStore.ttl;
  }
}
