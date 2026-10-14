/// Hang so cau hinh dung chung cho chart signal.
abstract final class ChartConfig {
  /// Keo truc Y de chua nguong khi
  /// |nguong − gia tri gan nhat cua du lieu| <= ty le nay × max(|gia tri gan
  /// nhat|, 1); xa hon thi chi hien nhan ▲ / ▼ o mep chart.
  static const double thresholdAxisPullRatio = 0.20;

  /// Chip nguong: khoang cach toi nguong < ty le nay × max(|gia tri|, 1) thi
  /// to cam (sap vuot).
  static const double thresholdNearRatio = 0.10;
}
