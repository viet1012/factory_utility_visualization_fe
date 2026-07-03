import 'package:dio/dio.dart';

import '../../../utility_models/response/minute_point.dart';
import '../utility_dashboard_overview_hourly/utility_dashboard_overview_hourly_widgets/CoolingTankTemperaturePanel.dart';
import '../utility_dashboard_overview_monthly/monthly_utility_usage_panel.dart';
import '../utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_card.dart';

class UtilityDashboardOverviewApi {
  final Dio dio;

  UtilityDashboardOverviewApi(this.dio);

  /// ENERGY MINUTES
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

  Future<List<HourlyTempCompareDto>> getCoolingTankHourly({
    required String facId,
    required int hours,
    String type = 'WATER',
  }) async {
    final res = await dio.get(
      '/api/utility/hourly-sensor-compare',
      queryParameters: {'facId': facId, 'hours': hours, 'type': type},
    );

    final data = res.data as List;

    return data
        .map((e) => HourlyTempCompareDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
  Future<List<Map<String, dynamic>>> getEnergyDaily({
    required String facId,
    required String month,
    String? nameEn,
    required String type,
  }) async {
    final res = await dio.get(
      '/api/utility/energy-daily',
      queryParameters: {
        'facId': facId,
        'month': month,
        'nameEn': nameEn,
        'type': type,
      },
    );

    final List data = res.data;

    return data.map((e) => Map<String, dynamic>.from(e)).toList();
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

    double? toDouble(dynamic v) => (v as num?)?.toDouble();

    return data.map<Map<String, dynamic>>((e) {
      return {
        'name': _normalizeName(e['name'] ?? ''),
        'cate': e['cate'] ?? '',
        'month': e['month'] ?? month,
        'unit': e['unit'] ?? '',

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
}
