import 'dart:math';

import 'package:factory_utility_visualization/utility_models/f2_utility_parameter_history.dart';
import 'package:factory_utility_visualization/utility_models/f2_utility_parameter_master.dart';
import 'package:factory_utility_visualization/utility_models/f2_utility_scada_box.dart';
import 'package:factory_utility_visualization/utility_models/f2_utility_scada_channel.dart';
import 'package:factory_utility_visualization/utility_models/request/utility_series_request.dart';
import 'package:factory_utility_visualization/utility_models/utility_model.dart';

import 'utility_repository.dart';

class _ParamDef {
  final String category;
  final String nameEn;
  final String nameVi;
  final String unit;
  final UtilityValueType valueType;
  final bool isImportant;
  final double? min;
  final double? max;

  const _ParamDef({
    required this.category,
    required this.nameEn,
    required this.nameVi,
    required this.unit,
    required this.valueType,
    required this.isImportant,
    this.min,
    this.max,
  });
}

extension _Dt on DateTime {
  DateTime truncHour() => DateTime(year, month, day, hour);

  DateTime truncDay() => DateTime(year, month, day);

  DateTime truncMonth() => DateTime(year, month, 1);

  DateTime addMonths(int n) => DateTime(year, month + n, 1);
}

class UtilityMockRepository implements UtilityRepository {
  // =========================
  // MOCK CATALOG (RANGE/DEF)
  // =========================
  static const Map<String, List<_ParamDef>> _catalog = {
    'Electricity': [
      _ParamDef(
        category: 'Operating status',
        nameEn: 'Operating status',
        nameVi: 'Trạng thái hoạt động',
        unit: '',
        valueType: UtilityValueType.boolType,
        isImportant: true,
      ),
      _ParamDef(
        category: 'Voltage',
        nameEn: 'Voltage',
        nameVi: 'Điện áp',
        unit: 'V',
        valueType: UtilityValueType.doubleType,
        isImportant: true,
        min: 210,
        max: 240,
      ),
      _ParamDef(
        category: 'Current',
        nameEn: 'Current',
        nameVi: 'Dòng điện',
        unit: 'A',
        valueType: UtilityValueType.doubleType,
        isImportant: true,
        min: 10,
        max: 80,
      ),
      _ParamDef(
        category: 'Power',
        nameEn: 'Power',
        nameVi: 'Công suất',
        unit: 'kW',
        valueType: UtilityValueType.doubleType,
        isImportant: true,
        min: 5,
        max: 120,
      ),
      _ParamDef(
        category: 'Energy Consumption',
        nameEn: 'Energy Consumption',
        nameVi: 'Điện năng tiêu thụ',
        unit: 'kWh',
        valueType: UtilityValueType.doubleType,
        isImportant: true,
        min: 1000,
        max: 9000,
      ),
      _ParamDef(
        category: 'Power factor (cosφ)',
        nameEn: 'Power factor (cosφ)',
        nameVi: 'Hệ số công suất (cosφ)',
        unit: '',
        valueType: UtilityValueType.doubleType,
        isImportant: false,
        min: 0.7,
        max: 1.0,
      ),
      _ParamDef(
        category: 'Harmonic',
        nameEn: 'Harmonic (THD-V)',
        nameVi: 'Sóng hài (THD-V)',
        unit: '%',
        valueType: UtilityValueType.doubleType,
        isImportant: false,
        min: 1,
        max: 10,
      ),
      _ParamDef(
        category: 'Harmonic',
        nameEn: 'Harmonic (THD-I)',
        nameVi: 'Sóng hài (THD-I)',
        unit: '%',
        valueType: UtilityValueType.doubleType,
        isImportant: false,
        min: 1,
        max: 20,
      ),
      _ParamDef(
        category: 'Temperature',
        nameEn: 'Temperature',
        nameVi: 'Nhiệt độ',
        unit: '°C',
        valueType: UtilityValueType.doubleType,
        isImportant: false,
        min: 25,
        max: 60,
      ),
      _ParamDef(
        category: 'Humidity',
        nameEn: 'Humidity',
        nameVi: 'Độ ẩm',
        unit: '%RH',
        valueType: UtilityValueType.doubleType,
        isImportant: false,
        min: 30,
        max: 90,
      ),
    ],
    'Water': [
      _ParamDef(
        category: 'Operating status',
        nameEn: 'Operating status',
        nameVi: 'Trạng thái hoạt động',
        unit: '',
        valueType: UtilityValueType.boolType,
        isImportant: true,
      ),
      _ParamDef(
        category: 'Flow rate',
        nameEn: 'Flow rate',
        nameVi: 'Lưu lượng',
        unit: 'm³/h',
        valueType: UtilityValueType.doubleType,
        isImportant: true,
        min: 2,
        max: 80,
      ),
      _ParamDef(
        category: 'Water level',
        nameEn: 'Water level',
        nameVi: 'Mực nước',
        unit: '%',
        valueType: UtilityValueType.doubleType,
        isImportant: true,
        min: 0,
        max: 100,
      ),
      _ParamDef(
        category: 'Pressure',
        nameEn: 'Pressure',
        nameVi: 'Áp suất',
        unit: 'bar',
        valueType: UtilityValueType.doubleType,
        isImportant: true,
        min: 1,
        max: 10,
      ),
      _ParamDef(
        category: 'Temperature',
        nameEn: 'Temperature',
        nameVi: 'Nhiệt độ',
        unit: '°C',
        valueType: UtilityValueType.doubleType,
        isImportant: false,
        min: 10,
        max: 45,
      ),
    ],
    'Compressed Air': [
      _ParamDef(
        category: 'Operating status',
        nameEn: 'Operating status',
        nameVi: 'Trạng thái hoạt động',
        unit: '',
        valueType: UtilityValueType.boolType,
        isImportant: true,
      ),
      _ParamDef(
        category: 'Pressure',
        nameEn: 'Pressure',
        nameVi: 'Áp suất',
        unit: 'bar',
        valueType: UtilityValueType.doubleType,
        isImportant: true,
        min: 4,
        max: 9,
      ),
      _ParamDef(
        category: 'Temperature',
        nameEn: 'Temperature',
        nameVi: 'Nhiệt độ',
        unit: '°C',
        valueType: UtilityValueType.doubleType,
        isImportant: false,
        min: 20,
        max: 55,
      ),
      _ParamDef(
        category: 'Humidity',
        nameEn: 'Humidity',
        nameVi: 'Độ ẩm',
        unit: '%RH',
        valueType: UtilityValueType.doubleType,
        isImportant: false,
        min: 10,
        max: 60,
      ),
      _ParamDef(
        category: 'Compressed air quality',
        nameEn: 'Compressed air quality',
        nameVi: 'Chất lượng khí nén',
        unit: 'ISO',
        valueType: UtilityValueType.intType,
        isImportant: true,
        min: 1,
        max: 9,
      ),
    ],
  };

