import 'package:dio/dio.dart';

import '../utility_models/f2_utility_parameter_master.dart';
import '../utility_models/f2_utility_scada_channel.dart';
import '../utility_models/response/latest_record.dart';
import '../utility_models/response/minute_point.dart';
import '../utility_models/response/sum_compare_item.dart';

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

  Future<List<ParamDto>> getParams({
    String? facId,
    String? cate,
    String? boxDeviceId,
  }) async {
    final qp = <String, dynamic>{};
    if (facId != null && facId.trim().isNotEmpty) qp['facId'] = facId.trim();
    if (cate != null && cate.trim().isNotEmpty) qp['cate'] = cate.trim();
    if (boxDeviceId != null && boxDeviceId.trim().isNotEmpty) {
      qp['boxDeviceId'] = boxDeviceId.trim();
    }

    final res = await _dio.get('/api/utility/params', queryParameters: qp);

    final data = res.data;
    if (data is! List) throw Exception('params: expected List');

    return data
        .map((e) => ParamDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
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
          (e) => MinutePointDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<SumCompareItem>> sumCompare({
    String by = 'cate',
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? deviceIds,
    List<String>? cateIds,
    // ✅ NEW
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

        // ✅ QUAN TRỌNG
        if (nameEns?.isNotEmpty == true) 'nameEns': nameEns,
      },
    );

    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => SumCompareItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // Java LocalDateTime.parse() nhận format "yyyy-MM-ddTHH:mm:ss" OK
  String _toIsoNoZ(DateTime dt) {
    final d = dt.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}
