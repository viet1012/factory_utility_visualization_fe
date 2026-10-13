/// Format so dung chung cho moi chart / card / bang cua utility dashboard.
///
/// Quy tac: lam tron theo [decimals], bo 0 thua o cuoi, dau phan cach hang
/// nghin `,`, null / khong huu han -> `—`.
library;

const String kMissingValue = '—';

/// Vd (decimals = 2): 1234.5 -> `1,234.5`; 0.1 -> `0.1`; 7 -> `7`; null -> `—`.
String formatValue(num? value, {int decimals = 2}) {
  if (value == null || !value.isFinite) return kMissingValue;

  final digits = decimals.clamp(0, 12);
  var text = value.toDouble().toStringAsFixed(digits);

  // -0.004 voi 2 so le -> "-0.00": bo dau am cua so 0.
  if (text.startsWith('-') && double.parse(text) == 0) {
    text = text.substring(1);
  }

  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  }

  return _group(text);
}

/// Nhu [formatValue], gan them unit bang mot dau cach. Khong gan unit khi
/// gia tri thieu.
String formatWithUnit(num? value, String? unit, {int decimals = 2}) {
  final text = formatValue(value, decimals: decimals);
  final normalizedUnit = unit?.trim() ?? '';

  if (text == kMissingValue || normalizedUnit.isEmpty) return text;
  return '$text $normalizedUnit';
}

/// Chen `,` vao phan nguyen: "-1234567.5" -> "-1,234,567.5".
String _group(String text) {
  final negative = text.startsWith('-');
  final body = negative ? text.substring(1) : text;

  final dot = body.indexOf('.');
  final integer = dot < 0 ? body : body.substring(0, dot);
  final fraction = dot < 0 ? '' : body.substring(dot);

  if (integer.length <= 3) return text;

  final buffer = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    if (i > 0 && (integer.length - i) % 3 == 0) buffer.write(',');
    buffer.write(integer[i]);
  }

  return '${negative ? '-' : ''}$buffer$fraction';
}
