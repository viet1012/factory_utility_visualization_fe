import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/utility_facade_service.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_fac_details/layout/utility_fac_layout_screen.dart';
import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_widgets/utility_glow_card.dart';
import '../utility_dashboard_overview_widgets/utility_info_box_header.dart';

// ============================================================
// MODEL
// ============================================================

class EnergyMonthlySummary {
  final String cate;
  final String name;
  final String month;

  final double? minValue;
  final double? maxValue;
  final double? prevMinValue;
  final double? prevMaxValue;

  final double? value;
  final double? avgValue;

  final double? vndCost;
  final double? usdCost;

  final double? prevValue;
  final double? prevAvgValue;

  final double? prevVndCost;
  final double? prevUsdCost;

  final double? deltaValue;
  final double? deltaPercent;

  final String unit;

  final DateTime? pickAt;
  final DateTime? generatedAt;

  const EnergyMonthlySummary({
    required this.cate,
    required this.name,
    required this.month,
    required this.minValue,
    required this.maxValue,
    required this.prevMinValue,
    required this.prevMaxValue,
    required this.value,
    required this.avgValue,
    required this.vndCost,
    required this.usdCost,
    required this.prevValue,
    required this.prevAvgValue,
    required this.prevVndCost,
    required this.prevUsdCost,
    required this.deltaValue,
    required this.deltaPercent,
    required this.unit,
    required this.pickAt,
    required this.generatedAt,
  });

  factory EnergyMonthlySummary.fromJson(Map<String, dynamic> json) {
    return EnergyMonthlySummary(
      cate: _readString(json['cate']),
      name: _readString(json['name']),
      month: _readString(json['month']),

      minValue: _readDouble(json['minValue']),
      maxValue: _readDouble(json['maxValue']),
      prevMinValue: _readDouble(json['prevMinValue']),
      prevMaxValue: _readDouble(json['prevMaxValue']),

      value: _readDouble(json['value']),
      avgValue: _readDouble(json['avgValue']),

      vndCost: _readDouble(json['vndCost']),
      usdCost: _readDouble(json['usdCost']),

      prevValue: _readDouble(json['prevValue']),
      prevAvgValue: _readDouble(json['prevAvgValue']),

      prevVndCost: _readDouble(json['prevVndCost']),
      prevUsdCost: _readDouble(json['prevUsdCost']),

      deltaValue: _readDouble(json['deltaValue']),
      deltaPercent: _readDouble(json['deltaPercent']),

      unit: _readString(json['unit']),

      pickAt: _readDateTime(json['pickAt'] ?? json['timestamp']),

      generatedAt: _readDateTime(json['generatedAt']),
    );
  }

  static String _readString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    final raw = value.toString().trim();

    if (raw.isEmpty) return null;

    return double.tryParse(raw.replaceAll(',', ''));
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();

    if (raw.isEmpty) return null;

    return DateTime.tryParse(raw)?.toLocal();
  }

  double get displayValue {
    return value ?? avgValue ?? 0;
  }

  double? get previousDisplayValue {
    return prevValue ?? prevAvgValue;
  }

  double? get currentCost {
    if (usdCost != null) return usdCost;
    if (vndCost != null) return vndCost;

    return null;
  }

  double? get previousCost {
    // Chỉ lấy previous tương ứng với loại tiền hiện tại.
    if (usdCost != null) return prevUsdCost;
    if (vndCost != null) return prevVndCost;

    return null;
  }

  String get currentCostUnit {
    if (usdCost != null) return 'USD';
    if (vndCost != null) return 'VND';

    return '';
  }

  String get previousCostUnit {
    // Unit previous phải đi theo loại tiền current.
    if (usdCost != null && prevUsdCost != null) return 'USD';
    if (vndCost != null && prevVndCost != null) return 'VND';

    return '';
  }

  bool get hasComparableCost {
    final current = currentCost;
    final previous = previousCost;

    return current != null &&
        previous != null &&
        currentCostUnit.isNotEmpty &&
        currentCostUnit == previousCostUnit;
  }

  /// Current cost - previous cost.
  double? get costDeltaValue {
    if (!hasComparableCost) return null;

    return currentCost! - previousCost!;
  }

  /// Phần trăm thay đổi chi phí so với tháng trước.
  double? get costDeltaPercent {
    if (!hasComparableCost) return null;

    final previous = previousCost!;

    if (previous == 0) return null;

    return ((currentCost! - previous) / previous) * 100;
  }
}

