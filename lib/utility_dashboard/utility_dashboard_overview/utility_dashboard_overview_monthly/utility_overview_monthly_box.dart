import 'dart:async';
import 'dart:ui';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_card.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_detail_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_common/utility_fac_style.dart';
import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_widgets/utility_info_box_header.dart';

/// =======================
/// MODEL ENERGY
/// =======================
class EnergyMonthlySummary {
  final String cate;
  final String name;
  final String month;
  final double value;
  final String unit;
  final DateTime timestamp;

  EnergyMonthlySummary({
    required this.cate,
    required this.name,
    required this.month,
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  factory EnergyMonthlySummary.fromJson(Map<String, dynamic> json) {
    return EnergyMonthlySummary(
      cate: json['cate'] ?? '',
      name: json['name'] ?? '',
      month: json['month'] ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? '',
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
    );
  }
}

/// =======================
/// Helpers
/// =======================
IconData _iconByCate(String cate) {
  switch (cate) {
    case 'Electricity':
      return Icons.bolt_rounded;
    case 'Water':
      return Icons.water_drop_rounded;
    case 'Compressed Air':
      return Icons.air_rounded;
    default:
      return Icons.device_unknown_rounded;
  }
}

Color _colorByCate(String cate) {
  switch (cate) {
    case 'Electricity':
      return const Color(0xFFFFB300);
    case 'Water':
      return const Color(0xFF29B6F6);
    case 'Compressed Air':
      return const Color(0xFF26C6DA);
    default:
      return Colors.white70;
  }
}

final _numFmt = NumberFormat('#,##0');

String _format(double v) => _numFmt.format(v);

/// =======================
/// WIDGET
/// =======================
class UtilityOverviewMonthlyBox extends StatefulWidget {
  final double width;
  final double? height;
  final String facId;
  final String month;
  final String headerTitle;
  final bool isHighlighted;
  final void Function(String facId, VoltageStatus? status)?
  onVoltageAlarmChanged;

  const UtilityOverviewMonthlyBox({
    super.key,
    required this.facId,
    required this.month,
    required this.headerTitle,
    this.width = 210,
    this.height = 220,
    this.isHighlighted = true,
    this.onVoltageAlarmChanged,
  });

  @override
  State<UtilityOverviewMonthlyBox> createState() =>
      _UtilityOverviewMonthlyBoxState();
}

class _UtilityOverviewMonthlyBoxState extends State<UtilityOverviewMonthlyBox>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _highlightController;
  late final Animation<double> _opacityAnimation;

  bool loading = true;
  Object? error;
  List<EnergyMonthlySummary> items = const <EnergyMonthlySummary>[];
  List<VoltageStatus> voltageStatuses = const <VoltageStatus>[];

  DataHealthResult? _cachedHealth;

  bool _loadingNow = false;
  bool _disposed = false;
  bool _screenActive = true;
  bool _wasAlarm = false;

  Timer? _refreshTimer;

  static const Duration _refreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();

    fx = UtilityInfoBoxFx(this)..init();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isHighlighted ? 1.0 : 0.0,
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      _load();
    });

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || _disposed || !_screenActive) return;
      _load();
    });
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

    final sourceChanged =
        oldWidget.facId != widget.facId || oldWidget.month != widget.month;

    if (!sourceChanged) return;

    _cachedHealth = null;
    _wasAlarm = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      setState(() {
        loading = true;
        error = null;
        items = const <EnergyMonthlySummary>[];
        voltageStatuses = const <VoltageStatus>[];
      });
      _load();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _screenActive = false;
    _refreshTimer?.cancel();
    fx.dispose();
    _pulseController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingNow || _disposed || !mounted || !_screenActive) return;
    if (widget.facId.trim().isEmpty) return;

    _loadingNow = true;

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      final results = await Future.wait<dynamic>([
        api.getEnergyMonthlySummary(facId: widget.facId, month: widget.month),
        api.getVoltageStatus(facId: widget.facId),
      ]);

      if (!mounted || _disposed || !_screenActive) return;

      final parsedItems = (results[0] as List)
          .map((e) => EnergyMonthlySummary.fromJson(e))
          .toList(growable: false);

      final parsedVoltages = List<VoltageStatus>.from(
        results[1] as List<VoltageStatus>,
      );

      final alarmVoltages = parsedVoltages
          .where((e) => e.isAlarm)
          .toList(growable: false);
      final hasAlarmNow = alarmVoltages.isNotEmpty;

      final healthValues = <double>[
        ...parsedItems.map((e) => e.value).where((v) => v != 0),
        ...parsedVoltages
            .expand((v) => [v.minVol, v.maxVol])
            .where((v) => v != 0),
      ];

      final nextHealth = DataHealthAnalyzer.analyze(
        key: "Monthly_${widget.facId}_${widget.headerTitle}",
        loading: false,
        error: null,
        values: healthValues,
      );

      if (!mounted || _disposed || !_screenActive) return;

      setState(() {
        items = parsedItems;
        voltageStatuses = parsedVoltages;
        _cachedHealth = nextHealth;
        loading = false;
        error = null;
      });

      if (_wasAlarm != hasAlarmNow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _disposed || !_screenActive) return;
          widget.onVoltageAlarmChanged?.call(
            widget.facId,
            hasAlarmNow ? alarmVoltages.first : null,
          );
        });
      }

      _wasAlarm = hasAlarmNow;
    } catch (e) {
      if (!mounted || _disposed || !_screenActive) return;
      setState(() {
        error = e;
        loading = false;
      });
    } finally {
      _loadingNow = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final facColor = UtilityFacStyle.colorFromFac(widget.headerTitle);

    final healthResult =
        _cachedHealth ??
        DataHealthAnalyzer.analyze(
          key: "Monthly_${widget.facId}_${widget.headerTitle}",
          loading: loading,
          error: error,
          values: const [],
        );

    return RepaintBoundary(
      child: SlideTransition(
        position: fx.slide,
        child: AnimatedBuilder(
          animation: fx.listenable,
          builder: (_, child) {
            return Transform.scale(scale: fx.scale.value, child: child);
          },
          child: AnimatedBuilder(
            animation: _opacityAnimation,
            builder: (context, child) {
              return Opacity(opacity: _opacityAnimation.value, child: child);
            },
            child: _MonthlyShell(
              width: widget.width,
              height: widget.height ?? 220,
              facColor: facColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UtilityInfoBoxHeader.header(
                    facilityColor: facColor,
                    facTitle: widget.headerTitle,
                    healthResult: healthResult,
                  ),
                  Expanded(
                    child: _Body(
                      loading: loading,
                      error: error,
                      items: items,
                      voltageStatuses: voltageStatuses,
                      pulseAnimation: _pulseAnimation,
                      facId: widget.facId,
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
}

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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.7), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
          child: child,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final bool loading;
  final Object? error;
  final List<EnergyMonthlySummary> items;
  final List<VoltageStatus> voltageStatuses;
  final Animation<double> pulseAnimation;
  final String facId;

  const _Body({
    required this.loading,
    required this.error,
    required this.items,
    required this.voltageStatuses,
    required this.pulseAnimation,
    required this.facId,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (error != null) {
      return const Center(child: Text('API Error'));
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      );
    }

    final alarms = voltageStatuses
        .where((e) => e.isAlarm)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (alarms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RepaintBoundary(
                child: _AlarmBanner(alarms: alarms, facId: facId),
              ),
            ),
          const _Divider(),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) =>
                  RepaintBoundary(child: _EnergyRow(item: items[i])),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmBanner extends StatelessWidget {
  final List<VoltageStatus> alarms;
  final String facId;

  const _AlarmBanner({required this.alarms, required this.facId});

  void _openDetail(BuildContext context) {
    final api = context.read<UtilityDashboardOverviewApi>();

    showDialog(
      context: context,
      builder: (_) => VoltageChartDialog(api: api, facId: facId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarm = alarms.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openDetail(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.3),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voltage Alarm',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alarms.length == 1
                          ? '${alarm.boxDeviceId} exceeded threshold'
                          : '${alarms.length} issues detected - tap to view detail',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (alarms.length > 1)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${alarms.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black87, Colors.transparent],
        ),
      ),
    );
  }
}

class _EnergyRow extends StatelessWidget {
  final EnergyMonthlySummary item;

  const _EnergyRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _colorByCate(item.cate);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(_iconByCate(item.cate), color: color, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: item.value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, __) {
              return Text(
                '${_format(v)} ${item.unit}',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
