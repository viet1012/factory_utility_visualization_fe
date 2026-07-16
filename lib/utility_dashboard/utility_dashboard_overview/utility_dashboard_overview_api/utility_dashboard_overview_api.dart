import 'package:dio/dio.dart';

import '../../../utility_api/dio_client.dart';
import '../../../utility_models/response/minute_point.dart';
import '../utility_dashboard_overview_models/utility_daily_dashboard_response.dart';
import '../utility_dashboard_overview_models/utility_hourly_dashboard_response.dart';
import '../utility_dashboard_overview_models/utility_minute_dashboard_response.dart';
import '../utility_dashboard_overview_monthly/monthly_utility_usage_panel.dart';
import '../utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_card.dart';
import '../utility_dashboard_overview_monthly/utility_overview_monthly_box.dart';

class UtilityDashboardOverviewApi {
  UtilityDashboardOverviewApi();

  Dio get _dio => DioClient.dio;

  // ============================================================
  // ENDPOINTS
  // ============================================================

  static const String _minuteDashboardPath = '/api/utility/minute-dashboard';

  static const String _energyMinutePath = '/api/utility/energy-minute';

  static const String _hourlyDashboardPath = '/api/utility/hourly-dashboard';

  static const String _energyHourlyPath = '/api/utility/energy/hourly';

  static const String _energyDailyPath = '/api/utility/energy-daily';

  static const String _monthlySummaryPath = '/api/utility/monthly-summary';

  static const String _monthlySummaryRefreshPath =
      '/api/utility/monthly-summary/refresh';

  static const String _monthlyUsagePath = '/api/utility/monthly-usage';

  static const String _voltageStatusPath = '/api/utility/voltage/status';

  static const String _voltageDetailPath = '/api/utility/voltage/detail';

  static const String _signalHealthMatrixPath =
      '/api/utility/signal-health-matrix';

  // ============================================================
  // MINUTE
  // ============================================================

  Future<UtilityMinuteDashboardResponse> getMinuteDashboard({
    required String facId,
    int minutes = 60,
  }) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    final safeMinutes = _safeRange(minutes, fallback: 60, min: 1, max: 24 * 60);

    final response = await _get(
      _minuteDashboardPath,
      queryParameters: {'facId': normalizedFac, 'minutes': safeMinutes},
    );

