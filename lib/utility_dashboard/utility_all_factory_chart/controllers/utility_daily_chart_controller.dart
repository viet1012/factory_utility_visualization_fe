import '../../utility_catalog/models/signal_history_models.dart';
import '../models/series_history_response.dart';
import '../models/utility_daily_models.dart';
import 'series_history_chart_controller.dart';

typedef DailyBoxState = SeriesBoxState<DailySignalSeries>;

/// Lich su theo ngay (bucket=1d) cua tab Daily, thang hien tai.
///
/// from = 00:00 ngay dau thang, to = 00:00 ngay dau thang sau, hoac phut
/// hien tai khi thang chua ket thuc. Gom request nhieu box, cache, huy,
/// retry: xem [SeriesHistoryChartController]. Khong polling.
class UtilityDailyChartController
    extends SeriesHistoryChartController<DailySignalSeries> {
  UtilityDailyChartController({
    required super.repository,
    super.requestTimeout = const Duration(seconds: 90),
    super.cacheTtl = const Duration(minutes: 5),
    super.maxConcurrentRequests,
  });

  static DateTime _monthOf(DateTime now) => DateTime(now.year, now.month);

  @override
  String get bucket => '1d';

  @override
  String get windowTag {
    final month = _monthOf(DateTime.now());
    return 'month:${month.year}${month.month.toString().padLeft(2, '0')}';
  }

  @override
  String get debugLabel => 'DAILY';

  @override
  HistoryWindow windowAt(DateTime now) {
    final from = _monthOf(now);
    final next = DateTime(from.year, from.month + 1);
    final current = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );

    return HistoryWindow(
      from: from,
      to: next.isAfter(current) ? current : next,
    );
  }

  @override
  DailySignalSeries convert(
    SeriesHistorySignalDto dto,
    SeriesHistoryResponse response,
    HistoryWindow window,
  ) {
    return DailySignalSeries.fromDto(dto);
  }
}
