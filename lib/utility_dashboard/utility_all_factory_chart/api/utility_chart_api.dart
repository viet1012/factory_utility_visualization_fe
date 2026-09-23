import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../utility_api/dio_client.dart';
import '../models/chart_catalog_response.dart';
import '../models/minute_point.dart';
import '../models/utility_daily_models.dart';

class UtilityChartApi {
  final Dio _dio;

  UtilityChartApi({Dio? dio}) : _dio = dio ?? DioClient.dio;

  String? _clean(String? value) {
    final normalized = value?.trim();
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  List<String> _cleanList(List<String>? values) {
    if (values == null) return [];
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _qp(Map<String, dynamic> raw) {
    final result = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      result[key] = value;
    });
    return result;
  }

  List<dynamic> _asList(dynamic data, String path) {
    if (data is! List) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        message: '$path: expected List but got ${data.runtimeType}',
        type: DioExceptionType.badResponse,
      );
    }
    return data.cast<dynamic>();
  }

  String _toIsoNoZ(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}T${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  Future<ChartCatalogResponse> getChartCatalog({
    required String facId,
    required String cate,
    int importantOnly = 0,
    String? scadaId,
    String? boxId,
    String? boxDeviceId,
  }) async {
    final query = <String, dynamic>{
      'facId': facId,
      'cate': cate,
      'importantOnly': importantOnly,
    };

    if (scadaId != null && scadaId.trim().isNotEmpty) {
      query['scadaId'] = scadaId.trim();
    }
    if (boxId != null && boxId.trim().isNotEmpty) {
      query['boxId'] = boxId.trim();
    }
    if (boxDeviceId != null && boxDeviceId.trim().isNotEmpty) {
      query['boxDeviceId'] = boxDeviceId.trim();
    }

    final response = await _dio.get(
      '/api/utility/chart-catalog',
      queryParameters: query,
    );

    return ChartCatalogResponse.fromJson(
      Map<String, dynamic>.from(response.data),
    );
  }

  Future<List<MinutePointDto>> getSeriesMinute({
    required DateTime from,
    required DateTime to,
    String? boxDeviceId,
    String? plcAddress,
    List<String>? cateIds,
  }) async {
    const path = '/api/utility/series/minute';
    final query = _qp({
      'from': _toIsoNoZ(from),
      'to': _toIsoNoZ(to),
      'boxDeviceId': _clean(boxDeviceId),
      'plcAddress': _clean(plcAddress),
      if (_cleanList(cateIds).isNotEmpty)
        'cateIds': _cleanList(cateIds).join(','),
    });

    try {
      final response = await _dio.get(path, queryParameters: query);
      return _asList(response.data, path)
          .map(
            (item) => MinutePointDto.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (error) {
      debugPrint('âŒ API ERROR: $path');
      debugPrint('PARAMS: $query');
      debugPrint('ERROR: $error');
      rethrow;
    }
  }

  Future<UtilityDailyDashboardResponse> getDailySignals({
    required String boxDeviceId,
    required String month,
  }) async {
    final normalizedBox = boxDeviceId.trim();
    if (normalizedBox.isEmpty) {
      throw ArgumentError('boxDeviceId must not be empty');
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/api/utility/daily-signals',
      queryParameters: {'boxDeviceId': normalizedBox, 'month': month},
      options: Options(
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Daily API returned empty response');
    }
    return UtilityDailyDashboardResponse.fromJson(data);
  }
}
