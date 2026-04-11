import 'dart:ui';

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
      floatingActionButton: _AddButton(
        label: addButtonText,
        disabled: submitting,
        onTap: onAdd,
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

class _AddButton extends StatelessWidget {
  final String label;
  final bool disabled;
  final VoidCallback onTap;

  const _AddButton({
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF3B82F6);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),

                  // 🌫 glass nền
                  color: Colors.white.withOpacity(0.06),

                  // 🧊 viền kính
                  border: Border.all(color: Colors.white.withOpacity(0.5)),

                  // 🌈 glow nhẹ
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
