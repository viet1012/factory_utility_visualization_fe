/// View models for the Signal Health Matrix summary rows.
///
/// These stay lightweight records: they only carry what the Error Summary and
/// Box-with-issues ribbons render.
typedef ErrorSummaryItem = ({
  String errorKey,
  String signalName,
  String parameterCode,
  String ruleType,
  int deviceCount,
});

typedef BoxIssueItem = ({String boxDeviceId, int issueCount});

/// Mutable accumulator used while grouping abnormal signals by error key.
///
/// [boxDeviceIds] is a set so a device contributing several occurrences of the
/// same error is still counted once.
class ErrorSummaryAccumulator {
  final String errorKey;
  final String signalName;
  final String parameterCode;
  final String ruleType;
  final Set<String> boxDeviceIds = <String>{};

  ErrorSummaryAccumulator({
    required this.errorKey,
    required this.signalName,
    required this.parameterCode,
    required this.ruleType,
  });
}
