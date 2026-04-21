import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_models/response/latest_record.dart';
import 'package:factory_utility_visualization/utility_models/response/tree_series_response.dart';
import 'package:factory_utility_visualization/utility_models/response/utility_catalog.dart';

import '../utility_dashboard/utility_dashboard_fac_details/layout/overlay_layout_store.dart';
import '../utility_dashboard/utility_dashboard_fac_details/layout/utility_fac_layout_screen.dart';

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

  Future<TreeSeriesResponse> fetchLatestTree({
    required List<String> facIds,
    required List<String> plcAddresses,
    String? boxDeviceId,
  }) async {
    // normalize + tránh gửi rỗng
    final facs = facIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final plcs = plcAddresses
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final qp = <String, dynamic>{
      'facIds': facs.join(','),
      'plcAddresses': plcs.join(','),
    };

    final box = boxDeviceId?.trim();
    if (box != null && box.isNotEmpty) qp['boxDeviceId'] = box;

    final res = await dio.get('/api/utility/latest-tree', queryParameters: qp);

    // Dio thường trả Map<String,dynamic> sẵn
    final Map<String, dynamic> j = (res.data as Map).cast<String, dynamic>();

    return TreeSeriesResponse.fromJson(j);
  }

  // =========================
  // ✅ GROUP OVERLAY (NEW)
  // =========================

  /// GET /api/utility/overlay-groups?facId=Fac_B
  /// return: [{ boxDeviceId:"...", x01:0.2, y01:0.3 }, ...]
  Future<Map<String, OverlayGroupItem>> getOverlayGroups(String facId) async {
    final res = await dio.get(
      '/api/utility/overlay',
      queryParameters: {'facId': facId},
    );

    final data = (res.data as List).cast<dynamic>();

    final out = <String, OverlayGroupItem>{};

    for (final j in data) {
      final m = (j as Map).cast<String, dynamic>();
      final box = (m['boxDeviceId'] ?? '').toString().trim();
      if (box.isEmpty) continue;

      final x = (m['x'] as num?)?.toDouble() ?? 0.2;
      final y = (m['y'] as num?)?.toDouble() ?? 0.2;
      final direction = (m['direction'] ?? 'right').toString();

      out[box] = OverlayGroupItem(
        pos01: Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)),
        direction: direction,
      );
    }

    print('RAW RESPONSE: ${res.data}');
    return out;
  }

  /// POST /api/utility/overlay-groups
  /// body: { facId, boxDeviceId, x01, y01 }
  Future<void> setOverlayGroupPos({
    required String facId,
    required String boxDeviceId,
    required Offset pos01,
    required ArrowDirection direction, // ⭐ thêm dòng này
  }) async {
    await dio.post(
      '/api/utility/overlay/upsert',
      data: {
        'facId': facId,
        'boxDeviceId': boxDeviceId,
        'x': pos01.dx,
        'y': pos01.dy,
        'direction': direction.name, // ⭐ thêm dòng này
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
