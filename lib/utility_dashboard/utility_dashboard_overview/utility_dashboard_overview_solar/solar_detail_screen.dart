import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../utility_api/dio_client.dart';
import '../../shared/polling/dashboard_polling_intervals.dart';
import '../../shared/polling/polling_coordinator.dart';
import '../../shared/polling/polling_scope.dart';
import '../../shared/polling/polling_task_ids.dart';
import 'api/solar_api.dart';
import 'helpers/solar_detail_formatters.dart';
import 'models/solar_detail_data.dart';
import 'models/solar_hourly_by_facility.dart';
import 'widgets/solar_daily_generation_panel.dart';
import 'widgets/solar_detail_header.dart';
import 'widgets/solar_detail_kpi_section.dart';
import 'widgets/solar_energy_source_panel.dart';
import 'widgets/solar_hourly_by_facility_panel.dart';
import 'widgets/solar_impact_panel.dart';

class SolarDetailScreen extends StatefulWidget {
  final String facId;

  /// yyyyMM
  /// Ví dụ: 202608
  final String month;

  /// Route duoc push ngoai MultiProvider cua dashboard nen nhan truc tiep.
  final PollingCoordinator pollingCoordinator;

  const SolarDetailScreen({
    super.key,
    required this.facId,
    required this.month,
    required this.pollingCoordinator,
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

  /// Hourly by facility: tai rieng theo ngay, doi ngay khong tai lai detail.
  late DateTime _hourlyDate = _defaultHourlyDate();

  SolarHourlyByFacility? _hourly;

  bool _hourlyLoading = false;

  String? _hourlyError;

  int _hourlyVersion = 0;

  /// Moi instance mot task id (route co the bi push hai lan).
  late final String _pollingTaskId = PollingTaskIds.solarDetail(this);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _load();

    _loadHourly();

    _startPolling();
  }

  @override
  void didUpdateWidget(covariant SolarDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final facChanged = oldWidget.facId != widget.facId;

    final monthChanged = oldWidget.month != widget.month;

    if (facChanged || monthChanged) {
      _requestVersion++;

      _load(mainLoading: true);

      if (monthChanged) _hourlyDate = _defaultHourlyDate();

      _loadHourly();
    }
  }

  /// Detail khong can query lien tuc: 1 tieng mot lan, qua PollingCoordinator
  /// de dung khi tab trinh duyet an. Chu ky >= 1h nen hien lai chi tai ngay
  /// khi lan thanh cong gan nhat da qua 1h (khong reset lich).
  void _startPolling() {
    final coordinator = widget.pollingCoordinator;

    coordinator.register(
      id: _pollingTaskId,
      scope: PollingScope.solarDetail,
      interval: DashboardPollingIntervals.solarDetail,
      action: _poll,
    );
    coordinator.activateScope(PollingScope.solarDetail);
    coordinator.start(_pollingTaskId);
  }

  Future<void> _poll() async {
    if (!mounted || _refreshing) return;

    // Hourly chi lam moi khi dang xem hom nay; ngay da qua khong doi.
    final hourly = _isViewingHourlyToday
        ? _loadHourly(silent: true)
        : Future<void>.value();

    await _load(silent: true);
    await hourly;

    // _load tu bat loi; nem lai de PollingCoordinator khong tinh la lan
    // thanh cong (quy tac chay bu dua tren lan thanh cong gan nhat).
    final error = _error;
    if (error != null) throw StateError(error);
  }

  @override
  void dispose() {
    _requestVersion++;
    _hourlyVersion++;

    final coordinator = widget.pollingCoordinator;
    coordinator.unregister(_pollingTaskId);
    coordinator.deactivateScope(PollingScope.solarDetail);

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

  // ============================================================
  // HOURLY BY FACILITY
  // ============================================================

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// yyyyMM -> ngay 1 cua thang; null khi sai dinh dang.
  DateTime? _monthStart() {
    final value = widget.month.trim();
    if (value.length != 6) return null;

    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(4, 6));
    if (year == null || month == null || month < 1 || month > 12) return null;

    return DateTime(year, month);
  }

  DateTime _hourlyFirstDate() => _monthStart() ?? _today();

  /// Ngay cuoi chon duoc: cuoi thang, khong qua hom nay.
  DateTime _hourlyLastDate() {
    final start = _monthStart();
    if (start == null) return _today();

    final monthEnd = DateTime(start.year, start.month + 1, 0);
    final today = _today();

    if (!monthEnd.isAfter(today)) return monthEnd;

    // Thang hien tai (hoac tuong lai): dung o hom nay, khong truoc ngay 1.
    return today.isBefore(start) ? start : today;
  }

  /// Hom nay neu thang dang chon la thang hien tai, nguoc lai ngay cuoi thang.
  DateTime _defaultHourlyDate() {
    final start = _monthStart();
    final today = _today();

    if (start == null) return today;

    if (start.year == today.year && start.month == today.month) return today;

    return DateTime(start.year, start.month + 1, 0);
  }

  bool get _isViewingHourlyToday => _hourlyDate == _today();

  void _onHourlyDateChanged(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    final first = _hourlyFirstDate();
    final last = _hourlyLastDate();

    if (day.isBefore(first) || day.isAfter(last)) return;
    if (day == _hourlyDate) return;

    setState(() => _hourlyDate = day);

    _loadHourly();
  }

  Future<void> _loadHourly({bool silent = false}) async {
    if (!mounted) return;

    final version = ++_hourlyVersion;

    final fac = widget.facId.trim().isEmpty ? 'KVH' : widget.facId.trim();

    final date = DateFormat('yyyy-MM-dd').format(_hourlyDate);

    if (!silent) {
      setState(() {
        _hourlyLoading = true;
        _hourlyError = null;
      });
    }

    try {
      final result = await _api.getHourly(facId: fac, date: date);

      if (!mounted || version != _hourlyVersion) return;

      setState(() {
        _hourly = _onlySelectedFac(result, fac);
        _hourlyLoading = false;
        _hourlyError = null;
      });
    } catch (e) {
      if (!mounted || version != _hourlyVersion) return;

      setState(() {
        _hourlyLoading = false;

        // Poll loi: giu chart dang co, lan poll sau thu lai.
        if (!silent || _hourly == null) {
          _hourlyError = e is DioException
              ? _hourlyDioError(e)
              : 'Cannot load hourly solar data';
        }
      });
    }
  }

  /// Header chon 1 fac thi chi giu fac do (backend thuong da loc san).
  SolarHourlyByFacility _onlySelectedFac(
    SolarHourlyByFacility data,
    String fac,
  ) {
    if (fac.toUpperCase() == 'KVH') return data;

    final matched = data.facilities
        .where((f) => f.facId.toUpperCase() == fac.toUpperCase())
        .toList(growable: false);

    if (matched.isEmpty || matched.length == data.facilities.length) {
      return data;
    }

    return SolarHourlyByFacility(
      date: data.date,
      facId: data.facId,
      facilities: matched,
      totalHours: data.totalHours,
      totalKwh: data.totalKwh,
      peakKwh: data.peakKwh,
      peakHour: data.peakHour,
    );
  }

  /// Loi 400 co truong `message`; con lai dung thong bao chung.
  String _hourlyDioError(DioException error) {
    final body = error.response?.data;

    if (body is Map) {
      final message = body['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) return message;
    }

    return _dioError(error);
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
                  onRefresh: () {
                    _load();
                    _loadHourly();
                  },
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
                    onDaySelected: _onHourlyDateChanged,
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
                Expanded(
                  flex: 6,
                  child: SolarHourlyByFacilityPanel(
                    data: _hourly,
                    date: _hourlyDate,
                    firstDate: _hourlyFirstDate(),
                    lastDate: _hourlyLastDate(),
                    loading: _hourlyLoading,
                    error: _hourlyError,
                    onDateChanged: _onHourlyDateChanged,
                    onRetry: _loadHourly,
                  ),
                ),

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
