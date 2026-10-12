import 'package:dio/dio.dart';

import '../models/signal_history_models.dart';

/// Nguon du lieu lich su signal cho che do Chart.
///
/// UI chi phu thuoc vao interface nay. Repository dang dung duoc chon o
/// `signalHistoryRepositoryProvider` (providers/signal_history_providers.dart).
abstract class SignalHistoryRepository {
  /// Tra ve mot series cho moi id, cung thu tu voi [signalIds].
  /// Id khong ton tai bi bo qua. [cancelToken] bi huy khi nguoi dung doi
  /// range / device hoac khi timeout. [bucket] la tham so bucket cua API
  /// ('auto' hoac do rong co dinh nhu '1h').
  Future<SignalHistoryResult> fetchHistory({
    required List<String> signalIds,
    required DateTime from,
    required DateTime to,
    String bucket = 'auto',
    CancelToken? cancelToken,
  });
}

/// Backend tu choi request (HTTP 400). [message] la thong bao cua backend,
/// hien thang trong error state cua chart.
class SignalHistoryRequestException implements Exception {
  final String message;

  const SignalHistoryRequestException(this.message);

  @override
  String toString() => 'SignalHistoryRequestException: $message';
}
