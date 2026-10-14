import 'package:dio/dio.dart';

import '../../../../utility_api/dio_client.dart';
import '../../setting_api_support.dart';
import '../models/utility_scada.dart';

/// `/api/v1/utility-scada` qua Dio dung chung ([DioClient.dio]).
/// Loi HTTP / mang: DioException, doi thong bao bang settingErrorMessage.
class UtilityScadaApi {
  static const String _path = '/api/v1/utility-scada';

  final Dio _dio;

  UtilityScadaApi({Dio? dio}) : _dio = dio ?? DioClient.dio;

  Future<List<UtilityScada>> getAll() async {
    final response = await _dio.get<dynamic>(
      _path,
      options: settingRequestOptions(),
    );

    return settingListOf(response)
        .map((e) => UtilityScada.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<UtilityScada> create(UtilityScada item) async {
    final payload = Map<String, dynamic>.from(item.toJson())..remove('id');

    final response = await _dio.post<dynamic>(
      _path,
      data: payload,
      options: settingRequestOptions(withBody: true),
    );

    return UtilityScada.fromJson(settingMapOf(response));
  }

  Future<UtilityScada> update(int id, UtilityScada item) async {
    final payload = Map<String, dynamic>.from(item.toJson())..remove('id');

    final response = await _dio.put<dynamic>(
      '$_path/$id',
      data: payload,
      options: settingRequestOptions(withBody: true),
    );

    return UtilityScada.fromJson(settingMapOf(response));
  }
}
