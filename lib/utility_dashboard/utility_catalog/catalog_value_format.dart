/// Format gia tri signal dung chung cho bang va chart, de hai view luon
/// hien cung mot con so cho cung mot gia tri.
library;

/// `--` khi null / khong huu han; |v| >= 1000 -> 1 so le, con lai 2 so le.
/// Signal status cung theo quy tac nay (vd: `7.00`), giong cot VALUE cua bang.
String formatCatalogValue(double? value) {
  if (value == null || !value.isFinite) {
    return '--';
  }

  return value.abs() >= 1000
      ? value.toStringAsFixed(1)
      : value.toStringAsFixed(2);
}

/// Nhu [formatCatalogValue], gan them unit bang mot dau cach.
/// Khong gan unit khi gia tri la `--`.
String formatCatalogValueWithUnit(double? value, String? unit) {
  final valueText = formatCatalogValue(value);
  final normalizedUnit = unit?.trim() ?? '';

  if (valueText == '--' || normalizedUnit.isEmpty) {
    return valueText;
  }

  return '$valueText $normalizedUnit';
}
