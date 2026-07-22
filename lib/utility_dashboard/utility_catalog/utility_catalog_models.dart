

class CatalogTableRow {
  final String facility;
  final String category;
  final String rawCategory;

  final String scadaId;
  final String boxId;
  final String boxDeviceId;

  final String plcAddress;
  final String cateId;
  final String signalName;

  final double? value;
  final String unit;
  final DateTime? recordedAt;

  CatalogTableRow({
    required this.facility,
    required this.category,
    required this.rawCategory,
    required this.scadaId,
    required this.boxId,
    required this.boxDeviceId,
    required this.plcAddress,
    required this.cateId,
    required this.signalName,
    required this.value,
    required this.unit,
    required this.recordedAt,
  });

  bool isStaleAt(DateTime now) {
    final time = recordedAt;

    if (time == null) {
      return true;
    }

    return now.difference(time.toLocal()) > const Duration(minutes: 2);
  }

  bool get isStale {
    return isStaleAt(DateTime.now());
  }

  String get statusLabel {
    return isStale ? 'Stale' : 'Online';
  }

  String statusLabelAt(DateTime now) {
    return isStaleAt(now) ? 'Stale' : 'Online';
  }

  String get displaySignalName {
    final name = signalName.trim();

    if (name.isNotEmpty) {
      return name;
    }

    final id = cateId.trim();

    return id.isEmpty ? '--' : id;
  }

  String get displayValue {
    final currentValue = value;

    if (currentValue == null) {
      return '--';
    }

    final valueText = currentValue.abs() >= 1000
        ? currentValue.toStringAsFixed(1)
        : currentValue.toStringAsFixed(2);

    final normalizedUnit = unit.trim();

    return normalizedUnit.isEmpty ? valueText : '$valueText $normalizedUnit';
  }

  String get displayTime {
    final time = recordedAt;

    if (time == null) {
      return '--';
    }

    final local = time.toLocal();

    return '${_two(local.day)}/'
        '${_two(local.month)}/'
        '${local.year} '
        '${_two(local.hour)}:'
        '${_two(local.minute)}:'
        '${_two(local.second)}';
  }

  String searchTextAt(DateTime now) {
    return [
      facility,
      category,
      rawCategory,
      scadaId,
      boxId,
      boxDeviceId,
      plcAddress,
      cateId,
      signalName,
      unit,
      displayValue,
      statusLabelAt(now),
    ].join('|').toLowerCase();
  }

  static String _two(int value) {
    return value.toString().padLeft(2, '0');
  }
}

enum CatalogDeviceHealth { online, warning, offline }

class CatalogDeviceGroup {
  final String key;

  final String facility;
  final String category;
  final String scadaId;
  final String boxId;
  final String boxDeviceId;

  final List<CatalogTableRow> signals;

  const CatalogDeviceGroup({
    required this.key,
    required this.facility,
    required this.category,
    required this.scadaId,
    required this.boxId,
    required this.boxDeviceId,
    required this.signals,
  });

  int get signalCount => signals.length;

  int get staleCount {
    return signals.where((item) => item.isStale).length;
  }

  int get onlineCount {
    return signalCount - staleCount;
  }

  CatalogDeviceHealth get health {
    if (signals.isEmpty || staleCount == signalCount) {
      return CatalogDeviceHealth.offline;
    }

    if (staleCount > 0) {
      return CatalogDeviceHealth.warning;
    }

    return CatalogDeviceHealth.online;
  }

  DateTime? get lastUpdated {
    DateTime? latest;

    for (final signal in signals) {
      final time = signal.recordedAt;

      if (time == null) continue;

      if (latest == null || time.isAfter(latest)) {
        latest = time;
      }
    }

    return latest;
  }
}

class CatalogTreeGroup {
  final String key;
  final String facility;
  final String category;
  final String scadaId;
  final String boxId;

  final List<CatalogDeviceGroup> devices;

  const CatalogTreeGroup({
    required this.key,
    required this.facility,
    required this.category,
    required this.scadaId,
    required this.boxId,
    required this.devices,
  });

  int get deviceCount => devices.length;

  int get signalCount {
    return devices.fold(0, (total, device) => total + device.signalCount);
  }

  int get staleDeviceCount {
    return devices.where((device) {
      return device.health != CatalogDeviceHealth.online;
    }).length;
  }
}
