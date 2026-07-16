import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  DioClient._();

  static Dio? _instance;

  static Dio get dio {
    final client = _instance;

    if (client == null) {
      throw StateError(
        'DioClient chưa được khởi tạo. '
        'Hãy gọi DioClient.init() trước khi sử dụng.',
      );
    }

    return client;
  }

  static bool get isInitialized => _instance != null;

  static void init({
    required String baseUrl,
    Map<String, dynamic>? headers,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 90),
    Duration sendTimeout = const Duration(seconds: 30),
    bool enableLogging = kDebugMode,
  }) {
    final normalizedBaseUrl = baseUrl.trim();

    if (normalizedBaseUrl.isEmpty) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'baseUrl không được để trống',
      );
    }

    final client = Dio(
      BaseOptions(
        baseUrl: normalizedBaseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: <String, dynamic>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?headers,
        },
      ),
    );

    if (enableLogging) {
      client.interceptors.add(_createLoggingInterceptor());
    }

    _instance = client;
  }

  static InterceptorsWrapper _createLoggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('[DIO REQUEST] ${options.method} ${options.uri}');

        if (options.queryParameters.isNotEmpty) {
          debugPrint('[DIO QUERY] ${options.queryParameters}');
        }

        if (options.data != null) {
          debugPrint('[DIO BODY] ${options.data}');
        }

        handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint(
          '[DIO RESPONSE] '
          '${response.statusCode} '
          '${response.requestOptions.uri}',
        );

        handler.next(response);
      },
      onError: (error, handler) {
        debugPrint(
          '[DIO ERROR] '
          '${error.requestOptions.method} '
          '${error.requestOptions.uri}',
        );

        debugPrint('[DIO ERROR TYPE] ${error.type}');
        debugPrint('[DIO ERROR MESSAGE] ${error.message}');

        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;

        if (statusCode != null) {
          debugPrint('[DIO STATUS] $statusCode');
        }

        if (responseData != null) {
          debugPrint('[DIO RESPONSE DATA] $responseData');
        }

        handler.next(error);
      },
    );
  }

  static void setHeader(String key, dynamic value) {
    dio.options.headers[key] = value;
  }

  static void removeHeader(String key) {
    dio.options.headers.remove(key);
  }

  static void setBearerToken(String? token) {
    final normalized = token?.trim();

    if (normalized == null || normalized.isEmpty) {
      removeHeader('Authorization');
      return;
    }

    setHeader('Authorization', 'Bearer $normalized');
  }

  static void clear() {
    _instance?.close(force: true);
    _instance = null;
  }
}
