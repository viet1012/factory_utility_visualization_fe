import 'dart:async';
import 'dart:ui';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_detail_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_common/utility_fac_style.dart';
import '../data_health.dart';
import '../utility_dashboard_api/utility_dashboard_overview_api.dart';
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
/// MODEL VOLTAGE
/// =======================
class VoltageStatus {
  final String name;
  final double minVol;
  final double maxVol;
  final String alarm;
  final DateTime timestamp;

  VoltageStatus({
    required this.name,
    required this.minVol,
    required this.maxVol,
    required this.alarm,
    required this.timestamp,
  });

  factory VoltageStatus.fromJson(Map<String, dynamic> json) {
    return VoltageStatus(
      name: json['name'] ?? '',
      minVol: (json['minVol'] as num?)?.toDouble() ?? 0,
      maxVol: (json['maxVol'] as num?)?.toDouble() ?? 0,
      alarm: json['alarm'] ?? 'Normal',
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
    );
  }

  bool get isAlarm => alarm == "Alarm";
}

/// =======================
/// WIDGET
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

// -----------------------------------------------------------------------------
// StatefulWidget
// -----------------------------------------------------------------------------
class UtilityOverviewMonthlyBox extends StatefulWidget {
  final double width;
  final double? height;
  final String facId;
  final String month;
  final String headerTitle;
  final bool isHighlighted; // 🔥 Đã có sẵn

  const UtilityOverviewMonthlyBox({
    super.key,
    required this.facId,
    required this.month,
    required this.headerTitle,
    this.width = 240,
    this.height = 220,
    this.isHighlighted = true,
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

  // 🔥 CHỈ CẦN OPACITY ANIMATION THÔI
  late final AnimationController _highlightController;
  late final Animation<double> _opacityAnimation;

  bool loading = true;
  Object? error;
  List<EnergyMonthlySummary> items = [];
  VoltageStatus? voltageStatus;

  DataHealthResult? _cachedHealth;
  bool _loadingNow = false;
  bool _disposed = false;

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

    // 🔥 CHỈ OPACITY - KHÔNG CÓ GLOW
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 🔥 Opacity: 0.5 (mờ) -> 1.0 (sáng)
    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );

    if (widget.isHighlighted) {
      _highlightController.value = 1.0;
    }

    _load();
  }

  @override
  void didUpdateWidget(covariant UtilityOverviewMonthlyBox old) {
    super.didUpdateWidget(old);

    if (old.isHighlighted != widget.isHighlighted) {
      if (widget.isHighlighted) {
        _highlightController.forward();
      } else {
        _highlightController.reverse();
      }
    }

    if (old.facId == widget.facId && old.month == widget.month) return;

    setState(() {
      loading = true;
      error = null;
      items = [];
      voltageStatus = null;
      _cachedHealth = null;
    });

    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    fx.dispose();
    _pulseController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingNow || _disposed) return;
    _loadingNow = true;

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      final results = await Future.wait([
        api.getEnergyMonthlySummary(facId: widget.facId, month: widget.month),
        api.getVoltageStatus(),
      ]);

      if (!mounted) return;

      final parsed = (results[0] as List)
          .map((e) => EnergyMonthlySummary.fromJson(e))
          .toList();
      final voltage = results[1] as VoltageStatus;

      _cachedHealth = DataHealthAnalyzer.analyze(
        key: "Monthly_${widget.facId}_${widget.headerTitle}",
        loading: false,
        error: null,
        values: [...parsed.map((e) => e.value), voltage.maxVol],
      );

