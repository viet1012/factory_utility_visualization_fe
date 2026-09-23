import '../models/signal_health_history_models.dart';

/// Aggregation helpers for the Signal Health History panel.
///
/// All chart/card maths lives here rather than in the screen or the widgets, so
/// `SignalHealthMatrixScreen` stays orchestration-only and each aggregation is
/// independently testable.

/// What every HISTORY count actually measures.
///
/// Stated once here and reused in card help text, chart subtitles and
/// tooltips, so the page never implies these are unique devices or signals.
const String kHistoryCountMeaning =
    'Counts triggered alert evaluations, not unique devices.';

/// Subtitle for the hourly trend chart.
const String kHistoryTrendSubtitle = 'Alert occurrences per hour by level';

/// Longer explanation of the trend chart, shown as an info tooltip.
///
/// A device contributes more than one alert when several of its signals or
/// rules trigger in the same hour, so these totals exceed a device headcount.
const String kHistoryTrendHelp =
    'For each hour, the number of alert evaluations that triggered at each '
    'level. A single device can contribute several alerts when multiple '
    'signals or rules trigger. These are occurrences - not unique devices, '
    'signals or descriptions.';

/// One point on the hourly trend chart.
typedef HistoryTrendPoint = ({
  DateTime bucketTime,
  int level1,
  int level2,
  int level3,
  int total,
});

/// One bar on the "top alert descriptions" chart.
///
/// [key] is the parameterCode+ruleType+description identity; [label] is what
/// the axis shows.
typedef HistoryDescriptionStat = ({
  String key,
  String label,
  String parameterCode,
  String ruleType,
  int alertCount,
  int deviceCount,
});

/// One bar on the "top box devices" chart.
typedef HistoryDeviceStat = ({
  String boxDeviceId,
  int alertCount,
  int descriptionCount,
});

/// Per-level totals backing the three level cards.
typedef HistoryLevelTotals = ({
  int level1,
  int level2,
  int level3,
  int unknown,
  int total,
});

/// Totals per severity across every bucket in the range.
HistoryLevelTotals buildLevelTotals(List<SignalHealthHistoryBucket> buckets) {
  var level1 = 0;
  var level2 = 0;
  var level3 = 0;
  var unknown = 0;

  for (final bucket in buckets) {
    for (final alert in bucket.alerts) {
      switch (alert.level) {
        case SignalHealthAlertLevel.level1:
          level1 += alert.count;
        case SignalHealthAlertLevel.level2:
          level2 += alert.count;
        case SignalHealthAlertLevel.level3:
          level3 += alert.count;
        case SignalHealthAlertLevel.unknown:
          unknown += alert.count;
      }
    }
  }

  return (
    level1: level1,
    level2: level2,
    level3: level3,
    unknown: unknown,
    total: level1 + level2 + level3 + unknown,
  );
}

/// Everything a level card needs to summarise one severity at a glance.
///
/// [series] is the per-hour count list backing the sparkline and [times] holds
/// the matching bucket timestamps, index-for-index, so a sparkline point can
/// name its own hour. [peakValue] and [peakTime] describe the highest bucket.
///
/// Purely numeric: no trend classification, so the card states measured values
/// rather than an interpretation of them.
typedef HistoryLevelTrend = ({
  List<int> series,
  List<DateTime> times,
  int total,
  double averagePerHour,
  int peakValue,
  DateTime? peakTime,
});

/// Per-hour counts for one level, in bucket order. Backs the card sparkline.
List<int> buildLevelSparkline(
  List<SignalHealthHistoryBucket> buckets,
  SignalHealthAlertLevel level,
) {
  final result = buckets
      .map((bucket) => bucket.countFor(level))
      .toList(growable: false);

  return List<int>.unmodifiable(result);
}

/// Sparkline series, total, hourly average and peak for one level.
///
/// Uses the same [buckets] as the main Hourly Alert Trend chart, so the card
/// and the chart always describe the same time range.
HistoryLevelTrend buildLevelTrend(
  List<SignalHealthHistoryBucket> buckets,
  SignalHealthAlertLevel level,
) {
  final series = buildLevelSparkline(buckets, level);

  var total = 0;
  var peakValue = 0;
  DateTime? peakTime;

  for (var index = 0; index < series.length; index++) {
    final value = series[index];

    total += value;

    // Strictly greater: on ties the EARLIEST peak wins, so the reported time
    // is stable between rebuilds.
    if (value > peakValue) {
      peakValue = value;
      peakTime = buckets[index].bucketTime;
    }
  }

  /*
   * averagePerHour = tong alert cua level / SO BUCKET GIO tra ve.
   *
   * Mau so la so bucket, khong phai so gio giua from va to: backend co the
   * bo qua gio khong co du lieu, va chia cho mot khoang gio dai hon so bucket
   * thuc te se lam trung binh thap di mot cach sai lech.
   */
  final averagePerHour = series.isEmpty ? 0.0 : total / series.length;

  /*
   * times[i] luon tuong ung series[i]: cung mot list buckets, cung thu tu,
   * khong loc bo bucket nao. Bucket khong co alert van giu cho voi gia tri 0
   * (countFor tra ve 0), nen truc thoi gian khong bi co lai.
   */
  final times = List<DateTime>.unmodifiable(
    buckets.map((bucket) => bucket.bucketTime),
  );

  final result = (
    series: series,
    times: times,
    total: total,
    averagePerHour: averagePerHour,
    peakValue: peakValue,
    peakTime: peakTime,
  );

  assert(() {
    return _debugAssertLevelTrendConsistent(result, level);
  }());

  return result;
}