// ============================================================
// FORMATTERS
// ============================================================

final NumberFormat _integerFmt = NumberFormat('#,##0');
final NumberFormat _decimalFmt = NumberFormat('#,##0.0');
final NumberFormat _moneyFmt = NumberFormat('#,##0');

const EdgeInsets _metricCardPadding = EdgeInsets.symmetric(
  horizontal: 2,
  vertical: 5,
);

String _formatUtilityNumber(EnergyMonthlySummary item, double? value) {
  if (value == null) {
    return '--';
  }

  return _isElectricityItem(item)
      ? _formatInteger(value)
      : _formatDecimal(value);
}

String _metricModeLabel(EnergyMonthlySummary item) {
  return _isElectricityItem(item) ? 'MTD' : 'AVG';
}

String _formatInteger(double value) {
  return _integerFmt.format(value);
}

String _formatDecimal(double value) {
  return _decimalFmt.format(value);
}

String _formatMoney(double value) {
  return _moneyFmt.format(value);
}

String _formatCost(double? value, String unit) {
  if (value == null) {
    return '--';
  }

  final formattedValue = _formatMoney(value);
  final normalizedUnit = unit.trim();

  if (normalizedUnit.isEmpty) {
    return formattedValue;
  }

  return '$formattedValue $normalizedUnit';
}

bool _isElectricityItem(EnergyMonthlySummary item) {
  return item.cate.trim().toUpperCase().contains('ELECTRIC');
}

bool _isWaterItem(EnergyMonthlySummary item) {
  return item.cate.trim().toUpperCase().contains('WATER');
}

bool _isAirItem(EnergyMonthlySummary item) {
  final cate = item.cate.trim().toUpperCase();

  return cate.contains('AIR') || cate.contains('COMPRESSED');
}

String _resolveUnit(EnergyMonthlySummary item, ChartTheme theme) {
  final apiUnit = item.unit.trim();

  if (apiUnit.isNotEmpty) {
    return apiUnit;
  }

  return theme.unit.trim();
}

String _formatUtilityValue(
  EnergyMonthlySummary item,
  double? value,
  String unit,
) {
  if (value == null) {
    return '--';
  }

  final formatted = _isElectricityItem(item)
      ? _formatInteger(value)
      : _formatDecimal(value);

  if (unit.trim().isEmpty) {
    return formatted;
  }

  return '$formatted ${unit.trim()}';
}

String _monthlyPeriodLabel(EnergyMonthlySummary item) {
  final isAverage = _isWaterItem(item) || _isAirItem(item);
  final suffix = isAverage ? 'AVG' : 'MTD';

  final raw = item.month.trim();

  if (!RegExp(r'^\d{6}$').hasMatch(raw)) {
    return 'MONTHLY $suffix';
  }

  final year = raw.substring(0, 4);
  final monthNumber = int.tryParse(raw.substring(4, 6));

  if (monthNumber == null || monthNumber < 1 || monthNumber > 12) {
    return 'MONTHLY $suffix';
  }

  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  return '${months[monthNumber - 1]} $year $suffix';
}

// ============================================================
// MONTHLY BOX
// ============================================================

class UtilityOverviewMonthlyBox extends StatefulWidget {
  final double width;
  final double? height;

  final String facId;
  final String month;
  final String headerTitle;

  final bool isHighlighted;
  final String? filterCate;

  const UtilityOverviewMonthlyBox({
    super.key,
    required this.facId,
    required this.month,
    required this.headerTitle,
    this.width = 330,
    this.height,
    this.isHighlighted = true,
    this.filterCate,
  });

  @override
  State<UtilityOverviewMonthlyBox> createState() {
    return _UtilityOverviewMonthlyBoxState();
  }
}

