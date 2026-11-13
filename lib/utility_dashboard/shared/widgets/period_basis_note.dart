import 'package:flutter/material.dart';

/// Dong phu nho cho biet ky tinh cua so lieu, vd
/// `Calendar month · Nov 1 – Nov 12 ⓘ`. Chu duoc cat bang ellipsis khi
/// thieu cho; icon ⓘ luon hien va mang [tooltip].
///
/// [text] null: chi hien icon (vd man Bill period da co subtitle rieng).
/// [compactText]: ban rut gon, dung khi [text] khong vua chieu ngang (van
/// ellipsis neu ban rut gon cung khong vua).
/// Chuoi va tooltip lay tu `PeriodBasisFormatter`.
class PeriodBasisNote extends StatelessWidget {
  final String? text;
  final String? compactText;
  final String tooltip;
  final TextStyle? style;
  final Color? iconColor;
  final double iconSize;

  const PeriodBasisNote({
    super.key,
    this.text,
    this.compactText,
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

    final compact = compactText;
    if (compact == null || compact == label) {
      return _row(label, textStyle, icon);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 4 - iconSize;
        final fits =
            !constraints.hasBoundedWidth ||
            _textWidth(context, label, textStyle) <= available;
        return _row(fits ? label : compact, textStyle, icon);
      },
    );
  }

  Widget _row(String label, TextStyle textStyle, Widget icon) {
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

  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
