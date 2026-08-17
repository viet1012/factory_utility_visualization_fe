import 'dart:ui';

import 'package:dio/dio.dart';

import '../utility_dashboard/utility_dashboard_fac_details/layout/overlay_layout_store.dart';
import '../utility_dashboard/utility_dashboard_fac_details/models/group_frame_types.dart';

class UtilityFacadeService {
  final Dio dio;

  UtilityFacadeService(this.dio);

  String? _clean(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
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
    final cleanBoxDeviceId = _clean(boxDeviceId);
    final cleanColor = _clean(color);

    if (cleanFacId == null || cleanBoxDeviceId == null) {
      return;
    }

    final data = <String, dynamic>{
      'facId': cleanFacId,
      'boxDeviceId': cleanBoxDeviceId,
      'x': pos01.dx,
      'y': pos01.dy,
      'direction': direction.name,

      // Quan trọng: không gửi null để tránh backend xóa màu cũ.
      if (cleanColor != null) 'color': cleanColor,
    };

    await dio.post('/api/utility/overlay/upsert', data: data);
  }
}