class _UtilityOverviewMonthlyBoxState extends State<UtilityOverviewMonthlyBox>
    with TickerProviderStateMixin {
  /// Monthly summary không cần refresh mỗi 30 giây.
  /// GET sẽ dùng cache backend.
  static const Duration _refreshInterval = Duration(hours: 6);

  static const Duration _requestTimeout = Duration(seconds: 30);

  late final UtilityInfoBoxFx _fx;

  late final AnimationController _highlightController;
  late final Animation<double> _opacityAnimation;

  Timer? _refreshTimer;

  bool _disposed = false;
  bool _screenActive = true;

  bool _loading = true;
  bool _fetching = false;

  int _requestToken = 0;

  Object? _error;
  DataHealthResult? _cachedHealth;

  List<EnergyMonthlySummary> _items = const [];

  bool get _canUpdate {
    return mounted && !_disposed && _screenActive;
  }

  @override
  void initState() {
    super.initState();

    _fx = UtilityInfoBoxFx(this)..init();

    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.isHighlighted ? 1 : 0.55,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUpdate) return;

      unawaited(_load());
    });

    _startRefreshTimer();
  }

  @override
  void activate() {
    super.activate();

    _screenActive = true;
  }

  @override
  void deactivate() {
    _screenActive = false;

    super.deactivate();
  }

  @override
  void didUpdateWidget(covariant UtilityOverviewMonthlyBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isHighlighted != widget.isHighlighted) {
      if (widget.isHighlighted) {
        _highlightController.forward();
      } else {
        _highlightController.reverse();
      }
    }

    final oldFac = oldWidget.facId.trim();
    final newFac = widget.facId.trim();

    final oldMonth = oldWidget.month.trim();
    final newMonth = widget.month.trim();

    final sourceChanged = oldFac != newFac || oldMonth != newMonth;

    if (!sourceChanged) return;

    /// Vô hiệu hóa response cũ.
    _requestToken++;

    _fetching = false;
    _cachedHealth = null;

    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUpdate) return;

      unawaited(_load(force: true));
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_canUpdate || _fetching) {
        return;
      }

      unawaited(_load(silent: true));
    });
  }

  Future<void> _load({bool silent = false, bool force = false}) async {
    if (!_canUpdate) return;

    if (_fetching && !force) {
      return;
    }

    final facId = widget.facId.trim();
    final month = widget.month.trim();

    if (facId.isEmpty || month.isEmpty) {
      return;
    }

    final requestToken = ++_requestToken;

    _fetching = true;

    if (!silent && _items.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      /// getMonthlySummary đã trả trực tiếp:
      /// List<EnergyMonthlySummary>
      ///
      /// Không parse Map lần thứ hai.
      final result = await api
          .getMonthlySummary(facId: facId, month: month)
          .timeout(_requestTimeout);

      if (!_isValidRequest(requestToken)) {
        return;
      }

      final nextItems = List<EnergyMonthlySummary>.unmodifiable(result);

      final healthValues = nextItems
          .map((item) => item.displayValue)
          .where((value) => value.isFinite && value != 0)
          .toList(growable: false);

      final nextHealth = DataHealthAnalyzer.analyze(
        key: 'Monthly_${widget.facId}_${widget.headerTitle}',
        loading: false,
        error: null,
        values: healthValues,
      );

      setState(() {
        _items = nextItems;
        _cachedHealth = nextHealth;

        _loading = false;
        _error = null;
      });
    } on TimeoutException catch (exception) {
      _handleLoadError(requestToken, exception, '[MONTHLY TIMEOUT]');
    } catch (exception, stackTrace) {
      _handleLoadError(
        requestToken,
        exception,
        '[MONTHLY ERROR]',
        stackTrace: stackTrace,
      );
    } finally {
      if (_isValidRequest(requestToken)) {
        _fetching = false;
      }
    }
  }

  void _handleLoadError(
    int requestToken,
    Object exception,
    String tag, {
    StackTrace? stackTrace,
  }) {
    if (!_isValidRequest(requestToken)) {
      return;
    }

    debugPrint('$tag $exception');

    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }

    setState(() {
      _loading = false;

      /// Nếu đã có dữ liệu cũ thì tiếp tục hiển thị.
      /// Chỉ hiện lỗi khi chưa có dữ liệu.
      _error = _items.isEmpty ? exception : null;
    });
  }

  bool _isValidRequest(int requestToken) {
    return _canUpdate && requestToken == _requestToken;
  }

  void _openFacilityDetail() {
    final service = context.read<UtilityFacadeService>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return UtilityFacDetailScreens(facId: widget.facId, svc: service);
        },
      ),
    );
  }

  List<EnergyMonthlySummary> _filteredItems() {
    final filter = widget.filterCate?.trim().toUpperCase();

    if (filter == null || filter.isEmpty) {
      return _items;
    }

    return _items
        .where((item) {
          final cate = item.cate.trim().toUpperCase();

          if (filter == 'ELECTRICITY') {
            return cate.contains('ELECTRIC');
          }

          if (filter == 'WATER') {
            return cate.contains('WATER');
          }

          if (filter == 'AIR') {
            return cate.contains('AIR') || cate.contains('COMPRESSED');
          }

          return cate.contains(filter);
        })
        .toList(growable: false);
  }

  ChartTheme _resolveCurrentTheme(List<EnergyMonthlySummary> displayItems) {
    final filterCate = widget.filterCate?.trim();

    if (filterCate != null && filterCate.isNotEmpty) {
      return ChartThemeResolver.theme(filterCate);
    }

    if (displayItems.isNotEmpty) {
      return ChartThemeResolver.theme(displayItems.first.cate);
    }

    return ChartThemes.power;
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _filteredItems();

    final currentTheme = _resolveCurrentTheme(displayItems);

    final headerColor = currentTheme.iconColor;

    final healthResult =
        _cachedHealth ??
        DataHealthAnalyzer.analyze(
          key: 'Monthly_${widget.facId}_${widget.headerTitle}',
          loading: _loading,
          error: _error,
          values: const [],
        );

    return GestureDetector(
      onTap: _openFacilityDetail,
      child: RepaintBoundary(
        child: SlideTransition(
          position: _fx.slide,
          child: AnimatedBuilder(
            animation: Listenable.merge([_fx.listenable, _opacityAnimation]),
            builder: (_, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(scale: _fx.scale.value, child: child),
              );
            },
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              // facColor: facColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UtilityInfoBoxHeader.header(
                    facilityColor: headerColor.withOpacity(.3),
                    facTitle: widget.headerTitle,
                    healthResult: healthResult,
                  ),
                  _MonthlyBody(
                    loading: _loading,
                    error: _error,
                    items: displayItems,
                    onRetry: _load,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _screenActive = false;

    _requestToken++;

    _refreshTimer?.cancel();
    _refreshTimer = null;

    _fx.dispose();
    _highlightController.dispose();

    super.dispose();
  }
}

// ============================================================
// MONTHLY BODY
// ============================================================

class _MonthlyBody extends StatelessWidget {
  final bool loading;
  final Object? error;
  final List<EnergyMonthlySummary> items;
  final Future<void> Function() onRetry;

  const _MonthlyBody({
    required this.loading,
    required this.error,
    required this.items,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (error != null && items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: _InlineState(
          icon: Icons.cloud_off_rounded,
          title: 'API Error',
          message: 'Tap to retry',
          onTap: onRetry,
        ),
      );
    }

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: _InlineState(
          icon: Icons.dataset_outlined,
          title: 'No Data',
          message: 'No monthly utility data.',
        ),
      );
    }

    final waterItems = items.where(_isWaterItem).toList(growable: false);

    final otherItems = items
        .where((item) => !_isWaterItem(item))
        .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < otherItems.length; index++) ...[
          RepaintBoundary(child: _EnergyRow(item: otherItems[index])),
          if (index < otherItems.length - 1 || waterItems.isNotEmpty)
            const SizedBox(height: 8),
        ],

        if (waterItems.isNotEmpty)
          RepaintBoundary(child: _WaterGroupCard(items: waterItems)),
      ],
    );
  }
}

