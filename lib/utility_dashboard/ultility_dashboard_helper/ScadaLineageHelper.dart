import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ===============================
/// SCADA LINEAGE HELPER
/// FAC → BOX → DEVICE → PARAM → HISTORY
/// ===============================
class ScadaLineageHelper {
  ScadaLineageHelper._(); // static only

  // ===============================
  // PUBLIC API
  // ===============================

  /// Card hiển thị lineage + nút copy SQL
  static Widget lineageCard({
    required String title,
    required List<LineageStep> steps,
    String? sqlToCopy,
  }) {
    return _LineageCard(title: title, steps: steps, sqlToCopy: sqlToCopy);
  }

  /// Breadcrumb text cho từng parameter row
  static Widget breadcrumb(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1B2A44)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9FB2D6),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ===============================
  // SQL TEMPLATES (DÙNG CHUNG)
  // ===============================

  static const String sqlJoinByParameterId = '''
SELECT
  fac.fac_id,
  fac.fac_name,
  sb.scada_id,
  sb.plc_ip,
  sb.plc_port,
  ch.box_device_id,
  ch.cate,
  pm.parameter_id,
  pm.name_en,
  pm.name_vi,
  pm.unit,
  pm.plc_address,
  ph.value,
  ph.recorded_at
FROM f2_facility fac
JOIN f2_utility_scada_box sb
  ON sb.fac_id = fac.fac_id
JOIN f2_utility_scada_device ch
  ON ch.box_id = sb.scada_id
JOIN f2_utility_parameter_master pm
  ON pm.box_device_id = ch.box_device_id
LEFT JOIN f2_utility_parameter_history ph
  ON ph.parameter_id = pm.parameter_id
 AND ph.recorded_at = (
    SELECT MAX(h2.recorded_at)
    FROM f2_utility_parameter_history h2
    WHERE h2.parameter_id = pm.parameter_id
 )
ORDER BY fac.fac_id, sb.scada_id, ch.box_device_id, pm.parameter_id;
''';

  static const String sqlJoinFallbackByAddress = '''
SELECT
  sb.scada_id,
  ch.box_device_id,
  pm.name_en,
  pm.plc_address,
  ph.value,
  ph.recorded_at
FROM f2_utility_scada_box sb
JOIN f2_utility_scada_device ch
  ON ch.box_id = sb.scada_id
JOIN f2_utility_parameter_master pm
  ON pm.box_device_id = ch.box_device_id
LEFT JOIN f2_utility_parameter_history ph
  ON ph.box_device_id = pm.box_device_id
 AND ph.plc_address = pm.plc_address
 AND ph.recorded_at = (
    SELECT MAX(h2.recorded_at)
    FROM f2_utility_parameter_history h2
    WHERE h2.box_device_id = pm.box_device_id
      AND h2.plc_address = pm.plc_address
 );
''';

  // ===============================
  // LINEAGE STEPS FACTORY
  // ===============================

  static List<LineageStep> facSteps() => const [
    LineageStep(
      table: 'f2_utility_scada_box',
      keyHint: 'fac_id → scada_id',
      joinDesc: 'FAC.fac_id = scada_box.fac_id',
    ),
    LineageStep(
      table: 'f2_utility_scada_device',
      keyHint: 'box_id → box_device_id',
      joinDesc: 'scada_box.scada_id = device.box_id',
    ),
    LineageStep(
      table: 'f2_utility_parameter_master',
      keyHint: 'box_device_id → parameter_id',
      joinDesc: 'device.box_device_id = master.box_device_id',
    ),
    LineageStep(
      table: 'f2_utility_parameter_history',
      keyHint: 'parameter_id → recorded_at',
      joinDesc: 'master.parameter_id = history.parameter_id (latest)',
    ),
  ];

  static List<LineageStep> boxSteps() => const [
    LineageStep(
      table: 'f2_utility_scada_box',
      keyHint: 'scada_id',
      joinDesc: 'BOX xác định bởi scada_id',
    ),
    LineageStep(
      table: 'f2_utility_scada_device',
      keyHint: 'box_id',
      joinDesc: 'device.box_id = box.scada_id',
    ),
    LineageStep(
      table: 'f2_utility_parameter_master',
      keyHint: 'box_device_id',
      joinDesc: 'master.box_device_id = device.box_device_id',
    ),
  ];

  static List<LineageStep> deviceSteps() => const [
    LineageStep(
      table: 'f2_utility_scada_device',
      keyHint: 'box_device_id',
      joinDesc: 'DEVICE xác định bởi box_device_id',
    ),
    LineageStep(
      table: 'f2_utility_parameter_master',
      keyHint: 'box_device_id',
      joinDesc: 'device.box_device_id = master.box_device_id',
    ),
    LineageStep(
      table: 'f2_utility_parameter_history',
      keyHint: 'parameter_id',
      joinDesc: 'master.parameter_id = history.parameter_id',
    ),
  ];
}

/// ===============================
/// MODEL
/// ===============================
class LineageStep {
  final String table;
  final String keyHint;
  final String joinDesc;

  const LineageStep({
    required this.table,
    required this.keyHint,
    required this.joinDesc,
  });
}

/// ===============================
/// PRIVATE WIDGETS
/// ===============================
class _LineageCard extends StatelessWidget {
  final String title;
  final List<LineageStep> steps;
  final String? sqlToCopy;

  const _LineageCard({
    required this.title,
    required this.steps,
    this.sqlToCopy,
  });

  void _copySql(BuildContext context) async {
    if (sqlToCopy == null) return;
    await Clipboard.setData(ClipboardData(text: sqlToCopy!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ SQL copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B2A44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: steps
                .map(
                  (s) => Chip(
                    backgroundColor: const Color(0xFF0E1729),
                    side: const BorderSide(color: Color(0xFF1B2A44)),
                    label: Text(
                      '${s.table} (${s.keyHint})',
                      style: const TextStyle(
                        color: Color(0xFF9FB2D6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 8),

          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${s.joinDesc}',
                style: const TextStyle(color: Color(0xFF9FB2D6), fontSize: 12),
              ),
            ),
          ),

          if (sqlToCopy != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy SQL Join'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9FB2D6),
                side: const BorderSide(color: Color(0xFF1B2A44)),
              ),
              onPressed: () => _copySql(context),
            ),
          ],
        ],
      ),
    );
  }
}
