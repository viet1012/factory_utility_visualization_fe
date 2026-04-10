import 'package:flutter/material.dart' hide SearchBar;

import '../utility_dashboard_setting_widgets/scada_channel_widgets.dart';

class BaseSettingScreen extends StatelessWidget {
  final String title;
  final bool loading;
  final bool submitting;
  final String? error;
  final int totalCount;
  final int filteredCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;
  final Widget body;
  final String searchHint;
  final String addButtonText;

  const BaseSettingScreen({
    super.key,
    required this.title,
    required this.loading,
    required this.submitting,
    required this.error,
    required this.totalCount,
    required this.filteredCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onAdd,
    required this.body,
    required this.searchHint,
    required this.addButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: submitting ? null : onAdd,
        icon: const Icon(Icons.add_rounded),
        label: Text(addButtonText),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: loading ? null : onRefresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SearchBar(
                      controller: searchController,
                      hintText: searchHint,
                      onChanged: onSearchChanged,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: Icons.dataset_outlined,
                            label: 'Total',
                            value: totalCount.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            icon: Icons.filter_alt_outlined,
                            label: 'Showing',
                            value: filteredCount.toString(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
          if (submitting)
            Container(
              color: Colors.black.withOpacity(0.18),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
