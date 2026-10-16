import 'package:flutter/material.dart';

import '../model/power_usage.dart';
import 'electricity_style.dart';

class TotalCard extends StatelessWidget {
  final PowerUsageResponse data;
  final PowerUnit unit;

  const TotalCard({super.key, required this.data, required this.unit});

  @override
  Widget build(BuildContext context) {
    final total = data.total;
    final usdMode = unit == PowerUnit.usd && total.usd != null;

    final kwh = total.kwh;
    final prev = total.prevKwh;
    final delta = (kwh != null && prev != null) ? kwh - prev : null;

    return ElectricityCard(
      title: 'Total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    usdMode ? fmtUsd(total.usd) : fmtKwh(kwh),
                    style: const TextStyle(
                      color: ElectricityColors.text,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                usdMode ? 'USD' : 'kWh',
                style: const TextStyle(
                  color: ElectricityColors.textDim,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (total.usd != null)
            Text(
              usdMode
                  ? '= ${fmtKwh(kwh)} kWh at blended ${fmtRate(total.blendedRate)}/kWh'
                  : '= ${fmtUsd(total.usd)} at blended ${fmtRate(total.blendedRate)}/kWh',
              style: const TextStyle(
                color: ElectricityColors.textDim,
                fontSize: 11.5,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChangeBadge(changePct: total.changePct, fontSize: 12),
              if (delta != null)
                Text(
                  '${delta >= 0 ? '+' : '-'}${fmtKwh(delta.abs())} kWh',
                  style: TextStyle(
                    color: delta > 0
                        ? ElectricityColors.up
                        : delta < 0
                        ? ElectricityColors.down
                        : ElectricityColors.textDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Previous: ${fmtKwh(prev)} kWh',
            style: const TextStyle(
              color: ElectricityColors.textDim,
              fontSize: 11.5,
            ),
          ),
          if (data.forecast != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: ElectricityColors.cardBorder),
            const SizedBox(height: 10),
            _ForecastBlock(forecast: data.forecast!),
          ],
        ],
      ),
    );
  }
}

class _ForecastBlock extends StatelessWidget {
  final PowerUsageForecast forecast;

  const _ForecastBlock({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final days = forecast.daysInMonth;
    final day = forecast.dayOfMonth.clamp(0, days > 0 ? days : 0);
    final fraction = days > 0 ? day / days : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Month forecast',
          style: TextStyle(color: ElectricityColors.textDim, fontSize: 11.5),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${fmtKwh(forecast.projectedKwh)} kWh',
              style: const TextStyle(
                color: ElectricityColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            ChangeBadge(
              changePct: forecast.changePctVsPrevMonth,
              suffix: 'vs prev month',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: (fraction * 1000).round(),
                  child: const ColoredBox(color: ElectricityColors.facA),
                ),
                Expanded(
                  flex: ((1 - fraction) * 1000).round(),
                  child: const ColoredBox(
                    color: ElectricityColors.track,
                    child: CustomPaint(
                      painter: StripePainter(Color(0xFF2A4565)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'day $day of $days · month to date ${fmtKwh(forecast.monthToDateKwh)} kWh',
          style: const TextStyle(
            color: ElectricityColors.textFaint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
