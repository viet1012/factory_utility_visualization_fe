import '../../utility_catalog/models/signal_history_models.dart';
import '../models/series_history_response.dart';
import '../models/utility_hourly_models.dart';
import 'series_history_chart_controller.dart';

/// Du lieu cua mot box o tab Hourly; [SeriesBoxData.tag] = ten range.
typedef HourlyBoxData = SeriesBoxData<HourlySignalSeries>;
typedef HourlyBoxState = SeriesBoxState<HourlySignalSeries>;

extension HourlyBoxDataRange on HourlyBoxData {
  UtilityHourlyRange get range => UtilityHourlyRange.values.byName(tag);
}

/// Lich su theo gio (bucket=1h) cua tab Hourly; range Today / 24h / 7d.
///
/// Gom request nhieu box, cache, huy, retry: xem
/// [SeriesHistoryChartController]. Polling 5 phut ([poll]).
class UtilityHourlyChartController
    extends SeriesHistoryChartController<HourlySignalSeries> {
  UtilityHourlyChartController({
    required super.repository,
    super.requestTimeout,
    super.cacheTtl,
    super.maxConcurrentRequests,
  });

  UtilityHourlyRange _range = UtilityHourlyRange.today;

  UtilityHourlyRange get range => _range;

  /// Chi doi state; tab se goi [load] khi thay signature doi.
  void changeRange(UtilityHourlyRange range) {
    if (_range == range) return;

    _range = range;
    safeNotify();
  }

  @override
  String get bucket => '1h';

  @override
  String get windowTag => _range.name;

  @override
  String get debugLabel => 'HOURLY';

  @override
  HistoryWindow windowAt(DateTime now) => _range.windowAt(now);

  @override
  HourlySignalSeries convert(
    SeriesHistorySignalDto dto,
    SeriesHistoryResponse response,
    HistoryWindow window,
  ) {
    return HourlySignalSeries.fromDto(
      dto,
      isSnapshot: response.isSnapshot,
      windowTo: window.to,
    );
  }
}
