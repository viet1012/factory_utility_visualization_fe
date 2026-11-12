import 'package:dio/dio.dart';

import '../model/electric_consumption.dart';

class ElectricConsumptionException implements Exception {
  final String message;

  const ElectricConsumptionException(this.message);

  @override
  String toString() => message;
}

class ElectricConsumptionApi {
  final Dio _dio;

  ElectricConsumptionApi({required Dio dio}) : _dio = dio;

  /// [month] null: ky hien tai. [months]: so ky truoc trong `monthly` (0–36).
  Future<ElectricConsumptionResponse> fetch({
    String? month,
    int months = 12,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/utility/electric-consumption',
        queryParameters: {if (month != null) 'month': month, 'months': months},
        cancelToken: cancelToken,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );

      final data = response.data;
      if (data is! Map) {
        throw const ElectricConsumptionException(
          'Unexpected electric consumption response',
        );
      }
      return ElectricConsumptionResponse.fromJson(
        Map<String, dynamic>.from(data),
      );
    } on DioException catch (e) {
      throw ElectricConsumptionException(_messageOf(e));
    }
  }

  /// 400 tra `message` (body Map hoac chuoi).
  static String _messageOf(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();

    final status = e.response?.statusCode;
    if (status != null) {
      return 'Electric consumption request failed (HTTP $status)';
    }
    return e.message ?? 'Cannot reach the server';
  }
}
