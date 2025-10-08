import 'package:factory_utility_visualization/model/signal.dart';

class Facility {
  final String fac;
  final String facName;
  final DateTime? lastUpdate;
  final List<Signal> signals;

  Facility({
    required this.fac,
    required this.facName,
    this.lastUpdate,
    required this.signals,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      fac: json['fac'] ?? '',
      facName: json['facName'] ?? '',
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : null,
      signals: (json['signals'] as List)
          .map((e) => Signal.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fac': fac,
      'facName': facName,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'signals': signals.map((e) => e.toJson()).toList(),
    };
  }
}
