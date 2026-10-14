import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../utility_api/dio_client.dart';
import '../models/chart_catalog_response.dart';
import '../models/series_history_response.dart';

class UtilityChartApi {
  final Dio _dio;

  UtilityChartApi({Dio? dio}) : _dio = dio ?? DioClient.dio;

  List<String> _cleanList(List<String>? values) {
    if (values == null) return [];
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
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

  Future<ChartCatalogResponse> getChartCatalog({
    required String facId,
    required String cate,
    int importantOnly = 0,
  }) async {
    final query = <String, dynamic>{
      'facId': facId,
      'cate': cate,
      'importantOnly': importantOnly,
    };

    final response = await _dio.get(
      '/api/utility/chart-catalog',
      queryParameters: query,
    );

    return ChartCatalogResponse.fromJson(
      Map<String, dynamic>.from(response.data),
    );
  }

  /// ISO-8601 kem offset cua may, vd: 2026-10-12T08:00:00+07:00.
  /// Dio tu encode query component, nen '+' duoc gui dung la %2B.
  String _toIsoWithOffset(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');

    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();

    return '${local.year}-${two(local.month)}-${two(local.day)}'
        'T${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
        '$sign${two(abs.inHours)}:${two(abs.inMinutes % 60)}';
  }

  /// Lich su theo bucket cua mot hoac nhieu box device.
  ///
  /// Moi box gui chung tham so `boxDeviceId` (CSV khi nhieu box).
  /// [plcAddresses] ap cho moi box (rong = moi PLC); noi goi tu loc lai theo
  /// (boxDeviceId, plcAddress). Backend tu chon bucket khi [bucket] = 'auto'.
  Future<SeriesHistoryResponse> getSeriesHistory({
    required List<String> boxDeviceIds,
    required DateTime from,
    required DateTime to,
    List<String>? plcAddresses,
    String bucket = 'auto',
    CancelToken? cancelToken,
  }) async {
    const path = '/api/utility/series/history';
    final boxes = _cleanList(boxDeviceIds);
    final plcs = _cleanList(plcAddresses);

    if (boxes.isEmpty) {
      throw ArgumentError('boxDeviceIds must not be empty');
    }

    final query = _qp({
      'boxDeviceId': boxes.join(','),
      if (plcs.isNotEmpty) 'plcAddress': plcs.join(','),
      'from': _toIsoWithOffset(from),
      'to': _toIsoWithOffset(to),
      'bucket': bucket,
    });

    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map) {
        throw DioException(
          requestOptions: response.requestOptions,
          message: '$path: expected Map but got ${data.runtimeType}',
          type: DioExceptionType.badResponse,
        );
      }
      return SeriesHistoryResponse.fromJson(Map<String, dynamic>.from(data));
    } catch (error) {
      // Huy chu dong (doi range / timeout) khong phai loi API.
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      debugPrint('❌ API ERROR: $path');
      debugPrint('PARAMS: $query');
      debugPrint('ERROR: $error');
      rethrow;
    }
  }
}