/// Debug-only reconciliation between the sparkline series and the card
/// figures. Compiled out of release builds by the enclosing `assert`.
///
/// Catches the failure that matters most here: a sparkline that stops
/// describing the same data as the total / average / peak beside it.
bool _debugAssertLevelTrendConsistent(
  HistoryLevelTrend trend,
  SignalHealthAlertLevel level,
) {
  final seriesSum = trend.series.fold<int>(0, (sum, value) => sum + value);

  if (seriesSum != trend.total) {
    throw StateError(
      'Sparkline sum ($seriesSum) != card total (${trend.total}) '
      'for ${level.label}.',
    );
  }

  final seriesMax = trend.series.isEmpty
      ? 0
      : trend.series.reduce((a, b) => a > b ? a : b);

  if (seriesMax != trend.peakValue) {
    throw StateError(
      'Sparkline max ($seriesMax) != displayed peak (${trend.peakValue}) '
      'for ${level.label}.',
    );
  }

  if (trend.times.length != trend.series.length) {
    throw StateError(
      'Sparkline has ${trend.series.length} points but '
      '${trend.times.length} timestamps for ${level.label}.',
    );
  }

  return true;
}

/// Buckets whose `errorCount` disagrees with the sum of their level counts.
///
/// Surfaced as a non-blocking notice so a backend drift is visible rather than
/// silently skewing the charts.
List<SignalHealthHistoryBucket> findInconsistentBuckets(
  List<SignalHealthHistoryBucket> buckets,
) {
  final result = buckets
      .where((bucket) => !bucket.hasConsistentErrorCount)
      .toList(growable: false);

  return List<SignalHealthHistoryBucket>.unmodifiable(result);
}

/// Chronological per-hour series for the trend chart.
///
/// Buckets are already sorted by the API layer; this only projects them, so the
/// chart's X axis stays in backend bucket order.
List<HistoryTrendPoint> buildTrendSeries(
  List<SignalHealthHistoryBucket> buckets,
) {
  final result = buckets
      .map((bucket) {
        final level1 = bucket.countFor(SignalHealthAlertLevel.level1);
        final level2 = bucket.countFor(SignalHealthAlertLevel.level2);
        final level3 = bucket.countFor(SignalHealthAlertLevel.level3);

        return (
          bucketTime: bucket.bucketTime,
          level1: level1,
          level2: level2,
          level3: level3,
          total: bucket.totalAlerts,
        );
      })
      .toList(growable: false);

  return List<HistoryTrendPoint>.unmodifiable(result);
}

/// Top alert descriptions, summed over the whole selected range.
///
/// Grouped by parameterCode + ruleType + description, never description text
/// alone. [levelFilter] narrows to a single severity when a level card is
/// selected; [limit] caps the bars so the chart stays readable.
List<HistoryDescriptionStat> buildTopDescriptions(
  List<SignalHealthHistoryBucket> buckets, {
  SignalHealthAlertLevel? levelFilter,
  int limit = 8,
}) {
  final counts = <String, int>{};
  final labels = <String, String>{};
  final parameterCodes = <String, String>{};
  final ruleTypes = <String, String>{};
  final devices = <String, Set<String>>{};

  for (final bucket in buckets) {
    for (final alert in bucket.alerts) {
      if (levelFilter != null && alert.level != levelFilter) continue;

      for (final description in alert.descriptions) {
        final key = description.groupKey;

        counts[key] = (counts[key] ?? 0) + description.count;

        labels.putIfAbsent(key, () => description.displayLabel);
        parameterCodes.putIfAbsent(key, () => description.parameterCode);
        ruleTypes.putIfAbsent(key, () => description.ruleType);

        final seen = devices.putIfAbsent(key, () => <String>{});

        for (final device in description.devices) {
          if (device.boxDeviceId.isNotEmpty) seen.add(device.boxDeviceId);
        }
      }
    }
  }

  final result =
      counts.entries
          .map(
            (entry) => (
              key: entry.key,
              label: labels[entry.key] ?? '-',
              parameterCode: parameterCodes[entry.key] ?? '',
              ruleType: ruleTypes[entry.key] ?? '',
              alertCount: entry.value,
              deviceCount: devices[entry.key]?.length ?? 0,
            ),
          )
          .toList()
        ..sort(
          _compareByAlertCount((item) => item.alertCount, (item) => item.label),
        );

  return _take(result, limit);
}

