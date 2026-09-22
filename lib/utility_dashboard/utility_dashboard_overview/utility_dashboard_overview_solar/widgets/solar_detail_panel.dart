import 'package:flutter/material.dart';

import '../helpers/solar_detail_formatters.dart';

/// Khung panel dung chung cho cac section cua Solar Detail.
///
/// Luu y: [child] duoc dat truc tiep trong mot [Column], nen caller van
/// phai tu boc [Expanded] giong nhu code cu.
class SolarDetailPanel extends StatelessWidget {
  final String title;

  final Color titleColor;

  final Widget child;

  const SolarDetailPanel({
    super.key,
    required this.title,
    required this.titleColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: solarPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),

          const SizedBox(height: 5),

          child,
        ],
      ),
    );
  }
}

/// Decoration dung chung cho panel va cac o KPI.
BoxDecoration solarPanelDecoration() {
  return BoxDecoration(
    color: SolarDetailColors.panel.withValues(alpha: .92),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: SolarDetailColors.border.withValues(alpha: .8)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .35),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  );
}
