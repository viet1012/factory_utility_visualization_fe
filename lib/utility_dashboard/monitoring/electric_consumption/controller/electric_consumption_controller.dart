import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/state/safe_change_notifier.dart';
import '../api/electric_consumption_api.dart';
import '../model/electric_consumption.dart';

/// Che do xem man Bill period.
enum ConsumptionView {
  overview('Overview'),
  charts('Charts');

  const ConsumptionView(this.label);

  final String label;
}

/// MONITORING › Elec. consumption. Doi ky / so ky lich su thi tai lai ngay
/// (giu data cu, mo di); polling chi tai khi dang xem ky hien tai.
class ElectricConsumptionController extends ChangeNotifier
    with SafeChangeNotifier {
  final ElectricConsumptionApi _api;

  ElectricConsumptionController({required ElectricConsumptionApi api})
    : _api = api;

  static const List<int> historyOptions = [6, 12, 24];

  ElectricConsumptionResponse? _data;
  String? _error;
  bool _loading = false;
  int _months = 6;

  /// null: luon theo ky hien tai (qua ngay 21 tu sang ky moi).
  DateTime? _month;

  CancelToken? _cancelToken;
  int _requestSeq = 0;
  bool _disposed = false;

  ElectricConsumptionResponse? get data => _data;
  String? get error => _error;
  bool get loading => _loading;
  bool get hasData => _data != null;
  int get months => _months;

  /// Bang so lieu chi tiet duoi chart (nhu sheet Excel).
  bool _showDetail = true;
  bool get showDetail => _showDetail;

  void toggleDetail() {
    _showDetail = !_showDetail;
    safeNotify();
  }

  /// Toggle "Values" o legend chart: ghi so giua tung doan chong. Dung chung
  /// cho moi chart cua man hinh (chart phong to co trang thai rieng).
  bool _showValues = false;
  bool get showValues => _showValues;

  void setShowValues(bool value) {
    if (_showValues == value) return;
    _showValues = value;
    safeNotify();
  }

  /// Overview (KPI + chart + bang) hoac Charts (chi luoi chart).
  ConsumptionView _view = ConsumptionView.overview;
  ConsumptionView get view => _view;

  void setView(ConsumptionView view) {
    if (_view == view) return;
    _view = view;
    safeNotify();
  }

  static DateTime get currentBillMonth => billMonthOf(DateTime.now());

  /// Ky dang xem (ky hien tai khi chua chon).
  DateTime get month => _month ?? currentBillMonth;

  bool get isViewingCurrent =>
      _month == null || !month.isBefore(currentBillMonth);

  /// Ky chua bat dau thi backend tra 400.
  bool get canGoNext => month.isBefore(currentBillMonth);

  Future<void> setMonths(int months) {
    if (_months == months) return Future.value();
    _months = months;
    return load();
  }

  Future<void> shiftMonth(int delta) {
    final next = DateTime(month.year, month.month + delta);
    if (next.isAfter(currentBillMonth)) return Future.value();
    _month = next.isBefore(currentBillMonth) ? next : null;
    return load();
  }

  Future<void> goToCurrent() {
    if (_month == null) return Future.value();
    _month = null;
    return load();
  }

  /// Task polling (scope electricConsumption).
  Future<void> poll() {
    if (hasData && !isViewingCurrent) return Future.value();
    return load();
  }

  Future<void> retry() => load();

  Future<void> load() async {
    if (_disposed) return;

    _cancelToken?.cancel();
    final cancelToken = _cancelToken = CancelToken();
    final seq = ++_requestSeq;

    _loading = true;
    safeNotify();

    try {
      final result = await _api.fetch(
        month: _month == null ? null : formatBillMonth(_month!),
        months: _months,
        cancelToken: cancelToken,
      );
      if (_disposed || seq != _requestSeq) return;

      _data = result;
      _error = null;
    } catch (e) {
      if (_disposed || seq != _requestSeq || cancelToken.isCancelled) return;
      _error = e.toString();
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _loading = false;
        safeNotify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel();
    super.dispose();
  }
}
