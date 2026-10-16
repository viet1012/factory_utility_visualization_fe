import '../../utility_catalog/models/signal_history_models.dart';
import '../models/series_history_response.dart';
import '../models/utility_minute_models.dart';
import 'series_history_chart_controller.dart';

typedef MinuteBoxState = SeriesBoxState<MinuteSignalSeries>;

/// Lich su theo phut (bucket=1m) cua tab Minutes.
///
/// Cua so [window] ket thuc o phut hien tai (lam tron xuong). Moi lan poll
/// (1 phut) tai lai ca cua so cho moi box dang hien thi, gom nhieu box mot
/// request: xem [SeriesHistoryChartController].
class UtilityMinuteChartController
    extends SeriesHistoryChartController<MinuteSignalSeries> {
  /// Khoang du lieu tren bieu do.
  final Duration window;

  UtilityMinuteChartController({
    required super.repository,
    this.window = const Duration(minutes: 60),
    super.requestTimeout,
    super.cacheTtl,
    super.maxConcurrentRequests,
  });

  @override
  String get bucket => '1m';

  @override
  String get windowTag => 'last${window.inMinutes}m';

  @override
  String get debugLabel => 'MINUTE';

  @override
  DateTime? lastSampleAt(MinuteSignalSeries series) => series.latest?.ts;

  @override
  Duration get sampleBucket => kMinuteBucket;

  /// Mau cuoi cu hon 5 phut: DEVICE_STALE / FEED_DELAYED.
  @override
  Duration? get staleAfter => const Duration(minutes: 5);

  @override
  HistoryWindow windowAt(DateTime now) {
    final to = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return HistoryWindow(from: to.subtract(window), to: to);
  }

  @override
  MinuteSignalSeries convert(
    SeriesHistorySignalDto dto,
    SeriesHistoryResponse response,
    HistoryWindow window,
  ) {
    return MinuteSignalSeries.fromDto(dto, windowTo: window.to);
  }
}
