enum Trend { up, down, stable, unknown }

Trend parseTrend(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'UP':
      return Trend.up;
    case 'DOWN':
      return Trend.down;
    case 'STABLE':
      return Trend.stable;
    default:
      return Trend.unknown;
  }
}

class SumCompareItem {
  final String key;
  final String nowDate;
  final String prevDate;

  final double now;
  final double prev;
  final double delta;

  final String pctText; // "9.12%" hoặc "+9.12%"
  final Trend trend;

  SumCompareItem({
    required this.key,
    required this.nowDate,
    required this.prevDate,
    required this.now,
    required this.prev,
    required this.delta,
    required this.pctText,
    required this.trend,
  });

  factory SumCompareItem.fromJson(Map<String, dynamic> j) {
    double toD(dynamic v) => (v == null) ? 0.0 : (v as num).toDouble();

    return SumCompareItem(
      key: (j['key'] ?? 'UNKNOWN').toString(),
      nowDate: (j['nowDate'] ?? '').toString(),
      prevDate: (j['prevDate'] ?? '').toString(),
      now: toD(j['now']),
      prev: toD(j['prev']),
      delta: toD(j['delta']),
      pctText: (j['pctText'] ?? '--').toString(),
      trend: parseTrend(j['trend']?.toString()),
    );
  }
}
