import 'package:dio/dio.dart';

import '../../utility_all_factory_chart/models/series_history_response.dart';
import '../models/signal_history_models.dart';

/// Nguon du lieu lich su signal (`GET /api/utility/series/history`) dung
/// chung cho chart device, sparkline, Filter chart va tab Hourly.
///
/// UI chi phu thuoc vao interface nay. Ban dang dung duoc tao mot lan o
/// UtilityDashboardScreen (cache + dedupe dung chung moi noi goi).
abstract class SignalHistoryRepository {
  /// Thoi gian mot ket qua trong cache con duoc dung lai neu noi goi khong
  /// truyen [cacheTtl] rieng.
  static const Duration defaultCacheTtl = Duration(seconds: 60);

  /// Tra ve mot series cho moi id, cung thu tu voi [signalIds].
  /// Id khong ton tai bi bo qua. [cancelToken] bi huy khi nguoi dung doi
  /// range / device hoac khi timeout. [bucket] la tham so bucket cua API
  /// ('auto' hoac do rong co dinh nhu '1h').
  Future<SignalHistoryResult> fetchHistory({
    required List<String> signalIds,
    required DateTime from,
    required DateTime to,
    String bucket = 'auto',
    Duration cacheTtl = defaultCacheTtl,
    CancelToken? cancelToken,
  });

  /// Response tho cua mot box device cho [plcAddresses].
  ///
  /// [forceRefresh] bo qua cache (van dung chung request dang chay cung
  /// khoa). Loi 400 duoc doi thanh [SignalHistoryRequestException].
  Future<SeriesHistoryResponse> fetchDeviceHistory({
    required String boxDeviceId,
    required List<String> plcAddresses,
    required DateTime from,
    required DateTime to,
    String bucket = 'auto',
    Duration cacheTtl = defaultCacheTtl,
    bool forceRefresh = false,
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