/// Top box devices, summed over the whole selected range.
///
/// Device `count` is scoped to its parent description, so adding a device's
/// counts across descriptions and buckets yields its range-wide total without
/// double-counting.
///
/// [levelFilter] narrows to one severity; [descriptionKey] narrows to a single
/// selected description so the chart shows only the affected devices.
List<HistoryDeviceStat> buildTopDevices(
  List<SignalHealthHistoryBucket> buckets, {
  SignalHealthAlertLevel? levelFilter,
  String? descriptionKey,
  int limit = 8,
}) {
  final counts = <String, int>{};
  final descriptions = <String, Set<String>>{};

  for (final bucket in buckets) {
    for (final alert in bucket.alerts) {
      if (levelFilter != null && alert.level != levelFilter) continue;

      for (final description in alert.descriptions) {
        if (descriptionKey != null && description.groupKey != descriptionKey) {
          continue;
        }

        for (final device in description.devices) {
          final key = device.boxDeviceId.trim();
          if (key.isEmpty) continue;

          counts[key] = (counts[key] ?? 0) + device.count;

          descriptions
              .putIfAbsent(key, () => <String>{})
              .add(description.groupKey);
        }
      }
    }
  }

  final result =
      counts.entries
          .map(
            (entry) => (
              boxDeviceId: entry.key,
              alertCount: entry.value,
              descriptionCount: descriptions[entry.key]?.length ?? 0,
            ),
          )
          .toList()
        ..sort(
          _compareByAlertCount(
            (item) => item.alertCount,
            (item) => item.boxDeviceId,
          ),
        );

  return _take(result, limit);
}

/// Flattens every signal for [boxDeviceId] across the range, newest first.
///
/// Honours the same [levelFilter]/[descriptionKey] narrowing as the charts, so
/// the drill-down always reflects what the user actually selected.
List<SignalHealthHistorySignal> collectSignalsForDevice(
  List<SignalHealthHistoryBucket> buckets,
  String boxDeviceId, {
  SignalHealthAlertLevel? levelFilter,
  String? descriptionKey,
}) {
  final target = boxDeviceId.trim();

  if (target.isEmpty) return const [];

  final result = <SignalHealthHistorySignal>[];

  for (final bucket in buckets) {
    for (final alert in bucket.alerts) {
      if (levelFilter != null && alert.level != levelFilter) continue;

      for (final description in alert.descriptions) {
        if (descriptionKey != null && description.groupKey != descriptionKey) {
          continue;
        }

        for (final device in description.devices) {
          if (device.boxDeviceId.trim() != target) continue;

          result.addAll(device.signals);
        }
      }
    }
  }

  result.sort((a, b) {
    final first = a.recordedAt;
    final second = b.recordedAt;

    // Signals with no timestamp sink to the bottom rather than reordering
    // randomly between rebuilds.
    if (first == null && second == null) {
      return a.plcAddress.compareTo(b.plcAddress);
    }

    if (first == null) return 1;
    if (second == null) return -1;

    return second.compareTo(first);
  });

  return List<SignalHealthHistorySignal>.unmodifiable(result);
}

/// Distinct devices in the range, for the drill-down picker.
List<String> collectDeviceIds(List<SignalHealthHistoryBucket> buckets) {
  final values = <String>{};

  for (final bucket in buckets) {
    for (final alert in bucket.alerts) {
      for (final description in alert.descriptions) {
        for (final device in description.devices) {
          final id = device.boxDeviceId.trim();
          if (id.isNotEmpty) values.add(id);
        }
      }
    }
  }

  final result = values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return List<String>.unmodifiable(result);
}

/// Formats a register reading for the drill-down table.
///
/// Whole numbers print without decimals; everything else to 2 places. Null
/// renders as `-` so a missing currentValue/previousValue is visibly absent
/// rather than shown as 0.
String formatSignalValue(double? value) {
  if (value == null) return '-';

  if (value == value.roundToDouble() && value.abs() < 1e12) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(2);
}

