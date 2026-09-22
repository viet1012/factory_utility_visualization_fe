import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../utility_api/dio_client.dart';
import 'api/solar_api.dart';
import 'helpers/solar_detail_formatters.dart';
import 'models/solar_detail_data.dart';
import 'widgets/solar_daily_generation_panel.dart';
import 'widgets/solar_detail_header.dart';
import 'widgets/solar_detail_kpi_section.dart';
import 'widgets/solar_energy_source_panel.dart';
import 'widgets/solar_hourly_profile_panel.dart';
import 'widgets/solar_impact_panel.dart';

class SolarDetailScreen extends StatefulWidget {
  final String facId;

  /// yyyyMM
  /// Ví dụ: 202608
  final String month;

  const SolarDetailScreen({
    super.key,
    required this.facId,
    required this.month,
  });

  @override
  State<SolarDetailScreen> createState() => _SolarDetailScreenState();
}

class _SolarDetailScreenState extends State<SolarDetailScreen> {
  // ============================================================
  // API
  // ============================================================

  late final SolarApi _api = SolarApi(DioClient.dio);

  // ============================================================
  // STATE
  // ============================================================

  SolarDetailData? _data;

  bool _loading = true;
  bool _refreshing = false;

  String? _error;

  int _requestVersion = 0;

  Timer? _refreshTimer;

  /// Detail không cần query liên tục.
  /// 1 tiếng refresh một lần.
  static const Duration _refreshInterval = Duration(hours: 1);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _load();

    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant SolarDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final facChanged = oldWidget.facId != widget.facId;

    final monthChanged = oldWidget.month != widget.month;

    if (facChanged || monthChanged) {
      _requestVersion++;

      _load(mainLoading: true);
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || _refreshing) {
        return;
      }

      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _requestVersion++;

    _refreshTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // API LOAD
  // ============================================================

  Future<void> _load({bool silent = false, bool mainLoading = false}) async {
    if (!mounted) return;

    final requestVersion = ++_requestVersion;

    final fac = widget.facId.trim().isEmpty ? 'KVH' : widget.facId.trim();

    final month = widget.month.trim();

    if (month.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Month is required';
      });

      return;
    }

    if (!silent) {
      setState(() {
        if (mainLoading || _data == null) {
          _loading = true;
        } else {
          _refreshing = true;
        }

        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final result = await _api.getDetail(facId: fac, month: month);

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _data = result;

        _loading = false;
        _refreshing = false;

        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _refreshing = false;

        _error = _dioError(e);
      });
    } catch (e) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _refreshing = false;

        _error = 'Cannot load Solar Detail';
      });
    }
  }

  String _dioError(DioException error) {
    final code = error.response?.statusCode;

    if (code != null) {
      return 'Solar API error: HTTP $code';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Solar API timeout';
    }

    return 'Cannot connect to Solar API';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SolarDetailColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _background()),

            Column(
              children: [
                SolarDetailHeader(
                  facId: widget.facId,
                  monthLabel: SolarDetailFormatters.monthLabel(widget.month),
                  refreshing: _refreshing,
                  onBack: () => Navigator.of(context).pop(),
                  onRefresh: () => _load(),
                ),

                Expanded(child: _body()),
              ],
            ),

            if (_refreshing)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: SolarDetailColors.cyan,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _background() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [Color(0xff07263d), Color(0xff020b15)],
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _body() {
    if (_loading && _data == null) {
      return const Center(
        child: CircularProgressIndicator(color: SolarDetailColors.cyan),
      );
    }

    if (_error != null && _data == null) {
      return _errorView();
    }

    final data = _data;

    if (data == null) {
      return _errorView();
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // =========================================================
          // TOP KPI
          // =========================================================
          SizedBox(height: 120, child: SolarDetailKpiSection(data: data)),

          const SizedBox(height: 7),

          // =========================================================
          // MIDDLE
          //
          // Monthly trend + Energy source
          // =========================================================
          Expanded(
            flex: 58,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: SolarDailyGenerationPanel(
                    data: data,
                    month: widget.month,
                  ),
                ),

                const SizedBox(width: 7),

                Expanded(flex: 3, child: SolarEnergySourcePanel(data: data)),
              ],
            ),
          ),

          const SizedBox(height: 7),

          // =========================================================
          // BOTTOM
          //
          // Hourly + Cost/Environment
          // =========================================================
          Expanded(
            flex: 42,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: SolarHourlyProfilePanel(data: data)),

                const SizedBox(width: 7),

                Expanded(
                  flex: 4,
                  child: SolarImpactPanel(data: data, month: widget.month),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Colors.redAccent,
            size: 38,
          ),

          const SizedBox(height: 10),

          Text(
            _error ?? 'No Solar data',
            style: const TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () => _load(mainLoading: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reload'),
          ),
        ],
      ),
    );
  }
}
