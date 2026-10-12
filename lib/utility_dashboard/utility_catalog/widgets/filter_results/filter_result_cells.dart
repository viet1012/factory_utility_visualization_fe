import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog_value_format.dart';
import '../../catalog_view_models.dart';
import '../../models/signal_history_models.dart';
import '../../providers/filter_sparkline_controller.dart';
import '../signal_chart/signal_chart_palette.dart';
import 'signal_sparkline.dart';

/// Id lich su cua mot dong, cung cong thuc voi chart panel device.
String filterSignalIdOf(CatalogTableRow row) {
  return buildSignalHistoryId(
    fac: row.facility,
    cate: row.rawCategory,
    scadaId: row.scadaId,
    boxId: row.boxId,
    boxDeviceId: row.boxDeviceId,
    plcAddress: row.plcAddress,
  );
}

/// Signal trang thai: kind STATUS tu API, hoac (khi chua tai xong lich su)
/// ten bat dau bang "Slave".
bool isStatusSignal(CatalogTableRow row, SignalHistorySeries? series) {
  if (series != null) return series.kind == SignalKind.status;

  return row.displaySignalName.toLowerCase().startsWith('slave');
}

/// "just now", "1 min ago", "5 min ago", "2 h ago", "1 d ago".
String formatRelativeTime(DateTime time, DateTime now) {
  final diff = now.difference(time.toLocal());

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';

  return '${diff.inDays} d ago';
}

// ============================================================
// BOX / DEVICE
// ============================================================

/// Box (dam) + device (nho, mo) trong mot o. Ten bi cat thi co tooltip day du.
class FilterDeviceCell extends StatelessWidget {
  final CatalogTableRow row;

  const FilterDeviceCell({super.key, required this.row});

  static const TextStyle _boxStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle _deviceStyle = TextStyle(
    color: SignalChartColors.mutedText,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final box = row.boxId.trim().isEmpty ? '--' : row.boxId.trim();
    final device = row.boxDeviceId.trim().isEmpty
        ? '--'
        : row.boxDeviceId.trim();

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final truncated =
              _overflows(box, _boxStyle, constraints.maxWidth) ||
              _overflows(device, _deviceStyle, constraints.maxWidth);

          final content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                box,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _boxStyle,
              ),
              const SizedBox(height: 2),
              Text(
                device,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _deviceStyle,
              ),
            ],
          );

          if (!truncated) return content;

          return Tooltip(
            message: 'Box: $box\nDevice: $device',
            child: content,
          );
        },
      ),
    );
  }

  static bool _overflows(String text, TextStyle style, double maxWidth) {
    if (!maxWidth.isFinite) return false;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
  }
}

// ============================================================
// PLC / SIGNAL
// ============================================================

/// Badge PLC cung style voi bang device (mau theo category).
class FilterPlcCell extends StatelessWidget {
  final CatalogTableRow row;

