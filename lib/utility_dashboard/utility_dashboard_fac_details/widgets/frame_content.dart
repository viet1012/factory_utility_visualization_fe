import 'package:flutter/material.dart';

import '../models/group_frame_types.dart';

class FrameContent extends StatelessWidget {
  final String boxDeviceId;
  final String? scadaText;
  final LabelOrientation orientation;
  final bool hasAlarm;

  const FrameContent({
    required this.boxDeviceId,
    required this.scadaText,
    required this.orientation,
    required this.hasAlarm,
  });

  static const _labelShadows = [
    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
    Shadow(color: Colors.black, blurRadius: 10, offset: Offset.zero),
  ];

  bool get _hasScada {
    return (scadaText ?? '').trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (orientation == LabelOrientation.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.view_quilt_rounded,
            size: 16,
            color: Colors.white.withOpacity(0.95),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: RotatedBox(quarterTurns: 1, child: _label),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _label,
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              scadaText!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget get _label {
    return Text(
      boxDeviceId,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
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
