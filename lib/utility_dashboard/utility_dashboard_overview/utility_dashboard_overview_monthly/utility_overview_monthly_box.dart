import 'dart:async';

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
      timestamp: DateTime.parse(json['timestamp']),
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

  VoltageStatus({
    required this.name,
    required this.minVol,
    required this.maxVol,
    required this.alarm,
  });

  factory VoltageStatus.fromJson(Map<String, dynamic> json) {
    return VoltageStatus(
      name: json['name'] ?? '',
      minVol: (json['minVol'] as num?)?.toDouble() ?? 0,
      maxVol: (json['maxVol'] as num?)?.toDouble() ?? 0,
      alarm: json['alarm'] ?? 'Normal',
    );
  }

  bool get isAlarm => alarm == "Alarm";
}

/// =======================
/// WIDGET
/// =======================
class UtilityOverviewMonthlyBox extends StatefulWidget {
  final double width;
  final double? height;
  final String facId;
  final String month;
  final String headerTitle;

  const UtilityOverviewMonthlyBox({
    super.key,
    required this.facId,
    required this.month,
    required this.headerTitle,
    this.width = 240,
    this.height = 220,
  });

  @override
  State<UtilityOverviewMonthlyBox> createState() =>
      _UtilityOverviewMonthlyBoxState();
}

class _UtilityOverviewMonthlyBoxState extends State<UtilityOverviewMonthlyBox>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;

  bool loading = true;
  Object? error;

  List<EnergyMonthlySummary> items = [];

  VoltageStatus? voltageStatus;

  Timer? _timer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late UtilityDashboardOverviewApi api;

  @override
  void initState() {
    super.initState();

    api = context.read<UtilityDashboardOverviewApi>();

    fx = UtilityInfoBoxFx(this)..init();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _load();

    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  /// =======================
  /// LOAD DATA
  /// =======================
  Future<void> _load() async {
    try {
      final raw = await api.getEnergyMonthlySummary(
        facId: widget.facId,
        month: widget.month,
      );

      final parsed = raw.map((e) => EnergyMonthlySummary.fromJson(e)).toList();

      final voltage = await api.getVoltageStatus();

      if (!mounted) return;

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
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    fx.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// =======================
  /// ICON BY CATEGORY
  /// =======================
  IconData _iconByCate(String cate) {
    switch (cate) {
      case "Electricity":
        return Icons.flash_on;
      case "Water":
        return Icons.water_drop;
      case "Compressed Air":
        return Icons.air;
      default:
        return Icons.device_unknown;
    }
  }

  /// =======================
  /// COLOR BY CATEGORY
  /// =======================
  Color _colorByCate(String cate) {
    switch (cate) {
      case "Electricity":
        return Colors.orangeAccent;
      case "Water":
        return Colors.lightBlueAccent;
      case "Compressed Air":
        return Colors.cyanAccent;
      default:
        return Colors.white70;
    }
  }

  String _format(double v) {
    final f = NumberFormat("#,##0.##");
    return f.format(v);
  }

  /// =======================
  /// BUILD
  /// =======================
  @override
  Widget build(BuildContext context) {
    final facilityColor = UtilityFacStyle.colorFromFac(widget.headerTitle);

    final healthResult = DataHealthAnalyzer.analyze(
      loading: loading,
      error: error,
      timestamps: items.map((e) => e.timestamp).toList(),
      values: items.map((e) => e.value).toList(),
    );

    return SlideTransition(
      position: fx.slide,
      child: AnimatedBuilder(
        animation: fx.listenable,
        builder: (_, __) {
          return Transform.scale(
            scale: fx.scale.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: _decoration(facilityColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UtilityInfoBoxHeader.header(
                    facilityColor: facilityColor,
                    facTitle: widget.headerTitle,
                    healthResult: healthResult,
                  ),
                  Expanded(child: _body()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// =======================
  /// BOX STYLE
  /// =======================
  BoxDecoration _decoration(Color facilityColor) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1A237E).withOpacity(0.32),
          const Color(0xFF0D47A1).withOpacity(0.28),
        ],
      ),
      border: Border.all(color: facilityColor.withOpacity(0.3)),
      boxShadow: [
        BoxShadow(
          color: facilityColor.withOpacity(0.25),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// =======================
  /// VOLTAGE ALERT
  /// =======================
  Widget _voltageAlert() {
    if (voltageStatus == null) return const SizedBox();

    final alarm = voltageStatus!.isAlarm;
    final color = alarm ? Colors.redAccent : _colorByCate("Electricity");

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) {
              return Transform.scale(
                scale: alarm ? _pulseAnimation.value : 1,
                child: child,
              );
            },
            child: Icon(Icons.flash_on, color: color, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Voltage",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "Min: ${voltageStatus!.minVol.toStringAsFixed(1)}V   ",
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (_, child) {
                        return Transform.scale(
                          scale: alarm ? _pulseAnimation.value : 1,
                          child: child,
                        );
                      },
                      child: Text(
                        "Max: ${voltageStatus!.maxVol.toStringAsFixed(1)}V",
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// =======================
  /// BODY
  /// =======================
  Widget _body() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (error != null) {
      return const Center(
        child: Text("API error", style: TextStyle(color: Colors.redAccent)),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Text("No data", style: TextStyle(color: Colors.white70)),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) {
                return Dialog(
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
                    child: VoltageDetailChart(api: api),
                  ),
                );
              },
            );
          },
          child: _voltageAlert(),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];

              final color = _colorByCate(item.cate);

              return Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(_iconByCate(item.cate), color: color, size: 26),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: item.value),
                      duration: const Duration(milliseconds: 800),
                      builder: (_, v, __) {
                        return Text(
                          "${_format(v)} ${item.unit}",
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
