import 'package:flutter/material.dart';

/// Dong phu nho cho biet ky tinh cua so lieu, vd
/// `Calendar month · Nov 1 – Nov 12 ⓘ`. Chu duoc cat bang ellipsis khi
/// thieu cho; icon ⓘ luon hien va mang [tooltip].
///
/// [text] null: chi hien icon (vd man Bill period da co subtitle rieng).
/// Chuoi va tooltip lay tu `PeriodBasisFormatter`.
class PeriodBasisNote extends StatelessWidget {
  final String? text;
  final String tooltip;
  final TextStyle? style;
  final Color? iconColor;
  final double iconSize;

  const PeriodBasisNote({
    super.key,
    this.text,
    required this.tooltip,
    this.style,
    this.iconColor,
    this.iconSize = 13,
  });

  static final TextStyle _defaultStyle = TextStyle(
    color: Colors.white.withValues(alpha: .68),
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? _defaultStyle;
    final icon = Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Icon(
        Icons.info_outline_rounded,
        size: iconSize,
        color: iconColor ?? textStyle.color,
      ),
    );

    final label = text;
    if (label == null) return icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: textStyle,
          ),
        ),
        const SizedBox(width: 4),
        icon,
      ],
    );
  }
}
