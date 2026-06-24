import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utility_models/f2_utility_parameter_master.dart';
import '../utility_models/f2_utility_scada_channel.dart';
import '../utility_models/response/latest_record.dart';
import '../utility_models/response/minute_point.dart';
import '../utility_models/response/tree_series_response.dart';
import 'dio_client.dart';

class UtilityApi {
  final Dio _dio;

  UtilityApi({Dio? dio}) : _dio = dio ?? DioClient.dio;

  // ================== HELPERS ==================

  String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  List<String> _cleanList(List<String>? list) {
    if (list == null) return [];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Map<String, dynamic> _qp(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      out[k] = v;
    });
    return out;
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

  Map<String, dynamic> _asMap(dynamic data, String path) {
    if (data is! Map) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        message: '$path: expected Map but got ${data.runtimeType}',
        type: DioExceptionType.badResponse,
      );
    }
    return data.cast<String, dynamic>();
  }

  void _log(Response res) {
    debugPrint('[GET] ${res.realUri}');
  }

  String _toIsoNoZ(DateTime dt) {
    final d = dt.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  // ================== API ==================

  // ---------- TREE SERIES ----------
  Future<TreeSeriesResponse> getTreeSeries({
    required String fac,
    required String boxDeviceId,
    required String plcAddress,
    String? range,
    int? year,
    int? month,
  }) async {
    const path = '/api/utility/chart/tree-series';

    final res = await _dio.get(
      path,
      queryParameters: _qp({
        'fac': _clean(fac),
        'boxDeviceId': _clean(boxDeviceId),
        'plcAddress': _clean(plcAddress),
        'range': _clean(range),
        'year': year,
        'month': month,
      }),
    );

    _log(res);

    return TreeSeriesResponse.fromJson(_asMap(res.data, path));
  }

  // ---------- CHANNELS ----------
  Future<List<ScadaChannelDto>> getChannels({
    String? facId,
    String? cate,
  }) async {
    const path = '/api/utility/channels';

    final res = await _dio.get(
      path,
      queryParameters: _qp({'facId': _clean(facId), 'cate': _clean(cate)}),
    );

    return _asList(res.data, path)
        .map((e) => ScadaChannelDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---------- PARAMS ----------
  Future<List<ParamDto>> getParams({
    String? facId,
    String? cate,
    String? boxDeviceId,
    int? importantOnly,
  }) async {
    const path = '/api/utility/params';

    final res = await _dio.get(
      path,
      queryParameters: _qp({
        'facId': _clean(facId),
        'cate': _clean(cate),
        'boxDeviceId': _clean(boxDeviceId),
        if (importantOnly != null) 'importantOnly': importantOnly == 1 ? 1 : 0,
      }),
    );

    _log(res);

    return _asList(
      res.data,
      path,
    ).map((e) => ParamDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ---------- LATEST ----------
  Future<List<LatestRecordDto>> getLatest({
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) async {
    const path = '/api/utility/latest';

    final res = await _dio.get(
      path,
      queryParameters: _qp({
        'facId': _clean(facId),
        'scadaId': _clean(scadaId),
        'cate': _clean(cate),
        'boxDeviceId': _clean(boxDeviceId),
        if (_cleanList(cateIds).isNotEmpty)
          'cateIds': _cleanList(cateIds).join(','),
      }),
    );

    _log(res);

    return _asList(res.data, path)
        .map((e) => LatestRecordDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---------- MINUTE SERIES ----------
  Future<List<MinutePointDto>> getSeriesMinute({
    required DateTime from,
    required DateTime to,
    String? boxDeviceId,
    String? plcAddress,
    List<String>? cateIds,
  }) async {
    const path = '/api/utility/series/minute';

    final qp = _qp({
      'from': _toIsoNoZ(from),
      'to': _toIsoNoZ(to),
      'boxDeviceId': _clean(boxDeviceId),
      'plcAddress': _clean(plcAddress),
      if (_cleanList(cateIds).isNotEmpty)
        'cateIds': _cleanList(cateIds).join(','),
    });

    try {
      final res = await _dio.get(path, queryParameters: qp);

      _log(res);

      return _asList(res.data, path)
          .map((e) => MinutePointDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ API ERROR: $path');
      debugPrint('PARAMS: $qp');
      debugPrint('ERROR: $e');
      rethrow;
    }
  }
}
