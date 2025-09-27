import 'package:flutter/material.dart';
import '../main.dart';
import '../model/facility_data.dart';
import '../widgets/facility_info_box.dart';
import '../widgets/summary_card.dart';

class FacilityDashboard extends StatelessWidget {
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

  final String mainImageUrl = 'images/factory.jpg'; // asset local

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Facility Dashboard'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Facility Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: Offset(0, 5),
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

                      // Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.transparent,
                              Colors.black.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),

                      // Info boxes
                      Stack(
                        children: [
                          Image.asset(
                            mainImageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),

                          // FAC A - top right
                          Positioned(
                            top: 50, // điều chỉnh theo ảnh thực tế
                            right: 400,
                            child: FacilityInfoBox(
                              facility: FacilityData(
                                name: 'Fac A',
                                power: 199999,
                                volume: 2222,
                                pressure: 1234,
                                position: Alignment.topRight,
                              ),
                            ),
                          ),

                          // FAC B - bottom right
                          Positioned(
                            bottom: 80,
                            right: 400,
                            child: FacilityInfoBox(
                              facility: FacilityData(
                                name: 'Fac B',
                                power: 199999,
                                volume: 2222,
                                pressure: 1234,
                                position: Alignment.bottomRight,
                              ),
                            ),
                          ),

                          // FAC C - top left
                          Positioned(
                            top: 60,
                            left: 20,
                            child: FacilityInfoBox(
                              facility: FacilityData(
                                name: 'Fac C',
                                power: 199999,
                                volume: 2222,
                                pressure: 1234,
                                position: Alignment.topLeft,
                              ),
                            ),
                          ),

                          // Optional Title
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Summary cards
            Container(
              height: 80,
              child: Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Total Power',
                      value:
                          '${(facilities.fold(0.0, (sum, f) => sum + f.power) / 1000).toStringAsFixed(0)}k kWh',
                      icon: Icons.flash_on,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SummaryCard(
                      title: 'Total Volume',
                      value:
                          '${(facilities.fold(0.0, (sum, f) => sum + f.volume)).toStringAsFixed(0)} m³',
                      icon: Icons.water_drop,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SummaryCard(
                      title: 'Avg Pressure',
                      value:
                          '${(facilities.fold(0.0, (sum, f) => sum + f.pressure) / facilities.length).toStringAsFixed(0)} MPa',
                      icon: Icons.speed,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
