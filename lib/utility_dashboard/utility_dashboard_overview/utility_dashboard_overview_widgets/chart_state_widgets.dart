import 'package:flutter/material.dart';

class EmptyChartState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? color;

  const EmptyChartState({
    super.key,
    this.icon = Icons.insert_chart_outlined_rounded,
    this.title = 'No Data Available',
    this.message = 'There is currently no chart data for this period.',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white.withOpacity(0.58);

    return _ChartStateShell(
      icon: icon,
      iconColor: c,
      iconBackground: Colors.white.withOpacity(0.06),
      title: title,
      message: message,
    );
  }
}

class ChartApiErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final Color color;

  const ChartApiErrorState({
    super.key,
    required this.onRetry,
    this.color = Colors.redAccent,
  });

  @override
  Widget build(BuildContext context) {
    return _ChartStateShell(
      icon: Icons.cloud_off_rounded,
      iconColor: color,
      iconBackground: color.withOpacity(0.12),
      title: 'Unable to Load Data',
      message: 'Please check your connection or try again.',
      action: SizedBox(
        height: 32,
        child: ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text(
            'Retry',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartStateShell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final Widget? action;

  const _ChartStateShell({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBackground,
                  border: Border.all(color: iconColor.withOpacity(0.18)),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.52),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    );
  }
}
