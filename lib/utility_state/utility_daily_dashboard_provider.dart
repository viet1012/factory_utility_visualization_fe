import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_dashboard/utility_all_factory_chart/'
    'utility_daily_models.dart';

class UtilityDailySignalProvider extends ChangeNotifier {
  final UtilityApi api;

  UtilityDailySignalProvider({required this.api});

  static const Duration requestTimeout = Duration(seconds: 90);

  bool loading = false;
  bool refreshing = false;
  bool fetching = false;

  Object? error;

  List<UtilityDailySeries> _series = const <UtilityDailySeries>[];

  List<UtilityDailySeries> get series => _series;

  List<String> _currentBoxDeviceIds = const <String>[];

  String? _currentMonth;

  int dataVersion = 0;

  int _requestToken = 0;

  bool get hasData => _series.isNotEmpty;

  Future<void> load({
    required List<String> boxDeviceIds,
    required String month,
    bool forceRefresh = false,
  }) async {
    final normalizedDevices =
        boxDeviceIds
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    final normalizedMonth = month.trim();

    if (normalizedDevices.isEmpty) {
      clear();
      return;
    }

    final sameRequest =
        listEquals(normalizedDevices, _currentBoxDeviceIds) &&
        normalizedMonth == _currentMonth;

    if (!forceRefresh && sameRequest && hasData) {
      return;
    }

    final requestToken = ++_requestToken;

    final requestChanged = !sameRequest;

    fetching = true;
    error = null;

    if (requestChanged) {
      _currentBoxDeviceIds = List<String>.unmodifiable(normalizedDevices);

      _currentMonth = normalizedMonth;

      // Xóa dữ liệu Device cũ ngay.
      _series = const <UtilityDailySeries>[];

      loading = true;
      refreshing = false;

      dataVersion++;
    } else {
      loading = _series.isEmpty;
      refreshing = _series.isNotEmpty;
    }

    notifyListeners();

    try {
      final requests = normalizedDevices
          .map((boxDeviceId) {
            return api
                .getDailySignals(
                  boxDeviceId: boxDeviceId,
                  month: normalizedMonth,
                )
                .timeout(requestTimeout);
          })
          .toList(growable: false);

      final responses = await Future.wait(requests);

      // Request cũ hoàn thành sau request mới
      // thì không được ghi đè UI.
      if (requestToken != _requestToken) {
        return;
      }

      final combinedSeries = <UtilityDailySeries>[];

      for (final response in responses) {
        for (final item in response.series) {
          combinedSeries.add(item.copyWith(boxDeviceId: response.boxDeviceId));
        }
      }

      combinedSeries.sort(_compareSeries);

      _series = List<UtilityDailySeries>.unmodifiable(combinedSeries);

      error = null;
      dataVersion++;
    } catch (exception) {
      if (requestToken != _requestToken) {
        return;
      }

      error = exception;

      // Không khôi phục chart Device cũ.
      _series = const <UtilityDailySeries>[];

      dataVersion++;
    } finally {
      if (requestToken == _requestToken) {
        fetching = false;
        loading = false;
        refreshing = false;

        notifyListeners();
      }
    }
  }

  int _compareSeries(UtilityDailySeries first, UtilityDailySeries second) {
    final deviceCompare = first.boxDeviceId.toUpperCase().compareTo(
      second.boxDeviceId.toUpperCase(),
    );

    if (deviceCompare != 0) {
      return deviceCompare;
    }

    final nameCompare = first.nameEn.toUpperCase().compareTo(
      second.nameEn.toUpperCase(),
    );

    if (nameCompare != 0) {
      return nameCompare;
    }

    return first.plcAddress.toUpperCase().compareTo(
      second.plcAddress.toUpperCase(),
    );
  }

  Future<void> refresh() async {
    final month = _currentMonth;

    if (month == null || _currentBoxDeviceIds.isEmpty) {
      return;
    }

    await load(
      boxDeviceIds: _currentBoxDeviceIds,
      month: month,
      forceRefresh: true,
    );
  }

  void clear() {
    _requestToken++;

    final alreadyEmpty =
        _series.isEmpty &&
        _currentBoxDeviceIds.isEmpty &&
        error == null &&
        !loading &&
        !refreshing &&
        !fetching;

    if (alreadyEmpty) {
      return;
    }

    _currentBoxDeviceIds = const <String>[];

    _currentMonth = null;

    _series = const <UtilityDailySeries>[];

    error = null;

    loading = false;
    refreshing = false;
    fetching = false;

    dataVersion++;

    notifyListeners();
  }
}
