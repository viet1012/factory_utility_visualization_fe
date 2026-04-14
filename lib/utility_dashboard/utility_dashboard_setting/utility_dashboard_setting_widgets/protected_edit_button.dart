import 'package:flutter/material.dart';

import 'common_action_buttons.dart';

class ProtectedEditButton extends StatelessWidget {
  final VoidCallback onVerified;
  final String password;
  final String? title;
  final String? message;
  final bool compact;
  final bool outlined;

  const ProtectedEditButton({
    super.key,
    required this.onVerified,
    required this.password,
    this.title,
    this.message,
    this.compact = false,
    this.outlined = true,
  });

  Future<void> _handleTap(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordConfirmDialog(
        expectedPassword: password,
        title: title ?? 'Xác nhận mật khẩu',
        message: message ?? 'Nhập mật khẩu để chỉnh sửa dữ liệu.',
      ),
    );

    if (ok == true) {
      onVerified();
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sai mật khẩu hoặc đã huỷ thao tác'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppActionButton(
      type: AppActionType.edit,
      onPressed: () => _handleTap(context),
      compact: compact,
      outlined: outlined,
    );
  }
}

class _PasswordConfirmDialog extends StatefulWidget {
  final String expectedPassword;
  final String title;
  final String message;

  const _PasswordConfirmDialog({
    required this.expectedPassword,
    required this.title,
    required this.message,
  });

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _errorText;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final ok = _passwordCtrl.text.trim() == widget.expectedPassword;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorText = 'Mật khẩu không đúng';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF11151C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        widget.title,
        style: const TextStyle(
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
              widget.message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                hintText: 'Nhập mật khẩu',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                errorText: _errorText,
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
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
                    setState(() {
                      _obscure = !_obscure;
                    });
                  },
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white70,
                  ),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Huỷ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
  }
}
