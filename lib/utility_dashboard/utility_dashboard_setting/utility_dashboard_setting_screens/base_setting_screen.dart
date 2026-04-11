import 'package:flutter/material.dart' hide SearchBar;

import '../utility_dashboard_setting_widgets/setting_common_widgets.dart';

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
  final List<Widget>? topActions;

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
    this.topActions,
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
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _HeaderActionBar(
                          totalCount: totalCount,
                          filteredCount: filteredCount,
                          loading: loading,
                          onRefresh: onRefresh,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SearchBar(
                      controller: searchController,
                      hintText: searchHint,
                      onChanged: onSearchChanged,
                    ),
                    if (topActions != null && topActions!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: topActions!,
                        ),
                      ),
                    ],
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

class _HeaderActionBar extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final bool loading;
  final VoidCallback onRefresh;

  const _HeaderActionBar({
    required this.totalCount,
    required this.filteredCount,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CompactStatCard(
          icon: Icons.dataset_outlined,
          label: 'Total',
          value: totalCount.toString(),
        ),
        CompactStatCard(
          icon: Icons.filter_alt_outlined,
          label: 'Showing',
          value: filteredCount.toString(),
        ),
        _IconActionButton(
          tooltip: 'Refresh',
          icon: Icons.refresh_rounded,
          onTap: loading ? null : onRefresh,
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  const _IconActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? Colors.white24 : Colors.white70,
          ),
        ),
      ),
    );
  }
}