  static const List<UtilityScadaBox> _boxes = [
    UtilityScadaBox(
      id: 1,
      scadaId: 'A1',
      facName: 'Factory A',
      plcIp: '192.168.20.1',
      plcPort: 502,
      wlan: null,
    ),
    UtilityScadaBox(
      id: 2,
      scadaId: 'A2',
      facName: 'Factory A',
      plcIp: '192.168.20.2',
      plcPort: 502,
      wlan: null,
    ),
    UtilityScadaBox(
      id: 3,
      scadaId: 'B1',
      facName: 'Factory B',
      plcIp: '192.168.30.1',
      plcPort: 502,
      wlan: 'B-WLAN-01',
    ),
    UtilityScadaBox(
      id: 4,
      scadaId: 'B2',

      facName: 'Factory B',
      plcIp: '192.168.30.2',
      plcPort: 502,
      wlan: 'B-WLAN-02',
    ),
    UtilityScadaBox(
      id: 5,
      scadaId: 'C1',

      facName: 'Factory C',
      plcIp: '192.168.40.1',
      plcPort: 502,
      wlan: 'C-WLAN-01',
    ),
    UtilityScadaBox(
      id: 6,
      scadaId: 'C2',
      facName: 'Factory C',
      plcIp: '192.168.40.2',
      plcPort: 502,
      wlan: null,
    ),
  ];

  // =========================
  // BASIC MOCK TABLES
  // =========================
  @override
  Future<List<UtilityScadaBox>> fetchBoxes() async => _boxes;

  @override
  Future<List<UtilityScadaChannel>> fetchChannels() async {
    int id = 1;
    final out = <UtilityScadaChannel>[];

    for (final b in _boxes) {
      final scada = b.scadaId;
      out.addAll([
        UtilityScadaChannel(
          id: id++,
          scadaId: scada,
          cate: 'Electricity',
          boxDeviceId: '${scada}_ELEC',
          boxId: 'MCCB-$scada',
        ),
        UtilityScadaChannel(
          id: id++,
          scadaId: scada,
          cate: 'Water',
          boxDeviceId: '${scada}_WTR',
          boxId: 'WTR-$scada',
        ),
        UtilityScadaChannel(
          id: id++,
          scadaId: scada,
          cate: 'Compressed Air',
          boxDeviceId: '${scada}_AIR',
          boxId: 'AIR-$scada',
        ),
      ]);
    }

    return out;
  }

