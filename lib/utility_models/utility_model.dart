import 'dart:convert';

/// ======================
/// Helpers
/// ======================
 int? toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

double? toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// Hỗ trợ parse "2/2/2026 10:00" hoặc ISO
 DateTime? toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;

  // Try ISO first
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;

  // Try dd/MM/yyyy HH:mm or M/d/yyyy HH:mm
  // Example: 2/2/2026 10:00
  final parts = s.split(' ');
  if (parts.isEmpty) return null;
  final datePart = parts[0];
  final timePart = parts.length > 1 ? parts[1] : '00:00';

  final d = datePart.split('/');
  final t = timePart.split(':');

  if (d.length < 3) return null;

  final month = int.tryParse(d[0]); // because sample looks M/d/yyyy
  final day = int.tryParse(d[1]);
  final year = int.tryParse(d[2]);

  final hour = t.isNotEmpty ? int.tryParse(t[0]) : 0;
  final minute = t.length > 1 ? int.tryParse(t[1]) : 0;

  if (year == null || month == null || day == null) return null;

  return DateTime(
    year,
    month,
    day,
    hour ?? 0,
    minute ?? 0,
  );
}

 String? toStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.trim().isEmpty ? null : s.trim();
}

/// ======================
/// Enums
/// ======================
enum UtilityValueType {
  intType,
  longType,
  floatType,
  doubleType,
  stringType,
  boolType,
  unknown;

  static UtilityValueType fromDb(dynamic v) {
    final s = (v ?? '').toString().trim().toLowerCase();
    switch (s) {
      case 'int':
        return UtilityValueType.intType;
      case 'long':
        return UtilityValueType.longType;
      case 'float':
        return UtilityValueType.floatType;
      case 'double':
        return UtilityValueType.doubleType;
      case 'string':
      case 'text':
        return UtilityValueType.stringType;
      case 'bool':
      case 'boolean':
        return UtilityValueType.boolType;
      default:
        return UtilityValueType.unknown;
    }
  }

  String toDb() {
    switch (this) {
      case UtilityValueType.intType:
        return 'int';
      case UtilityValueType.longType:
        return 'long';
      case UtilityValueType.floatType:
        return 'float';
      case UtilityValueType.doubleType:
        return 'double';
      case UtilityValueType.stringType:
        return 'string';
      case UtilityValueType.boolType:
        return 'bool';
      case UtilityValueType.unknown:
        return 'unknown';
    }
  }
}
