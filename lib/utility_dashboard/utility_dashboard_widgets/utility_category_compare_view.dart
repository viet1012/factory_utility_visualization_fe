import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_models/response/sum_compare_item.dart';
import '../../utility_state/sum_compare_provider.dart';

class UtilityCategoryCompareView extends StatelessWidget {
  const UtilityCategoryCompareView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SumCompareProvider>(
      builder: (context, p, _) {
        if (p.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (p.error != null) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'API error: ${p.error}',
              style: TextStyle(color: Colors.white.withOpacity(0.85)),
            ),
          );
        }

        final rows = p.rows;
        if (rows.isEmpty) return const SizedBox.shrink();

        final nowDate = rows.first.nowDate;
        final prevDate = rows.first.prevDate;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nowDate.isNotEmpty && prevDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Today: $nowDate   •   Prev: $prevDate',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // ✅ LIST DỌC: thay thế Breakdown luôn
            _CompareCardsList(rows: rows),
          ],
        );
      },
    );
  }
}

class _CompareCardsList extends StatelessWidget {
  final List<SumCompareItem> rows;

  const _CompareCardsList({required this.rows});

  @override
  Widget build(BuildContext context) {
    // sort theo now desc cho dễ nhìn
    final items = [...rows]..sort((a, b) => b.now.compareTo(a.now));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CompareCardRow(item: items[i]),
    );
  }
}

class _CompareCardRow extends StatelessWidget {
  final SumCompareItem item;

  const _CompareCardRow({required this.item});

  (IconData, Color) _keyIcon(String key) {
    final k = key.toLowerCase();

    if (k.contains('electric') || k.contains('power')) {
      return (Icons.flash_on, Colors.orangeAccent);
    }
    if (k.contains('water') || k.contains('volume')) {
      return (Icons.water_drop_outlined, Colors.blueAccent.shade700);
    }

    return (Icons.sensors, Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final (trendColor, trendIcon) = _trendStyle(item.trend);
    final (keyIcon, keyColor) = _keyIcon(item.key);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(trendIcon, size: 18, color: trendColor),
          const SizedBox(width: 10),

          // LEFT: key + prev/delta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(keyIcon, size: 22, color: keyColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Prev ${item.prev.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Δ ${item.delta.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: trendColor.withOpacity(0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // RIGHT: pct badge + now value
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: trendColor.withOpacity(0.35)),
                ),
                child: Text(
                  item.pctText,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.now.toStringAsFixed(2),
                style: const TextStyle(
                  color: Color(0xFF00F5FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (Color, IconData) _trendStyle(Trend t) {
    switch (t) {
      case Trend.up:
        return (Colors.redAccent, Icons.arrow_upward);
      case Trend.down:
        return (Colors.green, Icons.arrow_downward);
      case Trend.stable:
        return (Colors.amberAccent, Icons.remove);
      default:
        return (Colors.grey, Icons.help_outline);
    }
  }
}
