/// Doc gia tri JSON tu backend theo kieu "long": so co the den duoi dang
/// chuoi, field co the null / thieu. Dung chung cho moi model `fromJson`.
///
/// Cac ham tra `null` khi khong doc duoc; noi goi tu chon fallback
/// (vd `jsonDouble(v) ?? 0`).
library;

/// num hoac chuoi so -> double. null, chuoi rong / sai, NaN, Infinity -> null.
double? jsonDouble(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse('${value ?? ''}');

  return (parsed == null || !parsed.isFinite) ? null : parsed;
}

/// num (bo phan thap phan) hoac chuoi so nguyen -> int; con lai -> null.
int? jsonInt(Object? value) {
  if (value is num) return value.isFinite ? value.toInt() : null;

  return int.tryParse('${value ?? ''}');
}

/// `toString()` da trim; null -> ''.
String jsonText(Object? value) => value?.toString().trim() ?? '';

/// DateTime hoac chuoi ISO-8601 -> gio dia phuong.
///
/// Chuoi co offset / `Z` duoc doi sang local; chuoi khong offset da duoc
/// `DateTime.parse` hieu la local nen giu nguyen.
DateTime? jsonDateTime(Object? value) {
  if (value is DateTime) return value.toLocal();

  final text = jsonText(value);
  if (text.isEmpty) return null;

  return DateTime.tryParse(text)?.toLocal();
}
