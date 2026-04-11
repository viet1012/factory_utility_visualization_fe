import 'package:flutter/material.dart' hide SearchBar;
import 'package:provider/provider.dart';

import '../utility_dashboard_setting_models/utility_para_view_model.dart';
import '../utility_dashboard_setting_widgets/para_card.dart';
import '../utility_dashboard_setting_widgets/setting_common_widgets.dart';
import '../utility_para_api.dart';
import 'base_setting_screen.dart';

class UtilityParaScreen extends StatefulWidget {
  final UtilityParaApi api;

  const UtilityParaScreen({super.key, required this.api});

  @override
  State<UtilityParaScreen> createState() => _UtilityParaScreenState();
}

class _UtilityParaScreenState extends State<UtilityParaScreen> {
  late final UtilityParaViewModel _viewModel;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _viewModel = UtilityParaViewModel(api: widget.api);
    _searchController = TextEditingController();
    _viewModel.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
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
      child: Consumer<UtilityParaViewModel>(
        builder: (_, vm, __) {
          return BaseSettingScreen(
            title: 'Utility Parameters',
            loading: vm.loading,
            submitting: vm.submitting,
            error: vm.error,
            totalCount: vm.totalCount,
            filteredCount: vm.filteredCount,
            searchController: _searchController,
            onSearchChanged: vm.setSearch,
            onRefresh: vm.load,
            onAdd: () {
              _showMessage('Chưa gắn form create UtilityPara');
            },
            searchHint: 'Search by name, category, PLC address, unit...',
            addButtonText: 'Add Parameter',
            body: _buildBody(vm),
          );
        },
      ),
    );
  }

  Widget _buildBody(UtilityParaViewModel vm) {
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null) {
      return ErrorState(message: vm.error!, onRetry: vm.load);
    }

    if (vm.filteredItems.isEmpty) {
      return EmptyState(
        message: vm.totalCount == 0
            ? 'No parameter found'
            : 'No parameter matches your search',
        icon: Icons.tune_rounded,
      );
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
            return UtilityParaCard(
              item: item,
              onEdit: () {
                _showMessage(
                  'Chưa gắn form edit cho ${item.nameEn ?? item.nameVi ?? 'parameter'}',
                );
              },
            );
          },
        );
      },
    );
  }

  GridConfig _getGridConfig(double width) {
    if (width >= 1400) {
      return const GridConfig(crossAxisCount: 4, childAspectRatio: 1.22);
    } else if (width >= 1000) {
      return const GridConfig(crossAxisCount: 3, childAspectRatio: 1.12);
    } else if (width >= 680) {
      return const GridConfig(crossAxisCount: 2, childAspectRatio: 1.02);
    }
    return const GridConfig(crossAxisCount: 1, childAspectRatio: 1.45);
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
