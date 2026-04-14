import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_widgets/protected_edit_button.dart';
import 'package:flutter/material.dart';

import '../setting_security.dart';
import '../utility_dashboard_setting_models/utility_scada.dart';
import 'common_action_buttons.dart';

class ScadaCard extends StatelessWidget {
  final UtilityScada item;
  final Color accent;
  final bool disabled;
  final VoidCallback onEdit;

  const ScadaCard({
    super.key,
    required this.item,
    required this.accent,
    required this.disabled,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final connectedText = (item.connected ?? '-').trim();
    final statusColor = _statusColor(connectedText);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.055),
            Colors.white.withOpacity(0.03),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(statusColor, connectedText),
              const SizedBox(height: 14),
              _buildInfoPanel(),
              const Spacer(),
              // _EditButton(disabled: disabled, onTap: onEdit),
              ProtectedEditButton(
                password: SettingSecurity.editPassword,
                onVerified: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color statusColor, String connectedText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.18)),
          ),
          child: Icon(Icons.hub_outlined, color: accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.scadaId ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.fac ?? 'Unknown FAC',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.58),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: connectedText,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: statusColor.withOpacity(0.55), blurRadius: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _InfoLine(
            icon: Icons.lan_rounded,
            label: 'PLC IP',
            value: item.plcIp ?? '-',
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.settings_input_component_rounded,
            label: 'Port',
            value: '${item.plcPort ?? '-'}',
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.computer_rounded,
            label: 'PC',
            value: item.pcName ?? '-',
          ),
        ],
      ),
    );
  }

  Color _statusColor(String value) {
    final v = value.toLowerCase();
    if (v.contains('ok')) {
      return const Color(0xFF22C55E);
    }
    if (v.contains('fail') || v.contains('offline') || v == 'false') {
      return const Color(0xFFEF4444);
    }
    return Colors.orangeAccent;
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white.withOpacity(0.45)),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.56),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  final bool disabled;
  final VoidCallback onTap;

  const _EditButton({required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: AppActionButton(
        type: AppActionType.edit,
        onPressed: disabled ? null : onTap,
      ),
    );
  }
}
