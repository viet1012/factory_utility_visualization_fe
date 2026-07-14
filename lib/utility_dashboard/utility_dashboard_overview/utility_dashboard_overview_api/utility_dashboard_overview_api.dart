import 'package:dio/dio.dart';

import '../../../utility_models/response/minute_point.dart';
import '../utility_dashboard_overview_models/utility_daily_dashboard_response.dart';
import '../utility_dashboard_overview_models/utility_hourly_dashboard_response.dart';
import '../utility_dashboard_overview_models/utility_minute_dashboard_response.dart';
import '../utility_dashboard_overview_monthly/monthly_utility_usage_panel.dart';
import '../utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_card.dart';
import '../utility_dashboard_overview_monthly/utility_overview_monthly_box.dart';

class UtilityDashboardOverviewApi {
  final Dio dio;

  UtilityDashboardOverviewApi(this.dio);

  static const Duration _monthlyGetTimeout = Duration(seconds: 15);

  static const Duration _monthlyRefreshTimeout = Duration(seconds: 60);

  /// ENERGY MINUTES
  Future<UtilityMinuteDashboardResponse> getMinuteDashboard({
    required String facId,
    int minutes = 60,
  }) async {
    final normalizedFac = facId.trim();

    if (normalizedFac.isEmpty) {
      throw ArgumentError.value(facId, 'facId', 'facId is required');
    }

    final safeMinutes = minutes <= 0 ? 60 : minutes.clamp(1, 24 * 60);

    final response = await dio.get(
      '/api/utility/minute-dashboard',
      queryParameters: {'facId': normalizedFac, 'minutes': safeMinutes},
    );

    final raw = response.data;

    if (raw is! Map) {
      throw const FormatException('Invalid minute dashboard response');
    }

    return UtilityMinuteDashboardResponse.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<List<MinutePointDto>> getEnergyMinute({
    required String facId,
    required int minutes,
    String? utilityType,
    String? nameEn,
  }) async {
    final res = await dio.get(
      '/api/utility/energy-minute',
      queryParameters: {
        'facId': facId,
        'minutes': minutes,
        'type': utilityType,
      },
    );
    final List data = res.data;

    return data.map((e) => MinutePointDto.fromJson(e)).toList();
  }

  ///  HOURLY
  Future<UtilityHourlyDashboardResponse> getHourlyDashboard({
    required String facId,
    int hours = 48,
    String? nameEn,
    double? exchange,
    double? sepzone,
  }) async {
    final normalizedFac = facId.trim();

    if (normalizedFac.isEmpty) {
      throw ArgumentError('facId is required');
    }

    final query = <String, dynamic>{'facId': normalizedFac, 'hours': hours};

    final normalizedName = nameEn?.trim();

    if (normalizedName != null && normalizedName.isNotEmpty) {
      query['nameEn'] = normalizedName;
    }

    if (exchange != null) {
      query['exchange'] = exchange;
    }

    if (sepzone != null) {
      query['sepzone'] = sepzone;
    }

    final response = await dio.get(
      '/api/utility/hourly-dashboard',
      queryParameters: query,
    );

    final raw = response.data;

    if (raw is! Map) {
      throw const FormatException('Invalid hourly dashboard response');
    }

    return UtilityHourlyDashboardResponse.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<List<Map<String, dynamic>>> getEnergyHourly({
    required String facId,
    required int hours,
    String? nameEn,
  }) async {
    final res = await dio.get(
      '/api/utility/energy/hourly',
      queryParameters: {'facId': facId, 'hours': hours, 'nameEn': nameEn},
    );
    print("url: ${res.realUri}");
    final List data = res.data;

    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// ENERGY DAILY
  Future<UtilityDailyDashboardResponse> getDailyDashboard({
    required String facId,
    required String month,
  }) async {
    final normalizedFac = facId.trim();
    final normalizedMonth = month.trim();

    if (normalizedFac.isEmpty) {
      throw ArgumentError('facId is required');
    }

    if (!RegExp(r'^\d{6}$').hasMatch(normalizedMonth)) {
      throw ArgumentError('month must be yyyyMM, for example 202607');
    }

    final response = await dio.get(
      '/api/utility/energy-daily',
      queryParameters: {'facId': normalizedFac, 'month': normalizedMonth},
    );

    final raw = response.data;

    if (raw is! Map) {
      throw const FormatException('Invalid daily dashboard response');
    }

    return UtilityDailyDashboardResponse.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<List<Map<String, dynamic>>> getEnergyMonthlySummary({
    required String facId,
    required String month,
  }) async {
    final res = await dio.get(
      '/api/utility/monthly-summary',
      queryParameters: {'facId': facId, 'month': month},
    );

    print('res: ${res.realUri}');

    final List data = res.data as List;

    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return data.map<Map<String, dynamic>>((e) {
      return {
        'name': _normalizeName(e['name'] ?? ''),
        'cate': e['cate'] ?? '',
        'month': e['month'] ?? month,
        'unit': e['unit'] ?? '',

        'minValue': toDouble(e['minValue']),
        'maxValue': toDouble(e['maxValue']),
        'prevMinValue': toDouble(e['prevMinValue']),
        'prevMaxValue': toDouble(e['prevMaxValue']),

        'value': toDouble(e['value']),
        'avgValue': toDouble(e['avgValue']),

        'vndCost': toDouble(e['vndCost']),
        'usdCost': toDouble(e['usdCost']),

        'prevValue': toDouble(e['prevValue']),
        'prevAvgValue': toDouble(e['prevAvgValue']),
        'prevVndCost': toDouble(e['prevVndCost']),
        'prevUsdCost': toDouble(e['prevUsdCost']),

        'deltaValue': toDouble(e['deltaValue']),
        'deltaPercent': toDouble(e['deltaPercent']),

        'pickAt': e['pickAt'],
        'timestamp': e['pickAt'] ?? e['timestamp'],
      };
    }).toList();
  }

  /// ===============================================================
  /// MONTHLY SUMMARY - NEW API
  /// ===============================================================

  Future<List<EnergyMonthlySummary>> getMonthlySummary({
    required String facId,
    required String month,
  }) async {
    final normalizedFac = _normalizeMonthlyFac(facId);

    final normalizedMonth = _normalizeMonthlyMonth(month);

    final response = await dio
        .get(
          '/api/utility/monthly-summary',
          queryParameters: {'facId': normalizedFac, 'month': normalizedMonth},
        )
        .timeout(_monthlyGetTimeout);

    return _parseMonthlySummaryResponse(
      response.data,
      fallbackMonth: normalizedMonth,
    );
  }

  /// Ép backend xóa cache FAC + month,
  /// sau đó query DB lại và cache kết quả mới.
  Future<List<EnergyMonthlySummary>> forceRefreshMonthlySummary({
    required String facId,
    required String month,
  }) async {
    final normalizedFac = _normalizeMonthlyFac(facId);

    final normalizedMonth = _normalizeMonthlyMonth(month);

    final response = await dio
        .post(
          '/api/utility/monthly-summary/refresh',
          queryParameters: {'facId': normalizedFac, 'month': normalizedMonth},
        )
        .timeout(_monthlyRefreshTimeout);

    return _parseMonthlySummaryResponse(
      response.data,
      fallbackMonth: normalizedMonth,
    );
  }

  /// VOLTAGE STATUS (min/max + alarm)
  Future<List<VoltageStatus>> getVoltageStatus({required String facId}) async {
    final res = await dio.get(
      '/api/utility/voltage/status',
      queryParameters: {'facId': facId},
    );

    final data = res.data;
    if (data is! List) return const [];

    return List<VoltageStatus>.from(data.map((e) => VoltageStatus.fromJson(e)));
  }

  /// VOLTAGE DETAIL (chart)
  Future<List<dynamic>> getVoltageDetail({required String facId}) async {
    final res = await dio.get(
      '/api/utility/voltage/detail',
      queryParameters: {'facId': facId},
    );

    final data = res.data;
    if (data is! List) return [];
    return data;
  }

  Future<List<MonthlyUtilityUsage>> getMonthlyUtilityUsage({
    required String facId,
    required int year,
    required int month,
    String nameEn = 'Total Energy Consumption',
  }) async {
    final res = await dio.get(
      '/api/utility/monthly-usage',
      queryParameters: {
        'fac': facId,
        'year': year,
        'month': month,
        'nameEn': nameEn,
      },
    );

    final data = res.data;

    if (data is! List) return const [];

    return data
        .map((e) => MonthlyUtilityUsage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// SIGNAL HEALTH MATRIX
  Future<List<Map<String, dynamic>>> getSignalHealthMatrix() async {
    final res = await dio.get('/api/utility/signal-health-matrix');

    final data = res.data;

    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

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

      json['cate'] = json['cate']?.toString() ?? '';

      json['month'] = json['month']?.toString() ?? fallbackMonth;

      json['unit'] = json['unit']?.toString() ?? '';

      /*
     * Backend mới trả generatedAt.
     * Model cũ có thể đang dùng timestamp.
     */
      json['timestamp'] =
          json['generatedAt'] ?? json['pickAt'] ?? json['timestamp'];

      result.add(EnergyMonthlySummary.fromJson(json));
    }

    return List<EnergyMonthlySummary>.unmodifiable(result);
  }

  /// ENERGY MONTHLY SUMMARY
  String _normalizeName(String name) {
    switch (name) {
      case 'Total Energy Consumption':
        return 'Total Energy';
      case 'Total Water Consumption':
        return 'TOTAL WATER';
      default:
        return name.toUpperCase();
    }
  }

  String _normalizeMonthlyFac(String facId) {
    final normalized = facId.trim();

    return normalized.isEmpty ? 'KVH' : normalized;
  }

  String _normalizeMonthlyMonth(String month) {
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
}
