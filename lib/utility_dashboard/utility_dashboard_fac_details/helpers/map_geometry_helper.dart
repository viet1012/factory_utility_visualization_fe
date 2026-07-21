import 'package:flutter/material.dart';

class MapGeometryHelper {
  const MapGeometryHelper._();

  static Offset autoPlace(int index) {
    final safeIndex = index < 0 ? 0 : index;

    const columns = 4;
    const startX = 0.08;
    const startY = 0.08;
    const gapX = 0.22;
    const gapY = 0.12;

    final column = safeIndex % columns;
    final row = safeIndex ~/ columns;

    return Offset(
      (startX + column * gapX).clamp(0.02, 0.88),
      (startY + row * gapY).clamp(0.02, 0.88),
    );
  }

  static Offset clampPosition(Offset position) {
    return Offset(position.dx.clamp(0.0, 1.0), position.dy.clamp(0.0, 1.0));
  }

  /// Hiển thị toàn bộ ảnh, giữ đúng tỷ lệ.
  /// Ảnh có thể để lại khoảng trống hai bên hoặc trên dưới.
  static Rect containRect(Size containerSize, Size imageSize) {
    if (containerSize.width <= 0 ||
        containerSize.height <= 0 ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return Offset.zero & containerSize;
    }

    final scaleX = containerSize.width / imageSize.width;
    final scaleY = containerSize.height / imageSize.height;

    // contain dùng scale nhỏ hơn để toàn bộ ảnh nằm trong container.
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final width = imageSize.width * scale;
    final height = imageSize.height * scale;

    return Rect.fromLTWH(
      (containerSize.width - width) / 2,
      (containerSize.height - height) / 2,
      width,
      height,
    );
  }

  /// Lấp đầy container nhưng có thể cắt ảnh.
  static Rect coverRect(Size containerSize, Size imageSize) {
    if (containerSize.width <= 0 ||
        containerSize.height <= 0 ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return Offset.zero & containerSize;
    }

    final scaleX = containerSize.width / imageSize.width;
    final scaleY = containerSize.height / imageSize.height;

    final scale = scaleX > scaleY ? scaleX : scaleY;

    final width = imageSize.width * scale;
    final height = imageSize.height * scale;

    return Rect.fromLTWH(
      (containerSize.width - width) / 2,
      (containerSize.height - height) / 2,
      width,
      height,
    );
  }
}
