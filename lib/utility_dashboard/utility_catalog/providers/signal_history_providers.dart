import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../utility_all_factory_chart/api/utility_chart_api.dart';
import '../api/api_signal_history_repository.dart';
import '../api/signal_history_repository.dart';
import 'latest_provider.dart';
import 'signal_history_controller.dart';

/// Diem DUY NHAT chon nguon du lieu lich su signal.
///
/// Moi range (1h / 6h / 24h / 7d) dung GET /api/utility/series/history.
Provider<SignalHistoryRepository> signalHistoryRepositoryProvider() {
  return Provider<SignalHistoryRepository>(
    create: (context) {
      final latest = context.read<LatestProvider>();

      return ApiSignalHistoryRepository(
        // UtilityChartApi() dung chung DioClient.dio da init o dashboard.
        api: UtilityChartApi(),
        source: () => latest.items,
      );
    },
  );
}

/// Cung cap repository + SignalHistoryController cho cay Utility Catalog.
class SignalHistoryScope extends StatelessWidget {
  final Widget child;

  const SignalHistoryScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        signalHistoryRepositoryProvider(),
        ChangeNotifierProvider<SignalHistoryController>(
          create: (context) => SignalHistoryController(
            repository: context.read<SignalHistoryRepository>(),
          ),
        ),
      ],
      child: child,
    );
  }
}
