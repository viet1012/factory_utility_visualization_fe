import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/charts/signal_chart_spec_registry.dart';
import '../../shared/charts/signal_thresholds.dart';
import '../../shared/charts/value_format.dart';
import '../models/water_check_models.dart';

// ============================================================
// COLORS
// ============================================================

const Color kWaterOkColor = Color(0xFF22C55E);
const Color kWaterNearColor = kThresholdLevel2Color;
const Color kWaterOverColor = kThresholdLevel3Color;
const Color kWaterStaleColor = Color(0xFF94A3B8);
const Color kWaterAccent = Color(0xFF38BDF8);

const Color kWaterTextPrimary = Color(0xFFE2E8F0);
const Color kWaterTextMuted = Color(0xFF94A3B8);

Color waterStatusColor(WaterStatus status) {
  return switch (status) {
    WaterStatus.ok => kWaterOkColor,
    WaterStatus.near => kWaterNearColor,
    WaterStatus.over => kWaterOverColor,
    WaterStatus.stale || WaterStatus.noThreshold => kWaterStaleColor,
  };
}

String waterStatusLabel(WaterStatus status) {
  return switch (status) {
    WaterStatus.ok => 'OK',
    WaterStatus.near => 'Near',
    WaterStatus.over => 'Over',
    WaterStatus.stale => 'No signal',
    WaterStatus.noThreshold => 'No threshold',
  };
}

/// Mau gia tri ben phai dong: chi NEAR / OVER co mau.
Color waterValueColor(WaterStatus status) {
  return switch (status) {
    WaterStatus.near => kWaterNearColor,
    WaterStatus.over => kWaterOverColor,
    WaterStatus.stale => kWaterStaleColor,
    _ => kWaterTextPrimary,
  };
}

/// Cham trang thai; NO_THRESHOLD = vong vien xam.
class WaterStatusDot extends StatelessWidget {
  final WaterStatus status;
  final double size;

  const WaterStatusDot({super.key, required this.status, this.size = 8});

  @override
  Widget build(BuildContext context) {
    final color = waterStatusColor(status);
    final hollow = status == WaterStatus.noThreshold;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hollow ? Colors.transparent : color,
        border: hollow ? Border.all(color: color, width: 1.4) : null,
        boxShadow: hollow || status == WaterStatus.stale
            ? null
            : [BoxShadow(color: color.withValues(alpha: .5), blurRadius: 4)],
      ),
    );
  }
}

// ============================================================
// NUMBERS
// ============================================================

/// So le theo SignalChartSpec cua group (code / unit).
int waterDecimals({String? code, String? unit}) {
  return SignalChartSpecRegistry.resolve(code: code, unit: unit).decimals;
}

/// "▲ 0.4 °C/1h" / "▼ 0.12 m/1h"; null khi khong co trend.
String? formatTrend(double? trend, String unit, int decimals) {
  if (trend == null) return null;

  final arrow = trend > 0 ? '▲' : (trend < 0 ? '▼' : '•');
  final value = formatValue(trend.abs(), decimals: decimals);
  final suffix = unit.trim().isEmpty ? '/1h' : ' ${unit.trim()}/1h';

  return '$arrow $value$suffix';
}

/// Tieu de nguong chung cua group: "max 35 °C", "min 0.5 m",
/// "1.5–3.0 kg/cm²". Null khi khong co nguong khong trivial.
String? groupThresholdText(WaterGroup group, int decimals) {
  final rule = group.primaryThreshold;
  if (rule == null) return null;

  final unit = group.unit.trim();
  final low = rule.low;
  final high = rule.high;

  if (low != null && high != null) {
    final range =
        '${formatValue(low, decimals: decimals)}–'
        '${formatValue(high, decimals: decimals)}';
    return unit.isEmpty ? range : '$range $unit';
  }
  if (high != null) {
    return 'max ${formatWithUnit(high, unit, decimals: decimals)}';
  }
  return 'min ${formatWithUnit(low, unit, decimals: decimals)}';
}

