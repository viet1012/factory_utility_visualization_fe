import 'dart:async';
import 'dart:ui';

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
    return usdCost ?? vndCost;
  }

  double? get previousCost {
    return prevUsdCost ?? prevVndCost;
  }

  String get currentCostUnit {
    if (usdCost != null) return 'USD';
    if (vndCost != null) return 'VND';

    return '';
  }

  String get previousCostUnit {
    if (prevUsdCost != null) return 'USD';
    if (prevVndCost != null) return 'VND';

    return '';
  }
}

// ============================================================
// FORMATTERS
// ============================================================

final NumberFormat _integerFmt = NumberFormat('#,##0');
final NumberFormat _decimalFmt = NumberFormat('#,##0.0');
final NumberFormat _moneyFmt = NumberFormat('#,##0');

const EdgeInsets _metricCardPadding = EdgeInsets.symmetric(
  horizontal: 5,
  vertical: 5,
);

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
    this.width = 300,
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

    final facColor = ChartThemes.colorFromFac(widget.headerTitle);

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
// MONTHLY SHELL
// ============================================================

class _MonthlyShell extends StatelessWidget {
  final double width;
  final double? height;
  final Color facColor;
  final Widget child;

  const _MonthlyShell({
    required this.width,
    this.height,
    required this.facColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final content = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(.16),
                    const Color(0xff67CFFF).withOpacity(.08),
                    const Color(0xff0B1C2F).withOpacity(.18),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    facColor.withOpacity(.18),
                    facColor.withOpacity(.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withOpacity(.22),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: facColor.withOpacity(.18),
                    blurRadius: 18,
                    spreadRadius: -6,
                  ),
                ],
              ),
            ),
          ),

          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(.08)),
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 1, color: Colors.white.withOpacity(.45)),
          ),

          Positioned(
            bottom: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: facColor.withOpacity(.35),
                boxShadow: [
                  BoxShadow(color: facColor.withOpacity(.45), blurRadius: 8),
                ],
              ),
            ),
          ),

          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.9),
                boxShadow: [
                  BoxShadow(color: facColor.withOpacity(.7), blurRadius: 8),
                ],
              ),
            ),
          ),

          Padding(padding: const EdgeInsets.all(1), child: child),
        ],
      ),
    );

    if (height != null) {
      return SizedBox(width: width, height: height, child: content);
    }

    return SizedBox(width: width, child: content);
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

class _MetricPeriodLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _MetricPeriodLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = text.trim().toUpperCase();

    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 8.5,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.05,
      ),
    );
  }
}

class _MetricDeltaBadge extends StatelessWidget {
  final double? delta;
  final bool reverseColor;

  const _MetricDeltaBadge({required this.delta, this.reverseColor = false});

  @override
  Widget build(BuildContext context) {
    final value = delta;

    if (value == null) {
      return const SizedBox.shrink();
    }

    final isUp = value > 0;
    final isDown = value < 0;

    final Color color;

    if (value == 0) {
      color = Colors.white54;
    } else if (reverseColor) {
      color = isUp ? Colors.redAccent : Colors.greenAccent;
    } else {
      color = isUp ? Colors.redAccent : Colors.greenAccent;
    }

    final icon = isUp
        ? Icons.arrow_upward_rounded
        : isDown
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 2),
          Text(
            '${value.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricHeader extends StatelessWidget {
  final String title;
  final double? delta;

  const _MetricHeader({required this.title, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(.88),
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: .15,
            ),
          ),
        ),

        if (delta != null) ...[
          const SizedBox(width: 6),
          _MetricDeltaBadge(delta: delta),
        ],
      ],
    );
  }
}

class _MetricValueRow extends StatelessWidget {
  final String current;
  final String previous;
  final Color color;
  final double currentFontSize;
  final double previousFontSize;

  const _MetricValueRow({
    required this.current,
    required this.previous,
    required this.color,
    this.currentFontSize = 22,
    this.previousFontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedPrevious = previous.trim();
    final hasPrevious =
        normalizedPrevious.isNotEmpty && normalizedPrevious != '--';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            current,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: currentFontSize,
              height: .95,
              fontWeight: FontWeight.w900,
              letterSpacing: -.35,
            ),
          ),
        ),
        if (hasPrevious) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              normalizedPrevious,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white70,
                fontSize: previousFontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -.20,
              ),
            ),
          ),
        ],
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

    final unit = _resolveUnit(item, theme);
    final previousText = _formatUtilityValue(
      item,
      item.previousDisplayValue,
      unit,
    );

    final content = Padding(
      padding: _metricCardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header chỉ còn tên metric và phần trăm thay đổi.
          _MetricHeader(title: _title(), delta: item.deltaPercent),

          const SizedBox(height: 3),
          // 2. Kỳ dữ liệu nằm ngay dưới tên.
          _MetricPeriodLabel(text: _monthlyPeriodLabel(item), color: color),
          // Cost của điện đặt dưới value để period luôn sát title.
          if (isElectricity) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MoneyMetric(
                    label: 'CURRENT COST',
                    value: _formatCost(item.currentCost, item.currentCostUnit),
                    color: Colors.orangeAccent,
                    icon: Icons.monetization_on_outlined,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MoneyMetric(
                    label: 'PREVIOUS COST',
                    value: _formatCost(
                      item.previousCost,
                      item.previousCostUnit,
                    ),
                    color: Colors.white70,
                    icon: Icons.history_rounded,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ],
          // const SizedBox(height: 3),
          Divider(
            height: 1,
            thickness: .5,
            color: Colors.white.withOpacity(.5),
          ),
          // 3. Current bên trái, previous bên phải.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: item.displayValue),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, animatedValue, __) {
              return _MetricValueRow(
                current: _formatUtilityValue(item, animatedValue, unit),
                previous: previousText,
                color: color,
                currentFontSize: 22,
                previousFontSize: 22,
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
                const SizedBox(height: 7),
                Divider(
                  height: 1,
                  thickness: .5,
                  color: Colors.white.withOpacity(.5),
                ),
                const SizedBox(height: 7),
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
        // 1. Header chỉ còn tên metric và delta.
        Row(
          children: [
            Expanded(
              child: Text(
                _displayName(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(.78),
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (item.deltaPercent != null) ...[
              const SizedBox(width: 6),
              _MetricDeltaBadge(delta: item.deltaPercent),
            ],
          ],
        ),

        const SizedBox(height: 3),

        // 2. Water luôn hiển thị dạng JAN 2026 AVG.
        _MetricPeriodLabel(text: _monthlyPeriodLabel(item), color: color),

        const SizedBox(height: 3),

        // 3. Current và previous dùng cùng format với điện/khí nén.
        _MetricValueRow(
          current: _formatUtilityValue(item, item.displayValue, unit),
          previous: _formatUtilityValue(item, item.previousDisplayValue, unit),
          color: color,
          currentFontSize: 22,
          previousFontSize: 22,
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
