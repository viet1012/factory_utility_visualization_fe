import 'package:dio/dio.dart';

import '../models/solar_dashboard_data.dart';
import '../models/solar_detail_data.dart';
import '../models/solar_hourly_by_facility.dart';

class SolarApi {
  SolarApi(this._dio);

  final Dio _dio;

  Future<SolarDashboardData> getMonthly({
    required String facId,
    required String month,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/solar/monthly',
      queryParameters: {'facId': facId, 'month': month},
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid solar dashboard response');
    }

    return SolarDashboardData.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<SolarDetailData> getDetail({
    required String facId,
    required String month,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/solar/detail',
      queryParameters: {'facId': facId, 'month': month},
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid Solar API response');
    }

    return SolarDetailData.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// [date]: yyyy-MM-dd.
  Future<SolarHourlyByFacility> getHourly({
    required String facId,
    required String date,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/solar/hourly',
      queryParameters: {'facId': facId, 'date': date},
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid Solar hourly response');
    }

    return SolarHourlyByFacility.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
