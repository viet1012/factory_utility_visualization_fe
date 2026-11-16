import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Timeout + lich retry cua MOT endpoint. So lan retry toi da =
/// `backoff.length`. Chinh tai day (vd sau khi BE co warm-up).
class RequestPolicy {
  final Duration timeout;
  final List<Duration> backoff;

  const RequestPolicy({required this.timeout, required this.backoff});

  int get maxRetries => backoff.length;

  /// GET /api/utility/monthly-summary: 30s, retry 2 lan (1s -> 3s).
  static const RequestPolicy monthlySummary = RequestPolicy(
    timeout: Duration(seconds: 30),
    backoff: [Duration(seconds: 1), Duration(seconds: 3)],
  );

  /// POST /api/utility/monthly-summary/refresh: BE tinh lai toan bo.
  static const RequestPolicy monthlySummaryRefresh = RequestPolicy(
    timeout: Duration(seconds: 120),
    backoff: [Duration(seconds: 1), Duration(seconds: 3)],
  );

  /// GET /api/utility/energy-daily: 30s, retry 2 lan (1s -> 3s).
  static const RequestPolicy energyDaily = RequestPolicy(
    timeout: Duration(seconds: 30),
    backoff: [Duration(seconds: 1), Duration(seconds: 3)],
  );

  /// GET /api/solar/monthly: 30s, retry 2 lan (1s -> 3s).
  static const RequestPolicy solarMonthly = RequestPolicy(
    timeout: Duration(seconds: 30),
    backoff: [Duration(seconds: 1), Duration(seconds: 3)],
  );
}

/// Muc uu tien khi xep hang qua [RequestGate].
enum RequestPriority {
  /// monthly-summary cua FAC dang chon (panel SUMMARY).
  high,

  /// O FAC A/B/C, solar, daily.
  normal,
}

/// Gioi han so request song song: toi da [maxConcurrent], trong do request
/// [RequestPriority.normal] chi duoc chiem toi da [maxNormal] cho -> luon con
/// cho cho request [RequestPriority.high]. Hang doi: high truoc, roi normal.
class RequestGate {
  RequestGate({this.maxConcurrent = 3, this.maxNormal = 2})
    : assert(maxNormal < maxConcurrent);

  /// Dung chung cho cac endpoint tong hop cua Overview.
  static final RequestGate overview = RequestGate();

  final int maxConcurrent;
  final int maxNormal;

  int _running = 0;
  int _runningNormal = 0;

  final Queue<_Waiter> _high = Queue<_Waiter>();
  final Queue<_Waiter> _normal = Queue<_Waiter>();

  /// Cho den luot; goi ham tra ve dung MOT lan de nha cho.
  Future<void Function()> acquire(RequestPriority priority) {
    final waiter = _Waiter(priority);
    (priority == RequestPriority.high ? _high : _normal).add(waiter);
    _pump();
    return waiter.completer.future;
  }

  bool _canStart(RequestPriority priority) {
    if (_running >= maxConcurrent) return false;
    return priority == RequestPriority.high || _runningNormal < maxNormal;
  }

  void _pump() {
    while (true) {
      final _Waiter? next;
      if (_high.isNotEmpty && _canStart(RequestPriority.high)) {
        next = _high.removeFirst();
      } else if (_normal.isNotEmpty && _canStart(RequestPriority.normal)) {
        next = _normal.removeFirst();
      } else {
        return;
      }

      _running++;
      final isNormal = next.priority == RequestPriority.normal;
      if (isNormal) _runningNormal++;

      var released = false;
      next.completer.complete(() {
        if (released) return;
        released = true;
        _running--;
        if (isNormal) _runningNormal--;
        _pump();
      });
    }
  }
}

class _Waiter {
  _Waiter(this.priority);

  final RequestPriority priority;
  final Completer<void Function()> completer = Completer<void Function()>();
}

/// Chay request voi timeout + retry tu dong:
/// - moi lan thu co CancelToken rieng, qua [timeout] thi huy that su request
///   (khong de request treo) va nem [TimeoutException];
/// - loi timeout / 5xx / mat mang -> thu lai theo [RequestPolicy] cua
///   endpoint; loi 4xx / parse -> nem ngay;
/// - [gate]: xin cho truoc moi lan thu, nha cho trong luc cho backoff.
///
/// Moi lan thu that bai deu log ra console (tag, loai loi, status) de chan
/// doan loi lan dau.
abstract final class RequestRetry {
  static Future<T> run<T>(
    Future<T> Function(CancelToken cancelToken) request, {
    required String tag,
    required RequestPolicy policy,
    RequestGate? gate,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    final timeout = policy.timeout;
    final backoff = policy.backoff;
    final attempts = policy.maxRetries + 1;

    for (var attempt = 1; ; attempt++) {
      final release = gate == null ? null : await gate.acquire(priority);
      final stopwatch = Stopwatch()..start();

      try {
        return await _attempt(request, timeout);
      } catch (error) {
        final retryable = isRetryable(error);
        final canRetry = retryable && attempt < attempts;

        debugPrint(
          '[RETRY $tag] attempt $attempt/$attempts failed after '
          '${stopwatch.elapsedMilliseconds} ms: ${describe(error)}'
          '${canRetry ? ' -> retry in ${backoff[attempt - 1].inSeconds}s' : ''}',
        );

        if (!canRetry) rethrow;
      } finally {
        release?.call();
      }

      await Future<void>.delayed(backoff[attempt - 1]);
    }
  }

  static Future<T> _attempt<T>(
    Future<T> Function(CancelToken cancelToken) request,
    Duration timeout,
  ) async {
    final cancelToken = CancelToken();
    var timedOut = false;

    final timer = Timer(timeout, () {
      timedOut = true;
      cancelToken.cancel('timeout after ${timeout.inSeconds}s');
    });

    try {
      return await request(cancelToken);
    } on DioException catch (error) {
      if (timedOut && error.type == DioExceptionType.cancel) {
        throw TimeoutException('Request timed out', timeout);
      }
      rethrow;
    } finally {
      timer.cancel();
    }
  }

  /// timeout / mat mang / 5xx: thu lai. 4xx, huy chu dong, parse: khong.
  static bool isRetryable(Object error) {
    if (error is TimeoutException) return true;
    if (error is! DioException) return false;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        return status >= 500;
      case DioExceptionType.unknown:
        // Web: XHR loi mang (khong co response) thuong la unknown.
        return error.response == null;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }

  /// `TimeoutException (30s)` / `DioException.receiveTimeout` /
  /// `DioException.badResponse 504` ... de doc log.
  static String describe(Object error) {
    if (error is TimeoutException) {
      return 'TimeoutException (${error.duration?.inSeconds ?? '?'}s)';
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      return 'DioException.${error.type.name}'
          '${status == null ? '' : ' $status'}'
          '${error.message == null ? '' : ' - ${error.message}'}';
    }
    return '${error.runtimeType}: $error';
  }
}
