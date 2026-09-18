import 'package:dio/dio.dart';

import '../../../../utility_api/dio_client.dart';

class SignalHealthApi {
  SignalHealthApi();

  static const String _signalHealthMatrixPath =
      '/api/utility/signal-health-matrix';

  Dio get _dio => DioClient.dio;

  Future<List<Map<String, dynamic>>> getSignalHealthMatrix() async {
    final response = await _dio.get<dynamic>(_signalHealthMatrixPath);

    return _parseMapList(
      response.data,
      errorMessage: 'Invalid signal health matrix response',
    );
  }

  List<Map<String, dynamic>> _parseMapList(
    dynamic raw, {
    required String errorMessage,
  }) {
    if (raw is! List) {
      throw FormatException(errorMessage);
    }

    final result = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }

    return List<Map<String, dynamic>>.unmodifiable(result);
  }
}
