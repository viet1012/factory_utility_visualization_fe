import '../../utility_dashboard_overview/'
    'utility_dashboard_overview_models/latest_tree_response.dart';

class FacDeviceViewData {
  final String boxDeviceId;
  final Set<String> categories;
  final Set<String> scadaIds;
  final List<LatestSignalDto> signals;

  FacDeviceViewData({
    required this.boxDeviceId,
    Set<String>? categories,
    Set<String>? scadaIds,
    List<LatestSignalDto>? signals,
  }) : categories = categories ?? <String>{},
       scadaIds = scadaIds ?? <String>{},
       signals = signals ?? <LatestSignalDto>[];

  String? get primaryCategory {
    final values =
        categories
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList()
          ..sort(_compareText);

    return values.isEmpty ? null : values.first;
  }

  String get scadaText {
    final values =
        scadaIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList()
          ..sort(_compareText);

    return values.join(', ');
  }

  static int _compareText(String first, String second) {
    return first.trim().toLowerCase().compareTo(second.trim().toLowerCase());
  }
}
