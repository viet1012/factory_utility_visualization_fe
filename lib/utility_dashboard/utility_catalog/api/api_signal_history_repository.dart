import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/charts/series_math.dart';
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
/// Backend da gap-fill bucket rong (count = 0) va tra kind / nguong /
/// alertLevel. Mot request cho moi boxDeviceId, loc theo plcAddress.
///
/// Dung chung cho moi luong lich su:
/// - cache LRU ([cacheCapacity] muc) theo (nhom box da sort, PLC da sort,
///   from, to, bucket); TTL do noi goi truyen. Tap PLC nam tron trong cac
///   muc con han cung (nhom box, from, to, bucket) thi ghep tu cache, chi
///   goi phan con thieu. [fetchSeriesHistory] gui ca nhom box trong mot
///   request (`boxDeviceId` CSV);
/// - request dang chay cung khoa duoc dung chung (dedupe);
/// - CancelToken cua noi goi chi huy request that khi khong con ai cho.
class ApiSignalHistoryRepository implements SignalHistoryRepository {
  static const int cacheCapacity = 100;

  final UtilityChartApi api;

  /// Cay latest hien tai: map signalId -> boxDeviceId / plcAddress / ten.
  final List<LatestFacilityDto> Function() source;

  /// Doi khi cay latest doi (LatestProvider.dataVersion): dung lai index.
  final int Function() sourceVersion;

  ApiSignalHistoryRepository({
    required this.api,
    required this.source,
    required this.sourceVersion,
  });

  Map<String, LatestSignalRef>? _index;
  int? _indexVersion;

  final LinkedHashMap<String, _CacheEntry> _cache =
      LinkedHashMap<String, _CacheEntry>();

  final Map<String, _SharedRequest> _inFlight = <String, _SharedRequest>{};

