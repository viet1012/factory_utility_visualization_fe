import '../controllers/utility_chart_catalog_controller.dart';

/// Device -> PLC da sort cua cac signal dang hien thi (catalog da loc
/// Important / slave), dung chung cho Minutes / Hourly / Daily.
///
/// [selectedBox] = 'ALL' (hoac rong): moi device; khac: chi device do.
/// Device khong con signal nao thi khong co trong map nen khong goi request.
Map<String, List<String>> resolvePlcsByBox(
  List<SignalChartConfig> charts,
  String selectedBox,
) {
  final selected = selectedBox.trim().toUpperCase();
  final showAll = selected.isEmpty || selected == 'ALL';

  final result = <String, Set<String>>{};

  for (final chart in charts) {
    final deviceId = chart.boxDeviceId.trim();
    final plc = chart.plcAddress.trim();

    if (deviceId.isEmpty || plc.isEmpty) continue;
    if (!showAll && deviceId.toUpperCase() != selected) continue;

    result.putIfAbsent(deviceId, () => <String>{}).add(plc);
  }

  final devices = result.keys.toList()..sort();

  return {
    for (final device in devices) device: result[device]!.toList()..sort(),
  };
}

/// Dinh danh request cua [plcsByBox] (khong bao gio rong, ke ca map rong).
String plcsByBoxSignature(
  Map<String, List<String>> plcsByBox, {
  String prefix = '',
}) {
  return [
    'req:$prefix',
    for (final MapEntry(key: device, value: plcs) in plcsByBox.entries)
      '$device:${plcs.join(',')}',
  ].join('|');
}
