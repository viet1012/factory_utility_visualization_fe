import 'package:flutter/material.dart';

import 'group_frame_types.dart';

typedef UpdateGroupPosition =
    Future<void> Function({
      required String boxDeviceId,
      required Offset position,
    });

typedef UpdateGroupDirection =
    Future<void> Function({
      required String boxDeviceId,
      required ArrowDirection direction,
    });
