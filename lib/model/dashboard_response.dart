import 'facility.dart';

class DashboardResponse {
  final DateTime timestamp;
  final List<Facility> facilities;

  DashboardResponse({required this.timestamp, required this.facilities});

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    return DashboardResponse(
      timestamp: DateTime.parse(json['timestamp']),
      facilities: (json['facilities'] as List)
          .map((e) => Facility.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'facilities': facilities.map((e) => e.toJson()).toList(),
    };
  }
}
