import '../../shared/json/json_read.dart';

class LatestFacilityDto {
  final String fac;
  final List<LatestCategoryDto> categories;

  const LatestFacilityDto({required this.fac, required this.categories});

  factory LatestFacilityDto.fromJson(Map<String, dynamic> json) {
    return LatestFacilityDto(
      fac: jsonText(json['fac']),
      categories: _readList(json['categories'], LatestCategoryDto.fromJson),
    );
  }
}

class LatestCategoryDto {
  final String cate;
  final List<LatestScadaDto> scadas;

  const LatestCategoryDto({required this.cate, required this.scadas});

  factory LatestCategoryDto.fromJson(Map<String, dynamic> json) {
    return LatestCategoryDto(
      cate: jsonText(json['cate']),
      scadas: _readList(json['scadas'], LatestScadaDto.fromJson),
    );
  }
}

class LatestScadaDto {
  final String scadaId;
  final List<LatestBoxDto> boxes;

  const LatestScadaDto({required this.scadaId, required this.boxes});

  factory LatestScadaDto.fromJson(Map<String, dynamic> json) {
    return LatestScadaDto(
      scadaId: jsonText(json['scadaId']),
      boxes: _readList(json['boxes'], LatestBoxDto.fromJson),
    );
  }
}

class LatestBoxDto {
  final String boxId;
  final List<LatestDeviceDto> devices;

  const LatestBoxDto({required this.boxId, required this.devices});

  factory LatestBoxDto.fromJson(Map<String, dynamic> json) {
    return LatestBoxDto(
      boxId: jsonText(json['boxId']),
      devices: _readList(json['devices'], LatestDeviceDto.fromJson),
    );
  }
}

class LatestDeviceDto {
  final String boxDeviceId;
  final List<LatestSignalDto> signals;

  const LatestDeviceDto({required this.boxDeviceId, required this.signals});

  factory LatestDeviceDto.fromJson(Map<String, dynamic> json) {
    return LatestDeviceDto(
      boxDeviceId: jsonText(json['boxDeviceId']),
      signals: _readList(json['signals'], LatestSignalDto.fromJson),
    );
  }
}

class LatestSignalDto {
  final String plcAddress;
  final String cateId;
  final String nameEn;
  final double? value;
  final String unit;
  final DateTime? recordedAt;

  /// "ANALOG" | "COUNTER" | "STATUS" (null khi backend khong tra).
  final String? kind;

  const LatestSignalDto({
    required this.plcAddress,
    required this.cateId,
    required this.nameEn,
    required this.value,
    required this.unit,
    required this.recordedAt,
    this.kind,
  });

  factory LatestSignalDto.fromJson(Map<String, dynamic> json) {
    return LatestSignalDto(
      plcAddress: jsonText(json['plcAddress']),
      cateId: jsonText(json['cateId']),
      nameEn: jsonText(json['nameEn']),
      value: jsonDouble(json['value']),
      unit: jsonText(json['unit']),
      recordedAt: _readDateTime(json['recordedAt']),
      kind: switch (jsonText(json['kind']).toUpperCase()) {
        '' => null,
        final kind => kind,
      },
    );
  }
}

List<T> _readList<T>(dynamic raw, T Function(Map<String, dynamic>) parser) {
  if (raw is! List) {
    return const [];
  }

  return List<T>.unmodifiable(
    raw.whereType<Map>().map((item) => parser(Map<String, dynamic>.from(item))),
  );
}

/// Khong doi sang local (khac [jsonDateTime]): giu mui gio cua chuoi.
DateTime? _readDateTime(dynamic value) {
  if (value == null) return null;

  return DateTime.tryParse(value.toString());
}
