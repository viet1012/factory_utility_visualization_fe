import 'package:dio/dio.dart';

import '../model/power_usage.dart';

class PowerUsageException implements Exception {
  final String message;

  const PowerUsageException(this.message);

  @override
  String toString() => message;
}

class PowerUsageApi {
  final Dio _dio;

  PowerUsageApi({required Dio dio}) : _dio = dio;

  Future<PowerUsageResponse> fetch({
    required DateTime date,
    required PowerPeriod period,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/utility/power-usage',
        queryParameters: {'date': formatQueryDate(date), 'period': period.query},
        cancelToken: cancelToken,
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      final data = response.data;
      if (data is! Map) {
        throw const PowerUsageException('Unexpected power usage response');
      }
      return PowerUsageResponse.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw PowerUsageException(_messageOf(e));
    }
  }

  /// yyyy-MM-dd
  static String formatQueryDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  /// 400 tra `message` (body Map hoac chuoi).
  static String _messageOf(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();

    final status = e.response?.statusCode;
    if (status != null) return 'Power usage request failed (HTTP $status)';
    return e.message ?? 'Cannot reach the server';
  }
}
