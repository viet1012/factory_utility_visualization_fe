import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/power_usage.dart';
import 'electricity_style.dart';

Color supplyColor(PowerSupplyBandType type) => switch (type) {
  PowerSupplyBandType.highPeak => ElectricityColors.highPeak,
  PowerSupplyBandType.normal => ElectricityColors.normal,
  PowerSupplyBandType.lowPeak => ElectricityColors.lowPeak,
  PowerSupplyBandType.solar => ElectricityColors.solar,
  PowerSupplyBandType.unknown => ElectricityColors.other,
};

class SupplyMixCard extends StatelessWidget {
  final PowerUsageResponse data;

  const SupplyMixCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final bands = data.supplyMix
        .where((b) => (b.sharePct ?? 0) > 0)
        .toList(growable: false);
    final solar = data.solarBand;

    final summary = data.supplyMix.isEmpty
        ? null
        : [
            if (solar != null) 'Solar covers ${fmtPct(solar.sharePct)}',
            'blended ${fmtRate(data.total.blendedRate)}',
            'total ${fmtUsd(data.total.usd)}',
          ].join(' · ');

    return ElectricityCard(
      title: 'Energy supply mix',
      trailing: summary == null
          ? null
          : Text(
              summary,
              style: const TextStyle(
                color: ElectricityColors.textDim,
                fontSize: 11.5,
              ),
            ),
      child: data.supplyMix.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tariff bands not configured',
                style: TextStyle(
                  color: ElectricityColors.textDim,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        for (final band in bands)
                          Expanded(
                            flex: _flex(band),
                            child: Container(
                              color: supplyColor(band.type),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                '${band.label} ${fmtPct(band.sharePct)}',
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  color:
                                      band.type == PowerSupplyBandType.lowPeak
                                      ? const Color(0xFF0B2545)
                                      : Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final band in bands)
                      Expanded(
                        flex: _flex(band),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            '${fmtMwh(band.kwh)} MWh @ ${fmtRate(band.rate)} = ${fmtUsd(band.usd)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ElectricityColors.textDim,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (solar != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Cost includes solar purchased at 83% of tariff',
                    style: TextStyle(
                      color: ElectricityColors.textFaint,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// Phan doan qua nho van du cho de doc nhan.
  static int _flex(PowerSupplyBand band) =>
      math.max(30, ((band.sharePct ?? 0) * 10).round());
}
