import 'package:factory_utility_visualization/model/signal.dart';

class FacilityFiltered {
  final String fac;
  final String facName;
  final List<Signal> signals;

  FacilityFiltered({
    required this.fac,
    required this.facName,
    required this.signals,
  });
}
