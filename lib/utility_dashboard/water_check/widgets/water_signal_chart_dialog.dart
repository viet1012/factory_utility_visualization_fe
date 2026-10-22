import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/polling/dashboard_polling_intervals.dart';
import '../../shared/polling/polling_coordinator.dart';
import '../../shared/polling/polling_scope.dart';
import '../../shared/polling/polling_task_ids.dart';
import '../../utility_all_factory_chart/controllers/utility_chart_catalog_controller.dart';
import '../../utility_all_factory_chart/controllers/utility_minute_chart_controller.dart';
import '../../utility_all_factory_chart/widgets/utility_minute_chart_panel.dart';
import '../../utility_catalog/api/signal_history_repository.dart';
import '../models/water_check_models.dart';
import 'water_check_format.dart';

/// Diem do can mo chart (dialog) / chuyen sang CHARTS › Minutes.
class WaterSignalRef {
  final String facId;
  final String boxDeviceId;
  final String plcAddress;
  final String name;
  final String deviceName;
  final String unit;

  /// Mau moi nhat + gio cua diem do tren board (dong tren dau dialog va
  /// diem cuoi cua chart).
  final double? value;
  final DateTime? recordedAt;

  /// Nhom muc nuoc: cua so median truot (status danh gia theo median).
  final Duration? medianWindow;

  const WaterSignalRef({
    required this.facId,
    required this.boxDeviceId,
    required this.plcAddress,
    required this.name,
    required this.deviceName,
    required this.unit,
    this.value,
    this.recordedAt,
    this.medianWindow,
  });

  factory WaterSignalRef.of(
    String facId,
    WaterSignal signal,
    WaterGroup group,
  ) {
    return WaterSignalRef(
      facId: facId,
      boxDeviceId: signal.boxDeviceId,
      plcAddress: signal.plcAddress,
      name: signal.name,
      deviceName: signal.deviceName,
      unit: group.unit,
      value: waterDisplayValue(signal),
      recordedAt: signal.recordedAt,
      medianWindow: group.isLevel ? group.config.levelMedianWindow : null,
    );
  }

  String get key => waterSignalKey(facId, boxDeviceId, plcAddress);
}

/// Chart 1h (bucket=1m) cua mot diem do, dung lai the Minutes cua CHARTS.
///
/// Dialog nam tren Navigator, ngoai cay Provider cua dashboard: lay cac
/// dependency tu [context] cua tab roi cap lai cho dialog.
///
/// [board] + [resolve]: dong gia tri tren dau theo board moi nhat;
/// [boardVersion]: doi moi lan board poll xong -> tai lai series (khong co
/// thi chart tu poll theo chu ky Minutes); [onLoaded]: goi mot lan khi
/// chart tai xong (lam moi board).
Future<void> showWaterSignalChartDialog(
  BuildContext context, {
  required WaterSignalRef signal,
  required void Function(WaterSignalRef signal) onOpenInCharts,
  Listenable? board,
  WaterSignalRef? Function(String key)? resolve,
  Object? Function()? boardVersion,
  VoidCallback? onLoaded,
}) {
  final repository = context.read<SignalHistoryRepository>();
  final catalog = context.read<UtilityChartCatalogController>();
  final polling = context.read<PollingCoordinator>();

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .6),
    builder: (dialogContext) => _WaterSignalChartDialog(
      signal: signal,
      repository: repository,
      catalog: catalog,
      polling: polling,
      board: board,
      resolve: resolve,
      boardVersion: boardVersion,
      onLoaded: onLoaded,
      onOpenInCharts: () {
        Navigator.of(dialogContext).pop();
        onOpenInCharts(signal);
      },
    ),
  );
}

class _WaterSignalChartDialog extends StatefulWidget {
  final WaterSignalRef signal;
  final SignalHistoryRepository repository;
  final UtilityChartCatalogController catalog;
  final PollingCoordinator polling;
  final Listenable? board;
  final WaterSignalRef? Function(String key)? resolve;
  final Object? Function()? boardVersion;
  final VoidCallback? onLoaded;
  final VoidCallback onOpenInCharts;

