import 'dart:async';
import 'package:factory_utility_visualization/api/ApiService.dart';
import 'package:flutter/material.dart';

import '../model/facility_data.dart';
import '../widgets/facility_info_box.dart';
import '../widgets/summary_card.dart';

class FacilityDashboard extends StatelessWidget {
  FacilityDashboard({super.key});

  final String mainImageUrl = 'images/factory.jpg';
  final ApiService api = ApiService();

  Stream<List<FacilityData>> getFacilityStream() async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      final now = DateTime.now().second;

      yield [
        FacilityData(
          name: 'Fac A',
          power: 190000 + (now * 100),
          volume: 2000 + now.toDouble(),
          pressure: 1200 + (now % 50),
          position: Alignment.topRight,
        ),
        FacilityData(
          name: 'Fac B',
          power: await api.fetchElectricValue() ?? (200000 + (now * 80)),
          volume: 2200 + (now % 30),
          pressure: 1230 + (now % 20),
          position: Alignment.bottomRight,
        ),
        FacilityData(
          name: 'Fac C',
          power: 210000 + (now * 50),
          volume: 2100 + (now % 25),
          pressure: 1250 + (now % 40),
          position: Alignment.topLeft,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Facility Dashboard'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<FacilityData>>(
          stream: getFacilityStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final facilities = snapshot.data!;
            final totalPower = facilities.fold(0.0, (sum, f) => sum + f.power);
            final totalVolume = facilities.fold(
              0.0,
              (sum, f) => sum + f.volume,
            );
            final avgPressure =
                facilities.fold(0.0, (sum, f) => sum + f.pressure) /
                facilities.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeNow(context),
                const SizedBox(height: 10),
                Expanded(child: _buildFactoryMap(context, facilities)),
                const SizedBox(height: 20),
                _buildSummaryRow(totalPower, totalVolume, avgPressure),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeNow(BuildContext context) {
    final now = DateTime.now();
    final timeString =
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}:"
        "${now.second.toString().padLeft(2, '0')}";

    return Text(
      "Time: $timeString",
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildFactoryMap(BuildContext context, List<FacilityData> facilities) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
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
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
            ),
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
            Positioned(
              top: screenHeight * 0.03,
              right: screenWidth * 0.2,
              child: FacilityInfoBox(
                facility: facilities[0],
                width: screenWidth * 0.2,
              ),
            ),
            Positioned(
              top: screenHeight * 0.43,
              right: screenWidth * 0.2,
              child: FacilityInfoBox(
                facility: facilities[1],
                width: screenWidth * 0.2,
              ),
            ),
            Positioned(
              top: screenHeight * 0.05,
              left: screenWidth * 0.1,
              child: FacilityInfoBox(facility: facilities[2]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    double totalPower,
    double totalVolume,
    double avgPressure,
  ) {
    return Row(
      children: [
        Expanded(
          child: SummaryCard(
            title: 'Total Power',
            value: '${(totalPower / 1000).toStringAsFixed(0)}k kWh',
            icon: Icons.flash_on,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SummaryCard(
            title: 'Total Volume',
            value: '${totalVolume.toStringAsFixed(0)} m³',
            icon: Icons.water_drop,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SummaryCard(
            title: 'Avg Pressure',
            value: '${avgPressure.toStringAsFixed(0)} MPa',
            icon: Icons.speed,
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}
