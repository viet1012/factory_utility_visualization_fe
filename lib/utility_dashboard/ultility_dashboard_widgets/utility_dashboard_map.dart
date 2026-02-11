import 'package:factory_utility_visualization/utility_dashboard/ultility_dashboard_widgets/utility_facility_info_box.dart';
import 'package:flutter/material.dart';

import '../../widgets/overview/factory_map_with_rain.dart';

class UtilityDashboardMap extends StatelessWidget {
  final String mainImageUrl;

  const UtilityDashboardMap({super.key, required this.mainImageUrl});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Container(
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
              Expanded(child: Container()),
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      FactoryMapWithRain(mainImageUrl: mainImageUrl),

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

                      /// ===== FAC A =====
                      Align(
                        alignment: const FractionalOffset(0.9, 0.04),
                        child: const UtilityFacilityInfoBox(
                          facId: 'Fac_A',
                          cateIds: ['E_TTL_KW', 'E_Cur1'],
                        ),
                      ),

                      /// ===== FAC B =====
                      Align(
                        alignment: const FractionalOffset(0.9, 0.7),
                        child: const UtilityFacilityInfoBox(
                          facId: 'Fac_B',
                          cateIds: ['E_TTL_KW', 'E_Cur1'],
                        ),
                      ),

                      /// ===== FAC C =====
                      Align(
                        alignment: const FractionalOffset(0.2, 0.04),
                        child: const UtilityFacilityInfoBox(
                          facId: 'Fac_C',
                          cateIds: ['E_TTL_KW', 'E_Cur1'],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: Container()),
            ],
          ),
        );
      },
    );
  }
}
