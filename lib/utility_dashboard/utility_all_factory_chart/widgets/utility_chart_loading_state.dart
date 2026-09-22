import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';

class UtilityChartLoadingState extends StatelessWidget {
  final String cate;
  final String message;

  const UtilityChartLoadingState({
    super.key,
    required this.cate,
    this.message = 'Loading utility signals...',
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(cate);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.line.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(
              color: theme.line.withValues(alpha: .08),
              blurRadius: 18,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: theme.line,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .72),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
