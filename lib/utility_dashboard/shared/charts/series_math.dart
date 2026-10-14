/// Tinh toan thuan (khong UI) dung chung cho cac chart lich su signal.
library;

/// Khoang cach duong nho nhat giua hai moc lien tiep; mac dinh 1 phut.
Duration inferBucketStep(Iterable<DateTime> timestamps) {
  Duration? smallest;
  DateTime? previous;

  for (final ts in timestamps) {
    if (previous != null) {
      final diff = ts.difference(previous);

      if (diff > Duration.zero && (smallest == null || diff < smallest)) {
        smallest = diff;
      }
    }
    previous = ts;
  }

  return smallest ?? const Duration(minutes: 1);
}

/// Bo cac khoang rong NGAN cua [points] (da gap-fill, theo thoi gian) de
/// duong noi thang qua; khoang rong co do dai > [threshold] giu nguyen cac
/// diem rong de EmptyPointMode.gap ngat duong. Rong o dau series bi bo.
///
/// Cung quy tac voi SignalPlotData (SCADA TABLE).
List<T> dropShortGaps<T>(
  List<T> points, {
  required bool Function(T point) hasValue,
  required Duration step,
  required Duration threshold,
}) {
  final result = <T>[];
  var index = 0;

  while (index < points.length) {
    if (hasValue(points[index])) {
      result.add(points[index++]);
      continue;
    }

    final first = index;
    while (index < points.length && !hasValue(points[index])) {
      index++;
    }

    if (first == 0) continue;
    if (step * (index - first) > threshold) {
      result.addAll(points.getRange(first, index));
    }
  }

  return result;
}

/// Gia tri vuot nguong cua mot bucket, null = trong nguong.
///
/// So [max] (fallback [value]) voi [high] truoc, roi [min] (fallback
/// [value]) voi [low]: bat ca dinh ngan trong bucket ma avg da lam phang.
double? thresholdBreach({
  required double value,
  double? min,
  double? max,
  double? low,
  double? high,
}) {
  final top = max ?? value;
  if (high != null && top > high) return top;

  final bottom = min ?? value;
  if (low != null && bottom < low) return bottom;

  return null;
}

/// Mot mau dua vao [ValueEnvelope.of].
typedef EnvelopeSample = ({double value, double low, double high, int weight});

/// min / max (tren low / high cua tung mau) va trung binh co trong so.
class ValueEnvelope {
  final double? min;
  final double? max;
  final double? avg;

  const ValueEnvelope({this.min, this.max, this.avg});

  factory ValueEnvelope.of(Iterable<EnvelopeSample> samples) {
    double? min;
    double? max;
    var weightedSum = 0.0;
    var weight = 0;

    for (final sample in samples) {
      if (min == null || sample.low < min) min = sample.low;
      if (max == null || sample.high > max) max = sample.high;

      weightedSum += sample.value * sample.weight;
      weight += sample.weight;
    }

    return ValueEnvelope(
      min: min,
      max: max,
      avg: weight == 0 ? null : weightedSum / weight,
    );
  }
}