// ============================================================
// INLINE STATE
// ============================================================

class _InlineState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  final Future<void> Function()? onTap;

  const _InlineState({
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(.55), size: 22),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(.84),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          message,
          style: TextStyle(
            color: Colors.white.withOpacity(.52),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return Center(child: content);
    }

    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          unawaited(onTap!());
        },
        child: Padding(padding: const EdgeInsets.all(10), child: content),
      ),
    );
  }
}
// ============================================================
// COMMON METRIC UI
// ============================================================

class _MetricDeltaBadge extends StatelessWidget {
  final double? delta;

  const _MetricDeltaBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    final value = delta;

    if (value == null) {
      return Text(
        '--',
        style: TextStyle(
          color: Colors.white.withOpacity(.35),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    final isUp = value > 0;
    final isDown = value < 0;

    final color = value == 0
        ? Colors.white54
        : isUp
        ? Colors.redAccent
        : Colors.greenAccent;

    final icon = isUp
        ? Icons.arrow_upward_rounded
        : isDown
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 1),
        Text(
          '${value.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontSize: 16,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MetricHeader extends StatelessWidget {
  final String title;
  final Color colors;

  const _MetricHeader({required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors,
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w900,
        letterSpacing: .15,
      ),
    );
  }
}

class _MetricValueText extends StatelessWidget {
  final String value;
  final String unit;
  final Color color;

  final String? badge;
  final bool emphasized;
  final TextAlign textAlign;

  const _MetricValueText({
    required this.value,
    required this.unit,
    required this.color,
    this.badge,
    this.emphasized = false,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUnit = unit.trim();
    final normalizedBadge = badge?.trim().toUpperCase() ?? '';

    final alignment = textAlign == TextAlign.right
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -.30,
              ),
            ),

            if (normalizedUnit.isNotEmpty)
              TextSpan(
                text: ' $normalizedUnit',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),

            if (normalizedBadge.isNotEmpty)
              TextSpan(
                text: ' ($normalizedBadge)',
                style: TextStyle(
                  color: color.withOpacity(.9),
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .15,
                ),
              ),
          ],
        ),
        maxLines: 1,
        textAlign: textAlign,
      ),
    );
  }
}