      setState(() {
        items = parsed;
        voltageStatus = voltage;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    } finally {
      _loadingNow = false;
    }

    if (!_disposed) {
      Future.delayed(const Duration(seconds: 30), _load);
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

    return SlideTransition(
      position: fx.slide,
      child: AnimatedBuilder(
        animation: fx.listenable,
        builder: (_, child) =>
            Transform.scale(scale: fx.scale.value, child: child),
        // 🔥 CHỈ BỌC OPACITY - KHÔNG CÓN GLOW NỮA
        child: AnimatedBuilder(
          animation: _opacityAnimation,
          builder: (context, child) {
            return Opacity(opacity: _opacityAnimation.value, child: child);
          },
          child: _MonthlyShell(
            width: widget.width,
            height: widget.height ?? 220,
            facColor: facColor,
            // 🔥 GIỮ NGUYÊN HIỆU ỨNG GLASS - KHÔNG THAY ĐỔI
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
                    voltageStatus: voltageStatus,
                    facColor: facColor,
                    pulseAnimation: _pulseAnimation,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥 _MonthlyShell - GIỮ NGUYÊN HIỆU ỨNG GLASS, KHÔNG THAY ĐỔI
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
    // 🔥 GIỮ NGUYÊN STYLE CŨ - KHÔNG THAY ĐỔI GÌ CẢ
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
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: child,
        ),
      ),
    );
  }
}
// -----------------------------------------------------------------------------
// _Body — StatelessWidget, nhận data từ ngoài, không giữ state
// -----------------------------------------------------------------------------

class _Body extends StatelessWidget {
  final bool loading;
  final Object? error;
  final List<EnergyMonthlySummary> items;
  final VoltageStatus? voltageStatus;
  final Color facColor;
  final Animation<double> pulseAnimation;

  const _Body({
    required this.loading,
    required this.error,
    required this.items,
    required this.voltageStatus,
    required this.facColor,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: CircularProgressIndicator(color: facColor, strokeWidth: 2),
      );
    }

    if (error != null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: Color(0xFFEF5350), size: 28),
            SizedBox(height: 6),
            Text(
              'API Error',
              style: TextStyle(color: Color(0xFFEF5350), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 20),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        children: [
          if (voltageStatus != null) ...[
            // không kéo energy rows repaint theo
            RepaintBoundary(
              child: _VoltageCard(
                status: voltageStatus!,
                pulseAnimation: pulseAnimation,
              ),
            ),
            const SizedBox(height: 4),
          ],
          const _Divider(),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) => _EnergyRow(item: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// _Divider — const, zero cost
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// _VoltageCard — StatelessWidget, pulse animation scope h?p
// -----------------------------------------------------------------------------

class _VoltageCard extends StatelessWidget {
  final VoltageStatus status;
  final Animation<double> pulseAnimation;

  const _VoltageCard({required this.status, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    final alarm = status.isAlarm;
    final color = alarm ? const Color(0xFFEF5350) : const Color(0xFFFFB300);

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: 1400,
            height: 600,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: VoltageDetailChart(
              api: context.read<UtilityDashboardOverviewApi>(),
            ),
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 6),

        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(alarm ? 0.6 : 0.25)),
        ),
        child: Row(
          children: [
            // Pulse icon — AnimatedBuilder scope nh? nh?t có th?
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (_, child) => Transform.scale(
                scale: alarm ? pulseAnimation.value : 1.0,
                child: child,
              ),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                ),
                child: Icon(Icons.bolt_rounded, color: color, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Voltage',
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (alarm) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF5350).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFEF5350),
                              width: 0.5,
                            ),
                          ),
                          child: const Text(
                            'ALARM',
                            style: TextStyle(
                              color: Color(0xFFEF5350),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _VoltageChip(
                        label: 'MIN',
                        value: status.minVol,
                        color: Colors.white60,
                      ),
                      const SizedBox(width: 12),
                      // Ch? MAX chip pulse khi alarm
                      AnimatedBuilder(
                        animation: pulseAnimation,
                        builder: (_, child) => Transform.scale(
                          scale: alarm ? pulseAnimation.value : 1.0,
                          child: child,
                        ),
                        child: _VoltageChip(
                          label: 'MAX',
                          value: status.maxVol,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withOpacity(0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// _VoltageChip — const-friendly StatelessWidget
// -----------------------------------------------------------------------------

class _VoltageChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _VoltageChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: '${value.toStringAsFixed(0)} V',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// _EnergyRow — StatelessWidget, TweenAnimationBuilder scope h?p
// -----------------------------------------------------------------------------

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
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          // TweenAnimationBuilder ch? rebuild Text này, không ?nh hu?ng gì khác
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: item.value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, __) => Text(
              '${_format(v)} ${item.unit}',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
