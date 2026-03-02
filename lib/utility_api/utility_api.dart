import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../utility_models/f2_utility_parameter_master.dart';
import '../utility_models/f2_utility_scada_channel.dart';
import '../utility_models/response/latest_record.dart';
import '../utility_models/response/minute_point.dart';
import '../utility_models/response/sum_compare_item.dart';
import '../utility_models/response/tree_series_response.dart';
import 'dio_client.dart';

class UtilityApi {
  final Dio _dio;

  UtilityApi({Dio? dio}) : _dio = dio ?? DioClient.dio;

  // ========== tree-series ==========
  Future<TreeSeriesResponse> getTreeSeries({
    required String fac,
    required String boxDeviceId,
    required String plcAddress,
    String? range, // TODAY/YESTERDAY/LAST_7_DAYS/THIS_MONTH nếu BE support
    int? year,
    int? month,
  }) async {
    const path = '/api/utility/chart/tree-series';

    final qp = <String, dynamic>{
      'fac': fac.trim(),
      'boxDeviceId': boxDeviceId.trim(),
      'plcAddress': plcAddress.trim(),
      if (range != null && range.trim().isNotEmpty) 'range': range.trim(),
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };

    final res = await _dio.get(path, queryParameters: qp);
    debugPrint('[GET] ${res.realUri}');

    final data = res.data;
    if (data is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'tree-series: Expected Map but got ${data.runtimeType}',
        type: DioExceptionType.badResponse,
      );
    }
    return TreeSeriesResponse.fromJson((data as Map).cast<String, dynamic>());
  }

  // ========== channels ==========
  Future<List<ScadaChannelDto>> getChannels({
    String? facId,
    String? cate,
  }) async {
    final qp = <String, dynamic>{};
    if (facId != null && facId.trim().isNotEmpty) qp['facId'] = facId.trim();
    if (cate != null && cate.trim().isNotEmpty) qp['cate'] = cate.trim();

    final res = await _dio.get('/api/utility/channels', queryParameters: qp);
    final data = res.data;
    if (data is! List) throw Exception('channels: expected List');

    return data
        .map(
          (e) => ScadaChannelDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  // ========== params ==========
  Future<List<ParamDto>> getParams({
    String? facId,
    String? cate,
    String? boxDeviceId,
    int? importantOnly,
  }) async {
    final qp = <String, dynamic>{};

    final fac = facId?.trim();
    if (fac != null && fac.isNotEmpty) qp['facId'] = fac;

    final c = cate?.trim();
    if (c != null && c.isNotEmpty) qp['cate'] = c;

    final box = boxDeviceId?.trim();
    if (box != null && box.isNotEmpty) qp['boxDeviceId'] = box;

    if (importantOnly != null) qp['importantOnly'] = importantOnly == 1 ? 1 : 0;

    final res = await _dio.get('/api/utility/params', queryParameters: qp);
    debugPrint('[GET] ${res.realUri}');

    final data = res.data;
    if (data is! List) throw Exception('params: expected List');

    return data
        .map((e) => ParamDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ========== latest ==========
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
      if (cleaned.isNotEmpty) params['cateIds'] = cleaned.join(',');
    }

    final res = await _dio.get('/api/utility/latest', queryParameters: params);
    final data = res.data;
    debugPrint('[GET] ${res.realUri}');

    if (data is! List) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'latest: Expected List but got: ${data.runtimeType}',
        type: DioExceptionType.badResponse,
      );
    }

    return data
        .map(
          (e) => LatestRecordDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  // ========== minute series ==========
  Future<List<MinutePointDto>> getSeriesMinute({
    required DateTime from,
    required DateTime to,
    String? boxDeviceId,
    String? plcAddress,
    List<String>? cateIds,
  }) async {
    final qp = <String, dynamic>{'from': _toIsoNoZ(from), 'to': _toIsoNoZ(to)};

    void putIfNotBlank(String k, String? v) {
      if (v != null && v.trim().isNotEmpty) qp[k] = v.trim();
    }

    putIfNotBlank('boxDeviceId', boxDeviceId);
    putIfNotBlank('plcAddress', plcAddress);

    if (cateIds != null) {
      final cleaned = cateIds
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (cleaned.isNotEmpty) qp['cateIds'] = cleaned.join(',');
    }

    final res = await _dio.get(
      '/api/utility/series/minute',
      queryParameters: qp,
    );
    debugPrint('[GET] ${res.realUri}');

    final data = res.data;
    if (data is! List) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'minute: Expected List but got: ${data.runtimeType}',
        type: DioExceptionType.badResponse,
      );
    }

    return data
        .map(
          (e) => MinutePointDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  // ========== sum compare ==========
  Future<List<SumCompareItem>> sumCompare({
    String by = 'cate',
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? deviceIds,
    List<String>? cateIds,
    List<String>? nameEns,
  }) async {
    final res = await _dio.get(
      '/api/utility/sum-compare',
      queryParameters: {
        'by': by,
        if (facId?.trim().isNotEmpty == true) 'facId': facId,
        if (scadaId?.trim().isNotEmpty == true) 'scadaId': scadaId,
        if (cate?.trim().isNotEmpty == true) 'cate': cate,
        if (boxDeviceId?.trim().isNotEmpty == true) 'boxDeviceId': boxDeviceId,
        if (deviceIds?.isNotEmpty == true) 'deviceIds': deviceIds,
        if (cateIds?.isNotEmpty == true) 'cateIds': cateIds,
        if (nameEns?.isNotEmpty == true) 'nameEns': nameEns,
      },
    );

    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => SumCompareItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  String _toIsoNoZ(DateTime dt) {
    final d = dt.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  // (nếu bạn còn dùng)
  String _fmtIso(DateTime dt) => DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);
}