class _MetricComparisonRow extends StatelessWidget {
  final String currentValue;
  final String currentUnit;

  final String previousValue;
  final String previousUnit;

  final String mode;
  final double? delta;

  final Color currentColor;

  const _MetricComparisonRow({
    required this.currentValue,
    required this.currentUnit,
    required this.previousValue,
    required this.previousUnit,
    required this.mode,
    required this.delta,
    required this.currentColor,
  });

  bool get _hasPrevious {
    final value = previousValue.trim();

    return value.isNotEmpty && value != '--';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // CURRENT
          Expanded(
            flex: 11,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _MetricValueText(
                value: currentValue,
                unit: currentUnit,
                badge: mode,
                color: currentColor,
                emphasized: true,
                textAlign: TextAlign.left,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // PRE MONTH
          Expanded(
            flex: 9,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _hasPrevious
                  ? _MetricValueText(
                      value: previousValue,
                      unit: previousUnit,
                      color: Colors.white,
                      emphasized: false,
                      textAlign: TextAlign.left,
                    )
                  : Text(
                      '--',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.35),
                        fontSize: 17,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 8),

          // DIFF
          SizedBox(
            width: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: _MetricDeltaBadge(delta: delta),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumnsHeader extends StatelessWidget {
  const _MetricColumnsHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white,
      fontSize: 12.5,
      height: 1,
      fontWeight: FontWeight.w900,
      letterSpacing: .45,
    );

    return Row(
      children: [
        Expanded(
          flex: 11,
          child: Text('CURRENT', textAlign: TextAlign.left, style: style),
        ),

        const SizedBox(width: 8),

        Expanded(
          flex: 9,
          child: Text('PRE MONTH', textAlign: TextAlign.left, style: style),
        ),

        const SizedBox(width: 8),

        SizedBox(
          width: 60,
          child: Text('DIFF', textAlign: TextAlign.right, style: style),
        ),
      ],
    );
  }
}
// ============================================================
// ELECTRICITY / AIR ROW
// ============================================================

class _EnergyRow extends StatelessWidget {
  final EnergyMonthlySummary item;

  const _EnergyRow({required this.item});

  String _title() {
    if (_isElectricityItem(item)) {
      return 'Total Energy';
    }

    if (_isAirItem(item)) {
      return 'Compressed Air';
    }

    final name = item.name.trim();

    return name.isNotEmpty ? name : item.cate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(item.cate);
    final color = theme.iconColor;

    final isElectricity = _isElectricityItem(item);
    final isAir = _isAirItem(item);

    final utilityUnit = _resolveUnit(item, theme);
    final mode = _metricModeLabel(item);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricHeader(title: _title(), colors: theme.line),

          const SizedBox(height: 10),

          const _MetricColumnsHeader(),

          const SizedBox(height: 4),

          // Điện có thêm một hàng chi phí.
          if (isElectricity) ...[
            _MetricComparisonRow(
              currentValue: item.currentCost == null
                  ? '--'
                  : _formatMoney(item.currentCost!),
              currentUnit: item.currentCostUnit,
              previousValue: item.previousCost == null
                  ? '--'
                  : _formatMoney(item.previousCost!),
              previousUnit: item.previousCostUnit,
              mode: mode,
              delta: item.costDeltaPercent,
              currentColor: color,
            ),

            const SizedBox(height: 3),
            Divider(
              height: 1,
              thickness: .5,
              color: Colors.white.withOpacity(.7),
            ),

            const SizedBox(height: 3),
          ],

          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: item.displayValue),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, animatedValue, __) {
              return _MetricComparisonRow(
                currentValue: _formatUtilityNumber(item, animatedValue),
                currentUnit: utilityUnit,
                previousValue: _formatUtilityNumber(
                  item,
                  item.previousDisplayValue,
                ),
                previousUnit: utilityUnit,
                mode: mode,
                delta: item.deltaPercent,
                currentColor: color,
              );
            },
          ),
        ],
      ),
    );

    if (isElectricity) {
      return UtilityGlowCard.electricity(color: color, child: content);
    }

    if (isAir) {
      return UtilityGlowCard.air(color: color, child: content);
    }

    return UtilityGlowCard.electricity(color: color, child: content);
  }
}
// ============================================================
// WATER GROUP
// ============================================================

