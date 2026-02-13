import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_models/response/latest_record.dart';
import 'package:factory_utility_visualization/utility_models/response/utility_catalog.dart';

import '../utility_dashboard/utility_dashboard_fac_details/layout/OverlayPosDto.dart';

class UtilityFacadeService {
  final Dio dio;

  UtilityFacadeService(this.dio);

  final _cache = <String, _CacheEntry>{};

  String _key({
    String? fac,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    bool? importantOnly,
    String include = 'scadas,channels,params,latest',
  }) {
    return 'fac=${fac ?? ''}|scada=${scadaId ?? ''}|cate=${cate ?? ''}|dev=${boxDeviceId ?? ''}|imp=${importantOnly ?? ''}|inc=$include';
  }

  Future<UtilityCatalogDto> getCatalogCached({
    String? fac,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    bool? importantOnly,
    Duration ttl = const Duration(seconds: 5),
    String include = 'scadas,channels,params,latest',
    bool force = false,
  }) async {
    final k = _key(
      fac: fac,
      scadaId: scadaId,
      cate: cate,
      boxDeviceId: boxDeviceId,
      importantOnly: importantOnly,
      include: include,
    );

    final now = DateTime.now();
    final hit = _cache[k];

    if (!force && hit != null && now.difference(hit.at) < ttl) {
      return hit.data;
    }

    final res = await dio.get(
      '/api/utility/catalog',
      queryParameters: {
        if (fac != null && fac != 'ALL') 'facId': fac,
        if (scadaId != null && scadaId.isNotEmpty) 'scadaId': scadaId,
        if (cate != null && cate != 'ALL') 'cate': cate,
        if (boxDeviceId != null && boxDeviceId.isNotEmpty)
          'boxDeviceId': boxDeviceId,
        if (importantOnly != null) 'importantOnly': importantOnly,
        'include': include,
      },
    );

    final data = UtilityCatalogDto.fromJson(res.data as Map<String, dynamic>);
    _cache[k] = _CacheEntry(data, now);
    return data;
  }

  Future<List<LatestRecordDto>> getLatestByFac(String facId) async {
    final res = await dio.get(
      '/api/utility/latest',
      queryParameters: {'facId': facId},
    );

    final data = (res.data as List).cast<dynamic>();
    return data
        .map(
          (e) => LatestRecordDto.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<List<OverlayPosDto>> getOverlay(String facId) async {
    final res = await dio.get(
      '/api/utility/overlay',
      queryParameters: {'facId': facId},
    );

    return (res.data as List).map((e) => OverlayPosDto.fromJson(e)).toList();
  }

  Future<void> upsertOverlay({
    required String facId,
    required String boxDeviceId,
    required String plcAddress,
    required double x,
    required double y,
  }) async {
    await dio.post(
      '/api/utility/overlay/upsert',
      data: {
        'facId': facId,
        'boxDeviceId': boxDeviceId,
        'plcAddress': plcAddress,
        'x': x,
        'y': y,
      },
    );
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry {
  final UtilityCatalogDto data;
  final DateTime at;

  _CacheEntry(this.data, this.at);
}
