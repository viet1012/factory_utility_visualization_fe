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
import 'water_check_format.dart';

/// Diem do can mo chart (dialog) / chuyen sang CHARTS › Minutes.
class WaterSignalRef {
  final String facId;
  final String boxDeviceId;
  final String plcAddress;
  final String name;
  final String deviceName;
  final String unit;

  const WaterSignalRef({
    required this.facId,
    required this.boxDeviceId,
    required this.plcAddress,
    required this.name,
    required this.deviceName,
    required this.unit,
  });
}

/// Chart 1h (bucket=1m) cua mot diem do, dung lai the Minutes cua CHARTS.
///
/// Dialog nam tren Navigator, ngoai cay Provider cua dashboard: lay cac
/// dependency tu [context] cua tab roi cap lai cho dialog.
Future<void> showWaterSignalChartDialog(
  BuildContext context, {
  required WaterSignalRef signal,
  required void Function(WaterSignalRef signal) onOpenInCharts,
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
  final VoidCallback onOpenInCharts;

  const _WaterSignalChartDialog({
    required this.signal,
    required this.repository,
    required this.catalog,
    required this.polling,
    required this.onOpenInCharts,
  });

  @override
  State<_WaterSignalChartDialog> createState() =>
      _WaterSignalChartDialogState();
}

class _WaterSignalChartDialogState extends State<_WaterSignalChartDialog> {
  late final UtilityMinuteChartController _chart;
  late final String _taskId;

  @override
  void initState() {
    super.initState();

    _chart = UtilityMinuteChartController(
      repository: widget.repository,
      window: const Duration(minutes: 60),
      requestTimeout: const Duration(seconds: 15),
    );

    unawaited(
      _chart.load(
        plcsByBox: {
          widget.signal.boxDeviceId: [widget.signal.plcAddress],
        },
      ),
    );

    // Lam moi theo scope WATER CHECK: dung khi tab an / trinh duyet an.
    _taskId = PollingTaskIds.waterCheckSignalChart(this);
    if (!widget.polling.isDisposed) {
      widget.polling
        ..register(
          id: _taskId,
          scope: PollingScope.waterCheck,
          interval: DashboardPollingIntervals.chartsMinuteSeries,
          action: _chart.poll,
        )
        ..start(_taskId);
    }
  }

  @override
  void dispose() {
    widget.polling.unregister(_taskId);
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return UtilityMinuteChartPanel(
                        facId: signal.facId,
                        cate: 'Water',
                        boxDeviceId: signal.boxDeviceId,
                        plcAddress: signal.plcAddress,
                        signalName: signal.name,
                        unit: signal.unit,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
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