  @override
  Future<List<UtilityParameterMaster>> fetchMasters() async {
    final chs = await fetchChannels();
    int id = 1;
    final out = <UtilityParameterMaster>[];

    String addr(int i) => 'D${i + 1}';

    for (final c in chs) {
      final defs = _catalog[c.cate] ?? const [];
      for (int i = 0; i < defs.length; i++) {
        final d = defs[i];
        out.add(
          UtilityParameterMaster(
            id: id++,
            category: d.category,
            nameVi: d.nameVi,
            nameEn: d.nameEn,
            unit: d.unit,
            boxDeviceId: c.boxDeviceId,
            plcAddress: addr(i),
            valueType: d.valueType,
            isImportant: d.isImportant,
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<List<UtilityParameterHistory>> fetchLatestHistories({
    DateTime? at,
    int seed = 1,
  }) async {
    final now = at ?? DateTime.now();
    final masters = await fetchMasters();

    // ✅ Latest = last point của series (cùng seed logic với chart)
    final out = <UtilityParameterHistory>[];

    for (final m in masters) {
      final req = UtilitySeriesRequest(
        facId: _inferFacIdFromDevice(m.boxDeviceId),
        // cần helper suy ra facId
        utility: _inferUtilityFromDevice(m.boxDeviceId),
        // helper suy ra utility
        deviceId: m.boxDeviceId,
        plcAddress: m.plcAddress,
        from: now.subtract(const Duration(hours: 23)),
        to: now,
        bucket: TimeBucket.hour,
        seed: seed, // ✅ dùng chung seed
      );

      final series = await fetchSeries(req);
      if (series.isEmpty) continue;

      out.add(series.last); // ✅ latest = last series point
    }

    return out;
  }

  String _inferUtilityFromDevice(String boxDeviceId) {
    if (boxDeviceId.endsWith('_ELEC')) return 'Electricity';
    if (boxDeviceId.endsWith('_WTR')) return 'Water';
    return 'Compressed Air';
  }

  // ⚠️ bạn cần map deviceId → facId.
  // Với mock của bạn deviceId dạng "A1_ELEC" / "B2_WTR"…
  // suy ra scadaId = split('_').first => tra box để lấy facId.
  String _inferFacIdFromDevice(String boxDeviceId) {
    final scadaId = boxDeviceId.split('_').first; // A1, B2...
    final b = _boxes.firstWhere(
      (x) => x.scadaId == scadaId,
      orElse: () => _boxes.first,
    );
    return b.facName;
  }

  // =========================
  // FLEXIBLE HELPERS FOR UI
  // =========================
  @override
  Future<List<UtilityParameterMaster>> fetchParamsFor({
    required String facId,
    required String utility,
  }) async {
    final boxes = await fetchBoxes();
    final scadas = boxes
        .where((b) => b.facName == facId)
        .map((b) => b.scadaId)
        .toSet();

    final channels = await fetchChannels();
    final devIds = channels
        .where((c) => scadas.contains(c.scadaId) && c.cate == utility)
        .map((c) => c.boxDeviceId)
        .toSet();

    final masters = await fetchMasters();
    return masters.where((m) => devIds.contains(m.boxDeviceId)).toList();
  }

  // =========================
  // SERIES (for charts)
  // =========================
  @override
  Future<List<UtilityParameterHistory>> fetchSeries(
    UtilitySeriesRequest req,
  ) async {
    final deviceId = await _resolveDeviceId(
      facId: req.facId,
      utility: req.utility,
      scadaId: req.scadaId,
      explicitDeviceId: req.deviceId,
    );

    final master = await _resolveMaster(
      deviceId: deviceId,
      plcAddress: req.plcAddress,
    );

    final def = _catalog[req.utility]?.firstWhere(
      (d) => d.nameEn == master.nameEn,
      orElse: () => _fallbackDef(master),
    );

    final used = def ?? _fallbackDef(master);

    final from = _align(req.from, req.bucket, isStart: true);
    final to = _align(req.to, req.bucket, isStart: false);

    final points = _buildTimeline(from, to, req.bucket);
    if (points.isEmpty) return [];

    final stableSeed = _stableSeed(
      '${req.facId}|${req.utility}|$deviceId|${req.plcAddress}|${req.seed}',
    );
    final rnd = Random(stableSeed);

    final min = used.min ?? 0;
    final max = used.max ?? 100;
    final span = (max - min).abs() < 1e-9 ? 1.0 : (max - min);

    double base = min + span * 0.55;
    base += _facBias(req.facId) * span * 0.08;
    base += _utilityBias(req.utility) * span * 0.06;

    // BOOL
    if (used.valueType == UtilityValueType.boolType) {
      return points.map((t) {
        final on = rnd.nextDouble() > 0.25 ? 1 : 0;
        return UtilityParameterHistory(
          id: _histId(t, stableSeed),
          boxDeviceId: deviceId,
          plcAddress: req.plcAddress,
          value: on,
          recordedAt: t,
        );
      }).toList();
    }

    final isInt = used.valueType == UtilityValueType.intType;
    final amp = span * 0.12;
    final noise = span * 0.03;

    final out = <UtilityParameterHistory>[];
    for (int i = 0; i < points.length; i++) {
      final t = points[i];
      final s = _season(t, req.bucket);

      // random walk nhẹ
      base += (rnd.nextDouble() - 0.5) * span * 0.01;

      double v = base + s * amp + (rnd.nextDouble() - 0.5) * 2 * noise;

      // clamp
      if (v < min) v = min + rnd.nextDouble() * noise;
      if (v > max) v = max - rnd.nextDouble() * noise;

      final value = isInt ? v.round() : double.parse(v.toStringAsFixed(2));

      out.add(
        UtilityParameterHistory(
          id: 100000 + i + (stableSeed % 10000),
          boxDeviceId: deviceId,
          plcAddress: req.plcAddress,
          value: value,
          recordedAt: t,
        ),
      );
    }

    return out;
  }

  // =========================
  // INTERNAL HELPERS
  // =========================
  _ParamDef _fallbackDef(UtilityParameterMaster m) {
    if (m.valueType == UtilityValueType.intType) {
      return _ParamDef(
        category: m.category,
        nameEn: m.nameEn,
        nameVi: m.nameVi,
        unit: m.unit,
        valueType: m.valueType,
        isImportant: m.isImportant == true,
        min: 0,
        max: 10,
      );
    }
    return _ParamDef(
      category: m.category,
      nameEn: m.nameEn,
      nameVi: m.nameVi,
      unit: m.unit,
      valueType: m.valueType,
      isImportant: m.isImportant == true,
      min: 0,
      max: 100,
    );
  }

  DateTime _align(DateTime dt, TimeBucket b, {required bool isStart}) {
    switch (b) {
      case TimeBucket.hour:
        return dt.truncHour();
      case TimeBucket.day:
        return dt.truncDay();
      case TimeBucket.month:
        return dt.truncMonth();
    }
  }

  List<DateTime> _buildTimeline(DateTime from, DateTime to, TimeBucket b) {
    if (to.isBefore(from)) return [];
    final out = <DateTime>[];
    var cur = from;

    while (!cur.isAfter(to)) {
      out.add(cur);
      cur = _step(cur, b);
    }
    return out;
  }

  DateTime _step(DateTime dt, TimeBucket b) {
    switch (b) {
      case TimeBucket.hour:
        return dt.add(const Duration(hours: 1));
      case TimeBucket.day:
        return dt.add(const Duration(days: 1));
      case TimeBucket.month:
        return dt.addMonths(1);
    }
  }

  double _season(DateTime t, TimeBucket b) {
    switch (b) {
      case TimeBucket.hour:
        return sin((t.hour / 24.0) * 2 * pi);
      case TimeBucket.day:
        return sin(((t.day - 1) / 30.0) * 2 * pi);
      case TimeBucket.month:
        return sin(((t.month - 1) / 12.0) * 2 * pi);
    }
  }

  double _facBias(String facId) {
    if (facId == 'A') return 0.15;
    if (facId == 'B') return -0.05;
    if (facId == 'C') return 0.05;
    return 0.0;
  }

  double _utilityBias(String utility) {
    if (utility == 'Electricity') return 0.10;
    if (utility == 'Water') return -0.05;
    return 0.00; // Compressed Air
  }

  int _stableSeed(String s) {
    int h = 2166136261;
    for (final c in s.codeUnits) {
      h ^= c;
      h *= 16777619;
    }
    return h.abs();
  }

  int _histId(DateTime t, int seed) =>
      (t.millisecondsSinceEpoch ~/ 1000) ^ seed;

  Future<String> _resolveDeviceId({
    required String facId,
    required String utility,
    String? scadaId,
    String? explicitDeviceId,
  }) async {
    if (explicitDeviceId != null) return explicitDeviceId;

    final boxes = await fetchBoxes();
    final scadas = boxes
        .where((b) => b.facName == facId)
        .map((b) => b.scadaId)
        .toSet();

    final targetScadas = (scadaId != null && scadas.contains(scadaId))
        ? {scadaId}
        : scadas;

    final channels = await fetchChannels();
    final devs = channels
        .where((c) => targetScadas.contains(c.scadaId) && c.cate == utility)
        .toList();

    if (devs.isEmpty) {
      // fallback
      return '${targetScadas.isNotEmpty ? targetScadas.first : "A1"}_ELEC';
    }
    return devs.first.boxDeviceId;
  }

  Future<UtilityParameterMaster> _resolveMaster({
    required String deviceId,
    required String plcAddress,
  }) async {
    final masters = await fetchMasters();
    return masters.firstWhere(
      (x) => x.boxDeviceId == deviceId && x.plcAddress == plcAddress,
      orElse: () => masters.firstWhere((x) => x.boxDeviceId == deviceId),
    );
  }
}
