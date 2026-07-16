import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/widgets/utility_chart_loading_state.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/widgets/utility_minute_chart_grid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utility_state/chart_catalog_provider.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_overview/utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_all_factories_models.dart';

class UtilityDailyTab extends StatelessWidget {
  final String facId;
  final String cate;
  final String? scadaId;
  final String selectedBox;
  final bool importantOnly;

  const UtilityDailyTab({
    super.key,
    required this.facId,
    required this.cate,
    required this.scadaId,
    required this.selectedBox,
    required this.importantOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ChartCatalogProvider, CatalogBodyVm>(
      selector: (_, provider) {
        return CatalogBodyVm(
          loading: provider.loading,
          error: provider.error,
          charts: provider.charts,
        );
      },
      shouldRebuild: (previous, next) {
        return previous.loading != next.loading ||
            previous.error != next.error ||
            !identical(previous.charts, next.charts);
      },
      builder: (context, vm, _) {
        if (vm.loading && vm.charts.isEmpty) {
          return UtilityChartLoadingState(cate: cate);
        }

        if (vm.error != null && vm.charts.isEmpty) {
          return ChartApiErrorState(
            color: ChartThemes.byCate(cate).line,
            onRetry: () {
              context.read<ChartCatalogProvider>().loadCatalog(
                facId: facId,
                cate: cate,
                importantOnly: importantOnly ? 1 : 0,
                forceRefresh: true,
              );
            },
          );
        }

        if (vm.charts.isEmpty) {
          return EmptyChartState(
            icon: Icons.sensors_off_rounded,
            title: 'No Signals Available',
            message:
                'No utility signals found in '
                '$selectedBox / ${scadaId ?? "-"}',
            color: Colors.white.withOpacity(.58),
          );
        }

        return UtilityMinuteChartGrid(
          charts: vm.charts,
          facId: facId,
          cate: cate,
          scadaId: scadaId,
        );
      },
    );
  }
}
