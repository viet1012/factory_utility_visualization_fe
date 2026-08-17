import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_dashboard_overview_widgets/common_chart_title_bar.dart';
import '../utility_dashboard_overview_widgets/scada_chart_panel.dart';

// ============================================================
// RANGE
// ============================================================

class DailyChartRange {
  final DateTime minX;
  final DateTime maxX;

  final double maxY;
  final double yInterval;

  const DailyChartRange({
    required this.minX,
    required this.maxX,
    required this.maxY,
    required this.yInterval,
  });
}

// ============================================================
// COMMON UTILS
// ============================================================

class DailyChartUtils {
  const DailyChartUtils._();

  static final NumberFormat _compactValueFormat = NumberFormat.compact(
    locale: 'en_US',
  );

  // ============================================================
  // VALIDATE
  // ============================================================

  static bool isValidSource({required String facId, required String month}) {
    final fac = facId.trim();
    final normalizedMonth = month.trim();

    return fac.isNotEmpty && RegExp(r'^\d{6}$').hasMatch(normalizedMonth);
  }

  // ============================================================
  // RANGE
  // ============================================================

  static DailyChartRange calculateRange({
    required String month,
    required Iterable<double> values,
  }) {
    final year = int.parse(month.substring(0, 4));

    final monthNumber = int.parse(month.substring(4, 6));

    final firstDay = DateTime(year, monthNumber, 1);

    final lastDay = DateTime(
      year,
      monthNumber + 1,
      1,
    ).subtract(const Duration(days: 1));

    var maxValue = 0.0;

    for (final value in values) {
      if (!value.isFinite) {
        continue;
      }

      if (value > maxValue) {
        maxValue = value;
      }
    }

    final rawMaxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    final yInterval = _niceStep(rawMaxY / 5);

    final maxY = _niceCeil(rawMaxY, yInterval);

    return DailyChartRange(
      minX: firstDay.subtract(const Duration(hours: 12)),
      maxX: lastDay.add(const Duration(hours: 12)),
      maxY: maxY,
      yInterval: yInterval,
    );
  }

  static double _niceStep(double rawStep) {
    if (rawStep <= 0 || !rawStep.isFinite) {
      return 1;
    }

    final exponent = (log(rawStep) / ln10).floor();

    final base = pow(10, exponent).toDouble();

    final fraction = rawStep / base;

    if (fraction <= 1) {
      return base;
    }

    if (fraction <= 2) {
      return 2 * base;
    }

    if (fraction <= 5) {
      return 5 * base;
    }

    return 10 * base;
  }

  static double _niceCeil(double value, double step) {
    if (step <= 0 || !step.isFinite) {
      return value;
    }

    return (value / step).ceil() * step;
  }

  // ============================================================
  // FORMAT VALUE
  // ============================================================

  static String formatValue(double value) {
    if (!value.isFinite) {
      return '--';
    }

    final absolute = value.abs();

    if (absolute >= 1000) {
      return _compactValueFormat.format(value);
    }

    if (absolute >= 100) {
      return value.toStringAsFixed(1);
    }

    if (absolute >= 10) {
      return value.toStringAsFixed(2);
    }

    return value.toStringAsFixed(3);
  }

  // ============================================================
  // LATEST POINT
  // ============================================================

  static T resolveLatest<T>({
    required List<T> rows,
    required DateTime Function(T item) dateOf,
    required String month,
  }) {
    final sorted = List<T>.from(rows)
      ..sort((a, b) => dateOf(a).compareTo(dateOf(b)));

    final now = DateTime.now();

    final currentMonth = DateFormat('yyyyMM').format(now);

    if (currentMonth != month) {
      return sorted.last;
    }

    for (var index = sorted.length - 1; index >= 0; index--) {
      final date = dateOf(sorted[index]).toLocal();

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return sorted[index];
      }
    }

    return sorted.last;
  }
}

// ============================================================
// COMMON FRAME
// ============================================================

class DailyChartFrame extends StatefulWidget {
  final String facId;
  final String month;

  final ChartTheme theme;

  final bool loading;
  final Object? error;

  final bool hasData;

  final DataHealthResult health;

  final String value;
  final String valueTimestamp;

  final String? valueLabel;

  final String emptyTitle;
  final String emptyMessage;

  final double width;
  final double height;

  final bool showHeader;

  final VoidCallback? onRetry;

  final Widget? chart;

  const DailyChartFrame({
    super.key,
    required this.facId,
    required this.month,
    required this.theme,
    required this.loading,
    required this.error,
    required this.hasData,
    required this.health,
    required this.value,
    required this.valueTimestamp,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.chart,
    this.valueLabel,
    this.onRetry,
    this.width = 520,
    this.height = 320,
    this.showHeader = true,
  });

  @override
  State<DailyChartFrame> createState() => _DailyChartFrameState();
}

class _DailyChartFrameState extends State<DailyChartFrame>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx _fx;

  bool get _hasRequired {
    return DailyChartUtils.isValidSource(
      facId: widget.facId,
      month: widget.month,
    );
  }

  @override
  void initState() {
    super.initState();

    _fx = UtilityInfoBoxFx(this)..init();
  }

  @override
  void dispose() {
    _fx.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _fx.slide,
      child: MouseRegion(
        onEnter: (_) => _fx.onHover(true),
        onExit: (_) => _fx.onHover(false),
        child: AnimatedBuilder(
          animation: _fx.listenable,
          builder: (_, child) {
            return Transform.scale(scale: _fx.scale.value, child: child);
          },
          child: ScadaChartPanel(
            width: widget.width,
            height: widget.height,
            color: widget.theme.line,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // ==========================================================
    // INVALID
    // ==========================================================

    if (!_hasRequired) {
      return const EmptyChartState(
        icon: Icons.warning_amber_rounded,
        title: 'Invalid Parameters',
        message: 'Missing facId or invalid month format.',
      );
    }

    // ==========================================================
    // LOADING
    // ==========================================================

    if (widget.loading && !widget.hasData) {
      return Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: widget.theme.line,
          ),
        ),
      );
    }

    // ==========================================================
    // ERROR
    // ==========================================================

    if (widget.error != null && !widget.hasData) {
      return ChartApiErrorState(
        color: widget.theme.line,
        onRetry: widget.onRetry ?? () {},
      );
    }

    // ==========================================================
    // NORMAL
    // ==========================================================

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          CommonChartTitleBar(
            title: widget.theme.title,
            health: widget.health,

            valueLabel: widget.valueLabel,

            value: widget.value,

            valueTs: widget.valueTimestamp,

            backgroundColor: Colors.transparent,

            borderColor: widget.theme.line.withOpacity(.44),
          ),

          const SizedBox(height: 6),
        ],

        Expanded(
          child: !widget.hasData || widget.chart == null
              ? EmptyChartState(
                  title: widget.emptyTitle,
                  message: widget.emptyMessage,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(.06)),
                    color: Colors.black.withOpacity(.05),
                  ),
                  child: RepaintBoundary(child: widget.chart!),
                ),
        ),
      ],
    );
  }
}
