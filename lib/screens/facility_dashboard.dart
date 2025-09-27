import 'package:flutter/material.dart';
import '../model/facility_data.dart';
import '../widgets/facility_info_box.dart';
import '../widgets/summary_card.dart';

class FacilityDashboard extends StatelessWidget {
  FacilityDashboard({super.key});

  final List<FacilityData> facilities = [
    FacilityData(
      name: 'Fac A',
      power: 199999,
      volume: 2222,
      pressure: 1234,
      position: Alignment.topRight,
    ),
    FacilityData(
      name: 'Fac B',
      power: 199999,
      volume: 2222,
      pressure: 1234,
      position: Alignment.bottomRight,
    ),
    FacilityData(
      name: 'Fac C',
      power: 199999,
      volume: 2222,
      pressure: 1234,
      position: Alignment.topLeft,
    ),
  ];

  final String mainImageUrl = 'images/factory.jpg';

  @override
  Widget build(BuildContext context) {
    final totalPower = facilities.fold(0.0, (sum, f) => sum + f.power);
    final totalVolume = facilities.fold(0.0, (sum, f) => sum + f.volume);
    final avgPressure =
        facilities.fold(0.0, (sum, f) => sum + f.pressure) / facilities.length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Facility Dashboard'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Facility Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 20),

            // Map background with facility overlay
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.35),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Image.asset(
                        mainImageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      // overlay gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.transparent,
                              Colors.black.withOpacity(0.15),
                            ],
                          ),
                        ),
                      ),
                      // facility boxes
                      Positioned(
                        top: 50,
                        right: 350,
                        child: FacilityInfoBox(facility: facilities[0]),
                      ),
                      Positioned(
                        bottom: 80,
                        right: 350,
                        child: FacilityInfoBox(facility: facilities[1]),
                      ),
                      Positioned(
                        top: 60,
                        left: 20,
                        child: FacilityInfoBox(facility: facilities[2]),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // summary row
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Total Power',
                    value: '${(totalPower / 1000).toStringAsFixed(0)}k kWh',
                    icon: Icons.flash_on,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SummaryCard(
                    title: 'Total Volume',
                    value: '${totalVolume.toStringAsFixed(0)} m³',
                    icon: Icons.water_drop,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SummaryCard(
                    title: 'Avg Pressure',
                    value: '${avgPressure.toStringAsFixed(0)} MPa',
                    icon: Icons.speed,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
