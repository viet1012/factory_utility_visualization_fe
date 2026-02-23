import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_models/response/sum_compare_item.dart';
import '../../utility_state/sum_compare_provider.dart';

class UtilityCategoryCompareView extends StatefulWidget {
  const UtilityCategoryCompareView({super.key});

  @override
  State<UtilityCategoryCompareView> createState() =>
      _UtilityCategoryCompareViewState();
}

class _UtilityCategoryCompareViewState
    extends State<UtilityCategoryCompareView> {
  static const _nameEns = ['Total Energy Consumption'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<SumCompareProvider>();
      p.setFilter(nameEns: _nameEns);
      p.startPolling();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SumCompareProvider>(
      builder: (context, p, _) {
        final rows = p.rows;
        final err = p.error;

        final nowDate = rows.isNotEmpty ? rows.first.nowDate : '';
        final prevDate = rows.isNotEmpty ? rows.first.prevDate : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CompactHeader(
              title: 'Category Compare',
              subtitle: (nowDate.isNotEmpty && prevDate.isNotEmpty)
                  ? 'Today: $nowDate • Prev: $prevDate'
                  : null,
              isLoading: p.isLoading,
              onRefresh: () async {
                // nếu có fetchNow() thì gọi
                // await p.fetchNow();
              },
            ),
            const SizedBox(height: 8),

            if (p.isLoading && rows.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (err != null && rows.isEmpty)
              Expanded(child: _ErrorState(error: err))
            else if (rows.isEmpty)
              const Expanded(child: _EmptyState())
            else
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CompactCompareCard(item: rows[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// ================= UI PARTS =================

class _CompactHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isLoading;
  final Future<void> Function()? onRefresh;

  const _CompactHeader({
    required this.title,
    required this.subtitle,
    required this.isLoading,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.analytics_outlined, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: Icon(Icons.refresh, color: Colors.white.withOpacity(0.85)),
          ),
      ],
    );
  }
}

class _CompactCompareCard extends StatelessWidget {
  final SumCompareItem item;

  const _CompactCompareCard({required this.item});

  (IconData, Color) _keyIcon(String key) {
    final k = key.toLowerCase();
    if (k.contains('electric') || k.contains('power') || k.contains('energy')) {
      return (Icons.flash_on, Colors.orangeAccent);
    }
    if (k.contains('water') || k.contains('volume')) {
      return (Icons.water_drop_outlined, Colors.blueAccent);
    }
    if (k.contains('air')) {
      return (Icons.air, Colors.cyanAccent);
    }
    return (Icons.sensors, Colors.grey);
  }

  (Color, IconData, String) _trendBadge(Trend t) {
    switch (t) {
      case Trend.up:
        return (Colors.redAccent, Icons.arrow_upward, 'UP');
      case Trend.down:
        return (Colors.green, Icons.arrow_downward, 'DOWN');
      case Trend.stable:
        return (Colors.amberAccent, Icons.remove, 'STABLE');
      default:
        return (Colors.grey, Icons.help_outline, 'N/A');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (keyIcon, keyColor) = _keyIcon(item.key);
    final (trendColor, trendIcon, trendText) = _trendBadge(item.trend);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withOpacity(0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // icon square
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: keyColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: keyColor.withOpacity(0.35)),
            ),
            child: Icon(keyIcon, color: keyColor, size: 22),
          ),
          const SizedBox(width: 10),

          // content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // title + trend chip
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.key,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TrendChip(
                      color: trendColor,
                      icon: trendIcon,
                      text: trendText,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // NOW (big) + PREV (small)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.now.toStringAsFixed(2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF00F5FF),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      label: 'PREV',
                      value: item.prev.toStringAsFixed(2),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Δ + %
                Row(
                  children: [
                    _MiniStat(
                      label: 'Δ',
                      value: item.delta.toStringAsFixed(2),
                      valueColor: trendColor,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      label: '%',
                      value: item.pctText,
                      valueColor: trendColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final vColor = valueColor ?? Colors.white.withOpacity(0.85);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: vColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final bool compact;

  const _TrendChip({
    required this.color,
    required this.icon,
    required this.text,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'API error:\n$error',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.85)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No data',
        style: TextStyle(color: Colors.white.withOpacity(0.75)),
      ),
    );
  }
}

enum CompareSort { nowDesc, nowAsc, pctDesc, deltaDesc }