    return UtilityMinuteDashboardResponse.fromJson(
      _asMap(response.data, errorMessage: 'Invalid minute dashboard response'),
    );
  }

  Future<List<MinutePointDto>> getEnergyMinute({
    required String facId,
    required int minutes,
    String? utilityType,
    String? nameEn,
  }) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    final safeMinutes = _safeRange(minutes, fallback: 60, min: 1, max: 24 * 60);

    final query = <String, dynamic>{
      'facId': normalizedFac,
      'minutes': safeMinutes,
    };

    _putOptionalText(query, key: 'type', value: utilityType);

    _putOptionalText(query, key: 'nameEn', value: nameEn);

    final response = await _get(_energyMinutePath, queryParameters: query);

    return _parseList(
      response.data,
      MinutePointDto.fromJson,
      errorMessage: 'Invalid energy minute response',
    );
  }

  // ============================================================
  // HOURLY
  // ============================================================

  Future<UtilityHourlyDashboardResponse> getHourlyDashboard({
    required String facId,
    int hours = 48,
    String? nameEn,
    double? exchange,
    double? sepzone,
  }) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    final safeHours = _safeRange(hours, fallback: 48, min: 1, max: 24 * 31);

    final query = <String, dynamic>{'facId': normalizedFac, 'hours': safeHours};

    _putOptionalText(query, key: 'nameEn', value: nameEn);

    if (exchange != null) {
      query['exchange'] = exchange;
    }

    if (sepzone != null) {
      query['sepzone'] = sepzone;
    }

    final response = await _get(_hourlyDashboardPath, queryParameters: query);

    return UtilityHourlyDashboardResponse.fromJson(
      _asMap(response.data, errorMessage: 'Invalid hourly dashboard response'),
    );
  }

  Future<List<Map<String, dynamic>>> getEnergyHourly({
    required String facId,
    required int hours,
    String? nameEn,
  }) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    final safeHours = _safeRange(hours, fallback: 48, min: 1, max: 24 * 31);

    final query = <String, dynamic>{'facId': normalizedFac, 'hours': safeHours};

    _putOptionalText(query, key: 'nameEn', value: nameEn);

    final response = await _get(_energyHourlyPath, queryParameters: query);

    return _parseMapList(
      response.data,
      errorMessage: 'Invalid energy hourly response',
    );
  }

  // ============================================================
  // DAILY
  // ============================================================

  Future<UtilityDailyDashboardResponse> getDailyDashboard({
    required String facId,
    required String month,
  }) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    final normalizedMonth = _normalizeMonth(month);

    final response = await _get(
      _energyDailyPath,
      queryParameters: {'facId': normalizedFac, 'month': normalizedMonth},
    );

    return UtilityDailyDashboardResponse.fromJson(
      _asMap(response.data, errorMessage: 'Invalid daily dashboard response'),
    );
  }

  // ============================================================
  // MONTHLY SUMMARY
  // ============================================================

  Future<List<EnergyMonthlySummary>> getMonthlySummary({
    required String facId,
    required String month,
  }) {
    return _requestMonthlySummary(
      facId: facId,
      month: month,
      forceRefresh: false,
    );
  }

  Future<List<EnergyMonthlySummary>> forceRefreshMonthlySummary({
    required String facId,
    required String month,
  }) {
    return _requestMonthlySummary(
      facId: facId,
      month: month,
      forceRefresh: true,
    );
  }

  Future<List<EnergyMonthlySummary>> _requestMonthlySummary({
    required String facId,
    required String month,
    required bool forceRefresh,
  }) async {
    final normalizedFac = _normalizeMonthlyFac(facId);
    final normalizedMonth = _normalizeMonth(month);

    final query = <String, dynamic>{
      'facId': normalizedFac,
      'month': normalizedMonth,
    };

    final response = forceRefresh
        ? await _post(_monthlySummaryRefreshPath, queryParameters: query)
        : await _get(_monthlySummaryPath, queryParameters: query);

    return _parseMonthlySummaryResponse(
      response.data,
      fallbackMonth: normalizedMonth,
    );
  }

  /// Method tương thích với code cũ.
  ///
  /// Code mới nên dùng [getMonthlySummary].
  Future<List<Map<String, dynamic>>> getEnergyMonthlySummary({
    required String facId,
    required String month,
  }) async {
    final items = await getMonthlySummary(facId: facId, month: month);

    return items.map(_monthlySummaryToMap).toList(growable: false);
  }

  // ============================================================
  // MONTHLY USAGE
  // ============================================================

  Future<List<MonthlyUtilityUsage>> getMonthlyUtilityUsage({
    required String facId,
    required int year,
    required int month,
    String nameEn = 'Total Energy Consumption',
  }) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    if (year < 2000 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'Invalid year');
    }

    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Month must be from 1 to 12');
    }

    final response = await _get(
      _monthlyUsagePath,
      queryParameters: {
        'fac': normalizedFac,
        'year': year,
        'month': month,
        'nameEn': nameEn.trim(),
      },
    );

    return _parseList(
      response.data,
      MonthlyUtilityUsage.fromJson,
      errorMessage: 'Invalid monthly usage response',
    );
  }

  // ============================================================
  // VOLTAGE
  // ============================================================

  Future<List<VoltageStatus>> getVoltageStatus({required String facId}) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    final response = await _get(
      _voltageStatusPath,
      queryParameters: {'facId': normalizedFac},
    );

    return _parseList(
      response.data,
      VoltageStatus.fromJson,
      errorMessage: 'Invalid voltage status response',
    );
  }

  Future<List<dynamic>> getVoltageDetail({required String facId}) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    final response = await _get(
      _voltageDetailPath,
      queryParameters: {'facId': normalizedFac},
    );

    final raw = response.data;

    if (raw is! List) {
      throw const FormatException('Invalid voltage detail response');
    }

    return List<dynamic>.unmodifiable(raw);
  }

  // ============================================================
  // SIGNAL HEALTH
  // ============================================================

  Future<List<Map<String, dynamic>>> getSignalHealthMatrix() async {
    final response = await _get(_signalHealthMatrixPath);

    return _parseMapList(
      response.data,
      errorMessage: 'Invalid signal health matrix response',
    );
  }

  // ============================================================
  // HTTP
  // ============================================================

  Future<Response<dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> _post(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    Options? options,
  }) {
    return _dio.post<dynamic>(
      path,
      queryParameters: queryParameters,
      data: data,
      options: options,
    );
  }

  // ============================================================
  // MONTHLY PARSE
  // ============================================================

  List<EnergyMonthlySummary> _parseMonthlySummaryResponse(
    dynamic raw, {
    required String fallbackMonth,
  }) {
    if (raw is! List) {
      throw const FormatException('Invalid monthly summary response');
    }

    final result = <EnergyMonthlySummary>[];

    for (final item in raw) {
      if (item is! Map) {
        continue;
      }

      final json = Map<String, dynamic>.from(item);

      json['name'] = _normalizeName(json['name']?.toString() ?? '');

      json['cate'] = json['cate']?.toString().trim() ?? '';

      final rawMonth = json['month']?.toString().trim() ?? '';

      json['month'] = rawMonth.isEmpty ? fallbackMonth : rawMonth;

      json['unit'] = json['unit']?.toString().trim() ?? '';

      json['timestamp'] =
          json['generatedAt'] ?? json['pickAt'] ?? json['timestamp'];

      result.add(EnergyMonthlySummary.fromJson(json));
    }

    return List<EnergyMonthlySummary>.unmodifiable(result);
  }

  Map<String, dynamic> _monthlySummaryToMap(EnergyMonthlySummary item) {
    final pickAt = item.pickAt?.toIso8601String();
    final generatedAt = item.generatedAt?.toIso8601String();

    return {
      'name': item.name,
      'cate': item.cate,
      'month': item.month,
      'unit': item.unit,

      'minValue': item.minValue,
      'maxValue': item.maxValue,
      'prevMinValue': item.prevMinValue,
      'prevMaxValue': item.prevMaxValue,

      'value': item.value,
      'avgValue': item.avgValue,

      'vndCost': item.vndCost,
      'usdCost': item.usdCost,

      'prevValue': item.prevValue,
      'prevAvgValue': item.prevAvgValue,
      'prevVndCost': item.prevVndCost,
      'prevUsdCost': item.prevUsdCost,

      'deltaValue': item.deltaValue,
      'deltaPercent': item.deltaPercent,

      'pickAt': pickAt,
      'generatedAt': generatedAt,
      'timestamp': generatedAt ?? pickAt,
    };
  }

  // ============================================================
  // GENERIC PARSE
  // ============================================================

  Map<String, dynamic> _asMap(dynamic raw, {required String errorMessage}) {
    if (raw is! Map) {
      throw FormatException(errorMessage);
    }

    return Map<String, dynamic>.from(raw);
  }

  List<Map<String, dynamic>> _parseMapList(
    dynamic raw, {
    required String errorMessage,
  }) {
    if (raw is! List) {
      throw FormatException(errorMessage);
    }

    final result = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }

    return List<Map<String, dynamic>>.unmodifiable(result);
  }

  List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parser, {
    required String errorMessage,
  }) {
    if (raw is! List) {
      throw FormatException(errorMessage);
    }

    final result = <T>[];

    for (final item in raw) {
      if (item is! Map) {
        continue;
      }

      result.add(parser(Map<String, dynamic>.from(item)));
    }

    return List<T>.unmodifiable(result);
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String _requiredText(String value, {required String fieldName}) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName is required');
    }

    return normalized;
  }

  void _putOptionalText(
    Map<String, dynamic> query, {
    required String key,
    required String? value,
  }) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return;
    }

    query[key] = normalized;
  }

  int _safeRange(
    int value, {
    required int fallback,
    required int min,
    required int max,
  }) {
    if (value <= 0) {
      return fallback;
    }

    return value.clamp(min, max);
  }

  String _normalizeMonthlyFac(String facId) {
    final normalized = facId.trim();

    return normalized.isEmpty ? 'KVH' : normalized;
  }

  String _normalizeMonth(String month) {
    final normalized = month.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        month,
        'month',
        'Month must use yyyyMM format, for example 202607',
      );
    }

    final monthNumber = int.tryParse(normalized.substring(4, 6));

    if (monthNumber == null || monthNumber < 1 || monthNumber > 12) {
      throw ArgumentError.value(month, 'month', 'Invalid month value');
    }

    return normalized;
  }

  String _normalizeName(String name) {
    final normalized = name.trim();

    switch (normalized) {
      case 'Total Energy Consumption':
        return 'Total Energy';

      case 'Total Water Consumption':
        return 'Total Water';

      default:
        return normalized;
    }
  }
}