  const _WaterSignalChartDialog({
    required this.signal,
    required this.repository,
    required this.catalog,
    required this.polling,
    this.board,
    this.resolve,
    this.boardVersion,
    this.onLoaded,
    required this.onOpenInCharts,
  });

  @override
  State<_WaterSignalChartDialog> createState() =>
      _WaterSignalChartDialogState();
}

class _WaterSignalChartDialogState extends State<_WaterSignalChartDialog> {
  static final Listenable _never = ChangeNotifier();

  late final UtilityMinuteChartController _chart;
  String? _taskId;

  /// Response board da dung cho lan tai series gan nhat.
  Object? _boardVersion;

  bool get _followsBoard =>
      widget.board != null && widget.boardVersion != null;

  @override
  void initState() {
    super.initState();

    // Cua so toi hien tai, gom ca bucket phut dang chay.
    _chart = UtilityMinuteChartController(
      repository: widget.repository,
      window: const Duration(minutes: 60),
      requestTimeout: const Duration(seconds: 15),
      includeRunningBucket: true,
    );
    _boardVersion = widget.boardVersion?.call();

    // Tai xong: lam moi board de gia tri tren dau khop voi chart.
    unawaited(
      _chart
          .load(
            plcsByBox: {
              widget.signal.boxDeviceId: [widget.signal.plcAddress],
            },
          )
          .then((_) {
            if (mounted) widget.onLoaded?.call();
          }, onError: (_) {}),
    );

    if (_followsBoard) {
      // Tai lai series moi lan board poll xong (15s): chart va header cung
      // nhip. Board da dung theo scope WATER CHECK khi tab / trinh duyet an.
      widget.board!.addListener(_onBoardChanged);
      return;
    }

    // Khong co board: tu lam moi theo scope WATER CHECK.
    final taskId = _taskId = PollingTaskIds.waterCheckSignalChart(this);
    if (!widget.polling.isDisposed) {
      widget.polling
        ..register(
          id: taskId,
          scope: PollingScope.waterCheck,
          interval: DashboardPollingIntervals.chartsMinuteSeries,
          action: _chart.poll,
        )
        ..start(taskId);
    }
  }

  void _onBoardChanged() {
    final version = widget.boardVersion!.call();
    if (version == null || identical(version, _boardVersion)) return;

    _boardVersion = version;
    unawaited(_chart.poll().catchError((_) {}));
  }

  @override
  void dispose() {
    if (_followsBoard) widget.board!.removeListener(_onBoardChanged);
    final taskId = _taskId;
    if (taskId != null) widget.polling.unregister(taskId);
    _chart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signal = widget.signal;
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * .62).clamp(640.0, 980.0);
    final height = (size.height * .62).clamp(360.0, 560.0);

    return Dialog(
      backgroundColor: const Color(0xFF071425),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: kWaterAccent.withValues(alpha: .35)),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        signal.facId,
                        if (signal.deviceName.isNotEmpty) signal.deviceName,
                        signal.name,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kWaterTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onOpenInCharts,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open in Charts'),
                    style: TextButton.styleFrom(foregroundColor: kWaterAccent),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: kWaterTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: MultiProvider(
                  providers: [
                    ChangeNotifierProvider<UtilityMinuteChartController>.value(
                      value: _chart,
                    ),
                    ChangeNotifierProvider<UtilityChartCatalogController>.value(
                      value: widget.catalog,
                    ),
                  ],
                  child: ListenableBuilder(
                    listenable: widget.board ?? _never,
                    builder: (context, _) {
                      final reading =
                          widget.resolve?.call(signal.key) ?? signal;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return UtilityMinuteChartPanel(
                            facId: signal.facId,
                            cate: 'Water',
                            boxDeviceId: signal.boxDeviceId,
                            plcAddress: signal.plcAddress,
                            signalName: signal.name,
                            unit: signal.unit,
                            latestReading: ChartLatestReading(
                              value: reading.value,
                              recordedAt: reading.recordedAt,
                            ),
                            medianWindow: reading.medianWindow,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
