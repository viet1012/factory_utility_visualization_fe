import 'package:flutter/material.dart';

import '../utility_dashboard_setting_models/utility_para.dart';
import '../utility_dashboard_setting_models/utility_scada.dart';
import '../utility_dashboard_setting_models/utility_scada_channel.dart';
import 'common_action_buttons.dart';

// ============ STAT CARD ============
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ INFO TILE ============
class InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const InfoTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ============ DARK TEXT FIELD ============
class DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? validatorText;
  final TextInputType keyboardType;

  const DarkTextField({
    required this.controller,
    required this.label,
    this.validatorText,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: _buildBorder(Colors.white.withOpacity(0.08)),
        enabledBorder: _buildBorder(Colors.white.withOpacity(0.08)),
        focusedBorder: _buildBorder(Colors.blueAccent),
      ),
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return validatorText;
        }
        return null;
      },
    );
  }

  OutlineInputBorder _buildBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
  }
}

// ============ CHANNEL CARD ============
class ChannelCard extends StatelessWidget {
  final UtilityScadaChannel item;
  final Color accent;
  final IconData icon;
  final bool disabled;
  final VoidCallback onEdit;

  const ChannelCard({
    required this.item,
    required this.accent,
    required this.icon,
    required this.disabled,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: disabled ? null : onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildCategoryBadge(),
                const SizedBox(height: 10),
                InfoTile(label: 'ID', value: '${item.id ?? '-'}'),
                const SizedBox(height: 16),
                InfoTile(label: 'SCADA', value: item.scadaId ?? '-'),
                const SizedBox(height: 10),
                InfoTile(label: 'Box ID', value: item.boxId ?? '-'),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: AppActionButton(
                    type: AppActionType.edit,
                    onPressed: disabled ? null : onEdit,
                  ),
                ),
                // _buildActionButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.boxDeviceId ?? '-',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
          onSelected: (value) {
            if (value == 'edit') onEdit();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          item.cate ?? 'Unknown',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: disabled ? null : onEdit,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.14)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text('Edit'),
      ),
    );
  }
}

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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: disabled ? null : onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 14),

                _CompactInfoRow(label: 'PLC IP', value: item.plcIp ?? '-'),
                const SizedBox(height: 16),

                Expanded(
                  child: _CompactInfoRow(
                    label: 'Port',
                    value: '${item.plcPort ?? '-'}',
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _CompactInfoRow(
                    label: 'PC',
                    value: item.pcName ?? '-',
                  ),
                ),
                const Spacer(),

                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(
                            text: item.connected ?? '-',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppActionButton(
                    type: AppActionType.edit,
                    onPressed: disabled ? null : onEdit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.developer_board_rounded, color: accent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.scadaId ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class UtilityParaCard extends StatelessWidget {
  final UtilityPara item;
  final VoidCallback onEdit;

  const UtilityParaCard({super.key, required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final bool important = item.isImportant == 1;
    final bool alert = item.isAlert == 1;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 10),

                if ((item.cateId ?? '').isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.cateId!,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      // CỘT 1: PLC + TYPE
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InfoTile(
                              label: 'PLC',
                              value: item.plcAddress ?? '-',
                            ),
                            const SizedBox(height: 4),
                            InfoTile(
                              label: 'Type',
                              value: item.valueType ?? '-',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // CỘT 2: UNIT + VI
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InfoTile(label: 'Unit', value: item.unit ?? '-'),
                            const SizedBox(height: 4),
                            InfoTile(label: 'ENG', value: item.nameEn ?? '-'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FlagChip(
                      text: important ? 'Important' : 'Normal',
                      color: important ? Colors.amber : Colors.blueGrey,
                    ),
                    _FlagChip(
                      text: alert ? 'Alert' : 'No Alert',
                      color: alert ? Colors.redAccent : Colors.green,
                    ),
                  ],
                ),

                if (alert) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniValueBox(
                          label: 'Min',
                          value: '${item.minAlert ?? '-'}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniValueBox(
                          label: 'Max',
                          value: '${item.maxAlert ?? '-'}',
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.14)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.cyan.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.tune_rounded, color: Colors.cyan, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.nameEn ?? item.nameVi ?? '-',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
          onSelected: (value) {
            if (value == 'edit') onEdit();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
          ],
        ),
      ],
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String text;
  final Color color;

  const _FlagChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniValueBox extends StatelessWidget {
  final String label;
  final String value;

  const _MiniValueBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _CompactInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ============ SEARCH BAR ============
class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const SearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white54),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

// ============ EMPTY STATE ============
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ERROR STATE ============
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.redAccent.withOpacity(0.24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
