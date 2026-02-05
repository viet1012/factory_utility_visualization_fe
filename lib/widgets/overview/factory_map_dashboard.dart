import 'package:factory_utility_visualization/widgets/overview/summary_charts_grid.dart';
import 'package:factory_utility_visualization/widgets/overview/summary_column.dart';
import 'package:flutter/material.dart';
import '../../model/facility_filtered.dart';
import '../facility_info_box.dart';
import 'factory_map_with_rain.dart';
import 'package:factory_utility_visualization/widgets/overview/summary_charts_grid.dart';
import 'package:factory_utility_visualization/widgets/overview/summary_column.dart';
import 'package:flutter/material.dart';

import '../../model/facility_filtered.dart';
import '../facility_info_box.dart';
import 'factory_map_with_rain.dart';

class FactoryMapDashboard extends StatelessWidget {
  final List<FacilityFiltered> facilities;      // NOW
  final List<FacilityFiltered> prevFacilities;  // PREV
  final String mainImageUrl;

  const FactoryMapDashboard({
    super.key,
    required this.facilities,
    required this.prevFacilities,
    required this.mainImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: screenWidth,
      height: screenHeight / 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: SummaryChartsGrid(facilities: facilities)),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  FactoryMapWithRain(mainImageUrl: mainImageUrl),
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

                  if (facilities.isNotEmpty)
                    Positioned(
                      top: screenHeight * 0.0,
                      right: screenWidth * 0.05,
                      child: FacilityInfoBox(facility: facilities[0]),
                    ),
                    Positioned(
                      top: screenHeight * 0.4,
                      right: screenWidth * 0.05,
                      child: FacilityInfoBox(facility: facilities[1]),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SummaryColumn(
                facilities: facilities,
                prevFacilities: prevFacilities, // ✅ truyền prev vào
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Positioned(
//   top: screenHeight * 0.0,
//   left: screenWidth * 0.03,
//   child: FacilityInfoBox(facility: facilities[2]),
// ),