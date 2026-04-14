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

  /// Bật/tắt xác thực mật khẩu trước khi Add
  final bool requireAddPassword;

  /// Mật khẩu dùng để xác thực Add
  final String addPassword;

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
    this.requireAddPassword = false,
    this.addPassword = '123456',
  });

  Future<void> _handleAdd(BuildContext context) async {
    if (!requireAddPassword) {
      onAdd();
      return;
    }

    final ok = await _showPasswordConfirmDialog(
      context: context,
      expectedPassword: addPassword,
    );

    if (ok == true) {
      onAdd();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sai mật khẩu hoặc đã huỷ thao tác'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool?> _showPasswordConfirmDialog({
    required BuildContext context,
    required String expectedPassword,
  }) async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF11151C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Xác nhận mật khẩu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nhập mật khẩu để thêm mới dữ liệu.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscure,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                        ),
                        hintText: 'Nhập mật khẩu',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                        ),
                        errorText: errorText,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 1.2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.2,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setStateDialog(() {
                              obscure = !obscure;
                            });
                          },
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        final ok = passwordCtrl.text.trim() == expectedPassword;
                        if (ok) {
                          Navigator.of(dialogContext).pop(true);
                        } else {
                          setStateDialog(() {
                            errorText = 'Mật khẩu không đúng';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Huỷ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final ok = passwordCtrl.text.trim() == expectedPassword;
                    if (ok) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      setStateDialog(() {
                        errorText = 'Mật khẩu không đúng';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text(
                    'Xác nhận',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    passwordCtrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _AddButton(
        label: addButtonText,
        disabled: submitting,
        onTap: () => _handleAdd(context),
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
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.50)),
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
