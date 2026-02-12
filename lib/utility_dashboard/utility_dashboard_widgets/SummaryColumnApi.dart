import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_models/response/sum_compare_item.dart';
import '../../utility_state/sum_compare_provider.dart';

class SummaryColumnApi extends StatelessWidget {
  const SummaryColumnApi({super.key});

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

            // ✅ show list theo JSON key
            _CompareCardsGrid(rows: rows),
            const SizedBox(height: 12),

            // ✅ breakdown cũng theo JSON key
            _CompareBreakdownList(rows: rows),
          ],
        );
      },
    );
  }
}

class _CompareCardsGrid extends StatelessWidget {
  final List<SumCompareItem> rows;

  const _CompareCardsGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    // sort theo now desc cho đẹp
    final items = [...rows]..sort((a, b) => b.now.compareTo(a.now));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _CompareCard(item: items[i]),
    );
  }
}

class _CompareCard extends StatelessWidget {
  final SumCompareItem item;

  const _CompareCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final (trendColor, trendIcon) = _trendStyle(item.trend);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withOpacity(0.8),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header: key + trend badge
          Row(
            children: [
              Expanded(
                child: Text(
                  item.key, // ✅ key từ JSON
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: trendColor.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 12, color: trendColor),
                    const SizedBox(width: 4),
                    Text(
                      item.pctText, // ✅ pctText từ JSON
                      style: TextStyle(
                        color: trendColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Now
          Text(
            item.now.toStringAsFixed(2), // ✅ now từ JSON
            style: const TextStyle(
              color: Color(0xFF00F5FF),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),

          const SizedBox(height: 6),

          // Prev + Delta
          Row(
            children: [
              Expanded(
                child: Text(
                  'Prev: ${item.prev.toStringAsFixed(2)}', // ✅ prev từ JSON
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Text(
                'Δ ${item.delta.toStringAsFixed(2)}', // ✅ delta từ JSON
                style: TextStyle(
                  color: trendColor.withOpacity(0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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

class _CompareBreakdownList extends StatelessWidget {
  final List<SumCompareItem> rows;

  const _CompareBreakdownList({required this.rows});

  @override
  Widget build(BuildContext context) {
    final items = [...rows]..sort((a, b) => b.now.compareTo(a.now));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((it) => _row(it)).toList(),
      ),
    );
  }

  Widget _row(SumCompareItem it) {
    final (trendColor, trendIcon) = _trendStyle(it.trend);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              it.key, // ✅ key JSON
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(trendIcon, size: 14, color: trendColor),
          const SizedBox(width: 4),
          Text(
            it.pctText, // ✅ pctText JSON
            style: TextStyle(color: trendColor, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 12),
          Text(
            'Now: ${it.now.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Prev: ${it.prev.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
            ),
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
