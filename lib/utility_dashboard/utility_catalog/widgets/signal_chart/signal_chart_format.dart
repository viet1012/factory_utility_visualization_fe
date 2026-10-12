import '../../catalog_value_format.dart';

/// Gia tri tren chart dung CHUNG quy tac voi cot VALUE cua bang
/// (xem catalog_value_format.dart), ke ca signal status.
String formatSignalValue(double? value) => formatCatalogValue(value);

String formatSignalValueWithUnit(double? value, String? unit) {
  return formatCatalogValueWithUnit(value, unit);
}

/// dd/MM/yyyy HH:mm, gio dia phuong.
String formatSignalTimestamp(DateTime time) {
  final local = time.toLocal();

  String two(int value) => value.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
