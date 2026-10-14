import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../api/signal_history_repository.dart';
import 'filter_chart_controller.dart';
import 'filter_sparkline_controller.dart';
import 'signal_history_controller.dart';

/// Cung cap SignalHistoryController (chart panel device),
/// FilterSparklineController (bang Filter results) va FilterChartController
/// cho cay Utility Catalog. Ca ba dung chung [SignalHistoryRepository] cua
/// dashboard (cache + dedupe chung voi tab Hourly).
class SignalHistoryScope extends StatelessWidget {
  final Widget child;

  const SignalHistoryScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SignalHistoryController>(
          create: (context) => SignalHistoryController(
            repository: context.read<SignalHistoryRepository>(),
          ),
        ),
        ChangeNotifierProvider<FilterSparklineController>(
          create: (context) => FilterSparklineController(
            repository: context.read<SignalHistoryRepository>(),
          ),
        ),
        // Che do Chart cua Filter results; 1h dung lai cache sparkline.
        ChangeNotifierProvider<FilterChartController>(
          create: (context) => FilterChartController(
            repository: context.read<SignalHistoryRepository>(),
            sparklines: context.read<FilterSparklineController>(),
          ),
        ),
      ],
      child: child,
    );
  }
}
