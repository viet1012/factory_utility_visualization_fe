import 'package:flutter/material.dart' hide SearchBar;
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/utility_fac_style.dart';
import '../setting_security.dart';
import '../utility_dashboard_setting_dialog/scada_form_dialog.dart';
import '../utility_dashboard_setting_models/scada_view_model.dart';
import '../utility_dashboard_setting_models/utility_scada.dart';
import '../utility_dashboard_setting_widgets/scada_card.dart';
import '../utility_dashboard_setting_widgets/setting_common_widgets.dart';
import '../utility_scada_api.dart';
import 'base_setting_screen.dart';

class UtilityScadaScreen extends StatefulWidget {
  final UtilityScadaApi api;

  const UtilityScadaScreen({super.key, required this.api});

  @override
  State<UtilityScadaScreen> createState() => _UtilityScadaScreenState();
}

class _UtilityScadaScreenState extends State<UtilityScadaScreen> {
  late final ScadaViewModel _viewModel;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _viewModel = ScadaViewModel(api: widget.api);
    _searchController = TextEditingController();
    _viewModel.loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openFormDialog({UtilityScada? item}) async {
    final result = await showDialog<UtilityScada>(
      context: context,
      builder: (_) => ScadaFormDialog(initialValue: item, isEdit: item != null),
    );

    if (result == null) return;

    try {
      if (item == null) {
        await _viewModel.createItem(result);
        _showMessage('Created successfully');
      } else if (item.id != null) {
        await _viewModel.updateItem(item.id!, result);
        _showMessage('Updated successfully');
      }
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<ScadaViewModel>(
        builder: (_, vm, __) {
          return BaseSettingScreen(
            title: 'Utility SCADA',
            loading: vm.loading,
            submitting: vm.submitting,
            error: vm.error,
            totalCount: vm.totalCount,
            filteredCount: vm.filteredCount,
            searchController: _searchController,
            onSearchChanged: vm.setSearchKeyword,
            onRefresh: vm.loadData,
            onAdd: () => _openFormDialog(),
            searchHint: 'Search by SCADA ID, FAC, PLC IP, PC name, WLAN...',
            addButtonText: 'Add SCADA',
            requireAddPassword: true,
            addPassword: SettingSecurity.editPassword,
            body: _buildBody(vm),
          );
        },
      ),
    );
  }

  Widget _buildBody(ScadaViewModel vm) {
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null) {
      return ErrorState(message: vm.error!, onRetry: vm.loadData);
    }

    if (vm.filteredItems.isEmpty) {
      return const EmptyState(message: 'No data found');
    }

    final grouped = _groupByFac(vm.filteredItems);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridConfig = _getGridConfig(constraints.maxWidth);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: grouped.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (_, index) {
            final entry = grouped.entries.elementAt(index);
            final fac = entry.key;
            final items = entry.value;
            final facColor = UtilityFacStyle.colorFromFac(fac);

            return _FacSection(
              fac: fac,
              count: items.length,
              color: facColor,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridConfig.crossAxisCount,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: gridConfig.childAspectRatio,
                ),
                itemBuilder: (_, itemIndex) {
                  final item = items[itemIndex];
                  return ScadaCard(
                    item: item,
                    accent: UtilityFacStyle.colorFromFac(item.fac),
                    disabled: vm.submitting,
                    onEdit: () => _openFormDialog(item: item),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Map<String, List<UtilityScada>> _groupByFac(List<UtilityScada> items) {
    const facOrder = ['Fac_A', 'Fac_B', 'Fac_C'];

    final map = <String, List<UtilityScada>>{};

    for (final item in items) {
      final fac = (item.fac ?? '').trim().isEmpty
          ? 'Unknown FAC'
          : item.fac!.trim();
      map.putIfAbsent(fac, () => []).add(item);
    }

    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        final aIndex = facOrder.indexOf(a);
        final bIndex = facOrder.indexOf(b);

        if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
        if (aIndex != -1) return -1;
        if (bIndex != -1) return 1;
        return a.compareTo(b);
      });

    final sortedMap = <String, List<UtilityScada>>{};
    for (final key in sortedKeys) {
      final values = map[key]!
        ..sort((a, b) => (a.scadaId ?? '').compareTo(b.scadaId ?? ''));
      sortedMap[key] = values;
    }

    return sortedMap;
  }

  GridConfig _getGridConfig(double width) {
    if (width > 1400) {
      return const GridConfig(crossAxisCount: 4, childAspectRatio: 1.32);
    } else if (width > 1050) {
      return const GridConfig(crossAxisCount: 3, childAspectRatio: 1.18);
    } else if (width > 700) {
      return const GridConfig(crossAxisCount: 2, childAspectRatio: 1.06);
    }
    return const GridConfig(crossAxisCount: 1, childAspectRatio: 1.22);
  }
}

class GridConfig {
  final int crossAxisCount;
  final double childAspectRatio;

  const GridConfig({
    required this.crossAxisCount,
    required this.childAspectRatio,
  });
}

class _FacSection extends StatelessWidget {
  final String fac;
  final int count;
  final Color color;
  final Widget child;

  const _FacSection({
    required this.fac,
    required this.count,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                fac,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count SCADA',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
