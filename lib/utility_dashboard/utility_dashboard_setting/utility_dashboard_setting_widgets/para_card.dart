import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_widgets/setting_common_widgets.dart';
import 'package:flutter/material.dart';

import '../utility_dashboard_setting_models/utility_para.dart';

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
                    FlagChip(
                      text: important ? 'Important' : 'Normal',
                      color: important ? Colors.amber : Colors.blueGrey,
                    ),
                    FlagChip(
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
                        child: MiniValueBox(
                          label: 'Min',
                          value: '${item.minAlert ?? '-'}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MiniValueBox(
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
