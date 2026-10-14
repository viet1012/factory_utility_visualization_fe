import 'package:dio/dio.dart';

import '../../../../utility_api/dio_client.dart';
import '../../setting_api_support.dart';
import '../models/utility_para.dart';
import '../models/utility_para_tree_models.dart';

/// `/api/v1/utility-para` qua Dio dung chung ([DioClient.dio]).
/// Dio nem DioException voi status ngoai 2xx nen khong tu kiem tra status;
/// doi thong bao bang settingErrorMessage.
class UtilityParaApi {
  static const String _path = '/api/v1/utility-para';

  final Dio _dio;

  UtilityParaApi({Dio? dio}) : _dio = dio ?? DioClient.dio;

  Future<List<UtilityParaTreeFac>> getGroupedByFacWithParas() async {
    final response = await _dio.get<dynamic>(
      '$_path/grouped-by-fac-with-paras',
      options: settingRequestOptions(),
    );

    return settingListOf(response)
        .map(
          (e) =>
              UtilityParaTreeFac.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<UtilityPara> create(UtilityPara item) async {
    final response = await _dio.post<dynamic>(
      _path,
      data: item.toJson()..remove('id'),
      options: settingRequestOptions(withBody: true),
    );

    return UtilityPara.fromJson(settingMapOf(response));
  }

  Future<UtilityPara> update(int id, UtilityPara item) async {
    final response = await _dio.put<dynamic>(
      '$_path/$id',
      data: item.toJson()..remove('id'),
      options: settingRequestOptions(withBody: true),
    );

    return UtilityPara.fromJson(settingMapOf(response));
  }
}
