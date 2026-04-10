import 'package:flutter/material.dart' hide SearchBar;
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/utility_fac_style.dart';
import '../utility_dashboard_setting_dialog/channel_form_dialog.dart';
import '../utility_dashboard_setting_models/scada_channel_view_model.dart';
import '../utility_dashboard_setting_models/utility_scada_channel.dart';
import '../utility_dashboard_setting_widgets/scada_channel_widgets.dart';
import '../utility_scada_channel_api.dart';
import 'base_setting_screen.dart';

class UtilityScadaChannelScreen extends StatefulWidget {
  final UtilityScadaChannelApi api;

  const UtilityScadaChannelScreen({super.key, required this.api});

  @override
  State<UtilityScadaChannelScreen> createState() =>
      _UtilityScadaChannelScreenState();
}

class _UtilityScadaChannelScreenState extends State<UtilityScadaChannelScreen> {
  late final ScadaChannelViewModel _viewModel;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _viewModel = ScadaChannelViewModel(api: widget.api);
    _searchController = TextEditingController();
    _viewModel.loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openFormDialog({UtilityScadaChannel? item}) async {
    final result = await showDialog<UtilityScadaChannel>(
      context: context,
      builder: (_) =>
          ChannelFormDialog(initialValue: item, isEdit: item != null),
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
      child: Consumer<ScadaChannelViewModel>(
        builder: (_, vm, __) {
          return BaseSettingScreen(
            title: 'Utility SCADA Channels',
            loading: vm.loading,
            submitting: vm.submitting,
            error: vm.error,
            totalCount: vm.totalCount,
            filteredCount: vm.filteredCount,
            searchController: _searchController,
            onSearchChanged: vm.setSearchKeyword,
            onRefresh: vm.loadData,
            onAdd: () => _openFormDialog(),
            searchHint: 'Search by SCADA, category, box, device...',
            addButtonText: 'Add Channel',
            body: _buildBody(vm),
          );
        },
      ),
    );
  }

  Widget _buildBody(ScadaChannelViewModel vm) {
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null) {
      return ErrorState(message: vm.error!, onRetry: vm.loadData);
    }

    if (vm.filteredItems.isEmpty) {
      return const EmptyState(message: 'No data found');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridConfig = _getGridConfig(constraints.maxWidth);

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: vm.filteredItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridConfig.crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: gridConfig.childAspectRatio,
          ),
          itemBuilder: (_, index) {
            final item = vm.filteredItems[index];
            return ChannelCard(
              item: item,
              accent: UtilityFacStyle.colorByCate(item.cate),
              icon: UtilityFacStyle.iconByCate(item.cate),
              disabled: vm.submitting,
              onEdit: () => _openFormDialog(item: item),
            );
          },
        );
      },
    );
  }

  GridConfig _getGridConfig(double width) {
    if (width > 1280) {
      return const GridConfig(crossAxisCount: 4, childAspectRatio: 1.28);
    } else if (width > 920) {
      return const GridConfig(crossAxisCount: 3, childAspectRatio: 1.18);
    } else if (width > 620) {
      return const GridConfig(crossAxisCount: 2, childAspectRatio: 1.10);
    }
    return const GridConfig(crossAxisCount: 1, childAspectRatio: 1.55);
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