/// Ly do cua trang thai (API khong tra truong rieng): suy tu status, gia tri
/// va nguong chung cua group.
String waterReason(WaterSignal signal, WaterGroup group, int decimals) {
  final unit = group.unit;
  final value = signal.value;
  final rule = group.primaryThreshold;
  String fmt(double? v) => formatWithUnit(v, unit, decimals: decimals);

  switch (signal.status) {
    case WaterStatus.stale:
      final lastSeen = signal.lastSeenAt;
      return lastSeen == null
          ? 'No signal'
          : 'No signal since ${formatHhmm(lastSeen)} · last '
                '${fmt(signal.lastValue)}';
    case WaterStatus.noThreshold:
      return value != null && value < 0
          ? 'No limit set · pump stopped?'
          : 'No limit set';
    case WaterStatus.ok:
      return 'Within limits';
    case WaterStatus.near:
    case WaterStatus.over:
      final low = rule?.low;
      final high = rule?.high;
      final over = signal.status == WaterStatus.over;

      // Phia nguong lien quan: phia dang vuot, khong thi phia gan hon.
      final isHigh = value == null
          ? high != null
          : high != null &&
                (low == null ||
                    (over
                        ? value > high
                        : (high - value).abs() < (value - low).abs()));
      final limit = isHigh ? high : low;
      if (limit == null) return over ? 'Out of limit' : 'Near limit';

      final side = isHigh ? 'max' : 'min';
      final distance = signal.distance;
      final gap = distance == null ? '' : ' (${fmt(distance.abs())})';

      return over
          ? '${isHigh ? 'Above' : 'Below'} $side ${fmt(limit)}$gap'
          : 'Near $side ${fmt(limit)}$gap';
  }
}

/// Tooltip cua mot diem do: ten day du, box, PLC, recordedAt, reason, trend1h.
String waterTooltip(WaterSignal signal, WaterGroup group, int decimals) {
  final device = signal.deviceName.isEmpty ? '' : ' (${signal.deviceName})';

  return [
    signal.name,
    'Box: ${signal.boxDeviceId}$device',
    'PLC: ${signal.plcAddress}',
    'Recorded: ${formatDayTime(signal.recordedAt)}',
    'Reason: ${waterReason(signal, group, decimals)}',
    'Trend 1h: '
        '${formatTrend(signal.trend1h, group.unit, decimals) ?? kMissingValue}',
  ].join('\n');
}

// ============================================================
// TIME
// ============================================================

/// "15/10 09:12".
String formatDayTime(DateTime? time) {
  if (time == null) return kMissingValue;
  final d = time.day.toString().padLeft(2, '0');
  final m = time.month.toString().padLeft(2, '0');
  return '$d/$m ${formatHhmm(time)}';
}

final DateFormat _hhmm = DateFormat('HH:mm');

String formatHhmm(DateTime? time) => time == null ? '—' : _hhmm.format(time);

/// "12 min" / "2h 05m".
String formatAge(DateTime since, DateTime now) {
  final minutes = now.difference(since).inMinutes.clamp(0, 1 << 30);
  if (minutes < 60) return '$minutes min';

  final hours = minutes ~/ 60;
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return '${hours}h ${rest}m';
}

/// "since 09:12 (14 min)".
String formatSince(DateTime since, DateTime now) {
  return 'since ${formatHhmm(since)} (${formatAge(since, now)})';
}

// ============================================================
// NAMES
// ============================================================

final RegExp _tokenSplit = RegExp(r'[\s_\-·/]+');

/// Bo phan trung voi ten group: "Cooling tank temperature Tank 1A" trong
/// group "Cooling tank temperature" -> "Tank 1A". Rong khi khong con gi.
String shortSignalName(String name, String groupName) {
  final full = name.trim();
  final group = groupName.trim();
  if (group.isEmpty) return full;

  if (full.toLowerCase().startsWith(group.toLowerCase())) {
    return _trimSeparators(full.substring(group.length));
  }

  final groupTokens = {
    for (final token in group.toLowerCase().split(_tokenSplit))
      if (token.isNotEmpty) token,
  };

  final kept = [
    for (final token in full.split(_tokenSplit))
      if (token.isNotEmpty && !groupTokens.contains(token.toLowerCase())) token,
  ];

  return kept.join(' ');
}

String _trimSeparators(String text) {
  return text.replaceAll(RegExp(r'^[\s_\-·:/()]+|[\s_\-·:/()]+$'), '');
}

/// Ten hien thi cua cac signal trong mot group: ten rut gon; trung nhau hoac
/// rong thi kem deviceName de phan biet.
List<String> displayNamesOf(WaterGroup group) {
  final shorts = [
    for (final signal in group.signals)
      shortSignalName(signal.name, group.name),
  ];

  final counts = <String, int>{};
  for (final short in shorts) {
    counts[short.toLowerCase()] = (counts[short.toLowerCase()] ?? 0) + 1;
  }

  return [
    for (var i = 0; i < shorts.length; i++)
      _withDevice(
        shorts[i],
        group.signals[i],
        duplicated: (counts[shorts[i].toLowerCase()] ?? 0) > 1,
      ),
  ];
}

String _withDevice(
  String short,
  WaterSignal signal, {
  required bool duplicated,
}) {
  final device = signal.deviceName.trim();

  if (short.isEmpty) {
    if (device.isNotEmpty) return device;
    return signal.name.isNotEmpty ? signal.name : signal.plcAddress;
  }
  if (duplicated && device.isNotEmpty) return '$device · $short';
  return short;
}
