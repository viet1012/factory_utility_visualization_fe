import 'package:dio/dio.dart';

import '../../../utility_models/response/minute_point.dart';
import '../utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_card.dart';
import '../utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_detail_chart.dart';

class UtilityDashboardOverviewApi {
  final Dio dio;

  UtilityDashboardOverviewApi(this.dio);

  /// ENERGY MINUTES
  Future<List<MinutePointDto>> getEnergyMinute({
    required String facId,
    required int minutes,
    String? nameEn,
  }) async {
    final res = await dio.get(
      '/api/utility/energy-minute',
      queryParameters: {'facId': facId, 'minutes': minutes, 'nameEn': nameEn},
    );
    // print('res: ${res.realUri}');
    final List data = res.data;

    return data.map((e) => MinutePointDto.fromJson(e)).toList();
  }

  /// ENERGY HOURLY
  Future<List<Map<String, dynamic>>> getEnergyHourly({
    required String facId,
    required int hours,
    String? nameEn,
  }) async {
    final res = await dio.get(
      '/api/utility/energy-hourly',
      queryParameters: {'facId': facId, 'hours': hours, 'nameEn': nameEn},
    );

    final List data = res.data;

    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// ENERGY DAILY
  Future<List<Map<String, dynamic>>> getEnergyDaily({
    required String facId,
    required String month,
    String? nameEn,
  }) async {
    final res = await dio.get(
      '/api/utility/energy-daily',
      queryParameters: {'facId': facId, 'month': month, 'nameEn': nameEn},
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
      '/api/utility/energy-monthly-summary',
      queryParameters: {
        'facId': facId,
        'month': month,
        'names': ['Total Energy Consumption'],
      },
    );
    print('res: ${res.realUri}');

    final List data = res.data as List;

    return data.map<Map<String, dynamic>>((e) {
      return {
        'name': _normalizeName(e['name'] ?? ''),
        'value': (e['value'] as num?)?.toDouble() ?? 0,
        'cate': e['cate'] ?? '',
        'unit': e['unit'] ?? '',
        'timestamp': e['timestamp'],
      };
    }).toList();
  }

  /// VOLTAGE STATUS (min/max + alarm)
  Future<VoltageStatus> getVoltageStatus({required String facId}) async {
    final res = await dio.get(
      '/api/utility/voltage/status',
      queryParameters: {'facId': facId},
    );
    return VoltageStatus.fromJson(res.data);
  }

  /// VOLTAGE DETAIL (chart)
  Future<List<VoltageDetail>> getVoltageDetail({required String facId}) async {
    final uri = Uri.parse(
      '${dio.options.baseUrl}/api/utility/voltage/detail',
    ).replace(queryParameters: {'facId': facId});

    print("URL: $uri");
    final res = await dio.get(
      '/api/utility/voltage/detail',
      queryParameters: {'facId': facId},
    );

    final List data = res.data;
    return (res.data as List).map((e) => VoltageDetail.fromJson(e)).toList();
  }
}
