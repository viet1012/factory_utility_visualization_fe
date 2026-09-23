import 'package:dio/dio.dart';

import '../../../utility_api/dio_client.dart';
import '../models/signal_health_history_models.dart';

/// Read-only client for the hourly Signal Health history endpoint.
///
/// Kept separate from [SignalHealthApi] so the realtime matrix and the
/// historical query evolve independently, matching the existing one-file-per-
/// concern layout of this module.
class SignalHealthHistoryApi {
  SignalHealthHistoryApi();

  static const String _historyHourlyPath =
      '/api/utility/signal-health/history/hourly';

  Dio get _dio => DioClient.dio;

  /// Fetches hourly alert buckets for [filter].
  ///
  /// `from`/`to` are sent as ISO-8601 local wall-clock strings with no `Z` and
  /// no offset, matching the convention the other Utility endpoints already
  /// use. Optional facet filters are omitted entirely when null/blank so the
  /// backend applies its own "all" default rather than matching an empty
  /// string.
  Future<List<SignalHealthHistoryBucket>> getHourlyHistory(
    SignalHealthHistoryFilter filter,
  ) async {
    final query = <String, dynamic>{
      'from': _toIsoNoZone(filter.from),
      'to': _toIsoNoZone(filter.to),
    };

    void putText(String key, String? value) {
      final normalized = value?.trim();

      if (normalized != null &&
          normalized.isNotEmpty &&
          normalized.toUpperCase() != 'ALL') {
        query[key] = normalized;
      }
    }

    putText('fac', filter.fac);
    putText('cate', filter.cate);
    putText('scadaId', filter.scadaId);
    putText('boxDeviceId', filter.boxDeviceId);

    final response = await _dio.get<dynamic>(
      _historyHourlyPath,
      queryParameters: query,
    );

    return _parseBuckets(response.data);
  }

  /// Accepts either a bare list of buckets or an envelope carrying them under
  /// a `data`/`buckets`/`items` key, so a backend envelope change does not
  /// break the panel.
  List<SignalHealthHistoryBucket> _parseBuckets(dynamic raw) {
    final list = _extractList(raw);

    if (list == null) {
      throw const FormatException('Invalid signal health history response');
    }

    final result = <SignalHealthHistoryBucket>[];

    for (final item in list) {
      if (item is! Map) continue;

      final bucket = SignalHealthHistoryBucket.tryFromJson(
        Map<String, dynamic>.from(item),
      );

      // Buckets without a usable bucketTime cannot be plotted, so drop them.
      if (bucket != null) result.add(bucket);
    }

    result.sort((a, b) => a.bucketTime.compareTo(b.bucketTime));

    return List<SignalHealthHistoryBucket>.unmodifiable(result);
  }

  List<dynamic>? _extractList(dynamic raw) {
    if (raw is List) return raw;

    if (raw is Map) {
      for (final key in const ['data', 'buckets', 'items', 'result']) {
        final value = raw[key];
        if (value is List) return value;
      }
    }

    return null;
  }

  /// Formats as `yyyy-MM-ddTHH:mm:ss` with no zone designator.
  String _toIsoNoZone(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;

    String two(int number) => number.toString().padLeft(2, '0');

    return '${local.year.toString().padLeft(4, '0')}-'
        '${two(local.month)}-'
        '${two(local.day)}T'
        '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}';
  }
}
