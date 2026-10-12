import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../utility_all_factory_chart/api/utility_chart_api.dart';
import '../../utility_all_factory_chart/models/series_history_response.dart';
import '../models/latest_tree_response.dart';
import '../models/signal_history_models.dart';
import 'latest_signal_index.dart';
import 'signal_history_repository.dart';

/// Lich su that tu `GET /api/utility/series/history` cho MOI range.
///
/// bucket do caller chon (HistoryRange.requestBucket): 'auto' -> backend tu
/// chon (≤1h: 1m, ≤6h: 5m, ≤24h: 15m, >24h: snapshot 1h); 24h gui '1h'.
/// Backend
/// da gap-fill bucket rong (count = 0) va tra kind / nguong / alertLevel.
/// Mot request cho moi boxDeviceId, loc theo cac plcAddress duoc yeu cau.
class ApiSignalHistoryRepository implements SignalHistoryRepository {
  final UtilityChartApi api;

  /// Cay latest hien tai: map signalId -> boxDeviceId / plcAddress / ten.
  final List<LatestFacilityDto> Function() source;

  ApiSignalHistoryRepository({required this.api, required this.source});

  @override
  Future<SignalHistoryResult> fetchHistory({
    required List<String> signalIds,
    required DateTime from,
    required DateTime to,
    String bucket = 'auto',
    CancelToken? cancelToken,
  }) async {
    // Thoi diem gui request: de nhan biet bucket cuoi chua du thoi gian.
    final requestedAt = DateTime.now();

    /*
     * Lam tron xuong theo phut (giay = 0): cac lan polling trong cung mot
     * phut gui cung mot request, moc bucket on dinh giua cac lan refresh.
     */
    from = _floorMinute(from);
    to = _floorMinute(to);

    final index = indexLatestSignals(source());

    // Gom signal theo boxDeviceId, giu thu tu yeu cau.
    final byDevice = <String, List<_Target>>{};

    for (final id in signalIds) {
      final ref = index[id];
      if (ref == null) continue;

      final device = ref.boxDeviceId.trim();
      if (device.isEmpty) continue;

      byDevice.putIfAbsent(device, () => <_Target>[]).add(_Target(id, ref));
    }

    if (byDevice.isEmpty) {
      return const SignalHistoryResult(
        series: <SignalHistorySeries>[],
        source: DataSource.api,
      );
    }

    // Song song theo device; loi cua mot device khong lam hong device khac.
    final responses = await Future.wait(
      byDevice.entries.map(
        (entry) => _fetchDevice(
          entry.key,
          entry.value,
          from,
          to,
          bucket,
          cancelToken,
        ),
      ),
    );

    final mapWatch = Stopwatch()..start();

    final failures = responses.where((item) => item.error != null).toList();

    // Khong device nao thanh cong: nem loi de UI hien error state + Retry.
    if (failures.length == responses.length) {
      final failure = failures.first;
      Error.throwWithStackTrace(
        _mapError(failure.error!),
        failure.stackTrace ?? StackTrace.current,
      );
    }

    final seriesById = <String, SignalHistorySeries>{};
    var aggregation = HistoryAggregation.minAvgMax;
    Duration? resultBucket;

    for (final response in responses) {
      final body = response.body;

      // Device nay loi (cac device khac van OK): moi the cua no hien loi.
      if (body == null) {
        final message = _describeError(response.error);

        for (final target in response.targets) {
          seriesById[target.id] = _errorSeries(target, message);
        }
        continue;
      }

      final responseAggregation = body.isSnapshot
          ? HistoryAggregation.snapshot
          : HistoryAggregation.minAvgMax;

      if (responseAggregation == HistoryAggregation.snapshot) {
        aggregation = HistoryAggregation.snapshot;
      }

      final responseBucket = body.bucketDuration;
      resultBucket ??= responseBucket;

      // Ghep theo khoa that (boxDeviceId + plcAddress), khong theo thu tu.
      final signalsByPlc = <String, SeriesHistorySignalDto>{
        for (final signal in body.signals)
          if (signal.boxDeviceId.trim() == response.boxDeviceId)
            signal.plcAddress.trim(): signal,
      };

      for (final target in response.targets) {
        final plc = target.ref.signal.plcAddress.trim();
        final dto = signalsByPlc[plc];

        // Loi rieng cua signal: chi the do hien loi.
        if (dto == null) {
          seriesById[target.id] = _errorSeries(
            target,
            'Not returned by the history API.',
          );
          continue;
        }

        if (dto.parseError != null) {
          seriesById[target.id] = _errorSeries(
            target,
            'Invalid history data for this signal.',
          );
          debugPrint(
            '[SIGNAL HISTORY PARSE ERROR] boxDeviceId=${response.boxDeviceId} '
            'plc=$plc error=${dto.parseError}',
          );
          continue;
        }

        seriesById[target.id] = _buildSeries(
          target,
          dto,
          responseAggregation,
          responseBucket,
          requestedAt,
        );
      }
    }

    final ordered = <SignalHistorySeries>[
      for (final id in signalIds)
        if (seriesById[id] != null) seriesById[id]!,
    ];

    if (kDebugMode) {
      debugPrint(
        '[SIGNAL HISTORY] parsed series=${ordered.length} '
        'errors=${ordered.where((s) => s.error != null).length} '
        'points=${ordered.fold<int>(0, (n, s) => n + s.points.length)} '
        'map=${mapWatch.elapsedMilliseconds}ms',
      );
    }

    return SignalHistoryResult(
      series: List<SignalHistorySeries>.unmodifiable(ordered),
      source: DataSource.api,
      aggregation: aggregation,
      bucket: resultBucket,
    );
  }

