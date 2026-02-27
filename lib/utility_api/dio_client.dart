import 'package:dio/dio.dart';

class DioClient {
  DioClient._();

  static late Dio dio;

  static void init({required String baseUrl, Map<String, dynamic>? headers}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          if (headers != null) ...headers,
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          // debugPrint('➡️ [REQ] ${o.method} ${o.baseUrl}${o.path}');
          // debugPrint('   query: ${o.queryParameters}');
          return h.next(o);
        },
        onResponse: (r, h) {
          // debugPrint('✅ [RES] ${r.statusCode} ${r.realUri}');
          return h.next(r);
        },
        onError: (e, h) {
          // debugPrint('❌ [ERR] ${e.requestOptions.path} ${e.message}');
          // debugPrint('   response: ${e.response?.data}');
          return h.next(e);
        },
      ),
    );
  }
}
