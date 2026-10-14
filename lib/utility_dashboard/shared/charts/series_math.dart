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
