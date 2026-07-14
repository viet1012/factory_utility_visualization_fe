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
}

// ============================================================
// FORMATTERS
// ============================================================

final NumberFormat _numFmt = NumberFormat('#,##0');
final NumberFormat _moneyFmt = NumberFormat('#,##0');

String _format(double value) {
  return _numFmt.format(value);
}

String _formatMoney(double value) {
  return _moneyFmt.format(value);
}

String _formatCost(double? value) {
  if (value == null) {
    return '--';
  }

  return '\$${_formatMoney(value)}';
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
    this.height = 280,
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

    for (final item in _items) {
      final cate = item.cate.trim().toUpperCase();

      bool matched;

      if (filter == 'ELECTRICITY') {
        matched = cate.contains('ELECTRIC');
      } else if (filter == 'WATER') {
        matched = cate.contains('WATER');
      } else if (filter == 'AIR') {
        matched = cate.contains('AIR') || cate.contains('COMPRESSED');
      } else {
        matched = cate.contains(filter);
      }

      if (matched) {
        return <EnergyMonthlySummary>[item];
      }
    }

    return const [];
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
            child: _MonthlyShell(
              width: widget.width,
              height: widget.height ?? 220,
              facColor: facColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UtilityInfoBoxHeader.header(
                    facilityColor: headerColor.withOpacity(.3),
                    facTitle: widget.headerTitle,
                    healthResult: healthResult,
                  ),
                  Expanded(
                    child: _MonthlyBody(
                      loading: _loading,
                      error: _error,
                      items: displayItems,
                      onRetry: _load,
                    ),
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
  final double height;
  final Color facColor;
  final Widget child;

  const _MonthlyShell({
    required this.width,
    required this.height,
    required this.facColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            /// Glass blur
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: const SizedBox.expand(),
            ),

            /// Glass background
            Container(
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

            /// Top highlight
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

            /// Outer border
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withOpacity(.22),
                  width: 1.2,
                ),
              ),
            ),

            /// Glow border
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: facColor.withOpacity(.18),
                    blurRadius: 18,
                    spreadRadius: -6,
                  ),
                ],
              ),
            ),

            /// Inner border
            Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(.08)),
                ),
              ),
            ),

            /// Top reflection
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 1, color: Colors.white.withOpacity(.45)),
            ),

            /// Bottom glow
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

            /// Corner light
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

            /// Content
            Padding(padding: const EdgeInsets.all(1), child: child),
          ],
        ),
      ),
    );
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
      return const Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (error != null && items.isEmpty) {
      return _InlineState(
        icon: Icons.cloud_off_rounded,
        title: 'API Error',
        message: 'Tap to retry',
        onTap: onRetry,
      );
    }

    if (items.isEmpty) {
      return const _InlineState(
        icon: Icons.dataset_outlined,
        title: 'No Data',
        message: 'No monthly utility data.',
      );
    }

    if (items.length == 1) {
      return Center(
        child: RepaintBoundary(child: _EnergyRow(item: items.first)),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) {
        return const SizedBox(height: 8);
      },
      itemBuilder: (_, index) {
        return RepaintBoundary(child: _EnergyRow(item: items[index]));
      },
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
// ENERGY ROW
// ============================================================

class _EnergyRow extends StatelessWidget {
  final EnergyMonthlySummary item;

  const _EnergyRow({required this.item});

  String _titleByCate(ChartTheme theme) {
    final cate = item.cate.toUpperCase();

    if (cate.contains('ELECTRIC')) {
      return 'Total Energy';
    }

    if (cate.contains('WATER')) {
      return 'Water';
    }

    if (cate.contains('AIR')) {
      return 'Air';
    }

    final name = item.name.trim();

    return name.isNotEmpty ? name : theme.title;
  }

  String _previousText(String unit) {
    final previous = item.previousDisplayValue;

    if (previous == null) {
      return '--';
    }

    return '${_format(previous)} $unit';
  }

  String _valueTypeLabel() {
    final cate = item.cate.toUpperCase();

    if (cate.contains('ELECTRIC')) {
      final raw = item.month;

      if (raw.length == 6) {
        final year = raw.substring(0, 4);

        final monthNumber = int.tryParse(raw.substring(4, 6));

        if (monthNumber != null && monthNumber >= 1 && monthNumber <= 12) {
          const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];

          return '${months[monthNumber - 1]} $year MTD';
        }
      }

      return 'Monthly';
    }

    if (cate.contains('WATER')) {
      return 'Monthly Avg';
    }

    if (cate.contains('AIR')) {
      return 'Monthly Avg';
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(item.cate);

    final color = theme.iconColor;
    final title = _titleByCate(theme);

    final unit = item.unit.trim().isNotEmpty ? item.unit.trim() : theme.unit;

    final value = item.displayValue;
    final delta = item.deltaPercent;

    final isUp = delta != null && delta > 0;
    final isDown = delta != null && delta < 0;

    final cate = item.cate.toUpperCase();

    final isElectricity = cate.contains('ELECTRIC');

    final isWater = cate.contains('WATER');

    final isAir = cate.contains('AIR');

    final Color deltaColor;

    if (delta == null) {
      deltaColor = Colors.white54;
    } else if (isElectricity) {
      deltaColor = isDown ? Colors.greenAccent : Colors.redAccent;
    } else {
      deltaColor = isUp ? Colors.redAccent : Colors.greenAccent;
    }

    final IconData deltaIcon;

    if (isUp) {
      deltaIcon = Icons.arrow_upward_rounded;
    } else if (isDown) {
      deltaIcon = Icons.arrow_downward_rounded;
    } else {
      deltaIcon = Icons.remove_rounded;
    }

    final content = Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Title + type + delta
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.88),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withOpacity(.35)),
                    ),
                    child: Text(
                      _valueTypeLabel(),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  if (delta != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: deltaColor.withOpacity(.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: deltaColor.withOpacity(.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(deltaIcon, color: deltaColor, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${delta.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: deltaColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 6),

              /// Current value + previous value
              Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: value),
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeOutCubic,
                    builder: (_, animatedValue, __) {
                      return Text(
                        '${_format(animatedValue)} $unit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.45,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      value: _previousText(unit),
                      color: Colors.white70,
                      icon: Icons.history_rounded,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              /// Electricity costs
              if (isElectricity)
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        value: _formatCost(item.currentCost),
                        color: Colors.orangeAccent,
                        icon: Icons.monetization_on_outlined,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _MiniMetric(
                        value: _formatCost(item.previousCost),
                        color: Colors.white70,
                        icon: Icons.history_rounded,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );

    if (isElectricity) {
      return UtilityGlowCard.electricity(color: color, child: content);
    }

    if (isWater) {
      return UtilityGlowCard.water(color: color, child: content);
    }

    if (isAir) {
      return UtilityGlowCard.air(color: color, child: content);
    }

    return UtilityGlowCard.electricity(color: color, child: content);
  }
}

// ============================================================
// MINI METRIC
// ============================================================

class _MiniMetric extends StatelessWidget {
  final String value;
  final Color color;
  final IconData icon;

  const _MiniMetric({
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withOpacity(.9)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
