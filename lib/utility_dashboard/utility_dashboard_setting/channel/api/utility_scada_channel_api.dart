import 'package:dio/dio.dart';

import '../../../../utility_api/dio_client.dart';
import '../../setting_api_support.dart';
import '../models/utility_scada_channel.dart';
import '../models/utility_scada_tree_models.dart';

/// `/api/v1/utility-scada-channels` qua Dio dung chung ([DioClient.dio]).
/// Loi HTTP / mang: DioException, doi thong bao bang settingErrorMessage.
class UtilityScadaChannelApi {
  static const String _path = '/api/v1/utility-scada-channels';

  final Dio _dio;

  UtilityScadaChannelApi({Dio? dio}) : _dio = dio ?? DioClient.dio;

  Future<List<UtilityScadaTreeFacRaw>> getGroupedByFac() async {
    final response = await _dio.get<dynamic>(
      '$_path/group-by-fac',
      options: settingRequestOptions(),
    );

    return settingListOf(response)
        .map(
          (e) => UtilityScadaTreeFacRaw.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<UtilityScadaChannel>> getAll() async {
    final response = await _dio.get<dynamic>(
      _path,
      options: settingRequestOptions(),
    );

    return settingListOf(response)
        .map(
          (e) =>
              UtilityScadaChannel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<UtilityScadaChannel> create(UtilityScadaChannel item) async {
    final payload = Map<String, dynamic>.from(item.toJson())..remove('id');

    final response = await _dio.post<dynamic>(
      _path,
      data: payload,
      options: settingRequestOptions(withBody: true),
    );

    return UtilityScadaChannel.fromJson(settingMapOf(response));
  }

  Future<UtilityScadaChannel> update(int id, UtilityScadaChannel item) async {
    final payload = Map<String, dynamic>.from(item.toJson())..remove('id');

    final response = await _dio.put<dynamic>(
      '$_path/$id',
      data: payload,
      options: settingRequestOptions(withBody: true),
    );

    return UtilityScadaChannel.fromJson(settingMapOf(response));
  }
}
