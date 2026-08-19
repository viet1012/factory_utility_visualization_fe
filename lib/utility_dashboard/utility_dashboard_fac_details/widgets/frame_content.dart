import 'package:flutter/material.dart';

import '../models/group_frame_types.dart';

class FrameContent extends StatelessWidget {
  final String boxDeviceId;

  final String? scadaText;

  final LabelOrientation orientation;

  final bool hasAlarm;

  // ============================================================
  // RANK
  // ============================================================

  final int? rank;

  final double? value;

  final String? unit;

  final bool editMode;

  const FrameContent({
    super.key,

    required this.boxDeviceId,
    required this.scadaText,
    required this.orientation,
    required this.hasAlarm,

    this.rank,
    this.value,
    this.unit,

    this.editMode = false,
  });

  static const List<Shadow> _labelShadows = [
    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),

    Shadow(color: Colors.black, blurRadius: 10, offset: Offset.zero),
  ];

  // ============================================================
  // DATA
  // ============================================================

  bool get _hasRank {
    return rank != null && value != null;
  }

  String get _boxText {
    final value = boxDeviceId.trim();

    return value.isEmpty ? '-' : value;
  }

  String get _unitText {
    final text = unit?.trim() ?? '';

    return text;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // EDIT MODE
    //
    // Giữ tên box để dễ chỉnh vị trí.
    // ==========================================================

    if (editMode) {
      return _buildEditContent();
    }

    // ==========================================================
    // NORMAL MODE
    //
    // 1
    // 245 kWh
    // ==========================================================

    if (_hasRank) {
      return _buildRankContent();
    }

    // Chưa có period data:
    // fallback tên box.
    return _buildEditContent();
  }

  // ============================================================
  // RANK CONTENT
  // ============================================================

  Widget _buildRankContent() {
    return Tooltip(
      message:
          '$_boxText\n'
          'Rank $rank\n'
          '${_formatValue(value!)} $_unitText',

      waitDuration: const Duration(milliseconds: 350),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          // ====================================================
          // RANK
          // ====================================================
          Text(
            '$rank',

            maxLines: 1,

            style: const TextStyle(
              color: Colors.white,

              fontSize: 18,

              height: 1,

              fontWeight: FontWeight.w900,

              shadows: _labelShadows,
            ),
          ),

          const SizedBox(height: 3),

          // ====================================================
          // VALUE
          // ====================================================
          Text(
            '${_formatValue(value!)}'
            '${_unitText.isEmpty ? '' : ' $_unitText'}',

            maxLines: 1,

            overflow: TextOverflow.visible,

            softWrap: false,

            style: const TextStyle(
              color: Colors.white,

              fontSize: 11,

              height: 1,

              fontWeight: FontWeight.w800,

              shadows: _labelShadows,
            ),
          ),

          if (hasAlarm) ...[
            const SizedBox(height: 3),

            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.yellowAccent,
              size: 14,
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // EDIT CONTENT
  // ============================================================

  Widget _buildEditContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Flexible(
          child: Text(
            _boxText,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              color: Colors.white,

              fontWeight: FontWeight.w900,

              fontSize: 12,

              shadows: _labelShadows,
            ),
          ),
        ),

        if (hasAlarm) ...[
          const SizedBox(width: 5),

          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.yellowAccent,
            size: 15,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // FORMAT VALUE
  // ============================================================

  static String _formatValue(double value) {
    if (value >= 1000000) {
      final result = value / 1000000;

      return '${_trim(result, 2)}M';
    }

    if (value >= 1000) {
      final result = value / 1000;

      return '${_trim(result, 2)}K';
    }

    return _trim(value, 1);
  }

  static String _trim(double value, int decimals) {
    var text = value.toStringAsFixed(decimals);

    text = text.replaceFirst(RegExp(r'\.?0+$'), '');

    return text;
  }
}
