import '../../models/signal_history_models.dart';

/// Khoang null lien tiep phai DAI HON nguong nay moi ngat duong + to xam.
///
/// Chu ky ghi thuc te ~65s nen bucket 1m co ~12% phut trong le (moi lan 1
/// phut); cac lo nho do duoc noi qua thay vi ve thanh vet xam.
/// Ket qua: bucket 1m -> can > 3 bucket lien tiep; bucket 5m / 15m / 1h ->
/// chi 1 bucket rong da du ngat.
const Duration kSignalGapBreakThreshold = Duration(minutes: 3);

class SignalGap {
  final DateTime start;
  final DateTime end;

  const SignalGap(this.start, this.end);
}

/// Diem dua vao chart sau khi xu ly khoang trong.
class SignalPlotData {
  /// Diem de ve: khoang null NGAN da bi bo (duong noi qua), khoang null DAI
  /// van giu diem null (EmptyPointMode.gap se ngat duong tai do).
  final List<SignalHistoryPoint> points;

  /// Cac khoang null dai, to nen xam tren truc X.
  final List<SignalGap> gaps;

  /// Do rong bucket da dung de xet (tu backend hoac suy ra).
  final Duration bucket;

  const SignalPlotData._(this.points, this.gaps, this.bucket);

  factory SignalPlotData.of(
    List<SignalHistoryPoint> source, {
    Duration? bucket,
    Duration threshold = kSignalGapBreakThreshold,
  }) {
    final step = bucket ?? _inferBucket(source);

    final points = <SignalHistoryPoint>[];
    final gaps = <SignalGap>[];

    var index = 0;

    while (index < source.length) {
      if (source[index].value != null) {
        points.add(source[index]);
        index++;
        continue;
      }

      final first = index;
      while (index < source.length && source[index].value == null) {
        index++;
      }
      final last = index - 1;

      // Null o DAU series (truoc diem co du lieu dau tien, vd 24h khi raw
      // chi giu ~24h): de trong, khong to xam, khong tinh la gap.
      if (first == 0) continue;

      final runLength = last - first + 1;
      final isLong = step * runLength > threshold;

      if (!isLong) continue; // Bo qua: duong noi thang qua lo ngan.

      points.addAll(source.getRange(first, last + 1));

      // Nen xam keo tu diem co du lieu truoc den diem co du lieu sau.
      final start = source[first - 1].ts;
      final end = last + 1 < source.length
          ? source[last + 1].ts
          : source[last].ts;

      gaps.add(SignalGap(start, end));
    }

    return SignalPlotData._(
      List<SignalHistoryPoint>.unmodifiable(points),
      List<SignalGap>.unmodifiable(gaps),
      step,
    );
  }

  /// Khoang cach duong nho nhat giua hai diem lien tiep; mac dinh 1 phut.
  static Duration _inferBucket(List<SignalHistoryPoint> points) {
    Duration? smallest;

    for (var i = 1; i < points.length; i++) {
      final diff = points[i].ts.difference(points[i - 1].ts);
      if (diff <= Duration.zero) continue;

      if (smallest == null || diff < smallest) smallest = diff;
    }

    return smallest ?? const Duration(minutes: 1);
  }
}
