import 'package:flutter/material.dart';

import '../../../utility_state/chart_catalog_provider.dart';
import '../utility_minute_chart_panel.dart';

class UtilityMinuteChartGrid extends StatelessWidget {
  final List<SignalChartConfig> charts;
  final String facId;
  final String cate;
  final String? scadaId;

  const UtilityMinuteChartGrid({
    super.key,
    required this.charts,
    required this.facId,
    required this.cate,
    required this.scadaId,
  });

  int _columnCount(double width) {
    if (width >= 1700) return 3;
    if (width >= 1150) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          key: const PageStorageKey<String>('utility-minute-grid'),
          padding: const EdgeInsets.only(top: 4),
          cacheExtent: constraints.maxHeight * .30,
          addRepaintBoundaries: false,
          addAutomaticKeepAlives: false,
          addSemanticIndexes: false,
          itemCount: charts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columnCount(constraints.maxWidth),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 16 / 10,
          ),
          itemBuilder: (context, index) {
            final chart = charts[index];

            return RepaintBoundary(
              key: ValueKey<String>(
                '${facId}_'
                '${cate}_'
                '${scadaId ?? ''}_'
                '${chart.boxDeviceId}_'
                '${chart.plcAddress}',
              ),
              child: UtilityMinuteChartPanel(
                facId: facId,
                scadaId: scadaId,
                cate: cate,
                boxDeviceId: chart.boxDeviceId,
                plcAddress: chart.plcAddress,
                cateIds: chart.cateIds,
              ),
            );
          },
        );
      },
    );
  }
}
