import 'package:flutter/material.dart';

typedef UpdateGroupPosition =
    Future<void> Function({
      required String boxDeviceId,
      required Offset position,
    });