class _WaterGroupCard extends StatelessWidget {
  final List<EnergyMonthlySummary> items;

  const _WaterGroupCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final color = ChartThemes.water.iconColor;

    return UtilityGlowCard.water(
      color: color,
      child: Padding(
        padding: _metricCardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _WaterCompactRow(item: items[index], color: color),

              if (index < items.length - 1) ...[
                const SizedBox(height: 3),
                Divider(
                  height: 1,
                  thickness: .5,
                  color: Colors.white.withOpacity(.5),
                ),
                const SizedBox(height: 3),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _WaterCompactRow extends StatelessWidget {
  final EnergyMonthlySummary item;
  final Color color;

  const _WaterCompactRow({required this.item, required this.color});

  String _displayName() {
    final name = item.name.trim();
    final normalized = name.toUpperCase();

    if (normalized.contains('COOLING TANK')) {
      return 'Cooling Tank Temperature';
    }

    if (normalized.contains('PIPELINE PRESSURE')) {
      return 'Pipeline Pressure';
    }

    return name.isNotEmpty ? name : 'Water Metric';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.water;
    final unit = _resolveUnit(item, theme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricHeader(title: _displayName(), colors: theme.line),

        const SizedBox(height: 10),

        const _MetricColumnsHeader(),

        const SizedBox(height: 4),

        _MetricComparisonRow(
          currentValue: _formatUtilityNumber(item, item.displayValue),
          currentUnit: unit,
          previousValue: _formatUtilityNumber(item, item.previousDisplayValue),
          previousUnit: unit,
          mode: 'AVG',
          delta: item.deltaPercent,
          currentColor: color,
        ),
      ],
    );
  }
}
// ============================================================
// MINI METRIC
// ============================================================

// ============================================================
// MONEY METRIC
// ============================================================

class _MoneyMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final double fontSize;

  const _MoneyMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color.withOpacity(.80)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.50),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              height: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
