import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../shared/state/safe_change_notifier.dart';
import '../api/utility_dashboard_overview_api.dart';
import '../models/energy_monthly_summary.dart';
import 'monthly_summary_store.dart';

/// Panel SUMMARY (MONTHLY): doc du lieu cua key (facId, month) hien tai tu
/// [MonthlySummaryStore] (dung chung voi 3 o Fac_A/B/C tren MAP).
/// Polling do task MAP cua store dam nhan, provider khong tu polling.
class UtilityMonthlySummaryProvider extends ChangeNotifier
    with SafeChangeNotifier {
  final UtilityDashboardOverviewApi api;
  final MonthlySummaryStore store;

  UtilityMonthlySummaryProvider(this.api, this.store) {
    store.addListener(_onStoreChanged);
  }

  // ============================================================
  // CONFIG
  // ============================================================

  static const Duration forceRefreshTimeout = Duration(seconds: 120);

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  bool _disposed = false;

  bool _forceRefreshing = false;

  /// Loi cua POST refresh (loi GET nam trong store).
  Object? _forceRefreshError;

  String? _facId;
  String? _month;

  // ============================================================
  // GETTERS
  // ============================================================

  /// Chua co du lieu va chua co loi cho key hien tai.
  bool get loading {
    if (!hasValidParams) return false;
    return !_hasLoaded && error == null;
  }

  /// Dang tai lai khi da co du lieu (giu UI cu).
  bool get refreshing {
    if (!hasValidParams) return false;
    return hasData && (store.isLoading(_facId!, _month!) || _forceRefreshing);
  }

  bool get forceRefreshing => _forceRefreshing;

  bool get fetching {
    if (!hasValidParams) return false;
    return store.isLoading(_facId!, _month!) || _forceRefreshing;
  }

  Object? get error {
    if (_forceRefreshError != null) return _forceRefreshError;
    if (!hasValidParams) {
      return _facId == null
          ? null
          : 'Missing facId or invalid month format yyyyMM';
    }
    return store.errorOf(_facId!, _month!);
  }

  String? get facId => _facId;

  String? get month => _month;

  List<EnergyMonthlySummary> get rows {
    if (!hasValidParams) return const <EnergyMonthlySummary>[];
    return store.rowsOf(_facId!, _month!);
  }

  bool get hasData => rows.isNotEmpty;

  bool get _hasLoaded => store.hasLoaded(_facId!, _month!);

  bool get hasValidParams {
    final currentFac = _facId;
    final currentMonth = _month;

    return currentFac != null &&
        currentFac.trim().isNotEmpty &&
        currentMonth != null &&
        _isValidMonth(currentMonth);
  }

  EnergyMonthlySummary? get electricity {
    return _findByCate('ELECTRIC');
  }

  EnergyMonthlySummary? get water {
    return _findByCate('WATER');
  }

  EnergyMonthlySummary? get air {
    return _findByCate('AIR') ?? _findByCate('COMPRESSED');
  }

  // ============================================================
  // CONFIGURE
  // ============================================================

  /// Doi key hien tai va tai qua store (cache con han thi khong goi API).
  void configure({required String facId, required String month}) {
    if (_disposed) return;

    final normalizedFac = _normalizeFac(facId);
    final normalizedMonth = _normalizeMonth(month);

    final changed = normalizedFac != _facId || normalizedMonth != _month;

    if (changed) {
      if (hasValidParams) store.unwatch(_facId!, _month!);

      _facId = normalizedFac;
      _month = normalizedMonth;
      _forceRefreshError = null;

      store.watch(normalizedFac, normalizedMonth);

      safeNotify();
    }

    unawaited(load());
  }

  // ============================================================
  // NORMAL GET
  // ============================================================

  Future<void> load({bool silent = false, bool force = false}) async {
    if (_disposed || !hasValidParams) return;

    await store.get(_facId!, _month!, force: force);
  }

  // ============================================================
  // NORMAL REFRESH
  // ============================================================

  Future<void> refresh() async {
    if (_disposed || _forceRefreshing) return;

    await load();
  }

  // ============================================================
  // FORCE REFRESH BACKEND CACHE
  // ============================================================

  /// POST /monthly-summary/refresh, sau do xoa key trong store va tai lai:
  /// panel va o Fac cung key cap nhat cung luc.
  Future<bool> forceRefresh() async {
    if (_disposed || _forceRefreshing || !hasValidParams) {
      return false;
    }

    final requestFac = _facId!;
    final requestMonth = _month!;

    _forceRefreshing = true;
    _forceRefreshError = null;
    safeNotify();

    var success = false;

    try {
      await api
          .forceRefreshMonthlySummary(facId: requestFac, month: requestMonth)
          .timeout(forceRefreshTimeout);

      if (_disposed) return false;

      store.invalidate(requestFac, requestMonth);
      await store.get(requestFac, requestMonth, force: true);

      success = store.errorOf(requestFac, requestMonth) == null;
    } on TimeoutException catch (error, stackTrace) {
      _handleForceRefreshError(
        error: error,
        stackTrace: stackTrace,
        tag: '[MONTHLY FORCE REFRESH TIMEOUT]',
      );
    } on DioException catch (error, stackTrace) {
      _handleForceRefreshError(
        error: error,
        stackTrace: stackTrace,
        tag: '[MONTHLY FORCE REFRESH DIO ${error.type}]',
      );
    } catch (error, stackTrace) {
      _handleForceRefreshError(
        error: error,
        stackTrace: stackTrace,
        tag: '[MONTHLY FORCE REFRESH ERROR]',
      );
    } finally {
      if (!_disposed) {
        _forceRefreshing = false;
        safeNotify();
      }
    }

    return success;
  }

  // ============================================================
  // RETRY
  // ============================================================

  Future<void> retry() async {
    if (_disposed || _forceRefreshing) return;

    _forceRefreshError = null;
    await load(force: true);
  }

  // ============================================================
  // CLEAR
  // ============================================================

  void clear() {
    if (_disposed) return;

    if (hasValidParams) store.unwatch(_facId!, _month!);

    _facId = null;
    _month = null;
    _forceRefreshError = null;
    _forceRefreshing = false;

    safeNotify();
  }

  // ============================================================
  // CATEGORY HELPERS
  // ============================================================

  EnergyMonthlySummary? _findByCate(String keyword) {
    final normalizedKeyword = keyword.trim().toUpperCase();

    for (final item in rows) {
      final category = item.cate.trim().toUpperCase();

      if (category.contains(normalizedKeyword)) {
        return item;
      }
    }

    return null;
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _handleForceRefreshError({
    required Object error,
    required StackTrace stackTrace,
    required String tag,
  }) {
    if (_disposed) return;

    // Khong xoa rows cu neu refresh loi.
    _forceRefreshError = error;

    debugPrint('$tag $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String _normalizeFac(String facId) {
    return MonthlySummaryStore.keyOf(facId, '').facId;
  }

  String _normalizeMonth(String month) {
    final normalized = month.trim();

    if (!_isValidMonth(normalized)) {
      throw ArgumentError.value(
        month,
        'month',
        'Month must use yyyyMM format, for example 202607',
      );
    }

    return normalized;
  }

  bool _isValidMonth(String value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return false;
    }

    final monthNumber = int.tryParse(value.substring(4, 6));

    return monthNumber != null && monthNumber >= 1 && monthNumber <= 12;
  }

  // ============================================================
  // STORE
  // ============================================================

  void _onStoreChanged() {
    if (_disposed) return;
    safeNotify();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;

    store.removeListener(_onStoreChanged);
    if (hasValidParams) store.unwatch(_facId!, _month!);

    super.dispose();
  }
}
