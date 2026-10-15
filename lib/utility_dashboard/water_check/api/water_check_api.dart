import 'package:dio/dio.dart';

import '../../../utility_api/dio_client.dart';
import '../models/water_check_models.dart';

class WaterCheckApi {
  final Dio _dio;

  WaterCheckApi({Dio? dio}) : _dio = dio ?? DioClient.dio;

  Future<WaterCheckResponse> fetch({CancelToken? cancelToken}) async {
    final response = await _dio.get<dynamic>(
      '/api/utility/water-check',
      cancelToken: cancelToken,
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('water-check: unexpected response body.');
    }

    return WaterCheckResponse.fromJson(Map<String, dynamic>.from(data));
  }
}