  const FilterPlcCell({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final color = SignalChartColors.category(row.category);
    final plc = row.plcAddress.trim();

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Text(
          plc.isEmpty ? '--' : plc,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class FilterSignalCell extends StatelessWidget {
  final CatalogTableRow row;

  const FilterSignalCell({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final code = row.cateId.trim();

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.displaySignalName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (code.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SignalChartColors.mutedText,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// VALUE
// ============================================================

/// Gia tri hien tai (tu /api/utility/latest).
/// - STATUS: badge "Code 8", khong so thap phan.
/// - Co nguong (tu lich su 1h): thanh nho the hien vi tri so voi low / high;
///   vuot nguong thi gia tri va thanh do.
class FilterValueCell extends StatelessWidget {
  final CatalogTableRow row;
  final String signalId;

  const FilterValueCell({super.key, required this.row, required this.signalId});

  @override
  Widget build(BuildContext context) {
    final series = context.select<FilterSparklineController, SignalHistorySeries?>(
      (controller) => controller.seriesFor(signalId),
    );

    final value = row.value;
    final hasValue = value != null && value.isFinite;

    if (isStatusSignal(row, series)) {
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: hasValue
            ? _CodeBadge(code: value.round(), stale: row.isStale)
            : const Text('--', style: TextStyle(color: SignalChartColors.mutedText)),
      );
    }

    final low = series?.thresholdLow;
    final high = series?.thresholdHigh;
    final hasThreshold = hasValue && (low != null || high != null);
    final outOfRange = hasValue && (series?.isOutOfRange(value) ?? false);

    final color = outOfRange
        ? SignalChartColors.alert
        : row.isStale
        ? SignalChartColors.stale
        : SignalChartColors.online;

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCatalogValueWithUnit(value, row.unit),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (hasThreshold) ...[
            const SizedBox(height: 5),
            Tooltip(
              message:
                  'Low ${formatCatalogValueWithUnit(low, row.unit)}'
                  '  ·  High ${formatCatalogValueWithUnit(high, row.unit)}',
              child: _ThresholdPositionBar(
                value: value,
                low: low,
                high: high,
                outOfRange: outOfRange,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeBadge extends StatelessWidget {
  final int code;
  final bool stale;

  const _CodeBadge({required this.code, required this.stale});

  @override
  Widget build(BuildContext context) {
    final color = stale ? SignalChartColors.stale : statusCodeColor(code);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        'Code $code',
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Thanh ngang nho: vung binh thuong (low..high) to xanh nhat, cham la
/// vi tri gia tri hien tai. Thieu mot phia thi vung keo ra mep.
class _ThresholdPositionBar extends StatelessWidget {
  final double value;
  final double? low;
  final double? high;
  final bool outOfRange;

  const _ThresholdPositionBar({
    required this.value,
    required this.low,
    required this.high,
    required this.outOfRange,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 8,
      child: CustomPaint(
        painter: _ThresholdBarPainter(value, low, high, outOfRange),
      ),
    );
  }
}

class _ThresholdBarPainter extends CustomPainter {
  final double value;
  final double? low;
  final double? high;
  final bool outOfRange;

  _ThresholdBarPainter(this.value, this.low, this.high, this.outOfRange);

  @override
  void paint(Canvas canvas, Size size) {
    final a = low ?? high!;
    final b = high ?? low!;

    var lo = math.min(math.min(a, b), value);
    var hi = math.max(math.max(a, b), value);

    var span = hi - lo;
    if (span <= 0) span = math.max(value.abs() * .1, 1);

    lo -= span * .15;
    hi += span * .15;
    final range = hi - lo;

    double xOf(double v) => ((v - lo) / range).clamp(0.0, 1.0) * size.width;

    final trackTop = size.height / 2 - 1.5;

    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackTop, size.width, 3),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      track,
      Paint()..color = Colors.white.withValues(alpha: .10),
    );

    final zoneStart = xOf(low ?? lo);
    final zoneEnd = xOf(high ?? hi);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(zoneStart, trackTop, zoneEnd, trackTop + 3),
        const Radius.circular(2),
      ),
      Paint()
        ..color = (outOfRange ? SignalChartColors.alert : SignalChartColors.online)
            .withValues(alpha: .35),
    );

    canvas.drawCircle(
      Offset(xOf(value), size.height / 2),
      3.5,
      Paint()
        ..color = outOfRange ? SignalChartColors.alert : SignalChartColors.text,
    );
  }

  @override
  bool shouldRepaint(covariant _ThresholdBarPainter old) {
    return old.value != value ||
        old.low != low ||
        old.high != high ||
        old.outOfRange != outOfRange;
  }
}

// ============================================================
// SPARKLINE 1h
// ============================================================

class FilterSparklineCell extends StatelessWidget {
  final CatalogTableRow row;
  final String signalId;
  final String deviceKey;

  const FilterSparklineCell({
    super.key,
    required this.row,
    required this.signalId,
    required this.deviceKey,
  });

  @override
  Widget build(BuildContext context) {
    final series = context.select<FilterSparklineController, SignalHistorySeries?>(
      (controller) => controller.seriesFor(signalId),
    );
    final state = context.select<FilterSparklineController, SparklineLoadState?>(
      (controller) => controller.stateOf(deviceKey),
    );

    Widget child;

    if (series != null &&
        series.error == null &&
        series.points.any((point) => point.value != null)) {
      child = SignalSparkline(
        series: series,
        color: SignalChartColors.line(row.rawCategory),
      );
    } else if (series == null && state == SparklineLoadState.loading) {
      child = Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else {
      child = Tooltip(
        message: state == SparklineLoadState.error
            ? 'Unable to load 1h history'
            : 'No data in the last hour',
        child: const Text(
          '—',
          style: TextStyle(color: SignalChartColors.mutedText),
        ),
      );
    }

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: child,
    );
  }
}

// ============================================================
// UPDATED / STATUS
// ============================================================

/// Thoi gian tuong doi; tooltip ghi gio day du; cam khi stale.
class FilterUpdatedCell extends StatelessWidget {
  final CatalogTableRow row;
  final DateTime now;

  const FilterUpdatedCell({super.key, required this.row, required this.now});

  @override
  Widget build(BuildContext context) {
    final time = row.recordedAt;
    final stale = row.isStaleAt(now);

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: time == null
          ? const Text('--', style: TextStyle(color: SignalChartColors.mutedText))
          : Tooltip(
              message: row.displayTime,
              child: Text(
                formatRelativeTime(time, now),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: stale
                      ? SignalChartColors.stale
                      : SignalChartColors.subText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}

/// Cham trang thai + tooltip (thay cho badge ONLINE / STALE).
class FilterStatusDotCell extends StatelessWidget {
  final CatalogTableRow row;
  final DateTime now;

  const FilterStatusDotCell({super.key, required this.row, required this.now});

  @override
  Widget build(BuildContext context) {
    final stale = row.isStaleAt(now);
    final color = stale ? SignalChartColors.stale : SignalChartColors.online;

    return Center(
      child: Tooltip(
        message: '${row.statusLabelAt(now)}  ·  ${row.displayTime}',
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .45), blurRadius: 6),
            ],
          ),
        ),
      ),
    );
  }
}
