/// Gioi han so diem ve moi series.
library;

/// So diem toi da dua vao mot series Syncfusion.
const int kMaxChartPoints = 500;

/// Giam [points] ve khoang [maxPoints] diem, giu hinh dang tin hieu:
/// chia thanh `maxPoints / 2` nhom lien tiep, moi nhom giu diem co [low] nho
/// nhat va diem co [high] lon nhat (theo dung thu tu thoi gian), cong them
/// mot diem rong (gia tri null) neu nhom co lo de chart van ngat duong.
///
/// [low] / [high] mac dinh = [value]; voi series co dai min–max truyen
/// `min ?? value` / `max ?? value` de giu dinh / day cua dai.
/// Diem dau va cuoi luon duoc giu. Danh sach <= [maxPoints] tra ve nguyen.
List<T> downsampleMinMax<T>(
  List<T> points, {
  required double? Function(T point) value,
  double? Function(T point)? low,
  double? Function(T point)? high,
  int maxPoints = kMaxChartPoints,
}) {
  if (points.length <= maxPoints || maxPoints < 4) return points;

  final lowOf = low ?? value;
  final highOf = high ?? value;

  final buckets = maxPoints ~/ 2;
  final size = points.length / buckets;

  final result = <T>[points.first];

  for (var b = 0; b < buckets; b++) {
    final start = (b * size).floor();
    final end = b == buckets - 1 ? points.length : ((b + 1) * size).floor();
    if (end <= start) continue;

    int? minIndex;
    int? maxIndex;
    int? gapIndex;
    double? minValue;
    double? maxValue;

    for (var i = start; i < end; i++) {
      final point = points[i];
      if (value(point) == null) {
        gapIndex ??= i;
        continue;
      }

      final lo = lowOf(point) ?? value(point)!;
      final hi = highOf(point) ?? value(point)!;

      if (minValue == null || lo < minValue) {
        minValue = lo;
        minIndex = i;
      }
      if (maxValue == null || hi > maxValue) {
        maxValue = hi;
        maxIndex = i;
      }
    }

    final picked = <int>{
      if (minIndex != null) minIndex,
      if (maxIndex != null) maxIndex,
      if (gapIndex != null) gapIndex,
    }.toList()..sort();

    for (final index in picked) {
      if (index == 0 || index == points.length - 1) continue;
      result.add(points[index]);
    }
  }

  result.add(points.last);
  return result;
}
