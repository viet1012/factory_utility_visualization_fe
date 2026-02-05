import 'package:flutter/material.dart';
import '../../kvh_widgets/electricity/power_circular_gauge.dart';
import '../../model/facility_filtered.dart';

class SummaryChartsGrid extends StatelessWidget {
  final List<FacilityFiltered> facilities;

  const SummaryChartsGrid({super.key, required this.facilities});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.16, // giữ tỷ lệ ô đồng nhất
        crossAxisSpacing: 18,
        mainAxisSpacing: 12,
      ),
      itemCount: facilities.length,
      itemBuilder: (context, index) {
        final facility = facilities[index];
        return Column(
          children: [
            // Header
            Container(
              height: 36,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.6),
                    Colors.black.withOpacity(0.3),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Text(
                  facility.fac,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Power gauge
            SizedBox(
              height: 120,
              child: PowerCircularGauge(facility: facility),
            ),
            const SizedBox(height: 10),
            // Bạn có thể thêm các gauge khác sau này:
            // SizedBox(height: 120, child: CustomWaterWaveGauge(facility: facility, maxVolume: 6000)),
            // SizedBox(height: 150, child: AirTankIndicator(facility: facility)),
            // SizedBox(height: 150, child: TemperatureThermometer(facility: facility)),
          ],
        );
      },
    );
  }
}
