import 'package:flutter/material.dart';

import 'utility_minute_chart_panel.dart';

class FacChartConfig {
  final String facId;
  final List<SignalChartConfig> charts;

  const FacChartConfig({required this.facId, required this.charts});
}

class SignalChartConfig {
  final String boxDeviceId;
  final String plcAddress;
  final List<String>? cateIds;

  const SignalChartConfig({
    required this.boxDeviceId,
    required this.plcAddress,
    this.cateIds,
  });
}

class UtilityAllFactoriesChartsScreen extends StatefulWidget {
  const UtilityAllFactoriesChartsScreen({super.key});

  @override
  State<UtilityAllFactoriesChartsScreen> createState() =>
      _UtilityAllFactoriesChartsScreenState();
}

class _UtilityAllFactoriesChartsScreenState
    extends State<UtilityAllFactoriesChartsScreen> {
  // ✅ demo config
  final List<FacChartConfig> facs = const [
    FacChartConfig(
      facId: 'Fac_A',
      charts: [
        SignalChartConfig(
          boxDeviceId: 'DB-P1_400A',
          plcAddress: 'D1',
          cateIds: ['E_Cur1'],
        ),
      ],
    ),
    FacChartConfig(
      facId: 'Fac_B',
      charts: [
        SignalChartConfig(
          boxDeviceId: 'DPB-L2-PANNEL_CB-80A',
          plcAddress: 'D18',
          cateIds: ['E_TTL_KW'],
        ),
        SignalChartConfig(
          boxDeviceId: 'DPB-L2-PANNEL_CB-80A',
          plcAddress: 'D20',
          cateIds: ['E_TTL_KW'],
        ),
        SignalChartConfig(
          boxDeviceId: 'DPB-L2-PANNEL-CB-80A',
          plcAddress: 'D22',
          cateIds: ['E_TTL_KW'],
        ),
        SignalChartConfig(
          boxDeviceId: 'DPB-L2-PANNEL_CB-80A',
          plcAddress: 'D24',
          cateIds: ['E_TTL_KW'],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // flatten list: (fac, chart)
    final items = <({String facId, SignalChartConfig c})>[];
    for (final f in facs) {
      for (final c in f.charts) {
        items.add((facId: f.facId, c: c));
      }
    }

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0a0e27), Color(0xFF1a1a2e), Color(0xFF16213e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            var cross = 1;
            if (w >= 1200) cross = 2;
            if (w >= 1700) cross = 3;

            return GridView.builder(
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 16 / 10,
              ),
              itemBuilder: (context, i) {
                final facId = items[i].facId;
                final cfg = items[i].c;

                return UtilityMinuteChartPanel(
                  facId: facId,
                  boxDeviceId: cfg.boxDeviceId,
                  plcAddress: cfg.plcAddress,
                  cateIds: cfg.cateIds,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
