import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_models/response/latest_record.dart';
import 'package:factory_utility_visualization/utility_models/response/tree_series_response.dart';
import 'package:factory_utility_visualization/utility_models/response/utility_catalog.dart';
import 'package:flutter/foundation.dart';

import '../utility_dashboard/utility_dashboard_fac_details/layout/overlay_layout_store.dart';
import '../utility_dashboard/utility_dashboard_fac_details/models/group_frame_types.dart';

class UtilityFacadeService {
  final Dio dio;

  UtilityFacadeService(this.dio);

  final Map<String, _CacheEntry> _cache = {};

  static const String _defaultCatalogInclude = 'scadas,channels,params,latest';

  String _cacheKey({
    String? fac,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    bool? importantOnly,
    String include = _defaultCatalogInclude,
  }) {
    return [
      'fac=${fac ?? ''}',
      'scada=${scadaId ?? ''}',
      'cate=${cate ?? ''}',
      'dev=${boxDeviceId ?? ''}',
      'imp=${importantOnly ?? ''}',
      'inc=$include',
    ].join('|');
  }

  String? _clean(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  List<String> _cleanList(List<String> values) {
    return values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Map<String, dynamic> _catalogQuery({
    String? fac,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    bool? importantOnly,
    String include = _defaultCatalogInclude,
  }) {
    return {
      if (_clean(fac) != null && fac != 'ALL') 'facId': fac,
      if (_clean(scadaId) != null) 'scadaId': scadaId,
      if (_clean(cate) != null && cate != 'ALL') 'cate': cate,
      if (_clean(boxDeviceId) != null) 'boxDeviceId': boxDeviceId,
      if (importantOnly != null) 'importantOnly': importantOnly,
      'include': include,
    };
  }

  List<dynamic> _asList(dynamic data, {required String apiName}) {
    if (data is! List) {
      throw DioException(
        requestOptions: RequestOptions(path: apiName),
        message: '$apiName: Expected List but got ${data.runtimeType}',
        type: DioExceptionType.badResponse,
      );
    }
    return data.cast<dynamic>();
  }

  Map<String, dynamic> _asMap(dynamic data, {required String apiName}) {
    if (data is! Map) {
      throw DioException(
        requestOptions: RequestOptions(path: apiName),
        message: '$apiName: Expected Map but got ${data.runtimeType}',
        type: DioExceptionType.badResponse,
      );
    }
    return data.cast<String, dynamic>();
  }

  Future<UtilityCatalogDto> getCatalogCached({
    String? fac,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    bool? importantOnly,
    Duration ttl = const Duration(seconds: 5),
    String include = _defaultCatalogInclude,
    bool force = false,
  }) async {
    final key = _cacheKey(
      fac: fac,
      scadaId: scadaId,
      cate: cate,
      boxDeviceId: boxDeviceId,
      importantOnly: importantOnly,
      include: include,
    );

    final now = DateTime.now();
    final cached = _cache[key];

    if (!force && cached != null && now.difference(cached.at) < ttl) {
      return cached.data;
    }

    final res = await dio.get(
      '/api/utility/catalog',
      queryParameters: _catalogQuery(
        fac: fac,
        scadaId: scadaId,
        cate: cate,
        boxDeviceId: boxDeviceId,
        importantOnly: importantOnly,
        include: include,
      ),
    );

    final dto = UtilityCatalogDto.fromJson(
      _asMap(res.data, apiName: '/api/utility/catalog'),
    );

    _cache[key] = _CacheEntry(dto, now);
    return dto;
  }

  Future<List<LatestRecordDto>> getLatestByFac(String facId) async {
    final cleanFacId = _clean(facId);
    if (cleanFacId == null) return const [];

    final res = await dio.get(
      '/api/utility/latest',
      queryParameters: {'facId': cleanFacId},
    );

    debugPrint('GET ${res.requestOptions.uri}');

    return _asList(res.data, apiName: '/api/utility/latest')
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
    final cleanFacIds = _cleanList(facIds);
    final cleanPlcAddresses = _cleanList(plcAddresses);
    final cleanBoxDeviceId = _clean(boxDeviceId);

    final queryParameters = <String, dynamic>{
      'facIds': cleanFacIds.join(','),
      'plcAddresses': cleanPlcAddresses.join(','),
      if (cleanBoxDeviceId != null) 'boxDeviceId': cleanBoxDeviceId,
    };

    final res = await dio.get(
      '/api/utility/latest-tree',
      queryParameters: queryParameters,
    );

    return TreeSeriesResponse.fromJson(
      _asMap(res.data, apiName: '/api/utility/latest-tree'),
    );
  }

  Future<Map<String, OverlayGroupItem>> getOverlayGroups(String facId) async {
    final cleanFacId = _clean(facId);
    if (cleanFacId == null) return {};

    final res = await dio.get(
      '/api/utility/overlay',
      queryParameters: {'facId': cleanFacId},
    );

    final list = _asList(res.data, apiName: '/api/utility/overlay');
    final result = <String, OverlayGroupItem>{};

    for (final item in list) {
      final map = (item as Map).cast<String, dynamic>();

      final overlayKey = (map['boxDeviceId'] ?? '').toString().trim();
      if (overlayKey.isEmpty) continue;

      final x = (map['x'] as num?)?.toDouble() ?? 0.2;
      final y = (map['y'] as num?)?.toDouble() ?? 0.2;
      final direction = (map['direction'] ?? 'right').toString();
      final color = map['color']?.toString();

      result[overlayKey] = OverlayGroupItem(
        pos01: Offset(
          x.clamp(0.0, 1.0).toDouble(),
          y.clamp(0.0, 1.0).toDouble(),
        ),
        direction: direction,
        color: color,
      );
    }

    return result;
  }

  Future<void> setOverlayGroupPos({
    required String facId,
    required String boxDeviceId,
    required Offset pos01,
    required ArrowDirection direction,
    String? color,
  }) async {
    final cleanFacId = _clean(facId);
    final cleanOverlayKey = _clean(boxDeviceId);

    if (cleanFacId == null || cleanOverlayKey == null) return;

    await dio.post(
      '/api/utility/overlay/upsert',
      data: {
        'facId': cleanFacId,
        'boxDeviceId': cleanOverlayKey,
        'x': pos01.dx,
        'y': pos01.dy,
        'direction': direction.name,
        'color': _clean(color),
      },
    );
  }

  void clearCache() {
    _cache.clear();
  }
}

class _CacheEntry {
  final UtilityCatalogDto data;
  final DateTime at;

  _CacheEntry(this.data, this.at);
}
