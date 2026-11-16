import 'package:dio/dio.dart';

import '../../../utility_api/dio_client.dart';
import '../../shared/network/request_retry.dart';
import '../models/energy_monthly_summary.dart';
import '../models/utility_daily_dashboard_response.dart';
import '../models/utility_hourly_dashboard_response.dart';
import '../models/utility_minute_dashboard_response.dart';

class UtilityDashboardOverviewApi {
  UtilityDashboardOverviewApi();

  Dio get _dio => DioClient.dio;

  // ============================================================
  // ENDPOINTS
  // ============================================================

  static const String _minuteDashboardPath = '/api/utility/minute-dashboard';

  static const String _hourlyDashboardPath = '/api/utility/hourly-dashboard';

  static const String _energyDailyPath = '/api/utility/energy-daily';

  static const String _monthlySummaryPath = '/api/utility/monthly-summary';

  static const String _monthlySummaryRefreshPath =
      '/api/utility/monthly-summary/refresh';


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

  // ============================================================
  // HOURLY
  //
  // Backend luôn trả 24 giờ: hôm nay vs hôm qua (không có tham số hours).
  // ============================================================

  Future<UtilityHourlyDashboardResponse> getHourlyDashboard({
    required String facId,
  }) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    final response = await _get(
      _hourlyDashboardPath,
      queryParameters: {'facId': normalizedFac},
    );

    return UtilityHourlyDashboardResponse.fromJson(
      _asMap(response.data, errorMessage: 'Invalid hourly dashboard response'),
    );
  }

  // ============================================================
  // DAILY
  // ============================================================

  /// Timeout / retry do [RequestRetry] cua noi goi dam nhan ([cancelToken]).
  Future<UtilityDailyDashboardResponse> getDailyDashboard({
    required String facId,
    required String month,
    CancelToken? cancelToken,
  }) async {
    final normalizedFac = _requiredText(facId, fieldName: 'facId');

    final normalizedMonth = _normalizeMonth(month);

    final response = await _get(
      _energyDailyPath,
      queryParameters: {'facId': normalizedFac, 'month': normalizedMonth},
      options: _energyDailyOptions,
      cancelToken: cancelToken,
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
    CancelToken? cancelToken,
  }) {
    return _requestMonthlySummary(
      facId: facId,
      month: month,
      forceRefresh: false,
      cancelToken: cancelToken,
    );
  }

  Future<List<EnergyMonthlySummary>> forceRefreshMonthlySummary({
    required String facId,
    required String month,
    CancelToken? cancelToken,
  }) {
    return _requestMonthlySummary(
      facId: facId,
      month: month,
      forceRefresh: true,
      cancelToken: cancelToken,
    );
  }

  Future<List<EnergyMonthlySummary>> _requestMonthlySummary({
    required String facId,
    required String month,
    required bool forceRefresh,
    CancelToken? cancelToken,
  }) async {
    final normalizedFac = _normalizeMonthlyFac(facId);
    final normalizedMonth = _normalizeMonth(month);

    final query = <String, dynamic>{
      'facId': normalizedFac,
      'month': normalizedMonth,
    };

    // POST refresh: BE tinh lai, de timeout cua noi goi (120s) quyet dinh.
    final response = forceRefresh
        ? await _post(
            _monthlySummaryRefreshPath,
            queryParameters: query,
            cancelToken: cancelToken,
          )
        : await _get(
            _monthlySummaryPath,
            queryParameters: query,
            options: _monthlySummaryOptions,
            cancelToken: cancelToken,
          );

    return _parseMonthlySummaryResponse(
      response.data,
      fallbackMonth: normalizedMonth,
    );
  }

  // ============================================================
  // HTTP
  // ============================================================

  /// receiveTimeout theo [RequestPolicy] cua tung endpoint. Tren web Dio
  /// khong dam bao dung moc nay, nen [RequestRetry] con huy bang CancelToken.
  static final Options _monthlySummaryOptions = Options(
    receiveTimeout: RequestPolicy.monthlySummary.timeout,
  );

  static final Options _energyDailyOptions = Options(
    receiveTimeout: RequestPolicy.energyDaily.timeout,
  );

  Future<Response<dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> _post(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<dynamic>(
      path,
      queryParameters: queryParameters,
      data: data,
      options: options,
      cancelToken: cancelToken,
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

  // ============================================================
  // GENERIC PARSE
  // ============================================================

  Map<String, dynamic> _asMap(dynamic raw, {required String errorMessage}) {
    if (raw is! Map) {
      throw FormatException(errorMessage);
    }

    return Map<String, dynamic>.from(raw);
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