  @override
  Future<SignalHistoryResult> fetchHistory({
    required List<String> signalIds,
    required DateTime from,
    required DateTime to,
    String bucket = 'auto',
    Duration cacheTtl = SignalHistoryRepository.defaultCacheTtl,
    CancelToken? cancelToken,
  }) async {
    final index = _signalIndex();

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
          cacheTtl,
          cancelToken,
        ),
      ),
    );

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
      final parts = response.parts;

      // Device nay loi (cac device khac van OK): moi the cua no hien loi.
      if (parts == null) {
        final message = _describeError(response.error);

        for (final target in response.targets) {
          seriesById[target.id] = _errorSeries(target, message);
        }
        continue;
      }

      // Cac phan cung (from, to, bucket) nen cung cach gop / do rong bucket.
      final meta = parts.first.response;

      final responseAggregation = meta.isSnapshot
          ? HistoryAggregation.snapshot
          : HistoryAggregation.minAvgMax;

      if (responseAggregation == HistoryAggregation.snapshot) {
        aggregation = HistoryAggregation.snapshot;
      }

      final responseBucket = meta.bucketDuration;
      resultBucket ??= responseBucket;

      // Ghep theo khoa that (boxDeviceId + plcAddress), khong theo thu tu.
      final signalsByPlc = <String, (SeriesHistorySignalDto, DateTime)>{
        for (final part in parts)
          for (final signal in part.response.signals)
            if (signal.boxDeviceId.trim() == response.boxDeviceId)
              signal.plcAddress.trim(): (signal, part.requestedAt),
      };

      for (final target in response.targets) {
        final plc = target.ref.signal.plcAddress.trim();
        final match = signalsByPlc[plc];

        // Loi rieng cua signal: chi the do hien loi.
        if (match == null) {
          seriesById[target.id] = _errorSeries(
            target,
            'Not returned by the history API.',
          );
          continue;
        }

        final (dto, requestedAt) = match;

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
        'points=${ordered.fold<int>(0, (n, s) => n + s.points.length)}',
      );
    }

    return SignalHistoryResult(
      series: List<SignalHistorySeries>.unmodifiable(ordered),
      source: DataSource.api,
      aggregation: aggregation,
      bucket: resultBucket,
    );
  }

  @override
  Future<SeriesHistoryResponse> fetchSeriesHistory({
    required List<String> boxDeviceIds,
    required List<String> plcAddresses,
    required DateTime from,
    required DateTime to,
    String bucket = 'auto',
    Duration cacheTtl = SignalHistoryRepository.defaultCacheTtl,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final parts = await _loadDevice(
        boxDeviceIds: boxDeviceIds,
        plcAddresses: plcAddresses,
        from: from,
        to: to,
        bucket: bucket,
        cacheTtl: cacheTtl,
        forceRefresh: forceRefresh,
        cancelToken: cancelToken,
      );

      if (parts.length == 1) return parts.single.response;

      final meta = parts.first.response;

      return SeriesHistoryResponse(
        bucket: meta.bucket,
        source: meta.source,
        aggregation: meta.aggregation,
        signals: List<SeriesHistorySignalDto>.unmodifiable([
          for (final part in parts) ...part.response.signals,
        ]),
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapError(error), stackTrace);
    }
  }

  // ============================================================
  // DEVICE LOAD: CACHE + DEDUPE
  // ============================================================

  /// Cac phan du lieu phu [plcAddresses] cua mot nhom box: tu cache va /
  /// hoac tu request moi (chi cho phan cache con thieu).
  Future<List<_Part>> _loadDevice({
    required List<String> boxDeviceIds,
    required List<String> plcAddresses,
    required DateTime from,
    required DateTime to,
    required String bucket,
    required Duration cacheTtl,
    required bool forceRefresh,
    required CancelToken? cancelToken,
  }) async {
    final boxes =
        boxDeviceIds
            .map((box) => box.trim())
            .where((box) => box.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final box = boxes.join(',');
    final plcs =
        plcAddresses
            .map((plc) => plc.trim())
            .where((plc) => plc.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    /*
     * Lam tron xuong theo phut (giay = 0): cac lan polling trong cung mot
     * phut gui cung mot request, moc bucket on dinh giua cac lan refresh.
     */
    from = _floorMinute(from);
    to = _floorMinute(to);

    final prefix = _cachePrefix(box, from, to, bucket);
    final key = _cacheKey(prefix, plcs);

    var missing = plcs;
    final parts = <_Part>[];

    if (!forceRefresh) {
      final exact = _freshEntry(key, cacheTtl);
      if (exact != null) return [exact.part];

      if (!_inFlight.containsKey(key)) {
        final covered = _coveredFromCache(prefix, plcs, cacheTtl);

        if (covered.isNotEmpty) {
          final plcsByEntry = <_CacheEntry, Set<String>>{};
          covered.forEach((plc, entry) {
            plcsByEntry.putIfAbsent(entry, () => <String>{}).add(plc);
          });

          parts.addAll(
            plcsByEntry.entries.map((item) => item.key.part.only(item.value)),
          );

          missing = plcs
              .where((plc) => !covered.containsKey(plc))
              .toList(growable: false);

          if (missing.isEmpty) return parts;
        }
      }
    }

    // forceRefresh (polling): luon gui request moi, khong ghep vao request
    // dang chay da gui truoc do.
    final missingKey = _cacheKey(prefix, missing);
    final shared =
        (forceRefresh ? null : _inFlight[missingKey]) ??
        _start(
          key: missingKey,
          boxes: boxes,
          plcs: missing,
          from: from,
          to: to,
          bucket: bucket,
        );

    parts.add(await _join(shared, missingKey, cancelToken));
    return parts;
  }

  _CacheEntry? _freshEntry(String key, Duration ttl) {
    final entry = _cache[key];
    if (entry == null || !entry.isFresh(ttl)) return null;

    // LRU: muc vua dung chuyen ve cuoi.
    _cache
      ..remove(key)
      ..[key] = entry;

    return entry;
  }

  /// PLC -> muc cache con han cung [prefix] chua no (muc moi hon thang).
  Map<String, _CacheEntry> _coveredFromCache(
    String prefix,
    List<String> plcs,
    Duration ttl,
  ) {
    final wanted = plcs.toSet();
    final covered = <String, _CacheEntry>{};

    final entries =
        _cache.entries
            .where(
              (item) => item.key.startsWith(prefix) && item.value.isFresh(ttl),
            )
            .toList()
          ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));

    for (final MapEntry(key: key, value: entry) in entries) {
      var used = false;

      for (final plc in entry.part.plcs) {
        if (!wanted.contains(plc)) continue;
        covered[plc] = entry;
        used = true;
      }

      if (used) {
        _cache
          ..remove(key)
          ..[key] = entry;
      }
    }

    return covered;
  }

  _SharedRequest _start({
    required String key,
    required List<String> boxes,
    required List<String> plcs,
    required DateTime from,
    required DateTime to,
    required String bucket,
  }) {
    final shared = _SharedRequest(
      plcs: Set<String>.unmodifiable(plcs),
      requestedAt: DateTime.now(),
    );
    _inFlight[key] = shared;

    final watch = Stopwatch()..start();

    final box = boxes.join(',');

    if (kDebugMode) {
      debugPrint(
        '[SIGNAL HISTORY] send boxes=${boxes.length} ($box) '
        'plc=${plcs.length} from=$from to=$to bucket=$bucket',
      );
    }

    shared.future = api
        .getSeriesHistory(
          boxDeviceIds: boxes,
          plcAddresses: plcs,
          from: from,
          to: to,
          bucket: bucket,
          cancelToken: shared.token,
        )
        .then((body) {
          if (kDebugMode) {
            debugPrint(
              '[SIGNAL HISTORY] recv boxes=$box '
              'bucket=${body.bucket} source=${body.source} '
              'signals=${body.signals.length} '
              'elapsed=${watch.elapsedMilliseconds}ms',
            );
          }

          final part = _Part(
            response: body,
            plcs: shared.plcs,
            requestedAt: shared.requestedAt,
          );
          _store(key, part);
          return part;
        })
        .whenComplete(() {
          shared.done = true;
          if (identical(_inFlight[key], shared)) _inFlight.remove(key);
        });

    return shared;
  }

  /// Cho ket qua cua [shared]. Huy [cancelToken] chi bo luot cho nay; request
  /// that bi huy khi khong con ai cho.
  Future<_Part> _join(
    _SharedRequest shared,
    String key,
    CancelToken? cancelToken,
  ) {
    final cancelled = cancelToken?.cancelError;
    if (cancelled != null) return Future<_Part>.error(cancelled);

    shared.waiters++;

    final completer = Completer<_Part>();
    var settled = false;

    shared.future.then(
      (part) {
        if (settled) return;
        settled = true;
        shared.waiters--;
        completer.complete(part);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (settled) return;
        settled = true;
        shared.waiters--;
        completer.completeError(error, stackTrace);
      },
    );

    cancelToken?.whenCancel.then((error) {
      if (settled) return;
      settled = true;
      shared.waiters--;

      if (shared.waiters == 0 && !shared.done) {
        if (identical(_inFlight[key], shared)) _inFlight.remove(key);
        final token = shared.token;
        if (!token.isCancelled) token.cancel('no remaining waiters');
      }

      completer.completeError(error);
    });

    return completer.future;
  }

  void _store(String key, _Part part) {
    _cache
      ..remove(key)
      ..[key] = _CacheEntry(part: part, fetchedAt: DateTime.now());

    while (_cache.length > cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  static String _cachePrefix(
    String box,
    DateTime from,
    DateTime to,
    String bucket,
  ) {
    return '$box|${from.toIso8601String()}|${to.toIso8601String()}|$bucket|';
  }

  /// [plcs] da sort.
  static String _cacheKey(String prefix, List<String> plcs) {
    return '$prefix${plcs.join(',')}';
  }

  // ============================================================
  // SIGNAL INDEX
  // ============================================================

  Map<String, LatestSignalRef> _signalIndex() {
    final version = sourceVersion();
    final cached = _index;

    if (cached != null && version == _indexVersion) return cached;

    final index = indexLatestSignals(source());
    _index = index;
    _indexVersion = version;

    return index;
  }

  // ============================================================
  // MAPPING
  // ============================================================

  Future<_DeviceResponse> _fetchDevice(
    String boxDeviceId,
    List<_Target> targets,
    DateTime from,
    DateTime to,
    String bucket,
    Duration cacheTtl,
    CancelToken? cancelToken,
  ) async {
    try {
      final parts = await _loadDevice(
        boxDeviceIds: [boxDeviceId],
        plcAddresses: [
          for (final target in targets) target.ref.signal.plcAddress,
        ],
        from: from,
        to: to,
        bucket: bucket,
        cacheTtl: cacheTtl,
        forceRefresh: false,
        cancelToken: cancelToken,
      );

      return _DeviceResponse(
        boxDeviceId: boxDeviceId,
        targets: targets,
        parts: parts,
      );
    } catch (error, stackTrace) {
      final cancelled = error is DioException && CancelToken.isCancel(error);

      if (!cancelled || kDebugMode) {
        debugPrint(
          '[SIGNAL HISTORY ${cancelled ? 'CANCELLED' : 'API ERROR'}] '
          'boxDeviceId=$boxDeviceId '
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
    SeriesHistorySignalDto dto,
    HistoryAggregation aggregation,
    Duration? bucket,
    DateTime requestedAt,
  ) {
    final signal = target.ref.signal;

    // Ten / code / unit uu tien tu cay latest de khop voi bang.
    final unit = _firstNotEmpty(signal.unit, dto.unit);
    final code = _firstNotEmpty(signal.cateId, dto.code);
    final name = _firstNotEmpty(signal.nameEn, dto.name) ?? code ?? '--';

    // Bucket chua du thoi gian luc gui request ma chua co mau: bo.
    final points = dropIncompleteEmptyBuckets(
      dto.points,
      bucket: bucket ?? inferBucketStep(dto.points.map((point) => point.ts)),
      reference: requestedAt,
    );

    return SignalHistorySeries(
      signalId: target.id,
      plc: signal.plcAddress.trim(),
      name: name,
      code: code,
      unit: unit,
      kind: parseSignalKind(dto.kind),
      thresholdLow: dto.thresholdLow,
      thresholdHigh: dto.thresholdHigh,
      alertLevel: dto.alertLevel,
      thresholds: dto.thresholds,
      breachCount: dto.breachCount,
      lastBreachAt: dto.lastBreachAt,
      aggregation: aggregation,
      bucket: bucket,
      points: List<SignalHistoryPoint>.unmodifiable(points.map(_toPoint)),
    );
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

/// Mot phan du lieu cua box: response cho [plcs] (tap PLC da yeu cau) va
/// thoi diem gui request (de bo bucket chua du thoi gian).
class _Part {
  final SeriesHistoryResponse response;
  final Set<String> plcs;
  final DateTime requestedAt;

  const _Part({
    required this.response,
    required this.plcs,
    required this.requestedAt,
  });

  /// Chi giu cac signal thuoc [keep].
  _Part only(Set<String> keep) {
    if (keep.length == plcs.length && keep.containsAll(plcs)) return this;

    // So PLC khong phan biet hoa thuong (response co the khac chu voi request).
    final keepKeys = {for (final plc in keep) plc.trim().toUpperCase()};

    return _Part(
      response: SeriesHistoryResponse(
        bucket: response.bucket,
        source: response.source,
        aggregation: response.aggregation,
        signals: List<SeriesHistorySignalDto>.unmodifiable(
          response.signals.where(
            (signal) =>
                keepKeys.contains(signal.plcAddress.trim().toUpperCase()),
          ),
        ),
      ),
      plcs: keep,
      requestedAt: requestedAt,
    );
  }
}

class _CacheEntry {
  final _Part part;
  final DateTime fetchedAt;

  const _CacheEntry({required this.part, required this.fetchedAt});

  bool isFresh(Duration ttl) => DateTime.now().difference(fetchedAt) <= ttl;
}

/// Request dang chay, dung chung cho moi noi goi cung khoa.
class _SharedRequest {
  final Set<String> plcs;
  final DateTime requestedAt;
  final CancelToken token = CancelToken();

  late final Future<_Part> future;

  int waiters = 0;
  bool done = false;

  _SharedRequest({required this.plcs, required this.requestedAt});
}

class _DeviceResponse {
  final String boxDeviceId;
  final List<_Target> targets;
  final List<_Part>? parts;
  final Object? error;
  final StackTrace? stackTrace;

  const _DeviceResponse({
    required this.boxDeviceId,
    required this.targets,
    this.parts,
    this.error,
    this.stackTrace,
  });
}
