import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  DioClient._();

  static late Dio dio;

  static void init({required String baseUrl, Map<String, dynamic>? headers}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,

        // Tang timeout
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 90),

        // Ch? dùng cho request có body (POST/PUT),
        // không c?n thi?t cho GET trên Flutter Web.
        // sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,

        headers: {
          'Content-Type': 'application/json',
          if (headers != null) ...headers,
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint(
            '[REQ] ${options.method} ${options.baseUrl}${options.path}',
          );
          debugPrint('Query: ${options.queryParameters}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '[RES] ${response.statusCode} ${response.requestOptions.path}',
          );
          handler.next(response);
        },
        onError: (e, handler) {
          debugPrint(
            '[ERR] ${e.requestOptions.method} ${e.requestOptions.path}',
          );
          debugPrint('Type: ${e.type}');
          debugPrint('Message: ${e.message}');
          debugPrint('Response: ${e.response?.data}');
          handler.next(e);
        },
      ),
    );
  }
}
