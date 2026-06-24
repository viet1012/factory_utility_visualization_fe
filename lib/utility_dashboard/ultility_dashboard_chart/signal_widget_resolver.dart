enum SignalWidgetType {
  pressure,
  tankLevel,
  temperature,
  humidity,
  flow,
  energy,
  lineChart,
  hidden,
}

class SignalWidgetResolver {
  static SignalWidgetType resolve(String? nameEn) {
    final n = (nameEn ?? '').toLowerCase();

    if (n.contains('slave')) {
      return SignalWidgetType.hidden;
    }

    if (n.contains('water level') || n.contains('reservoir')) {
      return SignalWidgetType.tankLevel;
    }

    if (n.contains('pressure')) {
      return SignalWidgetType.pressure;
    }

    if (n.contains('temperature')) {
      return SignalWidgetType.temperature;
    }

    if (n.contains('humidity') || n.contains('humity')) {
      return SignalWidgetType.humidity;
    }

    if (n.contains('flow')) {
      return SignalWidgetType.flow;
    }

    if (n.contains('energy') ||
        n.contains('power') ||
        n.contains('consumption')) {
      return SignalWidgetType.energy;
    }

    return SignalWidgetType.lineChart;
  }
}
