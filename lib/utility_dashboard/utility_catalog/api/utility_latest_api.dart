import 'package:dio/dio.dart';

import '../../../utility_api/dio_client.dart';
import '../models/latest_tree_response.dart';

class UtilityLatestApi {
  final Dio _dio;

  UtilityLatestApi({Dio? dio}) : _dio = dio ?? DioClient.dio;

  Future<List<LatestFacilityDto>> getLatestTree({
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) async {
    final query = <String, dynamic>{};
    void putText(String key, String? value) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        query[key] = normalized;
      }
    }

    putText('facId', facId);
    putText('scadaId', scadaId);
    putText('cate', cate);
    putText('boxDeviceId', boxDeviceId);
    final normalizedCateIds = (cateIds ?? [])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (normalizedCateIds.isNotEmpty) {
      query['cateIds'] = normalizedCateIds;
    }
    final response = await _dio.get<dynamic>(
      '/api/utility/latest',
      queryParameters: query,
    );
    final raw = response.data;
    if (raw is! List) {
      throw const FormatException('Invalid latest tree response');
    }
    return List<LatestFacilityDto>.unmodifiable(
      raw.whereType<Map>().map(
        (item) => LatestFacilityDto.fromJson(Map<String, dynamic>.from(item)),
      ),
    );
  }
}
