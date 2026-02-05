import 'package:flutter/material.dart';
import '../../model/facility_filtered.dart';
import '../../model/signal.dart';

class SummaryColumn extends StatelessWidget {
  final List<FacilityFiltered> facilities;      // NOW
  final List<FacilityFiltered> prevFacilities;  // PREV

  const SummaryColumn({
    super.key,
    required this.facilities,
    required this.prevFacilities,
  });

  @override
  Widget build(BuildContext context) {
    if (facilities.isEmpty) return const SizedBox();

    final totalPowerNow = _sumByKey(facilities, 'electricity');
    final totalPowerPrev =
    prevFacilities.isEmpty ? null : _sumByKey(prevFacilities, 'electricity');

    final totalVolumeNow = _sumByKey(facilities, 'volume');
    final totalVolumePrev =
    prevFacilities.isEmpty ? null : _sumByKey(prevFacilities, 'volume');

    final powerUnit = _unitOfFirstMatch(facilities, 'electricity');
    final volumeUnit = _unitOfFirstMatch(facilities, 'volume');

    final powerTrend = _calcTrend(oldValue: totalPowerPrev, newValue: totalPowerNow);
    final volumeTrend = _calcTrend(oldValue: totalVolumePrev, newValue: totalVolumeNow);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'TOTAL POWER',
                oldValue: totalPowerPrev,
                newValue: totalPowerNow,
                unit: powerUnit,
                icon: Icons.flash_on,
                color: const Color(0xff0e3ed3),
                colorIcon: Colors.orangeAccent,
                trendValue: powerTrend,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'TOTAL VOLUME',
                oldValue: totalVolumePrev,
                newValue: totalVolumeNow,
                unit: volumeUnit,
                icon: Icons.water_drop_outlined,
                color: const Color(0xff0e3ed3),
                colorIcon: const Color(0xff0e3ed3),
                trendValue: volumeTrend,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FacilityTrendAnalysis(
          facilities: facilities,
          prevFacilities: prevFacilities,
        ),
      ],
    );
  }

  // =========================
  // Helpers
  // =========================

  static double _sumByKey(List<FacilityFiltered> list, String key) {
    final k = key.toLowerCase();
    double sum = 0.0;
    for (final f in list) {
      sum += _valueByDescContains(f, k);
    }
    return sum;
  }

  static String _unitOfFirstMatch(List<FacilityFiltered> list, String key) {
    final k = key.toLowerCase();
    final f0 = list.first;
    final s = f0.signals.firstWhere(
          (s) => (s.description).toLowerCase().contains(k),
      orElse: () => f0.signals.first,
    );
    return s.unit;
  }

  static double _valueByDescContains(FacilityFiltered facility, String lowerKey) {
    final s = facility.signals.firstWhere(
          (s) => (s.description).toLowerCase().contains(lowerKey),
      orElse: () => facility.signals.first,
    );
    return s.value;
  }

  static double _calcTrend({required double? oldValue, required double newValue}) {
    if (oldValue == null || oldValue == 0) return 0;
    return ((newValue - oldValue) / oldValue) * 100;
  }
}

// ============ SUMMARY CARD ============
class _SummaryCard extends StatelessWidget {
  final String title;
  final double? oldValue;
  final double newValue;
  final String unit;
  final IconData icon;
  final Color color;
  final Color colorIcon;
  final double trendValue;

