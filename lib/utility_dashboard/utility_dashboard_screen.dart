import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utility_api/utility_api.dart';
import '../utility_state/latest_provider.dart';
import 'ultility_dashboard_helper/scada_tab_bar.dart';
import 'ultility_dashboard_widgets/utility_dashboard_map.dart';

class UtilityDashboardScreen extends StatefulWidget {
  const UtilityDashboardScreen({super.key});

  @override
  State<UtilityDashboardScreen> createState() => _UtilityDashboardScreenState();
}

class _UtilityDashboardScreenState extends State<UtilityDashboardScreen> {
  final String mainImageUrl = 'assets/images/SPC2.png';
  late final UtilityApi api;

  @override
  void initState() {
    super.initState();
    api = UtilityApi(baseUrl: 'http://localhost:9999');
    // Android emulator => http://10.0.2.2:9999
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final p = LatestProvider(
          api: api,
          interval: const Duration(seconds: 2),
        );
        p.startPolling(); // ✅ chạy realtime toàn app
        return p;
      },
      child: DefaultTabController(
        length: 1,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0a0e27),
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: ScadaTabBar(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: UtilityDashboardMap(
                        api: api,
                        mainImageUrl: mainImageUrl,
                      ),
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