  Future<_DeviceResponse> _fetchDevice(
    String boxDeviceId,
    List<_Target> targets,
    DateTime from,
    DateTime to,
    String bucket,
    CancelToken? cancelToken,
  ) async {
    final watch = Stopwatch()..start();

    if (kDebugMode) {
      debugPrint(
        '[SIGNAL HISTORY] send boxDeviceId=$boxDeviceId '
        'plc=${targets.length} from=$from to=$to bucket=$bucket',
      );
    }

    try {
      final body = await api.getSeriesHistory(
        boxDeviceId: boxDeviceId,
        plcAddresses: [
          for (final target in targets) target.ref.signal.plcAddress,
        ],
        from: from,
        to: to,
        bucket: bucket,
        cancelToken: cancelToken,
      );

      if (kDebugMode) {
        debugPrint(
          '[SIGNAL HISTORY] recv boxDeviceId=$boxDeviceId '
          'bucket=${body.bucket} source=${body.source} '
          'signals=${body.signals.length} '
          'points=${body.signals.fold<int>(0, (n, s) => n + s.points.length)} '
          'elapsed=${watch.elapsedMilliseconds}ms',
        );
      }

      return _DeviceResponse(
        boxDeviceId: boxDeviceId,
        targets: targets,
        body: body,
      );
    } catch (error, stackTrace) {
      final cancelled = error is DioException && CancelToken.isCancel(error);

      if (!cancelled || kDebugMode) {
        debugPrint(
          '[SIGNAL HISTORY ${cancelled ? 'CANCELLED' : 'API ERROR'}] '
          'boxDeviceId=$boxDeviceId elapsed=${watch.elapsedMilliseconds}ms '
          'error=${cancelled ? error.message : error}',
        );
      }

      return _DeviceResponse(
        boxDeviceId: boxDeviceId,
        targets: targets,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  SignalHistorySeries _buildSeries(
    _Target target,
    SeriesHistorySignalDto? dto,
    HistoryAggregation aggregation,
    Duration? bucket,
    DateTime requestedAt,
  ) {
    final signal = target.ref.signal;

    // Ten / code / unit uu tien tu cay latest de khop voi bang.
    final unit = _firstNotEmpty(signal.unit, dto?.unit);
    final code = _firstNotEmpty(signal.cateId, dto?.code);
    final name = _firstNotEmpty(signal.nameEn, dto?.name) ?? code ?? '--';

    return SignalHistorySeries(
      signalId: target.id,
      plc: signal.plcAddress.trim(),
      name: name,
      code: code,
      unit: unit,
      kind: _parseKind(dto?.kind),
      thresholdLow: dto?.thresholdLow,
      thresholdHigh: dto?.thresholdHigh,
      alertLevel: dto?.alertLevel,
      aggregation: aggregation,
      bucket: bucket,
      points: dto == null
          ? const <SignalHistoryPoint>[]
          : List<SignalHistoryPoint>.unmodifiable(
              _dropIncompleteEmpty(dto.points, bucket, requestedAt).map(
                _toPoint,
              ),
            ),
    );
  }

  /// Bucket chua du thoi gian (ts + bucket > requestedAt) ma count == 0:
  /// bo khoi series - khong ve, khong tinh la gap. Neu da co mau (count > 0)
  /// thi van giu va ve binh thuong.
  static List<SeriesHistoryPointDto> _dropIncompleteEmpty(
    List<SeriesHistoryPointDto> points,
    Duration? bucket,
    DateTime requestedAt,
  ) {
    final step = bucket ?? _inferBucket(points);

    return [
      for (final point in points)
        if (!(point.count == 0 && point.ts.add(step).isAfter(requestedAt)))
          point,
    ];
  }

  /// Khoang cach duong nho nhat giua hai diem lien tiep; mac dinh 1 phut.
  static Duration _inferBucket(List<SeriesHistoryPointDto> points) {
    Duration? smallest;

    for (var i = 1; i < points.length; i++) {
      final diff = points[i].ts.difference(points[i - 1].ts);
      if (diff <= Duration.zero) continue;

      if (smallest == null || diff < smallest) smallest = diff;
    }

    return smallest ?? const Duration(minutes: 1);
  }

  static DateTime _floorMinute(DateTime time) {
    final local = time.toLocal();

    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  /// The loi cho mot signal: giu ten / PLC / unit tu cay latest de the van
  /// nhan dien duoc, khong co diem.
  SignalHistorySeries _errorSeries(_Target target, String message) {
    final signal = target.ref.signal;
    final code = _firstNotEmpty(signal.cateId, null);
    final unit = _firstNotEmpty(signal.unit, null);

    return SignalHistorySeries(
      signalId: target.id,
      plc: signal.plcAddress.trim(),
      name: _firstNotEmpty(signal.nameEn, null) ?? code ?? '--',
      code: code,
      unit: unit,
      kind: SignalKind.analog,
      thresholdLow: null,
      thresholdHigh: null,
      points: const <SignalHistoryPoint>[],
      error: message,
    );
  }

  static String _describeError(Object? error) {
    final mapped = error == null ? null : _mapError(error);

    if (mapped is SignalHistoryRequestException) return mapped.message;

    if (mapped is DioException &&
        (mapped.type == DioExceptionType.connectionTimeout ||
            mapped.type == DioExceptionType.receiveTimeout)) {
      return 'History API timed out.';
    }

    return 'Unable to load history for this signal.';
  }

  /// Diem ve = avg; bucket rong (count == 0) -> null.
  static SignalHistoryPoint _toPoint(SeriesHistoryPointDto point) {
    final empty = point.count == 0;

    return SignalHistoryPoint(
      ts: point.ts,
      value: empty ? null : point.avg,
      min: empty ? null : point.min,
      max: empty ? null : point.max,
      last: empty ? null : point.last,
      count: point.count,
      delta: point.delta,
    );
  }

  static SignalKind _parseKind(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'STATUS':
        return SignalKind.status;
      case 'COUNTER':
        return SignalKind.counter;
      default:
        // ANALOG hoac thieu: ve line, an toan nhat.
        return SignalKind.analog;
    }
  }

  /// 400 -> SignalHistoryRequestException kem message cua backend.
  static Object _mapError(Object error) {
    if (error is! DioException || error.response?.statusCode != 400) {
      return error;
    }

    final data = error.response?.data;
    String? message;

    if (data is Map) {
      message = (data['message'] ?? data['error'] ?? data['detail'])
          ?.toString();
    } else if (data is String) {
      message = data;
    }

    final text = message?.trim() ?? '';

    return SignalHistoryRequestException(
      text.isEmpty ? 'Invalid history request (HTTP 400).' : text,
    );
  }

  static String? _firstNotEmpty(String? first, String? second) {
    final a = first?.trim() ?? '';
    if (a.isNotEmpty) return a;

    final b = second?.trim() ?? '';
    return b.isEmpty ? null : b;
  }
}

class _Target {
  final String id;
  final LatestSignalRef ref;

  const _Target(this.id, this.ref);
}

class _DeviceResponse {
  final String boxDeviceId;
  final List<_Target> targets;
  final SeriesHistoryResponse? body;
  final Object? error;
  final StackTrace? stackTrace;

  const _DeviceResponse({
    required this.boxDeviceId,
    required this.targets,
    this.body,
    this.error,
    this.stackTrace,
  });
}
