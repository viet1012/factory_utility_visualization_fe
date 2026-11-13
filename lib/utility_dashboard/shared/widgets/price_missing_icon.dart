import 'package:flutter/material.dart';

/// Tooltip dung chung khi backend bao `priceMissing` (co gio khong co bang
/// gia -> tien chi mot phan).
const String kPriceMissingMessage =
    'Some hours have no tariff – cost is partial';

/// Icon info nho dat canh gia tri tien khi [visible].
class PriceMissingIcon extends StatelessWidget {
  final bool visible;
  final double size;
  final Color color;

  const PriceMissingIcon({
    super.key,
    required this.visible,
    this.size = 13,
    this.color = const Color(0xFFFF9F43),
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: kPriceMissingMessage,
        waitDuration: const Duration(milliseconds: 200),
        child: Icon(Icons.info_outline, size: size, color: color),
      ),
    );
  }
}
