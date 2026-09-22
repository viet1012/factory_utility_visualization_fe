/// View model noi bo cua Utility Catalog monitor mode.
///
/// Tach ra khoi man hinh de cac widget con dung chung ma khong phai
/// nam cung mot file.
library;

// ============================================================
// FLATTENED TABLE ROW
// ============================================================

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

  /*
   * Các giá trị đã chuẩn hóa.
   * Không cần trim lại trong mỗi lần build.
   */
  final String normalizedFacility;
  final String normalizedCategory;
  final String normalizedRawCategory;

  final String normalizedScadaId;
  final String normalizedBoxId;
  final String normalizedBoxDeviceId;

  final String normalizedPlcAddress;
  final String normalizedCateId;
  final String normalizedSignalName;
  final String normalizedUnit;

  final String searchBaseText;

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
  }) : normalizedFacility = facility.trim(),
       normalizedCategory = category.trim(),
       normalizedRawCategory = rawCategory.trim(),

       normalizedScadaId = scadaId.trim(),
       normalizedBoxId = boxId.trim(),
       normalizedBoxDeviceId = boxDeviceId.trim(),

       normalizedPlcAddress = plcAddress.trim(),
       normalizedCateId = cateId.trim(),
       normalizedSignalName = signalName.trim(),
       normalizedUnit = unit.trim(),

       searchBaseText = [
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
       ].join('|').toLowerCase();

  // ============================================================
  // STATUS
  // ============================================================

  bool isStaleAt(DateTime now) {
    final time = recordedAt;

    if (time == null) {
      return true;
    }

    final localTime = time.toLocal();

    return now.difference(localTime) > const Duration(minutes: 2);
  }

  /*
   * Dùng cho những chỗ không truyền now.
   * Trong vòng lặp nhiều row nên ưu tiên isStaleAt(now).
   */
  bool get isStale {
    return isStaleAt(DateTime.now());
  }

  String statusLabelAt(DateTime now) {
    return isStaleAt(now) ? 'Stale' : 'Online';
  }

  String get statusLabel {
    return isStale ? 'Stale' : 'Online';
  }

  // ============================================================
  // DISPLAY
  // ============================================================

  String get displaySignalName {
    if (normalizedSignalName.isNotEmpty) {
      return normalizedSignalName;
    }

    if (normalizedCateId.isNotEmpty) {
      return normalizedCateId;
    }

    return '--';
  }

  String get displayValue {
    final currentValue = value;

    if (currentValue == null || !currentValue.isFinite) {
      return '--';
    }

    final valueText = currentValue.abs() >= 1000
        ? currentValue.toStringAsFixed(1)
        : currentValue.toStringAsFixed(2);

    if (normalizedUnit.isEmpty) {
      return valueText;
    }

    return '$valueText $normalizedUnit';
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

  // ============================================================
  // SEARCH
  // ============================================================

  String searchTextAt(DateTime now) {
    return '$searchBaseText|'
        '${displayValue.toLowerCase()}|'
        '${statusLabelAt(now).toLowerCase()}';
  }

  String get searchText {
    return searchTextAt(DateTime.now());
  }

  static String _two(int value) {
    return value.toString().padLeft(2, '0');
  }
}

enum DeviceHealth { online, warning, offline }

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

  DeviceHealth get health {
    if (signals.isEmpty || staleCount == signalCount) {
      return DeviceHealth.offline;
    }

    if (staleCount > 0) {
      return DeviceHealth.warning;
    }

    return DeviceHealth.online;
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
  final String scadaId;
  final String boxId;
  final List<CatalogDeviceGroup> devices;

  const CatalogTreeGroup({
    required this.key,
    required this.scadaId,
    required this.boxId,
    required this.devices,
  });

  int get deviceCount => devices.length;

  int get signalCount {
    return devices.fold(0, (total, device) => total + device.signalCount);
  }

  int get staleDeviceCount {
    return devices
        .where((device) => device.health != DeviceHealth.online)
        .length;
  }
}
// ============================================================
// SUMMARY
// ============================================================

class CatalogSummary {
  final int facilities;
  final int devices;
  final int signals;
  final int online;
  final int stale;

  const CatalogSummary({
    required this.facilities,
    required this.devices,
    required this.signals,
    required this.online,
    required this.stale,
  });

  factory CatalogSummary.fromRows(List<CatalogTableRow> rows) {
    final facilities = <String>{};
    final devices = <String>{};

    var online = 0;
    var stale = 0;

    for (final row in rows) {
      facilities.add(row.facility);

      devices.add(
        '${row.facility}|'
        '${row.scadaId}|'
        '${row.boxId}|'
        '${row.boxDeviceId}',
      );

      if (row.isStale) {
        stale++;
      } else {
        online++;
      }
    }

    return CatalogSummary(
      facilities: facilities.length,
      devices: devices.length,
      signals: rows.length,
      online: online,
      stale: stale,
    );
  }
}
