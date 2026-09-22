import '../models/signal_health_view_models.dart';

/// A signal counts as abnormal when it reports any status other than OK.
bool isSignalNg(Map<String, dynamic> signal) {
  final status = '${signal['status'] ?? ''}'.trim().toUpperCase();
  return status.isNotEmpty && status != 'OK';
}

String firstNonEmpty(Iterable<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String normalizeSignalName(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Grouping key for the Error Summary.
///
/// Represents the logical signal / error type, never the physical PLC address:
/// two devices exposing the same signal on different addresses must merge into
/// a single summary item.
String signalErrorKey(Map<String, dynamic> signal) {
  final code = firstNonEmpty([signal['parameterCode'], signal['cateId']]);
  if (code.isNotEmpty) return normalizeSignalName(code);

  return normalizeSignalName(
    firstNonEmpty([signal['signalName'], signal['nameEn'], signal['name']]),
  );
}

/// Groups abnormal signals by logical error type, counting DISTINCT devices.
List<ErrorSummaryItem> buildErrorSummary(List<Map<String, dynamic>> rows) {
  final grouped = <String, ErrorSummaryAccumulator>{};

  for (final device in rows) {
    final boxDeviceId = '${device['boxDeviceId'] ?? ''}'.trim();
    final rawSignals = device['signals'];
    if (rawSignals is! List) continue;

    for (final rawSignal in rawSignals) {
      if (rawSignal is! Map) continue;
      final signal = Map<String, dynamic>.from(rawSignal);
      if (!isSignalNg(signal)) continue;

      final signalName = firstNonEmpty([
        signal['signalName'],
        signal['nameEn'],
        signal['name'],
      ]);
      final parameterCode = firstNonEmpty([
        signal['parameterCode'],
        signal['cateId'],
      ]);
      final ruleType = firstNonEmpty([
        signal['ruleType'],
        signal['rule'],
        signal['errorType'],
        signal['status'],
      ], fallback: '-');
      final key = signalErrorKey(signal);
      if (key.isEmpty) continue;

      final entry = grouped.putIfAbsent(
        key,
        () => ErrorSummaryAccumulator(
          errorKey: key,
          signalName: signalName.isEmpty ? parameterCode : signalName,
          parameterCode: parameterCode,
          ruleType: ruleType,
        ),
      );
      if (boxDeviceId.isNotEmpty) {
        entry.boxDeviceIds.add(boxDeviceId);
      }
    }
  }

  final result = grouped.values
      .map(
        (entry) => (
          errorKey: entry.errorKey,
          signalName: entry.signalName,
          parameterCode: entry.parameterCode,
          ruleType: entry.ruleType,
          deviceCount: entry.boxDeviceIds.length,
        ),
      )
      .toList(growable: false);
  result.sort((a, b) {
    final countCompare = b.deviceCount.compareTo(a.deviceCount);
    if (countCompare != 0) return countCompare;
    return a.signalName.toLowerCase().compareTo(b.signalName.toLowerCase());
  });
  return result;
}

/// Counts abnormal signals per box device over the toolbar/search filtered
/// rows, independent of any Error Type selection.
List<BoxIssueItem> buildBoxIssueSummary(List<Map<String, dynamic>> rows) {
  final counts = <String, int>{};

  for (final device in rows) {
    final boxDeviceId = '${device['boxDeviceId'] ?? ''}'.trim();
    if (boxDeviceId.isEmpty) continue;

    final rawSignals = device['signals'];
    if (rawSignals is! List) continue;

    var issueCount = 0;
    for (final rawSignal in rawSignals) {
      if (rawSignal is! Map) continue;
      if (isSignalNg(Map<String, dynamic>.from(rawSignal))) issueCount++;
    }
    if (issueCount == 0) continue;

    counts[boxDeviceId] = (counts[boxDeviceId] ?? 0) + issueCount;
  }

  final result = counts.entries
      .map((e) => (boxDeviceId: e.key, issueCount: e.value))
      .toList();
  result.sort((a, b) {
    final countCompare = b.issueCount.compareTo(a.issueCount);
    if (countCompare != 0) return countCompare;
    return a.boxDeviceId.toLowerCase().compareTo(b.boxDeviceId.toLowerCase());
  });
  return result;
}

/// Narrows rows to devices carrying the selected abnormal error type.
List<Map<String, dynamic>> applyErrorSummaryFilter(
  List<Map<String, dynamic>> filteredRows,
  String? selectedErrorKey,
) {
  final errorKey = selectedErrorKey;
  if (errorKey == null) return filteredRows;

  return filteredRows
      .where((device) {
        final rawSignals = device['signals'];
        if (rawSignals is! List) return false;

        return rawSignals.whereType<Map>().any((rawSignal) {
          final signal = Map<String, dynamic>.from(rawSignal);
          return isSignalNg(signal) && signalErrorKey(signal) == errorKey;
        });
      })
      .toList(growable: false);
}
