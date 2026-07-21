import 'package:flutter/material.dart';

import '../models/group_frame_types.dart';

class FrameContent extends StatelessWidget {
  final String boxDeviceId;
  final String? scadaText;
  final LabelOrientation orientation;
  final bool hasAlarm;

  const FrameContent({
    super.key,
    required this.boxDeviceId,
    required this.scadaText,
    required this.orientation,
    required this.hasAlarm,
  });

  static const List<Shadow> _labelShadows = [
    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
    Shadow(color: Colors.black, blurRadius: 10, offset: Offset.zero),
  ];

  bool get _hasScada {
    return (scadaText ?? '').trim().isNotEmpty;
  }

  String get _boxDeviceText {
    final value = boxDeviceId.trim();

    return value.isEmpty ? '-' : value;
  }

  @override
  Widget build(BuildContext context) {
    if (orientation == LabelOrientation.vertical) {
      return _buildVerticalContent();
    }

    return _buildHorizontalContent();
  }

  Widget _buildHorizontalContent() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // Không dùng MainAxisSize.min vì tên cần được phép co lại.
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Tooltip(
                  message: _boxDeviceText,
                  waitDuration: const Duration(milliseconds: 400),
                  child: _buildLabel(textAlign: TextAlign.left),
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
          ),
          if (_hasScada) ...[
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              child: Tooltip(
                message: scadaText!.trim(),
                waitDuration: const Duration(milliseconds: 400),
                child: Text(
                  scadaText!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerticalContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.view_quilt_rounded,
          size: 16,
          color: Colors.white.withOpacity(0.95),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: RotatedBox(
            quarterTurns: 1,
            child: Tooltip(
              message: _boxDeviceText,
              waitDuration: const Duration(milliseconds: 400),
              child: _buildLabel(textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel({required TextAlign textAlign}) {
    return Text(
      _boxDeviceText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      textAlign: textAlign,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 12,
        height: 1.1,
        shadows: _labelShadows,
      ),
    );
  }
}
