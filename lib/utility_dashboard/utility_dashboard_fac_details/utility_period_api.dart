import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'models/period/utility_period_dashboard.dart';

class UtilityPeriodApi {
  UtilityPeriodApi(this._dio);

  final Dio _dio;

  Future<UtilityPeriodDashboard> getDashboard({
    required String facId,
    required String type,
    required String period,
    required DateTime date,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/utility/period-dashboard',

      queryParameters: {
        'facId': facId,
        'type': type,
        'period': period,
        'date': DateFormat('yyyyMMdd').format(date),
      },
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid period dashboard response');
    }

    return UtilityPeriodDashboard.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
