import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_common/utility_fac_style.dart';
import '../data_health.dart';
import '../utility_dashboard_overview_widgets/utility_info_box_header.dart';

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

  List<Map<String, dynamic>> items = [];

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final dio = context.read<Dio>();

      final res = await dio.get(
        '/api/utility/energy-monthly-summary',
        queryParameters: {
          'facId': widget.facId,
          'month': widget.month,
          'names': ['Total Energy Consumption'],
        },
      );

      if (!mounted) return;

      final List data = res.data as List;

      final parsed = data.map<Map<String, dynamic>>((e) {
        return {
          'name': _normalizeName(e['name'] ?? ''),
          'value': (e['value'] as num?)?.toDouble() ?? 0,
          'cate': e['cate'] ?? '',
          'unit': e['unit'] ?? '',
        };
      }).toList();

      setState(() {
        items = parsed;
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
    super.dispose();
  }

  String _format(double v) {
    if (v >= 1000) return v.toStringAsFixed(1);
    if (v >= 100) return v.toStringAsFixed(2);
    return v.toStringAsFixed(3);
  }

  IconData _iconByCate(String cate) {
    switch (cate) {
      case 'Electricity':
        return Icons.flash_on;
      case 'Water':
        return Icons.water_drop;
      case 'Compressed Air':
        return Icons.air;
      default:
        return Icons.device_unknown;
    }
  }

  Color _colorByCate(String cate) {
    switch (cate) {
      case 'Electricity':
        return Colors.orangeAccent;
      case 'Water':
        return Colors.lightBlueAccent;
      case 'Compressed Air':
        return Colors.cyanAccent;
      default:
        return Colors.white70;
    }
  }

  String _normalizeName(String name) {
    switch (name) {
      case 'Total Energy Consumption':
        return 'Total Energy';
      case 'Total Water Consumption':
        return 'TOTAL WATER';
      default:
        return name.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityColor = UtilityFacStyle.colorFromFac(widget.headerTitle);

    final healthResult = DataHealthAnalyzer.analyze(
      loading: loading,
      error: error,
      timestamps: items.isNotEmpty
          ? List.generate(items.length, (_) => DateTime.now())
          : [],
      values: items.map((e) => e['value'] as double).toList(),
    );

    return SlideTransition(
      position: fx.slide,
      child: AnimatedBuilder(
        animation: fx.listenable,
        builder: (context, child) {
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
      border: Border.all(color: facilityColor.withOpacity(0.3), width: 1),
      boxShadow: [
        BoxShadow(
          color: facilityColor.withOpacity(0.25),
          blurRadius: 22,
          spreadRadius: 2,
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

  Widget _body() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (error != null) {
      return const Center(
        child: Text(
          'API error',
          style: TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final cate = item['cate'] as String;
        final value = item['value'] as double;
        final unit = item['unit'] as String;
        final color = _colorByCate(cate);

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color.withOpacity(0.8), width: 1),
                ),
                child: Icon(_iconByCate(cate), color: color, size: 20),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: const Duration(milliseconds: 800),
                builder: (_, v, __) {
                  return Text(
                    "${_format(v)} $unit",
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
    );
  }
}
