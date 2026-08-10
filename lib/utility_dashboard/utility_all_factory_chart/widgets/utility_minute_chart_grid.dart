import 'package:flutter/material.dart';

import '../../../utility_state/chart_catalog_provider.dart';
import '../utility_minute_chart_panel.dart';

class UtilityMinuteChartGrid extends StatelessWidget {
  final List<SignalChartConfig> charts;
  final String facId;
  final String cate;
  final String? scadaId;

  /// DEVICE đang chọn, không phải BOX GROUP.
  final String selectedBox;

  const UtilityMinuteChartGrid({
    super.key,
    required this.charts,
    required this.facId,
    required this.cate,
    required this.scadaId,
    required this.selectedBox,
  });

  int _columnCount(double width) {
    if (width >= 1700) return 3;
    if (width >= 1150) return 2;
    return 1;
  }

  List<SignalChartConfig> _displayCharts() {
    final selected = selectedBox.trim().toUpperCase();

    if (selected.isEmpty || selected == 'ALL') {
      return charts;
    }

    return charts
        .where((chart) {
          return chart.boxDeviceId.trim().toUpperCase() == selected;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final displayCharts = _displayCharts();

    if (displayCharts.isEmpty) {
      return Center(
        child: Text(
          'No chart found for $selectedBox',
          style: TextStyle(
            color: Colors.white.withOpacity(.70),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          key: PageStorageKey<String>(
            'utility-minute-grid|'
            '$facId|'
            '${scadaId ?? ''}|'
            '${selectedBox.trim().toUpperCase()}',
          ),
          padding: const EdgeInsets.only(top: 4),
          cacheExtent: constraints.maxHeight * .30,
          addRepaintBoundaries: false,
          addAutomaticKeepAlives: false,
          addSemanticIndexes: false,
          itemCount: displayCharts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columnCount(constraints.maxWidth),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 16 / 10,
          ),
          itemBuilder: (context, index) {
            final chart = displayCharts[index];

            final boxDeviceId = chart.boxDeviceId.trim();
            final plcAddress = chart.plcAddress.trim();

            return RepaintBoundary(
              key: ValueKey<String>(
                '$facId|'
                '$cate|'
                '${scadaId ?? ''}|'
                '$boxDeviceId|'
                '$plcAddress',
              ),
              child: UtilityMinuteChartPanel(
                facId: facId,
                scadaId: scadaId,
                cate: cate,
                boxDeviceId: boxDeviceId,
                plcAddress: plcAddress,
              ),
            );
          },
        );
      },
    );
  }
}
