import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'value_format.dart';

/// Kieu du lieu cua diem hover, quyet dinh cac dong trong tooltip.
enum HoverKind { analog, counter, status }

/// Trackball / tooltip dung chung cho chart signal.
///
/// ActivationMode.singleTap cua Syncfusion: web / desktop hien khi re chuot
/// (PointerHoverEvent), man hinh cam ung hien khi cham.
class ChartHoverStyle {
  ChartHoverStyle._();

  static const double markerRadius = 6;
  static const double markerBorderWidth = 2;

  static const double titleFontSize = 13;
  static const double rowFontSize = 12;
  static const EdgeInsets padding = EdgeInsets.all(10);
  static const double radius = 8;
  static final Color background = const Color(
    0xFF0B1728,
  ).withValues(alpha: .92);
  static const Color border = Color(0xFF20344D);

  /// Cam ung: giu tooltip mot luc sau khi nhac tay.
  static bool get _isTouch =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Chi series co `enableTrackball: true` tham gia (mac dinh cua Syncfusion);
  /// tat o series phu (dai min–max, cham vuot nguong) de chi co mot tooltip.
  ///
  /// [markerColor] null: marker lay mau cua tung series (chart nhieu series).
  /// [displayMode] groupAllPoints: mot tooltip cho moi series tai cung x.
  static TrackballBehavior trackball({
    required Color? markerColor,
    required ChartTrackballBuilder builder,
    TrackballDisplayMode displayMode = TrackballDisplayMode.nearestPoint,
  }) {
    return TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      hideDelay: _isTouch ? 2500 : 0,
      tooltipDisplayMode: displayMode,
      tooltipAlignment: ChartAlignment.near,
      lineType: TrackballLineType.vertical,
      lineColor: Colors.white.withValues(alpha: .28),
      lineWidth: 1,
      lineDashArray: const <double>[3, 3],
      markerSettings: TrackballMarkerSettings(
        markerVisibility: TrackballVisibilityMode.visible,
        width: markerRadius * 2,
        height: markerRadius * 2,
        color: markerColor,
        borderColor: Colors.white,
        borderWidth: markerBorderWidth,
      ),
      builder: builder,
    );
  }

  /// Dong noi dung theo kind:
  /// ANALOG: Avg (Value khi snapshot), Min – Max, Samples; COUNTER: Usage;
  /// STATUS: Code.
  static List<(String, String)> rows({
    required HoverKind kind,
    required double? value,
    required String unit,
    required int decimals,
    double? min,
    double? max,
    int? samples,
    bool isSnapshot = false,
  }) {
    String fmt(double? v) => formatValue(v, decimals: decimals);
    String withUnit(double? v) => formatWithUnit(v, unit, decimals: decimals);

    return switch (kind) {
      HoverKind.analog => [
        (isSnapshot ? 'Value' : 'Avg', withUnit(value)),
        if (min != null && max != null)
          ('Min – Max', '${fmt(min)} – ${withUnit(max)}'),
        if (samples != null) ('Samples', formatValue(samples, decimals: 0)),
      ],
      HoverKind.counter => [('Usage', withUnit(value))],
      HoverKind.status => [
        ('Code', value == null ? kMissingValue : '${value.round()}'),
      ],
    };
  }
}

/// Khung tooltip: tieu de (thoi gian) + cac dong `label: value`.
class ChartHoverCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  /// Mau o vuong truoc moi dong (chart nhieu series), cung thu tu [rows].
  final List<Color?>? swatches;

  /// Chi so dong to do (vuot nguong).
  final Set<int> alerts;

  const ChartHoverCard({
    super.key,
    required this.title,
    required this.rows,
    this.swatches,
    this.alerts = const <int>{},
  });

  static const Color alertColor = Colors.redAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: ChartHoverStyle.padding,
      decoration: BoxDecoration(
        color: ChartHoverStyle.background,
        borderRadius: BorderRadius.circular(ChartHoverStyle.radius),
        border: Border.all(color: ChartHoverStyle.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: ChartHoverStyle.titleFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          for (final (index, (label, value)) in rows.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (swatches?.elementAtOrNull(index) case final color?) ...[
                    Container(width: 8, height: 8, color: color),
                    const SizedBox(width: 6),
                  ],
                  Flexible(child: _row(label, value, alerts.contains(index))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, bool alert) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .62),
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: alert ? alertColor : Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      style: const TextStyle(fontSize: ChartHoverStyle.rowFontSize),
    );
  }
}