  const _SummaryCard({
    required this.title,
    required this.oldValue,
    required this.newValue,
    required this.unit,
    required this.icon,
    required this.color,
    required this.colorIcon,
    required this.trendValue,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = trendValue >= 0;
    final trendColor = isUp ? Colors.redAccent : Colors.green;
    final trendText =
    isUp ? "▲ ${trendValue.toStringAsFixed(1)}%" : "▼ ${trendValue.abs().toStringAsFixed(1)}%";

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent.withOpacity(0.8),
                ),
                child: Icon(icon, color: colorIcon, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trendText,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                newValue.toStringAsFixed(2),
                style: TextStyle(
                  color: const Color(0xFF00F5FF),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: color, blurRadius: 10)],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ],
          ),
          if (oldValue != null) ...[
            const SizedBox(height: 4),
            Text(
              "Previous: ${oldValue!.toStringAsFixed(2)} $unit",
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// ============ CHART : FACILITY TREND ANALYSIS (NOW vs PREV) ============
class _FacilityTrendAnalysis extends StatelessWidget {
  final List<FacilityFiltered> facilities; // NOW
  final List<FacilityFiltered> prevFacilities; // PREV snapshot

  const _FacilityTrendAnalysis({
    required this.facilities,
    required this.prevFacilities,
  });

  @override
  Widget build(BuildContext context) {
    final prevByFac = <String, FacilityFiltered>{
      for (final f in prevFacilities) f.fac: f,
    };

    final trendData = facilities.map((nowFac) {
      final nowPowerSignals = _signalsByDesc(nowFac, 'electricity');
      final nowVolSignals = _signalsByDesc(nowFac, 'volume');

      final currentPowerByUnit = _sumByUnit(nowPowerSignals);
      final currentVolByUnit = _sumByUnit(nowVolSignals);

      final prevFac = prevByFac[nowFac.fac];
      final oldPowerByUnit = prevFac == null
          ? null
          : _sumByUnit(_signalsByDesc(prevFac, 'electricity'));
      final oldVolByUnit =
      prevFac == null ? null : _sumByUnit(_signalsByDesc(prevFac, 'volume'));

      return FacilityTrendData(
        name: nowFac.fac,
        currentPowerByUnit: currentPowerByUnit,
        currentVolumeByUnit: currentVolByUnit,
        oldPowerByUnit: oldPowerByUnit,
        oldVolumeByUnit: oldVolByUnit,
      );
    }).toList();

    // ✅ nếu muốn cố định Fac A/B/C:
    // const order = ['Fac A', 'Fac B', 'Fac C'];
    // trendData.sort((a,b) => order.indexOf(a.name).compareTo(order.indexOf(b.name)));

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB000FF).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB000FF).withOpacity(0.2),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: trendData.map(_buildRow).toList(),
      ),
    );
  }

  // =========================
  // UI row builder
  // =========================




  Widget _buildRow(FacilityTrendData data) {
    // trend theo từng unit
    final powerTrendByUnit =
    _trendByUnit(data.oldPowerByUnit, data.currentPowerByUnit);
    final volTrendByUnit =
    _trendByUnit(data.oldVolumeByUnit, data.currentVolumeByUnit);

    // chọn unit chính để quyết định màu/icon (ưu tiên kW rồi tới %)
    final powerMainUnit = _pickMainUnit(data.currentPowerByUnit);
    final volMainUnit = _pickMainUnit(data.currentVolumeByUnit);

    final powerMainTrend = powerTrendByUnit[powerMainUnit] ?? 0.0;
    final volMainTrend = volTrendByUnit[volMainUnit] ?? 0.0;

    final isPowerUp = powerMainTrend > 0;
    final isVolumeUp = volMainTrend > 0;

    final powerColor = isPowerUp ? Colors.redAccent : Colors.green;
    final volumeColor = isVolumeUp ? Colors.redAccent : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Facility name
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFB000FF),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0xFFB000FF), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.name,
                  style: TextStyle(
                    color: Colors.grey[200],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _metricRowMulti(
            label: 'Power',
            icon: const Icon(Icons.flash_on, color: Colors.orange, size: 14),
            nowByUnit: data.currentPowerByUnit,
            prevByUnit: data.oldPowerByUnit,
            trendByUnit: powerTrendByUnit,
            mainColor: powerColor,
          ),
          const SizedBox(height: 8),
          _metricRowMulti(
            label: 'Volume',
            icon: const Icon(Icons.water_drop, color: Color(0xFF00F5FF), size: 14),
            nowByUnit: data.currentVolumeByUnit,
            prevByUnit: data.oldVolumeByUnit,
            trendByUnit: volTrendByUnit,
            mainColor: volumeColor,
          ),
        ],
      ),
    );
  }

  Widget _metricRowMulti({
    required String label,
    required Widget icon,
    required Map<String, double> nowByUnit,
    required Map<String, double>? prevByUnit,
    required Map<String, double> trendByUnit,
    required Color mainColor,
  }) {
    final units = trendByUnit.keys.toList()
      ..sort((a, b) => _unitRank(a).compareTo(_unitRank(b)));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: 8),

        // ===== TREND LIST (mỗi unit 1 dòng) =====
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: units.map((unit) {
              final trend = trendByUnit[unit] ?? 0.0;
              final isUp = trend >= 0;
              final color = isUp ? Colors.redAccent : Colors.green;

              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      unit,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: color,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(width: 8),

        // ===== NOW / PREV =====
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Now: ${_fmtByUnit(nowByUnit)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
            if (prevByUnit != null)
              Text(
                'Prev: ${_fmtByUnit(prevByUnit)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ],
    );
  }


  // =========================
  // Data helpers
  // =========================

  static List<Signal> _signalsByDesc(FacilityFiltered f, String key) {
    final k = key.toLowerCase();
    return f.signals
        .where((s) => s.description.toLowerCase().contains(k))
        .toList();
  }

  /// sum theo unit: kW, %, m3/h...
  static Map<String, double> _sumByUnit(List<Signal> signals) {
    final map = <String, double>{};
    for (final s in signals) {
      final unit = (s.unit).trim().isEmpty ? '-' : s.unit.trim();
      map[unit] = (map[unit] ?? 0.0) + s.value;
    }
    return map;
  }

  static double _trend(double? oldValue, double newValue) {
    if (oldValue == null || oldValue == 0) return 0;
    return ((newValue - oldValue) / oldValue) * 100;
  }

  static Map<String, double> _trendByUnit(
      Map<String, double>? oldMap,
      Map<String, double> newMap,
      ) {
    final keys = {...?oldMap?.keys, ...newMap.keys};
    final out = <String, double>{};
    for (final k in keys) {
      out[k] = _trend(oldMap?[k], newMap[k] ?? 0);
    }
    return out;
  }

  static String _fmtByUnit(Map<String, double> m) {
    if (m.isEmpty) return '-';
    // ưu tiên kW trước, rồi %, rồi còn lại
    final entries = m.entries.toList()
      ..sort((a, b) => _unitRank(a.key).compareTo(_unitRank(b.key)));
    return entries.map((e) => '${e.value.toStringAsFixed(2)} ${e.key}').join(' | ');
  }

  static String _pickMainUnit(Map<String, double> m) {
    if (m.containsKey('kW')) return 'kW';
    if (m.containsKey('%')) return '%';
    if (m.isNotEmpty) return m.keys.first;
    return '-';
  }

  static int _unitRank(String unit) {
    if (unit == 'kW') return 0;
    if (unit == '%') return 1;
    return 99;
  }
}

// ============ MODEL ============
class FacilityTrendData {
  final String name;

  final Map<String, double> currentPowerByUnit; // vd: {'kW': 78.7, '%': 62.3}
  final Map<String, double> currentVolumeByUnit;

  final Map<String, double>? oldPowerByUnit;
  final Map<String, double>? oldVolumeByUnit;

  FacilityTrendData({
    required this.name,
    required this.currentPowerByUnit,
    required this.currentVolumeByUnit,
    this.oldPowerByUnit,
    this.oldVolumeByUnit,
  });
}