/// Formats a delta with an explicit sign, so a rise reads `+12` not `12`.
String formatSignalDelta(double? delta) {
  if (delta == null) return '-';

  if (delta == 0) return '0';

  final text = formatSignalValue(delta.abs());

  return delta > 0 ? '+$text' : '-$text';
}

/// Label describing the selected range, used as the chart subtitles so the
/// description/device bars are read as range totals rather than per-hour.
String formatRangeLabel(DateTime from, DateTime to) {
  return '${formatFilterDateTime(from)} - ${formatFilterDateTime(to)}';
}

/// True when every bucket falls on the same calendar day.
///
/// Drives axis labelling: a single-day range only needs `HH:mm`, while a
/// multi-day range must make the date change visible.
bool isSingleDayRange(List<SignalHealthHistoryBucket> buckets) {
  if (buckets.length < 2) return true;

  final first = buckets.first.bucketTime.toLocal();
  final last = buckets.last.bucketTime.toLocal();

  return first.year == last.year &&
      first.month == last.month &&
      first.day == last.day;
}

/// Two-line axis label for a multi-day range.
///
/// Renders `dd/MM` above `HH:mm` only on the first bucket of each day (and at
/// midnight), so the date change is obvious without repeating it on every
/// tick. All other ticks show `HH:mm` alone.
String formatTrendAxisLabel(DateTime value, {required bool singleDay}) {
  final local = value.toLocal();

  final time = '${_two(local.hour)}:${_two(local.minute)}';

  if (singleDay) return time;

  // Midnight starts a new calendar day: always stamp it with the date.
  if (local.hour == 0) {
    return '${_two(local.day)}/${_two(local.month)}\n$time';
  }

  return time;
}

/// Full local datetime for tooltips: `dd/MM/yyyy HH:mm`.
String formatFullDateTime(DateTime value) {
  final local = value.toLocal();

  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// Caption shown directly above the level-card sparkline.
const String kHistorySparklineLabel = 'Alerts by hour';

/// Two-line sparkline tooltip: `dd/MM/yyyy HH:mm` then `<count> alerts`.
String formatSparklinePointTooltip(DateTime bucketTime, int value) {
  return '${formatFullDateTime(bucketTime)}\n$value alerts';
}

/// `Avg/hour: 19.0` - average alert occurrences per hourly bucket.
///
/// One decimal place: enough to distinguish 0.4 from 1.2 without implying
/// precision the counts do not have.
String formatAveragePerHour(double average) {
  return 'Avg/hour: ${average.toStringAsFixed(1)}';
}

/// `Peak: 23 alerts • 23/09 04:00`, or a dash when the level had no alerts.
///
/// Says "alerts" explicitly so the number is not read as devices or signals,
/// and always carries the date: a bare `HH:mm` is ambiguous whenever the
/// selected range spans more than one day. The full year stays in the tooltip
/// so the card metric row remains compact.
String formatPeakMetric(int peakValue, DateTime? peakTime) {
  if (peakValue <= 0 || peakTime == null) return 'Peak: -';

  return 'Peak: $peakValue alerts • ${formatBucketDateHour(peakTime)}';
}

/// Full peak datetime for the card tooltip.
///
/// The visible metric shows only `HH:mm`, which is ambiguous when the range
/// spans several dates, so the tooltip carries `dd/MM/yyyy HH:mm`.
String formatPeakTooltipLine(int peakValue, DateTime? peakTime) {
  if (peakValue <= 0 || peakTime == null) {
    return 'Peak: no alerts in this period.';
  }

  return 'Peak: $peakValue alerts at ${formatFullDateTime(peakTime)}.';
}

/// `HH:mm` label used on the trend axis.
String formatBucketHour(DateTime value) {
  final local = value.toLocal();

  return '${_two(local.hour)}:${_two(local.minute)}';
}

/// `dd/MM HH:mm` label for tooltips and the detail table.
String formatBucketDateHour(DateTime value) {
  final local = value.toLocal();

  return '${_two(local.day)}/${_two(local.month)} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// `dd/MM/yyyy HH:mm` label used by the filter bar.
String formatFilterDateTime(DateTime value) {
  final local = value.toLocal();

  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Descending by count, then ascending by label so equal counts keep a stable
/// order between rebuilds instead of shuffling.
int Function(T, T) _compareByAlertCount<T>(
  int Function(T) count,
  String Function(T) label,
) {
  return (T a, T b) {
    final countCompare = count(b).compareTo(count(a));

    if (countCompare != 0) return countCompare;

    return label(a).toLowerCase().compareTo(label(b).toLowerCase());
  };
}

List<T> _take<T>(List<T> source, int limit) {
  if (limit <= 0 || source.length <= limit) {
    return List<T>.unmodifiable(source);
  }

  return List<T>.unmodifiable(source.sublist(0, limit));
}
