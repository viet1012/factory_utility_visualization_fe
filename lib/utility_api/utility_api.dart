import 'package:dio/dio.dart';

import '../utility_models/response/latest_record.dart';

class UtilityApi {
  final Dio _dio;

  UtilityApi({
    required String baseUrl, // ví dụ: http://192.168.1.10:8002
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               headers: {'Content-Type': 'application/json'},
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('➡️ [REQ] ${options.method} ${options.baseUrl}${options.path}');
          print('   query: ${options.queryParameters}');
          print('   headers: ${options.headers}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print(
            '✅ [RES] ${response.statusCode} ${response.requestOptions.path}',
          );
          print('   data: ${response.data}');
          return handler.next(response);
        },
        onError: (e, handler) {
          print('❌ [ERR] ${e.requestOptions.path}');
          print('   message: ${e.message}');
          print('   response: ${e.response?.data}');
          return handler.next(e);
        },
      ),
    );
  }

  /// GET /api/utility/latest
  /// cateIds truyền dạng CSV (Current,Voltage) đúng theo controller bạn đang dùng
  Future<List<LatestRecordDto>> getLatest({
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) async {
    final params = <String, dynamic>{};

    void putIfNotBlank(String key, String? val) {
      if (val != null && val.trim().isNotEmpty) params[key] = val.trim();
    }

    putIfNotBlank('facId', facId);
    putIfNotBlank('scadaId', scadaId);
    putIfNotBlank('cate', cate);
    putIfNotBlank('boxDeviceId', boxDeviceId);

    if (cateIds != null) {
      final cleaned = cateIds
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (cleaned.isNotEmpty) {
        params['cateIds'] = cleaned.join(','); // ✅ match cateIdsCsv
      }
    }

    final res = await _dio.get('/api/utility/latest', queryParameters: params);

    final data = res.data;
    if (data is! List) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'Expected List but got: ${data.runtimeType}',
        type: DioExceptionType.badResponse,
      );
    }

    return data
        .map(
          (e) => LatestRecordDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}
